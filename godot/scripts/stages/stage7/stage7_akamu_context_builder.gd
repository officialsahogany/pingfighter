extends RefCounted

# Read-only Stage 7 AI/actor context projection.
#
# Render payload arrays are borrowed references. Never deep-copy them here:
# update owners mutate them, then draw consumers read them synchronously.

const Stage7AkamuCloneState := preload("res://scripts/stages/stage7/stage7_akamu_clone_state.gd")
const Stage7AkamuEscapeState := preload("res://scripts/stages/stage7/stage7_akamu_escape_state.gd")


func build_boss_ai_context(
	boss_gauge: float,
	awakened: bool,
	freeze_state: Object,
	motion_state: Object,
	clone_state: Object,
	shuriken_state: Object,
	cloud_state: Object,
	escape_state: Object,
	superspeed_state: Object,
	state_owner: Object
) -> Dictionary:
	var freeze_active: bool = bool(freeze_state.is_active())
	return {
		"stage7_akamu_boss_gauge": boss_gauge,
		"stage7_akamu_awakened": awakened,
		"stage7_akamu_gameplay_freeze_active": freeze_active,
		"stage7_akamu_gameplay_freeze_reason": freeze_state.reason,
		"stage7_akamu_boss_ai_frozen": motion_state.scripted_motion_active or freeze_active,
		"stage7_akamu_scripted_motion_active": motion_state.scripted_motion_active,
		"stage7_akamu_scripted_boss_pos": motion_state.scripted_boss_pos,
		"stage7_akamu_clone_casting": clone_state.casting,
		"stage7_akamu_clone_live_count": clone_state.get_live_count(),
		"stage7_akamu_shuriken_casting": shuriken_state.casting,
		"stage7_akamu_cloud_dash_active": cloud_state.dash_active,
		"stage7_akamu_cloud_dash_phase": cloud_state.dash_phase,
		"stage7_akamu_escape_active": escape_state.active,
		"stage7_akamu_superspeed_active": superspeed_state.active,
		"stage7_akamu_superspeed_remaining": superspeed_state.remaining_sec,
		"stage7_akamu_state_owner": state_owner,
	}


func build_actor_draw_context(
	boss_gauge: float,
	awakened: bool,
	status: String,
	boss_attack_total_sec: float,
	superspeed_duration_sec: float,
	freeze_state: Object,
	motion_state: Object,
	presentation_state: Object,
	awakening_state: Object,
	clone_state: Object,
	starpoint_state: Object,
	shuriken_state: Object,
	cloud_state: Object,
	escape_state: Object,
	superspeed_state: Object
) -> Dictionary:
	return {
		"stage7_akamu_boss_gauge": boss_gauge,
		"stage7_akamu_awakened": awakened,
		"stage7_akamu_status": status,
		"stage7_akamu_gameplay_freeze_active": freeze_state.is_active(),
		"stage7_akamu_gameplay_freeze_remaining": freeze_state.remaining_sec,
		"stage7_akamu_gameplay_freeze_reason": freeze_state.reason,
		"stage7_akamu_awakening_trigger_armed": awakening_state.trigger_armed,
		"stage7_akamu_awakening_intro_pending": awakening_state.intro_pending,
		"stage7_akamu_awakening_intro_done": awakening_state.intro_done,
		"stage7_akamu_boss_ball_intangible": motion_state.boss_ball_intangible,
		"stage7_akamu_scripted_motion_active": motion_state.scripted_motion_active,
		"stage7_akamu_scripted_boss_pos": motion_state.scripted_boss_pos,
		"stage7_akamu_boss_attack_active": presentation_state.boss_attack_remaining_sec > 0.0,
		"stage7_akamu_boss_attack_remaining": presentation_state.boss_attack_remaining_sec,
		"stage7_akamu_boss_attack_total": boss_attack_total_sec,
		"stage7_akamu_boss_attack_source": presentation_state.boss_attack_source,
		"stage7_akamu_boss_attack_target_x": presentation_state.boss_attack_target_x,
		"stage7_akamu_clone_casting": clone_state.casting,
		"stage7_akamu_clone_cast_progress": clampf(
			clone_state.cast_elapsed_sec / maxf(0.001, Stage7AkamuCloneState.CAST_SEC),
			0.0,
			1.0
		),
		"stage7_akamu_clone_cooldown_remaining": clone_state.cooldown_remaining_sec,
		"stage7_akamu_clone_live_count": clone_state.get_live_count(),
		"stage7_akamu_shuriken_casting": shuriken_state.casting,
		"stage7_akamu_shuriken_cooldown_remaining": shuriken_state.cooldown_remaining_sec,
		"stage7_akamu_shuriken_drain_ticks_left": shuriken_state.gauge_ticks_left,
		"stage7_akamu_cloud_dash_active": cloud_state.dash_active,
		"stage7_akamu_cloud_dash_phase": cloud_state.dash_phase,
		"stage7_akamu_cloud_phase_progress": cloud_state.get_phase_progress(),
		"stage7_akamu_cloud_field_active": cloud_state.field_active,
		"stage7_akamu_cloud_cooldown_remaining": cloud_state.cooldown_remaining_sec,
		"stage7_akamu_escape_active": escape_state.active,
		"stage7_akamu_escape_progress": clampf(
			escape_state.elapsed_sec / Stage7AkamuEscapeState.DURATION_SEC,
			0.0,
			1.0
		),
		"stage7_akamu_clones": clone_state.entities,
		"stage7_akamu_starpoint_drops": starpoint_state.get_draw_list(),
		"stage7_akamu_starpoint_particles": starpoint_state.get_particle_draw_list(),
		"stage7_akamu_shurikens": shuriken_state.projectiles,
		"stage7_akamu_afterimages": escape_state.afterimages,
		"stage7_akamu_particles": shuriken_state.hit_particles,
		"stage7_akamu_wind_burst_particles": awakening_state.burst_particles,
		"stage7_akamu_superspeed_afterimages": superspeed_state.afterimages,
		"stage7_akamu_superspeed_dark_particles": superspeed_state.dark_particles,
		"stage7_akamu_superspeed_trails": superspeed_state.trails,
		"stage7_akamu_superspeed_active": superspeed_state.active,
		"stage7_akamu_superspeed_remaining": superspeed_state.remaining_sec,
		"stage7_akamu_superspeed_duration": superspeed_duration_sec,
		"stage7_akamu_superspeed_text_remaining": superspeed_state.text_remaining_sec,
		"stage7_akamu_superspeed_cooldown_remaining": superspeed_state.cooldown_remaining_sec,
		"stage7_akamu_superspeed_dash_active": superspeed_state.dash_active,
		"stage7_akamu_superspeed_dash_direction": superspeed_state.dash_direction,
		"stage7_akamu_cloud": cloud_state.draw_context,
		"stage7_akamu_hologram": escape_state.hologram_draw_context,
		"stage7_akamu_aura": cloud_state.aura_draw_context,
		"stage7_akamu_wind_aura": awakening_state.draw_context,
	}
