extends CanvasLayer
## Touch controls layer (mobile, landscape): floating joystick on the left
## half, camera look drag on the right half, and jump / sprint / action
## buttons in the bottom-right corner.
##
## The layer stays hidden until bind_player() attaches it to the local
## player (game.gd owns the instantiation). Multitouch: joystick and look
## are tracked per touch index so both thumbs can be used at once.
##
## Visual pass: glass joystick (soft base, tick marks, knob with accent
## dot) and round glass buttons with vector glyphs drawn via _draw() — no
## unicode arrows/emoji, so everything stays crisp at any DPI.

signal move_changed(vec: Vector2)
signal look_delta(delta: Vector2)
signal jump_pressed
signal jump_released
signal sprint_toggled(on: bool)
signal action_a_pressed

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const STICK_RADIUS := 62.0
const DEAD_ZONE := 0.08
const MOUSE_TOUCH_ID := 100  # Synthetic touch index for desktop mouse testing.
const LAYER_ORDER := 14  # Above HUD, below pause overlay (20).
const JUMP_SIZE := 72.0
const SPRINT_SIZE := 64.0
const ACTION_SIZE := 60.0
const GLASS_BG := Color(0.10, 0.13, 0.20, 0.72)
const GLASS_HOVER := Color(0.17, 0.21, 0.31, 0.82)
const GLASS_PRESSED := Color(0.05, 0.07, 0.12, 0.88)

var _player = null
var _root: Control = null
var _stick = null  # JoystickView instance
var _stick_center := Vector2.ZERO
var _stick_index := -1
var _look_index := -1
var _look_last := Vector2.ZERO
var _mouse_down := false
var _button_rects: Array = []
var _rest_stick_pos := Vector2.ZERO
var _btn_jump: Button = null
var _btn_sprint: Button = null
var _btn_action: Button = null
var _bound: Array = []  # list of (signal, callable) for current player


# Custom-drawn joystick: soft glass base, direction ticks and a knob whose
# inner dot lights up in the accent blue while dragging. Input-transparent.
class JoystickView:
	extends Control
	const ACCENT := Color("#3d6df2")
	var radius := 62.0
	var knob := Vector2.ZERO

	func set_knob(offset: Vector2) -> void:
		knob = offset
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		# Base: soft fill + crisp outer ring.
		draw_circle(center, radius, Color(1.0, 1.0, 1.0, 0.08))
		draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.5), 2.5, true)
		# Four direction ticks at 72% of the radius.
		var tick := Color(1.0, 1.0, 1.0, 0.35)
		var tick_r := radius * 0.72
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(center + dir * tick_r, center + dir * (tick_r + 6.0), tick, 2.0, true)
		# Knob: soft shadow underneath, solid white cap on top.
		var knob_r := radius * 0.42
		var kpos := center + knob
		draw_circle(kpos + Vector2(0.0, 2.0), knob_r, Color(0.0, 0.0, 0.0, 0.25))
		draw_circle(kpos, knob_r, Color(1.0, 1.0, 1.0, 0.9))
		if knob.length() > 2.0:
			# Active: accent dot marks the drag direction.
			draw_circle(kpos, radius * 0.24, Color(ACCENT, 0.9))
		else:
			draw_circle(kpos, radius * 0.15, Color(1.0, 1.0, 1.0, 0.35))


