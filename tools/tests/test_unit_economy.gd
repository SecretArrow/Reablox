extends Node
## Unit test: GameState (autoload `GameState`) — "ekonomi" offline game:
## statistik (add_stat/get_stat), achievement (unlock_achievement), avatar,
## dan persistensi user://progress.json & user://avatar.json.
##
## CATATAN PENTING: game_state.gd TIDAK memiliki API koin/XP/level (tidak ada
## earn/spend balance). Penghargaan gameplay nyata (adventure.gd, racing.gd,
## build_manager.gd) hanya berupa add_stat(...) + unlock_achievement(...) —
## suite ini menguji API nyata tersebut, termasuk replika alurnya.
##
## Order-independent: GameState adalah autoload shared -> seluruh state
## (termasuk field internal _stats/_achievements yang dibaca dari source)
## di-snapshot di awal lalu dipulihkan penuh di akhir suite, termasuk
## isi file progress.json/avatar.json di disk.

const FW := preload("res://tools/tests/test_framework.gd")

const PROGRESS_PATH := "user://progress.json"
const AVATAR_PATH := "user://avatar.json"

var fw := FW.new()

var _stats_snap: Dictionary = {}
var _ach_snap: Dictionary = {}
var _avatar_snap: Dictionary = {}
var _had_progress := false
var _had_avatar := false
var _ach_signals: Array = []
var _avatar_signals := 0


func _ready() -> void:
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	# --- snapshot SEBELUM mutasi apa pun (autoload shared antar suite) ---
	_stats_snap = GameState._stats.duplicate(true)
	_ach_snap = GameState._achievements.duplicate(true)
	_avatar_snap = GameState.avatar_config.duplicate(true)
	_had_progress = FileAccess.file_exists(PROGRESS_PATH)
	_had_avatar = FileAccess.file_exists(AVATAR_PATH)

	_test_initial_state()
	_test_api_surface()
	_test_default_avatar()
	_test_add_stat()
	_test_gameplay_award_flows()
	_test_achievements()
	_test_state_isolation()
	_test_persistence()
	_test_avatar_config()
	_restore_all()
	_test_restore_verification()


# ------------------------------------------------------------ nilai awal


func _test_initial_state() -> void:
	fw.section("GameState: nilai awal")
	fw.check_eq("get_stat kunci baru == 0", GameState.get_stat("zz_probe_stat"), 0)
	fw.check("get_stat mengembalikan int", typeof(GameState.get_stat("zz_probe_stat")) == TYPE_INT)
	fw.check(
		"achievements_state() mengembalikan Dictionary",
		typeof(GameState.achievements_state()) == TYPE_DICTIONARY
	)
	fw.check_eq(
		"is_achievement_unlocked id tak dikenal == false",
		GameState.is_achievement_unlocked("zz_probe_ach"),
		false
	)
	fw.check(
		"player_name terisi (diatur saat _ready)",
		not GameState.player_name.strip_edges().is_empty()
	)
	fw.check_eq("is_multiplayer() == false di lingkungan test", GameState.is_multiplayer(), false)
	fw.check_eq("is_host() == false di lingkungan test", GameState.is_host(), false)


func _test_api_surface() -> void:
	fw.section("GameState: bentuk API (ekonomi = stats + achievement)")
	for m in [
		"add_stat",
		"get_stat",
		"unlock_achievement",
		"is_achievement_unlocked",
		"achievements_state"
	]:
		fw.check("method %s() tersedia" % [m], GameState.has_method(m))
	# Karakterisasi permukaan API: memang belum ada koin/XP/level.
	var present: Array = []
	for m in [
		"add_coins",
		"get_coins",
		"spend_coins",
		"spend",
		"add_xp",
		"gain_xp",
		"get_xp",
		"set_level",
		"level_up",
		"get_level"
	]:
		if GameState.has_method(m):
			present.append(m)
	fw.check("API koin/XP/level belum ada di game_state.gd %s" % [str(present)], present.is_empty())


