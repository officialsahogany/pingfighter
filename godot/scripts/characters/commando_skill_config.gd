extends RefCounted

const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const MAX_SKILL_SLOTS := 5
const FIXED_SKILLS := ["supply_drop", "emergency_supply"]
const PISTOL_ORB_SKILL := "commando_pistol"
const SAVE_SNAPSHOT_VERSION := 1
const PERMANENT_FIREARM_SKILLS := [
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
	"bazooka",
	"ak47",
	PISTOL_ORB_SKILL,
]

const SKILL_COSTS := {
	"supply_drop": 350.0,
	"emergency_supply": 150.0,
	"net_gun": 0.0,
	"fire_support": 0.0,
	"bowling_trap": 0.0,
	"suicide_drone": 0.0,
	"bazooka": 0.0,
	"ak47": 0.0,
	"commando_pistol": 0.0,
}

const SKILL_COLORS := {
	"supply_drop": Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0),
	"emergency_supply": Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
	"net_gun": Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0),
	"fire_support": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
	"bowling_trap": Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0),
	"suicide_drone": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
	"bazooka": Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0),
	"ak47": Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0),
	"commando_pistol": Color(200.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0),
}

const COOLDOWN_SECONDS := {
	"supply_drop": 40.0,
	"emergency_supply": 60.0,
	"net_gun": 2.0,
	"fire_support": 3.5,
	"bowling_trap": 2.5,
	"suicide_drone": 4.0,
	"bazooka": 2.0,
	"ak47": 0.1,
	"commando_pistol": 0.0,
}

const SKILL_GOLD_REWARD_EXCLUDED := {
	"emergency_supply": true,
	"net_gun": true,
	"fire_support": true,
	"bowling_trap": true,
	"suicide_drone": true,
	"bazooka": true,
	"ak47": true,
	"commando_pistol": true,
}

const SKILL_DATA := {
	"supply_drop": {
		"name": "supply_drop",
		"korean": "물자보급",
		"cost": 350.0,
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0),
		"cooldown": 40.0,
		"description": "무전기로 보급기를 호출하여 랜덤 아이템이나 대여 화기류를 투하합니다.",
		"how_to_use": "S/↓ 또는 우클릭을 1초 홀드해 발동",
		"motion_hint": "무전기로 보급기를 호출",
		"effect_type": "supply_green",
	},
	"emergency_supply": {
		"name": "emergency_supply",
		"korean": "재장전",
		"cost": 150.0,
		"color": Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
		"cooldown": 60.0,
		"description": "무전기로 보급병을 호출합니다.\n잠시 후 보급병이 달려와 현재 선택한 화기류의 탄약을 최대치까지 보충합니다.",
		"how_to_use": "제자리에서 ↓를 두 번 눌러 발동",
		"motion_hint": "무전 후 보급병이 달려와 보급",
		"effect_type": "emergency_red",
	},
	"commando_pistol": {
		"name": "commando_pistol",
		"korean": "베레타",
		"cost": 0.0,
		"color": Color(200.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0),
		"cooldown": 0.0,
		"description": "준비동작 없이 즉시 발사되며 권총보다 연사가 2배 빠르고 탄속 20%, 정확도 30%가 향상된 베레타를 사용합니다.\n탄약 12발은 재장전 스킬로만 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "베레타 발사",
		"effect_type": "firearm_pistol",
	},
	"bazooka": {
		"name": "bazooka",
		"korean": "바주카포",
		"cost": 0.0,
		"color": Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0),
		"cooldown": 2.0,
		"description": "현재 선택 중일 때 발사 후 짧은 오브 쿨타임이 돕니다.\n재장전 스킬로 탄약을 1발씩 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "바주카포 발사",
		"effect_type": "firearm_bazooka",
	},
	"ak47": {
		"name": "ak47",
		"korean": "AK-47",
		"cost": 0.0,
		"color": Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0),
		"cooldown": 0.1,
		"description": "현재 선택 중일 때 1발마다 짧은 오브 쿨타임이 돕니다.\n재장전 게이지를 끝까지 채우면 탄약과 지속시간을 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "AK-47 연사",
		"effect_type": "firearm_ak47",
	},
	"net_gun": {
		"name": "net_gun",
		"korean": "그물덫총",
		"cost": 0.0,
		"color": Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0),
		"cooldown": 2.0,
		"description": "현재 선택 중일 때 발사 후 짧은 오브 쿨타임이 돕니다.\n재장전 스킬로 탄환을 1발씩 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "그물덫 발사",
		"effect_type": "firearm_net",
	},
	"fire_support": {
		"name": "fire_support",
		"korean": "화력지원",
		"cost": 0.0,
		"color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"cooldown": 3.5,
		"description": "현재 선택 중일 때 호출 후 짧은 오브 쿨타임이 돕니다.\n재장전 게이지를 끝까지 채우면 호출권을 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "화력지원 호출",
		"effect_type": "firearm_support",
	},
	"bowling_trap": {
		"name": "bowling_trap",
		"korean": "볼링트랩",
		"cost": 0.0,
		"color": Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0),
		"cooldown": 2.5,
		"description": "현재 선택 중일 때 설치 후 짧은 오브 쿨타임이 돕니다.\n재장전 스킬로 탄환을 1발씩 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "볼링트랩 설치",
		"effect_type": "firearm_trap",
	},
	"suicide_drone": {
		"name": "suicide_drone",
		"korean": "자폭드론",
		"cost": 0.0,
		"color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"cooldown": 4.0,
		"description": "현재 선택 중일 때 발진 후 짧은 오브 쿨타임이 돕니다.\n재장전 스킬로 탄환을 1발씩 보충합니다.",
		"how_to_use": "무기 선택 후 좌클릭 또는 SPACE",
		"motion_hint": "자폭드론 발진",
		"effect_type": "firearm_drone",
	},
}

