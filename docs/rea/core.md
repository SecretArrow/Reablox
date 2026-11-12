# REA — Core hardening, save, dan audio (W1-D)

Metodologi: Research → Engineer → Assert (lihat `docs/rea/README.md`).
Sumber utama: dokumentasi resmi Godot 4.4 (docs.godotengine.org) dan Roblox
Creator Docs (create.roblox.com). Catatan ini menyetujui nilai pasti yang
dikunci oleh `tools/tests/test_unit_core.tscn` + `test_unit_save.tscn`.

## 1. Konvensi audio UI/game ala Roblox mobile

Observasi APK Roblox + aset bawaan engine (`rbxasset://sounds/*`):

| Peristiwa | Aset Roblox asli | Karakter suara | Durasi |
| --- | --- | --- | --- |
| Lompat | `action_jump.mp3` | "hup" pendek, naik pitch lalu redup | ~0.1–0.2 dtk |
| Mendarat | `action_jump_land.mp3` | dentum rendah + desis singkat | ~0.2 dtk |
| Langkah (default) | `action_footsteps_plastic.mp3` | loop 4 langkah, noise lembut; pitch/volume diacak per langkah | ~0.9 dtk loop |
| Berenang | `action_swim.mp3` | cipakan noise berfilter | ~0.6 dtk |
| Tewas (klasik) | `uuhhh.mp3` ("oof") | nada turun + dengung | ~0.35 dtk |
| Pedang ayun | `swordslash.wav` | whoosh noise dengan filter menyapu turun | ~0.3 dtk |
| Pedang kena | `swordlunge.wav`/`unsheath.wav` + denting logam | square ter-detune + noise | ~0.2 dtk |
| Air | `impact_water.mp3` | splash: noise lowpass menyapu | ~0.4 dtk |
| Tombol UI | `button.wav`/`electronicpingshort.wav` | klik/keping pendek, sangat singkat | ~0.05–0.1 dtk |

Konvensi tambahan yang dipakai generator:

- **Koin**: game Roblox klasik (obby/tycoon) memakai chime 2–3 nada naik
  (mirip "coin" arcade: nada tinggi kedua ~ seperempat/quint di atas pertama).
  Reablox: dua nada B5 (987.77 Hz) → E6 (1318.51 Hz).
- **Checkpoint**: chime sukses 3 nada naik (G5 → C6 → E6), umum di obby.
- **Footstep per material**: Roblox memilih suara langkah berdasarkan material
  terrain/part (Grass, Stone, dll.) — Reablox menyediakan `footstep_grass`
  (lebih lembut/gelap) dan `footstep_stone` (lebih tajam/klik).
- **Volume aman**: `Sound.Volume` default Roblox 0.5 (skala 0–1). Generator
  menormalisasi tiap SFX ke peak ≤ 0.8 dan musik ke peak ≤ 0.6 supaya headroom
  bus Master cukup.
- Durasi SFX pendek (0.08–0.6 dtk) supaya responsif di mobile dan hemat memori.

Sumber: Roblox Creator Docs — "Sounds and Music", "Class Sound", serta daftar
aset `rbxasset://sounds/` yang dipakai default Humanoid/Tools
(create.roblox.com/docs/characters; create.roblox.com/docs/ui).

## 2. Praktik Godot 4.4 (sumber: docs.godotengine.org/4.4)

### Penulisan file atomik (save data)

- `FileAccess.store_string()` + `close()` TIDAK menjamin file utuh bila proses
  mati di tengah jalan. Praktik aman: tulis ke `<file>.tmp`, lalu
  `DirAccess.rename_absolute(tmp, target)` — rename pada filesystem yang sama
  bersifat atomik (POSIX). Sumber: "File system" / "Saving games"
  (docs.godotengine.org/4.4/tutorials/io/data_paths.html,
  docs.godotengine.org/4.4/tutorials/io/saving_games.html).
- `DirAccess.rename_absolute(from, to)` menerima path absolut;
  `ProjectSettings.globalize_path("user://...")` dipakai untuk memastikan path
  absolut OS.
- Jika rename gagal, file `.tmp` dibersihkan agar tidak menumpuk.
- `FileAccess.get_error()` setelah `store_string()` dipakai untuk mendeteksi
  kegagalan tulis (disk penuh).

### ConfigFile error handling (settings)

- `ConfigFile.load(path)` mengembalikan `Error`: `OK`, `ERR_FILE_NOT_FOUND`
  (wajar saat pertama kali jalan → pakai default), atau error parse lain
  (file korup → warning + clamp semua nilai).
