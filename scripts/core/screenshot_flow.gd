class_name ScreenshotFlow
extends Node
## ScreenshotFlow — mode pratinjau CI: argumen `--screenshot-demo`
## `--shot-dir=<path>` merender 5 tangkapan 1080p (menu, obby, plaza,
## avatar, hud) lalu keluar. Dipakai job "Pratinjau screenshot" di
## android-build.yml (Xvfb + GL compatibility).

const SHOT_NAMES := ["menu", "obby", "plaza", "avatar", "hud"]
const WAIT_GAME := 2.5
const WAIT_MENU := 1.5

var _shot_dir := "shots"
var _index := 0
var _current: Node = null


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_next()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.substr("--shot-dir=".length())


func _next() -> void:
	if _index >= SHOT_NAMES.size():
		print("SCREENSHOT_DEMO_DONE %d" % _index)
		get_tree().quit()
		return
	var shot_name: String = SHOT_NAMES[_index]
	_index += 1
	var wait := _build_scene(shot_name)
	await get_tree().create_timer(wait).timeout
	_capture(shot_name)
	_clear_scene()
	_next()


func _build_scene(shot_name: String) -> float:
	match shot_name:
		"menu":
			_add_scene("res://scenes/menu/main_menu.tscn")
			return WAIT_MENU
		"obby":
			GameState.reset_run("Pulau Obby")
			_add_scene("res://scenes/game/game.tscn")
			return WAIT_GAME
		"plaza":
			GameState.reset_run("Plaza Kreatif")
			_add_scene("res://scenes/game/game.tscn")
			return WAIT_GAME
		"avatar":
			var menu := _add_scene("res://scenes/menu/main_menu.tscn")
			if menu != null and menu.has_method("open_avatar"):
				menu.open_avatar()
			return WAIT_MENU
		"hud":
			GameState.reset_run("Pulau Obby")
			var game := _add_scene("res://scenes/game/game.tscn")
			if game != null:
				var hud := Hud.new()
				game.add_child(hud)
				hud.update_health(85.0, 100.0)
				hud.update_coins(42)
				hud.update_stage(3)
			return WAIT_GAME
	return WAIT_MENU


func _add_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("Scene pratinjau tidak ada: %s" % path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	_current = packed.instantiate()
	get_tree().root.add_child(_current)
	return _current


func _capture(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty() or img.get_width() < 10:
		img = Image.create(1920, 1080, false, Image.FORMAT_RGB8)
		img.fill(Color(0.09, 0.1, 0.16))
	var path := _shot_dir.path_join("%s.png" % shot_name)
	var err := img.save_png(path)
	if err != Error.OK:
		push_warning("Gagal menyimpan pratinjau %s (error %d)" % [path, err])
	else:
		print("SCREENSHOT_SAVED %s" % path)


func _clear_scene() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null
