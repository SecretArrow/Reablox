class_name NpcMonster
extends NpcBase
## NpcMonster — monster merah bermata neon: patrol antar waypoint,
## kejar pemain dalam 25 studs, serang dalam 4 studs (damage 10, jeda 1 dtk).

const CHASE_RANGE := 25.0
const ATTACK_RANGE := 4.0
const PATROL_SPEED := 6.0
const CHASE_SPEED := 10.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.0

var waypoints: Array = []
var _wp_index := 0
var _target: Node3D = null
var _state := "patrol"
var _attack_timer := 0.0
var _attack_count := 0


func _ready() -> void:
	super()
	npc_name = "Monster"
	health = 60.0
	max_health = 60.0
	_build_visual()


func set_target(p: Node3D) -> void:
	_target = p


func set_waypoints(points: Array) -> void:
	waypoints = points
	_wp_index = 0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.8
	capsule.height = 4.0
	body.mesh = capsule
	body.position = Vector3(0.0, 2.0, 0.0)
	body.material_override = MaterialsLib.make("plastic", Color(0.7, 0.15, 0.1))
	add_child(body)
	_add_eye(-0.25)
	_add_eye(0.25)


func _add_eye(offset_x: float) -> void:
	var eye := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	eye.mesh = box
	eye.position = Vector3(offset_x, 3.2, -0.75)
	eye.material_override = MaterialsLib.make("neon", Color(1.0, 0.1, 0.1))
	add_child(eye)


## AI: serang bila sangat dekat, kejar bila terlihat, patrol bila jauh.
func _ai(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _target == null or not is_instance_valid(_target):
		_patrol(delta)
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist <= ATTACK_RANGE:
		_attack_target()
	elif dist <= CHASE_RANGE:
		_state = "chase"
		_move_toward(_target.global_position, CHASE_SPEED, delta)
	else:
		_patrol(delta)


func _attack_target() -> void:
	_state = "attack"
	velocity.x = 0.0
	velocity.z = 0.0
	if _attack_timer > 0.0:
		return
	if not _target.has_method("damage"):
		return
	_target.damage(ATTACK_DAMAGE)
	_attack_timer = ATTACK_COOLDOWN
	_attack_count += 1


func _patrol(delta: float) -> void:
	if waypoints.is_empty():
		_state = "idle"
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_state = "patrol"
	var wp: Vector3 = waypoints[_wp_index]
	if global_position.distance_to(wp) < 1.5:
		_wp_index = (_wp_index + 1) % waypoints.size()
	else:
		_move_toward(wp, PATROL_SPEED, delta)


func _move_toward(target: Vector3, speed: float, _delta: float) -> void:
	var dir := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if dir.length() > 0.1:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func get_state() -> String:
	return _state


func get_attack_count() -> int:
	return _attack_count
