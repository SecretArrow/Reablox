class_name BuildManager
extends Node
## BuildManager — penempatan/modifikasi part ala Roblox Studio dengan
## undo/redo, kuota part, dan serialisasi dunia. Spek: docs/contracts.md §10.

var test_max_blocks := -1
var _root: Node3D = null
var _parts := {}
var _nodes := {}
var _next_id := 1
var _undo: Array = []
var _redo: Array = []
var _no_history := false


func setup(root: Node3D) -> void:
	_root = root


func snap(v: Vector3) -> Vector3:
	var g := GameConfig.GRID_SIZE
	return Vector3(roundf(v.x / g) * g, roundf(v.y / g) * g, roundf(v.z / g) * g)


func place_part(
	part_type: String,
	pos: Vector3,
	rot_y_deg := 0.0,
	size := PartLibrary.default_size(),
	color_hex := "#a3a2a5",
	material := "plastic",
	force_id := -1
) -> Dictionary:
	if not PartLibrary.is_valid_type(part_type):
		push_warning("Tipe part tidak valid: %s" % part_type)
		return {}
	var max_blocks: int = test_max_blocks if test_max_blocks > 0 else GameConfig.MAX_BLOCKS
	if count() >= max_blocks:
		push_warning("Kuota part penuh (%d)" % max_blocks)
		return {}
	var snapped := snap(pos)
	var new_id := force_id if force_id > 0 else _next_id
	_next_id = maxi(_next_id + 1, new_id + 1)
	var data := {
		"id": new_id,
		"type": part_type.to_lower(),
		"pos": [snapped.x, snapped.y, snapped.z],
		"rot_y_deg": fposmod(rot_y_deg, 360.0),
		"size": [size.x, size.y, size.z],
		"color": color_hex.to_lower(),
		"material": material.to_lower(),
		"anchored": true,
	}
	var node := PartLibrary.make_part(
		part_type, size, PartLibrary.color_from_hex(color_hex), material
	)
	node.name = "Part%d" % data["id"]
	node.position = snapped
	node.rotation_degrees.y = float(data["rot_y_deg"])
	var parent: Node = _root if _root != null else self
	parent.add_child(node)
	_parts[data["id"]] = data
	_nodes[data["id"]] = node
	_push_undo({"op": "place", "id": data["id"], "data": data.duplicate()})
	GameEvents.part_added.emit(data.duplicate())
	return data.duplicate()


func remove_part(id: int) -> bool:
	if not _parts.has(id):
		return false
	var data: Dictionary = _parts[id]
	var node: Node = _nodes[id]
	if is_instance_valid(node):
		node.queue_free()
	_parts.erase(id)
	_nodes.erase(id)
	_push_undo({"op": "remove", "data": data.duplicate()})
	GameEvents.part_removed.emit(id)
	return true


func move_part(id: int, pos: Vector3) -> bool:
	var node := _get_node(id)
	if node == null:
		return false
	var snapped := snap(pos)
	var from: Array = _parts[id]["pos"]
	_parts[id]["pos"] = [snapped.x, snapped.y, snapped.z]
	node.position = snapped
	_push_undo({"op": "move", "id": id, "from": from, "to": _parts[id]["pos"]})
	return true


func rotate_part(id: int, deg := GameConfig.ROT_STEP_DEG) -> bool:
	var node := _get_node(id)
	if node == null:
		return false
	var from: float = _parts[id]["rot_y_deg"]
	var to := fposmod(from + deg, 360.0)
	_parts[id]["rot_y_deg"] = to
	node.rotation_degrees.y = to
	_push_undo({"op": "rotate", "id": id, "from": from, "to": to})
	return true


func recolor_part(id: int, color_hex: String) -> bool:
	var node := _get_node(id)
	if node == null or not _is_valid_hex(color_hex):
		return false
	var from: String = _parts[id]["color"]
	var to := color_hex.to_lower()
	_parts[id]["color"] = to
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.material_override = MaterialsLib.make(
			_parts[id]["material"], PartLibrary.color_from_hex(to)
		)
	_push_undo({"op": "recolor", "id": id, "from": from, "to": to})
	return true


