extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload(
	"res://scripts/hud/character_info_overlay_lingpet_presenter.gd"
)
const CharacterInfoOverlayValueUtils := preload(
	"res://scripts/hud/character_info_overlay_value_utils.gd"
)
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

const CURRENT_PET_ID := "maribo"
const INCOMING_PET_ID := "volty"
const HATCH_SEED_SEARCH_LIMIT := 4096
const REWARD_SEED_SEARCH_LIMIT := 4096

var _failures: Array[String] = []


class DynamicOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"ball_active": false,
		"ball_pos": Vector2.ZERO,
		"ball_vel": Vector2.ZERO,
		"ball_size": 28.6,
		"special_gauge": 100.0,
		"special_gauge_max": 500.0,
		"lingpet_owned_pet_ids": [CURRENT_PET_ID],
		"owned_lingpet_ids": [CURRENT_PET_ID],
		"owned_ringpet_ids": [CURRENT_PET_ID],
		"lingpet_collection": {CURRENT_PET_ID: true},
		"ringpet_collection": {CURRENT_PET_ID: true},
		"owned_lingpets": {CURRENT_PET_ID: true},
		"owned_ringpets": {CURRENT_PET_ID: true},
		"lingpet_slots": [CURRENT_PET_ID, "", ""],
		"ringpet_slots": [CURRENT_PET_ID, "", ""],
		"lingpet_slot_pet_ids": [CURRENT_PET_ID, "", ""],
		"ringpet_slot_pet_ids": [CURRENT_PET_ID, "", ""],
		"lingpet_active_slot_index": 0,
		"ringpet_active_slot_index": 0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var runtime: Object = null

	func _init(next_runtime: Object) -> void:
		runtime = next_runtime

	func get_cached_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null

	func get_instance(key: String) -> Object:
		return get_cached_instance(key)


func _init() -> void:
	_verify_absorption_second_active_unlock_fills_both_surfaces()
	_verify_primary_unlock_keeps_second_slot_locked()
	if _failures.is_empty():
		print("guardian_active_unlock_absorption_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_absorption_second_active_unlock_fills_both_surfaces() -> void:
	var fixture := _make_zero_active_hatch_fixture()
	var runtime: Object = fixture.get("runtime")
	var owner: Object = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	var hatch_loadout: Dictionary = fixture.get("hatch_loadout", {}) as Dictionary
	_expect(
		str(hatch_loadout.get("active_skill_id", "")) == "",
		"fixture must use the production 0-level hatch outcome instead of a fabricated unlock state"
	)
	_expect(
		str(hatch_loadout.get("passive_skill_id", "")) != "",
		"fixture must retain a real hatched passive so the explicit empty-active loadout is persisted"
	)
	var before_loadout: Dictionary = runtime._loadout_state.get_stored_loadout(CURRENT_PET_ID)
	_expect(
		str(before_loadout.get("active_skill_id", "")) == ""
		and str(before_loadout.get("second_active_skill_id", "")) == "",
		"0-level hatch control must begin with both active slots empty"
	)

	var live_candidates: Array = runtime.build_guardian_enhance_live_candidates(owner)
	var reward_rng := _rng_for_candidate_type(
		live_candidates,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK
	)
	_expect(reward_rng != null, "fixture must find a deterministic second-active absorption roll")
	if reward_rng == null:
		runtime.reset_for_tests()
		return
	runtime.set_guardian_enhance_roll_rng_for_tests(reward_rng)
	var overflow_state: Object = runtime.get("_overflow_choice_state") as Object
	overflow_state.begin_main_egg(CURRENT_PET_ID)
	overflow_state.begin_main_overflow(INCOMING_PET_ID, false)
	_expect(overflow_state.activate_after_cutin(), "fixture must activate the production Replace / Absorb choice")
	_expect(
		runtime.commit_overflow_absorb(owner, registry),
		"production overflow absorb must accept the Guardian Enhancement result"
	)

	var result: Dictionary = runtime.get_guardian_enhance_last_result_for_tests()
	var applied_candidate: Dictionary = result.get("applied_candidate", {}) as Dictionary
	_expect(
		str(applied_candidate.get("type", ""))
		== LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		"deterministic absorption must land the extra-active unlock reward"
	)
	var rewards: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests(CURRENT_PET_ID)
	var loadout: Dictionary = runtime._loadout_state.get_stored_loadout(CURRENT_PET_ID)
	var runtime_snapshot: Dictionary = runtime.get_snapshot()
	var tab_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	var tab_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(
		tab_snapshot,
		Color(0.45, 1.0, 0.68, 1.0)
	)
	var rail_entries: Array = LingpetRailCard.build_entries(registry)
	var primary_id := str(loadout.get("active_skill_id", ""))
	var second_id := str(loadout.get("second_active_skill_id", ""))
	print(
		(
			"guardian_active_unlock_measurement: reward_counts.second_active_unlocked=%s "
		+ "loadout.active_skill_id=%s loadout.second_active_skill_id=%s "
		+ "loadout.second_active_skill_level=%d snapshot.companion_skill_id_1=%s "
		+ "tab.companion_skill_id_1=%s tab_active_cards=%d rail_cards=%d"
		) % [
			str(bool(rewards.get("second_active_unlocked", false))),
			primary_id,
			second_id,
			int(loadout.get("second_active_skill_level", 0)),
			str(runtime_snapshot.get("companion_skill_id_1", "")),
			str(tab_snapshot.get("companion_skill_id_1", "")),
			_count_active_specs(tab_specs),
			rail_entries.size(),
		]
	)
	_expect(
		bool(rewards.get("second_active_unlocked", false)),
		"absorption must retain the second-active reward ledger flag"
	)
	_expect(primary_id != "", "second-active reward must repair an empty primary active channel")
	_expect(second_id != "", "second-active reward must fill loadout slot 1")
	_expect(primary_id != second_id, "the two reconciled active slots must use distinct skills")
	_expect(
		int(loadout.get("active_skill_level", 0)) == 1
		and int(loadout.get("second_active_skill_level", 0)) == 1,
		"both skills implied by the extra-active reward must begin at Lv.1"
	)
	_expect(
		str(runtime_snapshot.get("companion_skill_id", "")) == primary_id
		and str(runtime_snapshot.get("companion_skill_id_1", "")) == second_id,
		"runtime snapshot must publish both reconciled active slots"
	)
	_expect(
		str(tab_snapshot.get("companion_skill_id", "")) == primary_id
		and str(tab_snapshot.get("companion_skill_id_1", "")) == second_id,
		"TAB snapshot must publish the primary and suffixed second-active keys"
	)
	_expect(
		_count_active_specs(tab_specs) == 2,
		"TAB Guardian panel must emit two active-skill cards after absorption"
	)
	_expect(
		rail_entries.size() == 2,
		"in-battle Lingpet rail must emit two active-skill cards after absorption"
	)
	if rail_entries.size() == 2:
		_expect(
			str((rail_entries[0] as Dictionary).get("id", "")) == primary_id
			and str((rail_entries[1] as Dictionary).get("id", "")) == second_id,
			"battle rail cards must preserve reconciled slot order"
		)
	runtime.reset_for_tests()


func _verify_primary_unlock_keeps_second_slot_locked() -> void:
	var fixture := _make_zero_active_hatch_fixture()
	var runtime: Object = fixture.get("runtime")
	var owner: Object = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK},
		owner,
		registry,
		CURRENT_PET_ID
	)
	_expect(bool(result.get("accepted", false)), "primary-active control reward must apply")
	var loadout: Dictionary = runtime._loadout_state.get_stored_loadout(CURRENT_PET_ID)
	var snapshot: Dictionary = runtime.get_snapshot()
	var entries: Array = LingpetRailCard.build_entries(registry)
	_expect(
		str(loadout.get("active_skill_id", "")) != "",
		"primary-active control reward must fill only slot 0"
	)
	_expect(
		str(loadout.get("second_active_skill_id", "")) == ""
		and str(snapshot.get("companion_skill_id_1", "")) == ""
		and entries.size() == 1,
		"primary-active reward must not invent or display a second active slot"
	)
	runtime.reset_for_tests()


