extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerStartCardOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
)
const TowerStartCardState := preload(
	"res://scripts/tower_ascent/tower_start_card_state.gd"
)

var _failures: Array[String] = []
var _leg_count := 0


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"


class FakeFlowOwner:
	extends RefCounted

	var run_id := "tower-start-card-run"

	func get_run_id() -> String:
		return run_id


class FakeUnlockStore:
	extends RefCounted

	var locked_ids: Dictionary = {}

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return not locked_ids.has(content_id)


class FakeSkillConfig:
	extends RefCounted

	var max_slots := 4
	var equipped_skills: Array[String] = ["base_skill"]
	var known_skills: Dictionary = {
		"base_skill": {"name": "Base"},
		"skill_alpha": {"name": "Alpha"},
		"skill_beta": {"name": "Beta"},
		"skill_gamma": {"name": "Gamma"},
		"skill_delta": {"name": "Delta"},
	}

	func is_shared_slot_full() -> bool:
		return equipped_skills.size() >= max_slots

	func get_skill_data(skill_id: String) -> Dictionary:
		var value: Variant = known_skills.get(skill_id, {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}

	func unlock_and_equip_skill(skill_id: String) -> bool:
		if not known_skills.has(skill_id) or is_shared_slot_full():
			return false
		if not equipped_skills.has(skill_id):
			equipped_skills.append(skill_id)
		return true


class FakeCatalog:
	extends RefCounted

	var all_calls := 0
	var data: Dictionary = {}

	func get_all_perk_data() -> Dictionary:
		all_calls += 1
		return data.duplicate(true)


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var current_choice_context: Dictionary = {"source": "before_start_card"}
	var apply_calls := 0
	var cancel_calls := 0
	var force_pending_swap := false
	var pending_swap := false
	var seen_context: Dictionary = {}
	var skill_config: FakeSkillConfig

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		seen_context = current_choice_context.duplicate(true)
		if force_pending_swap:
			pending_swap = true
			return false
		var perk_id := str(choice.get("id", ""))
		var unlocked_skill := str(choice.get("unlocks_skill", ""))
		if perk_id.is_empty():
			return false
		if not unlocked_skill.is_empty():
			if not skill_config.unlock_and_equip_skill(unlocked_skill):
				return false
			runtime_skill_levels[perk_id] = 1
		else:
			runtime_skill_levels[perk_id] = int(runtime_skill_levels.get(perk_id, 0)) + 1
		return true

	func has_pending_unlock_swap() -> bool:
		return pending_swap

	func cancel_pending_unlock_swap(_owner: Object = null) -> bool:
		if not pending_swap:
			return false
		pending_swap = false
		cancel_calls += 1
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_offer_shape_and_filters()
	_verify_determinism_and_global_rng_isolation()
	_verify_fallback_matrix()
	_verify_apply_and_single_pick_contract()
	_verify_pending_swap_fails_closed()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(_leg_count == 6, "all six start-card S1 smoke legs must execute")
	if _failures.is_empty():
		print("tower_start_card_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_offer_shape_and_filters() -> void:
	_leg_count += 1
	var fixture := _build_fixture(_standard_catalog())
	(fixture.unlock_store as FakeUnlockStore).locked_ids["mugong_locked"] = true
	var offer := TowerStartCardOfferBuilder.new().build_offer(
		"shape-run",
		fixture.owner,
		fixture.registry
	)
	var choices := _offer_choices(offer)
	_expect(bool(offer.get("accepted", false)), "one Chosik plus two Mugong must build")
	_expect(choices.size() == 3, "start-card offer must contain exactly three cards")
	_expect(_kind_count(choices, "chosik") == 1, "normal offer must contain one Chosik")
	_expect(_kind_count(choices, "mugong") == 2, "normal offer must contain two Mugong")
	var ids := _choice_ids(choices)
	for excluded_id in [
		"mugong_mythic",
		"mugong_instant",
		"mugong_training",
		"mugong_locked",
		"mugong_other_character",
	]:
		_expect(not ids.has(excluded_id), "excluded candidate leaked into offer: %s" % excluded_id)
	_expect((fixture.catalog as FakeCatalog).all_calls == 1, "one offer must call get_all_perk_data exactly once")
	for choice in choices:
		_expect(bool(choice.get("enabled", false)), "every fresh card must be enabled")
		_expect(not choice.has("reward_pick_cost"), "start card must not expose reward cost")
		_expect(not choice.has("reward_pick_price_text"), "start card must not expose price text")
		_expect(not choice.has("balance_text"), "start card must not expose balance text")


func _verify_determinism_and_global_rng_isolation() -> void:
	_leg_count += 1
	var builder := TowerStartCardOfferBuilder.new()
	var first := _build_fixture(_standard_catalog())
	var second := _build_fixture(_standard_catalog())
	var third := _build_fixture(_standard_catalog())
	var first_ids := _choice_ids(_offer_choices(builder.build_offer(
		"deterministic-run",
		first.owner,
		first.registry
	)))
	var second_ids := _choice_ids(_offer_choices(builder.build_offer(
		"deterministic-run",
		second.owner,
		second.registry
	)))
	var third_ids := _choice_ids(_offer_choices(builder.build_offer(
		"different-run",
		third.owner,
		third.registry
	)))
	_expect(first_ids == second_ids, "same run and character must reproduce the same three IDs")
	_expect(first_ids != third_ids, "changing run_id must change the deterministic offer fixture")

	seed(90210)
	var observed_first := randi()
	var rng_fixture := _build_fixture(_standard_catalog())
	builder.build_offer("rng-isolation", rng_fixture.owner, rng_fixture.registry)
	var observed_second := randi()
	seed(90210)
	var expected_first := randi()
	var expected_second := randi()
	_expect(
		observed_first == expected_first and observed_second == expected_second,
		"start-card generation must not advance global gameplay RNG"
	)


func _verify_fallback_matrix() -> void:
	_leg_count += 1
	var full_fixture := _build_fixture(_standard_catalog())
	(full_fixture.skill_config as FakeSkillConfig).max_slots = 1
	var full_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"full-slot",
		full_fixture.owner,
		full_fixture.registry
	))
	_expect(_kind_count(full_choices, "chosik") == 0, "full shared slots must suppress Chosik cards")
	_expect(_kind_count(full_choices, "mugong") == 3, "full shared slots must fall back to three Mugong")

	var no_chosik := _build_fixture({
		"m1": _mugong("m1"),
		"m2": _mugong("m2"),
		"m3": _mugong("m3"),
	})
	var no_chosik_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"no-chosik",
		no_chosik.owner,
		no_chosik.registry
	))
	_expect(_kind_count(no_chosik_choices, "mugong") == 3, "zero Chosik candidates must fall back to three Mugong")

	var one_mugong := _build_fixture({
		"m1": _mugong("m1"),
		"c1": _chosik("c1", "skill_alpha"),
		"c2": _chosik("c2", "skill_beta"),
	})
	var one_mugong_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"one-mugong",
		one_mugong.owner,
		one_mugong.registry
	))
	_expect(_kind_count(one_mugong_choices, "mugong") == 1, "one Mugong fixture must keep its Mugong")
	_expect(_kind_count(one_mugong_choices, "chosik") == 2, "one Mugong fixture must fill with two Chosik")

	var insufficient := _build_fixture({
		"m1": _mugong("m1"),
		"c1": _chosik("c1", "skill_alpha"),
	})
	var skipped := TowerStartCardOfferBuilder.new().build_offer(
		"insufficient",
		insufficient.owner,
		insufficient.registry
	)
	_expect(not bool(skipped.get("accepted", true)), "fewer than three total candidates must skip")
	_expect(str(skipped.get("reason", "")) == "start_card_skipped", "insufficient stock must use the explicit skip reason")


