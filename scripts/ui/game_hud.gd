extends CanvasLayer
## GameHUD — HUD in-game: profil kesehatan, minimap, objective, kontrol sentuh, toast.
## Hanya MEMBACA group/sinyal modul lain (tidak meng-instance player/build manager):
## - group "game": request_pause(), toggle_build_mode()
## - group "local_player": sinyal health_changed(hp, max_hp), died
## - group "mode_controller": get_objective_text()
## - group "env_weather": cycle_weather(), get_weather()
## - node "ChatOverlay" (cari di root): toggle(), open_emotes()
## Achievement: GameState.achievement_unlocked -> toast.
##
## Visual pass "modern glass": panel glass radius besar, bar kesehatan dengan
## warna dinamis (hijau/oranye/merah) + glyph hati vektor, tombol ikon bulat
## dengan glyph vektor (pause/kubus/chat), dan chip ala UiKit.

const Toast := preload("res://scripts/ui/toast.gd")
const Screenshot := preload("res://scripts/meta/screenshot.gd")
const MinimapScript := preload("res://scripts/ui/minimap.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")

const MARGIN := 16.0
const BTN_MIN := 48.0
const ICON_BTN := 48.0
const JOYSTICK_CLEARANCE := 150.0
const MAP_SIZE := 160.0
const GLASS_BG := Color(0.10, 0.13, 0.20, 0.72)
const GLASS_HOVER := Color(0.17, 0.21, 0.31, 0.82)
const GLASS_PRESSED := Color(0.05, 0.07, 0.12, 0.88)

var _root: Control
var _profile_panel: PanelContainer
var _name_label: Label
var _health_bar: ProgressBar
var _health_fill: StyleBoxFlat
var _health_text: Label
var _heart: HeartIcon = null
var _fps_label: Label
var _objective: PanelContainer
var _objective_label: Label
var _minimap: Control = null
var _build_btn: Button = null
var _weather_btn: Button = null
var _right_ctl: Control = null
var _player: Node = null


# Vector glyph drawn with _draw() (no unicode arrows / emoji): always crisp
# and tintable. Input-transparent so clicks reach the parent Button.
class GlyphIcon:
	extends Control
	var kind := "pause"
	var tint := Color(1.0, 1.0, 1.0, 0.95)

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y)
		match kind:
			"pause":
				# Two vertical bars.
				var bw := maxf(3.0, s * 0.13)
				var bh := s * 0.46
				draw_rect(Rect2(c + Vector2(-bw * 1.8, -bh * 0.5), Vector2(bw, bh)), tint)
				draw_rect(Rect2(c + Vector2(bw * 0.8, -bh * 0.5), Vector2(bw, bh)), tint)

				# Isometric cube outline (draw_polyline) with inner top edges.

				# Speech bubble outline with a tail.
			"build":
				# Isometric cube outline (draw_polyline) with inner top edges.
				var w := s * 0.40
				var h := s * 0.48
				var lw := maxf(2.0, s * 0.07)
				var outline := PackedVector2Array(
					[
						c + Vector2(0.0, -h),
						c + Vector2(w, -h * 0.5),
						c + Vector2(w, h * 0.5),
						c + Vector2(0.0, h),
						c + Vector2(-w, h * 0.5),
						c + Vector2(-w, -h * 0.5),
						c + Vector2(0.0, -h),
					]
				)
				draw_polyline(outline, tint, lw, true)
				var top_face := PackedVector2Array(
					[c + Vector2(-w, -h * 0.5), c, c + Vector2(w, -h * 0.5)]
				)
				draw_polyline(top_face, tint, lw, true)
				draw_line(c, c + Vector2(0.0, h), tint, lw, true)

				# Speech bubble outline with a tail.
			"chat":
				# Speech bubble outline with a tail.
				var bw := s * 0.80
				var bh := s * 0.60
				var rect := Rect2(c.x - bw * 0.5, c.y - bh * 0.5 - s * 0.05, bw, bh)
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
				sb.set_corner_radius_all(int(bh * 0.38))
				sb.set_border_width_all(2)
				sb.border_color = tint
				draw_style_box(sb, rect)
				var tail := PackedVector2Array(
					[
						c + Vector2(-bw * 0.16, rect.position.y + bh - 1.0),
						c + Vector2(-bw * 0.34, rect.position.y + bh + s * 0.14),
						c + Vector2(-bw * 0.02, rect.position.y + bh - 1.0),
					]
				)
				draw_colored_polygon(tail, tint)


