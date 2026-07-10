extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const MAX_SKILL_SLOTS := 5
const EQUIPPED_SKILLS := ["drive", "power_smashing"]
const SKILL_COSTS := {
	"drive": 150.0,
	"power_smashing": 300.0,
	"plasma": 40.0,
	"recovery": 120.0,
	"cleanse": 100.0,
	"shield_kiting": 130.0,
	"magnum_grip": 70.0,
	"ghost_shot": 420.0,
	"warp_gate": 100.0,
	"smasher_wheel": 200.0,
}
const SKILL_COLORS := {
	"drive": Color(255.0 / 255.0, 220.0 / 255.0, 50.0 / 255.0),
	"power_smashing": Color(255.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0),
	"plasma": Color(0.0, 200.0 / 255.0, 1.0),
	"recovery": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
	"cleanse": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
	"shield_kiting": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
	"magnum_grip": Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
	"ghost_shot": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
	"warp_gate": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
	"smasher_wheel": Color(1.0, 165.0 / 255.0, 60.0 / 255.0),
}
const COOLDOWN_SECONDS := {
	"drive": 15.0,
	"power_smashing": 35.0,
	"plasma": 8.0,
	"recovery": 12.0,
	"cleanse": 20.0,
	"shield_kiting": 12.0,
	"magnum_grip": 22.0,
	"ghost_shot": 85.0,
	"warp_gate": 50.0,
	"smasher_wheel": 25.0,
}
const SKILL_DATA := {
	"plasma": {
		"name": "plasma",
		"korean": "플라즈마",
		"cost": 40.0,
		"color": Color(0.0, 200.0 / 255.0, 1.0),
		"cooldown": 8.0,
		"description": "전방으로 플라즈마 구체를 발사합니다.\n구체에 닿는 동안 적이 둔화됩니다.\n충전이 길수록 둔화 성능이 강해집니다.",
		"how_to_use": "W/↑ 홀드 후 손을 떼면 발동",
		"motion_hint": "전방으로 플라즈마 구체를 발사",
		"effect_type": "projectile_cyan",
	},
	"recovery": {
		"name": "recovery",
		"korean": "리커버리",
		"cost": 120.0,
		"color": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
		"cooldown": 12.0,
		"description": "대쉬 후딜을 즉시 제거합니다.\n일정 기간 이동속도 50% 보너스를 얻습니다.",
		"how_to_use": "대쉬 후딜 중 W/↑ 키로 발동",
		"motion_hint": "녹색 빛으로 후딜 제거 + 가속",
		"effect_type": "heal_green",
	},
	"cleanse": {
		"name": "cleanse",
		"korean": "클렌즈",
		"cost": 100.0,
		"color": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
		"cooldown": 20.0,
		"description": "스턴/둔화 등 상태이상을 즉시 해제합니다.\n일정 기간 면역 상태가 됩니다.",
		"how_to_use": "상태이상 시 W 키로 발동",
		"motion_hint": "황금빛 정화로 상태이상 해제",
		"effect_type": "cleanse_light",
		"requires_debuff": true,
	},
	"shield_kiting": {
		"name": "shield_kiting",
		"korean": "쉴드카이팅",
		"cost": 130.0,
		"color": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
		"cooldown": 12.0,
		"description": "에너지 쉴드를 최대 0.36초간 충전 후 던집니다.\n명중 시 공속이 30% 증가하고 즉시 손으로 돌아옵니다.\n낮고 먼 하강 공에는 더 빠르게 반응합니다.",
		"how_to_use": "좌클릭 더블클릭 또는 SPACE 더블탭으로 발동",
		"motion_hint": "에너지 쉴드를 던졌다 회수",
		"effect_type": "shield_kiting_arc",
	},
	"drive": {
		"name": "drive",
		"korean": "드라이브",
		"cost": 150.0,
		"color": Color(1.0, 220.0 / 255.0, 50.0 / 255.0),
		"cooldown": 15.0,
		"description": "공을 휘어쳐 커브샷을 발사합니다.\n공이 오기 전에 미리 입력하면 더 정확하게 들어갑니다.",
		"how_to_use": "←/→ + 좌클릭 동시 입력으로 발동",
		"motion_hint": "공을 휘어쳐 커브샷 발사",
		"effect_type": "drive_curve",
	},
	"power_smashing": {
		"name": "power_smashing",
		"korean": "파워스매싱",
		"cost": 300.0,
		"color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"cooldown": 35.0,
		"description": "강력한 스매시로 공을 발사합니다.\n좌/우 방향키로 발사 방향을 지정할 수 있습니다.\n단독 클릭 홀드 시 맞은 반대쪽으로 자동 발사됩니다.",
		"how_to_use": "←/→ + 좌클릭 홀드로 발동",
		"motion_hint": "강력 스매시로 공을 발사",
		"effect_type": "smash_orange",
	},
	"magnum_grip": {
		"name": "magnum_grip",
		"korean": "매그넘 그립",
		"cost": 70.0,
		"color": Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
		"cooldown": 22.0,
		"description": "강력한 자기장으로 공을 패들로 끌어당깁니다.\n공이 패들에 닿으면 자기장이 해제됩니다.\n끌어온 공을 받아치면 공속 상한이 45까지 증가합니다.",
		"how_to_use": "←+→ 동시 입력으로 발동",
		"motion_hint": "자기장으로 공을 패들로 끌어당김",
		"effect_type": "magnetic_pull_blue",
	},
	"ghost_shot": {
		"name": "ghost_shot",
		"korean": "고스트스매싱",
		"cost": 420.0,
		"color": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
		"cooldown": 85.0,
		"description": "공이 뱀처럼 구불거리며 귀신이 따라다닙니다.\n게이지 420 이상에서 파워스매싱 대신 발동됩니다.",
		"how_to_use": "게이지 420 이상에서 ←/→ + 좌클릭 홀드로 발동",
		"motion_hint": "뱀처럼 구불거리는 공 + 귀신 추격",
		"effect_type": "ghost_purple",
	},
	"warp_gate": {
		"name": "warp_gate",
		"korean": "워프게이트",
		"cost": 100.0,
		"color": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
		"cooldown": 50.0,
		"description": "일정 기간 차원 포털을 전개합니다.\n좌/우 벽을 타넘어 반대편으로 순간이동할 수 있습니다.\n벽을 넘어도 추가 게이지를 소모하지 않습니다.",
		"how_to_use": "S 또는 ↓ 키를 0.5초 이상 홀드하여 발동",
		"motion_hint": "차원 포털을 열어 좌/우 벽 워프",
		"effect_type": "portal_purple",
	},
	"smasher_wheel": {
		"name": "smasher_wheel",
		"korean": "스매셔휠",
		"cost": 200.0,
		"color": Color(1.0, 165.0 / 255.0, 60.0 / 255.0),
		"cooldown": 25.0,
		"description": "1.2초간 패들이 자체 회전합니다.\n공에 닿으면 매우 빠르게 보스 방향으로 재발사 + 강한 드라이브 커브.\n휠로 친 공은 난이도와 관계없이 공속 상한 60을 적용합니다.\n발동 중 대쉬 불가, 이동속도 -15%, 방향전환 약 1초.",
		"how_to_use": "A→W→D (오른쪽) 또는 D→W→A (왼쪽) 순서로 0.6초 내 입력",
		"motion_hint": "패들이 자체 회전하며 공을 빠르게 재발사",
		"effect_type": "wheel_spin",
	},
}

