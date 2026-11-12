extends Node
## Suite world: terrain deterministik + zona warna, WorldEnv kurva matahari,
## MaterialsLib (22 material Roblox), WaterPlane ombak. Pola kontrak §8.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node
var _time_signal_hour := -1.0


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	GameEvents.time_of_day_changed.connect(_on_time_changed)
	await _run_tests()
	fw.finish()


func _on_time_changed(hour: float) -> void:
	_time_signal_hour = hour


func _run_tests() -> void:
	_terrain()
	_world_env()
	_materials()
	_water()


func _terrain() -> void:
	fw.section("Terrain deterministik")
	var tg := TerrainGen.new()
	add_child(tg)
	tg.set_seed(42)
	var a := tg.height_at(3.5, -2.5)
	var b := tg.height_at(3.5, -2.5)
	fw.check_eq("height_at deterministik (seed sama)", a, b)
	tg.set_seed(7)
	var c := tg.height_at(3.5, -2.5)
	fw.check("seed beda hasil beda", absf(a - c) > 0.001)
	var ok_no_nan := true
	for i in range(25):
		var x := float((i * 37) % 61) - 30.0
		var z := float((i * 53) % 61) - 30.0
		if is_nan(tg.height_at(x, z)):
			ok_no_nan = false
	fw.check("tanpa NaN di 25 titik", ok_no_nan)
	var cont := absf(tg.height_at(16.0, 8.0) - tg.height_at(15.95, 8.0))
	fw.check_lt("kontinu di batas chunk (delta < 0.5)", cont, 0.5)
	fw.check_gt("rentang tinggi wajar (> -25)", tg.height_at(10.0, 10.0), -25.0)
	fw.check_lt("rentang tinggi wajar (< 25)", tg.height_at(-10.0, 7.0), 25.0)

	fw.section("Terrain zona warna")
	fw.check("batu saat curam", tg.zone_color(5.0, 80.0, 2.0) == TerrainGen.COLOR_ROCK)
	fw.check("tanah saat lereng", tg.zone_color(5.0, 45.0, 2.0) == TerrainGen.COLOR_DIRT)
	fw.check("pasir dekat air", tg.zone_color(1.5, 5.0, 2.0) == TerrainGen.COLOR_SAND)
	fw.check("rumput datar", tg.zone_color(8.0, 5.0, 2.0) == TerrainGen.COLOR_GRASS)
	fw.check("pasir mengikuti water_level", tg.zone_color(4.0, 5.0, 5.0) == TerrainGen.COLOR_SAND)

	fw.section("Terrain generate")
	var root := tg.generate(42, 32, 2.0)
	add_child(root)
	fw.check_not_null("node terrain valid", root)
	fw.check("anak >= 8 (4 chunk x 2 node)", root.get_child_count() >= 8)
	var mesh_chunks := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			mesh_chunks += 1
	fw.check_eq("4 chunk mesh", mesh_chunks, 4)
	fw.check("slope_at terdefinisi", tg.slope_at(5.0, 5.0) >= 0.0)
	var root2 := tg.generate(42, 20, 2.0)
	fw.check("size bukan kelipatan 16 aman (fallback)", root2 != null)


func _world_env() -> void:
	fw.section("WorldEnv kurva matahari")
	var env := WorldEnv.new()
	fw.check_eq("elevasi tengah malam 0", env.sun_elevation(0.0), 0.0)
	fw.check_lt("elevasi jam 6 ~ 0", env.sun_elevation(6.0), 0.001)
	fw.check_gt("elevasi jam 12 > 0.8", env.sun_elevation(12.0), 0.8)
	fw.check_eq("elevasi jam 20 = 0", env.sun_elevation(20.0), 0.0)
	fw.check_gt("energi siang > malam", env.sun_energy(12.0), env.sun_energy(0.0))
	fw.check_gt("matahari siang lebih terang", env.sun_color(12.0).r, env.sun_color(3.0).r)
	fw.check_lt("ambient malam lebih gelap", env.ambient_color(3.0).r, env.ambient_color(12.0).r)
	fw.check_gt("langit siang lebih biru", env.sky_top_color(12.0).b, env.sky_top_color(2.0).b)
	var kontinu := absf(env.sun_color(7.5).r - env.sun_color(7.4).r) < 0.2
	fw.check("kurva warna kontinu", kontinu)

	fw.section("WorldEnv runtime")
	add_child(env)
	env.setup(null)
	fw.check_not_null("env terpasang", env.get_node_or_null("Sun"))
	env.set_hour(9.0)
	fw.check_eq("set_hour bekerja", env.get_hour(), 9.0)
	fw.check("sinyal waktu teremit", _time_signal_hour >= 0.0)
	var sun := env.get_node_or_null("Sun") as DirectionalLight3D
	env.apply_quality(0)
	fw.check("quality 0 mematikan bayangan", sun != null and not sun.shadow_enabled)
	env.apply_quality(2)
	fw.check("quality 2 menyalakan bayangan", sun != null and sun.shadow_enabled)
	env.apply_quality(9)
	fw.check("quality tak dikenal aman", true)
	remove_child(env)


func _materials() -> void:
	fw.section("MaterialsLib")
	fw.check_eq("22 material", MaterialsLib.kinds().size(), 22)
	fw.check("valid case-insensitive", MaterialsLib.is_valid_kind("Neon"))
	fw.check("kind tak dikenal invalid", not MaterialsLib.is_valid_kind("kayu"))
	var neon := MaterialsLib.make("neon", Color.RED)
	fw.check("neon beremisi", neon.emission_enabled)
	var glass := MaterialsLib.make("glass", Color.WHITE)
	fw.check("glass transparan", glass.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	var metal := MaterialsLib.make("metal", Color.WHITE)
	fw.check("metal metalik penuh", is_equal_approx(metal.metallic, 1.0))
	var wood := MaterialsLib.make("wood", Color.WHITE)
	fw.check(
		"wood lebih kasar dari plastic",
		wood.roughness > MaterialsLib.make("plastic", Color.WHITE).roughness
	)
	var fallback := MaterialsLib.make("tidak_ada", Color.WHITE)
	fw.check_not_null("kind salah tetap menghasilkan material", fallback)


func _water() -> void:
	fw.section("WaterPlane")
	var v1 := WaterPlane.wave_height(3.0, -2.0, 1.25)
	var v2 := WaterPlane.wave_height(3.0, -2.0, 1.25 + 4.0 * PI)
	fw.check("ombak periodik 4*PI", absf(v1 - v2) < 0.0001)
	fw.check(
		"ombak deterministik",
		is_equal_approx(
			WaterPlane.wave_height(1.0, 2.0, 0.5), WaterPlane.wave_height(1.0, 2.0, 0.5)
		)
	)
	var plane := WaterPlane.new()
	add_child(plane)
	fw.check_not_null("plane dibuat", plane)
	plane.set_wave_strength(0.5)
	fw.check("strength tersimpan", is_equal_approx(plane.get_wave_strength(), 0.5))
	plane.set_water_level(3.0)
	fw.check_eq("level air", plane.get_water_level(), 3.0)
