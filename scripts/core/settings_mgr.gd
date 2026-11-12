extends Node
## Settings — preferensi pemain, persist di user://settings.cfg.
##
## Setiap setter langsung menyimpan dan memancarkan GameEvents.settings_changed()
## (kecuali argumen save=false).

const PATH := "user://settings.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)


func _read(section: String, key: String, fallback: Variant) -> Variant:
	return _cfg.get_value(section, key, fallback)


func _write(section: String, key: String, value: Variant, save := true) -> void:
	_cfg.set_value(section, key, value)
	if save:
		_cfg.save(PATH)
		GameEvents.settings_changed.emit()


# --- Game -----------------------------------------------------------------------
func get_quality() -> int:
	return int(_read("game", "quality", 1))


func set_quality(v: int, save := true) -> void:
	_write("game", "quality", clampi(v, 0, 2), save)
	if save:
		GameEvents.quality_changed.emit(get_quality())


func get_sensitivity() -> float:
	return float(_read("game", "sensitivity", 0.5))


func set_sensitivity(v: float, save := true) -> void:
	_write("game", "sensitivity", clampf(v, 0.05, 1.0), save)


func get_invert_y() -> bool:
	return bool(_read("game", "invert_y", false))


func set_invert_y(v: bool, save := true) -> void:
	_write("game", "invert_y", v, save)


func get_shift_lock() -> bool:
	return bool(_read("game", "shift_lock", false))


func set_shift_lock(v: bool, save := true) -> void:
	_write("game", "shift_lock", v, save)


# --- Audio ------------------------------------------------------------------------
func get_vol_master() -> float:
	return float(_read("audio", "vol_master", 1.0))


func set_vol_master(v: float, save := true) -> void:
	_write("audio", "vol_master", clampf(v, 0.0, 1.0), save)


func get_vol_sfx() -> float:
	return float(_read("audio", "vol_sfx", 0.9))


func set_vol_sfx(v: float, save := true) -> void:
	_write("audio", "vol_sfx", clampf(v, 0.0, 1.0), save)


func get_vol_music() -> float:
	return float(_read("audio", "vol_music", 0.7))


func set_vol_music(v: float, save := true) -> void:
	_write("audio", "vol_music", clampf(v, 0.0, 1.0), save)


# --- Profil -----------------------------------------------------------------------
func get_locale() -> String:
	return str(_read("profile", "locale", "id"))


func set_locale(v: String, save := true) -> void:
	_write("profile", "locale", v, save)


func get_player_name() -> String:
	var n := str(_read("profile", "player_name", "Pemain"))
	return n.substr(0, 16) if not n.is_empty() else "Pemain"


func set_player_name(v: String, save := true) -> void:
	var clean := v.strip_edges().substr(0, 16)
	_write("profile", "player_name", clean if not clean.is_empty() else "Pemain", save)
