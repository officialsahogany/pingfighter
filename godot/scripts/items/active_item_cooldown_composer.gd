extends RefCounted

# 액티브 아이템 쿨다운 공용 최종 composer.
# 슬롯 컨트롤러(판정)·전투 HUD(웻지)·TAB 정보창이 반드시 같은 체인
# (퍽 → 신화 → 최종 하한)으로 같은 값을 읽게 하는 단일 지점이다.
# 하한 계약은 cooldown_floor_policy.gd 참조 (base>0 → 최종 ≥ base의 5%).

const CooldownFloorPolicy := preload("res://scripts/characters/cooldown_floor_policy.gd")


static func compose_effective_cooldown_msec(
	base_cooldown_msec: int,
	runtime_perk_state: Object,
	mythic_item_runtime: Object
) -> int:
	var base_msec: int = maxi(0, base_cooldown_msec)
	var cooldown_msec: int = base_msec
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(runtime_perk_state.get_active_item_cooldown_msec(cooldown_msec))
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(mythic_item_runtime.get_active_item_cooldown_msec(cooldown_msec))
	return CooldownFloorPolicy.floor_final_msec(base_msec, cooldown_msec)
