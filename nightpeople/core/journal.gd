extends Node
## What the player knows. Knowledge comes only from the world: reading something, taking it,
## overhearing or being told something, seeing it. Quests are not scripts: a quest's log is
## written from what is known (data/story.json "quest"), and dialogue topics open up the same way.

signal learned(flag: String)

const STORY := "res://data/story.json"

var story: Dictionary = {}
var known: Dictionary = {}          ## flag → Clock.total_minutes when learned

func _ready() -> void:
	story = JSON.parse_string(FileAccess.get_file_as_string(STORY))

func reset() -> void:
	known.clear()

func knows(flag: String) -> bool:
	return known.has(flag)

func knows_any(flags: Array) -> bool:
	for f in flags:
		if known.has(f):
			return true
	return false

func learn(flag: String) -> void:
	if flag == "" or known.has(flag):
		return
	known[flag] = Clock.total_minutes
	learned.emit(flag)
	for s in story.quest.stages:
		if s[0] == flag:
			Events.notice.emit("Noted: " + s[1].left(60) + ("..." if s[1].length() > 60 else ""))
			Sfx.ui("ui")

## The quest log, in the order things were learned, then contradictions and how it stands.
func quest_text() -> String:
	var q: Dictionary = story.quest
	var lines: Array[String] = []
	var stages: Array = q.stages.filter(func(s): return known.has(s[0]))
	stages.sort_custom(func(a, b): return known[a[0]] < known[b[0]])
	for s in stages:
		lines.append("- " + s[1])
	for c in q.contradictions:
		if known.has(c[0]) and known.has(c[1]):
			lines.append("! " + c[2])
	for e in q.endings:
		if known.has(e[0]):
			lines.append("\n" + e[1])
			break
	if lines.is_empty():
		return ""
	return q.title + "\n" + "\n".join(lines)
