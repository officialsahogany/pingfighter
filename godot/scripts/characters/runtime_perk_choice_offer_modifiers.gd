extends RefCounted

const MYTHIC_ITEM_RUNTIME_KEY := "mythic_item_runtime"
const DOWSING_GOGGLES_BONUS_SOURCE := "dowsing_goggles"


func get_item_perk_choice_count_bonus(owner: Object, registry: Object, get_instance: Callable) -> int:
	var mythic_item_runtime: Object = _get_mythic_item_runtime(registry, get_instance)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("get_runtime_perk_choice_count_bonus"):
		return 0
	return max(0, int(mythic_item_runtime.get_runtime_perk_choice_count_bonus(owner, registry)))


func build_target_choice_count(base_choice_count: int, item_bonus_choice_count: int) -> int:
	return max(0, int(base_choice_count) + max(0, int(item_bonus_choice_count)))


func build_dowsing_bonus_state_update(
	choices: Array,
	item_bonus_choice_count: int,
	target_choice_count: int
) -> Dictionary:
	if item_bonus_choice_count <= 0:
		return {"accepted": false}
	if choices.size() < target_choice_count + 1:
		return {"accepted": false}
	var next_choices := choices.duplicate(true)
	var bonus_card_index: int = next_choices.size() - 2
	var bonus_choice: Dictionary = _get_dict(next_choices[bonus_card_index]).duplicate(true)
	bonus_choice["is_dowsing_goggles_bonus"] = true
	bonus_choice["bonus_source_item"] = DOWSING_GOGGLES_BONUS_SOURCE
	next_choices[bonus_card_index] = bonus_choice
	return {
		"accepted": true,
		"current_choices": next_choices,
		"bonus_card_index": bonus_card_index,
	}


func build_perk_slot_status(catalog: Object, runtime_skill_levels: Dictionary, registry: Object) -> Dictionary:
	if catalog == null or not catalog.has_method("get_perk_slot_status"):
		return {}
	var status_value: Variant = catalog.get_perk_slot_status(runtime_skill_levels, registry)
	if status_value is Dictionary:
		return (status_value as Dictionary).duplicate(true)
	return {}


func reset_megingjord_extra_pick_count(owner: Object, registry: Object, get_instance: Callable) -> void:
	var mythic_item_runtime: Object = _get_mythic_item_runtime(registry, get_instance)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("on_new_perk_choice_batch"):
		mythic_item_runtime.on_new_perk_choice_batch(owner)


func reset_megingjord_extra_pick_count_for_new_choices(
	owner: Object,
	registry: Object,
	get_instance: Callable,
	new_choice_count: int
) -> void:
	for _index in range(max(0, new_choice_count)):
		reset_megingjord_extra_pick_count(owner, registry, get_instance)


func try_megingjord_extra_pick(choice_id: String, owner: Object, registry: Object, get_instance: Callable) -> bool:
	var mythic_item_runtime: Object = _get_mythic_item_runtime(registry, get_instance)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_after_perk_choice"):
		return false
	return bool(mythic_item_runtime.try_after_perk_choice(choice_id, owner, registry))


func _get_mythic_item_runtime(registry: Object, get_instance: Callable) -> Object:
	if not get_instance.is_valid():
		return null
	return get_instance.call(registry, MYTHIC_ITEM_RUNTIME_KEY)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
