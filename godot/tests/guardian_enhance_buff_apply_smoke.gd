extends SceneTree

const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkChoiceDispatch := preload(
	"res://scripts/characters/runtime_perk_choice_dispatch.gd"
)
const RuntimePerkChoiceActionRunner := preload(
	"res://scripts/characters/runtime_perk_choice_action_runner.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_live_dispatch_and_unique_owner()
	_verify_duration_owner_pet_replace_refill_and_cap()
	_verify_per_pet_buff_isolation_and_uncapped_fallback()
	_verify_unlock_payload_identifies_the_final_skill()
	if _failures.is_empty():
		print("guardian_enhance_buff_apply_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_live_dispatch_and_unique_owner() -> void:
	var fixture := _make_runtime_fixture()
	var runtime: Object = fixture.runtime
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	var rng := RandomNumberGenerator.new()
	rng.seed = 17031
	runtime.set_guardian_enhance_roll_rng_for_tests(rng)
	var choices: Array = RuntimePerkCatalog.new().get_choices(
		"smasher", {}, false, 3, owner, registry
	)
	var guardian_choice := _find_choice(choices, "lingpet_guardian_enhance")
	_expect(not guardian_choice.is_empty(), "owned guardian must surface the reserved enhance card in the live perk catalog")
	_expect(str(guardian_choice.get("offer_lane", "")) == "guardian_enhance_reserved", "first eligible card must occupy the protected reservation lane")
	var dispatch := RuntimePerkChoiceDispatch.new().build_dispatch(
		guardian_choice,
		false,
		false
	)
	_expect(str(dispatch.get("action", "")) == "lingpet_guardian_enhance", "perk dispatch must route the guardian enhance action")
	var action := RuntimePerkChoiceActionRunner.new().run_dispatch(
		dispatch,
		guardian_choice,
		owner,
		registry,
		{}
	)
	_expect(bool(action.get("accepted", false)), "action runner must apply one automatic guardian enhancement")
	var begin_result: Dictionary = action.get("begin_result", {}) as Dictionary
	_expect(not bool(begin_result.get("modal_started", true)), "live dispatch must not open a secondary choice modal")
	_expect(bool(runtime.get_guardian_enhance_last_result_for_tests().get("accepted", false)), "live dispatch must finish application before presentation starts")
	runtime.cancel_guardian_enhance_cutin(registry)
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var affinity_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_guardian_run_state.gd"
	)
	_expect(runtime_source.find("var _guardian_enhancement_buff_store") < 0, "runtime must not create a parallel enhancement store")
	_expect(
		affinity_source.find("func get_guardian_enhancement_skill_availability") >= 0
		and runtime_source.find("LingpetCatalog") < 0,
		"affinity owner must resolve enhancement skill availability without reopening catalog ownership in egg runtime"
	)
	_cleanup_runtime(runtime)


func _verify_duration_owner_pet_replace_refill_and_cap() -> void:
	var fixture := _make_runtime_fixture()
	var runtime: Object = fixture.runtime
	var owner: Object = fixture.owner
	runtime.set_duration_pool_for_tests(50.0, 50.0)
	var duration_candidate := {"type": LingpetEnhancementBuffStore.REWARD_TYPE_DURATION}
	for expected_count in [1, 2]:
		var applied: Dictionary = runtime.apply_guardian_enhancement_candidate(duration_candidate, owner, fixture.registry, "maribo")
		_expect(bool(applied.get("accepted", false)), "duration increase %d must apply" % expected_count)
		_expect(str(applied.get("storage_owner", "")) == "lingpet_duration_state", "duration increase must bypass the per-pet store")
		runtime.complete_guardian_enhance_roll(applied, "maribo")
	_expect_float(runtime.get_duration_pool_max(), 60.0, "two duration increases must raise the shared max by ten seconds")
	_expect_float(runtime.get_duration_pool_current(), 60.0, "duration increase must raise current and max together")
	var overflow_state: Object = runtime.get("_overflow_choice_state") as Object
	overflow_state.begin_main_egg("maribo")
	overflow_state.begin_main_overflow("volty", false)
	overflow_state.activate_after_cutin()
	_expect(runtime.commit_overflow_replace(0, owner, fixture.registry), "fixture must replace the one live guardian")
	_expect_float(runtime.get_duration_pool_max(), 60.0, "pet replacement must preserve the run-shared enhanced maximum")
	runtime.set_duration_pool_for_tests(13.0, 60.0)
	_expect(runtime.refill_guardian_duration_for_stage_transition(), "stage transition must report a changed refill")
	_expect_float(runtime.get_duration_pool_current(), 60.0, "stage refill must target the enhanced maximum")
	var affinity: Object = runtime.get("_guardian_run_state") as Object
	_expect(int(affinity.get_duration_increase_count()) == 2, "duration owner must retain the run cap counter")
	var candidates: Array = affinity.build_guardian_enhancement_candidates("volty", true, true)
	_expect(not _has_candidate_type(candidates, LingpetEnhancementBuffStore.REWARD_TYPE_DURATION), "third duration increase must be removed by the pre-roll filter")
	_cleanup_runtime(runtime)


func _verify_per_pet_buff_isolation_and_uncapped_fallback() -> void:
	var fixture := _make_runtime_fixture()
	var runtime: Object = fixture.runtime
	var owner: Object = fixture.owner
	var active_candidate := {
		"type": LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL,
		"skill_slot": 1,
	}
	var applied: Dictionary = runtime.apply_guardian_enhancement_candidate(
		active_candidate,
		owner,
		fixture.registry,
		"maribo"
	)
	_expect(bool(applied.get("accepted", false)), "active-skill +1 must traverse the live buff store")
	_expect(str(applied.get("storage_owner", "")) == "lingpet_enhancement_buff_store", "non-duration buff must report the unique per-pet owner")
	var maribo_counts: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("maribo")
	_expect(int(maribo_counts.get("active_skill_bonus", 0)) == 1, "owner snapshot must match the applied target-pet buff")
	_expect((applied.get("reward_counts", {}) as Dictionary) == maribo_counts, "apply result and buff-store owner snapshot must be identical")
	var level_detail: Dictionary = applied.get("result_detail", {}) as Dictionary
	_expect(str(level_detail.get("kind", "")) == "skill_level", "live skill +1 result must expose a level-up detail payload")
	_expect(str(level_detail.get("skill_id", "")) != "", "live skill +1 result must identify its final target skill")
	_expect(str(level_detail.get("skill_display_name", "")) != "", "live skill +1 result must expose the target display name")
	_expect(int(level_detail.get("new_level", 0)) == int(level_detail.get("previous_level", 0)) + 1, "live skill +1 result must expose the exact previous-to-new level transition")
	var icon_path := str(level_detail.get("icon_texture_path", ""))
	_expect(icon_path != "" and FileAccess.file_exists(icon_path), "live skill +1 result icon must resolve to an existing catalog asset")
	var lunabi_counts: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("lunabi")
	_expect(int(lunabi_counts.get("active_skill_bonus", 0)) == 0, "per-pet enhancement must not leak to another guardian")
	runtime.complete_guardian_enhance_roll(applied, "maribo")
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	var fallback: Dictionary = runtime.apply_guardian_enhance_duration_fallback(owner, fixture.registry)
	_expect(bool(fallback.get("accepted", false)), "all-invalid fallback must always apply at a full pool")
	_expect_float(runtime.get_duration_pool_current(), 75.0, "fallback must add fifteen seconds without a current-value cap")
	_expect_float(runtime.get_duration_pool_max(), 60.0, "fallback must leave pool_max unchanged")
	_expect(not bool(fallback.get("pool_max_changed", true)), "fallback result must explicitly report max preservation")
	var run_state: Dictionary = (runtime.get("_guardian_run_state") as Object).export_run_state()
	_expect_float(float(run_state.get("duration_pool", 0.0)), 75.0, "uncapped fallback current must survive owner export")
	var fallback_detail: Dictionary = fallback.get("result_detail", {}) as Dictionary
	_expect_float(float(fallback_detail.get("stat_amount", 0.0)), LingpetDurationState.REVALIDATION_FALLBACK_SECONDS, "fallback detail must read the +15 amount from the duration owner constant")

	var defense_detail: Dictionary = _build_result_detail_for_candidate(runtime, owner, fixture.registry, {
		"type": LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE,
	})
	_expect_float(float(defense_detail.get("stat_amount", 0.0)), LingpetCurrentProfile.ENHANCEMENT_PATROL_DEFENSE_BONUS * 100.0, "defense result amount must track the live profile constant")
	_cleanup_runtime(runtime)


func _build_result_detail_for_candidate(
	runtime: Object,
	owner: Object,
	registry: Object,
	candidate: Dictionary
) -> Dictionary:
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		candidate,
		owner,
		registry,
		"maribo"
	)
	_expect(bool(result.get("accepted", false)), "result-detail fixture candidate must apply")
	return result.get("result_detail", {}) as Dictionary


