extends Node
## Suite ekonomi: koin hasil bermain, leaderstats, progres tahap.
## 100% gratis — koin hanya dari bermain, tanpa uang nyata (policy free).

const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	_run_tests()
	fw.finish()


func _run_tests() -> void:
	fw.section("Ekonomi koin")
	GameState.reset_run("test_ekonomi")
	fw.check_eq("reset → koin 0", GameState.coins, 0)
	GameState.add_coins(5)
	fw.check_eq("tambah koin", GameState.coins, 5)
	fw.check("beli kosmetik (koin cukup)", GameState.spend_coins(3))
	fw.check_eq("saldo setelah beli", GameState.coins, 2)
	fw.check("beli gagal bila koin kurang", not GameState.spend_coins(999))
	fw.check_eq("saldo tetap", GameState.coins, 2)
	GameState.add_coins(100)
	fw.check_eq("koin besar", GameState.coins, 102)
	GameState.add_coins(-5)
	fw.check_eq("add negatif diabaikan", GameState.coins, 102)

	fw.section("Leaderstats")
	var stats := Leaderstats.get_stats()
	fw.check_eq("stats koin", stats["coins"], 102)
	fw.check_eq("stats dunia", stats["world"], "test_ekonomi")
	fw.check_eq("label tahap", Leaderstats.stage_label(3), "Tahap 3")
	GameState.record_death()
	GameState.record_death()
	fw.check_eq("kematian tercatat", Leaderstats.get_stats()["deaths"], 2)
	GameState.next_stage()
	fw.check_eq("tahap naik", Leaderstats.get_stats()["stage"], 2)
	GameState.activate_checkpoint(7)
	GameState.activate_checkpoint(3)
	fw.check_eq("checkpoint hanya naik", GameState.checkpoint_index, 7)
	GameState.reset_run("dunia_baru")
	fw.check_eq("reset bersih (koin)", GameState.coins, 0)
	fw.check_eq("reset bersih (tahap)", GameState.stage, 1)
	fw.check_eq("reset bersih (kematian)", GameState.deaths, 0)
