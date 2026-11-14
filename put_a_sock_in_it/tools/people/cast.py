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
	if style in ("normal", "sewn", "pits"):
		spots = [(ex, ey, 1.0), (-ex, ey + p.get("slide_eye", 0.0), 1.0)]
	elif style == "many":
		rng = np.random.default_rng(7)
		spots = [(rng.uniform(-1.0, 1.0), rng.uniform(0.45, 0.95), rng.uniform(0.6, 1.1)) for _ in range(p.get("eye_count", 9))]
	sock = p.get("sockets", 0.5)
	for (axx, ayy, sz) in spots:
		dx = (a - axx) / (0.13 * es * sz)
		dy = (y - ayy) / (0.05 * es * sz)
		d = np.sqrt(dx * dx + dy * dy)
		col = mix(col, smoothstep(3.0, 1.0, d), C("1e120c"), sock)         # the socket's shadow
		if style == "pits" or (style == "many" and p.get("pits")):
			# a hole: black, deep, one wet glint far down it
			col = mix(col, d < 1.15, C("070303"))
			col = mix(col, (d > 0.9) & (d < 1.3), C("2a1410"), 0.7)
			col = mix(col, np.sqrt((dx + 0.25) ** 2 + (dy - 0.25) ** 2) < 0.18, C("c8c0a8"), 0.8)
			continue
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
	fs = p.get("face_style", "slit")
	if fs == "slit":
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
		if p.get("lipless"):
			gum = fr & (np.abs(u) < 1.05) & (np.abs(y - line) < half + 0.035) & ~inside
			col = mix(col, gum, C("5a2420"), 0.85)
			col = mix(col, gum & (np.abs(np.sin(a * 40)) < 0.4) & (np.abs(y - line) > half + 0.012), C("2a0c0a"), 0.5)
		lipc = p.get("lip_col", C("7a5050"))
		near = fr & (np.abs(u) < 1.12) & ~inside & (not p.get("mask"))
		col = mix(col, near & (y > line) & (y < line + half + 0.03), lipc, 0.55)
		col = mix(col, near & (y < line) & (y > line - half - 0.04), lipc, 0.65)
		col = mix(col, near & (y < line - half - 0.04) & (y > line - half - 0.08), C("3a2a22"), 0.35)   # under the lip
		if not p.get("mask"):
			col = mix(col, fr & (np.abs(u) > 0.95) & (np.abs(u) < 1.25) & (np.abs(y - line) < 0.02), C("2a1c16"), 0.6)  # the corners
	if fs == "split":
		seam = (np.abs(a) < 0.075) & (y > 0.12) & (y < 0.98)
		col = mix(col, seam, C("1a0504"))
		col = mix(col, (np.abs(a) < 0.035) & (y > 0.12) & (y < 0.98), C("4a0c08"), 0.8)       # wet, red, deep in
		col = mix(col, (np.abs(a) > 0.075) & (np.abs(a) < 0.16) & (y > 0.1) & (y < 1.0), C("3a2418"), 0.5)
	if fs == "maw":
		cy, rad = p.get("maw_y", 0.38), p.get("maw_r", 0.16)
		d = np.sqrt((a / (rad * 2.2)) ** 2 + ((y - cy) / rad) ** 2)
		col = mix(col, d < 1.0, C("2a0806"))
		col = mix(col, (d < 0.75) & (np.abs(np.sin(np.arctan2(y - cy, a) * 12.0)) < 0.35) & (d > 0.45), C("a8945c"), 0.85)  # rings of teeth going down
		col = mix(col, (d < 0.4) & (np.abs(np.sin(np.arctan2(y - cy, a) * 9.0 + 0.5)) < 0.3) & (d > 0.2), C("8a7448"), 0.7)
		col = mix(col, d < 0.18, C("050101"))
		col = mix(col, (d > 1.0) & (d < 1.35), C("5a2018"), 0.6)
	if fs == "vmouth":
		v = (np.abs(a) < 0.06 * (1 - ((y - 0.55) / 0.42) ** 2).clip(0, 1) ** 0.5 + 0.005) & (y > 0.13) & (y < 0.97)
		col = mix(col, v, C("1a0504"))
		edge = (~v) & (np.abs(a) < 0.11) & (y > 0.15) & (y < 0.95)
		col = mix(col, edge & (np.abs(np.sin(y * 70.0)) < 0.45), C("b09a60"), 0.85)
	if fs == "pores":
		pc = cells(P, 55.0, 31)
		fm = fr & (y > 0.15) & (y < 1.0)
		col = mix(col, fm, C("8a6a52"), 0.6)
		col = mix(col, fm * smoothstep(0.48, 0.32, pc), C("a85a44"), 0.85)
		col = mix(col, fm * smoothstep(0.3, 0.18, pc), C("080202"))
	# nose: nostrils, the shadow under it, the bridge
	n = p.get("nose", 1.0)
	if n > 0:
		col = mix(col, fr & (np.abs(a) < 0.17) & (y > 0.43) & (y < 0.47), C("3a2620"), 0.6)
		for sgn in (-1, 1):
			col = mix(col, (np.abs(a - sgn * 0.075) < 0.035) & (np.abs(y - 0.465) < 0.013) & fr, C("140a08"))
			col = mix(col, (np.abs(a - sgn * 0.13) < 0.03) & (y > 0.47) & (y < 0.6) & fr, C("4a3428"), 0.35)   # its sides
		col = mix(col, fr & (np.abs(a) < 0.06) & (y > 0.5) & (y < 0.62), C("e0c8a8"), 0.25)
	if p.get("mask"):
		# a faceplate: a seam down the middle, a ridge across the brow, nothing human
		col = mix(col, fr & (np.abs(a) < 0.012) & (y > 0.68), C("2a1a12"), 0.6)
		col = mix(col, fr & (np.abs(y - 0.72) < 0.012) & (np.abs(a) < 0.55), C("2a1a12"), 0.5)
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
# ------------------------------------------------------------------ the cast (biomechanical)
import biomech as B  # noqa: E402


