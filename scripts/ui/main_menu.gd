extends Control
## MainMenu — layar utama Reablox (v0.4 modern pass, ala platform game modern):
## top bar (logo + chip pemain), hero judul besar, CTA hijau "Main" + Lanjutkan,
## baris shortcut kartu game populer dengan thumbnail prosedural, tombol
## sekunder glass, chip versi, toast achievement, panel pengaturan overlay.

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const ThumbArt := preload("res://scripts/ui/thumbnail_art.gd")

const SCENE_WORLD_SELECT := "res://scenes/world_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_AVATAR := "res://scenes/avatar_editor.tscn"
const SCENE_LOBBY := "res://scenes/lobby.tscn"
const SETTINGS_SCRIPT := "res://scripts/ui/settings_menu.gd"

## Shortcut game populer: [template_id, label_key] (klik = langsung main).
const SHORTCUTS := [
	["obby", "tpl_obby"],
	["racing", "tpl_racing"],
	["tycoon", "tpl_tycoon"],
	["adventure", "tpl_adventure"],
	["survival", "tpl_survival"],
	["city", "tpl_city"],
]

var _bg_root: Control
var _ui_root: Control
var _toast_layer: Control


func _ready() -> void:
	theme = Settings.get_theme()
	_bg_root = Control.new()
	_bg_root.name = "BgRoot"
	_bg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_root)
	_build_background()
	_ui_root = Control.new()
	_ui_root.name = "UiRoot"
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)
	_toast_layer = UiKit.make_toast_layer()
	add_child(_toast_layer)
	_build_ui()
	_apply_audio_settings()
	Settings.theme_changed.connect(_on_theme_changed)
	Locale.language_changed.connect(_on_language_changed)
	GameState.achievement_unlocked.connect(_on_achievement)


func _build_background() -> void:
	for c in _bg_root.get_children():
		c.queue_free()
	# Gradien kaya diagonal ala hero platform modern.
	if Settings.is_dark_mode():
		_bg_root.add_child(UiKit.make_rich_gradient(["#1b2a52", "#16203c", "#0d1322", "#0a0e19"]))
	else:
		_bg_root.add_child(UiKit.make_rich_gradient(["#dbe9ff", "#c6dcff", "#eef4ff", "#ffffff"]))
	_bg_root.add_child(UiKit.make_decor_blocks())


func _build_ui() -> void:
	for c in _ui_root.get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_ui_root.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_hero())
	root.add_child(_build_cta_row())
	root.add_child(_build_shortcuts())
	root.add_child(_build_secondary_row())
	root.add_child(UiKit.make_spacer(2.0))

	# Chip versi kanan-bawah.
	var ver := str(ProjectSettings.get_setting("application/config/version", "0.4.0"))
	var chip := UiKit.make_chip("Reablox v" + ver, Color(0, 0, 0, 0.42))
	chip.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14
	)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui_root.add_child(chip)


## Top bar ala aplikasi modern: logo kiri + chip profil pemain kanan.
func _build_top_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var logo := UiKit.make_badge("REABLOX", UiKit.COL_ACCENT)
	logo.custom_minimum_size = Vector2(120, 34)
	hb.add_child(logo)
	hb.add_child(UiKit.make_badge("100% GRATIS", UiKit.COL_PLAY))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spring)
	hb.add_child(_make_player_chip())
	return hb


## Chip pemain: kotak avatar mini (warna tubuh avatar) + nama.
func _make_player_chip() -> PanelContainer:
	var pc := UiKit.make_glass_panel(0.62, 22)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	var avatar: Dictionary = GameState.avatar_config
	var skin := String(avatar.get("skin", "#e0b088"))
	var head_col := Color(skin if skin.begins_with("#") else "#e0b088")
	# Kepala avatar membulat (StyleBox) — warna tubuh avatar pemain.
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = head_col
	hsb.set_corner_radius_all(8)
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", hsb)
	hp.custom_minimum_size = Vector2(26, 26)
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(hp)
	var nm := UiKit.make_label(GameState.player_name, 17)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(nm)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


## Hero: judul besar + tagline.
func _build_hero() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.make_title(Locale.t("app_name"))
	vb.add_child(title)
	var tagline := UiKit.make_label(Locale.t("tagline"), 19)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	tagline.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	tagline.add_theme_constant_override("shadow_offset_y", 2)
	vb.add_child(tagline)
	return vb


## Baris CTA: tombol hijau besar "Main" (+ "Lanjutkan" bila ada save).
func _build_cta_row() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	if not Saves.list_worlds().is_empty():
		var cont := UiKit.make_button_color(
			Locale.t("menu_continue"), UiKit.COL_ACCENT, Vector2(260, 66)
		)
		cont.pressed.connect(_continue_last)
		hb.add_child(cont)
	var play := UiKit.make_button_color(Locale.t("menu_play"), UiKit.COL_PLAY, Vector2(340, 66))
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(_goto_world_select)
	hb.add_child(play)
	return hb


