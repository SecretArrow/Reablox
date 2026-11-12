extends Node
## Suite unit HUD: Hud (health/koin/tahap/hotbar/toast + sinyal GameEvents),
## EscapeMenu, ChatOverlay, dan NameTag. Mengikuti pola framework test standar.
## Skrip di-preload langsung agar tidak bergantung pada cache class global.

const FW := preload("res://tools/tests/test_framework.gd")
const HudScript := preload("res://scripts/ui/hud/hud.gd")
const EscapeMenuScript := preload("res://scripts/ui/hud/escape_menu.gd")
const ChatOverlayScript := preload("res://scripts/ui/hud/chat_overlay.gd")
const NameTagScript := preload("res://scripts/ui/hud/name_tag.gd")

var fw: Node

var _flag_resume := false
var _flag_chat_submitted := false
var _chat_submitted_text := ""
var _flag_chat_toggled := false


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	await _test_hud()
	_test_escape_menu()
	_test_chat_overlay()
	_test_name_tag()


func _on_resume_requested() -> void:
	_flag_resume = true


func _on_chat_submitted(text: String) -> void:
	_flag_chat_submitted = true
	_chat_submitted_text = text


func _on_chat_toggled() -> void:
	_flag_chat_toggled = true


func _test_hud() -> void:
	fw.section("Hud")
	# Reset leaderstats agar tidak terpengaruh sesi/urutan suite lain.
	GameState.coins = 0
	GameState.stage = 1
	var hud: HudScript = HudScript.new()
	add_child(hud)
	fw.check_eq("label koin awal", hud.get_coins_label(), "Koin: 0")
	fw.check_eq("label health awal", hud.get_health_label(), "100/100")
	fw.check_eq("label tahap awal", hud.get_stage_label(), "Tahap 1")

	hud.update_health(70.0, 100.0)
	fw.check_eq("health 70 → teks 70/100", hud.get_health_label(), "70/100")
	fw.check_eq("70% → warna hijau", hud.get_health_color(), HudScript.COLOR_HEALTH_GREEN)
	fw.check("hijau bukan merah", hud.get_health_color() != HudScript.COLOR_HEALTH_RED)
	hud.update_health(40.0, 100.0)
	fw.check_eq("40% → warna kuning", hud.get_health_color(), HudScript.COLOR_HEALTH_YELLOW)
	hud.update_health(20.0, 100.0)
	fw.check_eq("20% → warna merah", hud.get_health_color(), HudScript.COLOR_HEALTH_RED)

	hud.update_coins(15)
	fw.check_eq("koin 15", hud.get_coins_label(), "Koin: 15")
	hud.update_stage(3)
	fw.check_eq("tahap 3", hud.get_stage_label(), "Tahap 3")

	GameEvents.coins_changed.emit(42)
	fw.check_eq("sinyal coins_changed → label ikut", hud.get_coins_label(), "Koin: 42")

	fw.check_eq("slot terpilih awal -1", hud.get_hotbar_selected(), -1)
	hud.set_hotbar_slot(3, "Pedang")
	fw.check_eq("set_hotbar_slot(3) → teks slot", hud.get_hotbar_slot_text(3), "Pedang")
	GameEvents.tool_equipped.emit(2)
	fw.check_eq("sinyal tool_equipped(2) → selected 2", hud.get_hotbar_selected(), 2)
	GameEvents.tool_unequipped.emit()
	fw.check_eq("sinyal tool_unequipped → selected -1", hud.get_hotbar_selected(), -1)

	hud.show_toast("tes")
	fw.check("toast tampil", hud.is_toast_visible())
	await get_tree().create_timer(2.3).timeout
	fw.check("toast hilang setelah ~2.2 dtk", not hud.is_toast_visible())
	hud.queue_free()


func _test_escape_menu() -> void:
	fw.section("EscapeMenu")
	var menu: EscapeMenuScript = EscapeMenuScript.new()
	add_child(menu)
	fw.check("default tersembunyi", not menu.visible)
	menu.open()
	fw.check("open() → tampil", menu.visible)
	fw.check("is_open() benar", menu.is_open())
	menu.toggle()
	fw.check("toggle() menutup", not menu.is_open())

	var buttons := menu.find_children("*", "Button", true, false)
	fw.check_eq("keempat tombol ada", buttons.size(), 4)

	_flag_resume = false
	menu.resume_requested.connect(_on_resume_requested)
	var btn_resume := _find_button_by_text(buttons, "Lanjut")
	fw.check_not_null("tombol Lanjut ditemukan", btn_resume)
	if btn_resume != null:
		btn_resume.pressed.emit()
	fw.check("tombol Lanjut → resume_requested teremit", _flag_resume)
	menu.queue_free()


func _find_button_by_text(buttons: Array, label: String) -> Button:
	for b in buttons:
		var btn := b as Button
		if btn != null and btn.text == label:
			return btn
	return null


func _test_chat_overlay() -> void:
	fw.section("ChatOverlay")
	var chat: ChatOverlayScript = ChatOverlayScript.new()
	add_child(chat)
	chat.add_message("Budi", "halo")
	chat.add_message("Sinta", "hai juga")
	fw.check_eq("add_message 2x → jumlah 2", chat.get_message_count(), 2)
	GameEvents.chat_message_received.emit("Budi", "halo")
	fw.check_eq("sinyal chat → jumlah 3", chat.get_message_count(), 3)

	fw.check("input awal tersembunyi", not chat.is_input_visible())
	chat.toggle()
	fw.check("toggle() → input tampil", chat.is_input_visible())

	_flag_chat_submitted = false
	_chat_submitted_text = ""
	chat.chat_submitted.connect(_on_chat_submitted)
	var inputs := chat.find_children("*", "LineEdit", true, false)
	fw.check_eq("satu LineEdit ditemukan", inputs.size(), 1)
	var line_edit := inputs[0] as LineEdit
	if line_edit != null:
		line_edit.text_submitted.emit("hai")
	fw.check("submit → chat_submitted teremit", _flag_chat_submitted)
	fw.check_eq("teks submit cocok", _chat_submitted_text, "hai")
	fw.check("input tersembunyi setelah submit", not chat.is_input_visible())
	fw.check_eq("teks input dikosongkan", "" if line_edit == null else line_edit.text, "")

	_flag_chat_toggled = false
	chat.chat_toggled.connect(_on_chat_toggled)
	var chat_buttons := chat.find_children("*", "Button", true, false)
	fw.check_eq("tombol chat ada", chat_buttons.size(), 1)
	if chat_buttons.size() > 0:
		(chat_buttons[0] as Button).pressed.emit()
	fw.check("tombol chat → chat_toggled teremit", _flag_chat_toggled)

	for i in range(10):
		chat.add_message("Spam", "pesan %d" % i)
	fw.check_eq("maks 8 pesan terlihat (lama dihapus)", chat.get_message_count(), 8)
	chat.queue_free()


func _test_name_tag() -> void:
	fw.section("NameTag")
	var parent := Node3D.new()
	add_child(parent)
	var tag: NameTagScript = NameTagScript.make(parent, "Budi")
	fw.check_not_null("make() mengembalikan tag", tag)
	fw.check("tag menjadi anak parent", tag.get_parent() == parent)
	fw.check_eq("teks tag", tag.text, "Budi")
	fw.check("posisi y == 6.2", is_equal_approx(tag.position.y, 6.2))
	fw.check_eq("billboard aktif", tag.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	tag.set_display_name("Sinta")
	fw.check_eq("set_display_name cocok", tag.get_display_name(), "Sinta")
	parent.queue_free()
