class_name Telephone
extends Node3D
## A wall telephone with its receiver off the hook, the engaged tone coming out of it, small and
## patient. Hang it up and some while later it rings. Answer it and there's someone breathing, and
## then the tone again. Reusable: Telephone.place(parent, id, at, facing, zone) anywhere.

var id := "phone"
var zone := -1
var _tone: AudioStreamPlayer3D
var _receiver: MeshInstance3D
var _ring_t := -1.0
var _ringing := 0.0

static func place(parent: Node, p_id: String, at: Vector3, facing: Vector3, p_zone: int) -> Telephone:
	var t := Telephone.new(); t.id = p_id; t.zone = p_zone; t.name = "Telephone_" + p_id
	parent.add_child(t)
	t.global_position = at
	t.look_at(at - facing, Vector3.UP)          # -Z faces into the room
	t._build()
	return t

func _hung() -> bool: return World.flag(id + "_hung")

func _build() -> void:
	var k := Kit.new()
	var body := Mats.flat(Color(0.12, 0.1, 0.09), zone)
	k.box(body, Vector3(0, 0, -0.06), Vector3(0.18, 0.24, 0.1))                # the set, on the wall
	k.box(Mats.flat(Color(0.75, 0.72, 0.62), zone), Vector3(0, 0.03, -0.115), Vector3(0.08, 0.08, 0.01))   # the dial
	k.commit(self, "Set")
	var rk := Kit.new()
	rk.box(body, Vector3.ZERO, Vector3(0.05, 0.2, 0.06))
	var r := rk.commit(self, "Receiver")
	_receiver = r[0] if r.size() > 0 else null
	var cord := Kit.new()
	cord.box(Mats.flat(Color(0.08, 0.07, 0.06), zone), Vector3(0, -0.36, -0.12), Vector3(0.012, 0.62, 0.012))
	cord.commit(self, "Cord")
	_tone = Audio.loop("engaged", self, -80.0, 1.2)
	var u := Usable.make(self, global_transform.translated_local(Vector3(0, -0.2, -0.1)), Vector3(0.3, 0.7, 0.3), [])
	u.title = "Telephone"
	u.offer = func(_k):
		if _ringing > 0.0: return [{"id": "answer", "label": "Answer"}]
		return [{"id": "listen", "label": "Listen"}, {"id": "hang", "label": "Hang up"}] if not _hung() else [{"id": "lift", "label": "Lift the receiver"}]
	u.acted.connect(_act)
	_sync()

func _sync() -> void:
	if _receiver:
		_receiver.position = Vector3(0, -0.02, -0.13) if _hung() else Vector3(0.0, -0.72, -0.14)
		_receiver.rotation = Vector3.ZERO if _hung() else Vector3(0.3, 0, 0.2)
	if _tone: _tone.volume_db = -80.0 if _hung() else -18.0

func _act(v: String, _k) -> void:
	match v:
		"listen":
			Audio.play("engaged", global_position, -8.0)
			Speech.say("kurt", "Engaged. Whoever she was calling, she never got through. Or she did, and they never hung up.", {"style": "quiet"})
		"hang":
			World.set_flag(id + "_hung", true); _sync()
			Audio.play("clink", global_position, -6.0)
			Noises.make(global_position, 2.0, "phone", self)
			_ring_t = randf_range(35.0, 70.0)
		"lift":
			World.set_flag(id + "_hung", false); _sync()
		"answer":
			_ringing = 0.0
			World.set_flag(id + "_hung", false); _sync()
			World.emit_event("phone_answered", {"id": id})
			Audio.play("breath", global_position, -10.0, 0.8)
			Speech.say("kurt", "Hello? ...Someone breathing. Close to the mouthpiece. Then the tone again.", {"style": "quiet"})

func _process(delta: float) -> void:
	if _ring_t > 0.0 and _hung():
		_ring_t -= delta
		if _ring_t <= 0.0: _ringing = 14.0
	if _ringing > 0.0:
		var before := _ringing
		_ringing -= delta
		if fmod(before, 3.0) < fmod(_ringing, 3.0) or before == 14.0:
			Audio.play("ring", global_position, -4.0)
			Noises.make(global_position, 14.0, "phone", self)    # loud enough to bring things
		if _ringing <= 0.0: _ringing = 0.0
