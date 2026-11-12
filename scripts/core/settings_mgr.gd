extends Node
## Settings — preferensi pemain, persist di user://settings.cfg.
##
## Pola "load -> sanitize -> persist": SEMUA nilai di-clamp saat _ready supaya
## file yang diedit tangan / sisa versi lama tidak merusak game; bila ada yang
## berubah karena clamp, file disimpan ulang sekali. Setiap setter langsung
## menyimpan dan memancarkan GameEvents.settings_changed() (kecuali save=false).

const PATH := "user://settings.cfg"

const DEFAULT_QUALITY := 1
const DEFAULT_SENSITIVITY := 0.5
const DEFAULT_INVERT_Y := false
const DEFAULT_SHIFT_LOCK := false
const DEFAULT_VOL_MASTER := 1.0
const DEFAULT_VOL_SFX := 0.9
const DEFAULT_VOL_MUSIC := 0.7
const DEFAULT_LOCALE := "id"
const DEFAULT_PLAYER_NAME := "Pemain"

const LOCALES := ["id", "en"]
const QUALITY_MIN := 0
const QUALITY_MAX := 2
const SENSITIVITY_MIN := 0.05
const SENSITIVITY_MAX := 1.0
const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const NAME_MAX_LEN := 16

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != Error.OK and err != Error.ERR_FILE_NOT_FOUND:
		push_warning("settings.cfg tidak terbaca (err %d) — pakai nilai default." % err)
	_sanitize_all()


## Kembalikan semua preferensi ke nilai default lalu simpan.
func reset_to_defaults() -> void:
	_cfg.clear()
	_sanitize_all()
	GameEvents.settings_changed.emit()


func _read(section: String, key: String, fallback: Variant) -> Variant:
	return _cfg.get_value(section, key, fallback)


## Baca nilai mentah; null berarti kunci belum ada (tanpa error engine).
func _read_raw(section: String, key: String) -> Variant:
	if not _cfg.has_section_key(section, key):
		return null
	return _cfg.get_value(section, key, null)


func _write(section: String, key: String, value: Variant, save := true) -> void:
	_cfg.set_value(section, key, value)
	if save:
		_save()
		GameEvents.settings_changed.emit()


func _save() -> void:
	var err := _cfg.save(PATH)
	if err != Error.OK:
		push_warning("Gagal menyimpan settings.cfg (err %d)." % err)


# --- Sanitasi saat muat --------------------------------------------------------


func _sanitize_all() -> void:
	var dirty := false
	dirty = _sanitize_quality() or dirty
	dirty = _sanitize_sensitivity() or dirty
	dirty = _sanitize_invert_y() or dirty
	dirty = _sanitize_shift_lock() or dirty
	dirty = _sanitize_volume("vol_master", DEFAULT_VOL_MASTER) or dirty
	dirty = _sanitize_volume("vol_sfx", DEFAULT_VOL_SFX) or dirty
	dirty = _sanitize_volume("vol_music", DEFAULT_VOL_MUSIC) or dirty
	dirty = _sanitize_locale() or dirty
	dirty = _sanitize_player_name() or dirty
	if dirty:
		_save()


func _sanitize_quality() -> bool:
	return _sanitize_int("game", "quality", DEFAULT_QUALITY, QUALITY_MIN, QUALITY_MAX)


func _sanitize_sensitivity() -> bool:
	return _sanitize_float(
		"game", "sensitivity", DEFAULT_SENSITIVITY, SENSITIVITY_MIN, SENSITIVITY_MAX
	)


func _sanitize_invert_y() -> bool:
	return _sanitize_bool("game", "invert_y", DEFAULT_INVERT_Y)


func _sanitize_shift_lock() -> bool:
	return _sanitize_bool("game", "shift_lock", DEFAULT_SHIFT_LOCK)


func _sanitize_volume(key: String, fallback: float) -> bool:
	return _sanitize_float("audio", key, fallback, VOLUME_MIN, VOLUME_MAX)


func _sanitize_locale() -> bool:
	var raw: Variant = _read_raw("profile", "locale")
	var clean := str(raw) if LOCALES.has(str(raw)) else DEFAULT_LOCALE
	if raw is String and raw == clean:
		return false
	_cfg.set_value("profile", "locale", clean)
	return true


func _sanitize_player_name() -> bool:
	var raw: Variant = _read_raw("profile", "player_name")
	var clean := clean_player_name(str(raw) if raw != null else DEFAULT_PLAYER_NAME)
	if raw is String and raw == clean:
		return false
	_cfg.set_value("profile", "player_name", clean)
	return true


## Tulis nilai int yang sudah di-clamp; true bila nilai berubah.
func _sanitize_int(section: String, key: String, fallback: int, lo: int, hi: int) -> bool:
	var raw: Variant = _read_raw(section, key)
	var clean := clampi(_to_int(raw, fallback), lo, hi)
	if raw is int and raw == clean:
		return false
	_cfg.set_value(section, key, clean)
	return true


