extends Node
## Test suite unit — sistem build: BlockLibrary, BuildManager (place/rotate/
## anchor/remove/undo/redo/snap grid/limit + ops terrain), BlockCoding,
## MiniScript, dan Terrain (heightmap).
## Ground truth (dibaca dulu, bukan dikarang):
##   scripts/build/block_library.gd, build_manager.gd, block_coding.gd,
##   mini_script.gd, terrain.gd + scripts/world/world_manager.gd (wiring
##   Blocks/MMChunks ala game.gd).
## Jalur: cd rblox-audit && godot --headless res://tools/tests/test_unit_build.tscn

const FW := preload("res://tools/tests/test_framework.gd")
const BlockLibrary := preload("res://scripts/build/block_library.gd")
const BuildManager := preload("res://scripts/build/build_manager.gd")
const BlockCoding := preload("res://scripts/build/block_coding.gd")
const MiniScript := preload("res://scripts/build/mini_script.gd")
const WorldTerrain := preload("res://scripts/build/terrain.gd")
const WorldManager := preload("res://scripts/world/world_manager.gd")

## Batas await eksekusi async BlockCoding (10 s @ 60 physics frame/s).
const BC_AWAIT_FRAMES := 600

var fw := FW.new()

var _world_root: Node3D = null
var _blocks_root: Node3D = null
var _mm = null  # renderer MultiMesh chunk (MMChunks)
var _bm = null  # BuildManager (Node3D + script build_manager.gd)
var _terrain = null  # Terrain (Node3D + script terrain.gd)
var _ui_host: Control = null
var _target_block: Node3D = null  # blok RigidBody beku untuk coding/script

# Rekaman sinyal block_changed(data, removed).
var _sig_count := 0
var _sig_last_data: Dictionary = {}
var _sig_last_removed := false


func _ready() -> void:
	add_child(fw)
	_setup_stage()
	await _run_tests()
	await _cleanup_nodes()
	fw.finish()


## Rakit panggung mini ala game.gd: WorldRoot > Blocks (+MMChunks) & Terrain
## 16x16 flat. BuildManager menemukan "Blocks" lewat current_scene.
func _setup_stage() -> void:
	_world_root = Node3D.new()
	_world_root.name = "WorldRoot"
	add_child(_world_root)
	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	_world_root.add_child(_blocks_root)
	_mm = WorldManager.make_chunk_renderer(_blocks_root)
	var flat: Array = []
	flat.resize(16 * 16)
	for i in flat.size():
		flat[i] = 0
	_terrain = WorldTerrain.build_from({"size": 16, "seed": 7, "heights": flat, "paint": []})
	_world_root.add_child(_terrain)
	_ui_host = Control.new()
	_ui_host.name = "UiHost"
	add_child(_ui_host)


func _run_tests() -> void:
	_test_block_library()
	_test_bm_setup()
	_test_snap_math()
	await _test_place_rotate_anchor()
	await _test_remove_undo_redo()
	await _test_undo_limit()
	await _test_block_limit()
	await _test_terrain_ops()
	await _test_block_coding()
	_test_mini_script()


# ------------------------------------------------------------------ helpers


## Jumlah anak Blocks yang benar-benar blok (meta block_data, belum di-free).
func _block_count() -> int:
	var n := 0
	if _blocks_root == null:
		return 0
	for c in _blocks_root.get_children():
		var nb := c as Node3D
		if (
			nb != null
			and is_instance_valid(nb)
			and not nb.is_queued_for_deletion()
			and nb.has_meta("block_data")
		):
			n += 1
	return n


func _find_block(id: String) -> Node3D:
	for c in _blocks_root.get_children():
		var nb := c as Node3D
		if (
			nb != null
			and is_instance_valid(nb)
			and not nb.is_queued_for_deletion()
			and nb.has_meta("block_data")
			and String((nb.get_meta("block_data", {}) as Dictionary).get("id", "")) == id
		):
			return nb
	return null


func _on_block_changed(data: Dictionary, removed: bool) -> void:
	_sig_count += 1
	_sig_last_data = data
	_sig_last_removed = removed


## Arahkan "kursor" BuildManager: _process menimpa _has_hit tiap frame
## (headless tanpa kamera -> raycast gagal), jadi pasang ulang tepat sebelum op.
func _aim(pos: Vector3) -> void:
	_bm._last_hit = pos
	_bm._has_hit = true


