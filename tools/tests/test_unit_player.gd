extends Node
## Suite player: fisika Humanoid Roblox (jalan/lari/lompat), kesehatan +
## respawn + checkpoint, renang, remote mode, kamera, kontrol sentuh.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node
var _sig_health := false
var _sig_respawn := false


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	GameEvents.player_health_changed.connect(_on_health)
	GameEvents.player_respawned.connect(_on_respawn)
	await _run_tests()
	fw.finish()


func _on_health(_current: float, _maximum: float) -> void:
	_sig_health = true


func _on_respawn() -> void:
	_sig_respawn = true


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


func _make_player() -> PlayerController:
	var player := load("res://scenes/player.tscn").instantiate() as PlayerController
	player.position = Vector3(0.0, 3.0, 0.0)
	add_child(player)
	return player


func _run_tests() -> void:
	_make_floor()
	fw.section("Fisika dasar")
	var player := _make_player()
	await _physics(30)
	fw.check("jatuh lalu mendarat", player.is_on_floor())
	Input.action_press("move_forward")
	await _physics(20)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	fw.check_gt("kecepatan jalan ~16 (>=13)", speed, 13.0)
	fw.check_lt("kecepatan jalan ~16 (<=19)", speed, 19.0)
	Input.action_release("move_forward")
	await _physics(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics(20)
	var sprint := Vector2(player.velocity.x, player.velocity.z).length()
	fw.check_gt("sprint ~24 (>=20)", sprint, 20.0)
	fw.check_lt("sprint ~24 (<=28)", sprint, 28.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _physics(10)

	fw.section("Lompat")
	var y0 := player.global_position.y
	Input.action_press("jump")
	await _physics(1)
	Input.action_release("jump")
	var maxy := y0
	for i in range(60):
		await get_tree().physics_frame
		maxy = maxf(maxy, player.global_position.y)
	var tinggi := maxy - y0
	fw.check_gt("tinggi lompat ~7.2 (>=5.5)", tinggi, 5.5)
	fw.check_lt("tinggi lompat ~7.2 (<=8.5)", tinggi, 8.5)
	await _physics(40)

	fw.section("Kesehatan & respawn")
	player.damage(30.0)
	fw.check_eq("damage 30 → health 70", player.get_health(), 70.0)
	fw.check("sinyal health teremit", _sig_health)
	player.test_respawn_override = 0.2
	player.damage(999.0)
	fw.check_eq("mati → state dead", player.get_state(), "dead")
	await _physics(40)
	fw.check_eq("respawn → health penuh", player.get_health(), 100.0)
	fw.check("sinyal respawn teremit", _sig_respawn)
	var horiz := Vector2(player.global_position.x, player.global_position.z).length()
	fw.check_lt("respawn kembali ke spawn (horizontal < 2)", horiz, 2.0)

	player.set_checkpoint(Vector3(30.0, 3.0, 30.0))
	player.damage(999.0)
	await _physics(40)
	var to_cp := Vector2(player.global_position.x - 30.0, player.global_position.z - 30.0).length()
	fw.check_lt("respawn di checkpoint (jarak < 2)", to_cp, 2.0)

	fw.section("Renang & remote")
	player.set_in_water(true)
	await _physics(10)
	fw.check_eq("di air → state swim", player.get_state(), "swim")
	player.set_in_water(false)
	await _physics(5)
	player.is_remote = true
	player.apply_remote(Vector3(25.0, 3.0, 25.0), 90.0, "walk")
	await _physics(20)
	var dist := player.global_position.distance_to(Vector3(25.0, 3.0, 25.0))
	fw.check_lt("remote mendekati target (< 6)", dist, 6.0)
	fw.check_eq("remote state mengikuti", player.get_state(), "walk")
	player.is_remote = false
	await _physics(5)

	fw.section("Kamera")
	fw.check_eq("clamp pitch bawah", PlayerCamera.clamp_pitch(-100.0), -80.0)
	fw.check_eq("clamp pitch atas", PlayerCamera.clamp_pitch(50.0), 50.0)
	var cam := PlayerCamera.new()
	add_child(cam)
	cam.setup(player)
	var arm := cam.get_node("Yaw/Pitch/Arm") as SpringArm3D
	fw.check_not_null("rig kamera terbangun", arm)
	fw.check("jarak default 12.5", arm != null and is_equal_approx(arm.spring_length, 12.5))

	fw.section("Kontrol sentuh")
	var v := TouchControls.thumbstick_vector(Vector2(100, 100), Vector2(132, 100))
	fw.check("vektor thumbstick ke kanan", absf(v.x - 0.5) < 0.01 and absf(v.y) < 0.01)
	var far := TouchControls.thumbstick_vector(Vector2(100, 100), Vector2(400, 100))
	fw.check("di luar radius → magnitude 1", is_equal_approx(far.length(), 1.0))
	fw.check("zona kiri benar", TouchControls.is_left_zone(Vector2(10, 10), Vector2(1000, 500)))
	fw.check(
		"zona kanan benar", not TouchControls.is_left_zone(Vector2(900, 10), Vector2(1000, 500))
	)

	fw.section("Move override ala sentuh")
	player.set_move_override(Vector2(0, -1))
	await _physics(20)
	fw.check_lt("bergerak maju -Z tanpa Input", player.global_position.z, 22.0)
	player.set_move_override(Vector2.ZERO)
	fw.check(
		"state akhir valid",
		["idle", "walk", "run", "jump", "freefall", "swim"].has(player.get_state())
	)
