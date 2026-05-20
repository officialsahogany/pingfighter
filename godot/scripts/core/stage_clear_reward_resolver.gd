extends RefCounted

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")

const REWARD_ACTIVE := "active"
const REWARD_PASSIVE := "passive"
const REWARD_MYTHIC := "mythic"
const REWARD_STARPOINT := "starpoint"

const NORMAL_ACTIVE_WEIGHT := 45.0
const NORMAL_PASSIVE_WEIGHT := 20.0
const NORMAL_STARPOINT_WEIGHT := 30.0
const NORMAL_MYTHIC_WEIGHT := 5.0
const STARPOINT_REWARD_MIN := 1
const STARPOINT_REWARD_MAX := 1

var _spawn_pool: Object = ActiveItemFieldSpawnPool.new()


func roll_reward(box_kind: String, owner: Object = null, registry: Object = null) -> Dictionary:
	if box_kind == REWARD_MYTHIC:
		return _roll_item_reward(REWARD_MYTHIC, owner, registry)

	var total_weight: float = (
		NORMAL_ACTIVE_WEIGHT
		+ NORMAL_PASSIVE_WEIGHT
		+ NORMAL_STARPOINT_WEIGHT
		+ NORMAL_MYTHIC_WEIGHT
	)
	var roll: float = randf() * max(0.001, total_weight)
	if roll < NORMAL_ACTIVE_WEIGHT:
		return _roll_item_reward(REWARD_ACTIVE, owner, registry)
	roll -= NORMAL_ACTIVE_WEIGHT
	if roll < NORMAL_PASSIVE_WEIGHT:
		return _roll_item_reward(REWARD_PASSIVE, owner, registry)
	roll -= NORMAL_PASSIVE_WEIGHT
	if roll < NORMAL_STARPOINT_WEIGHT:
		return _roll_starpoint_reward()
	return _roll_item_reward(REWARD_MYTHIC, owner, registry)


func grant_rewards(rewards: Array, owner: Object, registry: Object) -> Dictionary:
	var summary := {
		"attempted": 0,
		"granted": 0,
		"active_granted": 0,
		"passive_granted": 0,
		"mythic_granted": 0,
		"starpoint_granted": 0,
		"failed": [],
	}
	for reward_value in rewards:
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		var reward_type: String = str(reward.get("type", ""))
		if reward_type == "":
			continue
		summary["attempted"] = int(summary["attempted"]) + 1
		var granted := false
		match reward_type:
			REWARD_ACTIVE:
				granted = _grant_active_reward(reward, owner, registry)
				if granted:
					summary["active_granted"] = int(summary["active_granted"]) + 1
			REWARD_PASSIVE:
				granted = _grant_equipment_reward(reward, owner, registry)
				if granted:
					summary["passive_granted"] = int(summary["passive_granted"]) + 1
			REWARD_MYTHIC:
				granted = _grant_equipment_reward(reward, owner, registry)
				if granted:
					summary["mythic_granted"] = int(summary["mythic_granted"]) + 1
			REWARD_STARPOINT:
				granted = _grant_starpoint_reward(reward, owner, registry)
				if granted:
					summary["starpoint_granted"] = int(summary["starpoint_granted"]) + int(reward.get("amount", 0))
		if granted:
			summary["granted"] = int(summary["granted"]) + 1
		else:
			var failed_value: Variant = summary.get("failed", [])
			var failed: Array = failed_value if failed_value is Array else []
			failed.append(reward.duplicate(true))
			summary["failed"] = failed
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return summary


func _roll_item_reward(reward_group: String, owner: Object, registry: Object) -> Dictionary:
	var candidates: Array = _build_candidates_for_group(reward_group, owner, registry)
	var item_data: Dictionary = _pick_weighted_candidate(candidates)
	if item_data.is_empty():
		return _build_placeholder_item_reward(reward_group)
	return _build_item_reward(reward_group, item_data)


func _roll_starpoint_reward() -> Dictionary:
	var amount: int = randi_range(STARPOINT_REWARD_MIN, STARPOINT_REWARD_MAX)
	return {
		"type": REWARD_STARPOINT,
		"label": "★ %d" % amount,
		"amount": amount,
	}


func _build_candidates_for_group(reward_group: String, owner: Object, registry: Object) -> Array:
	var candidates: Array = []
	if _spawn_pool == null or not _spawn_pool.has_method("build_spawn_candidates"):
		return candidates
	for item_value in _spawn_pool.build_spawn_candidates(registry, owner):
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		if _get_item_group(item_data) == reward_group:
			candidates.append(item_data.duplicate(true))
	return candidates