# Vector glyph drawn with _draw() (no unicode arrows / emoji): always crisp
# and tintable. Input-transparent so taps reach the parent Button.
class GlyphIcon:
	extends Control
	var kind := "jump"
	var tint := Color(1.0, 1.0, 1.0, 0.95)

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y)
		match kind:
			"jump":
				# Filled triangle pointing up.
				var h := s * 0.34
				var pts := PackedVector2Array(
					[
						c + Vector2(0.0, -h),
						c + Vector2(h * 0.9, h * 0.62),
						c + Vector2(-h * 0.9, h * 0.62),
					]
				)
				draw_colored_polygon(pts, tint)
			"sprint":
				# Two chevrons pointing right.
				_chevron(c + Vector2(-s * 0.16, 0.0), s * 0.24)
				_chevron(c + Vector2(s * 0.14, 0.0), s * 0.24)
			"action":
				# Circle outline with a center dot.
				var w := maxf(2.0, s * 0.07)
				draw_arc(c, s * 0.26, 0.0, TAU, 40, tint, w, true)
				draw_circle(c, maxf(2.5, s * 0.08), tint)

	func _chevron(origin: Vector2, h: float) -> void:
		# ">" stroke of half-height h.
		var w := maxf(2.0, h * 0.30)
		var tip := origin + Vector2(h * 0.62, 0.0)
		draw_line(origin + Vector2(-h * 0.62, -h), tip, tint, w, true)
		draw_line(tip, origin + Vector2(-h * 0.62, h), tint, w, true)


# Glossy highlight arc hugging the top inside edge of a round button.
class GlassGloss:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, PI * 1.12, PI * 1.88, 40, Color(1.0, 1.0, 1.0, 0.30), 2.0, true)


func _ready() -> void:
	layer = LAYER_ORDER
	visible = false
	set_process_input(false)
	add_to_group("touch_controls")

	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th: Theme = Settings.get_theme()
	if th != null:
		_root.theme = th
	add_child(_root)
	_root.resized.connect(_layout)

	_stick = JoystickView.new()
	_stick.name = "Joystick"
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.radius = STICK_RADIUS
	_stick.size = Vector2(STICK_RADIUS * 2.0 + 12.0, STICK_RADIUS * 2.0 + 12.0)
	_root.add_child(_stick)

	_btn_jump = _make_button("jump", _t("hud_jump", "Lompat", "Jump"), JUMP_SIZE)
	_btn_sprint = _make_button("sprint", _t("hud_sprint", "Sprint", "Sprint"), SPRINT_SIZE)
	_btn_sprint.toggle_mode = true
	_btn_action = _make_button("action", _t("hud_action", "Aksi", "Action"), ACTION_SIZE)
	for b in [_btn_jump, _btn_sprint, _btn_action]:
		_root.add_child(b)
	_btn_jump.button_down.connect(_on_jump_down)
	_btn_jump.button_up.connect(_on_jump_up)
	_btn_sprint.toggled.connect(_on_sprint_toggled)
	_btn_action.pressed.connect(_on_action_pressed)
	Locale.language_changed.connect(_apply_texts)

	_layout()


func _exit_tree() -> void:
	_release_actions()


## Locale.t with inline id/en fallback while locale JSON lacks hud_* keys.
func _t(key: String, fb_id: String, fb_en: String) -> String:
	var s := String(Locale.t(key))
	if s != key:
		return s
	return fb_en if Locale.get_language() == "en" else fb_id


func _apply_texts() -> void:
	_set_caption(_btn_jump, _t("hud_jump", "Lompat", "Jump"))
	_set_caption(_btn_sprint, _t("hud_sprint", "Sprint", "Sprint"))
	_set_caption(_btn_action, _t("hud_action", "Aksi", "Action"))


func _set_caption(b: Button, text: String) -> void:
	if b == null or not is_instance_valid(b):
		return
	var lbl := b.get_node_or_null("Caption")
	if lbl is Label:
		(lbl as Label).text = text


## Connect this layer to the local player node. Also makes the layer visible:
## it must only be on screen while a local player exists.
func bind_player(p: Node) -> void:
	_disconnect_player()
	_player = p
	visible = true
	set_process_input(true)
	if p.has_method("set_touch_move"):
		move_changed.connect(p.set_touch_move)
		_bound.append([move_changed, p.set_touch_move])
	if p.has_method("add_look"):
		look_delta.connect(p.add_look)
		_bound.append([look_delta, p.add_look])
	if p.has_method("request_jump"):
		jump_pressed.connect(p.request_jump)
		_bound.append([jump_pressed, p.request_jump])
	if p.has_method("set_touch_sprint"):
		sprint_toggled.connect(p.set_touch_sprint)
		_bound.append([sprint_toggled, p.set_touch_sprint])
	_layout()


