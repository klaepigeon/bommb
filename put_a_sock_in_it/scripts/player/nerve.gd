class_name Nerve
extends Node
## Kurt's nerve (docs/SYSTEMS.md). One number, Game.fear 0..1, that the rest of the game reads:
##
##   rises    seeing her (more, the nearer she is); her coming for him; her being close at all,
##            seen or not; a fright (spike())
##   falls    slowly anywhere she isn't; faster crouched and still; fastest in a safe room
##   does     his heart (heard, faster and louder); his hands (the aim and what he holds shake);
##            the edges of his sight (vignette, colour draining); and his breathing: past half,
##            ragged breaths come that she can hear, unless he holds it
##
## Holding his breath ("hold_breath": B / R3 / touch BREATH): silent, for seven seconds at most
## (more with the Lungs node), and it frightens him a little more. Hold it too long and he gasps,
## loud. Hidden in a wardrobe with her listening at the doors, this is the whole game.

const HOLD_SECS := 7.0

var player: Player
var level: Node
var holding := false
var air := 1.0                  # breath held: 1 full .. 0 he has to breathe
var _winded := false            # gasped: can't hold it again till he's got some air back
var _ragged_t := 2.0
var _last_fear := 0.0

func attach(p: Player, lv: Node) -> void:
	player = p; level = lv
	name = "Nerve"
	lv.add_child(self)
	Sfx.loop("nerve_heart", "heart_loop", -80.0)

func _exit_tree() -> void:
	Sfx.stop_loop("nerve_heart")

## A fright: a jump, a scream close by, being grabbed.
func spike(amount: float) -> void:
	Game.fear = clampf(Game.fear + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if not player: return
	var f: float = Game.fear
	var rise := 0.0
	var m = level.get("marta")
	if m and m is MartaHunter and m.active and m.is_inside_tree():
		var d: float = player.global_position.distance_to(m.global_position)
		if _sees(m): rise += lerpf(0.7, 0.12, clampf(d / 14.0, 0.0, 1.0))
		if m.state == "chase": rise += 0.35
		rise += 0.3 * maxf(0.0, 1.0 - d / 6.0)            # close, seen or not: he can hear her
	rise *= Game.stat("fear_rise")
	var calm := 0.04
	if player.crouching and player.velocity.length() < 0.3: calm = 0.08
	if level.has_method("in_safe") and level.in_safe(player.global_position): calm = 0.3
	if player.hidden_in: calm = maxf(calm, 0.06)
	f += (rise - (calm if rise < 0.01 else 0.0)) * delta
	# holding his breath
	var want_hold := player.controls_or_hidden() and Input.is_action_pressed("hold_breath") and not _winded
	if want_hold and air > 0.0:
		holding = true
		air -= delta / (HOLD_SECS * Game.stat("stamina_max"))
		f += 0.03 * delta
		if air <= 0.0:
			# he can't: it comes out of him
			air = 0.0; holding = false; _winded = true
			Sfx.play("gasp", -1.0, randf_range(0.9, 1.0))
			Game.make_noise(player.global_position, 0.45)
			player.shake(0.01, 0.4)
	else:
		holding = false
		air = minf(1.0, air + delta / 3.0)
		if _winded and air > 0.5: _winded = false
	player.breath_held = holding
	Game.fear = clampf(f, 0.0, 1.0)
	f = Game.fear
	# ragged breathing, past half: heard
	if f > 0.5 and not holding:
		_ragged_t -= delta
		if _ragged_t <= 0.0:
			_ragged_t = randf_range(1.6, 3.4) * lerpf(1.4, 0.7, f)
			Sfx.play("breath", lerpf(-16.0, -8.0, f), randf_range(1.05, 1.25))
			Game.make_noise(player.global_position, 0.1 + 0.12 * f)
	# what it does to him
	Sfx.set_loop_volume("nerve_heart", linear_to_db(maxf(0.0001, smoothstep(0.15, 0.9, f) * 0.9)))
	Sfx.set_loop_pitch("nerve_heart", lerpf(0.9, 1.75, f))
	player.tremor = f
	Fx.set_k("fear", f)
	if f - _last_fear > 0.25: Fx.kick("fringe", 0.5, 0.6)    # a sudden jump in it
	_last_fear = lerpf(_last_fear, f, 1.0 - exp(-2.0 * delta))

## Does he have her in sight (on screen, nothing between)?
func _sees(m) -> bool:
	var to: Vector3 = m.head() - player.cam.global_position
	if to.length() > 16.0: return false
	if (-player.cam.global_transform.basis.z).dot(to.normalized()) < 0.6: return false
	var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, m.head(), 1, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
