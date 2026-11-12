extends Node
## Suite gameplay: killbrick, checkpoint, jump pad, moving platform, spinner,
## conveyor, koin — dengan player fisika nyata. Pola kontrak §8.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node
var _deaths_seen := 0


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	GameEvents.player_died.connect(_on_player_died)
	await _run_tests()
	fw.finish()


func _on_player_died() -> void:
	_deaths_seen += 1


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)
	add_child(floor_body)


func _make_player(x := 0.0, z := 0.0) -> PlayerController:
	var player := load("res://scenes/player.tscn").instantiate() as PlayerController
	player.position = Vector3(x, 3.0, z)
	player.test_respawn_override = 0.1
	add_child(player)
	player.set_spawn(Vector3(-100.0, 3.0, -100.0))
	return player


func _run_tests() -> void:
	_make_floor()
	GameState.reset_run("test_gameplay")

	fw.section("KillBrick")
	var player := _make_player()
	var killbrick := KillBrick.make(Vector3(0.0, 0.5, 0.0), Vector3(10.0, 1.0, 10.0))
	add_child(killbrick)
	await _physics(30)
	fw.check("killbrick mematikan pemain (sinyal tewas)", _deaths_seen >= 1)
	fw.check_gt("kill_count tercatat", killbrick.kill_count, 0)
	await _physics(20)

	fw.section("Checkpoint")
	GameState.reset_run("test_gameplay")
	var cp := Checkpoint.make(Vector3(30.0, 0.3, 30.0), 2)
	add_child(cp)
	player.global_position = Vector3(30.0, 3.0, 30.0)
	await _physics(20)
	fw.check_eq("checkpoint_index terisi", GameState.checkpoint_index, 2)
	fw.check_eq("stage maju", GameState.stage, 3)
	fw.check("checkpoint aktif", cp.activated)
	var cp_lama := Checkpoint.make(Vector3(50.0, 0.3, 50.0), 1)
	add_child(cp_lama)
	player.global_position = Vector3(50.0, 3.0, 50.0)
	await _physics(20)
	fw.check_eq("checkpoint tidak mundur", GameState.checkpoint_index, 2)

	fw.section("JumpPad")
	var pad := JumpPad.make(Vector3(70.0, 0.3, 0.0), 15.0)
	add_child(pad)
	player.global_position = Vector3(70.0, 2.0, 0.0)
	await _physics(12)
	fw.check_gt("player terlempar tinggi", player.velocity.y, 40.0)
	fw.check_gt("pad terpakai", pad.uses, 0)
	await _physics(60)

	fw.section("MovingPlatform")
	var plat := MovingPlatform.make(Vector3(0.0, 2.0, -40.0), Vector3(10.0, 2.0, -40.0), 10.0)
	add_child(plat)
	await _physics(40)
	fw.check_gt("platform menuju titik b", plat.global_position.x, 5.0)
	await _physics(60)
	fw.check("platform ping-pong kembali", plat.global_position.x < 5.0)

	fw.section("Spinner")
	var spinner := Spinner.make(Vector3(-30.0, 1.0, 0.0), 6.0)
	add_child(spinner)
	await _physics(10)
	fw.check("spinner berputar", not is_equal_approx(spinner.rotation_degrees.y, 0.0))
	player.global_position = Vector3(-30.0, 1.5, 3.0)
	await _physics(30)
	fw.check("spinner melukai pemain (sinyal tewas bertambah)", _deaths_seen >= 2)
	fw.check_gt("spinner kill_count tercatat", spinner.kill_count, 0)
	await _physics(15)

	fw.section("Conveyor")
	var conveyor := Conveyor.make(Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, -1.0), 8.0)
	add_child(conveyor)
	player.global_position = Vector3(0.0, 1.5, -20.0)
	await _physics(30)
	fw.check_lt("conveyor mendorong -Z", player.global_position.z, -23.0)

	fw.section("Koin")
	GameState.reset_run("test_gameplay")
	var coin := Coin.make(Vector3(0.0, 1.0, -60.0), 5)
	add_child(coin)
	player.global_position = Vector3(0.0, 1.5, -60.0)
	await _physics(20)
	fw.check_eq("koin masuk saldo", GameState.coins, 5)
	fw.check("koin tersembunyi", coin.is_collected())
	coin.set_respawn(0.1)
	await get_tree().create_timer(0.3).timeout
	fw.check("koin respawn", not coin.is_collected())
