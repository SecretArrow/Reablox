extends Node
## Test suite unit — katalog template dunia & skema world JSON "reablox-world".
## Domain (ground truth): scripts/world/templates.gd (katalog 10 template +
## build_world_json), scripts/world/world_manager.gd + scripts/world/game.gd
## (konsumen skema: field wajib, normalisasi, place_block).
## Jalankan: godot --headless res://tools/tests/test_unit_world.tscn

const FW := preload("res://tools/tests/test_framework.gd")
const Templates := preload("res://scripts/world/templates.gd")
const WorldManager := preload("res://scripts/world/world_manager.gd")
const BlockLibrary := preload("res://scripts/build/block_library.gd")
const GameScript := preload("res://scripts/world/game.gd")

## 10 id template persis seperti TEMPLATES di templates.gd.
const EXPECTED_IDS := [
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
## Field settings wajib yang dibaca game.gd/_normalize & mode via _settings.
const SETTING_KEYS := [
	"game_mode",
	"day_night",
	"cycle_minutes",
	"weather",
	"health_enabled",
	"build_allowed",
	"spawn",
]

var fw := FW.new()


func _ready() -> void:
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_test_catalog()
	_test_common_schema()
	_test_mode_specifics()
	_test_determinism()
	_test_unknown_id()
	await _test_consumers()


# ------------------------------------------------------------------ helpers


## Props dunia bertipe tertentu (mirror props_of mode_base, dari JSON mentah).
func _props(w: Dictionary, type: String) -> Array:
	var out: Array = []
	for p in w.get("props", []):
		if p is Dictionary and String(p.get("type", "")) == type:
			out.append(p)
	return out


func _ids_of(w: Dictionary, type: String) -> Array:
	var out: Array = []
	for p in _props(w, type):
		out.append(int(p.get("index", -1)))
	return out


func _is_hex(color: String) -> bool:
	var c := color if color.begins_with("#") else "#" + color
	return Color.html_is_valid(c)


func _is_num3(v: Variant) -> bool:
	if v is Array and (v as Array).size() >= 3:
		for e in v:
			if not (e is int or e is float):
				return false
		return true
	return false


## Perbandingan nilai setelah JSON round-trip: JSON.parse_string selalu
## menghasilkan float untuk semua angka, jadi int 1 vs float 1.0 dianggap sama.
func _json_rt_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		return _dict_rt_equal(a, b)
	if a is Array and b is Array:
		return _arr_rt_equal(a, b)
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return a == b


func _dict_rt_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k) or not _json_rt_equal(a[k], b[k]):
			return false
	return true


func _arr_rt_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not _json_rt_equal(a[i], b[i]):
			return false
	return true


# ------------------------------------------------------------------- tests


func _test_catalog() -> void:
	fw.section("Katalog template (templates.gd)")
	var cat := Templates.catalog()
	fw.check_eq("catalog() berisi 10 template", cat.size(), 10)
	var ids: Array = []
	for t in cat:
		if t is Dictionary:
			ids.append(String(t.get("id", "")))

		# catalog() harus salinan dalam (duplicate(true)): mutasi hasil tidak
		# boleh menembus konstanta TEMPLATES.
	var uniq := {}
	for i in ids:
		uniq[i] = true

		# catalog() harus salinan dalam (duplicate(true)): mutasi hasil tidak
		# boleh menembus konstanta TEMPLATES.
	fw.check_eq("id katalog unik", ids.size(), uniq.size())
	var expected_sorted := EXPECTED_IDS.duplicate()
	expected_sorted.sort()
	var got_sorted := ids.duplicate()
	got_sorted.sort()
	fw.check_eq("id katalog persis (10 mode)", got_sorted, expected_sorted)
	for t in cat:
		var tid := String(t.get("id", ""))
		fw.check(
			"entry '%s' punya name_key tpl_<id>" % tid,
			String(t.get("name_key", "")) == "tpl_" + tid
		)
		fw.check("entry '%s' punya desc_key" % tid, String(t.get("desc_key", "")).length() > 0)
		fw.check("entry '%s' punya warna hex valid" % tid, _is_hex(String(t.get("color", ""))))
		# catalog() harus salinan dalam (duplicate(true)): mutasi hasil tidak
		# boleh menembus konstanta TEMPLATES.
	cat[0]["id"] = "MUTATED"
	fw.check_ne(
		"catalog() salinan dalam (mutasi tak menembus)",
		String(Templates.catalog()[0].get("id")),
		"MUTATED"
	)