def bio(name, p, skin, build=None, extra=None, seed=0, gloss=0.5):
	"""A body (figure()), then what's grown into it (`build`), painted: flesh or gristle for the
	body, bone for the ridges and ribs and carapace, hose for the hoses, coral for the coral, the
	ribbed grooves dark and wet, grime, seeping; then `extra`."""
	# faces are masks of bone, not people's faces: no noses, no lips, no wrinkles or grimaces
	p = dict(p)
	p.update(nose=0.0, wrinkles=0, cheeks=0.0, droop=0.0, brow=1.0, jawf=0.0, lip_col=p.get("lip_col", C("2a120e")), mask=True)
	M = Model(name)
	L = figure(M, p)
	rng = np.random.default_rng(seed + 100)
	if build:
		build(M, L, p, rng)
	B.face_hoses(M, L, p.get("face_hose", 0.011), p.get("face_hoses", 1))
	if p.get("crest", True):
		B.crest(M, L, 0.012 * L["k"] ** 0.5)
	if p.get("temples", True):
		B.temples(M, L, 0.009 * L["k"] ** 0.5)
	if p.get("back_plates", True) and not p.get("skirt"):
		B.plates(M, L, "back", p.get("back_n", 5), width=0.08, thick=0.01, out=1.0)
	if p.get("belly_plates"):
		B.plates(M, L, "front", p["belly_plates"], width=0.1, thick=0.011, out=1.0 + p.get("belly", 0.0) * 0.6)
	# hoses plugged from the back into the shoulders/neck: the building feeding them
	sp, ch, k, gw = L["spine"], L["chest"], L["k"], L["gw"]
	for s in (-1, 1):
		B.plug(M, sp + F(s * 0.06 * gw * k, 0.12 * k, -0.1 * gw * k), (s * 0.3, 0, 1.0), "spine",
			ch + F(s * 0.14 * gw * k, 0.24 * k, -0.07 * gw * k), (s * 0.4, 0.6, 1.0), "chest", 0.012 * k ** 0.5, 0.08)

	def paint(P, N, part, th, s, M_):
		y = P[..., 1]
		gl = gloss
		if part.startswith("coral") or part.startswith("fan"):
			col = B.coral_paint(P, s, np.zeros(P.shape))
			return col, 0.05
		if part.startswith("hose"):
			col = B.HOSE * (0.85 + 0.15 * vnoise(P, 30.0, seed)[..., None])
			col = B.grooves(M_, col, C("120a08"), 0.85)
			col = B.seep(P, N, col, 0.3, seed + 4)
			return col, 0.75
		if part.startswith("port"):
			col = B.BONE * 0.7
			col = mix(col, M_.dark, C("0a0404"), 0.95)
			return B.grime(P, col, 0.3, seed), 0.6
		if part.startswith("tooth"):
			col = mix(np.broadcast_to(C("b8a46a"), P.shape).copy(), smoothstep(0.35, 0.0, s), C("3a0c08"), 0.9)
			return col, 0.7
		if part.startswith("mawring") or part.startswith("seamlip"):
			col = mix(np.broadcast_to(C("6a3a2c"), P.shape).copy(), smoothstep(0.2, 0.7, fbm(P, 30.0, 2, seed)), C("3a1a12"), 0.6)
			return col, 0.8
		if part.startswith("vert") or part.startswith("rib_") or part.startswith("plate") or part.startswith("mandible") or part.startswith("cage") or part.startswith("stitch"):
			col = B.BONE * (0.85 + 0.15 * vnoise(P, 25.0, seed)[..., None])
			col = B.grooves(M_, col, C("2a1a12"), 0.8)
			return B.grime(P, col, 0.3, seed), 0.35
		if part in ("skirt", "hair"):
			col = p.get("shell", B.BONE * 0.8) * (0.85 + 0.15 * vnoise(P, 25.0, seed)[..., None])
			col = B.grooves(M_, col, C("1a100c"), 0.85)
			col = B.grime(P, col, 0.4, seed)
			col = B.seep(P, N, col, 0.4, seed + 2)
			return col, 0.45
		col = skin_base(P, np.broadcast_to(skin, P.shape).copy(), p.get("mottle", 0.18), seed)
		col = B.grooves(M_, col, B.CAVITY, 0.8)
		if part == "head":
			gl = gloss * 0.45
			hy = (y - L["head"][1]) / L["hs"]
			# the mask: darker than the body, stained down from the crown, pitted like coral round the edges
			col = col * 0.78
			col = mix(col, smoothstep(0.2, 0.6, fbm(P * np.array([2.0, 0.5, 2.0]), 10.0, 2, seed + 20)), C("3a2618"), 0.45)
			col = mix(col, smoothstep(0.3, 0.16, cells(P, 70.0, seed + 21)) * (np.cos(th) < 0.5), C("2a1a12"), 0.5)
			if p.get("brain"):
				col = B.brain_coral(P, ((hy > 0.8) & (np.cos(th) < 0.1)) * 1.0, col, 16.0, seed)
			col = face(P, N, th, s, M_, L, p, col)
		if part == "trunk" and p.get("sunken"):
			# the cavity behind the ribs
			ch, sp = L["chest"][1], L["spine"][1]
			cav = (y > sp + 0.1) & (y < ch + 0.2) & (-N[..., 2] > -0.2)
			col = mix(col, cav, B.CAVITY, 0.55)
		col = B.veins(P, col, p.get("veins", 0.5), seed)
		col = B.grime(P, col, 0.3, seed)
		col = B.seep(P, N, col, 0.35, seed + 1)
		if extra:
			col = extra(P, N, part, th, s, L, col)
		col = nails(part, s, col, p.get("nail", C("7a6a40")))
		return ao(part, P, N, s, col, L), gl
	M.paint = paint
	return M


