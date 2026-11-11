extends Node
## Unit test: Locale (autoload `Locale`) + Settings (autoload `Settings`).
##
## Menguji perilaku NYATA dari:
##   - scripts/autoload/locale_manager.gd   -> t(), set_language(), fallback
##     kunci, substitusi {var}, fallback tabel FALLBACK ("en").
##   - scripts/autoload/settings_manager.gd -> get_value()/set_value(),
##     getter bertipe, sinyal setting_changed/theme_changed, get_theme(),
##     persistensi user://settings.cfg.
##   - data/locales/id.json vs en.json -> paritas kunci/nilai/placeholder.
##   - Invariant tools/sync_locales.py: semua Locale.t("kunci") statis di
##     res://scripts harus ada di kedua file locale.
##
## Suite order-independent: bahasa + seluruh setting di-snapshot SEBELUM
## mutasi apa pun dan dipulihkan penuh di akhir (autoload shared antar suite).

const FW := preload("res://tools/tests/test_framework.gd")

const LOCALE_ID_PATH := "res://data/locales/id.json"
const LOCALE_EN_PATH := "res://data/locales/en.json"
const SCRIPTS_ROOT := "res://scripts"
## Identik dengan pola tools/sync_locales.py (pemanggilan statis Locale.t("..")).
const LOCALE_CALL_RE := 'Locale\\.t\\(\\s*"([a-z0-9_]+)"'

var fw := FW.new()

var _lang_orig := ""
var _settings_orig: Dictionary = {}
var _lang_signals := 0
var _setting_events: Array = []
var _theme_signals := 0


func _ready() -> void:
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	# --- snapshot awal SEBELUM mutasi apa pun (autoload shared antar suite) ---
	_lang_orig = Locale.get_language()
	for k in Settings.DEFAULTS.keys():
		_settings_orig[k] = Settings.get_value(k)

	var en_tbl := _locale_table(LOCALE_EN_PATH)
	var id_tbl := _locale_table(LOCALE_ID_PATH)
	if (
		en_tbl.is_empty()
		or id_tbl.is_empty()
		or not en_tbl.has("menu_play")
		or not en_tbl.has("mode_obby_obj")
		or not id_tbl.has("menu_play")
		or not id_tbl.has("mode_obby_obj")
	):
		fw.check("fixture locale termuat (kedua file + kunci menu_play/mode_obby_obj)", false)
		_restore_all()
		return

	_test_locale_data_parity(en_tbl, id_tbl)
	_test_locale_used_keys(en_tbl, id_tbl)
	_test_locale_t_behavior(en_tbl)
	_test_locale_switching(en_tbl, id_tbl)
	_test_locale_settings_integration()
	_test_settings_defaults()
	_test_settings_roundtrip_and_signals()
	_test_settings_persistence()
	_restore_all()
	_test_restore_verification(en_tbl, id_tbl)


# ------------------------------------------------------------------ Locale


func _test_locale_data_parity(en_tbl: Dictionary, id_tbl: Dictionary) -> void:
	fw.section("Locale data: paritas id.json vs en.json")
	fw.check_gt("id.json terisi (jumlah kunci > 100)", id_tbl.size(), 100)
	fw.check_gt("en.json terisi (jumlah kunci > 100)", en_tbl.size(), 100)
	var id_keys := id_tbl.keys()
	var en_keys := en_tbl.keys()
	id_keys.sort()
	en_keys.sort()
	fw.check_eq("himpunan kunci identik (array kunci terurut)", id_keys, en_keys)

	var only_en: Array = []
	var only_id: Array = []
	for k in en_tbl.keys():
		if not id_tbl.has(k):
			only_en.append(k)
	for k in id_tbl.keys():
		if not en_tbl.has(k):
			only_id.append(k)
	fw.check("tidak ada kunci yang hanya ada di en.json %s" % [str(only_en)], only_en.is_empty())
	fw.check("tidak ada kunci yang hanya ada di id.json %s" % [str(only_id)], only_id.is_empty())

	var empty_en: Array = []
	var empty_id: Array = []
	for k in en_tbl.keys():
		if String(en_tbl[k]).strip_edges().is_empty():
			empty_en.append(k)
		if String(id_tbl.get(k, "")).strip_edges().is_empty():
			empty_id.append(k)
	fw.check("en.json tanpa nilai kosong/whitespace %s" % [str(empty_en)], empty_en.is_empty())
	fw.check("id.json tanpa nilai kosong/whitespace %s" % [str(empty_id)], empty_id.is_empty())

	if only_en.is_empty() and only_id.is_empty():
		var mism: Array = []
		for k in en_tbl.keys():
			var pe := _placeholders(String(en_tbl[k]))
			var pi := _placeholders(String(id_tbl[k]))
			if pe != pi:
				mism.append("%s (en=%s, id=%s)" % [k, str(pe), str(pi)])
		fw.check("token placeholder {..} konsisten id vs en %s" % [str(mism)], mism.is_empty())


