extends RefCounted

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentChestContract := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_contract.gd"
)
const TowerAscentActiveItemAcquisitionPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_active_item_acquisition_policy.gd"
)

const REWARD_ACTIVE := "active"
const REWARD_PASSIVE := "passive"
const REWARD_MYTHIC := "mythic"
const REWARD_MYTHIC_PERK := "mythic_perk"
const REWARD_MYTHIC_PERK_CHOICE := "mythic_perk_choice"
const REWARD_STARPOINT := "starpoint"
const BOX_ADVANCED := "advanced"
const BOX_GUARANTEED_MYTHIC := "guaranteed_mythic"
const LEGACY_BOX_MYTHIC := "mythic"
const TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE := 0.03

const NORMAL_ACTIVE_WEIGHT := 15.0
const NORMAL_PASSIVE_WEIGHT := 27.0
const NORMAL_STARPOINT_SINGLE_WEIGHT := 57.0
const NORMAL_STARPOINT_DOUBLE_WEIGHT := 0.0
const NORMAL_MYTHIC_WEIGHT := 1.0
const ADVANCED_BOX_MYTHIC_WEIGHT := 3.0
const ADVANCED_BOX_STARPOINT_DOUBLE_WEIGHT := 25.0
const ADVANCED_BOX_STARPOINT_TRIPLE_WEIGHT := 10.0
const ADVANCED_BOX_PASSIVE_WEIGHT := 62.0
const STARPOINT_REWARD_SINGLE_AMOUNT := 1
const STARPOINT_REWARD_DOUBLE_AMOUNT := 2
const STARPOINT_REWARD_TRIPLE_AMOUNT := 3
const NORMAL_REWARD_STARPOINT_SINGLE := "starpoint_1"
const NORMAL_REWARD_STARPOINT_DOUBLE := "starpoint_2"
const ADVANCED_REWARD_STARPOINT_DOUBLE := "advanced_starpoint_2"
const ADVANCED_REWARD_STARPOINT_TRIPLE := "advanced_starpoint_3"
const EXTRA_ACTIVE_REWARD_ITEM_NAMES: Array[String] = []

var _spawn_pool: Object = ActiveItemFieldSpawnPool.new()
var _active_catalog: Object = ActiveItemCatalog.new()


func roll_reward(
	box_kind: String,
	owner: Object = null,
	registry: Object = null,
	roll_override: float = -1.0
) -> Dictionary:
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		if box_kind == TowerAscentChestContract.CHEST_SUPREME_ART:
			return _roll_mythic_perk_reward(owner, registry)
		if box_kind == TowerAscentChestContract.CHEST_SECRET_CHOSIK:
			# 비전 ID가 없는 직접 호출은 적격을 증명할 수 없으므로 절세무공으로 다운시프트.
			return _roll_mythic_perk_reward(owner, registry)
		return _roll_tower_normal_box_reward(owner, registry, roll_override)
	if _is_guaranteed_mythic_box_kind(box_kind):
		if PerkConversionFlags.is_enabled():
			return _roll_mythic_perk_reward(owner, registry)
		return _roll_item_reward(REWARD_MYTHIC, owner, registry)
	if _is_advanced_box_kind(box_kind):
		return _roll_advanced_box_reward(owner, registry)

	return _roll_normal_box_reward(owner, registry)


func _roll_tower_normal_box_reward(
	owner: Object,
	registry: Object,
	roll_override: float = -1.0
) -> Dictionary:
	var roll_value := randf() if roll_override < 0.0 else clampf(roll_override, 0.0, 0.999999)
	if roll_value < TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE:
		if PerkConversionFlags.is_enabled():
			return _roll_mythic_perk_reward(owner, registry)
		return _roll_item_reward(REWARD_MYTHIC, owner, registry)
	var non_jackpot_roll := (
		(roll_value - TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE)
		/ (1.0 - TOWER_NORMAL_MYTHIC_JACKPOT_CHANCE)
	)
	var total_weight := (
		NORMAL_ACTIVE_WEIGHT
		+ NORMAL_PASSIVE_WEIGHT
		+ NORMAL_STARPOINT_SINGLE_WEIGHT
		+ NORMAL_STARPOINT_DOUBLE_WEIGHT
	)
	var weighted_roll := non_jackpot_roll * maxf(0.001, total_weight)
	if weighted_roll < NORMAL_ACTIVE_WEIGHT:
		return _roll_item_reward(REWARD_ACTIVE, owner, registry)
	weighted_roll -= NORMAL_ACTIVE_WEIGHT
	if weighted_roll < NORMAL_PASSIVE_WEIGHT:
		if PerkConversionFlags.is_enabled():
			return _roll_starpoint_reward(STARPOINT_REWARD_SINGLE_AMOUNT)
		return _roll_item_reward(REWARD_PASSIVE, owner, registry)
	weighted_roll -= NORMAL_PASSIVE_WEIGHT
	if weighted_roll < NORMAL_STARPOINT_SINGLE_WEIGHT:
		return _roll_starpoint_reward(STARPOINT_REWARD_SINGLE_AMOUNT)
	return _roll_starpoint_reward(STARPOINT_REWARD_DOUBLE_AMOUNT)


