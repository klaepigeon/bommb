#!/usr/bin/env python3
"""Reads tools/geo_dump.gd's output and reports:
  - z-fighting: triangles from different meshes lying in the same plane (within 1.5 mm) and
    overlapping by more than 4 cm^2, grouped by the pair of meshes;
  - interpenetration: physics bodies whose boxes sink more than 3 cm into each other on every axis
    (furniture into furniture, things into walls), skipping a body inside the big wall/floor sets.
usage: geo_check.py geo.json"""
import json, sys, math, collections
d = json.load(open(sys.argv[1]))
def sub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
tris = []   # (mesh index, p0,p1,p2, n, dd, area)
for mi, m in enumerate(d["meshes"]):
    t = m["tris"]
    for i in range(0, len(t), 9):
        p0 = tuple(t[i:i+3]); p1 = tuple(t[i+3:i+6]); p2 = tuple(t[i+6:i+9])
        c = cross(sub(p1,p0), sub(p2,p0)); l = math.sqrt(dot(c,c))
        if l < 1e-6: continue
        n = (c[0]/l, c[1]/l, c[2]/l)
        # (kept facing the way the face faces: only faces facing the same way can fight; two
        # faces back to back, like the touching sides of two boxes, never show)
        tris.append((mi, p0, p1, p2, n, dot(n,p0), l/2))
buckets = collections.defaultdict(list)
for k, tr in enumerate(tris):
    n = tr[4]
    # only axis-aligned-ish planes matter for walls/floors/decals; bucket by normal and offset
    key = (round(n[0]*20), round(n[1]*20), round(n[2]*20), round(tr[5]/0.003))
    buckets[key].append(k)
def proj(tr):
    n = tr[4]
    ax = max(range(3), key=lambda i: abs(n[i]))
    keep = [i for i in range(3) if i != ax]
    return [(p[keep[0]], p[keep[1]]) for p in (tr[1],tr[2],tr[3])]
def overlap_area(a, b):
    # polygon clipping (Sutherland-Hodgman) of triangle a by triangle b, both 2D
    def clip(poly, e0, e1, sgn):
        out = []
        def side(p): return sgn * ((e1[0]-e0[0])*(p[1]-e0[1]) - (e1[1]-e0[1])*(p[0]-e0[0]))
        for i in range(len(poly)):
            p, q = poly[i], poly[(i+1)%len(poly)]
            sp, sq = side(p), side(q)
            if sp >= 0: out.append(p)
            if (sp >= 0) != (sq >= 0) and sp != sq:
                t = sp/(sp-sq); out.append((p[0]+(q[0]-p[0])*t, p[1]+(q[1]-p[1])*t))
        return out
    ar = (b[1][0]-b[0][0])*(b[2][1]-b[0][1]) - (b[1][1]-b[0][1])*(b[2][0]-b[0][0])
    sgn = 1 if ar > 0 else -1
    poly = list(a)
    for i in range(3):
        poly = clip(poly, b[i], b[(i+1)%3], sgn)
        if not poly: return 0.0
    s = 0
    for i in range(len(poly)):
        s += poly[i][0]*poly[(i+1)%len(poly)][1] - poly[(i+1)%len(poly)][0]*poly[i][1]
    return abs(s)/2
pairs = collections.Counter(); seen = set()
for key, ks in buckets.items():
    # neighbours in offset too (a plane on a bucket edge)
    near = list(ks)
    for dk in (-1, 1):
        near += buckets.get((key[0],key[1],key[2],key[3]+dk), [])
    if len(ks) < 1 or len(near) < 2: continue
    for i in ks:
        a = tris[i]
        for j in near:
            if j <= i: continue
            b = tris[j]
            if a[0] == b[0] or abs(a[5]-b[5]) > 0.0015 or dot(a[4], b[4]) < 0.999: continue
            pa, pb = proj(a), proj(b)
            if max(p[0] for p in pa) < min(p[0] for p in pb) or max(p[0] for p in pb) < min(p[0] for p in pa): continue
            if max(p[1] for p in pa) < min(p[1] for p in pb) or max(p[1] for p in pb) < min(p[1] for p in pa): continue
            ov = overlap_area(pa, pb)
            if ov > 0.0004:
                n1, n2 = d["meshes"][a[0]]["name"], d["meshes"][b[0]]["name"]
                pairs[tuple(sorted((n1, n2)))] += ov
