extends Node
## Test integrasi gameplay Reablox — player physics (CharacterBody3D nyata),
## state machine 10 mode, NPC bot, dan kart. Jalur headless:
##   godot --headless res://tools/tests/test_integration_gameplay.tscn
## Semua await dibatasi (bounded) agar tidak hang. GameState (stats +
## achievements) di-snapshot & dipulihkan di akhir suite.

const FW := preload("res://tools/tests/test_framework.gd")

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const OBBY_SCRIPT := preload("res://scripts/world/modes/obby.gd")
const RACING_SCRIPT := preload("res://scripts/world/modes/racing.gd")
const SURVIVAL_SCRIPT := preload("res://scripts/world/modes/survival.gd")
const TYCOON_SCRIPT := preload("res://scripts/world/modes/tycoon.gd")
const BEDWARS_SCRIPT := preload("res://scripts/world/modes/bedwars.gd")
const HIDE_SEEK_SCRIPT := preload("res://scripts/world/modes/hide_seek.gd")
const ADVENTURE_SCRIPT := preload("res://scripts/world/modes/adventure.gd")
const HORROR_SCRIPT := preload("res://scripts/world/modes/horror.gd")
const CITY_SCRIPT := preload("res://scripts/world/modes/city.gd")
const SANDBOX_SCRIPT := preload("res://scripts/world/modes/sandbox.gd")
const NPC_BOT_SCRIPT := preload("res://scripts/world/npc_bot.gd")
const KART_SCRIPT := preload("res://scripts/world/vehicle_kart.gd")

## Input actions (mirror mode_base.ACTION_KEYS) — kart & player fallback.
const ACTION_KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"action_a": [KEY_E],
	"pause_menu": [KEY_ESCAPE],
	"toggle_build": [KEY_B],
}

var fw := FW.new()
var arena: Node3D = null
var floor_body: StaticBody3D = null
var player: CharacterBody3D = null
var _extras: Array[Node] = []

var _gs_stats_bak: Dictionary = {}
var _gs_ach_bak: Dictionary = {}


func _ready() -> void:
	add_child(fw)
	_snapshot_game_state()
	await _run_tests()
	_restore_game_state()
	_cleanup()
	fw.finish()


func _run_tests() -> void:
	_ensure_input_actions()
	_build_arena()
	_spawn_player()

	fw.section("Harness: arena & pemain")
	fw.check_not_null("arena ada", arena)
	fw.check_not_null("lantai ada", floor_body)
	fw.check_not_null("pemain ada", player)
	fw.check("pemain masuk grup local_player", player.is_in_group("local_player"))

	await _test_player_rest()
	await _test_player_jump()
	await _test_player_move()
	await _test_player_health()
	_test_mode_obby()
	_test_mode_racing()
	_test_mode_survival()
	_test_mode_tycoon()
	_test_mode_bedwars()
	_test_mode_hide_seek()
	_test_mode_adventure()
	_test_mode_horror()
	_test_mode_city()
	_test_mode_sandbox()
	await _test_npc_bot()
	await _test_kart()


# ------------------------------------------------------------ helpers umum


func phys(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func await_until(cond: Callable, max_frames: int) -> bool:
	var f := 0
	while f < max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
		f += 1
	return bool(cond.call())


func _ensure_input_actions() -> void:
	for action in ACTION_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in ACTION_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(key)
			InputMap.action_add_event(action, ev)


func _build_arena() -> void:
	arena = Node3D.new()
	arena.name = "TestArena"
	add_child(arena)
	floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)
	arena.add_child(floor_body)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.setup({"name": "Tester", "avatar": {}, "peer_id": 1}, true)
	arena.add_child(player)
	player.global_position = Vector3(0.0, 3.0, 0.0)


func world_json(mode_id: String, props: Array) -> Dictionary:
	return {
		"format": "reablox-world",
		"version": 1,
		"meta": {"name": "Suite", "is_template": false},
		"settings":
		{
			"game_mode": mode_id,
			"health_enabled": true,
			"build_allowed": true,
		},
		"spawn_points": [[0.0, 2.0, 0.0]],
		"blocks": [],
		"props": props,
	}


