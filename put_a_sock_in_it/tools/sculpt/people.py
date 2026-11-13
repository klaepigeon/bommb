"""The building's inhabitants, sculpted (docs/PEOPLE.md). Writes assets/people/<name>.glb.

	python3 tools/sculpt/people.py            # all of them
	python3 tools/sculpt/people.py super cook # some

Positions are Godot's: +y up, metres, and the body faces -z (forward). F(x, y, f) takes f as
"how far forward" and turns it into z, so a nose is F(0, 1.6, 0.1), not (0, 1.6, -0.1).
Every body starts from body() (the same numbers as FleshBody: height, girth, belly, arm, neck,
head, fingers, extra_joint, mouth, eyes), then gets what makes it itself.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from sculpt import Sculpt, cells, fbm, vnoise  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "people")


def F(x, y, f):
	return np.array([x, y, -f], float)


def C(hexs, mul=1.0):
	h = hexs.lstrip("#")
	return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]) * mul


def lerp(a, b, t):
	return a + (b - a) * t


def smoothstep(a, b, x):
	t = np.clip((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ a body
def body(S, p):
	"""Bones and the flesh of a body from FleshBody's numbers. Returns the landmarks."""
	h = p.get("height", 1.75)
	k = h / 1.75
	gw = p.get("girth", 1.0)
	belly = p.get("belly", 0.0)
	arm = p.get("arm", 1.0)
	neckl = p.get("neck", 1.0)
	headk = p.get("head", 1.0)
	fing = p.get("fingers", 1.0)
	skin = p["skin"]
	legc = p.get("leg_color", skin)
	torc = p.get("torso_color", skin)
	upc = p.get("upper_arm_color", torc)
	thin = p.get("thin", 0.0)          # 0..1: how much of the flesh is gone
	leg = 0.86 * k
	torso = 0.56 * k
	nl = 0.11 * k * neckl
	hs = 0.22 * k * headk
	L = {"k": k, "gw": gw, "hs": hs, "torso": torso, "leg": leg}
	hips = S.bone("hips", None, F(0, leg, 0))
	spine = S.bone("spine", "hips", F(0, leg + 0.02, 0))
	chest = S.bone("chest", "spine", spine + F(0, torso * 0.5, 0))
	neck = S.bone("neck", "chest", chest + F(0, torso * 0.5, 0))
	head = S.bone("head", "neck", neck + F(0, nl, 0))
	jaw = S.bone("jaw", "head", head + F(0, hs * 0.42, hs * 0.05))
	L.update(hips=hips, spine=spine, chest=chest, neck=neck, head=head, jaw=jaw)
	if belly > 0.01:
		L["belly_c"] = S.bone("belly", "spine", spine + F(0, torso * 0.15 - belly * 0.05, 0.1 * k + belly * 0.1))
	fat = max(0.0, gw - 1.0)
	wide = 1.0 - thin * 0.45

	# --- the trunk: soft, one mass
	t = S.group(k=0.07 + fat * 0.05, join=0.05)
	t.append(S.ell(hips + F(0, 0.0, -0.01), np.array([0.17 * gw, 0.12, 0.12 * gw]) * k * wide, "hips", torc))            # pelvis
	for s in (-1, 1):
		t.append(S.ell(hips + F(s * 0.075 * gw * k, -0.03 * k, -0.07 * gw * k), np.array([0.085 * gw, 0.11, 0.085 * gw]) * k * wide, "hips", torc))  # buttocks
	t.append(S.ell(spine + F(0, torso * 0.28, 0.0), np.array([0.165 * gw, torso * 0.36, 0.115 * gw]) * np.array([k * wide, 1, k * wide]), "spine", torc))
	t.append(S.ell(chest + F(0, torso * 0.18, 0.0), np.array([0.19 * gw * wide + 0.02, torso * 0.36, 0.12 * gw * wide + 0.01]) * np.array([k, 1, k]), "chest", torc))
	sd = p.get("shoulder_drop", 0.0)
	t.append(S.cap(chest + F(-(0.15 * gw * k - sd), torso * 0.42 - sd, -0.01), chest + F(0.15 * gw * k - sd, torso * 0.42 - sd, -0.01), 0.07 * k, 0.07 * k, "chest", torc))   # shoulders' line
	if thin > 0.3:
		pass
	# --- neck
	n = S.group(k=0.04, join=0.05)
	n.append(S.cap(neck + F(0, -0.04, 0), head + F(0, 0.04, -0.01), (0.06 + fat * 0.06) * k, (0.05 + fat * 0.05) * k * (1.0 - thin * 0.3), "neck", p.get("neck_color", skin)))
	# --- legs
	for s, side in ((-1, "l"), (1, "r")):
		hj = S.bone("hip_" + side, "hips", hips + F(s * 0.1 * gw * k, 0, 0))
		kn = S.bone("kn_" + side, "hip_" + side, hj + F(-s * 0.012 * gw * k, -leg * 0.5, 0.01))
		an = kn + F(0, -leg * 0.5 + 0.075 * k, -0.015)
		L["kn_" + side] = kn
		L["an_" + side] = an
		g = S.group(k=0.035, join=0.06)
		g.append(S.cap(hj + F(0, 0.02, 0), kn, 0.09 * gw * k * wide, 0.055 * k * (1.0 + fat * 0.3), "hip_" + side, legc))
		g.append(S.ell(hj + F(s * 0.01, -leg * 0.17, 0.0), np.array([0.075 * gw, 0.16, 0.08 * gw]) * k * wide, "hip_" + side, legc))     # thigh mass
		g.append(S.ell(kn + F(0, 0, 0.035 * k), np.array([0.045, 0.045, 0.03]) * k, "kn_" + side, skin))                            # kneecap
		g.append(S.cap(kn, an, 0.05 * k * wide, 0.032 * k * p.get("ankle", 1.0), "kn_" + side, skin))
		g.append(S.ell(kn + F(0, -leg * 0.14, -0.025 * k), np.array([0.045, 0.1, 0.045]) * k * wide, "kn_" + side, skin))          # calf
		g.append(S.ell(an + F(0, -0.04 * k, 0.045 * k), np.array([0.045, 0.035, 0.11]) * k, "kn_" + side, skin))                     # foot
		g.append(S.ell(an + F(0, -0.035 * k, -0.035 * k), np.array([0.035, 0.035, 0.04]) * k, "kn_" + side, skin))                   # heel
		toes = S.group(k=0.006, join=0.012)
		for i in range(5):
			x = s * (-0.025 + i * 0.013) * k
			r = (0.012 if i == 0 else 0.008) * k
			toes.append(S.cap(an + F(x - s * 0.002, -0.06 * k, 0.12 * k), an + F(x * 1.1, -0.065 * k, (0.155 - i * 0.006) * k * p.get("toes", 1.0)), r, r * 0.9, "kn_" + side, skin))
	# --- arms
	ab = 0.1 + fat * 0.25
	for s, side in ((-1, "l"), (1, "r")):
		drop = p.get("shoulder_drop", 0.0)
		sh = S.bone("sh_" + side, "chest", chest + F(s * (0.22 * gw * k * wide + 0.01 - drop * 0.4), torso * 0.45 - drop, 0))
		d = np.array([s * np.sin(ab), -np.cos(ab), 0.0])
		up = 0.32 * k * arm
		lo = 0.3 * k * arm
		el = S.bone("el_" + side, "sh_" + side, sh + d * up)
		bone_hand = "el_" + side
		if p.get("extra_joint"):
			ex = S.bone("ex_" + side, "el_" + side, el + d * lo)
			wr = ex + d * lo * 0.8
			bone_hand = "ex_" + side
		else:
			wr = el + d * lo
		L["sh_" + side] = sh
		L["el_" + side] = el
		L["wr_" + side] = wr
		g = S.group(k=0.03, join=0.05)
		dl = p.get("deltoid", 1.0)
		af = p.get("arm_fat", 1.0)
		g.append(S.ell(sh + F(s * 0.01, -0.03, 0), np.array([0.065 * gw * dl, 0.07 * dl, 0.065 * gw * dl]) * k * wide, "sh_" + side, upc))         # deltoid
		g.append(S.cap(sh, el, 0.055 * gw * k * wide * (0.8 + 0.2 * af), 0.04 * k * (1 + fat * 0.4) * af, "sh_" + side, upc))
		if fat > 0.2:   # what hangs under the arm
			g.append(S.ell(sh + d * up * 0.45 + F(0, -0.02, -0.02), np.array([0.05, 0.1, 0.05]) * k * fat * 1.2, "sh_" + side, upc))
		if p.get("extra_joint"):
			g.append(S.cap(el, ex, 0.04 * k, 0.032 * k, "el_" + side, skin))
			g.append(S.cap(ex, wr, 0.032 * k, 0.026 * k, "ex_" + side, skin))
			g.append(S.ell(ex, np.array([0.035, 0.03, 0.035]) * k, "ex_" + side, skin))    # the knuckle of the wrong joint
		else:
			g.append(S.cap(el, wr, (0.042 * k * wide + fat * 0.01) * p.get("arm_fat", 1.0), 0.028 * k * (1 + fat * 0.3), "el_" + side, skin))
		hand(S, wr, d, s, bone_hand, skin, k * p.get("hand", 1.0), fing, p)
	# --- the head
	head_(S, p, L)
	return L


