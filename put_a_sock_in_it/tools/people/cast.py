"""The building's inhabitants, low-poly (docs/PEOPLE.md). Writes assets/people/<name>.glb + .png.

	python3 tools/people/cast.py            # everyone
	python3 tools/people/cast.py super      # one

Every body comes from figure(): the same skeleton as FleshBody (hips spine chest neck head jaw,
sh/el/(ex)/hip/kn each side, belly if they have one), lofts for the trunk, head, arms, legs,
feet and fingers, shaped by the numbers in its dict. Then each character paints itself.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from lowpoly import C, F, Loft, Model, Ring, cells, fbm, mix, smoothstep, vnoise  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "people")


def W(**k):
	return k


def blendw(a, b, t):
	return {a: 1 - t, b: t} if a != b else {a: 1.0}


# ------------------------------------------------------------------ a figure
def figure(M, p):
	"""The skeleton and the lofts. p: height, girth (width), chest, waist, belly (forward),
	hips, thigh, calf, arm (length), upper/fore (thickness), neck (length), neckw, head (size),
	headw, jawf (chin forward), nose, brow, cheeks (hollow -), mouth (width), lip (gap: open),
	fingers (length, 0 = mittens), extra_joint, stoop, knees/elbows (knobs), skirt (length),
	hair (long: length), ears, wattle."""
	h = p.get("height", 1.75)
	k = h / 1.75
	gw = p.get("girth", 1.0)
	leg = 0.86 * k
	torso = 0.56 * k
	nl = 0.11 * k * p.get("neck", 1.0)
	hs = 0.22 * k * p.get("head", 1.0)
	L = dict(k=k, gw=gw, leg=leg, torso=torso, hs=hs)
	hips = M.bone("hips", None, F(0, leg, 0))
	spine = M.bone("spine", "hips", F(0, leg + 0.02, 0))
	chest = M.bone("chest", "spine", spine + F(0, torso * 0.5, 0))
	neck = M.bone("neck", "chest", chest + F(0, torso * 0.5, 0))
	head = M.bone("head", "neck", neck + F(0, nl, 0))
	jaw = M.bone("jaw", "head", head + F(0, hs * 0.42, hs * 0.05))
	if p.get("belly", 0.0) > 0.2:
		M.bone("belly", "spine", spine + F(0, torso * 0.18, 0.12 * k))
	L.update(hips=hips, spine=spine, chest=chest, neck=neck, head=head, jaw=jaw)
	sw = p.get("shoulders", 1.0)
	cw = p.get("chest", 1.0)
	ww = p.get("waist", 1.0)
	hw = p.get("hips", 1.0)
	bf = p.get("belly", 0.0)
	st = p.get("stoop", 0.0)
	y0 = leg
	# --- the trunk: crotch to the top of the neck
	ring = []
	def tw(y):
		# hips -> spine -> chest -> neck by height
		if y < spine[1] + 0.05:
			return {"hips": 1.0}
		if y < chest[1]:
			t = (y - spine[1] - 0.05) / (chest[1] - spine[1] - 0.05)
			return blendw("spine", "chest", smoothstep(0.3, 1.0, t))
		if y < neck[1] - 0.02:
			return {"chest": 1.0}
		return blendw("chest", "neck", smoothstep(neck[1] - 0.02, neck[1] + 0.03, y))
	tr = [
		(-0.06, 0.07 * hw, 0.06, 0, 0),                  # crotch
		(0.0, 0.15 * hw, 0.1, 0.0, 0.03 * p.get("butt", 1.0)),   # hips
		(0.08, 0.16 * hw, 0.105, bf * 0.06, 0.02),
		(0.17, 0.14 * ww, 0.095, bf * 0.12 - p.get("sunken", 0.0), 0.0),   # belly / waist
		(0.26, 0.135 * ww, 0.09, bf * 0.1 - p.get("sunken", 0.0) * 0.6, 0.0),
		(0.35, 0.15 * cw, 0.1, bf * 0.03, 0.01),            # the bottom of the ribs
		(0.44, 0.165 * cw, 0.105, 0.0, 0.015),
		(0.51, 0.18 * sw, 0.095, 0.0, 0.02),               # the shoulders
		(0.56, 0.12 * sw, 0.075, -0.01, 0.01),
		(0.585, 0.055 * p.get("neckw", 1.0), 0.055 * p.get("neckw", 1.0), 0.0, 0.0),   # the neck
	]
	for (yy, rx, rz, fr, bk) in tr:
		y = y0 + yy * k * (torso / (0.56 * k)) if yy <= 0.56 else y0 + 0.56 * k
		y = y0 + yy * k
		r = Ring(F(0, y, st * max(0, yy - 0.3) * 0.25), rx * gw * k, rz * gw * k, w=tw(y), front=fr * k, back=bk * k)
		ring.append(r)
	# up the neck to inside the head
	for t in (0.5, 1.15):
		y = neck[1] + nl * t
		ring.append(Ring(F(0, y, st * 0.1), 0.05 * p.get("neckw", 1.0) * k, 0.052 * p.get("neckw", 1.0) * k, w=blendw("neck", "head", smoothstep(0.6, 1.0, t)) if t < 1 else {"head": 1.0}))
	if p.get("wattle"):
		ring[-2].front += 0.02 * k
	for r in p.get("trunk_extra", []):
		pass
	M.add(Loft("trunk", ring, sides=10, cap_start=True, cap_end=True, texel=1.0))
	# --- the head
	head_(M, p, L)
	# --- legs
	for s, side in ((-1, "l"), (1, "r")):
		hj = M.bone("hip_" + side, "hips", hips + F(s * 0.095 * gw * k * hw, 0, 0))
		kn = M.bone("kn_" + side, "hip_" + side, hj + F(0, -leg * 0.5, 0.01))
		an = kn + F(0, -leg * 0.5 + 0.07 * k, -0.01)
		L["kn_" + side], L["an_" + side] = kn, an
		th = p.get("thigh", 1.0)
		ca = p.get("calf", 1.0)
		kb = p.get("knees", 1.0)
		rs = [
			Ring(hj + F(0, 0.06, 0), 0.085 * th * gw * k, w={"hips": 0.7, "hip_" + side: 0.3}),
			Ring(hj + F(0, -0.02, 0), 0.08 * th * gw * k, w={"hips": 0.25, "hip_" + side: 0.75}),
			Ring(hj + (kn - hj) * 0.45, 0.068 * th * gw * k, w={"hip_" + side: 1.0}),
			Ring(kn + F(0, 0.06, 0), 0.05 * th * k * (1 + (gw - 1) * 0.5), w={"hip_" + side: 1.0}),
			Ring(kn, 0.048 * kb * k, w={"hip_" + side: 0.5, "kn_" + side: 0.5}, front=0.008 * kb * k),
			Ring(kn + F(0, -0.06, -0.005), 0.045 * ca * k, w={"kn_" + side: 1.0}, back=0.012 * ca * k),
			Ring(kn + (an - kn) * 0.45, 0.04 * ca * k, w={"kn_" + side: 1.0}, back=0.008 * ca * k),
			Ring(an + F(0, 0.03, 0), 0.03 * k * p.get("ankle", 1.0), w={"kn_" + side: 1.0}),
		]
		M.add(Loft("leg_" + side, rs, sides=7, cap_start=False, cap_end=False))
		fl = p.get("foot", 1.0)
		fs = [
			Ring(an + F(0, -0.01, -0.045 * k), 0.028 * k, 0.03 * k, w={"kn_" + side: 1}),
			Ring(an + F(0, -0.035 * k, 0.0), 0.04 * k, 0.035 * k, w={"kn_" + side: 1}),
			Ring(an + F(0, -0.05 * k, 0.07 * k * fl), 0.045 * k, 0.02 * k, w={"kn_" + side: 1}),
			Ring(an + F(0, -0.058 * k, 0.15 * k * fl), 0.04 * k, 0.012 * k, w={"kn_" + side: 1}),
		]
		M.add(Loft("foot_" + side, fs, sides=6, front_hint=(0, 1, 0), texel=1.2))
	# --- arms
	ab = p.get("spread", 0.1)
	for s, side in ((-1, "l"), (1, "r")):
		sh = M.bone("sh_" + side, "chest", chest + F(s * 0.2 * gw * k * sw, torso * 0.45, 0))
		d = np.array([s * np.sin(ab), -np.cos(ab), 0.0])
		up = 0.32 * k * p.get("arm", 1.0)
		lo = 0.3 * k * p.get("arm", 1.0)
		el = M.bone("el_" + side, "sh_" + side, sh + d * up)
		ua = p.get("upper", 1.0)
		fa = p.get("fore", 1.0)
		eb = p.get("elbows", 1.0)
		rs = [
			Ring(F(s * 0.13 * sw * gw * k, sh[1] + 0.02, 0), 0.055 * ua * k * gw ** 0.5, w={"chest": 0.8, "sh_" + side: 0.2}),
			Ring(F(s * (0.13 * sw * gw * k + abs(sh[0] - s * 0.13 * sw * gw * k) * 0.6) , sh[1] + 0.015, 0), 0.058 * ua * k * gw ** 0.5, w={"chest": 0.5, "sh_" + side: 0.5}),
			Ring(sh + d * 0.02, 0.055 * ua * k * gw ** 0.5, w={"sh_" + side: 1.0}),
			Ring(sh + d * up * 0.45, 0.045 * ua * k * gw ** 0.5, w={"sh_" + side: 1.0}, back=p.get("arm_sag", 0.0) * k),
			Ring(el, 0.034 * eb * k, w={"sh_" + side: 0.5, "el_" + side: 0.5}, back=0.006 * eb * k),
			Ring(el + d * lo * 0.3, 0.035 * fa * k, w={"el_" + side: 1.0}),
		]
		bone_hand = "el_" + side
		if p.get("extra_joint"):
			ex = M.bone("ex_" + side, "el_" + side, el + d * lo)
			rs += [Ring(ex, 0.03 * k, w={"el_" + side: 0.5, "ex_" + side: 0.5}, front=0.008 * k),
				Ring(ex + d * lo * 0.4, 0.027 * k, w={"ex_" + side: 1.0})]
			wr = ex + d * lo * 0.8
			bone_hand = "ex_" + side
		else:
			wr = el + d * lo
		rs += [Ring(wr, 0.024 * k * fa ** 0.5, 0.02 * k, w={bone_hand: 1.0})]
		L["sh_" + side], L["el_" + side], L["wr_" + side] = sh, el, wr
		# the hand: flat, on the end of the arm
		hk = p.get("hand", 1.0) * k
		fg = p.get("fingers", 1.0)
		palm = [Ring(wr + d * 0.04 * hk, 0.016 * hk, 0.04 * hk, w={bone_hand: 1.0}),
			Ring(wr + d * 0.085 * hk, 0.013 * hk, 0.042 * hk, w={bone_hand: 1.0})]
		if fg <= 0:
			palm.append(Ring(wr + d * 0.13 * hk, 0.01 * hk, 0.03 * hk, w={bone_hand: 1.0}))
		rs += palm
		M.add(Loft("arm_" + side, rs, sides=7, cap_start=False, cap_end=True, front_hint=(0, 0, -1)))
		if fg > 0:
			for i in range(4):
				off = (-0.03 + i * 0.02) * hk
				base = wr + d * 0.08 * hk + F(0, 0, off)
				ln = (0.075 - abs(i - 1.4) * 0.008) * hk * fg
				curl = F(-s * 0.012 * hk * fg, 0, 0)
				fr = [Ring(base, 0.009 * hk, w={bone_hand: 1}), Ring(base + d * ln * 0.55, 0.008 * hk, w={bone_hand: 1}),
					Ring(base + d * ln + curl, 0.006 * hk, w={bone_hand: 1})]
				M.add(Loft("finger_%s%d" % (side, i), fr, sides=4, texel=1.5))
			tb = wr + d * 0.04 * hk + F(0, 0, 0.04 * hk)
			M.add(Loft("thumb_" + side, [Ring(tb, 0.011 * hk, w={bone_hand: 1}), Ring(tb + d * 0.04 * hk + F(0, 0, 0.015 * hk), 0.008 * hk, w={bone_hand: 1})], sides=4, texel=1.5))
	# --- a skirt
	if p.get("skirt"):
		ln = p["skirt"]
		def sw_(t):
			def f(th):
				side = "l" if np.sin(th) > 0 else "r"     # (+angle is the body's left)
				return {"hips": 1 - t, "hip_" + side: t}
			return f
		rs = []
		for i, t in enumerate(np.linspace(0, 1, 5)):
			y = hips[1] + 0.08 - t * leg * ln
			rx = (0.165 + t * 0.08) * hw * gw * k
			rs.append(Ring(F(0, y, 0), rx, rx * 0.8, w=sw_(t * 0.7)))
		M.add(Loft("skirt", rs, sides=12, cap_start=False, cap_end=False, texel=0.8))
	# --- long hair, hanging behind
	if p.get("hair"):
		hl = p["hair"]
		rs = []
		for i, t in enumerate(np.linspace(0, 1, 5)):
			y = head[1] + hs * 0.95 - t * (hs * 0.6 + hl)
			rx = hs * (0.45 + 0.05 * t)
			rz = hs * (0.18 if t > 0.3 else 0.35) * (1 - t * 0.3)
			wv = {"head": 1.0} if y > neck[1] + nl else blendw("head", "chest", smoothstep(neck[1] + nl, chest[1], y))
			rs.append(Ring(F(0, y, -hs * (0.18 + 0.12 * t)), rx, rz, w=wv))
		M.add(Loft("hair", rs, sides=10, texel=0.7))
	return L


def head_(M, p, L):
	k, hs, head = L["k"], L["hs"], L["head"]
	hw = p.get("headw", 1.0)
	mw = p.get("mouth", 1.0)
	gap = p.get("lip", 0.0) * hs
	jf = p.get("jawf", 0.0)
	nose = p.get("nose", 1.0)
	cheek = p.get("cheeks", 0.0)
	brow = p.get("brow", 1.0)
	mouth_y = head[1] + hs * 0.34
	L["mouth_y"] = mouth_y

	def jawish(level):
		# the front of the lower face goes with the jaw; the back and sides stay with the skull
		def f(th):
			a = np.clip(1.2 - np.abs(th), 0, 1) * level
			return {"jaw": a, "head": 1 - a} if a > 0 else {"head": 1.0}
		return f
	R = [
		# (height in head-sizes, half-width, half-depth, front bulge, extra bumps, weights)
		(0.02, 0.24, 0.26, 0.0, [], {"head": 1.0}),
		(0.12, 0.3, 0.32, 0.02 + jf * 0.05, [], jawish(1.0)),                       # under the chin
		(0.22, 0.34, 0.37, 0.04 + jf * 0.06, [(0, 0.5, 0.02 + jf * 0.04)], jawish(1.0)),     # chin
		(0.31 - gap / hs * 0.5, 0.36, 0.4, 0.03 + jf * 0.04, [], jawish(1.0)),          # the lower lip
		(0.33, 0.36, 0.41, 0.03, [], jawish(1.0)),                                      # (the mouth: this band)
		(0.35, 0.37, 0.41, 0.03, [], {"head": 1.0}),                                   # the upper lip
		(0.45, 0.38, 0.4, 0.01, [(0, 0.22, 0.05 * nose), (0.75, 0.3, cheek), (-0.75, 0.3, cheek)], {"head": 1.0}),  # under the nose
		(0.55, 0.39, 0.4, 0.0, [(0, 0.2, 0.06 * nose), (0.75, 0.35, cheek * 0.6), (-0.75, 0.35, cheek * 0.6)], {"head": 1.0}),   # nose, cheekbones
		(0.63, 0.39, 0.4, -0.015, [(0, 0.18, 0.025 * nose), (0.35, 0.18, -0.02), (-0.35, 0.18, -0.02)], {"head": 1.0}),  # the eyes, sunk
		(0.72, 0.4, 0.41, 0.015 * brow, [(0.35, 0.3, 0.012 * brow), (-0.35, 0.3, 0.012 * brow)], {"head": 1.0}),   # brow
		(0.85, 0.39, 0.42, 0.0, [], {"head": 1.0}),
		(0.98, 0.34, 0.38, 0.0, [], {"head": 1.0}),
		(1.08, 0.24, 0.28, 0.0, [], {"head": 1.0}),
		(1.13, 0.1, 0.12, 0.0, [], {"head": 1.0}),
	]
	rs = []
	for (y, rx, rz, fr, bumps, w) in R:
		rs.append(Ring(head + F(0, y * hs, 0.02 * hs), rx * hs * hw * (mw ** 0.25 if y < 0.5 else 1.0) * (p.get("jaww", 1.0) if y < 0.4 else 1.0), rz * hs, w=w, front=fr * hs, bumps=[(a, wd, amt * hs) for a, wd, amt in bumps], minv=0.02))
	rs[4].c = rs[4].c + F(0, 0, 0)
	M.add(Loft("head", rs, sides=12, cap_start=True, cap_end=True, texel=4.0))
	# ears
	er = p.get("ears", 1.0)
	if er > 0:
		for s in (-1, 1):
			c = head + F(s * hs * 0.39 * hw, hs * 0.6, -0.01)
			M.add(Loft("ear_" + ("l" if s < 0 else "r"), [Ring(c, hs * 0.02, hs * 0.05 * er, w={"head": 1}),
				Ring(c + F(s * hs * 0.06 * er, 0, -0.01), hs * 0.015, hs * 0.08 * er, w={"head": 1}),
				Ring(c + F(s * hs * 0.1 * er, 0.005, -0.015), hs * 0.01, hs * 0.06 * er, w={"head": 1})],
				sides=4, front_hint=(0, 1, 0), texel=1.6))


# ------------------------------------------------------------------ paint
LIGHT = None


def face(P, N, th, s, M, L, p, col):
	"""The face, painted on the head loft in its own coordinates: th around (0 the front), y."""
	hs, head = L["hs"], L["head"]
	y = (P[..., 1] - head[1]) / hs
	a = th
	fr = np.cos(a) > 0
	# eyes
	style = p.get("eyes", "normal")
	ey, ex = 0.63, 0.32 * p.get("eyegap", 1.0)
	es = p.get("eye_size", 1.0)
	spots = []
	if style in ("normal", "sewn"):
		spots = [(ex, ey, 1.0), (-ex, ey + p.get("slide_eye", 0.0), 1.0)]
	elif style == "many":
		rng = np.random.default_rng(7)
		spots = [(rng.uniform(-1.0, 1.0), rng.uniform(0.45, 0.95), rng.uniform(0.6, 1.1)) for _ in range(p.get("eye_count", 9))]
	sock = p.get("sockets", 0.5)
	for (axx, ayy, sz) in spots:
		dx = (a - axx) / (0.13 * es * sz)
		dy = (y - ayy) / (0.05 * es * sz)
		d = np.sqrt(dx * dx + dy * dy)
		col = mix(col, smoothstep(2.3, 1.0, d), C("3a2a22"), sock)         # the socket's shadow
		if style == "sewn":
			lid = d < 1.0
			col = mix(col, lid, C("8a5a50"), 0.7)
			seam = lid & (np.abs(dy) < 0.18)
			col = mix(col, seam, C("140c0a"))
			stitch = lid & (np.abs(np.sin(dx * 5.0)) < 0.35) & (np.abs(dy) < 0.75)
			col = mix(col, stitch, C("1c1210"))
			continue
		white = d < 1.0
		col = mix(col, white, p.get("sclera", C("c8bc98")))
		iris = np.sqrt((dx * 1.0) ** 2 + (dy * 0.75) ** 2) < 0.55
		col = mix(col, iris, p.get("iris", C("3a3020")))
		col = mix(col, np.sqrt(dx * dx + dy * dy) < 0.25, C("050404"))
		col = mix(col, (d < 1.15) & (d > 0.85) & (dy > 0), C("2a1c16"), 0.8)       # the lid's edge
		col = mix(col, (d < 1.0) & (dy > 0.55), p.get("lid_col", C("6a5444")), 0.9)  # heavy lids
	if style == "none":
		for sgn in (-1, 1):
			d = np.sqrt(((a - sgn * ex) / 0.16) ** 2 + ((y - ey) / 0.06) ** 2)
			col = mix(col, smoothstep(1.5, 0.6, d), C("6a5a52"), 0.35)
	# the mouth: a lens, the corners turned down; the inside dark; teeth hung from the top, uneven
	mw = 0.3 * p.get("mouth", 1.0)
	gap = p.get("lip", 0.0)
	mid = 0.33 - gap * 0.4
	u = a / mw
	line = mid - 0.035 * u * u * p.get("droop", 1.0)
	half = (0.006 + gap * 0.5) * np.clip(1 - u * u, 0, 1) ** 0.6
	inside = fr & (np.abs(u) < 1) & (np.abs(y - line) < half)
	col = mix(col, inside, C("1a0606"))
	teeth = p.get("teeth", 0)
	if teeth:
		rng = np.random.default_rng(p.get("seed", 1))
		gaps = rng.random(64) < p.get("missing", 0.0)
		ln = rng.uniform(0.4, 1.0, 64)
		ti = np.clip(np.floor((u + 1) * 0.5 * teeth * 2).astype(int), 0, 63)
		frac = (u + 1) * 0.5 * teeth * 2 - np.floor((u + 1) * 0.5 * teeth * 2)
		top = line + half
		tt = inside & ((ti % 2) == 0) & ~gaps[ti] & (top - y < (half * 2) * ln[ti] * 0.8) & (np.abs(frac - 0.5) < 0.45)
		col = mix(col, tt, p.get("teeth_col", C("b8a470")) * (0.75 + 0.25 * ln[ti])[..., None])
		low = inside & ((ti % 2) == 1) & ~gaps[(ti + 7) % 64] & (y - (line - half) < half * 0.5) & (gap > 0.02)
		col = mix(col, low, p.get("teeth_col", C("b8a470")) * 0.7)
	lipc = p.get("lip_col", C("7a5050"))
	near = fr & (np.abs(u) < 1.12) & ~inside
	col = mix(col, near & (y > line) & (y < line + half + 0.03), lipc, 0.55)
	col = mix(col, near & (y < line) & (y > line - half - 0.04), lipc, 0.65)
	col = mix(col, near & (y < line - half - 0.04) & (y > line - half - 0.08), C("3a2a22"), 0.35)   # under the lip
	col = mix(col, fr & (np.abs(u) > 0.95) & (np.abs(u) < 1.25) & (np.abs(y - line) < 0.02), C("2a1c16"), 0.6)  # the corners
	# nose: nostrils, the shadow under it, the bridge
	n = p.get("nose", 1.0)
	if n > 0:
		col = mix(col, fr & (np.abs(a) < 0.17) & (y > 0.43) & (y < 0.47), C("3a2620"), 0.6)
		for sgn in (-1, 1):
			col = mix(col, (np.abs(a - sgn * 0.075) < 0.035) & (np.abs(y - 0.465) < 0.013) & fr, C("140a08"))
			col = mix(col, (np.abs(a - sgn * 0.13) < 0.03) & (y > 0.47) & (y < 0.6) & fr, C("4a3428"), 0.35)   # its sides
		col = mix(col, fr & (np.abs(a) < 0.06) & (y > 0.5) & (y < 0.62), C("e0c8a8"), 0.25)
	# the old face: sockets deep, bags under the eyes, a ridge of brow, lines across the forehead,
	# from the nose to the mouth, crow's feet; the cheekbones lit and hollow under them
	for sgn in (-1, 1):
		ax = sgn * ex
		d = np.sqrt(((a - ax) / 0.2) ** 2 + ((y - 0.6) / 0.05) ** 2)
		col = mix(col, (d < 1.0) & (y < 0.6) & ~(np.sqrt(((a - ax) / (0.13 * es)) ** 2 + ((y - ey) / (0.05 * es)) ** 2) < 1.1), C("4a3830"), 0.35)
		col = mix(col, (np.abs(y - (0.57 - np.abs(a - ax) * 0.1)) < 0.008) & (np.abs(a - ax) < 0.16) & fr, C("3a2a22"), 0.5)  # the bag's line
		for k2 in range(3):
			cf = (np.abs(y - (ey - 0.02 + k2 * 0.025) - (np.abs(a) - np.abs(ax) - 0.15) * 0.25 * (k2 - 1)) < 0.006) & (np.abs(a) > np.abs(ax) + 0.13) & (np.abs(a) < np.abs(ax) + 0.3) & (np.sign(a) == sgn)
			col = mix(col, cf & fr, C("3a2a22"), 0.45)
		cb = np.sqrt(((a - sgn * 0.62) / 0.2) ** 2 + ((y - 0.53) / 0.04) ** 2)
		col = mix(col, (cb < 1.0) & fr, C("d8c0a0"), 0.2)
		fold = fr & (np.abs(a - sgn * (0.2 + (0.47 - y) * 0.9)) < 0.018) & (y > line - 0.02) & (y < 0.47)
		col = mix(col, fold, C("3a2a22"), 0.55)
	col = mix(col, fr & (y > 0.69) & (y < 0.73) & (np.abs(a) < 0.7), C("e0c8a8"), 0.18)                # brow ridge, lit
	col = mix(col, fr & (y > 0.655) & (y < 0.68) & (np.abs(a) < 0.65), C("3a2c22"), 0.45)              # its shadow
	for k2 in range(p.get("wrinkles", 0)):
		yy = 0.78 + k2 * 0.04
		wl = fr & (np.abs(y - yy - 0.012 * np.sin(a * 6 + k2)) < 0.005) & (np.abs(a) < 0.55)
		col = mix(col, wl, C("4a3a2e"), 0.5)
	col = mix(col, fr & (np.abs(a) < 0.035) & (y > 0.62) & (y < 0.68) & (p.get("wrinkles", 0) > 0), C("3a2a22"), 0.4)  # the frown
	if p.get("cheeks", 0.0) < 0:
		for sgn in (-1, 1):
			d = np.sqrt(((a - sgn * 0.62) / 0.22) ** 2 + ((y - 0.42) / 0.08) ** 2)
			col = mix(col, smoothstep(1.2, 0.2, d), C("3a2c24"), 0.55)
	return col


def skin_base(P, base, var=0.12, seed=0):
	n1 = fbm(P, 9.0, 3, seed)
	n2 = fbm(P, 30.0, 2, seed + 40)
	return base * (1.0 + var * n1[..., None] * np.array([0.7, 0.1, -0.4]) + 0.07 * n2[..., None])


def nails(part, s, col, c):
	if part.startswith("finger") or part.startswith("thumb"):
		col = mix(col, s > 0.72, c)
	if part.startswith("foot"):
		col = mix(col, s > 0.9, c, 0.7)
	return col


def ao(part, P, N, s, col, L):
	"""Shadow where body meets body: the crotch, the armpits, under the chin, the top of the limbs."""
	if part.startswith("leg") or part.startswith("arm"):
		col = col * (0.7 + 0.3 * smoothstep(0.0, 0.25, s))[..., None]
	if part == "trunk":
		y = P[..., 1]
		col = col * (0.7 + 0.3 * smoothstep(L["hips"][1] - 0.06, L["hips"][1] + 0.04, y))[..., None]
		col = col * (0.75 + 0.25 * smoothstep(L["neck"][1] + 0.06, L["neck"][1] - 0.02, y))[..., None]
	if part == "head":
		y = (P[..., 1] - L["head"][1]) / L["hs"]
		col = col * (0.6 + 0.4 * smoothstep(0.05, 0.22, y))[..., None]
	return col


def body_hair(P, mask, col, c, density=160.0, seed=4):
	speck = smoothstep(0.34, 0.14, cells(P, density, seed))
	return mix(col, mask * speck, c, 0.85)


# ------------------------------------------------------------------ the cast
def super_():
	"""Gennady Vorobyov. Tall, starved-thin, stooped, naked and wet. Every rib; the collarbones
	like handles; the belly sucked in under them and the skin there gone loose; knees and elbows
	wider than the limbs. A long neck, a wattle; a big bald head, liver-spotted, a few strands
	combed over; small wet eyes sunk under the brow; a wide mouth with too few yellow teeth, hanging
	open. Long yellow nails. Nothing sexual: a body, and that's the horror."""
	M = Model("super")
	p = dict(height=1.84, girth=0.86, shoulders=1.05, chest=0.95, waist=0.72, hips=0.85, sunken=0.03, stoop=0.25, butt=0.2,
		thigh=0.7, calf=0.75, knees=1.25, ankle=1.0, arm=1.05, upper=0.7, fore=0.75, elbows=1.25, neck=0.85, neckw=0.75, wattle=True,
		head=1.15, headw=0.92, jaww=0.72, jawf=0.35, nose=1.5, cheeks=-0.03, brow=1.8, mouth=1.3, lip=0.035, droop=1.6, wrinkles=4, fingers=1.5, hand=1.1, foot=1.1,
		ears=1.4, eyes="normal", eye_size=0.7, sockets=0.8, sclera=C("b8a878"), iris=C("4a3a1c"), lid_col=C("5e4a3c"), teeth=9,
		missing=0.5, teeth_col=C("a89050"), lip_col=C("5e3c3c"), seed=1993, slide_eye=-0.03, spread=0.08)
	L = figure(M, p)
	skin = C("9a8a70")

	def paint(P, N, part, th, s, M_):
		y = P[..., 1]
		x = P[..., 0]
		col = skin_base(P, np.broadcast_to(skin, P.shape).copy(), 0.25, 11)
		col = mix(col, smoothstep(-0.2, 0.7, fbm(P, 4.0, 2, 31)), C("8c8c80"), 0.3)    # grey under the yellow
		front = -N[..., 2]
		if part == "trunk":
			ch, sp, hp = L["chest"][1], L["spine"][1], L["hips"][1]
			# the ribs: shadow between each, down the sides and front
			rib = (y > sp + 0.12) & (y < ch + 0.2)
			band = 0.5 + 0.5 * np.cos((y - ch) * 2 * np.pi / 0.042 + np.abs(x) * 18.0)
			col = mix(col, rib * smoothstep(0.55, 0.95, band) * smoothstep(0.02, 0.06, np.abs(x)), C("4a3a2c"), 0.6)
			col = mix(col, rib * smoothstep(0.1, 0.0, band), C("c4b494"), 0.25)
			# the sternum, the collarbones, the hollow above them
			col = mix(col, (np.abs(x) < 0.012) & (y > ch - 0.05) & (y < ch + 0.26) & (front > 0.5), C("4a3a2c"), 0.45)
			cb = (np.abs(y - (ch + 0.27 - np.abs(x) * 0.15)) < 0.012) & (np.abs(x) > 0.02) & (front > 0.3)
			col = mix(col, cb, C("c8b898"), 0.5)
			col = mix(col, (np.abs(y - (ch + 0.25 - np.abs(x) * 0.15)) < 0.012) & (np.abs(x) > 0.02) & (front > 0.3), C("3a2c22"), 0.5)
			# the gut sucked in, the loose skin folding over itself below it
			gut = (y > sp - 0.02) & (y < sp + 0.12) & (front > 0.2)
			col = mix(col, gut & (np.abs(np.sin((y - sp) * 160.0 + x * 6)) < 0.25), C("5a4636"), 0.5)
			col = mix(col, (np.abs(y - (sp + 0.0)) < 0.012) & (front > 0.3) & (np.abs(x) < 0.12), C("3a2a20"), 0.6)
			# the hip bones standing out
			for sgn in (-1, 1):
				d = np.sqrt(((x - sgn * 0.1) / 0.03) ** 2 + ((y - (hp + 0.07)) / 0.04) ** 2)
				col = mix(col, smoothstep(1.2, 0.5, d) * (front > 0.2), C("c4b494"), 0.4)
				col = mix(col, smoothstep(1.6, 1.2, d) * (front > 0.2), C("4a3a2c"), 0.3)
				nip = np.sqrt((x - sgn * 0.085) ** 2 + (y - (ch + 0.0)) ** 2) < 0.012
				col = mix(col, nip & (front > 0.4), C("5a3a36"), 0.9)
			# the shoulder blades and the spine knuckles behind
			col = mix(col, (np.abs(x) < 0.01) & (front < -0.6) & (np.abs(np.sin(y * 150)) > 0.6), C("c4b494"), 0.4)
			col = mix(col, (front < -0.3) & (np.abs(np.abs(x) - 0.09) < 0.04) & (y > ch + 0.08) & (y < ch + 0.22), C("4a3a2c"), 0.25)
			# hair: sparse grey on the chest, a line down the gut, the dark mat at the crotch
			hair = smoothstep(0.08, 0.02, np.abs(x)) * (y > ch - 0.04) * (y < ch + 0.15) * (front > 0.2)
			hair = hair + smoothstep(0.02, 0.0, np.abs(x)) * (y > hp + 0.03) * (y < sp + 0.12) * (front > 0.4)
			col = body_hair(P, hair, col, C("3a3530"))
			crotch = (y < hp + 0.06) & (front > -0.1) & (np.abs(x) < 0.09)
			col = body_hair(P, crotch * 1.0, col, C("1e1a16"), 240.0)
			col = mix(col, (y < hp - 0.02) & (front > -0.1) & (np.abs(x) < 0.07), C("2a2018"), 0.55)
			# sores on the back, the shoulders
			so = cells(P, 9.0, 21)
			pick = vnoise(P, 4.0, 22) > 0.4
			col = mix(col, smoothstep(0.17, 0.1, so) * pick, C("6e1a16"), 0.9)
			col = mix(col, smoothstep(0.07, 0.03, so) * pick, C("a08a36"), 0.9)
		if part == "head":
			hs = L["hs"]
			hy = (y - L["head"][1]) / hs
			# bald: a dome of liver spots, stubble round the back and sides, three strands combed over
			sp = cells(P, 30.0, 5)
			col = mix(col, smoothstep(0.3, 0.15, sp) * (hy > 0.7), C("6a4a2c"), 0.8)
			col = mix(col, (hy > 0.55) & (hy < 0.85) & (np.cos(th) < 0.2), C("4a4038"), 0.45)
			comb = (hy > 0.85) & (np.abs(np.sin(hy * 26.0 + th * 0.8)) < 0.12)
			col = mix(col, comb, C("201a14"), 0.9)
			col = face(P, N, th, s, M_, L, p, col)
			# the face slides: the left side heavier, a weeping sore at the corner of the mouth
			col = mix(col, (np.sqrt(((th - 0.62) / 0.06) ** 2 + ((hy - 0.32) / 0.03) ** 2) < 1), C("7a1a14"), 0.9)
			col = mix(col, (hy < 0.25) & (np.cos(th) > 0.3), C("5a4436"), 0.3)        # stubble on the chin
			col = body_hair(P, ((hy < 0.3) & (np.cos(th) > 0.0)) * 1.0, col, C("3a3530"), 300.0)
		if part.startswith("leg"):
			# veins, the knees bruised, shins shiny
			vein = smoothstep(0.035, 0.0, np.abs(vnoise(P * np.array([1.6, 0.4, 1.6]), 14.0, 13)))
			col = mix(col, vein, C("3e3a5a"), 0.6)
			kn = L["kn_l"][1]
			col = mix(col, np.abs(y - kn) < 0.05, C("7a5a50"), 0.4)
			col = mix(col, (y < kn - 0.1) & (fbm(P, 9.0, 2, 30) > 0.2), C("5a3e40"), 0.5)
		if part.startswith("arm"):
			vein = smoothstep(0.03, 0.0, np.abs(vnoise(P * np.array([0.5, 1.6, 0.5]), 18.0, 14)))
			col = mix(col, vein * (y < L["el_l"][1] + 0.05), C("3e3a5a"), 0.5)
			col = mix(col, smoothstep(L["wr_l"][1] + 0.12, L["wr_l"][1] - 0.02, y), C("4a3a26"), 0.55)   # grime
		if part.startswith("finger") or part.startswith("thumb"):
			col = mix(col, np.ones(s.shape), C("5a4a32"), 0.35)
		if part.startswith("foot"):
			col = mix(col, np.ones(s.shape), C("3a3020"), 0.6)
		col = nails(part, s, col, C("8f7a3e"))
		return ao(part, P, N, s, col, L)
	M.paint = paint
	return M


