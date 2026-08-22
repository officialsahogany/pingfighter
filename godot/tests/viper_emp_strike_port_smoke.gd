extends SceneTree

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ViperSkillAudio := preload("res://scripts/audio/viper_skill_audio.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const BattlePerfProcessNodeReporter := preload("res://scripts/core/battle_perf_process_node_reporter.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")
const Stage2BossActorRenderer := preload("res://scripts/stages/stage2/stage2_boss_actor_renderer.gd")
const ViperEmpStrikeFxHost := preload("res://scripts/characters/viper_emp_strike_fx_host.gd")
const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "dive_strike"

	func get_skill_cost(skill_name: String) -> float:
		return 250.0 if skill_name == "dive_strike" else 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		return 70.0 if skill_name == "dive_strike" else 0.0


class FakeSkillState:
	var triggered := ""
	var cooldown_seconds := -1.0

	func trigger_cooldown(skill_name: String, _now_msec: int, cooldown: float) -> void:
		triggered = skill_name
		cooldown_seconds = cooldown

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeAudio:
	var prep := 0
	var strike := 0
	var jetpack_loop_active := false

	func play_viper_dive_prep() -> void:
		prep += 1

	func play_viper_dive_strike() -> void:
		strike += 1

	func sync_viper_jetpack_loop(active: bool) -> void:
		jetpack_loop_active = active


class FakeKickFallbackAudio:
	var backstep := 0
	var marshal := 0
	var shadow := 0

	func play_viper_backstep() -> void:
		backstep += 1

	func play_viper_marshal_kick() -> void:
		marshal += 1

	func play_viper_shadow_kick() -> void:
		shadow += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakePerkState:
	var four_poisons_level := 0
	var gold := 0

	func get_runtime_skill_level(skill_id: String) -> int:
		if skill_id == "four_poisons":
			return four_poisons_level
		return 0

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeStatusEffectState:
	var applications: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var entry := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		}
		applications.append(entry)
		return entry


func _init() -> void:
	_test_four_poisons_catalog_text_sync()
	_test_emp_gauge_cost_authoritative()
	_test_emp_audio_asset_parity()
	_test_emp_audio_does_not_fall_back_to_kicks()
	_test_emp_fx_host_remaster_stack()
	_test_emp_fx_host_reset_hides_detached_runtime()
	_test_emp_activation_impact_slip_and_four_poisons_scaling()
	_test_emp_shockwave_reach_applies_slip_without_ball_hit()
	_test_emp_startup_cancel_and_super_armor()
	print("viper_emp_strike_port_smoke: ok")
	quit(0)


func _test_emp_gauge_cost_authoritative() -> void:
	# Seals the EMP Strike (dive_strike) gauge consumption against the REAL config,
	# covering both the live gameplay path (SKILL_COSTS) and the tooltip/HUD path
	# (SKILL_DATA cost), which do NOT auto-sync. Reverse-verified: this fails at 150.
	var skill_config := ViperSkillConfig.new()
	_expect(abs(skill_config.get_skill_cost("dive_strike") - 250.0) < 0.01, "EMP Strike gauge cost should be 250")
	_expect(abs(float(skill_config.get_skill_data("dive_strike").get("cost", 0.0)) - 250.0) < 0.01, "EMP Strike tooltip cost should be 250")
	_expect(abs(ViperSkillRuntime.DIVE_GAUGE_COST - 250.0) < 0.01, "EMP runtime fallback gauge cost should match the authoritative 250")


func _test_four_poisons_catalog_text_sync() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("four_poisons")
	var descriptions: Dictionary = data.get("descriptions", {})
	var lv2: String = str(descriptions.get(2, ""))
	var lv3: String = str(descriptions.get(3, ""))
	var detail: String = str(data.get("detail", ""))
	_expect(lv2.find("천뢰진각 수면 +15%") >= 0, "four_poisons S3 Lv.2 card should mention Heavenly Thunder sleep scaling")
	_expect(lv2.find("4초식 쿨 -12%") >= 0, "four_poisons S3 Lv.2 card should mention four-form cooldown reduction")
	_expect(lv2.find("슈퍼아머") >= 0, "four_poisons S3 Lv.2 card should mention startup super armor")
	_expect(lv3.find("천뢰진각 수면 +25%") >= 0, "four_poisons S3 ceiling should preserve max-invested Heavenly Thunder sleep scaling")
	_expect(lv3.find("쌍영분신 HP 4") >= 0, "four_poisons S3 ceiling should mention twin-shadow clone HP")
	_expect(lv3.find("분신 복제") >= 0, "four_poisons S3 ceiling should mention clone skill replication")
	_expect(detail.find("추가 기력/쿨/골드") >= 0, "four_poisons detail should explain clone replication reward limits")


