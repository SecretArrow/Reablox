class_name Hotbar
extends Node
## Hotbar — 9 slot tool ala Roblox: assign, equip, aktivasi.
## Komunikasi lintas modul lewat sinyal GameEvents.tool_*.

var _slots: Array = []
var _active := -1
var _player: Node3D = null


func _init() -> void:
	_slots.resize(GameConfig.MAX_HOTBAR)
	for i in range(_slots.size()):
		_slots[i] = null


func set_player(p: Node3D) -> void:
	_player = p


## Taruh tool di slot (0..8); tool wajib punya metode activate().
func assign(tool: Node, slot: int) -> bool:
	if slot < 0 or slot >= _slots.size():
		return false
	if tool == null or not tool.has_method("activate"):
		return false
	_slots[slot] = tool
	return true


## Kosongkan slot; bila slot itu sedang aktif, unequip dulu.
func remove(slot: int) -> void:
	if slot < 0 or slot >= _slots.size():
		return
	_slots[slot] = null
	if _active == slot:
		_unequip_current()


## Aktifkan slot (pegang tool); emit tool_equipped bila sukses.
func equip(slot: int) -> bool:
	if slot < 0 or slot >= _slots.size():
		return false
	if _slots[slot] == null:
		return false
	_unequip_current()
	_active = slot
	var tool: Node = _slots[slot]
	if tool.has_method("equip"):
		tool.equip(_player)
	GameEvents.tool_equipped.emit(slot)
	return true


## Pakai tool aktif; emit tool_used bila sukses.
func activate_current() -> bool:
	if _active < 0 or _active >= _slots.size():
		return false
	var tool: Node = _slots[_active]
	if tool == null:
		return false
	tool.activate()
	GameEvents.tool_used.emit(_active)
	return true


## Lepas tool aktif: panggil unequip + emit tool_unequipped bila ada tool.
func _unequip_current() -> void:
	if _active < 0 or _active >= _slots.size():
		return
	var tool: Node = _slots[_active]
	_active = -1
	if tool == null:
		return
	if tool.has_method("unequip"):
		tool.unequip()
	GameEvents.tool_unequipped.emit()


func get_active_slot() -> int:
	return _active


func get_tool(slot: int) -> Node:
	if slot < 0 or slot >= _slots.size():
		return null
	return _slots[slot]


func is_assigned(slot: int) -> bool:
	if slot < 0 or slot >= _slots.size():
		return false
	return _slots[slot] != null
