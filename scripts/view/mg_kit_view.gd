class_name MgKitView
extends MgView
## Shared bits for the custom minigame views: coloured low-poly parts (one white material,
## vertex colours), labels, placing a puppet and making it act.

var white: Material
var glow: Material
var _font: Font


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	white = MB.mat(Tex.solid(Color.WHITE))
	glow = MB.mat(Tex.solid(Color.WHITE), Color.WHITE, Vector2.ONE, true)
	_font = PartyUi.title_font()


func part(build: Callable, parent: Node3D = self) -> MeshInstance3D:
	var mb := MB.new()
	build.call(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	return mi


func node(at: Vector3, parent: Node3D = self) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func label(text: String, at: Vector3, size := 64, col := Color("ffd23f"), parent: Node3D = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.012
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color("1a0b14")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	parent.add_child(l)
	return l


func put(seat: int, at: Vector3, face: Vector3) -> void:
	var c := fig(seat)
	if c.dead or c.is_ghost:
		return
	c.walk_to(at)
	c.look_toward(gv.on_arena(face) if c.get_parent() != gv.table else face)


func act(seat: int, clip: String) -> void:
	if gv.anims.has(seat):
		gv.anims[seat].play(clip)


func name_of(seat: int) -> String:
	return str(gv.view.players[seat].name) if not gv.view.is_empty() else ""
