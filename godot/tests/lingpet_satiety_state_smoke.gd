extends SceneTree

const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func queue_redraw() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_active_drain_and_rest_recovery()
	await _verify_skipped_update_freezes_satiety()
	_verify_save_restore_roundtrip()
	_verify_schema_gated_owner_mirror()
	_verify_satiety_slow_curve_and_junior_exemption()
	_verify_flight_velocity_uses_satiety_scale()
	_verify_telegraphed_exhaustion_suppresses_and_recovers()
	_verify_d12_wake_threshold_and_active_rest_recovery()
	_verify_hidden_sortie_exhaustion_parks_visibly()
	_verify_satiety_exhaustion_renderer_contract()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("lingpet_satiety_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_drain_and_rest_recovery() -> void:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 100.0)
	runtime.set_satiety_for_tests("lunabi", 50.0)
	runtime.update(12.0, owner, registry)
	_expect_float(runtime.get_satiety("maribo"), 97.0, "active companion should drain satiety by 0.25/sec")
	_expect_float(runtime.get_satiety("lunabi"), 51.0, "inactive battle-slot lingpet should recover at one-third drain")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect_eq(int(snapshot.get("satiety_pct", -1)), 97, "runtime snapshot should expose quantized active satiety")
	_cleanup_runtime(runtime)


func _verify_skipped_update_freezes_satiety() -> void:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "pause fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 80.0)
	await process_frame
	await process_frame
	_expect_float(runtime.get_satiety("maribo"), 80.0, "satiety must not use wall-clock time while update_lingpet is skipped")
	runtime.update(1.0, owner, registry)
	_expect_float(runtime.get_satiety("maribo"), 79.75, "satiety should resume from the delta-driven update tick")
	_cleanup_runtime(runtime)


func _verify_save_restore_roundtrip() -> void:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "save fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 73.0)
	runtime.set_satiety_for_tests("lunabi", 42.0)
	var snapshot: Dictionary = runtime.get_save_snapshot()
	var run_state: Dictionary = snapshot.get("affinity_run_state", {}) as Dictionary
	_expect(not run_state.is_empty(), "save snapshot should carry the run-state envelope")
	var pets: Dictionary = run_state.get("pets", {}) as Dictionary
	_expect(is_equal_approx(float((pets.get("maribo", {}) as Dictionary).get("satiety", -1.0)), 73.0), "save snapshot should carry Maribo satiety")
	_expect(is_equal_approx(float((pets.get("lunabi", {}) as Dictionary).get("satiety", -1.0)), 42.0), "save snapshot should carry inactive slot satiety")

	var restore_owner := _make_owner()
	var restored: Object = LingpetEggRuntime.new()
	restored.apply_save_snapshot(snapshot, restore_owner, Smoke.FakeRegistry.new())
	_expect_float(restored.get_satiety("maribo"), 73.0, "restore should preserve active pet satiety")
	_expect_float(restored.get_satiety("lunabi"), 42.0, "restore should preserve inactive slot satiety")

	var stripped_snapshot := snapshot.duplicate(true)
	stripped_snapshot.erase("affinity_run_state")
	var stripped: Object = LingpetEggRuntime.new()
	stripped.apply_save_snapshot(stripped_snapshot, _make_owner(), Smoke.FakeRegistry.new())
	_expect_float(stripped.get_satiety("maribo"), LingpetAffinityState.SATIETY_MAX, "stripped run-state must not restore satiety")
	_cleanup_runtime(runtime)
	_cleanup_runtime(restored)
	_cleanup_runtime(stripped)


func _verify_schema_gated_owner_mirror() -> void:
	for key in ["lingpet_satiety_pct", "ringpet_satiety_pct"]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s for satiety owner sync" % key)
	var owner := _make_schema_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "schema fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 76.6)
	runtime.update(0.0, owner, registry)
	_expect_eq(_owner_int(owner, "lingpet_satiety_pct"), 77, "schema-gated owner should receive divergent lingpet satiety")
	_expect_eq(_owner_int(owner, "ringpet_satiety_pct"), 77, "schema-gated owner should receive divergent ringpet satiety")
	_cleanup_runtime(runtime)


func _verify_satiety_slow_curve_and_junior_exemption() -> void:
	_expect_float(LingpetAffinityState.get_satiety_speed_multiplier_for_value(100.0), 1.0, "satiety above 50 should not slow the companion")
	_expect_float(LingpetAffinityState.get_satiety_speed_multiplier_for_value(30.0), 0.8, "satiety 30 should linearly slow to 80 percent")
	_expect_float(LingpetAffinityState.get_satiety_speed_multiplier_for_value(5.0), 0.6, "satiety below 10 should use the 60 percent floor")

	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "slow-curve fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 30.0)
	runtime.update(0.0, owner, registry)
	_expect_float(runtime.get_satiety_speed_scale_for_tests(owner), 0.8, "runtime should expose the active satiety speed scale")

	var junior_owner := _make_owner()
	junior_owner.ai_mode = "junior"
	var junior_runtime: Object = LingpetEggRuntime.new()
	_expect(junior_runtime.debug_grant_and_activate_pet("maribo", junior_owner, false, "", "", Smoke.FakeRegistry.new()), "junior fixture should activate Maribo")
	junior_runtime.set_satiety_for_tests("maribo", 0.0)
	junior_runtime.update(3.0, junior_owner)
	_expect(not junior_runtime.is_companion_exhausted_for_tests(junior_owner), "junior league should observe drain but remain exempt from exhaustion penalties")
	_expect_float(junior_runtime.get_satiety_speed_scale_for_tests(junior_owner), 1.0, "junior league should remain exempt from satiety slow penalties")
	_cleanup_runtime(runtime)
	_cleanup_runtime(junior_runtime)


func _verify_flight_velocity_uses_satiety_scale() -> void:
	var owner := _make_owner()
	var normal_motion := LingpetCompanionMotionState.new()
	normal_motion.configure_sortie_hidden_for_tests(Vector2(360.0, 220.0), 771, 0.0)
	normal_motion.update(
		0.05,
		owner,
		false,
		0.0,
		1,
		285.0,
		210.0,
		390.0,
		LingpetCompanionMotionState.MOTION_STYLE_SORTIE_FLIGHT,
		0.0,
		1.0
	)
	var normal_speed := normal_motion.motion_velocity.length()

	var slowed_motion := LingpetCompanionMotionState.new()
	slowed_motion.configure_sortie_hidden_for_tests(Vector2(360.0, 220.0), 771, 0.0)
	slowed_motion.update(
		0.05,
		owner,
		false,
		0.0,
		1,
		285.0,
		210.0,
		390.0,
		LingpetCompanionMotionState.MOTION_STYLE_SORTIE_FLIGHT,
		0.0,
		0.6
	)
	var slowed_speed := slowed_motion.motion_velocity.length()
	_expect(normal_speed > 0.0, "sortie flight fixture should produce a visible velocity")
	_expect_float(slowed_speed / normal_speed, 0.6, "sortie/free-flight satiety scale should apply to velocity, not hidden appearance timing", 0.02)


func _verify_telegraphed_exhaustion_suppresses_and_recovers() -> void:
	var owner := _make_owner()
	owner.player_paddle_height = 91.0
	owner.player_paddle_width = 150.0
	owner.player_pos = Vector2(90.0, owner.player_pos.y)
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "", registry), "exhaustion fixture should activate Maribo with a skill")
	var lane_y: float = float(owner.lingpet_companion_pos.y)

	runtime.set_satiety_for_tests("maribo", 1.0)
	runtime.configure_companion_motion_for_tests(Vector2(650.0, lane_y), 2, 0.0, false)
	_hit_companion(runtime, owner, registry, Vector2(650.0, lane_y))
	_expect(int(owner.lingpet_companion_contact_count) == 1, "pre-exhausted companion should still bounce the ball")

	runtime.reset_round({"owner": owner, "registry": registry})
	runtime.set_satiety_for_tests("maribo", 0.0)
	runtime.update(1.0, owner, registry)
	_expect(not runtime.is_companion_exhausted_for_tests(owner), "satiety zero should telegraph before KO instead of suppressing immediately")
	_expect_float(runtime.get_satiety_exhaustion_ratio_for_tests(owner), 1.0 / LingpetEggRuntime.SATIETY_EXHAUSTION_TELEGRAPH_SECONDS, "telegraph ratio should advance from update delta", 0.02)
	runtime.update(1.0, owner, registry)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "satiety zero should become exhausted after the telegraph window")
	var exhausted_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(exhausted_snapshot.get("companion_exhausted", false)), "runtime snapshot should expose exhausted state")
	_expect_float(float(exhausted_snapshot.get("satiety_speed_scale", -1.0)), 0.0, "exhausted companion should publish zero speed scale")

	runtime.configure_companion_motion_for_tests(Vector2(570.0, lane_y), 2, 0.0, false)
	owner.ball_active = true
	owner.ball_pos = Vector2(650.0, lane_y - 300.0)
	owner.ball_vel = Vector2(0.0, 12.0)
	runtime.set_debug_defense_rate_override(1.0)
	runtime.update(0.05, owner, registry)
	_expect(not bool(owner.lingpet_companion_defense_intercept_active), "exhausted companion should not arm defense intercept")
	_expect(not runtime.is_companion_striking_for_tests(), "exhausted companion should not arm anticipatory strike")
	_expect(not bool(runtime.get_snapshot().get("companion_skill_winding_up", false)), "exhausted companion should not arm active skills")

	var contact_before_ko_hit := int(owner.lingpet_companion_contact_count)
	owner.ball_active = true
	owner.ball_pos = owner.lingpet_companion_pos + Vector2(0.0, -6.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.05, owner, registry)
	_expect(int(owner.lingpet_companion_contact_count) == contact_before_ko_hit, "exhausted companion body hit should be suppressed")
	_expect(float(owner.ball_vel.y) > 0.0, "suppressed exhausted hit should leave the ball descending")

	var affinity_before_click: float = runtime.get_affinity_points("maribo")
	_expect(bool(runtime.try_begin_companion_click_reaction(owner.lingpet_companion_pos, registry)), "exhausted companion tap may still consume the click reaction")
	_expect_float(runtime.get_affinity_points("maribo"), affinity_before_click, "exhausted companion click should not grant affinity")

	owner.ball_active = false
	runtime.set_satiety_for_tests("maribo", 5.0)
	runtime.update(0.0, owner, registry)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "satiety below the wake threshold should not clear KO")
	runtime.set_satiety_for_tests("maribo", LingpetAffinityState.SATIETY_WAKE_THRESHOLD)
	runtime.update(0.0, owner, registry)
	_expect(not runtime.is_companion_exhausted_for_tests(owner), "satiety at the wake threshold should clear exhaustion")
	runtime.reset_round({"owner": owner, "registry": registry})
	runtime.configure_companion_motion_for_tests(Vector2(650.0, lane_y), 2, 0.0, false)
	var contact_before_recovery := int(owner.lingpet_companion_contact_count)
	_hit_companion(runtime, owner, registry, Vector2(650.0, lane_y))
	_expect(int(owner.lingpet_companion_contact_count) == contact_before_recovery + 1, "recovered companion should resume ball-hit participation")
	_cleanup_runtime(runtime)


