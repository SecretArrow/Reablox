extends Node
## Suite combat: tool (pedang, kuas cat), NPC (base + monster: patrol/chase/
## attack), hotbar 9 slot dengan sinyal GameEvents. Lantai + player nyata.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node

var _died_flag := false
var _died_name := ""
var _equip_flag := false
var _equip_slot := -1
var _unequip_flag := false
var _use_flag := false
var _use_slot := -1


class StubManager:
	extends Node
	## Stub BuildManager: catat panggilan recolor_part dan selalu berhasil.
	var calls := 0

	func recolor_part(_part_id: int, _color_hex: String) -> bool:
		calls += 1
		return true


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	GameEvents.npc_died.connect(_on_npc_died)
	GameEvents.tool_equipped.connect(_on_tool_equipped)
	GameEvents.tool_unequipped.connect(_on_tool_unequipped)
	GameEvents.tool_used.connect(_on_tool_used)
	await _run_tests()
	fw.finish()


func _on_npc_died(nama: String) -> void:
	_died_flag = true
	_died_name = nama


func _on_tool_equipped(slot: int) -> void:
	_equip_flag = true
	_equip_slot = slot


func _on_tool_unequipped() -> void:
	_unequip_flag = true


func _on_tool_used(slot: int) -> void:
	_use_flag = true
	_use_slot = slot


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameConfig.LAYER_WORLD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)
	add_child(floor_body)


func _make_player() -> PlayerController:
	var player := load("res://scenes/player.tscn").instantiate() as PlayerController
	player.position = Vector3(0.0, 3.0, 0.0)
	add_child(player)
	return player


func _run_tests() -> void:
	_make_floor()
	var player := _make_player()
	await _physics(30)
	fw.check("player mendarat di lantai", player.is_on_floor())
	await _test_npc_base()
	await _test_monster(player)
	await _test_sword(player)
	_test_hotbar(player)
	_test_paint()
	player.queue_free()


func _test_npc_base() -> void:
	fw.section("NPC base")
	var npc := NpcBase.new()
	npc.position = Vector3(10.0, 3.0, 0.0)
	add_child(npc)
	await _physics(20)
	fw.check("npc base jatuh lalu mendarat", npc.is_on_floor())
	fw.check_eq("collision_layer = LAYER_NPC", npc.collision_layer, GameConfig.LAYER_NPC)
	fw.check_eq("collision_mask = LAYER_WORLD", npc.collision_mask, GameConfig.LAYER_WORLD)
	npc.damage(20.0)
	fw.check_eq("damage 20 → health 30", npc.health, 30.0)
	npc.damage(999.0)
	fw.check("damage 999 → mati", npc.is_dead())
	fw.check("mati → antre dihapus", npc.is_queued_for_deletion())
	fw.check("sinyal npc_died teremit", _died_flag)
	fw.check_eq("nama npc_died cocok", _died_name, "NPC")


func _test_monster(player: PlayerController) -> void:
	fw.section("NPC monster")
	var mon := NpcMonster.new()
	mon.position = Vector3(20.0, 3.0, 0.0)
	mon.set_waypoints([Vector3(20.0, 3.0, 0.0), Vector3(30.0, 3.0, 0.0)])
	add_child(mon)
	await _physics(30)
	fw.check_gt("patrol bergerak ke arah waypoint (x > 12)", mon.global_position.x, 12.0)
	fw.check_eq("state saat patrol", mon.get_state(), "patrol")
	fw.check_eq("health monster 60", mon.health, 60.0)

	# Target jauh (~60 studs) → tetap patrol.
	player.global_position = Vector3(80.0, 3.0, 0.0)
	mon.set_target(player)
	await _physics(5)
	fw.check_eq("target jauh → tetap patrol", mon.get_state(), "patrol")

	# Target masuk jangkauan kejar → chase dan jarak menurun.
	player.global_position = Vector3(12.0, 3.0, 0.0)
	var dist_before := mon.global_position.distance_to(player.global_position)
	await _physics(20)
	var dist_after := mon.global_position.distance_to(player.global_position)
	fw.check_eq("target dekat → chase", mon.get_state(), "chase")
	fw.check("chase mendekatkan monster", dist_after < dist_before)

	# Target di samping → attack dan melukai pemain.
	player.global_position = mon.global_position + Vector3(2.5, 0.0, 0.0)
	await _physics(30)
	fw.check_eq("target sangat dekat → attack", mon.get_state(), "attack")
	fw.check("pemain terluka (health < 100)", player.get_health() < 100.0)
	fw.check_gte("jumlah serangan >= 1", mon.get_attack_count(), 1)
	mon.set_target(null)


