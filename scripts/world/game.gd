class_name Game
extends Node
## Game — scene dunia bermain: merakit dunia (demo/tersimpan), pemain,
## avatar R6 + animator, dan kamera orbit. Semua dibangun defensif.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _wm: WorldManager = null
var _player: PlayerController = null
var _camera: PlayerCamera = null


func _ready() -> void:
	_wm = WorldManager.new()
	add_child(_wm)
	var world_name := GameState.current_world
	var loaded := false
	if not DemoWorlds.find(world_name).is_empty():
		loaded = _wm.load_demo(world_name)
	else:
		loaded = _wm.load_saved(world_name)
	if not loaded:
		loaded = _wm.load_demo(DemoWorlds.OBBY_NAME)
	_spawn_player()


func get_player() -> PlayerController:
	return _player


func get_world_manager() -> WorldManager:
	return _wm


func get_camera() -> PlayerCamera:
	return _camera


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	var spawn := _find_spawn()
	_player.position = spawn
	add_child(_player)
	_player.set_checkpoint(spawn)
	_attach_avatar()
	_camera = PlayerCamera.new()
	add_child(_camera)
	_camera.setup(_player)


func _find_spawn() -> Vector3:
	var root := _wm.get_root()
	if root != null:
		var cps := root.find_children("*", "Checkpoint", true, false)
		if not cps.is_empty():
			var best: Checkpoint = null
			for cp in cps:
				var checkpoint := cp as Checkpoint
				if best == null or checkpoint.index < best.index:
					best = checkpoint
			return best.position + Vector3(0.0, 2.0, 0.0)
		var terrain := _wm.get_terrain()
		if terrain != null:
			return Vector3(0.0, terrain.height_at(0.0, 0.0) + 2.0, 0.0)
	return Vector3(0.0, 12.0, 0.0)


func _attach_avatar() -> void:
	var rig := AvatarRig.new()
	rig.name = "AvatarRig"
	_player.add_child(rig)
	rig.build(AvatarConfig.default_config())
	var animator := AvatarAnimator.new()
	animator.name = "AvatarAnimator"
	_player.add_child(animator)
	animator.attach(rig)
	_player.bind_avatar(animator)