# Glossy highlight arc hugging the top inside edge of a round button.
class GlassGloss:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, PI * 1.12, PI * 1.88, 40, Color(1.0, 1.0, 1.0, 0.30), 2.0, true)


# Vector heart glyph: two circles + triangle, tinted by current health.
class HeartIcon:
	extends Control
	var tint := Color("#00b06f")

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.26
		var lobes := -r * 0.55  # Y offset of the two circle centers.
		draw_circle(c + Vector2(-r * 0.92, lobes), r, tint)
		draw_circle(c + Vector2(r * 0.92, lobes), r, tint)
		var pts := PackedVector2Array(
			[
				c + Vector2(-r * 1.9, lobes),
				c + Vector2(r * 1.9, lobes),
				c + Vector2(0.0, r * 1.85),
			]
		)
		draw_colored_polygon(pts, tint)


# Accent dot with a soft glow halo (objective marker).
class DotIcon:
	extends Control
	var tint := Color("#3d6df2")

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r * 1.8, Color(tint.r, tint.g, tint.b, 0.22))
		draw_circle(c, r * 0.95, tint)


func _ready() -> void:
	layer = 1
	_build_ui()
	_apply_world_settings()
	_try_bind_player()

	var retry := Timer.new()
	retry.wait_time = 1.0
	retry.autostart = true
	retry.timeout.connect(_try_bind_player)
	add_child(retry)

	var obj_timer := Timer.new()
	obj_timer.wait_time = 0.5
	obj_timer.autostart = true
	obj_timer.timeout.connect(_poll_objective)
	add_child(obj_timer)

	var fps_timer := Timer.new()
	fps_timer.wait_time = 0.5
	fps_timer.autostart = true
	fps_timer.timeout.connect(_poll_fps)
	add_child(fps_timer)

	GameState.achievement_unlocked.connect(_on_achievement)

	# Sembunyikan tombol duplikat bila TouchControls (joystick) aktif
	_hide_dup_actions.call_deferred()