var equipped_skills: Array = EQUIPPED_SKILLS.duplicate()
var runtime_cooldown_multiplier := 1.0
var item_cooldown_multiplier := 1.0
var item_skill_slot_bonus := 0

# get_snapshot() 캐시. 전투 HUD가 매 프레임 호출하는데 skill_data 딥카피 +
# 로컬라이즈 재구성이 비쌌다. 입력 필드(장착 스킬 / 쿨타임 배수 / 슬롯 보너스 /
# 언어)가 그대로면 같은 Dictionary를 공유 참조로 돌려준다. 소비자는 전부 읽기
# 전용이며, 수정이 필요한 소비자는 duplicate(true) 후 사용해야 한다
# (smasher_skill_orb_tooltip_renderer가 기존 선례). 무효화는 dirty 플래그 대신
# 매 호출 값 비교라서 필드 직접 대입(테스트 등)도 안전하게 잡힌다.
# 재빌드 시 clear()가 아니라 새 Dictionary로 교체하므로, 이전에 반환된 스냅샷을
# 들고 있는 코드는 기존(매 호출 새 dict) 동작과 동일하게 옛 값을 유지한다.
var _snapshot_cache: Dictionary = {}
var _snapshot_cache_equipped: Array = []
var _snapshot_cache_runtime_mult := -1.0
var _snapshot_cache_item_mult := -1.0
var _snapshot_cache_slot_bonus := -1
var _snapshot_cache_language := ""


