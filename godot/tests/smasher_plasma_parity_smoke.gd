extends SceneTree

const BossAIState := preload("res://scripts/ai/boss_ai_state.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherPlasmaState := preload("res://scripts/characters/smasher_plasma_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")


class FakeAudio:
	var charge_active := false
	var shock_active := false
	var calls: Array[String] = []

	func sync_plasma_charge(active: bool) -> void:
		if active != charge_active:
			calls.append("charge_on" if active else "charge_off")
		charge_active = active

	func play_plasma_shoot() -> void:
		calls.append("shoot")

	func sync_plasma_shock(active: bool) -> void:
		if active != shock_active:
			calls.append("shock_on" if active else "shock_off")
		shock_active = active


class FakeBossGauge:
	var boss_special_gauge := 100.0


class FakeHongryunGauge:
	var hongryun_hit_count := 10.0
	var hongryun_max_hits := 12.0
	var hongryun_ready := true


func _init() -> void:
	_test_charge_release_projectile_and_audio()
	_test_stage_gauge_drain_routes()
	_test_fire_zone_no_longer_stacks_slow()
	_test_plasma_audio_relative_gains()
	print("smasher_plasma_parity_smoke: ok")
	quit(0)


func _test_charge_release_projectile_and_audio() -> void:
	var state: Object = SmasherPlasmaState.new()
	var skill_config: Object = SmasherSkillConfig.new()
	var skill_state: Object = SmasherSkillState.new()
	var status_effect_state: Object = StatusEffectState.new()
	var audio := FakeAudio.new()
	_expect(skill_config.unlock_and_equip_skill("plasma"), "plasma should equip for parity test")

	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"status_effect_state": status_effect_state,
		"audio": audio,
	}
	var config := {
		"ball_active": true,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"gauge_max": 500.0,
	}
	var player_pos := Vector2(300.0, 700.0)
	var gauge := 100.0
	for i in range(31):
		var hold_result: Dictionary = state.update_input(
			{"up_pressed": true},
			1000 + i * 16,
			gauge,
			player_pos,
			config,
			deps
		)
		gauge = float(hold_result.get("special_gauge", gauge))

	var release_result: Dictionary = state.update_input(
		{"up_pressed": false},
		1500,
		gauge,
		player_pos,
		config,
		deps
	)
	gauge = float(release_result.get("special_gauge", gauge))
	var draw_context: Dictionary = state.get_draw_context()
	_expect(is_equal_approx(gauge, 60.0), "minimum valid plasma release should consume exactly 40 gauge")
	_expect(bool(draw_context.get("smasher_plasma_wave_active", false)), "release after 30 frames should fire the plasma wave")
	_expect(is_equal_approx(float(draw_context.get("smasher_plasma_wave_slow_amount", 0.0)), 0.25), "30-frame release should match original 25% slow after minimum-cost top-up")
	_expect(audio.calls.has("charge_on"), "plasma charge loop should start while holding")
	_expect(audio.calls.has("shoot"), "plasma shoot sound should play on release")
	_expect(audio.calls.has("charge_off"), "plasma charge loop should stop after release")
	_expect(skill_state.get_configured_cooldown_remaining("plasma", 1500, skill_config) > 0.0, "release should trigger plasma cooldown")

	var stage1_gauge := FakeBossGauge.new()
	deps["stage1_dalji_whip_skill_state"] = stage1_gauge
	deps["current_stage"] = 1
	var wave_pos: Vector2 = draw_context.get("smasher_plasma_wave_pos", Vector2.ZERO)
	var boss_pos := Vector2(wave_pos.x - 50.0, wave_pos.y - 26.0)
	var effect_context := {
		"current_stage": 1,
		"player_pos": player_pos,
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": boss_pos,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	state.update_effects(1.0, effect_context, deps)
	state.update_effects(1.0, effect_context, deps)
	var ai_context: Dictionary = state.get_boss_ai_context()
	_expect(bool(ai_context.get("smasher_plasma_boss_slow_active", false)), "boss should be slowed while inside plasma")
	_expect(is_equal_approx(float(ai_context.get("smasher_plasma_boss_slow_multiplier", 0.0)), 0.75), "boss slow multiplier should expose 1 - slow amount")
	var shared_slow: Dictionary = status_effect_state.get_status("boss", "slow")
	_expect(not shared_slow.is_empty(), "plasma should register boss slow in the shared status state")
	_expect(str(shared_slow.get("source", "")) == "smasher_plasma", "plasma shared slow should keep a dedicated source key")
	_expect(is_equal_approx(float(shared_slow.get("multiplier", 0.0)), 0.75), "plasma shared slow should expose the same multiplier as the legacy AI context")
	var shared_ai_context: Dictionary = status_effect_state.get_boss_ai_context()
	_expect(bool(shared_ai_context.get("status_boss_slow_active", false)), "plasma shared slow should remain visible as a status AI context")
	_expect(not bool(shared_ai_context.get("active_item_spider_mine_slow_active", false)), "plasma shared slow should not bridge back into a second legacy slow source")
	var merged_ai_context: Dictionary = ai_context.duplicate(true)
	merged_ai_context.merge(shared_ai_context, true)
	var boss_ai: Object = BossAIState.new()
	_expect(is_equal_approx(boss_ai._get_active_item_slow_multiplier(merged_ai_context), 0.75), "plasma slow should not double-apply when legacy and shared status contexts are merged")
	_expect(is_equal_approx(stage1_gauge.boss_special_gauge, 99.0), "plasma should drain boss gauge by 0.5 per frame like Python")
	_expect(audio.calls.has("shock_on"), "plasma shock loop should start while the boss is inside the wave")

	state.wave_timer_frames = 0.5
	state.update_effects(1.0, effect_context, deps)
	_expect(status_effect_state.get_status("boss", "slow").is_empty(), "plasma shared slow should clear when the wave ends")


func _test_stage_gauge_drain_routes() -> void:
	var stage2_state: Object = _active_wave_state()
	var stage2_gauge := FakeBossGauge.new()
	stage2_state.update_effects(1.0, _contact_context(2), {
		"current_stage": 2,
		"stage2_boss_skill_state": stage2_gauge,
	})
	stage2_state.update_effects(1.0, _contact_context(2), {
		"current_stage": 2,
		"stage2_boss_skill_state": stage2_gauge,
	})
	_expect(is_equal_approx(stage2_gauge.boss_special_gauge, 99.0), "non-Hongryun stages should drain the current boss gauge route")

	var stage4_state: Object = _active_wave_state()
	var stage4_gauge := FakeBossGauge.new()
	stage4_state.update_effects(1.0, _contact_context(4), {
		"current_stage": 4,
		"stage4_ponk_skill_state": stage4_gauge,
	})
	stage4_state.update_effects(1.0, _contact_context(4), {
		"current_stage": 4,
		"stage4_ponk_skill_state": stage4_gauge,
	})
	_expect(is_equal_approx(stage4_gauge.boss_special_gauge, 99.0), "Stage 4 Ponk should drain through its boss_special_gauge owner")

	var hongryun_state: Object = _active_wave_state()
	var hongryun_gauge := FakeHongryunGauge.new()
	hongryun_state.update_effects(1.0, _contact_context(5), {
		"current_stage": 5,
		"stage5_hongryun_state": hongryun_gauge,
	})
	hongryun_state.update_effects(1.0, _contact_context(5), {
		"current_stage": 5,
		"stage5_hongryun_state": hongryun_gauge,
	})
	_expect(is_equal_approx(hongryun_gauge.hongryun_hit_count, 9.0), "Hongryun route should drain orb count instead of generic boss gauge")
	_expect(not hongryun_gauge.hongryun_ready, "Hongryun ready flag should clear when plasma drains below max")


func _test_fire_zone_no_longer_stacks_slow() -> void:
	var boss_ai: Object = BossAIState.new()
	var multiplier: float = boss_ai._get_active_item_slow_multiplier({
		"active_item_molotov_slow_active": true,
		"active_item_molotov_slow_factor": 0.5,
		"smasher_plasma_boss_slow_active": true,
		"smasher_plasma_boss_slow_multiplier": 0.75,
	})
	_expect(is_equal_approx(multiplier, 0.75), "molotov fire-zone movement obstruction should no longer stack a boss slow multiplier")


func _test_plasma_audio_relative_gains() -> void:
	_expect(FileAccess.file_exists(GameAudio.PLASMA_CHARGE_SOUND_PATH), "plasma charge wav should exist in the Godot asset tree")
	_expect(FileAccess.file_exists(GameAudio.PLASMA_SHOOT_SOUND_PATH), "plasma shoot wav should exist in the Godot asset tree")
	_expect(FileAccess.file_exists(GameAudio.PLASMA_SHOCK_SOUND_PATH), "plasma shock wav should exist in the Godot asset tree")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.PLASMA_CHARGE_SOUND_PATH) != null, "plasma charge wav should load as a Godot audio stream")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.PLASMA_SHOOT_SOUND_PATH) != null, "plasma shoot wav should load as a Godot audio stream")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.PLASMA_SHOCK_SOUND_PATH) != null, "plasma shock wav should load as a Godot audio stream")
	_expect(is_equal_approx(GameAudio.PLASMA_CHARGE_GAIN_DB, 0.0), "charge loop should use the original full-volume relative gain")
	_expect(abs(GameAudio.PLASMA_SHOOT_GAIN_DB + 6.0206) <= 0.001, "shoot cue should match Python's 0.5 relative volume")
	_expect(abs(GameAudio.PLASMA_SHOCK_GAIN_DB + 4.4370) <= 0.001, "shock loop should match Python's 0.6 relative volume")


func _active_wave_state() -> Object:
	var state: Object = SmasherPlasmaState.new()
	state.wave_active = true
	state.wave_pos = Vector2(377.5, 680.0)
	state.wave_radius = 50.0
	state.wave_slow_amount = 0.25
	state.wave_timer_frames = 180.0
	return state


func _contact_context(current_stage: int) -> Dictionary:
	return {
		"current_stage": current_stage,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(327.5, 654.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