def plain(name, p, skin, extra=None, seed=0):
	"""A body painted plainly (skin, face, clothes), plus whatever `extra` adds."""
	M = Model(name)
	L = figure(M, p)

	def paint(P, N, part, th, s, M_):
		y = P[..., 1]
		x = P[..., 0]
		col = skin_base(P, np.broadcast_to(skin, P.shape).copy(), p.get("mottle", 0.15), seed)
		front = -N[..., 2]
		dress = p.get("dress_col")
		if dress is not None and part in ("trunk", "skirt") or (dress is not None and part.startswith("arm") and y.mean() > L["el_l"][1]):
			cm = np.ones(y.shape, bool)
			if part.startswith("arm"):
				cm = y > L["el_l"][1] + 0.04
			if part == "trunk":
				cm = y < L["neck"][1] - 0.01
			cloth = dress * (0.9 + 0.1 * vnoise(P, 40.0, seed)[..., None])
			cloth = mix(cloth, fbm(P, 6.0, 3, seed + 3) > 0.3, C("3a2e24"), 0.4)               # stains
			cloth = mix(cloth, np.abs(np.sin(x * 60.0 + y * 4)) < 0.15, dress * 0.6, 0.6)        # folds
			col = np.where(cm[..., None], cloth, col)
		ap = p.get("apron_col")
		if ap is not None and part in ("trunk", "skirt"):
			am = (front > 0.2) & (np.abs(x) < 0.15 * L["gw"] + 0.03) & (y < L["chest"][1] + p.get("apron_top", 0.12))
			cloth = ap * (0.9 + 0.1 * vnoise(P, 40.0, seed)[..., None])
			col = np.where(am[..., None], cloth, col)
			strap = (np.abs(np.abs(x) - 0.07) < 0.012) & (y > L["chest"][1] + 0.1) & (front > 0.1)
			col = mix(col, strap, ap * 0.85)
		if part == "head":
			hy = (y - L["head"][1]) / L["hs"]
			if p.get("hair"):
				col = mix(col, (hy > 0.78) | ((hy > 0.4) & (np.cos(th) < -0.1)), p["hair_col"])
				col = mix(col, (hy > 0.78) & (np.abs(np.sin(th * 18.0)) < 0.3), p["hair_col"] * 0.7)
			col = face(P, N, th, s, M_, L, p, col)
		if part == "hair":
			col = p["hair_col"] * (0.75 + 0.25 * np.abs(np.sin(th * 23.0 + vnoise(P, 20.0, 3) * 2))[..., None])
		if extra:
			col = extra(P, N, part, th, s, L, col)
		col = nails(part, s, col, p.get("nail", C("8a7a60")))
		return ao(part, P, N, s, col, L)
	M.paint = paint
	return M, L


