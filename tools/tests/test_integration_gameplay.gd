extends Node
## Suite integrasi utuh: scene game -> dunia obby -> pemain + avatar hidup,
## kill brick, respawn checkpoint, koin, NPC plaza mengejar, build + simpan.

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


func _run_tests() -> void:
	fw.section("Scene game utuh (Pulau Obby)")
	GameState.reset_run("Pulau Obby")
	var scene := load("res://scenes/game/game.tscn") as PackedScene
	var game: Game = scene.instantiate() as Game
	add_child(game)
	await _physics(60)
	var player := game.get_player()
	fw.check_not_null("pemain tercipta", player)
	fw.check("pemain mendarat di platform start", player != null and player.is_on_floor())
	fw.check(
		"avatar R6 menempel", player != null and player.find_child("AvatarRig", true, false) != null
	)
	if player != null:
		player.test_respawn_override = 0.2
	await _physics(90)
	fw.check_eq("spawn aman (health penuh)", player.get_health(), 100.0)
	fw.check("GameState dunia cocok", GameState.current_world == "Pulau Obby")

	fw.section("Alur obby: maut, respawn, koin")
	var root: Node3D = game.get_world_manager().get_root()
	var killbricks := root.find_children("*", "KillBrick", true, false)
	fw.check("killbrick ada di dunia", not killbricks.is_empty())
	if not killbricks.is_empty() and player != null:
		var kb := killbricks[0] as Node3D
		player.global_position = kb.global_position + Vector3(0.0, 3.0, 0.0)
		await _physics(40)
		fw.check("killbrick mematikan (sinyal)", _deaths_seen >= 1)
		await _physics(20)
		var spawn_horiz := Vector2(player.global_position.x - 0.0, player.global_position.z - -14.0)
		fw.check_lt("respawn kembali ke start", spawn_horiz.length(), 8.0)
	var coins := root.find_children("*", "Coin", true, false)
	fw.check("koin ada di dunia", not coins.is_empty())
	if not coins.is_empty() and player != null:
		var before := GameState.coins
		var coin := coins[0] as Node3D
		player.global_position = coin.global_position + Vector3(0.0, 0.5, 0.0)
		await _physics(30)
		fw.check_gt("koin terambil", GameState.coins, before)

	fw.section("Plaza: NPC mengejar + build + simpan")
	var wm2 := WorldManager.new()
	add_child(wm2)
	fw.check("load plaza", wm2.load_demo("Plaza Kreatif"))
	var plaza_root := wm2.get_root()
	var npcs := plaza_root.find_children("*", "NpcMonster", true, false)
	fw.check("monster plaza ada", not npcs.is_empty())
	if not npcs.is_empty() and player != null:
		var npc := npcs[0] as NpcMonster
		npc.set_target(player)
		player.global_position = npc.global_position + Vector3(5.0, 0.5, 0.0)
		await _physics(40)
		fw.check(
			"monster mengejar pemain", npc.get_state() == "chase" or npc.get_state() == "attack"
		)
	fw.check_not_null("build manager plaza", wm2.get_build())
	if wm2.get_build() != null:
		var build := wm2.get_build()
		var placed := build.place_part("block", Vector3(0.0, 5.0, 0.0))
		fw.check("place_part sukses", not placed.is_empty())
		fw.check("save plaza", wm2.save_current())
		fw.check("dunia plaza tersimpan", Saves.world_exists("Plaza Kreatif"))
		var wm3 := WorldManager.new()
		add_child(wm3)
		fw.check("load_saved plaza", wm3.load_saved("Plaza Kreatif"))
		fw.check_eq("part dipulihkan", wm3.get_build().count(), 1)
		wm3.clear()

	fw.section("Escape menu & HUD terpisah aman")
	var hud := Hud.new()
	add_child(hud)
	hud.update_health(50.0, 100.0)
	fw.check_eq("HUD label health", hud.get_health_label(), "50/100")
	var menu := EscapeMenu.new()
	add_child(menu)
	fw.check("escape menu default tertutup", not menu.is_open())
	menu.open()
	fw.check("escape menu terbuka", menu.is_open())