def hand(S, wr, d, s, bone, skin, k, fing, p):
	g = S.group(k=0.01, join=0.02)
	palm = wr + d * 0.045 * k
	g.append(S.ell(palm, np.array([0.022, 0.045, 0.04]) * k, bone, skin))
	nail = p.get("nail", skin * 0.9)
	for i in range(4):
		off = (-0.027 + i * 0.018) * k
		base = palm + d * 0.04 * k + F(0, 0, off)
		ln = (0.075 - abs(i - 1.3) * 0.01) * k * fing
		curl = 0.02 * k * fing
		mid = base + d * ln * 0.55 + F(-s * 0.004, 0, 0)
		tip = mid + d * ln * 0.45 + F(-s * curl * 0.5, 0, 0)
		g.append(S.cap(base, mid, 0.0095 * k, 0.0085 * k, bone, skin))
		g.append(S.cap(mid, tip, 0.0085 * k, 0.007 * k, bone, skin))
		S.detail(S.ell(tip + F(0, 0, 0) + d * -0.006 * k + F(s * 0.005 * k, 0, 0), np.array([0.005, 0.009, 0.006]) * k, bone, nail, wet=0.4), k=0.003)
	thumb0 = palm + F(0, 0.0, 0.035 * k)
	g.append(S.cap(thumb0, thumb0 + d * 0.045 * k + F(-s * 0.012 * k, 0, 0.02 * k), 0.012 * k, 0.009 * k, bone, skin))