def _shoulder_coral(M, L, side, rng, n=3, size=0.2, r=0.025, depth=3):
	sh = L["sh_" + side]
	sgn = -1 if side == "l" else 1
	for i in range(n):
		d = np.array([sgn * 0.6, 1.0, rng.uniform(-0.3, 0.6)]) + rng.normal(0, 0.25, 3)
		B.coral(M, sh + F(sgn * 0.0, 0.03, -0.03 - i * 0.02), d, "chest" if i % 2 else "sh_" + side, size * rng.uniform(0.7, 1.1), r, depth, 0.65, rng)


def super_():
	"""Gennady Vorobyov. Starved-thin, stooped, wet; the building has grown into him. His ribs
	stand outside him, the chest sunk in behind them; vertebrae stand out of his back and run up
	into a skull drawn long and back, crusted in brain coral; a hose from the base of the skull
	feeds into his back; coral has broken out of his left shoulder. Small wet eyes, a lipless
	mouth full of yellow teeth hanging open. Long yellow nails."""
	p = dict(face_style="split", belly_plates=4, height=1.84, girth=0.86, shoulders=1.05, chest=0.9, waist=0.66, hips=0.85, sunken=0.045, stoop=0.25, butt=0.2,
		thigh=0.7, calf=0.75, knees=1.3, ankle=1.0, arm=1.08, upper=0.68, fore=0.72, elbows=1.3, neck=0.9, neckw=0.72,
		head=1.12, headw=0.9, jaww=0.78, mouth=1.1, lip=0.03,
		fingers=1.6, hand=1.1, foot=1.1, ears=0.0, eyes="pits", eye_size=0.65, sockets=0.95, teeth=13, missing=0.3, teeth_col=C("b09a58"), lip_col=C("3a1a14"), seed=1993,
		spread=0.08, brain=True, mottle=0.25)

	def build(M, L, p, rng):
		B.elongate(M, L, 0.55)
		B.cable_limbs(M, rng, 2, 0.006)
		B.spine_ridge(M, L, 0.018, True, 0.55)
		B.rib_hoops(M, L, 6, 0.007, 1.18)
		B.hose(M, L["head"] + F(0.03, L["hs"] * 0.3, -L["hs"] * 0.35), L["chest"] + F(0.05, 0.1, -0.08), ("head", "chest"), 0.016, 0.12, (0.3, 0.2, 1.0))
		_shoulder_coral(M, L, "l", rng, 3, 0.2, 0.028, 3)
		B.crust(M, L["sh_l"] + F(0.02, -0.02, 0.0), (-1.0, 0.3, 0.2), "sh_l", rng, 7, 0.05, 0.013)
		B.crust(M, L["head"] + F(-0.04, L["hs"] * 0.9, -L["hs"] * 0.45), (-0.3, 0.6, -1.0), "head", rng, 5, 0.03, 0.009)
		B.coral(M, L["hips"] + F(0.1, 0.06, -0.03), (1.0, 0.4, 0.3), "hips", 0.12, 0.016, 2, 0.6, rng)
		B.crust(M, L["kn_r"] + F(0.03, 0.02, 0.0), (1.0, 0.2, 0.4), "kn_r", rng, 6, 0.035, 0.01)
		B.crust(M, L["el_l"] + F(-0.02, -0.04, 0.0), (-1.0, 0.0, 0.3), "el_l", rng, 6, 0.035, 0.01)
		B.plug(M, L["chest"] + F(-0.04, 0.0, 0.07), (0, 0.2, 1.0), "chest", L["spine"] + F(0.05, 0.02, 0.06), (0.3, -0.3, 1.0), "spine", 0.01, 0.06)
		B.split_face(M, L, 9, rng)
		B.mandibles(M, L, 0.11, 0.012, 0.4, 4, rng)

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		if part.startswith("leg"):
			vein = smoothstep(0.035, 0.0, np.abs(vnoise(P * np.array([1.6, 0.4, 1.6]), 14.0, 13)))
			col = mix(col, vein, C("3a3050"), 0.55)
		if part == "trunk":
			hp = L["hips"][1]
			col = body_hair(P, ((y < hp + 0.06) & (-N[..., 2] > -0.1) & (np.abs(P[..., 0]) < 0.09)) * 1.0, col, C("1a1410"), 240.0)
			so = cells(P, 9.0, 21)
			pick = vnoise(P, 4.0, 22) > 0.4
			col = mix(col, smoothstep(0.17, 0.1, so) * pick, C("6e1a16"), 0.9)
		return col
	return bio("super", p, C("8a7656"), build, extra, 11, 0.55)


