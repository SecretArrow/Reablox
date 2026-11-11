extends Node
## Test suite SaveManager (autoload Saves) + skema world JSON (templates.gd).
## Jalur: cd rblox-audit && godot --headless res://tools/tests/test_unit_save.tscn
## Cakupan: roundtrip save/load, legacy "rblox-world", input korup, validasi
## path delete_world, export/import, cleanup berkas sementara.

const FW := preload("res://tools/tests/test_framework.gd")
const TEMPLATES := preload("res://scripts/world/templates.gd")

# Nama & path temp (semua memakai prefix "test_suite" agar mudah dibersihkan).
const NAME_MAIN := "Test Suite Tmp"
const NAME_LEGACY := "Test Suite Legacy"
const NAME_EXPORT := "Test Suite Export"
const NAME_IMPORT := "Test Suite Imported"
const PATH_MAIN := "user://worlds/test_suite_tmp.myworld"
const PATH_LEGACY := "user://worlds/test_suite_legacy.myworld"
const PATH_EXPORT := "user://worlds/test_suite_export.myworld"
const PATH_EXPORTED := "user://exports/test_suite_export.myworld"
const PATH_IMPORT := "user://worlds/test_suite_imported.myworld"
const PATH_IMPORT_SRC := "user://imports/test_suite_import_src.myworld"
const PATH_IMPORT_BAD := "user://imports/test_suite_badfmt.myworld"
const PATH_CORRUPT := "user://worlds/test_suite_corrupt.myworld"
const PATH_FOREIGN := "user://imports/test_suite_keep.myworld"
## Direktori saudara (prefix sama tanpa "/"): dulu lolos validasi delete_world.
const DIR_EVIL := "user://worlds_evil"
const PATH_EVIL := "user://worlds_evil/test_suite_trap.myworld"

var fw := FW.new()


func _ready() -> void:
	add_child(fw)
	_pre_clean()
	await _run_tests()
	_cleanup_files()
	fw.finish()


## Buang sisa file test dari run sebelumnya yang gagal di tengah jalan.
func _pre_clean() -> void:
	for dir in [Saves.WORLDS_DIR, Saves.EXPORTS_DIR, Saves.IMPORTS_DIR, DIR_EVIL]:
		DirAccess.make_dir_recursive_absolute(dir)
		for f in DirAccess.get_files_at(dir):
			if String(f).begins_with("test_suite"):
				DirAccess.remove_absolute("%s/%s" % [dir, String(f)])


func _run_tests() -> void:
	_test_template_schema()
	_test_roundtrip()
	_test_legacy_format()
	_test_corrupt_input()
	_test_delete_validation()
	_test_export_import()


# ------------------------------------------------------------- data builder


## Dunia kecil lengkap sesuai skema "reablox-world" (kontrak templates.gd).
func _make_world(fmt: String) -> Dictionary:
	var heights: Array = []
	var paint: Array = []
	for i in 64:  # size 8 -> 8x8 tile
		heights.append(i % 8)
		paint.append("rock" if i % 3 == 0 else "grass")
	return {
		"format": fmt,
		"version": 1,
		"meta": {"name": "Awal", "is_template": false},
		"settings":
		{
			"game_mode": "adventure",
			"day_night": false,
			"cycle_minutes": 7.5,
			"weather": "fog",
			"health_enabled": false,
			"build_allowed": true,
			"spawn": [1.5, 3.0, -2.5],
		},
		"spawn_points": [[1.5, 3.0, -2.5], [10.0, 2.0, 4.0]],
		"blocks":
		[
			{
				"id": "k1",
				"shape": "box",
				"pos": [1.0, 0.5, 2.0],
				"size": [2.0, 1.0, 2.0],
				"color": "#ff0000",
				"mat": "neon",
				"anchored": true,
				"script": "",
			},
			{
				"id": "k2",
				"shape": "sphere",
				"pos": [-3.0, 1.0, 0.0],
				"size": [1.0, 1.0, 1.0],
				"color": "#00ff00",
				"mat": "glass",
				"anchored": false,
				"script": "move(1, 0, 0)",
			},
		],
		"props": [{"type": "checkpoint", "role": "obby", "index": 0, "pos": [0.0, 1.0, 0.0]}],
		"terrain": {"size": 8, "seed": 99, "heights": heights, "paint": paint},
	}


