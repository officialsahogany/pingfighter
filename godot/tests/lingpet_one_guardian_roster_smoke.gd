extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetSaveRestorePlanner := preload("res://scripts/lingpet/lingpet_save_restore_planner.gd")
const LingpetOverflowChoiceState := preload("res://scripts/lingpet/lingpet_overflow_choice_state.gd")
const LingpetOverflowReplacePlan := preload("res://scripts/lingpet/lingpet_overflow_replace_plan.gd")
const LingpetOverflowChoiceOverlayHost := preload("res://scripts/hud/lingpet_overflow_choice_overlay_host.gd")
const LingpetGuardianEnhanceOfferEngine := preload("res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var lingpet_id := "maribo"
	var lingpet_state := "companion"
	var lingpet_owned_pet_ids: Array = ["maribo", "lunabi", "milkring"]
	var owned_lingpet_ids: Array = lingpet_owned_pet_ids.duplicate()
	var owned_ringpet_ids: Array = lingpet_owned_pet_ids.duplicate()
	var lingpet_collection: Dictionary = {"maribo": true, "lunabi": true, "milkring": true}
	var ringpet_collection: Dictionary = lingpet_collection.duplicate(true)
	var owned_lingpets: Dictionary = lingpet_collection.duplicate(true)
	var owned_ringpets: Dictionary = lingpet_collection.duplicate(true)
	var lingpet_slots: Array = ["", "lunabi", "maribo"]
	var ringpet_slots: Array = lingpet_slots.duplicate()
	var lingpet_slot_pet_ids: Array = lingpet_slots.duplicate()
	var ringpet_slot_pet_ids: Array = lingpet_slots.duplicate()
	var lingpet_active_slot_index := 2
	var ringpet_active_slot_index := 2


class FakeChoiceRuntime:
	extends RefCounted
	var snapshot := {
		"active": true,
		"absorb_only": false,
	}
	var replace_count := 0
	var absorb_count := 0

	func is_overflow_choice_active() -> bool:
		return true

	func get_overflow_choice_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func commit_overflow_replace(_slot_index: int, _owner: Object, _registry: Object) -> bool:
		replace_count += 1
		return true

	func commit_overflow_absorb(_owner: Object, _registry: Object) -> bool:
		absorb_count += 1
		return true


func _init() -> void:
	_verify_live_roster_and_collection_history_are_separate()
	_verify_legacy_three_slot_restore_takes_first_valid_only()
	_verify_collection_complete_eggs_become_absorb_only()
	_verify_two_choice_and_absorb_source_localization()
	_verify_two_choice_input_routes()
	_verify_retired_cycle_source_is_absent()
	_verify_round_reset_closes_absorb_presentation()
	if _failures.is_empty():
		print("lingpet_one_guardian_roster_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_live_roster_and_collection_history_are_separate() -> void:
	var owner := FakeOwner.new()
	var state := LingpetCollectionState.new()
	state.sync_from_owner(owner)
	_expect(state.get_owned_pet_ids() == ["lunabi"], "legacy live roster must prefer the first valid battle slot")
	_expect(state.get_battle_slots() == ["lunabi"], "legacy slot array must adopt only its first valid slot")
	var collected: Array[String] = state.get_collected_pet_ids()
	for pet_id in ["maribo", "lunabi", "milkring"]:
		_expect(collected.has(pet_id), "legacy ids must survive as permanent collection history: %s" % pet_id)
	var replaced: Dictionary = state.replace_slot(owner, 0, "volty")
	_expect(str(replaced.get("new_pet_id", "")) == "volty", "slot zero replacement must accept one incoming guardian")
	_expect(owner.lingpet_owned_pet_ids == ["volty"], "owner live roster must stay capped at one")
	for pet_id in ["maribo", "lunabi", "milkring", "volty"]:
		_expect(bool(owner.lingpet_collection.get(pet_id, false)), "replacement must preserve collection history: %s" % pet_id)


func _verify_legacy_three_slot_restore_takes_first_valid_only() -> void:
	var state := LingpetCollectionState.new()
	var planner := LingpetSaveRestorePlanner.new()
	var plan: Dictionary = planner.build_plan({
		"state": "companion",
		"pet_id": "maribo",
		"owned_pet_ids": ["volty", "milkring", "maribo"],
		"battle_slot_pet_ids": ["", "lunabi", "maribo"],
		"active_slot_index": 2,
	}, null, state, "maribo", "companion")
	_expect(str(plan.get("pet_id", "")) == "lunabi", "legacy restore must choose the first valid slot, not the old active index")
	_expect(state.get_owned_pet_ids() == ["lunabi"], "legacy restore must publish one live owner")
	_expect(state.get_battle_slots() == ["lunabi"], "legacy restore must shrink slots to one entry")
	var collected: Array[String] = state.get_collected_pet_ids()
	for pet_id in ["volty", "milkring", "maribo"]:
		_expect(collected.has(pet_id), "legacy owned ids must migrate into collection history: %s" % pet_id)


func _verify_collection_complete_eggs_become_absorb_only() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo"]
	owner.ringpet_slots = ["maribo"]
	owner.lingpet_slot_pet_ids = ["maribo"]
	owner.ringpet_slot_pet_ids = ["maribo"]
	var all_collected: Dictionary = {}
	for pet_id in LingpetCatalog.get_pet_ids():
		all_collected[pet_id] = true
	owner.lingpet_collection = all_collected.duplicate(true)
	owner.ringpet_collection = all_collected.duplicate(true)
	owner.owned_lingpets = all_collected.duplicate(true)
	owner.owned_ringpets = all_collected.duplicate(true)
	var state := LingpetCollectionState.new()
	_expect(state.should_spawn_egg(owner), "collection completion must not suppress later eggs")
	var hatch_pet_id := state.pick_hatch_pet_id(owner)
	_expect(hatch_pet_id != "", "collection-complete egg must still choose an enabled hatch identity")
	_expect(state.is_absorb_only_candidate(owner, hatch_pet_id), "collection-complete hatch must be marked absorb-only")
	var choice := LingpetOverflowChoiceState.new()
	choice.begin_main_overflow(hatch_pet_id, true)
	var plan: Dictionary = LingpetOverflowReplacePlan.new().consume(owner, 0, choice, state)
	_expect(not bool(plan.get("handled", false)), "absorb-only hatch must reject replacement")


func _verify_two_choice_and_absorb_source_localization() -> void:
	for language in ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]:
		var choice_copy := LingpetOverflowChoiceOverlayHost.get_copy_for_language_for_tests(language)
		_expect(str(choice_copy.get("replace", "")).strip_edges() != "", "%s must localize Replace" % language)
		_expect(str(choice_copy.get("absorb", "")).strip_edges() != "", "%s must localize Absorb" % language)
		_expect(str(choice_copy.get("absorb_desc", "")).strip_edges() != "", "%s must explain the enhancement reward" % language)
		var result_copy := LingpetGuardianEnhanceOfferEngine.get_result_copy_for_language_for_tests(language)
		_expect(str(result_copy.get("source_absorb", "")).strip_edges() != "", "%s must localize the absorption result source" % language)


func _verify_two_choice_input_routes() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeChoiceRuntime.new()
	var host := LingpetOverflowChoiceOverlayHost.new()
	var key_one := InputEventKey.new()
	key_one.pressed = true
	key_one.keycode = KEY_1
	_expect(host.handle_input(key_one, runtime, owner, null, Vector2(760.0, 750.0)), "Replace shortcut must be consumed")
	_expect(runtime.replace_count == 1 and runtime.absorb_count == 0, "normal Replace shortcut must use production replace commit")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_expect(host.handle_input(escape, runtime, owner, null, Vector2(760.0, 750.0)), "escape must be consumed")
	_expect(runtime.absorb_count == 1, "escape must safely choose production absorption")
	var absorb_only_runtime := FakeChoiceRuntime.new()
	absorb_only_runtime.snapshot["absorb_only"] = true
	var absorb_only_host := LingpetOverflowChoiceOverlayHost.new()
	_expect(absorb_only_host.handle_input(key_one, absorb_only_runtime, owner, null, Vector2(760.0, 750.0)), "absorb-only Replace shortcut must be consumed")
	_expect(absorb_only_runtime.replace_count == 0 and absorb_only_runtime.absorb_count == 1, "absorb-only hatch must not reach replacement even through the Replace shortcut")


func _verify_retired_cycle_source_is_absent() -> void:
	var router_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(router_source.find("LINGPET_CYCLE_KEY") < 0 and router_source.find("cycle_lingpet_slot") < 0, "battle input router must retire L/Shift+L cycling")
	_expect(runtime_source.find("func cycle_lingpet_slot") < 0, "one-guardian runtime must retire cycle API")


func _verify_round_reset_closes_absorb_presentation() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var reset_start := runtime_source.find("func reset_round(")
	var reset_end := runtime_source.find("\nfunc ", reset_start + 1)
	var reset_body := runtime_source.substr(reset_start, reset_end - reset_start)
	var absorb_at := reset_body.find("commit_overflow_absorb(owner, registry)")
	var close_after_absorb_at := reset_body.find("cancel_guardian_enhance_cutin(registry)", absorb_at + 1)
	_expect(absorb_at >= 0, "round reset must settle an unanswered hatch through absorption")
	_expect(close_after_absorb_at > absorb_at, "round reset must close the compact enhancement presentation reopened by absorption")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