func _make_zero_active_hatch_fixture() -> Dictionary:
	var hatch_loadout := _find_zero_active_hatch_loadout(CURRENT_PET_ID)
	var owner := DynamicOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new(runtime)
	_expect(not hatch_loadout.is_empty(), "fixture must find a real 0-level active hatch roll")
	if hatch_loadout.is_empty():
		return {"owner": owner, "runtime": runtime, "registry": registry, "hatch_loadout": {}}
	_expect(
		runtime.debug_grant_and_activate_pet(
			CURRENT_PET_ID,
			owner,
			false,
			str(hatch_loadout.get("active_skill_id", "")),
			str(hatch_loadout.get("passive_skill_id", "")),
			registry,
			int(hatch_loadout.get("active_skill_level", 0)),
			int(hatch_loadout.get("passive_skill_level", 0))
		),
		"fixture must activate the production hatch loadout"
	)
	# debug_grant keeps explicit test loadouts sticky by design. A real hatch does
	# not own that test-only bypass, so clear it before exercising the live reward
	# reconciler while preserving the exact hatch-produced ids and levels.
	runtime._loadout_state.set_skip_unlock_reconcile(false)
	runtime._loadout_state.invalidate_runtime_and_snapshot_cache(runtime._snapshot_builder)
	runtime.update(0.0, owner, registry)
	return {
		"owner": owner,
		"runtime": runtime,
		"registry": registry,
		"hatch_loadout": hatch_loadout,
	}


func _find_zero_active_hatch_loadout(pet_id: String) -> Dictionary:
	for seed_value in range(1, HATCH_SEED_SEARCH_LIMIT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var loadout: Dictionary = LingpetCatalog.pick_skill_loadout(pet_id, rng)
		if (
			str(loadout.get("active_skill_id", "")) == ""
			and str(loadout.get("passive_skill_id", "")) != ""
		):
			return loadout
	return {}


func _rng_for_candidate_type(candidates: Array, reward_type: String) -> RandomNumberGenerator:
	var total_weight := 0.0
	var target_start := -1.0
	var target_end := -1.0
	for value in candidates:
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value as Dictionary
		var weight := maxf(0.001, float(candidate.get("weight", 1.0)))
		if str(candidate.get("type", "")) == reward_type:
			target_start = total_weight
			target_end = total_weight + weight
		total_weight += weight
	if total_weight <= 0.0 or target_start < 0.0:
		return null
	for seed_value in range(1, REWARD_SEED_SEARCH_LIMIT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var roll := rng.randf_range(0.0, total_weight)
		if roll > target_start and roll <= target_end:
			rng.seed = seed_value
			return rng
	return null


func _count_active_specs(specs: Array) -> int:
	var count := 0
	for value in specs:
		if value is Dictionary and str((value as Dictionary).get("badge", "")) == "A":
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
