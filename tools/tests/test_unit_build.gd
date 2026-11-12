extends Node
## Suite build: part library (5 tipe), warna hex, snap grid, kuota, undo/redo,
## serialisasi dunia. Pola kontrak §8.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_part_library()
	await _build_manager()


func _part_library() -> void:
	fw.section("PartLibrary")
	fw.check("tipe valid case-insensitive", PartLibrary.is_valid_type("BLOCK"))
	fw.check("tipe sphere valid", PartLibrary.is_valid_type("Sphere"))
	fw.check("tipe tak dikenal invalid", not PartLibrary.is_valid_type("kubus"))
	for kind in ["block", "sphere", "cylinder", "wedge", "corner"]:
		var node := PartLibrary.make_part(kind, Vector3(4, 2, 3), Color.RED, "plastic")
		fw.check_not_null("make_part %s menghasilkan node" % kind, node)
		fw.check(
			"%s punya mesh + collision" % kind,
			node.get_node_or_null("Mesh") != null and node.get_node_or_null("Collision") != null
		)
		fw.check_eq("%s meta part_type" % kind, str(node.get_meta("part_type")), kind)
	var hex_str := PartLibrary.hex(Color(0.1, 0.2, 0.3))
	fw.check_eq("hex dari warna", hex_str, "#1a334d")
	var back := PartLibrary.color_from_hex("#1a334d")
	fw.check("round-trip hex → warna", absf(back.r - 0.1) < 0.01 and absf(back.b - 0.3) < 0.01)
	fw.check(
		"hex invalid → fallback abu",
		PartLibrary.color_from_hex("merah") == PartLibrary.FALLBACK_COLOR
	)
	fw.check_eq("ukuran default Part Roblox", PartLibrary.default_size(), Vector3(4.0, 1.2, 2.0))


func _build_manager() -> void:
	fw.section("BuildManager dasar")
	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)
	var bm := BuildManager.new()
	add_child(bm)
	bm.setup(root)
	fw.check_eq("snap ke grid", bm.snap(Vector3(1.4, 2.6, -0.5)), Vector3(1.0, 3.0, -1.0))
	var data := bm.place_part("block", Vector3(1.4, 0.6, 2.0))
	fw.check("place valid menghasilkan data", not data.is_empty())
	fw.check_eq("id pertama 1", data.get("id", -1), 1)
	fw.check_eq(
		"posisi di-snap",
		Vector3(data["pos"][0], data["pos"][1], data["pos"][2]),
		Vector3(1.0, 1.0, 2.0)
	)
	fw.check_not_null("node part ada di root", root.get_node_or_null("Part1"))
	fw.check_eq("place tipe invalid → {}", bm.place_part("bola_api", Vector3.ZERO).size(), 0)

	fw.section("Kuota & operasi")
	bm.test_max_blocks = 3
	fw.check("place ke-2 ok", not bm.place_part("sphere", Vector3(10, 0, 0)).is_empty())
	fw.check("place ke-3 ok", not bm.place_part("wedge", Vector3(20, 0, 0)).is_empty())
	fw.check_eq("place ke-4 ditolak kuota", bm.place_part("cylinder", Vector3(30, 0, 0)).size(), 0)
	bm.test_max_blocks = -1
	fw.check_eq("count 3", bm.count(), 3)
	fw.check("move_part", bm.move_part(1, Vector3(5.4, 1.0, 1.0)))
	fw.check_eq("posisi pindah", bm.get_part(1)["pos"], [5.0, 1.0, 1.0])
	fw.check("rotate_part", bm.rotate_part(1, 90.0))
	fw.check_eq("rotasi 90", float(bm.get_part(1)["rot_y_deg"]), 90.0)
	fw.check("rotate_part lagi", bm.rotate_part(1, 290.0))
	fw.check_eq("rotasi wrap 380→20", float(bm.get_part(1)["rot_y_deg"]), 20.0)
	fw.check("recolor valid", bm.recolor_part(1, "#FF0000"))
	fw.check_eq("warna tersimpan", bm.get_part(1)["color"], "#ff0000")
	fw.check("recolor hex salah ditolak", not bm.recolor_part(1, "zzz"))
	fw.check("recolor id tak ada ditolak", not bm.recolor_part(999, "#00ff00"))
	var dup := bm.duplicate_part(1)
	fw.check("duplicate menghasilkan data", not dup.is_empty())
	fw.check("duplicate id baru", dup.get("id", 0) != 1)
	fw.check_eq("duplicate posisi +2 stud", dup["pos"][0], 7.0)

	fw.section("Undo / redo")
	fw.check_eq("count sebelum undo", bm.count(), 4)
	fw.check("undo place (duplicate)", bm.undo())
	fw.check_eq("count turun", bm.count(), 3)
	fw.check("redo place (duplicate)", bm.redo())
	fw.check_eq("count naik lagi", bm.count(), 4)
	fw.check("undo lagi (duplicate lepas)", bm.undo())
	fw.check_eq("count turun 3", bm.count(), 3)
	fw.check("undo recolor", bm.undo())
	fw.check_eq("warna kembali semula", bm.get_part(1)["color"], "#a3a2a5")
	fw.check("undo rotate kedua", bm.undo())
	fw.check_eq("rotasi kembali 90", float(bm.get_part(1)["rot_y_deg"]), 90.0)
	fw.check("undo rotate pertama", bm.undo())
	fw.check_eq("rotasi kembali 0", float(bm.get_part(1)["rot_y_deg"]), 0.0)
	fw.check("undo move", bm.undo())
	fw.check_eq("posisi kembali awal", bm.get_part(1)["pos"], [1.0, 1.0, 2.0])
	fw.check("redo move", bm.redo())
	fw.check_eq("posisi maju lagi", bm.get_part(1)["pos"], [5.0, 1.0, 1.0])

	fw.section("Hapus & pulihkan")
	fw.check("remove_part", bm.remove_part(1))
	var node1 := root.get_node_or_null("Part1")
	fw.check("node part1 dijadwalkan hapus", node1 != null and node1.is_queued_for_deletion())
	fw.check("undo remove", bm.undo())
	fw.check_eq("part dipulihkan", bm.count(), 3)
	await get_tree().process_frame

	fw.section("Serialisasi")
	var ser := bm.serialize()
	fw.check_eq("serialize count", ser.size(), 3)
	var id_sorted := true
	for i in range(1, ser.size()):
		if int(ser[i]["id"]) < int(ser[i - 1]["id"]):
			id_sorted = false
	fw.check("get_parts terurut id", id_sorted)
	bm.clear()
	fw.check_eq("clear mengosongkan", bm.count(), 0)
	var loaded := bm.load_parts(ser)
	fw.check_eq("load_parts memuat 3", loaded, 3)
	fw.check("posisi dipulihkan", not bm.get_part(3)["pos"].is_empty())
	var kotor := ser.duplicate()
	kotor.append("bukan dictionary")
	kotor.append({"type": "jenis_palsu"})
	fw.check_eq("entri rusak di-skip", bm.load_parts(kotor), 3)
