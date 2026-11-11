class_name Fixtures
## Small static interactables, each its own inner class:
##   Drawer      slides out; its contents ride in it (frozen until taken)
##   HideSpot    a place to hide (wardrobe, under a bed, the bath); the AI may check it
##   Readable    a document fixed in place (a note on the fridge, the notice on the wall)
##   Breakable   a static obstacle with durability: struck with a tool, shot, hit by thrown things
##   Padlock     a padlock on a hasp holding a door shut
##   Trigger     an Area3D that calls back when the player enters (story beats, room tracking)


class Drawer:
	extends Node3D
	signal state_changed(d: Drawer)
	var depth := 0.4
	var body: AnimatableBody3D
	var open_k := 0.0
	var _target := 0.0
	var drawer_id := ""
	var locked := false
	var key_tag := ""

	func setup(p_body: AnimatableBody3D, p_depth: float, p_id := "") -> void:
		body = p_body
		depth = p_depth
		drawer_id = p_id
		Hook.attach(body, self, "Drawer", p_id)

	func iverbs(p: Node) -> Array:
		if locked:
			if key_tag != "" and p.inv.with_tag(key_tag) != "":
				return [Interactable.v("unlock", "Unlock")]
			var pick: String = p.inv.with_tag("pry")
			var out := [Interactable.v("open", "Open")]
			if pick != "":
				out.append(Interactable.v("force", "Prise it open (%s)" % ItemDB.item_name(pick), {"time": 1.5, "noise": 6.0}))
			return out
		return [Interactable.v("open", "Close" if _target > 0.5 else "Open")]

	func iverb(id: String, _p: Node) -> void:
		if id == "unlock" or id == "force":
			locked = false
			Sfx.play_at("bolt" if id == "unlock" else "scrape", body.global_position, -4.0, 1.3, 2.0 if id == "unlock" else 6.0)
			if id == "force":
				Story.record("route.forced_drawer")
			return
		if locked:
			Sfx.play_at("door_locked", body.global_position, -8.0, 1.4, 2.0)
			return
		_target = 0.0 if _target > 0.5 else 1.0
		Sfx.play_at("drawer", body.global_position, -6.0, randf_range(0.9, 1.15), 2.5)
		state_changed.emit(self)
		Events.world_changed.emit(self, "drawer")

	func ifocus() -> Vector3:
		return body.global_position

	func _physics_process(delta: float) -> void:
		if body and absf(open_k - _target) > 0.001:
			open_k = move_toward(open_k, _target, delta * 2.5)
			body.position.z = -open_k * depth * 0.8

	func get_state() -> Dictionary:
		return {"open": _target, "locked": locked}

	func set_state(d: Dictionary) -> void:
		_target = float(d.get("open", 0.0)); open_k = _target; locked = d.get("locked", locked)
		if body: body.position.z = -open_k * depth * 0.8


class HideSpot:
	extends Node3D
	## The camera sits at this node's transform while hidden. `exit` is where Kurt steps out.
	var kind := "wardrobe"          # wardrobe | bed | bath | closet
	var exit_pos := Vector3.ZERO
	var occupant: Node = null
	var spot_id := ""
	var crouched := false           # under a bed: the view is low and narrow
	var door: Door = null           # wardrobe doors close on you (and open when she checks)

	func iverbs(p: Node) -> Array:
		if occupant:
			return []
		if door and not door.is_closed() and door.open_k < 0.5:
			return [Interactable.v("hide", "Hide inside")]
		var label: String = {"wardrobe": "Hide inside", "bed": "Crawl under", "bath": "Lie down in the bath", "closet": "Squeeze in"}.get(kind, "Hide")
		return [Interactable.v("hide", label)]

	func iverb(id: String, p: Node) -> void:
		if id == "hide" and occupant == null:
			p.hide_in(self)

	func ifocus() -> Vector3:
		return global_position

	func enter(p: Node) -> void:
		occupant = p
		if door:
			door.close()
		Story.record("stealth.hid", {"spot": spot_id})

	func leave() -> void:
		occupant = null
		if door:
			door.try_open(door.side_of(global_transform * exit_pos))

	## the AI opens it up: returns the occupant if anyone's inside
	func search() -> Node:
		if door:
			door.try_open(door.side_of(global_position + global_transform.basis.z * 2.0))
		Sfx.play_at("door_open" if door else "scrape", global_position, 0.0, 0.7, 4.0)
		return occupant


class Readable:
	extends Node3D
	var doc_id := ""

	func iverbs(_p: Node) -> Array:
		return [Interactable.v("read", "Read")]

	func iverb(_id: String, _p: Node) -> void:
		Events.show_document.emit(doc_id)


