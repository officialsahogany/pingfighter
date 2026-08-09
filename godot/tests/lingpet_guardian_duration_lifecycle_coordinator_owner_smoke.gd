extends SceneTree
# expect-zero-object-leaks -- lifecycle fixtures must release runtime owners.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_facade_ownership_boundary()
	_verify_production_lifecycle()
	# Let zero-ref RefCounted teardown flush before SceneTree exits. The fixture
	# activates and retires several transient VFX/state owners in one call stack.
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("lingpet_guardian_duration_lifecycle_coordinator_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_facade_ownership_boundary() -> void:
	var facade_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_guardian_duration_lifecycle_coordinator.gd"
	)
	_expect(
		facade_source.find("LingpetGuardianDurationLifecycleCoordinator") >= 0
		and facade_source.find("_guardian_duration_lifecycle.configure") >= 0,
		"egg runtime must configure one Guardian duration lifecycle owner"
	)
	_expect(
		facade_source.find("return bool(_guardian_duration_lifecycle.is_stowed_state())") >= 0
		and facade_source.find("_guardian_duration_lifecycle.set_stowed_state(value)") >= 0,
		"legacy _guardian_stowed access must project through the canonical lifecycle state"
	)
	var delegated_functions := {
		"func refill_guardian_duration_for_stage_transition": "refill_for_stage_transition",
		"func try_toggle_guardian_stow": "_guardian_duration_lifecycle.try_toggle",
		"func _advance_duration_pool": "_guardian_duration_lifecycle.advance",
		"func _set_guardian_stowed": "_guardian_duration_lifecycle.set_stowed",
		"func _complete_guardian_summon_transition": "complete_summon_transition",
		"func _end_guardian_runtime_for_stow": "end_runtime_for_stow",
	}
	for signature in delegated_functions.keys():
		var body := _function_body(facade_source, str(signature))
		var delegated_call := str(delegated_functions[signature])
		_expect(
			body.find(delegated_call) >= 0,
			"%s must delegate to %s" % [str(signature), delegated_call]
		)
	_expect(
		_function_body(facade_source, "func _set_guardian_stowed").find("begin_stow") < 0
		and _function_body(facade_source, "func _set_guardian_stowed").find("play_lingpet_guardian_stow_transition") < 0,
		"egg runtime must not regain stow transition or audio ordering"
	)
	_expect(
		_function_body(facade_source, "func _end_guardian_runtime_for_stow").find("cancel_windups") < 0
		and _function_body(facade_source, "func _end_guardian_runtime_for_stow").find("reset_round_transients") < 0,
		"egg runtime must not regain residual teardown fanout"
	)
	for owned_behavior in [
		"can_resummon_guardian",
		"begin_stow",
		"begin_summon",
		"play_lingpet_guardian_stow_transition",
		"play_lingpet_guardian_summon_transition",
		"cancel_windups",
		"end_for_stow",
		"pet_id == \"nekuring\"",
	]:
		_expect(
			coordinator_source.find(owned_behavior) >= 0,
			"duration lifecycle coordinator must own %s" % owned_behavior
		)
	var cancel_at := coordinator_source.find("_skill_persistence.cancel_windups")
	var host_cleanup_at := coordinator_source.find("_skill_runtime_host.end_for_stow", cancel_at)
	var passive_cleanup_at := coordinator_source.find("_afterglow_leak_state.reset_round_transients", host_cleanup_at)
	_expect(
		cancel_at >= 0 and host_cleanup_at > cancel_at and passive_cleanup_at > host_cleanup_at,
		"stow cleanup must preserve windup -> active runtime -> passive residue order"
	)


func _verify_production_lifecycle() -> void:
	var owner := _make_runtime_owner()
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry),
		"production fixture must activate one Guardian"
	)
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	runtime._guardian_stowed = true
	_expect(runtime.is_guardian_stowed(), "legacy direct stowed write must reach coordinator-backed state")
	runtime._guardian_stowed = false
	_expect(runtime.is_companion_active(), "legacy direct unstowed write must restore the summoned fold")
	runtime.update(6.01, owner, registry)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "production toggle must be consumed after the six-second hold")
	_expect(runtime.is_guardian_stowed(), "production toggle must enter stowed state")
	var transition: Dictionary = runtime.get_snapshot().get("guardian_transition", {}) as Dictionary
	_expect(str(transition.get("mode", "")) == "stow", "production toggle must begin the stow transition")
	runtime.update(0.47, owner, registry)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "recovered shared pool must begin resummon")
	runtime.update(0.53, owner, registry)
	_expect(runtime.is_companion_active(), "summon transition completion must reactivate the Guardian")

	runtime.set_duration_pool_for_tests(5.0, 60.0)
	_expect(runtime.refill_guardian_duration_for_stage_transition(), "stage-transition facade must report a real refill")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 60.0), "stage-transition refill must restore the shared pool")
	runtime.set_duration_pool_for_tests(0.01, 60.0)
	runtime._guardian_stowed = false
	runtime.update(0.02, owner, registry)
	_expect(runtime.is_guardian_stowed(), "duration expiry must force the production stow path")
	_cleanup_runtime(runtime)
	registry.instances.clear()
	ProjectResourceLoader.clear_caches()


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


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