bbox = {}
for m in d["meshes"]:
    t = m["tris"]; xs = t[0::3]; ys = t[1::3]; zs = t[2::3]
    bbox[m["name"]] = "[%.2f..%.2f, %.2f..%.2f, %.2f..%.2f]" % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))
def lab(n): return n + ("  " + bbox[n] if "@" in n.split("/")[-1] else "")
print("Z-FIGHTING: %d mesh pairs" % len(pairs))
for (a, b), area in pairs.most_common(60):
    print("  %.3f m2   %s  <->  %s" % (area, lab(a), lab(b)))
# which to lift: in each pair the one with less surface overall (the trim, the tiles, the rug)
area = collections.Counter()
for t in tris: area[d["meshes"][t[0]]["name"]] += t[6]
# layers: in every pair the smaller lies on the bigger, one layer up (relaxed until stable, so a
# trim on a wall on a shell ends up two layers up)
layer = collections.Counter()
edges = [((a if area[a] < area[b] else b), (b if area[a] < area[b] else a)) for (a, b), ov in pairs.items() if ov >= 0.0004]
for _ in range(10):
    changed = False
    for top, bot in edges:
        if layer[top] <= layer[bot]:
            layer[top] = layer[bot] + 1; changed = True
    if not changed: break
if len(sys.argv) > 3 and sys.argv[3] == "--bump":
    # measured on geometry already lifted by argv[2]: whatever still ties goes up past what it's on
    have = json.load(open(sys.argv[2]))
    short = lambda n: n.split("/")[-1]
    bumped = 0
    for top, bot in edges:
        if "/Apartment/" not in top and "Wardrobe" not in top: continue
        want = have.get(short(bot), 0) + 1
        if have.get(short(top), 0) < want: have[short(top)] = want; bumped += 1
    json.dump(have, open(sys.argv[2], "w"), indent=1, sort_keys=True)
    print("BUMPED %d meshes -> %s" % (bumped, sys.argv[2]))
elif len(sys.argv) > 2:
    out = {}
    for n, l in layer.items():
        if l > 0 and "/Apartment/" in n: out[n.split("/Apartment/")[-1].split("/")[-1]] = l
    json.dump(out, open(sys.argv[2], "w"), indent=1, sort_keys=True)
    print("LIFT LAYERS: %d meshes (max layer %d) -> %s" % (len(out), max(out.values()) if out else 0, sys.argv[2]))
# interpenetration
bs = d["bodies"]
def pen(a, b):
    return [min(a["max"][i], b["max"][i]) - max(a["min"][i], b["min"][i]) for i in range(3)]
hits = []
for i in range(len(bs)):
    for j in range(i+1, len(bs)):
        a, b = bs[i], bs[j]
        if a["name"] == b["name"]: continue
        if ("Walls" in a["name"] and "Walls" in b["name"]) or ("Floor" in a["name"] and "Floor" in b["name"]): continue
        p = pen(a, b)
        if min(p) > 0.03:
            # skip a thing resting inside a much bigger room-sized box (floors, ceilings)
            va = math.prod(a["max"][k]-a["min"][k] for k in range(3)); vb = math.prod(b["max"][k]-b["min"][k] for k in range(3))
            if max(va, vb) > 6.0: continue
            hits.append((min(p), a["name"], a["kind"], b["name"], b["kind"]))
hits.sort(reverse=True)
print("INTERPENETRATING: %d pairs (sunk > 3 cm on every axis)" % len(hits))
for h in hits[:80]:
    print("  %.2f m   %s (%s)  <->  %s (%s)" % h)
