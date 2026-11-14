"""Biomechanical parts for the inhabitants (docs/PEOPLE.md): the building has grown into them.

Bone, gristle and hose, ribbed like ducting, wet; and coral, the thing that joins every one of
them: branching out of a shoulder, crusting a skull in brain-coral grooves, fanned out where ears
were, the same pitted bleached stuff in every body in the building.

	ribbify(loft, per_m, depth)       limbs and necks segmented like hose
	elongate(M, L, amount)            the skull drawn back and up
	spine_ridge(M, L, ...)            vertebrae standing out of the back, up into the skull
	rib_hoops(M, L, ...)              the ribs outside the body, the chest sunk in behind them
	hose(M, a, b, bones, ...)         a ribbed tube grown from one place on the body into another
	coral(M, root, dir, bone, ...)    branching staghorn coral, from inside the body out
	fan(M, root, bone, ...)           fan coral: a flat spread of ribs
	tendrils(M, L, ...)               hoses hanging from the skull instead of hair

And the paint: bone, gristle, the wet dark of the cavities, coral (pitted, bleached, the polyps'
tips orange-pink), brain-coral grooves.
"""
import numpy as np

from lowpoly import C, F, Loft, Ring, cells, fbm, mix, smoothstep, vnoise


def _lerpw(a, b, t):
	if callable(a) or callable(b):
		return a if t < 0.5 else b
	out = {}
	for k, v in a.items():
		out[k] = out.get(k, 0) + v * (1 - t)
	for k, v in b.items():
		out[k] = out.get(k, 0) + v * t
	return out


def ribbify(loft, per_m=40.0, depth=0.18, keep_ends=True):
	"""Rings in between the rings, alternately fat and thin: a ribbed tube. The thin ones are
	grooves (dark in the paint)."""
	rs = loft.rings
	out = [rs[0]]
	k = 0
	for i in range(len(rs) - 1):
		a, b = rs[i], rs[i + 1]
		ln = np.linalg.norm(b.c - a.c)
		n = max(1, int(ln * per_m))
		for j in range(1, n + 1):
			t = j / n
			last = j == n
			r = Ring(a.c + (b.c - a.c) * t, a.rx + (b.rx - a.rx) * t, a.rz + (b.rz - a.rz) * t, w=_lerpw(a.w, b.w, t),
				front=a.front + (b.front - a.front) * t, back=a.back + (b.back - a.back) * t, bumps=(b.bumps if t > 0.5 else a.bumps),
				shift=a.shift + (b.shift - a.shift) * t, minv=0.004)
			if not (last and keep_ends and i == len(rs) - 2):
				k += 1
				if k % 2:
					r.rx *= 1 - depth
					r.rz *= 1 - depth
					r.dark = 1.0
				else:
					r.rx *= 1 + depth * 0.3
					r.rz *= 1 + depth * 0.3
			out.append(r)
	loft.rings = out
	return loft


def elongate(M, L, amount=1.0):
	"""The cranium drawn out backward and up, a long ribbed dome."""
	hs, head = L["hs"], L["head"]
	lf = next(l for l in M.lofts if l.name == "head")
	keep = []
	for r in lf.rings:
		y = (r.c[1] - head[1]) / hs
		if y > 0.65:
			t = y - 0.65
			r.c = r.c + F(0, t * hs * 0.25 * amount, -t * t * hs * 1.4 * amount)
		keep.append(r)
	# carry on out the back
	top = keep[-2]
	cap = keep[-1]
	base = top.c
	for i, t in enumerate((0.35, 0.7, 1.0)):
		c = base + F(0, hs * (0.12 * t) * amount, -hs * (0.45 * t + 0.05) * amount)
		rr = top.rx * (1 - 0.55 * t)
		keep.insert(len(keep) - 1, Ring(c, rr, top.rz * (1 - 0.6 * t), w={"head": 1.0}, minv=0.02, dark=0.0))
	cap.c = keep[-2].c + F(0, hs * 0.03, -hs * 0.08)
	cap.rx *= 0.5
	cap.rz *= 0.5
	lf.rings = keep
	lf.front_hint = np.array([0, 0, -1.0])


