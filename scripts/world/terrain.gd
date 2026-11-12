class_name TerrainGen
extends Node
## TerrainGen — terrain halus deterministik ala Roblox: fBm simplex,
## warna per-zona (rumput/tanah/batu/pasir), chunk + skirt tepi, collision
## trimesh per chunk. Spek: docs/rea/graphics.md §4.

const CHUNK := 16
const DEFAULT_SIZE := 128
const SLOPE_DIRT := 35.0
const SLOPE_ROCK := 55.0
const SAND_BAND := 0.75
const BLEND := 0.5
const SKIRT_DROP := 2.0

const COLOR_GRASS := Color(0.435, 0.639, 0.302)
const COLOR_DIRT := Color(0.478, 0.333, 0.227)
const COLOR_ROCK := Color(0.451, 0.451, 0.451)
const COLOR_SAND := Color(0.82, 0.788, 0.6)

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_octaves = 1
	_noise.seed = 0


func set_seed(seed_value: int) -> void:
	_noise.seed = seed_value


## Tinggi terrain (studs) — murni, deterministik, kontinu.
## fBm manual 4 oktaf (frekuensi x2, amplitudo x0.5 per oktaf).
func height_at(x: float, z: float) -> float:
	var height := 0.0
	var amplitude := 1.0
	var frequency := 0.012
	for i in range(4):
		var sample := _noise.get_noise_2d(x * frequency + i * 137.0, z * frequency - i * 91.0)
		height += sample * amplitude
		amplitude *= 0.5
		frequency *= 2.0
	return height * 14.0 - 4.0


## Kemiringan lokal (derajat) dari selisih tetangga ±1 stud.
func slope_at(x: float, z: float) -> float:
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz) / 2.0))


## Warna zona: batu curam, tanah lereng, pasir dekat garis air, rumput datar.
func zone_color(height: float, slope_deg: float, water_level: float) -> Color:
	if slope_deg > SLOPE_ROCK + BLEND:
		return COLOR_ROCK
	if slope_deg > SLOPE_DIRT + BLEND:
		return COLOR_DIRT
	if height < water_level + SAND_BAND - BLEND:
		return COLOR_SAND
	return COLOR_GRASS


## Bangun seluruh terrain: grid chunk 16x16 studs dari -size/2 .. size/2.
func generate(seed_value: int, size := DEFAULT_SIZE, water_level := 2.0) -> Node3D:
	set_seed(seed_value)
	if size % CHUNK != 0:
		push_warning("Ukuran terrain harus kelipatan %d — pakai %d" % [CHUNK, DEFAULT_SIZE])
		size = DEFAULT_SIZE
	var root := Node3D.new()
	root.name = "Terrain"
	var half := size / 2
	for cz in range(-half, half, CHUNK):
		for cx in range(-half, half, CHUNK):
			_build_chunk(root, cx, cz, water_level, half)
	return root


func _build_chunk(root: Node3D, cx: int, cz: int, water_level: float, half: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := CHUNK + 1
	for z in range(cz, cz + CHUNK + 1):
		for x in range(cx, cx + CHUNK + 1):
			var fx := float(x)
			var fz := float(z)
			var h := height_at(fx, fz)
			var edge := x <= -half or x >= half or z <= -half or z >= half
			if edge:
				h -= SKIRT_DROP
			st.set_color(zone_color(h, slope_at(fx, fz), water_level))
			st.add_vertex(Vector3(fx, h, fz))
	for z in range(CHUNK):
		for x in range(CHUNK):
			var i0 := z * n + x
			var i1 := i0 + 1
			var i2 := i0 + n
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Chunk%d_%d" % [cx, cz]
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Col%d_%d" % [cx, cz]
	body.collision_layer = GameConfig.LAYER_WORLD
	var shape := mesh.create_trimesh_shape()
	if shape != null:
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
	root.add_child(body)
