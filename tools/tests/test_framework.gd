extends Node
## Framework test headless untuk Reablox — unit, integration, gameplay, policy.
##
## Pola pemakaian (setiap suite scene):
##   const FW := preload("res://tools/tests/test_framework.gd")
##   var fw := FW.new()
##   func _ready() -> void:
##       add_child(fw)
##       await _run_tests()          # panggil fw.check*(...) di sini
##       fw.finish()                 # mencetak ALL_TESTS_PASS / TESTS_FAILED + quit
##
## Konvensi CI: grep "ALL_TESTS_PASS" pada output stdout.
## Semua suite HARUS defensif: tidak bergantung pada urutan eksekusi suite lain
## (GameState dkk. adalah autoload yang shared saat dijalankan via test_all).

signal done(ok: bool, passed: int, total: int)

var _passed := 0
var _total := 0
var _failures: Array[String] = []


## Tandai awal bagian test (membantu membaca log).
func section(title: String) -> void:
	print("\n--- %s ---" % title)


## assertion dasar; mengembalikan nilai kondisi.
func check(desc: String, cond: bool) -> bool:
	_total += 1
	if cond:
		_passed += 1
		print("  [PASS] %s" % desc)
	else:
		_failures.append(desc)
		print("  [FAIL] %s" % desc)
	return cond


func check_eq(desc: String, got: Variant, expected: Variant) -> bool:
	var ok: bool = got == expected
	if not ok:
		print("        got:      %s" % _s(got))
		print("        expected: %s" % _s(expected))
	return check("%s  [%s == %s]" % [desc, _s(got), _s(expected)], ok)


func check_ne(desc: String, got: Variant, other: Variant) -> bool:
	return check("%s  [%s != %s]" % [desc, _s(got), _s(other)], got != other)


func check_gt(desc: String, a: Variant, b: Variant) -> bool:
	return check("%s  [%s > %s]" % [desc, _s(a), _s(b)], a > b)


func check_gte(desc: String, a: Variant, b: Variant) -> bool:
	return check("%s  [%s >= %s]" % [desc, _s(a), _s(b)], a >= b)


func check_lt(desc: String, a: Variant, b: Variant) -> bool:
	return check("%s  [%s < %s]" % [desc, _s(a), _s(b)], a < b)


func check_not_null(desc: String, obj: Variant) -> bool:
	return check("%s  (bukan null & valid)" % desc, obj != null and is_instance_valid(obj))


func check_is_type(desc: String, value: Variant, type: int) -> bool:
	return check("%s  (tipe %s)" % [desc, type_string(type)], typeof(value) == type)


## Baca file teks dari res:// (untuk test konten data). Kosong bila gagal.
func read_res(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Parse JSON dari res://; error -> Dictionary kosong (pemanggil wajib cek).
func load_json(path: String) -> Variant:
	var txt := read_res(path)
	if txt.is_empty():
		return {}
	return JSON.parse_string(txt)


## Finalisasi: ringkasan + marker + quit (kecuali dipanggil dari runner batch).
func finish(quit := true) -> void:
	var ok := _failures.is_empty()
	print("")
	if ok:
		print("ALL_TESTS_PASS %d/%d" % [_passed, _total])
	else:
		print("TESTS_FAILED %d gagal / %d total:" % [_failures.size(), _total])
		for f in _failures:
			print("  - %s" % f)
	emit_signal("done", ok, _passed, _total)
	if quit:
		get_tree().quit(0 if ok else 1)


func _s(v: Variant) -> String:
	var out := str(v)
	if out.length() > 80:
		out = out.substr(0, 77) + "..."
	return out