def head_(S, p, L):
	k, hs, head, jaw = L["k"], L["hs"], L["head"], L["jaw"]
	skin = p.get("face", p["skin"])
	fat = max(0.0, L["gw"] - 1.0)
	thin = p.get("thin", 0.0)
	mw = 0.045 * k * p.get("mouth", 1.0)
	g = S.group(k=0.025, join=0.035)
	c = head + F(0, hs * 0.62, -hs * 0.02)
	g.append(S.ell(c, np.array([hs * 0.4, hs * 0.48, hs * 0.48]), "head", skin))                                              # cranium
	g.append(S.ell(head + F(0, hs * 0.42, hs * 0.18), np.array([hs * 0.33, hs * 0.32, hs * 0.3]), "head", skin))            # face
	g.append(S.cap(head + F(-hs * 0.24, hs * 0.72, hs * 0.38), head + F(hs * 0.24, hs * 0.72, hs * 0.38), hs * 0.07, hs * 0.07, "head", skin))   # brow
	for s in (-1, 1):
		g.append(S.ell(head + F(s * hs * 0.22, hs * 0.5, hs * 0.32), np.array([hs * 0.1, hs * 0.08, hs * 0.08]) * (1 - thin * 0.4), "head", skin))   # cheekbone
		if not p.get("no_ears"):
			er = p.get("ears", 1.0)
			g.append(S.ell(head + F(s * hs * 0.42, hs * 0.55, 0.0), np.array([hs * 0.04, hs * 0.13, hs * 0.09]) * er, "head", p.get("ear_color", skin)))
	# nose
	nz = p.get("nose", 1.0)
	if nz > 0:
		g.append(S.cap(head + F(0, hs * 0.66, hs * 0.44), head + F(0, hs * 0.5, hs * 0.53 * nz), hs * 0.04, hs * 0.06 * nz, "head", p.get("nose_color", skin)))
		for s in (-1, 1):
			g.append(S.ell(head + F(s * hs * 0.05 * nz, hs * 0.48, hs * 0.49), np.array([hs * 0.04, hs * 0.035, hs * 0.04]) * nz, "head", p.get("nose_color", skin)))
	# the jaw (it moves: everything that's the chin goes with it)
	j = S.group(k=0.03, join=0.03)
	j.append(S.ell(jaw + F(0, -hs * 0.2, hs * 0.22), np.array([max(hs * 0.25, mw * 1.25), hs * 0.14, hs * 0.2]), "jaw", skin))
	j.append(S.ell(jaw + F(0, -hs * 0.3, hs * 0.32), np.array([hs * 0.12, hs * 0.08, hs * 0.08]), "jaw", skin))               # chin
	# lips
	lipc = p.get("lip", skin * np.array([1.0, 0.8, 0.8]))
	ly = head + F(0, hs * 0.34, 0)
	lf = hs * 0.47
	open_ = p.get("slack", 0.0) * hs * 0.12
	u = S.group(k=0.015, join=0.02)
	u.append(S.cap(ly + F(-mw, 0.004, lf - 0.01), ly + F(0, 0.008, lf + 0.004), 0.011 * k, 0.014 * k * p.get("lips", 1.0), "head", lipc))
	u.append(S.cap(ly + F(0, 0.008, lf + 0.004), ly + F(mw, 0.004, lf - 0.01), 0.014 * k * p.get("lips", 1.0), 0.011 * k, "head", lipc))
	lw = S.group(k=0.015, join=0.02)
	lo = ly + F(0, -0.018 * k - open_, 0)
	lw.append(S.cap(lo + F(-mw, 0.004, lf - 0.012), lo + F(0, -0.004 * p.get("droop", 1.0), lf + 0.002), 0.011 * k, 0.016 * k * p.get("lips", 1.0), "jaw", lipc))
	lw.append(S.cap(lo + F(0, -0.004 * p.get("droop", 1.0), lf + 0.002), lo + F(mw, 0.004, lf - 0.012), 0.016 * k * p.get("lips", 1.0), 0.011 * k, "jaw", lipc))
	# the mouth: a slot, deep
	S.carve(S.ell(ly + F(0, -0.009 * k - open_ * 0.5, lf - hs * 0.12), np.array([mw * 1.05, 0.006 * k + open_ * 0.5, hs * 0.2])), k=0.008)
	S.carve(S.ell(ly + F(0, -0.01 * k - open_ * 0.5, lf - hs * 0.32), np.array([mw * 0.9, hs * 0.1 + open_, hs * 0.2])), k=0.02)
	L["mouth"] = ly + F(0, -0.009 * k, lf)
	L["mw"] = mw
	L["lf"] = lf
	mouth_inside(S, p, L)
	eyes(S, p, L)


def mouth_inside(S, p, L):
	k, hs, head = L["k"], L["hs"], L["head"]
	mw, lf = L["mw"], L["lf"]
	ly = head + F(0, hs * 0.34, 0)
	gum = C("4a1a1c")
	S.detail(S.ell(ly + F(0, -0.03 * k, lf - hs * 0.32), np.array([mw * 0.7, 0.012 * k, hs * 0.15]), "jaw", C("3a1416"), wet=0.6), k=0.004)   # the tongue
	tc = p.get("teeth_color", C("cdbf94"))
	teeth = p.get("teeth", 8)
	rng = np.random.default_rng(p.get("seed", 1))
	open_ = p.get("slack", 0.0) * hs * 0.12
	for row, bone, dy in ((0, "head", 0.004), (1, "jaw", -0.016 - open_)):
		for i in range(teeth):
			if rng.random() < p.get("missing", 0.0):
				continue
			t = (i + 0.5) / teeth * 2 - 1
			x = t * mw * 0.75
			f = lf - hs * 0.07 - (t * t) * hs * 0.1
			sz = np.array([0.0045, 0.008, 0.004]) * k * p.get("tooth", 1.0) * rng.uniform(0.75, 1.3)
			col = tc * rng.uniform(0.7, 1.05)
			S.detail(S.ell(ly + F(x, dy * k - (0.004 if row == 0 else -0.004) * k, f), sz, bone, col, wet=0.7, rot=(0, 0, rng.uniform(-0.25, 0.25))), k=0.002)