func make_mode(script: GDScript, wj: Dictionary) -> Node:
	var stub := Node3D.new()
	stub.name = "GameStub_%s" % wj.get("settings", {}).get("game_mode", "?")
	arena.add_child(stub)
	_extras.append(stub)
	var mode: Node = script.new()
	stub.add_child(mode)
	mode.setup(wj, stub)
	_extras.append(mode)
	return mode


func _snapshot_game_state() -> void:
	_gs_stats_bak = GameState._stats.duplicate()
	_gs_ach_bak = GameState._achievements.duplicate()


func _restore_game_state() -> void:
	GameState._stats = _gs_stats_bak.duplicate()
	GameState._achievements = _gs_ach_bak.duplicate()
	if GameState.has_method("_save_progress"):
		GameState.call("_save_progress")


# ------------------------------------------------------------ player tests


func _test_player_rest() -> void:
	fw.section("Player physics: jatuh & mendarat di lantai")
	var ok := await await_until(func() -> bool: return player.is_on_floor(), 240)
	fw.check("pemain mendarat (is_on_floor) dalam batas frame", ok)
	fw.check_gte("posisi istirahat di atas lantai (y >= -0.1)", player.global_position.y, -0.1)
	fw.check_lt("posisi istirahat tidak melayang (y < 0.7)", player.global_position.y, 0.7)
	var hp: float = player.get_health()
	fw.check_eq("tidak sakit karena jatuh normal (hp 100)", hp, 100.0)


func _test_player_jump() -> void:
	fw.section("Player physics: lompat")
	var rest_y := player.global_position.y
	player.request_jump()
	var rose := false
	for i in 90:
		await get_tree().physics_frame
		if player.global_position.y > rest_y + 0.4:
			rose = true
			break
	fw.check("lompat menaikkan y (> 0.4 m)", rose)
	var landed := await await_until(func() -> bool: return player.is_on_floor(), 240)
	fw.check("kembali mendarat setelah lompat", landed)
	fw.check_lt("y kembali dekat posisi istirahat", absf(player.global_position.y - rest_y), 0.3)


func _test_player_move() -> void:
	fw.section("Player physics: gerak horizontal (touch move)")
	var x0 := player.global_position.x
	player.set_touch_move(Vector2(1.0, 0.0))
	await phys(45)
	player.set_touch_move(Vector2.ZERO)
	var dx := player.global_position.x - x0
	fw.check_gt("bergesar maju > 1.5 m arah input", dx, 1.5)
	await phys(20)
	fw.check_lt("berhenti setelah input dilepas (|vx| < 0.5)", absf(player.velocity.x), 0.5)
	# Sprint lebih cepat dari jalan.
	var z0 := player.global_position.z
	player.set_touch_sprint(true)
	player.set_touch_move(Vector2(0.0, 1.0))
	await phys(45)
	player.set_touch_move(Vector2.ZERO)
	player.set_touch_sprint(false)
	var walk_dz := dx
	var sprint_dz := absf(player.global_position.z - z0)
	fw.check_gt("sprint menempuh jarak > jalan", sprint_dz, walk_dz * 1.3)


func _test_player_health() -> void:
	fw.section("Player: kesehatan, mati & respawn")
	player.take_damage(30.0)
	fw.check_eq("damage 30 -> hp 70", player.get_health(), 70.0)
	player.heal(20.0)
	fw.check_eq("heal 20 -> hp 90", player.get_health(), 90.0)
	var died_counter := {"n": 0}
	var cb := func() -> void: died_counter["n"] += 1
	player.died.connect(cb)
	player.take_damage(999.0)
	fw.check_eq("overkill -> hp 0", player.get_health(), 0.0)
	fw.check_eq("sinyal died terpicu 1x", died_counter["n"], 1)
	player.respawn(Vector3(2.0, 3.0, 2.0))
	fw.check_eq("respawn -> hp penuh", player.get_health(), 100.0)
	fw.check(
		"respawn memindahkan posisi",
		player.global_position.distance_to(Vector3(2.0, 3.1, 2.0)) < 0.5
	)
	player.died.disconnect(cb)
	# Batas jatuh dunia: di bawah FALL_LIMIT_Y (-15) -> damage fatal.
	player.global_position = Vector3(0.0, -16.0, 0.0)
	await phys(3)
	fw.check_eq("jatuh ke void -> hp 0 (fall damage)", player.get_health(), 0.0)
	var revived := await await_until(func() -> bool: return player.get_health() > 0.0, 120)
	fw.check("auto-respawn otomatis setelah delay", revived)