## Baris shortcut kartu game populer (thumbnail + label, klik langsung main).
func _build_shortcuts() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var header := UiKit.make_section_header("POPULER", UiKit.COL_GOLD)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for sc in SHORTCUTS:
		row.add_child(_make_shortcut_card(String(sc[0]), String(sc[1])))
	return vb


## Kartu shortcut: thumbnail art di atas + nama mode; klik = langsung main.
func _make_shortcut_card(world_id: String, label_key: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 128)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.set_corner_radius_all(UiKit.CORNER)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(1, 1, 1, 0.13)
	sbh.border_color = Color(1, 1, 1, 0.26)
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(1, 1, 1, 0.04)
	sbp.border_color = Color(1, 1, 1, 0.10)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_play_shortcut.bind(world_id))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	var tex := TextureRect.new()
	tex.texture = ThumbArt.get_icon(world_id)
	tex.custom_minimum_size = Vector2(136, 78)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size_flags_horizontal = Control.SIZE_FILL
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tex)
	var nm := UiKit.make_label(Locale.t(label_key), 15)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	UiKit.attach_press_animation(btn)
	return btn


## Baris tombol sekunder (glass): Buat, Avatar, Multiplayer, Pengaturan, Keluar.
func _build_secondary_row() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_secondary(Locale.t("menu_create"), _start_build_mode))
	hb.add_child(_secondary(Locale.t("menu_avatar"), _goto_avatar))
	hb.add_child(_secondary(Locale.t("menu_multiplayer"), _goto_lobby))
	hb.add_child(_secondary(Locale.t("menu_settings"), _open_settings))
	hb.add_child(_secondary(Locale.t("menu_quit"), _quit_app, UiKit.COL_DANGER))
	return hb


func _secondary(text: String, action: Callable, tint := Color(1, 1, 1, 0.10)) -> Button:
	var b := UiKit.make_button_secondary(text, Vector2(178, 54))
	if tint != Color(1, 1, 1, 0.10):
		b = UiKit.make_button_color(text, tint, Vector2(178, 54))
	b.pressed.connect(action)
	return b


func _play_shortcut(world_id: String) -> void:
	GameState.pending_action = {"mode": "play", "world_id": world_id}
	if ResourceLoader.exists(SCENE_GAME):
		GameState.goto_scene(SCENE_GAME)
	else:
		_show_fallback_toast()


func _goto_world_select() -> void:
	if ResourceLoader.exists(SCENE_WORLD_SELECT):
		GameState.goto_scene(SCENE_WORLD_SELECT)
	else:
		_show_fallback_toast()


## Lanjutkan: muat save terbaru (dunia + state sesi) langsung ke gameplay.
func _continue_last() -> void:
	var saves := Saves.list_worlds()
	if saves.is_empty():
		return
	var latest: Dictionary = saves[0]  # list_worlds() sudah urut terbaru dulu
	GameState.pending_action = {"mode": "play", "world_path": String(latest.get("path", ""))}
	GameState.goto_scene(SCENE_GAME)


func _start_build_mode() -> void:
	GameState.pending_action = {"mode": "build", "world_id": "empty"}
	if ResourceLoader.exists(SCENE_GAME):
		GameState.goto_scene(SCENE_GAME)
	else:
		_show_fallback_toast()


func _goto_avatar() -> void:
	if ResourceLoader.exists(SCENE_AVATAR):
		GameState.goto_scene(SCENE_AVATAR)
	else:
		_show_fallback_toast()


func _goto_lobby() -> void:
	if ResourceLoader.exists(SCENE_LOBBY):
		GameState.goto_scene(SCENE_LOBBY)
	else:
		_show_fallback_toast()


func _open_settings() -> void:
	for c in get_children():
		if c.has_meta("settings_overlay"):
			return
	if not ResourceLoader.exists(SETTINGS_SCRIPT):
		_show_fallback_toast()
		return
	var script: Variant = load(SETTINGS_SCRIPT)
	if script == null:
		_show_fallback_toast()
		return
	var panel: Control = script.new()
	panel.set_meta("settings_overlay", true)
	panel.call("open", self)


func _quit_app() -> void:
	get_tree().quit()


func _show_fallback_toast() -> void:
	UiKit.show_toast(_toast_layer, Locale.t("error_not_impl"))


func _on_theme_changed() -> void:
	theme = Settings.get_theme()
	_build_background()


func _on_language_changed() -> void:
	_build_ui()


func _on_achievement(id: String, _title: String) -> void:
	# Kunci dinamis per achievement; contoh EN: "ach_first_build": "First Block!"
	UiKit.show_toast(_toast_layer, Locale.t("ach_" + id))


func _apply_audio_settings() -> void:
	_apply_bus("Master", float(Settings.get_value("master_volume", 0.8)))
	_apply_bus("Music", float(Settings.get_value("music_volume", 0.7)))
	_apply_bus("SFX", float(Settings.get_value("sfx_volume", 0.9)))


func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	if linear > 0.001:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
