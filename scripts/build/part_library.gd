class_name PartLibrary
extends RefCounted
## PartLibrary — pabrik part ala Roblox Studio: block, sphere, cylinder,
## wedge, corner. Semua part StaticBody3D di layer parts.

const PART_TYPES := ["block", "sphere", "cylinder", "wedge", "corner"]
const FALLBACK_COLOR := Color("a3a2a5")


static func is_valid_type(part_type: String) -> bool:
	return PART_TYPES.has(part_type.to_lower())


## Ukuran default Part Roblox klasik: 4 x 1.2 x 2 studs.
static func default_size() -> Vector3:
	return Vector3(4.0, 1.2, 2.0)


## Color -> "#rrggbb" huruf kecil.
static func hex(color: Color) -> String:
	return "#%02x%02x%02x" % [roundi(color.r8), roundi(color.g8), roundi(color.b8)]


## "#rrggbb" -> Color; string salah -> abu Medium stone.
static func color_from_hex(hex_str: String) -> Color:
	var clean := hex_str.strip_edges()
	var valid := clean.length() == 7 and clean.begins_with("#")
	if valid:
		for i in range(1, 7):
			if not "0123456789abcdefABCDEF".contains(clean[i]):
				valid = false
				break
	if not valid:
		push_warning("Hex warna tidak valid: %s — pakai abu default" % hex_str)
		return FALLBACK_COLOR
	return Color.from_string(clean, FALLBACK_COLOR)


static func make_part(
	part_type: String, size: Vector3, color: Color, material := "plastic"
) -> StaticBody3D:
	var key := part_type.to_lower()
	if not is_valid_type(key):
		push_warning("Tipe part tidak dikenal: %s — pakai block" % part_type)
		key = "block"
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_PARTS
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	match key:
		"block":
			var box := BoxMesh.new()
			box.size = size
			mesh_inst.mesh = box
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			mesh_inst.mesh = sphere
			mesh_inst.scale = size
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			mesh_inst.mesh = cyl
			mesh_inst.scale = size
		"wedge":
			mesh_inst.mesh = _wedge_mesh(size)
		"corner":
			mesh_inst.mesh = _wedge_mesh(Vector3(size.z, size.y, size.x))
	mesh_inst.material_override = MaterialsLib.make(material, color)
	body.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	if key == "block":
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
	else:
		var convex: ConvexPolygonShape3D = mesh_inst.mesh.create_convex_shape()
		col.shape = convex
	body.add_child(col)
	body.set_meta("part_type", key)
	return body


## Wedge (ram): penampang segitiga di bidang ZY, panjang di sumbu X.
## Sisi vertikal di +Z, kemiringan dari bawah-depan ke atas-belakang.
static func _wedge_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sx := size.x * 0.5
	var sy := size.y * 0.5
	var sz := size.z * 0.5
	var bottom_front := Vector3(-sx, -sy, -sz)
	var bottom_back := Vector3(-sx, -sy, sz)
	var top_back := Vector3(-sx, sy, sz)
	var bottom_front_r := Vector3(sx, -sy, -sz)
	var bottom_back_r := Vector3(sx, -sy, sz)
	var top_back_r := Vector3(sx, sy, sz)
	# Alas.
	_add_quad(st, bottom_front, bottom_front_r, bottom_back_r, bottom_back)
	# Sisi vertikal belakang.
	_add_quad(st, bottom_back, bottom_back_r, top_back_r, top_back)
	# Kemiringan.
	_add_quad(st, bottom_front, bottom_back, top_back, bottom_front_r)
	# Dua segitiga samping.
	_add_triangle(st, bottom_front, top_back, bottom_back)
	_add_triangle(st, bottom_front_r, bottom_back_r, top_back_r)
	st.generate_normals()
	return st.commit()


static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
