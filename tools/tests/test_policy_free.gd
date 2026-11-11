extends Node
## Reablox ABSOLUTE FREE POLICY guard — automated CI enforcement.
##
## POLICY (non-negotiable): Reablox is 100% FREE forever. No ads, no IAP,
## no subscriptions, no premium tiers, no pay-to-win, no loot boxes / gacha,
## no real-money payments or donations of ANY kind.
##
## What this suite enforces:
##   1. Recursive anti-monetization token scan of the game itself:
##      scripts/, scenes/, data/, android_plugins/, prompts/ plus the root
##      files project.godot, export_presets.cfg, icon.svg.
##      (Infra/docs trees — .godot/, android/, tools/, docs/, .github/ — are
##      intentionally NOT scanned.)
##   2. data/cosmetics/cosmetics.json — complete catalog, 100% free items.
##   3. data/cosmetics/presets.json — every equipped cosmetic id must resolve.
##   4. export_presets.cfg — Android permissions limited to the LAN
##      multiplayer / haptics allowlist (no billing/payment permissions).
##   5. project.godot — no monetization-related autoloads or settings.
##
## ---------------------------------------------------------------------------
## FINAL TOKEN LIST & MATCHING RULES (documented — edit CONSCIOUSLY).
## All matching is case-insensitive: each line is lowercased before matching.
##
## A) SUBSTRING tokens — matched anywhere in a line. These are SDK / brand /
##    service identifiers that can never occur inside an innocent word, so no
##    boundaries are needed (they also catch joined forms such as
##    "playbilling", "billingclient", "paymentFlow", "premiumCurrency",
##    "com.android.vending.BILLING"):
##        paypal, billing, payment, paywall, premium, microtransaction, gacha,
##        revenuecat, admob, adsense, adcolony, applovin, chartboost, vungle,
##        ironsource, xsolla, patreon, saweria
##    ("billing" alone covers playbilling / play_billing / billingclient /
##     the BILLING permission. patreon/saweria/donat* extend the suggested
##     list: "no real-money payments of ANY kind" includes donation links —
##     Indonesian-language project, so the local platform saweria is listed.)
##
## B) CONTEXT tokens — regex with custom boundaries, tuned against the REAL
##    vocabulary of this codebase (English + Indonesian). Boundary classes:
##    `(?:^|[^a-z0-9])` = "word start, underscore allowed" (snake_case join
##    counts as a hit), `(?:^|[^a-z0-9_])` = "true word start, underscore
##    counts as a word char" (snake_case join does NOT count).
##
##    token      pattern                                          rationale
##    ------     --------                                         ---------
##    stripe     (?:^|[^a-z0-9_])stripe(?![a-z0-9])               catches stripe / com.stripe /
##    stripe_sdk / stripe-api.
##                                                                 Does NOT flag "shirt_stripe",
##    "Striped Shirt" (real
##                                                                 cosmetics, i.e. clothing
##    patterns) — '_' before and
##                                                                 letters after
##    ("striped"/"stripes") block the match.
##    purchase   (?:^|[^a-z0-9_])purchases?(?![a-z])              catches "purchase",
##    "purchases", "purchase_flow",
##                                                                 "restore purchase". Does NOT
##    flag "Property purchased!"
##                                                                 (data/locales/en.json, tycoon
##    mode: buying IN-GAME
##                                                                 property with in-game money is
##    allowed). Verb forms
##
##    (purchased/purchasing/purchaser) are deliberately not
##                                                                 matched — real IAP plumbing
##    trips "billing"/"payment"/
##                                                                 "in_app_purchase"/"paypal"/...
##    anyway.
##    subscri*   (?:^|[^a-z0-9_])subscri                          catches
##    subscribe/subscription(s)/subscribed/
##                                                                 subscribing at word start;
##    "unsubscribe" passes.
##    paid       (?:^|[^a-z0-9])paid                              catches "paid", "get_paid",
##    "paid_tier";
##                                                                 "unpaid"/"underpaid" pass
##    (leading letters block).
##    iap        (?:^|[^a-z0-9])iap                               catches "IAP", "iap_manager",
##    "get_iap", "IAPManager".
##                                                                 Does NOT flag Indonesian words
##    "siap"(ready), "tiap"
##                                                                 (each), "persimpangan",
##    "diapkan" — they contain "iap"
##                                                                 behind a letter; '_' IS
##    allowed before "iap" so
##                                                                 snake_case iap identifiers are
##    still caught.
##    top-up     (?:^|[^a-z0-9])top[\s_-]?ups?(?![a-z])           catches topup / top up / top-up
##    / top_up / cash_topup.
##                                                                 Does NOT flag "stop_updating",
##    "top_upgrades",
##                                                                 "top hat", "hat_top" (real
##    cosmetics).
##    loot box   (?:^|[^a-z0-9_])loot[\s_-]?box                   lootbox / loot box / loot_box /
##    loot-box.
##    coin pack  (?:^|[^a-z0-9_])coin[\s_-]?packs?(?![a-z])       purchasable currency packs.
##    gem pack   (?:^|[^a-z0-9_])gem[\s_-]?packs?(?![a-z])        purchasable currency packs.
##    in-app     in[\s_-]?app[\s_-]?purchase                      in_app_purchase / in-app
##    purchase / inapppurchase.
##    unity ads  unity[\s_-]?ads                                  also "unityads" / "unity_ads".
##    real money (?:^|[^a-z0-9_])real[\s_-]?money                 "surreal money" passes.
##    donation   (?:^|[^a-z0-9_])donat(?:e|es|ed|ing|ion|ions)    donation/donate forms; bare
##    "donat"
##                                                                 (Indonesian: donut) passes.
##
## C) Deliberately NOT forbidden (documented decisions):
##    - bare "price" / "cost" / "cash" / "money" / "gem" / "coin" words in
##      game code: the tycoon mode has a legit IN-GAME soft-currency economy
##      (see scripts/world/modes/tycoon.gd — "price"/"_cash"/"harga"). Only
##      REAL money is forbidden; cost-like KEYS inside cosmetics.json /
##      presets.json ARE forbidden (checked semantically below).
##    - bare "ad"/"ads": false-positive prone (e.g. the policy text "no ads"
##      itself would trip); ad NETWORKS are covered by the list in A).
##    - "vending": could be an in-game vending machine; the Play Billing
##      permission com.android.vending.BILLING is caught by "billing".
##    - "iap"-style short tokens inside longer words: always boundary-matched.
##
## Match-report format: file:line [token] <trimmed line snippet>.
## Every hit is a FAILING check; the whole suite fails if any hit exists.
## ---------------------------------------------------------------------------

