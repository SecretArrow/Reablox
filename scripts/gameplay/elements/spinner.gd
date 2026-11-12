class_name Spinner
extends AnimatableBody3D
## Spinner — palang berputar mematikan ala obby Roblox (kill-bar berputar).

var kill_count := 0
var _speed_deg := 120.0


static func make(pos: Vector3, radius := 6.0, speed_deg := 120.0, damage := 999.0) -> Spinner:
	var sp := Spinner.new()
	sp.position = pos
	sp._speed_deg = speed_deg
	sp.set_meta("damage", damage)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.0, 1.0, 1.2)
	col.shape = shape
	sp.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(radius * 2.0, 1.0, 1.2)
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make("neon", Color(0.76, 0.13, 0.11))
	sp.add_child(mesh)
	var pole := MeshInstance3D.new()
	var pole_box := BoxMesh.new()
	pole_box.size = Vector3(1.0, 3.0, 1.0)
	pole.mesh = pole_box
	pole.position = Vector3(0.0, 1.5, 0.0)
	pole.material_override = MaterialsLib.make("concrete", Color.WHITE)
	sp.add_child(pole)
	var area := Area3D.new()
	area.collision_mask = GameConfig.LAYER_PLAYER
	area.monitoring = true
	var area_col := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(radius * 2.0, 1.4, radius * 2.0)
	area_col.shape = area_shape
	area.add_child(area_col)
	sp.add_child(area)
	area.body_entered.connect(sp._on_body_entered)
	return sp


func _physics_process(delta: float) -> void:
	rotate_y(deg_to_rad(_speed_deg) * delta)


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.has_method("damage"):
		body.damage(float(get_meta("damage", 999.0)))
		kill_count += 1