func _exit_tree() -> void:
	Input.action_release("jump")
	Input.action_release("action_a")
	Input.action_release("sprint")


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Settings.get_theme()
	add_child(_root)

	# ---- Kiri-atas: kartu profil (nama + health) + chip FPS ----
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeft"
	top_left.add_theme_constant_override("separation", 6)
	top_left.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN)
	)
	top_left.grow_horizontal = Control.GROW_DIRECTION_END
	top_left.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(top_left)

	var profile := PanelContainer.new()
	profile.name = "ProfilePanel"
	profile.add_theme_stylebox_override("panel", _panel_sb(0.66, 14, 14.0, 10.0))
	top_left.add_child(profile)
	_profile_panel = profile

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 5)
	profile.add_child(pv)

	_name_label = Label.new()
	_name_label.text = String(GameState.player_name)
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	pv.add_child(_name_label)

	# Baris kesehatan: glyph hati vektor + bar dengan warna dinamis.
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(hp_row)

	_heart = HeartIcon.new()
	_heart.custom_minimum_size = Vector2(18.0, 18.0)
	_heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(_heart)

	var hp_holder := Control.new()
	hp_holder.custom_minimum_size = Vector2(192.0, 16.0)
	hp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(hp_holder)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.02, 0.03, 0.06, 0.55)
	hp_bg.set_corner_radius_all(12)
	_health_fill = StyleBoxFlat.new()
	_health_fill.bg_color = UiKit.COL_PLAY
	_health_fill.set_corner_radius_all(12)
	_health_fill.shadow_color = Color(1, 1, 1, 0.20)
	_health_fill.shadow_size = 1
	_health_bar.add_theme_stylebox_override("background", hp_bg)
	_health_bar.add_theme_stylebox_override("fill", _health_fill)
	hp_holder.add_child(_health_bar)

	_health_text = Label.new()
	_health_text.text = "100/100"
	_health_text.add_theme_font_size_override("font_size", 11)
	_health_text.add_theme_color_override("font_color", Color.WHITE)
	_health_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_health_text.add_theme_constant_override("shadow_offset_x", 1)
	_health_text.add_theme_constant_override("shadow_offset_y", 1)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_holder.add_child(_health_text)

	var fps_chip := UiKit.make_chip("60 FPS")
	fps_chip.name = "FpsChip"
	top_left.add_child(fps_chip)
	_fps_label = fps_chip.get_child(0) as Label
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))

	# ---- Kanan-atas: minimap + baris tombol ikon (pause/build/chat) ----
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_col.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN)
	)
	right_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_col.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(right_col)

	_minimap = MinimapScript.new()
	right_col.add_child(_minimap)

	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 8)
	right_col.add_child(icon_row)

	icon_row.add_child(_icon_button("pause", _t("hud_pause", "Jeda", "Pause"), _on_pause))
	_build_btn = _icon_button("build", _t("hud_build", "Bangun", "Build"), _on_build)
	icon_row.add_child(_build_btn)
	icon_row.add_child(_icon_button("chat", _t("hud_chat", "Chat", "Chat"), _on_chat))

	# ---- Tengah-atas: objective (poll mode_controller) ----
	_objective = PanelContainer.new()
	_objective.name = "ObjectivePanel"
	_objective.add_theme_stylebox_override("panel", _panel_sb(0.55, UiKit.CORNER, 14.0, 8.0))
	_objective.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(MARGIN)
	)
	_objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective.grow_vertical = Control.GROW_DIRECTION_END
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.visible = false
	_root.add_child(_objective)

	var obj_row := HBoxContainer.new()
	obj_row.add_theme_constant_override("separation", 8)
	obj_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.add_child(obj_row)

	var obj_dot := DotIcon.new()
	obj_dot.custom_minimum_size = Vector2(10.0, 10.0)
	obj_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	obj_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_row.add_child(obj_dot)

	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 15)
	_objective_label.add_theme_color_override("font_color", Color.WHITE)
	_objective_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_objective_label.add_theme_constant_override("outline_size", 2)
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_objective_label.add_theme_constant_override("shadow_offset_x", 1)
	_objective_label.add_theme_constant_override("shadow_offset_y", 1)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_row.add_child(_objective_label)

	# ---- Kanan-bawah: kolom kontrol gerak ----
	_right_ctl = VBoxContainer.new()
	var right_ctl: VBoxContainer = _right_ctl
	right_ctl.add_theme_constant_override("separation", 10)
	right_ctl.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN)
	)
	right_ctl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_ctl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(right_ctl)

	var jump_btn := UiKit.make_button_color(
		_t("hud_jump", "Lompat", "Jump"), UiKit.COL_ACCENT, Vector2(132.0, 64.0)
	)
	jump_btn.button_down.connect(func() -> void: Input.action_press("jump"))
	jump_btn.button_up.connect(func() -> void: Input.action_release("jump"))
	right_ctl.add_child(jump_btn)

	var sprint_btn := UiKit.make_button_color(
		_t("hud_sprint", "Lari", "Sprint"), UiKit.COL_PLAY, Vector2(132.0, 56.0)
	)
	sprint_btn.toggle_mode = true
	sprint_btn.toggled.connect(_on_sprint_toggled)
	right_ctl.add_child(sprint_btn)

	var action_btn := UiKit.make_button_secondary(
		_t("hud_action", "Aksi", "Action"), Vector2(132.0, 56.0)
	)
	action_btn.button_down.connect(func() -> void: Input.action_press("action_a"))
	action_btn.button_up.connect(func() -> void: Input.action_release("action_a"))
	right_ctl.add_child(action_btn)

	# ---- Kiri-bawah: baris tombol kecil DI ATAS area joystick (offset bawah 150px) ----
	var left_row := HBoxContainer.new()
	left_row.add_theme_constant_override("separation", 8)
	left_row.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN)
	)
	left_row.grow_horizontal = Control.GROW_DIRECTION_END
	left_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left_row.offset_bottom -= JOYSTICK_CLEARANCE
	left_row.offset_top -= JOYSTICK_CLEARANCE
	_root.add_child(left_row)

	left_row.add_child(_small_button(_t("hud_emote", "Emote", "Emote"), _on_emote))
	left_row.add_child(_small_button(_t("hud_shot", "Foto", "Photo"), _on_screenshot))
	_weather_btn = _small_button(_t("hud_weather", "Cuaca", "Weather"), _on_weather)
	left_row.add_child(_weather_btn)