def eyes(S, p, L):
	k, hs, head = L["k"], L["hs"], L["head"]
	style = p.get("eyes", "normal")
	skin = p.get("face", p["skin"])
	ey = head + F(0, hs * 0.62, 0)
	ef = hs * 0.4
	es = p.get("eye_size", 1.0)
	if style == "none":
		for s in (-1, 1):
			S.carve(S.ell(ey + F(s * hs * 0.17, 0, ef + 0.03 * k), np.array([0.022, 0.014, 0.03]) * k), k=0.02)   # where they'd be: shallow, skinned over
		return
	spots = []
	if style == "many":
		rng = np.random.default_rng(7)
		for i in range(p.get("eye_count", 9)):
			a = rng.uniform(-0.9, 0.9)
			y = rng.uniform(0.3, 0.95)
			spots.append((np.sin(a) * hs * 0.42, hs * y, np.cos(a) * hs * 0.46, rng.uniform(0.5, 1.0)))
	else:
		for s in (-1, 1):
			spots.append((s * hs * 0.17, hs * 0.62 + (p.get("slide_eye", 0.0) if s > 0 else 0.0), ef, 1.0))
	for x, y, f, sz in spots:
		c = head + F(x, y, f)
		r = 0.013 * k * es * sz
		fwd = np.array([x * 0.6, 0, -f])
		fwd /= np.linalg.norm(fwd)
		if style == "sewn":
			S.carve(S.ell(c + -fwd * 0.006, np.array([r * 1.4, r * 0.9, r * 1.2])), k=0.01)
			lid = S.ell(c - fwd * 0.004, np.array([r * 1.25, r * 0.85, r * 0.8]), "head", p.get("lid_color", skin * np.array([1.0, 0.8, 0.8])), wet=0.3)
			lid.tag = ("sewn", c, fwd, r)
			S.detail(lid, k=0.006)
			continue
		S.carve(S.ell(c - fwd * r * 0.4, np.array([r * 1.6, r * 1.2, r * 1.4])), k=0.008)
		ball = S.ell(c - fwd * r * 0.25, np.array([r, r, r]), "head", p.get("sclera", C("c9c09a")), wet=1.0)
		ball.tag = ("eye", c - fwd * r * 0.25, fwd, r)
		S.detail(ball, k=0.002)
		# lids: heavy
		S.detail(S.ell(c - fwd * r * 0.1 + F(0, r * 0.75 * p.get("lid", 1.0), 0), np.array([r * 1.3, r * 0.45 * p.get("lid", 1.0), r * 0.9]), "head", skin * 0.93, wet=0.3), k=0.006)
		S.detail(S.ell(c - fwd * r * 0.1 + F(0, -r * 0.85, 0), np.array([r * 1.2, r * 0.35, r * 0.8]), "head", p.get("under_eye", skin * np.array([0.85, 0.75, 0.8])), wet=0.3), k=0.006)


# ------------------------------------------------------------------ paint
def paint_eyes(P, col, wet, ctx):
	for j, s in enumerate(ctx["shapes"]):
		tag = getattr(s, "tag", None)
		if not tag:
			continue
		kind, c, fwd, r = tag
		near = ctx["D"][:, j] < 0.003
		v = (P - c)
		dn = np.linalg.norm(v, axis=1) + 1e-9
		facing = (v @ fwd) / dn
		if kind == "eye":
			iris = near & (facing > 0.8)
			pupil = near & (facing > 0.93)
			col[iris] = C("3a3020")
			col[pupil] = C("060504")
			# the veins in the white
			vein = near & (facing < 0.8) & (np.abs(vnoise(P, 900.0, 3)) < 0.08)
			col[vein] = col[vein] * 0.5 + C("8a1a12") * 0.5
		elif kind == "sewn":
			# stitches across where the lids meet
			up = np.array([0.0, 1.0, 0.0])
			side = np.cross(up, fwd)
			sx = (v @ side) / r
			sy = (v @ up) / r
			stitch = near & (np.abs(np.sin(sx * 5.0)) < 0.25) & (np.abs(sy) < 0.6)
			seam = near & (np.abs(sy) < 0.08) & (np.abs(sx) < 1.1)
			col[stitch | seam] = C("140c0a")
			sore = near & (np.abs(sy) < 0.35) & ~(stitch | seam)
			col[sore] = col[sore] * 0.6 + C("7a2420") * 0.4
			wet[sore] = 0.8
	return col, wet


def mouth_dark(P, col, wet, L, ctx):
	"""Inside the mouth: wet, red-black."""
	m = L["mouth"]
	q = (P - m) / np.array([L["mw"] * 1.1, 0.06, 0.12])
	deep = (q[:, 2] > 0.02) & (np.linalg.norm(q, axis=1) < 1.0)
	is_detail = np.zeros(len(P), bool)
	for j, s in enumerate(ctx["shapes"]):
		if s.wet >= 0.7:
			is_detail |= ctx["D"][:, j] < 0.002
	inner = deep & ~is_detail
	col[inner] = C("1c0707")
	wet[inner] = 0.3
	return col, wet


def skin_base(P, N, col, wet, ctx, mottle=0.12, seed=0):
	n1 = fbm(P, 9.0, 3, seed)
	n2 = fbm(P, 23.0, 2, seed + 40)
	col = col * (1.0 + mottle * n1[:, None] * np.array([0.6, 0.0, -0.5]) + 0.06 * n2[:, None])
	return col, wet


def blend(col, mask, c, amt=1.0):
	m = np.clip(mask, 0, 1)[:, None] * amt
	return col * (1 - m) + np.asarray(c) * m


