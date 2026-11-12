class_name WorldEnv
extends Node
## WorldEnv — matahari, langit prosedural, kabut tipis, dan siklus siang-malam.
## Kurva (elevasi/energi/warna) adalah fungsi murni agar bisa diuji headless.
## Siklus otomatis: 24 jam dunia = GameConfig.DAY_LENGTH_SEC detik nyata.

const SUN_ENERGY_FACTOR := 1.3
const ELEVATION_SCALE := 12.0 / 14.0

const SUN_NOON := Color(1.0, 0.97, 0.9)
const SUN_WARM := Color(1.0, 0.62, 0.35)
const SUN_NIGHT := Color(0.2, 0.25, 0.4)
const AMBIENT_DAY := Color(0.5, 0.55, 0.65)
const AMBIENT_DUSK := Color(0.45, 0.4, 0.42)
const AMBIENT_NIGHT := Color(0.08, 0.1, 0.18)
const SKY_TOP_DAY := Color(0.32, 0.55, 0.95)
const SKY_TOP_NIGHT := Color(0.02, 0.03, 0.08)
const SKY_HORIZON_DAY := Color(0.72, 0.84, 0.98)
const SKY_HORIZON_DUSK := Color(0.98, 0.55, 0.28)
const SKY_HORIZON_NIGHT := Color(0.05, 0.08, 0.15)

# Keypoint [jam, warna]: zona spek dipegang tepat, antar zona di-lerp linear
# supaya kurva kontinu di semua jam (termasuk pergantian hari di jam 24/0).
const SUN_KEYS := [
	[3.0, SUN_NIGHT],
	[5.0, SUN_WARM],
	[8.0, SUN_WARM],
	[10.0, SUN_NOON],
	[14.0, SUN_NOON],
	[16.0, SUN_WARM],
	[19.0, SUN_WARM],
	[21.0, SUN_NIGHT],
]
const AMBIENT_KEYS := [
	[4.0, AMBIENT_NIGHT],
	[6.0, AMBIENT_DUSK],
	[8.0, AMBIENT_DUSK],
	[10.0, AMBIENT_DAY],
	[14.0, AMBIENT_DAY],
	[16.0, AMBIENT_DUSK],
	[19.0, AMBIENT_DUSK],
	[21.0, AMBIENT_NIGHT],
]
const SKY_TOP_KEYS := [
	[5.0, SKY_TOP_NIGHT],
	[8.0, SKY_TOP_DAY],
	[16.0, SKY_TOP_DAY],
	[19.0, SKY_TOP_NIGHT],
]
const SKY_HORIZON_KEYS := [
	[5.0, SKY_HORIZON_NIGHT],
	[7.0, SKY_HORIZON_DUSK],
	[9.0, SKY_HORIZON_DAY],
	[15.0, SKY_HORIZON_DAY],
	[17.0, SKY_HORIZON_DUSK],
	[19.0, SKY_HORIZON_NIGHT],
]

var _hour := -1.0
var _last_whole_hour := -1
var _environment: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D


func _init() -> void:
	_hour = GameConfig.START_TIME_HOUR


func _process(delta: float) -> void:
	# Maju 24 jam per DAY_LENGTH_SEC detik, lalu wrap ke rentang 0..24.
	var step := 24.0 / GameConfig.DAY_LENGTH_SEC
	_hour = fmod(_hour + delta * step, 24.0)
	_apply_time()


## Bangun WorldEnvironment + DirectionalLight3D via kode lalu masuk ke parent.
func setup(parent: Node) -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_environment = _make_environment()
	var holder := WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = _environment
	add_child(holder)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	add_child(_sun)
	if parent != null and not is_inside_tree():
		parent.add_child(self)
	_apply_time()


## Atur jam dunia (di-clamp 0..24) dan terapkan ke matahari/langit/ambient.
func set_hour(hour: float) -> void:
	_hour = clampf(hour, 0.0, 24.0)
	_apply_time()


func get_hour() -> float:
	return _hour


