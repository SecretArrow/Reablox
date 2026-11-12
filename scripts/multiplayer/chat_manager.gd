class_name ChatManager
extends Node
## ChatManager — kirim pesan chat lintas jaringan via RPC andal.
## Saat offline (tidak ada peer aktif), pesan hanya dipantulkan lokal ke
## GameEvents supaya UI chat tetap berfungsi di mode pemain tunggal.

const MAX_LEN := 200


func send_chat(text: String) -> void:
	var sender := GameState.player_name
	var clean := text.strip_edges().substr(0, MAX_LEN)
	if clean.is_empty():
		return
	if _is_offline():
		_receive(sender, clean)
	else:
		_receive.rpc(sender, clean)


func send_local(text: String) -> void:
	_receive(GameState.player_name, text)


@rpc("any_peer", "call_local", "reliable")
func _receive(sender: String, text: String) -> void:
	GameEvents.chat_message_received.emit(sender, text)


func _is_offline() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer == null or peer is OfflineMultiplayerPeer
