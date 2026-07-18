extends RefCounted

# 콜드부트 결과 티어 프레젠테이션 플랜(CB2) — committed_record만 읽어
# 결정론적으로 파생한다(라이브 RNG 없음). 티어 모델은 "기본 3결과(성공/
# 부작용/부산물) + stable 대체 분기"다: stable은 독립 4번째 결과가 아니라
# 부작용 롤이 core_stabilize 세이브(코일 SNAP-IN) 또는 빈 페널티 해소로
# 성공급 부팅으로 대체된 분기다(docs/perk_fusion_cold_boot_cinematic_plan.md §4).
#
# 소비 계약(CB3): 카운트는 기계 거동의 물량이다 —
#   brown_out_lane_count  = option_penalties 총 옵션 수(B3 회로 레인 암전)
#   ejected_module_count  = deleted_options 총 키 수(B3 퓨즈-모듈 물리 EJECT)
#   deployed_module_count = byproducts 수(B4 각성 하드웨어 전개, 1~3)
# tell은 부팅 게이지/이그니션의 거동 차등이다(리컬러 금지 원칙):
#   boot_stutter     = raw 부작용 롤(B2 게이지 스터터 — stable 세이브여도
#                      게이지는 흔들렸다가 클램프된다)
#   boot_overshoot   = 부산물(B2 상한 돌파 + 골드 2차 링)
#   ignition_surge   = 확정 부작용(B3 임계 SURGE)
#   stabilizer_snap  = core_stabilize 소비 세이브(B3 안정화 코일 SNAP-IN)

const READOUT_SYNC_OK := "sync_ok"
const READOUT_OVERLOAD_DERATE := "overload_derate"
const READOUT_CORE_AWAKENED := "core_awakened"
const READOUT_STABILIZED := "stabilized"


static func build_plan(record: Dictionary) -> Dictionary:
	var tier := str(record.get("outcome", "success"))
	var raw_tier := str(record.get("raw_outcome", tier))
	var brown_out_lane_count := _count_option_penalties(record.get("option_penalties", {}))
	var ejected_module_count := _count_deleted_options(record.get("deleted_options", {}))
	var deployed_module_count := (record.get("byproducts", []) as Array).size()
	var stabilizer_snap := (
		tier == "stable"
		and raw_tier == "side_effect"
		and bool(record.get("core_stabilize_consumed", false))
	)
	return {
		"tier": tier,
		"raw_tier": raw_tier,
		"readout_id": _resolve_readout_id(tier),
		"boot_stutter": raw_tier == "side_effect",
		"boot_overshoot": tier == "byproduct",
		"ignition_surge": tier == "side_effect",
		"ignition_dual_gold_ring": tier == "byproduct",
		"stabilizer_snap": stabilizer_snap,
		"brown_out_lane_count": brown_out_lane_count,
		"ejected_module_count": ejected_module_count,
		"deployed_module_count": deployed_module_count,
	}


static func _resolve_readout_id(tier: String) -> String:
	match tier:
		"side_effect":
			return READOUT_OVERLOAD_DERATE
		"byproduct":
			return READOUT_CORE_AWAKENED
		"stable":
			return READOUT_STABILIZED
	return READOUT_SYNC_OK


static func _count_option_penalties(penalties_value: Variant) -> int:
	if not penalties_value is Dictionary:
		return 0
	var count := 0
	for perk_penalties_value: Variant in (penalties_value as Dictionary).values():
		if perk_penalties_value is Dictionary:
			count += (perk_penalties_value as Dictionary).size()
	return count


static func _count_deleted_options(deleted_value: Variant) -> int:
	if not deleted_value is Dictionary:
		return 0
	var count := 0
	for deleted_keys_value: Variant in (deleted_value as Dictionary).values():
		if deleted_keys_value is Array:
			count += (deleted_keys_value as Array).size()
	return count
