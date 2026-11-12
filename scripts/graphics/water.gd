class_name WaterPlane
extends MeshInstance3D
## WaterPlane — permukaan air ala Roblox: teal transparan, ombak sin kecil.
## Spek: docs/rea/graphics.md §3. Visual saja; Area3D renang ditangani
## modul world.


const WATER_COLOR := Color(0.07, 0.56, 0.56, 0.55)

const SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.07, 0.56, 0.56, 0.55);
uniform float wave_strength = 0.15;
uniform float wave_time = 0.0;

void vertex() {
    VERTEX.y += wave_strength * (
        sin(0.35 * VERTEX.x + 1.0 * wave_time)
        + sin(0.28 * VERTEX.z + 0.5 * wave_time + 1.7)
        + 0.5 * sin(0.9 * (VERTEX.x + VERTEX.z) + 1.5 * wave_time)
    );
}

void fragment() {
    ALBEDO = albedo_color.rgb;
    ALPHA = albedo_color.a;
    ROUGHNESS = 0.05;
    METALLIC = 0.6;
    EMISSION = albedo_color.rgb * 0.03;
}
"""


var _mat: ShaderMaterial
var _time := 0.0


func _init(size := 64.0) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat.shader = shader
	_mat.set_shader_parameter("albedo_color", WATER_COLOR)
	_mat.set_shader_parameter("wave_strength", 0.15)
	_mat.set_shader_parameter("wave_time", 0.0)
	plane.material = _mat
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_time += delta
	if _mat != null:
		_mat.set_shader_parameter("wave_time", _time)


## Tinggi ombak (studs) — murni, deterministik, periodik 4*PI detik.
static func wave_height(x: float, z: float, t: float, strength := 0.15) -> float:
	return strength * (
		sin(0.35 * x + 1.0 * t)
		+ sin(0.28 * z + 0.5 * t + 1.7)
		+ 0.5 * sin(0.9 * (x + z) + 1.5 * t)
	)


func set_wave_strength(s: float) -> void:
	var clamped := clampf(s, 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_parameter("wave_strength", clamped)


func get_wave_strength() -> float:
	if _mat == null:
		return 0.15
	return float(_mat.get_shader_parameter("wave_strength"))


func set_water_level(y: float) -> void:
	position.y = y


func get_water_level() -> float:
	return position.y
