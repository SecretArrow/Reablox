class_name ToolBase
extends Node
## ToolBase — dasar semua tool yang bisa dipegang pemain (pedang, kuas cat).
## Tool tidak tahu UI; cukup equip/unequip lalu activate() saat dipakai.

var tool_name := ""
var _player: Node3D = null


## Ikat tool ke pemain yang memegangnya.
func equip(player: Node3D) -> void:
	_player = player


## Lepas ikatan tool dari pemain.
func unequip() -> void:
	_player = null


## Virtual: aksi utama tool (tebas, tembak, cat). Anak menimpa bila perlu.
func activate() -> void:
	pass


func has_player() -> bool:
	return _player != null and is_instance_valid(_player)
