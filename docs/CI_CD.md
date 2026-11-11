# CI/CD Reablox — Quality Gate, Build Signed, E2E, Release & Auto-Fix

Dokumentasi pipeline CI/CD GitHub Actions untuk proyek Godot 4.4 **Reablox** (Android).
Prinsip: **tanpa build lokal** — semua lint, test, build, signing, dan rilis terjadi
di GitHub Actions. Credential signing disimpan sebagai **GitHub Secrets** (tidak pernah
ada di repo maupun log).

## Diagram alur (teks)

```text
push (branch apapun) / PR ──► ci.yml  ── Lint (gdlint + gdformat --check)
                             quality    └─ Unit+Integration+Gameplay tests (headless)
                             gate         (9 scene, 982+ checks, incl. policy FREE)

push ke main / tag v* ──► android-build.yml
                          ├─ job quality-gate (lint+test ulang — build hanya
                          │   setelah gate hijau)
                          ├─ job build: decode keystore dari Secrets
                          │   → export APK (universal + 3 ABI split)
                          │   → verifikasi signature (apksigner, tolak debug key
                          │     untuk rilis) → cek ukuran → artifact Reablox-Android
                          ├─ job screenshots: render 5 pratinjau 1080p (Xvfb+Mesa)
                          ├─ job e2e-test: universal-apk-test.yml
                          │   (SMOKE di main; STANDARD untuk tag) — install APK di
                          │   emulator, launch, crash-detect, explore otonom
                          └─ job dev-release (hanya push main): upsert pre-release
                              "dev-build" (signed, split per ABI)

tag v* (setelah build sukses) ──► release.yml ── GitHub Release stabil
                                 (download artifact run build → verifikasi ulang
                                  signature → terbitkan release + notes)

gagal? ──► autofix.yml (workflow_run: failure)
           └─ tools/ci_autofix.py: ambil log → gdformat + sync_locales →
              commit "[autofix]" → push (anti-loop: maks 1x per kegagalan;
              jika tak bisa diperbaiki → buka/komentari issue)

malam hari (03:00 UTC) ──► universal-apk-test.yml (schedule)
           └─ DEEP exploration + repair loop otonom pada APK rilisan dev-build

manual ──► tests.yml (workflow_dispatch): full suite + E2E DEEP/STANDARD
```

## Workflow 1: `CI` (`.github/workflows/ci.yml`)

Quality gate cepat (~4–6 menit), trigger **setiap push** (semua branch + tag,
kecuali perubahan docs/prompt saja) dan PR ke main.

| Job | Isi |
|---|---|
| **Lint & format check** | `gdformat --check` + `gdlint` pada `scripts/ tools/ scenes/` (gdtoolkit dipin di `requirements-ci.txt` supaya hasil deterministik) |
| **Unit, integration & gameplay tests** | `godot --headless` menjalankan 9 test scene; tiap scene wajib mencetak `ALL_TESTS_PASS`; error skrip apapun = gagal; log diunggah sebagai artifact saat gagal |

Test scene (`tools/tests/`):

| Scene | Cek | Jumlah |
|---|---|---|
| `test_unit_core` | parity locale id/en, fallback kunci, settings roundtrip + persistensi | 69 |
| `test_unit_economy` | stats/achievements gameplay-only, restore state | 66 |
| `test_unit_save` | roundtrip world, format legacy `rblox-world`, input korup, validasi path, export/import | 85 |
| `test_unit_build` | block library, place/rotate/scale/remove, undo/redo, grid snap, limit, terrain, block coding, mini script | 212 |
| `test_unit_world` | skema 10 template, config per mode, determinisme seed, konsumen (WorldManager/Game) | 391 |
| `test_integration_gameplay` | fisika pemain (jatuh/lompat/gerak/sprint/void), state machine 10 mode (obby/racing/survival/tycoon/bedwars/hide&seek/adventure/horror/city/sandbox), NPC bot, kart (masuk/mengemudi/keluar) | 87 |
| `test_policy_free` | **Guard anti-monetisasi**: scan token pembayaran/ads/subscription di seluruh source, kosmetik wajib gratis, permission Android bersih | 72 |
| `tools/test_mm` + `tools/test_budget` | MultiMesh chunk renderer + polygon budget (legacy, marker disatukan) | — |

## Workflow 2: `Android Build & E2E` (`.github/workflows/android-build.yml`)