func _verify_apply_and_single_pick_contract() -> void:
	_leg_count += 1
	var mugong_fixture := _build_fixture(_standard_catalog())
	var mugong_state := TowerStartCardState.new()
	_expect(mugong_state.begin(mugong_fixture.owner, mugong_fixture.registry), "state must begin with a valid offer")
	var mugong_index := _find_kind_index(mugong_state.get_card_choices(), "mugong")
	_expect(mugong_state.select_slot(mugong_index), "Mugong start card must apply")
	var mugong_result := mugong_state.get_selection_result()
	var mugong_id := str(mugong_result.get("picked_perk_id", ""))
	_expect(int((mugong_fixture.runtime_state as FakeRuntimeState).runtime_skill_levels.get(mugong_id, 0)) == 1, "Mugong choice must update runtime skill levels")
	_expect(str((mugong_fixture.runtime_state as FakeRuntimeState).seen_context.get("source", "")) == "tower_start_card", "grant must expose tower_start_card source")
	_expect((mugong_fixture.runtime_state as FakeRuntimeState).current_choice_context == {"source": "before_start_card"}, "grant must restore the previous choice context")
	_expect(not mugong_state.select_slot(mugong_index), "a second click after the one pick must be a no-op")
	var frozen_cards := mugong_state.get_card_choices()
	_expect(frozen_cards.size() == 3, "selection must preserve all three card slots")
	for choice in frozen_cards:
		_expect(not bool(choice.get("enabled", true)), "selection must disable every remaining card")
	mugong_state.update(TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC)
	_expect(mugong_state.is_completed() and not mugong_state.is_active(), "absorb completion must end the phase")

	var chosik_fixture := _build_fixture(_standard_catalog())
	var chosik_state := TowerStartCardState.new()
	_expect(chosik_state.begin(chosik_fixture.owner, chosik_fixture.registry), "Chosik fixture must begin")
	var chosik_index := _find_kind_index(chosik_state.get_card_choices(), "chosik")
	var chosik_choice := chosik_state.get_card_choices()[chosik_index]
	_expect(chosik_state.select_slot(chosik_index), "Chosik start card must apply")
	_expect((chosik_fixture.skill_config as FakeSkillConfig).equipped_skills.has(str(chosik_choice.get("unlocks_skill", ""))), "Chosik choice must equip its unlocked skill")