const FW := preload("res://tools/tests/test_framework.gd")

const SCAN_DIRS := [
	"res://scripts",
	"res://scenes",
	"res://data",
	"res://android_plugins",
	"res://prompts",
]
const SCAN_FILES := [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://icon.svg",
]
## Text file extensions eligible for the token scan (everything else —
## .png, .import, .uid, binaries — is skipped).
const TEXT_EXTS := [
	"gd",
	"tscn",
	"tres",
	"json",
	"cfg",
	"md",
	"txt",
	"kt",
	"java",
	"xml",
	"svg",
	"py",
	"shader",
	"csv",
	"yml",
	"yaml",
	"ini",
	"godot",
	"gradle",
]
## Sanity floor: if the scan ever covers fewer files than this, the scan
## itself is broken (renamed root, traversal bug) and must fail loudly.
const MIN_TOTAL_FILES := 60

## --- A) substring tokens (see header) -------------------------------------
const SUBSTRING_TOKENS := [
	"paypal",
	"billing",
	"payment",
	"paywall",
	"premium",
	"microtransaction",
	"gacha",
	"revenuecat",
	"admob",
	"adsense",
	"adcolony",
	"applovin",
	"chartboost",
	"vungle",
	"ironsource",
	"xsolla",
	"patreon",
	"saweria",
]