func _verify_d12_wake_threshold_and_active_rest_recovery() -> void:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "", registry), "D12 fixture should activate Maribo")
	runtime.set_satiety_for_tests("maribo", 0.0)
	runtime.update(2.0, owner, registry)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "D12 fixture should reach KO before recovery checks")
	runtime.update(125.0, owner, registry)
	_expect_float(runtime.get_satiety("maribo"), 10.416, "active KO companion should recover at rest speed", 0.02)
	_expect(not runtime.is_companion_exhausted_for_tests(owner), "active KO companion should auto-wake once satiety reaches 10")
	_cleanup_runtime(runtime)

	var ping_owner := _make_owner()
	var ping_registry = Smoke.FakeRegistry.new()
	var ping_runtime: Object = LingpetEggRuntime.new()
	_expect(ping_runtime.debug_grant_and_activate_pet("maribo", ping_owner, false, "maribo_hydro_sphere", "", ping_registry), "pingpong fixture should activate Maribo")
	ping_runtime.set_satiety_for_tests("maribo", 0.0)
	ping_runtime.update(2.0, ping_owner, ping_registry)
	_expect(ping_runtime.is_companion_exhausted_for_tests(ping_owner), "pingpong fixture should start from KO")
	_expect(bool(ping_runtime.switch_lingpet_slot(1, ping_owner, ping_registry)), "pingpong fixture should switch to the bench pet")
	ping_runtime.update(1.0, ping_owner, ping_registry)
	_expect(bool(ping_runtime.switch_lingpet_slot(0, ping_owner, ping_registry)), "pingpong fixture should switch back to the KO pet")
	ping_runtime.update(0.0, ping_owner, ping_registry)
	_expect(ping_runtime.get_satiety("maribo") > 0.0 and ping_runtime.get_satiety("maribo") < LingpetAffinityState.SATIETY_WAKE_THRESHOLD, "bench pingpong should only recover a small satiety amount")
	_expect(ping_runtime.is_companion_exhausted_for_tests(ping_owner), "bench one-tick pingpong should not clear KO before satiety 10")
	_cleanup_runtime(ping_runtime)