func _verify_pending_swap_fails_closed() -> void:
	_leg_count += 1
	var fixture := _build_fixture(_standard_catalog())
	(fixture.runtime_state as FakeRuntimeState).force_pending_swap = true
	var state := TowerStartCardState.new()
	_expect(state.begin(fixture.owner, fixture.registry), "pending-swap fixture must begin")
	var chosik_index := _find_kind_index(state.get_card_choices(), "chosik")
	_expect(not state.select_slot(chosik_index), "a pending Chosik swap must fail closed")
	_expect((fixture.runtime_state as FakeRuntimeState).cancel_calls == 1, "pending swap must be explicitly canceled")
	_expect(not (fixture.runtime_state as FakeRuntimeState).pending_swap, "pending swap state must not leak past the start card")
	_expect(state.is_completed() and state.was_skipped(), "failed grant must end instead of hanging")


func _verify_source_contract() -> void:
	_leg_count += 1
	var builder_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
	)
	var state_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_start_card_state.gd"
	)
	_expect(builder_source.count("get_all_perk_data") == 2, "builder source must contain one call plus one contract comment")
	_expect(builder_source.find("get_perk_data") < 0, "builder must not repeat per-ID catalog lookups")
	_expect(builder_source.find("choices.shuffle") < 0, "builder must not use global Array shuffle")
	_expect(builder_source.find("RandomNumberGenerator.new()") >= 0, "builder must own a private RNG")
	for forbidden_method in [
		"apply_reward_pick_purchase",
		"finalize_reward_pick",
		"get_reward_pick_context",
		"apply_once",
	]:
		_expect(state_source.find(forbidden_method) < 0, "state must not enter reward transaction path: %s" % forbidden_method)


func _build_fixture(catalog_data: Dictionary) -> Dictionary:
	var owner := FakeOwner.new()
	var flow_owner := FakeFlowOwner.new()
	var unlock_store := FakeUnlockStore.new()
	var skill_config := FakeSkillConfig.new()
	var catalog := FakeCatalog.new()
	catalog.data = catalog_data.duplicate(true)
	var runtime_state := FakeRuntimeState.new()
	runtime_state.skill_config = skill_config
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow_owner,
		"tower_ascent_unlock_store": unlock_store,
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": skill_config,
	}
	return {
		"owner": owner,
		"flow_owner": flow_owner,
		"unlock_store": unlock_store,
		"skill_config": skill_config,
		"catalog": catalog,
		"runtime_state": runtime_state,
		"registry": registry,
	}


func _standard_catalog() -> Dictionary:
	return {
		"mugong_alpha": _mugong("mugong_alpha"),
		"mugong_beta": _mugong("mugong_beta"),
		"mugong_gamma": _mugong("mugong_gamma"),
		"mugong_delta": _mugong("mugong_delta"),
		"mugong_epsilon": _mugong("mugong_epsilon"),
		"mugong_zeta": _mugong("mugong_zeta"),
		"chosik_alpha": _chosik("chosik_alpha", "skill_alpha"),
		"chosik_beta": _chosik("chosik_beta", "skill_beta"),
		"chosik_gamma": _chosik("chosik_gamma", "skill_gamma"),
		"chosik_delta": _chosik("chosik_delta", "skill_delta"),
		"mugong_mythic": _mugong("mugong_mythic", {"rarity": "mythic"}),
		"mugong_instant": _mugong("mugong_instant", {"is_instant": true}),
		"mugong_training": _mugong("mugong_training", {"is_physique_training": true}),
		"mugong_locked": _mugong("mugong_locked"),
		"mugong_other_character": _mugong("mugong_other_character", {"character_restriction": "viper"}),
	}


func _mugong(perk_id: String, extra: Dictionary = {}) -> Dictionary:
	var data := {
		"id": perk_id,
		"name": perk_id,
		"max_level": 5,
	}
	data.merge(extra, true)
	return data


func _chosik(perk_id: String, skill_id: String) -> Dictionary:
	return {
		"id": perk_id,
		"name": perk_id,
		"max_level": 1,
		"unlocks_skill": skill_id,
		"character_restriction": "smasher",
	}


func _offer_choices(offer: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = offer.get("choices", [])
	if value is Array:
		for choice_value in value as Array:
			if choice_value is Dictionary:
				result.append(choice_value as Dictionary)
	return result


func _choice_ids(choices: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for choice in choices:
		result.append(str(choice.get("id", "")))
	return result


func _kind_count(choices: Array[Dictionary], kind: String) -> int:
	var count := 0
	for choice in choices:
		if str(choice.get("start_card_kind", "")) == kind:
			count += 1
	return count


func _find_kind_index(choices: Array[Dictionary], kind: String) -> int:
	for index in range(choices.size()):
		if str(choices[index].get("start_card_kind", "")) == kind:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
