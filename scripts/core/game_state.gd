extends Node
## GameState — mode permainan & statistik sesi (leaderstats ala Roblox).

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


func add_coins(n: int) -> void:
	coins += maxi(n, 0)
	GameEvents.coins_changed.emit(coins)


func spend_coins(n: int) -> bool:
	if n < 0 or coins < n:
		return false
	coins -= n
	GameEvents.coins_changed.emit(coins)
	return true


func record_death() -> void:
	deaths += 1


func next_stage() -> void:
	stage += 1
	GameEvents.stage_changed.emit(stage)


func activate_checkpoint(index: int) -> void:
	if index > checkpoint_index:
		checkpoint_index = index
		GameEvents.checkpoint_activated.emit(index)