func get_snapshot() -> Dictionary:
	var language: String = LanguageSettings.get_language()
	if (
		not _snapshot_cache.is_empty()
		and _snapshot_cache_equipped == equipped_skills
		and _snapshot_cache_runtime_mult == runtime_cooldown_multiplier
		and _snapshot_cache_item_mult == item_cooldown_multiplier
		and _snapshot_cache_slot_bonus == item_skill_slot_bonus
		and _snapshot_cache_language == language
	):
		return _snapshot_cache
	_snapshot_cache = {
		"max_slots": get_max_skill_slots(),
		"equipped_skills": equipped_skills.duplicate(),
		"skill_costs": SKILL_COSTS,
		"skill_colors": SKILL_COLORS,
		"runtime_cooldown_multiplier": runtime_cooldown_multiplier,
		"item_cooldown_multiplier": item_cooldown_multiplier,
		"item_skill_slot_bonus": item_skill_slot_bonus,
		"cooldown_multiplier": _get_effective_cooldown_multiplier(),
		"cooldown_reduction_eligible": true,
		"cooldown_reduction_skill_ids": get_cooldown_reduction_skill_ids(),
		"cooldown_seconds": _get_effective_cooldown_seconds_map(),
		"skill_data": _get_effective_skill_data_map(),
	}
	_snapshot_cache_equipped = equipped_skills.duplicate()
	_snapshot_cache_runtime_mult = runtime_cooldown_multiplier
	_snapshot_cache_item_mult = item_cooldown_multiplier
	_snapshot_cache_slot_bonus = item_skill_slot_bonus
	_snapshot_cache_language = language
	return _snapshot_cache


func get_max_skill_slots() -> int:
	return max(1, MAX_SKILL_SLOTS + max(0, item_skill_slot_bonus))


func get_cooldown_seconds(skill_name: String) -> float:
	return float(COOLDOWN_SECONDS.get(skill_name, 0.0)) * _get_effective_cooldown_multiplier()


func get_cooldown_reduction_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for skill_name_value: Variant in COOLDOWN_SECONDS.keys():
		if float(COOLDOWN_SECONDS.get(skill_name_value, 0.0)) > 0.0:
			result.append(str(skill_name_value))
	result.sort()
	return result


func get_effective_cooldown_multiplier() -> float:
	return _get_effective_cooldown_multiplier()




func set_runtime_cooldown_multiplier(multiplier: float) -> void:
	runtime_cooldown_multiplier = max(0.0, float(multiplier))


func set_item_cooldown_multiplier(multiplier: float) -> void:
	item_cooldown_multiplier = max(0.0, float(multiplier))


func set_item_skill_slot_bonus(slot_bonus: int) -> Array:
	item_skill_slot_bonus = max(0, int(slot_bonus))
	return _trim_equipped_skills_to_max()


func get_skill_cost(skill_name: String) -> float:
	return float(SKILL_COSTS.get(skill_name, 0.0))


func is_skill_equipped(skill_name: String) -> bool:
	return equipped_skills.has(skill_name)


func unlock_and_equip_skill(skill_name: String) -> bool:
	if not SKILL_DATA.has(skill_name):
		return false
	if equipped_skills.has(skill_name):
		return true
	if equipped_skills.size() >= get_max_skill_slots():
		return false
	equipped_skills.append(skill_name)
	return true