func _test_emp_audio_asset_parity() -> void:
	var prep_path := _viper_audio_path("dive_prep")
	var strike_path := _viper_audio_path("dive_strike")
	_expect(prep_path == "res://assets/sounds/beforedivestrike.wav", "EMP prep should use the Python reference beforedivestrike.wav")
	_expect(strike_path == "res://assets/sounds/divestrike.wav", "EMP landing should use the Python reference divestrike.wav")
	_expect(FileAccess.file_exists(prep_path), "EMP prep wav should exist in the Godot asset tree")
	_expect(FileAccess.file_exists(strike_path), "EMP landing wav should exist in the Godot asset tree")
	_expect(ProjectResourceLoader.load_audio_stream(prep_path) != null, "EMP prep wav should load as a Godot audio stream")
	_expect(ProjectResourceLoader.load_audio_stream(strike_path) != null, "EMP landing wav should load as a Godot audio stream")
	_expect(abs(_viper_audio_gain("dive_prep") + 4.4370) <= 0.001, "EMP prep should match Python's 0.6 relative volume")
	_expect(abs(_viper_audio_gain("dive_strike") + 4.4370) <= 0.001, "EMP landing should match Python's 0.6 relative volume")


func _viper_audio_path(cue_id: String) -> String:
	return str(ViperSkillAudio.CUE_SPECS[cue_id].get("path", ""))


func _viper_audio_gain(cue_id: String) -> float:
	return float(ViperSkillAudio.CUE_SPECS[cue_id].get("gain_db", 0.0))


func _test_emp_audio_does_not_fall_back_to_kicks() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var audio := FakeKickFallbackAudio.new()
	runtime._play_dive_prep_sound({"audio": audio})
	runtime._play_dive_strike_sound({"audio": audio})
	_expect(audio.backstep == 0, "EMP prep should stay silent instead of falling back to backstep when its cue is unavailable")
	_expect(audio.marshal == 0, "EMP landing should not fall back to marshal kick")
	_expect(audio.shadow == 0, "EMP landing should not fall back to shadow kick")


func _test_emp_fx_host_remaster_stack() -> void:
	var host_source: String = FileAccess.get_file_as_string("res://scripts/characters/viper_emp_strike_fx_host.gd")
	_expect(host_source.find("static func prewarm_assets_step()") >= 0, "EMP FX host should expose staged asset prewarm")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	_expect(runtime_source.find("EmpStrikeFxHost.prewarm_assets_step()") >= 0, "Viper skill runtime staged prewarm should advance EMP assets through the step API")
	ViperEmpStrikeFxHost.prewarm_assets()
	var host := ViperEmpStrikeFxHost.new()
	_expect(host.has_method("prewarm_runtime_nodes"), "EMP FX host should expose runtime node prewarm")
	host.prewarm_runtime_nodes()
	var warm_debug: Dictionary = host.get_debug_status()
	_expect(bool(warm_debug.get("texture_pieces_ready", false)), "EMP runtime node prewarm should keep reusable texture pieces ready")
	_expect(not bool(warm_debug.get("active", true)), "EMP runtime node prewarm should leave the hidden host inactive")
	_expect(int(warm_debug.get("process_mode", Node.PROCESS_MODE_INHERIT)) == Node.PROCESS_MODE_DISABLED, "EMP runtime node prewarm should disable the hidden host process subtree")
	root.add_child(host)
	_expect(not _process_report_mentions_emp_host(host), "prewarmed inactive EMP FX host should not register a process callback in BattlePerf scan")
	host.sync_state({
		"render_scale": 1.0,
		"phase": 2,
		"hold_active": false,
		"hold_ratio": 0.0,
		"prep_progress": 1.0,
		"shockwave_progress": 0.35,
		"shockwave_alpha": 0.85,
		"height_ratio": 0.70,
		"hit_text_timer": 40.0,
		"hit_text_frames": 50.0,
		"start_msec": 100,
		"shockwave_spawn_msec": 200,
		"hit_spawn_msec": 300,
		"screen_player_center": Vector2(380.0, 560.0),
		"screen_foot": Vector2(380.0, 700.0),
		"screen_shockwave_center": Vector2(380.0, 730.0),
		"screen_hit_pos": Vector2(380.0, 690.0),
		"screen_hit_text_pos": Vector2(380.0, 690.0),
	}, true)
	var debug: Dictionary = host.get_debug_status()
	_expect(int(debug.get("shader_layers", 0)) >= 3, "EMP FX host should provide shader-driven layers")
	_expect(int(debug.get("gpu_particle_layers", 0)) >= 4, "EMP FX host should provide GPU particle layers")
	_expect(bool(debug.get("texture_pieces_ready", false)), "EMP FX host should prewarm reusable texture pieces")
	_expect(not bool(debug.get("processing", true)), "EMP FX host should be draw-sync driven without an outside-shell process callback")
	_expect(int(debug.get("process_mode", Node.PROCESS_MODE_DISABLED)) == Node.PROCESS_MODE_INHERIT, "active EMP FX host should re-enable its child process subtree for particles and tweens")
	_expect(not _process_report_mentions_emp_host(host), "active EMP FX host should stay out of BattlePerf process callback scans")
	host.tear_down(true)


