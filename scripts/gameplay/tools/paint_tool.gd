class_name PaintTool
extends ToolBase
## PaintTool — kuas cat: mewarnai part build lewat BuildManager.
## Tanpa target part terpilih, activate() tidak melakukan apa-apa.

var painted := 0
var _build_manager: Node = null


func _init() -> void:
	tool_name = "Kuas Cat"


## Suntik manager build (dipakai untuk recolor part dunia).
func set_build_manager(m: Node) -> void:
	_build_manager = m


## Belum ada target part; belum melakukan apa pun saat tombol pakai ditekan.
func activate() -> void:
	pass


## Warnai part dengan hex; true bila manager berhasil mewarnai.
func paint(part_id: int, color_hex: String) -> bool:
	if _build_manager == null:
		return false
	if not _build_manager.has_method("recolor_part"):
		return false
	var ok: bool = _build_manager.recolor_part(part_id, color_hex)
	if ok:
		painted += 1
	return ok
