# REA — Grafis + Terrain (W1-A)

Spek implementasi pre-baked oleh integrator (subagent tanpa akses web).
Nilai dari dokumentasi resmi Roblox (Lighting/Materials/Terrain) + konversi
param Godot 4.4 mobile renderer. Agent: implementasi LANGSUNG, tanpa riset web.

## 1. Lighting Roblox default (Lighting, Technology=ShadowMap)

| Properti Roblox | Nilai default | Padanan Godot kita |
| --- | --- | --- |
| ClockTime | 14 (jam 14:00) | `START_TIME_HOUR = 14.0` (GameConfig) |
| Brightness | 3.0 | energi matahari puncak ~1.3 |
| Ambient | [0.5, 0.5, 0.5] | ambient siang (0.55, 0.6, 0.7) × 0.9 |
| OutdoorAmbient | [0.274, 0.274, 0.274] | malam (0.08, 0.1, 0.18) |
| GlobalShadows | true | DirectionalLight3D.shadow_enabled (quality>=1) |
| FogStart/FogEnd | 0 / 100000 | kabut tipis: depth far ~0.004, warna horizon |
| GeographicLatitude | 41.73 | kemiringan sumbu matahari ~20° dari vertikal |

Kurva matahari (fungsi murni, HARUS testable tanpa render):
- `sun_elevation(h)`: jam 6 terbit, 12 puncak, 18 terbenam → sin curve:
  `elev = sin((h - 6) / 12 * PI) * (12/14)` clamp 0..1 siang; malam (h<6 atau h>18) = 0.
- `sun_energy(h)`: `1.3 * elev` (siang); malam 0.0 (bulan: ambient malam saja).
- `sun_color(h)`: siang penuh (1.0, 0.97, 0.9); jam 5–8 & 16–19 interpolasi hangat
  (1.0, 0.62, 0.35) di dekat horizon; malam (0.2, 0.25, 0.4).
- `ambient_color(h)`: siang (0.5, 0.55, 0.65); fajar/senja (0.45, 0.4, 0.42);
  malam (0.08, 0.1, 0.18).
- Sky ProceduralSkyMaterial: siang top (0.32, 0.55, 0.95) horizon (0.72, 0.84, 0.98);
  senja horizon (0.98, 0.55, 0.28); malam top (0.02, 0.03, 0.08) horizon (0.05, 0.08, 0.15).
- Yaw matahari berputar penuh 24 jam (jam 6 = timur -X, 12 = atas, 18 = barat +X).
- Kecepatan siklus: 24 jam dunia = `GameConfig.DAY_LENGTH_SEC` (600 dtk).
  Emit `GameEvents.time_of_day_changed(hour)` setiap jam bulat berubah.
- `apply_quality(level)`: 0 = shadow off, glow off, msaa off; 1 = shadow 1024,
  glow on (intensity 0.4); 2 = shadow 2048, glow 0.6 + fog halus. (Set via
  environment & light props; angka pasti bebas asal monoton naik.)

## 2. Material Roblox → StandardMaterial3D

`MaterialsLib.make(kind, color)`: albedo = color × tint; param:

| kind | tint | roughness | metallic | emission | lainnya |
| --- | --- | --- | --- | --- | --- |
| plastic | putih | 0.55 | 0 | - | |
| smooth_plastic | putih | 0.15 | 0 | - | |
| wood | (0.82, 0.64, 0.42) | 0.85 | 0 | - | |
| wood_planks | (0.72, 0.55, 0.36) | 0.85 | 0 | - | |
| brick | (0.9, 0.62, 0.5) | 0.9 | 0 | - | |
| cobblestone | (0.62, 0.62, 0.62) | 0.95 | 0 | - | |
| concrete | (0.85, 0.85, 0.83) | 0.9 | 0 | - | |
| metal | (0.85, 0.87, 0.9) | 0.35 | 1.0 | - | |
| diamond_plate | (0.8, 0.82, 0.85) | 0.45 | 0.9 | - | |
| foil | (0.9, 0.9, 0.95) | 0.1 | 1.0 | - | |
| grass | (0.55, 0.75, 0.4) | 0.9 | 0 | - | |
| leafy_grass | (0.35, 0.62, 0.3) | 0.95 | 0 | - | |
| sand | (0.9, 0.85, 0.65) | 0.95 | 0 | - | |
| fabric | (0.6, 0.55, 0.5) | 1.0 | 0 | - | |
| snow | (0.97, 0.98, 1.0) | 0.8 | 0 | - | |
| mud | (0.45, 0.35, 0.25) | 0.95 | 0 | - | |
| asphalt | (0.3, 0.3, 0.32) | 0.95 | 0 | - | |
| limestone | (0.88, 0.86, 0.78) | 0.85 | 0 | - | |
| pavement | (0.65, 0.63, 0.6) | 0.9 | 0 | - | |
| neon | albedo = color | 0.5 | 0 | emission_enabled, emissive = color, energy 2.5 | |
| glass | putih | 0.05 | 0 | - | transparency ALPHA, alpha 0.45 |
| force_field | putih | 0.2 | 0 | emission color × 0.8 | transparency alpha 0.55 |

`kinds()` mengembalikan 22 kind di atas; `is_valid_kind()` case-insensitive.

## 3. Air (Roblox Water)

WaterColor default (18, 143, 143) → (0.07, 0.56, 0.56) teal; WaterTransparency 0.6;
WaterWaveSize 0.15; WaterWaveSpeed 10; WaterReflectance 0.35.

WaterPlane: PlaneMesh + ShaderMaterial spatial:
- vertex: `y += wave_height(x, z, t)`; fungsi murni:
  `wave_height(x, z, t) = A1*sin(0.35*x + 1.1*t) + A1*sin(0.28*z + 0.9*t + 1.7)
   + A2*sin(0.9*(x+z) + 1.6*t)`, A1 = wave_strength (default 0.15 stud),
  A2 = A1*0.5. Periodik, deterministik, tanpa NaN.
- fragment: albedo teal, alpha 0.55, roughness 0.05, metallic 0.6 (kilau),
  sedikit emission teal × 0.03. `render_priority` rendah.
- API: `set_wave_strength(s)` (0..1), `set_water_level(y)` (position.y), `size`.

## 4. Terrain halus ala Roblox

- Heightmap deterministik: FastNoiseLite seed, fBm 4 oktaf, frekuensi 0.012,
  gain 0.5, lacunarity 2.0. `height_at(x, z) = fbm(x,z) * 14.0 - 4.0` (rentang
  ±10 studs, pulau menarik dengan lembah).
- Warna vertex: rumput #6FA34D (slope < 35° & di atas air+0.5); pasir #D1C999
  (dekat water_level ±0.75); tanah #7A553A (slope 35–55°); batu #737373
  (slope > 55°). Blend linear antar zona (0.5 stud transisi).
- Chunk 16×16 studs, size default 128 (8×8 chunk), skirt tepi luar (turun 2
  studs) supaya tidak ada celah terlihat dari samping.
- Collision per chunk: ConcavePolygonShape3D (dari mesh), layer LAYER_WORLD.
- Semua fungsi klasifikasi (slope, zona warna) murni & testable.

## 5. Deviasi yang disetujui

- Renderer mobile: tanpa SDFGI/SSAO (Roblox ShadowMap juga tanpa GI real-time).
- Langit malam tanpa bintang prosedural (bisa menyusul).
- Air tanpa refraksi screen-space (mobile hemat) — transparansi + kilau saja.
