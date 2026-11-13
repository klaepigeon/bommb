"""The sculpting kit for the building's inhabitants (docs/PEOPLE.md).

A body is sculpted as a signed distance field: shapes (capsules, ellipsoids) each pinned to a bone,
blended into one continuous skin (smooth union), carved (the mouth, the eye sockets, the navel),
and pushed in and out (folds, lumps, cellulite). The field is turned into a mesh (surface nets,
then projected back onto the true surface), painted per vertex (each shape's colour, blended;
ambient occlusion from the field itself; spots, hair, veins, sores from the character's own paint
function) and skinned (each vertex weighted to the bones of the shapes it came from, smoothed).
Written out as a glTF (.glb) with a skeleton whose bones are the game's joints (FleshBody's: hips
spine chest neck head jaw sh_* el_* ex_* hip_* kn_*, and belly for the jiggle), at rest with no
rotation, so the game's poses (euler offsets per joint) mean the same thing on these bodies.

The file is a normal glb: open it in Blender, resculpt it by hand, keep the bone names, export it
back over the same path, and the game uses yours.

Only numpy. Run people.py, not this.
"""
import json
import struct

import numpy as np


# ------------------------------------------------------------------ noise
def _hash(ix, iy, iz, seed):
	h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)).astype(np.float64) / 4294967295.0


def vnoise(P, freq, seed=0):
	"""Smooth value noise in [-1, 1] at points P (N,3)."""
	q = P * freq
	i = np.floor(q).astype(np.int64)
	f = q - i
	u = f * f * (3.0 - 2.0 * f)
	out = 0.0
	for dx in (0, 1):
		for dy in (0, 1):
			for dz in (0, 1):
				w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
				out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
	return out * 2.0 - 1.0


def fbm(P, freq, octaves=3, seed=0):
	s = 0.0
	a = 1.0
	t = 0.0
	for o in range(octaves):
		s = s + a * vnoise(P, freq * (2.0 ** o), seed + o * 17)
		t += a
		a *= 0.5
	return s / t


def cells(P, freq, seed=0):
	"""Distance to the nearest of a jittered lattice of points (0 at a point, ~1 far): spots."""
	q = P * freq
	i = np.floor(q).astype(np.int64)
	best = np.full(len(P), 9.0)
	for dx in (-1, 0, 1):
		for dy in (-1, 0, 1):
			for dz in (-1, 0, 1):
				c = i + np.array([dx, dy, dz])
				j = np.stack([_hash(c[:, 0], c[:, 1], c[:, 2], seed + k) for k in range(3)], 1)
				d = np.linalg.norm(q - (c + j), axis=1)
				best = np.minimum(best, d)
	return best


# ------------------------------------------------------------------ distance functions
def d_capsule(P, a, b, ra, rb):
	a = np.asarray(a, float)
	b = np.asarray(b, float)
	ba = b - a
	t = np.clip(((P - a) @ ba) / max(1e-9, ba @ ba), 0.0, 1.0)
	return np.linalg.norm(P - (a + t[:, None] * ba), axis=1) - (ra + (rb - ra) * t)


def _rot(euler):
	x, y, z = euler
	cx, sx, cy, sy, cz, sz = np.cos(x), np.sin(x), np.cos(y), np.sin(y), np.cos(z), np.sin(z)
	Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
	Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
	Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
	return Ry @ Rx @ Rz


def d_ellipsoid(P, c, r, rot=None):
	q = P - np.asarray(c, float)
	if rot is not None:
		q = q @ _rot(rot)          # (into the ellipsoid's frame: the inverse of R, applied as row vectors)
	r = np.asarray(r, float)
	k0 = np.linalg.norm(q / r, axis=1)
	k1 = np.linalg.norm(q / (r * r), axis=1)
	return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def smin(a, b, k):
	if k <= 0:
		return np.minimum(a, b)
	h = np.maximum(k - np.abs(a - b), 0.0) / k
	return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
	return -smin(-a, -b, k)


