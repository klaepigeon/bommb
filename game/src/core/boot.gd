extends Node
## Crash trail. The first autoload: it writes how far startup got (user://boot.txt) at each step,
## and marks the session "running" once the game has been up for a few seconds. If the previous
## launch never got that far, it crashed: main.gd shows where, with the tail of the engine's log
## from that session, and offers a safe start. Plain file writes only: nothing here can fail loudly.

const PATH := "user://boot.txt"

var previous_stage := ""          ## where the last launch stopped ("" = it ran fine, or first launch)
var previous_log := ""            ## the last lines of that session's engine log
var _t := 0.0
var _ok := false

func _enter_tree() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var last := f.get_as_text().strip_edges().get_slice("\n", f.get_as_text().strip_edges().count("\n"))
		if last != "" and not last.begins_with("running"):
			previous_stage = last
			previous_log = _previous_log_tail()
		f = null
	var w := FileAccess.open(PATH, FileAccess.WRITE)
	if w:
		w.store_line("engine up, scripts running")

func mark(stage: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(stage)

func _process(delta: float) -> void:
	if _ok:
		return
	_t += delta
	if _t > 6.0:
		_ok = true
		mark("running (started fine)")

## Godot keeps the previous sessions' logs as user://logs/godot<date>.log; the newest is the one
## that just crashed (this session's own is godot.log)
static func _previous_log_tail() -> String:
	var d := DirAccess.open("user://logs")
	if not d:
		return ""
	var files := []
	for n in d.get_files():
		if n.begins_with("godot") and n.ends_with(".log") and n != "godot.log":
			files.append(n)
	if files.is_empty():
		return ""
	files.sort()
	var f := FileAccess.open("user://logs/" + String(files.back()), FileAccess.READ)
	if not f:
		return ""
	var lines := f.get_as_text().split("\n")
	return "\n".join(lines.slice(maxi(0, lines.size() - 25)))