func _test_emp_fx_host_reset_hides_detached_runtime() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var host := ViperEmpStrikeFxHost.new()
	root.add_child(host)
	runtime.emp_fx_host = host
	host.sync_state({
		"render_scale": 1.0,
		"phase": 2,
		"hold_active": false,
		"hold_ratio": 0.0,
		"prep_progress": 1.0,
		"shockwave_progress": 0.35,
		"shockwave_alpha": 0.85,
		"height_ratio": 0.70,
		"hit_text_timer": 40.0,
		"hit_text_frames": 50.0,
		"start_msec": 100,
		"shockwave_spawn_msec": 200,
		"hit_spawn_msec": 300,
		"screen_player_center": Vector2(380.0, 560.0),
		"screen_foot": Vector2(380.0, 700.0),
		"screen_shockwave_center": Vector2(380.0, 730.0),
		"screen_hit_pos": Vector2(380.0, 690.0),
		"screen_hit_text_pos": Vector2(380.0, 690.0),
	}, true)
	var active_debug: Dictionary = host.get_debug_status()
	_expect(bool(active_debug.get("active", false)), "EMP FX host should be active before reset")
	_expect(not bool(active_debug.get("processing", true)), "active EMP FX host should not register a script process callback")
	_expect(not _process_report_mentions_emp_host(host), "active EMP FX host should not appear in BattlePerf process callback scans")
	runtime.reset_round()
	var reset_debug: Dictionary = host.get_debug_status()
	_expect(not bool(reset_debug.get("active", true)), "round reset should hide the detached EMP FX host")
	_expect(not bool(reset_debug.get("processing", true)), "round reset should keep the EMP FX host out of process callbacks")
	_expect(int(reset_debug.get("process_mode", Node.PROCESS_MODE_INHERIT)) == Node.PROCESS_MODE_DISABLED, "round reset should disable the hidden EMP FX host process subtree")
	_expect(not _process_report_mentions_emp_host(host), "round reset should remove the EMP FX host from BattlePerf process callback scans")
	_expect(not bool(reset_debug.get("charge_emitting", true)), "round reset should stop EMP charge particles")
	_expect(not bool(reset_debug.get("jet_emitting", true)), "round reset should stop EMP jet particles")
	_expect(not bool(reset_debug.get("shockwave_emitting", true)), "round reset should stop EMP shockwave particles")
	_expect(not bool(reset_debug.get("hit_emitting", true)), "round reset should stop EMP hit particles")
	host.tear_down(true)


