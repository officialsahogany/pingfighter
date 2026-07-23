extends SceneTree

# Diagnostic-only ratio microbench: mythic sync_after with CONVERTED PERKS OWNED
# (NOT a pass/fail gate - absolute numbers vary per machine; use the RATIOS).
#
# 2026-07-23 라이브 triage: physics.items.mythic.sync_after가 mythic 퍽 누적
# 이후 창(16%)에서 avg 3966us — 6월 장착 기준 531us의 ~7.5배. 2026-06-13
# 벤치(미장착)는 clean 225.6us / 컨텍스트 빌드 117.9us(52%)였다. 이 벤치는
# 패시브→퍽 전환(13 신화퍽 + 전환 퍽 다수 보유) 상태를 재현해 어느 층이
# 폭발했는지(컨텍스트 게터 fan-out vs 값 빌드 vs 레벨 조회 체인) 귀속한다.
# Run:
#   godot --headless --path godot -s res://tools/mythic_sync_equipped_microbench.gd

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

const ITERATIONS := 2000


class PlainOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true


func _bench(label: String, callable: Callable, iterations: int = ITERATIONS) -> float:
	callable.call()
	var start := Time.get_ticks_usec()
	for _i in range(iterations):
		callable.call()
	var per_call := float(Time.get_ticks_usec() - start) / float(iterations)
	print("%s: %.1fus" % [label, per_call])
	return per_call


func _init() -> void:
	var owner := PlainOwner.new()

	# --- 베이스라인: 전환 플래그 OFF + 퍽 미보유 (6월 벤치와 동일 조건) ---
	PerkConversionFlags.debug_set_enabled(false)
	var runtime_base: Object = MythicItemRuntime.new()
	runtime_base.reset()
	var syncer_base: Object = runtime_base.owner_syncer
	syncer_base.sync_transient_owner_state(runtime_base, owner)
	_bench("baseline(flag OFF, no perks) sync", func() -> void:
		syncer_base.sync_transient_owner_state(runtime_base, owner))

	# --- 전환 상태: 플래그 ON + 신화퍽 13종 Lv1 + 전환퍽 전체 Lv3 ---
	PerkConversionFlags.debug_set_enabled(true)
	var perk_state: Object = RuntimePerkState.new()
	for perk_id in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		perk_state.runtime_skill_levels[str(perk_id)] = 1
	for perk_id in RuntimePerkCatalog.CONVERTED_PERKS.keys():
		perk_state.runtime_skill_levels[str(perk_id)] = 3
	print("granted perks: %d" % perk_state.runtime_skill_levels.size())

	var runtime: Object = MythicItemRuntime.new()
	runtime.reset()
	runtime.runtime_perk_state_ref = perk_state
	var syncer: Object = runtime.owner_syncer
	syncer.sync_transient_owner_state(runtime, owner)

	var total := _bench("equipped(flag ON) sync", func() -> void:
		syncer.sync_transient_owner_state(runtime, owner))

	var contexts_cost := _bench("  _build_transient_contexts", func() -> void:
		syncer._build_transient_contexts(runtime))
	var contexts: Dictionary = syncer._build_transient_contexts(runtime)
	var state_cost := _bench("  _build_transient_state_values", func() -> void:
		syncer._build_transient_state_values(runtime, contexts))
	var owner_cost := _bench("  _build_transient_owner_values", func() -> void:
		syncer._build_transient_owner_values(runtime, contexts))
	print("  (build 3층 합 %.1fus / sync 전체 %.1fus — 잔여=diff·캐시 갱신)" % [
		contexts_cost + state_cost + owner_cost, total])

	print("--- per-context getter ---")
	_bench("  get_sensor_context", func() -> void: runtime.get_sensor_context())
	_bench("  get_hermes_shoes_context", func() -> void: runtime.get_hermes_shoes_context())
	_bench("  get_celestial_armor_context", func() -> void: runtime.get_celestial_armor_context())
	_bench("  get_baal_boots_context", func() -> void: runtime.get_baal_boots_context())
	_bench("  get_rainbow_fur_glove_context", func() -> void: runtime.get_rainbow_fur_glove_context())
	_bench("  get_adversity_armor_context", func() -> void: runtime.get_adversity_armor_context())
	_bench("  get_shrapnel_armor_context", func() -> void: runtime.get_shrapnel_armor_context())
	_bench("  get_poseidon_context", func() -> void: runtime.get_poseidon_context())
	_bench("  get_horn_strawberry_context", func() -> void: runtime.get_horn_strawberry_context())
	_bench("  get_odins_eye_context", func() -> void: runtime.get_odins_eye_context())

	print("--- leaf query ---")
	_bench("  get_converted_perk_effect_level(sensor) x1", func() -> void:
		runtime.get_converted_perk_effect_level("sensor"))

	quit(0)