func _verify_unlock_payload_identifies_the_final_skill() -> void:
	var fixture := _make_runtime_fixture()
	var runtime: Object = fixture.runtime
	var owner: Object = fixture.owner
	var empty_loadout := LingpetCatalog.build_empty_loadout("maribo")
	var empty_by_pet := {"maribo": empty_loadout}
	for key in ["lingpet_loadouts", "ringpet_loadouts", "owned_lingpet_loadouts", "owned_ringpet_loadouts"]:
		owner.set(key, empty_by_pet.duplicate(true))
	var loadout_state: Object = runtime.get("_loadout_state") as Object
	loadout_state.set_loadouts(empty_by_pet)
	loadout_state.invalidate_runtime_cache()
	loadout_state.set_skip_unlock_reconcile(false)
	var run_state: Object = runtime.get("_guardian_run_state") as Object
	run_state.configure_reward_context("maribo", "patrol", 1, 1, 0, false, "", "")
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK},
		owner,
		fixture.registry,
		"maribo"
	)
	_expect(bool(result.get("accepted", false)), "empty active channel must accept its unlock enhancement")
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	_expect(str(detail.get("kind", "")) == "skill_unlock", "unlock result must carry the unlock presentation kind")
	_expect(str(detail.get("skill_id", "")) != "", "unlock result must identify the skill selected by final reconciliation")
	_expect(str(detail.get("skill_display_name", "")) != "", "unlock result must carry the selected skill display name")
	_expect(int(detail.get("previous_level", -1)) == 0 and int(detail.get("new_level", 0)) >= 1, "unlock result must expose the 0-to-unlocked level transition")
	var icon_path := str(detail.get("icon_texture_path", ""))
	_expect(icon_path != "" and FileAccess.file_exists(icon_path), "unlock result must carry an existing selected-skill icon")
	_cleanup_runtime(runtime)


