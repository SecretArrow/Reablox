class_name AvatarRig
extends Node3D
## Rig avatar blocky ala Roblox, dibangun prosedural dari Dictionary config.
## Origin berada di lantai tepat di antara kedua kaki; karakter menghadap -Z.

# Alias preload: kelas global belum terdaftar di cache .godot (tanpa --import).
const BrickColorsLib := preload("res://scripts/avatar/brick_colors.gd")

const COSMETICS_PATH := "res://data/cosmetics/cosmetics.json"
const HEX_COLOR_PATTERN := "^#[0-9A-Fa-f]{6}$"

# Nama bagian tubuh -> path node mesh-nya di dalam rig.
const PART_NODES := {
	"torso": "Torso",
	"head": "Head",
	"left_arm": "ShoulderL/LeftArm",
	"right_arm": "ShoulderR/RightArm",
	"left_leg": "HipL/LeftLeg",
	"right_leg": "HipR/RightLeg",
}

# Slot kosmetik -> node induk tempat aksesori ditempel.
const SLOT_PARENTS := {
	"hat": "Head",
	"hair": "Head",
	"face": "Head",
	"face_gear": "Head",
	"accessory": "Head",
	"back": "Torso",
	"wings": "Torso",
	"shirt": "Torso",
	"pants": "Torso",
	"hand": "ShoulderR",
}

# Offset holder aksesori per slot (slot di luar spek dipetakan wajar).
const SLOT_OFFSETS := {
	"hat": Vector3(0, 0.75, 0),
	"back": Vector3(0, 0, 0.65),
	"face_gear": Vector3(0, 0, -0.75),
	"face": Vector3(0, 0, -0.75),
	"accessory": Vector3(0, 0, -0.75),
	"hair": Vector3(0, 0.6, 0),
	"wings": Vector3(0, 0, 0.65),
	"shirt": Vector3(0, 0, 0),
	"pants": Vector3(0, -1.0, 0),
	"hand": Vector3(0, -1.4, 0),
}

# Ukuran bawaan bentuk aksesori saat data kosmetik tidak menyediakan ukuran.
const DEFAULT_BOX_SIZE := Vector3(0.8, 0.5, 0.8)
const DEFAULT_CYLINDER_RADIUS := 0.35
const DEFAULT_CYLINDER_HEIGHT := 0.5
const DEFAULT_SPHERE_RADIUS := 0.35
const FALLBACK_ACCESSORY_COLOR := "Bright yellow"

# Data kosmetik ditulis untuk kepala ~0.6 unit; kepala rig 1.2 unit -> skala 2x.
const SHAPE_SCALE := 2.0

var _config: Dictionary = {}
var _cosmetics: Array = []
var _accessory_roots: Array[Node3D] = []


func build(config: Dictionary) -> void:
	# Bangun ulang seluruh rig dari config (duplikat disimpan di _config).
	_clear()
	_config = config.duplicate(true)
	var colors: Dictionary = _config.get("colors", {})
	_add_limb(
		"HipL", Vector3(-0.5, 2.0, 0), "LeftLeg", Vector3(0, -1.0, 0), colors.get("left_leg", "")
	)
	_add_limb(
		"HipR", Vector3(0.5, 2.0, 0), "RightLeg", Vector3(0, -1.0, 0), colors.get("right_leg", "")
	)
	_add_limb(
		"ShoulderL",
		Vector3(-1.5, 3.7, 0),
		"LeftArm",
		Vector3(0, -0.7, 0),
		colors.get("left_arm", "")
	)
	_add_limb(
		"ShoulderR",
		Vector3(1.5, 3.7, 0),
		"RightArm",
		Vector3(0, -0.7, 0),
		colors.get("right_arm", "")
	)
	add_child(_make_box("Torso", Vector3(0, 3.0, 0), Vector3(2, 2, 1), colors.get("torso", "")))
	var head := _make_box(
		"Head", Vector3(0, 4.6, 0), Vector3(1.2, 1.2, 1.2), colors.get("head", "")
	)
	head.add_child(_make_face())
	add_child(head)


func set_part_color(part_name: String, color: Color) -> bool:
	# Ubah warna satu bagian tubuh; sekaligus catat di salinan _config.
	var node_path := String(PART_NODES.get(part_name, ""))
	if node_path.is_empty():
		push_warning("Bagian tubuh tidak dikenal: %s" % part_name)
		return false
	var mesh_inst := get_node_or_null(node_path) as MeshInstance3D
	if mesh_inst == null:
		push_warning("Node bagian tubuh tidak ditemukan: %s" % node_path)
		return false
	var material := mesh_inst.material_override as StandardMaterial3D
	if material == null:
		material = _make_material(color)
		mesh_inst.material_override = material
	else:
		material.albedo_color = color
	if typeof(_config.get("colors")) == TYPE_DICTIONARY:
		(_config.get("colors") as Dictionary)[part_name] = "#" + color.to_html(false)
	return true


