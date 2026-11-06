class_name Flashboard
extends Node3D
## The flashboard over the stage, the kind every bingo hall has: lamp bulbs behind smoked
## glass, hung on chains. Left window: where we are (ROUND 03, BOOK II). Middle: the twenty
## numbers of a d20, and every number rolled this round lights up. Right window: the FILE,
## his suspicion of you, which blinks when it gets high.

const W := 200
const H := 52
const FONT := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
}
const AMBER := Color("ffc860")
const RED := Color("ff4a2a")
const DIM := Color("2a1a10")

var img: Image
var tex: ImageTexture
var left_label := "LAST"
var left_value := "CALL"
var right_label := "FILE"
var right_value := "00"
var hot := false
var lit: Dictionary = {}       # d20 number -> fade (1 = just rolled)
var _blink := 0.0
var _dirty := true

func _ready() -> void:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(img)
	var black := MB.mat(Tex.grime(Color("0e0c0a"), Color("1a1612"), 16, 30, 0.3))
	var brass := MB.mat(Tex.brass(31))
	var chain := MB.mat(Tex.grime(Color("4a4a46"), Color("6a6a64"), 16, 32, 0.3))
	var mb := MB.new()
	var bw := 3.9
	var bh := bw * float(H) / W
	mb.box("k", black, Vector3(bw + 0.12, bh + 0.12, 0.1), MB.T(Vector3(0, 0, -0.06)), Color(1, 1, 1))
	for y in [bh / 2 + 0.07, -bh / 2 - 0.07]:
		mb.box("b", brass, Vector3(bw + 0.2, 0.05, 0.14), MB.T(Vector3(0, y, -0.04)), Color(1, 1, 1))
	for x in [bw / 2 + 0.08, -bw / 2 - 0.08]:
		mb.box("b", brass, Vector3(0.05, bh + 0.2, 0.14), MB.T(Vector3(x, 0, -0.04)), Color(0.9, 0.9, 0.9))
		# chains up to the ceiling
		for k in range(10):
			mb.box("c", chain, Vector3(0.025, 0.09, 0.012 if k % 2 == 0 else 0.025), MB.T(Vector3(x * 0.8, bh / 2 + 0.16 + k * 0.1, -0.06)), Color(1, 1, 1))
	var face := ShaderMaterial.new()
	face.shader = MB.PSX_UNLIT
	face.set_shader_parameter("albedo_tex", tex)
	face.set_shader_parameter("albedo", Color(1, 1, 1))
	face.set_shader_parameter("snap_res", MB.snap_default)
	mb.quad("f", face, Vector3(-bw / 2, -bh / 2, 0), Vector3(bw / 2, -bh / 2, 0), Vector3(bw / 2, bh / 2, 0), Vector3(-bw / 2, bh / 2, 0), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb050")
	glow.light_energy = 0.35
	glow.omni_range = 2.6
	glow.position = Vector3(0, -0.3, 0.6)
	add_child(glow)
	redraw()

func set_left(label: String, value: String) -> void:
	if label != left_label or value != left_value:
		left_label = label
		left_value = value
		_dirty = true

func set_right(label: String, value: String, is_hot := false) -> void:
	if label != right_label or value != right_value or is_hot != hot:
		right_label = label
		right_value = value
		hot = is_hot
		_dirty = true

## Light a d20 number (it fades over the next few rolls, not at once).
func light(n: int) -> void:
	if n < 1 or n > 20:
		return
	age_lights()
	lit[n] = 1.0

func clear_lights() -> void:
	lit.clear()
	_dirty = true

func _process(delta: float) -> void:
	if hot:
		_blink += delta
		if fmod(_blink, 0.9) < delta:
			_dirty = true
	if _dirty:
		redraw()

func redraw() -> void:
	_dirty = false
	img.fill(Color("0a0806"))
	# left window: label in small bulbs, value in big
	_text(left_label, 6, 5, 1, AMBER.darkened(0.15))
	_text(left_value, 6, 18, 2, AMBER)
	# middle: the twenty faces of a d20 in a 5 x 4 grid; a rolled number's cell lights up
	var mx := 68
	for n in range(1, 21):
		var col := (n - 1) % 5
		var row := (n - 1) / 5
		var x := mx + col * 14
		var y := 5 + row * 11
		var on: float = lit.get(n, 0.0)
		if on > 0.0:
			for yy in range(y, y + 10):
				for xx in range(x, x + 13):
					img.set_pixel(xx, yy, DIM.lerp(AMBER.darkened(0.35), on))
		var t := str(n)
		var tw := Tex.digits_width(t, 1)
		Tex.draw_digits(img, t, x + (13 - tw) / 2, y + 3, 1, Color("fff0c0") if on > 0.0 else Color("5a3a1e"))
	# right window: the FILE
	var blink_off := hot and fmod(_blink, 0.9) > 0.6
	var rc := RED if hot else AMBER
	_text(right_label, 146, 5, 1, rc.darkened(0.15))
	if not blink_off:
		_text(right_value, 146, 18, 2, rc)
	tex.update(img)

func _bulb(x: int, y: int, c: Color, on: bool) -> void:
	if x < 0 or y < 0 or x >= W - 1 or y >= H - 1:
		return
	img.set_pixel(x, y, c)
	if on:
		img.set_pixel(x + 1, y, c.darkened(0.25))
		img.set_pixel(x, y + 1, c.darkened(0.25))
		img.set_pixel(x + 1, y + 1, c.darkened(0.45))

func _bulb_disc(cx: int, cy: int, r: int, c: Color, on: bool) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := Vector2(x - cx, y - cy).length()
			if d <= r + 0.2 and x >= 0 and y >= 0 and x < W and y < H:
				img.set_pixel(x, y, c.lightened(0.35) if on and d < r * 0.4 else c)

## Bulb-matrix text: every lit pixel of the 5x7 glyph is a bulb; unlit ones show faintly.
func _text(s: String, x0: int, y0: int, scale: int, c: Color) -> void:
	var x := x0
	var step := 2 * scale
	for ch in s.to_upper():
		if ch == " ":
			x += 3 * step
			continue
		var g: Array = FONT.get(ch, FONT["?"])
		for gy in range(7):
			for gx in range(5):
				var on: bool = g[gy][gx] == "1"
				var px := x + gx * step
				var py := y0 + gy * step
				if on:
					_bulb(px, py, c, true)
					if scale > 1:
						_bulb(px + 1, py, c, true)
						_bulb(px, py + 1, c, true)
						_bulb(px + 1, py + 1, c, true)
				elif scale > 1:
					_bulb(px, py, DIM, false)
		x += 6 * step

## Every roll fades the older lights a little, so the board shows the recent ones brightest.
func age_lights() -> void:
	for k in lit.keys():
		lit[k] = float(lit[k]) * 0.8
		if lit[k] < 0.25:
			lit.erase(k)
	_dirty = true