def hunter():
	p = dict(face_style="maw", maw_y=0.42, maw_r=0.17, belly_plates=6, back_n=7, height=2.05, girth=1.3, shoulders=1.35, chest=1.2, waist=0.9, hips=0.95, arm=1.45, upper=1.25, fore=1.2, thigh=1.05, calf=1.0,
		head=0.85, headw=1.0, neck=0.7, neckw=1.3, mouth=1.9, lip=0.12, teeth=18, teeth_col=C("c8b888"), eyes="many", pits=True, eye_count=8, eye_size=0.5,
		nose=0.0, ears=0.0, fingers=1.7, hand=1.4, stoop=0.6, jawf=0.8, seed=4, mottle=0.2, lip_col=C("2a0c0a"), lipless=True, sockets=0.9, brain=True,
		shell=C("4a4440"))

	def build(M, L, p, rng):
		B.cable_limbs(M, rng)
		B.elongate(M, L, 1.3)
		B.spine_ridge(M, L, 0.03, True, 0.6)
		B.rib_hoops(M, L, 7, 0.011, 1.06)
		for i in range(3):
			B.coral(M, L["sh_l"] + F(-0.05, 0.05, -0.05 * i), (-0.8, 1.0, rng.uniform(-0.5, 0.5)), "sh_l", 0.35, 0.045, 3, 0.55, rng)
		B.crust(M, L["neck"] + F(-0.06, 0.02, -0.06), (-0.5, 0.5, 1.0), "neck", rng, 10, 0.07, 0.016)
		B.maw(M, L, 0.42, 0.17, 16, rng)
		for side in ("l", "r"):
			_shoulder_coral(M, L, side, rng, 4, 0.26, 0.036, 3)
			B.crust(M, L["sh_" + side], ((-1.0 if side == "l" else 1.0), 0.6, 0.0), "sh_" + side, rng, 9, 0.07, 0.018)
			B.coral(M, L["el_" + side] + F(0, 0, -0.02), (0.3 * (1 if side == "r" else -1), 0.2, -1.0), "el_" + side, 0.14, 0.018, 2, 0.6, rng)
		for sx in (-1, 1):
			B.hose(M, L["jaw"] + F(sx * 0.05, -0.05, 0.05), L["chest"] + F(sx * 0.12, 0.05, 0.12), ("jaw", "chest"), 0.022, 0.1, (sx * 0.6, 0, 1.0))
	return bio("hunter", p, C("5a5048"), build, None, 2, 0.45)


