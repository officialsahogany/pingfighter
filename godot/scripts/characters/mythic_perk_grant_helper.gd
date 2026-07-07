extends RefCounted

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const REWARD_MYTHIC_PERK := "mythic_perk"
const REWARD_STARPOINT := "starpoint"
const FALLBACK_STARPOINT_AMOUNT := 3
const MYTHIC_PERK_IDS := [
	"megingjord",
	"transcendent_crown",
	"ragnarok_hammer",
	"hermes_shoes",
	"poseidon_trident",
	"heavenly_cape",
	"horn_strawberry_mask",
	"odins_eye",
	"celestial_armor",
	"baal_boots",
	"pandora_legacy",
]


static func build_reward(owner: Object, registry: Object, fallback_starpoints: int = FALLBACK_STARPOINT_AMOUNT) -> Dictionary:
	if not _has_open_perk_slot(registry):
		return build_starpoint_fallback_reward(fallback_starpoints)
	var perk_id: String = pick_random_unowned_mythic_perk_id(registry)
	if perk_id == "":
		return build_starpoint_fallback_reward(fallback_starpoints)
	return build_reward_for_perk(perk_id, owner, registry, fallback_starpoints)


static func build_reward_for_perk(
	perk_id: String,
	_owner: Object,
	registry: Object,
	fallback_starpoints: int = FALLBACK_STARPOINT_AMOUNT
) -> Dictionary:
	perk_id = perk_id.strip_edges()
	if perk_id == "":
		return build_starpoint_fallback_reward(fallback_starpoints)
	if not _has_open_perk_slot(registry):
		return build_starpoint_fallback_reward(fallback_starpoints)
	var perk_data: Dictionary = _get_perk_data(registry, perk_id)
	var label: String = str(perk_data.get("name", perk_id))
	return {
		"type": REWARD_MYTHIC_PERK,
		"label": label,
		"id": perk_id,
		"perk_id": perk_id,
		"amount": 1,
		"max_level": int(perk_data.get("max_level", 1)),
		"rarity": "mythic",
		"perk_data": perk_data,
		"fallback_starpoints": max(1, fallback_starpoints),
	}


static func build_starpoint_fallback_reward(amount: int = FALLBACK_STARPOINT_AMOUNT) -> Dictionary:
	amount = clampi(amount, 1, 3)
	return {
		"type": REWARD_STARPOINT,
		"label": "★%d" % amount,
		"amount": amount,
		"mythic_perk_fallback": true,
	}