func reset_runtime_skills() -> void:
	equipped_skills = EQUIPPED_SKILLS.duplicate()
	runtime_cooldown_multiplier = 1.0
	item_cooldown_multiplier = 1.0
	item_skill_slot_bonus = 0


func get_skill_data(skill_name: String) -> Dictionary:
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
		"plasma":
			data["korean"] = "Plasma"
			data["description"] = "Fire a plasma orb forward. Enemies touching it are slowed; longer charge strengthens the slow."
			data["how_to_use"] = "Hold W/Up, then release"
			data["motion_hint"] = "Fire a plasma orb forward"
		"recovery":
			data["korean"] = "Recovery"
			data["description"] = "Immediately cancels dash recovery and grants a temporary 50% movement speed bonus."
			data["how_to_use"] = "Press W/Up during dash recovery"
			data["motion_hint"] = "Green light cancels recovery and accelerates"
		"cleanse":
			data["korean"] = "Cleanse"
			data["description"] = "Immediately clears status effects such as stun or slow and grants temporary immunity."
			data["how_to_use"] = "Press W while affected by a status effect"
			data["motion_hint"] = "Golden cleanse clears status effects"
		"shield_kiting":
			data["korean"] = "Shield Kiting"
			data["description"] = "Charge and throw an energy shield for up to 0.36s. On hit, ball speed increases 30% and the shield returns immediately."
			data["how_to_use"] = "Double-click left mouse or double-tap SPACE"
			data["motion_hint"] = "Throw and recall an energy shield"
		"drive":
			data["korean"] = "Drive"
			data["description"] = "Strike the ball into a curve shot. Early input before the ball arrives improves accuracy."
			data["how_to_use"] = "Press Left/Right + left-click together"
			data["motion_hint"] = "Curve the ball with a drive shot"
		"power_smashing":
			data["korean"] = "Power Smashing"
			data["description"] = "Launch the ball with a powerful smash. Left/right input controls launch direction."
			data["how_to_use"] = "Hold Left/Right + left-click"
			data["motion_hint"] = "Launch the ball with a heavy smash"
		"magnum_grip":
			data["korean"] = "Magnum Grip"
			data["description"] = "Pull the ball toward the paddle with a powerful magnetic field. Returning the pulled ball raises its speed cap to 45."
			data["how_to_use"] = "Press Left+Right together"
			data["motion_hint"] = "Pull the ball to the paddle with magnetism"
		"ghost_shot":
			data["korean"] = "Ghost Smashing"
			data["description"] = "The ball snakes around while a ghost follows it. At 420+ gauge, replaces Power Smashing."
			data["how_to_use"] = "At 420+ gauge, hold Left/Right + left-click"
			data["motion_hint"] = "Snaking ball with ghost pursuit"
		"warp_gate":
			data["korean"] = "Warp Gate"
			data["description"] = "Open dimensional portals for a duration. You can cross left/right walls without extra gauge cost."
			data["how_to_use"] = "Hold S or Down for at least 0.5s"
			data["motion_hint"] = "Open portals to warp through side walls"
		"smasher_wheel":
			data["korean"] = "Smasher Wheel"
			data["description"] = "The paddle spins for 1.2s. On ball contact, it relaunches very fast toward the boss with a strong drive curve."
			data["how_to_use"] = "Input A-W-D or D-W-A within 0.6s"
			data["motion_hint"] = "Spin the paddle and relaunch the ball"


func _get_effective_cooldown_seconds_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in COOLDOWN_SECONDS.keys():
		result[str(skill_name)] = get_cooldown_seconds(str(skill_name))
	return result


func _get_effective_skill_data_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in SKILL_DATA.keys():
		result[str(skill_name)] = get_skill_data(str(skill_name))
	return result


func _get_effective_cooldown_multiplier() -> float:
	return max(0.0, runtime_cooldown_multiplier) * max(0.0, item_cooldown_multiplier)


func _trim_equipped_skills_to_max() -> Array:
	var removed: Array = []
	var max_slots: int = get_max_skill_slots()
	while equipped_skills.size() > max_slots:
		removed.append(equipped_skills.pop_back())
	return removed