## Panel glass semi-transparan: radius besar, border halus, bayangan lembut.
func _panel_sb(alpha: float, radius: int, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.07, 0.12, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


func _poll_fps() -> void:
	if _fps_label == null or not is_instance_valid(_fps_label):
		return

		# Diakhiri "FPS" agar tangkapan demo (game_state.gd) menyembunyikan chip ini.

		# Kode warna budget scene: putih <=100k, kuning <=200k, merah >200k.
	var fps := Engine.get_frames_per_second()
	var tris := PolyBudget.estimate_onscreen_tris()
	# Diakhiri "FPS" agar tangkapan demo (game_state.gd) menyembunyikan chip ini.
	_fps_label.text = "%s tris • %d FPS" % [_fmt_tris(tris), fps]
	# Kode warna budget scene: putih <=100k, kuning <=200k, merah >200k.
	var lvl := PolyBudget.scene_level(tris)
	var col := Color(1, 1, 1, 0.78)
	if lvl == 1:
		col = Color(1.0, 0.82, 0.35)
	elif lvl == 2:
		col = Color(1.0, 0.45, 0.38)
	_fps_label.add_theme_color_override("font_color", col)


## Format ringkas jumlah tris: 840 -> "840", 8400 -> "8.4k", 125000 -> "125k",
## 1240000 -> "1.2M" (mengikuti gaya counter poly tooling game engine).
func _fmt_tris(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (float(n) / 1_000_000.0)
	if n >= 10_000:
		return "%dk" % (n / 1000)
	if n >= 1_000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)


## Tombol ikon bulat: glass gelap, glyph vektor, highlight glossy di atas.
func _icon_button(kind: String, hint: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = ""
	b.tooltip_text = hint
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ICON_BTN, ICON_BTN)

	var gloss := GlassGloss.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(gloss)

	var glyph := GlyphIcon.new()
	glyph.kind = kind
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 9.0
	glyph.offset_top = 9.0
	glyph.offset_right = -9.0
	glyph.offset_bottom = -9.0
	b.add_child(glyph)

	b.add_theme_stylebox_override("normal", _glass_sb(GLASS_BG, ICON_BTN))
	b.add_theme_stylebox_override("hover", _glass_sb(GLASS_HOVER, ICON_BTN))
	b.add_theme_stylebox_override("pressed", _glass_sb(GLASS_PRESSED, ICON_BTN, true))
	b.add_theme_stylebox_override("disabled", _glass_sb(Color(0.3, 0.33, 0.4, 0.5), ICON_BTN))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(handler)
	UiKit.attach_press_animation(b)
	return b


## Lingkaran glass gelap: border putih tipis + drop shadow; margin konten
## menyusut saat pressed (kesan "tertekan").
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


## Pil kecil glass untuk aksi sekunder (emote/foto/cuaca).
func _small_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, BTN_MIN)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _pill_sb(GLASS_BG))
	b.add_theme_stylebox_override("hover", _pill_sb(GLASS_HOVER))
	b.add_theme_stylebox_override("pressed", _pill_sb(GLASS_PRESSED, true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.pressed.connect(handler)
	UiKit.attach_press_animation(b)
	return b


func _pill_sb(base: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	if pressed:
		sb.content_margin_left = 15.0
		sb.content_margin_right = 15.0
	else:
		sb.content_margin_left = 16.0
		sb.content_margin_right = 16.0
	return sb


func _apply_world_settings() -> void:
	var settings := _world_settings()
	if _profile_panel != null:
		_profile_panel.visible = bool(settings.get("health_enabled", true))
	if _build_btn != null:
		_build_btn.visible = bool(settings.get("build_allowed", true))
	if _weather_btn != null:
		_weather_btn.visible = (not GameState.is_multiplayer()) or GameState.is_host()


func _world_settings() -> Dictionary:
	var cw: Variant = GameState.current_world
	if typeof(cw) != TYPE_DICTIONARY:
		return {}
	var s: Variant = cw.get("settings", {})
	return s if typeof(s) == TYPE_DICTIONARY else {}


# ------------------------------------------------------------- health binding


func _try_bind_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var nodes := get_tree().get_nodes_in_group("local_player")
	if nodes.is_empty():
		return
	var p: Node = nodes[0]
	_player = p
	if p.has_signal("health_changed"):
		if not p.is_connected("health_changed", _on_health_changed):
			p.connect("health_changed", _on_health_changed)
		var hp: Variant = p.get("health")
		var max_hp: Variant = p.get("max_health")
		_set_health(float(hp) if hp != null else 100.0, float(max_hp) if max_hp != null else 100.0)
	if p.has_signal("died"):
		if not p.is_connected("died", _on_player_died):
			p.connect("died", _on_player_died)


func _on_health_changed(hp: float, max_hp: float) -> void:
	_set_health(hp, max_hp)


func _on_player_died() -> void:
	_set_health(0.0, _health_bar.max_value)


func _set_health(hp: float, max_hp: float) -> void:
	if _health_bar == null:
		return
	var mx := maxf(max_hp, 1.0)
	_health_bar.max_value = mx
	_health_bar.value = clampf(hp, 0.0, mx)
	_health_text.text = "%d/%d" % [int(round(hp)), int(round(mx))]
	var ratio := clampf(_health_bar.value / mx, 0.0, 1.0)
	var col := _health_color(ratio)
	if _health_fill != null:
		_health_fill.bg_color = col
	if _heart != null:
		_heart.tint = col


## Warna kesehatan per rasio: hijau > 60%, oranye 30-60%, merah < 30%.
func _health_color(ratio: float) -> Color:
	if ratio > 0.6:
		return UiKit.COL_PLAY
	if ratio >= 0.3:
		return UiKit.COL_WARN
	return UiKit.COL_DANGER


# ------------------------------------------------------------------- actions


func _on_pause() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("request_pause"):
		game.call("request_pause")
	else:
		Toast.show(
			self,
			_t("hud_pause_unavailable", "Menu jeda belum tersedia", "Pause menu is not available")
		)


func _on_sprint_toggled(pressed: bool) -> void:
	if pressed:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _on_chat() -> void:
	var chat := _find_chat_overlay()
	if chat != null and chat.has_method("toggle"):
		chat.call("toggle")
	else:
		Toast.show(self, _t("hud_chat_unavailable", "Chat belum tersedia", "Chat is not available"))


func _on_emote() -> void:
	var chat := _find_chat_overlay()
	if chat != null and chat.has_method("open_emotes"):
		chat.call("open_emotes")
	else:
		Toast.show(
			self, _t("hud_emote_unavailable", "Emote belum tersedia", "Emotes are not available")
		)


func _on_screenshot() -> void:
	var path := Screenshot.capture(self)
	if path == "":
		Toast.show(
			self,
			_t("error_generic", "Terjadi kesalahan. Coba lagi.", "Something went wrong. Try again.")
		)
	else:
		Toast.show(self, path)


func _on_build() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("toggle_build_mode"):
		game.call("toggle_build_mode")
	else:
		Toast.show(
			self,
			_t("hud_build_unavailable", "Mode bangun belum tersedia", "Build mode is not available")
		)


func _on_weather() -> void:
	var weather := get_tree().get_first_node_in_group("env_weather")
	if weather == null:
		Toast.show(
			self, _t("hud_weather_unavailable", "Cuaca belum tersedia", "Weather is not available")
		)
		return
	if weather.has_method("cycle_weather"):
		weather.call("cycle_weather")
	var w := ""
	if weather.has_method("get_weather"):
		w = String(weather.call("get_weather"))
	Toast.show(self, _t("hud_weather_now", "Cuaca", "Weather") + ": " + _weather_label(w))


func _weather_label(w: String) -> String:
	match w:
		"rain":
			return _t("weather_rain", "Hujan", "Rain")
		"fog":
			return _t("weather_fog", "Berkabut", "Fog")
		"snow":
			return _t("weather_snow", "Salju", "Snow")
	return _t("weather_clear", "Cerah", "Clear")


func _on_achievement(id: String, _title: String) -> void:
	var label := String(Locale.t("ach_" + id))
	if label == "ach_" + id:
		label = String(id).replace("_", " ").capitalize()
	Toast.show(self, label + " +1")


func _poll_objective() -> void:
	var text := ""
	var mc := get_tree().get_first_node_in_group("mode_controller")
	if mc != null and mc.has_method("get_objective_text"):
		text = String(mc.call("get_objective_text"))
	if _objective_label != null:
		_objective_label.text = text
	if _objective != null:
		_objective.visible = text != ""


func _find_chat_overlay() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	if tree.root.has_node("ChatOverlay"):
		return tree.root.get_node("ChatOverlay")
	return _find_node_by_name(tree.root, "ChatOverlay")


func _find_node_by_name(node: Node, target: String) -> Node:
	for child in node.get_children():
		if String(child.name) == target:
			return child
		var found := _find_node_by_name(child, target)
		if found != null:
			return found
	return null


func _hide_dup_actions() -> void:
	if _right_ctl == null:
		return
	var tc := get_tree().get_first_node_in_group("touch_controls")
	if tc != null:
		_right_ctl.visible = false


func _t(key: String, fb_id: String, fb_en: String) -> String:
	var s := String(Locale.t(key))
	if s != key:
		return s
	return fb_en if Locale.get_language() == "en" else fb_id
