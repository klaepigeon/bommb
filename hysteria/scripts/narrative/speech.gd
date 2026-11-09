class_name Speech
extends Node
## The one channel everybody speaks through, so nobody talks over anybody: Kurt, the people and
## things he meets, and Socko (whose lines still go through his own `say`, because his mouth is
## Kurt's fingers and the timing of it lives there).
##
## A line is identified by a stable id. If the voice library (content/voice/index.json) has a
## preferred take for it, that recording plays, from where the speaker is; otherwise the speaker's
## TTS voice (content/characters.json) reads it. Either way the subtitle shows who's speaking and
## stays up for as long as the line does.

signal line_started(speaker: String, text: String, id: String)
signal line_finished(speaker: String, id: String)

const CHARACTERS := "res://content/characters.json"
const VOICES := "res://content/voice/index.json"

var main: Node
var subtitles: Subtitles
var characters := {}
var voices := {}
var conversation: Node = null        # a Conversation while one is running (ambient talk waits)
var _busy_until := 0
var _player: AudioStreamPlayer3D
var _speaking := ""

func setup(p_main: Node) -> void:
	main = p_main
	characters = _load(CHARACTERS)
	voices = (_load(VOICES).get("lines", {}) as Dictionary)
	subtitles = Subtitles.new(); subtitles.name = "Subtitles"; main.add_child(subtitles)
	_player = AudioStreamPlayer3D.new(); _player.unit_size = 3.0; add_child(_player)

static func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

func in_conversation() -> bool:
	return conversation != null

func busy() -> bool:
	var s = main.get("socko")
	return Time.get_ticks_msec() < _busy_until or (s and bool(s.get("talking")))

func label_of(speaker: String) -> String:
	return String((characters.get(speaker, {}) as Dictionary).get("label", speaker.to_upper()))

func color_of(speaker: String) -> Color:
	return Color(String((characters.get(speaker, {}) as Dictionary).get("color", "#dddddd")))

## The take that plays for a line, or "" (then TTS reads it).
func take_for(line_id: String) -> String:
	var e: Dictionary = voices.get(line_id, {})
	var pref := String(e.get("preferred", ""))
	if pref != "" and FileAccess.file_exists("res://content/voice/" + pref): return "res://content/voice/" + pref
	for ext in ["ogg", "wav"]:
		var p := "res://content/voice/%s.%s" % [line_id, ext]
		if ResourceLoader.exists(p): return p
	return ""

## Say a line now. `at` is where the voice comes from (a recording plays there). Returns how long
## it'll take, in seconds.
func say(speaker: String, text: String, line_id := "", at = null, emotion := "neutral") -> float:
	_speaking = speaker
	if speaker == "socko":
		var s = main.get("socko")
		if s and s.visible:
			s.call("say", text, emotion, 1.0)
			var dur := maxf(1.6, text.length() * 0.065)
			_busy_until = Time.get_ticks_msec() + int(dur * 1000.0)
			line_started.emit(speaker, text, line_id)
			return dur
	var dur := maxf(1.4, text.length() * 0.06 + 0.4)
	var take := take_for(line_id) if line_id != "" else ""
	if take != "":
		var st: AudioStream = load(take)
		_player.stream = st
		var e: Dictionary = voices.get(line_id, {})
		_player.volume_db = float(e.get("volume_db", 0.0))
		_player.global_position = (at as Vector3) if at is Vector3 else main.player.global_position
		_player.play()
		dur = st.get_length() + float(e.get("tail", 0.15))
	else:
		var v := String(Game.call("_voice"))
		if v != "":
			var t: Dictionary = (characters.get(speaker, {}) as Dictionary).get("tts", {})
			DisplayServer.tts_stop()
			DisplayServer.tts_speak(text.replace("…", "...").replace("«", "").replace("»", ""), v, 75, float(t.get("pitch", 1.0)), float(t.get("rate", 1.0)))
	_busy_until = Time.get_ticks_msec() + int(dur * 1000.0)
	subtitles.show_line(label_of(speaker), text, dur + 0.5, color_of(speaker))
	line_started.emit(speaker, text, line_id)
	return dur

## Cut whoever's speaking off (an interruption).
func stop() -> void:
	_player.stop()
	if String(Game.call("_voice")) != "": DisplayServer.tts_stop()
	_busy_until = 0
