extends Node
## Suite unit Saves — sanitize nama dunia, round-trip dunia, unique/delete,
## list_worlds, dunia korup, tulis atomik (.tmp), batas ukuran 8 MB, profil.
## Pola kontrak §8 (deterministik: dunia uji dibersihkan di awal).

const FW := preload("res://tools/tests/test_framework.gd")

const TEST_WORLDS := [
	"Pulau Seru",
	"A",
	"A_2",
	"Korup",
	"TanpaVersi",
	"Besar",
	"PartsDunia",
	"Alpha",
	"Beta",
]

var fw: Node


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_cleanup_worlds()
	_test_sanitize_name()
	_test_world_roundtrip()
	_test_unique_and_delete()
	_test_list_worlds()
	_test_corrupt_and_missing()
	_test_atomic_and_limits()
	_test_profile()
	_cleanup_worlds()


## Hapus semua dunia uji supaya suite tidak bergantung riwayat eksekusi lama.
func _cleanup_worlds() -> void:
	for world_name in TEST_WORLDS:
		Saves.delete_world(world_name)


# --- sanitize_name -----------------------------------------------------------------


func _test_sanitize_name() -> void:
	fw.section("sanitize_name")
	fw.check_eq("nama normal tidak berubah", Saves.sanitize_name("Pulau Seru"), "Pulau Seru")
	fw.check_eq("nama kosong jadi Dunia", Saves.sanitize_name(""), "Dunia")
	fw.check("karakter path dibersihkan", not Saves.sanitize_name("../etc/pass").contains("/"))
	fw.check_eq("panjang dibatasi 32", Saves.sanitize_name("a".repeat(50)), "a".repeat(32))
	fw.check_eq("karakter aneh dibuang", Saves.sanitize_name("a!@#b"), "ab")


# --- save_world / load_world round-trip ---------------------------------------------


func _test_world_roundtrip() -> void:
	fw.section("save_world / load_world")
	var data := {
		"version": 1,
		"name": "Pulau Seru",
		"time_hour": 14.5,
		"parts": [{"id": 1, "type": "block"}, {"id": 2, "type": "sphere"}],
	}
	fw.check("simpan dunia berhasil", Saves.save_world("Pulau Seru", data))
	var loaded := Saves.load_world("Pulau Seru")
	fw.check_eq("round-trip name", str(loaded.get("name", "")), "Pulau Seru")
	fw.check_eq("round-trip version", int(loaded.get("version", 0)), 1)
	fw.check("round-trip time_hour", is_equal_approx(float(loaded.get("time_hour", 0.0)), 14.5))
	var parts: Array = loaded.get("parts", [])
	fw.check_eq("round-trip jumlah parts", parts.size(), 2)
	fw.check_gt("ada saved_at", float(loaded.get("saved_at", 0.0)), 0.0)
	fw.check("data asli tidak berubah", not data.has("saved_at"))
	fw.check("world_exists benar", Saves.world_exists("Pulau Seru"))


# --- unique_world_name / delete_world ------------------------------------------------


func _test_unique_and_delete() -> void:
	fw.section("unique_world_name / delete_world")
	fw.check_eq("nama unik saat bebas", Saves.unique_world_name("A"), "A")
	fw.check("simpan dunia A", Saves.save_world("A", {"version": 1}))
	fw.check_eq("nama unik saat terpakai", Saves.unique_world_name("A"), "A_2")
	fw.check("hapus dunia A berhasil", Saves.delete_world("A"))
	fw.check("hapus kedua kali gagal", not Saves.delete_world("A"))


# --- list_worlds ----------------------------------------------------------------------


func _test_list_worlds() -> void:
	fw.section("list_worlds")
	fw.check(
		"simpan PartsDunia", Saves.save_world("PartsDunia", {"version": 1, "parts": [1, 2, 3]})
	)
	fw.check("simpan Alpha", Saves.save_world("Alpha", {"version": 1, "parts": []}))
	fw.check("simpan Beta", Saves.save_world("Beta", {"version": 1, "parts": []}))
	var worlds := Saves.list_worlds()
	fw.check_gte("minimal 2 dunia terdaftar", worlds.size(), 2)
	fw.check_gt("daftar tidak kosong", worlds.size(), 0)
	fw.check(
		"urut terbaru lebih dulu",
		worlds.size() >= 2 and float(worlds[0]["saved_at"]) >= float(worlds[1]["saved_at"])
	)
	var names: Array[String] = []
	var parts_meta := -1
	for entry in worlds:
		var entry_name := str(entry.get("name", ""))
		names.append(entry_name)
		if entry_name == "PartsDunia":
			parts_meta = int(entry.get("parts", -1))
	fw.check("Beta terdaftar", names.has("Beta"))
	fw.check_eq("meta parts terisi (3)", parts_meta, 3)


# --- Dunia korup / hilang --------------------------------------------------------------


func _test_corrupt_and_missing() -> void:
	fw.section("Dunia korup / hilang")
	var f := FileAccess.open("user://worlds/Korup.json", FileAccess.WRITE)
	if f != null:
		f.store_string("bukan json")
		f.close()
	fw.check_eq("JSON korup -> kosong", Saves.load_world("Korup").size(), 0)
	var f2 := FileAccess.open("user://worlds/TanpaVersi.json", FileAccess.WRITE)
	if f2 != null:
		f2.store_string('{"name": "TanpaVersi"}')
		f2.close()
	fw.check_eq("tanpa version -> kosong", Saves.load_world("TanpaVersi").size(), 0)
	fw.check_eq("dunia tidak ada -> kosong", Saves.load_world("TidakAda"), {})


# --- Tulis atomik & batas ukuran --------------------------------------------------------


func _test_atomic_and_limits() -> void:
	fw.section("Tulis atomik & batas ukuran")
	fw.check("simpan ulang Beta", Saves.save_world("Beta", {"version": 1, "parts": []}))
	var tmp_count := 0
	var dir := DirAccess.open("user://worlds")
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while not fname.is_empty():
			if fname.ends_with(".tmp"):
				tmp_count += 1
			fname = dir.get_next()
		dir.list_dir_end()
	fw.check_eq("tidak ada file .tmp tersisa", tmp_count, 0)
	var big := "a".repeat(9 * 1024 * 1024)
	fw.check("payload raksasa ditolak", not Saves.save_world("Besar", {"version": 1, "blob": big}))
	fw.check("file raksasa tidak tercipta", not Saves.world_exists("Besar"))


# --- Profil ------------------------------------------------------------------------------


func _test_profile() -> void:
	fw.section("Profil")
	_remove_profile_file()
	fw.check_eq("profil hilang -> kosong", Saves.load_profile(), {})
	fw.check("simpan profil", Saves.save_profile({"coins": 7, "stage": 3}))
	var profile := Saves.load_profile()
	fw.check_eq("profil coins", int(profile.get("coins", 0)), 7)
	fw.check_eq("profil stage", int(profile.get("stage", 0)), 3)
	fw.check("profil tidak kosong", not profile.is_empty())


func _remove_profile_file() -> void:
	if FileAccess.file_exists("user://profile.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
