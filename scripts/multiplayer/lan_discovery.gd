class_name LanDiscovery
extends Node
## LanDiscovery — pencarian host di jaringan lokal lewat paket UDP ringan.
## Host menyiarkan "MAGIC;nama;port" setiap detik; klien mem-bind port
## discovery lalu mengumpulkan daftar server. Di sandbox siaran dikirim
## loopback (127.0.0.1) supaya aman dan tetap bisa diuji otomatis.

const DISCOVERY_PORT := 24566
const MAGIC := "REABLOX1"
const BROADCAST_INTERVAL := 1.0

var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _servers := {}
var _server_name := ""
var _game_port := 24565
var _acc := 0.0
var _is_server_mode := false
var _is_client_mode := false


func server_mode(server_name: String, game_port := 24565) -> void:
	stop()
	_server_name = server_name
	_game_port = game_port
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("127.0.0.1", DISCOVERY_PORT)
	_is_server_mode = true
	_acc = 0.0


func client_mode() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	_servers.clear()
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT, "0.0.0.0")
	if err != OK:
		push_warning("LanDiscovery: gagal bind port %d (error %d)" % [DISCOVERY_PORT, err])
		_listener = null
		return
	_is_client_mode = true


func poll() -> void:
	if _listener == null:
		return
	while _listener.get_available_packet_count() > 0:
		var pkt := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var parts := pkt.get_string_from_utf8().split(";")
		if parts.size() < 3 or parts[0] != MAGIC:
			continue
		var port := int(parts[2])
		_servers[ip + ":" + parts[2]] = {"ip": ip, "name": parts[1], "port": port}


func get_servers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _servers:
		out.append(_servers[key])
	return out


func stop() -> void:
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null
	if _listener != null:
		_listener.close()
		_listener = null
	_servers.clear()
	_server_name = ""
	_game_port = 24565
	_acc = 0.0
	_is_server_mode = false
	_is_client_mode = false


func is_server_mode() -> bool:
	return _is_server_mode


func is_client_mode() -> bool:
	return _is_client_mode


func _process(delta: float) -> void:
	if _is_server_mode:
		_tick_broadcast(delta)
	if _is_client_mode:
		poll()


func _tick_broadcast(delta: float) -> void:
	if _broadcaster == null:
		return
	_acc += delta
	if _acc < BROADCAST_INTERVAL:
		return
	_acc = 0.0
	var payload := MAGIC + ";" + _server_name + ";" + str(_game_port)
	_broadcaster.put_packet(payload.to_utf8_buffer())


func _exit_tree() -> void:
	stop()
