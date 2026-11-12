extends Node
## Suite unit modul UI — UiTheme, ScreenStack, MainMenu, SettingsScreen,
## dan AvatarEditorScreen. Deterministik, tidak bergantung suite lain.

const FW := preload("res://tools/tests/test_framework.gd")
const UiThemeLib := preload("res://scripts/ui/kit/ui_theme.gd")
const ScreenStackLib := preload("res://scripts/ui/kit/screen_stack.gd")
const MainMenuLib := preload("res://scripts/ui/menu/main_menu.gd")
const SettingsScreenLib := preload("res://scripts/ui/menu/settings_screen.gd")
const AvatarEditorScreenLib := preload("res://scripts/ui/menu/avatar_editor_screen.gd")
const AvatarConfigLib := preload("res://scripts/avatar/avatar_config.gd")

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var fw: Node
var _closed_count := 0
var _saved_count := 0
var _last_saved: Dictionary = {}


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	# Paksa locale id agar pencarian teks tombol deterministik.
	Locale.set_locale("id")
	_test_ui_theme()
	_test_screen_stack()
	await _test_layout_anchors()
	_test_main_menu()
	_test_settings_screen()
	_test_avatar_editor()


# --- UiTheme ------------------------------------------------------------------------


func _test_ui_theme() -> void:
	fw.section("UiTheme")
	fw.check_eq("konstanta BG", UiThemeLib.BG, Color("232527"))
	fw.check_eq("konstanta ACCENT", UiThemeLib.ACCENT, Color("00a2ff"))
	fw.check_eq("konstanta RADIUS 8", UiThemeLib.RADIUS, 8)
	fw.check_eq("konstanta FONT_SIZE_TITLE 28", UiThemeLib.FONT_SIZE_TITLE, 28)
	var panel := UiThemeLib.make_panel()
	fw.check("make_panel -> PanelContainer", panel is PanelContainer)
	panel.free()
	var btn := UiThemeLib.make_button("Uji")
	fw.check("make_button -> Button", btn is Button)
	fw.check_eq("teks tombol", btn.text, "Uji")
	fw.check_eq("min size tombol 160x48", btn.custom_minimum_size, Vector2(160, 48))
	btn.free()
	var label := UiThemeLib.make_label("Halo", 20, true)
	fw.check("make_label -> Label", label is Label)
	fw.check_eq("teks label", label.text, "Halo")
	label.free()
	var title := UiThemeLib.make_title("Judul")
	fw.check("make_title -> Label", title is Label)
	fw.check_eq("ukuran font judul 28", title.get_theme_font_size("font_size"), 28)
	title.free()
	var slider := UiThemeLib.make_slider(0.0, 2.0, 1.0)
	fw.check("make_slider -> HSlider", slider is HSlider)
	fw.check_eq("nilai slider awal", slider.value, 1.0)
	slider.free()
	var check := UiThemeLib.make_check("Cek", true)
	fw.check("make_check -> CheckBox tercentang", check is CheckBox and check.button_pressed)
	check.free()
	var edit := UiThemeLib.make_line_edit("Nama", "Ketik nama")
	fw.check("make_line_edit -> LineEdit", edit is LineEdit)
	fw.check_eq("placeholder LineEdit", edit.placeholder_text, "Ketik nama")
	edit.free()


# --- ScreenStack ----------------------------------------------------------------------


func _test_screen_stack() -> void:
	fw.section("ScreenStack")
	var stack := ScreenStackLib.new()
	add_child(stack)
	var a := ColorRect.new()
	var b := ColorRect.new()
	var c := ColorRect.new()
	stack.push(a)
	stack.push(b)
	stack.push(c)
	fw.check_eq("push 3 layar -> depth 3", stack.depth(), 3)
	fw.check_eq("current = layar teratas", stack.current(), c)
	fw.check("hanya layar aktif terlihat", c.visible and not b.visible and not a.visible)
	var popped := stack.pop()
	fw.check_eq("pop -> depth 2", stack.depth(), 2)
	fw.check("layar sebelumnya tampil kembali", b.visible)
	fw.check_eq("pop mengembalikan layar teratas", popped, c)
	fw.check_eq("current kini layar kedua", stack.current(), b)
	var d := ColorRect.new()
	stack.replace(d)
	fw.check_eq("replace -> depth 1", stack.depth(), 1)
	fw.check_eq("current = layar pengganti", stack.current(), d)
	stack.clear()
	fw.check_eq("clear -> depth 0", stack.depth(), 0)
	fw.check("clear -> current null", stack.current() == null)
	stack.free()


