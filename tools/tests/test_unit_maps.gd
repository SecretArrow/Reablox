extends Node
## Test unit maps — audit kualitas 10 template dunia (REA audit).
## Membangun DUNIA ASLI tiap template via WorldManager.build_world lalu
## memvalidasi: skema JSON, blok valid & unik, spawn di atas permukaan,
## prop tidak tertanam di dalam dinding, objek melayang, dan runtime mode
## (setup + tick + objective + session). Menemukan bug map/bangunan/objek
## yang tidak terlihat oleh test unit biasa (yang memakai blocks kosong).

const FW := preload("res://tools/tests/test_framework.gd")
const TEMPLATES := preload("res://scripts/world/templates.gd")
const WORLD_MANAGER := preload("res://scripts/world/world_manager.gd")
const MODE_IDS: Array[String] = [
	"obby",
	"racing",
	"city",
	"survival",
	"horror",
	"bedwars",
	"hide_seek",
	"empty",
	"adventure",
	"tycoon",
]

## Jumlah prop minimum per mode {type: count}.
const EXPECT_PROPS := {
	"obby": {"checkpoint": 5},
	"racing": {"checkpoint": 4, "kart": 2},
	"city": {"streetlamp": 8},
	"survival": {"campfire": 1, "zombie_spawner": 5},
	"horror": {"fuse": 5, "exit": 1},
	"bedwars": {"bed": 4, "generator": 5},
	"hide_seek": {"seeker": 1},
	"empty": {},
	"adventure": {"star": 10, "chest": 1},
	"tycoon": {"buypad": 4},
}

var fw := FW.new()
var _arena: Node3D = null


func _ready() -> void:
	add_child(fw)
	_arena = Node3D.new()
	_arena.name = "MapsArena"
	add_child(_arena)
	for id in MODE_IDS:
		_audit_mode(id)
	fw.finish()


func _audit_mode(id: String) -> void:
	var wj: Dictionary = TEMPLATES.build_world_json(id)
	var settings: Dictionary = wj.get("settings", {})
	fw.section("Map %s: skema JSON" % id)
	fw.check_eq("format reablox-world", String(wj.get("format", "")), "reablox-world")
	fw.check_eq("versi skema 1", int(wj.get("version", 0)), 1)
	fw.check_eq("game_mode cocok", String(settings.get("game_mode", "")), id)
	fw.check_gte("spawn_points >= 1", (wj.get("spawn_points", []) as Array).size(), 1)

	# Build dunia asli di arena.
	var built: Dictionary = WORLD_MANAGER.build_world(wj, _arena)
	var blocks_root: Node3D = built.get("blocks")
	var props_root: Node3D = built.get("props")
	var terrain: Node3D = built.get("terrain")

	fw.section("Map %s: struktur dunia terbangun" % id)
	fw.check_not_null("blocks root ada", blocks_root)
	fw.check_not_null("props root ada", props_root)
	fw.check_not_null("terrain ada", terrain)
	fw.check_gt("blok terbangun > 0", blocks_root.get_child_count(), 0)

	var blocks: Array = wj.get("blocks", [])
	var ids := {}
	var clean := true
	for b in blocks:
		var bd: Dictionary = b
		var bid := String(bd.get("id", ""))
		if bid == "" or ids.has(bid):
			clean = false
		ids[bid] = true
		var pos := WORLD_MANAGER.to_vec3(bd.get("pos", []))
		var size := WORLD_MANAGER.to_vec3(bd.get("size", []))
		if (
			not (pos.is_finite() and size.is_finite())
			or size.x <= 0.0
			or size.y <= 0.0
			or size.z <= 0.0
		):
			clean = false
	fw.check("semua blok: id unik, pos & size finite > 0", clean)
	if id != "adventure":
		fw.check_gt("blok di JSON > 0", blocks.size(), 0)
	else:
		fw.check("adventure berbasis terrain (0 blok sah)", blocks.size() == 0)

	fw.section("Map %s: spawn di atas permukaan" % id)
	var spawns_ok := true
	for spv in wj.get("spawn_points", []):
		var sp := WORLD_MANAGER.to_vec3(spv)
		var top := _surface_top(blocks, sp.x, sp.z, terrain)
		if sp.y < top - 0.05:
			spawns_ok = false
		if _inside_block(blocks, sp, 0.1):
			spawns_ok = false
	fw.check("spawn tidak tertanam & di atas permukaan", spawns_ok)

	fw.section("Map %s: prop per-mode & integritas objek" % id)
	var props: Array = wj.get("props", [])
	var counts := {}
	for p in props:
		var t := String(p.get("type", "?"))
		counts[t] = int(counts.get(t, 0)) + 1
	for t in EXPECT_PROPS[id].keys():
		fw.check_gte(
			"prop '%s' >= %d" % [t, EXPECT_PROPS[id][t]], int(counts.get(t, 0)), EXPECT_PROPS[id][t]
		)
	var prop_ok := true
	var prop_msg := ""
	for p in props:
		var pos := WORLD_MANAGER.to_vec3(p.get("pos", []))
		if not pos.is_finite():
			prop_ok = false
			prop_msg = String(p.get("type", "?")) + " pos tidak finite"
			break
		if _inside_block(blocks, pos, 0.05):
			prop_ok = false
			prop_msg = "prop '%s' tertanam di dalam blok (%s)" % [p.get("type", "?"), pos]
			break
		var top := _surface_top(blocks, pos.x, pos.z, terrain)
		if pos.y - top > 1.25:
			prop_ok = false
			prop_msg = (
				"prop '%s' melayang %.2f di atas permukaan (%s)"
				% [p.get("type", "?"), pos.y - top, pos]
			)
			break
	fw.check("prop tidak tertanam & tidak melayang " + prop_msg, prop_ok)

	# Keterjangkauan khusus obby: jarak antar platform melompat.
	if id == "obby":
		_audit_obby_reach(blocks)

	# Runtime mode: setup + tick + objective + session.
	fw.section("Map %s: runtime mode 10 tick" % id)
	var mode := _run_mode(id, wj)
	fw.check_not_null("mode controller dibuat", mode)
	if mode != null:
		if id == "empty":
			# Sandbox memang tanpa objective; cukup cek tipe String.
			fw.check_is_type(
				"objective String (sandbox boleh kosong)",
				String(mode.call("get_objective_text")),
				TYPE_STRING
			)
		else:
			fw.check(
				"objective text tidak kosong", String(mode.call("get_objective_text")).length() > 0
			)
		fw.check_is_type("session_state Dictionary", mode.call("session_state"), TYPE_DICTIONARY)

	# Bersihkan subtree arena tiap mode (build_world menambah node baru).
	for c in _arena.get_children():
		_arena.remove_child(c)
		c.free()