func _roll_normal_box_reward(owner: Object, registry: Object, roll_override: float = -1.0) -> Dictionary:
	var roll_value: float = randf() if roll_override < 0.0 else roll_override
	match _resolve_normal_box_reward_type(roll_value):
		REWARD_ACTIVE:
			return _roll_item_reward(REWARD_ACTIVE, owner, registry)
		REWARD_PASSIVE:
			return _roll_item_reward(REWARD_PASSIVE, owner, registry)
		NORMAL_REWARD_STARPOINT_SINGLE:
			return _roll_starpoint_reward(STARPOINT_REWARD_SINGLE_AMOUNT)
		NORMAL_REWARD_STARPOINT_DOUBLE:
			return _roll_starpoint_reward(STARPOINT_REWARD_DOUBLE_AMOUNT)
		REWARD_MYTHIC_PERK:
			return _roll_mythic_perk_reward(owner, registry)
	return _roll_item_reward(REWARD_MYTHIC, owner, registry)


func _resolve_normal_box_reward_type(roll: float) -> String:
	var total_weight: float = (
		NORMAL_ACTIVE_WEIGHT
		+ NORMAL_PASSIVE_WEIGHT
		+ NORMAL_STARPOINT_SINGLE_WEIGHT
		+ NORMAL_STARPOINT_DOUBLE_WEIGHT
		+ NORMAL_MYTHIC_WEIGHT
	)
	var weighted_roll: float = clamp(roll, 0.0, 0.999999) * max(0.001, total_weight)
	if weighted_roll < NORMAL_ACTIVE_WEIGHT:
		return REWARD_ACTIVE
	weighted_roll -= NORMAL_ACTIVE_WEIGHT
	if weighted_roll < NORMAL_PASSIVE_WEIGHT:
		if PerkConversionFlags.is_enabled():
			return NORMAL_REWARD_STARPOINT_SINGLE
		return REWARD_PASSIVE
	weighted_roll -= NORMAL_PASSIVE_WEIGHT
	if weighted_roll < NORMAL_STARPOINT_SINGLE_WEIGHT:
		return NORMAL_REWARD_STARPOINT_SINGLE
	weighted_roll -= NORMAL_STARPOINT_SINGLE_WEIGHT
	if weighted_roll < NORMAL_STARPOINT_DOUBLE_WEIGHT:
		return NORMAL_REWARD_STARPOINT_DOUBLE
	if PerkConversionFlags.is_enabled():
		return REWARD_MYTHIC_PERK
	return REWARD_MYTHIC


