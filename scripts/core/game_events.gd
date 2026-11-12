extends Node
## GameEvents — bus sinyal global lintas modul.
##
## Aturan arsitektur: modul TIDAK memanggil metode modul lain secara langsung;
## komunikasi lintas modul hanya lewat sinyal di sini atau lewat autoload core.

# --- Pemain ------------------------------------------------------------------
signal player_health_changed(current: float, maximum: float)
signal player_died
signal player_respawned
signal coins_changed(total: int)
signal stage_changed(stage: int)
signal checkpoint_activated(index: int)

# --- Tool & hotbar --------------------------------------------------------------
signal tool_equipped(slot: int)
signal tool_unequipped
signal tool_used(slot: int)

# --- Build ----------------------------------------------------------------------
signal part_added(part_data: Dictionary)
signal part_removed(part_id: int)
signal world_loaded(world_name: String)
signal world_saved(world_name: String)

# --- Dunia & kualitas grafis ------------------------------------------------------
signal time_of_day_changed(hour: float)
signal quality_changed(level: int)

# --- UI ---------------------------------------------------------------------------
signal settings_changed
signal toast_requested(message: String)

# --- Multiplayer -------------------------------------------------------------------
signal chat_message_received(sender: String, text: String)
signal net_peer_joined(peer_id: int, player_name: String)
signal net_peer_left(peer_id: int)

# --- NPC -----------------------------------------------------------------------------
signal npc_died(npc_name: String)
