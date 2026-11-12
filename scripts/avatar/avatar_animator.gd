class_name AvatarAnimator
extends Node
## Animator prosedural avatar — pose murni fungsi dari state dan waktu (derajat).

# Alias preload: kelas global belum terdaftar di cache .godot (tanpa --import).
const AvatarRigLib := preload("res://scripts/avatar/avatar_rig.gd")

const VALID_STATES := [
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

# Kunci pose -> nama pivot pada AvatarRig.
const PIVOT_KEYS := {
	"shoulder_l": "ShoulderL",
	"shoulder_r": "ShoulderR",
	"hip_l": "HipL",
	"hip_r": "HipR",
}

var _rig: AvatarRigLib
var _state := "idle"
var _t := 0.0


func attach(rig: AvatarRigLib) -> bool:
	# Pasang animator ke rig; false bila rig null.
	_rig = rig
	return rig != null


func set_state(state: String) -> bool:
	# Ganti state animasi; state tak dikenal ditolak dengan warning.
	if state not in VALID_STATES:
		push_warning("State animasi tidak dikenal: %s" % state)
		return false
	_state = state
	return true


func tick(delta: float) -> void:
	# Maju waktu lalu terapkan pose ke pivot rig (pivot null dilewati).
	_t += delta
	if _rig == null or not is_instance_valid(_rig):
		return
	var pose := pose_for(_state, _t)
	for pivot_key in PIVOT_KEYS:
		var pivot := _rig.get_node_or_null(String(PIVOT_KEYS[pivot_key])) as Node3D
		if pivot != null and pose.has(pivot_key):
			pivot.rotation_degrees = pose[pivot_key]


func get_state() -> String:
	return _state


func get_time() -> float:
	return _t


static func pose_for(state: String, t: float) -> Dictionary:
	# Pose (derajat) murni dari state & waktu; state tak dikenal -> kosong.
	match state:
		"idle":
			var sway := 3.0 * sin(TAU * t / 3.0)
			return {
				"shoulder_l": Vector3(sway, 0.0, 0.0),
				"shoulder_r": Vector3(-sway, 0.0, 0.0),
				"hip_l": Vector3.ZERO,
				"hip_r": Vector3.ZERO,
			}
		"walk":
			var walk_s := sin(TAU * 1.6 * t)
			return {
				"shoulder_l": Vector3(50.0 * walk_s, 0.0, 0.0),
				"shoulder_r": Vector3(-50.0 * walk_s, 0.0, 0.0),
				"hip_l": Vector3(-40.0 * walk_s, 0.0, 0.0),
				"hip_r": Vector3(40.0 * walk_s, 0.0, 0.0),
			}
		"run":
			var run_s := sin(TAU * 2.2 * t)
			return {
				"shoulder_l": Vector3(70.0 * run_s, 0.0, 0.0),
				"shoulder_r": Vector3(-70.0 * run_s, 0.0, 0.0),
				"hip_l": Vector3(-55.0 * run_s, 0.0, 0.0),
				"hip_r": Vector3(55.0 * run_s, 0.0, 0.0),
			}
		"jump":
			return {
				"shoulder_l": Vector3(-170.0, 0.0, 0.0),
				"shoulder_r": Vector3(-170.0, 0.0, 0.0),
				"hip_l": Vector3.ZERO,
				"hip_r": Vector3.ZERO,
			}
		"freefall":
			return {
				"shoulder_l": Vector3(0.0, 0.0, -80.0),
				"shoulder_r": Vector3(0.0, 0.0, 80.0),
				"hip_l": Vector3(-15.0, 0.0, 0.0),
				"hip_r": Vector3(15.0, 0.0, 0.0),
			}
		"swim":
			var swim_s := sin(TAU * 1.2 * t)
			return {
				"shoulder_l": Vector3(60.0 * swim_s, 0.0, 0.0),
				"shoulder_r": Vector3(-60.0 * swim_s, 0.0, 0.0),
				"hip_l": Vector3(45.0 * swim_s, 0.0, 0.0),
				"hip_r": Vector3(-45.0 * swim_s, 0.0, 0.0),
			}
		"climb":
			var climb_s := sin(TAU * 1.5 * t)
			return {
				"shoulder_l": Vector3(40.0 * climb_s, 0.0, 0.0),
				"shoulder_r": Vector3(-40.0 * climb_s, 0.0, 0.0),
				"hip_l": Vector3(-40.0 * climb_s, 0.0, 0.0),
				"hip_r": Vector3(40.0 * climb_s, 0.0, 0.0),
			}
		"sit":
			return {
				"shoulder_l": Vector3(-20.0, 0.0, 0.0),
				"shoulder_r": Vector3(-20.0, 0.0, 0.0),
				"hip_l": Vector3(-90.0, 0.0, 0.0),
				"hip_r": Vector3(-90.0, 0.0, 0.0),
			}
		"wave":
			var wave_s := sin(TAU * 1.8 * t)
			return {
				"shoulder_l": Vector3.ZERO,
				"shoulder_r": Vector3(0.0, 0.0, -(140.0 + 20.0 * wave_s)),
				"hip_l": Vector3.ZERO,
				"hip_r": Vector3.ZERO,
			}
		"dance":
			var dance_s := sin(TAU * 1.4 * t)
			return {
				"shoulder_l": Vector3(0.0, 0.0, 60.0 + 30.0 * dance_s),
				"shoulder_r": Vector3(0.0, 0.0, -(60.0 + 30.0 * sin(TAU * 1.4 * t + PI))),
				"hip_l": Vector3(10.0 * dance_s, 0.0, 0.0),
				"hip_r": Vector3.ZERO,
			}
	return {}
