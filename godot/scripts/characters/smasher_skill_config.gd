extends RefCounted

const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherPlasmaState := preload("res://scripts/characters/smasher_plasma_state.gd")

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
	"smasher_wheel": 240.0,
	"smasher_overdrive": 220.0,
	"void_phantom": 320.0,
}
const SKILL_COLORS := {
	"drive": Color(0.36, 0.62, 1.0),
	"power_smashing": Color(0.30, 0.88, 1.0),
	"plasma": Color(0.0, 200.0 / 255.0, 1.0),
	"recovery": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
	"cleanse": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
	"shield_kiting": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
	"magnum_grip": Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
	"ghost_shot": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
	"warp_gate": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
	"smasher_wheel": Color(0.64, 0.84, 1.0),
	"smasher_overdrive": Color(80.0 / 255.0, 225.0 / 255.0, 1.0),
	"void_phantom": Color(0.35, 0.90, 1.0),
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
	# 회선반동(가드 후 재돌격)으로 한 번 발동에 보스 가드를 두 번 강요하게 되면서
	# 25초로는 회전이 너무 빨랐다. 같은 "가드 한 번으로 안 끝나는" 급인
	# 벽력유성(220기력/28초)에 쿨타임을 맞추고 기력은 240으로 더 비싸게 둔다
	# (2026-08-05 게이지 소모 상향: 유성 220 / 천선무 240 / 허공환영 320).
	"smasher_wheel": 28.0,
	"smasher_overdrive": 28.0,
	"void_phantom": 70.0,
}
const SKILL_DATA := {
	"plasma": {
		"name": "plasma",
		"korean": "한령탄",
		"cost": 40.0,
		"color": Color(0.0, 200.0 / 255.0, 1.0),
		"cooldown": 8.0,
		"description": "전방으로 한령탄을 발사합니다.\n한령탄에 닿는 동안 적이 둔화됩니다.\n충전이 길수록 둔화 성능이 강해집니다.",
		"how_to_use": "W/↑ 홀드 후 손을 떼면 발동",
		"motion_hint": "전방으로 한령탄을 발사",
		"effect_type": "projectile_cyan",
	},
	"recovery": {
		"name": "recovery",
		"korean": "경신보",
		"cost": 120.0,
		"color": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
		"cooldown": 12.0,
		"description": "활주 후딜을 즉시 제거합니다.\n일정 기간 이동속도 50% 보너스를 얻습니다.",
		"how_to_use": "활주 후딜 중 W/↑ 키로 발동",
		"motion_hint": "녹색 빛으로 후딜 제거 + 가속",
		"effect_type": "heal_green",
	},
	"cleanse": {
		"name": "cleanse",
		"korean": "청심결",
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
		"korean": "회천비륜",
		"cost": 130.0,
		"color": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
		"cooldown": 12.0,
		"description": "귀면 방패에 기운을 모아 최대 0.36초 후 회전 투척합니다.\n명중 시 공속이 30% 증가하고 즉시 손으로 돌아옵니다.\n낮고 먼 하강 공에는 더 빠르게 반응합니다.",
		"how_to_use": "좌클릭 더블클릭 또는 SPACE 더블탭으로 발동",
		"motion_hint": "귀면 방패를 회전 투척 후 회수",
		"effect_type": "shield_kiting_arc",
	},
	"drive": {
		"name": "drive",
		"korean": "벽력타",
		"cost": 150.0,
		"color": Color(0.36, 0.62, 1.0),
		"cooldown": 15.0,
		"description": "벽력의 기운을 실어 공을 휘어칩니다.\n공이 오기 전에 미리 입력하면 더 정확하게 들어갑니다.",
		"how_to_use": "←/→ + 좌클릭 동시 입력으로 발동",
		"motion_hint": "청자색 뇌광을 두른 커브 타격",
		"effect_type": "drive_curve",
	},
	"power_smashing": {
		"name": "power_smashing",
		"korean": "천뢰격",
		"cost": 300.0,
		"color": Color(0.30, 0.88, 1.0),
		"cooldown": 35.0,
		"description": "하늘의 벼락을 공에 실어 강타합니다.\n좌/우 방향키로 발사 방향을 지정할 수 있습니다.\n단독 클릭 홀드 시 맞은 반대쪽으로 자동 발사됩니다.",
		"how_to_use": "←/→ + 좌클릭 홀드로 발동",
		"motion_hint": "청백색 뇌광을 두른 공을 발사",
		"effect_type": "thunder_strike",
	},
	"magnum_grip": {
		"name": "magnum_grip",
		"korean": "흡인장",
		"cost": 70.0,
		"color": Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
		"cooldown": 22.0,
		"description": "강력한 자기장으로 공을 몸쪽으로 끌어당깁니다.\n공이 몸에 닿으면 자기장이 해제됩니다.\n끌어온 공을 받아치면 공속 상한이 45까지 증가합니다.",
		"how_to_use": "←+→ 동시 입력으로 발동",
		"motion_hint": "자기장으로 공을 몸쪽으로 끌어당김",
		"effect_type": "magnetic_pull_blue",
	},
	"ghost_shot": {
		"name": "ghost_shot",
		"korean": "빙혼비격",
		"cost": 420.0,
		"color": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
		"cooldown": 85.0,
		"description": "한미량이 공 속으로 빨려 들어가 빙의한 채 기괴한 궤적으로 보스에게 비격을 날립니다.\n기력 420 이상에서 천뢰격 대신 발동됩니다.",
		"how_to_use": "기력 420 이상에서 ←/→ + 좌클릭 홀드로 발동",
		"motion_hint": "한미량의 영체가 공에 스며들어 비격",
		"effect_type": "ghost_purple",
	},
	"warp_gate": {
		"name": "warp_gate",
		"korean": "건곤환문",
		"cost": 100.0,
		"color": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
		"cooldown": 50.0,
		"description": "일정 기간 건곤환문을 전개합니다.\n좌/우 경계를 넘어 반대편으로 순간이동할 수 있습니다.\n문을 넘어도 추가 기력을 소모하지 않습니다.\n통과 후 2초간 이동 경로에 환문잔영이 남습니다. 잔영은 공을 한 번 받아친 뒤 연기로 흩어집니다.",
		"description_max_lines": 7,
		"how_to_use": "S 또는 ↓ 키를 0.5초 이상 홀드하여 발동",
		"motion_hint": "건곤의 문을 열어 좌/우 경계를 넘음",
		"effect_type": "portal_purple",
	},
	"smasher_overdrive": {
		"name": "smasher_overdrive",
		"korean": "벽력유성",
		"cost": 220.0,
		"color": Color(80.0 / 255.0, 225.0 / 255.0, 1.0),
		"cooldown": 28.0,
		"description": "우클릭을 유지한 채 받아친 공이 반대쪽으로 활강하다 보스 코앞에서 급전합니다.\n←/→로 최종 낙하 지점을 지정하며, 방향키 없이 치면 맞은 각도의 반대쪽으로 꺾입니다.\n보스가 공을 가드하면 즉시 종료됩니다.",
		"how_to_use": "마우스 우클릭 홀드 + ←/→로 타구 시 발동",
		"motion_hint": "반대쪽으로 낚은 뒤 보스 앞에서 역방향 급전",
		"effect_type": "overdrive_meteor_break",
	},
	"smasher_wheel": {
		"name": "smasher_wheel",
		"korean": "풍운천선무",
		"cost": 240.0,
		"color": Color(0.64, 0.84, 1.0),
		"cooldown": 25.0,
		"description": "1.2초간 한미량이 구름을 휘감으며 회전합니다.\n공에 닿으면 구름을 사방으로 흩뜨리며 보스 방향으로 고속 곡선 반격을 날립니다.\n보스가 가드하면 공이 빙글 휘감겨 내려갔다 다시 솟구칩니다(발동당 1회).\n반격은 공속 상한 60. 발동 중 활주 불가, 이동속도 -15%.",
		"how_to_use": "A→W→D (오른쪽) 또는 D→W→A (왼쪽) 순서로 0.6초 내 입력",
		"motion_hint": "구름을 휘감아 반격하고, 가드당하면 회선하며 재돌격",
		# 오브 툴팁의 기본 설명 예산은 5줄인데 `_wrap_text` 는 초과분을 조용히
		# 버린다. 300px 패널 실측 랩 결과 최대 7줄(한국어)이 필요하다 —
		# 회선반동 문구 이전에도 한국어 마지막 줄이 통째로 잘리고 있었다.
		# 씰: smasher_wheel_rebound_smoke._test_tooltip_wraps_without_clipping.
		"description_max_lines": 8,
		"effect_type": "wheel_spin",
	},
	"void_phantom": {
		"name": "void_phantom",
		"korean": "허공환영",
		"cost": 320.0,
		"color": Color(0.35, 0.90, 1.0),
		"cooldown": 70.0,
		"description": "허공을 갈라 받아친 공의 환영을 함께 띄워 보냅니다.\n반투명 환영 2개가 좌우로 넓게 갈라져 보스가 높은 확률로 착각합니다.\n보스가 가드할 때까지 공 속도가 40% 감소합니다.",
		"how_to_use": "↓/S + 좌클릭을 유지한 채 공을 받아치면 발동",
		"motion_hint": "두 환영이 받아친 공의 좌우로 넓게 갈라져 함께 솟아오름",
		"effect_type": "void_phantom_split",
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
		"skill_costs": _get_effective_skill_costs_map(),
		"skill_colors": _get_effective_skill_colors_map(),
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
	if CommonSkillCatalog.is_common_skill(skill_name):
		return float(CommonSkillCatalog.get_cooldown_seconds_map(_get_effective_cooldown_multiplier()).get(skill_name, 0.0))
	return float(COOLDOWN_SECONDS.get(skill_name, 0.0)) * _get_effective_cooldown_multiplier()


func get_cooldown_reduction_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for skill_name_value: Variant in COOLDOWN_SECONDS.keys():
		if float(COOLDOWN_SECONDS.get(skill_name_value, 0.0)) > 0.0:
			result.append(str(skill_name_value))
	for common_skill_id: String in CommonSkillCatalog.get_all_skill_ids():
		if float(CommonSkillCatalog.get_cooldown_seconds_map().get(common_skill_id, 0.0)) > 0.0:
			result.append(common_skill_id)
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
	if CommonSkillCatalog.is_common_skill(skill_name):
		return float(CommonSkillCatalog.get_skill_costs().get(skill_name, 0.0))
	return float(SKILL_COSTS.get(skill_name, 0.0))


func is_skill_equipped(skill_name: String) -> bool:
	return equipped_skills.has(skill_name)


func unlock_and_equip_skill(skill_name: String) -> bool:
	if not SKILL_DATA.has(skill_name) and not CommonSkillCatalog.is_common_skill(skill_name):
		return false
	if equipped_skills.has(skill_name):
		return true
	if equipped_skills.size() >= get_max_skill_slots():
		return false
	equipped_skills.append(skill_name)
	return true


func is_shared_slot_full() -> bool:
	return equipped_skills.size() >= get_max_skill_slots()


func get_shared_slot_swap_candidates(skill_name: String) -> Array:
	if (not SKILL_DATA.has(skill_name) and not CommonSkillCatalog.is_common_skill(skill_name)) or equipped_skills.has(skill_name):
		return []
	return equipped_skills.duplicate()


func unequip_skill(skill_name: String) -> bool:
	if not equipped_skills.has(skill_name):
		return false
	equipped_skills.erase(skill_name)
	return true


func reset_runtime_skills() -> void:
	equipped_skills = EQUIPPED_SKILLS.duplicate()
	runtime_cooldown_multiplier = 1.0
	item_cooldown_multiplier = 1.0
	item_skill_slot_bonus = 0


func get_skill_data(skill_name: String) -> Dictionary:
	if CommonSkillCatalog.is_common_skill(skill_name):
		var common_data := CommonSkillCatalog.get_skill_data(skill_name)
		common_data["cooldown"] = get_cooldown_seconds(skill_name)
		return common_data
	var value: Variant = SKILL_DATA.get(skill_name, {})
	if value is Dictionary:
		var data: Dictionary = value
		data = data.duplicate(true)
		data["cooldown"] = get_cooldown_seconds(skill_name)
		if skill_name == "plasma":
			# 플라즈마는 차징 비례 쿨(3~15초) — 툴팁이 단일값 대신 range로
			# 표기할 수 있게 실효 쿨감 배수를 접은 범위를 노출한다.
			var cooldown_scale: float = _get_effective_cooldown_multiplier()
			data["cooldown_range"] = [
				SmasherPlasmaState.COOLDOWN_MIN_SECONDS * cooldown_scale,
				SmasherPlasmaState.COOLDOWN_MAX_SECONDS * cooldown_scale,
			]
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
			data["korean"] = "Cold Spirit Orb"
			data["description"] = "Fire a cold spirit orb forward. Enemies touching it are slowed; longer charge strengthens the slow."
			data["how_to_use"] = "Hold W/Up, then release"
			data["motion_hint"] = "Fire a cold spirit orb forward"
		"recovery":
			data["korean"] = "Lightness Step"
			data["description"] = "Immediately cancels dash recovery and grants a temporary 50% movement speed bonus."
			data["how_to_use"] = "Press W/Up during dash recovery"
			data["motion_hint"] = "Green light cancels recovery and accelerates"
		"cleanse":
			data["korean"] = "Clear-Heart Art"
			data["description"] = "Immediately clears status effects such as stun or slow and grants temporary immunity."
			data["how_to_use"] = "Press W while affected by a status effect"
			data["motion_hint"] = "Golden cleanse clears status effects"
		"shield_kiting":
			data["korean"] = "Heaven-Turning Flying Wheel"
			data["description"] = "Charge and throw Miryang's gwimyeon shield as a spinning flying wheel for up to 0.36s. On hit, ball speed increases 30% and the shield returns immediately."
			data["how_to_use"] = "Double-click left mouse or double-tap SPACE"
			data["motion_hint"] = "Spin-throw and recall the gwimyeon shield"
		"drive":
			data["korean"] = "Thunderclap Strike"
			data["description"] = "Curve the ball with a thunderclap-charged strike. Early input before the ball arrives improves accuracy."
			data["how_to_use"] = "Press Left/Right + left-click together"
			data["motion_hint"] = "Curve strike wrapped in blue-violet lightning"
		"power_smashing":
			data["korean"] = "Heavenly Thunder Strike"
			data["description"] = "Launch the ball wrapped in heavenly lightning. Left/right input controls launch direction."
			data["how_to_use"] = "Hold Left/Right + left-click"
			data["motion_hint"] = "Launch the ball wrapped in blue-white lightning"
		"magnum_grip":
			data["korean"] = "Attraction Palm"
			data["description"] = "Pull the ball toward your body with a powerful magnetic field. Returning the pulled ball raises its speed cap to 45."
			data["how_to_use"] = "Press Left+Right together"
			data["motion_hint"] = "Pull the ball to your body with magnetism"
		"ghost_shot":
			data["korean"] = "Spirit-Possession Flying Strike"
			data["description"] = "Miryang is drawn into the ball and possesses it, sending it along an uncanny path before a flying strike at the boss. At 420+ gauge, replaces Heavenly Thunder Strike."
			data["how_to_use"] = "At 420+ gauge, hold Left/Right + left-click"
			data["motion_hint"] = "Miryang's spirit merges with the ball for a flying strike"
		"warp_gate":
			data["korean"] = "Heaven-Earth Exchange Gate"
			data["description"] = "Open paired exchange gates for a duration. You can cross the left/right boundaries without extra gauge cost. After crossing, a trail of afterimages lingers for 2 seconds, returns the ball once, then dissolves into smoke."
			data["how_to_use"] = "Hold S or Down for at least 0.5s"
			data["motion_hint"] = "Open paired gates and cross the side boundaries"
		"smasher_wheel":
			data["korean"] = "Stormcloud Celestial Spin Dance"
			data["description"] = "For 1.2s, Han Miryang spins wrapped in storm clouds. On ball contact, the clouds scatter as she counters toward the boss with a high-speed curve. If the boss guards it, the ball coils back down and surges up again (once per cast)."
			data["how_to_use"] = "Input A-W-D or D-W-A within 0.6s"
			data["motion_hint"] = "Whirl through storm clouds to counter, then coil back up if guarded"
		"smasher_overdrive":
			data["korean"] = "Thunderbolt Meteor"
			data["description"] = "Return the ball with right-click held: it glides to the opposite side, then breaks hard just before the boss. Left/Right picks the final landing side; with no direction it breaks against the angle it was struck at. Ends the moment the boss guards it."
			data["how_to_use"] = "Hold right-click + Left/Right, then return the ball"
			data["motion_hint"] = "Bait to one side, then reverse-break in front of the boss"
		"void_phantom":
			data["korean"] = "Void Phantom"
			data["description"] = "Splits the void so phantoms of the returned ball rise alongside it. Two slightly translucent phantoms split widely to either side, and the boss is very likely to chase one of them."
			data["how_to_use"] = "Hold Down/S + left-click, then return the ball"
			data["motion_hint"] = "Two phantoms split wide to either side of the returned ball"


func _get_effective_cooldown_seconds_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in COOLDOWN_SECONDS.keys():
		result[str(skill_name)] = get_cooldown_seconds(str(skill_name))
	result.merge(CommonSkillCatalog.get_cooldown_seconds_map(_get_effective_cooldown_multiplier()), true)
	return result


func _get_effective_skill_data_map() -> Dictionary:
	var result: Dictionary = {}
	for skill_name in SKILL_DATA.keys():
		result[str(skill_name)] = get_skill_data(str(skill_name))
	result.merge(CommonSkillCatalog.get_all_skill_data(), true)
	for common_skill_id: String in CommonSkillCatalog.get_all_skill_ids():
		result[common_skill_id]["cooldown"] = get_cooldown_seconds(common_skill_id)
	return result


func _get_effective_skill_costs_map() -> Dictionary:
	var result := SKILL_COSTS.duplicate()
	result.merge(CommonSkillCatalog.get_skill_costs(), true)
	return result


func _get_effective_skill_colors_map() -> Dictionary:
	var result := SKILL_COLORS.duplicate()
	result.merge(CommonSkillCatalog.get_skill_colors(), true)
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
