extends Node
## Suite maps: katalog dunia demo, perakit obby/plaza, WorldManager
## load/save dunia. Pola kontrak §8.

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_catalog()
	_builders()
	_world_manager()


func _catalog() -> void:
	fw.section("Katalog dunia demo")
	var worlds := DemoWorlds.list()
	fw.check_eq("dua dunia demo", worlds.size(), 2)
	fw.check_eq("nama pertama", worlds[0]["name"], "Pulau Obby")
	fw.check_eq("nama kedua", worlds[1]["name"], "Plaza Kreatif")
	fw.check_eq("seed Pulau Obby", DemoWorlds.find("Pulau Obby")["seed"], 42)
	fw.check("deskripsi terisi", not str(DemoWorlds.find("Plaza Kreatif")["desc"]).is_empty())
	fw.check_eq("dunia tak dikenal kosong", DemoWorlds.find("TakDikenal").size(), 0)


func _builders() -> void:
	fw.section("Perakit level")
	var root := Node3D.new()
	add_child(root)
	var made_obby := DemoWorlds.build_obby(root)
	fw.check_gt("obby membangun > 20 elemen", made_obby, 20)
	fw.check_gte("anak obby sesuai", root.get_child_count(), 32)
	var root2 := Node3D.new()
	add_child(root2)
	var made_plaza := DemoWorlds.build_plaza(root2)
	fw.check_gte("plaza membangun >= 17 objek", made_plaza, 17)
	fw.check_gte("anak plaza sesuai", root2.get_child_count(), 17)
	fw.check_not_null("monster plaza ada", root2.get_node_or_null("NpcMonster"))
	fw.check_eq("obby root null aman", DemoWorlds.build_obby(null), 0)


func _world_manager() -> void:
	fw.section("WorldManager demo")
	var wm := WorldManager.new()
	add_child(wm)
	fw.check("load_demo Pulau Obby", wm.load_demo("Pulau Obby"))
	fw.check_not_null("root dunia terbangun", wm.get_root())
	fw.check_gte("root berisi elemen", wm.get_root().get_child_count(), 32)
	fw.check_eq("GameState ikut dunia", GameState.current_world, "Pulau Obby")
	fw.check("load_demo tak dikenal gagal", not wm.load_demo("TakDikenal"))
	fw.check_not_null("terrain tersimpan", wm.get_terrain())
	fw.check_not_null("env tersimpan", wm.get_env())
	fw.check_not_null("build manager siap", wm.get_build())

	fw.section("WorldManager simpan & muat")
	fw.check("save_current sukses", wm.save_current())
	fw.check("dunia tersimpan ada", Saves.world_exists("Pulau Obby"))
	var payload := Saves.load_world("Pulau Obby")
	fw.check("payload punya time_hour", payload.has("time_hour"))
	fw.check("payload punya terrain", payload.has("terrain"))
	wm.clear()
	fw.check("clear mengosongkan", wm.get_root() == null)
	fw.check("load_saved dunia barusan", wm.load_saved("Pulau Obby"))
	fw.check_not_null("root dunia pulih", wm.get_root())
	fw.check("load_saved salah nama gagal", not wm.load_saved("DuniaNihil"))
