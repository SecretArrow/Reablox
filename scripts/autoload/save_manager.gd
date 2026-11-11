extends Node
## Autoload: Saves — manajemen file world (.myworld), ekspor/impor, screenshot.
## Format .myworld = JSON teks:
## {"format":"reablox-world","version":1,"meta":{...},"settings":{...},
## "blocks":[...],"props":[...],"terrain":{...}}

const WORLDS_DIR := "user://worlds"
const EXPORTS_DIR := "user://exports"
const IMPORTS_DIR := "user://imports"
const SHOTS_DIR := "user://screenshots"
const EXT := ".myworld"


func _ready() -> void:
	for d in [WORLDS_DIR, EXPORTS_DIR, IMPORTS_DIR, SHOTS_DIR]:
		DirAccess.make_dir_recursive_absolute(d)


func list_worlds() -> Array:
	var out: Array = []
	var files := DirAccess.get_files_at(WORLDS_DIR)
	for f in files:
		if not String(f).ends_with(EXT):
			continue
		var path := "%s/%s" % [WORLDS_DIR, f]
		var data := load_world(path)
		if data.is_empty():
			continue
		var meta: Dictionary = data.get("meta", {})
		(
			out
			. append(
				{
					"name": String(meta.get("name", String(f).trim_suffix(EXT))),
					"path": path,
					"modified": FileAccess.get_modified_time(path),
					"is_template": bool(meta.get("is_template", false)),
				}
			)
		)
	out.sort_custom(func(a, b): return int(a.get("modified", 0)) > int(b.get("modified", 0)))
	return out


func save_world(world_name: String, data: Dictionary) -> Error:
	if not data.has("meta"):
		data["meta"] = {}
	data["meta"]["name"] = world_name
	var safe := _sanitize_filename(world_name)
	var path := "%s/%s%s" % [WORLDS_DIR, safe, EXT]
	if FileAccess.file_exists(path):
		var n := 2
		while FileAccess.file_exists("%s/%s_%d%s" % [WORLDS_DIR, safe, n, EXT]):
			n += 1
		path = "%s/%s_%d%s" % [WORLDS_DIR, safe, n, EXT]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FAILED
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


func load_world(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	var fmt := String(data.get("format", ""))
	if fmt != "reablox-world" and fmt != "rblox-world":
		return {}
	return data


func delete_world(path: String) -> Error:
	# "/": tanpa pemisah, "user://worlds_evil/..." lolos begins_with(WORLDS_DIR).
	if not String(path).begins_with(WORLDS_DIR + "/"):
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(path)


func export_world(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var fname := path.get_file()
	var dest := "%s/%s" % [EXPORTS_DIR, fname]
	var err := DirAccess.copy_absolute(path, dest)
	if err != OK:
		return ""
	return dest


func import_world(source_path: String) -> String:
	if not FileAccess.file_exists(source_path):
		return ""
	var data := load_world(source_path)
	if data.is_empty():
		return ""
	var name := String(data.get("meta", {}).get("name", source_path.get_file().trim_suffix(EXT)))
	var safe := _sanitize_filename(name)
	var dest := "%s/%s%s" % [WORLDS_DIR, safe, EXT]
	var err := DirAccess.copy_absolute(source_path, dest)
	if err != OK:
		return ""
	return dest


func save_screenshot(img: Image) -> String:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	var secs := Time.get_unix_time_from_system()
	var fname := "shot_%d_%03d.png" % [int(secs), Time.get_ticks_msec() % 1000]
	var path := "%s/%s" % [SHOTS_DIR, fname]
	var err := img.save_png(path)
	if err != OK:
		return ""
	return path


func _sanitize_filename(name: String) -> String:
	var safe := name.to_lower().strip_edges()
	var re := RegEx.new()
	re.compile("[^a-z0-9_\\-]+")
	safe = re.sub(safe, "_", true)
	if safe == "":
		safe = "world"
	return safe.substr(0, 40)