def hunter():
	p = dict(height=2.05, girth=1.35, shoulders=1.35, chest=1.25, waist=1.0, hips=0.95, arm=1.45, upper=1.4, fore=1.3, thigh=1.1, calf=1.1,
		head=0.75, headw=1.15, neck=0.6, neckw=1.4, mouth=1.9, lip=0.12, teeth=12, teeth_col=C("c8b888"), eyes="many", eye_count=11, eye_size=0.55,
		nose=0.0, ears=0.0, fingers=1.6, hand=1.4, stoop=0.6, jawf=0.8, seed=4, mottle=0.3, lip_col=C("6a3030"), sockets=0.9)

	def extra(P, N, part, th, s, L, col):
		gr = cells(P, 6.0, 12)
		col = mix(col, smoothstep(0.25, 0.1, gr), C("c48a7a"), 0.7)         # growths, raw
		col = mix(col, smoothstep(0.1, 0.04, gr), C("6a2a26"), 0.8)
		col = mix(col, fbm(P, 20.0, 2, 8) > 0.35, C("8a6a62"), 0.4)
		return col
	return plain("hunter", p, C("ae9686"), extra, 2)[0]


def listener():
	p = dict(height=1.85, girth=0.72, shoulders=0.9, chest=0.85, waist=0.7, hips=0.8, thigh=0.7, calf=0.7, knees=1.2, upper=0.7, fore=0.7, elbows=1.2,
		neck=2.4, neckw=0.7, head=1.25, headw=0.92, eyes="none", mouth=1.2, lip=0.03, teeth=14, teeth_col=C("d0c8b0"), nose=0.3, ears=3.0,
		fingers=1.8, arm=1.2, seed=9, mottle=0.08, lip_col=C("9a7a78"))

	def extra(P, N, part, th, s, L, col):
		vein = smoothstep(0.03, 0.0, np.abs(vnoise(P * np.array([1.5, 0.5, 1.5]), 12.0, 1)))
		col = mix(col, vein, C("6a7a9a"), 0.45)
		if part.startswith("ear"):
			col = mix(col, s > 0.3, C("c08a84"), 0.6)
		return col
	return plain("listener", p, C("d8cac2"), extra, 5)[0]


