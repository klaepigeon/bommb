class_name Door
extends Node3D
## A hinged door: room doors, front doors, cabinet doors (cabinet = true: smaller, never AI routes).
## Local frame: origin at the bottom centre of the opening, X along the opening, +Z / -Z the two
## sides. The panel swings toward `swing` (+1 opens into +Z).
##
## Locks are layered and each is its own problem with its own solutions:
##   locked    keyed lock: key (tag key_tag), pick it (tag "pick", quiet, slow), force it (tag
##             "pry", loud, breaks it for good), or a gunshot through the lock (loud, one round)
##   bolt      a bolt on one side: slide it from that side; from the other, force it (pry)
##   chain     a chain on one side: lift it off from that side; from the other the door opens a
##             hand's width; cut it (tag "cut") or pry the staple out (loud)
##   padlock   a Padlock node on a hasp: its own interactable (see padlock.gd)
##   jammed    scripted: won't open, reason id (the story uses this once)
## A closed door blocks sight and muffles sound (the AI checks `is_closed()`). Heavy things
## against the swing stop it (barricades); Marta shoves them, and pounds through locked doors.

signal tried(door: Door, why: String)   # someone tried to open it and couldn't
signal opened(door: Door)
signal state_changed(door: Door)

@export var width := 0.86
@export var height := 2.02
@export var thickness := 0.045
@export var style := "door_panel"
@export var swing := 1.0
@export var max_angle := 100.0
@export var cabinet := false
@export var door_id := ""

var locked := false
var key_tag := ""
var pickable := true
var bolt_side := 0            # 0 none; +1 / -1: the side it slides from
var bolt_on := false
var chain_side := 0
var chain_on := false
var jammed := ""              # reason id, "" = not jammed
var broken := false
var hp := 100.0
var padlock: Node = null      # Padlock, while fitted and locked it holds the door shut

var open_k := 0.0             # 0 shut .. 1 fully open
var _target := 0.0
var _chain_stop := false
var blocked := false
var pivot: Node3D
var panel: AnimatableBody3D
var hook: Hook
var _light := Color(0.4, 0.4, 0.4)
var _mat: ShaderMaterial
var _speed := 2.2
## what the prompt calls it ("Fridge", "Toy chest")
var display_name := "":
	set(v):
		display_name = v
		if hook:
			hook.display_name = v

func build(light: Color, alter := {}) -> void:
	_light = light
	pivot = Node3D.new(); pivot.name = "Pivot"
	pivot.position = Vector3(-width * 0.5, 0, 0)
	add_child(pivot)
	panel = AnimatableBody3D.new(); panel.name = "Panel"
	panel.collision_layer = 1 | 8          # architecture + doors (the AI's sight rays test layer 1)
	panel.collision_mask = 0
	panel.sync_to_physics = false
	pivot.add_child(panel)
	var mb := MB.new()
	var h := Vector3(width * 0.5 - 0.005, height * 0.5 - 0.005, thickness * 0.5)
	var c := Vector3(width * 0.5, height * 0.5, 0)
	mb.box(style, c, h, Basis.IDENTITY, height if not cabinet else 0.5)
	# handle on both faces, at the free edge
	var hx := width - 0.07
	var hy := minf(1.0, height * 0.5)
	for s in [-1.0, 1.0]:
		mb.box("brass" if not cabinet else "chrome", Vector3(hx, hy, s * (thickness * 0.5 + 0.03)), Vector3(0.05, 0.012, 0.012))
	_mat = Mats.flat(style, light, alter)
	var mats := {style: _mat, "brass": Mats.flat("brass", light, alter), "chrome": Mats.flat("chrome", light, alter)}
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit(mats); panel.add_child(mi)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = h * 2.0
	cs.shape = bs; cs.position = c; panel.add_child(cs)
	hook = Hook.attach(panel, self, "Cupboard" if cabinet else "Door", door_id)
	if door_id != "":
		add_to_group("doors")

func ifocus() -> Vector3:
	return panel.global_transform * Vector3(width - 0.08, minf(1.0, height * 0.5), 0)

func side_of(pos: Vector3) -> int:
	return 1 if to_local(pos).z >= 0.0 else -1

func is_closed() -> bool:
	return open_k < 0.08

## the door itself holds (keyed lock, bolt, padlock, jammed); the chain lets it open a crack
func is_secured_against(side: int) -> bool:
	if broken:
		return false
	if jammed != "" or locked or (padlock and padlock.is_locked()):
		return true
	if bolt_on and side != bolt_side:
		return true
	return false

