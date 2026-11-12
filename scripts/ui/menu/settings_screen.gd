class_name SettingsScreen
extends Control
## Layar pengaturan: kualitas grafis, sensitivitas, kontrol, audio, bahasa,
## dan nama pemain. Semua kontrol dua arah terhubung ke autoload Settings.

signal closed

const UiThemeLib := preload("res://scripts/ui/kit/ui_theme.gd")

var _quality_slider: HSlider
var _sens_slider: HSlider
var _invert_check: CheckBox
var _shift_check: CheckBox
var _volume_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _name_edit: LineEdit
var _syncing := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_syncing = false
	sync_from_settings()


## Muat ulang seluruh nilai kontrol dari Settings tanpa memicu penulisan ulang.
func sync_from_settings() -> void:
	_syncing = true
	_quality_slider.set_value_no_signal(float(Settings.get_quality()))
	_sens_slider.set_value_no_signal(Settings.get_sensitivity())
	_invert_check.set_pressed_no_signal(Settings.get_invert_y())
	_shift_check.set_pressed_no_signal(Settings.get_shift_lock())
	_volume_slider.set_value_no_signal(Settings.get_vol_master())
	_music_slider.set_value_no_signal(Settings.get_vol_music())
	_sfx_slider.set_value_no_signal(Settings.get_vol_sfx())
	_name_edit.text = Settings.get_player_name()
	_syncing = false


# --- Pembangunan UI ---------------------------------------------------------------


func _build_ui() -> void:
	var panel := UiThemeLib.make_panel()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 96
	panel.offset_right = -96
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	box.add_child(UiThemeLib.make_title(Locale.tr_key("settings_title", "Pengaturan")))
	_build_quality_row(box)
	_build_sensitivity_row(box)
	_build_control_rows(box)
	_build_audio_rows(box)
	_build_language_row(box)
	_build_name_row(box)
	_build_back_row(box)


func _build_quality_row(box: VBoxContainer) -> void:
	box.add_child(_row_label(Locale.tr_key("settings_quality", "Kualitas")))
	_quality_slider = UiThemeLib.make_slider(0.0, 2.0, 1.0)
	_quality_slider.step = 1.0
	_quality_slider.value_changed.connect(_on_quality_changed)
	box.add_child(_quality_slider)


func _build_sensitivity_row(box: VBoxContainer) -> void:
	box.add_child(_row_label(Locale.tr_key("settings_sensitivity", "Sensitivitas")))
	_sens_slider = UiThemeLib.make_slider(0.05, 1.0, 0.5)
	_sens_slider.value_changed.connect(_on_sensitivity_changed)
	box.add_child(_sens_slider)


func _build_control_rows(box: VBoxContainer) -> void:
	_invert_check = UiThemeLib.make_check(Locale.tr_key("settings_invert_y", "Balik-Y"), false)
	_invert_check.toggled.connect(_on_invert_toggled)
	box.add_child(_invert_check)
	_shift_check = UiThemeLib.make_check(Locale.tr_key("settings_shift_lock", "Shift-lock"), false)
	_shift_check.toggled.connect(_on_shift_lock_toggled)
	box.add_child(_shift_check)


func _build_audio_rows(box: VBoxContainer) -> void:
	box.add_child(_row_label(Locale.tr_key("settings_volume", "Volume")))
	_volume_slider = UiThemeLib.make_slider(0.0, 1.0, 0.9)
	_volume_slider.value_changed.connect(_on_volume_changed)
	box.add_child(_volume_slider)
	box.add_child(_row_label(Locale.tr_key("settings_music", "Musik")))
	_music_slider = UiThemeLib.make_slider(0.0, 1.0, 0.7)
	_music_slider.value_changed.connect(_on_music_changed)
	box.add_child(_music_slider)
	box.add_child(_row_label(Locale.tr_key("settings_sfx", "Efek Suara")))
	_sfx_slider = UiThemeLib.make_slider(0.0, 1.0, 0.9)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	box.add_child(_sfx_slider)


func _build_language_row(box: VBoxContainer) -> void:
	box.add_child(_row_label(Locale.tr_key("settings_language", "Bahasa")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var id_btn := UiThemeLib.make_button("ID")
	id_btn.pressed.connect(_on_locale_id_pressed)
	row.add_child(id_btn)
	var en_btn := UiThemeLib.make_button("EN")
	en_btn.pressed.connect(_on_locale_en_pressed)
	row.add_child(en_btn)


func _build_name_row(box: VBoxContainer) -> void:
	var placeholder := Locale.tr_key("settings_player_name", "Nama Pemain")
	box.add_child(_row_label(placeholder))
	_name_edit = UiThemeLib.make_line_edit(Settings.get_player_name(), placeholder)
	_name_edit.text_changed.connect(_on_name_changed)
	box.add_child(_name_edit)


func _build_back_row(box: VBoxContainer) -> void:
	var back := UiThemeLib.make_button(Locale.tr_key("menu_back", "Kembali"))
	back.pressed.connect(_on_back_pressed)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)


func _row_label(text: String) -> Label:
	return UiThemeLib.make_label(text, UiThemeLib.FONT_SIZE, true)


# --- Handler perubahan nilai -------------------------------------------------------


func _on_quality_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_quality(int(round(value)))


func _on_sensitivity_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_sensitivity(value)


func _on_invert_toggled(pressed: bool) -> void:
	if _syncing:
		return
	Settings.set_invert_y(pressed)


func _on_shift_lock_toggled(pressed: bool) -> void:
	if _syncing:
		return
	Settings.set_shift_lock(pressed)


func _on_volume_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_vol_master(value)


func _on_music_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_vol_music(value)


func _on_sfx_changed(value: float) -> void:
	if _syncing:
		return
	Settings.set_vol_sfx(value)


func _on_name_changed(new_text: String) -> void:
	if _syncing:
		return
	Settings.set_player_name(new_text)


func _on_locale_id_pressed() -> void:
	if _syncing:
		return
	Locale.set_locale("id")


func _on_locale_en_pressed() -> void:
	if _syncing:
		return
	Locale.set_locale("en")


## Tombol kembali: komit nama pemain dulu (penulisan program tidak memicu
## sinyal text_changed), lalu umumkan closed.
func _on_back_pressed() -> void:
	_commit_player_name()
	closed.emit()


func _commit_player_name() -> void:
	if _name_edit == null or _syncing:
		return
	var clean := Settings.clean_player_name(_name_edit.text)
	if clean != Settings.get_player_name():
		Settings.set_player_name(_name_edit.text)
