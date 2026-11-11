class_name ErrorLog
extends Logger
## Catches every engine and script error. On a phone it appends them (rate-limited) to
## user://errors.log, with the last story beat, so a crash or a broken interaction in the field can
## be reported; the in-game pause menu can show the path. Tests read `count` and fail on any.
## Called from any thread: guarded by a mutex, and it never touches the scene tree.

static var inst: ErrorLog
var count := 0
var last := ""
var beat := ""
var _m := Mutex.new()
var _written := 0
const PATH := "user://errors.log"
## noise that isn't ours (headless audio/TTS, leak reports at exit)
const IGNORE := ["synth", "tts", "leaked", "RID allocations", "ObjectDB instances", "resources still in use", "Condition \"status < 0\""]

static func install() -> void:
	if inst:
		return
	inst = ErrorLog.new()
	OS.add_logger(inst)

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var msg := "%s %s (%s:%d %s)" % [code, rationale, file, line, function]
	for k in IGNORE:
		if k in msg:
			return
	_m.lock()
	count += 1
	last = msg
	var write := _written < 200
	_written += 1
	_m.unlock()
	if write:
		var f := FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH, FileAccess.WRITE)
		if f:
			f.seek_end()
			f.store_line("[%s] beat=%s %s" % [Time.get_datetime_string_from_system(), beat, msg])

func _log_message(_message: String, _error: bool) -> void:
	pass