func _p_side(p: Node) -> int:
	return side_of((p as Node3D).global_position)

func iverbs(p: Node) -> Array:
	var inv: Inventory = p.inv
	var s := _p_side(p)
	var out := []
	if not is_closed() and not _chain_stop:
		return [Interactable.v("toggle", "Close")]
	if broken:
		return [Interactable.v("toggle", "Open")]
	if locked:
		var key := inv.with_tag(key_tag) if key_tag != "" else ""
		if key != "":
			out.append(Interactable.v("unlock", "Unlock (%s)" % ItemDB.item_name(key)))
		else:
			out.append(Interactable.v("toggle", "Open"))
			var pick := inv.with_tag("pick")
			if pickable and pick != "":
				var q := float(ItemDB.get_item(pick).get("quality", {}).get("pick", 1.0))
				out.append(Interactable.v("pick", "Pick the lock (%s)" % ItemDB.item_name(pick), {"time": 5.0 / q, "noise": 1.5}))
	else:
		out.append(Interactable.v("toggle", "Open"))
		if key_tag != "" and inv.with_tag(key_tag) != "":
			out.append(Interactable.v("lock", "Lock it"))
	if bolt_side == s:
		out.append(Interactable.v("bolt", "Slide the bolt back" if bolt_on else "Slide the bolt across"))
	if chain_side == s:
		out.append(Interactable.v("chain", "Lift the chain off" if chain_on else "Put the chain on", {"noise": 2.0}))
	if not cabinet and (locked or (bolt_on and bolt_side != s) or (chain_on and chain_side != s)):
		var pry := inv.with_tag("pry")
		if pry != "":
			var q := float(ItemDB.get_item(pry).get("quality", {}).get("pry", 1.0))
			out.append(Interactable.v("force", "Force it (%s)" % ItemDB.item_name(pry), {"time": 3.5 / q, "noise": 13.0}))
	if chain_on and chain_side != s and inv.with_tag("cut") != "":
		out.append(Interactable.v("cut", "Cut the chain", {"time": 2.0, "noise": 4.0}))
	return out

func iverb(id: String, p: Node) -> void:
	var s := _p_side(p)
	match id:
		"toggle":
			if is_closed() or _chain_stop:
				try_open(s, p)
			else:
				close()
		"unlock":
			locked = false
			Sfx.play_at("bolt", ifocus(), -4.0, 1.2, 2.0)
			Story.record("used:key", {"door": door_id})
			state_changed.emit(self)
			try_open(s, p)
		"lock":
			locked = true
			Sfx.play_at("bolt", ifocus(), -4.0, 1.2, 2.0)
			Story.record("route.locked_door", {"door": door_id})
			state_changed.emit(self)
		"pick":
			locked = false
			Sfx.play_at("bolt", ifocus(), -8.0, 1.4, 1.5)
			Story.record("stealth.picked_lock", {"door": door_id})
			state_changed.emit(self)
		"force":
			_force()
			Story.record("route.forced_door", {"door": door_id})
		"cut":
			chain_on = false; chain_side = 0
			Sfx.play_at("chain", ifocus(), 0.0, 1.0, 4.0)
			state_changed.emit(self)
		"bolt":
			bolt_on = not bolt_on
			Sfx.play_at("bolt", ifocus(), -2.0, 1.0, 3.0)
			if bolt_on:
				Story.record("route.bolted_door", {"door": door_id})
			state_changed.emit(self)
		"chain":
			chain_on = not chain_on
			Sfx.play_at("chain", ifocus(), -4.0, 1.0, 2.0)
			state_changed.emit(self)

func iprogress(id: String, k: float, _p: Node) -> void:
	if id == "force" and fmod(k * 7.0, 1.0) < 0.05:
		Sfx.play_at("scrape", ifocus(), -6.0, 1.3, 10.0, "forcing")
	elif id == "pick" and fmod(k * 9.0, 1.0) < 0.06:
		Sfx.play_at("dry_fire", ifocus(), -16.0, 0.8)

func _force() -> void:
	locked = false
	bolt_on = false
	chain_on = false
	broken = false
	key_tag = ""
	Sfx.play_at("thud_heavy", ifocus(), 2.0, 1.2, 14.0, "forced")
	state_changed.emit(self)

