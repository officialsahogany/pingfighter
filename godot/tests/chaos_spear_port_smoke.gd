extends SceneTree

const ChaosSpearFxHost := preload("res://scripts/characters/viper_chaos_spear_fx_host.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


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
		return skill_name == "chaos_spear"

	func get_skill_cost(skill_name: String) -> float:
		return 150.0 if skill_name == "chaos_spear" else 0.0


class FakeSkillState:
	var triggered := ""

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered = skill_name

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeAudio:
	var windup := 0
	var flying := 0
	var impact := 0
	var blackhole := 0
	var windup_stops := 0
	var flying_stops := 0
	var impact_stops := 0
	var blackhole_stops := 0

	func play_chaos_spear_windup() -> void:
		windup += 1

	func stop_chaos_spear_windup() -> void:
		windup_stops += 1

	func play_chaos_spear_flying() -> void:
		flying += 1

	func stop_chaos_spear_flying() -> void:
		flying_stops += 1

	func play_chaos_spear_impact() -> void:
		impact += 1

	func stop_chaos_spear_impact() -> void:
		impact_stops += 1

	func play_chaos_spear_blackhole_loop() -> void:
		blackhole += 1

	func stop_chaos_spear_blackhole_loop() -> void:
		blackhole_stops += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakePerkState:
	var gold := 0

	func get_runtime_skill_level(_skill_id: String) -> int:
		return 0

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeAbsorbTarget:
	var did_absorb := false

	func absorb_chaos_spear_objects(_center: Vector2, _radius: float, _deps: Dictionary = {}) -> Array:
		if did_absorb:
			return []
		did_absorb = true
		return [{"position": Vector2(390.0, 430.0), "strength": 1.0, "color": Color(0.8, 0.5, 1.0)}]


func _init() -> void:
	_verify_chaos_spear_fx_pipeline()
	_verify_chaos_spear_round_boundary_cleanup()

	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var orb := FakeOrbHud.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var perk_state := FakePerkState.new()
	var absorb_target := FakeAbsorbTarget.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"orb_hud_state": orb,
		"audio": audio,
		"feedback": feedback,
		"runtime_perk_state": perk_state,
		"stage_background": absorb_target,
	}
	var config := {
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"ball_pos": Vector2(140.0, 250.0),
		"ball_vel": Vector2(5.0, 4.0),
	}
	var player_pos := Vector2(302.5, 700.0)

	input.snapshot["left_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "A alone should only buffer the chaos spear command")
	input.snapshot["left_pressed"] = false
	runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(not bool(result.get("activated", false)), "A-W should still wait for D")
	input.snapshot["up_pressed"] = false
	runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	input.snapshot["right_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, deps)
	_expect(bool(result.get("activated", false)), "A-W-D should activate chaos spear")
	_expect(str(skill_state.triggered) == "chaos_spear", "activation should trigger the chaos spear cooldown")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 350.0) < 0.01, "activation should spend 150 gauge")
	_expect(orb.spins == 1, "activation should spin the orb HUD once")
	_expect(audio.windup == 1, "activation should play phase 1 windup audio")

	var effect_context := {
		"selected_character_type": "viper",
		"ball_active": true,
		"player_pos": player_pos,
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(140.0, 250.0),
		"ball_vel": Vector2(5.0, 4.0),
	}
	for _i in range(46):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "flying", "startup should advance into flying")
	_expect(audio.flying == 1, "flying transition should play phase 2 audio")
	for _i in range(18):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "impact", "flying should advance into impact")
	for _i in range(23):
		runtime.update_effects(1.0, Time.get_ticks_msec(), effect_context, deps)
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "blackhole", "impact should open the blackhole")
	_expect(audio.impact == 1 and audio.blackhole >= 1, "blackhole transition should play phase 3 and gravity audio")

	var scene := {
		"ball_pos": Vector2(140.0, 250.0),
		"ball_vel": Vector2(5.0, 4.0),
		"player_collision_cooldown": 0.0,
		"ball_impact_boost": 1.0,
	}
	var motion_context := effect_context.duplicate(true)
	for _i in range(7):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, deps)
		result = runtime.apply_chaos_spear_ball_motion(1.0, scene, motion_context, deps)
		scene.merge(result, true)
		motion_context.merge(scene, true)
	_expect(bool(result.get("skip_ball_motion_step", false)), "blackhole should own the ball motion step")
	_expect(_get_vector2(scene, "ball_pos", Vector2.ZERO).distance_to(Vector2(140.0, 250.0)) > 1.0, "blackhole should pull the ball into orbit")
	_expect(perk_state.gold >= 1 + 5, "blackhole should grant tick gold and absorbed-object gold")

	for _i in range(173):
		runtime.update_effects(1.0, Time.get_ticks_msec(), motion_context, deps)
	result = runtime.apply_chaos_spear_ball_motion(1.0, scene, motion_context, deps)
	_expect(result.has("ball_vel") and _get_vector2(result, "ball_vel", Vector2.ZERO).length() >= 16.0, "blackhole expiry should release the ball at a strong speed")

	print("chaos_spear_port_smoke: ok")
	quit(0)