func _pick_weighted_candidate(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}

	var total_weight := 0.0
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		total_weight += max(0.0, float(candidate.get("chance", 0.0)))

	if total_weight <= 0.0:
		var index: int = randi() % candidates.size()
		var fallback_value: Variant = candidates[index]
		if fallback_value is Dictionary:
			var fallback: Dictionary = fallback_value
			return fallback.duplicate(true)
		return {}

	var roll: float = randf() * total_weight
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		roll -= max(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	var last_value: Variant = candidates.back()
	if last_value is Dictionary:
		var last: Dictionary = last_value
		return last.duplicate(true)
	return {}


func _build_item_reward(reward_group: String, item_data: Dictionary) -> Dictionary:
	var item_name: String = str(item_data.get("name", ""))
	var display_name: String = str(item_data.get("display_name", item_name))
	var rolls: Dictionary = _get_dict(item_data.get("rolls", {})).duplicate(true)
	return {
		"type": reward_group,
		"label": display_name if display_name != "" else _fallback_item_label(reward_group),
		"item_name": item_name,
		"icon_path": str(item_data.get("icon_path", "")),
		"amount": 1,
		"rolls": rolls,
		"item_data": item_data.duplicate(true),
	}


func _build_placeholder_item_reward(reward_group: String) -> Dictionary:
	return {
		"type": reward_group,
		"label": _fallback_item_label(reward_group),
		"amount": 1,
	}


func _fallback_item_label(reward_group: String) -> String:
	match reward_group:
		REWARD_ACTIVE:
			return "액티브 아이템"
		REWARD_PASSIVE:
			return "패시브 아이템"
		REWARD_MYTHIC:
			return "신화 아이템"
	return "보상"


func _grant_active_reward(reward: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = _get_reward_item_name(reward)
	if item_name == "":
		return false
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("grant_item_to_slot"):
		return false
	return bool(active_item_runtime.grant_item_to_slot(item_name, owner, registry, true))


func _grant_equipment_reward(reward: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = _get_reward_item_name(reward)
	if item_name == "":
		return false
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("acquire_item"):
		return false
	var rolls: Dictionary = _get_dict(reward.get("rolls", {})).duplicate(true)
	var acquired_item_data: Dictionary = _get_dict(reward.get("item_data", {})).duplicate(true)
	var inventory_index: int = int(mythic_item_runtime.acquire_item(
		item_name,
		owner,
		registry,
		rolls,
		true,
		false,
		acquired_item_data
	))
	if inventory_index < 0:
		return false
	if bool(reward.get("show_acquisition_cinematic", false)):
		_try_start_acquisition_cinematic(reward, owner, registry, mythic_item_runtime, inventory_index, acquired_item_data)
	return true


func _grant_starpoint_reward(reward: Dictionary, owner: Object, registry: Object) -> bool:
	var amount: int = max(0, int(reward.get("amount", 0)))
	if amount <= 0:
		return false
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var runtime_perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	if runtime_perk_state == null or runtime_perk_catalog == null:
		return false
	if not runtime_perk_state.has_method("collect_star_points"):
		return false
	var defer_choice_open: bool = bool(reward.get("defer_choice_open", false))
	runtime_perk_state.collect_star_points(
		amount,
		_get_selected_character_type(owner),
		runtime_perk_catalog,
		owner,
		registry,
		defer_choice_open
	)
	return true


func _get_item_group(item_data: Dictionary) -> String:
	var item_type: String = str(item_data.get("type", "active"))
	var rarity: String = str(item_data.get("rarity", ""))
	if item_type == REWARD_MYTHIC or rarity == REWARD_MYTHIC:
		return REWARD_MYTHIC
	if item_type == REWARD_PASSIVE or rarity == REWARD_PASSIVE:
		return REWARD_PASSIVE
	return REWARD_ACTIVE


func _get_reward_item_name(reward: Dictionary) -> String:
	var item_name: String = str(reward.get("item_name", ""))
	if item_name != "":
		return item_name
	var item_data: Dictionary = _get_dict(reward.get("item_data", {}))
	return str(item_data.get("name", ""))


func _try_start_acquisition_cinematic(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	mythic_item_runtime: Object,
	inventory_index: int,
	fallback_item_data: Dictionary
) -> void:
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("start_acquisition_cinematic"):
		return
	var acquired_item_data: Dictionary = fallback_item_data.duplicate(true)
	if mythic_item_runtime.has_method("get_inventory_item"):
		var inventory_item_value: Variant = mythic_item_runtime.get_inventory_item(inventory_index)
		if inventory_item_value is Dictionary and not (inventory_item_value as Dictionary).is_empty():
			acquired_item_data = (inventory_item_value as Dictionary).duplicate(true)
	if acquired_item_data.is_empty():
		return
	var pickup_position: Vector2 = _get_vector2(reward.get("pickup_position", Vector2(380.0, 375.0)), Vector2(380.0, 375.0))
	var target_player_center: Vector2 = _get_vector2(reward.get("target_player_center", Vector2.INF), Vector2.INF)
	mythic_item_runtime.start_acquisition_cinematic(
		acquired_item_data,
		pickup_position,
		owner,
		registry,
		target_player_center
	)


func _get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null or str(value) == "":
		return "smasher"
	return str(value)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