func _test_emp_activation_impact_slip_and_four_poisons_scaling() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	perk_state.four_poisons_level = 3
	var status_state := FakeStatusEffectState.new()
	var jetpack := ViperJetpackState.new()
	jetpack.set_offset_y(-120.0, {"audio": audio})
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, perk_state, jetpack, status_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 580.0)

	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "EMP should require a 0.3s down hold before activation")
	runtime.dive_hold_start_msec = Time.get_ticks_msec() - 301
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "EMP should activate after the down-hold requirement")
	_expect(str(result.get("skill_name", "")) == "dive_strike", "EMP activation should report dive_strike")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 250.0) < 0.01, "EMP should spend 250 gauge")
	_expect(str(skill_state.triggered) == "dive_strike", "EMP should trigger its own cooldown")
	_expect(abs(skill_state.cooldown_seconds - 56.0) < 0.01, "S3 four_poisons ceiling should preserve -20% EMP cooldown")
	_expect(audio.prep == 1 and orb.spins == 1, "EMP startup should play prep audio and spin the orb")
	var startup_snap: Dictionary = runtime.get_snapshot()
	_expect(abs(float(startup_snap.get("dive_prep_frames", 0.0)) - 14.4) < 0.01, "S3 four_poisons ceiling should preserve EMP prep timing")

	player_pos = _get_vector2(result, "player_pos", player_pos)
	for _i in range(30):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 250.0)), config, deps)
		if result.has("player_pos"):
			player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("dive_active", false)), "EMP should remain active during the landing shockwave window")
	_expect(int(snap.get("dive_phase", -1)) == 2, "EMP should land and enter the shockwave phase")
	_expect(audio.strike == 1, "EMP landing should play the strike audio")
	_expect(float(snap.get("dive_shockwave_radius", 0.0)) > 30.0, "EMP circular shockwave should start from the landing ring")
	_expect(float(snap.get("dive_shockwave_max_radius", 0.0)) > 650.0, "EMP circular shockwave should expand far enough to reach the boss")
	var fx_state: Dictionary = runtime.particle_drawer.build_emp_strike_fx_state(
		runtime,
		Vector2.ZERO,
		{"render_scale": 1.0, "game_offset": Vector2.ZERO},
		60.0,
		200.0,
		60.0
	)
	_expect(float(fx_state.get("shockwave_alpha", 0.0)) > 0.0, "EMP should keep the original circular shockwave visual active")
	_expect(float(fx_state.get("shockwave_radius", 0.0)) > 30.0, "EMP should drive boss reach through the original shockwave radius")
	_expect(not fx_state.has("boss_wave_active"), "EMP should not spawn a separate boss-side wave layer")

	var scene := {
		"ball_pos": Vector2(380.0, 690.0),
		"ball_vel": Vector2(3.0, 4.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context: Dictionary = config.duplicate(true)
	motion_context.merge(scene, true)
	var impact: Dictionary = runtime.apply_emp_strike_ball_motion(1.0, scene, motion_context, deps)
	_expect(impact.has("ball_vel"), "EMP shockwave should hit a ball inside the vertical pulse band")
	_expect(_get_vector2(impact, "ball_vel", Vector2.ZERO).y < 0.0, "EMP shockwave should reflect the ball upward")
	_expect(perk_state.gold == 20 and int(impact.get("runtime_perk_gold", 0)) == 20, "EMP shockwave hit should grant 20 skill gold")
	_expect(float(runtime.get_snapshot().get("dive_slip_timer", 0.0)) > 90.0, "S3 four_poisons ceiling should preserve EMP slip duration")
	var hit_feedback_snap: Dictionary = runtime.get_snapshot()
	_expect(float(hit_feedback_snap.get("dive_hit_text_timer", 0.0)) > 0.0, "EMP shockwave hit should start hit text feedback")
	_expect(_get_vector2(hit_feedback_snap, "dive_hit_text_pos", Vector2.ZERO).distance_to(scene["ball_pos"]) < 0.01, "EMP hit text should anchor to the impacted ball")
	runtime.update_effects(10.0, Time.get_ticks_msec(), config, deps)
	_expect(float(runtime.get_snapshot().get("dive_hit_text_timer", 0.0)) < float(hit_feedback_snap.get("dive_hit_text_timer", 0.0)), "EMP hit text should tick down through the effect update path")
	var wave_guard := 0
	while not bool(runtime.get_snapshot().get("dive_shockwave_boss_effect_applied", false)) and wave_guard < 60:
		wave_guard += 1
		runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 250.0)), config, deps)
	var wave_snap: Dictionary = runtime.get_snapshot()
	_expect(bool(wave_snap.get("dive_shockwave_boss_effect_applied", false)), "EMP runtime should remember that the circular shockwave applied its boss EMP effect")
	_expect(status_state.applications.is_empty(), "EMP shockwave should not apply confusion in the original parity behavior")
	_expect(float(wave_snap.get("dive_shockwave_radius", 0.0)) > 650.0, "EMP circular shockwave should reach the boss-side hitbox")
	var actor_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(actor_context.get("viper_emp_slip_active", false)), "EMP slip should expose a boss draw overlay state")
	_expect(float(actor_context.get("viper_emp_slip_ratio", 0.0)) > 0.0, "EMP boss draw overlay should expose remaining slip ratio")
	var stage1_renderer := Stage1BossActorRenderer.new()
	var stage2_renderer := Stage2BossActorRenderer.new()
	_expect(float(stage1_renderer._get_emp_status_intensity(actor_context)) > 0.0, "Stage 1 boss renderer should consume EMP overlay intensity")
	_expect(float(stage2_renderer._get_emp_status_intensity(actor_context)) > 0.0, "Stage 2 boss renderer should consume EMP overlay intensity")

	var boss_ai := BossAiState.new()
	var boss_context: Dictionary = config.duplicate(true)
	boss_context.merge(runtime.get_boss_ai_context(), true)
	var boss_result: Dictionary = boss_ai.update(1.0 / 60.0, Vector2(300.0, 25.0), 0.0, boss_context)
	_expect(_get_vector2(boss_result, "boss_pos", Vector2.ZERO).x > 300.0, "EMP slip should move the boss paddle away from the hit side")