func _verify_hidden_sortie_exhaustion_parks_visibly() -> void:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(runtime.debug_grant_and_activate_pet("lunabi", owner, false, "lunabi_headbutt", "", registry), "sortie KO fixture should activate Lunabi")
	runtime.configure_companion_sortie_hidden_for_tests(Vector2(-190.0, 220.0), 771, 30.0)
	runtime.set_satiety_for_tests("lunabi", 0.0)
	runtime.update(2.0, owner, registry)
	var snapshot: Dictionary = runtime.get_snapshot()
	var parked_pos: Vector2 = snapshot.get("companion_pos", Vector2.ZERO)
	_expect(runtime.is_companion_exhausted_for_tests(owner), "hidden sortie fixture should reach KO")
	_expect(bool(snapshot.get("companion_visible", false)), "hidden sortie KO should become visible instead of staying offscreen")
	_expect(str(snapshot.get("companion_sortie_phase", "")) == LingpetCompanionMotionState.SORTIE_PHASE_EXHAUSTED_PARK, "hidden sortie KO should enter the exhausted park phase")
	_expect(parked_pos.x >= 0.0 and parked_pos.x <= LingpetCompanionMotionState.FIELD_WIDTH, "hidden sortie KO park x should be inside the playfield")
	_expect(parked_pos.y >= 0.0 and parked_pos.y <= LingpetCompanionMotionState.FIELD_HEIGHT, "hidden sortie KO park y should be inside the playfield")
	_expect_float(float(snapshot.get("satiety_speed_scale", -1.0)), 0.0, "parked KO flight pet should still publish zero satiety speed scale")
	_cleanup_runtime(runtime)


