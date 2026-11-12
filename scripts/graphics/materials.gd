class_name MaterialsLib
extends RefCounted
## MaterialsLib — pabrik StandardMaterial3D dengan 22 material paritas Roblox.
## Spek: docs/rea/graphics.md §2. Semua fungsi static, aman headless.

## kind -> [tint, roughness, metallic, emission_energy, alpha]
const _PROPS := {
	"plastic": [Color(1.0, 1.0, 1.0), 0.55, 0.0, 0.0, 1.0],
	"smooth_plastic": [Color(1.0, 1.0, 1.0), 0.15, 0.0, 0.0, 1.0],
	"wood": [Color(0.82, 0.64, 0.42), 0.85, 0.0, 0.0, 1.0],
	"wood_planks": [Color(0.72, 0.55, 0.36), 0.85, 0.0, 0.0, 1.0],
	"brick": [Color(0.9, 0.62, 0.5), 0.9, 0.0, 0.0, 1.0],
	"cobblestone": [Color(0.62, 0.62, 0.62), 0.95, 0.0, 0.0, 1.0],
	"concrete": [Color(0.85, 0.85, 0.83), 0.9, 0.0, 0.0, 1.0],
	"metal": [Color(0.85, 0.87, 0.9), 0.35, 1.0, 0.0, 1.0],
	"diamond_plate": [Color(0.8, 0.82, 0.85), 0.45, 0.9, 0.0, 1.0],
	"foil": [Color(0.9, 0.9, 0.95), 0.1, 1.0, 0.0, 1.0],
	"grass": [Color(0.55, 0.75, 0.4), 0.9, 0.0, 0.0, 1.0],
	"leafy_grass": [Color(0.35, 0.62, 0.3), 0.95, 0.0, 0.0, 1.0],
	"sand": [Color(0.9, 0.85, 0.65), 0.95, 0.0, 0.0, 1.0],
	"fabric": [Color(0.6, 0.55, 0.5), 1.0, 0.0, 0.0, 1.0],
	"snow": [Color(0.97, 0.98, 1.0), 0.8, 0.0, 0.0, 1.0],
	"mud": [Color(0.45, 0.35, 0.25), 0.95, 0.0, 0.0, 1.0],
	"asphalt": [Color(0.3, 0.3, 0.32), 0.95, 0.0, 0.0, 1.0],
	"limestone": [Color(0.88, 0.86, 0.78), 0.85, 0.0, 0.0, 1.0],
	"pavement": [Color(0.65, 0.63, 0.6), 0.9, 0.0, 0.0, 1.0],
	"neon": [Color(1.0, 1.0, 1.0), 0.5, 0.0, 2.5, 1.0],
	"glass": [Color(1.0, 1.0, 1.0), 0.05, 0.0, 0.0, 0.45],
	"force_field": [Color(1.0, 1.0, 1.0), 0.2, 0.0, 0.8, 0.55],
}


static func kinds() -> Array[String]:
	var out: Array[String] = []
	for key in _PROPS:
		out.append(key)
	return out


static func is_valid_kind(kind: String) -> bool:
	return _PROPS.has(kind.to_lower())


static func make(kind: String, color: Color) -> StandardMaterial3D:
	var key := kind.to_lower()
	if not _PROPS.has(key):
		push_warning("Material tidak dikenal: %s — memakai plastic" % kind)
		key = "plastic"
	var props: Array = _PROPS[key]
	var tint: Color = props[0]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a)
	mat.roughness = props[1]
	mat.metallic = props[2]
	var emission_energy: float = props[3]
	var alpha: float = props[4]
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	return mat