class Breakable:
	extends Node3D
	## A static obstacle that can be destroyed: a boarded-up hole, a panel, glass. The way through
	## is whatever has enough force: a striking tool (hold, loud), a gunshot, a heavy thing thrown.
	signal broke(b: Breakable)
	var hp := 60.0
	var label := "Smash it"
	var break_id := ""
	var sound := "thud_heavy"
	var body: StaticBody3D
	var unscrew := false            # can be taken off quietly with a screwdriver instead
	var done := false

	func iverbs(p: Node) -> Array:
		if done:
			return []
		var out := []
		var strike: String = p.inv.with_tag("strike")
		if strike != "":
			var q := float(ItemDB.get_item(strike).get("quality", {}).get("strike", 1.0))
			out.append(Interactable.v("strike", "%s (%s)" % [label, ItemDB.item_name(strike)], {"time": hp / 40.0 / q, "noise": 12.0}))
		if unscrew and p.inv.with_tag("unscrew") != "":
			out.append(Interactable.v("unscrew", "Unscrew it", {"time": 5.0, "noise": 1.0}))
		if out.is_empty():
			out.append(Interactable.v("kick", "Kick it", {"noise": 8.0}))
		return out

	func iverb(id: String, p: Node) -> void:
		match id:
			"strike":
				Story.record("route.smashed:" + break_id)
				smash()
			"unscrew":
				Story.record("route.unscrewed:" + break_id)
				Sfx.play_at("metal", global_position, -8.0, 1.4, 1.0)
				_remove()
			"kick":
				if p.has_method("kick"): p.kick()
				damage(12.0)

	func iprogress(id: String, k: float, _p: Node) -> void:
		if id == "strike" and fmod(k * 5.0, 1.0) < 0.05:
			Sfx.play_at(sound, global_position, 0.0, randf_range(0.8, 1.1), 12.0, "smash")

	func ifocus() -> Vector3:
		return global_position

	func damage(a: float) -> void:
		if done:
			return
		hp -= a
		Sfx.play_at(sound, global_position, -2.0, randf_range(0.8, 1.1), 10.0, "smash")
		if hp <= 0.0:
			smash()

	func hit_by_object(prop: Node, speed: float) -> void:
		damage(speed * float(prop.mass) * 1.2)

	func smash() -> void:
		if done:
			return
		Sfx.play_at("glass" if sound == "glass" else "thud_heavy", global_position, 2.0, 0.9, 13.0, "break")
		_remove()

	func _remove() -> void:
		done = true
		Story.set_flag("broken:" + break_id)
		broke.emit(self)
		Events.world_changed.emit(self, "broken")
		if body:
			body.queue_free()
		for c in get_children():
			if c is MeshInstance3D:
				c.queue_free()

	func get_state() -> Dictionary:
		return {"done": done}

	func set_state(d: Dictionary) -> void:
		if d.get("done", false) and not done:
			done = true; broke.emit(self)
			if body: body.queue_free()
			for c in get_children():
				if c is MeshInstance3D: c.queue_free()


class Padlock:
	extends Node3D
	var key_tag := "key:padlock48"
	var locked := true
	var door: Door
	var hp := 40.0
	var lock_id := ""
	var body: StaticBody3D

	func is_locked() -> bool:
		return locked

	func iverbs(p: Node) -> Array:
		if not locked:
			return []
		var out := []
		var key: String = p.inv.with_tag(key_tag)
		if key != "":
			out.append(Interactable.v("unlock", "Unlock the padlock"))
		var cut: String = p.inv.with_tag("cut")
		if cut != "":
			out.append(Interactable.v("cut", "Cut the shackle (%s)" % ItemDB.item_name(cut), {"time": 2.5, "noise": 3.0}))
		var pry: String = p.inv.with_tag("pry")
		if pry != "":
			out.append(Interactable.v("pry", "Lever the hasp off (%s)" % ItemDB.item_name(pry), {"time": 4.0, "noise": 12.0}))
		var strike: String = p.inv.with_tag("strike")
		if strike != "" and strike != pry:
			out.append(Interactable.v("strike", "Smash it (%s)" % ItemDB.item_name(strike), {"time": 3.0, "noise": 14.0}))
		if out.is_empty():
			out.append(Interactable.v("tug", "Tug at it", {"noise": 3.0}))
		return out

	func iverb(id: String, _p: Node) -> void:
		match id:
			"unlock":
				Story.record("route.padlock_key", {"lock": lock_id})
				_open("bolt")
			"cut":
				Story.record("route.padlock_cut", {"lock": lock_id})
				_open("chain")
			"pry":
				Story.record("route.padlock_pried", {"lock": lock_id})
				_open("scrape")
			"strike":
				Story.record("route.padlock_smashed", {"lock": lock_id})
				_open("metal")
			"tug":
				Sfx.play_at("chain", global_position, -6.0, 1.2, 3.0)
				Events.toast.emit("It's a good lock.")

	func iprogress(id: String, k: float, _p: Node) -> void:
		if id in ["strike", "pry"] and fmod(k * 6.0, 1.0) < 0.05:
			Sfx.play_at("metal", global_position, -2.0, randf_range(0.8, 1.2), 12.0, "smash")

	func ifocus() -> Vector3:
		return global_position

	## a gunshot: one hit is enough
	func shot(_point: Vector3) -> void:
		if locked:
			Story.record("route.padlock_shot", {"lock": lock_id})
			_open("metal")

	func break_off() -> void:
		if locked:
			_open("metal")

	func _open(snd: String) -> void:
		locked = false
		Sfx.play_at(snd, global_position, 0.0, 1.0, 4.0)
		Events.world_changed.emit(self, "unlocked")
		if door:
			door.state_changed.emit(door)
		# it drops off the hasp
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y - 0.9, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if body:
			body.collision_layer = 0

	func get_state() -> Dictionary:
		return {"locked": locked}

	func set_state(d: Dictionary) -> void:
		if not d.get("locked", true) and locked:
			locked = false
			position.y -= 0.9
			if body: body.collision_layer = 0


class Trigger:
	extends Area3D
	signal entered(t: Trigger)
	signal exited(t: Trigger)
	var trigger_id := ""
	var once := false
	var fired := false

	func _init() -> void:
		collision_layer = 0
		collision_mask = 4        # the player
		monitorable = false
		body_entered.connect(func(b):
			if b.is_in_group("player") and not (once and fired):
				fired = true
				entered.emit(self))
		body_exited.connect(func(b):
			if b.is_in_group("player"):
				exited.emit(self))

	static func box(id: String, center: Vector3, size: Vector3) -> Trigger:
		var t := Trigger.new()
		t.trigger_id = id
		t.name = "T_" + id
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
		cs.shape = bs; t.add_child(cs)
		t.position = center
		return t