- `get_value(section, key, default)` aman dipanggil walau section belum ada.
- Karena nilai bisa diedit tangan/versi lama, SEMUA nilai di-clamp saat `_ready`
  (mis. `quality` 0..2, `sensitivity` 0.05..1, `vol_*` 0..1, `locale`
  hanya "id"/"en", `player_name` ≤ 16 karakter); bila ada yang berubah karena
  clamp → simpan ulang sekali. Ini pola "load → sanitize → persist".

### AudioStreamWAV & import WAV

- WAV diimpor oleh `ResourceImporterWAV`; format 16-bit PCM dipertahankan
  secara default; `force/mono` bisa diaktifkan, tapi generator kita sudah
  mono sejak awal.
- Loop: opsi impor `loop/enable` + `loop_begin`/`loop_end` (sampel). Kontrak
  W1-D: cukup WAV biasa — loop diaktifkan lewat kode nanti
  (`stream.loop_mode = AudioStreamWAV.LOOP_FORWARD` +
  `loop_end = data.size()/mix_rate`). Generator tetap merancang musik agar
  ekor nada di-wrap ke awal buffer sehingga loop mulus.
- SFX dibuat non-loop (default). `AudioStreamPlayer.pitch_scale` dipakai
  Audio mgr untuk variasi (mis. langkah 0.9–1.1) seperti Roblox mengacak
  pitch langkah.
- Sumber: docs.godotengine.org/4.4/tutorials/audio/audio_streams.html dan
  halaman class `AudioStreamWAV`, `ResourceImporterWAV`.

### Screenshot headless

- `Viewport.get_texture().get_image()` pada server render headless (dummy)
  mengembalikan gambar kosong → `capture()` harus mengembalikan `""` dan tidak
  crash (penting untuk CI). Sumber: class `Viewport`, `Image.is_empty()`.

## 3. Keputusan teknis generator (tools/audio_gen.py)

- STDLIB saja: `wave`, `struct`, `math`, `random` (kontrak). Deterministik:
  `random.seed(20240901)` tetap.
- SFX: 44100 Hz, 16-bit, mono, 0.08–0.6 dtk, envelope attack singkat (≤ 5 ms)
  + decay eksponensial; campuran sine/square/noise; one-pole lowpass untuk
  noise; soft-clip `tanh` + normalisasi peak per file.
- Musik: **22050 Hz** (deviasi disengaj dari 44.1 kHz, didokumentasikan):
  kontrak menuntut total aset < 2 MB; 2 track loop 12–20 dtk pada 44.1 kHz
  sendiri sudah ~2.1–2.8 MB. 22050 Hz tetap menampung harmonik pad/arpeggio
  hingga 11 kHz (cukup untuk musik lembut), menghemat 50% ukuran → total
  aset akhir ± 1.6 MB (< 2 MB).
- Loop mulus: semua event (pad/arp/bass) dirender ke buffer dengan indeks
  modulo panjang loop, sehingga ekor nada akhir terdengar di awal track.
- `music/menu.wav` (16 dtk, 120 BPM): progresi Am–F–C–G (add9) — "ceria
  minor": pad lembut + arpeggio 8th + bass. `music/world.wav` (12 dtk):
  pad lambat Cmaj7–Am7–Fmaj7 + arpeggio sparse (ambient tenang).

## 4. Konstanta paritas yang dikunci suite

`WALK_SPEED=16.0`, `JUMP_HEIGHT=7.2`, `GRAVITY=196.2`, `MAX_HEALTH=100.0`,
`RESPAWN_TIME=5.0` — sesuai default `Humanoid` Roblox
(create.roblox.com/docs/characters/reference#humanoid — WalkSpeed 16,
JumpHeight 7.2 studs, Health 100; Workspace.Gravity default 196.2;
RespawnTime 5). Nilai ini TIDAK diubah oleh W1-D; suite hanya mengunci.

## 5. Gap / penyederhanaan (jujur dicatat)

- Tidak ada akses internet di lingkungan kerja agen ini, jadi riset memakai
  pengetahuan dokumentasi resmi di atas tanpa fetch langsung; nilai yang
  dikutip adalah nilai default stabil yang juga dikunci `docs/contracts.md`.
- Musik 22050 Hz (bukan 44.1 kHz) — alasan ukuran, lihat §3.
- WAV tanpa metadata loop; loop musik dinyalakan lewat kode (kontrak).
- `AudioStreamWAV` import default (tanpa kompresi) — file kecil, lossless.
