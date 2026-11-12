extends Node
## Locale — i18n minimal dari data/locales/{id,en}.json.
##
## Kunci string didefinisikan bertahap oleh modul UI; missing key mengembalikan
## fallback (atau kunci itu sendiri) agar tidak pernah crash. key_count() dan
## missing_keys() dipakai suite test untuk memverifikasi kelengkapan kamus.

const LOCALES := ["id", "en"]
const DEFAULT_LOCALE := "id"

var _strings := {}
var _code := DEFAULT_LOCALE


func _ready() -> void:
	_load(Settings.get_locale())


func _load(code: String) -> void:
	if not LOCALES.has(code):
		code = DEFAULT_LOCALE
	_code = code
	_strings = {}
	var path := "res://data/locales/%s.json" % code
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("File locale tidak ditemukan: %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_strings = parsed
	else:
		push_warning("Locale %s gagal di-parse" % code)


func tr_key(key: String, fallback := "") -> String:
	if _strings.has(key):
		return str(_strings[key])
	return fallback if not fallback.is_empty() else key


func set_locale(code: String) -> void:
	_load(code)
	Settings.set_locale(_code)
	GameEvents.settings_changed.emit()


func get_locale() -> String:
	return _code


func available() -> Array:
	return LOCALES.duplicate()


## Jumlah kunci terjemahan yang termuat untuk locale aktif.
func key_count() -> int:
	return _strings.size()


## Kembalikan subset dari `needed` yang belum ada di kamus locale aktif.
func missing_keys(needed: Array) -> Array[String]:
	var out: Array[String] = []
	for key in needed:
		var k := str(key)
		if not _strings.has(k):
			out.append(k)
	return out
