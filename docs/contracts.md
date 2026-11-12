# Kontrak Modul — Reablox v0.6 "Roblox Parity Rebuild"

Dokumen ini adalah KONTRAK TUNGGAL antar agen pembangun. Baca penuh sebelum menulis kode.
Pelanggaran kontrak = hasil DITOLAK saat integrasi.

## 0. Aturan mutlak

1. **100% gratis selamanya** — tanpa iklan/IAP/langganan/donasi/judul "premium".
   Suite `tools/tests/test_policy_free.gd` memindai `scripts/`, `scenes/`, `data/`,
   `android_plugins/`, `prompts/`, `project.godot`, `export_presets.cfg`, `icon.svg`.
2. JANGAN mengubah file di luar kepemilikan modulmu (lihat §9).
3. `project.godot` TIDAK BOLEH diedit agen (dikelola integrator). Semua autoload dan
   input map sudah terdaftar — jangan menambah yang baru tanpa persetujuan integrator.
4. Godot 4.4.1 + GDScript. Renderer **mobile** (TANPA SDFGI/SSAO/VoxelGI — jangan pakai).
5. Semua `.gd`: indentasi TAB, lolos `gdlint` + `gdformat` (gdtoolkit 4.5.0).
6. Metodologi REA: sebelum implementasi, RISET perilaku APK Roblox asli (dokumentasi
   resmi + observasi), catat nilai pasti + sumber di `docs/rea/<modul>.md`.

## 1. Autoload (urutan _ready: atas ke bawah)