func _test_emp_shockwave_reach_applies_slip_without_ball_hit() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	perk_state.four_poisons_level = 3
	var status_state := FakeStatusEffectState.new()
	var jetpack := ViperJetpackState.new()
	jetpack.set_offset_y(-120.0, {"audio": audio})
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, perk_state, jetpack, status_state)
	var config := _base_config()
	var player_pos := Vector2(302.5, 580.0)

	input.snapshot["down_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	runtime.dive_hold_start_msec = Time.get_ticks_msec() - 301
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	player_pos = _get_vector2(result, "player_pos", player_pos)
	for _i in range(30):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 250.0)), config, deps)
		if result.has("player_pos"):
			player_pos = _get_vector2(result, "player_pos", player_pos)

	_expect(float(runtime.get_snapshot().get("dive_slip_timer", 0.0)) <= 0.0, "test setup should not apply EMP slip before the ring reaches the boss")
	var wave_guard := 0
	while not bool(runtime.get_snapshot().get("dive_shockwave_boss_effect_applied", false)) and wave_guard < 60:
		wave_guard += 1
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, float(result.get("special_gauge", 250.0)), config, deps)
	_expect(bool(runtime.get_snapshot().get("dive_shockwave_boss_effect_applied", false)), "EMP ring should apply the boss EMP effect even without a ball hit")
	_expect(float(runtime.get_snapshot().get("dive_slip_timer", 0.0)) > 90.0, "EMP ring boss contact should start the original EMP slip with Four Poisons scaling")
	_expect(status_state.applications.is_empty(), "EMP ring boss contact should not apply confusion")
	_expect(perk_state.gold == 0, "EMP ring boss contact without ball hit should not award ball-hit skill gold")
	_expect(float(runtime.get_snapshot().get("dive_hit_text_timer", 0.0)) <= 0.0, "EMP ring boss contact without ball hit should not show ball-hit text")


func _test_emp_startup_cancel_and_super_armor() -> void:
	var low_poison := _activated_runtime_with_poison_level(0)
	var runtime: Object = low_poison["runtime"]
	runtime.register_player_ball_contact(low_poison["deps"], _base_config())
	_expect(not bool(runtime.get_snapshot().get("dive_active", true)), "EMP startup should cancel on player-ball contact without four_poisons super armor")

	var armored := _activated_runtime_with_poison_level(2)
	runtime = armored["runtime"]
	runtime.register_player_ball_contact(armored["deps"], _base_config())
	_expect(bool(runtime.get_snapshot().get("dive_active", false)), "S3 Lv.2 four_poisons super armor should preserve EMP startup")


func _activated_runtime_with_poison_level(level: int) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var audio := FakeAudio.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	perk_state.four_poisons_level = level
	var jetpack := ViperJetpackState.new()
	jetpack.set_offset_y(-80.0, {"audio": audio})
	var deps := _deps(input, skill_config, skill_state, audio, orb, feedback, perk_state, jetpack)
	var config := _base_config()
	var player_pos := Vector2(302.5, 620.0)
	input.snapshot["down_pressed"] = true
	runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	runtime.dive_hold_start_msec = Time.get_ticks_msec() - 301
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "test setup should activate EMP")
	return {
		"runtime": runtime,
		"deps": deps,
	}


func _deps(
	input: Object,
	skill_config: Object,
	skill_state: Object,
	audio: Object,
	orb: Object,
	feedback: Object,
	perk_state: Object,
	jetpack: Object,
	status_state: Object = null
) -> Dictionary:
	return {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"audio": audio,
		"orb_hud_state": orb,
		"feedback": feedback,
		"runtime_perk_state": perk_state,
		"viper_jetpack_state": jetpack,
		"status_effect_state": status_state,
	}


func _base_config() -> Dictionary:
	return {
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 700.0,
		"boss_pos": Vector2(300.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _process_report_mentions_emp_host(host: Node) -> bool:
	var report: String = BattlePerfProcessNodeReporter.new().build(host)
	return report.find("ViperEmpStrikeFxHost<viper_emp_strike_fx_host.gd>") >= 0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
