"""The kit for the building's inhabitants (docs/PEOPLE.md): low-poly, PS1-style.

A body is a handful of lofts, the way they were box-modelled in 1997. Each loft is a run of
rings (cross-sections) along a path: the trunk from the crotch to the neck, the head, each arm,
each leg, the feet, the fingers. A ring is an ellipse with bulges (a nose on the front of the
head's nose ring, ribs, a belly), weighted to the bones it moves with. One mesh, smooth-shaded,
1-3k triangles.

Every loft gets a rectangle of one texture page (256 x 256): the texture is painted by working
out, for every texel, where on the body it lands (its 3D point and normal, and the loft's own
coordinates: around, and along), and asking the character's paint function what's there. The
lighting is baked in (from above and in front, as in the games), then the colours are cut to
15 bits with an ordered dither.

Out: <name>.glb (mesh, skeleton, skin; no images) and <name>.png (the page), which FleshBody
loads with the game's PS1 shader. The rest pose has no rotation on any bone, so the game's poses
mean the same thing here.

Only numpy (and zlib for the png).
"""
import json
import struct
import zlib

import numpy as np

TAU = np.pi * 2.0


# ------------------------------------------------------------------ noise
def _hash(ix, iy, iz, seed):
	h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)).astype(np.float64) / 4294967295.0


def vnoise(P, freq, seed=0):
	q = P * freq
	i = np.floor(q).astype(np.int64)
	f = q - i
	u = f * f * (3.0 - 2.0 * f)
	out = 0.0
	for dx in (0, 1):
		for dy in (0, 1):
			for dz in (0, 1):
				w = (u[..., 0] if dx else 1 - u[..., 0]) * (u[..., 1] if dy else 1 - u[..., 1]) * (u[..., 2] if dz else 1 - u[..., 2])
				out = out + w * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
	return out * 2.0 - 1.0


def fbm(P, freq, octaves=3, seed=0):
	s, a, t = 0.0, 1.0, 0.0
	for o in range(octaves):
		s = s + a * vnoise(P, freq * (2.0 ** o), seed + o * 17)
		t += a
		a *= 0.5
	return s / t


def cells(P, freq, seed=0):
	q = P * freq
	i = np.floor(q).astype(np.int64)
	best = np.full(P.shape[:-1], 9.0)
	for dx in (-1, 0, 1):
		for dy in (-1, 0, 1):
			for dz in (-1, 0, 1):
				c = i + np.array([dx, dy, dz])
				j = np.stack([_hash(c[..., 0], c[..., 1], c[..., 2], seed + k) for k in range(3)], -1)
				best = np.minimum(best, np.linalg.norm(q - (c + j), axis=-1))
	return best


