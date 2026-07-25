extends RefCounted

# Pure animation-state and sheet-geometry owner for the Commando firearm HUD.
# The renderer keeps compatibility wrappers and injects the current clock so
# these calculations remain deterministic in focused tests.

const PISTOL_FIRE_RECOIL_GRID_COLS := 4
const PISTOL_FIRE_RECOIL_GRID_ROWS := 4
const PISTOL_FIRE_RECOIL_FRAME_COUNT := 16
const PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT := 4
const PISTOL_FIRE_RECOIL_POST_FRAME_COUNT := 12
const AK47_FIRE_RECOIL_GRID_COLS := 4
const AK47_FIRE_RECOIL_GRID_ROWS := 4
const AK47_FIRE_RECOIL_FRAME_COUNT := 16
const AK47_HUD_RECOIL_ROTATION_DEGREES_BY_FRAME := [
	0.0, -2.5, -5.5, -8.0, -5.5, -2.5, -8.5, -5.5,
	-3.0, -7.0, -4.0, -2.0, -1.0, -0.4, 0.0, 0.0,
]
const NET_GUN_FIRE_RECOIL_GRID_COLS := 4
const NET_GUN_FIRE_RECOIL_GRID_ROWS := 4
const NET_GUN_FIRE_RECOIL_FRAME_COUNT := 16
const NET_GUN_HUD_RECOIL_KICK_BY_FRAME := [
	0.0, -0.030, -0.060, -0.085, -0.075, -0.060, -0.050, -0.040,
	-0.032, -0.024, -0.016, -0.010, -0.006, -0.003, 0.0, 0.0,
]
const BAZOOKA_FIRE_RECOIL_GRID_COLS := 4
const BAZOOKA_FIRE_RECOIL_GRID_ROWS := 4
const BAZOOKA_FIRE_RECOIL_FRAME_COUNT := 16
const BOWLING_TRAP_INSTALL_GRID_COLS := 4
const BOWLING_TRAP_INSTALL_GRID_ROWS := 4
const BOWLING_TRAP_INSTALL_FRAME_COUNT := 16
const BOWLING_TRAP_CAPTURE_GRID_COLS := 4
const BOWLING_TRAP_CAPTURE_GRID_ROWS := 4
const BOWLING_TRAP_CAPTURE_FRAME_COUNT := 16
const BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO := Vector2(0.5, 0.62)
const SUICIDE_DRONE_HOVER_GRID_COLS := 4
const SUICIDE_DRONE_HOVER_GRID_ROWS := 4
const SUICIDE_DRONE_HOVER_FRAME_COUNT := 16
const SUICIDE_DRONE_HOVER_FRAME_MSEC := 70.0


static func is_suicide_drone_hover_active(weapon_id: String, state: Dictionary) -> bool:
	return weapon_id == "suicide_drone" and bool(state.get("active", false))


static func is_hud_highlight_active(weapon_id: String, state: Dictionary) -> bool:
	if not bool(state.get("active", false)):
		return false
	if float(state.get("timer_frames", 0.0)) <= 0.0:
		return false
	var highlighted_weapon_id: String = str(state.get("weapon_id", ""))
	return highlighted_weapon_id.is_empty() or highlighted_weapon_id == weapon_id


static func get_hud_highlight_ratio(state: Dictionary) -> float:
	if not bool(state.get("active", false)):
		return 0.0
	var explicit_ratio: float = float(state.get("ratio", -1.0))
	if explicit_ratio >= 0.0:
		return clampf(explicit_ratio, 0.0, 1.0)
	var timer_frames: float = maxf(0.0, float(state.get("timer_frames", 0.0)))
	var timer_max_frames: float = maxf(1.0, float(state.get("timer_max_frames", 1.0)))
	return clampf(timer_frames / timer_max_frames, 0.0, 1.0)


static func is_pistol_fire_active(weapon_id: String, state: Dictionary) -> bool:
	if weapon_id != "pistol" and weapon_id != "commando_pistol":
		return false
	return (
		float(state.get("fire_delay_frames", 0.0)) > 0.0
		or float(state.get("post_fire_animation_frames", 0.0)) > 0.0
	)


