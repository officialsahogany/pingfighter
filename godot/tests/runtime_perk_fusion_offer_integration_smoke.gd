extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

var _failures: Array[String] = []


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	state.choice_active = true
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "reserved", "offer_lane": "owned_upgrade_reserved", "offer_protected": true},
		{"id": "ordinary_2", "offer_lane": "replaceable", "offer_protected": false},
	]

	var plan: Dictionary = state._try_inject_perk_fusion_offer(catalog, 0.0, 0.0)
	_expect(bool(plan.get("rolled", false)), "eligible battle offer should perform one appearance roll")
	_expect(bool(plan.get("appeared", false)), "forced zero roll should inject the fusion card")
	_expect(str((state.current_choices[0] as Dictionary).get("id", "")) == "perk_fusion", "only replaceable lane should become fusion")
	_expect(str((state.current_choices[1] as Dictionary).get("id", "")) == "reserved", "reserved lane should remain unchanged")
	_expect(not _has_choice(state.current_choices, "convert_to_gold"), "normal fusion offers should not depend on the retired gold lane")

	# Production order is fusion -> Dice -> training. Once fusion replaced a
	# base lane, training must skip the whole screen so only one system
	# replacement can consume the three-card offer.
	var dice_result: Dictionary = state._try_inject_mystic_dice_offer(0.25)
	var count_before_training := state.current_choices.size()
	var metrics_before_training: Dictionary = state.get_physique_training_snapshot()
	var training_result := state._try_inject_physique_training_offer(
		bool(dice_result.get("appeared", false)),
		bool(plan.get("appeared", false)),
		0.0,
		0.0,
		0.0
	)
	var metrics_after_training: Dictionary = state.get_physique_training_snapshot()
	_expect(_has_choice(state.current_choices, "perk_fusion"), "training skip should preserve the fusion card")
	_expect(not _has_training_choice(state.current_choices), "training must not coexist with a fusion replacement")
	_expect(state.current_choices.size() == count_before_training, "fusion-skip should preserve the offer card count")
	_expect(bool(training_result.get("skipped_for_perk_fusion", false)), "fusion-skip should be explicit in the result contract")
	_expect(metrics_after_training.get("eligible_screen_count_before_dice_exhaustion", -1) == metrics_before_training.get("eligible_screen_count_before_dice_exhaustion", -2), "fusion-skip should not enter training eligibility metrics")
	_expect(not _has_choice(state.current_choices, "mystic_dice"), "Dice and training auxiliary cards must remain mutually exclusive")

	var denied_state := RuntimePerkState.new()
	denied_state.runtime_skill_levels = state.runtime_skill_levels.duplicate(true)
	denied_state.choice_active = true
	denied_state.current_choice_context = {"source": "plaza_academy"}
	denied_state.current_choices = [
		{"id": "ordinary", "offer_lane": "replaceable", "offer_protected": false},
	]
	var denied: Dictionary = denied_state._try_inject_perk_fusion_offer(catalog, 0.0, 0.0)
	_expect(not bool(denied.get("rolled", true)), "plaza source should fail closed before appearance roll")
	_expect(str((denied_state.current_choices[0] as Dictionary).get("id", "")) == "ordinary", "denied source should preserve its exact offer")

	# 실 open_next_choice 관통(결정적 seam): 오퍼 주입이 실 open 경로에
	# 배선돼 있음을 fallback 없이 봉인한다. seam은 일회성 소비다.
	var real_state := RuntimePerkState.new()
	real_state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	real_state.pending_skill_choices = 1
	# The fusion seam fixes only the post-generation appearance/replacement rolls.
	# Seed the preceding base-card generation too so this real-path leg cannot
	# intermittently produce a non-replaceable fixture before the seam is reached.
	seed(5521)
	real_state.set_test_perk_fusion_offer_roll_override(0.0, 0.0)
	real_state.open_next_choice("smasher", catalog, true, null, null, null, {"source": "battle_starpoint"})
	var real_fusion_found := false
	for real_choice: Variant in real_state.current_choices:
		if real_choice is Dictionary and str((real_choice as Dictionary).get("id", "")) == "perk_fusion":
			real_fusion_found = true
	_expect(real_fusion_found, "the real open_next_choice path should expose the fusion card deterministically through the seam")
	_expect(real_state._test_perk_fusion_offer_roll_override.is_empty(), "the deterministic offer seam must be one-shot")

	var collection_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	_expect(collection_source.contains("{\"source\": \"battle_starpoint\"}"), "battle starpoint opener should stamp the allowlisted source explicitly")

	if _failures.is_empty():
		PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
		print("runtime_perk_fusion_offer_integration_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_choice(choices: Array, choice_id: String) -> bool:
	for value: Variant in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return true
	return false


func _has_training_choice(choices: Array) -> bool:
	for value: Variant in choices:
		if value is Dictionary and bool((value as Dictionary).get("is_physique_training", false)):
			return true
	return false
