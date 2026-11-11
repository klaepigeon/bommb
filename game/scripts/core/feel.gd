extends Node
## Game feel, in one place. Trauma (0..1) drives a camera shake (squared, so small knocks stay
## small and big ones are big), decaying over time; hit-stop freezes the world for a few
## hundredths of a second when something lands; fov_punch kicks the field of view. Anything
## loud near the camera can add trauma through `at()` (Audio does this for the sounds in
## SHAKERS, so a slammed door or the Super's tread shakes the view by distance, with no code at
## the source). Settings: "screen_shake" scales all of it (0 turns it off).

## sound -> trauma at 1 m (falls off with distance; db shifts it a little)
const SHAKERS := {
	"slam": 0.32, "kick": 0.22, "axe": 0.22, "splinter": 0.28, "step_heavy": 0.09, "thud": 0.07,
	"glass": 0.12, "breaker": 0.12, "rumble": 0.4, "gunshot": 0.18, "zap": 0.15, "crash": 0.3,
}

var trauma := 0.0
var fov_kick := 0.0                ## degrees, added to the camera's fov, decays
var roll_bias := 0.0               ## a lean of the head (radians) the shake settles around
var _t := 0.0
var _stop_until := 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 47
	_noise.frequency = 1.0

func scale() -> float:
	var s = Settings.get_v("screen_shake")
	return float(s) if s != null else 1.0

## Add trauma directly (at the camera).
func shake(amount: float) -> void:
	trauma = clampf(trauma + amount * scale(), 0.0, 1.0)

## Something happened at `pos` with this much force (trauma at 1 m), heard by the camera.
func at(pos: Vector3, amount: float, radius := 14.0) -> void:
	var cam: Camera3D = Lights.camera
	if cam == null or not is_instance_valid(cam): return
	var d := cam.global_position.distance_to(pos)
	if d > radius: return
	var fall := 1.0 / (1.0 + d * d * 0.12)
	shake(amount * fall)

## Freeze the world for `sec` (real time). Short: 0.03-0.08.
func hitstop(sec: float) -> void:
	if scale() <= 0.0 or Engine.time_scale < 1.0: return
	var now := Time.get_ticks_msec() / 1000.0
	_stop_until = now + sec
	Engine.time_scale = 0.05

func fov_punch(deg: float) -> void:
	fov_kick += deg * clampf(scale(), 0.0, 1.0)

## The camera's shake this frame: Vector3(pitch, yaw, roll) radians, and a position offset.
func offset() -> Array:
	var t2 := trauma * trauma
	var r := Vector3(_noise.get_noise_2d(_t * 23.0, 1.0), _noise.get_noise_2d(_t * 23.0, 50.0), _noise.get_noise_2d(_t * 23.0, 99.0))
	var rot := Vector3(r.x * 0.06, r.y * 0.06, r.z * 0.09) * t2
	var pos := Vector3(_noise.get_noise_2d(_t * 17.0, 7.0), _noise.get_noise_2d(_t * 17.0, 13.0), 0.0) * 0.05 * t2
	rot.z += roll_bias
	return [rot, pos]

func _process(delta: float) -> void:
	var real := Time.get_ticks_msec() / 1000.0
	if Engine.time_scale < 1.0 and real >= _stop_until:
		Engine.time_scale = 1.0
	var d := delta / maxf(Engine.time_scale, 0.05)
	_t += d
	trauma = maxf(trauma - d * 1.3, 0.0)
	fov_kick = move_toward(fov_kick, 0.0, d * (8.0 + absf(fov_kick) * 6.0))