# --- MainMenu --------------------------------------------------------------------------


func _test_main_menu() -> void:
	fw.section("MainMenu")
	var menu := _make_menu()
	if menu == null:
		fw.check("scene menu termuat & valid", false)
		return
	fw.check_not_null("stack internal siap", menu._stack)
	fw.check_eq("beranda = depth 1", menu._stack.depth(), 1)
	menu.open_world_list()
	var world_screen := menu._stack.current()
	fw.check_not_null("layar pilih dunia aktif", world_screen)
	fw.check("layar dunia punya tombol >= 2", _count_buttons(world_screen) >= 2)
	fw.check_not_null("tombol Pulau Obby ada", _find_button(world_screen, "Pulau Obby"))
	fw.check_not_null("tombol Plaza Kreatif ada", _find_button(world_screen, "Plaza Kreatif"))
	menu.open_settings()
	fw.check("open_settings -> SettingsScreen", menu._stack.current() is SettingsScreenLib)
	menu.open_avatar()
	fw.check("open_avatar -> AvatarEditorScreen", menu._stack.current() is AvatarEditorScreenLib)
	fw.check_eq("depth tumpukan menu 4", menu._stack.depth(), 4)
	_press_back(menu._stack.current())
	fw.check("kembali dari avatar -> pengaturan", menu._stack.current() is SettingsScreenLib)
	_press_back(menu._stack.current())
	var obby := _find_button(menu._stack.current(), "Pulau Obby")
	fw.check_not_null("kembali ke layar dunia", obby)
	if obby != null:
		var tree := get_tree()
		obby.emit_signal("pressed")
		# _start_world memanggil change_scene yang melepas scene test dari
		# tree; pasang kembali agar sisa suite tetap berjalan dan bisa quit.
		if not is_inside_tree():
			tree.root.add_child(self)
	fw.check_eq("dunia terpilih", menu.get_selected_world(), "Pulau Obby")
	fw.check_eq("GameState.current_world ter-reset", GameState.current_world, "Pulau Obby")
	fw.check("scene game tersedia (tanpa navigasi)", ResourceLoader.exists(SceneLoader.GAME_SCENE))
	menu.queue_free()


# --- SettingsScreen ----------------------------------------------------------------------


func _test_settings_screen() -> void:
	fw.section("SettingsScreen")
	var prev_name := Settings.get_player_name()
	var screen := SettingsScreenLib.new()
	add_child(screen)
	fw.check_not_null("layar pengaturan valid", screen)
	Settings.set_quality(2)
	screen.sync_from_settings()
	fw.check_eq("slider kualitas mengikuti Settings", screen._quality_slider.value, 2.0)
	screen._quality_slider.value = 1.0
	fw.check_eq("Settings.get_quality mengikuti slider", Settings.get_quality(), 1)
	var en := _find_button(screen, "EN")
	fw.check_not_null("tombol EN ada", en)
	if en != null:
		en.emit_signal("pressed")
	fw.check_eq("locale berubah ke en", Locale.get_locale(), "en")
	Locale.set_locale("id")
	fw.check_eq("locale dikembalikan ke id", Locale.get_locale(), "id")
	_closed_count = 0
	screen.closed.connect(_on_screen_closed)
	screen._name_edit.text = "UjiUi"
	_press_back(screen)
	fw.check_eq("sinyal closed ter-emit saat kembali", _closed_count, 1)
	fw.check_eq("nama pemain disimpan saat kembali", Settings.get_player_name(), "UjiUi")
	Settings.set_player_name(prev_name)
	screen.queue_free()


# --- AvatarEditorScreen --------------------------------------------------------------------


