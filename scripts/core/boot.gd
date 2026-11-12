extends Control
## Boot — titik masuk aplikasi: tunggu autoload siap lalu buka menu utama.


func _ready() -> void:
	await get_tree().process_frame
	if not SceneLoader.goto_menu():
		_show_rebuild_notice()


func _show_rebuild_notice() -> void:
	var label := Label.new()
	label.text = "REABLOX v0.6\nSedang dibangun ulang — menu belum tersedia."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	add_child(label)
