class_name Screenshot
extends Node
## Screenshot — menangkap layar ke PNG di user://screenshots/.
##
## Aman untuk headless/CI: bila server display tidak tersedia atau tekstur
## viewport kosong, capture() mengembalikan string kosong tanpa crash.
## Nama file memakai epoch milidetik supaya unik dan terurut.

const SAVE_DIR := "user://screenshots"
const FILE_PREFIX := "reablox_"


## Tangkap viewport saat ini; kembalikan path file PNG, atau "" bila gagal.
func capture() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var viewport := get_viewport()
	if viewport == null:
		return ""
	var tex := viewport.get_texture()
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var path := (
		"%s/%s%d.png" % [SAVE_DIR, FILE_PREFIX, int(Time.get_unix_time_from_system() * 1000.0)]
	)
	var err := img.save_png(path)
	if err != Error.OK:
		push_warning("Gagal menyimpan screenshot %s (err %d)." % [path, err])
		return ""
	return path
