class_name Door
extends Interactable
## A hinged door between a room and wherever its other side is. Who may pass is not stored on
## the door: it asks World.may_enter() for the room behind it (owners, public hours), so shops
## lock themselves at closing time. Anyone already inside can always open it (a thumb-turn).
## NPCs with access open it as they reach it; it closes after them. Players need access, the
## key, or to pick the lock (which makes a noise people can hear).

const OPEN_ANGLE := 95.0

var id := ""
var room := ""            ## the private side's room id
var key := ""             ## item id that unlocks it ("" = no key)
var width := 1.3
var picked := false       ## lock picked: open to anyone until next closed by an owner
var is_open := false

var _leaf: AnimatableBody3D
var _hinge: Node3D
var _npc_hold := 0.0
var _tween: Tween

func setup(def: Dictionary, leaf_prop: String) -> void:
	id = def.id
	room = def.room
	key = def.get("key", "")
	label = World.rooms[room].name if World.rooms.has(room) else "Door"
	_hinge = Node3D.new()
	_hinge.position.x = -width * 0.5
	add_child(_hinge)
	_leaf = AnimatableBody3D.new()
	_leaf.collision_layer = 8          # doors
	_leaf.collision_mask = 0
	_leaf.sync_to_physics = false
	_leaf.position.x = width * 0.5
	_hinge.add_child(_leaf)
	var vis := Assets.prop(leaf_prop)
	var sz: Vector3 = vis.get_meta("size")
	vis.scale = Vector3(width / maxf(sz.x, 0.01), 2.1 / maxf(sz.y, 0.01), 1.0)
	_leaf.add_child(vis)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 2.1, 0.08)
	cs.shape = box
	cs.position.y = 1.05
	_leaf.add_child(cs)
	# NPCs reaching the doorway
	var sense := Area3D.new()
	sense.collision_layer = 0
	sense.collision_mask = 4           # npc
	var ss := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(width, 2.0, 2.6)
	ss.shape = sb
	ss.position.y = 1.0
	sense.add_child(ss)
	add_child(sense)
	sense.body_entered.connect(_on_npc)

func _physics_process(delta: float) -> void:
	if _npc_hold > 0.0:
		_npc_hold -= delta
		if _npc_hold <= 0.0 and is_open:
			var sense: Area3D = get_child(1) as Area3D
			if sense and sense.has_overlapping_bodies():
				_npc_hold = 1.0
			else:
				set_open(false)

func _on_npc(body: Node) -> void:
	if body.has_method("npc_id") and allows(body.npc_id(), body.global_position):
		set_open(true)
		_npc_hold = 2.0

## May `who` open it from where they stand?
func allows(who: String, from: Vector3) -> bool:
	if World.room_at(from) == room:
		return true
	return picked or World.may_enter(who, room)

func verbs(actor: Node) -> Array[String]:
	if is_open:
		return ["Close"]
	if allows("player", actor.global_position) or (key != "" and actor.has_method("has_item") and actor.has_item(key)):
		return ["Open"]
	return ["Pick lock", "Knock"]

func perform(actor: Node, verb: String) -> void:
	match verb:
		"Open":
			if not allows("player", actor.global_position):
				Sfx.play_at("keys", global_position + Vector3.UP)
			set_open(true)
		"Close":
			set_open(false)
		"Knock":
			for i in 3:
				get_tree().create_timer(i * 0.28).timeout.connect(func(): Sfx.play_at("knock", global_position + Vector3.UP * 1.3, 0.0, 0.03))
			Events.world_event.emit({"kind": "knock", "actor": actor, "position": global_position, "place": room, "loudness": 10.0})
			Events.notice.emit("You knock. Nobody answers." if not _someone_home() else "You knock. Someone moves inside.")
		"Pick lock":
			picked = true
			Sfx.play_at("lockpick", global_position + Vector3.UP)
			Events.world_event.emit({"kind": "lockpick", "actor": actor, "position": global_position, "place": room, "loudness": 6.0})
			Events.notice.emit("The lock gives.")
			set_open(true)

func _someone_home() -> bool:
	for n in World.npcs.values():
		if World.room_at(n.global_position) == room:
			return true
	return false

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	Sfx.play_at("door_open" if open else "door_close", global_position + Vector3.UP)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation_degrees:y", OPEN_ANGLE if open else 0.0, 0.45)
	if not open:
		picked = false

func focus_point() -> Vector3:
	return global_position + Vector3.UP * 1.0
