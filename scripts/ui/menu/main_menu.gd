class_name MainMenu
extends Control
## Layar utama ala aplikasi Roblox: beranda + sublayar (pilih dunia,
## pengaturan, editor avatar) yang dinavigasi lewat ScreenStack internal.

const UiThemeLib := preload("res://scripts/ui/kit/ui_theme.gd")
const ScreenStackLib := preload("res://scripts/ui/kit/screen_stack.gd")
const SettingsScreenLib := preload("res://scripts/ui/menu/settings_screen.gd")
const AvatarEditorScreenLib := preload("res://scripts/ui/menu/avatar_editor_screen.gd")

const DEMO_WORLDS := ["Pulau Obby", "Plaza Kreatif"]
const ABOUT_MESSAGE := "Reablox — sandbox gratis 100%"

var selected_world := ""
var _stack: ScreenStackLib
var _player_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_stack = ScreenStackLib.new()
	_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stack)
	_stack.push(_build_home())


## Dunia yang terakhir dipilih lewat layar pilih dunia (kosong bila belum ada).
func get_selected_world() -> String:
	return selected_world


## Buka sublayar daftar dunia (dunia demo + dunia tersimpan).
func open_world_list() -> void:
	if _stack == null:
		return
	_stack.push(_build_world_screen())


## Buka sublayar pengaturan; sinyal closed mempop tumpukan.
func open_settings() -> void:
	if _stack == null:
		return
	var screen := SettingsScreenLib.new()
	screen.closed.connect(_on_subscreen_closed)
	_stack.push(screen)


## Buka sublayar editor avatar; sinyal closed mempop tumpukan.
func open_avatar() -> void:
	if _stack == null:
		return
	var screen := AvatarEditorScreenLib.new()
	screen.closed.connect(_on_subscreen_closed)
	_stack.push(screen)


# --- Pembangunan UI ---------------------------------------------------------------


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = UiThemeLib.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_home() -> Control:
	var screen := _new_subscreen()
	var box := _subscreen_box(screen)
	_add_centered(box, UiThemeLib.make_title("REABLOX"))
	_player_label = UiThemeLib.make_label(Settings.get_player_name(), UiThemeLib.FONT_SIZE, true)
	_add_centered(box, _player_label)
	_add_home_button(box, "menu_play", "Main", true, _on_play_pressed)
	_add_home_button(box, "menu_avatar", "Avatar", false, _on_avatar_pressed)
	_add_home_button(box, "menu_settings", "Pengaturan", false, _on_settings_pressed)
	_add_home_button(box, "menu_about", "Tentang", false, _on_about_pressed)
	return screen


func _add_home_button(
	box: VBoxContainer, key: String, fallback: String, accent: bool, handler: Callable
) -> void:
	var btn := UiThemeLib.make_button(Locale.tr_key(key, fallback), accent)
	btn.pressed.connect(handler)
	_add_centered(box, btn)


func _build_world_screen() -> Control:
	var screen := _new_subscreen()
	var box := _subscreen_box(screen)
	_add_centered(box, UiThemeLib.make_title(Locale.tr_key("menu_world_list_title", "Pilih Dunia")))
	for world_name in DEMO_WORLDS:
		var world_btn := UiThemeLib.make_button(world_name)
		world_btn.pressed.connect(_on_world_pressed.bind(world_name))
		_add_centered(box, world_btn)
	var saved := UiThemeLib.make_button(Locale.tr_key("menu_saved_worlds", "Dunia Tersimpan"))
	saved.pressed.connect(_on_saved_worlds_pressed)
	_add_centered(box, saved)
	_add_back_button(box)
	return screen


func _build_saved_screen() -> Control:
	var screen := _new_subscreen()
	var box := _subscreen_box(screen)
	_add_centered(box, UiThemeLib.make_title(Locale.tr_key("menu_saved_worlds", "Dunia Tersimpan")))
	var worlds := Saves.list_worlds()
	if worlds.is_empty():
		_add_centered(
			box,
			UiThemeLib.make_label(
				Locale.tr_key("menu_no_saves", "Belum ada dunia tersimpan."),
				UiThemeLib.FONT_SIZE,
				true
			)
		)
	for entry in worlds:
		var world_name := String(entry.get("name", ""))
		if world_name.is_empty():
			continue
		var world_btn := UiThemeLib.make_button(world_name)
		world_btn.pressed.connect(_on_world_pressed.bind(world_name))
		_add_centered(box, world_btn)
	_add_back_button(box)
	return screen


## Kerangka sublayar: panel gelap dengan margin + kolom isi terpusat.
func _new_subscreen() -> Control:
	var screen := Control.new()
	var panel := UiThemeLib.make_panel()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 96
	panel.offset_right = -96
	panel.offset_top = 48
	panel.offset_bottom = -48
	screen.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return screen


## Kolom isi sublayar; dibuat ulang bila struktur tidak ditemukan (defensif).
func _subscreen_box(screen: Control) -> VBoxContainer:
	var box := screen.get_node_or_null("Panel/Box") as VBoxContainer
	if box != null:
		return box
	var fallback := VBoxContainer.new()
	fallback.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(fallback)
	return fallback


func _add_centered(box: VBoxContainer, node: Control) -> void:
	if box == null or node == null:
		return
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(node)


func _add_back_button(box: VBoxContainer) -> void:
	var back := UiThemeLib.make_button(Locale.tr_key("menu_back", "Kembali"))
	back.pressed.connect(_on_back_pressed)
	_add_centered(box, back)


# --- Aksi tombol -------------------------------------------------------------------


func _on_play_pressed() -> void:
	open_world_list()


func _on_avatar_pressed() -> void:
	open_avatar()


func _on_settings_pressed() -> void:
	open_settings()


func _on_about_pressed() -> void:
	GameEvents.toast_requested.emit(Locale.tr_key("toast_about", ABOUT_MESSAGE))


func _on_world_pressed(world_name: String) -> void:
	_start_world(world_name)


func _on_saved_worlds_pressed() -> void:
	if _stack != null:
		_stack.push(_build_saved_screen())


func _on_back_pressed() -> void:
	if _stack != null:
		_stack.pop()


func _on_subscreen_closed() -> void:
	if _stack != null:
		_stack.pop()


## Mulai dunia: catat pilihan, reset run, lalu pindah ke scene game.
func _start_world(world_name: String) -> void:
	selected_world = world_name
	GameState.reset_run(world_name)
	SceneLoader.goto_game()