# ------------------------------------------------------------------ the cast
def the_super():
	"""Gennady Vorobyov. Naked; heavy; wet. The belly hangs to his thighs and over everything,
	the chest sags onto it, the neck is folds, the face slides down on one side. Small eyes in a
	wide wet mouth of a face. Thin legs under all of it, the veins standing out on them; long
	yellow nails; liver spots, sores, hair where you don't want it. Nothing sexual about any of
	it: a body, and that's the horror."""
	S = Sculpt("super")
	skin = C("8c806a")
	p = dict(height=1.84, girth=1.45, belly=1.0, mouth=1.9, head=1.12, neck=0.55, fingers=1.4, skin=skin,
		face=C("8d7b68"), lip=C("6e4e4c"), teeth=7, missing=0.45, teeth_color=C("a8915a"), tooth=1.2, slack=0.35, droop=2.2,
		lips=1.3, eye_size=0.75, lid=1.7, sclera=C("b4a476"), nail=C("8f7a3e"), ankle=1.3, nose=1.05, nose_color=C("94705f"), ears=1.25, seed=1993,
		deltoid=0.7, arm_fat=1.5, shoulder_drop=0.07)
	L = body(S, p)
	k, gw, torso, spine, chest, hs, head, jaw = L["k"], L["gw"], L["torso"], L["spine"], L["chest"], L["hs"], L["head"], L["jaw"]
	bc = L["belly_c"]
	# the belly: a mass hanging off the front of him, and the apron of it over the groin
	g = S.group(k=0.12, join=0.1)
	g.append(S.ell(bc + F(0, 0.06, -0.03), np.array([0.27, 0.24, 0.19]) * k, "belly", skin))
	g.append(S.ell(bc + F(0, -0.12, 0.04), np.array([0.29, 0.21, 0.2]) * k, "belly", skin))
	g.append(S.ell(bc + F(0, -0.31, 0.03), np.array([0.23, 0.14, 0.15]) * k, "belly", skin, rot=(0.3, 0, 0)))
	for s in (-1, 1):
		g.append(S.ell(spine + F(s * 0.24 * k, torso * 0.1, -0.03), np.array([0.11, 0.14, 0.15]) * k, "spine", skin))          # love handles
		g.append(S.ell(spine + F(s * 0.13 * k, torso * 0.25, -0.14 * k), np.array([0.14, 0.09, 0.09]) * k, "spine", skin))     # the rolls on his back
		g.append(S.ell(spine + F(s * 0.12 * k, torso * 0.62, -0.13 * k), np.array([0.14, 0.08, 0.08]) * k, "chest", skin))
	# the chest: sagging onto the belly
	c = S.group(k=0.06, join=0.07)
	for s in (-1, 1):
		c.append(S.ell(chest + F(s * 0.12 * k, torso * 0.08, 0.14 * k), np.array([0.11, 0.12, 0.08]) * k, "chest", skin))
		c.append(S.ell(chest + F(s * 0.135 * k, -torso * 0.06, 0.17 * k), np.array([0.08, 0.075, 0.065]) * k, "chest", skin))
		# the shoulders slope into the neck: fat over the trapezius
		c.append(S.cap(L["neck"] + F(s * 0.04, 0.02, -0.03), L["sh_" + ("l" if s < 0 else "r")] + F(-s * 0.03, 0.03, -0.01), 0.075 * k, 0.07 * k, "chest", skin))
	# the neck: no neck, folds; a hump of fat behind
	n = S.group(k=0.05, join=0.06)
	for i in range(3):
		n.append(S.ell(L["neck"] + F(0, 0.0 + i * 0.035, 0.02 - i * 0.004), np.array([0.135 - i * 0.012, 0.035, 0.125 - i * 0.012]) * k, "neck", skin))
	n.append(S.ell(L["neck"] + F(0, -0.02, -0.08 * k), np.array([0.12, 0.08, 0.07]) * k, "chest", skin))
	# jowls and the chins, on the jaw so they swing when he talks
	jw = S.group(k=0.04, join=0.045)
	for s in (-1, 1):
		jw.append(S.ell(head + F(s * hs * 0.27, hs * 0.2 - (0.012 if s < 0 else 0.0), hs * 0.2), np.array([hs * 0.15, hs * 0.19, hs * 0.15]), "jaw", p["face"]))
	jw.append(S.ell(jaw + F(0, -hs * 0.44, hs * 0.16), np.array([hs * 0.32, hs * 0.14, hs * 0.22]), "jaw", p["face"]))
	jw.append(S.ell(jaw + F(0, -hs * 0.6, hs * 0.05), np.array([hs * 0.3, hs * 0.11, hs * 0.2]), "jaw", p["face"]))
	# the face slides: the left cheek lower and heavier than the right
	jw.append(S.ell(head + F(-hs * 0.21, hs * 0.37, hs * 0.32), np.array([hs * 0.12, hs * 0.13, hs * 0.09]), "head", p["face"]))
	# folds: under each breast, the crease under the belly (a smile, up at the sides), the navel
	S.disps.append(lambda P: fold(P, chest + F(-0.13 * k, -torso * 0.17, 0.2), 0.008, 0.0, 0.09, depth=0.007, curve=3.0))
	S.disps.append(lambda P: fold(P, chest + F(0.13 * k, -torso * 0.17, 0.2), 0.008, 0.0, 0.09, depth=0.007, curve=3.0))
	S.disps.append(lambda P: fold(P, bc + F(0, -0.36 * k, 0.0), 0.014, 0.0, 0.32, depth=0.02, curve=1.6))
	S.disps.append(lambda P: fold(P, bc + F(0, 0.17 * k, 0.0), 0.016, 0.0, 0.26, depth=0.008, curve=1.2))
	S.disps.append(lambda P: cellulite(P, 0.0035))
	S.carve(S.ell(bc + F(0, -0.03, 0.215 * k), np.array([0.013, 0.02, 0.03])), k=0.02)   # the navel: deep
	S.carve(S.ell(L["hips"] + F(0, -0.05 * k, -0.2 * k), np.array([0.012, 0.13, 0.08]) * k), k=0.03)     # behind

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.25, seed=11)
		ao = ctx["ao"]
		front = -N[:, 2]
		y = P[:, 1]
		# grey under the yellow: the blood not getting there
		col = blend(col, smoothstep(-0.2, 0.6, fbm(P, 4.0, 2, 31)), C("8a8a80"), 0.25)
		# the folds: raw, red, wet
		crease = smoothstep(0.72, 0.42, ao)
		col = blend(col, crease, C("7a3a30"), 0.6)
		wet = np.maximum(wet, 0.5 + 0.5 * crease)
		# liver spots, in clusters
		sp = cells(P, 26.0, 5)
		col = blend(col, smoothstep(0.3, 0.16, sp) * smoothstep(0.1, 0.35, fbm(P, 3.0, 1, 9)), C("5e4228"), 0.75)
		# sores, here and there: a red ring and a yellow middle
		so = cells(P, 7.0, 21)
		pick = vnoise(P, 4.0, 22) > 0.45
		col = blend(col, smoothstep(0.15, 0.09, so) * pick, C("6e1a16"), 0.85)
		col = blend(col, smoothstep(0.065, 0.03, so) * pick, C("a08a36"), 0.9)
		# the nipples
		for s in (-1, 1):
			nc = chest + F(s * 0.14 * k, -torso * 0.07, 0.235 * k)
			col = blend(col, smoothstep(0.028, 0.018, np.linalg.norm(P - nc, axis=1)), C("6a4440"), 0.8)
		# hair: the chest, the line down the gut, the mat under it, the shoulders, the backs of the hands
		speck = smoothstep(0.32, 0.12, cells(P, 160.0, 4))
		chestm = smoothstep(0.14, 0.02, np.abs(P[:, 0]) - 0.03) * smoothstep(chest[1] - 0.02, chest[1] + 0.1, y) * smoothstep(chest[1] + 0.26, chest[1] + 0.16, y) * (front > 0.2)
		line = smoothstep(0.035, 0.0, np.abs(P[:, 0])) * smoothstep(bc[1] - 0.25, bc[1] + 0.05, y) * (front > 0.5)
		under = smoothstep(bc[1] - 0.3, bc[1] - 0.38, y) * (front > -0.2) * smoothstep(0.24, 0.1, np.abs(P[:, 0])) * (y > L["leg"] - 0.25)
		shoulders = smoothstep(chest[1] + 0.22, chest[1] + 0.32, y) * (front < -0.2) * (fbm(P, 6.0, 2, 3) > 0.0)
		forearm = (np.abs(P[:, 0]) > 0.3) & (y < chest[1]) & (y > L["wr_l"][1]) & (front < 0.3)
		hairm = np.clip(chestm + line + under * 1.6 + shoulders * 0.8 + forearm * 0.5, 0, 1) * speck
		col = blend(col, hairm, C("17120e"), 0.85)
		wet = wet * (1 - 0.7 * hairm)
		# the scalp: stubble, a few greasy strands combed across it
		scalp = smoothstep(head[1] + hs * 0.75, head[1] + hs * 0.9, y)
		col = blend(col, scalp * speck, C("3a3028"), 0.5)
		comb = scalp * (np.abs(np.sin(P[:, 2] * 220.0 + vnoise(P, 30.0, 6) * 2.0)) < 0.12) * (vnoise(P, 12.0, 7) > -0.1)
		col = blend(col, comb, C("231c16"), 0.9)
		wet = np.maximum(wet, comb * 0.95)
		# the legs: veins (raised, blue-grey), the shins bruised and shiny, the ankles swollen
		legm = smoothstep(L["leg"] - 0.05, L["leg"] - 0.15, y)
		vein = legm * smoothstep(0.03, 0.0, np.abs(vnoise(P * np.array([1.6, 0.5, 1.6]), 16.0, 13)))
		col = blend(col, vein, C("3e3a5a"), 0.6)
		shin = smoothstep(0.45, 0.1, y) * (fbm(P, 9.0, 2, 30) > 0.15)
		col = blend(col, shin, C("5a3e40"), 0.45)
		# grime: the feet, the hands
		col = blend(col, smoothstep(0.1, 0.0, y), C("33291c"), 0.65)
		col = blend(col, smoothstep(L["wr_l"][1] + 0.02, L["wr_l"][1] - 0.12, y) * (np.abs(P[:, 0]) > 0.25), C("4a3a26"), 0.5)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, np.clip(wet * 0.95, 0, 1)
	S.paint = paint
	S.ao_strength = 1.3
	return S


