extends Node
## Suite unit modul AVATAR — BrickColors, AvatarRig, AvatarAnimator, AvatarConfig.
## Pola kontrak §8 (deterministik, tidak bergantung suite lain).

const FW := preload("res://tools/tests/test_framework.gd")
const COSMETICS_PATH := "res://data/cosmetics/cosmetics.json"
const ANIM_STATES := [
	"idle",
	"walk",
	"run",
	"jump",
	"freefall",
	"swim",
	"climb",
	"sit",
	"wave",
	"dance",
]

var fw: Node


func _ready() -> void:
	fw = FW.new()
	add_child(fw)
	await _run_tests()
	fw.finish()


func _run_tests() -> void:
	_test_brick_colors()
	_test_rig_build()
	_test_rig_validate()
	_test_accessories()
	_test_animator()
	_test_avatar_config()


# --- BrickColors ----------------------------------------------------------------


func _test_brick_colors() -> void:
	fw.section("BrickColors")
	fw.check_eq("PALETTE berisi 35 warna", BrickColors.PALETTE.size(), 35)
	fw.check("is_valid case-insensitive", BrickColors.is_valid("bright blue"))
	fw.check("warna asing ditolak", not BrickColors.is_valid("Warna Aneh"))
	fw.check_eq(
		"color_of fallback ke abu-abu medium",
		BrickColors.color_of("Warna Aneh"),
		BrickColors.color_of("Medium stone grey")
	)
	fw.check_eq(
		"default_noob torso", String(BrickColors.default_noob().get("torso", "")), "Bright blue"
	)
	fw.check_eq("names() berisi 35 nama", BrickColors.names().size(), 35)
	var sorted_copy: Array = BrickColors.names().duplicate()
	sorted_copy.sort()
	fw.check("names() terurut menaik", BrickColors.names() == sorted_copy)
	fw.check_eq("color_of nilai hex cyan", BrickColors.color_of("cyan"), Color("04afec"))


# --- AvatarRig.build -------------------------------------------------------------


func _test_rig_build() -> void:
	fw.section("AvatarRig.build")
	var rig := AvatarRig.new()
	add_child(rig)
	var config := AvatarConfig.default_config()
	rig.build(config)
	fw.check_not_null("node Torso ada", rig.get_node_or_null("Torso"))
	fw.check_not_null("node Head ada", rig.get_node_or_null("Head"))
	var head := rig.get_node_or_null("Head") as MeshInstance3D
	var torso := rig.get_node_or_null("Torso") as MeshInstance3D
	fw.check_eq(
		"Head BoxMesh ukuran 1.2 kubus", (head.mesh as BoxMesh).size, Vector3(1.2, 1.2, 1.2)
	)
	fw.check_eq("Torso BoxMesh ukuran (2,2,1)", (torso.mesh as BoxMesh).size, Vector3(2, 2, 1))
	fw.check(
		"posisi pivot ShoulderL.y ~ 3.7",
		is_equal_approx((rig.get_node_or_null("ShoulderL") as Node3D).position.y, 3.7)
	)
	fw.check("posisi Head.y ~ 4.6", is_equal_approx(head.position.y, 4.6))
	fw.check_not_null("wajah Sprite3D anak Head", head.get_node_or_null("Face"))
	fw.check_eq("get_config == config masukan", rig.get_config(), config)


# --- AvatarRig.validate_config + set_part_color ----------------------------------


func _test_rig_validate() -> void:
	fw.section("AvatarRig.validate_config")
	fw.check(
		"config valid -> tanpa error",
		AvatarRig.validate_config(AvatarConfig.default_config()).is_empty()
	)
	var broken := {"colors": {}, "material": "", "face": 5, "accessories": "bukan array"}
	fw.check("config rusak -> berisi error", not AvatarRig.validate_config(broken).is_empty())
	var rig := AvatarRig.new()
	add_child(rig)
	rig.build(AvatarConfig.default_config())
	fw.check("set_part_color torso hijau -> true", rig.set_part_color("torso", Color.GREEN))
	var material := (
		(rig.get_node_or_null("Torso") as MeshInstance3D).material_override as StandardMaterial3D
	)
	fw.check_not_null("material torso ada", material)
	fw.check_eq("material torso berubah hijau", material.albedo_color, Color.GREEN)
	fw.check("bagian tubuh palsu -> false", not rig.set_part_color("sayap", Color.RED))