var equipped_permanent: Array = []
var runtime_cooldown_multiplier := 1.0
var item_cooldown_multiplier := 1.0
var item_skill_slot_bonus := 0

# get_snapshot() 캐시 — smasher_skill_config.gd의 캐시 주석 참조. 입력 필드
# (영구 장착 무기 / 쿨타임 배수 / 슬롯 보너스 / 언어)가 그대로면 같은
# Dictionary를 공유 참조로 돌려준다 (소비자는 읽기 전용 계약). 무효화는
# 매 호출 값 비교 + 언어 비교, 재빌드는 새 Dictionary 교체.
var _snapshot_cache: Dictionary = {}
var _snapshot_cache_equipped_permanent: Array = []
var _snapshot_cache_runtime_mult := -1.0
var _snapshot_cache_item_mult := -1.0
var _snapshot_cache_slot_bonus := -1
var _snapshot_cache_language := ""


func get_snapshot() -> Dictionary:
	var language: String = LanguageSettings.get_language()
	if (
		not _snapshot_cache.is_empty()
		and _snapshot_cache_equipped_permanent == equipped_permanent
		and _snapshot_cache_runtime_mult == runtime_cooldown_multiplier
		and _snapshot_cache_item_mult == item_cooldown_multiplier
		and _snapshot_cache_slot_bonus == item_skill_slot_bonus
		and _snapshot_cache_language == language
	):
		return _snapshot_cache
	_snapshot_cache = {
		"max_slots": get_max_skill_slots(),
		"shared_slot_capacity": get_shared_slot_capacity(),
		"fixed_skills": FIXED_SKILLS.duplicate(),
		"equipped_permanent": equipped_permanent.duplicate(),
		"equipped_skills": get_equipped_skills(),
		"skill_costs": _get_effective_skill_costs_map(),
		"skill_colors": _get_effective_skill_colors_map(),
		"runtime_cooldown_multiplier": runtime_cooldown_multiplier,
		"item_cooldown_multiplier": item_cooldown_multiplier,
		"item_skill_slot_bonus": item_skill_slot_bonus,
		"skill_gold_rewards": _get_skill_gold_reward_map(),
		"cooldown_multiplier": _get_effective_cooldown_multiplier(),
		"cooldown_reduction_eligible": true,
		"cooldown_reduction_skill_ids": get_cooldown_reduction_skill_ids(),
		"cooldown_seconds": _get_effective_cooldown_seconds_map(),
		"skill_data": _get_effective_skill_data_map(),
	}
	_snapshot_cache_equipped_permanent = equipped_permanent.duplicate()
	_snapshot_cache_runtime_mult = runtime_cooldown_multiplier
	_snapshot_cache_item_mult = item_cooldown_multiplier
	_snapshot_cache_slot_bonus = item_skill_slot_bonus
	_snapshot_cache_language = language
	return _snapshot_cache