## --- B) [label, cheap literal gate, regex] (see header) -------------------
const REGEX_TOKENS := [
	["stripe", "stripe", "(?:^|[^a-z0-9_])stripe(?![a-z0-9])"],
	["purchase", "purchas", "(?:^|[^a-z0-9_])purchases?(?![a-z])"],
	["subscription/subscribe", "subscri", "(?:^|[^a-z0-9_])subscri"],
	["paid", "paid", "(?:^|[^a-z0-9])paid"],
	["iap", "iap", "(?:^|[^a-z0-9])iap"],
	["top-up", "top", "(?:^|[^a-z0-9])top[\\s_-]?ups?(?![a-z])"],
	["loot box", "loot", "(?:^|[^a-z0-9_])loot[\\s_-]?box"],
	["coin pack", "coin", "(?:^|[^a-z0-9_])coin[\\s_-]?packs?(?![a-z])"],
	["gem pack", "gem", "(?:^|[^a-z0-9_])gem[\\s_-]?packs?(?![a-z])"],
	["in-app purchase", "purchase", "in[\\s_-]?app[\\s_-]?purchase"],
	["unity ads", "unity", "unity[\\s_-]?ads"],
	["real money", "real", "(?:^|[^a-z0-9_])real[\\s_-]?money"],
	["donation", "donat", "(?:^|[^a-z0-9_])donat(?:e|es|ed|ing|ion|ions)"],
]

## Matcher regression samples — the matcher itself is under test so future
## token edits cannot silently break precision (false positives) or recall.
const SELFTEST_FLAG := [
	"IAPManager",
	"get_iap",
	"iap manager",
	"com.stripe.android",
	"stripe_sdk",
	"restore purchase",
	"purchase_flow",
	"topup",
	"top_up",
	"cash_topup",
	"in_app_purchase",
	"lootbox",
	"unity ads",
	"donate",
	"subscription",
	"paypal checkout",
	"google play billing",
]
const SELFTEST_IGNORE := [
	"siap",
	"tiap frame",
	"persimpangan",
	"shirt_stripe",
	"Striped Shirt",
	"Property purchased!",
	"unpaid",
	"stop_updating",
	"top hat",
	"hat_top",
	"top_upgrades",
	"unity addons",
	"donat",
]

## --- Cosmetics catalog policy ---------------------------------------------
const COSMETICS_PATH := "res://data/cosmetics/cosmetics.json"
const PRESETS_PATH := "res://data/cosmetics/presets.json"
const MIN_COSMETICS := 52
## Documented catalog categories (slots observed in the shipped data).
const EXPECTED_SLOTS := [
	"hat",
	"hair",
	"face",
	"shirt",
	"pants",
	"accessory",
	"wings",
	"back",
	"hand",
]
## Cost-like JSON keys inside cosmetics/presets data: any occurrence is a
## policy smell (items must have NO price at all). Substring matches are
## safe in this tiny key namespace; "cost"/"sku"/"iap" use snake_case word
## boundaries so e.g. a future "costume" or "skull" key is not false-flagged.
const COST_KEY_SUBSTRINGS := [
	"price",
	"currency",
	"paid",
	"money",
	"cash",
	"purchas",
	"billing",
	"premium",
	"usd",
	"rupiah",
	"gem",
	"coin",
]
const COST_KEY_BOUNDED := ["cost", "sku", "iap"]

## --- Android export permission allowlist ----------------------------------
## LAN multiplayer (WiFi Direct / Bluetooth / multicast) + haptics only.
## Anything else (billing, vending, payments, ads, tracking...) must fail.
const ALLOWED_ANDROID_PERMISSIONS := [
	"INTERNET",
	"ACCESS_NETWORK_STATE",
	"ACCESS_WIFI_STATE",
	"CHANGE_WIFI_MULTICAST_STATE",
	"NEARBY_WIFI_DEVICES",
	"BLUETOOTH",
	"BLUETOOTH_ADMIN",
	"BLUETOOTH_CONNECT",
	"BLUETOOTH_SCAN",
	"BLUETOOTH_ADVERTISE",
	"VIBRATE",
	"WAKE_LOCK",
	"ACCESS_COARSE_LOCATION",
	"ACCESS_FINE_LOCATION",
]
const ALLOWED_PERMISSION_KEYS := [
	"internet",
	"access_network_state",
	"access_wifi_state",
	"change_wifi_multicast_state",
	"nearby_wifi_devices",
	"bluetooth",
	"bluetooth_admin",
	"bluetooth_connect",
	"bluetooth_scan",
	"bluetooth_advertise",
	"vibrate",
	"wake_lock",
	"access_coarse_location",
	"access_fine_location",
]
const MONETIZATION_PERM_WORDS := [
	"billing",
	"payment",
	"purchase",
	"vending",
	"subscription",
	"premium",
	"pay",
]

