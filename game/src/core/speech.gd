extends Node
## Dialogue: lines by id from content/script.json, queued, subtitled, optionally voiced with the
## platform's text-to-speech. The preserved Socko performance (preserved/socko/socko.gd) listens
## to line_started / line_cue / line_finished and reads mouth(); those signatures are fixed.

signal line_started(speaker: String, text: String)
signal line_cue(id: String, line: Dictionary)
signal line_finished(speaker: String)
signal subtitle(speaker: String, display_name: String, color: Color, text: String, style: String)
signal subtitle_clear
signal sequence_finished(tag: int)

const SCRIPT_PATH := "res://content/script.json"
const CHAR_PATH := "res://content/characters.json"

var lines := {}
var characters := {}
var speaking := ""            ## speaker of the line being said now, "" if none
var current_id := ""
var fast := false             ## tests: lines take a tenth of the time

var _queue: Array = []        ## [{id, tag}]
var _t := 0.0
var _dur := 0.0
var _tag := 0
var _tts_ok := false
var _voices := {}
var _syll := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lines = _load(SCRIPT_PATH).get("lines", {})
	characters = _load(CHAR_PATH)
	_tts_ok = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and not DisplayServer.get_name() == "headless"
	if _tts_ok:
		var v := DisplayServer.tts_get_voices_for_language("en")
		if v.is_empty():
			_tts_ok = false
		else:
			for c in characters:
				_voices[c] = v[0]

static func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("missing " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func has_line(id: String) -> bool:
	return lines.has(id)

func busy() -> bool:
	return speaking != "" or not _queue.is_empty()

## Queue lines; returns the sequence's tag (sequence_finished(tag) fires after the last one).
func queue(ids: Array) -> int:
	_tag += 1
	for id in ids:
		if lines.has(id):
			_queue.append({"id": id, "tag": _tag})
		else:
			push_warning("Speech: no line '%s'" % id)
	_queue.append({"id": "", "tag": _tag})        # end marker
	return _tag

## Queue lines and wait for them to be said.
func speak(ids: Array) -> void:
	var tag := queue(ids)
	while true:
		var t = await sequence_finished
		if t == tag:
			return

## A one-off line that is dropped if something else is being said (barks, reactions).
func bark(id: String) -> bool:
	if busy() or not lines.has(id):
		return false
	queue([id])
	return true

func stop_all() -> void:
	_queue.clear()
	if speaking != "":
		_end_line()
	if _tts_ok:
		DisplayServer.tts_stop()

func _process(delta: float) -> void:
	if speaking != "":
		_t += delta
		_syll += delta
		if _t >= _dur:
			_end_line()
		return
	while not _queue.is_empty():
		var q: Dictionary = _queue.pop_front()
		if q.id == "":
			sequence_finished.emit(q.tag)
			continue
		_start_line(q.id)
		return

func _start_line(id: String) -> void:
	var l: Dictionary = lines[id]
	var sp: String = l.get("speaker", "kurt")
	var text: String = l.get("text", "")
	var ch: Dictionary = characters.get(sp, {})
	current_id = id
	speaking = sp
	_t = 0.0
	_syll = 0.0
	var words := text.split(" ", false).size()
	_dur = float(l.get("duration", maxf(1.3, 0.9 + words * 0.34 / float(ch.get("rate", 1.0)))))
	if fast:
		_dur *= 0.1
	line_cue.emit(id, l)
	line_started.emit(sp, text)
	var style: String = l.get("style", "")
	subtitle.emit(sp, String(ch.get("name", sp.to_upper())), Color(String(ch.get("color", "#ffffff"))), text, style)
	if l.has("sfx"):
		Sfx.play(String(l.sfx), 0.0)
	if _tts_ok and Settings.get_v("tts_voice") and not l.get("silent", false) and not fast:
		var vol := int(float(ch.get("volume", 90)) * float(Settings.get_v("vol_voice")) * float(Settings.get_v("vol_master")))
		if style == "quiet":
			vol = int(vol * 0.6)
		DisplayServer.tts_speak(_spoken(text), _voices.get(sp, ""), vol, float(ch.get("pitch", 1.0)), float(ch.get("rate", 1.0)))

## what the voice reads: stage directions and bracketed sounds are not read aloud
static func _spoken(text: String) -> String:
	var re := RegEx.new()
	re.compile("[\\[(][^\\])]*[\\])]")
	return re.sub(text, "", true).strip_edges()

func _end_line() -> void:
	var sp := speaking
	speaking = ""
	current_id = ""
	subtitle_clear.emit()
	line_finished.emit(sp)

## How open a speaker's mouth is right now (0..1): syllable-rate flapping while they talk.
func mouth(speaker: String) -> float:
	if speaking != speaker:
		return 0.0
	var l: Dictionary = lines.get(current_id, {})
	if l.get("silent", false):
		return 0.0
	var env := clampf(_t / 0.08, 0.0, 1.0) * clampf((_dur - _t) / 0.15, 0.0, 1.0)
	var s := absf(sin(_syll * 10.5)) * (0.65 + 0.35 * sin(_syll * 3.7))
	return clampf(s * env, 0.0, 1.0)
