extends SceneTree

const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage2VariantBossRenderer := preload("res://scripts/stages/stage2/stage2_variant_boss_renderer.gd")
const Stage2ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const ViperSkillChaosSpearBallMotionRuntime := preload("res://scripts/characters/viper_skill_chaos_spear_ball_motion_runtime.gd")


class FakeSelectionOwner:
	extends RefCounted
	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var selected_character_id := ""
	var selected_runtime_character_id := ""
	var selected_character_type := ""
	var selected_character_name := ""
	var ai_mode := ""
	var chance_gems_count := 0
	var chance_gems_max := 3

	func _init(value: Object) -> void:
		selection_state = value

	func get_node_or_null(path: NodePath) -> Object:
		return selection_state if str(path) == "/root/GameSelectionState" else null


class FakeAudio:
	var net_count := 0
	var break_count := 0
	var strike_count := 0

	func play_commando_net_gun_capture() -> void:
		net_count += 1

	func play_spider_mine_setup() -> void:
		break_count += 1

	func play_stage3_tail() -> void:
		strike_count += 1


class FakeStatusEffectState:
	var slow_count := 0
	var last_multiplier := 1.0

	func apply_status(target: String, status_id: String, _frames: float, data: Dictionary = {}, _source: String = "") -> void:
		if target == "player" and status_id == "slow":
			slow_count += 1
			last_multiplier = float(data.get("multiplier", 1.0))


class FakeStageBackground:
	var starpoint_count := 0

	func spawn_starpoint_drop(_pos: Vector2, source_type: String = "", _deps: Dictionary = {}, _context: Dictionary = {}) -> void:
		if source_type == "golden_web":
			starpoint_count += 1


class FakeFeedback:
	var shake_count := 0

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shake_count += 1


class FakePowerState:
	var parabola_active := false
	var reset_count := 0

	func is_parabola_active() -> bool:
		return parabola_active

	func reset(_clear_text: bool = true) -> void:
		parabola_active = false
		reset_count += 1


class FakeRuntimePerkState:
	var awarded_gold := 0

	func award_gold(amount: int, _context: Dictionary = {}, _deps: Dictionary = {}) -> int:
		awarded_gold += amount
		return amount


class FakeChaosRuntime:
	var chaos_release_pending := false
	var chaos_release_velocity := Vector2.ZERO
	var chaos_ball_motion_owned := false
	var chaos_state := "blackhole"
	var chaos_target := Vector2.ZERO
	var chaos_phase_frames := 0.0
	var chaos_base_radius := 52.0
	var chaos_orbit_seed := 0.0
	var chaos_blackhole_origin_valid := true
	var chaos_blackhole_ball_origin := Vector2.ZERO
	var chaos_prev_ball_center := Vector2.ZERO
	var chaos_prev_ball_valid := true
	var chaos_gold_ticks_paid := 0
	var chaos_absorb_poll_frames := 5.4
	var chaos_absorb_pulses: Array = []


func _init() -> void:
	_verify_catalog_selection_and_size_route()
	_verify_web_rescue_phase_draw_routes()
	_verify_rage_target_distance_maximization()
	_verify_procedural_gait_and_hit_reaction()
	_verify_arachne_skill_routes()
	print("stage2_arachne_boss_port_smoke: ok")
	quit(0)


func _verify_catalog_selection_and_size_route() -> void:
	_expect(StageBossVariantCatalog.normalize_variant(2, "arachne") == "arachne", "Arachne must register in the Stage 2 pool")
	_expect(StageBossVariantCatalog.normalize_variant(3, "arachne") == "yeonmyo", "Arachne must not cross into the Stage 3 pool")
	var selection_state: Object = GameSelectionState.new()
	selection_state.set_stage(2, "dalji", false, "arachne")
	var owner := FakeSelectionOwner.new(selection_state)
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.stage_boss_variant == "arachne", "selection startup must carry the Arachne variant")
	_expect(owner.boss_paddle_width == 130.0 and owner.boss_hitbox_height == 52.0, "Arachne must apply the original +30% paddle ratio to Godot's live base size")
	selection_state.set_stage(2, "dalji", false, "unknown")
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.stage_boss_variant == "cheongringwi" and owner.boss_paddle_width == 100.0, "unknown Stage 2 variants must preserve headline size and identity")
	owner.selection_state = null
	selection_state.free()


