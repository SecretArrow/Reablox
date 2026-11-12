class_name KillBrick
extends Area3D
## KillBrick — blok maut neon merah ala obby Roblox: menyentuh = damage fatal.

var kill_count := 0


static func make(pos: Vector3, size := Vector3(4.0, 1.0, 4.0)) -> KillBrick:
	var brick := KillBrick.new()
	brick.position = pos
	brick.collision_mask = GameConfig.LAYER_PLAYER
	brick.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	brick.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make("neon", Color(0.76, 0.13, 0.11))
	brick.add_child(mesh)
	brick.body_entered.connect(brick._on_body_entered)
	return brick


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("damage"):
		body.damage(999.0)
		kill_count += 1
