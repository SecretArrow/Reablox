extends Node
## SceneLoader — perpindahan scene antar layar utama (menu <-> game).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"


func goto_scene(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("Scene tidak ditemukan: %s" % path)
		return false
	return get_tree().change_scene_to_file(path) == Error.OK


func goto_menu() -> bool:
	return goto_scene(MENU_SCENE)


func goto_game() -> bool:
	return goto_scene(GAME_SCENE)
