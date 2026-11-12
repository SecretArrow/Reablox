extends Node
## Suite unit modul CORE — konstanta GameConfig, input map, sinyal GameEvents,
## clamp Settings, Locale, Audio, GameState, SceneLoader, Screenshot.
## Pola kontrak §8 (deterministik, tidak bergantung suite lain).

const FW := preload("res://tools/tests/test_framework.gd")

const BASIC_ACTIONS := [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"sprint",
	"interact",
	"ui_menu",
	"ui_chat",
	"zoom_in",
	"zoom_out",
	"build_rotate",
	"build_delete",
	"build_duplicate",
	"build_undo",
	"build_redo",
	"build_grid",
]
const SFX_NAMES := [
	"jump",
	"land",
	"footstep_grass",
	"footstep_stone",
	"coin",
	"sword_swing",
	"sword_hit",
	"hurt",
	"die",
	"respawn",
	"ui_click",
	"ui_hover",
	"place_block",
	"remove_block",
	"checkpoint",
	"splash",
	"npc_growl",
]

var fw: Node

# Flag untuk round-trip sinyal (di-set oleh handler, dibaca suite).
var _flag_coins := false
var _flag_stage := false
var _flag_toast := false
var _got_coins := -1
var _got_stage := -1
var _got_toast := ""


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_test_game_config()
	_test_game_events()
	_test_settings()
	_test_locale()
	_test_audio()
	_test_game_state()
	_test_scene_loader()
	_test_screenshot()


# --- GameConfig + input map -------------------------------------------------------


func _test_game_config() -> void:
	fw.section("GameConfig")
	fw.check_eq("WALK_SPEED", GameConfig.WALK_SPEED, 16.0)
	fw.check_eq("JUMP_HEIGHT", GameConfig.JUMP_HEIGHT, 7.2)
	fw.check_eq("GRAVITY", GameConfig.GRAVITY, 196.2)
	fw.check_eq("MAX_HEALTH", GameConfig.MAX_HEALTH, 100.0)
	fw.check_eq("RESPAWN_TIME", GameConfig.RESPAWN_TIME, 5.0)
	fw.check_eq("MAX_HOTBAR", GameConfig.MAX_HOTBAR, 9)
	var missing: Array[String] = []
	for action in BASIC_ACTIONS:
		if not _action_ok(action):
			missing.append(action)
	fw.check("semua 17 action inti terdaftar + berbinding", missing.is_empty())
	var hotbar_ok := true
	for i in range(9):
		if not _action_ok("hotbar_%d" % (i + 1)):
			hotbar_ok = false
	fw.check("action hotbar_1..hotbar_9 terdaftar", hotbar_ok)