# ------------------------------------------------------------------ the sculpt
class Shape:
	def __init__(self, kind, args, bone, color, wet=0.0, rot=None):
		self.kind = kind
		self.args = args
		self.bone = bone
		self.color = np.asarray(color, float)
		self.wet = wet
		self.rot = rot
		self.tag = None

	def dist(self, P):
		if self.kind == "cap":
			return d_capsule(P, *self.args)
		return d_ellipsoid(P, self.args[0], self.args[1], self.rot)

	def bounds(self):
		if self.kind == "cap":
			a, b, ra, rb = self.args
			r = max(ra, rb)
			lo = np.minimum(a, b) - r
			hi = np.maximum(a, b) + r
		else:
			c, rr = self.args
			r = max(rr)
			lo = np.asarray(c) - r
			hi = np.asarray(c) + r
		return np.asarray(lo, float), np.asarray(hi, float)


class Sculpt:
	"""Groups of shapes (each smooth-unioned inside, then joined to the body with its own
	blend), displacements, carves (smooth subtraction), then details (teeth, eyes: not carved)."""

	def __init__(self, name):
		self.name = name
		self.bones = {}          # name -> (parent or None, world position)
		self.order = []
		self.groups = []         # [k, join, [Shape]]
		self.carves = []         # [k, Shape-like]
		self.details = []        # [k, Shape]
		self.disps = []          # f(P) -> delta d (positive pushes in)
		self.paint = None        # f(P, N, col, wet, ctx) -> (col, wet)
		self.ao_strength = 1.0

	# bones
	def bone(self, name, parent, pos):
		self.bones[name] = (parent, np.asarray(pos, float))
		self.order.append(name)
		return np.asarray(pos, float)

	# shapes
	def group(self, k=0.03, join=0.03):
		g = [k, join, []]
		self.groups.append(g)
		return g[2]

	@staticmethod
	def cap(a, b, ra, rb, bone, color, wet=0.0):
		return Shape("cap", (np.asarray(a, float), np.asarray(b, float), ra, rb), bone, color, wet)

	@staticmethod
	def ell(c, r, bone="head", color=(0, 0, 0), wet=0.0, rot=None):
		return Shape("ell", (np.asarray(c, float), np.asarray(r, float)), bone, color, wet, rot)

	def carve(self, shape, k=0.01):
		self.carves.append([k, shape])

	def detail(self, shape, k=0.004):
		self.details.append([k, shape])

	def all_shapes(self):
		out = [s for g in self.groups for s in g[2]]
		out += [d[1] for d in self.details]
		return out

	# the field
	def sdf(self, P):
		d = None
		for k, join, shapes in self.groups:
			if not shapes:
				continue
			dg = shapes[0].dist(P)
			for s in shapes[1:]:
				dg = smin(dg, s.dist(P), k)
			d = dg if d is None else smin(d, dg, join)
		for f in self.disps:
			d = d + f(P)
		for k, s in self.carves:
			d = smax(d, -s.dist(P), k)
		for k, s in self.details:
			d = smin(d, s.dist(P), k)
		return d

	def grad(self, P, h):
		e = np.eye(3) * h
		g = np.stack([self.sdf(P + e[i]) - self.sdf(P - e[i]) for i in range(3)], 1) / (2 * h)
		return g

	# --------------------------------------------------------------- the mesh
	def bake(self, voxel=0.012, smooth_weights=3, soft=0.02):
		lo = np.min([s.bounds()[0] for s in self.all_shapes()], 0) - 0.06
		hi = np.max([s.bounds()[1] for s in self.all_shapes()], 0) + 0.06
		n = np.ceil((hi - lo) / voxel).astype(int) + 1
		xs = [lo[i] + np.arange(n[i]) * voxel for i in range(3)]
		G = np.stack(np.meshgrid(*xs, indexing="ij"), -1).reshape(-1, 3)
		F = np.concatenate([self.sdf(G[i:i + 400000]) for i in range(0, len(G), 400000)]).reshape(n)
		del G
		verts, tris = surface_nets(F, lo, voxel)
		# onto the true surface
		for _ in range(3):
			d = self.sdf(verts)
			g = self.grad(verts, voxel * 0.25)
			gg = np.maximum((g * g).sum(1), 1e-6)
			step = (d / gg)[:, None] * g
			nrm = np.linalg.norm(step, axis=1, keepdims=True)
			step = np.where(nrm > voxel * 0.6, step / np.maximum(nrm, 1e-9) * voxel * 0.6, step)
			verts = verts - step
		normals = self.grad(verts, voxel * 0.5)
		normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
		# winding: outward
		a, b, c = verts[tris[:, 0]], verts[tris[:, 1]], verts[tris[:, 2]]
		fn = np.cross(b - a, c - a)
		flip = (fn * normals[tris].mean(1)).sum(1) < 0
		tris[flip] = tris[flip][:, [0, 2, 1]]
		area = np.linalg.norm(fn, axis=1)
		tris = tris[area > 1e-12]
		# what each vertex is made of
		shapes = self.all_shapes()
		D = np.stack([s.dist(verts) for s in shapes], 1)
		dmin = D.min(1, keepdims=True)
		W = np.exp(-(D - dmin) / 0.006)
		W /= W.sum(1, keepdims=True)
		col = W @ np.stack([s.color for s in shapes])
		wet = W @ np.array([s.wet for s in shapes])
		ao = self.ambient(verts, normals)
		ctx = {"D": D, "shapes": shapes, "ao": ao}
		if self.paint:
			col, wet = self.paint(verts, normals, col, wet, ctx)
		col = col * (0.35 + 0.65 * ao[:, None]) ** self.ao_strength
		# skin weights: per bone, the nearest of its shapes; soft across joints; smoothed on the mesh
		names = self.order
		bi = {b: i for i, b in enumerate(names)}
		BD = np.full((len(verts), len(names)), 9.0)
		for j, s in enumerate(shapes):
			BD[:, bi[s.bone]] = np.minimum(BD[:, bi[s.bone]], D[:, j])
		BW = np.exp(-(BD - BD.min(1, keepdims=True)) / soft)
		BW /= BW.sum(1, keepdims=True)
		e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
		e = np.concatenate([e, e[:, ::-1]])
		cnt = np.bincount(e[:, 0], minlength=len(verts)).astype(float)
		for _ in range(smooth_weights):
			acc = np.zeros_like(BW)
			np.add.at(acc, e[:, 0], BW[e[:, 1]])
			BW = 0.5 * BW + 0.5 * acc / np.maximum(cnt, 1)[:, None]
		top = np.argsort(-BW, 1)[:, :4]
		tw = np.take_along_axis(BW, top, 1)
		tw[tw < 0.02] = 0.0
		tw /= tw.sum(1, keepdims=True)
		self.mesh = dict(verts=verts, normals=normals, tris=tris, col=np.clip(col, 0, 1), wet=np.clip(wet, 0, 1), joints=top, weights=tw)
		print(f"  {self.name}: {len(verts)} verts, {len(tris)} tris, grid {tuple(n)}")
		return self.mesh

	def ambient(self, P, N):
		occ = np.zeros(len(P))
		for i, h in enumerate([0.012, 0.025, 0.05, 0.09, 0.15]):
			d = self.sdf(P + N * h)
			occ += (0.75 ** i) * np.clip((h - d) / h, 0, 1)
		return np.clip(1.0 - occ * 0.45, 0.0, 1.0)

	# --------------------------------------------------------------- out
	def write_glb(self, path):
		m = self.mesh
		names = self.order
		bi = {b: i for i, b in enumerate(names)}
		buf = bytearray()
		views = []
		accessors = []

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
			"COLOR_0": add(np.concatenate([m["col"], np.ones((len(m["col"]), 1))], 1).astype(np.float32), F32, "VEC4", 34962),
			# the rest position, for detail that stays on the skin when it moves (shaders/flesh.gdshader)
			"TEXCOORD_0": add(m["verts"][:, :2].astype(np.float32), F32, "VEC2", 34962),
			"TEXCOORD_1": add(np.stack([m["verts"][:, 2], m["wet"]], 1).astype(np.float32), F32, "VEC2", 34962),
			"JOINTS_0": add(m["joints"].astype(np.uint16), U16, "VEC4", 34962),
			"WEIGHTS_0": add(m["weights"].astype(np.float32), F32, "VEC4", 34962),
		}
		idx = add(m["tris"].reshape(-1).astype(np.uint32), U32, "SCALAR", 34963)
		ibm = []
		for b in names:
			p = self.bones[b][1]
			mat = np.eye(4)
			mat[:3, 3] = -p
			ibm.append(mat.T.reshape(-1))          # column-major
		ibm_acc = add(np.array(ibm, np.float32), F32, "MAT4")
		nodes = []
		for b in names:
			parent, p = self.bones[b]
			local = p - (self.bones[parent][1] if parent else 0.0)
			nodes.append({"name": b, "translation": [float(x) for x in local]})
		for b in names:
			kids = [bi[c] for c in names if self.bones[c][0] == b]
			if kids:
				nodes[bi[b]]["children"] = kids
		roots = [bi[b] for b in names if self.bones[b][0] is None]
		mesh_node = len(nodes)
		nodes.append({"name": self.name, "mesh": 0, "skin": 0})
		top = len(nodes)
		nodes.append({"name": self.name + "_rig", "children": roots + [mesh_node]})
		gl = {
			"asset": {"version": "2.0", "generator": "put_a_sock_in_it tools/sculpt"},
			"scene": 0,
			"scenes": [{"nodes": [top]}],
			"nodes": nodes,
			"meshes": [{"name": self.name, "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]}],
			"materials": [{"name": "flesh", "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.8}}],
			"skins": [{"joints": list(range(len(names))), "inverseBindMatrices": ibm_acc, "skeleton": roots[0]}],
			"buffers": [{"byteLength": len(buf)}],
			"bufferViews": views,
			"accessors": accessors,
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


# ------------------------------------------------------------------ surface nets
_CORNERS = np.array([[i & 1, (i >> 1) & 1, (i >> 2) & 1] for i in range(8)])
_EDGES = [(a, b) for a in range(8) for b in range(a + 1, 8) if np.abs(_CORNERS[a] - _CORNERS[b]).sum() == 1]


def surface_nets(F, lo, v):
	nx, ny, nz = F.shape
	acc = np.zeros((nx - 1, ny - 1, nz - 1, 3))
	cnt = np.zeros((nx - 1, ny - 1, nz - 1))
	def corner(c):
		return F[c[0]:nx - 1 + c[0], c[1]:ny - 1 + c[1], c[2]:nz - 1 + c[2]]
	for a, b in _EDGES:
		fa, fb = corner(_CORNERS[a]), corner(_CORNERS[b])
		x = (fa < 0) != (fb < 0)
		t = np.where(x, fa / np.where(x, fa - fb, 1.0), 0.0)
		pos = _CORNERS[a][None, None, None, :] + t[..., None] * (_CORNERS[b] - _CORNERS[a])[None, None, None, :]
		acc += pos * x[..., None]
		cnt += x
	active = cnt > 0
	vid = np.full(cnt.shape, -1, np.int64)
	vid[active] = np.arange(active.sum())
	ii = np.argwhere(active)
	verts = lo + (ii + acc[active] / cnt[active][:, None]) * v
	quads = []
	inside = F < 0
	# an edge along axis `ax` from grid point p with a sign change -> the 4 cells around it
	for ax in range(3):
		o1, o2 = [a for a in range(3) if a != ax]
		sl0 = [slice(0, F.shape[i]) for i in range(3)]
		sl0[ax] = slice(0, F.shape[ax] - 1)
		sl1 = list(sl0)
		sl1[ax] = slice(1, F.shape[ax])
		ch = inside[tuple(sl0)] != inside[tuple(sl1)]
		pts = np.argwhere(ch)
		pts = pts[(pts[:, o1] >= 1) & (pts[:, o2] >= 1) & (pts[:, o1] <= F.shape[o1] - 2) & (pts[:, o2] <= F.shape[o2] - 2)]
		def cellid(d1, d2):
			c = pts.copy()
			c[:, o1] -= d1
			c[:, o2] -= d2
			return vid[c[:, 0], c[:, 1], c[:, 2]]
		q = np.stack([cellid(1, 1), cellid(0, 1), cellid(0, 0), cellid(1, 0)], 1)
		quads.append(q[(q >= 0).all(1)])
	q = np.concatenate(quads)
	# split along the shorter diagonal
	d02 = np.linalg.norm(verts[q[:, 0]] - verts[q[:, 2]], axis=1)
	d13 = np.linalg.norm(verts[q[:, 1]] - verts[q[:, 3]], axis=1)
	a = d02 <= d13
	t1 = np.where(a[:, None], q[:, [0, 1, 2]], q[:, [0, 1, 3]])
	t2 = np.where(a[:, None], q[:, [0, 2, 3]], q[:, [1, 2, 3]])
	return verts, np.concatenate([t1, t2])