func _test_common_schema() -> void:
	fw.section("build_world_json: skema umum 10 template")
	for tid in EXPECTED_IDS:
		var w := Templates.build_world_json(tid)
		var label := "template '%s'" % tid
		fw.check_eq(
			"%s: format == reablox-world" % label, String(w.get("format", "")), "reablox-world"
		)
		fw.check_eq("%s: version == 1" % label, int(w.get("version", 0)), 1)
		var meta: Variant = w.get("meta")
		fw.check("%s: meta Dictionary" % label, meta is Dictionary)
		if meta is Dictionary:
			fw.check(
				"%s: meta.name tak kosong" % label,
				String((meta as Dictionary).get("name", "")).length() > 0
			)
			fw.check(
				"%s: meta.is_template true" % label,
				bool((meta as Dictionary).get("is_template", false))
			)

			# Validasi tiap blok terhadap skema world_manager.place_block.

			# JSON round-trip: nilai template murni primitif — serialize + parse
			# harus menghasilkan struktur & nilai identik (int/float dianggap sama
			# karena JSON.parse_string selalu menghasilkan float).
		var s: Variant = w.get("settings")
		fw.check("%s: settings Dictionary" % label, s is Dictionary)
		var sd: Dictionary = s if s is Dictionary else {}
		if s is Dictionary:
			fw.check_eq(
				"%s: settings.game_mode == id" % label, String(sd.get("game_mode", "")), tid
			)
			for k in SETTING_KEYS:
				fw.check("%s: settings.%s ada" % [label, k], sd.has(k))

				# Validasi tiap blok terhadap skema world_manager.place_block.

				# JSON round-trip: nilai template murni primitif — serialize + parse
				# harus menghasilkan struktur & nilai identik (int/float dianggap sama
				# karena JSON.parse_string selalu menghasilkan float).
			fw.check("%s: cycle_minutes > 0" % label, float(sd.get("cycle_minutes", 0.0)) > 0.0)
			fw.check("%s: spawn [x,y,z]" % label, _is_num3(sd.get("spawn")))

			# Validasi tiap blok terhadap skema world_manager.place_block.

			# JSON round-trip: nilai template murni primitif — serialize + parse
			# harus menghasilkan struktur & nilai identik (int/float dianggap sama
			# karena JSON.parse_string selalu menghasilkan float).
		var sp: Variant = w.get("spawn_points")
		fw.check("%s: spawn_points Array" % label, sp is Array)
		if sp is Array:
			fw.check("%s: spawn_points tak kosong" % label, (sp as Array).size() > 0)
			var sp_ok := true
			for p in sp:
				if not _is_num3(p):
					sp_ok = false

				# Validasi tiap blok terhadap skema world_manager.place_block.

				# JSON round-trip: nilai template murni primitif — serialize + parse
				# harus menghasilkan struktur & nilai identik (int/float dianggap sama
				# karena JSON.parse_string selalu menghasilkan float).
			fw.check("%s: tiap spawn 3 angka" % label, sp_ok)
			fw.check(
				"%s: settings.spawn == spawn_points[0]" % label, sd.get("spawn") == (sp as Array)[0]
			)
			var y_ok := true
			for p in sp:
				if float(p[1]) < 1.0:
					y_ok = false

				# Validasi tiap blok terhadap skema world_manager.place_block.

				# JSON round-trip: nilai template murni primitif — serialize + parse
				# harus menghasilkan struktur & nilai identik (int/float dianggap sama
				# karena JSON.parse_string selalu menghasilkan float).
			fw.check("%s: spawn di atas tanah (y >= 1)" % label, y_ok)

			# Validasi tiap blok terhadap skema world_manager.place_block.

			# JSON round-trip: nilai template murni primitif — serialize + parse
			# harus menghasilkan struktur & nilai identik (int/float dianggap sama
			# karena JSON.parse_string selalu menghasilkan float).
		var blocks: Variant = w.get("blocks")
		fw.check("%s: blocks Array ada" % label, blocks is Array)
		var props: Variant = w.get("props")
		fw.check("%s: props Array ada" % label, props is Array)
		# Validasi tiap blok terhadap skema world_manager.place_block.
		if blocks is Array:
			var b_ok := true
			var id_set := {}
			for b in blocks:
				if not (b is Dictionary):
					b_ok = false
					continue
				var bd: Dictionary = b
				var bid := String(bd.get("id", ""))
				if bid == "" or id_set.has(bid):
					b_ok = false
				id_set[bid] = true
				if not BlockLibrary.is_valid_shape(String(bd.get("shape", ""))):
					b_ok = false
				if not BlockLibrary.is_valid_material(String(bd.get("mat", ""))):
					b_ok = false
				if not _is_num3(bd.get("pos")) or not _is_num3(bd.get("size")):
					b_ok = false
				if not _is_hex(String(bd.get("color", ""))):
					b_ok = false
				if not (bd.get("anchored") is bool):
					b_ok = false

				# JSON round-trip: nilai template murni primitif — serialize + parse
				# harus menghasilkan struktur & nilai identik (int/float dianggap sama
				# karena JSON.parse_string selalu menghasilkan float).
			fw.check("%s: semua blok valid (id/shape/mat/pos/size/color/anchored)" % label, b_ok)

			# JSON round-trip: nilai template murni primitif — serialize + parse
			# harus menghasilkan struktur & nilai identik (int/float dianggap sama
			# karena JSON.parse_string selalu menghasilkan float).
		if props is Array:
			var p_ok := true
			for p in props:
				if not (p is Dictionary) or String((p as Dictionary).get("type", "")) == "":
					p_ok = false
				elif not _is_num3((p as Dictionary).get("pos")):
					p_ok = false
				# JSON round-trip: nilai template murni primitif — serialize + parse
				# harus menghasilkan struktur & nilai identik (int/float dianggap sama
				# karena JSON.parse_string selalu menghasilkan float).
			fw.check("%s: semua props punya type + pos" % label, p_ok)
			# JSON round-trip: nilai template murni primitif — serialize + parse
			# harus menghasilkan struktur & nilai identik (int/float dianggap sama
			# karena JSON.parse_string selalu menghasilkan float).
		var parsed: Variant = JSON.parse_string(JSON.stringify(w))
		fw.check(
			"%s: JSON round-trip identik" % label,
			parsed is Dictionary and _json_rt_equal(parsed, w)
		)


