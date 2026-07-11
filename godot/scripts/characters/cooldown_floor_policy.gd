extends RefCounted

# 최종 합성 쿨다운 하한 정책 (2026-07-11 감사 합의):
# 기본 쿨다운이 양수인 경우, 모든 효과(퍽 유효레벨·연마·융합·천사의 주사위·
# 신화 아이템 배수)를 적용한 최종 쿨다운은 기본값의 5% 미만으로 내려가지
# 않는다 (최대 95% 감소). 기본값이 의도적으로 0인 스킬·아이템은 계속 0이다.
#
# 적용 지점은 중간 쿼리 서피스가 아니라 "최종 합성점"이다:
# - 스킬: 캐릭터 skill_config의 runtime × item 배수 합성
#   (smasher/viper/commando/blacksmith `_get_effective_cooldown_multiplier`)
# - 액티브 아이템: 퍽 → 신화 체인 이후 (active_item_cooldown_composer,
#   TAB `active_item_cooldown_from_base`)
# - 바이퍼 사독 가산 경로 (`viper_skill_scaling`)
# 중간 헬퍼(runtime_perk_effective_stat_query_surface 등)에는 하한을 넣지
# 않는다 — 이중 적용/표시-판정 괴리를 막기 위해 최종 지점 단일 적용.

const FINAL_COOLDOWN_MULTIPLIER_FLOOR := 0.05


static func floor_final_multiplier(final_multiplier: float) -> float:
	return maxf(FINAL_COOLDOWN_MULTIPLIER_FLOOR, final_multiplier)


static func floor_final_seconds(base_seconds: float, final_seconds: float) -> float:
	if base_seconds <= 0.0:
		return maxf(0.0, final_seconds)
	return maxf(final_seconds, base_seconds * FINAL_COOLDOWN_MULTIPLIER_FLOOR)


static func floor_final_msec(base_msec: int, final_msec: int) -> int:
	if base_msec <= 0:
		return maxi(0, final_msec)
	return maxi(final_msec, int(ceilf(float(base_msec) * FINAL_COOLDOWN_MULTIPLIER_FLOOR)))