var fw := FW.new()
var _rules: Array = []
var _rules_ok := true


func _ready() -> void:
	add_child(fw)
	for entry in REGEX_TOKENS:
		var e: Array = entry
		var re := RegEx.new()
		if re.compile(String(e[2])) != OK:
			_rules_ok = false
			push_error("test_policy_free: cannot compile pattern '%s'" % String(e[2]))
			continue
		_rules.append({"name": String(e[0]), "gate": String(e[1]), "re": re})
	_run_tests()
	fw.finish()


func _run_tests() -> void:
	_test_matcher()
	var groups: Array = _test_coverage_and_scan()
	_test_cosmetics()
	_test_presets()
	_test_export_permissions()
	_test_project_autoloads()


## --- 0. matcher precision regression ---------------------------------------
func _test_matcher() -> void:
	fw.section("Policy matcher self-check (token rules are under test)")
	fw.check("all %d regex token rules compiled" % REGEX_TOKENS.size(), _rules_ok)
	for s in SELFTEST_FLAG:
		fw.check("matcher FLAGS violation text: '%s'" % s, _line_hits(String(s)).size() > 0)
	for s in SELFTEST_IGNORE:
		fw.check("matcher IGNORES legitimate text: '%s'" % s, _line_hits(String(s)).is_empty())


## --- 1. coverage + token scan; returns scan groups for the report ----------
func _test_coverage_and_scan() -> Array:
	fw.section("Scan coverage (game code & data only)")
	var groups: Array = []
	var total_files := 0
	for root in SCAN_DIRS:
		var files: Array[String] = []
		_collect_files(String(root), files)
		var hits: Array[String] = []
		var lines := 0
		for f in files:
			var res := _scan_file(String(f))
			lines += int(res["lines"])
			for h in res["hits"]:
				hits.append(String(h))
		groups.append({"label": String(root), "files": files.size(), "lines": lines, "hits": hits})
		total_files += files.size()
		fw.check(
			"%s reachable and scanned (%d files, %d lines)" % [String(root), files.size(), lines],
			files.size() > 0
		)
	var root_hits: Array[String] = []
	var root_lines := 0
	for f in SCAN_FILES:
		var p := String(f)
		fw.check("root file %s present" % p, FileAccess.file_exists(p))
		var res := _scan_file(p)
		root_lines += int(res["lines"])
		for h in res["hits"]:
			root_hits.append(String(h))
	(
		groups
		. append(
			{
				"label": "root files (project.godot, export_presets.cfg, icon.svg)",
				"files": SCAN_FILES.size(),
				"lines": root_lines,
				"hits": root_hits,
			}
		)
	)
	total_files += SCAN_FILES.size()
	fw.check_gte(
		"total text files scanned (guards against a silently empty scan)",
		total_files,
		MIN_TOTAL_FILES
	)

	fw.section("Anti-monetization token scan")
	for g in groups:
		var gd: Dictionary = g
		var ghits: Array = gd["hits"]
		fw.check(
			(
				"%s: no forbidden monetization tokens (%d files, %d lines scanned)"
				% [gd["label"], gd["files"], gd["lines"]]
			),
			ghits.is_empty()
		)
		for h in ghits:
			fw.check("VIOLATION %s" % String(h), false)
	return groups