def listener():
	p = dict(face_style="pores", belly_plates=5, height=1.85, girth=0.72, shoulders=0.9, chest=0.85, waist=0.68, hips=0.8, thigh=0.7, calf=0.7, knees=1.3, upper=0.66, fore=0.66, elbows=1.3,
		neck=2.4, neckw=0.62, head=1.15, headw=0.85, eyes="none", mouth=1.25, lip=0.04, lipless=True, teeth=20, teeth_col=C("d0c8b0"), ears=0.0,
		fingers=1.9, arm=1.2, seed=9, mottle=0.08, lip_col=C("3a1a14"), brain=True)

	def build(M, L, p, rng):
		B.ribbify(M.lofts[0], 45.0, 0.06)          # the trunk, and the long neck: segmented
		B.elongate(M, L, 0.9)
		B.spine_ridge(M, L, 0.016, True, 0.6)
		B.rib_hoops(M, L, 6, 0.006, 1.15)
		hs, head = L["hs"], L["head"]
		for s in (-1, 1):
			B.fan(M, head + F(s * hs * 0.36, hs * 0.6, -0.02), "head", up=(s * 0.35, 1.0, 0.2), side=(0.1 * s, 0.0, 1.0), size=hs * 1.1, ribs=7, name="fan")
		B.crust(M, L["neck"] + F(0, 0.15, -0.04), (0, 0.2, 1.0), "neck", rng, 6, 0.03, 0.01)
		for k in range(10):
			p_, n_ = B.on_face(M, L, rng.uniform(-0.7, 0.7), rng.uniform(0.25, 0.95), -0.005)
			B.coral(M, p_, n_ + rng.normal(0, 0.3, 3), "head", 0.025, 0.008, 1, 0.5, rng)
		B.cable_limbs(M, rng)
	return bio("listener", p, C("a89880"), build, None, 5, 0.4)


