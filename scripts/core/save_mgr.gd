extends Node
## Saves — penyimpanan dunia (JSON) di user://worlds/.


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("worlds"):
		dir.make_dir_recursive("worlds")


func sanitize_name(world_name: String) -> String:
	var out := ""
	for c in world_name.strip_edges():
		if (
			(c >= "a" and c <= "z")
			or (c >= "A" and c <= "Z")
			or (c >= "0" and c <= "9")
			or c == " "
			or c == "_"
			or c == "-"
		):
			out += c
	out = out.strip_edges()
	return out.substr(0, 32) if not out.is_empty() else "Dunia"


func world_path(world_name: String) -> String:
	return "user://worlds/%s.json" % sanitize_name(world_name)


func world_exists(world_name: String) -> bool:
	return FileAccess.file_exists(world_path(world_name))


func save_world(world_name: String, data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(world_path(world_name), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	GameEvents.world_saved.emit(sanitize_name(world_name))
	return true


func load_world(world_name: String) -> Dictionary:
	var path := world_path(world_name)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func delete_world(world_name: String) -> bool:
	var path := world_path(world_name)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return err == Error.OK


func list_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open("user://worlds")
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(".json"):
			var entry := _read_world_meta("user://worlds/" + fname)
			entry["name"] = fname.get_basename()
			out.append(entry)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(_worlds_newest_first)
	return out


func unique_world_name(base_name: String) -> String:
	var base := sanitize_name(base_name)
	if not world_exists(base):
		return base
	var idx := 2
	while world_exists("%s_%d" % [base, idx]):
		idx += 1
	return "%s_%d" % [base, idx]


func _read_world_meta(path: String) -> Dictionary:
	var meta := {"saved_at": 0.0, "parts": -1}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return meta
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		meta["saved_at"] = float(parsed.get("saved_at", 0.0))
		var parts = parsed.get("parts", [])
		if parts is Array:
			meta["parts"] = parts.size()
	return meta


func _worlds_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a["saved_at"]) > float(b["saved_at"])
