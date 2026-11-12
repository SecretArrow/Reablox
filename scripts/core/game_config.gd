extends Node
## GameConfig — konstanta paritas Roblox + registrasi input map saat runtime.
##
## Skala dunia: 1 unit = 1 stud. Nilai default mengikuti Humanoid Roblox:
## WalkSpeed 16, JumpHeight 7.2, Gravity 196.2, Health 100, RespawnTime 5.
## Agen modul diverifikasi ulang nilai ini ke docs/rea/*.md (metodologi REA).

# --- Gerak & tubuh (studs, detik) -----------------------------------------
const GRAVITY := 196.2
const WALK_SPEED := 16.0
const SPRINT_SPEED := 24.0
const JUMP_HEIGHT := 7.2
const SWIM_SPEED := 16.0
const CLIMB_SPEED := 8.0
const MAX_HEALTH := 100.0
const RESPAWN_TIME := 5.0

# --- Kamera ----------------------------------------------------------------
const CAM_MIN_DIST := 0.5
const CAM_MAX_DIST := 128.0
const CAM_DEFAULT_DIST := 12.5

# --- Build ------------------------------------------------------------------
const GRID_SIZE := 1.0
const ROT_STEP_DEG := 90.0
const MAX_BLOCKS := 4000
const MAX_HOTBAR := 9

# --- Jaringan -----------------------------------------------------------------
const NET_PORT := 24565
const NET_TICK_HZ := 15.0

# --- Waktu dunia ----------------------------------------------------------------
const DAY_LENGTH_SEC := 600.0
const START_TIME_HOUR := 14.0

# --- Physics layers (bitmask) -----------------------------------------------------
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_PARTS := 4
const LAYER_NPC := 8
const LAYER_WATER := 16
const LAYER_PICKUP := 32
const LAYER_PROJECTILE := 64


func _ready() -> void:
	_register_input_map()


func _register_input_map() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("ui_menu", KEY_ESCAPE)
	_add_key("ui_chat", KEY_T)
	_add_key("ui_chat", KEY_SLASH)
	_add_key("build_rotate", KEY_R)
	_add_key("build_delete", KEY_X)
	_add_key("build_delete", KEY_DELETE)
	_add_key("build_grid", KEY_G)
	_add_combo("build_duplicate", KEY_D, true)
	_add_combo("build_undo", KEY_Z, true)
	_add_combo("build_redo", KEY_Y, true)
	_add_combo("build_redo", KEY_Z, true, true)
	_add_wheel("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_add_wheel("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	for i in range(9):
		var action := "hotbar_%d" % (i + 1)
		_add_key(action, KEY_1 + i)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_combo(action: String, key: Key, ctrl := false, shift := false) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	InputMap.action_add_event(action, ev)


func _add_wheel(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
