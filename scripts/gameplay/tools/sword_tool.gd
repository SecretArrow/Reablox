class_name SwordTool
extends ToolBase
## SwordTool — pedang klasik ala Roblox: damage 30, jangkauan 6 studs.
## Serangan berupa raycast dari tinggi dada ke arah hadap pemain.

const DAMAGE := 30.0
const RANGE := 6.0

var _hits := 0


func _init() -> void:
	tool_name = "Pedang"


## Tebas ke arah hadap pemain; kena musuh -> damage + sfx + hit counter.
func activate() -> void:
	if not has_player():
		return
	Audio.play_sfx("sword_swing")
	var from := _player.global_position + Vector3(0.0, 3.0, 0.0)
	var fwd := -_player.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + fwd * RANGE)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider == null:
		return
	if not hit.collider.has_method("damage"):
		return
	hit.collider.damage(DAMAGE)
	Audio.play_sfx("sword_hit")
	_hits += 1


func get_hits() -> int:
	return _hits