func _verify_chaos_spear_fx_pipeline() -> void:
	var host_source: String = FileAccess.get_file_as_string("res://scripts/characters/viper_chaos_spear_fx_host.gd")
	_expect(host_source.find("static func prewarm_assets_step()") >= 0, "Chaos Spear FX host should expose staged asset prewarm")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	_expect(runtime_source.find("func _init() -> void:\n\tpass") >= 0, "Viper skill runtime constructor should avoid monolithic FX prewarm")
	_expect(runtime_source.find("ChaosSpearFxHost.prewarm_assets_step()") >= 0, "Viper skill runtime staged prewarm should advance Chaos Spear assets through the step API")
	var status: Dictionary = ChaosSpearFxHost.build_pipeline_status()
	_expect(bool(status.get("chaos_spear_shader_host_pipeline", false)), "Chaos Spear FX host should expose the shader pipeline")
	_expect(bool(status.get("chaos_spear_texture_pieces_ready", false)), "Chaos Spear FX host should load all five imagegen texture pieces")
	_expect(bool(status.get("chaos_spear_glyph_png_slot", false)), "Chaos Spear glyph PNG slot should load")
	_expect(bool(status.get("chaos_spear_silhouette_png_slot", false)), "Chaos Spear silhouette PNG slot should load")
	_expect(bool(status.get("chaos_spear_trail_png_slot", false)), "Chaos Spear trail PNG slot should load")
	_expect(bool(status.get("chaos_spear_impact_burst_png_slot", false)), "Chaos Spear impact burst PNG slot should load")
	_expect(bool(status.get("chaos_spear_cracks_png_slot", false)), "Chaos Spear cracks PNG slot should load")
	_expect(int(status.get("chaos_spear_gpu_particle_layers", 0)) >= 5, "Chaos Spear FX host should keep charge plus blackhole particle layers")
	_verify_chaos_spear_fx_phase_visibility()


func _verify_chaos_spear_fx_phase_visibility() -> void:
	var host: Node = ChaosSpearFxHost.new()
	_expect(host.has_method("prewarm_runtime_nodes"), "Chaos Spear FX host should expose runtime node prewarm")
	host.prewarm_runtime_nodes()
	var warm_debug: Dictionary = host.get_debug_status()
	_expect(bool(warm_debug.get("texture_pieces_ready", false)), "Chaos Spear runtime node prewarm should keep texture pieces ready")
	_expect(not bool(warm_debug.get("active", true)), "Chaos Spear runtime node prewarm should leave the hidden host inactive")
	var base_state := {
		"screen_center": Vector2(380.0, 435.0),
		"screen_current": Vector2(380.0, 690.0),
		"screen_origin": Vector2(380.0, 690.0),
		"screen_player_center": Vector2(380.0, 690.0),
		"screen_size": 220.0,
		"alpha": 1.0,
		"progress": 0.0,
		"phase_progress": 0.65,
		"render_scale": 1.0,
		"flight_angle": -1.2,
		"spawn_msec": 1,
	}
	var state := base_state.duplicate(true)
	state["phase"] = "startup"
	host.sync_state(state, true)
	var debug: Dictionary = host.get_debug_status()
	_expect(bool(debug.get("glyph_visible", false)), "Chaos Spear startup should show the glyph texture")
	_expect(bool(debug.get("spear_visible", false)), "Chaos Spear startup should show the spear texture")
	_expect(not bool(debug.get("processing", true)), "Chaos Spear FX host should stay driven by battle draw sync")

	state = base_state.duplicate(true)
	state["phase"] = "flying"
	state["screen_current"] = Vector2(380.0, 520.0)
	state["phase_progress"] = 0.40
	host.sync_state(state, true)
	debug = host.get_debug_status()
	_expect(bool(debug.get("spear_visible", false)), "Chaos Spear flying should show the spear texture")
	_expect(bool(debug.get("trail_visible", false)), "Chaos Spear flying should show the trail texture")

	state = base_state.duplicate(true)
	state["phase"] = "impact"
	state["phase_progress"] = 0.42
	host.sync_state(state, true)
	debug = host.get_debug_status()
	_expect(bool(debug.get("impact_burst_visible", false)), "Chaos Spear impact should show the burst texture")
	_expect(bool(debug.get("cracks_visible", false)), "Chaos Spear impact should show the cracks texture")
	_expect(bool(debug.get("cracks_writhe_shader", false)), "Chaos Spear cracks should use the writhing ember shader")
	_expect(float(debug.get("cracks_intensity", 0.0)) >= 0.99, "Chaos Spear impact cracks should raise writhing intensity")
	_expect(float(debug.get("cracks_distort_strength", 0.0)) >= 0.05, "Chaos Spear cracks should use strong v2 displacement")
	_expect(float(debug.get("cracks_lateral_strength", 0.0)) >= 0.04, "Chaos Spear cracks should use lateral snake displacement")
	_expect(float(debug.get("cracks_jitter_strength", 0.0)) >= 0.01, "Chaos Spear cracks should use high-frequency electric jitter")
	_expect(float(debug.get("cracks_bolt_flow_speed", 0.0)) >= 4.0, "Chaos Spear cracks should use fast bolt flow")
	_expect(float(debug.get("cracks_flicker_speed", 0.0)) >= 8.0, "Chaos Spear cracks should use fast branch flicker")

	state = base_state.duplicate(true)
	state["phase"] = "blackhole"
	state["progress"] = 0.45
	state["phase_progress"] = 0.45
	host.sync_state(state, true)
	debug = host.get_debug_status()
	_expect(bool(debug.get("blackhole_visible", false)), "Chaos Spear blackhole should show the shader disk")
	_expect(bool(debug.get("cracks_visible", false)), "Chaos Spear blackhole should keep the cracks texture behind the disk")
	_expect(float(debug.get("cracks_intensity", 0.0)) >= 0.80, "Chaos Spear blackhole cracks should keep ember intensity alive")
	host.free()


func _verify_chaos_spear_round_boundary_cleanup() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var audio := FakeAudio.new()
	var host: Node = _active_startup_fx_host()
	runtime.chaos_fx_host = host
	runtime.chaos_state = "startup"
	runtime.chaos_phase_frames = 4.0
	runtime.reset_round({"audio": audio})
	_expect(str(runtime.get_snapshot().get("chaos_state", "")) == "idle", "round reset should clear active Chaos Spear state")
	_expect(not bool(host.get_debug_status().get("active", true)), "round reset should hide the node-hosted Chaos Spear FX")
	_expect(
		audio.windup_stops >= 1 and audio.flying_stops >= 1 and audio.impact_stops >= 1 and audio.blackhole_stops >= 1,
		"round reset should stop every Chaos Spear audio phase"
	)
	host.free()

	var waiting_runtime: Object = ViperSkillRuntime.new()
	var waiting_host: Node = _active_startup_fx_host()
	waiting_runtime.chaos_fx_host = waiting_host
	waiting_runtime.chaos_state = "startup"
	waiting_runtime.chaos_target = Vector2(380.0, 435.0)
	waiting_runtime.chaos_current = Vector2(380.0, 690.0)
	waiting_runtime.update_effects(1.0, Time.get_ticks_msec(), {
		"selected_character_type": "viper",
		"ball_active": true,
		"waiting_for_serve": true,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 420.0),
	}, {"audio": FakeAudio.new()})
	_expect(str(waiting_runtime.get_snapshot().get("chaos_state", "")) == "idle", "serve wait should cancel a just-started Chaos Spear")
	_expect(not bool(waiting_host.get_debug_status().get("active", true)), "serve wait cleanup should hide the Chaos Spear FX host")
	waiting_host.free()


func _active_startup_fx_host() -> Node:
	var host: Node = ChaosSpearFxHost.new()
	host.sync_state({
		"phase": "startup",
		"screen_center": Vector2(380.0, 435.0),
		"screen_current": Vector2(380.0, 690.0),
		"screen_origin": Vector2(380.0, 690.0),
		"screen_player_center": Vector2(380.0, 690.0),
		"screen_size": 220.0,
		"alpha": 1.0,
		"progress": 0.0,
		"phase_progress": 0.65,
		"render_scale": 1.0,
		"flight_angle": -1.2,
		"spawn_msec": 1,
	}, true)
	_expect(bool(host.get_debug_status().get("active", false)), "test setup should activate the Chaos Spear FX host")
	_expect(not bool(host.get_debug_status().get("processing", true)), "active Chaos Spear FX host should not run detached _process")
	return host


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
