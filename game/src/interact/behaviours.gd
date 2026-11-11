extends RefCounted
## Prop behaviours: things that keep doing something after you touch them. Each is a Node child of
## its Prop and adds verbs (iverbs_extra / iverb_extra). They are the game's distraction tools:
## sound in a place you're not.

static func new_behaviour(kind: String) -> Node:
	match kind:
		"radio": return Radio.new()
		"alarm_clock": return AlarmClock.new()
		"music_box": return MusicBox.new()
	return Node.new()


class Radio:
	extends Node
	## Static, loud, constant: a noise beacon. Marta goes to it and silences it (she switches it
	## off, or if she's already angry she smashes it).
	var on := false
	var _loop: AudioStreamPlayer3D
	var _t := 0.0

	func iverbs_extra(_p: Node) -> Array:
		return [Interactable.v("radio", "Switch off" if on else "Switch on", {"noise": 2.0})]

	func iverb_extra(id: String, p: Node) -> void:
		if id == "radio":
			set_on(not on)
			if on:
				Story.record("stealth.distraction", {"what": "radio"})

	func set_on(v: bool) -> void:
		on = v
		Sfx.play_at("switch", get_parent().global_position, -6.0, 1.0, 1.0)
		if on and not _loop:
			_loop = Sfx.loop_at("static", get_parent(), -2.0, 3.0)
		elif not on and _loop:
			_loop.queue_free(); _loop = null
		Events.world_changed.emit(get_parent(), "radio_on" if on else "radio_off")

	func _process(delta: float) -> void:
		if on:
			_t -= delta
			if _t <= 0.0:
				_t = 1.2
				Events.noise.emit(get_parent().global_position, 11.0, "radio", get_parent())

	## the AI's way of dealing with it
	func silence() -> void:
		if on:
			set_on(false)


class AlarmClock:
	extends Node
	## Wind it, put it down, walk away: in ten seconds it rings for eight. A delayed distraction.
	var armed := false
	var ringing := false
	var _t := 0.0
	var _loop: AudioStreamPlayer3D

	func iverbs_extra(_p: Node) -> Array:
		if ringing:
			return [Interactable.v("clock_stop", "Stop it ringing")]
		if armed:
			return []
		return [Interactable.v("clock_wind", "Wind it and set the alarm", {"noise": 1.0})]

	func iverb_extra(id: String, _p: Node) -> void:
		if id == "clock_wind":
			arm()
		elif id == "clock_stop":
			_stop()

	func arm(delay := 10.0) -> void:
		armed = true
		_t = delay
		_loop = Sfx.loop_at("tick", get_parent(), -10.0, 1.0)
		Story.record("stealth.distraction", {"what": "alarm_clock"})

	func _process(delta: float) -> void:
		if not armed:
			return
		_t -= delta
		if not ringing and _t <= 0.0:
			ringing = true
			_t = 8.0
			if _loop: _loop.queue_free()
			_loop = Sfx.loop_at("alarm", get_parent(), 2.0, 4.0)
		elif ringing:
			if fmod(_t, 1.0) > 1.0 - delta:
				Events.noise.emit(get_parent().global_position, 15.0, "alarm", get_parent())
			if _t <= 0.0:
				_stop()

	func _stop() -> void:
		armed = false
		ringing = false
		if _loop: _loop.queue_free(); _loop = null

	func silence() -> void:
		_stop()


class MusicBox:
	extends Node
	## Sonya's music box. Marta hears it and goes to it, and when she reaches it she stops hunting:
	## she sits down in the air beside it and listens until it winds down. The humane way past her.
	var playing := false
	var _t := 0.0
	var _loop: AudioStreamPlayer3D

	func iverbs_extra(_p: Node) -> Array:
		if playing:
			return []
		return [Interactable.v("crank", "Wind it up", {"noise": 1.0})]

	func iverb_extra(id: String, _p: Node) -> void:
		if id == "crank":
			play()

	func play(sec := 30.0) -> void:
		playing = true
		_t = sec
		if _loop: _loop.queue_free()
		_loop = Sfx.loop_at("music_box", get_parent(), -2.0, 3.0)
		Story.record("used:music_box")

	func _process(delta: float) -> void:
		if not playing:
			return
		_t -= delta
		if fmod(_t, 2.0) > 2.0 - delta:
			Events.noise.emit(get_parent().global_position, 16.0, "lullaby", get_parent())
		if _t <= 0.0:
			playing = false
			if _loop:
				_loop.pitch_scale = 0.8
				var l := _loop
				_loop = null
				get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(l): l.queue_free())