## --- 2. cosmetics catalog must be complete and 100% free --------------------
func _test_cosmetics() -> void:
	fw.section("Cosmetics catalog (data/cosmetics/cosmetics.json)")
	var cjson: Variant = fw.load_json(COSMETICS_PATH)
	fw.check("cosmetics.json parses as a JSON array", cjson is Array)
	if not (cjson is Array):
		return
	var items: Array = cjson
	fw.check_gte("cosmetic item count (shipped free catalog = 52)", items.size(), MIN_COSMETICS)
	var cosmetic_ids: Dictionary = {}
	var duplicate_ids: Array[String] = []
	var bad_items: Array[String] = []
	var slot_set: Dictionary = {}
	for i in items.size():
		var item: Variant = items[i]
		if not (item is Dictionary):
			bad_items.append("item #%d is not an object" % i)
			continue
		var d: Dictionary = item
		var item_id := str(d.get("id", ""))
		if item_id.is_empty() or cosmetic_ids.has(item_id):
			duplicate_ids.append(item_id if not item_id.is_empty() else "(empty id, item #%d)" % i)
		else:
			cosmetic_ids[item_id] = true
		var slot := str(d.get("slot", ""))
		slot_set[slot] = true
		if not (slot in EXPECTED_SLOTS):
			bad_items.append("%s -> unknown slot '%s'" % [item_id, slot])
	fw.check("all cosmetic ids unique and non-empty", duplicate_ids.is_empty())
	fw.check(
		"every item uses a documented slot category %s" % str(EXPECTED_SLOTS), bad_items.is_empty()
	)
	fw.check(
		(
			"catalog categories exactly match the documented set (found %d: %s)"
			% [slot_set.size(), str(slot_set.keys())]
		),
		slot_set.size() == EXPECTED_SLOTS.size() and bad_items.is_empty()
	)
	var cost_fields: Array = []
	_find_cost_fields(items, "cosmetics", cost_fields)
	fw.check(
		"cosmetics.json contains NO price/cost/currency keys at all (items are free)",
		cost_fields.is_empty()
	)
	var nonfree: Array[String] = []
	for e in cost_fields:
		var entry: Array = e
		var v: Variant = entry[1]
		var bad := false
		if v is float or v is int:
			bad = float(v) > 0.0
		elif v is String:
			var sv := str(v).to_lower()
			bad = not (sv.is_empty() or sv == "free" or sv == "0")
		else:
			bad = true
		if bad:
			nonfree.append("%s = %s" % [str(entry[0]), str(v)])
	fw.check("no cosmetic costs anything (any cost field value must be 0)", nonfree.is_empty())
	for nf in nonfree:
		fw.check("VIOLATION priced cosmetic: %s" % nf, false)


## --- 3. presets must reference only existing cosmetics -----------------------
func _test_presets() -> void:
	fw.section("Avatar presets (data/cosmetics/presets.json)")
	var pjson: Variant = fw.load_json(PRESETS_PATH)
	fw.check("presets.json parses as a JSON array", pjson is Array)
	if not (pjson is Array):
		return
	var presets: Array = pjson
	fw.check_gt("preset count", presets.size(), 0)
	var cosmetic_ids := _cosmetic_id_set()
	var preset_ids: Dictionary = {}
	var dup: Array[String] = []
	var bad_slots: Array[String] = []
	var missing: Array[String] = []
	var refs := 0
	for p in presets:
		if not (p is Dictionary):
			bad_slots.append("preset entry is not an object")
			continue
		var pd: Dictionary = p
		var pid := str(pd.get("id", ""))
		if pid.is_empty() or preset_ids.has(pid):
			dup.append(pid)
		else:
			preset_ids[pid] = true
		var cfgv: Variant = pd.get("config", {})
		var cfg: Dictionary = cfgv if cfgv is Dictionary else {}
		var eqv: Variant = cfg.get("equipped", {})
		var equipped: Dictionary = eqv if eqv is Dictionary else {}
		for slot in equipped:
			var cid := str(equipped[slot])
			if not (slot in EXPECTED_SLOTS):
				bad_slots.append("%s: unknown slot '%s'" % [pid, slot])
			if cid.is_empty():
				continue
			refs += 1
			if not cosmetic_ids.has(cid):
				missing.append("%s: %s='%s' not in cosmetics.json" % [pid, slot, cid])
	fw.check("preset ids unique and non-empty", dup.is_empty())
	fw.check("preset equipped slots are documented categories", bad_slots.is_empty())
	fw.check("all %d equipped cosmetic ids resolve in cosmetics.json" % refs, missing.is_empty())
	for m in missing:
		fw.check("VIOLATION dangling cosmetic reference: %s" % m, false)
	var pcost: Array = []
	_find_cost_fields(presets, "presets", pcost)
	fw.check("presets.json contains NO price/cost/currency keys at all", pcost.is_empty())


