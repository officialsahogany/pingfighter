extends SceneTree

# Seal: 전환 퍽 유효레벨 메모 (perf — O(1) 입력 대조 유효성, 무효화 훅 없음).
#
# 2026-07-23 mythic sync_after 재분해: get_converted_perk_effect_level 리프가
# 호출당 7.8us × 틱당 ~60회로 컨텍스트 빌드 층(61%)의 본체였다. 메모는
# (해당 퍽 raw 레벨, 아이템 퍽 레벨 보너스, 점화 오라, 융합 리비전) 4입력을
# 매 호출 O(1)로 대조해 유효성을 재유도한다 — 이 씰은 다음을 봉인한다:
#  (1) 게이팅: 동일 입력 반복 조회는 유효레벨 재계산 1회 (perf 본체)
#  (2) 스테일 불가(키 커버리지): 4입력 각각의 변경이 무효화 호출 없이도
#      즉시 재계산을 유발 (Lazy Applied-Key Re-Apply Trap 방지)
#  (3) 값 정확성: 메모 경유 결과 == 동일 입력의 fresh 상태 직산
#
# 반증검증(수동, in-place 토글 — git reset 금지): 쿼리 서피스의 메모 조회
# 분기를 제거(항상 재계산)하면 (1) 레그가 call_count 3으로 RED. 메모 키에서
# fusion_revision 항을 빼면 (2) 융합 레그가 스테일 값으로 RED.

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const PERK_ID := "sensor"

var _failures: Array[String] = []


class CountingEffectiveLevels:
	extends RefCounted

	var real: Object = null
	var call_count := 0

	func get_converted_perk_effect_level(
		runtime_skill_levels: Dictionary,
		item_perk_level_bonus: int,
		viper_ignition_aura_active: bool,
		perk_id: String
	) -> int:
		call_count += 1
		return int(real.get_converted_perk_effect_level(
			runtime_skill_levels,
			item_perk_level_bonus,
			viper_ignition_aura_active,
			perk_id
		))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_memo_gating_and_key_coverage()
	_verify_value_parity_with_fresh_state()

	if _failures.is_empty():
		print("runtime_perk_converted_level_memo_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_memo_gating_and_key_coverage() -> void:
	var state: Object = RuntimePerkState.new()
	var counter := CountingEffectiveLevels.new()
	counter.real = state._effective_levels
	state._effective_levels = counter
	state.runtime_skill_levels[PERK_ID] = 1

	# (1) 게이팅: 동일 입력 3회 조회 = 재계산 1회.
	var level_raw1: int = state.get_converted_perk_effect_level(PERK_ID)
	state.get_converted_perk_effect_level(PERK_ID)
	state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 1, "identical inputs should recompute once (got %d)" % counter.call_count)
	_expect(level_raw1 >= 1, "granted perk should resolve to a positive effect level")

	# (2) 키 커버리지 — 각 입력 변경이 무효화 호출 없이 즉시 재계산 유발.
	state.runtime_skill_levels[PERK_ID] = 3
	var level_raw3: int = state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 2, "raw level change should recompute (got %d)" % counter.call_count)
	_expect(level_raw3 != level_raw1, "raw level change should surface a new effect level")

	state.item_perk_level_bonus = 2
	state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 3, "item perk level bonus change should recompute (got %d)" % counter.call_count)

	state.viper_ignition_aura_active = true
	state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 4, "ignition aura toggle should recompute (got %d)" % counter.call_count)

	var revision_before: int = state.get_perk_fusion_revision()
	state._fusion_runtime_state.get_fusion_state().reset()
	_expect(
		state.get_perk_fusion_revision() != revision_before,
		"precondition: fusion reset should bump the revision"
	)
	state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 5, "fusion revision bump should recompute (got %d)" % counter.call_count)

	# 게이팅 재확인: 변경 후 안정 상태에서 다시 0회.
	state.get_converted_perk_effect_level(PERK_ID)
	state.get_converted_perk_effect_level(PERK_ID)
	_expect(counter.call_count == 5, "settled inputs should stop recomputing (got %d)" % counter.call_count)


func _verify_value_parity_with_fresh_state() -> void:
	# 메모 경유(반복 조회로 메모가 데워진 상태)의 값이 같은 입력으로 새로 만든
	# 상태의 직산과 동일해야 한다.
	var warmed: Object = RuntimePerkState.new()
	warmed.runtime_skill_levels[PERK_ID] = 3
	warmed.item_perk_level_bonus = 2
	warmed.viper_ignition_aura_active = true
	warmed.get_converted_perk_effect_level(PERK_ID)
	var memo_value: int = warmed.get_converted_perk_effect_level(PERK_ID)

	var fresh: Object = RuntimePerkState.new()
	fresh.runtime_skill_levels[PERK_ID] = 3
	fresh.item_perk_level_bonus = 2
	fresh.viper_ignition_aura_active = true
	var fresh_value: int = fresh.get_converted_perk_effect_level(PERK_ID)
	_expect(
		memo_value == fresh_value,
		"memoized value should equal a fresh-state computation (%d vs %d)" % [memo_value, fresh_value]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
