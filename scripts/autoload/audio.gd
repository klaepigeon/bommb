extends Node
## Audio channels (Music, SFX, Voice, Ambience under Master), with volumes from Settings.
## Sounds are asked for by id (Assets resolves them). Silence is a tool too: duck() pulls
## the music right down for a beat.

const BUSES := ["Music", "SFX", "Voice", "Ambience"]
const POOL := 12

var _music: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var music_id := ""
var muted := false   # tests


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_music = _player("Music")
	_music_b = _player("Music")
	_amb = _player("Ambience")
	_voice = _player("Voice")
	for i in POOL:
		_pool.append(_player("SFX"))
	apply_volumes()


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_volumes() -> void:
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(float(s.get_v("master", 1.0))))
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, float(s.get_v(b.to_lower(), 1.0)))))


func sfx(id: String, pitch_jitter: float = 0.06, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted:
		return
	var s := Assets.stream("sfx", id)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter)))
	p.play()


## A stream that isn't in the manifest (the campaign's sound set, via Sfx).
func play_stream(s: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.05, pitch: float = 1.0) -> void:
	if muted or s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter)))
	p.play()


## Positional sound for a world point (chairs humming, the bomb ticking).
func sfx_at(parent: Node3D, id: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if muted or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = Assets.stream("sfx", id)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func music(id: String, fade: float = 0.8) -> void:
	if id == music_id:
		return
	music_id = id
	var s: AudioStream = Assets.stream("music", id) if id != "" else null
	var old := _music
	_music = _music_b
	_music_b = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)
	if s == null or muted:
		return
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_music.stream = s
	_music.volume_db = -30.0
	_music.pitch_scale = 1.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, fade)


## Music stops dead (Musical Chairs), or comes back.
func music_halt(on: bool) -> void:
	_music.stream_paused = on


func music_pitch(p: float) -> void:
	_music.pitch_scale = p


func duck(seconds: float = 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -24.0, 0.1)
	tw.tween_interval(seconds)
	tw.tween_property(_music, "volume_db", 0.0, 0.6)


func ambience(id: String) -> void:
	var s: AudioStream = Assets.stream("ambience", id) if id != "" else null
	if s == null or muted:
		_amb.stop()
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int(s.get_length() * (s as AudioStreamWAV).mix_rate)
	_amb.stream = s
	_amb.volume_db = -14.0
	_amb.play()


## The Caller's voice: a recorded line if one has been supplied for this id
## (assets.json "voice"), otherwise a babble of hums pitched to the syllables.
func voice(line_id: String, text: String) -> void:
	if muted:
		return
	var s: AudioStream = Assets.stream("voice", line_id) if line_id != "" else null
	if s:
		_voice.stream = s
		_voice.pitch_scale = 1.0
		_voice.play()
		return
	var syll := clampi(text.length() / 6, 1, 10)
	for i in syll:
		get_tree().create_timer(i * 0.11).timeout.connect(func():
			sfx("caller_hum", 0.0, -10.0, 1.6 + randf_range(-0.35, 0.35)))
