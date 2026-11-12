# Metodologi REA — Reablox v0.6 Rebuild

REA = **Research → Engineer → Assert**. Setiap modul dibangun dengan siklus:

1. **Research** — teliti perilaku APK Roblox asli untuk domain modul:
   baca dokumentasi resmi (create.roblox.com/docs), observasi nilai default,
   konvensi komunitas. Catat ANGKA PASTI (kecepatan, ukuran, warna, durasi)
   beserta sumbernya ke `docs/rea/<modul>.md`.
2. **Engine** — implementasi setara di Godot 4.4.1 sesuai `docs/contracts.md`.
   Jika Roblox dan Godot berbeda secara fundamental, pilih pendekatan yang
   menyerupai TAMPILAN/PERASAAN Roblox dan dokumentasikan penyimpangannya.
3. **Assert** — suite test headless mengunci perilaku (min. 20 pemeriksaan);
   semua suite hijau = `ALL_TESTS_PASS N/N`.

## Target paritas v0.6

- **Gameplay**: fisika Humanoid default (WalkSpeed 16, JumpHeight 7.2,
  Gravity 196.2 studs/s², Health 100, respawn 5 dtk), berenang, memanjat,
  tool/hotbar 9 slot, obby (kill brick, checkpoint, jump pad, conveyor,
  spinner, moving platform), koin + leaderstats, NPC monster, multiplayer LAN.
- **Grafis**: pencahayaan matahari + bayangan ala ShadowMap, siklus siang-malam,
  langit prosedural, kabut tipis, material khas Roblox (Plastic, Neon, Glass,
  Wood, Metal, dll.), air berombak, terrain halus berjenjang rumput/tanah/batu/pasir.
- **UI/UX**: menu ala aplikasi Roblox (kartu dunia, avatar editor, pengaturan),
  topbar, hotbar, health bar, chat + bubble, kontrol sentuh (thumbstick dinamis
  + tombol lompat), layar muat dengan tips.

## Dokumen temuan REA per modul

| Modul | File |
| --- | --- |
| Grafis + terrain | docs/rea/graphics.md |
| Avatar R6 | docs/rea/avatar.md |
| Player + kamera | docs/rea/player.md |
| Core/save/audio | docs/rea/core.md |
| Build system | docs/rea/build.md |
| Obby + ekonomi | docs/rea/gameplay.md |
| Tools + NPC | docs/rea/combat.md |
| Multiplayer | docs/rea/multiplayer.md |
| UI/UX | docs/rea/ui.md |
| World manager + demo | docs/rea/world.md |
