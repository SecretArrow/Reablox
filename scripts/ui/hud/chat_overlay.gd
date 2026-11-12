class_name ChatOverlay
extends Control
## ChatOverlay — chat teks ala Roblox: log pesan (maks 8 terlihat, pesan lama
## dihapus), input LineEdit tersembunyi, dan tombol chat kecil. Pesan masuk
## otomatis lewat GameEvents.chat_message_received.

signal chat_toggled
signal chat_submitted(text: String)

const MAX_VISIBLE_MESSAGES := 8

var _messages_box: VBoxContainer
var _chat_input: LineEdit
var _chat_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_messages()
	_build_input()
	_build_button()
	GameEvents.chat_message_received.connect(_on_chat_message_received)


## Log pesan kiri-bawah: anak Label menempel ke dasar kotak (alignment END)
## sehingga pesan baru "naik" seperti chat Roblox.
func _build_messages() -> void:
	_messages_box = VBoxContainer.new()
	_messages_box.name = "Messages"
	_messages_box.alignment = BoxContainer.ALIGNMENT_END
	_messages_box.anchor_left = 0.0
	_messages_box.anchor_top = 1.0
	_messages_box.anchor_right = 0.0
	_messages_box.anchor_bottom = 1.0
	_messages_box.offset_left = 12
	_messages_box.offset_right = 332
	_messages_box.offset_top = -248
	_messages_box.offset_bottom = -68
	_messages_box.add_theme_constant_override("separation", 2)
	_messages_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_messages_box)


## Input chat tersembunyi tepat di bawah area log.
func _build_input() -> void:
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = "Ketik pesan..."
	_chat_input.anchor_left = 0.0
	_chat_input.anchor_top = 1.0
	_chat_input.anchor_right = 0.0
	_chat_input.anchor_bottom = 1.0
	_chat_input.offset_left = 12
	_chat_input.offset_right = 332
	_chat_input.offset_top = -64
	_chat_input.offset_bottom = -32
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_input_submitted)
	add_child(_chat_input)


## Tombol chat kecil di pojok kiri-bawah.
func _build_button() -> void:
	_chat_button = Button.new()
	_chat_button.name = "ChatButton"
	_chat_button.text = "Chat"
	_chat_button.anchor_left = 0.0
	_chat_button.anchor_top = 1.0
	_chat_button.anchor_right = 0.0
	_chat_button.anchor_bottom = 1.0
	_chat_button.offset_left = 12
	_chat_button.offset_right = 76
	_chat_button.offset_top = -28
	_chat_button.offset_bottom = -6
	_chat_button.pressed.connect(_on_chat_button_pressed)
	add_child(_chat_button)


## Tambah baris "[sender] text"; pesan lama dihapus bila melebihi 8.
func add_message(sender: String, text: String) -> void:
	var line := Label.new()
	line.name = "Msg%d" % get_message_count()
	line.text = "[%s] %s" % [sender, text]
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages_box.add_child(line)
	_trim_messages()


func _trim_messages() -> void:
	while _messages_box.get_child_count() > MAX_VISIBLE_MESSAGES:
		var oldest: Node = _messages_box.get_child(0)
		_messages_box.remove_child(oldest)
		oldest.queue_free()


## Tampilkan input + fokus bila tersembunyi; sembunyikan bila sudah tampil.
func toggle() -> void:
	if _chat_input.visible:
		_hide_input()
	else:
		_show_input()


func _show_input() -> void:
	_chat_input.visible = true
	_chat_input.grab_focus()


func _hide_input() -> void:
	_chat_input.visible = false
	_chat_input.release_focus()


## Enter pada input: emit sinyal, kosongkan teks, sembunyikan lagi.
func _on_input_submitted(text: String) -> void:
	chat_submitted.emit(text)
	_chat_input.text = ""
	_hide_input()


func is_input_visible() -> bool:
	return _chat_input.visible


func get_message_count() -> int:
	return _messages_box.get_child_count()


func _on_chat_button_pressed() -> void:
	chat_toggled.emit()
	toggle()


func _on_chat_message_received(sender: String, text: String) -> void:
	add_message(sender, text)