func _disconnect_player() -> void:
	for entry in _bound:
		var sig: Signal = entry[0]
		var cb: Callable = entry[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_bound.clear()


func unbind() -> void:
	_disconnect_player()
	_player = null
	visible = false
	set_process_input(false)
	_stick_index = -1
	_look_index = -1
	_release_actions()
	move_changed.emit(Vector2.ZERO)


func _release_actions() -> void:
	Input.action_release("jump")
	Input.action_release("sprint")
	Input.action_release("action_a")


# ------------------------------------------------------------------ input


func _input(event: InputEvent) -> void:
	if not visible or _player == null or not is_instance_valid(_player):
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Desktop fallback so the controls can be tested with a mouse.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return
		_mouse_down = event.pressed
		_handle_touch(MOUSE_TOUCH_ID, event.position, event.pressed)
	elif event is InputEventMouseMotion and _mouse_down:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return
		_handle_drag(MOUSE_TOUCH_ID, event.position)


func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _over_button(pos):
			return  # Buttons handle themselves through the GUI.
		if _in_stick_zone(pos):
			_stick_index = index
			_stick_center = _clamp_stick_center(pos)
			_stick.position = _stick_center - _stick.size * 0.5
			_apply_stick(Vector2.ZERO)
		elif _look_index == -1:
			_look_index = index
			_look_last = pos
	else:
		if index == _stick_index:
			_stick_index = -1
			_apply_stick(Vector2.ZERO)
			_stick.position = _rest_stick_pos
		elif index == _look_index:
			_look_index = -1


func _handle_drag(index: int, pos: Vector2) -> void:
	if index == _stick_index:
		_apply_stick(pos - _stick_center)
	elif index == _look_index:
		var d := pos - _look_last
		_look_last = pos
		if d.length_squared() > 0.0:
			look_delta.emit(d)


func _apply_stick(offset: Vector2) -> void:
	var v := offset.limit_length(STICK_RADIUS)
	if _stick != null and is_instance_valid(_stick) and _stick.has_method("set_knob"):
		_stick.set_knob(v)
	var out := v / STICK_RADIUS
	var len := out.length()
	if len < DEAD_ZONE:
		out = Vector2.ZERO
	elif len > 0.0:
		out = out.normalized() * (len - DEAD_ZONE) / (1.0 - DEAD_ZONE)
	move_changed.emit(out)


func _in_stick_zone(pos: Vector2) -> bool:
	var vs := _view_size()
	return pos.x < vs.x * 0.5 and pos.y > vs.y * 0.3


func _clamp_stick_center(pos: Vector2) -> Vector2:
	var vs := _view_size()
	var m := STICK_RADIUS + 16.0
	return Vector2(
		clampf(pos.x, m, maxf(m, vs.x * 0.5 - 16.0)),
		clampf(pos.y, maxf(m, vs.y * 0.3 + m * 0.5), maxf(m + 1.0, vs.y - m))
	)


func _over_button(pos: Vector2) -> bool:
	for r in _button_rects:
		if r is Rect2 and (r as Rect2).has_point(pos):
			return true
	return false


func _view_size() -> Vector2:
	if _root != null and _root.size.x > 1.0:
		return _root.size
	var vp := get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return Vector2(1280, 720)


# ------------------------------------------------------------------ buttons


func _on_jump_down() -> void:
	Input.action_press("jump")
	jump_pressed.emit()


func _on_jump_up() -> void:
	Input.action_release("jump")
	jump_released.emit()


func _on_sprint_toggled(on: bool) -> void:
	if on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")
	_apply_glass_style(_btn_sprint, SPRINT_SIZE, on)
	sprint_toggled.emit(on)


func _on_action_pressed() -> void:
	Input.action_press("action_a")
	action_a_pressed.emit()
	if is_inside_tree():
		get_tree().create_timer(0.12).timeout.connect(
			func() -> void: Input.action_release("action_a")
		)


# ------------------------------------------------------------------ build


## Round glass button with a vector glyph, a small caption underneath and a
## glossy top highlight. Targets are >= 48px as required for touch input.
func _make_button(kind: String, caption: String, side: float) -> Button:
	var b := Button.new()
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(side, side)

	var gloss := GlassGloss.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(gloss)

	var glyph := GlyphIcon.new()
	glyph.kind = kind
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 8.0
	glyph.offset_top = 6.0
	glyph.offset_right = -8.0
	glyph.offset_bottom = -20.0
	b.add_child(glyph)

	var lbl := Label.new()
	lbl.name = "Caption"
	lbl.text = caption
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -18.0
	lbl.offset_bottom = -4.0
	b.add_child(lbl)

	_apply_glass_style(b, side)
	UiKit.attach_press_animation(b)
	return b


## Glass round styleboxes; `on` swaps the sprint toggle fill to play-green
## (white glyph stays readable on both fills).
func _apply_glass_style(b: Button, side: float, on := false) -> void:
	var base := UiKit.COL_PLAY if on else GLASS_BG
	var hover := UiKit.COL_PLAY.lightened(0.10) if on else GLASS_HOVER
	var pressed := UiKit.COL_PLAY.darkened(0.22) if on else GLASS_PRESSED
	b.add_theme_stylebox_override("normal", _glass_sb(base, side))
	b.add_theme_stylebox_override("hover", _glass_sb(hover, side))
	b.add_theme_stylebox_override("pressed", _glass_sb(pressed, side, true))
	b.add_theme_stylebox_override("hover_pressed", _glass_sb(hover, side))
	b.add_theme_stylebox_override("disabled", _glass_sb(Color(0.3, 0.33, 0.4, 0.5), side))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Dark glass circle: 1px white border, drop shadow, compressed content
## margins while pressed for a "pushed in" feel.
func _glass_sb(base: Color, side: float, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(int(round(side * 0.5)))
	sb.set_border_width_all(1)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.25)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0.0, 3.0)
	if pressed:
		sb.content_margin_top = 1.0
		sb.content_margin_bottom = 1.0
	else:
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 3.0
	return sb


