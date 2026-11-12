class_name Leaderstats
extends RefCounted
## Leaderstats — papan statistik sesi ala Roblox (Coins / Stage / Deaths).
## Semua nilai koin 100% dari bermain — tanpa uang nyata (policy free).


static func get_stats() -> Dictionary:
	return {
		"coins": GameState.coins,
		"stage": GameState.stage,
		"deaths": GameState.deaths,
		"world": GameState.current_world,
	}


static func stage_label(stage: int) -> String:
	return "Tahap " + str(stage)