func _test_mode_specifics() -> void:
	fw.section("Config spesifik per mode")

	var obby := Templates.build_world_json("obby")
	fw.check_eq("obby: 5 checkpoint", _props(obby, "checkpoint").size(), 5)
	fw.check_eq("obby: index checkpoint urut 0..4", _ids_of(obby, "checkpoint"), [0, 1, 2, 3, 4])
	fw.check(
		"obby: semua checkpoint role obby",
		_props(obby, "checkpoint").all(func(p): return String(p.get("role")) == "obby")
	)
	fw.check_gte(
		"obby: >= 32 blok (start + 30 platform + finish)", (obby["blocks"] as Array).size(), 32
	)

	var racing := Templates.build_world_json("racing")
	fw.check_eq("racing: 4 checkpoint", _props(racing, "checkpoint").size(), 4)
	fw.check_eq("racing: index checkpoint 0..3", _ids_of(racing, "checkpoint"), [0, 1, 2, 3])
	fw.check_eq("racing: 2 kart", _props(racing, "kart").size(), 2)
	var kart_role_ok := true
	for p in _props(racing, "kart"):
		if String(p.get("role")) != "racing" or absf(float(p.get("yaw", 0.0)) - 90.0) >= 0.01:
			kart_role_ok = false
	fw.check("racing: kart role racing + yaw 90", kart_role_ok)
	fw.check_gte("racing: >= 60 blok track", (racing["blocks"] as Array).size(), 60)

	var city := Templates.build_world_json("city")
	fw.check_eq("city: 8 lampu jalan", _props(city, "streetlamp").size(), 8)
	fw.check_gte(
		"city: >= 25 blok (tanah + jalan + 20 gedung)", (city["blocks"] as Array).size(), 25
	)

	var survival := Templates.build_world_json("survival")
	fw.check_eq("survival: 5 zombie_spawner", _props(survival, "zombie_spawner").size(), 5)
	fw.check_eq("survival: 1 campfire", _props(survival, "campfire").size(), 1)
	fw.check_eq(
		"survival: cycle malam lebih cepat (6 menit)",
		float((survival["settings"] as Dictionary).get("cycle_minutes", 0.0)),
		6.0
	)
	fw.check_gte("survival: >= 30 blok arena", (survival["blocks"] as Array).size(), 30)

	var horror := Templates.build_world_json("horror")
	fw.check_eq("horror: 5 fuse", _props(horror, "fuse").size(), 5)
	fw.check_eq("horror: index fuse 0..4", _ids_of(horror, "fuse"), [0, 1, 2, 3, 4])
	fw.check_eq("horror: 1 exit", _props(horror, "exit").size(), 1)
	fw.check(
		"horror: day_night false (labirin gelap)",
		not bool((horror["settings"] as Dictionary).get("day_night", true))
	)
	fw.check_eq(
		"horror: weather fog", String((horror["settings"] as Dictionary).get("weather", "")), "fog"
	)
	fw.check_gte("horror: >= 20 blok dinding labirin", (horror["blocks"] as Array).size(), 20)

	var bedwars := Templates.build_world_json("bedwars")
	fw.check_eq("bedwars: 4 bed (4 tim)", _props(bedwars, "bed").size(), 4)
	var teams: Array = []
	for b in _props(bedwars, "bed"):
		teams.append(int(b.get("team", -1)))
	teams.sort()
	fw.check_eq("bedwars: tim bed 0..3", teams, [0, 1, 2, 3])
	fw.check_eq("bedwars: 5 generator (tengah + 4 tim)", _props(bedwars, "generator").size(), 5)
	fw.check_eq(
		"bedwars: 4 spawn point (satu per tim)", (bedwars["spawn_points"] as Array).size(), 4
	)
	fw.check(
		"bedwars: day_night false",
		not bool((bedwars["settings"] as Dictionary).get("day_night", true))
	)

	var hide_seek := Templates.build_world_json("hide_seek")
	fw.check_eq("hide_seek: 1 prop seeker", _props(hide_seek, "seeker").size(), 1)
	fw.check(
		"hide_seek: day_night false",
		not bool((hide_seek["settings"] as Dictionary).get("day_night", true))
	)
	fw.check_gte("hide_seek: >= 31 blok persembunyian", (hide_seek["blocks"] as Array).size(), 31)

	var empty := Templates.build_world_json("empty")
	fw.check_gte("empty: ada baseplate", (empty["blocks"] as Array).size(), 1)
	fw.check(
		"empty: build_allowed true (sandbox)",
		bool((empty["settings"] as Dictionary).get("build_allowed", false))
	)
	fw.check_eq("empty: tanpa props", (empty["props"] as Array).size(), 0)

	var adventure := Templates.build_world_json("adventure")
	var terr: Variant = adventure.get("terrain")
	fw.check("adventure: terrain ada", terr is Dictionary)
	if terr is Dictionary:
		var td: Dictionary = terr
		fw.check_eq("adventure: terrain size 32", int(td.get("size", 0)), 32)
		fw.check_eq("adventure: terrain seed 20240", int(td.get("seed", 0)), 20240)
		fw.check_eq(
			"adventure: heights 32x32 = 1024", (td.get("heights", []) as Array).size(), 1024
		)
		fw.check_eq("adventure: paint 32x32 = 1024", (td.get("paint", []) as Array).size(), 1024)
		var h_ok := true
		for h in td.get("heights", []):
			if not (h is float or h is int) or float(h) < 0.3:
				h_ok = false
				break
		fw.check("adventure: tinggi terrain >= 0.3 (clamp _adv_height)", h_ok)
	fw.check_eq("adventure: 10 star", _props(adventure, "star").size(), 10)
	fw.check_eq(
		"adventure: index star 0..9", _ids_of(adventure, "star"), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	)
	fw.check_eq("adventure: 1 chest", _props(adventure, "chest").size(), 1)
	fw.check_eq(
		"adventure: dunia terrain murni (tanpa blok)", (adventure["blocks"] as Array).size(), 0
	)

	var tycoon := Templates.build_world_json("tycoon")
	fw.check_eq("tycoon: 4 buypad", _props(tycoon, "buypad").size(), 4)
	fw.check(
		"tycoon: semua buypad role tycoon",
		_props(tycoon, "buypad").all(func(p): return String(p.get("role")) == "tycoon")
	)
	fw.check_gte(
		"tycoon: >= 12 blok (base + menara + conveyor)", (tycoon["blocks"] as Array).size(), 12
	)