func _audit_obby_reach(blocks: Array) -> void:
	var plats: Array = []
	for b in blocks:
		var bd: Dictionary = b
		var size := WORLD_MANAGER.to_vec3(bd.get("size", []))
		if absf(size.x - 3.0) < 0.01 and absf(size.y - 0.5) < 0.01:
			plats.append(WORLD_MANAGER.to_vec3(bd.get("pos", [])))
	plats.sort_custom(func(a, b): return (a as Vector3).z > (b as Vector3).z)
	var reach := true
	var gap_msg := ""
	for i in range(plats.size() - 1):
		var a: Vector3 = plats[i]
		var bb: Vector3 = plats[i + 1]
		var hd := Vector2(a.x, a.z).distance_to(Vector2(bb.x, bb.z)) - 3.0
		var dy := absf(bb.y - a.y)
		if hd > 3.5 or dy > 1.0:
			reach = false
			gap_msg = "platform %d->%d gap %.2f dy %.2f" % [i, i + 1, hd, dy]
			break
	fw.check("lompatan obby terjangkau " + gap_msg, reach)


func _run_mode(id: String, wj: Dictionary) -> Node:
	var stub := Node3D.new()
	stub.name = "GameStub_%s" % id
	_arena.add_child(stub)
	var scr: Variant = load("res://scripts/world/modes/%s.gd" % id)
	if scr == null or not (scr is GDScript):
		# Sama seperti game.gd: mode tanpa controller jatuh ke sandbox.
		scr = load("res://scripts/world/modes/sandbox.gd")
	if scr == null or not (scr is GDScript):
		return null
	var mode: Node = scr.new()
	stub.add_child(mode)
	mode.call("setup", wj, stub)
	for i in 10:
		mode.call("tick", 1.0 / 30.0)
	return mode


## Tinggi permukaan tertinggi di kolom (x,z): puncak terrain (bila ada) atau
## puncak AABB blok yang menutupi kolom tersebut (blok template rot 0).
func _surface_top(blocks: Array, x: float, z: float, terrain: Node3D) -> float:
	var top := -1000.0
	if terrain != null and terrain.has_method("get_height_at"):
		top = float(terrain.call("get_height_at", x, z))
	for b in blocks:
		var bd: Dictionary = b
		var pos := WORLD_MANAGER.to_vec3(bd.get("pos", []))
		var size := WORLD_MANAGER.to_vec3(bd.get("size", []))
		if absf(x - pos.x) <= size.x * 0.5 and absf(z - pos.z) <= size.z * 0.5:
			top = maxf(top, pos.y + size.y * 0.5)
	return top


func _inside_block(blocks: Array, pos: Vector3, margin: float) -> bool:
	for b in blocks:
		var bd: Dictionary = b
		var bpos := WORLD_MANAGER.to_vec3(bd.get("pos", []))
		var size := WORLD_MANAGER.to_vec3(bd.get("size", []))
		if (
			absf(pos.x - bpos.x) < size.x * 0.5 - margin
			and absf(pos.y - bpos.y) < size.y * 0.5 - margin
			and absf(pos.z - bpos.z) < size.z * 0.5 - margin
		):
			return true
	return false