## 0 = hemat (shadow & glow off); 1 = sedang; 2 = tinggi. Lainnya: warning.
func apply_quality(level: int) -> void:
	match level:
		0:
			if _sun != null:
				_sun.shadow_enabled = false
			if _environment != null:
				_environment.glow_enabled = false
		1:
			_apply_shadow(true, 1024)
			_apply_glow(0.4)
		2:
			_apply_shadow(true, 2048)
			_apply_glow(0.6)
		_:
			push_warning("Level kualitas tidak dikenal: %d (hanya 0..2)" % level)


## Fraksi elevasi matahari 0..1 — terbit jam 6, puncak jam 12, terbenam jam 18.
func sun_elevation(hour: float) -> float:
	if hour < 6.0 or hour > 18.0:
		return 0.0
	var phase := (hour - 6.0) / 12.0 * PI
	return clampf(sin(phase) * ELEVATION_SCALE, 0.0, 1.0)


## Energi matahari (Brightness ~1.3 saat puncak; 0 saat malam).
func sun_energy(hour: float) -> float:
	return SUN_ENERGY_FACTOR * sun_elevation(hour)


## Warna matahari: putih hangat siang, oranye fajar/senja, biru malam.
func sun_color(hour: float) -> Color:
	return _key_color(SUN_KEYS, hour)


## Warna ambient: terang siang, merah fajar/senja, gelap biru malam.
func ambient_color(hour: float) -> Color:
	return _key_color(AMBIENT_KEYS, hour)


## Warna puncak langit: biru siang, hampir hitam malam.
func sky_top_color(hour: float) -> Color:
	return _key_color(SKY_TOP_KEYS, hour)


## Warna horizon langit: biru muda siang, oranye senja, gelap malam.
func sky_horizon_color(hour: float) -> Color:
	return _key_color(SKY_HORIZON_KEYS, hour)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	# Kabut tipis sampai jauh (density 0.004) bernuansa warna horizon.
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = SKY_HORIZON_DAY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_DAY
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.sky = sky
	return env


func _apply_time() -> void:
	_emit_if_hour_changed()
	if _sun == null or _sky_mat == null or _environment == null:
		return
	var horizon := sky_horizon_color(_hour)
	_sun.light_color = sun_color(_hour)
	_sun.light_energy = sun_energy(_hour)
	_sun.rotation_degrees = _sun_rotation(_hour)
	_sky_mat.sky_top_color = sky_top_color(_hour)
	_sky_mat.sky_horizon_color = horizon
	_environment.ambient_light_color = ambient_color(_hour)
	_environment.fog_light_color = horizon


func _emit_if_hour_changed() -> void:
	var whole := int(floor(_hour))
	if whole == _last_whole_hour:
		return
	_last_whole_hour = whole
	GameEvents.time_of_day_changed.emit(_hour)


## Rotasi matahari: jam 6 di timur, jam 12 tepat di atas, jam 18 di barat.
func _sun_rotation(hour: float) -> Vector3:
	var elev := sun_elevation(hour) * 90.0 / ELEVATION_SCALE
	var azim := (hour - 12.0) * 15.0
	return Vector3(-elev, azim, 0.0)


func _apply_shadow(enabled: bool, atlas_size: int) -> void:
	if _sun != null:
		_sun.shadow_enabled = enabled
	RenderingServer.directional_shadow_atlas_set_size(atlas_size, false)


func _apply_glow(intensity: float) -> void:
	if _environment == null:
		return
	_environment.glow_enabled = true
	_environment.glow_intensity = intensity


## Interpolasi linear antar keypoint [jam, warna]; kontinu di seluruh 0..24.
func _key_color(keys: Array, hour: float) -> Color:
	var out: Color = keys[0][1]
	if hour <= float(keys[0][0]):
		return out
	var last := keys.size() - 1
	if hour >= float(keys[last][0]):
		out = keys[last][1]
		return out
	for i in range(last):
		var h1 := float(keys[i + 1][0])
		if hour <= h1:
			var h0 := float(keys[i][0])
			var c0: Color = keys[i][1]
			var c1: Color = keys[i + 1][1]
			var t := (hour - h0) / (h1 - h0)
			return c0.lerp(c1, t)
	return out
