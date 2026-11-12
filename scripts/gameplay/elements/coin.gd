class_name Coin
extends Area3D
## Coin — koin emas berputar ala Roblox: menambah saldo koin, menghilang,
## lalu muncul kembali setelah beberapa detik.

var value := 1
var collected := false
var respawn_sec := 10.0
var _timer := 0.0


static func make(pos: Vector3, coin_value := 1) -> Coin:
	var coin := Coin.new()
	coin.position = pos
	coin.value = coin_value
	coin.collision_mask = GameConfig.LAYER_PLAYER
	coin.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 1.8)
	col.shape = shape
	coin.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 0.15
	mesh.mesh = cyl
	mesh.rotation_degrees.x = 90.0
	mesh.material_override = MaterialsLib.make("neon", Color(0.99, 0.76, 0.05))
	coin.add_child(mesh)
	coin.body_entered.connect(coin._on_body_entered)
	return coin


func _process(delta: float) -> void:
	var mesh := get_node_or_null("Visual")
	if mesh != null and not collected:
		mesh.rotation_degrees.y += 180.0 * delta
	if collected and respawn_sec > 0.0:
		_timer += delta
		if _timer >= respawn_sec:
			collected = false
			visible = true
			monitoring = true
			_timer = 0.0


func _on_body_entered(body: Node3D) -> void:
	if collected or body == null or not body.has_method("damage"):
		return
	collected = true
	GameState.add_coins(value)
	Audio.play_sfx("coin")
	visible = false
	monitoring = false


func is_collected() -> bool:
	return collected


func set_respawn(sec: float) -> void:
	respawn_sec = sec
