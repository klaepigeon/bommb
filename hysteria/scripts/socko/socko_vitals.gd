class_name SockoVitals
extends RefCounted
## Socko is the health bar. There's no meter on the screen: how Kurt is doing is how the sock on
## his hand is doing, because it's the same arm. Four states you can tell apart at a glance, each
## with its own idle, and the blood on the cloth to go with them:
##
##   fine    (above 3/4)  as he ever was
##   hurt    (above 1/2)  sags a little, breathes faster, fresh blood starting through the knit
##   bad     (above 1/4)  slumped and curled, panting with his mouth open, shaking, one eye slow
##                        to follow the other, a soft pulse through the cloth
##   dying   (below 1/4)  hangs off the wrist, heaving; a hard double heartbeat squeezes him; he
##                        nods off and jerks awake; soaked red
##
## On a hit he flinches (shrinks, snaps away, shakes it off). When Kurt's strength comes back up
## a state, he perks: a stretch and a shake. `update` returns offsets that Socko adds to whatever
## else he is doing, so he still talks, points and lies while hurt, only worse.

signal tier_changed(tier: int, worse: bool)

var health := 1.0        # Kurt's, 0..1 (set every frame)
var d := 0.0             # damage as shown, 0..1: follows health down fast, up slowly
var wound := 0.0         # blood as shown: wells up with damage, dries far more slowly than he heals
var tier := 0
var _t := 0.0
var _breath := 0.0
var _flinch := 0.0
var _perk := 0.0
var _nod_in := 5.0
var _nod := -1.0
var _rng := RandomNumberGenerator.new()

static func tier_of(h: float) -> int:
	return 0 if h > 0.75 else (1 if h > 0.5 else (2 if h > 0.25 else 3))

func hit(amount: float) -> void:
	_flinch = clampf(0.5 + amount * 1.5, 0.5, 1.0)
	_nod = -1.0

func update(delta: float, still := 0.0) -> Dictionary:
	_t += delta
	var want := 1.0 - clampf(health, 0.0, 1.0)
	d = lerpf(d, want, 1.0 - exp(-delta * (5.0 if want > d else 0.8)))
	wound = maxf(wound - delta * 0.006, d)                 # blood dries slowly; it doesn't un-bleed
	var now := tier_of(1.0 - want)
	if now != tier:
		var worse := now > tier
		tier = now
		if not worse: _perk = 1.0
		tier_changed.emit(tier, worse)
	_flinch = maxf(0.0, _flinch - delta * 1.6)
	_perk = maxf(0.0, _perk - delta * 1.1)
	# breath: faster and deeper the worse he is; it lifts the head and swells the cloth
	_breath += delta * lerpf(1.6, 4.6, d)
	var heave := sin(_breath)
	var amp := lerpf(0.015, 0.075, smoothstep(0.2, 1.0, d))
	# the heart: a soft single pulse when it's bad, a hard lub-dub when he's dying
	var beat := 0.0
	if tier >= 2:
		var ph := fmod(_t * (1.25 if tier == 2 else 1.9), 1.0)
		beat = exp(-pow(ph / 0.07, 2.0))
		if tier == 3: beat = beat * 1.0 + exp(-pow((ph - 0.28) / 0.08, 2.0)) * 0.7
		beat *= 0.12 if tier == 2 else 0.3
	# dying: his head goes down, down... and he jerks awake
	var nod := 0.0
	if tier == 3 and _flinch <= 0.0:
		if _nod < 0.0:
			_nod_in -= delta
			if _nod_in <= 0.0: _nod = 0.0; _nod_in = _rng.randf_range(3.5, 6.5)
		else:
			_nod += delta
			nod = smoothstep(0.0, 1.5, _nod) * 0.6 if _nod < 1.5 else 0.6 * exp(-(_nod - 1.5) * 16.0)
			if _nod > 1.9: _nod = -1.0
	else:
		_nod = -1.0
	var woozy := smoothstep(0.35, 1.0, d)
	var shake_off := sin(_t * 31.0) * _flinch * (1.0 - _flinch) * 1.6        # the shake after the flinch
	return {
		"breath": heave * amp,
		"pitch": -0.42 * d - nod - _flinch * 0.45 + _perk * (1.0 - _perk) * 0.9,
		"roll": sin(_t * 0.55) * 0.2 * woozy + shake_off * 0.25,
		"yaw": sin(_t * 0.37 + 1.3) * 0.12 * woozy + shake_off * 0.4 + _flinch * 0.35,
		"lift": -0.024 * d - _flinch * 0.03 + _perk * (1.0 - _perk) * 0.06,
		"curl": 0.34 * d + _flinch * 0.5,
		"squash": 0.42 * d + heave * amp * 2.2 + beat + nod * 0.4,
		"stretch": -_flinch * 0.8 + _perk * (1.0 - _perk) * 2.2,
		"jaw": smoothstep(0.3, 0.8, d) * (0.07 + 0.11 * maxf(0.0, heave)) + _flinch * 0.3,
		"tremble": smoothstep(0.45, 1.0, d) * 0.85 + _flinch * 0.6,
		"lazy": smoothstep(0.45, 0.95, d),           # one eye slow to follow
		"beat": beat,
	}
