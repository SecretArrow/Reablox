# Reablox scene smoke test: load every .tscn one by one, catch parse/missing script errors.
# Runs headless. Prints SCENE_OK for each scene and SCENE_FAIL with reason on error.
extends SceneTree

var _scenes: Array = []
var _idx: int = 0
var _fails: int = 0


func _init() -> void:
	var root_dir: String = "res://scenes"
	_scenes = _collect_scenes(root_dir)
	_scenes.sort()
	print("SCENE_TOTAL %d" % _scenes.size())
	_next.call_deferred()


func _collect_scenes(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		var full: String = dir_path + "/" + fname
		if dir.current_is_dir() and not fname.begins_with("."):
			out.append_array(_collect_scenes(full))
		elif fname.ends_with(".tscn"):
			out.append(full)
		fname = dir.get_next()
	dir.list_dir_end()
	return out


func _next() -> void:
	if _idx >= _scenes.size():
		print("SCENE_SUMMARY %d/%d OK, %d FAIL" % [_scenes.size() - _fails, _scenes.size(), _fails])
		if _fails == 0:
			print("ALL_SCENES_PASS")
		else:
			print("SCENES_FAILED")
		quit(0 if _fails == 0 else 1)
		return
	var path: String = _scenes[_idx]
	_idx += 1
	var packed: PackedScene = load(path)
	if packed == null:
		print("SCENE_FAIL %s reason=load_returned_null" % path)
		_fails += 1
		_next.call_deferred()
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		print("SCENE_FAIL %s reason=instantiate_returned_null" % path)
		_fails += 1
		_next.call_deferred()
		return
	print("SCENE_OK %s (%s)" % [path, inst.get_class()])
	inst.free()
	_next.call_deferred()
