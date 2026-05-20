extends RefCounted

const FIRE_SHEET_WEAPON_IDS := [
	"ak47",
	"bazooka",
	"net_gun",
	"bowling_trap",
	"suicide_drone",
]
const LONG_DURATION_WEAPON_IDS := [
	"bazooka",
	"bowling_trap",
]
const START_FRAMES := {
	"ak47": 3,
	"bazooka": 3,
	"net_gun": 3,
}


static func normalize_weapon_fire_sheet_id(weapon_id: String) -> String:
	if FIRE_SHEET_WEAPON_IDS.has(weapon_id):
		return weapon_id
	return ""


static func get_duration_frames(
	weapon_id: String,
	default_frames: float,
	long_frames: float
) -> float:
	if LONG_DURATION_WEAPON_IDS.has(weapon_id):
		return long_frames
	return default_frames


static func get_start_frame(weapon_id: String, frame_count: int) -> int:
	if START_FRAMES.has(weapon_id):
		return clampi(int(START_FRAMES[weapon_id]), 0, max(0, frame_count - 1))
	return 0