func _verify_web_rescue_phase_draw_routes() -> void:
	var renderer: Object = Stage2VariantBossRenderer.new()
	var expected_methods := {
		"shoot": &"_draw_arachne_web_rescue_shoot",
		"hold_wait": &"_draw_arachne_web_rescue_hold_wait",
		"pull": &"_draw_arachne_web_rescue_pull",
		"hold": &"_draw_arachne_web_rescue_hold",
		"strike": &"_draw_arachne_web_rescue_strike",
	}
	var resolved_methods := {}
	for phase: String in expected_methods:
		var draw_method: StringName = renderer.resolve_arachne_rescue_draw_method({
			"arachne_web_rescue_active": true,
			"arachne_web_rescue_phase": phase,
			"arachne_web_rescue_progress": 0.5,
		})
		_expect(draw_method == expected_methods[phase], "Web Rescue %s must dispatch its dedicated production draw method" % phase)
		_expect(renderer.has_method(draw_method), "Web Rescue %s draw method must exist on the production renderer" % phase)
		_expect(not resolved_methods.has(draw_method), "Web Rescue phases must not collapse onto one draw method")
		resolved_methods[draw_method] = true
	_expect(resolved_methods.size() == 5, "Web Rescue must preserve five visually distinct production draw routes")
	_expect(renderer.resolve_arachne_rescue_draw_method({"arachne_web_rescue_active": false, "arachne_web_rescue_phase": "shoot"}).is_empty(), "inactive Web Rescue must not issue a phase draw call")
	_expect(renderer.resolve_arachne_rescue_draw_method({"arachne_web_rescue_active": true, "arachne_web_rescue_phase": "unknown"}).is_empty(), "unknown Web Rescue phases must fail closed")


func _verify_rage_target_distance_maximization() -> void:
	var seed := 741923
	var existing_x: Array[float] = [88.0, 162.0, 347.0, 419.0, 566.0, 651.0]
	var traps: Array = []
	for occupied_x: float in existing_x:
		traps.append({"pos": Vector2(occupied_x, 710.0), "radius": 50.0})
	var expected := _build_original_rage_target_oracle(seed, existing_x)
	var first: Object = Stage2ArachneBossState.new()
	first.rng.seed = seed
	first.web_traps = traps.duplicate(true)
	first._build_rage_targets()
	_expect(first.rage_targets == expected, "Spider Rage must choose the original best-of-20 X candidate farthest from existing and newly selected webs")
	var second: Object = Stage2ArachneBossState.new()
	second.rng.seed = seed
	second.web_traps = traps.duplicate(true)
	second._build_rage_targets()
	_expect(second.rage_targets == first.rage_targets, "Spider Rage target selection must remain gameplay-seed deterministic")
	var sorted_targets: Array = first.rage_targets.duplicate()
	sorted_targets.sort()
	_expect(
		float(sorted_targets[0]) >= 80.0 and float(sorted_targets[0]) <= 213.0
		and float(sorted_targets[1]) >= 313.0 and float(sorted_targets[1]) <= 446.0
		and float(sorted_targets[2]) >= 546.0 and float(sorted_targets[2]) <= 679.0,
		"Spider Rage must keep one radius-padded target inside each original three-way playfield zone"
	)
	first = null
	second = null


func _build_original_rage_target_oracle(seed: int, initial_existing_x: Array[float]) -> Array[float]:
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed
	var zones := [0, 1, 2]
	for idx in range(zones.size() - 1, 0, -1):
		var swap_index := oracle_rng.randi_range(0, idx)
		var temp: int = zones[idx]
		zones[idx] = zones[swap_index]
		zones[swap_index] = temp
	var occupied_x := initial_existing_x.duplicate()
	var selected: Array[float] = []
	for zone: int in zones:
		var zone_low := 30 + zone * 233 + 50
		var zone_high := 30 + (zone + 1) * 233 - 50
		var best_x := 0.0
		var best_distance := -1.0
		for _attempt in range(20):
			var candidate_x := float(oracle_rng.randi_range(zone_low, zone_high))
			var minimum_distance := INF
			for existing_x: float in occupied_x:
				minimum_distance = minf(minimum_distance, absf(candidate_x - existing_x))
			if minimum_distance > best_distance:
				best_distance = minimum_distance
				best_x = candidate_x
		selected.append(best_x)
		occupied_x.append(best_x)
	return selected