func grant_rewards(rewards: Array, owner: Object, registry: Object) -> Dictionary:
	var summary := {
		"attempted": 0,
		"granted": 0,
		"active_granted": 0,
		"passive_granted": 0,
		"mythic_granted": 0,
		"mythic_perk_granted": 0,
		"mythic_perk_choice_opened": 0,
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
			REWARD_MYTHIC_PERK:
				var mythic_perk_result: Dictionary = _grant_mythic_perk_reward(reward, owner, registry)
				granted = bool(mythic_perk_result.get("granted", false))
				if granted:
					if bool(mythic_perk_result.get("fallback_starpoint", false)):
						summary["starpoint_granted"] = int(summary["starpoint_granted"]) + int(mythic_perk_result.get("starpoint_amount", 0))
					else:
						summary["mythic_perk_granted"] = int(summary.get("mythic_perk_granted", 0)) + 1
			REWARD_MYTHIC_PERK_CHOICE:
				var mythic_choice_result: Dictionary = _grant_mythic_perk_choice_reward(reward, owner, registry)
				granted = bool(mythic_choice_result.get("granted", false))
				if granted:
					if bool(mythic_choice_result.get("fallback_starpoint", false)):
						summary["starpoint_granted"] = int(summary["starpoint_granted"]) + int(mythic_choice_result.get("starpoint_amount", 0))
					else:
						summary["mythic_perk_choice_opened"] = int(summary.get("mythic_perk_choice_opened", 0)) + 1
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


func _is_advanced_box_kind(box_kind: String) -> bool:
	return box_kind == BOX_ADVANCED or box_kind == LEGACY_BOX_MYTHIC


func _is_guaranteed_mythic_box_kind(box_kind: String) -> bool:
	return box_kind == BOX_GUARANTEED_MYTHIC


func _roll_advanced_box_reward(owner: Object, registry: Object, roll_override: float = -1.0) -> Dictionary:
	var roll_value: float = randf() if roll_override < 0.0 else roll_override
	match _resolve_advanced_box_reward_type(roll_value):
		REWARD_MYTHIC:
			return _roll_item_reward(REWARD_MYTHIC, owner, registry)
		REWARD_MYTHIC_PERK:
			return _roll_mythic_perk_reward(owner, registry)
		ADVANCED_REWARD_STARPOINT_DOUBLE:
			return _roll_starpoint_reward(STARPOINT_REWARD_DOUBLE_AMOUNT)
		ADVANCED_REWARD_STARPOINT_TRIPLE:
			return _roll_starpoint_reward(STARPOINT_REWARD_TRIPLE_AMOUNT)
	return _roll_item_reward(REWARD_PASSIVE, owner, registry)


func _resolve_advanced_box_reward_type(roll: float) -> String:
	var total_weight: float = (
		ADVANCED_BOX_MYTHIC_WEIGHT
		+ ADVANCED_BOX_STARPOINT_DOUBLE_WEIGHT
		+ ADVANCED_BOX_STARPOINT_TRIPLE_WEIGHT
		+ ADVANCED_BOX_PASSIVE_WEIGHT
	)
	var weighted_roll: float = clamp(roll, 0.0, 0.999999) * max(0.001, total_weight)
	if weighted_roll < ADVANCED_BOX_MYTHIC_WEIGHT:
		if PerkConversionFlags.is_enabled():
			return REWARD_MYTHIC_PERK
		return REWARD_MYTHIC
	weighted_roll -= ADVANCED_BOX_MYTHIC_WEIGHT
	if weighted_roll < ADVANCED_BOX_STARPOINT_DOUBLE_WEIGHT:
		return ADVANCED_REWARD_STARPOINT_DOUBLE
	weighted_roll -= ADVANCED_BOX_STARPOINT_DOUBLE_WEIGHT
	if weighted_roll < ADVANCED_BOX_STARPOINT_TRIPLE_WEIGHT:
		return ADVANCED_REWARD_STARPOINT_TRIPLE
	if PerkConversionFlags.is_enabled():
		return ADVANCED_REWARD_STARPOINT_DOUBLE
	return REWARD_PASSIVE


func _roll_starpoint_reward(amount: int = STARPOINT_REWARD_SINGLE_AMOUNT) -> Dictionary:
	amount = max(1, amount)
	return {
		"type": REWARD_STARPOINT,
		"label": "★ %d" % amount,
		"amount": amount,
	}


func _roll_mythic_perk_reward(owner: Object, registry: Object) -> Dictionary:
	return MythicPerkGrantHelper.build_choice_reward(owner, registry)


func _build_candidates_for_group(reward_group: String, owner: Object, registry: Object) -> Array:
	var candidates: Array = []
	if TowerAscentFeatureFlags.is_vertical_slice_enabled() and reward_group == REWARD_ACTIVE:
		for item_name_value in ActiveItemCatalog.CATALOG_ORDER:
			var item_name := str(item_name_value)
			if not TowerAscentUnlockFilter.is_content_unlocked(
				registry,
				TowerAscentUnlockFilter.CONTENT_ITEM,
				item_name
			):
				continue
			var item_data: Dictionary = _active_catalog.build_item_by_name(item_name)
			if TowerAscentActiveItemAcquisitionPolicy.is_allowed(
				item_data,
				TowerAscentActiveItemAcquisitionPolicy.CHANNEL_NORMAL_CHEST,
				owner
			):
				candidates.append(item_data.duplicate(true))
		return candidates
	if _spawn_pool == null or not _spawn_pool.has_method("build_spawn_candidates"):
		return candidates
	for item_value in _spawn_pool.build_spawn_candidates(registry, owner):
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		if _get_item_group(item_data) == reward_group:
			candidates.append(item_data.duplicate(true))
	if reward_group == REWARD_ACTIVE:
		_append_extra_active_reward_candidates(candidates, owner, registry)
	return candidates


func _append_extra_active_reward_candidates(
	candidates: Array,
	owner: Object,
	registry: Object
) -> void:
	for item_name in EXTRA_ACTIVE_REWARD_ITEM_NAMES:
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_ITEM,
			str(item_name)
		):
			continue
		if _candidate_list_has_item(candidates, str(item_name)):
			continue
		var item_data: Dictionary = _active_catalog.build_item_by_name(str(item_name))
		if (
			not item_data.is_empty()
			and _get_item_group(item_data) == REWARD_ACTIVE
			and TowerAscentActiveItemAcquisitionPolicy.is_allowed(
				item_data,
				TowerAscentActiveItemAcquisitionPolicy.CHANNEL_NORMAL_CHEST,
				owner
			)
		):
			candidates.append(item_data.duplicate(true))