| Nama | Path | Peran |
| --- | --- | --- |
| GameConfig | `scripts/core/game_config.gd` | Konstanta paritas Roblox + registrasi input map |
| GameEvents | `scripts/core/game_events.gd` | Bus sinyal global lintas modul |
| Settings | `scripts/core/settings_mgr.gd` | Preferensi pemain (user://settings.cfg) |
| Locale | `scripts/core/locale_manager.gd` | i18n id/en dari data/locales/*.json |
| Audio | `scripts/core/audio_mgr.gd` | SFX/musik (aset di assets/audio/) |
| Saves | `scripts/core/save_mgr.gd` | Dunia JSON di user://worlds/ |
| GameState | `scripts/core/game_state.gd` | Mode permainan + leaderstats sesi |
| SceneLoader | `scripts/core/scene_loader.gd` | Navigasi menu <-> game |
| Net | `scripts/multiplayer/net_manager.gd` | Multiplayer (stub, diisi W2-D) |

API kunci (jangan ubah signature; boleh menambah):

- `GameConfig.*` — lihat §2 (konstanta), dipakai lewat nama langsung.
- `GameEvents.<sinyal>.emit(...)` / `.connect(...)` — lihat §3.
- `Settings`: `get_quality()->int (0..2)`, `set_quality(v,save:=true)`,
  `get/set_sensitivity (0.05..1)`, `get/set_invert_y(bool)`, `get/set_shift_lock(bool)`,
  `get/set_vol_master|vol_sfx|vol_music (0..1)`, `get/set_locale("id"|"en")`,
  `get/set_player_name(str<=16)`.
- `Locale.tr_key(key, fallback := "") -> String`; `set_locale(code)`; `get_locale()`.
- `Audio.play_sfx(name, pitch := 1.0)`; `play_music(track)`; `stop_music()`;
  `has_sfx(name) -> bool`. Aset: `assets/audio/sfx/<name>.wav`, `assets/audio/music/<track>.wav`.
- `Saves.save_world(name, data: Dictionary) -> bool`; `load_world(name) -> Dictionary`;
  `list_worlds() -> Array[Dictionary]` (name/saved_at/parts); `delete_world(name)`;
  `world_exists(name)`; `unique_world_name(base)`; `sanitize_name(name)`.
- `GameState`: `mode` (Mode.MODE_MENU/MODE_PLAY/MODE_BUILD), `coins`, `stage`,
  `deaths`, `checkpoint_index`, `current_world`, `player_name`;
  `reset_run(world_name)`, `add_coins(n)`, `spend_coins(n)->bool`, `next_stage()`,
  `activate_checkpoint(idx)`, `record_death()`, `in_build_mode()`.
- `SceneLoader.goto_menu() / goto_game() / goto_scene(path) -> bool`.
- `Net`: `is_active()`, `is_server()`, `start_server(port)->bool`,
  `join_server(ip,port)->bool`, `leave()`, `get_peers()->Array[Dictionary]`.

## 2. Konstanta GameConfig (1 unit = 1 stud; JANGAN hardcode ulang)

```
GRAVITY=196.2  WALK_SPEED=16.0  SPRINT_SPEED=24.0  JUMP_HEIGHT=7.2
SWIM_SPEED=16.0  CLIMB_SPEED=8.0  MAX_HEALTH=100.0  RESPAWN_TIME=5.0
CAM_MIN_DIST=0.5  CAM_MAX_DIST=128.0  CAM_DEFAULT_DIST=12.5
GRID_SIZE=1.0  ROT_STEP_DEG=90.0  MAX_BLOCKS=4000  MAX_HOTBAR=9
NET_PORT=24565  NET_TICK_HZ=15.0  DAY_LENGTH_SEC=600.0  START_TIME_HOUR=14.0
LAYER_WORLD=1  LAYER_PLAYER=2  LAYER_PARTS=4  LAYER_NPC=8  LAYER_WATER=16
LAYER_PICKUP=32  LAYER_PROJECTILE=64
```

Kecepatan lompat vertikal dari JUMP_HEIGHT: `v = sqrt(2 * GRAVITY * JUMP_HEIGHT)`.

## 3. Sinyal GameEvents

```
player_health_changed(current,maximum)  player_died()  player_respawned()
coins_changed(total)  stage_changed(stage)  checkpoint_activated(index)
tool_equipped(slot)  tool_unequipped()  tool_used(slot)
part_added(part_data)  part_removed(part_id)
world_loaded(world_name)  world_saved(world_name)
time_of_day_changed(hour)  quality_changed(level)
settings_changed()  toast_requested(message)
chat_message_received(sender,text)  net_peer_joined(peer_id,player_name)
net_peer_left(peer_id)  npc_died(npc_name)
```

## 4. Input actions (didaftarkan runtime oleh GameConfig; jangan daftar ulang)

`move_forward/back/left/right` (WASD+panah), `jump` (Space), `sprint` (Shift),
`interact` (E), `hotbar_1`..`hotbar_9`, `ui_menu` (Esc), `ui_chat` (T, /),
`zoom_in/out` (wheel), `build_rotate` (R), `build_delete` (X/Del),
`build_duplicate` (Ctrl+D), `build_undo` (Ctrl+Z), `build_redo` (Ctrl+Y, Ctrl+Shift+Z),
`build_grid` (G).

## 5. Physics layers

1 world (terrain/bangunan statis) · 2 player · 3 parts (blok bangunan) · 4 npc ·
5 water (Area3D) · 6 pickup (koin) · 7 projectile.
Karakter: `collision_layer = LAYER_PLAYER`, `collision_mask = LAYER_WORLD|LAYER_PARTS|LAYER_NPC`.

## 6. Konvensi .tscn

Root node + script saja; SEMUA anak dibangun di kode. Format persis:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1"]

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")
```

ext_resource PATH-ONLY (tanpa uid). Tool Write TIDAK membuat direktori —
`mkdir -p` via bash PATH ABSOLUT dulu, baru Write.

## 7. Aturan style GDScript (HARD)

- Indentasi TAB. Tulis file baru via tool Write (verbatim, aman).
  JANGAN PERNAH pakai tool Edit/MultiEdit pada `.gd` (mengonversi tab→spasi,
  merusak file). Untuk mengubah: tulis ulang file penuh via Write, atau skrip
  python byte-level (`open(p,'rb').read().replace(a,b)`).
- TANPA lambda satu-baris (gdformat merusaknya jadi multiline invalid).
  Pakai fungsi bernama atau perulangan `for`.
- Sebelum dinyatakan selesai: `gdformat <direktori modulmu>` (mode tulis)
  lalu `gdlint <direktori modulmu>` — wajib nol pelanggaran.
- Komentar bahasa Indonesia, identifier bahasa Inggris, `class_name` PascalCase.
- Defensif: null-check hasil `load()`/instansiasi; validasi tipe data dari
  JSON/Dictionary (`is Dictionary`, `is Array`).
- Tanpa `await` di `_ready` autoload; hindari `call_deferred` berantai panjang.

## 8. Pola suite test (WAJIB)

```gdscript
extends Node
const FW := preload("res://tools/tests/test_framework.gd")

var fw: Node

func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()

func _run_tests() -> void:
	fw.section("NamaBagian")
	fw.check_eq("nilai b", 1 + 1, 2)
	# test fisika: await get_tree().physics_frame antar step
```

- Nama: `tools/tests/test_unit_<modul>.tscn` + `.gd` — CI glob otomatis menjalankan.
- Framework mencetak `ALL_TESTS_PASS N/N`; suite gagal jika tidak.
- JANGAN tambahkan `--quit` saat menjalankan suite (memotong test fisika).
- Perintah: `timeout 300 /home/z/.local/bin/godot --headless "res://tools/tests/test_unit_<modul>.tscn"`
- Import pertama kali: `cd <project> && /home/z/.local/bin/godot --headless --import --path .`
- Suite harus DETERMINISTIK dan tidak bergantung urutan suite lain.
- Minimal 20 pemeriksaan per suite; cakupkan jalur gagal (input buruk), bukan hanya happy path.

## 9. Kepemilikan direktori & suite

| Agen | Direktori (semua di bawah repo root) | Suite |
| --- | --- | --- |
| W1-A | `scripts/graphics/`, `scripts/world/` (terrain.gd) | test_unit_world |
| W1-B | `scripts/avatar/` | test_unit_avatar |
| W1-C | `scripts/player/`, `scenes/player.tscn` | test_unit_player |
| W1-D | `scripts/core/` (hardening), `tools/audio_gen.py`, `assets/audio/` | test_unit_core, test_unit_save |
| W2-A | `scripts/build/` | test_unit_build |
| W2-B | `scripts/gameplay/elements/`, `scripts/gameplay/economy/` | test_unit_gameplay, test_unit_economy |
| W2-C | `scripts/gameplay/tools/`, `scripts/gameplay/npc/`, `scripts/gameplay/hotbar/` | test_unit_combat |
| W2-D | `scripts/multiplayer/` (semua, termasuk mengganti net_manager.gd) | test_unit_multiplayer |
| W3-A | `scripts/ui/kit/`, `scripts/ui/menu/`, `scenes/menu/` | test_unit_ui |
| W3-B | `scripts/ui/hud/` | test_unit_hud |
| W3-C | `scripts/world/` (world_manager, demo_worlds, spawn_point), `scenes/game/` | test_unit_maps, test_integration_gameplay |

Integrator (sesi utama): `project.godot`, `docs/contracts.md`, `README.md`,
`tools/tests/test_policy_free.*`, `tools/tests/test_framework.gd`.

## 10. Skema data dunia (JSON, disimpan via Saves)

```
{
  "version": 1,
  "name": "...",
  "terrain": {"seed": int, "size": int, "water_level": float},
  "time_hour": float,
  "spawn": {"pos": [x,y,z], "yaw": float},
  "parts": [{"id": int, "type": "block|sphere|cylinder|wedge|corner",
             "pos": [x,y,z], "rot_y_deg": float, "size": [x,y,z],
             "color": "#RRGGBB", "material": "plastic|wood|metal|neon|glass|...",
             "anchored": bool}],
  "elements": [{"kind": "killbrick|checkpoint|jumppad|platform|spinner|conveyor|coin",
                "pos": [...], ...param per jenis}],
  "npcs": [{"kind": "monster", "pos": [...], "patrol": [...]}]
}
```

## 11. Token terlarang (policy_free, case-insensitive)

Substring: `paypal billing payment paywall premium microtransaction gacha
revenuecat admob adsense adcolony applovin chartboost vungle ironsource xsolla
patreon saweria`.
Regex boundary: `purchase(s)`, `subscri*`, `paid`, `iap`, `coin pack`, `gem pack`,
`in-app purchase`, `unity ads`, `donat(e/ion/...)`.
AMAN dipakai: `koin`/`coins`, `gratis`/`free`, `unlock`, `harga` (nilai koin).
Konsep "beli dengan koin hasil bermain" BOLEH; uang nyata TIDAK.

## 12. Perintah dasar

- Godot: `/home/z/.local/bin/godot` (4.4.1)
- Lint: `gdlint <dirs>` · Format: `gdformat <dirs>` (gdtoolkit 4.5.0)
- Python 3.12 + PIL tersedia (untuk generator aset).
- Direktori kerja agen: salinan pribadi (diberikan integrator) — JANGAN menyentuh
  `/home/z/my-project/rblox-audit` atau salinan agen lain.