static func is_weapon_fire_active(weapon_id: String, expected_weapon_id: String, state: Dictionary) -> bool:
	return (
		weapon_id == expected_weapon_id
		and bool(state.get("active", false))
		and str(state.get("weapon_id", "")) == expected_weapon_id
		and float(state.get("timer_frames", 0.0)) > 0.0
	)


static func get_pistol_fire_frame(state: Dictionary) -> int:
	var fire_delay_frames: float = float(state.get("fire_delay_frames", 0.0))
	var fire_delay_max_frames: float = maxf(1.0, float(state.get("fire_delay_max_frames", 1.0)))
	if fire_delay_frames > 0.0:
		var progress: float = clampf(1.0 - fire_delay_frames / fire_delay_max_frames, 0.0, 1.0)
		return clampi(int(progress * float(PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT)), 0, PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT - 1)
	var post_fire_frames: float = float(state.get("post_fire_animation_frames", 0.0))
	var post_fire_max_frames: float = maxf(1.0, float(state.get("post_fire_animation_max_frames", 1.0)))
	if post_fire_frames > 0.0:
		var progress: float = clampf(1.0 - post_fire_frames / post_fire_max_frames, 0.0, 1.0)
		return clampi(
			PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT + int(progress * float(PISTOL_FIRE_RECOIL_POST_FRAME_COUNT)),
			PISTOL_FIRE_RECOIL_WINDUP_FRAME_COUNT,
			PISTOL_FIRE_RECOIL_FRAME_COUNT - 1
		)
	return 0


static func get_timed_fire_frame(state: Dictionary, frame_count: int) -> int:
	var timer_frames: float = maxf(0.0, float(state.get("timer_frames", 0.0)))
	var timer_max_frames: float = maxf(1.0, float(state.get("timer_max_frames", 1.0)))
	var progress: float = clampf(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(frame_count)), 0, frame_count - 1)


static func get_ak47_rotation_degrees(weapon_id: String, state: Dictionary) -> float:
	if not is_weapon_fire_active(weapon_id, "ak47", state):
		return 0.0
	var frame := get_timed_fire_frame(state, AK47_FIRE_RECOIL_FRAME_COUNT)
	return float(AK47_HUD_RECOIL_ROTATION_DEGREES_BY_FRAME[frame])


static func get_net_gun_kick_ratio(weapon_id: String, state: Dictionary) -> float:
	if not is_weapon_fire_active(weapon_id, "net_gun", state):
		return 0.0
	var frame := get_timed_fire_frame(state, NET_GUN_FIRE_RECOIL_FRAME_COUNT)
	return float(NET_GUN_HUD_RECOIL_KICK_BY_FRAME[frame])


static func get_bowling_trap_hud_trap(traps: Array) -> Dictionary:
	for preferred_state in ["capturing", "installing", "waiting"]:
		for trap_value in traps:
			if trap_value is Dictionary:
				var trap: Dictionary = trap_value
				if str(trap.get("state", "")) == preferred_state:
					return trap
	return {}


static func is_bowling_trap_animated(weapon_id: String, state: Dictionary, traps: Array) -> bool:
	if weapon_id != "bowling_trap":
		return false
	if get_bowling_trap_hud_trap(traps).is_empty() and not bool(state.get("installing", false)):
		return false
	return (
		bool(state.get("installing", false))
		or float(state.get("install_pose_frames", 0.0)) > 0.0
		or float(state.get("control_lock_frames", 0.0)) > 0.0
		or not get_bowling_trap_hud_trap(traps).is_empty()
	)


static func is_bowling_trap_capture_active(weapon_id: String, traps: Array) -> bool:
	return weapon_id == "bowling_trap" and str(get_bowling_trap_hud_trap(traps).get("state", "")) == "capturing"


static func is_bowling_trap_install_active(weapon_id: String, state: Dictionary, traps: Array) -> bool:
	if weapon_id != "bowling_trap":
		return false
	return str(get_bowling_trap_hud_trap(traps).get("state", "")) == "installing" or bool(state.get("installing", false))


