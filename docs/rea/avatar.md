# REA — Avatar R6 + Animasi + Kustomisasi (W1-B)

Spek implementasi pre-baked oleh integrator. Sumber nilai: dokumentasi resmi
Roblox (rig R6, BrickColor) — nilai default stabil yang dikenal luas.

## 1. Dimensi rig R6 (studs, origin di lantai antara kedua kaki)

| Part | Ukuran (w×h×d) | Posisi pusat | Pivot |
| --- | --- | --- | --- |
| LeftLeg | 1×2×1 | (-0.5, 1.0, 0) | pinggul (-0.5, 2.0, 0) |
| RightLeg | 1×2×1 | (0.5, 1.0, 0) | pinggul (0.5, 2.0, 0) |
| Torso | 2×2×1 | (0, 3.0, 0) | - |
| LeftArm | 1×2×1 | (-1.5, 3.0, 0) | bahu (-1.5, 3.7, 0) |
| RightArm | 1×2×1 | (1.5, 3.0, 0) | bahu (1.5, 3.7, 0) |
| Head | kubus 1.2³ (visual) | (0, 4.6, 0) | - |

Tinggi total 5.2 studs. Karakter menghadap -Z (wajah pada sisi -Z kepala).
Semua part = MeshInstance3D (BoxMesh) + Node3D pivot untuk bahu/pinggul
(rotasi animasi X = ayunan maju-mundur, Z = buka samping).

Wajah klasik (digambar programatik ke ImageTexture 128×128, latar transparan,
tempel sebagai albedo texture sisi -Z kepala saja — pakai array 6 material):
- mata: 2 persegi hitam ~14×22 px di (38, 40) & (76, 40);
- senyum: kurva/lengkung hitam tebal dari (36, 78) ke (92, 78) puncak tengah
  y≈92; gaya smile klasik Roblox.

## 2. Warna default "noob" klasik (BrickColor)

| Bagian | BrickColor | RGB |
| --- | --- | --- |
| Head, LeftArm, RightArm | Bright yellow | (245, 205, 48) |
| Torso | Bright blue | (13, 105, 172) |
| LeftLeg, RightLeg | Br. yellowish green | (164, 189, 71) |

## 3. Palet BrickColor (min. 32, nama → RGB hex)

White #F2F3F3, Light stone grey #E5E4DF, Medium stone grey #A3A2A5, Dark stone
grey #635F62, Black #1B2A35, Reddish brown #694028, Brown #7C5C46, Dark orange
#A05F35, Bright orange #DA8541, Br. yellowish orange #EAB892, Earth green
#27462D, Dark green #287F47, Bright green #4B974B, Lime green #00FF00, Sand
green #789082, Sand blue #74869D, Navy blue #002060, Bright blue #0D69AC,
Pastel Blue #80BBDB, Cyan #04AFEC, Toothpaste #00FFFF, Bright violet #6B327C,
Royal purple #6225D1, Lavender #A694B7, Magenta #AA00AA, Hot pink #FF00BF,
Pink #FF66CC, Bright red #C4281C, New Yeller #FFFF00, Bright yellow #F5CD30,
Brick yellow #D7C59A, Camo #3A7D15, Grime #7F8E64, Dark taupe #594633.

`color_of(name)`: case-insensitive; fallback Medium stone grey. `names()`
terurut alfabetis. `default_noob()` sesuai tabel §2.

## 4. State animasi klasik R6 (prosedural, derajat, pivot)

`pose_for(state, t)` mengembalikan Dictionary {pivot: rot_deg} — murni,
testable. Konvensi: rot X positif = ayun ke depan (menuju -Z).

| State | Pola |
| --- | --- |
| idle | tangan kecil berayun X ±3° periode 3 dtk; tanpa kaki |
| walk | lengan X = 50·sin(ωt) kiri, -50·sin(ωt) kanan; kaki X kebalik lengan sisi sama... (kaki kiri sefase lengan kanan); ω = 2π·1.6 rad/s |
| run | sama, amplitudo lengan 70°, ω = 2π·2.2 |
| jump | kedua lengan X = -170° (ke atas belakang) selama naik |
| freefall | kedua lengan Z = ±80° (terbuka samping), kaki X = ±15° |
| swim | lengan bergantian X = 60·sin(ωt) sefase kaki berlawanan, ω = 2π·1.2 |
| climb | lengan kiri X = 40·sin(ωt), kanan 40·sin(ωt+π), ω = 2π·1.5, kaki ikut |
| sit | pinggul X = -90° (kaki ke depan), lengan X = -20° |
| wave | lengan kanan Z = -140° + osilasi Y? cukup Z = -(140 + 20·sin(ωt)), ω = 2π·1.8 |
| dance | torso? — cukup lengan Z = ±(60 + 30·sin(ωt)) bergantian, pinggul X kecil |

Invalid state → ditolak (return {} + push_warning). tick(delta) memajukan t
internal lalu menerapkan pose ke pivot rig.

## 5. Konfigurasi & kosmetik

`AvatarConfig.default_config()`:
```
{"colors": {"head": "Bright yellow", "torso": "Bright blue",
  "left_arm": "Bright yellow", "right_arm": "Bright yellow",
  "left_leg": "Br. yellowish green", "right_leg": "Br. yellowish green"},
 "material": "plastic", "face": "smile", "accessories": []}
```
- validate: warna harus ada di palet (atau hex #RRGGBB), material string
  non-kosong, accessories array of string id.
- serialize/deserialize: JSON-safe round-trip.
- Kosmetik: baca `data/cosmetics/cosmetics.json` (skema sudah ada — BACA
  filenya dulu). Pasang aksesori per slot: "hat" → di atas kepala (y = 5.2),
  "back" → belakang torso (z = +0.55), "face_gear" → depan kepala. Bentuk
  minimal: kotak / silinder / bola sesuai field di JSON. Id tak dikenal →
  dilewati dengan push_warning. Preset dari presets.json = config siap pakai.

## 6. Deviasi yang disetujui

- Kepala kubus 1.2³ (Roblox asli: blok 2×1×1 + SpecialMesh — visual ekuivalen).
- Animasi prosedural sin (Roblox asli: keyframe Animation) — terasa setara.
- Aksesori bentuk primitif (bukan mesh topi detail).