func get_save_snapshot() -> Dictionary:
	return {
		"version": SAVE_SNAPSHOT_VERSION,
		"equipped_permanent": equipped_permanent.duplicate(),
		"runtime_cooldown_multiplier": runtime_cooldown_multiplier,
		"item_cooldown_multiplier": item_cooldown_multiplier,
		"item_skill_slot_bonus": item_skill_slot_bonus,
	}


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary) -> Dictionary:
	reset_runtime_skills()
	if snapshot.is_empty():
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	runtime_cooldown_multiplier = max(0.0, float(snapshot.get("runtime_cooldown_multiplier", 1.0)))
	item_cooldown_multiplier = max(0.0, float(snapshot.get("item_cooldown_multiplier", 1.0)))
	item_skill_slot_bonus = max(0, int(snapshot.get("item_skill_slot_bonus", 0)))

	var dropped_ids: Array = []
	_restore_equipped_permanent_from_save(
		snapshot.get("equipped_permanent", snapshot.get("equipped_skills", [])),
		dropped_ids
	)
	var trimmed_ids: Array = _trim_equipped_permanent_to_capacity()
	dropped_ids.append_array(trimmed_ids)
	return {
		"restored": true,
		"equipped_permanent": equipped_permanent.duplicate(),
		"dropped_ids": dropped_ids,
		"trimmed_ids": trimmed_ids,
		"shared_slot_capacity": get_shared_slot_capacity(),
	}


func restore_save_snapshot(snapshot: Dictionary) -> Dictionary:
	return apply_save_snapshot(snapshot)


func get_max_skill_slots() -> int:
	return max(FIXED_SKILLS.size(), MAX_SKILL_SLOTS + max(0, item_skill_slot_bonus))


func get_shared_slot_capacity() -> int:
	return max(0, get_max_skill_slots() - FIXED_SKILLS.size())


func get_equipped_skills() -> Array:
	var result: Array = FIXED_SKILLS.duplicate()
	for skill_name in equipped_permanent:
		if result.size() >= get_max_skill_slots():
			break
		result.append(str(skill_name))
	return result


func get_cooldown_seconds(skill_name: String) -> float:
	return float(COOLDOWN_SECONDS.get(skill_name, 0.0)) * _get_effective_cooldown_multiplier()


func get_cooldown_reduction_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for skill_name_value: Variant in COOLDOWN_SECONDS.keys():
		if float(COOLDOWN_SECONDS.get(skill_name_value, 0.0)) > 0.0:
			result.append(str(skill_name_value))
	result.sort()
	return result


func set_runtime_cooldown_multiplier(multiplier: float) -> void:
	runtime_cooldown_multiplier = max(0.0, float(multiplier))


func set_item_cooldown_multiplier(multiplier: float) -> void:
	item_cooldown_multiplier = max(0.0, float(multiplier))


func set_item_skill_slot_bonus(slot_bonus: int) -> Array:
	item_skill_slot_bonus = max(0, int(slot_bonus))
	return _trim_equipped_permanent_to_capacity()