func _test_default_avatar() -> void:
	fw.section("GameState: DEFAULT_AVATAR")
	var da: Dictionary = GameState.DEFAULT_AVATAR
	fw.check(
		"kunci warna ada (skin/shirt/pants/hair)", da.has_all(["skin", "shirt", "pants", "hair"])
	)
	fw.check("kunci face ada", da.has("face"))
	var eq_v: Variant = da.get("equipped", {})
	fw.check("equipped adalah Dictionary", eq_v is Dictionary)
	if eq_v is Dictionary:
		var eq: Dictionary = eq_v
		for slot in ["hat", "hair", "face", "shirt", "pants", "accessory", "wings", "back", "hand"]:
			fw.check("slot equipped '%s' ada" % [slot], eq.has(slot))
		fw.check("default hair terpasang (tidak kosong)", String(eq.get("hair", "")) != "")
	var sentinel := Color(1.0, 0.0, 1.0, 1.0)
	var bad_cols: Array = []
	for ck in ["skin", "shirt", "pants", "hair"]:
		var c := Color.from_string(String(da.get(ck, "bukan-warna")), sentinel)
		if c == sentinel:
			bad_cols.append(ck)
	fw.check("warna default parse valid (#hex) %s" % [str(bad_cols)], bad_cols.is_empty())


# ----------------------------------------------------------------- stats


func _test_add_stat() -> void:
	fw.section("GameState.add_stat: akumulasi tepat & nilai balik")
	var base := GameState.get_stat("zz_probe_stat")
	fw.check_eq("add_stat() default amount=1 -> +1", GameState.add_stat("zz_probe_stat"), base + 1)
	fw.check_eq("get_stat mencerminkan total baru", GameState.get_stat("zz_probe_stat"), base + 1)
	fw.check_eq("add_stat() lagi -> akumulasi", GameState.add_stat("zz_probe_stat"), base + 2)
	fw.check_eq(
		"add_stat(x, 10) menambah tepat 10", GameState.add_stat("zz_probe_stat", 10), base + 12
	)
	fw.check_eq("total akhir sesuai jumlah", GameState.get_stat("zz_probe_stat"), base + 12)
	var r := GameState.add_stat("zz_probe_stat2", 5)
	fw.check_eq("kunci baru dengan amount eksplisit 5", r, 5)
	fw.check_eq("nilai balik == get_stat (total baru)", GameState.get_stat("zz_probe_stat2"), r)
	# Perilaku nyata: tidak ada guard jumlah negatif (tidak di-clamp).
	fw.check_eq(
		"amount negatif diterima apa adanya (tanpa guard) — perilaku nyata",
		GameState.add_stat("zz_probe_stat2", -2),
		3
	)


func _test_gameplay_award_flows() -> void:
	fw.section("GameState: alur penghargaan gameplay nyata (mode scripts)")
	# adventure.gd:49 — peti terbuka: GameState.add_stat("chests_opened", 1)
	var chest_before := GameState.get_stat("chests_opened")
	GameState.add_stat("chests_opened", 1)
	fw.check_eq(
		"hadiah peti (adventure.gd) menambah stat tepat 1",
		GameState.get_stat("chests_opened"),
		chest_before + 1
	)
	# build_manager.gd:168 — tiap blok: GameState.add_stat("blocks_placed")
	var blocks_before := GameState.get_stat("blocks_placed")
	var total := GameState.add_stat("blocks_placed")  # amount default 1, persis build_manager
	fw.check_eq("blok terpasang (build_manager.gd) menambah stat tepat 1", total, blocks_before + 1)
	# build_manager.gd:170-171 — kondisi builder_100: total >= 100 (batas tepat).
	var sim := GameState.add_stat("zz_build_sim", 99)
	fw.check("total 99: kondisi builder_100 (total >= 100) belum terpenuhi", not (sim >= 100))
	sim = GameState.add_stat("zz_build_sim", 1)
	fw.check("total 100: kondisi builder_100 terpenuhi (batas tepat)", sim >= 100)
	# racing.gd:59 — menang balapan: GameState.unlock_achievement("win_race")
	var race_was := GameState.is_achievement_unlocked("win_race")
	var race_ret := GameState.unlock_achievement("win_race")
	if race_was:
		fw.check_eq("win_race sudah terbuka -> unlock ulang false (idempoten)", race_ret, false)
	else:
		fw.check_eq("kemenangan balapan (racing.gd) -> unlock true", race_ret, true)
	fw.check("win_race terbuka setelah alur", GameState.is_achievement_unlocked("win_race"))


