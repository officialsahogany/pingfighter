extends RefCounted

const GENERAL_IDS := [
	"overload_circuit",
	"reverb",
	"golden_trajectory",
	"static_field",
	"recycle_protocol",
	"meridian_expand",
	"gravitybelt",
	"smartphone",
]
const RARE_IDS := [
	"core_stabilize",
	"limit_break",
	"dual_catalyst",
	"linked_arsenal",
	"returning_light_step",
	"spellbreaker_guard",
]
const RESERVED_IDS := [
	"overflow",
	"magnet_burst",
	"lingpet_resonance",
	"weather_adapt",
	"mutation_factor",
	"twin_roulette",
]
# 은퇴 상승무공: 풀에서 영구 제외하고 효과도 제거한다. id는 구 세이브 레코드
# 자가 정리(PerkFusionState prune)를 위해 카탈로그에 남긴다.
const RETIRED_IDS := [
	"sleeve_cosmos",
]

const DATA := {
	"overload_circuit": {"name": "벽력추진", "detail": "활주 중 공을 받아치면 15% 확률로 공 속도가 80% 증가하고 공이 붉은보라색으로 변합니다. 보스가 가드하면 원래 속도와 색으로 돌아옵니다.", "rarity": "general", "runtime_enabled": true},
	"reverb": {"name": "잔향", "detail": "초식 사용 뒤 3초 동안 이동 속도가 70% 증가합니다.", "rarity": "general", "runtime_enabled": true},
	"golden_trajectory": {"name": "황금 궤적", "detail": "공이 벽에 반사될 때 골드 2를 얻습니다. 라운드당 최대 40골드입니다.", "rarity": "general", "runtime_enabled": true},
	"static_field": {"name": "정전기장", "detail": "실점 직후 4초 동안 보스 이동 속도가 30% 감소합니다.", "rarity": "general", "runtime_enabled": true},
	"recycle_protocol": {"name": "절처봉생", "detail": "실점할 때 25% 확률로 활주 횟수를 모두 회복합니다.", "rarity": "general", "runtime_enabled": true},
	"meridian_expand": {"name": "기맥 확장", "detail": "이번 런의 무공 최대 슬롯이 1칸 늘어납니다.", "rarity": "general", "runtime_enabled": true},
	"sleeve_cosmos": {"name": "수리건곤", "rarity": "retired", "runtime_enabled": false},
	"gravitybelt": {"name": "찰나신법", "detail": "방향을 바꾸는 순간 무중력 상태가 되어, 관성 없이 즉시 반대 방향으로 움직입니다.", "rarity": "general", "runtime_enabled": true},
	"smartphone": {"name": "응변결", "detail": "위급 상황에서 회복·스톱워치·금강결계 액티브 아이템을 자동 사용합니다.", "rarity": "general", "runtime_enabled": true},
	"core_stabilize": {"name": "합일 안정화", "detail": "다음 합일 1회의 주화입마를 안정 합일로 바꿉니다.", "rarity": "rare", "runtime_enabled": true},
	"limit_break": {"name": "한계 돌파", "detail": "적용 가능한 무공의 유효 경지가 1 증가합니다.", "rarity": "rare", "runtime_enabled": true},
	"dual_catalyst": {"name": "이중 촉매", "detail": "다음 상승무공 발현 가능 합일의 발현 확률이 15%p 증가합니다.", "rarity": "rare", "runtime_enabled": true},
	"linked_arsenal": {"name": "연환병장", "detail": "보유한 활주구슬마다 액티브 아이템 슬롯이 1칸 늘어납니다.", "rarity": "rare", "runtime_enabled": true},
	"returning_light_step": {"name": "회광환보", "detail": "발동 가능한 활주 토큰이 없고 실점이 임박하면 30% 확률로 공의 예상 낙하지점으로 순간이동합니다.", "rarity": "rare", "runtime_enabled": true},
	"spellbreaker_guard": {"name": "파법호신결", "detail": "공을 받아칠 때 12% 확률로 5초간 파법결계를 펼칩니다. 결계 중 패링 가능한 보스 스킬을 무효화하며 해당 스킬의 사용은 소모됩니다.", "rarity": "rare", "runtime_enabled": true},
	"overflow": {"name": "오버플로우", "rarity": "reserved", "runtime_enabled": false},
	"magnet_burst": {"name": "자석 방출", "rarity": "reserved", "runtime_enabled": false},
	"lingpet_resonance": {"name": "수호령 공명", "rarity": "reserved", "runtime_enabled": false},
	"weather_adapt": {"name": "날씨 적응", "rarity": "reserved", "runtime_enabled": false},
	"mutation_factor": {"name": "변이 인자", "rarity": "reserved", "runtime_enabled": false},
	"twin_roulette": {"name": "쌍둥이 룰렛", "rarity": "reserved", "runtime_enabled": false},
}


func get_data(byproduct_id: String) -> Dictionary:
	var data: Dictionary = DATA.get(byproduct_id.strip_edges(), {})
	if data.is_empty():
		return {}
	var result := data.duplicate(true)
	result["id"] = byproduct_id.strip_edges()
	return result


func get_contextual_pool(
	owned_ids: Array,
	limit_break_eligible_sources: Array,
	perk_conversion_enabled: bool
) -> Array[String]:
	var owned_lookup: Dictionary = {}
	for value: Variant in owned_ids:
		owned_lookup[str(value)] = true
	var pool: Array[String] = []
	for byproduct_id: String in GENERAL_IDS + RARE_IDS:
		if owned_lookup.has(byproduct_id):
			continue
		if byproduct_id == "meridian_expand" and not perk_conversion_enabled:
			continue
		if byproduct_id == "limit_break" and limit_break_eligible_sources.is_empty():
			continue
		pool.append(byproduct_id)
	return pool


func is_runtime_enabled(byproduct_id: String) -> bool:
	return bool(DATA.get(byproduct_id.strip_edges(), {}).get("runtime_enabled", false))


func get_all_data() -> Dictionary:
	return DATA.duplicate(true)