def spine_ridge(M, L, r=0.02, into_skull=True, knobs=0.5):
	"""Vertebrae down the back: a ridge riding the trunk from the hips up the neck, into the skull."""
	k, gw = L["k"], L["gw"]
	pts = []
	ys = np.linspace(L["hips"][1] + 0.02, L["neck"][1] + (0.12 if into_skull else 0.0), 14)
	for y in ys:
		depth = 0.1 * gw * k if y < L["neck"][1] - 0.03 else 0.05 * k
		if into_skull and y > L["head"][1]:
			depth = L["hs"] * 0.35
		pts.append(F(0, y, -depth - r * 0.3))
	rs = []
	for p_ in pts:
		y = p_[1]
		if y < L["spine"][1] + 0.05:
			w = {"hips": 1.0}
		elif y < L["chest"][1]:
			w = {"spine": 1.0}
		elif y < L["neck"][1]:
			w = {"chest": 1.0}
		elif y < L["head"][1]:
			w = {"neck": 1.0}
		else:
			w = {"head": 1.0}
		rs.append(Ring(p_, r * k, r * k * 1.3, w=w))
	lf = Loft("vert_spine", rs, sides=6, front_hint=(0, 0, 1))
	ribbify(lf, 70.0, knobs)
	M.add(lf)


def rib_hoops(M, L, n=6, r=0.008, out=1.15):
	"""Ribs outside the body: hoops from the spine round to the front, open at the sternum."""
	k, gw = L["k"], L["gw"]
	for i in range(n):
		y = L["spine"][1] + 0.12 * k + i * 0.045 * k
		rx = (0.15 + 0.012 * i) * gw * k * out
		rz = 0.105 * gw * k * out
		for s in (-1, 1):
			pts = []
			for a in np.linspace(np.pi * 0.95, 0.18, 7):
				pts.append(F(s * rx * np.sin(a), y - 0.03 * k * (1 - a / np.pi), rz * np.cos(a)))
			w = {"chest": 1.0} if y > L["chest"][1] - 0.08 else {"spine": 0.5, "chest": 0.5}
			M.add(Loft("rib_%d%s" % (i, "lr"[s > 0]), [Ring(p, r * k, r * k * 1.6, w=w) for p in pts], sides=4))