func get_config() -> Dictionary:
	# Salinan config terakhir; kosong bila rig belum dibangun.
	if _config.is_empty():
		return {}
	return _config.duplicate(true)


static func validate_config(cfg: Dictionary) -> Array[String]:
	# Validasi skema config; kosong berarti valid.
	var errors: Array[String] = []
	var colors: Variant = cfg.get("colors")
	if typeof(colors) != TYPE_DICTIONARY:
		errors.append("cfg.colors harus Dictionary dengan 6 kunci bagian tubuh")
	else:
		var color_map := colors as Dictionary
		for part in PART_NODES:
			var value: Variant = color_map.get(part)
			if typeof(value) != TYPE_STRING or not _is_valid_color_value(String(value)):
				errors.append("cfg.colors.%s harus nama palet atau hex #rrggbb" % part)
	if typeof(cfg.get("material")) != TYPE_STRING or String(cfg.get("material")).is_empty():
		errors.append("cfg.material harus String non-kosong")
	if typeof(cfg.get("face")) != TYPE_STRING or String(cfg.get("face")).is_empty():
		errors.append("cfg.face harus String non-kosong")
	if typeof(cfg.get("accessories")) != TYPE_ARRAY:
		errors.append("cfg.accessories harus Array")
	return errors


static func _is_valid_color_value(value: String) -> bool:
	if _is_hex_color(value):
		return true
	return BrickColorsLib.is_valid(value)


static func _is_hex_color(value: String) -> bool:
	var pattern := RegEx.create_from_string(HEX_COLOR_PATTERN)
	return pattern != null and pattern.search(value) != null


func apply_accessory(id: String) -> bool:
	# Tempel aksesori dari cosmetics.json berdasarkan id; false bila tak ditemukan.
	if _config.is_empty():
		push_warning("Rig belum dibangun; apply_accessory('%s') diabaikan" % id)
		return false
	for item in _load_cosmetics():
		if typeof(item) == TYPE_DICTIONARY and String((item as Dictionary).get("id", "")) == id:
			_attach_item(item as Dictionary, id)
			return true
	push_warning("Aksesori '%s' tidak ditemukan di %s" % [id, COSMETICS_PATH])
	return false


func count_accessories() -> int:
	# Jumlah aksesori yang sedang terpasang pada rig.
	return _accessory_roots.size()


func _clear() -> void:
	# Bersihkan seluruh hasil build sebelumnya.
	for child in get_children():
		remove_child(child)
		child.free()
	_accessory_roots.clear()


func _add_limb(
	pivot_name: String,
	pivot_pos: Vector3,
	mesh_name: String,
	mesh_offset: Vector3,
	color_value: Variant
) -> void:
	# Pivot (bahu/pinggul) + mesh anggota tubuh sebagai anak pivot.
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pivot_pos
	add_child(pivot)
	pivot.add_child(_make_box(mesh_name, mesh_offset, Vector3(1, 2, 1), color_value))


func _make_box(
	node_name: String, node_pos: Vector3, box_size: Vector3, color_value: Variant
) -> MeshInstance3D:
	# MeshInstance3D BoxMesh dengan material warna solid (belum dipasang ke tree).
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	mesh_inst.position = node_pos
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _make_material(_color_from_config(color_value))
	return mesh_inst


func _make_face() -> Sprite3D:
	# Wajah senyum prosedural 128x128 sebagai Sprite3D di sisi depan kepala (-Z).
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var black := Color(0, 0, 0, 1)
	img.fill_rect(Rect2i(34, 36, 14, 24), black)
	img.fill_rect(Rect2i(80, 36, 14, 24), black)
	for i in 20:
		var smile_y := 78 + int(sin(float(i) / 19.0 * PI) * 12.0)
		img.fill_rect(Rect2i(36 + i * 3, smile_y, 3, 6), black)
	var face := Sprite3D.new()
	face.name = "Face"
	face.position = Vector3(0, 0, -0.62)
	face.pixel_size = 0.009
	face.texture = ImageTexture.create_from_image(img)
	face.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	face.double_sided = true
	face.transparent = true
	return face


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.metallic = 0.1
	return material


func _color_from_config(color_value: Variant) -> Color:
	# Terima nama palet BrickColors atau string hex "#rrggbb".
	var color_name := ""
	if typeof(color_value) == TYPE_STRING:
		color_name = String(color_value)
	if _is_hex_color(color_name):
		return Color(color_name)
	return BrickColorsLib.color_of(color_name)