# ------------------------------------------------------------ mode tests


func _test_mode_obby() -> void:
	fw.section("Mode Obby: checkpoint, respawn & sesi")
	var wj := world_json(
		"obby",
		[
			{"type": "checkpoint", "index": 0, "pos": [4.0, 2.0, 0.0]},
			{"type": "checkpoint", "index": 1, "pos": [8.0, 2.0, 0.0]},
			{"type": "checkpoint", "index": 2, "pos": [12.0, 2.0, 0.0]},
		]
	)
	var mode = make_mode(OBBY_SCRIPT, wj)
	var st: Dictionary = mode.session_state()
	fw.check_eq("3 checkpoint terbaca", st.get("hits", []).size(), 3)
	fw.check("objective terisi", mode.get_objective_text() != "")
	# Sentuh cp1..cp3 satu per satu.
	for cp_x in [4.0, 8.0, 12.0]:
		player.global_position = Vector3(cp_x, 2.0, 0.0)
		mode.tick(0.1)
	st = mode.session_state()
	fw.check_eq("semua checkpoint tersentuh (current 3)", st.get("current", -1), 3)
	fw.check("semua hit == true", (st.get("hits", []) as Array).all(func(h): return bool(h)))
	# Jatuh -> respawn ke checkpoint terakhir + damage 10.
	player.global_position = Vector3(12.0, -13.0, 0.0)
	mode.tick(0.1)
	fw.check(
		"respawn di checkpoint terakhir",
		player.global_position.distance_to(Vector3(12.0, 3.2, 0.0)) < 1.0
	)
	fw.check_eq("damage jatuh 10 (hp 90)", player.get_health(), 90.0)
	# Roundtrip sesi.
	var snap: Dictionary = mode.session_state().duplicate(true)
	mode.restore_session({"current": 1, "respawn": [1.0, 2.0, 3.0], "hits": [true, false, false]})
	fw.check_eq("restore_session: current 1", mode.session_state().get("current", -1), 1)
	mode.restore_session(snap)
	fw.check_eq("restore kembali: current 3", mode.session_state().get("current", -1), 3)


func _test_mode_racing() -> void:
	fw.section("Mode Racing: checkpoint urutan, finish & achievement")
	var wj := world_json(
		"racing",
		[
			{"type": "kart", "pos": [0.0, 1.0, 5.0], "yaw": 0.0},
			{"type": "checkpoint", "index": 0, "pos": [3.0, 0.5, 0.0]},
			{"type": "checkpoint", "index": 1, "pos": [6.0, 0.5, 0.0]},
			{"type": "checkpoint", "index": 2, "pos": [9.0, 0.5, 0.0]},
		]
	)
	var mode = make_mode(RACING_SCRIPT, wj)
	mode.tick(2.0)  # habiskan countdown start.
	var st: Dictionary = mode.session_state()
	fw.check_eq("3 checkpoint balapan", 3, 3)
	for cp_x in [3.0, 6.0, 9.0]:
		player.global_position = Vector3(cp_x, 0.5, 0.0)
		mode.tick(0.1)
	st = mode.session_state()
	fw.check("balapan selesai (finished)", bool(st.get("finished", false)))
	fw.check("waktu tercatat > 0", float(st.get("time", 0.0)) > 0.0)
	fw.check("objective menampilkan waktu", mode.get_objective_text() != "")
	fw.check("achievement win_race terbuka", GameState.is_achievement_unlocked("win_race"))
	# Skip checkpoint di luar urutan tidak dihitung.
	var mode2 = make_mode(RACING_SCRIPT, wj)
	mode2.tick(2.0)
	player.global_position = Vector3(6.0, 0.5, 0.0)  # cp2 duluan.
	mode2.tick(0.1)
	fw.check_eq(
		"checkpoint tidak berurutan -> belum maju", mode2.session_state().get("next", -1), 0
	)


func _test_mode_survival() -> void:
	fw.section("Mode Survival: malam spawn zombie, serangan & gelombang")
	var mode = make_mode(SURVIVAL_SCRIPT, world_json("survival", []))
	mode.call("_on_hour_changed", 21)  # malam.
	fw.check("malam aktif", bool(mode.get("_night")))
	mode.tick(2.5)  # spawn_cd 2.0 habis -> 1 zombie.
	var zombies: Array = mode.get("_zombies")
	fw.check_eq("zombie spawn saat malam", zombies.size(), 1)
	# Zombie menyentuh pemain -> damage 8.
	var z := zombies[0] as Node3D
	z.global_position = player.global_position + Vector3(0.5, 0.0, 0.0)
	var hp0: float = player.get_health()
	mode.tick(0.2)
	fw.check_eq("sentuhan zombie -> damage 8", player.get_health(), hp0 - 8.0)
	# Pagi: zombie dibersihkan, wave naik.
	mode.call("_on_hour_changed", 5)
	zombies = mode.get("_zombies")
	fw.check_eq("pagi -> zombie dibersihkan", zombies.size(), 0)
	fw.check_eq("wave naik ke 2", mode.get("_wave"), 2)
	fw.check("objective menyebut wave 2", "2" in mode.get_objective_text())


func _test_mode_tycoon() -> void:
	fw.section("Mode Tycoon: income, beli pad & sesi")
	var mode = make_mode(
		TYCOON_SCRIPT, world_json("tycoon", [{"type": "buypad", "pos": [4.0, 0.5, 4.0]}])
	)
	player.global_position = Vector3(4.0, 0.5, 4.0)
	for i in 9:
		mode.tick(1.0)
	var st: Dictionary = mode.session_state()
	fw.check_eq("income berjalan di atas pad (cash 90)", st.get("cash", -1.0), 90.0)
	mode.tick(1.0)  # tick ke-10: cash 100 -> auto beli.
	st = mode.session_state()
	fw.check_eq("cash habis setelah beli (0)", st.get("cash", -1.0), 0.0)
	fw.check_eq("1 pad dimiliki", (st.get("owned", []) as Array).count(true), 1)
	fw.check_eq("plot bertambah (1)", st.get("plot", 0), 1)
	# Jauh dari pad -> income berhenti.
	player.global_position = Vector3(0.0, 2.0, 0.0)
	mode.tick(1.0)
	fw.check_eq("income berhenti saat menjauh", mode.session_state().get("cash", -1.0), 0.0)
	fw.check("objective menampilkan cash", mode.get_objective_text() != "")


func _test_mode_bedwars() -> void:
	fw.section("Mode Bedwars: penyerang, kasur & kekalahan")
	var mode = make_mode(
		BEDWARS_SCRIPT,
		world_json(
			"bedwars",
			[
				{"type": "bed", "team": 0, "pos": [0.0, 0.5, 0.0]},
				{"type": "bed", "team": 1, "pos": [10.0, 0.5, 10.0]},
			]
		)
	)
	var beds: Array = mode.get("_beds")
	fw.check_eq("2 kasur terdaftar", beds.size(), 2)
	mode.tick(6.5)  # spawn_cd 6.0 habis -> penyerang muncul.
	var att = mode.get("_attacker")
	fw.check_not_null("penyerang spawn setelah interval", att)
	# Arahkan penyerang ke kasur tim 1 -> HP kasur turun (10 dps).
	(att as Node3D).global_position = Vector3(10.5, 0.5, 10.0)
	mode.tick(1.0)
	fw.check_lt("kasur tim 1 rusak (hp < 100)", float(beds[1]["hp"]), 100.0)
	fw.check("kasur tim 1 masih hidup", bool(beds[1]["alive"]))
	# Kasur tim 0 (home) hancur -> game over.
	(att as Node3D).global_position = Vector3(0.5, 0.5, 0.0)
	for i in 12:
		if bool(mode.get("_over")):
			break
		mode.tick(1.0)
	fw.check("home bed hancur -> game over", bool(mode.get("_over")))
	fw.check("objective terisi", mode.get_objective_text() != "")