def hose(M, a, b, bones, r=0.02, sag=0.1, out=None, per_m=55.0, name="hose"):
	"""A ribbed tube from a to b (both on the body), bowing out along `out`, weighted from the
	first bone to the second along its length."""
	a = np.asarray(a, float)
	b = np.asarray(b, float)
	out = np.asarray(out if out is not None else (0, 0, 1), float)
	c1 = a + out * sag + (b - a) * 0.25
	c2 = b + out * sag - (b - a) * 0.25
	rs = []
	for t in np.linspace(0, 1, 9):
		p = (1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * c1 + 3 * (1 - t) * t * t * c2 + t ** 3 * b
		w = {bones[0]: 1 - smoothstep(0.3, 0.7, t), bones[1]: smoothstep(0.3, 0.7, t)}
		w = {k_: v for k_, v in w.items() if v > 0.001}
		rs.append(Ring(p, r * (1.25 if t in (0, 1) else 1.0), w=w))
	lf = Loft(name, rs, sides=6, cap_start=False, cap_end=False, front_hint=(0, 1, 0))
	ribbify(lf, per_m, 0.22)
	M.add(lf)


def coral(M, root, direction, bone, length=0.18, r=0.022, depth=3, spread=0.6, rng=None, name="coral", n=2):
	"""Staghorn coral: a branch from inside the body outward, splitting, tapering, blunt-tipped."""
	rng = rng if rng is not None else np.random.default_rng(1)
	d = np.asarray(direction, float)
	d /= np.linalg.norm(d)
	root = np.asarray(root, float)
	tip = root + d * length
	mid = root + d * length * 0.5 + rng.normal(0, length * 0.08, 3)
	rs = [Ring(root - d * r, r * 1.2, w={bone: 1}), Ring(mid, r * 0.8, w={bone: 1}), Ring(tip - d * r * 0.4, r * 0.75, w={bone: 1}),
		Ring(tip, r * 1.0, w={bone: 1}), Ring(tip + d * r * 0.5, r * 0.7, w={bone: 1})]       # a bulb at the tip, a polyp
	idx = len(M.lofts)
	M.add(Loft("%s_%d" % (name, idx), rs, sides=5, cap_start=False, cap_end=True, front_hint=(0, 1, 0) if abs(d[1]) < 0.9 else (0, 0, -1), texel=0.8))
	if depth > 1:
		for i in range(n):
			nd = d + rng.normal(0, spread, 3)
			nd /= np.linalg.norm(nd)
			coral(M, tip - d * r * 0.5, nd, bone, length * rng.uniform(0.55, 0.8), r * 0.72, depth - 1, spread, rng, name, n)


def crust(M, centre, normal, bone, rng, n=8, size=0.05, r=0.014, name="coral"):
	"""Coral crust: knobbed stubs breaking out of an area of skin."""
	normal = np.asarray(normal, float)
	normal /= np.linalg.norm(normal)
	for i in range(n):
		off = rng.normal(0, size * 0.8, 3)
		off -= normal * (off @ normal)
		d = normal + rng.normal(0, 0.45, 3)
		coral(M, np.asarray(centre) + off, d, bone, size * rng.uniform(0.5, 1.2), r * rng.uniform(0.7, 1.3), 1, 0.5, rng, name)


def fan(M, root, bone, up=(0, 1, 0), side=(1, 0, 0), size=0.12, ribs=6, name="fan"):
	"""Fan coral: ribs spread in a plane from one root, thin."""
	root = np.asarray(root, float)
	up = np.asarray(up, float)
	side = np.asarray(side, float)
	for i in range(ribs):
		a = (i / (ribs - 1) - 0.5) * 2.0
		d = up * np.cos(a * 0.9) + side * np.sin(a * 0.9)
		pts = [root, root + d * size * 0.5 + side * 0.01 * a, root + d * size]
		M.add(Loft("%s_%d" % (name, len(M.lofts)), [Ring(p, 0.006 * (1.0 - 0.4 * j), w={bone: 1}) for j, p in enumerate(pts)], sides=4, texel=0.8))
		if i < ribs - 1:
			pass


def tendrils(M, L, n=10, length=0.5, r=0.012, rng=None):
	"""Instead of hair: hoses hanging from the back of the skull, to the shoulders and below."""
	rng = rng if rng is not None else np.random.default_rng(3)
	hs, head = L["hs"], L["head"]
	for i in range(n):
		a = rng.uniform(-2.4, 2.4)
		if abs(a) < 0.7:
			a = np.sign(a + 1e-3) * 0.7 + a * 0.3
		start = head + F(np.sin(a) * hs * 0.36, hs * rng.uniform(0.55, 0.95), np.cos(a) * hs * 0.36 * -1.0 if abs(a) > 1.57 else np.cos(a) * hs * 0.3)
		start = head + F(np.sin(a) * hs * 0.38, hs * rng.uniform(0.6, 0.95), -abs(np.cos(a)) * hs * 0.3 - hs * 0.05)
		ln = length * rng.uniform(0.6, 1.0)
		pts = [start + F(np.sin(a) * 0.02 * t, -ln * t, -0.04 * t - 0.03 * t * t) for t in np.linspace(0, 1, 6)]
		rs = []
		for j, p in enumerate(pts):
			y = p[1]
			w = {"head": 1.0} if y > L["neck"][1] + 0.05 else ({"neck": 0.5, "chest": 0.5} if y > L["chest"][1] else {"chest": 1.0})
			rs.append(Ring(p, r * (1 - 0.3 * j / 5), w=w))
		lf = Loft("hose_tendril%d" % i, rs, sides=5, front_hint=(0, 0, -1))
		ribbify(lf, 60.0, 0.25)
		M.add(lf)


# ------------------------------------------------------------------ paint
BONE = C("9a8460")
GRISTLE = C("8c6a52")
CAVITY = C("2a120e")
CORAL = C("c4ab8c")
POLYP = C("b8563c")
HOSE = C("5e5248")


def coral_paint(P, s, col, amt=1.0):
	"""Bleached, pitted; the tips going orange-pink."""
	c = CORAL * (0.85 + 0.15 * vnoise(P, 40.0, 2)[..., None])
	pores = smoothstep(0.32, 0.18, cells(P, 90.0, 6))
	c = mix(c, pores, C("4a3a30"), 0.75)
	c = mix(c, smoothstep(0.55, 0.85, s), POLYP, 0.85)
	c = mix(c, smoothstep(0.0, 0.25, 0.25 - s), C("3a2a20"), 0.6)    # dark where it breaks out of the skin
	return mix(col, np.ones(s.shape), c, amt) if np.ndim(amt) == 0 else col * (1 - amt[..., None]) + c * amt[..., None]


def brain_coral(P, mask, col, scale=14.0, seed=8):
	"""Meandering grooves, like brain coral, over a skull or a back."""
	m = np.abs(np.sin(fbm(P, scale, 2, seed) * 18.0))
	groove = (m < 0.28) * mask
	col = mix(col, mask, CORAL * 0.8, 0.45)
	col = mix(col, groove, C("2a1a14"), 0.85)
	return col


def grime(P, col, amt=0.35, seed=3):
	col = mix(col, smoothstep(0.1, 0.6, fbm(P, 7.0, 3, seed)), C("3a2c20"), amt)
	return mix(col, smoothstep(0.35, 0.15, cells(P, 120.0, seed + 1)), C("4a3a2c"), 0.3)


def grooves(M, col, c=CAVITY, amt=0.75):
	"""The ribbed parts' grooves, dark."""
	return mix(col, M.dark, c, amt)


def seep(P, N, col, amt=0.6, seed=12):
	"""Dark wet runs down from the joins."""
	run = fbm(P * np.array([3.0, 0.4, 3.0]), 9.0, 2, seed)
	return mix(col, smoothstep(0.25, 0.55, run), C("3a1a14"), amt)
