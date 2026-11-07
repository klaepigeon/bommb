class_name DeadRat
extends RefCounted
## The Dead Rat: the collectible. Grey-brown, stiff, legs in the air, a long bald tail,
## X for eyes. Disgusting and, somehow, worth having.

static var _mesh: ArrayMesh


static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var mb := LcMB.new()
	var fur := LcMB.mat(LcTex.grime(Color("5a4a40"), Color("8a7868"), 16, 77, 0.5))
	var pink := LcMB.mat(LcTex.grime(Color("c88a8a"), Color("e8aaaa"), 16, 78, 0.4))
	var black := LcMB.mat(LcTex.solid(Color("140c0a")))
	# on its back
	mb.sphere("b", fur, 0.22, 4, 8, LcMB.T(Vector3(0, 0.16, 0)), Color(1, 1, 1), Vector3(1.0, 0.75, 1.6))
	mb.sphere("h", fur, 0.13, 3, 6, LcMB.T(Vector3(0, 0.16, 0.36)), Color(1, 1, 1), Vector3(1.0, 0.9, 1.3))
	mb.cyl("n", pink, 0.05, 0.0, 0.12, 5, LcMB.T(Vector3(0, 0.15, 0.5), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		mb.cyl("e", pink, 0.05, 0.05, 0.02, 6, LcMB.T(Vector3(0.09 * sx, 0.26, 0.32), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
		mb.box("x", black, Vector3(0.05, 0.012, 0.012), LcMB.T(Vector3(0.05 * sx, 0.22, 0.47), Vector3(0, 0, 0.7)), Color(1, 1, 1))
		mb.box("x", black, Vector3(0.05, 0.012, 0.012), LcMB.T(Vector3(0.05 * sx, 0.22, 0.47), Vector3(0, 0, -0.7)), Color(1, 1, 1))
		for z in [-0.18, 0.18]:
			mb.box("l", pink, Vector3(0.03, 0.18, 0.03), LcMB.T(Vector3(0.11 * sx, 0.36, z), Vector3(0, 0, 0.3 * sx)), Color(1, 1, 1))
	for k in 6:
		mb.box("t", pink, Vector3(0.025, 0.025, 0.14), LcMB.T(Vector3(sin(k * 0.6) * 0.06, 0.1, -0.38 - k * 0.12)), Color(1, 1, 1))
	_mesh = mb.build()
	return _mesh