# ---------------------------------------------------------- achievements


func _test_achievements() -> void:
	fw.section("GameState.unlock_achievement: unlock, idempoten, sinyal")
	GameState.achievement_unlocked.connect(_on_achievement)
	_ach_signals = []
	var size_before := GameState.achievements_state().size()

	fw.check_eq("unlock pertama -> true", GameState.unlock_achievement("zz_probe_ach"), true)
	fw.check_eq(
		"is_achievement_unlocked -> true", GameState.is_achievement_unlocked("zz_probe_ach"), true
	)
	fw.check_eq(
		"unlock kedua -> false (idempoten, tanpa reward ganda)",
		GameState.unlock_achievement("zz_probe_ach"),
		false
	)
	fw.check(
		"tetap terbuka setelah unlock ulang", GameState.is_achievement_unlocked("zz_probe_ach")
	)
	fw.check_eq("sinyal achievement_unlocked terpicu tepat 1x", _ach_signals.size(), 1)
	if _ach_signals.size() >= 1:
		fw.check_eq(
			"sinyal membawa (id, title==id) sesuai emit(id, id)",
			_ach_signals[0],
			["zz_probe_ach", "zz_probe_ach"]
		)
	fw.check_eq(
		"jumlah entri achievements bertambah tepat 1 (tanpa duplikat)",
		GameState.achievements_state().size(),
		size_before + 1
	)
	fw.check_eq(
		"entri probe bernilai true",
		bool(GameState.achievements_state().get("zz_probe_ach", false)),
		true
	)
	GameState.achievement_unlocked.disconnect(_on_achievement)


func _test_state_isolation() -> void:
	fw.section("GameState.achievements_state: salinan terisolasi")
	var st := GameState.achievements_state()
	st["zz_probe_ach"] = false
	st["zz_probe_fake"] = true
	fw.check(
		"mutasi salinan tak mengubah internal (probe tetap true)",
		GameState.is_achievement_unlocked("zz_probe_ach")
	)
	fw.check_eq(
		"kunci palsu tak masuk internal", GameState.is_achievement_unlocked("zz_probe_fake"), false
	)


# ------------------------------------------------------------ persistensi


func _test_persistence() -> void:
	fw.section("GameState: persistensi user://progress.json")
	var disk := _read_json_user(PROGRESS_PATH)
	fw.check("progress.json terbaca & terisi", not disk.is_empty())
	var dstats: Dictionary = {}
	if disk.get("stats") is Dictionary:
		dstats = disk["stats"]
	var dach: Dictionary = {}
	if disk.get("achievements") is Dictionary:
		dach = disk["achievements"]
	fw.check_eq(
		"stat probe tersimpan ke disk (nilai final)",
		int(dstats.get("zz_probe_stat", -1)),
		GameState.get_stat("zz_probe_stat")
	)
	fw.check_eq("stat simulasi build tersimpan ke disk", int(dstats.get("zz_build_sim", -1)), 100)
	fw.check_eq("achievement probe tersimpan ke disk", bool(dach.get("zz_probe_ach", false)), true)


# ---------------------------------------------------------------- avatar


