class_name UiTheme
extends RefCounted
## Kit tema UI gelap ala aplikasi Roblox untuk Reablox.
##
## Semua widget dibuat prosedural lewat factory static sehingga konsisten di
## seluruh layar (menu, pengaturan, editor avatar) tanpa file .tres terpisah.

const BG := Color("232527")
const PANEL := Color("2b2d2f")
const PANEL_LIGHT := Color("3a3d40")
const ACCENT := Color("00a2ff")
const ACCENT_GREEN := Color("00b06f")
const DANGER := Color("ff4d4d")
const TEXT := Color("f2f3f3")
const TEXT_DIM := Color("a3a2a5")
const RADIUS := 8
const FONT_SIZE := 18
const FONT_SIZE_TITLE := 28

const BUTTON_MIN_SIZE := Vector2(160, 48)
# Bobot tebal (bold) standar TextServer; konstanta enum tidak tersedia di 4.4.
const FONT_WEIGHT_BOLD := 700


## StyleBox panel: latar solid, sudut membulat, margin isi 12 px.
static func panel_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(12)
	return style


## StyleBox tombol: variasi panel dengan margin lebih rapat.
static func button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## PanelContainer bertema gelap siap pakai.
static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(PANEL))
	return panel


## Button bertema; accent=true memakai warna biru aksen. Otomatis memutar
## bunyi klik "ui_click" setiap kali ditekan.
static func make_button(text: String, accent := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)
	btn.add_theme_color_override("font_focus_color", TEXT)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	var base := ACCENT if accent else PANEL_LIGHT
	btn.add_theme_stylebox_override("normal", button_style(base))
	btn.add_theme_stylebox_override("hover", button_style(base.lightened(0.15)))
	btn.add_theme_stylebox_override("pressed", button_style(base.darkened(0.15)))
	btn.pressed.connect(Audio.play_sfx.bind("ui_click"))
	return btn


## Label teks; dim=true memakai warna redup.
static func make_label(text: String, size := FONT_SIZE, dim := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_DIM if dim else TEXT)
	return label


## Judul besar tebal untuk kepala layar.
static func make_title(text: String) -> Label:
	var label := make_label(text, FONT_SIZE_TITLE, false)
	label.add_theme_color_override("font_color", TEXT)
	var font := SystemFont.new()
	font.font_weight = FONT_WEIGHT_BOLD
	label.add_theme_font_override("font", font)
	return label


## HSlider dengan langkah 0.05 dan lebar minimum yang nyaman disentuh.
static func make_slider(minv: float, maxv: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(240, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


## CheckBox bertema dengan status awal.
static func make_check(text: String, checked: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = checked
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_color_override("font_color", TEXT)
	check.add_theme_color_override("font_hover_color", TEXT)
	check.add_theme_font_size_override("font_size", FONT_SIZE)
	return check


## LineEdit bertema dengan teks awal dan placeholder.
static func make_line_edit(text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(240, 44)
	edit.add_theme_font_size_override("font_size", FONT_SIZE)
	edit.add_theme_color_override("font_color", TEXT)
	edit.add_theme_color_override("font_placeholder_color", TEXT_DIM)
	return edit