def laundress():
	p = dict(height=1.98, girth=0.8, shoulders=0.85, waist=0.8, arm=1.35, upper=0.7, fore=0.7, neck=1.7, neckw=0.7, head=0.85, eyes="sewn", mouth=0.7,
		fingers=1.5, skirt=0.85, hair=0.55, hair_col=C("8a8a84"), dress_col=C("4e4650"), apron_col=C("8a8a7c"), seed=2, lip_col=C("8a6a68"), stoop=0.3)

	def extra(P, N, part, th, s, L, col):
		if part.startswith("finger") or part.startswith("thumb") or (part.startswith("arm") and True):
			hand = (P[..., 1] < L["wr_l"][1] + 0.05)
			col = mix(col, hand, C("a0524a"), 0.55)     # raw from the water
		return col
	return plain("laundress", p, C("cdb9a6"), extra, 3)[0]


def caretaker():
	p = dict(height=1.62, girth=0.95, stoop=0.6, eyes="sewn", mouth=0.6, skirt=0.92, hair=0.35, hair_col=C("261a1a"), dress_col=C("2a1c20"),
		seed=5, lip_col=C("8a6a6a"), fingers=1.1)

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		front = -N[..., 2]
		blood = (fbm(P, 9.0, 2, 14) > 0.25) & (front > 0.4) & (y < L["chest"][1])
		blood |= (y < L["wr_l"][1] + 0.06) & (part.startswith("arm") | part.startswith("finger") | part.startswith("thumb"))
		col = mix(col, blood, C("4a0a0a"), 0.75)
		gr = cells(P, 14.0, 3)
		col = mix(col, smoothstep(0.2, 0.08, gr) * (part == "head") * ((y - L["head"][1]) < 0.1), C("b49088"), 0.8)
		return col
	return plain("caretaker", p, C("c9afa9"), extra, 6)[0]


