class_name PlayerController
extends CharacterBody3D
## PlayerController — fisika paritas Humanoid Roblox: WalkSpeed 16,
## JumpHeight 7.2, gravity 196.2 studs/s². Spek: docs/rea/player.md.

const ACCEL_GROUND := 160.0
const ACCEL_AIR := 60.0
const TERMINAL_VELOCITY := 400.0
const ROTATE_SPEED := 12.0

var camera_yaw := 0.0
var health := 100.0
var max_health := 100.0
var is_remote := false
var test_respawn_override := -1.0

var _state := "idle"
var _dead := false
var _respawn_timer := 0.0
var _move_override := Vector2.ZERO
var _jump_override := false
var _in_water := false
var _climb_zone := false
var _spawn_point := Vector3.ZERO
var _checkpoint := Vector3.ZERO
var _remote_target_pos := Vector3.ZERO
var _remote_yaw := 0.0
var _remote_state := "idle"
var _avatar: Node = null


func _ready() -> void:
	max_health = GameConfig.MAX_HEALTH
	health = max_health
	collision_layer = GameConfig.LAYER_PLAYER
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PARTS | GameConfig.LAYER_NPC
	floor_max_angle = deg_to_rad(89.0)
	_add_capsule()
	_spawn_point = global_position
	_checkpoint = _spawn_point


func _add_capsule() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 5.0
	col.shape = capsule
	col.position = Vector3(0.0, 2.5, 0.0)
	add_child(col)


func _physics_process(delta: float) -> void:
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_do_respawn()
		return
	if is_remote:
		_step_remote(delta)
		return
	var dir := _input_dir()
	var wish := _wish_direction(dir)
	if _in_water:
		_step_swim(delta, wish)
		return
	if _climb_zone and dir.y < -0.3:
		_step_climb()
		return
	_step_ground(delta, wish)


func _input_dir() -> Vector2:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if _move_override.length() > 0.01:
		dir = _move_override
	return dir


func _wish_direction(dir: Vector2) -> Vector3:
	var fwd := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var wish := right * dir.x + fwd * (-dir.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	return wish


func _step_ground(delta: float, wish: Vector3) -> void:
	var target := GameConfig.WALK_SPEED
	var sprinting := Input.is_action_pressed("sprint")
	if sprinting:
		target = GameConfig.SPRINT_SPEED
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, wish.x * target, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z * target, accel * delta)
	velocity.y = maxf(velocity.y - GameConfig.GRAVITY * delta, -TERMINAL_VELOCITY)
	var want_jump := Input.is_action_just_pressed("jump") or (_jump_override and is_on_floor())
	if want_jump and is_on_floor():
		velocity.y = sqrt(2.0 * GameConfig.GRAVITY * GameConfig.JUMP_HEIGHT)
	move_and_slide()
	if wish.length() > 0.05:
		var target_yaw := atan2(wish.x, wish.z) + PI
		var lerped := lerp_angle(
			deg_to_rad(rotation_degrees.y), target_yaw, minf(delta * ROTATE_SPEED, 1.0)
		)
		rotation_degrees.y = rad_to_deg(lerped)
	_update_state_ground(sprinting, wish)
	_push_anim()


func _update_state_ground(sprinting: bool, wish: Vector3) -> void:
	if _in_water:
		_state = "swim"
	elif not is_on_floor():
		_state = "jump" if velocity.y > 1.0 else "freefall"
	elif wish.length() > 0.05:
		_state = "run" if sprinting else "walk"
	else:
		_state = "idle"


func _step_swim(delta: float, wish: Vector3) -> void:
	var swim := GameConfig.SWIM_SPEED
	velocity.x = move_toward(velocity.x, wish.x * swim, ACCEL_GROUND * delta)
	velocity.z = move_toward(velocity.z, wish.z * swim, ACCEL_GROUND * delta)
	velocity.y = move_toward(velocity.y, 0.0, 60.0 * delta)
	if Input.is_action_pressed("jump"):
		velocity.y = swim * 0.6
	elif Input.is_action_pressed("sprint"):
		velocity.y = -swim * 0.6
	_state = "swim"
	move_and_slide()
	_push_anim()


func _step_climb() -> void:
	velocity = Vector3(0.0, GameConfig.CLIMB_SPEED, 0.0)
	_state = "climb"
	if Input.is_action_just_pressed("jump"):
		velocity.y = sqrt(2.0 * GameConfig.GRAVITY * GameConfig.JUMP_HEIGHT)
	move_and_slide()
	_push_anim()


func _step_remote(delta: float) -> void:
	var f := minf(delta * 10.0, 1.0)
	global_position = global_position.lerp(_remote_target_pos, f)
	var lerped := lerp_angle(deg_to_rad(rotation_degrees.y), deg_to_rad(_remote_yaw), f)
	rotation_degrees.y = rad_to_deg(lerped)
	_state = _remote_state
	_push_anim()


func _push_anim() -> void:
	if _avatar != null and is_instance_valid(_avatar) and _avatar.has_method("set_state"):
		_avatar.set_state(_state)


func set_camera_yaw(y: float) -> void:
	camera_yaw = y


func get_state() -> String:
	return _state


func get_health() -> float:
	return health


func damage(n: float) -> void:
	if _dead:
		return
	health = maxf(health - n, 0.0)
	GameEvents.player_health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func heal(n: float) -> void:
	health = minf(health + n, max_health)
	GameEvents.player_health_changed.emit(health, max_health)


func set_checkpoint(p: Vector3) -> void:
	_checkpoint = p


func set_spawn(p: Vector3) -> void:
	_spawn_point = p
	_checkpoint = p


func set_in_water(b: bool) -> void:
	_in_water = b


func set_climb_zone(b: bool) -> void:
	_climb_zone = b


func set_move_override(v: Vector2) -> void:
	_move_override = v


func set_jump_override(b: bool) -> void:
	_jump_override = b


func bind_avatar(node: Node) -> void:
	_avatar = node


func apply_remote(pos: Vector3, yaw_deg: float, state: String) -> void:
	_remote_target_pos = pos
	_remote_yaw = yaw_deg
	_remote_state = state


func _die() -> void:
	_dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	GameEvents.player_died.emit()
	if test_respawn_override > 0.0:
		_respawn_timer = test_respawn_override
	else:
		_respawn_timer = GameConfig.RESPAWN_TIME


func _do_respawn() -> void:
	_dead = false
	health = max_health
	global_position = _checkpoint
	velocity = Vector3.ZERO
	_state = "idle"
	GameEvents.player_respawned.emit()
	GameEvents.player_health_changed.emit(health, max_health)
