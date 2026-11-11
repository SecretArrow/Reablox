extends RefCounted
## UiKit — helper statis untuk membangun widget UI secara programatik.
## v0.4 "Modern pass": tombol modern dengan highlight atas (kesan glossy),
## radius besar, hover-lift, kartu dengan thumbnail, badge, icon button bulat,
## gradien multi-stop, dan toast glass — gaya platform game modern.

# ------------------------------------------------------------ palet warna --
# EN: dark palette
const COL_BG_DARK := Color("#11151f")
const COL_PANEL_DARK := Color("#1a2130")
const COL_TEXT_DARK := Color("#f0f3fa")
const COL_ACCENT := Color("#3d6df2")
const COL_ACCENT2 := Color("#00b26b")
# EN: light palette
const COL_BG_LIGHT := Color("#f2f5fb")
const COL_PANEL_LIGHT := Color("#ffffff")
const COL_TEXT_LIGHT := Color("#1a2233")
const COL_ACCENT_LIGHT := Color("#2f6fed")
const COL_ACCENT2_LIGHT := Color("#00a05f")
# EN: shared accents for modern look
const COL_PLAY := Color("#00b06f")
const COL_WARN := Color("#ff9d2e")
const COL_DANGER := Color("#ef5350")
const COL_GOLD := Color("#ffc107")

const CORNER := 16
const CORNER_XL := 22
const BTN_MIN_HEIGHT := 56.0
const TOUCH_MIN := 48.0

# ------------------------------------------------------------------ tombol


static func make_button(
	text: String, min_size: Vector2 = Vector2(160, 56), accent: bool = true
) -> Button:
	var b := Button.new()
	var sz := min_size
	if sz.y < BTN_MIN_HEIGHT:
		sz.y = BTN_MIN_HEIGHT
	b.custom_minimum_size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var base := COL_ACCENT if accent else COL_ACCENT2
	_apply_modern_button(b, base)
	return b


## Tombol dengan warna kustom (mis. hijau "Main", merah "Keluar").
static func make_button_color(
	text: String, base: Color, min_size: Vector2 = Vector2(160, 56)
) -> Button:
	var b := Button.new()
	var sz := min_size
	if sz.y < BTN_MIN_HEIGHT:
		sz.y = BTN_MIN_HEIGHT
	b.custom_minimum_size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	_apply_modern_button(b, base)
	return b


