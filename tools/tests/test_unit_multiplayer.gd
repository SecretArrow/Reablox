extends Node
## Suite unit multiplayer — NetManager (autoload Net), koneksi loopback ENet
## nyata (dua MultiplayerAPI dalam satu proses), ChatManager via RPC,
## PlayerSync snapshot, dan LanDiscovery broadcast loopback.

const FW := preload("res://tools/tests/test_framework.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

const PORT_SERVER := 24599
const PORT_CLOSED := 24001
const PORT_LOOPBACK := 24610
const PORT_DISCOVERY_GAME := 24620

var fw: Node
var _api_s: SceneMultiplayer = null
var _api_c: SceneMultiplayer = null
var _server_root: Node = null
var _client_root: Node = null
var _chat_text := ""
var _chat_count := 0


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	GameEvents.chat_message_received.connect(_on_chat_received)
	await _run_tests()
	GameEvents.chat_message_received.disconnect(_on_chat_received)
	fw.finish()


func _run_tests() -> void:
	_test_net_safety()
	_test_server_lifecycle()
	_test_join_closed_port()
	await _test_loopback_connection()
	await _test_chat_rpc()
	await _test_player_sync()
	await _test_lan_discovery()
	_test_cleanup()


func _on_chat_received(_sender: String, text: String) -> void:
	_chat_text = text
	_chat_count += 1


func _test_net_safety() -> void:
	fw.section("Net idle & leave aman")
	fw.check_eq("is_active false sebelum sesi", Net.is_active(), false)
	Net.leave()
	fw.check_eq("leave saat idle tidak crash", Net.is_active(), false)
	fw.check_is_type("get_peers mengembalikan Array", Net.get_peers(), TYPE_ARRAY)
	fw.check_eq("get_local_name memakai GameState", Net.get_local_name(), GameState.player_name)


func _test_server_lifecycle() -> void:
	fw.section("start_server / leave")
	fw.check_eq("start_server sukses", Net.start_server(PORT_SERVER), true)
	fw.check_eq("is_active true saat server", Net.is_active(), true)
	fw.check_eq("is_server true saat host", Net.is_server(), true)
	fw.check_eq("daftar peer kosong (tanpa klien)", Net.get_peers().size(), 0)
	Net.leave()
	fw.check_eq("is_active false setelah leave", Net.is_active(), false)
	fw.check_eq("is_server false setelah leave", Net.is_server(), false)


func _test_join_closed_port() -> void:
	fw.section("join ke port tertutup (koneksi async)")
	fw.check_eq("join_server diterima (async)", Net.join_server("127.0.0.1", PORT_CLOSED), true)
	Net.leave()
	fw.check_eq("leave langsung setelah join aman", Net.is_active(), false)


func _test_loopback_connection() -> void:
	fw.section("Koneksi loopback ENet nyata (server + klien satu proses)")
	_api_s = SceneMultiplayer.new()
	_server_root = Node.new()
	_server_root.name = "ServerRoot"
	add_child(_server_root)
	get_tree().set_multiplayer(_api_s, _server_root.get_path())
	_api_s.root_path = _server_root.get_path()
	var peer_s := ENetMultiplayerPeer.new()
	var err_s := peer_s.create_server(PORT_LOOPBACK, 8)
	fw.check_eq("ENet server loopback dibuat", err_s, OK)
	_api_s.multiplayer_peer = peer_s
	_api_c = SceneMultiplayer.new()
	_client_root = Node.new()
	_client_root.name = "ClientRoot"
	add_child(_client_root)
	get_tree().set_multiplayer(_api_c, _client_root.get_path())
	_api_c.root_path = _client_root.get_path()
	var peer_c := ENetMultiplayerPeer.new()
	var err_c := peer_c.create_client("127.0.0.1", PORT_LOOPBACK)
	fw.check_eq("ENet klien loopback dibuat", err_c, OK)
	_api_c.multiplayer_peer = peer_c
	await get_tree().create_timer(1.0).timeout
	fw.check_eq("server melihat 1 peer", _api_s.get_peers().size(), 1)
	fw.check_eq("klien melihat 1 peer", _api_c.get_peers().size(), 1)


func _test_chat_rpc() -> void:
	fw.section("ChatManager RPC loopback")
	var server_chat := ChatManager.new()
	server_chat.name = "ChatMP"
	_server_root.add_child(server_chat)
	var client_chat := ChatManager.new()
	client_chat.name = "ChatMP"
	_client_root.add_child(client_chat)
	var before := _chat_count
	client_chat.send_chat("halo dunia")
	await get_tree().create_timer(1.0).timeout
	fw.check_gt("chat rpc diterima (flag bertambah)", _chat_count, before)
	fw.check_eq("isi chat rpc sesuai", _chat_text, "halo dunia")
	var before_local := _chat_count
	server_chat.send_local("sapaan lokal")
	fw.check_gt("send_local memancarkan sinyal", _chat_count, before_local)
	fw.check_eq("isi chat lokal sesuai", _chat_text, "sapaan lokal")


func _test_player_sync() -> void:
	fw.section("PlayerSync snapshot & apply")
	var sync := PlayerSync.new()
	add_child(sync)
	var p1 := PLAYER_SCENE.instantiate() as PlayerController
	p1.is_remote = true
	add_child(p1)
	var p2 := PLAYER_SCENE.instantiate() as PlayerController
	p2.is_remote = true
	add_child(p2)
	sync.register_player(1, p1)
	sync.register_player(2, p2)
	p1.apply_remote(Vector3(10.0, 0.0, 5.0), 45.0, "walk")
	p1.global_position = Vector3(10.0, 0.0, 5.0)
	await get_tree().create_timer(0.4).timeout
	var snap := sync.build_snapshot()
	fw.check("snapshot memuat id 1", snap.has(1))
	fw.check_eq("posisi terenkapsulasi", snap[1]["pos"], [10.0, 0.0, 5.0])
	fw.check_eq("state terenkapsulasi", snap[1]["state"], "walk")
	fw.check("yaw menuju 45 derajat", absf(float(snap[1]["yaw"]) - 45.0) < 5.0)
	sync.apply_snapshot({2: {"pos": [3.0, 1.0, 7.0], "yaw": 90.0, "state": "walk"}})
	await get_tree().create_timer(0.5).timeout
	var moved := p2.global_position.distance_to(Vector3(3.0, 1.0, 7.0))
	fw.check_lt("apply_snapshot menggerakkan pemain remote", moved, 1.0)
	fw.check_eq("state remote diterapkan", p2.get_state(), "walk")
	fw.check("snapshot terakhir terisi oleh _process", sync.get_last_snapshot().has(1))
	fw.check("tick rate 15 Hz (0.0667 dtk)", absf(sync.get_tick_rate() - 0.0667) < 0.001)
	sync.unregister_player(2)
	fw.check("id 2 hilang setelah unregister", not sync.build_snapshot().has(2))


func _test_lan_discovery() -> void:
	fw.section("LanDiscovery broadcast loopback")
	var d := LanDiscovery.new()
	add_child(d)
	d.server_mode("DuniaKu", PORT_DISCOVERY_GAME)
	fw.check("mode server aktif", d.is_server_mode())
	d.client_mode()
	fw.check("mode klien aktif", d.is_client_mode())
	await get_tree().create_timer(2.5).timeout
	var servers := d.get_servers()
	fw.check_gte("server ditemukan via loopback", servers.size(), 1)
	fw.check("nama server sesuai", servers.size() >= 1 and servers[0]["name"] == "DuniaKu")
	fw.check("ip loopback", servers.size() >= 1 and servers[0]["ip"] == "127.0.0.1")
	fw.check(
		"port game sesuai", servers.size() >= 1 and int(servers[0]["port"]) == PORT_DISCOVERY_GAME
	)
	d.stop()
	fw.check("stop mematikan kedua mode", not d.is_server_mode() and not d.is_client_mode())


func _test_cleanup() -> void:
	fw.section("Pembersihan akhir")
	if _api_s != null and _api_s.multiplayer_peer != null:
		_api_s.multiplayer_peer.close()
	if _api_c != null and _api_c.multiplayer_peer != null:
		_api_c.multiplayer_peer.close()
	if _server_root != null:
		_server_root.queue_free()
	if _client_root != null:
		_client_root.queue_free()
	Net.leave()
	fw.check_eq("Net nonaktif di akhir suite", Net.is_active(), false)