func _verify_satiety_exhaustion_renderer_contract() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	var draw_context_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	_expect(draw_context_source.find("\"companion_exhausted\"") >= 0, "draw context should pass exhausted state to the companion renderer")
	_expect(draw_context_source.find("\"satiety_exhaustion_ratio\"") >= 0, "draw context should pass telegraph ratio to the companion renderer")
	_expect(renderer_source.find("_draw_satiety_exhaustion_telegraph") >= 0, "renderer should consume the telegraph ratio for visible warning feedback")
	_expect(renderer_source.find("_draw_exhausted_sleep_marker") >= 0, "renderer should consume exhausted state for visible sleep feedback")
	_expect(renderer_source.find("dest_rect.size.y *= 0.76") >= 0, "renderer should visibly lower/squash exhausted companion posture")


func _make_owner() -> Object:
	var owner = Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo", "lunabi"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.lingpet_slots = ["maribo", "lunabi", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _make_schema_owner() -> Object:
	var owner := SchemaGatedOwner.new()
	owner.set("ai_mode", "champion")
	owner.set("lingpet_owned_pet_ids", ["maribo", "lunabi"])
	owner.set("owned_lingpet_ids", ["maribo", "lunabi"])
	owner.set("owned_ringpet_ids", ["maribo", "lunabi"])
	owner.set("lingpet_slots", ["maribo", "lunabi", ""])
	owner.set("ringpet_slots", ["maribo", "lunabi", ""])
	owner.set("lingpet_slot_pet_ids", ["maribo", "lunabi", ""])
	owner.set("ringpet_slot_pet_ids", ["maribo", "lunabi", ""])
	owner.set("lingpet_active_slot_index", 0)
	owner.set("ringpet_active_slot_index", 0)
	return owner


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _hit_companion(runtime: Object, owner: Object, registry: Object, companion_pos: Vector2) -> void:
	owner.ball_active = true
	owner.ball_pos = companion_pos + Vector2(0.0, -6.0)
	owner.ball_pos_prev = owner.ball_pos - Vector2(0.0, 14.0 * 0.05 * 60.0)
	owner.ball_vel = Vector2(0.0, 14.0)
	runtime.update(0.05, owner, registry)


func _owner_int(owner: Object, key: String) -> int:
	var value: Variant = owner.get(key)
	if value == null:
		return -9999
	return int(value)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