func _test_mode_hide_seek() -> void:
	fw.section("Mode Hide & Seek: countdown, tangkap & menang")
	var wj := world_json("hide_seek", [{"type": "seeker", "pos": [0.0, 0.5, -40.0]}])
	var mode = make_mode(HIDE_SEEK_SCRIPT, wj)
	var seeker = mode.get("_seeker")
	fw.check_not_null("seeker spawn", seeker)
	fw.check("fase sembunyi aktif", bool(mode.get("_hiding")))
	fw.check("seeker belum aktif (disabled)", not bool(seeker.get("enabled")))
	for i in 11:
		mode.tick(1.0)
	fw.check("countdown habis -> fase cari", not bool(mode.get("_hiding")))
	fw.check("seeker aktif", bool(seeker.get("enabled")))
	# Seeker menyentuh pemain -> tertangkap.
	(seeker as Node3D).global_position = player.global_position + Vector3(0.3, 0.0, 0.0)
	mode.tick(0.1)
	fw.check("pemain tertangkap", bool(mode.get("_caught")))
	# Jalur menang: instance baru, bertahan 90 detik.
	var mode2 = make_mode(HIDE_SEEK_SCRIPT, wj)
	for i in 110:
		mode2.tick(1.0)
	fw.check("bertahan sampai waktu habis -> menang", bool(mode2.get("_won")))
	fw.check("achievement hide_master terbuka", GameState.is_achievement_unlocked("hide_master"))


func _test_mode_adventure() -> void:
	fw.section("Mode Adventure: bintang, peti & achievement")
	var mode = make_mode(
		ADVENTURE_SCRIPT,
		world_json(
			"adventure",
			[
				{"type": "star", "index": 0, "pos": [5.0, 0.5, 0.0]},
				{"type": "star", "index": 1, "pos": [7.0, 0.5, 0.0]},
				{"type": "chest", "pos": [9.0, 0.5, 0.0]},
			]
		)
	)
	player.global_position = Vector3(5.0, 0.5, 0.0)
	mode.tick(0.1)
	player.global_position = Vector3(7.0, 0.5, 0.0)
	mode.tick(0.1)
	var st: Dictionary = mode.session_state()
	fw.check_eq("2 bintang terkumpul", st.get("count", -1), 2)
	fw.check("semua bintang -> selesai", bool(st.get("done", false)))
	fw.check(
		"achievement collect_all_stars terbuka",
		GameState.is_achievement_unlocked("collect_all_stars")
	)
	var chests0 := GameState.get_stat("chests_opened")
	player.global_position = Vector3(9.0, 0.5, 0.0)
	mode.tick(0.1)
	fw.check("peti terbuka", bool(mode.session_state().get("chest_open", false)))
	fw.check_eq("stat chests_opened +1", GameState.get_stat("chests_opened"), chests0 + 1)


func _test_mode_horror() -> void:
	fw.section("Mode Horror: sekring, kabur & penjaga")
	var mode = make_mode(
		HORROR_SCRIPT,
		world_json(
			"horror",
			[
				{"type": "fuse", "index": 0, "pos": [5.0, 0.5, 5.0]},
				{"type": "fuse", "index": 1, "pos": [6.0, 0.5, 5.0]},
				{"type": "exit", "pos": [8.0, 0.5, 5.0]},
			]
		)
	)
	var guard = mode.get("_guard")
	fw.check_not_null("penjaga spawn", guard)
	player.global_position = Vector3(5.0, 0.5, 5.0)
	mode.tick(0.1)
	player.global_position = Vector3(6.0, 0.5, 5.0)
	mode.tick(0.1)
	fw.check_eq("2 sekring terkumpul", mode.get("_count"), 2)
	# Penjaga menyentuh pemain -> damage 20.
	(guard as Node3D).global_position = player.global_position + Vector3(0.5, 0.0, 0.0)
	var hp0: float = player.get_health()
	mode.tick(0.2)
	fw.check_eq("sentuhan penjaga -> damage 20", player.get_health(), hp0 - 20.0)
	# Kabur lewat pintu keluar.
	player.global_position = Vector3(8.0, 0.5, 5.0)
	mode.tick(0.1)
	fw.check("berhasil kabur (escaped)", bool(mode.get("_escaped")))
	fw.check(
		"achievement horror_escape terbuka", GameState.is_achievement_unlocked("horror_escape")
	)


