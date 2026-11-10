extends Node
## A trail of what the game was doing, written to disk as it goes (user://trail.txt, flushed at
## every mark), so that when it dies on a phone with no debugger attached there is something to
## read. If the last run didn't end cleanly, `last_crash` holds the end of its trail, and the game
## shows it at start-up to be screenshotted.

const PATH := "user://trail.txt"
var last_crash := ""
var _f: FileAccess
var _n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(PATH):
		var old := FileAccess.get_file_as_string(PATH)
		var lines := old.strip_edges().split("\n")
		if lines.size() > 1 and not String(lines[lines.size() - 1]).contains("CLEAN"):
			last_crash = "\n".join(lines.slice(maxi(0, lines.size() - 22)))
	_f = FileAccess.open(PATH, FileAccess.WRITE)
	mark("start %s %s | %s | %s" % [ProjectSettings.get_setting("application/config/version", "?"), OS.get_model_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])

func mark(what: String) -> void:
	if _f == null:
		return
	_n += 1
	_f.store_line("%d %.1fs %s" % [_n, Time.get_ticks_msec() / 1000.0, what])
	_f.flush()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			mark("CLEAN (in the background)")
		NOTIFICATION_APPLICATION_RESUMED:
			mark("back in front")
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			mark("CLEAN (quit)")
