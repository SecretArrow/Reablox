class_name EscapeMenu
extends Control
## EscapeMenu — menu jeda ala Roblox (tombol Esc): panel tengah berisi judul
## "Jeda" dan 4 tombol aksi. Tersembunyi secara default; dibangun via kode.
## Aksi hanya diteruskan lewat sinyal — pemanggil yang menentukan efeknya.

signal resume_requested
signal settings_requested
signal respawn_requested
signal leave_requested

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()
	visible = false


## Panel tengah: judul + tombol Lanjut, Pengaturan, Karakter Ulang, Keluar.
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(260.0, 240.0)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.name = "MenuBox"
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "Jeda"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_add_button(box, "Lanjut", _on_resume_pressed)
	_add_button(box, "Pengaturan", _on_settings_pressed)
	_add_button(box, "Karakter Ulang", _on_respawn_pressed)
	_add_button(box, "Keluar Dunia", _on_leave_pressed)


func _add_button(parent: Node, label: String, handler: Callable) -> void:
	var btn := Button.new()
	btn.name = "Btn%s" % label.replace(" ", "")
	btn.text = label
	btn.pressed.connect(handler)
	parent.add_child(btn)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func is_open() -> bool:
	return visible


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_respawn_pressed() -> void:
	respawn_requested.emit()


func _on_leave_pressed() -> void:
	leave_requested.emit()