func _test_determinism() -> void:
	fw.section("Determinisme generator (seed stabil)")
	for tid in ["obby", "city", "adventure", "hide_seek"]:
		var a := Templates.build_world_json(tid)
		var b := Templates.build_world_json(tid)
		fw.check("'%s': build dua kali identik (RNG deterministik)" % tid, a == b)


func _test_unknown_id() -> void:
	fw.section("Id tak dikenal -> fallback 'empty' (aman)")
	for bad in ["definitely_not_a_mode", "", "Obby"]:
		var w := Templates.build_world_json(String(bad))
		var label := "id '%s'" % bad
		fw.check_eq(
			"%s: game_mode jatuh ke empty" % label,
			String((w["settings"] as Dictionary).get("game_mode", "")),
			"empty"
		)
		fw.check("%s: format tetap valid" % label, String(w.get("format", "")) == "reablox-world")
		fw.check("%s: spawn_points tak kosong" % label, (w["spawn_points"] as Array).size() > 0)
		fw.check_gte("%s: baseplate tetap dibangun" % label, (w["blocks"] as Array).size(), 1)
		fw.check(
			"%s: build_allowed true (dunia bebas)" % label,
			bool((w["settings"] as Dictionary).get("build_allowed", false))
		)
		fw.check_eq("%s: tanpa props" % label, (w["props"] as Array).size(), 0)