func _load_cosmetics() -> Array:
	# Muat (dan cache) daftar item kosmetik dari cosmetics.json.
	if not _cosmetics.is_empty():
		return _cosmetics
	var file := FileAccess.open(COSMETICS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Gagal membuka %s" % COSMETICS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		_cosmetics = parsed
	else:
		push_warning("Skema %s tidak sesuai (diharapkan array)" % COSMETICS_PATH)
	return _cosmetics


func _attach_item(item: Dictionary, id: String) -> void:
	# Buat holder aksesori di induk slot lalu isi dengan tiap bentuk item.
	var slot := String(item.get("slot", ""))
	var parent := get_node_or_null(String(SLOT_PARENTS.get(slot, "Torso")))
	if parent == null:
		parent = self
	var holder := Node3D.new()
	holder.name = "Accessory_" + id
	var offset: Vector3 = SLOT_OFFSETS.get(slot, Vector3.ZERO)
	holder.position = offset
	parent.add_child(holder)
	for shape in item.get("shapes", []):
		if typeof(shape) == TYPE_DICTIONARY:
			_attach_shape(holder, shape as Dictionary, offset)
	_accessory_roots.append(holder)


func _attach_shape(holder: Node3D, shape: Dictionary, holder_pos: Vector3) -> void:
	# Satu bentuk kosmetik -> satu MeshInstance3D anak holder.
	var mesh := _mesh_for_shape(shape)
	if mesh == null:
		return
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Shape"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _make_material(_color_for_shape(shape))
	mesh_inst.position = _shape_position(shape, holder_pos)
	holder.add_child(mesh_inst)


func _mesh_for_shape(shape: Dictionary) -> Mesh:
	# Mesh sesuai tipe bentuk; ukuran dari data (diskalakan) atau bawaan spek.
	var shape_type := String(shape.get("type", "box"))
	var size := _scaled_shape_size(shape)
	match shape_type:
		"cylinder":
			var cylinder := CylinderMesh.new()
			if shape.has("size"):
				cylinder.top_radius = size.x * 0.5
				cylinder.bottom_radius = size.x * 0.5
				cylinder.height = size.y
			else:
				cylinder.top_radius = DEFAULT_CYLINDER_RADIUS
				cylinder.bottom_radius = DEFAULT_CYLINDER_RADIUS
				cylinder.height = DEFAULT_CYLINDER_HEIGHT
			return cylinder
		"sphere":
			var sphere := SphereMesh.new()
			if shape.has("size"):
				sphere.radius = size.x * 0.5
				sphere.height = size.y
			else:
				sphere.radius = DEFAULT_SPHERE_RADIUS
				sphere.height = DEFAULT_SPHERE_RADIUS * 2.0
			return sphere
		"prism":
			var prism := PrismMesh.new()
			prism.size = size
			return prism
		_:
			var box := BoxMesh.new()
			box.size = size
			return box


func _scaled_shape_size(shape: Dictionary) -> Vector3:
	# Ukuran bentuk dari data dikalikan SHAPE_SCALE; bawaan bila tidak ada.
	if not shape.has("size"):
		return DEFAULT_BOX_SIZE
	return _vec3_from_array(shape.get("size"), DEFAULT_BOX_SIZE) * SHAPE_SCALE


func _color_for_shape(shape: Dictionary) -> Color:
	# Warna bentuk: hex dari data, nama palet, atau fallback Bright yellow.
	var color_value := String(shape.get("color", ""))
	if _is_hex_color(color_value):
		return Color(color_value)
	if BrickColorsLib.is_valid(color_value):
		return BrickColorsLib.color_of(color_value)
	return BrickColorsLib.color_of(FALLBACK_ACCESSORY_COLOR)


func _shape_position(shape: Dictionary, holder_pos: Vector3) -> Vector3:
	# Posisi data dihitung relatif pusat part; holder hanya wadah grouping,
	# jadi offset holder dikurangkan kembali. Tanpa pos data -> tepat di slot.
	if not shape.has("pos"):
		return Vector3.ZERO
	return _vec3_from_array(shape.get("pos"), Vector3.ZERO) * SHAPE_SCALE - holder_pos


func _vec3_from_array(value: Variant, fallback: Vector3) -> Vector3:
	# Konversi array [x, y, z] angka menjadi Vector3 (fallback bila rusak).
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr := value as Array
	if arr.size() != 3:
		return fallback
	var nums: Array[float] = []
	for element in arr:
		if typeof(element) == TYPE_FLOAT or typeof(element) == TYPE_INT:
			nums.append(float(element))
		else:
			return fallback
	return Vector3(nums[0], nums[1], nums[2])