func _write_raw(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


# ------------------------------------------------------------------ sections


func _test_template_schema() -> void:
	fw.section("templates.gd: skema world JSON")
	var cat: Array = TEMPLATES.catalog()
	fw.check_eq("katalog 10 template", cat.size(), 10)
	var ids := {}
	for t in cat:
		ids[String(t.get("id", ""))] = true

		# Struktur blok memenuhi kontrak skema.

		# Id tak dikenal jatuh ke "empty".
	fw.check_eq("id template unik", ids.size(), 10)

	var w: Dictionary = TEMPLATES.build_world_json("empty")
	fw.check_eq("format reablox-world", String(w.get("format", "")), "reablox-world")
	fw.check_eq("version", int(w.get("version", 0)), TEMPLATES.VERSION)
	fw.check("meta.name terisi", not String(w.get("meta", {}).get("name", "")).is_empty())
	fw.check_eq("meta.is_template", bool(w.get("meta", {}).get("is_template", false)), true)
	fw.check_eq("settings.game_mode", String(w.get("settings", {}).get("game_mode", "")), "empty")
	fw.check_eq(
		"template empty mengizinkan build",
		bool(w.get("settings", {}).get("build_allowed", false)),
		true
	)
	var blocks: Array = w.get("blocks", [])
	fw.check_gt("template empty punya ground block", blocks.size(), 0)
	var spawns: Array = w.get("spawn_points", [])
	fw.check("spawn_points terisi", spawns.size() > 0 and (spawns[0] as Array).size() >= 3)

	# Struktur blok memenuhi kontrak skema.
	var ok_schema := true
	for b in TEMPLATES.build_world_json("obby").get("blocks", []):
		var bd: Dictionary = b
		for k in ["id", "shape", "pos", "size", "color", "mat", "anchored"]:
			if not bd.has(k):
				ok_schema = false
		if (bd.get("pos") as Array).size() != 3 or (bd.get("size") as Array).size() != 3:
			ok_schema = false

		# Id tak dikenal jatuh ke "empty".
	fw.check("semua blok obby punya field skema lengkap", ok_schema)

	# Id tak dikenal jatuh ke "empty".
	var unknown: Dictionary = TEMPLATES.build_world_json("template_tidak_ada")
	fw.check_eq(
		"id tak dikenal -> fallback empty",
		String(unknown.get("settings", {}).get("game_mode", "")),
		"empty"
	)


func _test_roundtrip() -> void:
	fw.section("SaveManager: roundtrip save/load")
	var world := _make_world("reablox-world")
	fw.check_eq("save_world sukses", Saves.save_world(NAME_MAIN, world), OK)
	fw.check("file tersimpan di WORLDS_DIR", FileAccess.file_exists(PATH_MAIN))

	var loaded: Dictionary = Saves.load_world(PATH_MAIN)
	fw.check("load_world mengembalikan data", not loaded.is_empty())
	fw.check_eq("format tetap", String(loaded.get("format", "")), "reablox-world")
	fw.check_eq("version tetap", int(loaded.get("version", 0)), 1)
	fw.check_eq(
		"meta.name distempel save_world", String(loaded.get("meta", {}).get("name", "")), NAME_MAIN
	)

	var lb: Array = loaded.get("blocks", [])
	fw.check_eq("jumlah blok tetap", lb.size(), 2)
	var b1: Dictionary = lb[0] if lb.size() > 0 else {}
	fw.check_eq("posisi blok k1 tetap", b1.get("pos", []), [1.0, 0.5, 2.0])
	fw.check_eq("ukuran blok k1 tetap", b1.get("size", []), [2.0, 1.0, 2.0])
	fw.check_eq("warna blok k1 tetap", String(b1.get("color", "")), "#ff0000")
	fw.check_eq("material blok k1 tetap", String(b1.get("mat", "")), "neon")
	fw.check_eq("anchored blok k1 tetap", bool(b1.get("anchored", true)), true)
	var b2: Dictionary = lb[1] if lb.size() > 1 else {}
	fw.check_eq("script blok k2 tetap", String(b2.get("script", "")), "move(1, 0, 0)")
	fw.check_eq("anchored blok k2 tetap", bool(b2.get("anchored", true)), false)

	var s: Dictionary = loaded.get("settings", {})
	fw.check_eq("settings.game_mode tetap", String(s.get("game_mode", "")), "adventure")
	fw.check_eq("settings.cycle_minutes tetap", float(s.get("cycle_minutes", 0.0)), 7.5)
	fw.check_eq("settings.weather tetap", String(s.get("weather", "")), "fog")
	fw.check_eq("settings.build_allowed tetap", bool(s.get("build_allowed", false)), true)
	fw.check_eq("settings.spawn tetap", s.get("spawn", []), [1.5, 3.0, -2.5])
	fw.check_eq(
		"spawn_points tetap", loaded.get("spawn_points", []), [[1.5, 3.0, -2.5], [10.0, 2.0, 4.0]]
	)
	fw.check_eq("props tetap", (loaded.get("props", []) as Array).size(), 1)

	var t: Dictionary = loaded.get("terrain", {})
	fw.check_eq("terrain.size tetap", int(t.get("size", 0)), 8)
	fw.check_eq("terrain.seed tetap", int(t.get("seed", 0)), 99)
	fw.check_eq("terrain.heights tetap", (t.get("heights", []) as Array).size(), 64)
	fw.check_eq("terrain.heights[9] tetap", int((t.get("heights", []) as Array)[9]), 1)
	fw.check_eq("terrain.paint[3] tetap", String((t.get("paint", []) as Array)[3]), "rock")

	# Dunia tersimpan muncul di daftar dengan meta benar.
	var entry := {}
	for w in Saves.list_worlds():
		if String(w.get("path", "")) == PATH_MAIN:
			entry = w
			break
	fw.check("list_worlds memuat dunia test", not entry.is_empty())
	fw.check_eq("nama di list_worlds", String(entry.get("name", "")), NAME_MAIN)
	fw.check_eq("is_template false di list", bool(entry.get("is_template", true)), false)
	fw.check_gt("modified time terisi", int(entry.get("modified", 0)), 0)


func _test_legacy_format() -> void:
	fw.section("SaveManager: legacy format rblox-world")
	var legacy := _make_world("rblox-world")
	fw.check_eq("save dunia legacy sukses", Saves.save_world(NAME_LEGACY, legacy), OK)
	var loaded: Dictionary = Saves.load_world(PATH_LEGACY)
	fw.check("loader menerima format lama rblox-world", not loaded.is_empty())
	fw.check_eq("format lama tidak ditulis ulang", String(loaded.get("format", "")), "rblox-world")
	fw.check_eq("blok dunia legacy tetap", (loaded.get("blocks", []) as Array).size(), 2)


func _test_corrupt_input() -> void:
	fw.section("SaveManager: input korup ditolak aman")
	fw.check_eq("path tidak ada -> {}", Saves.load_world("user://worlds/tidak_ada.myworld"), {})

	_write_raw(PATH_CORRUPT, "")
	fw.check_eq("file kosong -> {}", Saves.load_world(PATH_CORRUPT), {})

	_write_raw(PATH_CORRUPT, "ini bukan json {{{")
	fw.check_eq("JSON rusak -> {}", Saves.load_world(PATH_CORRUPT), {})

	_write_raw(PATH_CORRUPT, "[1, 2, 3]")
	fw.check_eq("JSON non-dict -> {}", Saves.load_world(PATH_CORRUPT), {})

	_write_raw(PATH_CORRUPT, '{"format": "minecraft", "blocks": []}')
	fw.check_eq("format tak dikenal -> {}", Saves.load_world(PATH_CORRUPT), {})

	var listed := false
	for w in Saves.list_worlds():
		if String(w.get("path", "")) == PATH_CORRUPT:
			listed = true
	fw.check("list_worlds melewati file korup", not listed)


func _test_delete_validation() -> void:
	fw.section("SaveManager: delete_world validasi path")
	# Kasus valid: dunia sendiri di WORLDS_DIR.
	fw.check_eq("delete dunia milik sendiri -> OK", Saves.delete_world(PATH_LEGACY), OK)
	fw.check("file legacy benar-benar terhapus", not FileAccess.file_exists(PATH_LEGACY))
	fw.check_eq("load setelah delete -> {}", Saves.load_world(PATH_LEGACY), {})

	# Path valid tapi file tidak ada: tetap lolos validasi, gagal di remove.
	var ghost := Saves.delete_world("user://worlds/test_suite_ghost.myworld")
	fw.check("delete file hilang -> error (bukan OK)", ghost != OK)

	# Kasus invalid: file nyata di luar WORLDS_DIR tidak boleh terhapus.
	_write_raw(PATH_FOREIGN, JSON.stringify(_make_world("reablox-world")))
	fw.check("file asing (imports) disiapkan", FileAccess.file_exists(PATH_FOREIGN))
	fw.check_eq(
		"delete di luar WORLDS_DIR ditolak", Saves.delete_world(PATH_FOREIGN), ERR_INVALID_PARAMETER
	)
	fw.check("file asing masih utuh", FileAccess.file_exists(PATH_FOREIGN))

	fw.check_eq(
		"delete path relatif ditolak",
		Saves.delete_world("worlds/apa_pun.myworld"),
		ERR_INVALID_PARAMETER
	)
	fw.check_eq(
		"delete res:// ditolak", Saves.delete_world("res://project.godot"), ERR_INVALID_PARAMETER
	)
	fw.check("project.godot masih ada", FileAccess.file_exists("res://project.godot"))

	# Regresi prefix: "user://worlds" tanpa "/" dulu cocok dengan
	# "user://worlds_evil/..." sehingga file di luar WORLDS_DIR bisa dihapus.
	_write_raw(PATH_EVIL, JSON.stringify(_make_world("reablox-world")))
	fw.check("file jebakan worlds_evil disiapkan", FileAccess.file_exists(PATH_EVIL))
	fw.check_eq(
		"delete prefix kembar (worlds_evil) ditolak",
		Saves.delete_world(PATH_EVIL),
		ERR_INVALID_PARAMETER
	)
	fw.check("file jebakan worlds_evil masih utuh", FileAccess.file_exists(PATH_EVIL))


func _test_export_import() -> void:
	fw.section("SaveManager: export/import")
	fw.check_eq(
		'export sumber hilang -> ""', Saves.export_world("user://worlds/tidak_ada.myworld"), ""
	)

	# Dunia utama disimpan lalu diekspor.
	fw.check_eq(
		"save dunia ekspor", Saves.save_world(NAME_EXPORT, _make_world("reablox-world")), OK
	)
	var dest := Saves.export_world(PATH_EXPORT)
	fw.check_eq("export ke EXPORTS_DIR", dest, PATH_EXPORTED)
	fw.check("file ekspor ada", FileAccess.file_exists(PATH_EXPORTED))
	var exported: Dictionary = Saves.load_world(PATH_EXPORTED)
	fw.check("file ekspor valid", not exported.is_empty())
	fw.check_eq("isi ekspor: jumlah blok", (exported.get("blocks", []) as Array).size(), 2)
	fw.check_eq("isi ekspor: nama", String(exported.get("meta", {}).get("name", "")), NAME_EXPORT)

	# Impor: sumber asing (folder imports) masuk ke worlds dengan nama tersanitasi.
	_write_raw(
		PATH_IMPORT_SRC,
		JSON.stringify(_make_world("reablox-world")).replace('"Awal"', '"' + NAME_IMPORT + '"')
	)
	fw.check("sumber impor disiapkan", FileAccess.file_exists(PATH_IMPORT_SRC))
	var imported := Saves.import_world(PATH_IMPORT_SRC)
	fw.check_eq("impor ke WORLDS_DIR tersanitasi", imported, PATH_IMPORT)
	var imp: Dictionary = Saves.load_world(PATH_IMPORT)
	fw.check("hasil impor bisa dimuat", not imp.is_empty())
	fw.check_eq(
		"hasil impor memakai meta.name", String(imp.get("meta", {}).get("name", "")), NAME_IMPORT
	)
	fw.check_eq("hasil impor: jumlah blok", (imp.get("blocks", []) as Array).size(), 2)

	fw.check_eq(
		'impor sumber hilang -> ""', Saves.import_world("user://imports/tidak_ada.myworld"), ""
	)
	_write_raw(PATH_IMPORT_BAD, '{"format": "minecraft"}')
	fw.check_eq('impor format invalid -> ""', Saves.import_world(PATH_IMPORT_BAD), "")


# ------------------------------------------------------------------ cleanup


func _cleanup_files() -> void:
	fw.section("Cleanup berkas temp")
	var removed := 0
	for p in [PATH_MAIN, PATH_EXPORT, PATH_IMPORT, PATH_CORRUPT]:
		if FileAccess.file_exists(p):
			removed += 1 if Saves.delete_world(p) == OK else 0

		# Dir sementara worlds_evil ikut dibongkar (file trap dibuang manual
		# karena berada di luar WORLDS_DIR — delete_world menolaknya).
	fw.check_eq("dunia temp dihapus via delete_world", removed, 4)
	fw.check_eq(
		"file asing (imports) dibersihkan",
		_remove_raw([PATH_FOREIGN, PATH_IMPORT_SRC, PATH_IMPORT_BAD, PATH_EXPORTED]),
		4
	)

	# Dir sementara worlds_evil ikut dibongkar (file trap dibuang manual
	# karena berada di luar WORLDS_DIR — delete_world menolaknya).
	if FileAccess.file_exists(PATH_EVIL):
		DirAccess.remove_absolute(PATH_EVIL)
	fw.check("dir worlds_evil dikosongkan", DirAccess.get_files_at(DIR_EVIL).is_empty())
	DirAccess.remove_absolute(DIR_EVIL)
	fw.check("dir worlds_evil dihapus", not DirAccess.dir_exists_absolute(DIR_EVIL))

	var leftovers := 0
	for dir in [Saves.WORLDS_DIR, Saves.EXPORTS_DIR, Saves.IMPORTS_DIR]:
		for f in DirAccess.get_files_at(dir):
			if String(f).begins_with("test_suite"):
				leftovers += 1
	fw.check_eq("tidak ada sisa file test_suite", leftovers, 0)
	fw.check("project utuh di akhir suite", FileAccess.file_exists("res://project.godot"))


func _remove_raw(paths: Array) -> int:
	var n := 0
	for p in paths:
		if FileAccess.file_exists(String(p)) and DirAccess.remove_absolute(String(p)) == OK:
			n += 1
	return n