static func grant_reward(reward: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == REWARD_STARPOINT:
		return _grant_starpoints(reward, owner, registry, int(reward.get("amount", FALLBACK_STARPOINT_AMOUNT)))
	if reward_type != REWARD_MYTHIC_PERK:
		return {"granted": false, "reward_type": reward_type}
	if not _has_open_perk_slot(registry):
		return _grant_starpoints(reward, owner, registry, int(reward.get("fallback_starpoints", FALLBACK_STARPOINT_AMOUNT)))

	var perk_id: String = str(reward.get("perk_id", reward.get("id", ""))).strip_edges()
	if perk_id == "" or _get_runtime_perk_level(registry, perk_id) > 0:
		perk_id = pick_random_unowned_mythic_perk_id(registry)
	if perk_id == "":
		return _grant_starpoints(reward, owner, registry, int(reward.get("fallback_starpoints", FALLBACK_STARPOINT_AMOUNT)))

	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("apply_choice"):
		return {"granted": false, "reward_type": REWARD_MYTHIC_PERK, "perk_id": perk_id}
	var choice: Dictionary = _get_perk_data(registry, perk_id)
	if choice.is_empty():
		choice = {"id": perk_id, "name": perk_id, "max_level": 1}
	choice["id"] = perk_id
	if not bool(runtime_perk_state.apply_choice(choice, owner, registry)):
		return {"granted": false, "reward_type": REWARD_MYTHIC_PERK, "perk_id": perk_id}
	return {
		"granted": true,
		"reward_type": REWARD_MYTHIC_PERK,
		"perk_id": perk_id,
		"fallback_starpoint": false,
		"starpoint_amount": 0,
	}


static func pick_random_unowned_mythic_perk_id(registry: Object) -> String:
	var candidates: Array[String] = []
	for perk_id_value in MYTHIC_PERK_IDS:
		var perk_id: String = str(perk_id_value)
		if _get_runtime_perk_level(registry, perk_id) <= 0:
			candidates.append(perk_id)
	if candidates.is_empty():
		return ""
	candidates.shuffle()
	return candidates[0]


static func is_mythic_perk_id(perk_id: String) -> bool:
	return MYTHIC_PERK_IDS.has(perk_id)


static func _grant_starpoints(reward: Dictionary, owner: Object, registry: Object, amount: int) -> Dictionary:
	amount = clampi(amount, 1, 3)
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var runtime_perk_catalog: Object = _get_runtime_perk_catalog(registry)
	if runtime_perk_state == null or runtime_perk_catalog == null:
		return {"granted": false, "reward_type": REWARD_STARPOINT, "starpoint_amount": amount}
	if not runtime_perk_state.has_method("collect_star_points"):
		return {"granted": false, "reward_type": REWARD_STARPOINT, "starpoint_amount": amount}
	runtime_perk_state.collect_star_points(
		amount,
		_get_selected_character_type(owner),
		runtime_perk_catalog,
		owner,
		registry,
		bool(reward.get("defer_choice_open", false))
	)
	return {
		"granted": true,
		"reward_type": REWARD_STARPOINT,
		"perk_id": "",
		"fallback_starpoint": true,
		"starpoint_amount": amount,
	}


static func _get_perk_data(registry: Object, perk_id: String) -> Dictionary:
	var runtime_perk_catalog: Object = _get_runtime_perk_catalog(registry)
	if runtime_perk_catalog != null and runtime_perk_catalog.has_method("get_perk_data"):
		var data_value: Variant = runtime_perk_catalog.get_perk_data(perk_id)
		if data_value is Dictionary:
			var data: Dictionary = data_value
			if not data.is_empty():
				return data.duplicate(true)
	var fallback_catalog := RuntimePerkCatalog.new()
	var fallback_value: Variant = fallback_catalog.get_perk_data(perk_id)
	if fallback_value is Dictionary:
		return (fallback_value as Dictionary).duplicate(true)
	return {}


static func _get_runtime_perk_level(registry: Object, perk_id: String) -> int:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return 0
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level(perk_id)))
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		return max(0, int((levels_value as Dictionary).get(perk_id, 0)))
	return 0


static func _get_runtime_perk_catalog(registry: Object) -> Object:
	var catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	if catalog != null:
		return catalog
	return RuntimePerkCatalog.new()


static func _has_open_perk_slot(registry: Object) -> bool:
	var runtime_perk_catalog: Object = _get_runtime_perk_catalog(registry)
	if runtime_perk_catalog == null or not runtime_perk_catalog.has_method("has_open_perk_slot"):
		return true
	return bool(runtime_perk_catalog.has_open_perk_slot(_get_runtime_perk_levels(registry)))


static func _get_runtime_perk_levels(registry: Object) -> Dictionary:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return {}
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		return (levels_value as Dictionary).duplicate(true)
	if runtime_perk_state.has_method("get_snapshot"):
		var snapshot_value: Variant = runtime_perk_state.get_snapshot()
		if snapshot_value is Dictionary:
			var snapshot: Dictionary = snapshot_value
			var snapshot_levels_value: Variant = snapshot.get("runtime_skill_levels", {})
			if snapshot_levels_value is Dictionary:
				return (snapshot_levels_value as Dictionary).duplicate(true)
	return {}


static func _get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null or str(value) == "":
		return "smasher"
	return str(value)


static func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
