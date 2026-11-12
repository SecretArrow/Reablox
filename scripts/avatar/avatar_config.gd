class_name AvatarConfig
extends RefCounted
## Helper config avatar: default, validasi, serialisasi, dan preset kosmetik.

# Alias preload: kelas global belum terdaftar di cache .godot (tanpa --import).
const BrickColorsLib := preload("res://scripts/avatar/brick_colors.gd")

const PRESETS_PATH := "res://data/cosmetics/presets.json"
const HEX_COLOR_PATTERN := "^#[0-9A-Fa-f]{6}$"
const REQUIRED_PARTS := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]


static func default_config() -> Dictionary:
	# Config bawaan avatar noob klasik.
	return {
		"colors": BrickColorsLib.default_noob(),
		"material": "plastic",
		"face": "smile",
		"accessories": [],
	}


static func validate(cfg: Dictionary) -> Array[String]:
	# Validasi skema config (logika sama dengan AvatarRig.validate_config).
	var errors: Array[String] = []
	var colors: Variant = cfg.get("colors")
	if typeof(colors) != TYPE_DICTIONARY:
		errors.append("cfg.colors harus Dictionary dengan 6 kunci bagian tubuh")
	else:
		var color_map := colors as Dictionary
		for part in REQUIRED_PARTS:
			var value: Variant = color_map.get(part)
			if typeof(value) != TYPE_STRING or not _is_valid_color_value(String(value)):
				errors.append("cfg.colors.%s harus nama palet atau hex #rrggbb" % part)
	if typeof(cfg.get("material")) != TYPE_STRING or String(cfg.get("material")).is_empty():
		errors.append("cfg.material harus String non-kosong")
	if typeof(cfg.get("face")) != TYPE_STRING or String(cfg.get("face")).is_empty():
		errors.append("cfg.face harus String non-kosong")
	if typeof(cfg.get("accessories")) != TYPE_ARRAY:
		errors.append("cfg.accessories harus Array")
	return errors


static func serialize(cfg: Dictionary) -> Dictionary:
	# Duplikat dalam yang aman untuk JSON (semua nilai tipe dasar JSON).
	return cfg.duplicate(true)


static func deserialize(d: Variant) -> Dictionary:
	# Kembalikan config dari data tersimpan; bila rusak -> default_config().
	if typeof(d) != TYPE_DICTIONARY:
		return default_config()
	var errors := validate(d as Dictionary)
	if not errors.is_empty():
		return default_config()
	return (d as Dictionary).duplicate(true)


static func apply_preset(preset_name: String) -> Dictionary:
	# Ambil config preset dari presets.json; bila tak ada -> default_config().
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Gagal membuka %s" % PRESETS_PATH)
		return default_config()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Skema %s tidak sesuai (diharapkan array)" % PRESETS_PATH)
		return default_config()
	for preset in parsed:
		if typeof(preset) != TYPE_DICTIONARY:
			continue
		if _preset_matches(preset as Dictionary, preset_name):
			var cfg: Variant = (preset as Dictionary).get("config")
			if typeof(cfg) == TYPE_DICTIONARY:
				return (cfg as Dictionary).duplicate(true)
			break
	return default_config()


static func _preset_matches(preset: Dictionary, preset_name: String) -> bool:
	# Cocokkan nama preset terhadap id, nama lokal, atau nama Inggris.
	if String(preset.get("id", "")) == preset_name:
		return true
	var label: Variant = preset.get("name")
	if typeof(label) == TYPE_DICTIONARY:
		var names := label as Dictionary
		if String(names.get("id", "")) == preset_name:
			return true
		if String(names.get("en", "")) == preset_name:
			return true
	return false


static func _is_valid_color_value(value: String) -> bool:
	if _is_hex_color(value):
		return true
	return BrickColorsLib.is_valid(value)


static func _is_hex_color(value: String) -> bool:
	var pattern := RegEx.create_from_string(HEX_COLOR_PATTERN)
	return pattern != null and pattern.search(value) != null