## Salin Array[String] konstanta ke Array biasa agar perbandingan aman.
func _plain(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		out.append(e)
	return out


# ------------------------------------------------------------------- tests


func _test_block_library() -> void:
	fw.section("BlockLibrary: katalog statis & validasi")
	fw.check_eq("4 bentuk", _plain(BlockLibrary.SHAPES), ["box", "sphere", "cylinder", "wedge"])
	fw.check_eq(
		"5 material", _plain(BlockLibrary.MATERIALS), ["plastic", "metal", "wood", "glass", "neon"]
	)
	fw.check_eq("palet 24 warna", BlockLibrary.COLORS.size(), 24)
	var hex_ok := true
	for c in BlockLibrary.COLORS:
		if not Color.html_is_valid(String(c)):
			hex_ok = false
	fw.check("semua warna palet hex valid", hex_ok)
	fw.check_eq("DEFAULT_COLOR", BlockLibrary.DEFAULT_COLOR, "#e0453a")

	for s in BlockLibrary.SHAPES:
		fw.check("is_valid_shape('%s')" % s, BlockLibrary.is_valid_shape(String(s)))
	fw.check("is_valid_shape('banana') -> false", not BlockLibrary.is_valid_shape("banana"))
	fw.check("is_valid_shape('') -> false", not BlockLibrary.is_valid_shape(""))
	for m in BlockLibrary.MATERIALS:
		fw.check("is_valid_material('%s')" % m, BlockLibrary.is_valid_material(String(m)))
	fw.check("is_valid_material('gold') -> false", not BlockLibrary.is_valid_material("gold"))
	for s in BlockLibrary.SHAPES:
		fw.check_eq(
			"default_size('%s') 1x1x1" % s, BlockLibrary.default_size(String(s)), Vector3.ONE
		)
	fw.section("BlockLibrary: make_mesh")
	fw.check("mesh box -> BoxMesh", BlockLibrary.make_mesh("box") is BoxMesh)
	fw.check_eq(
		"mesh box ukuran custom",
		(BlockLibrary.make_mesh("box", Vector3(2, 3, 4)) as BoxMesh).size,
		Vector3(2, 3, 4)
	)
	fw.check_eq("mesh default 1x1x1", (BlockLibrary.make_mesh("box") as BoxMesh).size, Vector3.ONE)
	var sm := BlockLibrary.make_mesh("sphere", Vector3(2, 3, 2)) as SphereMesh
	fw.check_eq("sphere radius = min(x,z)/2", sm.radius, 1.0)
	fw.check_eq("sphere height = y", sm.height, 3.0)
	var cm := BlockLibrary.make_mesh("cylinder", Vector3(2, 5, 2)) as CylinderMesh
	fw.check_eq("cylinder radius", cm.top_radius, 1.0)
	fw.check_eq("cylinder height", cm.height, 5.0)
	fw.check("wedge -> PrismMesh", BlockLibrary.make_mesh("wedge", Vector3.ONE) is PrismMesh)
	fw.check("bentuk tak dikenal -> fallback BoxMesh", BlockLibrary.make_mesh("banana") is BoxMesh)

	fw.section("BlockLibrary: make_material / make_collision / parse_color")
	var m_metal := BlockLibrary.make_material("metal", "#ffffff")
	fw.check("metal metallic 0.9", is_equal_approx(m_metal.metallic, 0.9))
	fw.check("metal roughness 0.3", is_equal_approx(m_metal.roughness, 0.3))
	fw.check(
		"wood roughness 0.95",
		is_equal_approx(BlockLibrary.make_material("wood", "#ffffff").roughness, 0.95)
	)
	var m_glass := BlockLibrary.make_material("glass", "#ff0000")
	fw.check("glass transparan", m_glass.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	fw.check("glass alpha 0.4 (toleransi float32)", is_equal_approx(m_glass.albedo_color.a, 0.4))
	var m_neon := BlockLibrary.make_material("neon", "#00ff00")
	fw.check("neon emissive", m_neon.emission_enabled)
	fw.check_eq("neon warna emis", m_neon.emission, Color(0, 1, 0))
	fw.check(
		"plastic roughness 0.8",
		is_equal_approx(BlockLibrary.make_material("plastic", "#ffffff").roughness, 0.8)
	)
	fw.check_eq(
		"warna hex diterapkan",
		BlockLibrary.make_material("plastic", "#0000ff").albedo_color,
		Color(0, 0, 1)
	)

	fw.check(
		"collision box -> BoxShape3D",
		BlockLibrary.make_collision("box", Vector3(2, 1, 2)) is BoxShape3D
	)
	fw.check_eq(
		"box shape ukuran",
		(BlockLibrary.make_collision("box", Vector3(2, 1, 2)) as BoxShape3D).size,
		Vector3(2, 1, 2)
	)
	fw.check(
		"collision sphere -> SphereShape3D",
		BlockLibrary.make_collision("sphere", Vector3.ONE) is SphereShape3D
	)
	fw.check_eq(
		"sphere radius 0.5",
		(BlockLibrary.make_collision("sphere", Vector3.ONE) as SphereShape3D).radius,
		0.5
	)
	fw.check(
		"collision cylinder -> CylinderShape3D",
		BlockLibrary.make_collision("cylinder", Vector3.ONE) is CylinderShape3D
	)
	var wedge_shape := BlockLibrary.make_collision("wedge", Vector3.ONE)
	fw.check("collision wedge -> ConvexPolygonShape3D", wedge_shape is ConvexPolygonShape3D)
	fw.check_eq("wedge convex 6 titik", (wedge_shape as ConvexPolygonShape3D).points.size(), 6)

	fw.check_eq("parse_color '#ff0000'", BlockLibrary.parse_color("#ff0000"), Color(1, 0, 0))
	fw.check_eq("parse_color tanpa '#'", BlockLibrary.parse_color("ff0000"), Color(1, 0, 0))
	fw.check_eq(
		"parse_color invalid -> default",
		BlockLibrary.parse_color("bukan-warna"),
		BlockLibrary.parse_color(BlockLibrary.DEFAULT_COLOR)
	)
	fw.check_eq(
		"parse_color kosong -> default",
		BlockLibrary.parse_color(""),
		Color(BlockLibrary.DEFAULT_COLOR)
	)


func _test_bm_setup() -> void:
	fw.section("BuildManager: wiring ala game.gd & setter")
	_bm = BuildManager.new()
	_bm.name = "BuildManager"
	add_child(_bm)
	fw.check("WorldManager termuat di _ready", _bm._wm != null)
	fw.check("ghost dibuat di _ready", _bm._ghost != null and _bm._ghost.get_parent() == _bm)
	fw.check("ghost awalnya tersembunyi", not _bm._ghost.visible)
	fw.check_eq("Blocks ditemukan via current_scene", _bm._blocks_root(), _blocks_root)
	fw.check("renderer MMChunks terpasang", _mm != null and _mm.get_parent() == _blocks_root)
	_bm.set_terrain(_terrain)
	fw.check_eq("terrain terikat", _bm._terrain, _terrain)

	_bm.activate(true)
	fw.check("activate(true) -> active", _bm.active)
	_bm.activate(false)
	fw.check("activate(false) -> tidak aktif", not _bm.active)
	_bm.activate(true)

	_bm.set_shape("box")
	_bm.set_material("plastic")
	_bm.set_color("#3b7bff")
	_bm.set_tool("place")
	fw.check_eq("get_color()", _bm.get_color(), "#3b7bff")
	_bm.set_shape("sphere")
	fw.check_eq("set_shape valid", _bm._shape, "sphere")
	fw.check("ghost mesh mengikuti bentuk", _bm._ghost.mesh is SphereMesh)
	_bm.set_shape("banana")
	fw.check_eq("set_shape invalid diabaikan", _bm._shape, "sphere")
	_bm.set_material("metal")
	fw.check_eq("set_material valid", _bm._material, "metal")
	_bm.set_material("adamant")
	fw.check_eq("set_material invalid diabaikan", _bm._material, "metal")
	_bm.set_color("#00ff00")
	fw.check_eq(
		"warna ghost diperbarui (alpha 0.5)",
		(_bm._ghost.material_override as StandardMaterial3D).albedo_color,
		Color(0, 1, 0, 0.5)
	)
	# Kembalikan pilihan default untuk tes place berikutnya.
	_bm.set_shape("box")
	_bm.set_material("neon")
	_bm.set_color("#3b7bff")


func _test_snap_math() -> void:
	fw.section("BuildManager: snap grid 0.5 (_snap_place)")
	fw.check_eq("GRID 0.5", BuildManager.GRID, 0.5)
	fw.check_eq(
		"hit (1.3,0,0) normal UP -> pusat (1.0,0.5,0.0)",
		_bm._snap_place(Vector3(1.3, 0, 0), Vector3.UP, Vector3.ONE),
		Vector3(1.0, 0.5, 0.0)
	)
	fw.check_eq(
		"hit samping dinding normal +X -> pusat (2.5,1.0,0.0)",
		_bm._snap_place(Vector3(2.0, 1.3, 0.0), Vector3.RIGHT, Vector3.ONE),
		Vector3(2.5, 1.0, 0.0)
	)
	fw.check_eq(
		"koordinat negatif snap ke bawah (floor)",
		_bm._snap_place(Vector3(-1.3, 0, 0), Vector3.UP, Vector3.ONE),
		Vector3(-1.5, 0.5, 0.0)
	)
	fw.check_eq(
		"blok 2x2x2 di tanah -> pusat y = 1.0",
		_bm._snap_place(Vector3(1.3, 0, 0), Vector3.UP, Vector3(2, 2, 2)),
		Vector3(1.0, 1.0, 0.0)
	)


func _test_place_rotate_anchor() -> void:
	fw.section("BuildManager: place / rotate / anchor")
	_bm.block_changed.connect(_on_block_changed)
	var before := _block_count()
	_bm._do_place({"position": Vector3(1.3, 0.0, 0.0), "normal": Vector3.UP})
	fw.check_eq("blok bertambah", _block_count(), before + 1)
	fw.check_eq("sinyal block_changed(place) terkirim", _sig_count, 1)
	fw.check("sinyal removed=false", not _sig_last_removed)
	var data: Dictionary = _sig_last_data
	var id := String(data.get("id", ""))
	fw.check("id blok format 'b<ticks+seq>'", id.begins_with("b"))
	fw.check_eq("data sinyal: shape", String(data.get("shape", "")), "box")
	fw.check_eq("data sinyal: warna", String(data.get("color", "")), "#3b7bff")
	fw.check_eq("data sinyal: material", String(data.get("mat", "")), "neon")
	fw.check_eq("data sinyal: pos hasil snap", data.get("pos", []), [1.0, 0.5, 0.0])

	var node := _find_block(id)
	fw.check_not_null("node blok ditemukan", node)
	fw.check("anchored -> StaticBody3D", node is StaticBody3D)
	fw.check_eq("posisi node = hasil snap", node.position, Vector3(1.0, 0.5, 0.0))
	var meta: Dictionary = node.get_meta("block_data", {})
	fw.check_eq("meta: id", String(meta.get("id", "")), id)
	fw.check_eq("meta: anchored true", bool(meta.get("anchored", false)), true)
	fw.check_eq("meta: size 1x1x1", meta.get("size", []), [1.0, 1.0, 1.0])
	fw.check("terdaftar di renderer MultiMesh", _mm.has_block(id))
	fw.check_eq("jumlah instance renderer", _mm.get_block_count(), 1)

	# Rotate: node diputar + meta rot_y + sinyal.
	_bm._edit_block(node, "rotate")
	fw.check("rotasi +90 derajat (PI/2)", is_equal_approx(node.rotation.y, PI * 0.5))
	fw.check(
		"meta rot_y 90 (toleransi float32)",
		is_equal_approx(
			float((node.get_meta("block_data", {}) as Dictionary).get("rot_y", 0.0)), 90.0
		)
	)
	fw.check_eq("sinyal rotate terkirim", _sig_count, 2)
	fw.check(
		"data sinyal rot_y 90 (toleransi float32)",
		is_equal_approx(float(_sig_last_data.get("rot_y", 0.0)), 90.0)
	)

	# Anchor toggle: blok diganti node baru (id sama), jenis body berubah.
	_bm._edit_block(node, "anchor")
	await get_tree().process_frame
	fw.check_eq("anchor toggle: jumlah blok tetap 1", _block_count(), 1)
	var node2 := _find_block(id)
	fw.check_not_null("pengganti ditemukan (id sama)", node2)
	fw.check("unanchored -> RigidBody3D", node2 is RigidBody3D)
	fw.check_eq(
		"meta anchored false",
		bool((node2.get_meta("block_data", {}) as Dictionary).get("anchored", true)),
		false
	)
	fw.check("blok dinamis keluar dari MultiMesh", not _mm.has_block(id))
	_bm._edit_block(node2, "anchor")
	await get_tree().process_frame
	var node3 := _find_block(id)
	fw.check_not_null("re-anchor: pengganti ditemukan", node3)
	fw.check("kembali StaticBody3D", node3 is StaticBody3D)
	fw.check("terdaftar lagi di MultiMesh", _mm.has_block(id))
	fw.check("rotasi dipertahankan lewat rot_y", is_equal_approx(node3.rotation.y, PI * 0.5))


func _test_remove_undo_redo() -> void:
	fw.section("BuildManager: remove / undo / redo")
	var id := String(_sig_last_data.get("id", ""))
	_bm._edit_block(_find_block(id), "remove")
	fw.check("sinyal remove terkirim", _sig_last_removed)
	await get_tree().process_frame
	fw.check_eq("remove: Blocks kosong", _block_count(), 0)
	fw.check("remove: dilepas dari MultiMesh", not _mm.has_block(id))

	_bm.undo()
	fw.check_eq("undo remove: blok kembali", _block_count(), 1)
	var restored := _find_block(id)
	fw.check_not_null("undo: id sama dipulihkan", restored)
	fw.check("undo: terdaftar lagi di MultiMesh", _mm.has_block(id))
	fw.check_eq("undo: posisi tetap hasil snap", restored.position, Vector3(1.0, 0.5, 0.0))

	_bm.redo()
	await get_tree().process_frame
	fw.check_eq("redo remove: blok hilang lagi", _block_count(), 0)
	fw.check("redo: dilepas dari MultiMesh", not _mm.has_block(id))

	_bm.undo()
	fw.check_eq("undo kedua: blok kembali", _block_count(), 1)

	# Undo dari place: blok baru hilang saat undo.
	_bm._do_place({"position": Vector3(-0.7, 0.0, 0.0), "normal": Vector3.UP})
	fw.check_eq("place kedua", _block_count(), 2)
	_bm.undo()
	await get_tree().process_frame
	fw.check_eq("undo place: kembali 1", _block_count(), 1)

	# Redo stack dibersihkan oleh aksi baru.
	_bm._do_place({"position": Vector3(-0.7, 0.0, 0.0), "normal": Vector3.UP})
	fw.check_eq("place ketiga", _block_count(), 2)
	_bm.redo()
	fw.check_eq("redo dibersihkan aksi baru (tetap 2)", _block_count(), 2)

	_bm.undo()
	_bm.undo()
	await get_tree().process_frame
	fw.check_eq("undo ganda: Blocks kosong", _block_count(), 0)
	_bm.undo()
	fw.check_eq("undo stack kosong -> no-op", _block_count(), 0)
	_bm.redo()
	_bm.redo()
	fw.check_eq("redo mengembalikan 2 blok", _block_count(), 2)
	_bm.undo()
	_bm.undo()
	await get_tree().process_frame
	fw.check_eq("undo lagi: Blocks kosong", _block_count(), 0)


func _test_undo_limit() -> void:
	fw.section("BuildManager: undo limit 50 langkah")
	fw.check_eq("UNDO_LIMIT 50", BuildManager.UNDO_LIMIT, 50)
	for i in 52:
		_bm._do_place({"position": Vector3(float(i % 8), 5.0, float(i / 8)), "normal": Vector3.UP})
	fw.check_eq("52 blok ditempatkan", _block_count(), 52)
	for i in 60:
		_bm.undo()
	await get_tree().process_frame
	fw.check_eq("hanya 50 langkah terakhir bisa di-undo (sisa 2)", _block_count(), 2)


func _test_block_limit() -> void:
	fw.section("BuildManager: batas MAX_BLOCKS")
	fw.check_eq("MAX_BLOCKS 12000", BuildManager.MAX_BLOCKS, 12000)
	# Penuhi Blocks hingga tepat batas dengan anak dummy (node tanpa meta).
	var dummies: Array = []
	while _blocks_root.get_child_count() < BuildManager.MAX_BLOCKS:
		var d := Node3D.new()
		d.name = "Dummy%d" % dummies.size()
		_blocks_root.add_child(d)
		dummies.append(d)

		# Satu slot longgar -> place diterima lagi.
	fw.check_eq("Blocks penuh 12000 anak", _blocks_root.get_child_count(), BuildManager.MAX_BLOCKS)
	var blocks_before := _block_count()
	var sig_before := _sig_count
	_bm._do_place({"position": Vector3(3.0, 0.0, 3.0), "normal": Vector3.UP})
	fw.check_eq("place di batas: ditolak (jumlah blok tetap)", _block_count(), blocks_before)
	fw.check_eq("place di batas: tanpa sinyal block_changed", _sig_count, sig_before)

	# Satu slot longgar -> place diterima lagi.
	(dummies[dummies.size() - 1] as Node3D).queue_free()
	dummies.pop_back()
	await get_tree().process_frame
	_bm._do_place({"position": Vector3(3.0, 0.0, 3.0), "normal": Vector3.UP})
	fw.check_eq("place di bawah batas: diterima", _block_count(), blocks_before + 1)
	fw.check_eq("sinyal place terkirim", _sig_count, sig_before + 1)

	for d in dummies:
		(d as Node3D).queue_free()
	await get_tree().process_frame
	fw.check_eq(
		"dummy dibersihkan (sisa blok + renderer)",
		_blocks_root.get_child_count(),
		_block_count() + 1
	)


func _test_terrain_ops() -> void:
	fw.section("Terrain: heightmap & ops via BuildManager")
	fw.check_eq("PAINTS 4 jenis", WorldTerrain.PAINTS.size(), 4)
	var paints_ok := true
	for p in ["grass", "dirt", "rock", "sand"]:
		if not (p in WorldTerrain.PAINTS):
			paints_ok = false

		# _process BuildManager menimpa _has_hit tiap frame; tanpa kamera di
		# headless raycast selalu gagal sehingga op terrain jadi no-op. Pasang
		# ulang arah "kursor" sebelum tiap op (seperti pemain membidik dulu).

		# Validasi input setup: clamp ukuran & tinggi.
	fw.check("PAINTS = grass/dirt/rock/sand", paints_ok)
	fw.check_eq("terrain terpasang di BuildManager", _bm._terrain, _terrain)
	fw.check_eq("ukuran terrain 16", _terrain.terrain_size, 16)
	fw.check_eq("heights 16x16 = 256 tile", _terrain.heights.size(), 256)
	fw.check_eq("terrain datar: tinggi 0", _terrain.get_height_at(8.5, 8.5), 0.0)

	# _process BuildManager menimpa _has_hit tiap frame; tanpa kamera di
	# headless raycast selalu gagal sehingga op terrain jadi no-op. Pasang
	# ulang arah "kursor" sebelum tiap op (seperti pemain membidik dulu).
	_aim(Vector3(8.0, 0.0, 8.0))
	_bm.terrain_raise()
	fw.check_eq("raise: tile (8,8) -> 1", _terrain.get_height_at(8.5, 8.5), 1.0)
	fw.check_eq("raise: tile luar radius tetap 0", _terrain.get_height_at(2.5, 2.5), 0.0)
	var mesh_before: Mesh = _terrain._surface.mesh
	for i in 3:
		await get_tree().physics_frame  # _rebuild di _physics_process

		# Validasi input setup: clamp ukuran & tinggi.
	fw.check("mesh permukaan dibangun ulang", _terrain._surface.mesh != mesh_before)
	fw.check(
		"collision shape diperbarui",
		(_terrain._body.get_child(0) as CollisionShape3D).shape != null
	)

	_aim(Vector3(8.0, 0.0, 8.0))
	_bm.terrain_lower()
	fw.check_eq("lower: kembali 0", _terrain.get_height_at(8.5, 8.5), 0.0)

	_aim(Vector3(8.0, 0.0, 8.0))
	_bm.terrain_raise()
	_bm.terrain_raise()
	fw.check_eq("sebelum flatten: tile (12,8) masih 0", _terrain.get_height_at(12.5, 8.5), 0.0)
	_aim(Vector3(10.9, 0.0, 8.0))
	_bm.terrain_flatten()
	fw.check_eq("flatten: tile (8,8) tetap 2", _terrain.get_height_at(8.5, 8.5), 2.0)
	fw.check_eq("flatten: tile (12,8) diratakan ke 2", _terrain.get_height_at(12.5, 8.5), 2.0)
	fw.check_eq("flatten: tile luar radius tetap 0", _terrain.get_height_at(2.5, 2.5), 0.0)

	_aim(Vector3(2.0, 0.0, 2.0))
	for i in 10:
		_bm.terrain_raise()

		# Validasi input setup: clamp ukuran & tinggi.
	fw.check_eq("tinggi di-clamp MAX_HEIGHT 8", _terrain.get_height_at(2.5, 2.5), 8.0)
	_aim(Vector3(2.0, 0.0, 2.0))
	for i in 10:
		_bm.terrain_lower()

		# Validasi input setup: clamp ukuran & tinggi.
	fw.check_eq("tinggi di-clamp bawah 0", _terrain.get_height_at(2.5, 2.5), 0.0)

	_aim(Vector3(8.0, 0.0, 8.0))
	_bm.terrain_paint("rock")
	fw.check_eq("paint rock diterima", _bm._paint, "rock")
	fw.check_eq("tile (8,8) dicat rock", String(_terrain.paint_data[8 * 16 + 8]), "rock")
	_bm.terrain_paint("lava")
	fw.check_eq("paint nama invalid diabaikan", _bm._paint, "rock")
	var paint_before := String(_terrain.paint_data[0])
	_terrain.paint(0, 0, 1, "lava")
	fw.check_eq("Terrain.paint invalid -> no-op", String(_terrain.paint_data[0]), paint_before)

	var ser: Dictionary = _terrain.serialize()
	fw.check_eq("serialize: size", int(ser.get("size", 0)), 16)
	fw.check_eq("serialize: seed", int(ser.get("seed", 0)), 7)
	fw.check_eq("serialize: heights 256", (ser.get("heights", []) as Array).size(), 256)
	fw.check_eq(
		"serialize: paint rock di idx 136", String((ser.get("paint", []) as Array)[136]), "rock"
	)

	# Validasi input setup: clamp ukuran & tinggi.
	var t_small: Node3D = WorldTerrain.build_from({"size": 4})
	fw.check_eq("size di-clamp minimum 8", t_small.terrain_size, 8)
	fw.check_eq("heights fallback noise 8x8", t_small.heights.size(), 64)
	var h_ok := true
	for h in t_small.heights:
		if int(h) < 0 or int(h) > WorldTerrain.MAX_HEIGHT:
			h_ok = false
	fw.check("tinggi noise dalam 0..8", h_ok)
	t_small.free()
	var raw: Array = []
	raw.resize(64)
	for i in 64:
		raw[i] = 99 if i == 0 else (-3 if i == 1 else 2)
	var t_clamp: Node3D = WorldTerrain.build_from({"size": 8, "heights": raw})
	fw.check_eq("height 99 di-clamp 8", t_clamp.get_height_at(0.5, 0.5), 8.0)
	fw.check_eq("height -3 di-clamp 0", t_clamp.get_height_at(1.5, 0.5), 0.0)
	fw.check_eq("height valid dibiarkan 2", t_clamp.get_height_at(2.5, 0.5), 2.0)
	t_clamp.free()


func _test_block_coding() -> void:
	fw.section("BlockCoding: program visual & eksekusi")
	fw.check_eq(
		"9 perintah BlockCoding",
		_plain(BlockCoding.COMMANDS),
		[
			"move_forward",
			"turn_left",
			"turn_right",
			"jump",
			"wait",
			"repeat_n",
			"if_player_near",
			"set_color",
			"say"
		]
	)
	var bc: Control = BlockCoding.new()
	_ui_host.add_child(bc)
	fw.check("panel awal tersembunyi", not bc.visible)
	bc.open(_ui_host, null)  # tanpa target -> toast, tanpa crash
	fw.check("open tanpa target: _target tetap null", bc._target == null)

	# Target: blok unanchored (jalur mesh) dibekukan agar gravitasi tidak
	# menggeser posisi selama eksekusi async.
	_target_block = (
		WorldManager
		. place_block(
			_blocks_root,
			{
				"id": "kode1",
				"pos": [0, 3, 0],
				"size": [1, 1, 1],
				"color": "#e0453a",
				"mat": "plastic",
				"anchored": false,
			}
		)
	)
	fw.check("target coding: RigidBody3D + mesh", _target_block is RigidBody3D)
	(_target_block as RigidBody3D).freeze = true
	bc.open(_ui_host, _target_block)
	fw.check("open: panel terlihat", bc.visible)
	fw.check_eq("open: target terikat", bc._target, _target_block)
	fw.check_eq("open: program kosong (tanpa script)", bc._program.size(), 0)

	# Susun program lewat alur UI nyata: tombol perintah -> baris argumen.
	bc._on_cmd("repeat_n")
	fw.check("baris argumen muncul", bc._arg_row.visible)
	fw.check_eq("arg default repeat_n", bc._arg_edit.text, "2")
	bc._on_arg_ok()
	fw.check_eq("program[0] repeat_n 2", bc._program[0], {"cmd": "repeat_n", "arg": "2"})
	bc._on_cmd("move_forward")  # tanpa argumen -> langsung masuk program
	bc._on_cmd("turn_left")
	fw.check_eq("program 3 langkah", bc._program.size(), 3)

	var start_pos := _target_block.position
	var start_rot := _target_block.rotation.y
	bc.run_script(_target_block)
	for i in BC_AWAIT_FRAMES:
		if not bc._running:
			break
		await get_tree().physics_frame

		# 2 pass x (move -Z lokal 1 + putar +90 derajat): posisi (-1, 0, -1),
		# rotasi total PI. Dua komposisi basis PI/2 diekstrak Euler sebagai
		# ~-PI (setara +PI mod 2π) — bandingkan beda sudut terbungkus.

		# set_color lewat alur UI: meta + material mesh diperbarui.

		# Program kosong: tidak ada efek, tidak crash.

		# if_player_near tanpa pemain lokal: program berhenti sebelum move.

		# _on_save: program Array tersimpan di meta target.
	fw.check("eksekusi selesai (tidak hang)", not bc._running)
	# 2 pass x (move -Z lokal 1 + putar +90 derajat): posisi (-1, 0, -1),
	# rotasi total PI. Dua komposisi basis PI/2 diekstrak Euler sebagai
	# ~-PI (setara +PI mod 2π) — bandingkan beda sudut terbungkus.
	fw.check("move_forward 2x: z -1", is_equal_approx(_target_block.position.z, start_pos.z - 1.0))
	fw.check(
		"pass ke-2 memutar arah: x -1", is_equal_approx(_target_block.position.x, start_pos.x - 1.0)
	)
	fw.check("y tidak berubah", is_equal_approx(_target_block.position.y, start_pos.y))
	fw.check(
		"turn_left 2x = PI (mod 2π)",
		is_equal_approx(absf(wrapf(_target_block.rotation.y - start_rot, -PI, PI)), PI)
	)

	# set_color lewat alur UI: meta + material mesh diperbarui.
	bc._program.clear()
	bc._on_cmd("set_color")
	fw.check_eq("arg default set_color", bc._arg_edit.text, "#e0453a")
	bc._arg_edit.text = "#00ff00"
	bc._on_arg_ok()
	fw.check_eq("program set_color", bc._program[0], {"cmd": "set_color", "arg": "#00ff00"})
	bc.run_script(_target_block)
	fw.check("set_color selesai sinkron (tanpa jeda)", not bc._running)
	fw.check_eq(
		"meta warna berubah",
		String((_target_block.get_meta("block_data", {}) as Dictionary).get("color", "")),
		"#00ff00"
	)
	var mesh := _target_block.get_node_or_null("Mesh") as MeshInstance3D
	fw.check_not_null("mesh blok ada (jalur non-MultiMesh)", mesh)
	fw.check_eq(
		"material albedo hijau",
		(mesh.material_override as StandardMaterial3D).albedo_color,
		Color(0, 1, 0)
	)

	# Program kosong: tidak ada efek, tidak crash.
	bc._program.clear()
	var pos_before := _target_block.position
	bc.run_script(_target_block)
	fw.check_eq("program kosong: target tak bergerak", _target_block.position, pos_before)

	# if_player_near tanpa pemain lokal: program berhenti sebelum move.
	bc._program = [{"cmd": "if_player_near", "arg": "4.0"}, {"cmd": "move_forward", "arg": ""}]
	bc.run_script(_target_block)
	for i in BC_AWAIT_FRAMES:
		if not bc._running:
			break
		await get_tree().physics_frame

		# _on_save: program Array tersimpan di meta target.
	fw.check("if_player_near tanpa pemain: berhenti", not bc._running)
	fw.check_eq("pemain jauh: move tidak dieksekusi", _target_block.position, pos_before)

	# _on_save: program Array tersimpan di meta target.
	bc._program.clear()
	bc._on_cmd("jump")
	bc._on_cmd("wait")
	bc._arg_edit.text = "0.1"
	bc._on_arg_ok()
	bc._on_save()
	var saved: Variant = (_target_block.get_meta("block_data", {}) as Dictionary).get(
		"script", null
	)
	fw.check("program tersimpan sebagai Array", saved is Array)
	fw.check_eq(
		"isi program tersimpan (jump)",
		(saved as Array)[0] if saved is Array and not (saved as Array).is_empty() else {},
		{"cmd": "jump", "arg": ""}
	)


func _test_mini_script() -> void:
	fw.section("MiniScript: parser baris & eksekusi")
	fw.check_eq(
		"4 perintah MiniScript",
		_plain(MiniScript.COMMANDS),
		["set_color", "rotate_y", "move", "set_scale"]
	)
	var ms: Control = MiniScript.new()
	_ui_host.add_child(ms)
	fw.check("panel awal tersembunyi", not ms.visible)
	ms.open(_ui_host, _target_block)
	fw.check("open: panel terlihat", ms.visible)
	fw.check_eq("kode awal kosong", ms._code.text, "")

	ms._code.text = (
		"# komentar diabaikan\n"
		+ "var jarak = 2\n"
		+ "move(jarak, 0, 0)\n"
		+ "rotate_y(90)\n"
		+ "set_scale(50, 1, 1)\n"
		+ 'set_color("#0000ff")'
	)
	# move/rotate_y MiniScript memakai translate()/rotate_y() Node3D yang
	# bekerja di ruang LOKAL (basis memutar + menskalakan offset). Target
	# masih memutar ~PI dari suite BlockCoding — pulihkan transform ke
	# identitas agar arah & besaran offset dapat dijiwa eksak.
	_target_block.rotation = Vector3.ZERO
	_target_block.scale = Vector3.ONE
	var pos0 := _target_block.position
	var rot0 := _target_block.rotation.y
	ms._on_run()
	fw.check(
		"run sukses: label output tidak merah",
		not ms._output.has_theme_color_override("font_color")
	)
	fw.check("move(var): x +2", is_equal_approx(_target_block.position.x, pos0.x + 2.0))
	fw.check_eq(
		"y & z tak berubah",
		Vector2(_target_block.position.y, _target_block.position.z),
		Vector2(pos0.y, pos0.z)
	)
	fw.check("rotate_y(90)", is_equal_approx(_target_block.rotation.y - rot0, PI * 0.5))
	fw.check_eq("set_scale di-clamp SCALE_MAX 10", _target_block.scale, Vector3(10, 1, 1))
	fw.check_eq(
		"set_color: meta biru",
		String((_target_block.get_meta("block_data", {}) as Dictionary).get("color", "")),
		"#0000ff"
	)

	# Error per baris: output merah, state target tak berubah.
	var pos_bad := _target_block.position
	ms._code.text = "bukan_perintah(1)"
	ms._on_run()
	fw.check(
		"perintah tak dikenal: output merah", ms._output.has_theme_color_override("font_color")
	)
	fw.check_eq("perintah tak dikenal: target tak berubah", _target_block.position, pos_bad)

	ms._code.text = "move(1, 0, zzz)"
	ms._on_run()
	fw.check("ekspresi tak valid: output merah", ms._output.has_theme_color_override("font_color"))
	fw.check_eq("ekspresi tak valid: target tak berubah", _target_block.position, pos_bad)

	ms._code.text = 'set_color("bukan-hex")'
	ms._on_run()
	fw.check("warna tak valid: output merah", ms._output.has_theme_color_override("font_color"))
	fw.check_eq(
		"warna tak valid: meta tak berubah",
		String((_target_block.get_meta("block_data", {}) as Dictionary).get("color", "")),
		"#0000ff"
	)

	ms._code.text = "x == 2"
	ms._on_run()
	fw.check("assignment ganda ditolak", ms._output.has_theme_color_override("font_color"))

	# Binding "self" ke node target. Scale masih (10,1,1) dari set_scale
	# (offset translate ikut skala) — pulihkan dulu ke identitas.
	_target_block.rotation = Vector3.ZERO
	_target_block.scale = Vector3.ONE
	_target_block.position = Vector3(5, 3, 0)
	ms._code.text = "move(0 - self.position.x, 0, 0)"
	ms._on_run()
	fw.check("ekspresi self: kembali ke x = 0", is_equal_approx(_target_block.position.x, 0.0))
	fw.check("self: run tetap sukses", not ms._output.has_theme_color_override("font_color"))

	# Simpan lalu muat ulang script teks dari meta target.
	ms._code.text = "rotate_y(45)\nmove(0, 1, 0)"
	ms._on_save()
	fw.check_eq(
		"script tersimpan di meta",
		String((_target_block.get_meta("block_data", {}) as Dictionary).get("script", "")),
		"rotate_y(45)\nmove(0, 1, 0)"
	)
	ms._code.text = ""
	ms.set_target(_target_block)
	fw.check_eq("set_target memuat script tersimpan", ms._code.text, "rotate_y(45)\nmove(0, 1, 0)")
	ms.close()
	fw.check("close: panel tersembunyi", not ms.visible)


# ------------------------------------------------------------------ cleanup


func _cleanup_nodes() -> void:
	fw.section("Cleanup node test")
	var spawned: Array = [_world_root, _ui_host, _bm]
	for n in spawned:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	await get_tree().process_frame
	fw.check(
		"world_root (+blocks, MMChunks, terrain) dibebaskan", not is_instance_valid(_world_root)
	)
	fw.check("BuildManager dibebaskan", not is_instance_valid(_bm))
	fw.check("host UI (BlockCoding/MiniScript) dibebaskan", not is_instance_valid(_ui_host))
	fw.check(
		"node Blocks tak lagi ditemukan",
		get_tree().current_scene.find_child("Blocks", true, false) == null
	)
	fw.check_eq("anak scene test hanya framework", get_child_count(), 1)
