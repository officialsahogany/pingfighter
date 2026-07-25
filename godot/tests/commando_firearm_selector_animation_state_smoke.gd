extends SceneTree

const AnimationState := preload("res://scripts/hud/commando_firearm_selector_animation_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_weapon_animation_state()
	_verify_frame_progression()
	_verify_bowling_trap_selection_and_motion()
	_verify_sheet_geometry()
	if _failures.is_empty():
		print("commando_firearm_selector_animation_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_weapon_animation_state() -> void:
	_expect(AnimationState.is_pistol_fire_active("pistol", {"fire_delay_frames": 2.0}), "base pistol windup should activate recoil")
	_expect(AnimationState.is_pistol_fire_active("commando_pistol", {"post_fire_animation_frames": 2.0}), "Beretta post-fire state should activate recoil")
	_expect(not AnimationState.is_pistol_fire_active("ak47", {"fire_delay_frames": 2.0}), "non-pistol weapons should not enter pistol recoil")
	var fire_state := {"active": true, "weapon_id": "ak47", "timer_frames": 12.0, "timer_max_frames": 16.0}
	_expect(AnimationState.is_weapon_fire_active("ak47", "ak47", fire_state), "matching active weapon fire state should animate")
	_expect(not AnimationState.is_weapon_fire_active("net_gun", "net_gun", fire_state), "mismatched weapon fire state should stay idle")
	var highlight := {"active": true, "timer_frames": 6.0, "timer_max_frames": 12.0, "weapon_id": ""}
	_expect(AnimationState.is_hud_highlight_active("bazooka", highlight), "empty highlight target should apply to the current weapon")
	_expect(is_equal_approx(AnimationState.get_hud_highlight_ratio(highlight), 0.5), "highlight ratio should derive from remaining timer")


func _verify_frame_progression() -> void:
	_expect(AnimationState.get_pistol_fire_frame({"fire_delay_frames": 4.0, "fire_delay_max_frames": 4.0}) == 0, "fresh pistol windup should start at frame zero")
	_expect(AnimationState.get_pistol_fire_frame({"post_fire_animation_frames": 6.0, "post_fire_animation_max_frames": 12.0}) == 10, "half post-fire pistol animation should map into the post-fire frame range")
	_expect(AnimationState.get_timed_fire_frame({"timer_frames": 8.0, "timer_max_frames": 16.0}, 16) == 8, "half elapsed timed recoil should use the middle frame")
	_expect(AnimationState.get_suicide_drone_hover_frame(0) == 0, "hover animation should begin at frame zero")
	_expect(AnimationState.get_suicide_drone_hover_frame(1120) == 0, "hover animation should wrap after sixteen 70ms frames")


func _verify_bowling_trap_selection_and_motion() -> void:
	var traps := [
		{"state": "waiting"},
		{"state": "installing", "install_progress": 0.25},
		{"state": "capturing", "capture_progress": 0.5},
	]
	var selected: Dictionary = AnimationState.get_bowling_trap_hud_trap(traps)
	_expect(str(selected.get("state", "")) == "capturing", "capturing trap should win the HUD priority order")
	_expect(AnimationState.is_bowling_trap_animated("bowling_trap", {}, traps), "a live trap should keep the HUD icon animated")
	_expect(AnimationState.is_bowling_trap_capture_active("bowling_trap", traps), "capturing trap should select the capture sheet")
	_expect(AnimationState.get_bowling_trap_capture_frame(traps) == 8, "half capture progress should select frame eight")
	var install_traps := [{"state": "installing", "install_progress": 0.5}]
	_expect(AnimationState.get_bowling_trap_install_frame({}, install_traps) == 8, "half install progress should select frame eight")
	var rect := Rect2(10.0, 20.0, 40.0, 60.0)
	var motion_rect := AnimationState.get_bowling_trap_motion_rect(rect, {}, install_traps[0], 1.0, 0)
	_expect(motion_rect.size.x > rect.size.x, "mid-install motion should apply the intended scale-up")
	_expect(is_equal_approx(AnimationState.get_bowling_trap_motion_rotation({}, install_traps[0], 0), -0.025), "mid-install rotation should interpolate deterministically")


func _verify_sheet_geometry() -> void:
	var source := AnimationState.get_sheet_source_rect(Vector2(400.0, 200.0), 6, 4, 2, 8)
	_expect(source == Rect2(200.0, 100.0, 100.0, 100.0), "sheet geometry should resolve row-major cells")
	var rect := Rect2(10.0, 20.0, 40.0, 60.0)
	var scaled := AnimationState.scale_rect_around_pivot(rect, 2.0, Vector2(0.5, 0.5))
	_expect(scaled == Rect2(-10.0, -10.0, 80.0, 120.0), "pivot scaling should preserve the rectangle center")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