def laundress():
	p = dict(height=1.98, girth=0.78, shoulders=0.85, waist=0.72, arm=1.35, upper=0.65, fore=0.65, neck=1.6, neckw=0.6, head=0.9, eyes="pits", eye_size=0.8,
		mouth=0.7, fingers=1.6, skirt=0.88, seed=2, lip_col=C("3a2420"), stoop=0.3, shell=C("5e5048"), ears=0.0, sunken=0.02)

	def build(M, L, p, rng):
		for lf in M.lofts:
			if lf.name == "skirt":
				B.ribbify(lf, 18.0, 0.12)
		B.tendrils(M, L, 12, 0.6, 0.011, rng)
		B.cable_limbs(M, rng, 2, 0.005, arms_only=True)
		B.spine_ridge(M, L, 0.015, False, 0.5)
		B.coral(M, L["chest"] + F(-0.05, 0.12, -0.08), (-0.3, 0.6, 1.0), "chest", 0.16, 0.026, 3, 0.6, rng)
		B.crust(M, L["chest"] + F(0.04, 0.05, -0.09), (0.2, 0.2, -1.0), "chest", rng, 8, 0.05, 0.012)
		B.cage(M, L, 5, 0.25, 0.9, 0.04)

	def extra(P, N, part, th, s, L, col):
		if part.startswith("finger") or part.startswith("thumb") or part.startswith("arm"):
			col = mix(col, P[..., 1] < L["wr_l"][1] + 0.05, C("8a3a32"), 0.5)
		return col
	return bio("laundress", p, C("958470"), build, extra, 3, 0.4)


def caretaker():
	p = dict(height=1.62, girth=0.95, stoop=0.7, eyes="sewn", mouth=0.6, skirt=0.92, hair=0.35, seed=5, lip_col=C("4a2a28"), fingers=1.2,
		shell=C("4a3a34"))

	def build(M, L, p, rng):
		for lf in M.lofts:
			if lf.name in ("skirt", "hair"):
				B.ribbify(lf, 22.0, 0.14)
		for i in range(4):
			B.coral(M, L["chest"] + F(rng.uniform(-0.1, 0.1), rng.uniform(0.0, 0.18), -0.09), (rng.uniform(-0.6, 0.6), 0.8, 1.0), "chest", 0.2, 0.03, 3, 0.6, rng)
		B.crust(M, L["neck"] + F(0, 0.05, -0.05), (0, 0.3, 1.0), "neck", rng, 6, 0.04, 0.012)
		B.stitches(M, L, 0.63, 0.6, 8)
		B.socket_coral(M, L, rng)

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		blood = (y < L["wr_l"][1] + 0.06) & (part.startswith("arm") | part.startswith("finger") | part.startswith("thumb"))
		return mix(col, blood, C("3a0806"), 0.75)
	return bio("caretaker", p, C("96806e"), build, extra, 6, 0.4)


def cook():
	p = dict(face_style="slit", belly_plates=5, height=1.8, girth=1.2, belly=0.9, chest=1.1, waist=1.15, hips=1.05, upper=1.2, fore=1.15, thigh=1.1, calf=1.0, mouth=1.6, lip=0.06,
		lipless=True, teeth=16, fingers=1.3, hand=1.15, head=0.95, headw=1.05, neckw=1.5, neck=0.6, seed=6, lip_col=C("3a1410"),
		eyes="pits", eye_size=0.7, ears=0.0)

	def build(M, L, p, rng):
		B.ribbify(M.lofts[0], 30.0, 0.04)            # the body in rolls
		B.cable_limbs(M, rng, 3, 0.008, arms_only=True)
		B.rib_hoops(M, L, 4, 0.008, 1.12)
		B.hose(M, L["spine"] + F(0.06, 0.15, 0.28), L["jaw"] + F(0.04, -0.06, 0.07), ("belly", "jaw"), 0.025, 0.1, (0.6, 0, 1.0))
		for side in ("l", "r"):
			B.crust(M, L["el_" + side] + F(0, -0.1, 0), ((1 if side == "r" else -1) * 0.6, 0.0, 0.8), "el_" + side, rng, 8, 0.05, 0.014)
		B.elongate(M, L, 0.3)
		B.mandibles(M, L, 0.15, 0.017, 0.45, 6, rng)

	def extra(P, N, part, th, s, L, col):
		y = P[..., 1]
		front = -N[..., 2]
		smear = (fbm(P * np.array([2.5, 0.6, 2.5]), 8.0, 3, 15) > 0.2) & (front > 0.2) & (part == "trunk")
		hands = (y < L["el_r"][1]) & (part.startswith("arm") | part.startswith("finger") | part.startswith("thumb"))
		return mix(col, smear | hands, C("3a0806"), 0.65)
	return bio("cook", p, C("94785e"), build, extra, 7, 0.55)


