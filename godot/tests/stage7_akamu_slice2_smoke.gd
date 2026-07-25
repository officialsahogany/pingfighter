extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const Stage7AkamuPlayfieldRenderer := preload("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BattleSceneEffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const MythicItemVenomMistRuntime := preload("res://scripts/items/mythic_item_venom_mist_runtime.gd")
const SmasherPlasmaState := preload("res://scripts/characters/smasher_plasma_state.gd")

var _failures: Array[String] = []


class FakeCleanseState:
	extends RefCounted

	var immune := false

	func is_immune() -> bool:
		return immune


class FakeActiveItemRuntime:
	extends RefCounted

	var paused := false
	var tear_gas_zones: Array = []

	func get_boss_ai_context() -> Dictionary:
		return {
			"active_item_tear_gas_cooldown_pause_active": paused,
			"active_item_boss_skill_cooldown_paused": paused,
		}

	func get_tear_gas_zones() -> Array:
		return tear_gas_zones


class FakeOwner:
	extends RefCounted

	var drive_text_timer_frames := 0.0
	var special_gauge := 100.0
	var player_speed := 5.0
	var lingpet_star_coil_freeze_boss_skill_cd := true
	var selected_character_type := "smasher"
	var battle_textures: Dictionary = {}


class FakeVenomRuntime:
	extends RefCounted

	var stage7_state: Object = null

	func _get_instance(_registry: Object, key: String) -> Object:
		if key == "stage7_akamu_state":
			return stage7_state
		return null


func _init() -> void:
	_verify_boss_hit_gauge_gain_pause_and_attack_trigger()
	_verify_shuriken_cast_cost_target_snapshot_and_awakened_bonus()
	_verify_shuriken_visual_parity_contract()
	_verify_blood_particle_legacy_parameters()
	_verify_shuriken_motion_is_fps_invariant()
	_verify_shuriken_swept_collision_at_supported_fps()
	_verify_shuriken_hitch_frame_hits_before_offscreen_cull()
	_verify_shuriken_hit_slow_immediate_speed_and_full_drain()
	_verify_cleanse_blocks_slow_and_drain_but_keeps_hit_particles()
	_verify_smoke_silently_absorbs_shuriken()
	_verify_boss_skill_pause_freezes_scheduler_but_not_inflight_projectiles()
	_verify_round_cleanup_clears_all_shuriken_transients()
	_verify_effects_result_propagates_speed_and_gauge()
	_verify_ball_snapshot_carries_star_coil_pause()
	_verify_external_boss_gauge_drain_routes_to_stage7()

	if _failures.is_empty():
		print("stage7_akamu_slice2_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shuriken_visual_parity_contract() -> void:
	# 원본 draw_stage8_shurikens 파리티: 채워진 은빛 4날(하이라이트+외곽선) +
	# 3링 금속 허브 + 중앙 구멍. 선 별표 플레이스홀더로의 회귀를 봉인한다.
	_expect(
		Stage7AkamuPlayfieldRenderer.SHURIKEN_BLADE_COLOR.is_equal_approx(
			Color(180.0 / 255.0, 190.0 / 255.0, 200.0 / 255.0)
		),
		"shuriken blades should keep the legacy silver-metal (180,190,200) palette"
	)
	_expect(
		Stage7AkamuPlayfieldRenderer.SHURIKEN_BLADE_HIGHLIGHT_COLOR.is_equal_approx(
			Color(220.0 / 255.0, 230.0 / 255.0, 240.0 / 255.0)
		),
		"shuriken blade highlight should keep the legacy (220,230,240) palette"
	)
	_expect(
		Stage7AkamuPlayfieldRenderer.SHURIKEN_HUB_DARK_COLOR.is_equal_approx(
			Color(80.0 / 255.0, 90.0 / 255.0, 100.0 / 255.0)
		),
		"shuriken hub should keep the legacy dark-metal (80,90,100) palette"
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd"
	)
	var start_index: int = source.find("func _draw_shuriken(")
	var end_index: int = source.find("func _draw_cloud(", maxi(0, start_index))
	var shuriken_source := source.substr(maxi(0, start_index), maxi(0, end_index - start_index))
	_expect(
		shuriken_source.find("draw_colored_polygon") >= 0,
		"shuriken should render filled legacy blades, not placeholder line strokes"
	)
	_expect(
		shuriken_source.find("SHURIKEN_HUB_HOLE_COLOR") >= 0,
		"shuriken hub should include the legacy center hole"
	)


func _verify_blood_particle_legacy_parameters() -> void:
	# 원본 create_blood_particles 파리티: 8~12개, 속도 3~12 + 상향킥 2~5,
	# 크기 2~5, 수명 20~40프레임, 중력 0.3~0.6 포물선, 시작 알파 1.0.
	var state: Object = Stage7AkamuState.new()
	state.debug_seed_rng(7211)
	state.call("_spawn_shuriken_hit_particles", Vector2(380.0, 600.0), Vector2(0.0, 20.0))
	var particles: Array = state.get("_particles")
	_expect(
		particles.size() >= 8 and particles.size() <= 12,
		"blood burst should spawn the legacy 8~12 particles"
	)
	var all_fields_ok := not particles.is_empty()
	for value in particles:
		var particle: Dictionary = value
		var gravity: float = float(particle.get("gravity_per_frame", -1.0))
		var radius: float = float(particle.get("radius", 0.0))
		var life: float = float(particle.get("max_life", 0.0))
		if gravity < 0.3 - 0.0001 or gravity > 0.6 + 0.0001:
			all_fields_ok = false
		if radius < 2.0 - 0.0001 or radius > 5.0 + 0.0001:
			all_fields_ok = false
		if life < 20.0 / 60.0 - 0.0001 or life > 40.0 / 60.0 + 0.0001:
			all_fields_ok = false
		if not is_equal_approx(float(particle.get("base_alpha", 0.0)), 1.0):
			all_fields_ok = false
	_expect(all_fields_ok, "blood particles should carry legacy gravity/size/lifetime/alpha ranges")
	var first_before: Dictionary = particles[0]
	var vel_before: Vector2 = first_before.get("vel", Vector2.ZERO)
	var gravity_per_frame: float = float(first_before.get("gravity_per_frame", 0.0))
	state.call("_update_particles", 1.0 / 60.0)
	var after_particles: Array = state.get("_particles")
	_expect(not after_particles.is_empty(), "blood particles should survive one update tick")
	if not after_particles.is_empty():
		var vel_after: Vector2 = (after_particles[0] as Dictionary).get("vel", Vector2.ZERO)
		# 판별 조건: 중력 경로는 y에 정확히 gravity_per_frame을 더하고 x는
		# 그대로 둔다. 마찰 경로(x0.92)는 x를 감쇠시키므로 여기서 갈린다.
		_expect(
			absf((vel_after.y - vel_before.y) - gravity_per_frame) < 0.01,
			"blood particles should gain exactly the legacy per-frame gravity on vel.y"
		)
		_expect(
			absf(vel_after.x - vel_before.x) < 0.0001,
			"blood particles must keep vel.x friction-free (legacy has no drag)"
		)


func _verify_boss_hit_gauge_gain_pause_and_attack_trigger() -> void:
	var state: Object = Stage7AkamuState.new()
	var context: Dictionary = _base_context()
	var scene := {"ball_pos": Vector2(420.0, 80.0), "ball_vel": Vector2(0.0, 12.0)}

	state.handle_boss_paddle_hit(scene, context)
	_expect_close(state.debug_get_gauge(), 80.0, "normal boss reflection should add 80 gauge")
	var draw_context: Dictionary = state.get_actor_draw_context()
	_expect(bool(draw_context.get("stage7_akamu_boss_attack_active", false)), "accepted boss reflection should trigger the Stage 7 attack pose")
	_expect(str(draw_context.get("stage7_akamu_boss_attack_source", "")) == "boss_paddle_hit", "boss reflection attack pose should expose its source")

	state.debug_set_awakened(true)
	state.debug_set_gauge(0.0)
	state.handle_boss_paddle_hit(scene, context)
	_expect_close(state.debug_get_gauge(), 90.0, "awakened boss reflection should add 90 gauge")

	state.debug_set_superspeed_active(true)
	state.debug_set_gauge(0.0)
	state.handle_boss_paddle_hit(scene, context)
	_expect_close(state.debug_get_gauge(), 20.0, "superspeed boss reflection should use the reduced 20 gauge gain")

	state.debug_set_superspeed_active(false)
	state.debug_set_awakened(false)
	state.debug_set_gauge(480.0)
	# Isolate the gauge-cap contract from the independent post-hit clone/cloud
	# rolls. Without an external writer guard, a valid random cloud start can
	# immediately spend 120 after the gauge reaches 500 and make this assertion
	# flaky even though the clamp itself succeeded.
	var clamp_context: Dictionary = context.duplicate()
	clamp_context["lingpet_puppet_grab_active"] = true
	state.handle_boss_paddle_hit(scene, clamp_context)
	_expect_close(state.debug_get_gauge(), 500.0, "boss reflection gauge gain should clamp at 500")

	var active_item_runtime := FakeActiveItemRuntime.new()
	active_item_runtime.paused = true
	state.debug_set_gauge(100.0)
	state.handle_boss_paddle_hit(scene, context, {"active_item_runtime": active_item_runtime})
	_expect_close(state.debug_get_gauge(), 100.0, "tear-gas pause should block boss-hit gauge gain on the ball path")
	context["lingpet_star_coil_freeze_boss_skill_cd"] = true
	active_item_runtime.paused = false
	state.handle_boss_paddle_hit(scene, context, {"active_item_runtime": active_item_runtime})
	_expect_close(state.debug_get_gauge(), 100.0, "Star Coil pause should block boss-hit gauge gain on the ball path")
	_expect(bool(state.get_actor_draw_context().get("stage7_akamu_boss_attack_active", false)), "cooldown pause should not suppress physical boss contact animation")


func _verify_shuriken_cast_cost_target_snapshot_and_awakened_bonus() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_seed_rng(71207)
	state.debug_set_gauge(100.0)
	state.debug_set_awakened(true)
	state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	var context: Dictionary = _base_context()
	context["player_pos"] = Vector2(100.0, 690.0)

	state.update(1.0 / 60.0, context)
	var snapshot: Dictionary = state.debug_get_shuriken_snapshot()
	_expect(bool(snapshot.get("casting", false)), "ready shuriken scheduler should enter the 300ms cast")
	_expect_close(state.debug_get_gauge(), 70.0, "shuriken should spend 30 gauge at cast start")
	_expect(bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", false)), "shuriken cast should hold the boss at the captured position")
	_expect(int(snapshot.get("projectile_count", -1)) == 0, "shuriken should not spawn before cast completion")

	# Target is sampled at release, not at cast start.
	context["player_pos"] = Vector2(520.0, 690.0)
	for _frame in range(18):
		state.update(1.0 / 60.0, context)
	snapshot = state.debug_get_shuriken_snapshot()
	_expect(not bool(snapshot.get("casting", true)), "shuriken cast should release after 300ms")
	_expect(int(snapshot.get("projectile_count", 0)) == 1, "primary shuriken should spawn once at release")
	_expect(int(snapshot.get("pending_count", 0)) == 1, "awakened primary shot should reserve one 200ms bonus shot")
	_expect(not bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", true)), "boss hold should release with the primary shuriken")
	var shuriken: Dictionary = (state.get_actor_draw_context().get("stage7_akamu_shurikens", []) as Array)[0]
	_expect((_as_vector2(shuriken.get("velocity", Vector2.ZERO))).x > 0.0, "released shuriken should aim at the player's release-time position")
	var primary_cooldown: float = float(snapshot.get("cooldown_remaining_sec", 0.0))
	_expect(primary_cooldown >= 8.0 and primary_cooldown <= 25.0, "primary release should arm an 8-25 second cooldown")

	for _frame in range(12):
		state.update(1.0 / 60.0, context)
	snapshot = state.debug_get_shuriken_snapshot()
	_expect(int(snapshot.get("projectile_count", 0)) == 2, "awakened bonus shuriken should release 200ms after the primary")
	_expect(int(snapshot.get("pending_count", -1)) == 0, "awakened pending reservation should be consumed exactly once")
	_expect(float(snapshot.get("cooldown_remaining_sec", 0.0)) < primary_cooldown, "primary cooldown should keep counting through the bonus shot")
	_expect(float(snapshot.get("cooldown_remaining_sec", 0.0)) > primary_cooldown - 0.25, "bonus shot must not reroll or reset the primary cooldown")


func _verify_shuriken_motion_is_fps_invariant() -> void:
	var endpoints: Array[Vector2] = []
	for fps in [30.0, 60.0, 120.0]:
		var state: Object = Stage7AkamuState.new()
		state.debug_spawn_shuriken(Vector2(50.0, 200.0), Vector2(700.0, 200.0))
		var context: Dictionary = _base_context()
		context["player_pos"] = Vector2(0.0, 690.0)
		var delta: float = 1.0 / fps
		for _frame in range(int(round(0.5 * fps))):
			state.update(delta, context)
		var shurikens: Array = state.get_actor_draw_context().get("stage7_akamu_shurikens", [])
		_expect(shurikens.size() == 1, "FPS motion leg should keep its horizontal shuriken in bounds")
		if not shurikens.is_empty():
			endpoints.append(_as_vector2((shurikens[0] as Dictionary).get("center", Vector2.ZERO)))
	_expect(endpoints.size() == 3, "all FPS motion legs should produce an endpoint")
	if endpoints.size() == 3:
		_expect(endpoints[0].distance_to(endpoints[1]) <= 0.01, "30 and 60 FPS shuriken endpoints should match")
		_expect(endpoints[1].distance_to(endpoints[2]) <= 0.01, "60 and 120 FPS shuriken endpoints should match")


func _verify_shuriken_swept_collision_at_supported_fps() -> void:
	for fps in [30.0, 60.0, 120.0]:
		var state: Object = Stage7AkamuState.new()
		var status_effect_state: Object = StatusEffectState.new()
		state.debug_spawn_shuriken(Vector2(380.0, 100.0), Vector2(380.0, 740.0))
		var context: Dictionary = _base_context()
		var hit := false
		var delta: float = 1.0 / fps
		for _frame in range(int(round(0.6 * fps))):
			var result: Dictionary = state.update(delta, context, {"status_effect_state": status_effect_state})
			if bool(result.get("stage7_akamu_shuriken_hit", false)):
				hit = true
				break
		_expect(hit, "shuriken should hit the player with swept collision at %d FPS" % int(fps))
		_expect((state.get_actor_draw_context().get("stage7_akamu_shurikens", []) as Array).is_empty(), "hit shuriken should be consumed at %d FPS" % int(fps))


func _verify_shuriken_hitch_frame_hits_before_offscreen_cull() -> void:
	var state: Object = Stage7AkamuState.new()
	var status_effect_state: Object = StatusEffectState.new()
	# At delta=0.1 the 20px/legacy-frame shot moves 120px: center 680→800.
	# Its endpoint is offscreen, but the swept segment crosses player y=690..740.
	state.debug_spawn_shuriken(Vector2(380.0, 680.0), Vector2(380.0, 740.0))
	var result: Dictionary = state.update(0.1, _base_context(), {
		"status_effect_state": status_effect_state,
	})
	_expect(bool(result.get("stage7_akamu_shuriken_hit", false)), "clamped hitch-frame swept hit should resolve before offscreen culling")
	_expect(bool(result.get("stage7_akamu_shuriken_slow_applied", false)), "hitch-frame shuriken hit should still apply the player debuff")
	var particles: Array = state.get_actor_draw_context().get("stage7_akamu_particles", [])
	_expect(not particles.is_empty(), "hitch-frame shuriken hit should create visible blood particles")
	if not particles.is_empty():
		var hit_particle_pos: Vector2 = _as_vector2((particles[0] as Dictionary).get("pos", Vector2.ZERO))
		_expect(hit_particle_pos.y <= 750.0, "hitch-frame blood should spawn at the swept collision point, not the offscreen endpoint")


func _verify_shuriken_hit_slow_immediate_speed_and_full_drain() -> void:
	var state: Object = Stage7AkamuState.new()
	var status_effect_state: Object = StatusEffectState.new()
	var context: Dictionary = _base_context()
	context["special_gauge"] = 100.0
	context["player_speed"] = 5.0
	state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var result: Dictionary = state.update(1.0 / 60.0, context, {"status_effect_state": status_effect_state})
	_expect(bool(result.get("stage7_akamu_shuriken_slow_applied", false)), "nonimmune shuriken hit should apply its slow")
	_expect_close(float(result.get("player_speed", 99.0)), 1.0, "shuriken hit should immediately multiply current speed by 0.2")
	var slow: Dictionary = status_effect_state.get_status_source("player", "slow", "stage7_akamu_shuriken")
	_expect_close(float(slow.get("multiplier", 1.0)), 0.2, "shuriken slow should use the shared 0.2 multiplier")
	_expect_close(float(slow.get("remaining_frames", 0.0)), 120.0, "shuriken slow should last 120 legacy frames")

	for _frame in range(119):
		result = state.update(1.0 / 60.0, context, {"status_effect_state": status_effect_state})
		if result.has("special_gauge"):
			context["special_gauge"] = float(result["special_gauge"])
	_expect_close(float(context.get("special_gauge", 0.0)), 40.0, "four 15-gauge ticks should drain a total of 60")
	_expect(int(state.debug_get_shuriken_snapshot().get("gauge_ticks_left", -1)) == 0, "all four shuriken gauge ticks should be consumed after two seconds")


func _verify_cleanse_blocks_slow_and_drain_but_keeps_hit_particles() -> void:
	var state: Object = Stage7AkamuState.new()
	var status_effect_state: Object = StatusEffectState.new()
	var cleanse_state := FakeCleanseState.new()
	cleanse_state.immune = true
	state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var result: Dictionary = state.update(1.0 / 60.0, _base_context(), {
		"status_effect_state": status_effect_state,
		"smasher_cleanse_state": cleanse_state,
	})
	_expect(bool(result.get("stage7_akamu_shuriken_cleansed", false)), "cleanse immunity should mark the whole shuriken debuff as blocked")
	_expect(not result.has("player_speed"), "cleanse immunity should block immediate movement slowdown")
	_expect(status_effect_state.get_status("player", "slow").is_empty(), "cleanse immunity should block shared slow application")
	_expect(int(state.debug_get_shuriken_snapshot().get("gauge_ticks_left", -1)) == 0, "cleanse immunity should block the new gauge-drain schedule")
	_expect(not (state.get_actor_draw_context().get("stage7_akamu_particles", []) as Array).is_empty(), "cleanse-immune hit should retain blood impact particles like the source")


func _verify_smoke_silently_absorbs_shuriken() -> void:
	var state: Object = Stage7AkamuState.new()
	var status_effect_state: Object = StatusEffectState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	active_item_runtime.tear_gas_zones = [{
		"position": Vector2(380.0, 715.0),
		"radius": 80.0,
		"radius_x": 180.0,
		"opacity": 0.8,
	}]
	state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var result: Dictionary = state.update(1.0 / 60.0, _base_context(), {
		"status_effect_state": status_effect_state,
		"active_item_runtime": active_item_runtime,
	})
	_expect(bool(result.get("stage7_akamu_shuriken_smoke_absorbed", false)), "tear-gas zone should absorb a shuriken at the player center")
	_expect(not bool(result.get("stage7_akamu_shuriken_hit", false)), "smoke absorption should not report a player hit")
	_expect(status_effect_state.get_status("player", "slow").is_empty(), "smoke absorption should not apply slow")
	_expect((state.get_actor_draw_context().get("stage7_akamu_particles", []) as Array).is_empty(), "smoke absorption should not create blood impact particles")


func _verify_boss_skill_pause_freezes_scheduler_but_not_inflight_projectiles() -> void:
	var state: Object = Stage7AkamuState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	active_item_runtime.paused = true
	state.debug_set_gauge(100.0)
	state.debug_set_shuriken_cooldown_remaining(1.0, 8.0)
	state.debug_spawn_shuriken(Vector2(50.0, 200.0), Vector2(700.0, 200.0))
	state.set("_shuriken_pending_remaining", [0.05])
	var context: Dictionary = _base_context()
	state.update(0.1, context, {"active_item_runtime": active_item_runtime})
	var snapshot: Dictionary = state.debug_get_shuriken_snapshot()
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), 1.0, "tear-gas pause should freeze the shuriken scheduler cooldown")
	_expect(int(snapshot.get("pending_count", 0)) == 1, "tear-gas pause should freeze an awakened pending shot before it can fire")
	_expect(int(snapshot.get("projectile_count", 0)) == 1, "tear-gas pause should not spawn a new pending shuriken")
	var shuriken: Dictionary = (state.get_actor_draw_context().get("stage7_akamu_shurikens", []) as Array)[0]
	_expect(_as_vector2(shuriken.get("center", Vector2.ZERO)).x > 50.0, "already-fired shuriken should keep moving during boss-skill cooldown pause")
	_expect(state.get_status() == "paused", "Stage 7 should expose paused status while boss skill cooldowns are frozen")

	active_item_runtime.paused = false
	state.update(0.1, context, {"active_item_runtime": active_item_runtime})
	snapshot = state.debug_get_shuriken_snapshot()
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), 0.9, "shuriken scheduler should resume after pause clears")
	_expect(int(snapshot.get("pending_count", -1)) == 0, "awakened pending shot should resume and fire after pause clears")
	_expect(int(snapshot.get("projectile_count", 0)) == 2, "resumed awakened pending shot should join the existing in-flight shuriken")