def smoothstep(a, b, x):
	t = np.clip((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)


def C(hexs):
	h = hexs.lstrip("#")
	return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def F(x, y, f):
	"""Godot's axes, the body facing -z: f is 'how far forward'."""
	return np.array([x, y, -f], float)


def mix(col, mask, c, amt=1.0):
	m = (np.clip(mask, 0, 1) * amt)[..., None]
	return col * (1 - m) + np.asarray(c) * m


# ------------------------------------------------------------------ rings and lofts
class Ring:
	"""A cross-section. rx across, rz front-to-back (in the loft's frame). Bulges push the outline
	out (or in, negative): `front`/`back` (a cosine lobe), and `bumps`: [(angle, width, amount)]
	(angle 0 = the front, + toward the body's right). `w`: {bone: weight}, or a function of the
	angle giving one (the jaw takes the front of the lower face). `dy` shifts the ring along the
	loft's 'front' axis (a belly pushed forward, a stoop)."""

	def __init__(self, c, rx, rz=None, w=None, front=0.0, back=0.0, bumps=(), shift=0.0, minv=0.012, dark=0.0):
		self.dark = dark          # 0..1: a groove (the paint darkens it)
		self.c = np.asarray(c, float)
		self.rx = rx
		self.rz = rx if rz is None else rz
		self.w = w or {}
		self.front = front
		self.back = back
		self.bumps = list(bumps)
		self.shift = shift
		self.minv = minv

	def radius_add(self, th):
		d = self.front * np.maximum(np.cos(th), 0) ** 2 + self.back * np.maximum(-np.cos(th), 0) ** 2
		for a, wd, amt in self.bumps:
			da = np.angle(np.exp(1j * (th - a)))
			d = d + amt * np.exp(-(da / wd) ** 2)
		return d


class Loft:
	def __init__(self, name, rings, sides=8, front_hint=(0, 0, -1), cap_start=True, cap_end=True, texel=1.0, flip=False, arc=None):
		self.name = name
		self.rings = rings
		self.n = sides
		self.front_hint = np.asarray(front_hint, float)
		self.cap_start = cap_start
		self.cap_end = cap_end
		self.texel = texel        # texture density relative to the rest
		self.flip = flip

	def frames(self):
		c = np.array([r.c for r in self.rings])
		t = np.zeros_like(c)
		t[1:-1] = c[2:] - c[:-2]
		t[0] = c[1] - c[0]
		t[-1] = c[-1] - c[-2]
		t /= np.linalg.norm(t, axis=1, keepdims=True)
		fr = []
		for i in range(len(c)):
			f = self.front_hint - t[i] * (self.front_hint @ t[i])
			if np.linalg.norm(f) < 1e-4:
				f = np.array([0, 1.0, 0]) - t[i] * t[i][1]
			f /= np.linalg.norm(f)
			side = np.cross(t[i], f)
			# 'side' must be the body's right (+x for a loft running up and facing -z)
			fr.append((t[i], f, side))
		return fr

	def grid(self):
		"""(rings, n+1, 3) positions; the last column repeats the first (the seam, at the back)."""
		fr = self.frames()
		n = self.n
		th = (np.arange(n + 1) / n - 0.5) * TAU
		G = np.zeros((len(self.rings), n + 1, 3))
		for i, r in enumerate(self.rings):
			t, f, side = fr[i]
			add = r.radius_add(th)
			rx = r.rx + add * 1.0
			rz = r.rz + add * 1.0
			G[i] = r.c + f * r.shift + np.outer(rx * np.sin(th), side) + np.outer(rz * np.cos(th), f)
		return G, th, fr


# ------------------------------------------------------------------ the model
class Model:
	def __init__(self, name, page=512):
		self.name = name
		self.page = page
		self.bones = {}
		self.order = []
		self.lofts = []
		self.paint = None          # f(P, N, part, th, s, ctx) -> rgb
		self.light = np.array([0.35, 0.85, -0.4])
		self.light /= np.linalg.norm(self.light)
		self.bake = (0.3, 0.75)   # baked light: ambient, direct
		self.gloss = {}            # part prefix -> how wet/shiny (a highlight painted in)
		self.dark = None

	def bone(self, name, parent, pos):
		self.bones[name] = (parent, np.asarray(pos, float))
		self.order.append(name)
		return np.asarray(pos, float)

	def add(self, loft):
		self.lofts.append(loft)
		return loft

	# ------------------------------------------------------------- build
	def build(self):
		verts, norms, uvs, joints, weights, tris = [], [], [], [], [], []
		rects = self._pack()
		self.tex = np.zeros((self.page, self.page, 3))
		bi = {b: i for i, b in enumerate(self.order)}
		base = 0
		for lf, (rx0, ry0, rw, rh) in zip(self.lofts, rects):
			G, th, fr = lf.grid()
			R, n1 = G.shape[0], G.shape[1]
			n = n1 - 1
			# normals on the closed grid
			Nm = np.zeros_like(G)
			for i in range(R):
				for j in range(n):
					a = G[i, j]
					right = G[i, (j + 1) % n] - G[i, (j - 1) % n]
					along = G[min(i + 1, R - 1), j] - G[max(i - 1, 0), j]
					nn = np.cross(right, along)
					Nm[i, j] = nn
			Nm[:, n] = Nm[:, 0]
			# outward: compare with the direction from the ring's centre
			out = G - np.array([r.c for r in lf.rings])[:, None, :]
			if (Nm * out).sum() < 0:
				Nm = -Nm
				flip = True
			else:
				flip = False
			Nm /= np.maximum(np.linalg.norm(Nm, axis=2, keepdims=True), 1e-9)
			# v: by length along, with a minimum per span (so a lip gets texels)
			span = [max(np.linalg.norm(lf.rings[i + 1].c - lf.rings[i].c), lf.rings[i].minv) for i in range(R - 1)]
			vv = np.concatenate([[0], np.cumsum(span)])
			vv /= vv[-1]
			uu = np.arange(n1) / n
			# weights per vertex
			W = np.zeros((R, n1, len(self.order)))
			for i, r in enumerate(lf.rings):
				for j in range(n1):
					w = r.w(th[j]) if callable(r.w) else r.w
					for b, x in w.items():
						W[i, j, bi[b]] += x
			W /= np.maximum(W.sum(2, keepdims=True), 1e-9)
			pv = G.reshape(-1, 3)
			verts.append(pv)
			norms.append(Nm.reshape(-1, 3))
			U = (rx0 + uu[None, :] * rw) / self.page
			V = (ry0 + vv[:, None] * rh) / self.page
			uvs.append(np.stack(np.broadcast_arrays(U, V), -1).reshape(-1, 2))
			Wf = W.reshape(-1, len(self.order))
			top = np.argsort(-Wf, 1)[:, :4]
			tw = np.take_along_axis(Wf, top, 1)
			tw /= np.maximum(tw.sum(1, keepdims=True), 1e-9)
			joints.append(top)
			weights.append(tw)
			idx = lambda i, j: base + i * n1 + j
			for i in range(R - 1):
				for j in range(n):
					a, b, c, d = idx(i, j), idx(i, j + 1), idx(i + 1, j + 1), idx(i + 1, j)
					if not flip:
						tris += [(a, b, c), (a, c, d)]
					else:
						tris += [(a, c, b), (a, d, c)]
			nv = R * n1
			# caps: a point just past the end ring
			for end, cap in ((0, lf.cap_start), (R - 1, lf.cap_end)):
				if not cap:
					continue
				t = fr[end][0] * (-1 if end == 0 else 1)
				r = lf.rings[end]
				cpos = r.c + fr[end][1] * r.shift + t * min(r.rx, r.rz) * 0.35
				verts.append(cpos[None])
				norms.append(t[None])
				uvs.append(np.array([[(rx0 + rw * 0.5) / self.page, (ry0 + (0 if end == 0 else rh)) / self.page]]))
				joints.append(top[end * n1:end * n1 + 1])
				weights.append(tw[end * n1:end * n1 + 1])
				ci = base + nv
				nv += 1
				for j in range(n):
					a, b = idx(end, j), idx(end, j + 1)
					if (end == 0) == flip:
						tris.append((ci, a, b))
					else:
						tris.append((ci, b, a))
			base += nv
			# the texture for this loft
			self._paint_rect(lf, G, Nm, th, vv, (rx0, ry0, rw, rh))
		self.mesh = dict(verts=np.concatenate(verts), normals=np.concatenate(norms), uv=np.concatenate(uvs),
			joints=np.concatenate(joints), weights=np.concatenate(weights), tris=np.array(tris, np.uint32))
		print(f"  {self.name}: {len(self.mesh['verts'])} verts, {len(tris)} tris")

	def _pack(self):
		"""Shelf-pack every loft's rectangle onto the page: width from its girth, height from its
		length, both scaled until everything fits."""
		want = []
		for lf in self.lofts:
			G, th, fr = lf.grid()
			girth = np.mean([np.linalg.norm(np.diff(G[i], axis=0), axis=1).sum() for i in range(len(G))])
			span = [max(np.linalg.norm(lf.rings[i + 1].c - lf.rings[i].c), lf.rings[i].minv) for i in range(len(G) - 1)]
			want.append((girth * lf.texel, sum(span) * lf.texel))
		scale = 400.0
		while True:
			x = y = row = 0
			rects = []
			ok = True
			for w, h in want:
				W = max(4, int(w * scale))
				H = max(4, int(h * scale))
				if x + W > self.page:
					x = 0
					y += row
					row = 0
				if W > self.page or y + H > self.page:
					ok = False
					break
				rects.append((x, y, W, H))
				x += W
				row = max(row, H)
			if ok:
				return rects
			scale *= 0.95

	def _paint_rect(self, lf, G, Nm, th, vv, rect):
		x0, y0, w, h = rect
		u = (np.arange(w) + 0.5) / w
		v = (np.arange(h) + 0.5) / h
		n = G.shape[1] - 1
		fj = u * n
		j0 = np.clip(np.floor(fj).astype(int), 0, n - 1)
		tj = fj - j0
		i0 = np.clip(np.searchsorted(vv, v, side="right") - 1, 0, len(vv) - 2)
		ti = (v - vv[i0]) / np.maximum(vv[i0 + 1] - vv[i0], 1e-9)
		I0, J0 = np.meshgrid(i0, j0, indexing="ij")
		TI, TJ = np.meshgrid(ti, tj, indexing="ij")

		def lerp2(A):
			a = A[I0, J0] * (1 - TJ[..., None]) + A[I0, J0 + 1] * TJ[..., None]
			b = A[I0 + 1, J0] * (1 - TJ[..., None]) + A[I0 + 1, J0 + 1] * TJ[..., None]
			return a * (1 - TI[..., None]) + b * TI[..., None]
		P = lerp2(G)
		N = lerp2(Nm)
		N /= np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-9)
		TH = (np.broadcast_to(u[None, :], (h, w)) - 0.5) * TAU
		S = np.broadcast_to(v[:, None], (h, w))
		dk = np.array([r.dark for r in lf.rings])
		dd = dk[i0] * (1 - ti) + dk[i0 + 1] * ti
		self.dark = np.broadcast_to(dd[:, None], (h, w))
		out = self.paint(P, N, lf.name, TH, S, self)
		if isinstance(out, tuple):
			col, gl = out
		else:
			col = out
			gl = next((g for k, g in self.gloss.items() if lf.name.startswith(k)), 0.25)
		lit = self.bake[0] + self.bake[1] * np.clip(N @ self.light, 0, 1) - 0.12 * np.clip(-N[..., 1], 0, 1)
		col = col * lit[..., None]
		# a wet highlight, painted in (the light from above, the eye in front)
		H = self.light + np.array([0.0, 0.0, -1.0])
		H /= np.linalg.norm(H)
		spec = np.clip(N @ H, 0, 1) ** 18 * np.asarray(gl)
		col = col + spec[..., None] * np.array([0.9, 0.85, 0.75])
		self.tex[y0:y0 + h, x0:x0 + w] = np.clip(col, 0, 1)

	# ------------------------------------------------------------- out
	def write(self, glb_path, png_path):
		write_png(png_path, ps1_colours(self.tex))
		write_glb(self, glb_path)