## Tombol sekunder: latar gelap semi-transparan + border halus (tidak "berteriak").
static func make_button_secondary(text: String, min_size: Vector2 = Vector2(160, 56)) -> Button:
	var b := Button.new()
	var sz := min_size
	if sz.y < BTN_MIN_HEIGHT:
		sz.y = BTN_MIN_HEIGHT
	b.custom_minimum_size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var base := Color(1, 1, 1, 0.10)
	var sb := _button_modern_sb(base)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.22)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := _button_modern_sb(Color(1, 1, 1, 0.17))
	sbh.set_border_width_all(1)
	sbh.border_color = Color(1, 1, 1, 0.32)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := _button_modern_sb(Color(1, 1, 1, 0.06), true)
	sbp.set_border_width_all(1)
	sbp.border_color = Color(1, 1, 1, 0.15)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("disabled", _button_modern_sb(Color(0.45, 0.48, 0.56, 0.4)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.92, 0.94, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_font_size_override("font_size", 20)
	attach_press_animation(b)
	return b


## Tombol bulat besar untuk HUD/kontrol sentuh; glyph digambar via label teks.
static func make_icon_button(
	label_text: String, diameter: float = 64.0, base := COL_ACCENT
) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(base.r, base.g, base.b, 0.92)
	sb.set_corner_radius_all(int(diameter * 0.5))
	sb.border_width_top = 2
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(
		base.lightened(0.12).r, base.lightened(0.12).g, base.lightened(0.12).b, 0.95
	)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = base.darkened(0.18)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color.WHITE)
	b.add_theme_font_size_override("font_size", int(diameter * 0.30))
	attach_press_animation(b)
	return b


static func _apply_modern_button(b: Button, base: Color) -> void:
	b.add_theme_stylebox_override("normal", _button_modern_sb(base))
	b.add_theme_stylebox_override("hover", _button_modern_sb(base.lightened(0.13)))
	b.add_theme_stylebox_override("pressed", _button_modern_sb(base.darkened(0.20), true))
	b.add_theme_stylebox_override("disabled", _button_modern_sb(Color(0.45, 0.48, 0.56, 0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.94, 0.96, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_font_size_override("font_size", 20)
	attach_press_animation(b)


## StyleBox tombol modern: highlight atas (glossy), bayangan lembut, radius besar.
static func _button_modern_sb(base: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(CORNER)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = (14.0 if not pressed else 16.0)
	sb.content_margin_bottom = (16.0 if not pressed else 12.0)
	# Highlight atas: kesan cahaya glossy ala platform game modern.
	sb.border_width_top = 2
	sb.border_color = Color(1, 1, 1, 0.30)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Animasi tekan: tombol menyusut saat ditekan, memantul saat dilepas.
static func attach_press_animation(b: Button) -> void:
	b.button_down.connect(
		func() -> void:
			b.pivot_offset = b.size * 0.5
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.05)
	)
	b.button_up.connect(
		func() -> void:
			if not is_instance_valid(b):
				return
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(
				Tween.EASE_OUT
			)
	)


# ------------------------------------------------------------------ teks


static func make_label(text: String, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func make_title(text: String) -> Label:
	var l := make_label(text, 54)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.13, 0.24, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


## Header seksi: label tebal besar dengan titik aksen berwarna di depannya.
static func make_section_header(text: String, accent := COL_ACCENT) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(8, 24)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Titik aksen kapsul.
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(dot)
	var l := make_label(text, 26)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	return hb


# ------------------------------------------------------------------ kontainer


## Kartu elevated: panel membulat dengan bayangan lembut (kesan kedalaman).
static func make_card(bg: Color = COL_PANEL_DARK, radius: int = CORNER) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	p.add_theme_stylebox_override("panel", sb)
	return p


## Chip/pil kecil: label dalam kapsul semi-transparan (badge, versi, status).
static func make_chip(text: String, bg: Color = Color(0, 0, 0, 0.45)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p


## Badge notifikasi ala platform modern: kapsul warna penuh + teks putih tebal.
static func make_badge(text: String, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(0, 24)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p


## Latar gradien vertikal (hero menu) — menggantikan ColorRect polos.
static func make_gradient_bg(top: Color, bottom: Color) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([top, bottom])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 64
	gt.height = 64
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Gradien kaya multi-stop diagonal (3-4 warna) untuk hero / panel besar.
static func make_rich_gradient(colors: Array) -> TextureRect:
	var g := Gradient.new()
	var cols := PackedColorArray()
	for c in colors:
		cols.append(c if c is Color else Color(String(c)))
	g.colors = cols
	var n := cols.size()
	var offs := PackedFloat32Array()
	for i in n:
		if n <= 1:
			offs.append(0.0)
		else:
			offs.append(float(i) / float(n - 1))
	g.offsets = offs
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	gt.width = 64
	gt.height = 64
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Dekorasi menu: blok-blok warna melayang pelan (kesan dunia sandbox).
static func make_decor_blocks() -> Control:
	var layer := Control.new()
	layer.name = "DecorBlocks"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# EN: deterministic layout (posisi, ukuran, warna, rotasi)
	var specs := [
		[0.08, 0.18, 54.0, "#e0453a", 18.0],
		[0.86, 0.14, 40.0, "#ffb300", -22.0],
		[0.16, 0.72, 44.0, "#26c6da", 32.0],
		[0.90, 0.66, 58.0, "#4ad48a", -14.0],
		[0.76, 0.82, 34.0, "#7e57c2", 24.0],
		[0.05, 0.45, 30.0, "#3b7bff", -30.0],
	]
	for s in specs:
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(String(s[3]), 0.30)
		sb.set_corner_radius_all(10)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(float(s[2]), float(s[2]))
		# EN: anchor to fractional position so it fits every aspect ratio
		box.anchor_left = float(s[0])
		box.anchor_top = float(s[1])
		box.anchor_right = float(s[0])
		box.anchor_bottom = float(s[1])
		box.offset_left = 0
		box.offset_top = 0
		box.offset_right = float(s[2])
		box.offset_bottom = float(s[2])
		box.rotation_degrees = float(s[4])
		box.pivot_offset = Vector2(float(s[2]) * 0.5, float(s[2]) * 0.5)
		layer.add_child(box)
		var tw := box.create_tween()
		tw.set_loops()
		(
			tw
			. tween_property(box, "position:y", -14.0, 2.4 + float(s[2]) * 0.01)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
			. as_relative()
		)
		(
			tw
			. tween_property(box, "position:y", 14.0, 2.4 + float(s[2]) * 0.01)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
			. as_relative()
		)
	return layer


static func make_panel(bg: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	if bg.a > 0.0:
		p.add_theme_stylebox_override("panel", _flat(bg, CORNER, 16.0, 14.0))
	return p


## Panel glass semi-transparan ala HUD modern: blur look + border terang.
static func make_glass_panel(alpha: float = 0.55, radius: int = CORNER) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.07, 0.12, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func make_hslider(min_value: float, max_value: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.value = value
	s.step = 0.01
	s.custom_minimum_size = Vector2(320, TOUCH_MIN)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	return s


static func make_option_button(items: Array) -> OptionButton:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.custom_minimum_size = Vector2(220, TOUCH_MIN + 8.0)
	ob.focus_mode = Control.FOCUS_NONE
	return ob


static func make_check(text: String, is_on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = is_on
	c.custom_minimum_size = Vector2(0, TOUCH_MIN)
	c.focus_mode = Control.FOCUS_NONE
	return c


static func make_separator() -> HSeparator:
	var s := HSeparator.new()
	s.custom_minimum_size = Vector2(0, 18)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func make_spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func make_background(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


static func make_toast_layer() -> Control:
	var layer := Control.new()
	layer.name = "ToastLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.anchor_left = 0.5
	stack.anchor_right = 0.5
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.offset_top = 24.0
	stack.offset_bottom = 24.0
	stack.add_theme_constant_override("separation", 8)
	layer.add_child(stack)
	return layer


static func show_toast(layer: Control, text: String, duration: float = 2.6) -> void:
	if layer == null or not layer.is_inside_tree():
		return
	var stack: Node = layer.get_node_or_null("Stack")
	if stack == null:
		return
	var panel := PanelContainer.new()
	var sb := _flat(Color(0.07, 0.09, 0.14, 0.94), 22, 22.0, 12.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	stack.add_child(panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = Vector2(80.0, 20.0)
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.chain().tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)


static func _flat(
	bg: Color, radius: int = CORNER, margin_h: float = 0.0, margin_v: float = 0.0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb
