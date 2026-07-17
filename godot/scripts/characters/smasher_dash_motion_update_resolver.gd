extends RefCounted

const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")

var active_motion_resolver: Object = SmasherDashActiveMotionResolver.new()


func update(
	state: Object,
	fps_scale: float,
	player_pos: Vector2,
	play_left: float,
	play_right: float,
	paddle_width: float,
	recovery_frames: float = 42.0
) -> Dictionary:
	var player_speed_zero: bool = false

	if not bool(state.get("dash_active")):
		var was_recovering: bool = float(state.get("dash_stun_timer")) > 0.0
		var inactive_update: Dictionary = update_inactive_timers(
			fps_scale,
			float(state.get("dash_stun_timer")),
			float(state.get("dash_available_timer"))
		)
		state.set("dash_stun_timer", float(inactive_update.get("stun_timer", state.get("dash_stun_timer"))))
		state.set("dash_available_timer", float(inactive_update.get("available_timer", state.get("dash_available_timer"))))
		var recovery_ended: bool = was_recovering and float(state.get("dash_stun_timer")) <= 0.0
		if recovery_ended:
			state.set("dash_recovery_total_frames", 0.0)
		return {
			"player_pos": player_pos,
			"player_speed_zero": player_speed_zero,
			"recovery_ended": recovery_ended,
		}

	var active_update: Dictionary = active_motion_resolver.update(
		fps_scale,
		player_pos,
		play_left,
		play_right,
		paddle_width,
		float(state.get("dash_direction")),
		float(state.get("dash_timer")),
		bool(state.get("dash_is_half")),
		recovery_frames,
		maxf(0.0, float(state.get("dash_distance_multiplier")))
	)
	player_pos = active_update.get("player_pos", player_pos)
	state.set("dash_timer", float(active_update.get("timer", state.get("dash_timer"))))
	state.set("dash_elapsed_frames", float(state.get("dash_elapsed_frames")) + float(active_update.get("elapsed_delta", fps_scale)))

	if bool(active_update.get("ended", false)):
		player_speed_zero = true
		var recovery_timer: float = float(active_update.get("recovery_timer", 0.0))
		if bool(state.get("dash_skip_recovery")):
			recovery_timer = 0.0
		state.set("dash_active", false)
		state.set("dash_elapsed_frames", 0.0)
		state.set("dash_stun_timer", recovery_timer)
		state.set("dash_recovery_total_frames", recovery_timer)
		state.set("dash_available_timer", float(state.get("dash_stun_timer")))
		state.set("dash_skip_recovery", false)

	return {
		"player_pos": player_pos,
		"player_speed_zero": player_speed_zero,
		"recovery_started": bool(active_update.get("ended", false)) and float(state.get("dash_stun_timer")) > 0.0,
	}


func update_inactive_timers(fps_scale: float, stun_timer: float, available_timer: float) -> Dictionary:
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - fps_scale)
	if available_timer > 0.0:
		available_timer = max(0.0, available_timer - fps_scale)
	return {
		"stun_timer": stun_timer,
		"available_timer": available_timer,
	}
