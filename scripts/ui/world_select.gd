extends Control
## World Select — discovery ala platform game modern: kartu template dengan
## thumbnail art prosedural + nama + deskripsi, tab Template & Dunia Saya,
## impor dunia (.myworld) via FileDialog / folder user://imports.

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const ThumbArt := preload("res://scripts/ui/thumbnail_art.gd")

const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const TEMPLATES_PATH := "res://scripts/world/templates.gd"

var _tpl: GDScript = null
var _list_box: VBoxContainer = null
var _import_box: VBoxContainer = null
var _confirm: ConfirmationDialog = null
var _file_dialog: FileDialog = null
var _pending_delete := ""


func _ready() -> void:
	theme = Settings.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(TEMPLATES_PATH):
		var r: Variant = load(TEMPLATES_PATH)
		if r is GDScript:
			_tpl = r
	_build_ui()
	_refresh_worlds()


# ------------------------------------------------------------------ UI dasar


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	# Header: tombol kembali glass + judul besar.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	root.add_child(head)
	var back := UiKit.make_button_secondary(Locale.t("common_back"), Vector2(130, 52))
	back.pressed.connect(_go_back)
	head.add_child(back)
	var title := UiKit.make_label(Locale.t("ws_title"), 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	# Tab: Template & Dunia Saya.
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_make_templates_tab())
	tabs.add_child(_make_worlds_tab())


func _make_templates_tab() -> Control:
	var tab := ScrollContainer.new()
	tab.name = Locale.t("ws_templates")
	tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(grid)
	if _tpl == null:
		grid.add_child(_make_info_label(Locale.t("error_generic")))
		return tab
	var catalog: Array = _tpl.call("catalog")
	if catalog.is_empty():
		grid.add_child(_make_info_label(Locale.t("error_generic")))
		return tab
	for entry in catalog:
		if entry is Dictionary:
			grid.add_child(_make_template_card(entry))
	return tab


## Kartu game modern: thumbnail art di atas + nama tebal + deskripsi + badge.
func _make_template_card(entry: Dictionary) -> Control:
	var id := String(entry.get("id", "empty"))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 258)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(UiKit.CORNER)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.shadow_color = Color(0, 0, 0, 0.32)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 10.0
	btn.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(1, 1, 1, 0.12)
	sbh.border_color = Color(1, 1, 1, 0.30)
	sbh.shadow_size = 16
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(1, 1, 1, 0.03)
	sbp.border_color = Color(1, 1, 1, 0.08)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_play_template.bind(id))
	UiKit.attach_press_animation(btn)

	# Isi kartu: thumbnail + overlay badge + nama + deskripsi.
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var tex_holder := Control.new()
	tex_holder.custom_minimum_size = Vector2(284, 160)
	tex_holder.clip_contents = true
	tex_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tex_holder)
	var tex := TextureRect.new()
	tex.texture = ThumbArt.get_icon(id)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_holder.add_child(tex)
	# Sudut thumbnail mengikuti radius kartu (border tipis di atas thumbnail).
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.set_corner_radius_all(14)
	fsb.set_border_width_all(1)
	fsb.border_color = Color(1, 1, 1, 0.16)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_holder.add_child(frame)

	var nm := UiKit.make_label(Locale.t(String(entry.get("name_key", id))), 21)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	nm.add_theme_constant_override("shadow_offset_y", 1)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var desc := UiKit.make_label(Locale.t(String(entry.get("desc_key", id))), 13)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.custom_minimum_size = Vector2(284, 0)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc)
	return btn


