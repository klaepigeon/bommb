extends Node
## The campaign's Sfx.play(name, volume_db, jitter), on MEAT PARTY's Audio channels.
## Sounds come from res://assets/audio (the campaign's generated set).

var _cache: Dictionary = {}


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var p := "res://assets/audio/%s.wav" % sound
		_cache[sound] = load(p) if ResourceLoader.exists(p) else null
	return _cache[sound]


func play(sound: String, volume_db: float = 0.0, jitter: float = 0.05, pitch: float = 1.0) -> void:
	var s := stream(sound)
	if s:
		Audio.play_stream(s, volume_db, jitter, pitch)


func play_music(_track: String) -> void:
	pass


func stop_music() -> void:
	pass