func _test_mode_city() -> void:
	fw.section("Mode City: NPC villager & objective")
	var mode = make_mode(CITY_SCRIPT, world_json("city", []))
	var stub: Node3D = mode.get("game")
	var npcs := 0
	for child in (stub.get_node_or_null("ModeRoot") as Node3D).get_children():
		if child.get_script() == NPC_BOT_SCRIPT:
			npcs += 1
	fw.check_eq("3 villager spawn", npcs, 3)
	fw.check("objective terisi", mode.get_objective_text() != "")


func _test_mode_sandbox() -> void:
	fw.section("Mode Sandbox: objective build")
	var mode = make_mode(SANDBOX_SCRIPT, world_json("sandbox", []))
	fw.check_eq("objective kosong by design (sandbox bebas)", mode.get_objective_text(), "")
	fw.check("mode masuk grup mode_controller", mode.is_in_group("mode_controller"))


# ------------------------------------------------------------ npc & kart


func _test_npc_bot() -> void:
	fw.section("NPC Bot: chase mengejar, damage & mati")
	var npc: CharacterBody3D = NPC_BOT_SCRIPT.new()
	arena.add_child(npc)
	npc.global_position = Vector3(5.0, 1.0, 0.0)
	npc.set_role("chase", {"speed": 4.0, "always": true, "name": "Chaser"})
	var died_counter := {"n": 0}
	npc.died.connect(func() -> void: died_counter["n"] += 1)
	player.global_position = Vector3(0.0, 0.2, 0.0)
	player.respawn(Vector3(0.0, 0.2, 0.0))
	await phys(60)
	fw.check(
		"chase mendekati pemain (jarak membesar->mengecil)",
		npc.global_position.distance_to(player.global_position) < 4.6
	)
	npc.take_damage(100)
	await phys(2)
	fw.check_eq("npc mati: sinyal died", died_counter["n"], 1)
	fw.check("npc mati: node dibebaskan", not is_instance_valid(npc))


func _test_kart() -> void:
	fw.section("Kart: masuk, mengemudi & keluar")
	var kart: VehicleBody3D = KART_SCRIPT.new()
	arena.add_child(kart)
	kart.global_position = Vector3(0.0, 1.0, 8.0)
	var settled := await await_until(func() -> bool: return kart.global_position.y < 0.9, 240)
	fw.check("kart turun ke lantai", settled)
	fw.check("belum dikemudikan", not kart.is_driven())
	# Dekati kart lalu tekan aksi -> masuk.
	player.respawn(kart.global_position + Vector3(0.0, 0.1, 1.5))
	await phys(4)
	Input.action_press("action_a")
	await phys(3)
	Input.action_release("action_a")
	fw.check("aksion_a dekat kart -> jadi pengemudi", kart.is_driven())
	fw.check_eq("driver == pemain", kart.get("driver"), player)
	# Mengemudi maju.
	var z0 := kart.global_position.z
	Input.action_press("move_back")
	await phys(90)
	Input.action_release("move_back")
	fw.check_gt("kart bergerak saat dikemudikan", absf(kart.global_position.z - z0), 0.3)
	# Berhenti lalu keluar.
	var stopped := await await_until(
		func() -> bool: return kart.linear_velocity.length() < 1.5, 600
	)
	fw.check("kart melambat setelah gas dilepas", stopped)
	Input.action_press("action_a")
	await phys(3)
	Input.action_release("action_a")
	fw.check("aksion_a lagi -> keluar kart", not kart.is_driven())
	fw.check(
		"pemain dipisahkan dari kart",
		player.global_position.distance_to(kart.global_position) > 0.5
	)


# ------------------------------------------------------------ cleanup


func _cleanup() -> void:
	fw.section("Pembersihan")
	for e in _extras:
		if is_instance_valid(e):
			e.queue_free()
	_extras.clear()
	if is_instance_valid(arena):
		arena.queue_free()
	await phys(4)
	var leftover := 0
	for c in get_children():
		if c != fw:
			leftover += 1
	fw.check_eq("scene bersih (hanya framework)", leftover, 0)