def cook():
	p = dict(height=1.8, girth=1.2, belly=0.9, chest=1.1, waist=1.15, hips=1.05, upper=1.25, fore=1.2, thigh=1.1, calf=1.0, mouth=1.4, lip=0.02,
		teeth=10, fingers=1.3, hand=1.15, head=0.92, headw=1.1, neckw=1.6, neck=0.6, apron_col=C("a89c8e"), apron_top=0.25, seed=6, lip_col=C("8a5a52"),
		jawf=0.3, nose=1.2)

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		front = -N[..., 2]
		smear = (fbm(P * np.array([2.5, 0.6, 2.5]), 8.0, 3, 15) > 0.25) & (front > 0.2) & (part == "trunk")
		hands = (y < L["el_r"][1]) & (part.startswith("arm") | part.startswith("finger") | part.startswith("thumb")) & (fbm(P, 14.0, 2, 16) > -0.3)
		col = mix(col, smear | hands, C("3a0806"), 0.6)
		return col
	return plain("cook", p, C("c8af96"), extra, 7)[0]


def rearranger():
	p = dict(height=1.5, girth=1.3, belly=0.5, waist=1.15, extra_joint=True, dress_col=C("454a5e"), skirt=0.7, hair=0.2, hair_col=C("4a4038"),
		seed=8, mouth=1.0, lip_col=C("9a7a70"), stoop=0.3)
	return plain("rearranger", p, C("c9b39f"), None, 8)[0]


