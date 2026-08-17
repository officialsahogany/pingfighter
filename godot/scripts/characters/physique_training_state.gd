extends RefCounted

# 상한제 폐지(2026-08-08 사용자 결정): 능력치별 상한도 런 전체 상한도 없다. 유일한
# 예외는 카탈로그가 max_count 3 으로 못박은 수납술(액티브 슬롯 +1)이며, 그 판정은
# catalog.get_max_count 한 곳에서만 나온다 — 이 모듈은 별도 총량 게이트를 갖지 않는다.
# ⚠ 이 모듈의 천장 게이트는 **수련 누적치만** 본다. 기보유 이관 무공과 합성되는 호환
# 런의 조기 포화는 `RuntimePerkState.is_physique_training_saturated`(최종 소비자 값
# 비교)가 정본이고, 여기 게이트는 프로브 없는 호출용 하위 폴백이다.
const SNAPSHOT_VERSION := 1

var acquired_counts: Dictionary = {}
var total_acquired_count := 0
var eligible_screen_count_before_dice_exhaustion := 0
var eligible_screen_count_after_dice_exhaustion := 0
var revision := 0


func reset() -> void:
	acquired_counts.clear()
	total_acquired_count = 0
	eligible_screen_count_before_dice_exhaustion = 0
	eligible_screen_count_after_dice_exhaustion = 0
	revision += 1


func can_acquire(training_id: String, catalog: Object) -> bool:
	if catalog == null or not catalog.has_method("has_training"):
		return false
	var clean_id := training_id.strip_edges()
	if not bool(catalog.has_training(clean_id)):
		return false
	# 실효 포화 게이트: 상한은 없어도 소비자가 포화한 뒤의 습득은 결과를 바꾸지 못하는
	# 죽은 카드다(순환결 15회차 = 이미 쿨타임 5% 하한). 천장은 카탈로그 단일 소스.
	if catalog.has_method("get_effective_ceiling"):
		var ceiling := float(catalog.get_effective_ceiling(clean_id))
		if ceiling > 0.0:
			var accumulated := float(catalog.get_amount(clean_id)) * float(get_count(clean_id))
			if accumulated >= ceiling - 0.0001:
				return false
	var max_count := int(catalog.get_max_count(clean_id))
	if max_count < 0:
		return true
	return get_count(clean_id) < max_count


func can_acquire_any(catalog: Object) -> bool:
	if catalog == null or not catalog.has_method("get_all_training_data"):
		return false
	for data_value: Variant in catalog.get_all_training_data():
		if data_value is Dictionary and can_acquire(str((data_value as Dictionary).get("id", "")), catalog):
			return true
	return false


func commit(training_id: String, catalog: Object) -> Dictionary:
	var clean_id := training_id.strip_edges()
	if not can_acquire(clean_id, catalog):
		return _build_result(false, clean_id, "cap_or_invalid")
	acquired_counts[clean_id] = get_count(clean_id) + 1
	total_acquired_count += 1
	revision += 1
	return _build_result(true, clean_id, "committed")


func get_count(training_id: String) -> int:
	return maxi(0, int(acquired_counts.get(training_id.strip_edges(), 0)))


func get_total_count() -> int:
	return total_acquired_count


func note_eligible_offer_screen(dice_remaining_uses: int) -> Dictionary:
	if dice_remaining_uses > 0:
		eligible_screen_count_before_dice_exhaustion += 1
	else:
		eligible_screen_count_after_dice_exhaustion += 1
	return {
		"before_dice_exhaustion": eligible_screen_count_before_dice_exhaustion,
		"after_dice_exhaustion": eligible_screen_count_after_dice_exhaustion,
	}


func get_bonus(stat_key: String, catalog: Object) -> float:
	if catalog == null or not catalog.has_method("get_all_training_data"):
		return 0.0
	var total := 0.0
	for data_value: Variant in catalog.get_all_training_data():
		if not data_value is Dictionary:
			continue
		var data: Dictionary = data_value as Dictionary
		if str(data.get("stat_key", "")) != stat_key.strip_edges():
			continue
		var entry_total := float(data.get("amount", 0.0)) * float(get_count(str(data.get("id", ""))))
		# 실효 천장을 넘는 누적은 게임플레이·카드·능력치 패널이 서로 다른 값을 말하지
		# 않도록 여기서 한 번에 깎는다(소비자 하한/clamp 와 같은 결과).
		var ceiling := float(data.get("effective_ceiling", 0.0))
		if ceiling > 0.0:
			entry_total = minf(entry_total, ceiling)
		total += entry_total
	return total


func get_revision() -> int:
	return revision


func get_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"acquired_counts": acquired_counts.duplicate(true),
		"total_acquired_count": total_acquired_count,
		"eligible_screen_count_before_dice_exhaustion": eligible_screen_count_before_dice_exhaustion,
		"eligible_screen_count_after_dice_exhaustion": eligible_screen_count_after_dice_exhaustion,
		"revision": revision,
	}


func restore(snapshot: Dictionary, catalog: Object) -> Dictionary:
	var restored_counts: Dictionary = {}
	var restored_total := 0
	var incoming: Dictionary = snapshot.get("acquired_counts", {}) as Dictionary
	if catalog != null and catalog.has_method("get_all_training_data"):
		for data_value: Variant in catalog.get_all_training_data():
			if not data_value is Dictionary:
				continue
			var training_id := str((data_value as Dictionary).get("id", ""))
			var max_count := int(catalog.get_max_count(training_id))
			var count := maxi(0, int(incoming.get(training_id, 0)))
			# 상한 있는 항목(수납술)만 클램프한다. 무제한 항목에 mini(count, -1) 를 적용하면
			# 복원이 조용히 0 으로 접힌다.
			if max_count >= 0:
				count = mini(count, max_count)
			if count > 0:
				restored_counts[training_id] = count
				restored_total += count
	acquired_counts = restored_counts
	total_acquired_count = restored_total
	eligible_screen_count_before_dice_exhaustion = maxi(
		0,
		int(snapshot.get("eligible_screen_count_before_dice_exhaustion", 0))
	)
	eligible_screen_count_after_dice_exhaustion = maxi(
		0,
		int(snapshot.get("eligible_screen_count_after_dice_exhaustion", 0))
	)
	revision += 1
	return {"accepted": true, "restored_total": restored_total, "revision": revision}


func _build_result(accepted: bool, training_id: String, reason: String) -> Dictionary:
	return {
		"accepted": accepted,
		"training_id": training_id,
		"reason": reason,
		"count": get_count(training_id),
		"total_acquired_count": total_acquired_count,
		"revision": revision,
	}