func _test_avatar_config() -> void:
	fw.section("GameState.set_avatar_config: roundtrip + sinyal + disk")
	var probe_cfg: Dictionary = _avatar_snap.duplicate(true)
	probe_cfg["skin"] = "#ff00ff"
	var eq_v: Variant = probe_cfg.get("equipped", {})
	if eq_v is Dictionary:
		var eq: Dictionary = (eq_v as Dictionary).duplicate(true)
		eq["hat"] = "zz_probe_hat"
		probe_cfg["equipped"] = eq
	else:
		probe_cfg["equipped"] = {"hat": "zz_probe_hat"}
	GameState.avatar_changed.connect(_on_avatar_changed)
	_avatar_signals = 0
	GameState.set_avatar_config(probe_cfg)
	fw.check_eq(
		"avatar_config.skin tersimpan (roundtrip)",
		String(GameState.avatar_config.get("skin", "")),
		"#ff00ff"
	)
	var eq_after: Dictionary = {}
	if GameState.avatar_config.get("equipped") is Dictionary:
		eq_after = GameState.avatar_config["equipped"]
	fw.check_eq("slot equipped hat tersimpan", String(eq_after.get("hat", "")), "zz_probe_hat")
	fw.check_eq("sinyal avatar_changed terpicu 1x", _avatar_signals, 1)
	var adisk := _read_json_user(AVATAR_PATH)
	fw.check_eq("avatar.json di disk memuat cfg baru", String(adisk.get("skin", "")), "#ff00ff")
	GameState.avatar_changed.disconnect(_on_avatar_changed)


# ---------------------------------------------------------------- restore


func _restore_all() -> void:
	# Pulihkan state memori + disk. Tidak ada API publik reset untuk
	# stats/achievements — field internal dipakai apa adanya dari source
	# (game_state.gd: _stats, _achievements, _save_progress) demi suite
	# order-independent.
	GameState._stats = _stats_snap.duplicate(true)
	GameState._achievements = _ach_snap.duplicate(true)
	GameState._save_progress()
	GameState.set_avatar_config(_avatar_snap.duplicate(true))
	if not _had_progress or not _had_avatar:
		var d := DirAccess.open("user://")
		if d != null:
			if not _had_progress:
				d.remove(PROGRESS_PATH.get_file())
			if not _had_avatar:
				d.remove(AVATAR_PATH.get_file())


func _test_restore_verification() -> void:
	fw.section("Restore: state awal GameState dipulihkan")
	fw.check_eq(
		"stat probe kembali ke nilai awal",
		GameState.get_stat("zz_probe_stat"),
		int(_stats_snap.get("zz_probe_stat", 0))
	)
	fw.check_eq(
		"stat probe2 kembali ke nilai awal",
		GameState.get_stat("zz_probe_stat2"),
		int(_stats_snap.get("zz_probe_stat2", 0))
	)
	fw.check_eq(
		"probe achievement kembali terkunci",
		GameState.is_achievement_unlocked("zz_probe_ach"),
		bool(_ach_snap.get("zz_probe_ach", false))
	)
	fw.check_eq(
		"avatar_config kembali ke awal (isi identik)", GameState.avatar_config, _avatar_snap
	)
	var disk := _read_json_user(PROGRESS_PATH)
	var dstats: Dictionary = {}
	if disk.get("stats") is Dictionary:
		dstats = disk["stats"]
	var dach: Dictionary = {}
	if disk.get("achievements") is Dictionary:
		dach = disk["achievements"]
	fw.check_eq("disk progress.json: stats identik dengan snapshot", dstats, _stats_snap)
	fw.check_eq("disk progress.json: achievements identik dengan snapshot", dach, _ach_snap)
	if not _had_progress:
		fw.check(
			"progress.json dihapus kembali (tidak ada sebelum suite)",
			not FileAccess.file_exists(PROGRESS_PATH)
		)
	if not _had_avatar:
		fw.check(
			"avatar.json dihapus kembali (tidak ada sebelum suite)",
			not FileAccess.file_exists(AVATAR_PATH)
		)


# ----------------------------------------------------------------- helper


func _on_achievement(id: String, title: String) -> void:
	_ach_signals.append([id, title])


func _on_avatar_changed() -> void:
	_avatar_signals += 1


func _read_json_user(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