func _make_runtime_fixture() -> Dictionary:
	var owner := Smoke.FakeOwner.new()
	_seed_roster(owner, ["maribo"])
	var runtime: Object = LingpetEggRuntime.new()
	var registry := Smoke.FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_spear_throw", "maribo_hydro_resonance", registry), "fixture must activate maribo")
	return {"owner": owner, "runtime": runtime, "registry": registry}


func _seed_roster(owner: Object, pet_ids: Array) -> void:
	var ids := pet_ids.duplicate()
	var collection := {}
	for pet_id in ids:
		collection[str(pet_id)] = true
	owner.lingpet_owned_pet_ids = ids.duplicate()
	owner.owned_lingpet_ids = ids.duplicate()
	owner.owned_ringpet_ids = ids.duplicate()
	owner.lingpet_collection = collection.duplicate(true)
	owner.ringpet_collection = collection.duplicate(true)
	owner.owned_lingpets = collection.duplicate(true)
	owner.owned_ringpets = collection.duplicate(true)
	owner.lingpet_slots = [ids[0]]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0


func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _has_candidate_type(candidates: Array, reward_type: String) -> bool:
	for value in candidates:
		if value is Dictionary and str((value as Dictionary).get("type", "")) == reward_type:
			return true
	return false


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null:
		runtime.reset_for_tests()


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
