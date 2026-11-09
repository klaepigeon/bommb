class_name CrashReport
extends Node
## If the game didn't close cleanly last time (it crashed, or the phone killed it in front of you),
## the end of that session's log is kept here, and the pause menu shows it ("Last crash log") so
## it can be photographed and sent. A marker file is written while the game is in front, removed
## when it's put away or closed; a marker still there at launch means the last run died.

const MARKER := "user://running"
var last_log := ""

func _ready() -> void:
	if FileAccess.file_exists(MARKER):
		last_log = _previous_log_tail(80)
	_mark(true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_mark(false)
		NOTIFICATION_APPLICATION_RESUMED:
			_mark(true)

func _mark(on: bool) -> void:
	if on:
		var f := FileAccess.open(MARKER, FileAccess.WRITE)
		if f: f.store_string(Time.get_datetime_string_from_system())
	elif FileAccess.file_exists(MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER))

## the newest log that isn't this session's: Godot keeps the last few, timestamped
func _previous_log_tail(lines: int) -> String:
	var d := DirAccess.open("user://logs")
	if not d: return "(no log was kept)"
	var files := []
	for f in d.get_files():
		if f.ends_with(".log") and f != "godot.log": files.append(f)
	if files.is_empty(): return "(no earlier log)"
	files.sort()
	var text := FileAccess.get_file_as_string("user://logs/" + String(files[-1]))
	var all := text.split("\n")
	return "\n".join(all.slice(maxi(0, all.size() - lines)))
