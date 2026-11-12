class_name Hud
extends Control
## Hud — HUD in-game ala Roblox: health bar kanan-atas, koin & tahap kiri-atas,
## hotbar 9 slot bawah-tengah, toast tengah-atas, dan tombol menu.
## Seluruh tata letak dibangun lewat kode di _ready() dan otomatis tersinkron
## dengan sinyal GameEvents (player_health_changed, coins_changed, dst.).

signal menu_requested
signal hotbar_slot_clicked(slot: int)

const COLOR_HEALTH_GREEN := Color(0.30, 0.85, 0.30)
const COLOR_HEALTH_YELLOW := Color(0.95, 0.85, 0.25)
const COLOR_HEALTH_RED := Color(0.90, 0.25, 0.25)
const COLOR_ACCENT := Color(1.00, 0.82, 0.30)

const HEALTH_BAR_WIDTH := 220.0
const TOAST_DURATION := 2.0
const SLOT_SIZE := 56.0

var _health_fill: ColorRect
var _health_label: Label
var _coins_label: Label
var _stage_label: Label
var _toast_label: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _hotbar_selected := -1
var _toast_token := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_health_bar()
	_build_toast()
	_build_hotbar()
	_connect_events()
	update_health(GameConfig.MAX_HEALTH, GameConfig.MAX_HEALTH)
	update_coins(GameState.coins)
	update_stage(GameState.stage)


## Kolom kiri-atas: tombol Menu, label koin, label tahap.
func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.name = "TopLeft"
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(12.0, 12.0)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "Menu"
	menu_button.pressed.connect(_on_menu_pressed)
	box.add_child(menu_button)

	_coins_label = Label.new()
	_coins_label.name = "CoinsLabel"
	_coins_label.text = "Koin: 0"
	box.add_child(_coins_label)

	_stage_label = Label.new()
	_stage_label.name = "StageLabel"
	_stage_label.text = "Tahap 1"
	box.add_child(_stage_label)


## Health bar kanan-atas: PanelContainer + isian ColorRect proporsional.
func _build_health_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "HealthPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.custom_minimum_size = Vector2(HEALTH_BAR_WIDTH, 26.0)
	add_child(panel)

	var track := Control.new()
	track.name = "HealthTrack"
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(track)

	_health_fill = ColorRect.new()
	_health_fill.name = "HealthFill"
	_health_fill.color = COLOR_HEALTH_GREEN
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_fill.anchor_top = 0.0
	_health_fill.anchor_bottom = 1.0
	track.add_child(_health_fill)

	_health_label = Label.new()
	_health_label.name = "HealthLabel"
	_health_label.text = "100/100"
	_health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_health_label)


## Label toast tengah-atas (tersembunyi sampai show_toast dipanggil).
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.offset_top = 48
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.visible = false
	add_child(_toast_label)


## Baris hotbar 9 kotak (PanelContainer 56x56) bawah-tengah.
func _build_hotbar() -> void:
	var row := HBoxContainer.new()
	row.name = "HotbarRow"
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in range(GameConfig.MAX_HOTBAR):
		row.add_child(_make_slot(i))


func _make_slot(slot: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % slot
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_gui_input.bind(slot))

	var label := Label.new()
	label.name = "SlotLabel"
	label.text = str(slot + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_slot_panels.append(panel)
	_slot_labels.append(label)
	return panel


func _connect_events() -> void:
	GameEvents.player_health_changed.connect(_on_player_health_changed)
	GameEvents.coins_changed.connect(_on_coins_changed)
	GameEvents.stage_changed.connect(_on_stage_changed)
	GameEvents.tool_equipped.connect(_on_tool_equipped)
	GameEvents.tool_unequipped.connect(_on_tool_unequipped)
	GameEvents.toast_requested.connect(_on_toast_requested)


## Perbarui health bar: teks "cur/max", lebar isian proporsional, dan warna
## hijau (>50%) → kuning (25-50%) → merah (<25%).
func update_health(cur: float, max: float) -> void:
	var maximum := maxf(max, 0.001)
	var ratio := clampf(cur / maximum, 0.0, 1.0)
	_health_fill.color = _health_color_for(ratio)
	_health_fill.offset_right = HEALTH_BAR_WIDTH * ratio
	_health_label.text = "%d/%d" % [int(round(cur)), int(round(maximum))]


func _health_color_for(ratio: float) -> Color:
	if ratio > 0.5:
		return COLOR_HEALTH_GREEN
	if ratio >= 0.25:
		return COLOR_HEALTH_YELLOW
	return COLOR_HEALTH_RED


func update_coins(total: int) -> void:
	_coins_label.text = "Koin: %d" % total


func update_stage(stage: int) -> void:
	_stage_label.text = "Tahap %d" % stage


## Tampilkan toast selama TOAST_DURATION detik; token mencegah toast lama
## menutup toast baru yang lebih baru.
func show_toast(text: String) -> void:
	_toast_token += 1
	_toast_label.text = text
	_toast_label.visible = true
	var timer := get_tree().create_timer(TOAST_DURATION)
	timer.timeout.connect(_on_toast_timeout.bind(_toast_token))


## Isi ikon/teks pada slot hotbar (0..8).
func set_hotbar_slot(slot: int, text: String) -> void:
	if slot < 0 or slot >= _slot_labels.size():
		return
	_slot_labels[slot].text = text


func get_health_label() -> String:
	return _health_label.text


## Warna isian health bar saat ini (untuk test).
func get_health_color() -> Color:
	return _health_fill.color


func get_coins_label() -> String:
	return _coins_label.text


func get_stage_label() -> String:
	return _stage_label.text


func get_hotbar_slot_text(slot: int) -> String:
	if slot < 0 or slot >= _slot_labels.size():
		return ""
	return _slot_labels[slot].text


func get_hotbar_selected() -> int:
	return _hotbar_selected


func is_toast_visible() -> bool:
	return _toast_label.visible


## Sorot slot aktif dengan modulate warna aksen.
func _refresh_slot_highlight() -> void:
	for i in range(_slot_panels.size()):
		if i == _hotbar_selected:
			_slot_panels[i].modulate = COLOR_ACCENT
		else:
			_slot_panels[i].modulate = Color.WHITE


func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		hotbar_slot_clicked.emit(slot)


func _on_toast_timeout(token: int) -> void:
	if token == _toast_token:
		_toast_label.visible = false


func _on_player_health_changed(cur: float, maximum: float) -> void:
	update_health(cur, maximum)


func _on_coins_changed(total: int) -> void:
	update_coins(total)


func _on_stage_changed(stage: int) -> void:
	update_stage(stage)


func _on_tool_equipped(slot: int) -> void:
	_hotbar_selected = slot
	_refresh_slot_highlight()


func _on_tool_unequipped() -> void:
	_hotbar_selected = -1
	_refresh_slot_highlight()


func _on_toast_requested(message: String) -> void:
	show_toast(message)