def crawler():
	p = dict(height=1.0, girth=0.75, shoulders=0.9, chest=0.85, waist=0.65, hips=0.75, thigh=0.6, calf=0.6, knees=1.4, upper=0.6, fore=0.6, elbows=1.4,
		arm=1.7, extra_joint=True, eyes="many", eye_count=8, eye_size=0.6, mouth=1.6, lip=0.1, teeth=12, teeth_col=C("c0b090"), nose=0.0, ears=0.0,
		neck=0.6, head=1.1, fingers=1.7, foot=1.4, seed=10, mottle=0.2, sockets=0.9, lip_col=C("5a3a46"))

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		x = P[..., 0]
		if part == "trunk":
			band = 0.5 + 0.5 * np.cos((y - L["chest"][1]) * 2 * np.pi / 0.03)
			rib = (y > L["spine"][1] + 0.05) & (y < L["chest"][1] + 0.12)
			col = mix(col, rib * smoothstep(0.6, 0.95, band), C("3a2a34"), 0.6)
		col = mix(col, fbm(P, 11.0, 3, 19) > 0.25, C("2a2420"), 0.5)
		return col
	return plain("crawler", p, C("b4a8b2"), extra, 9)[0]


CAST = {"super": super_, "hunter": hunter, "listener": listener, "laundress": laundress, "caretaker": caretaker, "cook": cook,
	"rearranger": rearranger, "crawler": crawler}

if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	for name in sys.argv[1:] or list(CAST):
		M = CAST[name]()
		M.build()
		M.write(os.path.join(OUT, name + ".glb"), os.path.join(OUT, name + ".png"))