def rearranger():
	p = dict(height=1.5, girth=1.3, belly=0.5, waist=1.15, extra_joint=True, skirt=0.7, seed=8, mouth=1.0, lip_col=C("4a2a24"), stoop=0.45,
		shell=C("5a4e44"), eyes="pits", eye_size=0.6, ears=0.0)

	def build(M, L, p, rng):
		B.cable_limbs(M, rng)
		for lf in M.lofts:
			if lf.name == "skirt":
				B.ribbify(lf, 16.0, 0.12)
		for i in range(6):
			B.coral(M, L["chest"] + F(rng.uniform(-0.15, 0.15), rng.uniform(-0.1, 0.2), -0.12), (rng.uniform(-0.7, 0.7), rng.uniform(0.2, 1.0), 1.0), "chest" if i % 2 else "spine", 0.22, 0.028, 3, 0.6, rng)
		B.crust(M, L["spine"] + F(0, 0.1, -0.12), (0, 0.3, 1.0), "spine", rng, 10, 0.1, 0.018)
		B.mouth_coral(M, L, rng, 8, 0.09)
		B.spine_ridge(M, L, 0.02, True, 0.5)
	return bio("rearranger", p, C("8e7c66"), build, None, 8, 0.4)


def crawler():
	p = dict(face_style="vmouth", belly_plates=4, height=1.0, girth=0.75, shoulders=0.9, chest=0.85, waist=0.6, hips=0.75, thigh=0.6, calf=0.6, knees=1.4, upper=0.6, fore=0.6, elbows=1.4,
		arm=1.7, extra_joint=True, eyes="many", pits=True, eye_count=9, eye_size=0.55, mouth=1.7, lip=0.12, lipless=True, teeth=16, teeth_col=C("c0b090"),
		nose=0.0, ears=0.0, neck=0.6, head=1.1, fingers=1.8, foot=1.4, seed=10, mottle=0.2, sockets=0.9, lip_col=C("2a0c0a"), sunken=0.04, brain=True)

	def build(M, L, p, rng):
		B.cable_limbs(M, rng)
		B.elongate(M, L, 1.1)
		B.spine_ridge(M, L, 0.014, True, 0.7)
		B.rib_hoops(M, L, 5, 0.006, 1.2)
		B.crust(M, L["head"] + F(0, L["hs"] * 0.95, -L["hs"] * 0.6), (0, 0.7, -1.0), "head", rng, 8, 0.04, 0.011)
		B.crust(M, L["chest"] + F(0, 0.08, -0.08), (0, 0.2, 1.0), "chest", rng, 6, 0.05, 0.012)
		for k in range(6):
			y = 0.2 + 0.7 * k / 6
			for s_ in (-1, 1):
				p_, n_ = B.on_face(M, L, s_ * 0.07, y, 0.0)
				B.fang(M, p_, F(-s_ * 1.0, 0.0, 0.5), "jaw" if y < 0.3 else "head", L["hs"] * 0.08, L["hs"] * 0.015)
	return bio("crawler", p, C("8a7c70"), build, None, 9, 0.5)


CAST = {"super": super_, "hunter": hunter, "listener": listener, "laundress": laundress, "caretaker": caretaker, "cook": cook,
	"rearranger": rearranger, "crawler": crawler}

if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	for name in sys.argv[1:] or list(CAST):
		M = CAST[name]()
		M.build()
		M.write(os.path.join(OUT, name + ".glb"), os.path.join(OUT, name + ".png"))