def fold(P, c, width, depth_w, half, depth=0.015, curve=0.0):
	"""A crease across the body at c: pushes in by `depth`, `width` tall, within `half` of the
	middle, bending up toward the sides by `curve` (a smile)."""
	d = np.abs(P[:, 1] - (c[1] + curve * (P[:, 0] - c[0]) ** 2))
	side = smoothstep(half, half * 0.6, np.abs(P[:, 0] - c[0]))
	front = smoothstep(0.0, 0.08, c[2] - P[:, 2] + 0.15)
	return depth * np.exp(-(d / width) ** 2) * side * front


def cellulite(P, amp):
	return amp * np.abs(vnoise(P, 40.0, 77))


def lumps(S, L, rng, count, bones, color, size=(0.03, 0.08)):
	"""Growths, set into the skin: a point near each bone pushed out to the surface, the lump
	half-sunk there."""
	g = S.group(k=0.035, join=0.03)
	for i in range(count):
		b = bones[i % len(bones)]
		c = S.bones[b][1] + rng.normal(0, 0.06, 3)
		for _ in range(8):
			P = c[None, :]
			d = S.sdf(P)[0]
			gr = S.grad(P, 0.004)[0]
			c = c - d * gr / max(1e-6, gr @ gr)
		n = S.grad(c[None, :], 0.004)[0]
		n /= max(1e-6, np.linalg.norm(n))
		r = rng.uniform(*size)
		g.append(S.ell(c - n * r * 0.35, np.array([r, r * rng.uniform(0.7, 1.3), r]), b, color))


def the_hunter():
	"""Huge, the head too small on it, the mouth too wide, eyes all over the head; growths."""
	S = Sculpt("hunter")
	skin = C("b29a8a")
	p = dict(height=2.05, girth=1.4, arm=1.45, head=0.8, neck=0.5, mouth=1.7, eyes="many", eye_count=11, fingers=1.6, skin=skin,
		lip=C("5a3a36"), lips=0.7, teeth=10, tooth=1.8, slack=0.8, teeth_color=C("c8b888"), nose=0.0, no_ears=True, hand=1.3, seed=4)
	L = body(S, p)
	rng = np.random.default_rng(12)
	lumps(S, L, rng, 18, ["chest", "spine", "sh_l", "sh_r", "neck", "hip_l"], C("c49a8a"), (0.035, 0.09))
	S.disps.append(lambda P: 0.006 * np.abs(vnoise(P, 14.0, 3)))

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.3, seed=2)
		col = blend(col, smoothstep(0.7, 0.4, ctx["ao"]), C("6a2a26"), 0.6)
		col = blend(col, (fbm(P, 30.0, 2, 8) > 0.35).astype(float), C("8a6a62"), 0.4)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, np.maximum(wet, 0.35)
	S.paint = paint
	return S