func _test_locale_used_keys(en_tbl: Dictionary, id_tbl: Dictionary) -> void:
	fw.section("Locale: kunci terpakai di kode (invariant tools/sync_locales.py)")
	var used: Dictionary = {}
	_collect_locale_keys(SCRIPTS_ROOT, used)
	fw.check_gt('panggilan Locale.t("..") ditemukan di res://scripts', used.size(), 50)
	var missing_en: Array = []
	var missing_id: Array = []
	for k in used.keys():
		if not en_tbl.has(k):
			missing_en.append(k)
		if not id_tbl.has(k):
			missing_id.append(k)
	missing_en.sort()
	missing_id.sort()
	fw.check("semua kunci terpakai ada di en.json %s" % [str(missing_en)], missing_en.is_empty())
	fw.check("semua kunci terpakai ada di id.json %s" % [str(missing_id)], missing_id.is_empty())


func _test_locale_t_behavior(en_tbl: Dictionary) -> void:
	fw.section("Locale.t(): lookup, fallback kunci, substitusi variabel")
	fw.check_eq("available_languages() == [id, en]", Locale.available_languages(), ["id", "en"])

	# Bahasa deterministik untuk bagian ini.
	Locale.set_language("en")
	fw.check_eq('set_language("en") -> get_language()', Locale.get_language(), "en")
	fw.check_eq(
		't("menu_play") = nilai en.json', Locale.t("menu_play"), String(en_tbl["menu_play"])
	)
	fw.check("t() kunci yang ada -> non-kosong", not Locale.t("menu_play").strip_edges().is_empty())
	fw.check_eq(
		"t() kunci hilang -> kembalikan kuncinya (fallback)",
		Locale.t("zz_no_such_key_probe"),
		"zz_no_such_key_probe"
	)

	var bad: Array = []
	for k in en_tbl.keys():
		if Locale.t(k) != String(en_tbl[k]):
			bad.append(k)
	fw.check("t(k) == en.json[k] untuk SEMUA kunci (bahasa en) %s" % [str(bad)], bad.is_empty())

	var tmpl := String(en_tbl["mode_obby_obj"])
	var expected := tmpl.replace("{x}", "3").replace("{y}", "10")
	fw.check_eq(
		"t() mensubstitusi {x}/{y} dari template data",
		Locale.t("mode_obby_obj", {"x": 3, "y": 10}),
		expected
	)
	fw.check(
		"hasil substitusi tidak menyisakan placeholder",
		not ("{" in Locale.t("mode_obby_obj", {"x": 3, "y": 10}))
	)
	fw.check_eq(
		"variabel di luar template diabaikan",
		Locale.t("menu_play", {"zz": 9}),
		String(en_tbl["menu_play"])
	)


func _test_locale_switching(en_tbl: Dictionary, id_tbl: Dictionary) -> void:
	fw.section("Locale: pergantian bahasa & sinyal language_changed")
	Locale.language_changed.connect(_on_language_changed)
	_lang_signals = 0

	# Prasyarat: bahasa saat ini "en" (dari bagian sebelumnya).
	Locale.set_language("en")  # tidak berubah -> tanpa sinyal
	fw.check_eq("set_language ke bahasa yang sama tidak memicu sinyal", _lang_signals, 0)

	Locale.set_language("id")
	fw.check_eq('get_language() == "id" setelah switch', Locale.get_language(), "id")
	fw.check_eq("language_changed terpicu tepat 1x", _lang_signals, 1)
	fw.check_ne(
		"sanity: teks menu_play id != en", String(id_tbl["menu_play"]), String(en_tbl["menu_play"])
	)
	fw.check_eq(
		't("menu_play") kini nilai id.json', Locale.t("menu_play"), String(id_tbl["menu_play"])
	)

	var bad: Array = []
	for k in id_tbl.keys():
		if Locale.t(k) != String(id_tbl[k]):
			bad.append(k)
	fw.check("t(k) == id.json[k] untuk SEMUA kunci (bahasa id) %s" % [str(bad)], bad.is_empty())

	var tmpl_id := String(id_tbl["mode_obby_obj"])
	fw.check_eq(
		"substitusi variabel bekerja juga di id",
		Locale.t("mode_obby_obj", {"x": 7, "y": 30}),
		tmpl_id.replace("{x}", "7").replace("{y}", "30")
	)

	# Bahasa tak dikenal: tabel kosong -> lookup jatuh ke konst FALLBACK ("en").
	Locale.set_language("zz")
	fw.check_eq(
		"set_language menerima kode tak dikenal (tanpa validasi)", Locale.get_language(), "zz"
	)
	fw.check_eq(
		"t() jatuh ke tabel fallback en saat bahasa tak dikenal",
		Locale.t("menu_play"),
		String(en_tbl["menu_play"])
	)
	fw.check_eq(
		"kunci hilang pada bahasa tak dikenal -> kunci itu sendiri",
		Locale.t("zz_missing_probe"),
		"zz_missing_probe"
	)

	Locale.language_changed.disconnect(_on_language_changed)