func get_skill_cost(skill_name: String) -> float:
	if skill_name == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
		return 0.0
	return float(SKILL_COSTS.get(skill_name, 0.0))


func get_skill_gold_reward(skill_name: String) -> int:
	var id: String = str(skill_name)
	if bool(SKILL_GOLD_REWARD_EXCLUDED.get(id, false)):
		return 0
	if not COOLDOWN_SECONDS.has(id):
		return 0
	var cooldown: float = float(COOLDOWN_SECONDS.get(id, 0.0))
	if cooldown <= 0.0:
		return 0
	return max(12, int(cooldown / 5.0 * 12.0))


func calculate_skill_gold_reward(skill_name: String) -> int:
	return get_skill_gold_reward(skill_name)


func is_skill_equipped(skill_name: String) -> bool:
	return get_equipped_skills().has(skill_name)


func is_permanent_firearm_skill(skill_name: String) -> bool:
	return PERMANENT_FIREARM_SKILLS.has(skill_name)


func is_shared_slot_skill(skill_name: String) -> bool:
	return is_permanent_firearm_skill(skill_name) or skill_name == CommonSkillCatalog.SOUL_SUMMON_ART_ID


func is_shared_slot_full() -> bool:
	return equipped_permanent.size() >= get_shared_slot_capacity()


func get_equipped_permanent() -> Array:
	return equipped_permanent.duplicate()


func get_shared_slot_swap_candidates(skill_name: String) -> Array:
	if not is_shared_slot_skill(skill_name):
		return []
	if equipped_permanent.has(skill_name):
		return []
	return get_equipped_permanent()


func unlock_and_equip_skill(skill_name: String) -> bool:
	if FIXED_SKILLS.has(skill_name):
		return true
	if not is_shared_slot_skill(skill_name):
		return false
	if equipped_permanent.has(skill_name):
		return true
	if is_shared_slot_full():
		return false
	equipped_permanent.append(skill_name)
	return true


func swap_equipped_permanent(old_skill_name: String, new_skill_name: String) -> bool:
	if not is_shared_slot_skill(new_skill_name):
		return false
	if not equipped_permanent.has(old_skill_name):
		return false
	if equipped_permanent.has(new_skill_name):
		return false
	var index: int = equipped_permanent.find(old_skill_name)
	if index < 0:
		return false
	equipped_permanent[index] = new_skill_name
	return true


func unequip_skill(skill_name: String) -> bool:
	if not equipped_permanent.has(skill_name):
		return false
	equipped_permanent.erase(skill_name)
	return true


func reset_runtime_skills() -> void:
	equipped_permanent.clear()
	runtime_cooldown_multiplier = 1.0
	item_cooldown_multiplier = 1.0
	item_skill_slot_bonus = 0


func get_skill_data(skill_name: String) -> Dictionary:
	if skill_name == CommonSkillCatalog.SOUL_SUMMON_ART_ID:
		return CommonSkillCatalog.get_skill_data()
	var value: Variant = SKILL_DATA.get(skill_name, {})
	if value is Dictionary:
		var data: Dictionary = value
		data = data.duplicate(true)
		data["cooldown"] = get_cooldown_seconds(skill_name)
		_localize_skill_data(data, skill_name)
		return data
	return {}


