extends RefCounted

const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const MAX_SKILL_SLOTS := 5
const EQUIPPED_SKILLS := ["shadow_step", "marshal_kick", "blade_rush"]
const SKILL_COSTS := {
	"shadow_step": 100.0,
	"blade_rush": 200.0,
	"nerve_strike": 90.0,
	"dive_strike": 250.0,
	"marshal_kick": 80.0,
	"phantom_kick": 60.0,
	"dark_blade": 150.0,
	"chaos_spear": 150.0,
	"core_flip": 120.0,
	"dual_glitch": 220.0,
	"ignition_aura": 230.0,
}
const SKILL_COLORS := {
	"shadow_step": Color(100.0 / 255.0, 0.0, 180.0 / 255.0),
	"blade_rush": Color(200.0 / 255.0, 50.0 / 255.0, 1.0),
	"nerve_strike": Color(180.0 / 255.0, 0.0, 220.0 / 255.0),
	"dive_strike": Color(1.0, 120.0 / 255.0, 50.0 / 255.0),
	"marshal_kick": Color(130.0 / 255.0, 0.0, 200.0 / 255.0),
	"phantom_kick": Color(180.0 / 255.0, 0.0, 1.0),
	"dark_blade": Color(120.0 / 255.0, 0.0, 30.0 / 255.0),
	"chaos_spear": Color(135.0 / 255.0, 70.0 / 255.0, 1.0),
	"core_flip": Color(1.0, 110.0 / 255.0, 200.0 / 255.0),
	"dual_glitch": Color(60.0 / 255.0, 220.0 / 255.0, 150.0 / 255.0),
	"ignition_aura": Color(1.0, 130.0 / 255.0, 40.0 / 255.0),
}
const COOLDOWN_SECONDS := {
	"shadow_step": 15.0,
	"blade_rush": 20.0,
	"nerve_strike": 35.0,
	"dive_strike": 70.0,
	"marshal_kick": 25.0,
	"phantom_kick": 40.0,
	"dark_blade": 45.0,
	"chaos_spear": 30.0,
	"core_flip": 25.0,
	"dual_glitch": 40.0,
	"ignition_aura": 70.0,
}
const SKILL_DATA := {
	"shadow_step": {
		"name": "shadow_step",
		"korean": "쉐도우 백스텝",
		"cost": 100.0,
		"color": Color(100.0 / 255.0, 0.0, 180.0 / 255.0),
		"cooldown": 15.0,
		"description": "대쉬를 하기 전 위치로 순간이동합니다.\n빠르게 뒷차기를 하며 연계기를 엽니다.\n마샬 킥 또는 다크 블레이드 선행기술.",
		"how_to_use": "대쉬 중 또는 직후 S키로 발동",
		"motion_hint": "잔상 남기고 시작 위치로 텔레포트",
		"effect_type": "shadow_teleport",
	},
	"blade_rush": {
		"name": "blade_rush",
		"korean": "에어 블레이드",
		"cost": 200.0,
		"color": Color(200.0 / 255.0, 50.0 / 255.0, 1.0),
		"cooldown": 20.0,
		"description": "체공 중 전방으로 검기를 발사합니다.\n발사 전 짧은 준비동작이 있습니다.\n검기에 맞은 공은 난이도와 관계없이 공속 상한 40을 적용합니다.",
		"how_to_use": "체공 중 W키 또는 위쪽 방향키로 발동",
		"motion_hint": "전방으로 거대한 보라 검기 발사",
		"effect_type": "slash_purple",
	},
	"nerve_strike": {
		"name": "nerve_strike",
		"korean": "베놈 엣지",
		"cost": 90.0,
		"color": Color(180.0 / 255.0, 0.0, 220.0 / 255.0),
		"cooldown": 35.0,
		"description": "상대의 배후로 빠르게 날아갑니다.\n등 뒤에서 눈을 베어 혼란을 부여합니다.",
		"how_to_use": "블레이드 계열 스킬 사용 후 착지 전 W 또는 위쪽 방향키",
		"motion_hint": "보스 등 뒤로 날아가 베어 혼란 부여",
		"effect_type": "stun_purple",
	},
	"dive_strike": {
		"name": "dive_strike",
		"korean": "EMP 스트라이크",
		"cost": 250.0,
		"color": Color(1.0, 120.0 / 255.0, 50.0 / 255.0),
		"cooldown": 70.0,
		"description": "강한 충격으로 원형 EMP 펄스를 끝까지 퍼트려 공을 튕기고 상대를 감전 둔화시킵니다.\n원형 파동의 테두리가 보스에게 닿으면 보스를 슬립 상태로 만듭니다.\n체공 높이에 비례해 펄스 강도가 증가합니다.",
		"how_to_use": "체공 중 S키 또는 아래쪽 방향키를 0.3초 이상 누르기",
		"motion_hint": "끝까지 퍼지는 원형 EMP 둔화",
		"effect_type": "dive_impact",
	},
	"marshal_kick": {
		"name": "marshal_kick",
		"korean": "마샬 킥",
		"cost": 80.0,
		"color": Color(130.0 / 255.0, 0.0, 200.0 / 255.0),
		"cooldown": 25.0,
		"description": "벽을 짚은 뒤 강한 반동으로 돌진합니다.\n공을 향해 날아가 발로 찹니다.\n다양한 콤보 연계에 사용됩니다.",
		"how_to_use": "쉐도우 백스텝, 블레이드 계열, 화랑 킥 발동 후",
		"motion_hint": "벽점프 후 공 쪽으로 돌진",
		"effect_type": "wall_dive_purple",
	},
	"phantom_kick": {
		"name": "phantom_kick",
		"korean": "팬텀 킥",
		"cost": 60.0,
		"color": Color(180.0 / 255.0, 0.0, 1.0),
		"cooldown": 40.0,
		"description": "마샬 킥 반동에 암흑 에너지를 싣습니다.\n쉐도우 백스텝 연계 시 공중 백스텝만 가능합니다.",
		"how_to_use": "마샬 킥 적중 후 S키 또는 아래쪽 방향키",
		"motion_hint": "암흑반물질 발차기",
		"effect_type": "wall_dive_purple",
	},
	"dark_blade": {
		"name": "dark_blade",
		"korean": "다크 블레이드",
		"cost": 150.0,
		"color": Color(120.0 / 255.0, 0.0, 30.0 / 255.0),
		"cooldown": 45.0,
		"description": "공을 타격한 뒤 붉게 빛나는 1초 안에 공중에서 강화 검기를 쏩니다.\n검기 적중 시 마샬 킥 윈도우가 열립니다.\n검붉은 강화 검기에 맞은 공은 난이도와 관계없이 공속 상한 50을 적용합니다.",
		"how_to_use": "쉐도우 백스텝, 에어 블레이드, 마샬/팬텀/화랑 킥 타격 후",
		"motion_hint": "공중에서 검붉은 강화 검기 발사",
		"effect_type": "slash_dark",
	},
	"chaos_spear": {
		"name": "chaos_spear",
		"korean": "카오스 스피어",
		"cost": 150.0,
		"color": Color(135.0 / 255.0, 70.0 / 255.0, 1.0),
		"cooldown": 30.0,
		"description": "혼돈의 창을 투척합니다.\n맵 중앙에 블랙홀이 생성됩니다.\n공과 일반 투사체를 빨아들입니다.",
		"how_to_use": "지상에서 A, W, D 순서로 입력",
		"motion_hint": "맵 중앙 블랙홀로 공과 투사체 흡수",
		"effect_type": "chaos_vortex",
	},
	"core_flip": {
		"name": "core_flip",
		"korean": "화랑 킥",
		"cost": 120.0,
		"color": Color(1.0, 110.0 / 255.0, 200.0 / 255.0),
		"cooldown": 25.0,
		"description": "화랑의 혼을 실은 킥으로 공을 타격합니다.\n예측이 힘든 사선으로 반격합니다.",
		"how_to_use": "대쉬로 공 타격 후 A와 D를 함께 입력",
		"motion_hint": "벽을 두 번 차고 공으로 돌진",
		"effect_type": "core_flip_arc",
	},
	"dual_glitch": {
		"name": "dual_glitch",
		"korean": "듀얼 글리치",
		"cost": 220.0,
		"color": Color(60.0 / 255.0, 220.0 / 255.0, 150.0 / 255.0),
		"cooldown": 40.0,
		"description": "바이퍼 고대기술로 스스로를 분열합니다.\n분신이 플레이어 움직임을 미러링합니다.\n좌우에서 공을 가드합니다.",
		"how_to_use": "A, D, A, D 순서 또는 좌우좌우 입력",
		"motion_hint": "좌우 분신 패들 소환",
		"effect_type": "glitch_clone",
	},
	"ignition_aura": {
		"name": "ignition_aura",
		"korean": "이그니션 오라",
		"cost": 230.0,
		"color": Color(1.0, 130.0 / 255.0, 40.0 / 255.0),
		"cooldown": 70.0,
		"description": "체내의 화염 에너지를 증폭합니다.\n일정 기간 모든 퍽 레벨이 증가합니다.\n골드 보너스도 함께 증가합니다.",
		"how_to_use": "지상에서 W키 또는 위쪽 방향키를 0.5초 이상 누르기",
		"motion_hint": "화염 에너지 분출",
		"effect_type": "ignition_burst",
	},
}

