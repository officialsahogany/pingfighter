extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const REWARD_MYTHIC_PERK := "mythic_perk"
const REWARD_MYTHIC_PERK_CHOICE := "mythic_perk_choice"
const REWARD_STARPOINT := "starpoint"
const FALLBACK_STARPOINT_AMOUNT := 3
const MYTHIC_PERK_CHOICE_COUNT := 3
const MYTHIC_PERK_ICON_FRAME_COUNT := 8
const MYTHIC_PERK_ICON_FRAME_MSEC := 110
const MYTHIC_PERK_IDS := [
	"megingjord",
	"transcendent_crown",
	"ragnarok_hammer",
	"hermes_shoes",
	"poseidon_trident",
	"sacred_laurel",
	"heavenly_cape",
	"horn_strawberry_mask",
	"odins_eye",
	"celestial_armor",
	"baal_boots",
	"pandora_legacy",
	"angel_blessing",
]


static func build_reward(owner: Object, registry: Object, fallback_starpoints: int = FALLBACK_STARPOINT_AMOUNT) -> Dictionary:
	if not _has_open_perk_slot(registry):
		return build_starpoint_fallback_reward(fallback_starpoints)
	var perk_id: String = pick_random_unowned_mythic_perk_id(registry)
	if perk_id == "":
		return build_starpoint_fallback_reward(fallback_starpoints)
	return build_reward_for_perk(perk_id, owner, registry, fallback_starpoints)


static func build_choice_reward(owner: Object, registry: Object, fallback_starpoints: int = FALLBACK_STARPOINT_AMOUNT) -> Dictionary:
	if get_available_mythic_perk_ids(owner, registry).is_empty():
		return build_starpoint_fallback_reward(fallback_starpoints)
	return {
		"type": REWARD_MYTHIC_PERK_CHOICE,
		"label": "신화 퍽 선택",
		"amount": 1,
		"choice_count": MYTHIC_PERK_CHOICE_COUNT,
		"rarity": "mythic",
		"fallback_starpoints": max(1, fallback_starpoints),
	}


static func build_reward_for_perk(
	perk_id: String,
	_owner: Object,
	registry: Object,
	fallback_starpoints: int = FALLBACK_STARPOINT_AMOUNT
) -> Dictionary:
	perk_id = perk_id.strip_edges()
	if perk_id == "":
		return build_starpoint_fallback_reward(fallback_starpoints)
	if not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		perk_id
	):
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


static func build_choice_card_for_perk(
	perk_id: String,
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Dictionary:
	perk_id = perk_id.strip_edges()
	if perk_id == "" or _get_runtime_perk_level(registry, perk_id) > 0:
		return {}
	if not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		perk_id
	):
		return {}
	var perk_data: Dictionary = _get_perk_data_from_catalog(catalog, registry, perk_id)
	if perk_data.is_empty() or str(perk_data.get("rarity", "")).to_lower() != "mythic":
		return {}
	if not _is_perk_allowed_for_owner(perk_data, owner):
		return {}
	var choice: Dictionary = perk_data.duplicate(true)
	choice["id"] = perk_id
	choice["current_level"] = 0
	choice["next_level"] = 1
	choice["max_level"] = int(choice.get("max_level", 1))
	choice["rarity"] = "mythic"
	choice["tree"] = "mythic"
	if not choice.has("character_restriction"):
		choice["character_restriction"] = ""
	var descriptions: Dictionary = _get_dict(choice.get("descriptions", {}))
	var description: String = str(descriptions.get(1, descriptions.get("1", "")))
	if description == "":
		description = str(choice.get("description", choice.get("detail", "")))
	choice["description"] = description
	return choice


static func build_mythic_choice_cards(
	count: int,
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Array:
	var ids: Array[String] = get_available_mythic_perk_ids(owner, registry, catalog)
	ids.shuffle()
	var cards: Array = []
	for perk_id in ids:
		if cards.size() >= max(1, count):
			break
		var card: Dictionary = build_choice_card_for_perk(perk_id, owner, registry, catalog)
		if not card.is_empty():
			cards.append(card)
	return cards


static func get_available_mythic_perk_ids(
	owner: Object,
	registry: Object,
	catalog: Object = null
) -> Array[String]:
	var candidates: Array[String] = []
	if not _has_open_perk_slot(registry):
		return candidates
	var resolved_catalog: Object = catalog if catalog != null else _get_runtime_perk_catalog(registry)
	for perk_id_value in MYTHIC_PERK_IDS:
		var perk_id: String = str(perk_id_value)
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			perk_id
		):
			continue
		if _get_runtime_perk_level(registry, perk_id) > 0:
			continue
		var perk_data: Dictionary = _get_perk_data_from_catalog(resolved_catalog, registry, perk_id)
		if perk_data.is_empty() or str(perk_data.get("rarity", "")).to_lower() != "mythic":
			continue
		if not _is_perk_allowed_for_owner(perk_data, owner):
			continue
		candidates.append(perk_id)
	return candidates


