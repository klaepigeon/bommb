class_name CrashReport
extends Node
## What happened, if the game didn't end properly last time. Every two seconds a line goes to
## user://breadcrumbs.txt and is flushed to storage straight away (so a crash, a freeze the phone
## killed, or a swipe-away after a hang all leave it behind): where Kurt was, the frame rate,
## memory, and the last few things that happened. Quitting from the menu writes "closed".
## At the next launch, if the last line isn't "closed", the game says so at once and shows it,
## together with the end of the engine's own log if there is one, to photograph and send.

const CRUMBS := "user://breadcrumbs.txt"
var last_log := ""            # the previous session's trail, if it didn't close
var _f: FileAccess
var _t := 0.0
var _events: Array[String] = []
var main: Node

func _ready() -> void:
	main = get_parent()
	last_log = _previous()
	_f = FileAccess.open(CRUMBS, FileAccess.WRITE)
	_line("started %s · %s" % [Time.get_datetime_string_from_system(), OS.get_model_name()])
	if last_log != "": _show_on_launch.call_deferred()

## something worth knowing happened (entering a place, a fight, a save...)
func note(what: String) -> void:
	_events.append(what)
	if _events.size() > 6: _events.pop_front()
	_line("· " + what)

func closed() -> void:
	_line("closed")

## leaving the tree is a proper shutdown (a crash never gets this far)
func _exit_tree() -> void:
	closed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: closed()
	elif what == NOTIFICATION_APPLICATION_PAUSED: _line("put away")
	elif what == NOTIFICATION_APPLICATION_RESUMED: _line("back")

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5: return
	_t = 0.0
	var p: Node3D = main.get("player")
	var where := "town" if main.get("in_labyrinth") else ("flat 48" if main.get("in_flat48") else "flat 47")
	var lamps := 0
	if main.get("labyrinth") and main.get("in_labyrinth"):
		for l in main.labyrinth.lamps: if l.visible: lamps += 1
	var torch = main.socko.get("torch") if main.get("socko") else null
	_line("%s %s · %d fps · %d draws · %dk tris · %d lamps · torch shadow %s · video %d MB · static %d MB · objects %d · time scale %.2f" % [where,
		str(p.global_position.snapped(Vector3.ONE * 0.1)) if p else "-", Engine.get_frames_per_second(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		lamps, str(torch.visible and torch.shadow_enabled) if torch else "-",
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), Engine.time_scale])

func _line(s: String) -> void:
	if not _f: return
	_f.store_line("%.1f  %s" % [Time.get_ticks_msec() / 1000.0, s])
	_f.flush()

## the last session's trail, if it didn't end with "closed"
func _previous() -> String:
	if not FileAccess.file_exists(CRUMBS): return ""
	var lines := FileAccess.get_file_as_string(CRUMBS).strip_edges().split("\n")
	if lines.is_empty() or lines[-1].ends_with("closed"): return ""
	# newest first, so the top of the screen (the bit that ends up in a photo) is the last moment
	var tail := lines.slice(maxi(1, lines.size() - 40))
	tail.reverse()
	var out := "newest first —\n" + "\n".join(tail) + "\n" + lines[0]
	var d := DirAccess.open("user://logs")
	if d:
		var files := []
		for f in d.get_files(): if f.ends_with(".log") and f != "godot.log": files.append(f)
		if files.size() > 0:
			files.sort()
			var log_lines := FileAccess.get_file_as_string("user://logs/" + String(files[-1])).split("\n")
			out += "\n\n— engine log —\n" + "\n".join(log_lines.slice(maxi(0, log_lines.size() - 40)))
	return out

func _show_on_launch() -> void:
	var layer := CanvasLayer.new(); layer.layer = 50; layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var t := TextEdit.new(); t.editable = false
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 30; t.offset_right = -30; t.offset_top = 30; t.offset_bottom = -110
	t.add_theme_font_size_override("font_size", 13)
	t.text = "The last session didn't end properly (a crash, or a freeze). This is what it was doing. A photo of this screen helps fix it.\n\n" + last_log
	layer.add_child(t)
	var b := Button.new(); b.text = "Carry on"; b.add_theme_font_size_override("font_size", 26)
	b.anchor_left = 0.5; b.anchor_right = 0.5; b.anchor_top = 1; b.anchor_bottom = 1
	b.offset_left = -150; b.offset_right = 150; b.offset_top = -95; b.offset_bottom = -25
	b.pressed.connect(layer.queue_free)
	layer.add_child(b)
	main.add_child(layer)