func _test_consumers() -> void:
	fw.section("Konsumen skema: WorldManager & Game._normalize")

	# to_vec3 — konversi skema [x,y,z] -> Vector3.
	fw.check_eq("to_vec3([1,2,3])", WorldManager.to_vec3([1, 2, 3]), Vector3(1, 2, 3))
	fw.check_eq(
		"to_vec3(Vector3) diteruskan", WorldManager.to_vec3(Vector3(4, 5, 6)), Vector3(4, 5, 6)
	)
	fw.check_eq("to_vec3 array pendek -> ZERO", WorldManager.to_vec3([1, 2]), Vector3.ZERO)
	fw.check_eq("to_vec3 invalid -> ZERO", WorldManager.to_vec3("nope"), Vector3.ZERO)

	# block_transform — matematika render MultiMesh (rotasi Y + skala size).
	# Rotasi 90° tak pernah eksak di float (cos 90° ~ 1e-16) — bandingkan
	# dengan toleransi, bukan kesamaan bit.
	var t := WorldManager.block_transform(Vector3(1, 0, 0), 90.0, Vector3(2, 1, 2))
	fw.check_eq("block_transform: origin = pos", t.origin, Vector3(1, 0, 0))
	fw.check(
		"block_transform: basis.x diputar 90° lalu diskala 2 (~1e-5)",
		(t.basis.x - Vector3(0, 0, -2)).length() < 1e-5
	)
	fw.check(
		"block_transform: basis.z diputar 90° lalu diskala 2 (~1e-5)",
		(t.basis.z - Vector3(2, 0, 0)).length() < 1e-5
	)
	fw.check(
		"block_transform: basis.y tak berubah (~1e-5)",
		(t.basis.y - Vector3(0, 1, 0)).length() < 1e-5
	)

	# Game._normalize — pelengkap field wajib skema (game.gd).
	var g: Node3D = GameScript.new()
	var w1 := {"meta": {"name": "X"}}
	g._normalize(w1)
	fw.check_eq("_normalize: format wajib diisi", String(w1.get("format", "")), "reablox-world")
	fw.check_eq("_normalize: version default 1", int(w1.get("version", 0)), 1)
	var s1: Dictionary = w1["settings"]
	fw.check_eq("_normalize: game_mode default sandbox", String(s1.get("game_mode", "")), "sandbox")
	fw.check_eq("_normalize: weather default clear", String(s1.get("weather", "")), "clear")
	fw.check("_normalize: day_night default true", bool(s1.get("day_night", false)))
	fw.check("_normalize: health_enabled default true", bool(s1.get("health_enabled", false)))
	for k in ["spawn_points", "blocks", "props"]:
		fw.check("_normalize: %s jadi Array" % k, w1.get(k) is Array)

		# WorldManager.place_block — konsumsi data blok skema template.

		# apply_block_update: replace id sama.

		# Cari blok hasil replace via meta block_data.id (bukan nama node —
		# Godot mengubah nama otomatis bila sibling bernama sama belum terhapus).

		# remove_block.
	var w2 := {
		"format": "rblox-world", "settings": {"game_mode": "obby"}, "spawn_points": [[1, 2, 3]]
	}
	g._normalize(w2)
	fw.check_eq(
		"_normalize: format legacy rblox-world diterima apa adanya (kompat)",
		String(w2.get("format", "")),
		"rblox-world"
	)
	var w3 := {"format": "bogus-v9", "settings": {"game_mode": "racing"}}
	g._normalize(w3)
	fw.check_eq(
		"_normalize: format tak dikenal dinormalisasi ke reablox-world",
		String(w3.get("format", "")),
		"reablox-world"
	)
	fw.check_eq(
		"_normalize: nilai yang sudah ada dipertahankan",
		String((w2["settings"] as Dictionary).get("game_mode", "")),
		"obby"
	)
	fw.check_eq(
		"_normalize: spawn_points yang sudah ada dipertahankan",
		(w2["spawn_points"] as Array).size(),
		1
	)
	g.free()

	# WorldManager.place_block — konsumsi data blok skema template.
	var root := Node3D.new()
	root.name = "TestBlocksRoot"
	add_child(root)
	var body := WorldManager.place_block(
		root,
		{
			"id": "tb1",
			"pos": [1, 2, 3],
			"size": [2, 1, 2],
			"color": "#ff0000",
			"mat": "plastic",
			"anchored": true
		}
	)
	fw.check("place_block: anchored -> StaticBody3D", body is StaticBody3D)
	fw.check_eq("place_block: posisi blok", (body as Node3D).position, Vector3(1, 2, 3))
	var meta: Dictionary = (body as Node3D).get_meta("block_data", {})
	fw.check_eq("place_block: meta block_data.id", String(meta.get("id", "")), "tb1")
	fw.check_gte("place_block: ada collision + mesh", (body as Node).get_child_count(), 2)
	var rb := WorldManager.place_block(
		root, {"id": "tb2", "pos": [0, 5, 0], "size": [2, 2, 2], "anchored": false}
	)
	fw.check("place_block: unanchored -> RigidBody3D", rb is RigidBody3D)
	if rb is RigidBody3D:
		fw.check(
			"place_block: massa ~ volume * 0.6 (8*0.6=4.8)",
			is_equal_approx((rb as RigidBody3D).mass, 4.8)
		)
		# apply_block_update: replace id sama.

		# Cari blok hasil replace via meta block_data.id (bukan nama node —
		# Godot mengubah nama otomatis bila sibling bernama sama belum terhapus).

		# remove_block.
	WorldManager.apply_block_update(
		root,
		{"id": "tb1", "pos": [9, 9, 9], "size": [1, 1, 1], "color": "#00ff00", "anchored": true},
		false
	)
	await get_tree().process_frame
	var alive: Array = []
	for c in root.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			alive.append(c)

		# Cari blok hasil replace via meta block_data.id (bukan nama node —
		# Godot mengubah nama otomatis bila sibling bernama sama belum terhapus).

		# remove_block.
	fw.check_eq("apply_block_update: replace id sama (tetap 2 blok)", alive.size(), 2)
	# Cari blok hasil replace via meta block_data.id (bukan nama node —
	# Godot mengubah nama otomatis bila sibling bernama sama belum terhapus).
	var replaced: Dictionary = {}
	for c in alive:
		var cmeta: Dictionary = (c as Node3D).get_meta("block_data", {})
		if String(cmeta.get("id", "")) == "tb1":
			replaced = cmeta

		# remove_block.
	fw.check_eq(
		"apply_block_update: data baru (pos 9,9,9)", replaced.get("pos", []) as Array, [9, 9, 9]
	)
	# remove_block.
	WorldManager.remove_block(root, alive[0] as Node3D)
	await get_tree().process_frame
	var left := 0
	for c in root.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			left += 1
	fw.check_eq("remove_block: blok dihapus (sisa 1)", left, 1)
	root.queue_free()
	await get_tree().process_frame
