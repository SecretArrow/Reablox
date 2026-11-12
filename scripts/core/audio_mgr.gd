extends Node
## Audio — pemutar SFX/musik; aset WAV di-generate oleh tools/audio_gen.py.
##
## Aman headless: jika aset belum ada, play_sfx() diam saja (tidak crash).

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

var _sfx := {}
var _music := {}
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_load_dir(SFX_DIR, _sfx)
	_load_dir(MUSIC_DIR, _music)
	apply_volumes()
	GameEvents.settings_changed.connect(apply_volumes)


func play_sfx(sfx_name: String, pitch := 1.0) -> void:
	var stream: AudioStream = _sfx.get(sfx_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_music(track: String) -> void:
	var stream: AudioStream = _music.get(track)
	if stream == null:
		return
	if _music_player.playing and _music_player.stream == stream:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func apply_volumes() -> void:
	_set_bus("Master", Settings.get_vol_master())
	_set_bus("SFX", Settings.get_vol_sfx())
	_set_bus("Music", Settings.get_vol_music())


func has_sfx(sfx_name: String) -> bool:
	return _sfx.has(sfx_name)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.0)


func _load_dir(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and (fname.ends_with(".wav") or fname.ends_with(".ogg")):
			var res := load(path + "/" + fname)
			if res is AudioStream:
				into[fname.get_basename()] = res
		fname = dir.get_next()
	dir.list_dir_end()
