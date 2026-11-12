class_name AvatarEditorScreen
extends Control
## Layar editor avatar: preview 3D (SubViewport + AvatarRig) di kiri dan panel
## pemilih warna per bagian tubuh di kanan, plus tombol acak/simpan/kembali.

signal saved(config: Dictionary)
signal closed

const UiThemeLib := preload("res://scripts/ui/kit/ui_theme.gd")
const AvatarRigLib := preload("res://scripts/avatar/avatar_rig.gd")
const AvatarConfigLib := preload("res://scripts/avatar/avatar_config.gd")
const BrickColorsLib := preload("res://scripts/avatar/brick_colors.gd")

const PART_ORDER := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const PART_LABELS := {
	"head": "Kepala",
	"torso": "Badan",
	"left_arm": "Lengan Kiri",
	"right_arm": "Lengan Kanan",
	"left_leg": "Kaki Kiri",
	"right_leg": "Kaki Kanan",
}

var _config: Dictionary = {}
var _rig: AvatarRigLib
var _part_options: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _config.is_empty():
		_config = AvatarConfigLib.default_config()
	_build_ui()
	_apply_config_to_rig()


## Salinan config avatar terkini (valid menurut AvatarConfig.validate).
func get_config() -> Dictionary:
	if _config.is_empty():
		_config = AvatarConfigLib.default_config()
	return _config.duplicate(true)


## Terapkan config eksternal; ditolak bila tidak lolos validasi.
func set_config(cfg: Dictionary) -> void:
	if cfg == null or not AvatarConfigLib.validate(cfg).is_empty():
		return
	_config = cfg.duplicate(true)
	_apply_config_to_rig()


## Acak warna seluruh bagian tubuh dengan nama palet yang sah.
func randomize() -> void:
	var names: Array = BrickColorsLib.names()
	if names.is_empty():
		return
	var colors: Variant = _config.get("colors")
	if typeof(colors) != TYPE_DICTIONARY:
		colors = {}
		_config["colors"] = colors
	for part in PART_ORDER:
		var color_name := String(names[randi() % names.size()])
		(colors as Dictionary)[part] = color_name
		_apply_part_color(part, color_name)
	_sync_option_selections()


# --- Pembangunan UI ---------------------------------------------------------------


func _build_ui() -> void:
	var panel := UiThemeLib.make_panel()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48
	panel.offset_right = -48
	panel.offset_top = 32
	panel.offset_bottom = -32
	add_child(panel)
	var cols := HBoxContainer.new()
	cols.name = "Cols"
	cols.add_theme_constant_override("separation", 24)
	panel.add_child(cols)
	cols.add_child(_build_preview())
	cols.add_child(_build_color_panel())


## Panel kiri: SubViewport berisi AvatarRig + kamera + cahaya.
func _build_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = "Preview"
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(512, 640)
	container.add_child(viewport)
	_rig = AvatarRigLib.new()
	viewport.add_child(_rig)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.4, 9.0)
	camera.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	viewport.add_child(camera)
	viewport.add_child(_make_light())
	viewport.add_child(_make_environment())
	return container


func _make_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	light.light_energy = 1.1
	return light


func _make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UiThemeLib.PANEL
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	return world_env


## Panel kanan: judul, 6 baris warna per bagian tubuh, tombol aksi.
func _build_color_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "ColorPanel"
	box.custom_minimum_size = Vector2(430, 0)
	box.add_theme_constant_override("separation", 10)
	box.add_child(UiThemeLib.make_title(Locale.tr_key("avatar_title", "Editor Avatar")))
	for part in PART_ORDER:
		box.add_child(_build_part_row(part))
	var randomize_btn := UiThemeLib.make_button(Locale.tr_key("avatar_randomize", "Acak Warna"))
	randomize_btn.pressed.connect(_on_randomize_pressed)
	box.add_child(randomize_btn)
	var save_btn := UiThemeLib.make_button(Locale.tr_key("avatar_save", "Simpan"), true)
	save_btn.pressed.connect(_on_save_pressed)
	box.add_child(save_btn)
	var back_btn := UiThemeLib.make_button(Locale.tr_key("menu_back", "Kembali"))
	back_btn.pressed.connect(_on_back_pressed)
	box.add_child(back_btn)
	return box


func _build_part_row(part: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + part
	row.add_theme_constant_override("separation", 10)
	var label := UiThemeLib.make_label(_part_label(part), UiThemeLib.FONT_SIZE, true)
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	var options := OptionButton.new()
	options.name = "Opt_" + part
	for color_name in BrickColorsLib.names():
		options.add_item(color_name)
	options.item_selected.connect(_on_part_color_selected.bind(part))
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(options)
	_part_options[part] = options
	return row


func _part_label(part: String) -> String:
	return String(PART_LABELS.get(part, part))


# --- Penerapan config --------------------------------------------------------------


## Bangun ulang rig preview dari _config lalu sinkronkan pilihan OptionButton.
func _apply_config_to_rig() -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	_rig.build(_config)
	_sync_option_selections()


## Pilih item tiap OptionButton sesuai warna _config (defensif bila tak cocok).
func _sync_option_selections() -> void:
	var names: Array = BrickColorsLib.names()
	var colors: Variant = _config.get("colors")
	if typeof(colors) != TYPE_DICTIONARY or names.is_empty():
		return
	for part in PART_ORDER:
		var options := _part_options.get(part) as OptionButton
		if options == null:
			continue
		var wanted := String((colors as Dictionary).get(part, ""))
		var idx := names.find(wanted)
		options.select(idx if idx >= 0 else 0)


## Ubah warna satu bagian: catat di _config dan terapkan ke rig bila ada.
func _apply_part_color(part: String, color_name: String) -> void:
	var colors: Variant = _config.get("colors")
	if typeof(colors) != TYPE_DICTIONARY:
		return
	(colors as Dictionary)[part] = color_name
	if _rig != null and is_instance_valid(_rig):
		_rig.set_part_color(part, BrickColorsLib.color_of(color_name))


# --- Handler tombol -----------------------------------------------------------------


func _on_part_color_selected(index: int, part: String) -> void:
	var names: Array = BrickColorsLib.names()
	if index < 0 or index >= names.size():
		return
	_apply_part_color(part, String(names[index]))


func _on_randomize_pressed() -> void:
	randomize()


func _on_save_pressed() -> void:
	saved.emit(get_config())


func _on_back_pressed() -> void:
	closed.emit()
