class_name TouchControls
extends Control
## TouchControls — thumbstick dinamis + tombol lompat ala Roblox mobile.
## Spek: docs/rea/player.md §5. Fungsi statis murni bisa dites headless.

const STICK_RADIUS := 64.0
const CAM_FACTOR := 2.0

var _camera: Node3D = null
var _player: CharacterBody3D = null
var _stick_origin := Vector2.ZERO
var _stick_active := false
var _stick_touch_index := -1
var _thumb: Panel = null
var _knob: Panel = null
var _jump_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_jump_button()
	if not DisplayServer.is_touchscreen_available():
		visible = false
		return
	_ensure_visual()


func setup(camera: Node3D, player: CharacterBody3D) -> void:
	_camera = camera
	_player = player


## Paruh kiri layar = zona thumbstick (ala Roblox).
static func is_left_zone(pos: Vector2, vp_size: Vector2) -> bool:
	return pos.x < vp_size.x * 0.5


## Vektor thumbstick dinormalisasi ke radius; di-clamp lingkaran.
static func thumbstick_vector(origin: Vector2, pos: Vector2, radius := 64.0) -> Vector2:
	var v := pos - origin
	if v.length() > radius:
		v = v.normalized() * radius
	return v / radius


func get_stick_origin() -> Vector2:
	return _stick_origin


func is_stick_active() -> bool:
	return _stick_active


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and is_left_zone(event.position, get_viewport_rect().size):
			_stick_origin = event.position
			_stick_active = true
			_stick_touch_index = event.index
			_show_stick(event.position)
		elif not event.pressed and event.index == _stick_touch_index:
			_release_stick()
	elif event is InputEventScreenDrag:
		if _stick_active and event.index == _stick_touch_index:
			var v := thumbstick_vector(_stick_origin, event.position)
			_update_knob(_stick_origin + v * STICK_RADIUS)
			_player.set_move_override(Vector2(v.x, -v.y))
		elif _camera != null:
			_camera.add_look_delta(event.relative.x * CAM_FACTOR, event.relative.y * CAM_FACTOR)


func _build_jump_button() -> void:
	_jump_btn = Button.new()
	_jump_btn.text = "JUMP"
	_jump_btn.anchor_left = 1.0
	_jump_btn.anchor_right = 1.0
	_jump_btn.anchor_top = 1.0
	_jump_btn.anchor_bottom = 1.0
	_jump_btn.offset_left = -150.0
	_jump_btn.offset_right = -20.0
	_jump_btn.offset_top = -150.0
	_jump_btn.offset_bottom = -20.0
	_jump_btn.add_theme_stylebox_override("normal", _circle_style(Color(1, 1, 1, 0.22), 60))
	_jump_btn.add_theme_stylebox_override("pressed", _circle_style(Color(1, 1, 1, 0.45), 60))
	_jump_btn.button_down.connect(_on_jump_down)
	_jump_btn.button_up.connect(_on_jump_up)
	add_child(_jump_btn)


func _ensure_visual() -> void:
	if _thumb != null:
		return
	_thumb = Panel.new()
	_thumb.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.18), 80))
	_thumb.size = Vector2(80, 80)
	add_child(_thumb)
	_knob = Panel.new()
	_knob.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.5), 36))
	_knob.size = Vector2(36, 36)
	add_child(_knob)
	_thumb.visible = false
	_knob.visible = false


func _circle_style(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _show_stick(pos: Vector2) -> void:
	_ensure_visual()
	_thumb.position = pos - Vector2(40, 40)
	_thumb.visible = true
	_update_knob(pos)


func _update_knob(pos: Vector2) -> void:
	_knob.position = pos - Vector2(18, 18)
	_knob.visible = true


func _release_stick() -> void:
	_stick_active = false
	_stick_touch_index = -1
	if _thumb != null:
		_thumb.visible = false
		_knob.visible = false
	if _player != null:
		_player.set_move_override(Vector2.ZERO)


func _on_jump_down() -> void:
	if _player != null:
		_player.set_jump_override(true)


func _on_jump_up() -> void:
	if _player != null:
		_player.set_jump_override(false)