def ps1_colours(img):
	"""15-bit colour with a 4x4 ordered dither, the way the hardware drew it."""
	bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
	h, w, _ = img.shape
	d = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w, None]
	q = np.floor(np.clip(img * 31.0 + d, 0, 31) + 0.5) / 31.0
	return (q * 255).astype(np.uint8)


def write_png(path, rgb):
	h, w, _ = rgb.shape
	raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def write_glb(M, path):
	m = M.mesh
	names = M.order
	bi = {b: i for i, b in enumerate(names)}
	buf = bytearray()
	views, accessors = [], []

	def add(arr, ctype, typ, target=None, minmax=False):
		arr = np.ascontiguousarray(arr)
		while len(buf) % 4:
			buf.append(0)
		off = len(buf)
		buf.extend(arr.tobytes())
		v = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
		if target:
			v["target"] = target
		views.append(v)
		a = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
		if minmax:
			a["min"] = arr.min(0).tolist()
			a["max"] = arr.max(0).tolist()
		accessors.append(a)
		return len(accessors) - 1
	F32, U16, U32 = 5126, 5123, 5125
	attrs = {
		"POSITION": add(m["verts"].astype(np.float32), F32, "VEC3", 34962, True),
		"NORMAL": add(m["normals"].astype(np.float32), F32, "VEC3", 34962),
		"TEXCOORD_0": add(m["uv"].astype(np.float32), F32, "VEC2", 34962),
		"JOINTS_0": add(m["joints"].astype(np.uint16), U16, "VEC4", 34962),
		"WEIGHTS_0": add(m["weights"].astype(np.float32), F32, "VEC4", 34962),
	}
	idx = add(m["tris"].reshape(-1).astype(np.uint32), U32, "SCALAR", 34963)
	ibm = []
	for b in names:
		mat = np.eye(4)
		mat[:3, 3] = -M.bones[b][1]
		ibm.append(mat.T.reshape(-1))
	ibm_acc = add(np.array(ibm, np.float32), F32, "MAT4")
	nodes = []
	for b in names:
		parent, p = M.bones[b]
		local = p - (M.bones[parent][1] if parent else 0.0)
		nodes.append({"name": b, "translation": [float(x) for x in local]})
	for b in names:
		kids = [bi[c] for c in names if M.bones[c][0] == b]
		if kids:
			nodes[bi[b]]["children"] = kids
	roots = [bi[b] for b in names if M.bones[b][0] is None]
	mesh_node = len(nodes)
	nodes.append({"name": M.name, "mesh": 0, "skin": 0})
	top = len(nodes)
	nodes.append({"name": M.name + "_rig", "children": roots + [mesh_node]})
	gl = {
		"asset": {"version": "2.0", "generator": "put_a_sock_in_it tools/people"},
		"scene": 0, "scenes": [{"nodes": [top]}], "nodes": nodes,
		"meshes": [{"name": M.name, "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]}],
		"materials": [{"name": M.name, "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 1.0}}],
		"skins": [{"joints": list(range(len(names))), "inverseBindMatrices": ibm_acc, "skeleton": roots[0]}],
		"buffers": [{"byteLength": len(buf)}], "bufferViews": views, "accessors": accessors,
	}
	js = json.dumps(gl).encode()
	js += b" " * ((4 - len(js) % 4) % 4)
	while len(buf) % 4:
		buf.append(0)
	with open(path, "wb") as f:
		f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
		f.write(struct.pack("<II", len(js), 0x4E4F534A))
		f.write(js)
		f.write(struct.pack("<II", len(buf), 0x004E4942))
		f.write(bytes(buf))
