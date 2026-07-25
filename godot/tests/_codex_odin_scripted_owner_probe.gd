extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const DarkSwampState := preload("res://scripts/items/odins_eye_dark_swamp_state.gd")


func _init() -> void:
	_probe("cloud")
	_probe("escape")
	print("_codex_odin_scripted_owner_probe: ok")
	quit(0)


func _probe(source: String) -> void:
	var state := DarkSwampState.new()
	var ai := BossAiState.new()
	state.boss_knockback_timer_frames = 24.0
	state.boss_stun_timer_frames = 60.0
	state.boss_knockback_vel = -25.0
	var applied := 0
	for frame in range(84):
		if frame > 0:
			state.update(1.0 / 60.0, false, true)
		var context := {
			"width": 760.0,
			"play_left": 0.0,
			"play_right": 760.0,
			"boss_paddle_width": 40.0,
			"stage7_akamu_scripted_motion_active": true,
			"stage7_akamu_escape_active": source == "escape",
			"stage7_akamu_cloud_dash_active": source == "cloud",
			"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
			"odins_eye_boss_stun_active": state.boss_stun_timer_frames > 0.0,
			"odins_eye_boss_knockback_active": state.boss_knockback_timer_frames > 0.0,
			"odins_eye_boss_knockback_vel": state.boss_knockback_vel,
		}
		var result: Dictionary = ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, context)
		if absf(float(result.get("boss_vel", 0.0))) > 0.000001:
			applied += 1
	print("PROBE %s applied=%d kb=%.1f stun=%.1f" % [source, applied, state.boss_knockback_timer_frames, state.boss_stun_timer_frames])
