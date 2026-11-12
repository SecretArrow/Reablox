extends Node
## GameState — mode permainan, statistik sesi (leaderstats ala Roblox), dan
## persistensi ringkas progres pemain lewat Saves (user://profile.json).
##
## Profil berisi coins, stage, checkpoint_index, current_world, player_name;
## disimpan setiap kali nilai tersebut berubah (on-change) supaya progres
## tidak hilang saat aplikasi ditutup paksa. deaths hanya statistik sesi.

enum Mode { MODE_MENU, MODE_PLAY, MODE_BUILD }

var mode: Mode = Mode.MODE_MENU
var current_world := ""
var coins := 0
var stage := 1
var deaths := 0
var checkpoint_index := 0
var player_name := "Pemain"


func _ready() -> void:
	player_name = Settings.get_player_name()
	_load_profile()


func _load_profile() -> void:
	var profile := Saves.load_profile()
	if profile.is_empty():
		return
	coins = maxi(int(profile.get("coins", 0)), 0)
	stage = maxi(int(profile.get("stage", 1)), 1)
	checkpoint_index = maxi(int(profile.get("checkpoint_index", 0)), 0)
	current_world = str(profile.get("current_world", ""))


## Simpan progres saat ini ke user://profile.json (tulis atomik via Saves).
func save_profile() -> void:
	var data := {
		"coins": coins,
		"stage": stage,
		"checkpoint_index": checkpoint_index,
		"current_world": current_world,
		"player_name": player_name,
	}
	Saves.save_profile(data)


## Ringkasan status untuk UI (leaderstats / menu jeda).
func get_profile_summary() -> Dictionary:
	return {
		"coins": coins,
		"stage": stage,
		"deaths": deaths,
		"checkpoint_index": checkpoint_index,
		"current_world": current_world,
		"player_name": player_name,
		"mode": mode,
	}


func set_mode(new_mode: Mode) -> void:
	mode = new_mode


func in_build_mode() -> bool:
	return mode == Mode.MODE_BUILD


func reset_run(world_name: String) -> void:
	current_world = world_name
	coins = 0
	stage = 1
	deaths = 0
	checkpoint_index = 0
	mode = Mode.MODE_PLAY
	GameEvents.coins_changed.emit(coins)
	GameEvents.stage_changed.emit(stage)
	save_profile()


func add_coins(n: int) -> void:
	coins += maxi(n, 0)
	GameEvents.coins_changed.emit(coins)
	save_profile()


func spend_coins(n: int) -> bool:
	if n < 0 or coins < n:
		return false
	coins -= n
	GameEvents.coins_changed.emit(coins)
	save_profile()
	return true


func record_death() -> void:
	deaths += 1


func next_stage() -> void:
	stage += 1
	GameEvents.stage_changed.emit(stage)
	save_profile()


func activate_checkpoint(index: int) -> void:
	if index > checkpoint_index:
		checkpoint_index = index
		GameEvents.checkpoint_activated.emit(index)
		save_profile()