func _verify_round_cleanup_clears_all_shuriken_transients() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(100.0)
	state.debug_set_awakened(true)
	state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	var context: Dictionary = _base_context()
	state.update(1.0 / 60.0, context)
	state.set("_shuriken_pending_remaining", [0.2])
	state.set("_shuriken_gauge_ticks_left", 4)
	state.set("_shuriken_gauge_tick_frames_remaining", 30.0)
	state.debug_spawn_shuriken(Vector2(100.0, 100.0), Vector2(200.0, 200.0))
	state.clear_round_transients()
	var snapshot: Dictionary = state.debug_get_shuriken_snapshot()
	_expect(not bool(snapshot.get("casting", true)), "round cleanup should cancel shuriken casting")
	_expect(int(snapshot.get("pending_count", -1)) == 0, "round cleanup should clear awakened pending shots")
	_expect(int(snapshot.get("projectile_count", -1)) == 0, "round cleanup should clear in-flight shurikens")
	_expect(int(snapshot.get("gauge_ticks_left", -1)) == 0, "round cleanup should clear shuriken gauge drain")
	_expect(not bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", true)), "round cleanup should release the shuriken boss hold")
	_expect_close(state.debug_get_gauge(), 70.0, "transient cleanup should preserve the post-cast boss gauge")
	_expect(state.debug_is_awakened(), "transient cleanup should preserve awakening")


func _verify_effects_result_propagates_speed_and_gauge() -> void:
	var controller: Object = BattleEffectsUpdateController.new()
	var state: Object = Stage7AkamuState.new()
	var status_effect_state: Object = StatusEffectState.new()
	state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var context: Dictionary = _base_context()
	context["special_gauge"] = 100.0
	context["player_speed"] = 5.0
	var result: Dictionary = controller.update(1.0 / 60.0, context, {
		"stage7_akamu_state": state,
		"status_effect_state": status_effect_state,
	})
	_expect_close(float(result.get("player_speed", 99.0)), 1.0, "effects controller should preserve Stage 7 immediate speed result")
	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect_close(owner.player_speed, 1.0, "effects result applier should write Stage 7 immediate slow speed to the owner")
	state.set("_shuriken_gauge_tick_frames_remaining", 1.0)
	context["player_speed"] = float(result.get("player_speed", 5.0))
	result = controller.update(1.0 / 60.0, context, {
		"stage7_akamu_state": state,
		"status_effect_state": status_effect_state,
	})
	_expect_close(float(result.get("special_gauge", 99.0)), 85.0, "effects controller should preserve Stage 7 gauge-drain result")

	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect_close(owner.special_gauge, 85.0, "effects result applier should write Stage 7 gauge drain to the owner")
	_expect_close(owner.player_speed, 1.0, "later gauge-only results should preserve the already-applied slow speed")


func _verify_ball_snapshot_carries_star_coil_pause() -> void:
	var snapshot: Dictionary = BallUpdateOwnerSnapshot.new().build(FakeOwner.new())
	_expect(bool(snapshot.get("lingpet_star_coil_freeze_boss_skill_cd", false)), "ball update snapshot should carry Star Coil boss-skill pause into the Stage 7 hit hook")


func _verify_external_boss_gauge_drain_routes_to_stage7() -> void:
	var stage7_state: Object = Stage7AkamuState.new()
	stage7_state.debug_set_gauge(100.0)
	var venom_runtime := FakeVenomRuntime.new()
	venom_runtime.stage7_state = stage7_state
	var venom: Object = MythicItemVenomMistRuntime.new()
	_expect(bool(venom.drain_boss_special_gauge(venom_runtime, null, 10.0, 7)), "Venom Mist should resolve the Stage 7 gauge owner")
	_expect_close(stage7_state.debug_get_gauge(), 90.0, "Venom Mist should drain the Stage 7 boss gauge")

	var plasma: Object = SmasherPlasmaState.new()
	_expect(bool(plasma._drain_boss_special_gauge(20.0, 7, {"stage7_akamu_state": stage7_state})), "Plasma should resolve the Stage 7 gauge owner")
	_expect_close(stage7_state.debug_get_gauge(), 70.0, "Plasma should drain the Stage 7 boss gauge instead of a stale earlier stage")


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_speed": 5.0,
		"special_gauge": 100.0,
		"gauge_max": 500.0,
		"dash_snapshot": {},
	}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