func _test_sword(player: PlayerController) -> void:
	fw.section("Pedang")
	player.global_position = Vector3(0.0, 3.0, 0.0)
	player.rotation_degrees = Vector3.ZERO
	var mon := NpcMonster.new()
	mon.position = Vector3(0.0, 3.0, -3.0)
	add_child(mon)
	await _physics(5)
	var sword := SwordTool.new()
	add_child(sword)
	sword.equip(player)
	sword.activate()
	fw.check_eq("tebasan 1 → health monster 30", mon.health, 30.0)
	fw.check_eq("hit tercatat 1", sword.get_hits(), 1)
	sword.activate()
	fw.check("tebasan 2 → monster mati", mon.is_dead())
	fw.check("monster mati → antre dihapus", mon.is_queued_for_deletion())
	fw.check_eq("total hit 2", sword.get_hits(), 2)
	await _physics(3)
	sword.activate()
	fw.check("ayunan ke ruang kosong: hits tetap 2", sword.get_hits() == 2)
	var bare := SwordTool.new()
	add_child(bare)
	bare.activate()
	fw.check_eq("tanpa equip → tidak crash, hits 0", bare.get_hits(), 0)
	fw.check_eq("nama tool pedang", sword.tool_name, "Pedang")


func _test_hotbar(player: PlayerController) -> void:
	fw.section("Hotbar")
	var hb := Hotbar.new()
	add_child(hb)
	hb.set_player(player)
	var t0 := SwordTool.new()
	var t1 := SwordTool.new()
	var t2 := PaintTool.new()
	fw.check("assign slot 0 ok", hb.assign(t0, 0))
	fw.check("assign slot 1 ok", hb.assign(t1, 1))
	fw.check("assign slot 2 ok", hb.assign(t2, 2))
	fw.check("assign slot 9 ditolak", not hb.assign(SwordTool.new(), 9))
	fw.check("assign slot -1 ditolak", not hb.assign(SwordTool.new(), -1))
	fw.check("assign tool null ditolak", not hb.assign(null, 3))
	fw.check_eq("slot aktif awal -1", hb.get_active_slot(), -1)
	fw.check("equip(9) ditolak", not hb.equip(9))

	_equip_flag = false
	fw.check("equip slot 1 sukses", hb.equip(1))
	fw.check("sinyal tool_equipped teremit", _equip_flag)
	fw.check_eq("slot pada sinyal = 1", _equip_slot, 1)
	fw.check("tool 1 terikat player", t1.has_player())
	fw.check("tool 0 belum terikat", not t0.has_player())

	_use_flag = false
	fw.check("activate_current sukses", hb.activate_current())
	fw.check("sinyal tool_used teremit", _use_flag)
	fw.check_eq("slot pada tool_used = 1", _use_slot, 1)

	_unequip_flag = false
	fw.check("equip slot 2 sukses", hb.equip(2))
	fw.check("sinyal tool_unequipped teremit", _unequip_flag)
	fw.check("tool 1 dilepas", not t1.has_player())
	fw.check("tool 2 terikat player", t2.has_player())

	hb.remove(2)
	fw.check("remove(2) → slot kosong", hb.get_tool(2) == null)
	fw.check_eq("slot aktif -1 setelah remove", hb.get_active_slot(), -1)
	fw.check("activate_current tanpa aktif → false", not hb.activate_current())


func _test_paint() -> void:
	fw.section("Kuas cat")
	var bare := PaintTool.new()
	add_child(bare)
	fw.check("tanpa manager → paint false", not bare.paint(1, "#00ff00"))
	fw.check_eq("nama tool kuas", bare.tool_name, "Kuas Cat")

	var paint := PaintTool.new()
	add_child(paint)
	var stub := StubManager.new()
	add_child(stub)
	paint.set_build_manager(stub)
	fw.check("paint(7, merah) → true", paint.paint(7, "#ff0000"))
	fw.check_eq("manager terpanggil 1x", stub.calls, 1)
	fw.check_eq("jumlah painted 1", paint.painted, 1)
	paint.activate()
	fw.check_eq("activate tanpa target: painted tetap 1", paint.painted, 1)