## Tulis nilai float yang sudah di-clamp; true bila nilai berubah.
func _sanitize_float(section: String, key: String, fallback: float, lo: float, hi: float) -> bool:
	var raw: Variant = _read_raw(section, key)
	var clean := clampf(_to_float(raw, fallback), lo, hi)
	if raw is float and raw == clean:
		return false
	_cfg.set_value(section, key, clean)
	return true


## Tulis nilai bool; true bila nilai berubah.
func _sanitize_bool(section: String, key: String, fallback: bool) -> bool:
	var raw: Variant = _read_raw(section, key)
	var clean := _to_bool(raw, fallback)
	if raw is bool and raw == clean:
		return false
	_cfg.set_value(section, key, clean)
	return true


# --- Konversi tipe defensif (nilai bisa diedit tangan) ---------------------------


func _to_int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is String:
		var s := str(v).strip_edges()
		return int(s) if s.is_valid_int() else fallback
	return fallback


func _to_float(v: Variant, fallback: float) -> float:
	if v is int:
		return float(v)
	if v is float:
		return v
	if v is String:
		var s := str(v).strip_edges()
		return float(s) if s.is_valid_float() else fallback
	return fallback


func _to_bool(v: Variant, fallback: bool) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return bool(v)
	if v is String:
		return str(v).to_lower() == "true"
	return fallback


## Bersihkan nama pemain: trim spasi, potong ke 16 karakter, kosong -> default.
func clean_player_name(v: String) -> String:
	var clean := v.strip_edges().substr(0, NAME_MAX_LEN)
	return clean if not clean.is_empty() else DEFAULT_PLAYER_NAME


# --- Game -----------------------------------------------------------------------


func get_quality() -> int:
	var v := _to_int(_read("game", "quality", DEFAULT_QUALITY), DEFAULT_QUALITY)
	return clampi(v, QUALITY_MIN, QUALITY_MAX)


func set_quality(v: int, save := true) -> void:
	_write("game", "quality", clampi(v, QUALITY_MIN, QUALITY_MAX), save)
	if save:
		GameEvents.quality_changed.emit(get_quality())


func get_sensitivity() -> float:
	var v := _to_float(_read("game", "sensitivity", DEFAULT_SENSITIVITY), DEFAULT_SENSITIVITY)
	return clampf(v, SENSITIVITY_MIN, SENSITIVITY_MAX)


func set_sensitivity(v: float, save := true) -> void:
	_write("game", "sensitivity", clampf(v, SENSITIVITY_MIN, SENSITIVITY_MAX), save)


func get_invert_y() -> bool:
	return _to_bool(_read("game", "invert_y", DEFAULT_INVERT_Y), DEFAULT_INVERT_Y)


func set_invert_y(v: bool, save := true) -> void:
	_write("game", "invert_y", v, save)


func get_shift_lock() -> bool:
	return _to_bool(_read("game", "shift_lock", DEFAULT_SHIFT_LOCK), DEFAULT_SHIFT_LOCK)


func set_shift_lock(v: bool, save := true) -> void:
	_write("game", "shift_lock", v, save)


# --- Audio ------------------------------------------------------------------------


func get_vol_master() -> float:
	var v := _to_float(_read("audio", "vol_master", DEFAULT_VOL_MASTER), DEFAULT_VOL_MASTER)
	return clampf(v, VOLUME_MIN, VOLUME_MAX)


func set_vol_master(v: float, save := true) -> void:
	_write("audio", "vol_master", clampf(v, VOLUME_MIN, VOLUME_MAX), save)


func get_vol_sfx() -> float:
	var v := _to_float(_read("audio", "vol_sfx", DEFAULT_VOL_SFX), DEFAULT_VOL_SFX)
	return clampf(v, VOLUME_MIN, VOLUME_MAX)


func set_vol_sfx(v: float, save := true) -> void:
	_write("audio", "vol_sfx", clampf(v, VOLUME_MIN, VOLUME_MAX), save)


func get_vol_music() -> float:
	var v := _to_float(_read("audio", "vol_music", DEFAULT_VOL_MUSIC), DEFAULT_VOL_MUSIC)
	return clampf(v, VOLUME_MIN, VOLUME_MAX)


func set_vol_music(v: float, save := true) -> void:
	_write("audio", "vol_music", clampf(v, VOLUME_MIN, VOLUME_MAX), save)


# --- Profil -----------------------------------------------------------------------


func get_locale() -> String:
	var v := str(_read("profile", "locale", DEFAULT_LOCALE))
	return v if LOCALES.has(v) else DEFAULT_LOCALE


func set_locale(v: String, save := true) -> void:
	var clean := v if LOCALES.has(v) else DEFAULT_LOCALE
	_write("profile", "locale", clean, save)


func get_player_name() -> String:
	return clean_player_name(str(_read("profile", "player_name", DEFAULT_PLAYER_NAME)))


func set_player_name(v: String, save := true) -> void:
	_write("profile", "player_name", clean_player_name(v), save)
