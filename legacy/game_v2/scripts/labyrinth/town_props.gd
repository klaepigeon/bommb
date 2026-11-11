class_name TownProps
## The street's furniture: what makes it a place people lived in. An advertising column with
## the season's bills (and one older bill half torn away under them), benches, a cart left at
## the kerb, barrels and crates outside the tavern and the bakery, telegraph wires sagging
## across the street, fallen leaves in the gutters.

static func advert_column(k: TownKit, owner: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	k.cyl("paint_green", at, 0.62, 0.3, 12, 0.6)
	k.cyl("trim", at + Vector3(0, 0.3, 0), 0.55, 2.3, 12, 0.55)
	k.cyl("paint_green", at + Vector3(0, 2.6, 0), 0.66, 0.16, 12, 0.66)
	k.cyl("tin", at + Vector3(0, 2.76, 0), 0.62, 0.5, 12, 0.05)
	k.cyl("iron", at + Vector3(0, 3.26, 0), 0.05, 0.25, 6, 0.02)
	# bills round the drum: paper panels, each with its title
	var bills := [["ТЕАТРЪ", "«Чайка»  ·  въ пятницу"], ["ГРАММОФОНЫ", "Патэ  ·  Невскій 24"], ["ЛОТЕРЕЯ", "въ пользу сиротъ"],
		["СЕАНСЪ\nЯСНОВИДѢНІЯ", "М. Соколова"], ["ПИВО", "Калинкинъ"], ["ЦИРКЪ", "Чинизелли"]]
	for i in bills.size():
		var a := TAU * (i + rng.randf() * 0.2) / bills.size()
		var n := Vector3(cos(a), 0, sin(a))
		var t := Vector3(-n.z, 0, n.x)
		var y := at.y + 0.75 + rng.randf() * 0.25
		var c := at + n * 0.565 + Vector3(0, y - at.y, 0)
		var w := 0.42; var h := 0.62
		var torn: bool = i == 3          # the old one, half torn away under the new
		var paper := "paper_old" if torn else "paper"
		k.quad(paper, c - t * w - Vector3(0, h, 0) * 0.5, c + t * w - Vector3(0, h, 0) * 0.5, c + t * w + Vector3(0, h, 0) * 0.5, c - t * w + Vector3(0, h, 0) * 0.5, n)
		for line in 2:
			var l := Label3D.new(); l.text = bills[i][line]
			l.font_size = 40 if line == 0 else 22; l.pixel_size = 0.004
			l.modulate = Color(0.55, 0.1, 0.08) if line == 0 else Color(0.12, 0.1, 0.09)
			if torn: l.modulate = Color(0.25, 0.2, 0.3, 0.85)
			l.outline_size = 0; l.shaded = true; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			owner.add_child(l)
			l.global_transform = Transform3D(Basis(t, Vector3.UP, n), owner.to_global(c + n * 0.004 + Vector3(0, 0.12 if line == 0 else -0.18, 0)))

static func bench(k: TownKit, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for sx in [-0.7, 0.7]:
		k.box("iron", at + b * Vector3(sx, 0.22, 0), Vector3(0.03, 0.22, 0.2), b)
		k.box("iron", at + b * Vector3(sx, 0.62, -0.2), Vector3(0.03, 0.2, 0.03), b)
	for i in 3:
		k.box("wood", at + b * Vector3(0, 0.45, -0.12 + i * 0.12), Vector3(0.85, 0.02, 0.05), b)
	for i in 2:
		k.box("wood", at + b * Vector3(0, 0.62 + i * 0.13, -0.22), Vector3(0.85, 0.05, 0.015), b)

static func barrel(k: TownKit, at: Vector3) -> void:
	k.cyl("wood", at, 0.24, 0.35, 10, 0.29)
	k.cyl("wood", at + Vector3(0, 0.35, 0), 0.29, 0.35, 10, 0.24)
	for y in [0.06, 0.62]:
		k.cyl("iron", at + Vector3(0, y, 0), 0.26 if y < 0.3 else 0.26, 0.04, 10, 0.26)
	k.cyl("iron", at + Vector3(0, 0.33, 0), 0.295, 0.04, 10, 0.295)

static func crate(k: TownKit, at: Vector3, yaw: float, s := 0.25) -> void:
	k.box("wood", at + Vector3(0, s, 0), Vector3(s, s, s), Basis(Vector3.UP, yaw))

## a peasant's cart (telega), shafts down on the cobbles, as if the horse had just been led off
static func cart(k: TownKit, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.box("wood", at + b * Vector3(0, 0.75, 0), Vector3(0.6, 0.04, 1.2), b)
	for sx in [-0.62, 0.62]:
		k.box("wood", at + b * Vector3(sx, 0.92, 0), Vector3(0.03, 0.15, 1.2), b)
	for sz in [-1.22, 1.22]:
		k.box("wood", at + b * Vector3(0, 0.92, sz), Vector3(0.62, 0.15, 0.03), b)
	for wz in [-0.7, 0.75]:
		for sx in [-0.72, 0.72]:
			var c := at + b * Vector3(sx, 0.45, wz)
			var wb := b * Basis(Vector3(0, 0, 1), PI * 0.5)
			k.box("wood", c, Vector3(0.05, 0.06, 0.06), wb)
			# a spoked wheel: a rim of eight segments, eight spokes
			for i in 8:
				var a := TAU * i / 8.0
				var rim := c + b * Vector3(0, cos(a), sin(a)) * 0.42
				k.box("wood", rim, Vector3(0.035, 0.035, 0.17), b * Basis(Vector3(1, 0, 0), a))
				k.box("wood", c + b * Vector3(0, cos(a), sin(a)) * 0.2, Vector3(0.02, 0.2, 0.02), b * Basis(Vector3(1, 0, 0), a))
	for sx in [-0.35, 0.35]:
		k.box("wood", at + b * Vector3(sx, 0.4, 2.0), Vector3(0.035, 0.035, 1.0), b * Basis(Vector3(1, 0, 0), -0.38))

## a wire sagging between two points (telegraph, tram), a chain of thin segments
static func wire(k: TownKit, a: Vector3, b: Vector3, sag := 0.6) -> void:
	const N := 10
	var prev := a
	for i in range(1, N + 1):
		var t := float(i) / N
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var mid := (prev + p) * 0.5; var d := p - prev
		var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
		k.box("iron", mid, Vector3(0.008, 0.008, d.length() * 0.5), basis)
		prev = p

## fallen leaves: flat cut-outs lying on the ground (at.y is the surface), in a drift along `axis`
static func leaves(k: TownKit, at: Vector3, axis: Vector3, length: float, width: float, n: int, rng: RandomNumberGenerator) -> void:
	var side := Vector3.UP.cross(axis).normalized()
	for i in n:
		var p := at + axis * rng.randf_range(-length, length) * 0.5 + side * rng.randf_range(-width, width) * 0.5 * pow(rng.randf(), 1.6)
		var s := rng.randf_range(0.16, 0.34)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var x := b.x * s; var z := b.z * s
		k.quad("leaves", p - x - z, p + x - z, p + x + z, p - x + z, Vector3.UP, p - x - z)