static func build_starpoint_fallback_reward(amount: int = FALLBACK_STARPOINT_AMOUNT) -> Dictionary:
	amount = clampi(amount, 1, 3)
	return {
		"type": REWARD_STARPOINT,
		"label": "★%d" % amount,
		"amount": amount,
		"mythic_perk_fallback": true,
	}


static func build_acquisition_cinematic_item_data(
	perk_id: String,
	registry: Object,
	fallback_data: Dictionary = {}
) -> Dictionary:
	perk_id = perk_id.strip_edges()
	if perk_id == "":
		return {}
	var perk_data: Dictionary = _get_perk_data(registry, perk_id)
	if perk_data.is_empty():
		perk_data = fallback_data.duplicate(true)
	if perk_data.is_empty():
		return {}
	var display_name: String = str(perk_data.get("name", fallback_data.get("label", perk_id)))
	if display_name == "":
		display_name = perk_id
	var reveal_description: String = _get_reveal_description_from_perk_data(perk_data)
	if reveal_description == "":
		reveal_description = str(fallback_data.get("description", "")).strip_edges()
	var sheet_path: String = str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(perk_id, ""))
	var static_path: String = str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, ""))
	var cinematic_data := {
		"id": perk_id,
		"perk_id": perk_id,
		"name": display_name,
		"qualified_display_name": display_name,
		"rarity": "mythic",
		"type": REWARD_MYTHIC_PERK,
		"icon_frame_count": MYTHIC_PERK_ICON_FRAME_COUNT,
		"icon_frame_msec": MYTHIC_PERK_ICON_FRAME_MSEC,
		"reveal_description": reveal_description,
	}
	if _texture_path_exists(sheet_path):
		cinematic_data["icon_sheet_path"] = sheet_path
	elif _texture_path_exists(static_path):
		cinematic_data["icon_path"] = static_path
	else:
		return {}
	return cinematic_data


static func try_start_acquisition_cinematic(
	perk_id: String,
	owner: Object,
	registry: Object,
	pickup_position: Vector2 = Vector2(380.0, 375.0),
	target_player_center: Vector2 = Vector2.INF,
	fallback_data: Dictionary = {}
) -> bool:
	perk_id = perk_id.strip_edges()
	if perk_id == "":
		return false
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("start_acquisition_cinematic"):
		return false
	var cinematic_data: Dictionary = build_acquisition_cinematic_item_data(perk_id, registry, fallback_data)
	if cinematic_data.is_empty():
		return false
	return bool(mythic_item_runtime.start_acquisition_cinematic(
		cinematic_data,
		pickup_position,
		owner,
		registry,
		target_player_center
	))


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
	for context_key in ["pickup_position", "target_player_center", "source", "grant_scope"]:
		if reward.has(context_key):
			choice[context_key] = reward.get(context_key)
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


static func _get_perk_data_from_catalog(catalog: Object, registry: Object, perk_id: String) -> Dictionary:
	if catalog != null and catalog.has_method("get_perk_data"):
		var data_value: Variant = catalog.get_perk_data(perk_id)
		if data_value is Dictionary:
			var data: Dictionary = data_value
			if not data.is_empty():
				return data.duplicate(true)
	return _get_perk_data(registry, perk_id)


static func _get_reveal_description_from_perk_data(perk_data: Dictionary) -> String:
	var descriptions: Dictionary = _get_dict(perk_data.get("descriptions", {}))
	var description: String = str(descriptions.get(1, descriptions.get("1", "")))
	if description == "":
		description = str(perk_data.get("description", perk_data.get("detail", "")))
	return description.strip_edges()


static func _texture_path_exists(path: String) -> bool:
	return path != "" and ProjectResourceLoader.texture_resource_exists(path)


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


static func _is_perk_allowed_for_owner(perk_data: Dictionary, owner: Object) -> bool:
	var restriction: String = str(perk_data.get("character_restriction", "")).strip_edges().to_lower()
	if restriction == "":
		return true
	return restriction == _get_selected_character_type(owner).strip_edges().to_lower()


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
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