func _action_ok(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	return not InputMap.action_get_events(action).is_empty()


# --- GameEvents round-trip ---------------------------------------------------------


func _test_game_events() -> void:
	fw.section("GameEvents")
	GameEvents.coins_changed.connect(_on_test_coins)
	GameEvents.stage_changed.connect(_on_test_stage)
	GameEvents.toast_requested.connect(_on_test_toast)
	GameEvents.coins_changed.emit(42)
	GameEvents.stage_changed.emit(7)
	GameEvents.toast_requested.emit("Halo")
	fw.check("round-trip coins_changed", _flag_coins and _got_coins == 42)
	fw.check("round-trip stage_changed", _flag_stage and _got_stage == 7)
	fw.check("round-trip toast_requested", _flag_toast and _got_toast == "Halo")
	GameEvents.coins_changed.disconnect(_on_test_coins)
	GameEvents.stage_changed.disconnect(_on_test_stage)
	GameEvents.toast_requested.disconnect(_on_test_toast)


func _on_test_coins(total: int) -> void:
	_flag_coins = true
	_got_coins = total


func _on_test_stage(stage: int) -> void:
	_flag_stage = true
	_got_stage = stage


func _on_test_toast(message: String) -> void:
	_flag_toast = true
	_got_toast = message


# --- Settings (clamp + reset) -----------------------------------------------------


func _test_settings() -> void:
	fw.section("Settings")
	Settings.reset_to_defaults()
	fw.check_eq("default quality", Settings.get_quality(), 1)
	fw.check_eq("default sensitivity", Settings.get_sensitivity(), 0.5)
	Settings.set_quality(9)
	fw.check_eq("quality 9 di-clamp ke 2", Settings.get_quality(), 2)
	Settings.set_quality(-5)
	fw.check_eq("quality -5 di-clamp ke 0", Settings.get_quality(), 0)
	Settings.set_sensitivity(5.0)
	fw.check("sensitivity 5 di-clamp ke 1.0", is_equal_approx(Settings.get_sensitivity(), 1.0))
	Settings.set_sensitivity(0.001)
	fw.check("sensitivity min 0.05", is_equal_approx(Settings.get_sensitivity(), 0.05))
	Settings.set_vol_master(2.0)
	fw.check("vol_master di-clamp ke 1.0", is_equal_approx(Settings.get_vol_master(), 1.0))
	Settings.set_vol_sfx(-1.0)
	fw.check("vol_sfx di-clamp ke 0.0", is_equal_approx(Settings.get_vol_sfx(), 0.0))
	Settings.set_player_name("  Budi  ")
	fw.check_eq("player_name di-trim", Settings.get_player_name(), "Budi")
	Settings.set_player_name("B".repeat(30))
	fw.check_eq("player_name dipotong 16", Settings.get_player_name().length(), 16)
	Settings.set_locale("fr")
	fw.check_eq("locale invalid jatuh ke id", Settings.get_locale(), "id")
	Settings.set_invert_y(true)
	fw.check_eq("invert_y tersimpan", Settings.get_invert_y(), true)
	Settings.reset_to_defaults()
	fw.check_eq("reset: quality kembali 1", Settings.get_quality(), 1)
	fw.check_eq("reset: player_name kembali default", Settings.get_player_name(), "Pemain")
	fw.check_eq("reset: invert_y kembali false", Settings.get_invert_y(), false)


# --- Locale ------------------------------------------------------------------------


func _test_locale() -> void:
	fw.section("Locale")
	Locale.set_locale("id")
	fw.check_eq("set_locale id", Locale.get_locale(), "id")
	fw.check_eq("missing key pakai fallback", Locale.tr_key("kunci_tidak_ada", "fb"), "fb")
	fw.check_eq("missing key tanpa fallback", Locale.tr_key("kunci_tidak_ada"), "kunci_tidak_ada")
	fw.check("key_count > 0", Locale.key_count() > 0)
	fw.check_eq("missing_keys deteksi zzz", Locale.missing_keys(["zzz"]), ["zzz"])
	fw.check_eq("missing_keys kosong untuk kunci ada", Locale.missing_keys(["app_name"]), [])
	var avail := Locale.available()
	fw.check("locale id dan en tersedia", avail.has("id") and avail.has("en"))


# --- Audio -------------------------------------------------------------------------


func _test_audio() -> void:
	fw.section("Audio")
	fw.check_eq("jumlah aset SFX diperiksa", SFX_NAMES.size(), 17)
	var missing: Array[String] = []
	for sfx_name in SFX_NAMES:
		if not Audio.has_sfx(sfx_name):
			missing.append(sfx_name)
	fw.check("semua 17 SFX tersedia", missing.is_empty())
	Audio.play_sfx("tak_ada")
	fw.check("play_sfx nama tak dikenal aman", true)
	Audio.play_music("menu")
	fw.check("play_music menu aman", true)
	Audio.play_music("tak_ada")
	fw.check("play_music nama tak dikenal aman", true)
	Audio.stop_music()
	fw.check("stop_music aman", true)


# --- GameState ---------------------------------------------------------------------


func _test_game_state() -> void:
	fw.section("GameState")
	GameState.reset_run("DuniaTes")
	fw.check_eq("reset_run: coins 0", GameState.coins, 0)
	fw.check_eq("reset_run: stage 1", GameState.stage, 1)
	fw.check_eq("reset_run: checkpoint 0", GameState.checkpoint_index, 0)
	GameState.add_coins(5)
	fw.check_eq("add_coins(5)", GameState.coins, 5)
	fw.check("spend_coins(3) berhasil", GameState.spend_coins(3))
	fw.check_eq("coins setelah spend 3", GameState.coins, 2)
	fw.check("spend_coins(999) ditolak", not GameState.spend_coins(999))
	fw.check_eq("coins tetap 2 setelah ditolak", GameState.coins, 2)
	GameState.activate_checkpoint(2)
	fw.check_eq("checkpoint naik ke 2", GameState.checkpoint_index, 2)
	GameState.activate_checkpoint(1)
	fw.check_eq("checkpoint tidak turun", GameState.checkpoint_index, 2)
	GameState.next_stage()
	fw.check_eq("next_stage ke 2", GameState.stage, 2)
	var summary := GameState.get_profile_summary()
	fw.check("summary bertipe Dictionary", summary is Dictionary)
	fw.check_eq("summary coins sinkron", int(summary.get("coins", -1)), 2)
	GameState.record_death()
	fw.check("record_death menambah deaths", GameState.deaths == 1)
	GameState.reset_run("X")
	fw.check_eq("reset ulang: coins 0", GameState.coins, 0)
	fw.check_eq("reset ulang: stage 1", GameState.stage, 1)
	fw.check_eq("reset ulang: checkpoint 0", GameState.checkpoint_index, 0)
	fw.check_eq("reset ulang: current_world X", GameState.current_world, "X")


# --- SceneLoader --------------------------------------------------------------------


func _test_scene_loader() -> void:
	fw.section("SceneLoader")
	fw.check("scene tidak ada -> false", not SceneLoader.goto_scene("res://tidak_ada.tscn"))


# --- Screenshot ---------------------------------------------------------------------


func _test_screenshot() -> void:
	fw.section("Screenshot")
	var shot := Screenshot.new()
	add_child(shot)
	fw.check_eq("capture headless mengembalikan string kosong", shot.capture(), "")
	remove_child(shot)
	shot.free()
	var liar := Screenshot.new()
	fw.check_eq("capture di luar scene tree aman", liar.capture(), "")
	liar.free()
