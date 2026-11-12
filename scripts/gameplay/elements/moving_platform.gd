class_name MovingPlatform
extends AnimatableBody3D
## MovingPlatform — platform bolak-balik ala obby Roblox. AnimatableBody3D
## otomatis membawa pemain yang berdiri di atasnya.

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _speed := 4.0
var _t := 0.0
var _progress := 0.0


static func make(
	a: Vector3, b: Vector3, speed := 4.0, size := Vector3(6.0, 0.5, 6.0)
) -> MovingPlatform:
	var plat := MovingPlatform.new()
	plat._a = a
	plat._b = b
	plat._speed = maxf(speed, 0.1)
	plat.position = a
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	plat.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make("plastic", Color(0.64, 0.64, 0.64))
	plat.add_child(mesh)
	return plat


func _physics_process(delta: float) -> void:
	var dist := _a.distance_to(_b)
	if dist < 0.001:
		return
	_t += delta * _speed / dist
	var cycle := fmod(_t, 2.0)
	_progress = cycle if cycle <= 1.0 else 2.0 - cycle
	position = _a.lerp(_b, _progress)


func get_progress() -> float:
	return _progress