## opening from `side` (+1/-1). Returns true if it started opening.
func try_open(side: int, who: Node = null) -> bool:
	if jammed != "":
		_rattle()
		tried.emit(self, jammed)
		return false
	if is_secured_against(side):
		_rattle()
		if padlock and padlock.is_locked():
			tried.emit(self, "padlock")
		elif locked:
			tried.emit(self, "locked")
		else:
			tried.emit(self, "bolted")
		return false
	_chain_stop = chain_on and side != chain_side
	_target = 0.13 if _chain_stop else 1.0
	if _chain_stop:
		tried.emit(self, "chain")
		Sfx.play_at("chain", ifocus(), -2.0, 1.0, 4.0)
	else:
		Sfx.play_at("door_open", ifocus(), -6.0 if who and who.is_in_group("player") else -2.0, randf_range(0.9, 1.1), 3.0 if not cabinet else 1.0)
	opened.emit(self)
	state_changed.emit(self)
	Events.world_changed.emit(self, "opened")
	return true

func close(slam := false) -> void:
	_target = 0.0
	_chain_stop = false
	state_changed.emit(self)
	Events.world_changed.emit(self, "closed")
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		Sfx.play_at("door_close", ifocus(), 2.0 if slam else -6.0, 1.0, 9.0 if slam else 3.0)

func _rattle() -> void:
	Sfx.play_at("door_locked", ifocus(), -4.0, randf_range(0.9, 1.1), 4.0, "rattle")

func open_instant(k := 1.0) -> void:
	open_k = k; _target = k
	_apply()

func _physics_process(delta: float) -> void:
	if not panel:
		return
	if absf(open_k - _target) < 0.001:
		return
	var step := signf(_target - open_k) * _speed * delta
	var nk := clampf(open_k + step, minf(open_k, _target), maxf(open_k, _target))
	if step > 0.0 and _sweep_blocked(nk):
		blocked = true
		_target = open_k
		if not cabinet:
			Sfx.play_at("thud_light", ifocus(), -6.0, 0.8, 3.0)
			tried.emit(self, "blocked")
		return
	blocked = false
	open_k = nk
	_apply()

func _apply() -> void:
	pivot.rotation.y = -deg_to_rad(max_angle) * open_k * swing

## heavy things in the way of the swing (a barricade) stop it
func _sweep_blocked(nk: float) -> bool:
	if cabinet:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(width * 0.95, height * 0.8, 0.12)
	q.shape = bs
	var b := Basis(Vector3.UP, -deg_to_rad(max_angle) * nk * swing)
	var local := Transform3D(b, Vector3(-width * 0.5, 0, 0)) * Transform3D(Basis.IDENTITY, Vector3(width * 0.5, height * 0.5, 0.0))
	q.transform = global_transform * local
	q.collision_mask = 2          # props
	var mass := 0.0
	for hit in space.intersect_shape(q, 8):
		var rb := hit.collider as RigidBody3D
		if rb:
			mass += rb.mass
	return mass >= 18.0

## Marta: shove what's against it (barricade) toward the room it opens into
func shove(strength: float, from_side: int) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(width, height * 0.8, 1.2)
	q.shape = bs
	q.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, height * 0.5, swing * 0.6))
	q.collision_mask = 2
	for hit in space.intersect_shape(q, 8):
		var rb := hit.collider as RigidBody3D
		if rb:
			rb.apply_central_impulse(global_transform.basis.z * swing * strength + Vector3(randf_range(-1, 1), 0, 0) * strength * 0.3)
	Sfx.play_at("thud_heavy", ifocus(), 0.0, 0.8, 12.0, "pounding")

## Marta: pound a secured door. Returns true when it gives.
func pound(damage: float) -> bool:
	hp -= damage
	Sfx.play_at("thud_heavy", ifocus(), 3.0, randf_range(0.7, 0.9), 16.0, "pounding")
	if hp <= 0.0:
		broken = true
		locked = false; bolt_on = false; chain_on = false; jammed = ""
		if padlock:
			padlock.break_off()
		Sfx.play_at("glass", ifocus(), -6.0, 0.6, 14.0)
		_target = 1.0
		state_changed.emit(self)
		return true
	return false

func get_state() -> Dictionary:
	return {"open": _target, "locked": locked, "bolt": bolt_on, "chain": chain_on, "broken": broken, "hp": hp, "jammed": jammed}

func set_state(d: Dictionary) -> void:
	locked = d.get("locked", locked); bolt_on = d.get("bolt", bolt_on); chain_on = d.get("chain", chain_on)
	broken = d.get("broken", broken); hp = d.get("hp", hp); jammed = d.get("jammed", jammed)
	open_instant(float(d.get("open", 0.0)))
