class_name Checkpoint
extends Area3D
## Checkpoint — titik simpan ala SpawnLocation obby Roblox: menyala hijau
## neon setelah diaktifkan, memajukan tahap pemain.

const PALETTE := [
	Color(0.04, 0.41, 0.67),
	Color(0.96, 0.16, 0.11),
	Color(0.29, 0.59, 0.19),
	Color(0.96, 0.72, 0.05),
]
const ACTIVE_COLOR := Color(0.29, 0.59, 0.19)

var index := 0
var activated := false


static func make(pos: Vector3, checkpoint_index: int) -> Checkpoint:
	var cp := Checkpoint.new()
	cp.position = pos
	cp.index = checkpoint_index
	cp.collision_mask = GameConfig.LAYER_PLAYER
	cp.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 0.5, 4.0)
	col.shape = shape
	cp.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 0.5, 4.0)
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make(
		"plastic", PALETTE[checkpoint_index % PALETTE.size()]
	)
	cp.add_child(mesh)
	cp.body_entered.connect(cp._on_body_entered)
	return cp


func _on_body_entered(body: Node3D) -> void:
	if activated or body == null or not body.has_method("damage"):
		return
	activated = true
	GameState.activate_checkpoint(index)
	while GameState.stage < index + 1:
		GameState.next_stage()
	Audio.play_sfx("checkpoint")
	var mesh := get_node_or_null("Visual") as MeshInstance3D
	if mesh != null:
		mesh.material_override = MaterialsLib.make("neon", ACTIVE_COLOR)


func reset() -> void:
	activated = false
	var mesh := get_node_or_null("Visual") as MeshInstance3D
	if mesh != null:
		mesh.material_override = MaterialsLib.make("plastic", PALETTE[index % PALETTE.size()])
