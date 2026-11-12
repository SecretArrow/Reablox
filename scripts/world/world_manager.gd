class_name WorldManager
extends Node
## WorldManager — merakit dunia utuh: terrain + langit + air + elemen demo
## atau dunia tersimpan (parts BuildManager), plus simpan ulang.

var _root: Node3D = null
var _env: WorldEnv = null
var _terrain: TerrainGen = null
var _build: BuildManager = null
var _seed := 42
var _size := 128
var _water_level := 2.0


func load_demo(world_name: String) -> bool:
	var data := DemoWorlds.find(world_name)
	if data.is_empty():
		push_warning("Dunia demo tidak dikenal: %s" % world_name)
		return false
	_clear_root()
	_seed = int(data.get("seed", 42))
	_size = int(data.get("size", 128))
	_water_level = float(data.get("water_level", 2.0))
	_build_terrain()
	if world_name == DemoWorlds.OBBY_NAME:
		DemoWorlds.build_obby(_root)
	elif world_name == DemoWorlds.PLAZA_NAME:
		DemoWorlds.build_plaza(_root)
	_setup_env()
	_setup_build()
	GameState.reset_run(world_name)
	GameEvents.world_loaded.emit(world_name)
	return true


func load_saved(world_name: String) -> bool:
	var data := Saves.load_world(world_name)
	if data.is_empty():
		push_warning("Dunia tersimpan tidak ditemukan: %s" % world_name)
		return false
	_clear_root()
	var terrain_data: Dictionary = data.get("terrain", {})
	_seed = int(terrain_data.get("seed", 42))
	_size = int(terrain_data.get("size", 128))
	_water_level = float(terrain_data.get("water_level", 2.0))
	_build_terrain()
	_setup_env()
	_setup_build()
	_build.load_parts(data.get("parts", []))
	GameState.reset_run(world_name)
	GameEvents.world_loaded.emit(world_name)
	return true


func save_current() -> bool:
	if _root == null:
		push_warning("Tidak ada dunia aktif untuk disimpan.")
		return false
	var payload := {
		"version": 1,
		"name": GameState.current_world,
		"terrain": {"seed": _seed, "size": _size, "water_level": _water_level},
		"parts": [],
		"elements": [],
		"npcs": [],
	}
	if _env != null:
		payload["time_hour"] = _env.get_hour()
	if _build != null:
		payload["parts"] = _build.serialize()
	return Saves.save_world(GameState.current_world, payload)


func get_root() -> Node3D:
	return _root


func get_build() -> BuildManager:
	return _build


func get_env() -> WorldEnv:
	return _env


func get_terrain() -> TerrainGen:
	return _terrain


func clear() -> void:
	_clear_root()


func _build_terrain() -> void:
	_terrain = TerrainGen.new()
	add_child(_terrain)
	_root = Node3D.new()
	_root.name = "WorldRoot"
	add_child(_root)
	_root.add_child(_terrain.generate(_seed, _size, _water_level))


func _setup_env() -> void:
	_env = WorldEnv.new()
	add_child(_env)
	_env.setup(_root)
	_env.set_hour(GameConfig.START_TIME_HOUR)
	_env.apply_quality(Settings.get_quality())
	if _water_level > -10.0:
		var water := WaterPlane.new(256.0)
		water.set_water_level(_water_level)
		_root.add_child(water)


func _setup_build() -> void:
	_build = BuildManager.new()
	add_child(_build)
	_build.setup(_root)


func _clear_root() -> void:
	if _build != null:
		_build.queue_free()
		_build = null
	if _terrain != null:
		_terrain.queue_free()
		_terrain = null
	if _env != null:
		_env.queue_free()
		_env = null
	if _root != null:
		_root.queue_free()
		_root = null
