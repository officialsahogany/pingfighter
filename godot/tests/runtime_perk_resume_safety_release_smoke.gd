extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

# Seals the perk-choice resume safety's ball-speed behavior:
# 1) arming freezes a descending ball and score-blocks it (baseline protection),
# 2) recovery ramps the DESCENDING ball from 30% back to full speed (protection kept),
# 3) the moment the ball moves UPWARD (player paddle bounce / attack skill such as
#    power smash or drive), the safety releases immediately and the externally-set
#    velocity is preserved verbatim — the recovery ramp must NOT crush a skill's
#    launch speed back down to original*ratio (tester-reported "post-modal attack
#    skill feels dead" regression),
# 4) a wall-bounce-like change that keeps the ball descending does NOT release.

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkResumeSafety := preload("res://scripts/characters/runtime_perk_resume_safety.gd")

const FRAME_DELTA := 1.0 / 60.0

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_vel := Vector2.ZERO
	var player_collision_cooldown := 0.0


func _init() -> void:
	_test_runtime_state_facade_routes_resume_safety()
	_test_arm_requires_descending_ball()
	_test_freeze_then_recovery_ramp_baseline()
	_test_upward_hit_during_recovery_releases_and_preserves_velocity()
	_test_upward_hit_during_freeze_releases_and_preserves_velocity()
	_test_descending_wall_bounce_keeps_protection()
	_test_source_contract()

	if _failures.is_empty():
		print("runtime_perk_resume_safety_release_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_runtime_state_facade_routes_resume_safety() -> void:
	var helper := RuntimePerkResumeSafety.new()
	var runtime_state := FakeRuntimeState.new()
	runtime_state._resume_safety = RuntimePerkResumeSafety.new()
	runtime_state._dynamic_effects = FakeDynamicEffects.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(2.0, 8.0)

	helper.capture_pre_choice_velocity_from_runtime_state(runtime_state, owner)
	owner.ball_vel = Vector2.ZERO
	helper.try_arm_from_runtime_state(runtime_state, owner, null)
	var context: Dictionary = helper.get_context_from_runtime_state(runtime_state)
	_expect(
		bool(context.get("perk_resume_freeze_active", false)),
		"runtime-state resume facade should arm the stored resume-safety helper"
	)
	helper.update_from_runtime_state(runtime_state, owner, null, FRAME_DELTA)
	_expect(
		runtime_state._dynamic_effects.refresh_calls == 1,
		"runtime-state resume facade should refresh Viper Ignition Aura dirty owner sync before update"
	)
	helper.clear_active_from_runtime_state(runtime_state)
	context = helper.get_context_from_runtime_state(runtime_state)
	_expect(
		not bool(context.get("perk_resume_freeze_active", false)),
		"runtime-state resume facade should clear active resume safety"
	)
	owner.ball_vel = Vector2(1.0, 7.0)
	helper.capture_pre_choice_velocity_from_runtime_state(runtime_state, owner)
	var stopwatch_payload: Dictionary = helper.consume_velocity_for_stopwatch_from_runtime_state(runtime_state)
	_expect(
		stopwatch_payload.get("ball_vel", Vector2.ZERO) == Vector2(1.0, 7.0),
		"runtime-state resume facade should expose Stopwatch velocity handoff"
	)


func _arm_state(owner: FakeOwner, descend_vel: Vector2) -> Object:
	var perk_state: Object = RuntimePerkState.new()
	owner.ball_vel = descend_vel
	perk_state._try_arm_resume_safety(owner, null)
	return perk_state


func _test_arm_requires_descending_ball() -> void:
	var owner := FakeOwner.new()
	var perk_state: Object = RuntimePerkState.new()
	owner.ball_vel = Vector2(4.0, -12.0)
	perk_state._try_arm_resume_safety(owner, null)
	var context: Dictionary = perk_state.get_ball_resume_context()
	_expect(
		not bool(context.get("perk_resume_freeze_active", false)),
		"upward ball at modal close should not arm the resume safety"
	)
	_expect(
		owner.ball_vel == Vector2(4.0, -12.0),
		"skipped arm should leave the upward ball velocity untouched"
	)

	var armed_owner := FakeOwner.new()
	var armed_state: Object = _arm_state(armed_owner, Vector2(2.0, 9.0))
	context = armed_state.get_ball_resume_context()
	_expect(
		bool(context.get("perk_resume_freeze_active", false)),
		"descending ball at modal close should arm the freeze"
	)
	_expect(
		armed_owner.ball_vel == Vector2.ZERO,
		"arming should zero the descending ball"
	)


func _test_freeze_then_recovery_ramp_baseline() -> void:
	var owner := FakeOwner.new()
	var perk_state: Object = _arm_state(owner, Vector2(0.0, 10.0))

	for _i in range(10):
		perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	var context: Dictionary = perk_state.get_ball_resume_context()
	_expect(
		not bool(context.get("perk_resume_freeze_active", false)),
		"freeze should expire after PERK_RESUME_FREEZE_FRAMES ticks"
	)
	_expect(
		bool(context.get("perk_resume_recovery_active", false)),
		"recovery ramp should start when the freeze expires"
	)
	_expect(
		abs(owner.ball_vel.length() - 10.0 * 0.30) <= 0.05,
		"recovery should start the descending ball at 30%% of original speed (got %.2f)" % owner.ball_vel.length()
	)
	_expect(
		owner.ball_vel.y > 0.0,
		"recovery start should keep the descending direction"
	)

	for _i in range(70):
		perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	context = perk_state.get_ball_resume_context()
	_expect(
		not bool(context.get("perk_resume_recovery_active", false)),
		"recovery should finish after PERK_RESUME_RECOVERY_FRAMES ticks"
	)
	_expect(
		abs(owner.ball_vel.length() - 10.0) <= 0.05,
		"undisturbed descending ball should recover full original speed (got %.2f)" % owner.ball_vel.length()
	)


func _test_upward_hit_during_recovery_releases_and_preserves_velocity() -> void:
	var owner := FakeOwner.new()
	var perk_state: Object = _arm_state(owner, Vector2(0.0, 10.0))

	# Burn the freeze plus ~20 recovery frames: ball is crawling downward.
	for _i in range(30):
		perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	_expect(
		owner.ball_vel.length() < 10.0 - 0.05,
		"mid-recovery ball should still be below original speed"
	)

	# Player power-smashes the crawling ball: fast upward skill velocity.
	var smash_vel := Vector2(6.0, -38.0)
	owner.ball_vel = smash_vel
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	_expect(
		owner.ball_vel == smash_vel,
		"upward skill velocity must survive the resume tick verbatim (got %s)" % str(owner.ball_vel)
	)
	var context: Dictionary = perk_state.get_ball_resume_context()
	_expect(
		not bool(context.get("perk_resume_recovery_active", false))
			and not bool(context.get("perk_resume_freeze_active", false)),
		"upward hit during recovery should release the resume safety"
	)

	# Later ticks must stay hands-off too.
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	_expect(
		owner.ball_vel == smash_vel,
		"released safety must never touch the ball again (got %s)" % str(owner.ball_vel)
	)


func _test_upward_hit_during_freeze_releases_and_preserves_velocity() -> void:
	var owner := FakeOwner.new()
	var perk_state: Object = _arm_state(owner, Vector2(0.0, 10.0))

	# Two freeze ticks in, a direct-set skill (e.g. blade projectile hit)
	# launches the ball upward without a paddle collision.
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	var skill_vel := Vector2(-4.0, -30.0)
	owner.ball_vel = skill_vel
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	_expect(
		owner.ball_vel == skill_vel,
		"upward skill velocity during the freeze must survive verbatim (got %s)" % str(owner.ball_vel)
	)
	var context: Dictionary = perk_state.get_ball_resume_context()
	_expect(
		not bool(context.get("perk_resume_freeze_active", false))
			and not bool(context.get("perk_resume_recovery_active", false)),
		"upward hit during the freeze should release the resume safety"
	)


func _test_descending_wall_bounce_keeps_protection() -> void:
	var owner := FakeOwner.new()
	var perk_state: Object = _arm_state(owner, Vector2(3.0, 9.0))

	# Burn the freeze plus ~20 recovery frames.
	for _i in range(30):
		perk_state.update_resume_safety(owner, null, FRAME_DELTA)

	# Wall bounce: vx flips, ball still descending -> protection must continue.
	owner.ball_vel = Vector2(-owner.ball_vel.x, abs(owner.ball_vel.y))
	perk_state.update_resume_safety(owner, null, FRAME_DELTA)
	var context: Dictionary = perk_state.get_ball_resume_context()
	_expect(
		bool(context.get("perk_resume_recovery_active", false)),
		"descending wall bounce must NOT release the resume safety"
	)
	var original_speed: float = Vector2(3.0, 9.0).length()
	_expect(
		owner.ball_vel.length() < original_speed - 0.05,
		"descending ball should stay on the ramp after a wall bounce (got %.2f)" % owner.ball_vel.length()
	)
	_expect(
		owner.ball_vel.y > 0.0 and owner.ball_vel.x < 0.0,
		"ramp must preserve the bounced direction while restoring magnitude"
	)


func _test_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_resume_safety.gd")
	var update_body: String = _function_body(state_source, "func update_resume_safety(")
	var context_body: String = _function_body(state_source, "func get_ball_resume_context(")
	var consume_body: String = _function_body(state_source, "func consume_resume_velocity_for_stopwatch(")
	var capture_body: String = _function_body(state_source, "func _capture_resume_pre_choice_velocity(")
	var arm_body: String = _function_body(state_source, "func _try_arm_resume_safety(")
	var clear_body: String = _function_body(state_source, "func _clear_resume_safety(")
	var clear_pre_body: String = _function_body(state_source, "func _clear_resume_pre_choice(")

	_expect(helper_source.find("func update_from_runtime_state") >= 0, "resume-safety helper should expose runtime-state update facade")
	_expect(helper_source.find("func get_context_from_runtime_state") >= 0, "resume-safety helper should expose runtime-state context facade")
	_expect(helper_source.find("func consume_velocity_for_stopwatch_from_runtime_state") >= 0, "resume-safety helper should expose runtime-state Stopwatch handoff facade")
	_expect(helper_source.find("func capture_pre_choice_velocity_from_runtime_state") >= 0, "resume-safety helper should expose pre-choice capture facade")
	_expect(helper_source.find("func try_arm_from_runtime_state") >= 0, "resume-safety helper should expose arm facade")
	_expect(helper_source.find("_refresh_viper_ignition_aura_owner_sync_if_needed") >= 0, "resume-safety helper should own pre-update dynamic-effect refresh handoff")
	_expect(helper_source.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_resume_safety\")") >= 0, "resume-safety helper should look itself up through shared runtime-state access")
	_expect(helper_source.find("RuntimePerkRuntimeStateAccess.get_object(runtime_state, \"_dynamic_effects\")") >= 0, "resume-safety helper should look up dynamic effects through shared runtime-state access")
	_expect(helper_source.find("RuntimePerkPayloadAccess.as_finite_vector2(") >= 0, "resume-safety helper should use shared finite Vector2 velocity normalization")
	_expect(helper_source.find("RuntimePerkRegistryLookup") >= 0, "resume-safety helper should preload shared registry lookup")
	_expect(helper_source.find("_registry_lookup.get_instance(registry, \"round_flow_state\")") >= 0, "resume-safety helper should use shared registry lookup for round flow state")
	_expect(helper_source.find("_registry_lookup.get_instance(registry, \"active_item_runtime\")") >= 0, "resume-safety helper should use shared registry lookup for active item runtime")
	_expect(helper_source.find("func _get_state_object(") < 0, "resume-safety helper should not keep local runtime-state object accessor")
	_expect(helper_source.find("func _get_instance(") < 0, "resume-safety helper should not keep local registry lookup")
	_expect(helper_source.find("func _get_valid_velocity(") < 0, "resume-safety helper should not keep local finite Vector2 normalizer")
	_expect(update_body.find("update_from_runtime_state") >= 0, "state update_resume_safety wrapper should use runtime-state facade")
	_expect(update_body.find("_dynamic_effects") < 0, "state update_resume_safety wrapper should not call dynamic effects directly")
	_expect(update_body.find("_resume_safety.update(") < 0, "state update_resume_safety wrapper should not call update directly")
	_expect(context_body.find("get_context_from_runtime_state") >= 0, "state resume context wrapper should use runtime-state facade")
	_expect(consume_body.find("consume_velocity_for_stopwatch_from_runtime_state") >= 0, "state Stopwatch handoff wrapper should use runtime-state facade")
	_expect(capture_body.find("capture_pre_choice_velocity_from_runtime_state") >= 0, "state pre-choice capture wrapper should use runtime-state facade")
	_expect(arm_body.find("try_arm_from_runtime_state") >= 0, "state arm wrapper should use runtime-state facade")
	_expect(clear_body.find("clear_active_from_runtime_state") >= 0, "state clear-active wrapper should use runtime-state facade")
	_expect(clear_pre_body.find("clear_pre_choice_from_runtime_state") >= 0, "state clear-pre-choice wrapper should use runtime-state facade")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


class FakeRuntimeState:
	extends RefCounted

	var _resume_safety: Object = null
	var _dynamic_effects: Object = null


class FakeDynamicEffects:
	extends RefCounted

	var refresh_calls := 0

	func refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(
		_runtime_state: Object,
		_registry: Object,
		_owner: Object
	) -> void:
		refresh_calls += 1
