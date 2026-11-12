class_name NetManager
extends Node
## Net (autoload) — manajemen sesi multiplayer LAN berbasis ENet.
## Host memanggil start_server(), klien join_server(); leave() menutup sesi.
## Event peer masuk/keluar diteruskan ke GameEvents agar UI bisa bereaksi.

signal peer_list_changed

## CONNECTION_STATUS_DISCONNECTED = 0 (enum ConnectionStatus); akses nama
## enum via kelas bermasalah di Godot 4.4.1 headless, jadi pakai angka bernama.
const STATUS_DISCONNECTED := 0

var _peer: ENetMultiplayerPeer = null
var _peer_names := {}
var _signals_connected := false


func is_active() -> bool:
	if _peer == null:
		return false
	var status := _peer.get_connection_status()
	return status != STATUS_DISCONNECTED


func is_server() -> bool:
	return is_active() and multiplayer.is_server()


func start_server(port := -1) -> bool:
	if is_active():
		leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port if port > 0 else GameConfig.NET_PORT, 16)
	if err != OK:
		push_warning("Net: gagal membuka server ENet (port %d, error %d)" % [port, err])
		return false
	_peer = p
	multiplayer.multiplayer_peer = p
	_connect_signals()
	return true


func join_server(ip: String, port := -1) -> bool:
	if is_active():
		leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port if port > 0 else GameConfig.NET_PORT)
	if err != OK:
		push_warning("Net: gagal memulai klien ENet ke %s:%d (error %d)" % [ip, port, err])
		return false
	_peer = p
	multiplayer.multiplayer_peer = p
	_connect_signals()
	return true


func leave() -> void:
	if _peer == null:
		return
	_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	_peer_names.clear()
	peer_list_changed.emit()


func get_peers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _peer == null:
		return out
	for id in multiplayer.get_peers():
		var entry := {"id": id, "name": _peer_names.get(id, "Pemain" + str(id))}
		out.append(entry)
	return out


func get_local_name() -> String:
	return GameState.player_name


func _connect_signals() -> void:
	if _signals_connected:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	_signals_connected = true


func _on_peer_connected(id: int) -> void:
	_peer_names[id] = "Pemain" + str(id)
	GameEvents.net_peer_joined.emit(id, _peer_names[id])
	peer_list_changed.emit()


func _on_peer_left(id: int) -> void:
	GameEvents.net_peer_left.emit(id)
	_peer_names.erase(id)
	peer_list_changed.emit()


func _exit_tree() -> void:
	leave()
