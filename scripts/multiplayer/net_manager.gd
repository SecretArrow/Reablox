extends Node
## Net — antarmuka jaringan multiplayer (stub; implementasi penuh oleh modul
## multiplayer pada gelombang 2). Semua metode aman dipanggil headless.

signal peer_list_changed


func is_active() -> bool:
	return false


func is_server() -> bool:
	return false


func start_server(_port := -1) -> bool:
	return false


func join_server(_ip: String, _port := -1) -> bool:
	return false


func leave() -> void:
	pass


func get_peers() -> Array[Dictionary]:
	return []