func _verify_procedural_gait_and_hit_reaction() -> void:
	var state: Object = Stage2ArachneBossState.new()
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"boss_pos": Vector2(315.0, 25.0),
		"boss_paddle_width": 130.0,
		"ball_pos": Vector2(440.0, 70.0),
		"ball_size": 28.6,
	}
	state.update(1.0 / 60.0, context, {})
	var idle_snapshot: Dictionary = state.get_actor_draw_context()
	_expect(int(idle_snapshot.get("arachne_motion_direction", 99)) == 0, "stationary Arachne must expose an idle motion state")
	_expect(idle_snapshot.get("arachne_leg_twitch", []).size() == 8, "stationary Arachne must expose one procedural twitch value per leg")
	context["boss_pos"] = Vector2(327.0, 25.0)
	state.update(1.0 / 60.0, context, {})
	var moving_snapshot: Dictionary = state.get_actor_draw_context()
	_expect(int(moving_snapshot.get("arachne_motion_direction", 0)) == 1, "rightward boss motion must drive Arachne's directional gait")
	_expect(float(moving_snapshot.get("arachne_motion_speed", 0.0)) > 0.0 and float(moving_snapshot.get("arachne_step_phase", 0.0)) > 0.0, "moving Arachne must advance its nonlinear gait phase from live speed")
	_expect(not is_equal_approx(float(moving_snapshot.get("arachne_body_bob", 0.0)), float(idle_snapshot.get("arachne_body_bob", 0.0))), "moving Arachne must replace idle breathing with gait-driven body bob")
	context["boss_pos"] = Vector2(327.0, 25.0)
	state.update(1.0 / 60.0, context, {})
	var settled_snapshot: Dictionary = state.get_actor_draw_context()
	_expect(int(settled_snapshot.get("arachne_motion_direction", 99)) == 0, "settled Arachne must return to idle leg twitch instead of looping a walk pose")
	var gameplay_rng_state: int = state.rng.state
	state.register_boss_hit(Vector2(-2.0, 8.0), context, {})
	var hit_snapshot: Dictionary = state.get_actor_draw_context()
	var venom: Array = hit_snapshot.get("arachne_venom_particles", [])
	_expect(float(hit_snapshot.get("arachne_hit_progress", 0.0)) == 1.0 and int(hit_snapshot.get("arachne_hit_direction", 0)) == 1, "Arachne hit reaction must begin at full 0.45-second intensity and preserve the impact side")
	_expect(venom.size() >= 6 and venom.size() <= 10, "Arachne hit reaction must emit the original six-to-ten venom particles")
	_expect(state.rng.state == gameplay_rng_state, "procedural hit particles must not advance authoritative gameplay RNG")
	var first_particle: Dictionary = venom[0]
	state.update(0.05, context, {})
	var advanced_hit: Dictionary = state.get_actor_draw_context()
	var advanced_venom: Array = advanced_hit.get("arachne_venom_particles", [])
	_expect(float(advanced_hit.get("arachne_hit_progress", 1.0)) < 1.0 and advanced_venom.size() == venom.size(), "Arachne hit intensity and live venom particles must advance across frames")
	_expect(_as_test_vector2(advanced_venom[0].get("pos", Vector2.ZERO)) != _as_test_vector2(first_particle.get("pos", Vector2.ZERO)), "venom particles must move from the fangs rather than remain a static hit badge")
	var particle_count_before_sibling_hit: int = state.venom_particles.size()
	context["stage_boss_variant"] = "molewang"
	state.register_boss_hit(Vector2.ZERO, context, {})
	_expect(state.venom_particles.size() == particle_count_before_sibling_hit, "Molewang hit routing must not spawn dormant Arachne venom")
	state = null


