class_name PlayerCamera
extends Node3D
## PlayerCamera — orbit ala Roblox: yaw/pitch + SpringArm anti-tembus,
## zoom roda, shift-lock via Settings. Spek: docs/rea/player.md.

const HEAD_HEIGHT := 4.5
const SENSITIVITY_BASE := 0.005
const ZOOM_STEP := 2.0

var _player: Node3D = null
var _yaw: Node3D = null
var _pitch: Node3D = null
var _arm: SpringArm3D = null
var _cam: Camera3D = null


func _ready() -> void:
	_build_rig()


func _build_rig() -> void:
	if _arm != null:
		return
	_yaw = Node3D.new()
	_yaw.name = "Yaw"
	add_child(_yaw)
	_pitch = Node3D.new()
	_pitch.name = "Pitch"
	_yaw.add_child(_pitch)
	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	_arm.spring_length = GameConfig.CAM_DEFAULT_DIST
	_arm.collision_mask = GameConfig.LAYER_WORLD
	_pitch.add_child(_arm)
	_cam = Camera3D.new()
	_cam.name = "Cam"
	_cam.fov = 70.0
	_arm.add_child(_cam)


func setup(player: Node3D) -> void:
	_build_rig()
	_player = player
	if is_inside_tree():
		_cam.make_current()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	global_position = _player.global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
	if Settings.get_shift_lock() and _player.has_method("set_camera_yaw"):
		_player.set_camera_yaw(-_yaw.rotation_degrees.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_delta(event.relative.x, event.relative.y)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_dist(-ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_dist(ZOOM_STEP)


func add_look_delta(dx: float, dy: float) -> void:
	if _arm == null:
		return
	var s := SENSITIVITY_BASE * Settings.get_sensitivity()
	_yaw.rotation_degrees.y -= dx * s
	var direction := 1.0 if Settings.get_invert_y() else -1.0
	_pitch.rotation_degrees.x = clamp_pitch(_pitch.rotation_degrees.x + dy * s * direction)


func get_distance() -> float:
	if _arm == null:
		return 0.0
	return _arm.spring_length


func get_yaw_deg() -> float:
	return _yaw.rotation_degrees.y if _yaw != null else 0.0


static func clamp_pitch(x: float) -> float:
	return clampf(x, -80.0, 80.0)


func _change_dist(d: float) -> void:
	_arm.spring_length = clampf(
		_arm.spring_length + d, GameConfig.CAM_MIN_DIST, GameConfig.CAM_MAX_DIST
	)