func _test_locale_settings_integration() -> void:
	fw.section("Locale <-> Settings: set_language menulis Settings[language]")
	Locale.set_language("en")
	fw.check_eq(
		'set_language("en") tersimpan ke Settings', String(Settings.get_value("language", "")), "en"
	)
	Locale.set_language("id")
	fw.check_eq(
		'set_language("id") tersimpan ke Settings', String(Settings.get_value("language", "")), "id"
	)


# ---------------------------------------------------------------- Settings


func _test_settings_defaults() -> void:
	fw.section("Settings: DEFAULTS masuk akal & prioritas get_value")
	var d: Dictionary = Settings.DEFAULTS
	fw.check_gte("DEFAULTS punya >= 10 kunci", d.size(), 10)
	for vk in ["master_volume", "music_volume", "sfx_volume"]:
		fw.check("default %s di rentang [0..1]" % [vk], float(d[vk]) >= 0.0 and float(d[vk]) <= 1.0)
	fw.check(
		"default language termasuk bahasa yang tersedia",
		Locale.available_languages().has(d["language"])
	)
	fw.check(
		"default graphics_quality valid (low/medium/high)",
		["low", "medium", "high"].has(d["graphics_quality"])
	)
	fw.check_gt("default camera_sensitivity > 0", float(d["camera_sensitivity"]), 0.0)
	for bk in ["dark_mode", "chat_enabled", "tutorial_done"]:
		fw.check("default %s bertipe bool" % [bk], typeof(d[bk]) == TYPE_BOOL)
	fw.check_eq(
		"get_value kunci tak dikenal -> default pemanggil",
		Settings.get_value("zz_unknown_probe", 42),
		42
	)
	fw.check(
		"get_value kunci tak dikenal tanpa default -> null",
		Settings.get_value("zz_unknown_probe") == null
	)
	fw.check(
		"get_value kunci terdaftar mengabaikan default pemanggil (prioritas _values/DEFAULTS)",
		Settings.get_value("language", "ZZ") != "ZZ"
	)
	fw.check("is_dark_mode() mengembalikan bool", typeof(Settings.is_dark_mode()) == TYPE_BOOL)
	fw.check("chat_enabled() mengembalikan bool", typeof(Settings.chat_enabled()) == TYPE_BOOL)


