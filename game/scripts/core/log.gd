extends Node
## A trail of what the game is doing, written to user://trail.txt and flushed at every mark, so if
## the phone kills the game the next launch can say where it was. A run that ends cleanly writes
## "exit". `previous` holds the last lines of a run that didn't.

var previous := ""
var _f: FileAccess
var _t0 := 0
var _fps_t := 0.0
const PATH := "user://trail.txt"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	if FileAccess.file_exists(PATH):
		var old := FileAccess.get_file_as_string(PATH)
		var last := old.strip_edges()
		if old != "" and not last.ends_with("exit") and not last.ends_with("paused"):
			var lines := old.strip_edges().split("\n")
			previous = "\n".join(lines.slice(maxi(0, lines.size() - 14)))
			_prev_all = "\n".join(lines.slice(maxi(0, lines.size() - 60)))
			# keep the crashed trail for later, too
			var keep := FileAccess.open("user://trail_crash.txt", FileAccess.WRITE)
			if keep: keep.store_string(old); keep.close()
	_f = FileAccess.open(PATH, FileAccess.WRITE)
	mark("start %s %s | %s %s | %s | v%s" % [OS.get_name(), OS.get_model_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(), ProjectSettings.get_setting("application/config/version", "?")])

## The whole of the last crashed run's trail (for the report screen).
func previous_full() -> String:
	return _prev_all

var _prev_all := ""

func mark(what: String) -> void:
	var line := "%7.2f %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, what]
	if OS.is_debug_build() or OS.has_feature("editor"):
		print("[trail] ", line)
	if _f:
		_f.store_line(line)
		_f.flush()

func _process(delta: float) -> void:
	_fps_t += delta
	if _fps_t > 5.0:
		_fps_t = 0.0
		var cam: Camera3D = Lights.camera if is_instance_valid(Lights.camera) else get_viewport().get_camera_3d()
		mark("fps %d mem %.0fMB vram %.0fMB obj %d at %s" % [Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), str(cam.global_position.snapped(Vector3.ONE * 0.1)) if cam else "-"])

func _notification(what: int) -> void:
	# put away (home, app switcher): if the system or the player then kills it, that's not a crash
	if what == NOTIFICATION_APPLICATION_PAUSED: mark("paused")
	if what == NOTIFICATION_APPLICATION_RESUMED: mark("resumed")
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _f:
			_f.store_line("exit")
			_f.flush()
