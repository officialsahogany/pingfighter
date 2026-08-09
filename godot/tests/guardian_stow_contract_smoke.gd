extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var stop_calls: Array[String] = []

	func stop_lingpet_gatling_loop() -> void:
		stop_calls.append("gatling")

	func stop_lingpet_star_coil_bind() -> void:
		stop_calls.append("star_coil_bind")

	func stop_lingpet_star_coil_move() -> void:
		stop_calls.append("star_coil_move")


func _init() -> void:
	_verify_stow_freezes_progress_and_ends_residuals()
	_verify_duration_expiry_keeps_nekuring_deployments()
	_verify_fold_ownership_surface()

	if _failures.is_empty():
		print("guardian_stow_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_stow_freezes_progress_and_ends_residuals() -> void:
	var owner := _make_runtime_owner()
	var audio := FakeAudio.new()
	var registry := Smoke.FakeRegistry.new({"game_audio": audio})
	var runtime: Object = LingpetEggRuntime.new()
	registry.instances["lingpet_egg_runtime"] = runtime
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture should activate a guardian")
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	runtime.update(6.1, owner, registry)

	var skill_states: Array = runtime.get("_companion_skill_states") as Array
	var primary_state: Object = skill_states[0] as Object
	primary_state.cooldown = 10.0
	primary_state.last_gain = 3.0
	var persistence: Object = runtime.get("_companion_skill_persistence") as Object
	persistence.shared_cooldown = 9.0
	var body_hit: Object = runtime.get("_companion_body_hit_state") as Object
	body_hit.cooldown = 1.25
	body_hit.gauge_last_gain = 4.0
	body_hit.ball_was_inside = true
	var motion: Object = runtime.get("_companion_motion_state") as Object
	motion.configure_for_tests(Vector2(380.0, 680.0), 771, 0.77, true)
	motion.defense_last_roll = 0.23

	var ring_dash: Object = runtime.get("_ring_dash_state") as Object
	ring_dash.set("_active", true)
	ring_dash.set("_cooldown", 4.0)
	ring_dash.set("_rolled_this_descent", true)
	var afterglow: Object = runtime.get("_afterglow_leak_state") as Object
	var residues: Array = afterglow.get("_residues") as Array
	residues.append({"timer": 2.0, "remaining_gauge": 1.0})

	var host: Object = runtime.get("_skill_runtime_host") as Object
	_expect(host.launch("nekuring_skeleton_archer", Vector2(380.0, 680.0), owner, {"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 99.0}), "fixture should launch a persistent archer")
	host.update(1.21, owner, registry, "nekuring_skeleton_archer", {})
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "counterproof fixture should contain one launched residual")
	_expect(host.launch("volty_gatling_burst", Vector2(380.0, 680.0), owner, {"registry": registry}), "fixture should create Gatling runtime")
	var gatling: Object = host.get("_gatling_burst_skill") as Object
	gatling.set("_loop_playing", true)
	gatling.set("_registry", registry)
	_expect(host.launch("orosha_star_coil", Vector2(380.0, 680.0), owner, {"registry": registry}), "fixture should create Star Coil runtime")
	var star_coil: Object = host.get("_star_coil_skill") as Object
	star_coil.set("_move_audio_active", true)
	owner.lingpet_star_coil_boss_slow_active = true
	owner.lingpet_star_coil_block_boss_dash = true
	owner.lingpet_star_coil_freeze_boss_skill_cd = true

	_expect(runtime.try_toggle_guardian_stow(owner, registry), "stow toggle should be consumed")
	_expect(runtime.is_guardian_stowed(), "guardian should enter stow after minimum hold")
	_expect(not runtime.is_companion_active(), "stow must fold companion_active false")
	var stowed_snapshot: Dictionary = runtime.get_snapshot()
	_expect(str(stowed_snapshot.get("state", "")) == "companion", "stowed snapshot should preserve roster state for the duration HUD")
	_expect(str(stowed_snapshot.get("pet_id", "")) == "maribo", "stowed snapshot should preserve the roster pet id for the duration HUD")
	_expect(not bool(stowed_snapshot.get("companion_active", true)), "stowed runtime snapshot must publish companion_active false")
	_expect(str(stowed_snapshot.get("active_pet_id", "")) == "", "stowed runtime snapshot must suppress the active pet id")
	_expect(str(stowed_snapshot.get("companion_skill_id", "")) == "", "stowed runtime snapshot must suppress active skill ownership")
	_expect(str(stowed_snapshot.get("companion_passive_skill_id", "")) == "", "stowed runtime snapshot must suppress passive ownership")
	_expect(str(owner.lingpet_state) == "none" and str(owner.ringpet_state) == "none", "stowed owner state must publish no active companion")
	_expect(str(owner.active_lingpet_id) == "", "stowed owner must clear the active lingpet id")
	_expect(str(owner.lingpet_active_skill_id) == "" and str(owner.lingpet_passive_skill_id) == "", "stowed owner must suppress skill and passive ownership")
	_expect(LingpetRailCard.build_entries(registry).is_empty(), "stowed guardian rail cards must be suppressed")
	_expect(not bool(motion.defense_intercept_active), "stow should terminate an active defense intercept")
	_expect(is_equal_approx(float(motion.defense_decision_timer), 0.77), "stow must preserve the defense decision lock timer")
	_expect(is_equal_approx(float(motion.defense_last_roll), 0.23), "stow must preserve the defense opportunity roll")
	_expect(not bool(ring_dash.get("_active")), "stow should terminate an active Linkport residual")
	_expect(is_equal_approx(float(ring_dash.get("_cooldown")), 4.0), "stow must preserve Linkport cooldown")
	_expect(bool(ring_dash.get("_rolled_this_descent")), "stow must preserve Linkport per-descent roll lock")
	_expect(not afterglow.has_visible_effects(), "stow should clear passive afterglow residues")
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 0, "stow should clear launched active-skill entity arrays")
	_expect(not host.has_visible_effects(), "stow should leave no active-skill VFX")
	_expect(audio.stop_calls.has("gatling"), "stow should explicitly stop active Gatling loop audio")
	_expect(audio.stop_calls.has("star_coil_move"), "stow should explicitly stop active Star Coil loop audio")
	_expect(not owner.lingpet_star_coil_boss_slow_active, "stow should restore boss slow CC")
	_expect(not owner.lingpet_star_coil_block_boss_dash, "stow should restore boss dash permission")
	_expect(not owner.lingpet_star_coil_freeze_boss_skill_cd, "stow should restore boss skill cooldown flow")

	var tracked_drop := {
		"lingpet_starlight_tracking_active": true,
		"lingpet_starlight_tracking_carrying": true,
		"lingpet_starlight_tracking_hold_remaining": 0.5,
	}
	runtime.update_starlight_tracking_for_starpoint_drop(tracked_drop, 0.1, {"owner": owner})
	_expect(not bool(tracked_drop.get("lingpet_starlight_tracking_active", true)), "stow should release a materialized starlight drop claim")
	_expect(not bool(tracked_drop.get("lingpet_starlight_tracking_carrying", true)), "stow should release a carried starlight drop")

	runtime.update(2.0, owner, registry)
	_expect(is_equal_approx(float(primary_state.cooldown), 10.0), "personal skill cooldown must freeze while stowed")
	_expect(is_equal_approx(float(persistence.shared_cooldown), 9.0), "shared skill cooldown must freeze while stowed")
	_expect(is_equal_approx(float(body_hit.cooldown), 1.25), "body-hit gauge cooldown must freeze while stowed")
	_expect(is_equal_approx(float(body_hit.gauge_last_gain), 4.0), "stored gauge gain must survive stow")
	_expect(not bool(body_hit.ball_was_inside), "stow must clear the live body-hit overlap latch")
	_expect(is_equal_approx(float(motion.defense_decision_timer), 0.77), "stowed updates must not consume the preserved defense lock")
	_expect(is_equal_approx(float(ring_dash.get("_cooldown")), 4.0), "stowed updates must not consume passive cooldown")

	_expect(runtime.try_toggle_guardian_stow(owner, registry), "healthy pool should resummon guardian")
	_expect(not runtime.is_companion_active(), "resummon presentation should keep combat availability disabled")
	_expect(is_equal_approx(float(motion.defense_decision_timer), 0.77), "resummon edge must not reroll or reset defense lock")
	runtime.update(0.53, owner, registry)
	_expect(runtime.is_companion_active(), "resummon completion should restore companion_active")
	runtime.update(1.0, owner, registry)
	_expect(float(primary_state.cooldown) < 10.0, "personal cooldown should resume only after resummon")
	_expect(float(persistence.shared_cooldown) < 9.0, "shared cooldown should resume only after resummon")
	_cleanup_runtime(runtime)
	registry.instances.clear()


func _verify_duration_expiry_keeps_nekuring_deployments() -> void:
	var owner := _make_nekuring_runtime_owner()
	var registry := Smoke.FakeRegistry.new({})
	var runtime: Object = LingpetEggRuntime.new()
	registry.instances["lingpet_egg_runtime"] = runtime
	_expect(runtime.debug_grant_and_activate_pet("nekuring", owner, false, "", "", registry), "fixture should activate Nekuring")
	runtime.set_duration_pool_for_tests(0.05, 60.0)
	var host: Object = runtime.get("_skill_runtime_host") as Object
	_expect(host.launch("nekuring_skeleton_archer", Vector2(380.0, 680.0), owner, {
		"registry": registry,
		"spawn_x": 380.0,
		"spawn_y": 650.0,
		"arrow_cooldown": 0.0,
	}), "fixture should launch a duration-expiry archer")
	_expect(host.launch("nekuring_bone_barrier", Vector2(380.0, 680.0), owner, {
		"registry": registry,
		"barrier_x": 320.0,
	}), "fixture should launch a duration-expiry bone barrier")
	host.update(1.21, owner, registry, "nekuring_skeleton_archer", {})
	var archer_before: Vector2 = (host.get_skeleton_archer_snapshot_for_tests().get("skeleton_archer_archer_positions", []) as Array)[0]

	runtime.update(0.1, owner, registry)
	_expect(runtime.is_guardian_stowed(), "duration exhaustion should remove Nekuring from the field")
	_expect(host.get_skeleton_archer_archer_count_for_tests() == 1, "duration exhaustion must preserve Nekuring's summoned archer")
	_expect(host.get_bone_barrier_barrier_count_for_tests() == 1, "duration exhaustion must preserve Nekuring's installed bone barrier")
	_expect(host.has_persistent_deployments(), "preserved Nekuring deployments should remain live after duration exhaustion")

	runtime.update(3.1, owner, registry)
	var archer_snapshot: Dictionary = host.get_skeleton_archer_snapshot_for_tests()
	var archer_after: Vector2 = (archer_snapshot.get("skeleton_archer_archer_positions", []) as Array)[0]
	_expect(not archer_after.is_equal_approx(archer_before), "a preserved archer should keep patrolling after Nekuring disappears")
	_expect(int(archer_snapshot.get("skeleton_archer_arrow_fire_count", 0)) > 0, "a preserved archer should keep firing after Nekuring disappears")
	var barrier_snapshot: Dictionary = host.get_bone_barrier_snapshot_for_tests()
	_expect(int(barrier_snapshot.get("bone_barrier_built_count", 0)) == 1, "a preserved bone barrier should finish building after Nekuring disappears")
	var collision_context: Dictionary = runtime.get_ball_collision_context()
	_expect(bool(collision_context.get("lingpet_bone_barrier_active", false)), "a preserved bone barrier should remain in the production ball-collision context")
	var barriers: Array = collision_context.get("lingpet_bone_barrier_barriers", []) as Array
	_expect(barriers.size() == 1, "post-expiry collision context should expose the preserved bone barrier")
	if not barriers.is_empty():
		var barrier: Dictionary = barriers[0] as Dictionary
		_expect(runtime.notify_lingpet_bone_barrier_hit(int(barrier.get("id", 0)), Vector2(380.0, 738.0), Vector2(0.0, -600.0), true, registry), "the preserved bone barrier should still accept a production collision notification")
		_expect(host.get_bone_barrier_barrier_count_for_tests() == 0, "a preserved bone barrier should disappear normally when consumed")
	_cleanup_runtime(runtime)
	registry.instances.clear()


func _verify_fold_ownership_surface() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(source.find("if guardian_summoned:\n\t\t\t_resolve_companion_ball_hit") >= 0, "body-hit callsite should use the summoned fold")
	_expect(source.find("_afterglow_leak_state.advance") >= 0 and source.find("guardian_summoned)") >= 0, "passive residual update should use the summoned fold")
	_expect(source.find("if guardian_summoned:\n\t\t\t_update_companion_skill_effects") >= 0, "active-skill update should use the summoned fold")
	_expect(source.find("func _end_guardian_runtime_for_stow") >= 0, "stow should own an explicit residual teardown boundary")
	var persistence_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
	_expect(persistence_source.count("if not companion_active:") >= 2, "both current and stored cooldown loops should carry the stow gate")


func _make_runtime_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _make_nekuring_runtime_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["nekuring"]
	owner.owned_lingpet_ids = ["nekuring"]
	owner.owned_ringpet_ids = ["nekuring"]
	owner.lingpet_slots = ["nekuring", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