func _test_settings_roundtrip_and_signals() -> void:
	fw.section("Settings: set/get roundtrip, tipe apa adanya, sinyal")
	Settings.setting_changed.connect(_on_setting_changed)
	Settings.theme_changed.connect(_on_theme_changed)
	_setting_events = []
	_theme_signals = 0

	Settings.set_value("master_volume", 0.25)
	fw.check_eq("roundtrip master_volume = 0.25", Settings.get_value("master_volume"), 0.25)
	fw.check_eq(
		"float tersimpan sebagai float (tanpa koersi)",
		typeof(Settings.get_value("master_volume")),
		TYPE_FLOAT
	)

	Settings.set_value("music_volume", 7)  # int pada kunci float — tidak ada validasi
	fw.check_eq(
		"int tersimpan utuh (perilaku nyata: tanpa validasi tipe)",
		Settings.get_value("music_volume"),
		7
	)
	fw.check_eq(
		"tipe int dipertahankan (tidak dipaksa float)",
		typeof(Settings.get_value("music_volume")),
		TYPE_INT
	)

	Settings.set_value("chat_enabled", false)
	fw.check_eq("roundtrip chat_enabled -> getter bool", Settings.chat_enabled(), false)
	Settings.set_value("graphics_quality", "high")
	fw.check_eq("roundtrip graphics_quality", Settings.get_value("graphics_quality"), "high")
	Settings.set_value("camera_sensitivity", 2.5)
	fw.check_eq("roundtrip camera_sensitivity", Settings.get_value("camera_sensitivity"), 2.5)

	var expected_events: Array = [
		["master_volume", 0.25],
		["music_volume", 7],
		["chat_enabled", false],
		["graphics_quality", "high"],
		["camera_sensitivity", 2.5],
	]
	fw.check_eq(
		"setting_changed: urutan & (kunci, nilai) tepat per set_value",
		_setting_events,
		expected_events
	)
	fw.check_eq("theme_changed belum terpicu oleh kunci non-dark_mode", _theme_signals, 0)

	var th_dark: Theme = Settings.get_theme()
	fw.check_not_null("get_theme() menghasilkan Theme", th_dark)
	Settings.set_dark_mode(false)
	fw.check_eq("set_dark_mode(false) -> is_dark_mode()", Settings.is_dark_mode(), false)
	var th_light: Theme = Settings.get_theme()
	fw.check("tema dibangun ulang (instance baru) setelah toggel dark_mode", th_light != th_dark)
	Settings.set_dark_mode(true)
	fw.check_eq("set_dark_mode(true) -> is_dark_mode()", Settings.is_dark_mode(), true)
	fw.check_eq("theme_changed terpicu tepat 2x untuk 2x toggel dark_mode", _theme_signals, 2)

	Settings.set_value("sfx_volume", 0.5)
	var saw_sfx := false
	for ev in _setting_events:
		if String(ev[0]) == "sfx_volume" and ev[1] == 0.5:
			saw_sfx = true
	fw.check("setting_changed membawa (kunci, nilai) yang benar", saw_sfx)

	Settings.setting_changed.disconnect(_on_setting_changed)
	Settings.theme_changed.disconnect(_on_theme_changed)


func _test_settings_persistence() -> void:
	fw.section("Settings: persistensi ke user://settings.cfg")
	Settings.set_value("sfx_volume", 0.125)
	var cf := ConfigFile.new()
	var err := cf.load("user://settings.cfg")
	fw.check_eq("settings.cfg termuat setelah set_value", err, OK)
	fw.check_eq("sfx_volume tertulis ke disk", cf.get_value("settings", "sfx_volume", -1.0), 0.125)
	fw.check_eq('file memakai section "settings"', cf.has_section("settings"), true)


# ----------------------------------------------------------------- restore


func _restore_all() -> void:
	# Pulihkan Locale & Settings ke snapshot awal (suite order-independent).
	if Locale.get_language() != _lang_orig:
		Locale.set_language(_lang_orig)
	for k in _settings_orig.keys():
		var v: Variant = _settings_orig[k]
		if Settings.get_value(k) != v:
			Settings.set_value(k, v)


func _test_restore_verification(en_tbl: Dictionary, id_tbl: Dictionary) -> void:
	fw.section("Restore: kondisi awal dikembalikan penuh")
	fw.check_eq("bahasa kembali ke awal", Locale.get_language(), _lang_orig)
	fw.check_eq(
		"Settings[language] kembali ke awal",
		String(Settings.get_value("language", "")),
		String(_lang_orig)
	)
	var mism: Array = []
	for k in _settings_orig.keys():
		if Settings.get_value(k) != _settings_orig[k]:
			mism.append(k)
	fw.check("semua setting DEFAULTS kembali ke nilai awal %s" % [str(mism)], mism.is_empty())
	if _lang_orig == "en" or _lang_orig == "id":
		var expect := (
			String(en_tbl["menu_play"]) if _lang_orig == "en" else String(id_tbl["menu_play"])
		)
		fw.check_eq(
			't("menu_play") sesuai bahasa awal yang dipulihkan', Locale.t("menu_play"), expect
		)


# ------------------------------------------------------------------ helper


func _on_language_changed() -> void:
	_lang_signals += 1


func _on_setting_changed(key: String, value: Variant) -> void:
	_setting_events.append([key, value])


func _on_theme_changed() -> void:
	_theme_signals += 1


func _locale_table(path: String) -> Dictionary:
	var parsed: Variant = fw.load_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _placeholders(text: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_]+)\\}")
	for m in re.search_all(text):
		out.append(m.get_string(1))
	out.sort()
	return out


func _collect_locale_keys(dir_path: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir_path):
		var fname := String(f)
		if fname.ends_with(".gd"):
			_scan_locale_calls("%s/%s" % [dir_path, fname], out)
	for d in DirAccess.get_directories_at(dir_path):
		_collect_locale_keys("%s/%s" % [dir_path, String(d)], out)


func _scan_locale_calls(path: String, out: Dictionary) -> void:
	var re := RegEx.new()
	re.compile(LOCALE_CALL_RE)
	for m in re.search_all(fw.read_res(path)):
		out[m.get_string(1)] = path