func _candidate_list_has_item(candidates: Array, item_name: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("name", "")) == item_name:
			return true
	return false


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
			return LanguageSettings.translate_text("액티브 아이템")
		REWARD_PASSIVE:
			return LanguageSettings.translate_text("패시브 아이템")
		REWARD_MYTHIC:
			return LanguageSettings.translate_text("신화 아이템")
	return LanguageSettings.translate_text("보상")


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


func _grant_mythic_perk_reward(reward: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var result_reward: Dictionary = reward.duplicate(true)
	result_reward["source"] = str(result_reward.get("source", "result_box_mythic_direct"))
	result_reward["grant_scope"] = "stage_clear_result"
	return MythicPerkGrantHelper.grant_reward(result_reward, owner, registry)


func _grant_mythic_perk_choice_reward(reward: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	var runtime_perk_catalog: Object = _get_instance(registry, "runtime_perk_catalog")
	if (
		runtime_perk_state != null
		and runtime_perk_catalog != null
		and runtime_perk_state.has_method("open_mythic_perk_choice")
	):
		var choice_count: int = max(1, int(reward.get("choice_count", MythicPerkGrantHelper.MYTHIC_PERK_CHOICE_COUNT)))
		var opened: bool = bool(runtime_perk_state.open_mythic_perk_choice(
			choice_count,
			owner,
			registry,
			runtime_perk_catalog,
			null,
			_build_mythic_choice_cinematic_context(reward)
		))
		if opened:
			_play_runtime_perk_choice_open_audio(registry)
			return {
				"granted": true,
				"reward_type": REWARD_MYTHIC_PERK_CHOICE,
				"choice_opened": true,
				"fallback_starpoint": false,
				"starpoint_amount": 0,
			}
	var fallback_reward: Dictionary = MythicPerkGrantHelper.build_starpoint_fallback_reward(
		int(reward.get("fallback_starpoints", MythicPerkGrantHelper.FALLBACK_STARPOINT_AMOUNT))
	)
	if reward.has("defer_choice_open"):
		# 결과화면 상자에서 온 보상이 그랜트 시점에 스타포인트로 폴백되면, 원래 스타포인트
		# 보상과 동일하게 지연 오픈 플래그를 물려받아 결과화면의 지연 선택 게이트 / 박스별
		# 보상 추적 플로우를 그대로 타야 한다.
		fallback_reward["defer_choice_open"] = bool(reward.get("defer_choice_open", false))
	var granted_fallback: bool = _grant_starpoint_reward(fallback_reward, owner, registry)
	return {
		"granted": granted_fallback,
		"reward_type": REWARD_STARPOINT if granted_fallback else REWARD_MYTHIC_PERK_CHOICE,
		"choice_opened": false,
		"fallback_starpoint": granted_fallback,
		"starpoint_amount": int(fallback_reward.get("amount", 0)) if granted_fallback else 0,
	}


func _build_mythic_choice_cinematic_context(reward: Dictionary) -> Dictionary:
	# 결과화면 상자 보상은 payload 에 상자 위치 기반 시네마틱 좌표를 싣고 온다. 선택형
	# 신화퍽은 카드를 고른 뒤에야 획득 시네마틱이 시작되므로, 좌표를 choice context 로
	# 넘겨 오픈 플로우가 각 카드에 스탬프하게 한다 (직접 지급 경로의
	# MythicPerkGrantHelper.grant_reward 좌표 복사와 같은 계약).
	var context: Dictionary = {
		"source": "result_box_mythic_choice",
		"grant_scope": "stage_clear_result",
	}
	for cinematic_key in ["pickup_position", "target_player_center"]:
		if reward.has(cinematic_key):
			context[cinematic_key] = reward.get(cinematic_key)
	return context


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


func _play_runtime_perk_choice_open_audio(registry: Object) -> void:
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio == null:
		return
	if game_audio.has_method("play_runtime_perk_choice_open"):
		game_audio.play_runtime_perk_choice_open()
	elif game_audio.has_method("play_starpoint_collect"):
		game_audio.play_starpoint_collect()


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
