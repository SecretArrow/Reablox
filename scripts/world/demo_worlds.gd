class_name DemoWorlds
extends RefCounted
## DemoWorlds — katalog dunia demo (murni data) plus perakit elemen level:
## obby 8 tahap menaik ke -Z serta plaza bangun-bebas. Kelas statis murni,
## tidak membuat node sendiri; semua elemen ditempel ke root milik pemanggil.

const OBBY_NAME := "Pulau Obby"
const PLAZA_NAME := "Plaza Kreatif"

const STAGES := 8
const STAGE_GAP := 14.0
const STAGE_START_Y := 6.0
const STAGE_CLIMB := 1.5
const HAZARD_OFFSET_Z := 7.0

const PLAZA_BLOCKS := 12
const PLAZA_RING_RADIUS := 12.0
const PLAZA_COIN_RADIUS := 8.0
const BLOCK_COLORS := ["#c4281c", "#0d69ac", "#f5cd30", "#4b974b"]
const PLATFORM_COLOR := "#a3a2a5"


## Daftar dunia demo yang tersedia (data statis, tanpa node).
static func list() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	(
		worlds
		. append(
			{
				"name": OBBY_NAME,
				"desc": "Lintasi 8 tahap obstacle course",
				"seed": 42,
				"size": 128,
				"water_level": 2.0,
			}
		)
	)
	(
		worlds
		. append(
			{
				"name": PLAZA_NAME,
				"desc": "Dataran bangun bebas dengan blok awal",
				"seed": 7,
				"size": 96,
				"water_level": -50.0,
			}
		)
	)
	return worlds


## Cari dunia demo bernama world_name; Dictionary kosong bila tak ada.
static func find(world_name: String) -> Dictionary:
	for world in list():
		if str(world.get("name", "")) == world_name:
			return world
	return {}


## Bangun 8 tahap obby menaik ke arah -Z dari start (0, 6, 0).
## Setiap tahap: platform, checkpoint, rintangan bergantian, dan satu koin.
## Mengembalikan jumlah elemen yang dibuat.
static func build_obby(root: Node3D) -> int:
	if root == null:
		push_warning("Root obby null — tidak ada yang dibangun.")
		return 0
	var made := 0
	for i in range(STAGES):
		var y := STAGE_START_Y + float(i) * STAGE_CLIMB
		var z := -STAGE_GAP * float(i + 1)
		root.add_child(_make_block(Vector3(0.0, y, z), Vector3(8.0, 1.0, 8.0), PLATFORM_COLOR))
		root.add_child(Checkpoint.make(Vector3(0.0, y + 0.3, z), i + 1))
		root.add_child(_make_hazard(i, y, z))
		root.add_child(Coin.make(Vector3(3.0, y + 1.5, z - HAZARD_OFFSET_Z), 1))
		made += 4
	return made


## Bangun plaza bangun-bebas: 12 blok starter melingkar, 4 koin, 1 monster.
## Mengembalikan jumlah objek yang dibuat.
static func build_plaza(root: Node3D) -> int:
	if root == null:
		push_warning("Root plaza null — tidak ada yang dibangun.")
		return 0
	var made := _add_plaza_blocks(root)
	made += _add_plaza_coins(root)
	root.add_child(_make_plaza_monster())
	made += 1
	return made


## Rintangan bergantian per tahap: killbrick -> spinner -> jump pad.
static func _make_hazard(i: int, y: float, z: float) -> Node3D:
	var base := Vector3(0.0, y, z - HAZARD_OFFSET_Z)
	match i % 3:
		0:
			return KillBrick.make(base, Vector3(6.0, 1.0, 6.0))
		1:
			return Spinner.make(Vector3(0.0, y + 1.5, z - HAZARD_OFFSET_Z), 5.0)
		2:
			return JumpPad.make(Vector3(0.0, y + 0.5, z - HAZARD_OFFSET_Z), 12.0)
	return KillBrick.make(base, Vector3(6.0, 1.0, 6.0))


## Blok StaticBody3D + BoxMesh sederhana sebagai lantai/dekorasi.
static func _make_block(pos: Vector3, size: Vector3, color_hex: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = MaterialsLib.make("plastic", PartLibrary.color_from_hex(color_hex))
	body.add_child(mesh)
	return body


## 12 blok starter dekoratif membentuk lingkaran, warna bersiklus 4 hex.
static func _add_plaza_blocks(root: Node3D) -> int:
	for i in range(PLAZA_BLOCKS):
		var angle := TAU * float(i) / float(PLAZA_BLOCKS)
		var pos := Vector3(cos(angle) * PLAZA_RING_RADIUS, 0.6, sin(angle) * PLAZA_RING_RADIUS)
		var color_hex: String = BLOCK_COLORS[i % BLOCK_COLORS.size()]
		root.add_child(_make_block(pos, Vector3(4.0, 1.2, 2.0), color_hex))
	return PLAZA_BLOCKS


## 4 koin di dalam lingkaran blok (radius 8).
static func _add_plaza_coins(root: Node3D) -> int:
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI / 4.0
		var pos := Vector3(cos(angle) * PLAZA_COIN_RADIUS, 1.5, sin(angle) * PLAZA_COIN_RADIUS)
		root.add_child(Coin.make(pos, 1))
	return 4


## Monster merah yang berpatroli 4 titik di sekitar plaza.
static func _make_plaza_monster() -> NpcMonster:
	var npc := NpcMonster.new()
	npc.name = "NpcMonster"
	npc.position = Vector3(8.0, 0.0, 8.0)
	(
		npc
		. set_waypoints(
			[
				Vector3(8.0, 0.0, 8.0),
				Vector3(-8.0, 0.0, 8.0),
				Vector3(-8.0, 0.0, -8.0),
				Vector3(8.0, 0.0, -8.0),
			]
		)
	)
	return npc