func duplicate_part(id: int) -> Dictionary:
	if not _parts.has(id):
		return {}
	var data: Dictionary = _parts[id]
	var pos := Vector3(
		float(data["pos"][0]) + 2.0 * GameConfig.GRID_SIZE,
		float(data["pos"][1]),
		float(data["pos"][2])
	)
	return place_part(
		data["type"],
		pos,
		float(data["rot_y_deg"]),
		Vector3(float(data["size"][0]), float(data["size"][1]), float(data["size"][2])),
		data["color"],
		data["material"],
	)


func get_part(id: int) -> Dictionary:
	if not _parts.has(id):
		return {}
	return (_parts[id] as Dictionary).duplicate()


func get_parts() -> Array:
	var out: Array = []
	var ids := _parts.keys()
	ids.sort()
	for id in ids:
		out.append((_parts[id] as Dictionary).duplicate())
	return out


func count() -> int:
	return _parts.size()


func clear() -> void:
	for id in _nodes.keys():
		var node: Node = _nodes[id]
		if is_instance_valid(node):
			node.queue_free()
	_parts.clear()
	_nodes.clear()
	_undo.clear()
	_redo.clear()


func serialize() -> Array:
	return get_parts()


func load_parts(arr: Array) -> int:
	clear()
	_no_history = true
	var loaded := 0
	for entry in arr:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		if not d.has("type") or not PartLibrary.is_valid_type(str(d["type"])):
			continue
		var pos_arr: Array = d.get("pos", [0.0, 0.0, 0.0])
		var size_arr: Array = d.get("size", [4.0, 1.2, 2.0])
		var result := place_part(
			str(d["type"]),
			Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2])),
			float(d.get("rot_y_deg", 0.0)),
			Vector3(float(size_arr[0]), float(size_arr[1]), float(size_arr[2])),
			str(d.get("color", "#a3a2a5")),
			str(d.get("material", "plastic")),
			int(d.get("id", 0)),
		)
		if not result.is_empty():
			loaded += 1
	_no_history = false
	return loaded


func undo() -> bool:
	if _undo.is_empty():
		return false
	var op: Dictionary = _undo.pop_back()
	var redo_op := op.duplicate()
	_no_history = true
	match op["op"]:
		"place":
			remove_part(int(op["id"]))
		"remove":
			_replay_place(op["data"])
		"move":
			_apply_move(int(op["id"]), op["from"])
		"rotate":
			_apply_rotation(int(op["id"]), float(op["from"]))
		"recolor":
			recolor_part(int(op["id"]), str(op["from"]))
	_no_history = false
	_redo.append(redo_op)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var op: Dictionary = _redo.pop_back()
	_no_history = true
	match op["op"]:
		"place":
			_replay_place(op["data"])
		"remove":
			remove_part(int(op["id"]))
		"move":
			_apply_move(int(op["id"]), op["to"])
		"rotate":
			_apply_rotation(int(op["id"]), float(op["to"]))
		"recolor":
			recolor_part(int(op["id"]), str(op["to"]))
	_no_history = false
	_undo.append(op)
	return true


func _replay_place(data: Dictionary) -> void:
	var pos_arr: Array = data["pos"]
	var size_arr: Array = data["size"]
	place_part(
		str(data["type"]),
		Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2])),
		float(data["rot_y_deg"]),
		Vector3(float(size_arr[0]), float(size_arr[1]), float(size_arr[2])),
		str(data["color"]),
		str(data["material"]),
		int(data["id"]),
	)


func _apply_move(id: int, pos_arr: Array) -> void:
	var node := _get_node(id)
	if node == null:
		return
	var pos := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	_parts[id]["pos"] = [pos.x, pos.y, pos.z]
	node.position = pos


func _apply_rotation(id: int, deg: float) -> void:
	var node := _get_node(id)
	if node == null:
		return
	_parts[id]["rot_y_deg"] = fposmod(deg, 360.0)
	node.rotation_degrees.y = fposmod(deg, 360.0)


func _get_node(id: int) -> Node3D:
	if not _nodes.has(id):
		return null
	var node: Node3D = _nodes[id]
	if not is_instance_valid(node):
		return null
	return node


func _push_undo(op: Dictionary) -> void:
	if _no_history:
		return
	_undo.append(op)
	_redo.clear()


func _is_valid_hex(hex_str: String) -> bool:
	var clean := hex_str.strip_edges().to_lower()
	if clean.length() != 7 or not clean.begins_with("#"):
		return false
	for i in range(1, 7):
		if not "0123456789abcdef".contains(clean[i]):
			return false
	return true