# --- AvatarRig.apply_accessory ---------------------------------------------------


func _test_accessories() -> void:
	fw.section("AvatarRig.apply_accessory")
	var rig := AvatarRig.new()
	add_child(rig)
	rig.build(AvatarConfig.default_config())
	fw.check_eq("belum ada aksesori terpasang", rig.count_accessories(), 0)
	fw.check("id palsu ditolak", not rig.apply_accessory("id_palsu"))
	fw.check_eq("count tetap 0 setelah id palsu", rig.count_accessories(), 0)
	var real_id := _first_cosmetic_id()
	fw.check("id asli %s diterima" % real_id, rig.apply_accessory(real_id))
	fw.check_eq("count jadi 1 setelah id asli", rig.count_accessories(), 1)
	fw.check_not_null(
		"node Accessory_%s dibuat" % real_id, rig.find_child("Accessory_" + real_id, true, false)
	)
	fw.check("id asli kedua (hat_crown) diterima", rig.apply_accessory("hat_crown"))
	fw.check_eq("count jadi 2", rig.count_accessories(), 2)


func _first_cosmetic_id() -> String:
	# Baca cosmetics.json sendiri lalu ambil id pertama (id pasti valid).
	var file := FileAccess.open(COSMETICS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).is_empty():
		return ""
	var first: Variant = (parsed as Array)[0]
	if typeof(first) != TYPE_DICTIONARY:
		return ""
	return String((first as Dictionary).get("id", ""))


# --- AvatarAnimator --------------------------------------------------------------


func _test_animator() -> void:
	fw.section("AvatarAnimator")
	var rig := AvatarRig.new()
	add_child(rig)
	rig.build(AvatarConfig.default_config())
	var animator := AvatarAnimator.new()
	add_child(animator)
	fw.check("attach(rig) -> true", animator.attach(rig))
	var all_states_ok := true
	for state in ANIM_STATES:
		if not animator.set_state(state):
			all_states_ok = false
	fw.check("10 state valid diterima", all_states_ok)
	fw.check("state moonwalk ditolak", not animator.set_state("moonwalk"))
	var walk := AvatarAnimator.pose_for("walk", 0.5)
	fw.check_eq("walk: lengan kiri = negasi lengan kanan", walk.shoulder_l.x, -walk.shoulder_r.x)
	var run_x := absf(AvatarAnimator.pose_for("run", 0.3).shoulder_l.x)
	var walk_x := absf(AvatarAnimator.pose_for("walk", 0.3).shoulder_l.x)
	fw.check_gt("run lebih lebar daripada walk", run_x, walk_x)
	fw.check_eq("pose jump -170", AvatarAnimator.pose_for("jump", 0.0).shoulder_l.x, -170.0)
	fw.check("state tak dikenal -> pose kosong", AvatarAnimator.pose_for("aneh", 0.0).is_empty())
	animator.set_state("walk")
	for i in 30:
		animator.tick(1.0 / 60.0)
	fw.check_gt("tick 30x memajukan waktu", animator.get_time(), 0.49)
	fw.check_eq("state terakhir walk", animator.get_state(), "walk")
	fw.check(
		"ShoulderL ter-rotasi oleh tick",
		(rig.get_node_or_null("ShoulderL") as Node3D).rotation_degrees != Vector3.ZERO
	)


# --- AvatarConfig ----------------------------------------------------------------


func _test_avatar_config() -> void:
	fw.section("AvatarConfig")
	var cfg_default := AvatarConfig.default_config()
	fw.check("validate default -> 0 error", AvatarConfig.validate(cfg_default).is_empty())
	var roundtrip := AvatarConfig.deserialize(AvatarConfig.serialize(cfg_default))
	fw.check_eq("serialize -> deserialize == asli", roundtrip, cfg_default)
	fw.check_eq(
		"deserialize non-Dictionary -> default", AvatarConfig.deserialize("rusak"), cfg_default
	)
	fw.check_eq(
		"apply_preset nama palsu -> default", AvatarConfig.apply_preset("nama_palsu"), cfg_default
	)
	var preset := AvatarConfig.apply_preset("Klasik")
	fw.check_eq("apply_preset Klasik -> skin preset", String(preset.get("skin", "")), "#e0b088")
