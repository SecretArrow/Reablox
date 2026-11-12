# REABLOX

Sandbox 3D gratis bergaya blocky — bangun, main, dan berbagi dunia.
100% gratis selamanya: **tanpa iklan, tanpa IAP, tanpa langganan** (dijaga
otomatis oleh suite `test_policy_free` di CI).

Dibangun ulang dari nol (v0.6, branch `roblox-parity`) dengan metodologi
**REA** (Research → Engineer → Assert): perilaku APK Roblox asli diteliti,
dikunci nilainya di `docs/rea/*.md`, lalu diimplementasikan di Godot 4.4.1
dan diamankan oleh suite test headless.

## Paritas gameplay (skala 1 unit = 1 stud)

- Fisika Humanoid default Roblox: WalkSpeed 16, JumpHeight 7.2,
  gravity 196.2 studs/s², Health 100, respawn 5 dtk.
- Karakter R6 blocky klasik (tinggi 5.2 studs) + wajah smile + 10 animasi
  prosedural (idle/walk/run/jump/freefall/swim/climb/sit/wave/dance).
- Kamera orbit ala Roblox (zoom 0.5–128, default 12.5) + shift-lock.
- Kontrol sentuh ala Roblox mobile: thumbstick dinamis + tombol lompat.
- Obby: kill brick, checkpoint bertahap, jump pad, conveyor, spinner,
  moving platform; koin + leaderstats; NPC monster patroli/kejar/serang.
- Build mode ala Studio-lite: 5 tipe part, 22 material Roblox, BrickColor,
  grid snap, rotasi, undo/redo, kuota 4000 part, simpan/muat dunia JSON.
- Multiplayer LAN (ENet): host/join, sinkronisasi pemain 15 Hz, chat RPC,
  penemuan server UDP; mode remote-player terinterpolasi.

## Paritas grafis

- Siklus siang-malam (24 jam = 10 menit) dengan kurva matahari/langit/
  ambient khas Roblox (ClockTime 14 pagi default, ShadowMap).
- Material PBR khas Roblox: Plastic, SmoothPlastic, Wood, Metal, Neon
  (emisi), Glass (transparan), dan 17 lainnya.
- Terrain halus deterministik: rumput/tanah/batu/pasir per kemiringan +
  garis air, air berombak teal transparan.

## Pengembangan

- Godot 4.4.1 · renderer mobile · Android minSdk 24 (portrait lock:
  landscape).
- CI (GitHub Actions): lint gdtoolkit + 15 suite test headless (639 cek)
  pada setiap push; build APK per-ABI (arm64-v8a, armeabi-v7a, x86_64,
  universal) bertanda tangan `CN=Reablox` saat tag `v*`.
- Menjalankan test lokal:
  `godot --headless --import --path .` lalu
  `godot --headless "res://tools/tests/test_unit_core.tscn"` (tanpa `--quit`).
- Kontrak antar modul: `docs/contracts.md`. Temuan REA: `docs/rea/`.