func _make_worlds_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = Locale.t("ws_my_worlds")
	tab.add_theme_constant_override("separation", 10)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_list_box)
	# Baris impor: tombol glass + keterangan.
	var imp_row := HBoxContainer.new()
	imp_row.add_theme_constant_override("separation", 12)
	tab.add_child(imp_row)
	var imp_btn := UiKit.make_button(Locale.t("ws_import"), Vector2(170, 52))
	imp_btn.pressed.connect(_open_import_dialog)
	imp_row.add_child(imp_btn)
	var hint := UiKit.make_label(Locale.t("ws_import_hint"), 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	imp_row.add_child(hint)
	# Daftar file di user://imports (fallback impor).
	_import_box = VBoxContainer.new()
	_import_box.add_theme_constant_override("separation", 8)
	tab.add_child(_import_box)
	return tab


# ------------------------------------------------------------------ dunia saya


func _refresh_worlds() -> void:
	_clear_children(_list_box)
	_clear_children(_import_box)
	var worlds: Array = Saves.list_worlds()
	if worlds.is_empty():
		_list_box.add_child(_make_info_label(Locale.t("ws_empty")))
	for w in worlds:
		if w is Dictionary:
			_list_box.add_child(_make_world_row(w))
	# Fallback impor: daftar berkas di user://imports.
	var files := DirAccess.get_files_at(Saves.IMPORTS_DIR)
	for f in files:
		var fname := String(f)
		if not fname.ends_with(Saves.EXT):
			continue
		_import_box.add_child(_make_import_row(fname))


## Baris dunia tersimpan: kartu glass + thumbnail kecil + tombol aksi.
func _make_world_row(w: Dictionary) -> Control:
	var card := UiKit.make_card(Color(1, 1, 1, 0.05))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var thumb := TextureRect.new()
	thumb.texture = ThumbArt.get_icon("world")
	thumb.custom_minimum_size = Vector2(96, 56)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_SCALE
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(thumb)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var nm := UiKit.make_label(String(w.get("name", "?")), 19)
	nm.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(nm)
	var dt := UiKit.make_label(_fmt_time(int(w.get("modified", 0))), 12)
	dt.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	info.add_child(dt)
	hb.add_child(info)
	var play := UiKit.make_button_color(Locale.t("common_play"), UiKit.COL_PLAY, Vector2(118, 52))
	play.pressed.connect(_play_world.bind(String(w.get("path", ""))))
	hb.add_child(play)
	var del := UiKit.make_button_color(
		Locale.t("common_delete"), UiKit.COL_DANGER, Vector2(118, 52)
	)
	del.pressed.connect(_ask_delete.bind(String(w.get("path", ""))))
	hb.add_child(del)
	return card


func _make_import_row(fname: String) -> Control:
	var panel := UiKit.make_card(Color(1, 1, 1, 0.04))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)
	var nm := UiKit.make_label(fname.trim_suffix(Saves.EXT), 15)
	nm.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var play := UiKit.make_button_secondary(Locale.t("common_play"), Vector2(110, 46))
	play.pressed.connect(_play_import.bind(Saves.IMPORTS_DIR + "/" + fname))
	hb.add_child(play)
	return panel


func _fmt_time(unix: int) -> String:
	if unix <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(unix).replace("T", " ")


# ------------------------------------------------------------------ aksi


func _play_template(id: String) -> void:
	GameState.pending_action = {"mode": "play", "world_id": id}
	GameState.goto_scene(GAME_SCENE)


func _play_world(path: String) -> void:
	GameState.pending_action = {"mode": "play", "world_path": path}
	GameState.goto_scene(GAME_SCENE)


func _play_import(src_path: String) -> void:
	var imported := Saves.import_world(src_path)
	if imported != "":
		_play_world(imported)


func _ask_delete(path: String) -> void:
	_pending_delete = path
	if _confirm == null:
		_confirm = ConfirmationDialog.new()
		_confirm.ok_button_text = Locale.t("common_yes")
		_confirm.cancel_button_text = Locale.t("common_no")
		_confirm.confirmed.connect(_do_delete)
		add_child(_confirm)
	_confirm.dialog_text = Locale.t("ws_confirm_delete")
	_confirm.popup_centered()


func _do_delete() -> void:
	if _pending_delete != "":
		Saves.delete_world(_pending_delete)
		_pending_delete = ""
		_refresh_worlds()


func _open_import_dialog() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.filters = PackedStringArray(["*.myworld ; Reablox World"])
		_file_dialog.file_selected.connect(_on_import_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(900, 560))


func _on_import_selected(path: String) -> void:
	Saves.import_world(path)
	_refresh_worlds()


func _go_back() -> void:
	GameState.goto_scene(MENU_SCENE)


# ------------------------------------------------------------------ util


func _make_info_label(text: String) -> Control:
	var l := UiKit.make_label(text, 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _clear_children(box: VBoxContainer) -> void:
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.free()
