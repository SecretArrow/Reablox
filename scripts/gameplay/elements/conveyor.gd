class_name Conveyor
extends AnimatableBody3D
## Conveyor — sabuk dorong ala obby Roblox: mendorong tubuh karakter yang
## berada di atasnya sepanjang arah sabuk.

var push_count := 0
var _dir := Vector3(0.0, 0.0, -1.0)
var _speed := 8.0
var _bodies := {}


static func make(
	pos: Vector3,
	dir := Vector3(0.0, 0.0, -1.0),
	speed := 8.0,
	size := Vector3(6.0, 0.5, 12.0),
) -> Conveyor:
	var cv := Conveyor.new()
	cv.position = pos
	cv._dir = dir.normalized()
	cv._speed = speed
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	cv.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make("asphalt", Color.WHITE)
	cv.add_child(mesh)
	var area := Area3D.new()
	area.collision_mask = GameConfig.LAYER_PLAYER
	area.monitoring = true
	var area_col := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(size.x, 1.0, size.z)
	area_col.shape = area_shape
	area_col.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(area_col)
	cv.add_child(area)
	area.body_entered.connect(cv._on_body_entered)
	area.body_exited.connect(cv._on_body_exited)
	return cv


func _physics_process(delta: float) -> void:
	push_count = 0
	for body in _bodies.values():
		if body != null and is_instance_valid(body) and body is CharacterBody3D:
			body.global_position += _dir * _speed * delta
			push_count += 1


func _on_body_entered(body: Node3D) -> void:
	_bodies[body.get_instance_id()] = body


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body.get_instance_id())
