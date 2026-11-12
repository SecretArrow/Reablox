class_name JumpPad
extends Area3D
## JumpPad — perangkat lompat obby: melempar pemain setinggi `power` studs.

var uses := 0


static func make(pos: Vector3, power := 15.0) -> JumpPad:
	var pad := JumpPad.new()
	pad.position = pos
	pad.collision_mask = GameConfig.LAYER_PLAYER
	pad.monitoring = true
	pad.set_meta("power", power)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 0.6, 4.0)
	col.shape = shape
	pad.add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 0.4
	mesh.mesh = cyl
	mesh.position = Vector3(0.0, -0.1, 0.0)
	mesh.material_override = MaterialsLib.make("neon", Color(0.18, 0.8, 0.24))
	pad.add_child(mesh)
	pad.body_entered.connect(pad._on_body_entered)
	return pad


func _on_body_entered(body: Node3D) -> void:
	if body == null or not (body is CharacterBody3D):
		return
	var power := float(get_meta("power", 15.0))
	body.velocity.y = sqrt(2.0 * GameConfig.GRAVITY * power)
	uses += 1
	Audio.play_sfx("jump")