func _as_test_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _verify_arachne_skill_routes() -> void:
	var registry: Object = GameplayModuleRegistry.new()
	var state: Object = registry.get_instance("stage2_boss_skill_state")
	var audio := FakeAudio.new()
	var statuses := FakeStatusEffectState.new()
	var background := FakeStageBackground.new()
	var feedback := FakeFeedback.new()
	var power_state := FakePowerState.new()
	var deps := {
		"audio": audio,
		"status_effect_state": statuses,
		"stage_background": background,
		"feedback": feedback,
		"power_state": power_state,
	}
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 300.0),
		"ball_vel": Vector2(2.0, -8.0),
		"ball_size": 28.6,
		"boss_pos": Vector2(315.0, 25.0),
		"boss_paddle_width": 130.0,
		"boss_hitbox_height": 52.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false},
	}
	var size_result: Dictionary = state.update(0.0, context, deps)
	_expect(float(size_result.get("boss_paddle_width", 0.0)) == 130.0 and float(size_result.get("boss_hitbox_height", 0.0)) == 52.0, "production update must keep Arachne collision size on the owner result route")
	_verify_hud_skill_key_contract(state)
	state.arachne_state.boss_special_gauge = 440.0
	var hit_result: Dictionary = state.register_boss_hit(Vector2(3.0, 8.0), context, deps)
	_expect(bool(hit_result.get("arachne_web_trap_triggered", false)), "boss contact must add 60 then trigger the 500-cost Web Trap")
	_expect(state.get_boss_special_gauge() <= 0.001 and audio.net_count == 1, "Web Trap must consume the full gauge and route the original net sound")
	for _index in range(12):
		state.update(0.05, context, deps)
	_expect(state.arachne_state.web_trap_projectile.is_empty() and state.arachne_state.web_traps.size() == 1, "Web Trap must land after the original 35-frame travel")
	var trap: Dictionary = state.arachne_state.web_traps[0]
	trap["expand"] = 0.0
	trap["golden"] = true
	state.arachne_state.web_traps[0] = trap
	var trap_pos: Vector2 = trap.get("pos", Vector2.ZERO)
	context["player_pos"] = trap_pos - Vector2(60.0, 25.0)
	state.update(0.05, context, deps)
	_expect(statuses.slow_count == 1 and statuses.last_multiplier == 0.40, "expanded web overlap must apply the original 0.40 player-speed multiplier")
	context["dash_snapshot"] = {"active": true}
	state.update(0.05, context, deps)
	_expect(state.arachne_state.web_traps.is_empty(), "dash overlap must destroy an expanded web")
	for _index in range(16):
		state.update(0.05, context, deps)
	_expect(background.starpoint_count == 1, "destroyed golden web must spawn a starpoint after 48 frames")

	state.arachne_state.web_trap_cooldown = 0.0
	state.arachne_state.boss_special_gauge = 50.0
	context["dash_snapshot"] = {"active": false}
	context["player_pos"] = Vector2(302.5, 700.0)
	context["ball_pos"] = Vector2(390.0, 20.0)
	context["ball_vel"] = Vector2(1.0, -9.0)
	power_state.parabola_active = true
	var rescue_result: Dictionary = state.update(0.01, context, deps)
	_expect(bool(rescue_result.get("skip_ball_motion_step", false)) and state.arachne_state.web_rescue_phase == "shoot", "top-bound upward ball must enter Web Rescue and freeze motion")
	_expect(not power_state.parabola_active and power_state.reset_count == 1, "Web Rescue activation must immediately clear the live Power Smashing parabola state")
	var moved_boss := false
	for _index in range(90):
		rescue_result = state.update(0.05, context, deps)
		if rescue_result.get("boss_pos", null) is Vector2:
			context["boss_pos"] = rescue_result["boss_pos"]
			moved_boss = true
		if not state.arachne_state.web_rescue_active:
			break
	_expect(moved_boss, "Web Rescue pull phase must move the live boss toward the caught ball")
	var released_vel := _as_vector2(rescue_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(not state.arachne_state.web_rescue_active and absf(released_vel.length() - 18.0) < 0.01 and released_vel.y > 0.0, "Web Rescue must release downward at fixed speed 18")
	_expect(audio.strike_count == 1, "Web Rescue strike must route paddle-impact audio once")
	state.reset()
	state.update(0.0, context, deps)
	state.arachne_state.boss_special_gauge = 50.0
	state.arachne_state.web_rescue_cooldown = 0.0
	state.update(0.01, context, deps)
	_expect(power_state.reset_count == 1, "Web Rescue must not reset an inactive Power Smashing state")
	state.reset()
	state.update(0.0, context, deps)
	_verify_chaos_spear_absorption(state, context)

	state.handle_score_event("player", {"player_score": 4}, deps)
	state.reset_round()
	_expect(state.arachne_state.rage_active and state.arachne_state.rage_triggered, "four-point event must start Spider Rage on the following round")
	for _index in range(27):
		state.update(0.05, context, deps)
	_expect(state.arachne_state.rage_frame >= 80 and not state.arachne_state.rage_projectiles.is_empty(), "Spider Rage must launch its first red web at frame 80")
	for _index in range(40):
		state.update(0.05, context, deps)
	var rage_trap_count := 0
	for value in state.arachne_state.web_traps:
		if value is Dictionary and bool(value.get("rage", false)):
			rage_trap_count += 1
	_expect(rage_trap_count == 3 and not state.arachne_state.rage_active, "Spider Rage must land three persistent red webs and finish after frame 120")
	state.reset_round()
	_expect(state.arachne_state.rage_active, "triggered Spider Rage must repeat on subsequent rounds")
	_expect(feedback.shake_count > 0 and audio.break_count > 0, "Spider Rage must route stomp shake and spider-impact audio")

	# Smoke is a true negative/counter route: a web projectile dissolves before landing.
	state.reset()
	state.update(0.0, context, deps)
	state.arachne_state.boss_special_gauge = 500.0
	state.register_boss_hit(Vector2(2.0, 8.0), context, deps)
	var projectile_pos: Vector2 = state.arachne_state._get_projectile_pos(state.arachne_state.web_trap_projectile)
	context["smoke_zones"] = [{"position": projectile_pos, "radius": 120.0, "opacity": 1.0}]
	state.update(0.01, context, deps)
	_expect(state.arachne_state.web_trap_projectile.is_empty() and state.arachne_state.web_traps.is_empty(), "dense smoke must dissolve a web projectile before it becomes a trap")

	state = null
	registry.clear_all()


func _verify_chaos_spear_absorption(state: Object, context: Dictionary) -> void:
	var center := Vector2(380.0, 180.0)
	var far_pos := Vector2(710.0, 650.0)
	state.arachne_state.web_trap_projectile = {
		"start": center,
		"target": center,
		"age": 0.0,
		"duration": 1.0,
		"golden": false,
		"rage": false,
	}
	state.arachne_state.rage_projectiles = [
		{"start": center, "target": center, "age": 0.0, "duration": 1.0, "golden": true, "rage": true},
		{"start": far_pos, "target": far_pos, "age": 0.0, "duration": 1.0, "golden": false, "rage": true},
	]
	state.arachne_state.web_traps = [
		{"pos": center + Vector2(24.0, 0.0), "radius": 50.0, "golden": false, "rage": false},
		{"pos": center + Vector2(-24.0, 0.0), "radius": 50.0, "golden": false, "rage": true},
		{"pos": far_pos, "radius": 50.0, "golden": false, "rage": false},
	]
	state.arachne_state.web_rescue_active = true
	state.arachne_state.web_rescue_phase = "hold"
	state.arachne_state.web_rescue_timer = 0.5
	state.arachne_state.web_rescue_ball_pos = center
	var runtime := FakeChaosRuntime.new()
	runtime.chaos_target = center
	runtime.chaos_blackhole_ball_origin = center
	runtime.chaos_prev_ball_center = center
	var gold_state := FakeRuntimePerkState.new()
	var result: Dictionary = ViperSkillChaosSpearBallMotionRuntime.apply_motion(
		runtime,
		1.0,
		{"ball_pos": center, "ball_vel": Vector2(0.0, -8.0)},
		{"ball_active": true},
		{"stage2_boss_skill_state": state, "runtime_perk_state": gold_state},
		{
			"blackhole_frames": 180.0,
			"ingress_frames": 31.2,
			"gold_tick_frames": 6.0,
			"gold_per_tick": 1,
			"object_gold": 5,
			"pull_radius": 175.0,
			"absorb_poll_frames": 5.4,
		}
	)
	_expect(state.arachne_state.web_trap_projectile.is_empty(), "Chaos Spear must absorb an in-flight Arachne Web Trap projectile")
	_expect(state.arachne_state.rage_projectiles.size() == 1 and state.arachne_state.web_traps.size() == 1, "Chaos Spear must absorb nearby rage projectiles and normal/rage webs while preserving far hazards")
	_expect(not state.arachne_state.web_rescue_active and state.arachne_state.web_rescue_phase == "idle", "Chaos Spear must cancel an active Web Rescue ownership sequence")
	_expect(runtime.chaos_absorb_pulses.size() == 5, "each absorbed Arachne object must publish one Chaos Spear pulse")
	_expect(gold_state.awarded_gold == 25 and int(result.get("runtime_perk_gold", 0)) == 25, "five absorbed Arachne objects must award the original five gold each")
	state.update(0.0, context.merged({"stage_boss_variant": "molewang"}, true), {})
	state.arachne_state.web_traps = [{"pos": center, "radius": 50.0, "golden": false, "rage": false}]
	var sibling_runtime := FakeChaosRuntime.new()
	sibling_runtime.chaos_target = center
	sibling_runtime.chaos_blackhole_ball_origin = center
	sibling_runtime.chaos_prev_ball_center = center
	var sibling_gold := FakeRuntimePerkState.new()
	ViperSkillChaosSpearBallMotionRuntime.apply_motion(
		sibling_runtime,
		1.0,
		{"ball_pos": center, "ball_vel": Vector2.ZERO},
		{"ball_active": true},
		{"stage2_boss_skill_state": state, "runtime_perk_state": sibling_gold},
		{"blackhole_frames": 180.0, "ingress_frames": 31.2, "gold_tick_frames": 6.0, "gold_per_tick": 1, "object_gold": 5, "pull_radius": 175.0, "absorb_poll_frames": 5.4}
	)
	_expect(state.arachne_state.web_traps.size() == 1 and sibling_gold.awarded_gold == 0, "Molewang active variant must not consume dormant Arachne hazards")
	state.reset()
	state.update(0.0, context, {})


func _verify_hud_skill_key_contract(state: Object) -> void:
	var ready_skill := _find_hud_skill(state.get_hud_context(), "web_trap")
	_expect(not ready_skill.is_empty(), "Arachne HUD must publish the Web Trap card")
	for legacy_key in ["active", "cooldown", "cooldown_total", "cooldown_progress"]:
		_expect(ready_skill.has(legacy_key), "Arachne HUD must preserve legacy producer key %s" % legacy_key)
	for renderer_key in ["status", "ready", "progress"]:
		_expect(ready_skill.has(renderer_key), "Arachne HUD must publish renderer key %s" % renderer_key)
	_expect(str(ready_skill.get("status", "")) == "ready" and bool(ready_skill.get("ready", false)) and is_equal_approx(float(ready_skill.get("progress", -1.0)), 1.0), "zero-cooldown inactive Web Trap must render as ready at 100 percent")
	state.arachne_state.web_trap_cooldown = 7.5
	var charging_skill := _find_hud_skill(state.get_hud_context(), "web_trap")
	_expect(str(charging_skill.get("status", "")) == "charging" and not bool(charging_skill.get("ready", true)), "cooling Web Trap must render as charging and not ready")
	_expect(is_equal_approx(float(charging_skill.get("progress", -1.0)), 0.5) and is_equal_approx(float(charging_skill.get("cooldown_progress", -1.0)), 0.5), "new and legacy progress keys must stay lockstep")
	state.arachne_state.web_trap_projectile = {"fixture": true}
	var casting_skill := _find_hud_skill(state.get_hud_context(), "web_trap")
	_expect(str(casting_skill.get("status", "")) == "casting" and bool(casting_skill.get("active", false)) and not bool(casting_skill.get("ready", true)), "active Web Trap must render as casting without dropping its legacy active key")
	state.reset()


func _find_hud_skill(hud_context: Dictionary, skill_id: String) -> Dictionary:
	for value in hud_context.get("stage2_boss_skill_hud_skills", []):
		if value is Dictionary and str(value.get("id", "")) == skill_id:
			return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