def the_listener():
	"""Thin, the neck twice as long as a neck; no eyes; the ears huge; long fingers."""
	S = Sculpt("listener")
	skin = C("dccdc6")
	p = dict(height=1.85, girth=0.75, neck=2.2, head=1.25, eyes="none", mouth=1.3, arm=1.2, fingers=1.8, skin=skin, thin=0.8,
		ears=2.6, ear_color=C("d2aaa4"), teeth=12, tooth=0.7, slack=0.2, lip=C("b89a96"), nose=0.3, seed=9)
	L = body(S, p)
	S.disps.append(lambda P: ribs(P, L, 0.006))

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.08, seed=5)
		vein = np.abs(fbm(P * np.array([1.5, 0.6, 1.5]), 14.0, 2, 1)) < 0.04
		col[vein] = col[vein] * 0.6 + C("6a7a9a") * 0.4
		col = blend(col, smoothstep(0.75, 0.5, ctx["ao"]), C("8a6a6a"), 0.5)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		return col, wet * 0.5 + 0.15
	S.paint = paint
	return S


def ribs(P, L, amp):
	ch = L["chest"]
	y = P[:, 1] - (ch[1] - 0.1)
	band = (y > 0) & (y < 0.3)
	trunk = smoothstep(0.16 * L["gw"] * L["k"], 0.1 * L["gw"] * L["k"], np.abs(P[:, 0]))
	return amp * band * trunk * (0.5 + 0.5 * np.cos(y * 2 * np.pi / 0.045)) * smoothstep(0.02, 0.06, np.abs(P[:, 0]))


def dressed(S, L, dress, skirt=True, length=0.75):
	"""A dress, as cloth over the body: a little bigger than the flesh, so it's what shows. The
	skirt is two halves, one on each leg, blended into one: it walks with the legs."""
	k, gw, torso = L["k"], L["gw"], L["torso"]
	g = S.group(k=0.08, join=0.02)
	g.append(S.ell(L["spine"] + F(0, torso * 0.28, 0.0), np.array([0.175 * gw, torso * 0.38, 0.125 * gw]) * np.array([k, 1, k]), "spine", dress))
	g.append(S.ell(L["chest"] + F(0, torso * 0.18, 0.0), np.array([0.2 * gw + 0.01, torso * 0.36, 0.13 * gw]) * np.array([k, 1, k]), "chest", dress))
	if skirt:
		g.append(S.ell(L["hips"] + F(0, 0.0, -0.01), np.array([0.19 * gw, 0.14, 0.14 * gw]) * k, "hips", dress))
		for s, side in ((-1, "l"), (1, "r")):
			top = L["hips"] + F(s * 0.06 * gw * k, -0.05, 0)
			g.append(S.cap(top, top + F(s * 0.03 * k, -L["leg"] * length, 0.01), 0.1 * gw * k, 0.12 * gw * k, "hip_" + side, dress))


def apron(P, N, col, wet, L, color, top, bottom, half):
	"""An apron, painted on the front of whatever's there (it moves with them: it's them)."""
	front = -N[:, 2]
	y = P[:, 1]
	m = (front > 0.15) & (y < top) & (y > bottom) & (np.abs(P[:, 0]) < half + 0.03 * np.sin(y * 40.0))
	col[m] = color * (0.9 + 0.1 * vnoise(P[m], 30.0, 2)[:, None])
	strap = (y > top) & (y < top + 0.3) & (np.abs(np.abs(P[:, 0]) - half * 0.6) < 0.015) & (front > 0.1)
	col[strap] = color * 0.85
	wet[m | strap] = 0.05
	return col, wet, m


def cloth_paint(P, col, wet, ctx, cloth_colors, seed=0):
	"""Stains, wear, dirt on whatever's cloth."""
	isc = np.zeros(len(P), bool)
	for j, s in enumerate(ctx["shapes"]):
		if any(np.allclose(s.color, c) for c in cloth_colors):
			isc |= ctx["D"][:, j] < 0.004
	stain = (fbm(P, 6.0, 3, seed) > 0.25) & isc
	col[stain] = col[stain] * 0.55 + C("4a3a2a") * 0.45
	weave = isc & (np.abs(np.sin(P[:, 1] * 900.0)) < 0.3)
	col[weave] *= 0.92
	wet[isc] = 0.05
	return col, wet


def hair_long(S, L, color, length=0.5, strands=26, seed=3):
	rng = np.random.default_rng(seed)
	hs, head = L["hs"], L["head"]
	g = S.group(k=0.02, join=0.02)
	g.append(S.ell(head + F(0, hs * 0.72, -hs * 0.06), np.array([hs * 0.43, hs * 0.42, hs * 0.5]), "head", color))
	for i in range(strands):
		a = rng.uniform(-2.6, 2.6)
		if abs(a) < 0.55:
			continue        # (not over the face)
		start = head + F(np.sin(a) * hs * 0.42, hs * 0.8, np.cos(a) * hs * 0.42)
		end = start + F(np.sin(a) * 0.03, -length * rng.uniform(0.6, 1.0), np.cos(a) * 0.02 - 0.03)
		bone = "head" if rng.random() < 0.6 else "neck"
		g.append(S.cap(start, end, 0.018, 0.008, bone, color * rng.uniform(0.8, 1.1)))


def the_laundress():
	S = Sculpt("laundress")
	skin = C("cfbba8")
	dress, apron_c = C("59505a"), C("8a8a7c")
	p = dict(height=1.98, girth=0.8, arm=1.35, neck=1.6, head=0.85, eyes="sewn", mouth=0.7, fingers=1.5, skin=skin, thin=0.6,
		torso_color=dress, upper_arm_color=dress, teeth=6, seed=2, lip=C("9a7a78"))
	L = body(S, p)
	dressed(S, L, dress, length=0.88)
	hair_long(S, L, C("8a8a84"), 0.55)

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.1, seed=3)
		col, wet = cloth_paint(P, col, wet, ctx, [dress], 2)
		col, wet, _ = apron(P, N, col, wet, L, apron_c, L["chest"][1] - 0.05, L["kn_l"][1] - 0.1, 0.13)
		hd = np.minimum(np.linalg.norm(P - L["wr_l"], axis=1), np.linalg.norm(P - L["wr_r"], axis=1))
		red = smoothstep(0.16, 0.05, hd)            # the hands: raw from the water
		col = blend(col, red, C("a0524a"), 0.5)
		col = blend(col, smoothstep(0.7, 0.45, ctx["ao"]), C("5a3a36"), 0.4)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, wet
	S.paint = paint
	return S


