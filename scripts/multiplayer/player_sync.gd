class_name PlayerSync
extends Node
## PlayerSync — sampling posisi pemain dengan laju NET_TICK_HZ, membangun
## snapshot ringkas {pos, yaw, state}, lalu menerapkannya kembali ke node
## pemain yang memiliki metode apply_remote(pos, yaw, state).

var _players := {}
var _acc := 0.0
var _last_snapshot := {}


func register_player(id: int, node: Node) -> void:
	_players[id] = node


func unregister_player(id: int) -> void:
	_players.erase(id)


func build_snapshot() -> Dictionary:
	var snap := {}
	for id in _players:
		var node: Node = _players[id]
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var spatial := node as Node3D
		var pos := spatial.global_position
		var state := "idle"
		if spatial.has_method("get_state"):
			state = str(spatial.get_state())
		snap[id] = {
			"pos": [pos.x, pos.y, pos.z],
			"yaw": spatial.rotation_degrees.y,
			"state": state,
		}
	return snap


func apply_snapshot(snap: Dictionary) -> void:
	for id in _players:
		var node: Node = _players[id]
		if not is_instance_valid(node) or not node.has_method("apply_remote"):
			continue
		var entry := _entry_for(snap, id)
		if entry.is_empty():
			continue
		var pos := _vec3_from(entry.get("pos", []))
		var yaw := float(entry.get("yaw", 0.0))
		var state := str(entry.get("state", "idle"))
		node.apply_remote(pos, yaw, state)


func get_tick_rate() -> float:
	return 1.0 / GameConfig.NET_TICK_HZ


func get_last_snapshot() -> Dictionary:
	return _last_snapshot


func _process(delta: float) -> void:
	_acc += delta
	if _acc < get_tick_rate():
		return
	_acc = 0.0
	_last_snapshot = build_snapshot()


func _entry_for(snap: Dictionary, id: int) -> Dictionary:
	if snap.has(id):
		return snap[id]
	if snap.has(str(id)):
		return snap[str(id)]
	return {}


func _vec3_from(value: Variant) -> Vector3:
	var arr: Array = value if value is Array else []
	if arr.size() < 3:
		return Vector3.ZERO
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
