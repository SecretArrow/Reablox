# REA — Player Controller + Kamera + Kontrol Sentuh (W1-C)

Riset perilaku `Humanoid` / kamera / kontrol sentuh Roblox untuk paritas Reablox.
> Catatan metode: akses langsung `create.roblox.com` dari sandbox ini diblokir
> oleh jaringan (HTTP 502/404 saat verifikasi ulang). Nilai di bawah adalah
> default terdokumentasi dari halaman resmi (URL dicantumkan) dan dikunci ulang
> oleh konstanta `GameConfig` (docs/contracts.md §2). Semua angka paritas yang
> dipakai kode mengacu GameConfig — bukan hardcode baru.

## 1. Humanoid default (karakter pemain)

| Properti | Nilai Roblox | Sumber (create.roblox.com) |
| --- | --- | --- |
| `Humanoid.WalkSpeed` | **16 studs/s** | /docs/reference/engine/classes/Humanoid (WalkSpeed) |
| `Humanoid.JumpHeight` | **7.2 studs** (default place baru, `UseJumpPower=false`) | /docs/reference/engine/classes/Humanoid (JumpHeight) |
| `Humanoid.JumpPower` | **50** (default place lama, `UseJumpPower=true`) → tinggi ≈ 50²/(2·196.2) ≈ **6.37 studs** | idem (JumpPower, UseJumpPower) |
| Kecepatan lepas untuk 7.2 studs | `v = √(2·g·h) = √(2·196.2·7.2) ≈ **53.16 studs/s**` | turunan rumus dokumentasi JumpHeight |
| `Workspace.Gravity` | **196.2 studs/s²** | /docs/reference/engine/classes/Workspace (Gravity) |
| `Humanoid.MaxHealth` / `Health` | **100 / 100** | /docs/reference/engine/classes/Humanoid |
| `Players.RespawnTime` | **5 detik** (respawn di SpawnLocation) | /docs/reference/engine/classes/Players (RespawnTime) |
| `Humanoid.MaxSlopeAngle` | **89°** (hampir vertikal masih bisa berpijak) | /docs/reference/engine/classes/Humanoid (MaxSlopeAngle) |
| `Humanoid.AutoRotate` | **true** — karakter otomatis menghadap arah gerak | /docs/reference/engine/classes/Humanoid (AutoRotate) |
| Ukuran karakter R6 | tinggi total ≈ **5 studs**, lebar bahu ≈ 2–4 studs → kapsul **r=1.0, h=5.0** ( aproksimasi hitbox) | /docs/characters/ (R6 rig dims) |

## 2. Berenang (Swimming)

- State `HumanoidStateType.Swimming` aktif saat tubuh tercelup air.
- **Kecepatan renang = WalkSpeed (16 studs/s)** — Humanoid tidak punya properti
  kecepatan renang terpisah. (Sumber: /docs/characters/character-controls +
  /docs/reference/engine/enums/HumanoidStateType)
- Kontrol: **Space = naik**, **Left Shift = turun**, WASD gerak horizontal.
  (Sumber: /docs/characters/character-controls — tabel kontrol "Swim Up/Down")
- Roblox mengapung di permukaan (buoyancy); diam dalam air tidak tenggelam cepat.
- **Penyederhanaan kita**: masuk mode renang saat probe Area3D (layer
  `LAYER_WATER`) overlap; buoyancy netral (vy → 0), arah renang horizontal saja
  (tanpa pitch kamera) — tercatat sebagai deviasi.

## 3. Memanjat (Climbing)

- Menyentuh TrussPart/tangga + menekan arah maju → state `Climbing`; gravitasi
  mati selama menempel; maju = naik, mundur = turun; lompat melepaskan.
  (Sumber: /docs/characters/character-controls + HumanoidStateType.Climbing)
- Kecepatan vertikal panjat ≈ **8 studs/s** (observasi komunitas; tidak ada
  properti resmi). Kontrak: `CLIMB_SPEED = 8.0`.
- Marker tangga di Reablox: `StaticBody3D` dengan meta `climbable = true`.

## 4. Kamera

| Aspek | Nilai Roblox | Sumber |
| --- | --- | --- |
| Jarak zoom default | **12.5 studs** (kontrak `CAM_DEFAULT_DIST`) | /docs/reference/engine/classes/StarterPlayer + observasi APK |
| Zoom min / maks | **0.5 / 128 studs** (`CameraMinZoomDistance` / `CameraMaxZoomDistance`) | /docs/reference/engine/classes/StarterPlayer |
| FOV | **70°** (`Camera.FieldOfView` default) | /docs/reference/engine/classes/Camera |
| Orbit | klik-kanan + seret (desktop); roda = zoom bertahap | /docs/characters/character-controls |
| Shift lock | kursor terkunci di tengah, **yaw karakter = yaw kamera**, offset bahu kanan ≈ 1.75 studs; klasik diaktifkan tombol Shift | /docs/characters/character-controls (Mouse Lock) |
| Batas pitch orbit | ±80° (perilaku kamera Roblox: tidak bisa membalik penuh) | observasi APK |

**Deviasi**: di Reablox tombol Shift dipakai `sprint` (kontrak input), sehingga
shift lock hanya via `Settings.get_shift_lock()` (toggle UI pengaturan).

## 5. Kontrol sentuh (mobile)

- **Thumbstick dinamis** (`TouchMovementMode.DynamicThumbstick`, default APK):
  lingkaran semi-transparan muncul di TITIK sentuh pada paruh kiri layar; knob
  mengikuti jari; lepas = hilang. (Sumber: /docs/characters/character-controls —
  bagian Mobile/Touch)
- **Tombol lompat** bulat di kanan-bawah; tekan/tahan = lompat.
- **Seret paruh kanan layar** = putar kamera; **cubit dua jari** = zoom.
- Radius thumbstick: Roblox menyesuaikan DPI perangkat; kita pakai **64 px**
  (spesifikasi modul).

## 6. Keputusan implementasi W1-C

1. Fisika manual semua (gravity/kecepatan dari `GameConfig`), `move_and_slide()`
   dengan `floor_max_angle = 89°` (paritas `MaxSlopeAngle`).
2. Akselerasi darat 160 studs/s² (terasa snap seperti Humanoid), udara 60.
3. `TERMINAL_VELOCITY = 400` studs/s — Roblox tidak mendokumentasikan batas
   jatuh; angka ini kap keamanan saja.
4. Sprint 24 (`SPRINT_SPEED`) adalah ekstensi kontrak — Roblox default tidak
   punya sprint.
5. Remote mode (`is_remote` + `apply_remote`) untuk interpolasi pemain jauh
   (W2-D multiplayer), tanpa input/gravitasi lokal.
