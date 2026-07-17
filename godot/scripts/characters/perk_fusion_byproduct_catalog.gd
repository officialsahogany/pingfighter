extends RefCounted

const GENERAL_IDS := [
	"overload_circuit",
	"reverb",
	"golden_trajectory",
	"static_field",
	"recycle_protocol",
]
const RARE_IDS := [
	"core_stabilize",
	"limit_break",
	"dual_catalyst",
]
const RESERVED_IDS := [
	"overflow",
	"magnet_burst",
	"lingpet_resonance",
	"weather_adapt",
	"mutation_factor",
	"twin_roulette",
]

const DATA := {
	"overload_circuit": {"name": "과부하 회로", "detail": "대쉬 뒤 첫 타구의 공 속도가 15% 증가합니다.", "rarity": "general", "runtime_enabled": true},
	"reverb": {"name": "잔향", "detail": "스킬 사용 뒤 3초 동안 이동 속도가 25% 증가합니다.", "rarity": "general", "runtime_enabled": true},
	"golden_trajectory": {"name": "황금 궤적", "detail": "공이 벽에 반사될 때 골드 2를 얻습니다. 라운드당 최대 40골드입니다.", "rarity": "general", "runtime_enabled": true},
	"static_field": {"name": "정전기장", "detail": "실점 직후 4초 동안 보스 이동 속도가 30% 감소합니다.", "rarity": "general", "runtime_enabled": true},
	"recycle_protocol": {"name": "재활용 프로토콜", "detail": "실점할 때 25% 확률로 대쉬 토큰을 모두 회복합니다.", "rarity": "general", "runtime_enabled": true},
	"core_stabilize": {"name": "융합핵 안정화", "detail": "다음 융합 1회의 부작용을 안정 융합으로 바꿉니다.", "rarity": "rare", "runtime_enabled": true},
	"limit_break": {"name": "한계 돌파", "detail": "적용 가능한 재료 퍽의 유효레벨이 1 증가합니다.", "rarity": "rare", "runtime_enabled": true},
	"dual_catalyst": {"name": "이중 촉매", "detail": "다음 부산물 가능 융합의 부산물 확률이 15%p 증가합니다.", "rarity": "rare", "runtime_enabled": true},
	"overflow": {"name": "오버플로우", "rarity": "reserved", "runtime_enabled": false},
	"magnet_burst": {"name": "자석 방출", "rarity": "reserved", "runtime_enabled": false},
	"lingpet_resonance": {"name": "링펫 공명", "rarity": "reserved", "runtime_enabled": false},
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


func get_contextual_pool(owned_ids: Array, limit_break_eligible_sources: Array) -> Array[String]:
	var owned_lookup: Dictionary = {}
	for value: Variant in owned_ids:
		owned_lookup[str(value)] = true
	var pool: Array[String] = []
	for byproduct_id: String in GENERAL_IDS + RARE_IDS:
		if owned_lookup.has(byproduct_id):
			continue
		if byproduct_id == "limit_break" and limit_break_eligible_sources.is_empty():
			continue
		pool.append(byproduct_id)
	return pool


func is_runtime_enabled(byproduct_id: String) -> bool:
	return bool(DATA.get(byproduct_id.strip_edges(), {}).get("runtime_enabled", false))


func get_all_data() -> Dictionary:
	return DATA.duplicate(true)