func _layout() -> void:
	if _root == null or _btn_jump == null:
		return
	var vs := _view_size()
	_btn_jump.custom_minimum_size = Vector2(JUMP_SIZE, JUMP_SIZE)
	_btn_jump.size = Vector2(JUMP_SIZE, JUMP_SIZE)
	_btn_jump.position = Vector2(vs.x - JUMP_SIZE - 18.0, vs.y - JUMP_SIZE - 22.0)
	_btn_sprint.custom_minimum_size = Vector2(SPRINT_SIZE, SPRINT_SIZE)
	_btn_sprint.size = Vector2(SPRINT_SIZE, SPRINT_SIZE)
	_btn_sprint.position = Vector2(
		vs.x - JUMP_SIZE - 18.0 - SPRINT_SIZE - 14.0, vs.y - SPRINT_SIZE - 22.0
	)
	_btn_action.custom_minimum_size = Vector2(ACTION_SIZE, ACTION_SIZE)
	_btn_action.size = Vector2(ACTION_SIZE, ACTION_SIZE)
	_btn_action.position = Vector2(
		vs.x - ACTION_SIZE - 24.0, vs.y - JUMP_SIZE - 22.0 - ACTION_SIZE - 14.0
	)
	var stick_size := Vector2(STICK_RADIUS * 2.0 + 12.0, STICK_RADIUS * 2.0 + 12.0)
	_stick.size = stick_size
	_rest_stick_pos = Vector2(20.0, vs.y - stick_size.y - 20.0)
	if _stick_index == -1:
		_stick.position = _rest_stick_pos
	_refresh_button_rects()


func _refresh_button_rects() -> void:
	_button_rects.clear()
	for b in [_btn_jump, _btn_sprint, _btn_action]:
		if b != null and is_instance_valid(b):
			_button_rects.append(Rect2(b.position, b.size))