func _test_avatar_editor() -> void:
	fw.section("AvatarEditorScreen")
	var editor := AvatarEditorScreenLib.new()
	add_child(editor)
	fw.check_not_null("layar editor avatar valid", editor)
	fw.check_not_null("rig preview valid", editor._rig)
	var cfg := editor.get_config()
	fw.check("config awal valid", AvatarConfigLib.validate(cfg).is_empty())
	fw.check_eq("config awal = default", cfg, AvatarConfigLib.default_config())
	var lain := AvatarConfigLib.default_config()
	lain["colors"]["torso"] = "Bright red"
	lain["colors"]["head"] = "Cyan"
	editor.set_config(lain)
	fw.check_eq("set_config tersimpan", editor.get_config(), lain)
	editor.randomize()
	var acak := editor.get_config()
	fw.check("config acak tetap valid", AvatarConfigLib.validate(acak).is_empty())
	fw.check_ne("warna acak berbeda dari input", acak, lain)
	_saved_count = 0
	editor.saved.connect(_on_editor_saved)
	var simpan := _find_button(editor, Locale.tr_key("avatar_save", "Simpan"))
	fw.check_not_null("tombol simpan ada", simpan)
	if simpan != null:
		simpan.emit_signal("pressed")
	fw.check_eq("sinyal saved ter-emit", _saved_count, 1)
	fw.check_eq("payload saved = config terkini", _last_saved, editor.get_config())
	editor.queue_free()


# --- LayoutAnchors (regresi) --------------------------------------------------------


func _test_layout_anchors() -> void:
	fw.section("LayoutAnchors")
	await get_tree().process_frame
	var ref := Control.new()
	ref.name = "RefFullRect"
	ref.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(ref)
	await get_tree().process_frame
	await get_tree().process_frame
	var target: Vector2 = ref.size
	fw.check_gt("kalibrasi referensi lebar > 0", target.x, 0.0)
	fw.check_gt("kalibrasi referensi tinggi > 0", target.y, 0.0)
	var packed := load(MENU_SCENE) as PackedScene
	var menu: Control = null
	if packed != null:
		menu = packed.instantiate() as Control
	await _settled_check("MainMenu memenuhi rect root", menu, target)
	await _settled_check("SettingsScreen memenuhi rect root", SettingsScreenLib.new(), target)
	await _settled_check("Hud memenuhi rect root", Hud.new(), target)
	await _settled_check("ChatOverlay memenuhi rect root", ChatOverlay.new(), target)
	await _settled_check("EscapeMenu memenuhi rect root", EscapeMenu.new(), target)
	await _settled_check("TouchControls memenuhi rect root", TouchControls.new(), target)
	var editor := AvatarEditorScreenLib.new()
	await _settled_check("AvatarEditorScreen memenuhi rect root", editor, target)
	var stack := ScreenStackLib.new()
	stack.name = "RefStack"
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(stack)
	var pushed := Control.new()
	stack.push(pushed)
	await get_tree().process_frame
	await get_tree().process_frame
	fw.check_eq("layar ScreenStack.push memenuhi stack", pushed.size, stack.size)
	stack.queue_free()
	ref.queue_free()


## Tambahkan control ke root, tunggu layout settle, bandingkan ukurannya.
func _settled_check(desc: String, control: Control, target: Vector2) -> void:
	if control == null:
		fw.check(desc, false)
		return
	get_tree().root.add_child(control)
	await get_tree().process_frame
	await get_tree().process_frame
	fw.check_eq(desc, control.size, target)
	control.queue_free()


# --- Helper ----------------------------------------------------------------------------------


func _make_menu() -> MainMenuLib:
	var packed := load(MENU_SCENE) as PackedScene
	if packed == null:
		push_error("Scene menu tidak termuat: %s" % MENU_SCENE)
		return null
	var menu := packed.instantiate() as MainMenuLib
	if menu == null:
		return null
	add_child(menu)
	return menu


func _find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for child in root.find_children("*", "Button", true, false):
		var btn := child as Button
		if btn != null and btn.text == text:
			return btn
	return null


func _count_buttons(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	for child in root.find_children("*", "Button", true, false):
		if child is Button:
			count += 1
	return count


func _press_back(screen: Node) -> void:
	var back := _find_button(screen, Locale.tr_key("menu_back", "Kembali"))
	if back != null:
		back.emit_signal("pressed")


func _on_screen_closed() -> void:
	_closed_count += 1


func _on_editor_saved(config: Dictionary) -> void:
	_saved_count += 1
	_last_saved = config
