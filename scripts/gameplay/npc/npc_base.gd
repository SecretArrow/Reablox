class_name NpcBase
extends CharacterBody3D
## NpcBase — dasar semua NPC: tabrakan kapsul, gravitasi, kesehatan,
## dan sinyal npc_died. Logika gerak ada di _ai() yang ditimpa anak.

var npc_name := "NPC"
var health := 50.0
var max_health := 50.0
var _dead := false


func _ready() -> void:
	collision_layer = GameConfig.LAYER_NPC
	collision_mask = GameConfig.LAYER_WORLD
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.8
	capsule.height = 4.0
	col.shape = capsule
	col.position = Vector3(0.0, 2.0, 0.0)
	add_child(col)


func _physics_process(delta: float) -> void:
	velocity.y = maxf(velocity.y - GameConfig.GRAVITY * delta, -400.0)
	_ai(delta)
	move_and_slide()


## Virtual: logika AI per frame fisika. Anak menimpa sesuai perilaku.
func _ai(_delta: float) -> void:
	pass


## Terima damage; mati (sinyal + queue_free) bila health habis.
func damage(n: float) -> void:
	if _dead:
		return
	health = maxf(health - n, 0.0)
	if health <= 0.0:
		_dead = true
		GameEvents.npc_died.emit(npc_name)
		queue_free()


func is_dead() -> bool:
	return _dead
