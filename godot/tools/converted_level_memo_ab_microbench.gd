extends SceneTree

# Diagnostic-only SAME-LOADOUT A/B for the converted-perk effective-level memo
# (NOT a pass/fail gate). Addresses the 2026-07-24 review point that the live
# 3966->585us drop was not a clean same-loadout A/B (label presence != equip,
# and the two live sessions differ in loadout/state). This bench holds ONE fixed
# perk dict and measures the leaf both ways on identical inputs:
#   A (memo OFF): call _effective_levels.get_converted_perk_effect_level(...)
#     directly -> recomputes every call (the pre-memo path).
#   B (memo ON):  call runtime_state.get_converted_perk_effect_level(perk) ->
#     O(1) input-compare cache hit after warm.
# Same runtime_state, same levels, same perk set: any delta is the memo alone.
# Run:
#   godot --headless --path godot -s res://tools/converted_level_memo_ab_microbench.gd

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

const ITERATIONS := 20000


func _bench(callable: Callable) -> float:
	callable.call()
	var start := Time.get_ticks_usec()
	for _i in range(ITERATIONS):
		callable.call()
	return float(Time.get_ticks_usec() - start) / float(ITERATIONS)


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state: Object = RuntimePerkState.new()
	# 고정 로드아웃: 전환 신화퍽 전체 Lv1 + 전환 퍽 전체 Lv3 (동일 A/B 조건).
	var perks: Array = []
	for perk_id in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		state.runtime_skill_levels[str(perk_id)] = 1
		perks.append(str(perk_id))
	for perk_id in RuntimePerkCatalog.CONVERTED_PERKS.keys():
		state.runtime_skill_levels[str(perk_id)] = 3
		perks.append(str(perk_id))
	print("fixed loadout perks: %d" % perks.size())

	# 공정한 OFF 베이스라인 = surface 내부 full 경로(래퍼 accessor + fusion
	# 보너스 루프 포함)를 매 호출. 이것이 메모가 실제로 감싸는 pre-memo 경로다.
	var surface: Object = state._effective_stat_queries
	var effective_levels: Object = state._effective_levels

	# 워밍 + 값 동일성 확인(A와 B가 같은 결과여야 A/B가 유효).
	state.get_converted_perk_effect_level(perks[0])
	var mismatch := 0
	for perk_id in perks:
		var a: int = int(surface.get_converted_perk_effect_level(effective_levels, state, perk_id))
		var b: int = int(state.get_converted_perk_effect_level(perk_id))
		if a != b:
			mismatch += 1
	print("A/B value mismatches (must be 0): %d" % mismatch)

	# A: memo OFF (surface full 경로 재계산 — 진짜 pre-memo 경로)
	var idx_a := {"i": 0}
	var a_us := _bench(func() -> void:
		var perk_id: String = perks[idx_a["i"] % perks.size()]
		idx_a["i"] += 1
		surface.get_converted_perk_effect_level(effective_levels, state, perk_id))

	# B: memo ON (O(1) 캐시히트)
	var idx_b := {"i": 0}
	var b_us := _bench(func() -> void:
		var perk_id: String = perks[idx_b["i"] % perks.size()]
		idx_b["i"] += 1
		state.get_converted_perk_effect_level(perk_id))

	print("A memo OFF (recompute) : %.3fus/call" % a_us)
	print("B memo ON  (cache hit) : %.3fus/call" % b_us)
	if a_us > 0.0:
		print("same-loadout leaf reduction: %.1f%% (%.3f -> %.3f)" % [(1.0 - b_us / a_us) * 100.0, a_us, b_us])
	quit(0)
