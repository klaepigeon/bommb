extends Node
## SAVES (SaveManager): the match in progress, on disk (user://match.save, JSON). Written
## at the start of every round (MatchCore.snapshot: every player's Teeth, Dead Rats, items,
## body, poisons, suspicion, Cage; the board, the rules, the facility, the Caller's Game,
## event history, statistics, and the RNG's state) and whenever the app is paused or
## closed. Loading it puts you back at the start of that round with the same RNG state:
## the same dice come up, so quitting can't reroll anything. Only the host (or an offline
## game) saves; the save is wiped when the match ends.

const PATH := "user://match.save"

var last: Dictionary = {}
var _seat_list: Array = []


func checkpoint(core: MatchCore) -> void:
	if Net.role not in ["offline", "host"]:
		return
	write(core.snapshot(), Seats.to_array() if Seats.has_method("to_array") else [])


func write(snap: Dictionary, seat_list: Array) -> void:
	var seats := []
	for s in seat_list:
		var d: Dictionary = (s as Dictionary).duplicate()
		if d.get("color") is Color:
			d.color = (d.color as Color).to_html()
		seats.append(d)
	last = {"version": 3, "time": Time.get_unix_time_from_system(), "match": snap, "seats": seats}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(last))
		f.close()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func read() -> Dictionary:
	if not has_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else {}


## The seats as they were (colours back to Colors).
func seats_of(d: Dictionary) -> Array:
	var out := []
	for s in d.get("seats", []):
		var x: Dictionary = (s as Dictionary).duplicate()
		x.seat = int(x.seat)
		x.face = int(x.get("face", 0))
		x.peer = int(x.get("peer", 0))
		if x.get("color") is String:
			x.color = Color.html(str(x.color))
		out.append(x)
	return out


func clear() -> void:
	last = {}
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func summary() -> String:
	var d := read()
	if d.is_empty():
		return ""
	var m: Dictionary = d.get("match", {})
	return "ROUND %d OF %d" % [int(m.get("round", 1)), int(m.get("max_rounds", 15))]


func _notification(what: int) -> void:
	# the app's going: the round-start save is already on disk; make sure it's flushed
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not last.is_empty():
			var f := FileAccess.open(PATH, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(last))
				f.close()
