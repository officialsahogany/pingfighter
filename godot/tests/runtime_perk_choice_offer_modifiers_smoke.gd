extends SceneTree

const RuntimePerkChoiceOfferModifiers := preload("res://scripts/characters/runtime_perk_choice_offer_modifiers.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_mythic_runtime_bridge()
	_verify_target_choice_count()
	_verify_dowsing_bonus_state_update()
	_verify_perk_slot_status_copy()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_offer_modifiers_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_mythic_runtime_bridge() -> void:
	var helper := RuntimePerkChoiceOfferModifiers.new()
	var owner := FakeOwner.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new({"mythic_item_runtime": mythic_runtime})
	_expect(helper.get_item_perk_choice_count_bonus(owner, registry, Callable(self, "_get_instance")) == 2, "choice-count bonus should come from mythic runtime")
	mythic_runtime.choice_bonus = -4
	_expect(helper.get_item_perk_choice_count_bonus(owner, registry, Callable(self, "_get_instance")) == 0, "choice-count bonus should clamp below zero")
	helper.reset_megingjord_extra_pick_count(owner, registry, Callable(self, "_get_instance"))
	_expect(mythic_runtime.batch_reset_count == 1, "new perk-choice batch should reset Megingjord counter")
	helper.reset_megingjord_extra_pick_count_for_new_choices(owner, registry, Callable(self, "_get_instance"), 3)
	_expect(mythic_runtime.batch_reset_count == 4, "new pending choice count should reset Megingjord once per granted choice")
	helper.reset_megingjord_extra_pick_count_for_new_choices(owner, registry, Callable(self, "_get_instance"), -2)
	_expect(mythic_runtime.batch_reset_count == 4, "negative pending choice count should not reset Megingjord")
	mythic_runtime.next_extra_pick = true
	_expect(helper.try_megingjord_extra_pick("smash_power", owner, registry, Callable(self, "_get_instance")), "Megingjord extra pick should forward selected choice id")
	_expect(mythic_runtime.last_choice_id == "smash_power", "Megingjord helper should preserve choice id")
	_expect(not helper.try_megingjord_extra_pick("smash_power", owner, FakeRegistry.new({}), Callable(self, "_get_instance")), "missing mythic runtime should not grant an extra pick")


func _verify_target_choice_count() -> void:
	var helper := RuntimePerkChoiceOfferModifiers.new()
	_expect(helper.build_target_choice_count(3, 2) == 5, "target choice count should include item bonus choices")
	_expect(helper.build_target_choice_count(3, -2) == 3, "target choice count should ignore negative item bonuses")
	_expect(helper.build_target_choice_count(-3, 1) == 0, "target choice count should clamp below zero")


func _verify_dowsing_bonus_state_update() -> void:
	var helper := RuntimePerkChoiceOfferModifiers.new()
	var choices: Array = [
		{"id": "a"},
		{"id": "b"},
		{"id": "c", "nested": {"value": 1}},
		{"id": "d"},
	]
	var rejected: Dictionary = helper.build_dowsing_bonus_state_update(choices, 0, 3)
	_expect(not bool(rejected.get("accepted", true)), "no item bonus should skip Dowsing mark")

	var update: Dictionary = helper.build_dowsing_bonus_state_update(choices, 1, 3)
	_expect(bool(update.get("accepted", false)), "valid item bonus should mark Dowsing bonus card")
	_expect(int(update.get("bonus_card_index", -1)) == 2, "Dowsing bonus should mark the penultimate card")
	var next_choices: Array = _get_array(update.get("current_choices", []))
	var marked_choice: Dictionary = _get_dict(next_choices[2])
	_expect(bool(marked_choice.get("is_dowsing_goggles_bonus", false)), "Dowsing bonus card should be flagged")
	_expect(str(marked_choice.get("bonus_source_item", "")) == RuntimePerkChoiceOfferModifiers.DOWSING_GOGGLES_BONUS_SOURCE, "Dowsing bonus source should be helper-owned")
	_get_dict(_get_dict(marked_choice.get("nested", {})))["value"] = 9
	_expect(int(_get_dict(_get_dict(choices[2]).get("nested", {})).get("value", 0)) == 1, "Dowsing update should deep-copy choices")


func _verify_perk_slot_status_copy() -> void:
	var helper := RuntimePerkChoiceOfferModifiers.new()
	var catalog := FakeCatalog.new()
	var status: Dictionary = helper.build_perk_slot_status(catalog, {"dash": 1}, FakeRegistry.new({}))
	_expect(int(status.get("count", 0)) == 1, "slot status should come from catalog")
	_get_dict(status.get("nested", {}))["limit"] = 99
	_expect(int(_get_dict(catalog.status.get("nested", {})).get("limit", 0)) == 12, "slot status should be deep-copied")
	_expect(helper.build_perk_slot_status(null, {}, null).is_empty(), "missing catalog should return empty slot status")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var open_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	var collection_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	var finish_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	_expect(state_source.find("RuntimePerkChoiceOfferModifiers") >= 0, "state should preload choice offer modifier helper")
	_expect(state_source.find("RuntimePerkChoiceOpenFlow") >= 0, "state should preload choice open-flow helper")
	_expect(open_flow_source.find("build_target_choice_count") >= 0, "open-flow should consume helper-owned target choice-count calculation")
	_expect(open_flow_source.find("build_dowsing_bonus_state_update") >= 0, "open-flow should consume Dowsing bonus state update helper")
	_expect(open_flow_source.find("build_perk_slot_status") >= 0, "open-flow should consume slot-status helper")
	_expect(state_source.find("RuntimePerkStarpointCollectionFlow") >= 0, "state should preload starpoint collection-flow helper")
	_expect(collection_flow_source.find("reset_megingjord_extra_pick_count_for_new_choices") >= 0, "collection flow should consume helper-owned Megingjord batch-reset helper")
	_expect(state_source.find("_choice_finish_flow.finish_successful_choice") >= 0, "state should route successful choice finish through finish-flow helper")
	_expect(finish_flow_source.find("try_megingjord_extra_pick") >= 0, "finish-flow helper should consume Megingjord extra-pick helper")
	_expect(state_source.find("get_runtime_perk_choice_count_bonus") < 0, "state should not call mythic choice-count API directly")
	_expect(state_source.find("on_new_perk_choice_batch") < 0, "state should not call Megingjord reset API directly")
	_expect(state_source.find("try_after_perk_choice") < 0, "state should not call Megingjord extra-pick API directly")
	_expect(finish_flow_source.find("try_after_perk_choice") < 0, "finish-flow helper should not call Megingjord extra-pick API directly")
	_expect(state_source.find(".get_perk_slot_status(") < 0, "state should not call perk-slot status API directly")
	var collect_body: String = _function_body(state_source, "func collect_star_points(")
	_expect(collect_body.find("for _index in range(int(collection_apply_result.get(\"new_pending_choice_count\"") < 0, "collect body should not own Megingjord batch-reset loop inline")
	_expect(collect_body.find("reset_megingjord_extra_pick_count(") < 0, "collect body should not call single Megingjord reset inline")
	var open_body: String = _function_body(state_source, "func open_next_choice(")
	_expect(open_body.find("BASE_PERK_CHOICE_COUNT + item_bonus_choice_count") < 0, "open-next body should not own target choice-count arithmetic inline")
	_expect(open_body.find("max(0, BASE_PERK_CHOICE_COUNT") < 0, "open-next body should not own target choice-count clamp inline")


func _get_instance(registry: Object, key: String) -> Object:
	return registry.get_instance(key)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	pass


class FakeMythicRuntime:
	var choice_bonus := 2
	var batch_reset_count := 0
	var next_extra_pick := false
	var last_choice_id := ""

	func get_runtime_perk_choice_count_bonus(_owner: Object, _registry: Object) -> int:
		return choice_bonus

	func on_new_perk_choice_batch(_owner: Object) -> void:
		batch_reset_count += 1

	func try_after_perk_choice(choice_id: String, _owner: Object, _registry: Object) -> bool:
		last_choice_id = choice_id
		return next_extra_pick


class FakeCatalog:
	var status := {"count": 1, "nested": {"limit": 12}}

	func get_perk_slot_status(_runtime_skill_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return status


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)