Trigger: push ke `main`, push tag `v*`, manual dispatch. Concurrency
`cancel-in-progress` supaya push baru membatalkan build lama (hemat waktu).

1. **quality-gate** — ulang lint + seluruh test scene (build TIDAK jalan sebelum hijau).
2. **build** — Java 17 + Android SDK 34 + Godot 4.4.1 (editor & template di-cache,
   Gradle di-cache) → decode keystore rilis dari `SIGNING_KEYSTORE_BASE64` →
   `versionCode = run_number` (monotonik, dev-build selalu bisa upgrade) →
   export `Android` (gradle) + 3 preset ABI → **`apksigner verify --print-certs`**
   (APK bertanda debug cert = gagal; tag tanpa secrets = gagal) → cek ≤300 MB →
   artifact `Reablox-Android` → keystore didelete dari runner.
3. **screenshots** — render 5 pratinjau 1080p via `--screenshot-demo` (Xvfb + Mesa).
4. **e2e-test** — reusable `universal-apk-test.yml` (mode SMOKE untuk push main,
   STANDARD untuk tag): APK di-install di emulator, diluncurkan, dicek crash,
   dijelajahi otonom, screenshot dilampirkan.
5. **dev-release** (hanya push main) — upsert pre-release `dev-build`.

Fallback signing: bila Secrets kosong DAN bukan tag → pakai debug keystore
(dengan warning besar). Rilis stabil (tag) **wajib** keystore rilis.

## Workflow 3: `Release` (`.github/workflows/release.yml`)

- **Otomatis**: setelah *Android Build & E2E* sukses untuk tag `v*` → ambil artifact
  dari run tersebut → verifikasi ulang signature → `gh release create v*` + upload APK.
- **Manual** (`workflow_dispatch`): pilih `from_run_id` (build main sukses terakhir)
  dan `tag` → terbitkan rilis dari build itu.

## Workflow 4: `Extended Tests` (`.github/workflows/tests.yml`)

Manual dispatch (pilih mode SMOKE/STANDARD/DEEP/RELEASE, sumber APK, autofix
loop) + full headless suite ulang. Eksplorasi DEEP malam hari sudah ditangani
`universal-apk-test.yml` (schedule 03:00 UTC) lengkap dengan repair loop otonom.

## Workflow 5: `CI Auto-Fix` (`.github/workflows/autofix.yml`)

Trigger `workflow_run` saat **CI** atau **Android Build & E2E** gagal:
`tools/ci_autofix.py` mengambil log kegagalan → `gdformat` + `sync_locales.py` →
commit `[autofix] …` → push (anti-loop: skip bila commit terakhir sudah `[autofix]`;
maks 1 percobaan per kegagalan). Bila tidak ada yang bisa diperbaiki otomatis,
script membuat/mengomentari issue berisi ekstrak error + link run.

## Signing & Keamanan

| Secret | Isi |
|---|---|
| `SIGNING_KEYSTORE_BASE64` | Keystore rilis (base64) — asal `key-sign-apk.zip` |
| `KEYSTORE_PASSWORD` | Password keystore |
| `KEY_PASSWORD` | Password key |
| `KEY_ALIAS` | Alias key (`reablox`) |
| `SIGNING_ZIP_PASSWORD` | Password arsip `key-sign-apk.zip` |

Aturan: keystore hanya hidup di runner sementara (dihapus setelah build), tidak
pernah dicetak di log, tidak pernah di-commit. `apksigner verify` memastikan APK
rilis tidak bertanda debug keystore. Fingerprint SHA-256 sertifikat rilis
terdokumentasi di `README-SIGNING.txt` di dalam `key-sign-apk.zip`.

## Hemat waktu build

- Cache Godot editor + export templates + Gradle (hit berikutnya ±2–3 menit lebih cepat).
- `concurrency` + `cancel-in-progress` — push baru membatalkan run lama yang sama.
- `paths-ignore` docs/markdown/prompts — tidak memicu build sama sekali.
- Quality gate ringan (tanpa Android SDK) memberi sinyal merah cepat ±4 menit.
- E2E memakai artifact build yang sama (tanpa rebuild).

## Reproduksi lokal (opsional, tanpa APK)

```bash
pip install -r requirements-ci.txt
gdformat --check scripts/ tools/ scenes/ && gdlint scripts/ tools/
godot --headless --import --path .
for t in tools/tests/test_*.tscn; do godot --headless "res://$t"; done
```