var equipped_skills: Array = EQUIPPED_SKILLS.duplicate()
var runtime_cooldown_multiplier := 1.0
var item_cooldown_multiplier := 1.0
var item_skill_slot_bonus := 0

# get_snapshot() 캐시 — smasher_skill_config.gd의 캐시 주석 참조. 입력 필드가
# 그대로면 같은 Dictionary를 공유 참조로 돌려준다 (소비자는 읽기 전용 계약).
# 무효화는 매 호출 값 비교 + 언어 비교, 재빌드는 새 Dictionary 교체.
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
		_append_guard_speed_reduction_description(data, skill_name)
		return data
	return {}


func _append_guard_speed_reduction_description(data: Dictionary, skill_name: String) -> void:
	if skill_name != "shadow_step" and skill_name != "marshal_kick":
		return
	var line: String = "상대가 가드하면 돌아오는 공속이 50% 감소합니다."
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		line = "If the opponent guards it, the returned ball loses 50% speed."
	var description: String = str(data.get("description", ""))
	if description.find(line) >= 0:
		return
	data["description"] = line if description.is_empty() else description + "\n" + line


func _localize_skill_data(data: Dictionary, skill_name: String) -> void:
	var language := LanguageSettings.get_language()
	if language == LanguageSettings.LANGUAGE_KOREAN:
		return
	if language == LanguageSettings.LANGUAGE_CHINESE or language == LanguageSettings.LANGUAGE_JAPANESE or language == LanguageSettings.LANGUAGE_SPANISH or language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL or language == LanguageSettings.LANGUAGE_RUSSIAN:
		LanguageSettings.localize_skill_config_data(data, skill_name)
		return
	match skill_name:
		"shadow_step":
			data["korean"] = "Shadow Backstep"
			data["description"] = "Teleport back to the position before your dash. Opens combo routes with a fast back kick."
			data["how_to_use"] = "Press S during or right after dash"
			data["motion_hint"] = "Leave an afterimage and teleport to the start point"
		"blade_rush":
			data["korean"] = "Air Blade"
			data["description"] = "Fire a blade wave forward while airborne. Has a short windup; balls hit by it use a speed cap of 40 regardless of difficulty."
			data["how_to_use"] = "Press W or Up while airborne"
			data["motion_hint"] = "Fire a giant purple slash forward"
		"nerve_strike":
			data["korean"] = "Venom Edge"
			data["description"] = "Rush behind the opponent and slash from behind to inflict confusion."
			data["how_to_use"] = "After a blade skill, press W or Up before landing"
			data["motion_hint"] = "Fly behind the boss and slash to confuse"
		"dive_strike":
			data["korean"] = "EMP Strike"
			data["description"] = "Release the circular EMP pulse with a hard impact, bouncing the ball and disrupting enemy movement. The same expanding ring reaches the boss and applies EMP slip. Pulse strength scales with airborne height."
			data["how_to_use"] = "Hold S or Down for 0.3s while airborne"
			data["motion_hint"] = "Full-reach circular EMP slow"
		"marshal_kick":
			data["korean"] = "Martial Kick"
			data["description"] = "Kick off a wall and rush toward the ball. Used as a combo bridge."
			data["how_to_use"] = "After Shadow Backstep, blade skills, or Hwarang Kick"
			data["motion_hint"] = "Wall-jump and rush toward the ball"
		"phantom_kick":
			data["korean"] = "Phantom Kick"
			data["description"] = "Load dark energy into the rebound from Martial Kick."
			data["how_to_use"] = "Press S or Down after Martial Kick hits"
			data["motion_hint"] = "Dark antimatter kick"
		"dark_blade":
			data["korean"] = "Dark Blade"
			data["description"] = "Within 3 seconds after hitting the ball, fire an empowered aerial slash. On hit, it opens the Martial Kick window."
			data["how_to_use"] = "After Shadow Backstep, Air Blade, Martial/Phantom/Hwarang Kick hits"
			data["motion_hint"] = "Fire a dark red empowered slash in the air"
		"chaos_spear":
			data["korean"] = "Chaos Spear"
			data["description"] = "Throw a spear of chaos. A black hole forms at center map and pulls in the ball and normal projectiles."
			data["how_to_use"] = "Input A, W, D on the ground"
			data["motion_hint"] = "Center-map black hole absorbs balls and projectiles"
		"core_flip":
			data["korean"] = "Hwarang Kick"
			data["description"] = "Kick the ball with Hwarang spirit and counterattack along a hard-to-read diagonal."
			data["how_to_use"] = "After hitting the ball with dash, press A and D together"
			data["motion_hint"] = "Kick off walls twice and rush toward the ball"
		"dual_glitch":
			data["korean"] = "Dual Glitch"
			data["description"] = "Split yourself with ancient Viper tech. Clones mirror player movement and guard the ball from both sides."
			data["how_to_use"] = "Input A, D, A, D or left-right-left-right"
			data["motion_hint"] = "Summon left and right clone paddles"
		"ignition_aura":
			data["korean"] = "Ignition Aura"
			data["description"] = "Amplify internal fire energy. All perk levels increase for a duration, and gold bonuses increase too."
			data["how_to_use"] = "Hold W or Up for 0.5s on the ground"
			data["motion_hint"] = "Release flame energy"


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
	return CooldownFloorPolicy.floor_final_multiplier(
		max(0.0, runtime_cooldown_multiplier) * max(0.0, item_cooldown_multiplier)
	)


func _trim_equipped_skills_to_max() -> Array:
	var removed: Array = []
	var max_slots: int = get_max_skill_slots()
	while equipped_skills.size() > max_slots:
		removed.append(equipped_skills.pop_back())
	return removed
