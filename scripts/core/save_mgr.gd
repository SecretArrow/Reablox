extends Node
## Saves — penyimpanan dunia (JSON) di user://worlds/ + profil pemain.
##
## Penulisan ATOMIK: teks ditulis ke <file>.tmp lalu di-rename ke target
## (rename pada filesystem yang sama bersifat atomik menurut POSIX), jadi file
## utama tidak pernah setengah jadi. Dunia yang setelah di-stringify lebih
## besar dari 8 MB ditolak. load_world mensyaratkan kunci "version".

const WORLDS_DIR := "user://worlds"
const PROFILE_PATH := "user://profile.json"
const NAME_MAX_LEN := 32
const MAX_JSON_BYTES := 8 * 1024 * 1024


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("worlds"):
		dir.make_dir_recursive("worlds")


# --- Nama file -----------------------------------------------------------------


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
	if out.is_empty():
		return "Dunia"
	return out.substr(0, NAME_MAX_LEN)


func world_path(world_name: String) -> String:
	return "user://worlds/%s.json" % sanitize_name(world_name)


func world_exists(world_name: String) -> bool:
	return FileAccess.file_exists(world_path(world_name))


# --- Dunia ------------------------------------------------------------------------


func save_world(world_name: String, data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["saved_at"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(payload, "\t")
	if text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		push_warning(
			"Dunia '%s' > %d MB — tidak disimpan." % [world_name, MAX_JSON_BYTES / 1048576]
		)
		return false
	if not _atomic_write_text(world_path(world_name), text):
		return false
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
	f.close()
	if not (parsed is Dictionary):
		push_warning("Dunia '%s' bukan JSON valid — dikosongkan." % world_name)
		return {}
	var dict: Dictionary = parsed
	if not dict.has("version"):
		push_warning("Dunia '%s' tanpa 'version' — dikosongkan." % world_name)
		return {}
	return dict


func delete_world(world_name: String) -> bool:
	var path := world_path(world_name)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != Error.OK:
		push_warning("Gagal menghapus dunia '%s' (err %d)." % [world_name, err])
		return false
	return true


func list_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(WORLDS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(".json"):
			var entry := _read_world_meta("%s/%s" % [WORLDS_DIR, fname])
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
	f.close()
	if parsed is Dictionary:
		meta["saved_at"] = float(parsed.get("saved_at", 0.0))
		var parts = parsed.get("parts", [])
		if parts is Array:
			meta["parts"] = parts.size()
	return meta


func _worlds_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a["saved_at"]) > float(b["saved_at"])


# --- Profil pemain -----------------------------------------------------------------


func save_profile(data: Dictionary) -> bool:
	return _atomic_write_text(PROFILE_PATH, JSON.stringify(data, "\t"))


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	push_warning("profile.json korup — dikosongkan.")
	return {}


# --- Tulis atomik --------------------------------------------------------------------


func _atomic_write_text(path: String, text: String) -> bool:
	var tmp_path := path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("Tidak bisa membuka file sementara: %s" % tmp_path)
		return false
	f.store_string(text)
	var write_err := f.get_error()
	f.close()
	if write_err != Error.OK:
		push_warning("Gagal menulis %s (err %d)." % [tmp_path, write_err])
		_remove_file(tmp_path)
		return false
	var rename_err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path)
	)
	if rename_err != Error.OK:
		push_warning("Gagal memindahkan %s -> %s (err %d)." % [tmp_path, path, rename_err])
		_remove_file(tmp_path)
		return false
	return true


func _remove_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != Error.OK:
		push_warning("Gagal menghapus %s (err %d)." % [path, err])