def the_caretaker():
	S = Sculpt("caretaker")
	skin = C("ccb2ad")
	dress = C("2e1f24")
	p = dict(height=1.62, girth=0.95, eyes="sewn", mouth=0.6, skin=skin, torso_color=dress, upper_arm_color=dress, seed=5, lip=C("8a6a6a"))
	L = body(S, p)
	dressed(S, L, dress, length=0.9)
	hair_long(S, L, C("261a1a"), 0.35, seed=8)
	rng = np.random.default_rng(3)
	lumps(S, L, rng, 6, ["neck", "head", "neck"], C("c4a09a"), (0.02, 0.04))

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.12, seed=6)
		col, wet = cloth_paint(P, col, wet, ctx, [dress], 4)
		# the hands and the front of her: what she carries to the bath
		blood = ((fbm(P, 9.0, 2, 14) > 0.3) & (-N[:, 2] > 0.5) & (P[:, 1] < L["chest"][1])) | ((P[:, 1] < L["wr_l"][1] + 0.06) & (np.abs(P[:, 0]) > 0.15))
		col[blood] = col[blood] * 0.4 + C("4a0a0a") * 0.6
		wet[blood] = 0.8
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, wet
	S.paint = paint
	return S


def the_cook():
	S = Sculpt("cook")
	skin = C("cbb39a")
	apron_c = C("b3a699")
	p = dict(height=1.8, girth=1.2, belly=0.8, mouth=1.4, fingers=1.3, head=0.9, skin=skin, teeth=9, slack=0.15, seed=6, lip=C("9a6a60"))
	L = body(S, p)
	k, bc = L["k"], L["belly_c"]
	g = S.group(k=0.12, join=0.12)
	g.append(S.ell(bc + F(0, -0.04, -0.02), np.array([0.24, 0.24, 0.16]) * k, "belly", skin))

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.16, seed=7)
		col, wet, am = apron(P, N, col, wet, L, apron_c, L["chest"][1] + 0.22, L["kn_l"][1] - 0.05, 0.25)
		# what's on it: smeared down the front, wiped on, and the hands and forearms to the elbow
		smear = am & (fbm(P * np.array([2.5, 0.6, 2.5]), 9.0, 3, 15) > 0.3)
		hands = (P[:, 1] < L["el_r"][1]) & (np.abs(P[:, 0]) > 0.2) & (fbm(P, 14.0, 2, 16) > -0.2)
		blood = smear | hands
		col[blood] = col[blood] * 0.3 + C("4a0a08") * 0.7
		wet[blood] = 0.75
		col = blend(col, smoothstep(0.7, 0.45, ctx["ao"]), C("7a3a30"), 0.5)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, np.maximum(wet, 0.35)
	S.paint = paint
	return S


def the_rearranger():
	S = Sculpt("rearranger")
	skin = C("cbb5a2")
	dress = C("4d5266")
	p = dict(height=1.5, girth=1.35, belly=0.5, extra_joint=True, skin=skin, torso_color=dress, upper_arm_color=dress, seed=8, lip=C("9a7a70"), mouth=1.0)
	L = body(S, p)
	dressed(S, L, dress, length=0.7)
	hair_long(S, L, C("4a4038"), 0.2, strands=14, seed=2)

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.14, seed=8)
		col, wet = cloth_paint(P, col, wet, ctx, [dress], 8)
		col = blend(col, smoothstep(0.7, 0.45, ctx["ao"]), C("5a4038"), 0.4)
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, wet
	S.paint = paint
	return S


def the_crawler():
	"""Small, starved, the arms twice as long and jointed twice, eyes across the head, the mouth
	wide. Lives in the walls; the skin's never seen light."""
	S = Sculpt("crawler")
	skin = C("b8adb6")
	p = dict(height=1.0, girth=0.8, arm=1.7, extra_joint=True, eyes="many", eye_count=8, mouth=1.5, neck=0.6, skin=skin, thin=1.0,
		teeth=11, tooth=1.3, slack=0.6, nose=0.0, no_ears=True, fingers=1.6, seed=10, lip=C("7a5a66"), toes=1.6)
	L = body(S, p)
	S.disps.append(lambda P: ribs(P, L, 0.008))
	# the spine: knuckles down its back
	for i in range(9):
		y = L["hips"][1] + 0.03 + i * 0.035
		bone = "spine" if y < L["chest"][1] else "chest"
		S.groups[0][2].append(S.ell(F(0, y, -0.075 * L["k"] - 0.012), np.array([0.012, 0.01, 0.012]), bone, skin))

	def paint(P, N, col, wet, ctx):
		col, wet = skin_base(P, N, col, wet, ctx, mottle=0.2, seed=9)
		col = blend(col, smoothstep(0.75, 0.45, ctx["ao"]), C("4a3040"), 0.6)
		grime = (fbm(P, 11.0, 3, 19) > 0.2)
		col[grime] = col[grime] * 0.5 + C("2a2420") * 0.5
		col, wet = mouth_dark(P, col, wet, L, ctx)
		col, wet = paint_eyes(P, col, wet, ctx)
		return col, np.maximum(wet, 0.4)
	S.paint = paint
	return S


CAST = {"super": (the_super, 0.0105), "hunter": (the_hunter, 0.014), "listener": (the_listener, 0.012), "laundress": (the_laundress, 0.013),
	"caretaker": (the_caretaker, 0.013), "cook": (the_cook, 0.013), "rearranger": (the_rearranger, 0.013), "crawler": (the_crawler, 0.009)}

if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	names = sys.argv[1:] or list(CAST)
	for name in names:
		make, voxel = CAST[name]
		S = make()
		S.bake(voxel=voxel)
		S.write_glb(os.path.join(OUT, name + ".glb"))