func _localize_skill_data(data: Dictionary, skill_name: String) -> void:
	var language := LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_KOREAN:
		return
	if language == LanguageSettings.LANGUAGE_CHINESE or language == LanguageSettings.LANGUAGE_JAPANESE or language == LanguageSettings.LANGUAGE_SPANISH or language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL or language == LanguageSettings.LANGUAGE_RUSSIAN:
		LanguageSettings.localize_skill_config_data(data, skill_name)
		return
	match skill_name:
		"supply_drop":
			data["korean"] = "Supply Drop"
			data["description"] = "Call a supply plane by radio to drop a random item or rented firearm."
			data["how_to_use"] = "Hold S/Down or right-click for 1 second"
			data["motion_hint"] = "Radio in a supply plane"
		"emergency_supply":
			data["korean"] = "Reload"
			data["description"] = "Call a supply soldier by radio. After a short delay, they refill the currently selected firearm to max ammo."
			data["how_to_use"] = "Press Down twice while standing still"
			data["motion_hint"] = "Radio, then supply soldier refill"
		"commando_pistol":
			data["korean"] = "Beretta"
			data["description"] = "Use a Beretta that fires instantly with no ready motion, twice the pistol fire rate, 20% faster bullets, and 30% better accuracy. Its 12 rounds are refilled only by Reload."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Fire Beretta"
		"bazooka":
			data["korean"] = "Bazooka"
			data["description"] = "When selected, firing triggers a short orb cooldown. Reload restores one round at a time."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Fire bazooka"
		"ak47":
			data["korean"] = "AK-47"
			data["description"] = "When selected, every shot triggers a short orb cooldown. A full reload gauge restores ammo and duration."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Fire AK-47"
		"net_gun":
			data["korean"] = "Net Trap Gun"
			data["description"] = "When selected, firing triggers a short orb cooldown. Reload restores one round at a time."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Fire net trap"
		"fire_support":
			data["korean"] = "Fire Support"
			data["description"] = "When selected, calling support triggers a short orb cooldown. A full reload gauge restores call charges."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Call fire support"
		"bowling_trap":
			data["korean"] = "Bowling Trap"
			data["description"] = "When selected, placing a trap triggers a short orb cooldown. Reload restores one round at a time."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Place bowling trap"
		"suicide_drone":
			data["korean"] = "Suicide Drone"
			data["description"] = "When selected, launching a drone triggers a short orb cooldown. Reload restores one round at a time."
			data["how_to_use"] = "Select weapon, then left-click or SPACE"
			data["motion_hint"] = "Launch suicide drone"


func _get_effective_cooldown_seconds_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in COOLDOWN_SECONDS.keys():
		result[str(skill_name)] = get_cooldown_seconds(str(skill_name))
	result[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = 0.0
	return result


func _get_effective_skill_data_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in SKILL_DATA.keys():
		result[str(skill_name)] = get_skill_data(str(skill_name))
	result[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = CommonSkillCatalog.get_skill_data()
	return result


func _get_effective_skill_costs_map() -> Dictionary:
	var result := SKILL_COSTS.duplicate()
	result[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = 0.0
	return result


func _get_effective_skill_colors_map() -> Dictionary:
	var result := SKILL_COLORS.duplicate()
	result[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = CommonSkillCatalog.SOUL_SUMMON_ART_COLOR
	return result


func _get_skill_gold_reward_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in COOLDOWN_SECONDS.keys():
		result[str(skill_name)] = get_skill_gold_reward(str(skill_name))
	return result


func _get_effective_cooldown_multiplier() -> float:
	return CooldownFloorPolicy.floor_final_multiplier(
		max(0.0, runtime_cooldown_multiplier) * max(0.0, item_cooldown_multiplier)
	)


func _restore_equipped_permanent_from_save(value: Variant, dropped_ids: Array) -> void:
	if not (value is Array):
		return
	for raw_skill_name in value:
		var skill_name: String = _normalize_skill_name(raw_skill_name)
		if FIXED_SKILLS.has(skill_name):
			continue
		if not is_shared_slot_skill(skill_name):
			dropped_ids.append(skill_name)
			continue
		if equipped_permanent.has(skill_name):
			dropped_ids.append(skill_name)
			continue
		equipped_permanent.append(skill_name)


func _normalize_skill_name(value: Variant) -> String:
	return str(value).strip_edges().to_lower()


func _trim_equipped_permanent_to_capacity() -> Array:
	var removed: Array = []
	var capacity: int = get_shared_slot_capacity()
	while equipped_permanent.size() > capacity:
		removed.append(equipped_permanent.pop_back())
	return removed
