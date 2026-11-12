extends Control
## Boot — titik masuk aplikasi: tunggu autoload siap lalu buka menu utama.
## Mode khusus: `-- --screenshot-demo --shot-dir=...` (pratinjau CI).


func _ready() -> void:
	await get_tree().process_frame
	if _screenshot_mode():
		var flow := ScreenshotFlow.new()
		get_tree().root.add_child(flow)
		return
	if not SceneLoader.goto_menu():
		_show_rebuild_notice()


func _screenshot_mode() -> bool:
	return "--screenshot-demo" in OS.get_cmdline_user_args()


func _show_rebuild_notice() -> void:
	var label := Label.new()
	label.text = "REABLOX v0.6\nSedang dibangun ulang — menu belum tersedia."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	add_child(label)
