extends SceneTree
# expect-zero-object-leaks -- enhancement flow fixtures must release runtime owners.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_facade_ownership_boundary()
	_verify_production_flow()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("lingpet_guardian_enhance_flow_coordinator_owner_smoke: ok")
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
		"res://scripts/lingpet/lingpet_guardian_enhance_flow_coordinator.gd"
	)
	_expect(
		facade_source.find("LingpetGuardianEnhanceFlowCoordinator") >= 0
		and facade_source.find("_guardian_enhance_flow.configure") >= 0,
		"egg runtime must configure one Guardian Enhancement flow owner"
	)
	var delegated_functions := {
		"func build_guardian_enhance_offer": "_guardian_enhance_flow.build_offer",
		"func apply_guardian_enhance_random_roll": "_guardian_enhance_flow.apply_random_roll",
		"func build_guardian_enhance_live_candidates": "_guardian_enhance_flow.build_live_candidates",
		"func trigger_guardian_enhancement_from_absorption": "_guardian_enhance_flow.trigger_from_absorption",
		"func can_apply_guardian_enhancement_candidate": "_guardian_enhance_flow.can_apply_candidate",
		"func apply_guardian_enhancement_candidate": "_guardian_enhance_flow.apply_candidate",
		"func apply_guardian_enhance_duration_fallback": "_guardian_enhance_flow.apply_duration_fallback",
	}
	for signature in delegated_functions.keys():
		var body := _function_body(facade_source, str(signature))
		var delegated_call := str(delegated_functions[signature])
		_expect(
			body.find(delegated_call) >= 0,
			"%s must delegate to %s" % [str(signature), delegated_call]
		)
	for retired_facade_owner in [
		"LingpetGuardianEnhanceApplier",
		"LingpetGuardianEnhanceResultDetail",
		"LingpetEnhancementBuffStore",
		"var _guardian_enhance_roll_rng_for_tests",
		"_copy_guardian_enhance_detail_fields",
	]:
		_expect(
			facade_source.find(retired_facade_owner) < 0,
			"egg runtime must not regain enhancement flow owner %s" % retired_facade_owner
		)
	for owned_behavior in [
		"LingpetGuardianEnhanceApplier.resolve_random_roll",
		"build_guardian_enhancement_candidates",
		"apply_guardian_enhancement",
		"handle_enhancement_gain",
		"LingpetGuardianEnhanceResultDetail.build",
		"_presentation.complete_roll",
		"WeakRef",
	]:
		_expect(
			coordinator_source.find(owned_behavior) >= 0,
			"Guardian Enhancement flow coordinator must own %s" % owned_behavior
		)


func _verify_production_flow() -> void:
	var owner := _make_runtime_owner()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := Smoke.FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(
		runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry),
		"production fixture must activate one Guardian"
	)
	runtime.set_duration_pool_for_tests(40.0, 50.0)
	var offer: Dictionary = runtime.build_guardian_enhance_offer(owner)
	_expect(bool(offer.get("offer_allowed", false)), "production offer path must remain eligible")
	_expect(str(offer.get("pet_id", "")) == "maribo", "offer must retain the resolved Guardian id")
	var rng := RandomNumberGenerator.new()
	rng.seed = 87123
	runtime.set_guardian_enhance_roll_rng_for_tests(rng)
	var result: Dictionary = runtime.apply_guardian_enhance_random_roll(
		[{"type": LingpetEnhancementBuffStore.REWARD_TYPE_DURATION}],
		owner,
		registry
	)
	_expect(bool(result.get("accepted", false)), "production random roll must apply its sole valid candidate")
	_expect(
		str((result.get("applied_candidate", {}) as Dictionary).get("type", ""))
		== LingpetEnhancementBuffStore.REWARD_TYPE_DURATION,
		"production random roll must preserve the selected duration candidate"
	)
	_expect(
		is_equal_approx(runtime.get_duration_pool_current(), 45.0)
		and is_equal_approx(runtime.get_duration_pool_max(), 55.0),
		"flow application must raise shared current and maximum duration together"
	)
	_expect(runtime.is_guardian_enhance_cutin_active(), "accepted production roll must start presentation")
	runtime.cancel_guardian_enhance_cutin(registry)
	var fallback: Dictionary = runtime.apply_guardian_enhance_duration_fallback(owner, registry)
	_expect(bool(fallback.get("accepted", false)), "production fallback must remain accepted")
	_expect(
		is_equal_approx(runtime.get_duration_pool_current(), 60.0)
		and is_equal_approx(runtime.get_duration_pool_max(), 55.0),
		"fallback must overfill current by fifteen seconds without changing maximum"
	)
	var detail: Dictionary = fallback.get("result_detail", {}) as Dictionary
	_expect(
		is_equal_approx(float(detail.get("stat_amount", 0.0)), 15.0),
		"fallback result detail must preserve the player-facing amount"
	)
	runtime.reset_for_tests()
	registry.instances.clear()
	ProjectResourceLoader.clear_caches()


func _make_runtime_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_collection = {"maribo": true}
	owner.ringpet_collection = {"maribo": true}
	owner.owned_lingpets = {"maribo": true}
	owner.owned_ringpets = {"maribo": true}
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