static func get_bowling_trap_capture_frame(traps: Array) -> int:
	var trap := get_bowling_trap_hud_trap(traps)
	if str(trap.get("state", "")) != "capturing":
		return 0
	return _get_progress_frame(trap, "capture_progress", BOWLING_TRAP_CAPTURE_FRAME_COUNT)


static func get_bowling_trap_install_frame(state: Dictionary, traps: Array) -> int:
	var trap := get_bowling_trap_hud_trap(traps)
	var raw_progress: float = float(trap.get("install_progress", state.get("install_progress", -1.0)))
	return _get_progress_frame(trap, "install_progress", BOWLING_TRAP_INSTALL_FRAME_COUNT, raw_progress)


static func _get_progress_frame(state: Dictionary, progress_key: String, frame_count: int, raw_progress: float = NAN) -> int:
	if is_nan(raw_progress):
		raw_progress = float(state.get(progress_key, -1.0))
	var progress := clampf(raw_progress, 0.0, 1.0)
	if raw_progress < 0.0:
		var timer_frames: float = maxf(0.0, float(state.get("timer_frames", 0.0)))
		var timer_max_frames: float = maxf(1.0, float(state.get("max_timer_frames", 1.0)))
		progress = clampf(1.0 - timer_frames / timer_max_frames, 0.0, 1.0)
	return clampi(int(progress * float(frame_count)), 0, frame_count - 1)


static func get_suicide_drone_hover_frame(elapsed_msec: int) -> int:
	var elapsed_frames := int(floor(float(elapsed_msec) / SUICIDE_DRONE_HOVER_FRAME_MSEC))
	return posmod(elapsed_frames, SUICIDE_DRONE_HOVER_FRAME_COUNT)


static func get_bowling_trap_motion_rect(rect: Rect2, state: Dictionary, trap: Dictionary, scale_factor: float, elapsed_msec: int) -> Rect2:
	if str(trap.get("state", "")) == "installing":
		var progress := clampf(float(trap.get("install_progress", state.get("install_progress", 0.0))), 0.0, 1.0)
		var install_scale := 0.92 + 0.12 * sin(progress * PI * 0.5)
		var install_y := (1.0 - progress) * 4.0 * scale_factor
		return scale_rect_around_pivot(Rect2(rect.position + Vector2(0.0, install_y), rect.size), install_scale, BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO)
	var phase := float(elapsed_msec) * 0.012
	var pulse := 0.5 + 0.5 * sin(phase)
	var bob := -1.8 * sin(phase) * scale_factor
	return scale_rect_around_pivot(Rect2(rect.position + Vector2(0.0, bob), rect.size), 1.0 + 0.035 * pulse, BOWLING_TRAP_HUD_MOTION_PIVOT_RATIO)


static func get_bowling_trap_motion_rotation(state: Dictionary, trap: Dictionary, elapsed_msec: int) -> float:
	if str(trap.get("state", "")) == "installing":
		var progress := clampf(float(trap.get("install_progress", state.get("install_progress", 0.0))), 0.0, 1.0)
		return lerpf(-0.08, 0.03, progress)
	return sin(float(elapsed_msec) * 0.012) * 0.045


static func get_sheet_source_rect(texture_size: Vector2, frame: int, columns: int, rows: int, frame_count: int) -> Rect2:
	var frame_index := clampi(frame, 0, frame_count - 1)
	var cell_w := texture_size.x / float(columns)
	var cell_h := texture_size.y / float(rows)
	var col := frame_index % columns
	@warning_ignore("integer_division")
	var row := int(frame_index / columns)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


static func scale_rect_around_pivot(rect: Rect2, scale: float, pivot_ratio: Vector2) -> Rect2:
	if is_equal_approx(scale, 1.0):
		return rect
	var safe_scale := maxf(0.01, scale)
	var pivot := rect.position + rect.size * pivot_ratio
	var scaled_size := rect.size * safe_scale
	return Rect2(pivot - scaled_size * pivot_ratio, scaled_size)
