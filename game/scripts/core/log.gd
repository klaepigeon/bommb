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
		if old != "" and not old.strip_edges().ends_with("exit"):
			var lines := old.strip_edges().split("\n")
			previous = "\n".join(lines.slice(maxi(0, lines.size() - 14)))
	_f = FileAccess.open(PATH, FileAccess.WRITE)
	mark("start %s %s %s" % [OS.get_name(), OS.get_model_name(), RenderingServer.get_video_adapter_name()])

func mark(what: String) -> void:
	var line := "%7.2f %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, what]
	if OS.is_debug_build() or OS.has_feature("editor"):
		print("[trail] ", line)
	if _f:
		_f.store_line(line)
		_f.flush()

func _process(delta: float) -> void:
	_fps_t += delta
	if _fps_t > 10.0:
		_fps_t = 0.0
		var cam: Camera3D = Lights.camera if is_instance_valid(Lights.camera) else get_viewport().get_camera_3d()
		mark("fps %d mem %.0fMB at %s" % [Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1048576.0, str(cam.global_position.snapped(Vector3.ONE * 0.1)) if cam else "-"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _f:
			_f.store_line("exit")
			_f.flush()