## --- 4. Android export permissions -----------------------------------------
func _test_export_permissions() -> void:
	fw.section("Android export permissions (export_presets.cfg)")
	var cfg_txt := fw.read_res("res://export_presets.cfg")
	fw.check("export_presets.cfg readable", not cfg_txt.is_empty())
	if cfg_txt.is_empty():
		return

		# Meta key: PackedStringArray of "android.permission.*" strings —
		# its contents are already validated by the extraction check above.
	var perm_re := RegEx.new()
	var cerr := perm_re.compile("android\\.permission\\.([A-Za-z0-9_]+)")
	fw.check("permission extraction regex compiles", cerr == OK)
	var perms: Array[String] = []
	if cerr == OK:
		for m in perm_re.search_all(cfg_txt):
			perms.append(String(m.get_string(1)))

		# Meta key: PackedStringArray of "android.permission.*" strings —
		# its contents are already validated by the extraction check above.
	var bad_perms: Array[String] = []
	var monetized_perms: Array[String] = []
	for p in perms:
		if not (p in ALLOWED_ANDROID_PERMISSIONS):
			bad_perms.append(p)
		var lp := p.to_lower()
		for w in MONETIZATION_PERM_WORDS:
			if lp.contains(String(w)):
				monetized_perms.append(p)
				break

		# Meta key: PackedStringArray of "android.permission.*" strings —
		# its contents are already validated by the extraction check above.
	fw.check(
		"all %d android.permission.* entries allowlisted (LAN/BT/wifi/vibrate)" % perms.size(),
		bad_perms.is_empty()
	)
	for bp in bad_perms:
		fw.check("VIOLATION android permission '%s' is not allowlisted" % bp, false)

		# Meta key: PackedStringArray of "android.permission.*" strings —
		# its contents are already validated by the extraction check above.
	fw.check(
		"no billing/payment/purchase/subscription Android permission", monetized_perms.is_empty()
	)
	for mp in monetized_perms:
		fw.check("VIOLATION monetization-related android permission '%s'" % mp, false)

		# Meta key: PackedStringArray of "android.permission.*" strings —
		# its contents are already validated by the extraction check above.
	var bad_keys: Array[String] = []
	var key_count := 0
	for line in cfg_txt.split("\n"):
		var t := line.strip_edges()
		if not t.begins_with("permissions/"):
			continue

			# Meta key: PackedStringArray of "android.permission.*" strings —
			# its contents are already validated by the extraction check above.
		var key := t.substr(String("permissions/").length()).split("=")[0]
		if key == "custom_permissions":
			# Meta key: PackedStringArray of "android.permission.*" strings —
			# its contents are already validated by the extraction check above.
			continue
		key_count += 1
		if not (key in ALLOWED_PERMISSION_KEYS):
			bad_keys.append(key)
	fw.check("all %d permissions/* export keys allowlisted" % key_count, bad_keys.is_empty())
	for bk in bad_keys:
		fw.check("VIOLATION export permission key '%s' is not allowlisted" % bk, false)


## --- 5. project.godot autoloads ---------------------------------------------
func _test_project_autoloads() -> void:
	fw.section("project.godot autoloads & settings")
	var pg := fw.read_res("res://project.godot")
	fw.check("project.godot readable", not pg.is_empty())
	if pg.is_empty():
		return
	var autoloads: Array = []
	var in_autoload := false
	for line in pg.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("[") and t.ends_with("]"):
			in_autoload = t == "[autoload]"
			continue
		if in_autoload and t.contains('="'):
			var parts := t.split("=", true, 1)
			var aname := parts[0].strip_edges()
			var apath := parts[1].strip_edges().trim_prefix('"').trim_suffix('"').trim_prefix("*")
			autoloads.append([aname, apath])
	fw.check_gt("autoload entries found in [autoload] section", autoloads.size(), 0)
	for a in autoloads:
		var entry: Array = a
		var combined := String(entry[0]) + " " + String(entry[1])
		fw.check(
			"autoload '%s' (%s) is monetization-free" % [entry[0], entry[1]],
			_line_hits(combined).is_empty()
		)


## --- helpers ----------------------------------------------------------------


## Recursively collect text files under root_dir into out (res:// paths).
func _collect_files(root_dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(root_dir)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not fname.begins_with("."):
			if d.current_is_dir():
				_collect_files(root_dir.path_join(fname), out)
			elif fname.get_extension().to_lower() in TEXT_EXTS:
				out.append(root_dir.path_join(fname))
		fname = d.get_next()
	d.list_dir_end()


## Scan one text file; returns {"lines": int, "hits": Array[String]}.
## Each hit: "file:line [token] snippet".
func _scan_file(path: String) -> Dictionary:
	var out := {"lines": 0, "hits": []}
	if not FileAccess.file_exists(path):
		(out["hits"] as Array).append("!! %s: file missing/unreadable" % path)
		return out
	var txt := fw.read_res(path)
	if txt.is_empty():
		return out
	var lines := txt.split("\n")
	out["lines"] = lines.size()
	for i in lines.size():
		var raw_line := lines[i]
		if raw_line.strip_edges().is_empty():
			continue
		for tok in _line_hits(raw_line):
			(out["hits"] as Array).append("%s:%d [%s] %s" % [path, i + 1, tok, _snippet(raw_line)])
	return out


## All tokens found on one line (case-insensitive; input is lowercased here).
func _line_hits(line: String) -> Array[String]:
	var hits: Array[String] = []
	var low := line.to_lower()
	for tok in SUBSTRING_TOKENS:
		if low.contains(String(tok)):
			hits.append(String(tok))
	for rule in _rules:
		var r: Dictionary = rule
		if low.contains(String(r["gate"])) and (r["re"] as RegEx).search(low) != null:
			hits.append(String(r["name"]))
	return hits


## Recursively find cost-like dictionary keys; appends [path, value] pairs.
func _find_cost_fields(value: Variant, path: String, out: Array) -> void:
	if value is Dictionary:
		var d: Dictionary = value
		for k in d.keys():
			var ks := str(k).to_lower()
			var hit := false
			for w in COST_KEY_SUBSTRINGS:
				if ks.contains(String(w)):
					hit = true
					break
			if not hit:
				for w in COST_KEY_BOUNDED:
					var word := String(w)
					if (
						ks == word
						or ks.begins_with(word + "_")
						or ks.ends_with("_" + word)
						or ks.contains("_" + word + "_")
					):
						hit = true
						break
			if hit:
				out.append([path + "." + str(k), d[k]])
			_find_cost_fields(d[k], path + "." + str(k), out)
	elif value is Array:
		var arr: Array = value
		for i in arr.size():
			_find_cost_fields(arr[i], "%s[%d]" % [path, i], out)


## Id set of cosmetics.json (empty if unparseable — dependent checks fail loud).
func _cosmetic_id_set() -> Dictionary:
	var ids: Dictionary = {}
	var cjson: Variant = fw.load_json(COSMETICS_PATH)
	if cjson is Array:
		for item in cjson:
			if item is Dictionary:
				var iid := str((item as Dictionary).get("id", ""))
				if not iid.is_empty():
					ids[iid] = true
	return ids


func _snippet(s: String) -> String:
	var t := s.strip_edges()
	if t.length() <= 60:
		return t
	return t.substr(0, 57) + "..."
