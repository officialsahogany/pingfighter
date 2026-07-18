extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkFusionModalLayout := preload("res://scripts/characters/perk_fusion_modal_layout.gd")

var _failures: Array[String] = []


class RegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object
	var mythic_runtime: Object


	func _init(state_value: Object, catalog_value: Object, mythic_value: Object = null) -> void:
		state = state_value
		catalog = catalog_value
		mythic_runtime = mythic_value


	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
			"mythic_item_runtime":
				return mythic_runtime
		return null


# 비-5레벨 자격 fixture: item_luck과 같은 데이터 형상이지만 max_level=3인
# 융합 후보 — null 카탈로그의 max=5 가정이면 한계돌파 자격이 갈라진다.
class LimitBreakCatalogStub:
	extends RefCounted

	var real: Object = RuntimePerkCatalog.new()
	var stub_max_level := 3

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == "test_alloy_core":
			var data: Dictionary = real.get_perk_data("item_luck").duplicate(true)
			data["max_level"] = stub_max_level
			return data
		if perk_id == "test_alloy_lattice":
			var lattice: Dictionary = real.get_perk_data("common_bulk_up").duplicate(true)
			lattice["max_level"] = stub_max_level
			return lattice
		return real.get_perk_data(perk_id)


	func get_slot_cost_for_level(perk_data: Dictionary, level: int) -> int:
		return real.get_slot_cost_for_level(perk_data, level)


class MythicRuntimeStub:
	extends RefCounted

	var after_choice_calls := 0
	var choice_bonus_calls := 0

	func try_after_perk_choice(_choice_id: String, _owner: Object, _registry: Object) -> bool:
		after_choice_calls += 1
		return false

	func get_runtime_perk_choice_count_bonus(_owner: Object, _registry: Object) -> int:
		choice_bonus_calls += 1
		return 1


class CooldownProbe:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0

	func pause_from_runtime_state(_runtime_state: Object, _owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func resume_from_runtime_state(_runtime_state: Object) -> void:
		resume_calls += 1


class ResumeSafetyProbe:
	extends RefCounted

	var arm_calls := 0

	func try_arm_from_runtime_state(_runtime_state: Object, _owner: Object, _registry: Object) -> void:
		arm_calls += 1


class AbsorptionProbe:
	extends RefCounted

	var start_calls := 0

	func start_from_runtime_state(_runtime_state: Object, _owner: Object) -> void:
		start_calls += 1

	func is_active_from_runtime_state(_runtime_state: Object) -> bool:
		return start_calls > 0


const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")

var _overlay_draw_ran := false
var _overlay_state: Object
var _overlay_catalog: Object
var _overlay_renderer: Object
var _overlay_perf_probe: Object


class PerfLabelProbe:
	extends RefCounted

	var labels: Array = []

	func begin_sample() -> int:
		return 0

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FusionOverlayRendererProbe:
	extends RefCounted

	var draw_calls := 0
	var last_snapshot: Dictionary = {}
	var last_catalog: Object
	var last_view_size := Vector2.ZERO

	func prewarm_assets() -> void:
		pass

	func draw(_canvas: CanvasItem, snapshot: Dictionary, catalog: Object, view_size: Vector2, _icon_renderer: Object) -> void:
		draw_calls += 1
		last_snapshot = snapshot.duplicate(true)
		last_catalog = catalog
		last_view_size = view_size


func _init() -> void:
	_verify_material_cancel_is_a_noop()
	_verify_s2_commit_and_s4_next_modal_boundary()
	_verify_result_box_dowsing_finish_is_transactionally_idempotent()
	_verify_rt_release_gate_blocks_phase_cascade()
	_verify_late_phase_grid_click_cannot_consume_finish_latches()
	_verify_modal_preview_rebuilds_only_when_selection_changes()
	_verify_core_stabilizer_preview_matches_committed_result()
	_verify_modal_preview_matches_commit_catalog_for_non_default_max_levels()
	_verify_commit_authority_and_preview_cache_across_catalog_swaps()
	_verify_last_choice_closes_only_after_reveal()
	_verify_real_input_router_full_modal_roundtrip()
	_verify_real_router_cancel_paths_and_reset_release()
	await _verify_real_overlay_draw_routes_fusion_modal()

	if _failures.is_empty():
		print("runtime_perk_fusion_modal_integration_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_material_cancel_is_a_noop() -> void:
	var fixture: Dictionary = _build_fixture(2)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var original_choices: Array = state.current_choices.duplicate(true)
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(state.is_perk_fusion_modal_active(), "fusion card should enter the nested materials modal")
	var cancel_result: Dictionary = state._cancel_perk_fusion_modal()
	_expect(bool(cancel_result.get("cancel_to_choices", false)), "materials cancel should request the original choice screen")
	_expect(not state.is_perk_fusion_modal_active(), "materials cancel should leave only the raw perk choice screen")
	_expect(state.current_choices == original_choices, "materials cancel should restore the exact frozen offer snapshot")
	_expect(state.choice_active and state.pending_skill_choices == 2, "materials cancel must not close or consume the raw perk modal")
	_expect(state.selected_choice_sequence == 0 and state.get_perk_fusion_revision() == 0, "materials cancel must not mutate sequence or fusion revision")


func _verify_s2_commit_and_s4_next_modal_boundary() -> void:
	var fixture: Dictionary = _build_fixture(2)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, _success_rolls())
	_expect(bool(commit_result.get("accepted", false)), "S2 confirm should commit one fusion record")
	_expect(state.choice_active, "S2 commit must keep raw choice_active true")
	_expect(state.pending_skill_choices == 2, "S2 commit must not consume pending choice count")
	_expect(state.selected_choice_sequence == 0, "S2 commit must not advance selected sequence")
	_expect(state.get_perk_fusion_revision() == 1, "S2 commit should advance fusion revision exactly once")
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1, "S2 commit should persist the record before animation")
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation", "committed result should enter animation without closing")

	state._confirm_perk_fusion_modal(null, registry)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal", "animation confirm should only skip to reveal")
	_expect(state.pending_skill_choices == 2 and state.selected_choice_sequence == 0, "animation skip must not finish the choice")
	state._confirm_perk_fusion_modal(null, registry)
	_expect(not state.is_perk_fusion_modal_active(), "S4 reveal confirm should finish the nested flow")
	_expect(state.pending_skill_choices == 1, "S4 finish should consume exactly one pending choice")
	_expect(state.selected_choice_sequence == 1, "S4 finish should advance sequence exactly once")
	_expect(state.choice_active, "remaining pending choice should open the next guarded modal")
	_expect(str(state.current_choice_context.get("source", "")) == "battle_starpoint", "next pending modal should preserve its source context")
	_expect(str(state.last_selected_id) == "perk_fusion", "finish path should record the fusion selection identity")
	_expect(str(state.last_selected_choice.get("type", "")) == "fusion", "S4 snapshot should publish the canonical fusion reward type")
	_expect((state.last_selected_choice.get("fusion_record", {}) as Dictionary).has("fusion_id"), "finish snapshot should carry the committed fusion record")


# 코덱스 P3: 프리뷰의 한계돌파 자격은 실 커밋과 같은 카탈로그(max_level)를
# 봐야 한다. dash_amplification은 실 max_level=3 — null 카탈로그의 5 가정
# 이면 자격 미달로 갈라진다. 비-한계돌파 부산물을 전부 선소유해 풀 후보가
# 자격 유무로만 비거나 채워지게 만들면(available.is_empty()가 가중치를
# 가른다) 갈라짐이 preview/commit 가중치 불일치로 관측된다.
func _verify_modal_preview_matches_commit_catalog_for_non_default_max_levels() -> void:
	var state := RuntimePerkState.new()
	var catalog := LimitBreakCatalogStub.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"common_swiftness": 5,
		"sensor": 5,
		"test_alloy_core": 3,
		"test_alloy_lattice": 3,
	}
	var grant_record: Dictionary = state.commit_perk_fusion(
		["common_swiftness", "sensor"],
		{
			"outcome": "byproduct",
			"byproducts": [
				"overload_circuit",
				"reverb",
				"golden_trajectory",
				"static_field",
				"recycle_protocol",
				"core_stabilize",
				"dual_catalyst",
			],
		},
		catalog
	)
	_expect(not grant_record.is_empty(), "catalog-parity fixture should pre-own every non-limit-break byproduct")
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [
		_fusion_card(["test_alloy_core", "test_alloy_lattice"]),
		_reserved_card(),
		_dowsing_card(),
		_gold_card(),
	]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	var preview: Dictionary = state.get_perk_fusion_modal_snapshot().get("outcome_preview", {}) as Dictionary
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, _success_rolls())
	var record: Dictionary = commit_result.get("record", {}) as Dictionary
	_expect(bool(commit_result.get("accepted", false)), "catalog-parity fixture should commit through the registry catalog")
	_expect(
		record.get("weights", {}) == preview.get("weights", {}),
		"S2 preview and committed result must read the same limit-break eligibility from the same catalog (real max_level=3 source)"
	)


# 코덱스 v2-P2: (A) S2 커밋은 커밋 시점 registry가 아니라 모달 시작 시
# 보존한 카탈로그를 권위로 쓴다 — A로 시작해 B registry로 confirm해도
# 프리뷰와 같은 가중치·같은 자격으로 커밋된다. (B) 프리뷰 캐시는 모달
# 경계에서 비워진다 — 리비전 불변 취소 후 다른 카탈로그로 재진입한 두
# 번째 모달이 첫 모달의 stale 프리뷰를 서빙하면 안 된다.
func _verify_commit_authority_and_preview_cache_across_catalog_swaps() -> void:
	var view_size := Vector2(760.0, 750.0)
	var state := RuntimePerkState.new()
	var catalog_a := LimitBreakCatalogStub.new()
	var registry_a := RegistryStub.new(state, catalog_a)
	var registry_real := RegistryStub.new(state, RuntimePerkCatalog.new())
	state.runtime_skill_levels = {
		"common_swiftness": 5,
		"sensor": 5,
		"test_alloy_core": 3,
		"test_alloy_lattice": 3,
	}
	var grant_record: Dictionary = state.commit_perk_fusion(
		["common_swiftness", "sensor"],
		{
			"outcome": "byproduct",
			"byproducts": [
				"overload_circuit",
				"reverb",
				"golden_trajectory",
				"static_field",
				"recycle_protocol",
				"core_stabilize",
				"dual_catalyst",
			],
		},
		catalog_a
	)
	_expect(not grant_record.is_empty(), "catalog-swap fixture should pre-own every non-limit-break byproduct")
	state.pending_skill_choices = 2
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [
		_fusion_card(["test_alloy_core", "test_alloy_lattice"]),
		_reserved_card(),
		_dowsing_card(),
		_gold_card(),
	]
	state.selected_index = 0

	# (B) 첫 모달: A(max=3) 카탈로그로 materials 단계에서 재료 2종을 선택해
	# 프리뷰를 캐시에 남긴 뒤, 스냅샷 재조회가 없는 직접 취소로 닫는다 —
	# 취소 직전 마지막 캐시 키(재료·materials·리비전)가 두 번째 모달의 같은
	# 지점과 정확히 일치하는 실 stale 위험 시퀀스다.
	state.choose_selected(null, registry_a, view_size)
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	var preview_a: Dictionary = state.get_perk_fusion_modal_snapshot().get("outcome_preview", {}) as Dictionary
	state._cancel_perk_fusion_modal()
	_expect(not state.is_perk_fusion_modal_active(), "catalog-swap fixture should fully cancel the first modal")
	# 두 번째 모달: 같은 재료·같은 phase·같은 리비전(커밋 없음)이지만
	# B(max=5) 카탈로그 — 경계 초기화가 있으면 자격 없음(빈 풀) 가중치로
	# 새로 계산되고, stale이면 첫 모달의 A 가중치가 그대로 서빙된다.
	var catalog_b := LimitBreakCatalogStub.new()
	catalog_b.stub_max_level = 5
	var registry_b := RegistryStub.new(state, catalog_b)
	state.choose_selected(null, registry_b, view_size)
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	var preview_b: Dictionary = state.get_perk_fusion_modal_snapshot().get("outcome_preview", {}) as Dictionary
	_expect(
		preview_b.get("weights", {}) != preview_a.get("weights", {}),
		"a revision-unchanged re-entry with a different catalog must rebuild the preview (no stale cache across modal boundaries)"
	)
	state._cancel_perk_fusion_modal()
	_expect(not state.is_perk_fusion_modal_active(), "catalog-swap fixture should fully cancel the second modal")

	# (A) 커밋 권위: A로 시작 -> 실 카탈로그 registry로 confirm — 보존본이
	# 권위면 프리뷰와 같은 가중치로 커밋되고, 커밋 시점 재조회면 스텁 전용
	# 재료가 무효가 되거나 가중치가 갈라진다.
	state.choose_selected(null, registry_a, view_size)
	_select_pair_and_enter_confirm(state)
	var preview_commit: Dictionary = state.get_perk_fusion_modal_snapshot().get("outcome_preview", {}) as Dictionary
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry_real, _success_rolls())
	var record: Dictionary = commit_result.get("record", {}) as Dictionary
	_expect(bool(commit_result.get("accepted", false)), "S2 confirm through a swapped registry must still commit with the preserved start catalog")
	_expect(
		record.get("weights", {}) == preview_commit.get("weights", {}),
		"the preserved start catalog must stay the single authority for both preview and commit weights"
	)


func _verify_last_choice_closes_only_after_reveal() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var cooldown := CooldownProbe.new()
	var resume_safety := ResumeSafetyProbe.new()
	var absorption := AbsorptionProbe.new()
	state._skill_cooldown_pause = cooldown
	state._resume_safety = resume_safety
	state._starpoint_absorption = absorption
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	state._confirm_perk_fusion_modal(null, registry, _success_rolls())
	_expect(state.choice_active and state.pending_skill_choices == 1, "last pending modal must remain guarded through committed animation")
	state._confirm_perk_fusion_modal(null, registry)
	_expect(state.choice_active and state.pending_skill_choices == 1, "last pending modal must remain guarded through reveal")
	state._confirm_perk_fusion_modal(null, registry)
	_expect(not state.choice_active, "last pending modal should close only on S4 reveal confirm")
	_expect(state.pending_skill_choices == 0 and state.selected_choice_sequence == 1, "last finish should consume/sequence exactly once")
	_expect(state.current_choices.is_empty(), "normal finish path should clear the frozen offer")
	_expect(cooldown.resume_calls == 1, "last S4 finish should resume skill cooldowns exactly once")
	_expect(resume_safety.arm_calls == 1, "last S4 finish should arm the resume ramp exactly once")
	_expect(absorption.start_calls == 1, "last S4 finish should start starpoint absorption exactly once")


func _verify_result_box_dowsing_finish_is_transactionally_idempotent() -> void:
	# The production opener shuffles ordinary lanes. Pin the global RNG so this
	# adversarial protected-lane fixture is deterministic across test order.
	seed(170071)
	var mythic := MythicRuntimeStub.new()
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog, mythic)
	var cooldown := CooldownProbe.new()
	var resume_safety := ResumeSafetyProbe.new()
	var absorption := AbsorptionProbe.new()
	state._skill_cooldown_pause = cooldown
	state._resume_safety = resume_safety
	state._starpoint_absorption = absorption

	# Build the plan's adversarial S2 fixture through the production opener:
	# two full-slot owned upgrades become protected reservations, Dowsing marks
	# another card, and only the last ordinary lane may become the fusion card.
	PerkConversionFlags.debug_set_enabled(true)
	catalog.mythic_jackpot_offer_chance = 0.0
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"dash_lightweight": 5,
		"dash_module_control": 5,
		"dash_jump": 1,
		"common_swiftness": 1,
	}
	state.pending_skill_choices = 2
	# 결정적 RNG seam: 실 open 경로가 스스로 융합 카드를 노출해야 한다 —
	# _try_inject 직접 호출 fallback은 실 배선 미관통을 은닉하므로 금지.
	state.set_test_perk_fusion_offer_roll_override(0.0, 0.0)
	state.open_next_choice(
		"smasher",
		catalog,
		true,
		null,
		registry,
		null,
		{"source": "result_box_starpoint_choice"}
	)
	var fusion_index: int = _find_choice_index(state.current_choices, "perk_fusion")
	_expect(fusion_index >= 0, "the real result-box open path should expose one fusion card deterministically")
	_expect(state._test_perk_fusion_offer_roll_override.is_empty(), "the deterministic offer seam must be consumed by the real open exactly once")
	_expect(_count_offer_lane(state.current_choices, "owned_upgrade_reserved") == 2, "combined S2 fixture should preserve two actual owned-upgrade reservations")
	_expect(_count_offer_lane(state.current_choices, "dowsing_bonus") == 1, "combined S2 fixture should preserve the actual Dowsing bonus lane")
	_expect(_count_offer_lane(state.current_choices, "gold") == 1, "combined S2 fixture should preserve the gold lane")
	_expect(mythic.choice_bonus_calls == 1, "initial result-box opener should query Dowsing exactly once")
	_expect(cooldown.pause_calls == 1, "initial result-box opener should pause cooldowns exactly once")
	state.selected_index = maxi(0, fusion_index)
	state.animation_time = 10.0

	var frozen_offer: Array = state.current_choices.duplicate(true)
	var frozen_context: Dictionary = state.current_choice_context.duplicate(true)
	var pending_before_s2: int = int(state.pending_skill_choices)
	var sequence_before_s2: int = int(state.selected_choice_sequence)
	var dowsing_calls_before_s2: int = mythic.choice_bonus_calls
	var pause_calls_before_s2: int = cooldown.pause_calls
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, _success_rolls())
	_expect(bool(commit_result.get("accepted", false)), "combined result-box S2 should commit its fusion record")
	_expect(state.get_perk_fusion_revision() == 1, "combined result-box S2 should advance fusion revision exactly once")
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1, "combined result-box S2 should append exactly one record")
	_expect(state.choice_active, "combined result-box S2 must keep raw choice_active true")
	_expect(state.pending_skill_choices == pending_before_s2, "combined result-box S2 must not consume pending choices")
	_expect(state.selected_choice_sequence == sequence_before_s2, "combined result-box S2 must not advance the choice sequence")
	_expect(state.current_choices == frozen_offer and state.current_choice_context == frozen_context, "combined result-box S2 must retain the frozen offer and source context")
	_expect(mythic.after_choice_calls == 0, "combined result-box S2 must not roll Megingjord")
	_expect(mythic.choice_bonus_calls == dowsing_calls_before_s2, "combined result-box S2 must not open/query the next Dowsing offer")
	_expect(cooldown.pause_calls == pause_calls_before_s2, "combined result-box S2 must not pause cooldowns for a next modal")
	_expect(cooldown.resume_calls == 0 and resume_safety.arm_calls == 0 and absorption.start_calls == 0, "combined result-box S2 must not run close/resume/ramp callbacks")

	state._confirm_perk_fusion_modal(null, registry)
	_expect(state.pending_skill_choices == pending_before_s2 and state.selected_choice_sequence == sequence_before_s2, "S3 skip must keep the raw result-box transaction frozen")
	_expect(mythic.after_choice_calls == 0 and mythic.choice_bonus_calls == dowsing_calls_before_s2, "S3 skip must not run Megingjord or next-open work")
	_expect(cooldown.pause_calls == pause_calls_before_s2 and cooldown.resume_calls == 0 and resume_safety.arm_calls == 0 and absorption.start_calls == 0, "S3 skip must not run next-open or close/ramp callbacks")

	state._confirm_perk_fusion_modal(null, registry)
	_expect(state.pending_skill_choices == 1 and state.selected_choice_sequence == 1, "result-box S4 should consume exactly one of two pending choices")
	_expect(mythic.after_choice_calls == 1, "result-box S4 should give Megingjord exactly one opportunity")
	_expect(mythic.choice_bonus_calls == dowsing_calls_before_s2 + 1, "S4 should open/query the next Dowsing offer exactly once")
	_expect(cooldown.pause_calls == pause_calls_before_s2 + 1, "S4 should pause cooldowns for the next modal exactly once")
	_expect(_has_dowsing_choice(state.current_choices), "next result-box choice should preserve the Dowsing protected lane")
	_expect(cooldown.resume_calls == 0 and resume_safety.arm_calls == 0 and absorption.start_calls == 0, "opening the next pending modal must not run final close/ramp steps")
	var pending_before: int = int(state.pending_skill_choices)
	var sequence_before: int = int(state.selected_choice_sequence)
	var choices_before: Array = state.current_choices.duplicate(true)
	var duplicate_result: Dictionary = state._finish_successful_choice(
		"perk_fusion",
		null,
		registry,
		null,
		state.last_selected_choice.duplicate(true)
	)
	_expect(bool(duplicate_result.get("already_finished", false)), "transaction guard should reject a repeated S4 finish for the same fusion id")
	_expect(state.pending_skill_choices == pending_before and state.selected_choice_sequence == sequence_before, "duplicate S4 must not consume pending or sequence twice")
	_expect(state.current_choices == choices_before, "duplicate S4 must not replace/close the already-open next modal")
	_expect(mythic.after_choice_calls == 1, "duplicate S4 must not reroll Megingjord")
	_expect(mythic.choice_bonus_calls == dowsing_calls_before_s2 + 1, "duplicate S4 must not query/open Dowsing twice")
	_expect(cooldown.pause_calls == pause_calls_before_s2 + 1, "duplicate S4 must not pause cooldowns for another modal")
	_expect(cooldown.resume_calls == 0 and resume_safety.arm_calls == 0 and absorption.start_calls == 0, "duplicate S4 must not run close/resume/ramp callbacks")
	PerkConversionFlags.debug_set_enabled(false)


func _verify_rt_release_gate_blocks_phase_cascade() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	state._handle_perk_fusion_modal_input(_rt_axis(0.10), null, registry, Vector2(760.0, 750.0))
	state._handle_perk_fusion_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation", "first released RT edge should commit S2")
	state._handle_perk_fusion_modal_input(_rt_axis(0.80), null, registry, Vector2(760.0, 750.0))
	state._handle_perk_fusion_modal_input(_rt_axis(1.00), null, registry, Vector2(760.0, 750.0))
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation", "held RT samples must not skip S3 or finish S4")
	_expect(state.pending_skill_choices == 1 and state.selected_choice_sequence == 0, "held RT must leave the raw choice transaction untouched after S2")
	state._handle_perk_fusion_modal_input(_rt_axis(0.10), null, registry, Vector2(760.0, 750.0))
	state._handle_perk_fusion_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal", "a second released RT edge may skip only into reveal")
	state._handle_perk_fusion_modal_input(_rt_axis(0.90), null, registry, Vector2(760.0, 750.0))
	_expect(state.choice_active and state.selected_choice_sequence == 0, "held second RT edge must not finish reveal")
	state._handle_perk_fusion_modal_input(_rt_axis(0.10), null, registry, Vector2(760.0, 750.0))
	state._handle_perk_fusion_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(not state.choice_active and state.selected_choice_sequence == 1, "third released RT edge should finish S4 exactly once")


func _verify_late_phase_grid_click_cannot_consume_finish_latches() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var view_size := Vector2(760.0, 750.0)
	var layout_helper := PerkFusionModalLayout.new()
	state.choose_selected(null, registry, view_size)
	_select_pair_and_enter_confirm(state)

	var confirm_snapshot: Dictionary = state.get_perk_fusion_modal_snapshot()
	var confirm_layout: Dictionary = layout_helper.build_layout(confirm_snapshot, view_size)
	var stale_candidate_rects: Array = confirm_layout.get("candidate_rects", []) as Array
	_expect(not stale_candidate_rects.is_empty(), "confirm fixture should retain visual material rects behind the confirmation card")
	state._handle_perk_fusion_modal_input(
		_mouse_click((stale_candidate_rects[0] as Rect2).get_center()),
		null,
		registry,
		view_size
	)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "confirm", "confirm-card grid click must not consume the one-shot commit request")
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, _success_rolls())
	_expect(bool(commit_result.get("accepted", false)), "normal confirm must still commit after a confirm-card grid click")

	state._confirm_perk_fusion_modal(null, registry)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal", "fixture should skip animation into reveal")
	var reveal_snapshot: Dictionary = state.get_perk_fusion_modal_snapshot()
	var reveal_layout: Dictionary = layout_helper.build_layout(reveal_snapshot, view_size)
	state._handle_perk_fusion_modal_input(
		_mouse_click((reveal_layout.get("result_rect", Rect2()) as Rect2).get_center()),
		null,
		registry,
		view_size
	)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal", "reveal result-card click must not consume the one-shot finish request")
	_expect(state.choice_active and state.selected_choice_sequence == 0, "reveal result-card click must leave the raw choice transaction guarded")
	state._handle_perk_fusion_modal_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(not state.choice_active and state.selected_choice_sequence == 1, "Enter must still finish normally after the reveal-card click regression sequence")


func _verify_modal_preview_rebuilds_only_when_selection_changes() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	var builds_before := int(state.get_perk_fusion_display_cache_stats().get("modal_preview_builds", 0))
	for _index in range(6):
		state.get_perk_fusion_modal_snapshot()
	var builds_after_idle := int(state.get_perk_fusion_display_cache_stats().get("modal_preview_builds", 0))
	_expect(builds_after_idle == builds_before + 1, "unchanged modal frames must reuse one derived preview build")
	state._perk_fusion_modal_flow.select_source_at(0)
	state.get_perk_fusion_modal_snapshot()
	_expect(
		int(state.get_perk_fusion_display_cache_stats().get("modal_preview_builds", 0)) == builds_after_idle + 1,
		"material selection change must invalidate the derived modal preview once"
	)


func _verify_core_stabilizer_preview_matches_committed_result() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"sensor": 5,
		"shrapnel_armor": 5,
	}
	var token_record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["core_stabilize"]},
		catalog
	)
	_expect(not token_record.is_empty(), "core preview fixture should acquire the one-shot stabilizer")
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "result_box_starpoint_choice"}
	state.current_choices = [_fusion_card(["sensor", "shrapnel_armor"]), _reserved_card(), _dowsing_card(), _gold_card()]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_select_pair_and_enter_confirm(state)
	var modal_snapshot: Dictionary = state.get_perk_fusion_modal_snapshot()
	var preview: Dictionary = modal_snapshot.get("outcome_preview", {}) as Dictionary
	_expect(bool(preview.get("core_stabilize_armed", false)), "S2 preview should expose the armed core stabilizer")
	_expect(str(preview.get("side_effect_effective_outcome", "")) == "stable", "S2 preview should relabel the side-effect bucket as stable")
	var source_previews: Array = modal_snapshot.get("source_previews", []) as Array
	_expect(source_previews.size() == 2, "S2 should publish one combined-value preview per selected source")
	_expect(_preview_option_count(source_previews, "sensor") == 2, "S2 sensor preview should retain both authored numeric options")
	_expect(_preview_option_count(source_previews, "shrapnel_armor") == 4, "S2 shrapnel preview should retain all four authored numeric options")
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, _side_effect_rolls())
	var record: Dictionary = commit_result.get("record", {}) as Dictionary
	_expect(str(record.get("raw_outcome", "")) == "side_effect" and str(record.get("outcome", "")) == "stable", "armed core should make the committed result match the stable S2 preview")
	_expect(record.get("weights", {}) == preview.get("weights", {}), "S2 preview and committed result must read the same centralized final weights")
	_expect(not bool(state.get_perk_fusion_token_snapshot().get("core_stabilize_armed", true)), "S2 commit should consume the armed core exactly once")


# 코덱스 보강 #1: 실 입력 라우터(state.handle_input) 관통 라운드트립 —
# 마우스 재료 선택 -> 키보드 확인 -> RT 커밋 -> RT 스킵 -> 키보드 finish가
# 전부 공개 라우터를 지나야 한다(내부 _handle_* 직접 호출 씰은 배선 누락을
# 은닉한다). 커밋 롤은 실 랜덤이므로 어서션은 트랜잭션 불변량만 본다.
func _verify_real_input_router_full_modal_roundtrip() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var view_size := Vector2(760.0, 750.0)
	var layout_helper := PerkFusionModalLayout.new()
	state.choose_selected(null, registry, view_size)
	_expect(state.is_perk_fusion_modal_active(), "roundtrip fixture should open the fusion modal")
	var first_layout: Dictionary = layout_helper.build_layout(state.get_perk_fusion_modal_snapshot(), view_size)
	var first_rects: Array = first_layout.get("candidate_rects", []) as Array
	_expect(first_rects.size() >= 2, "roundtrip fixture should expose at least two material rects")
	var consumed: bool = state.handle_input(_mouse_click((first_rects[0] as Rect2).get_center()), null, registry, view_size)
	_expect(consumed, "the real input router must consume events while the fusion modal is active")
	var second_layout: Dictionary = layout_helper.build_layout(state.get_perk_fusion_modal_snapshot(), view_size)
	state.handle_input(_mouse_click(((second_layout.get("candidate_rects", []) as Array)[1] as Rect2).get_center()), null, registry, view_size)
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "confirm", "router mouse picks + Enter should reach the confirm card (both materials selected)")
	state.handle_input(_rt_axis(0.90), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation", "router RT press should commit S2")
	_expect(state.get_perk_fusion_revision() == 1, "router S2 commit should advance fusion revision exactly once")
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1, "router S2 commit should persist exactly one record")
	_expect(state.choice_active and state.pending_skill_choices == 1, "router S2 must keep the raw choice transaction frozen")
	state.handle_input(_rt_axis(0.10), null, registry, view_size)
	state.handle_input(_rt_axis(0.90), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal", "second router RT edge should skip only into reveal")
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(not state.choice_active and state.selected_choice_sequence == 1, "router Enter on reveal should finish S4 exactly once")
	_expect(not state.is_perk_fusion_modal_active(), "router finish should close the nested fusion modal")


# 코덱스 보강 #6: 취소·리셋 lifecycle — 실 라우터 ESC의 S1 취소/S2->S1
# 복귀/S3·S4 no-op, 그리고 new-run reset()의 모달+RT 래치 해제.
func _verify_real_router_cancel_paths_and_reset_release() -> void:
	var fixture: Dictionary = _build_fixture(2)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var view_size := Vector2(760.0, 750.0)
	var layout_helper := PerkFusionModalLayout.new()
	var original_choices: Array = state.current_choices.duplicate(true)
	state.choose_selected(null, registry, view_size)
	state.handle_input(_key_press(KEY_ESCAPE), null, registry, view_size)
	_expect(not state.is_perk_fusion_modal_active(), "router ESC in S1 should cancel back to the raw choice screen")
	_expect(state.current_choices == original_choices and state.choice_active and state.pending_skill_choices == 2, "router S1 cancel must be a complete no-op on the frozen offer")
	_expect(state.get_perk_fusion_revision() == 0, "router S1 cancel must not commit anything")

	state.choose_selected(null, registry, view_size)
	var layout: Dictionary = layout_helper.build_layout(state.get_perk_fusion_modal_snapshot(), view_size)
	state.handle_input(_mouse_click(((layout.get("candidate_rects", []) as Array)[0] as Rect2).get_center()), null, registry, view_size)
	layout = layout_helper.build_layout(state.get_perk_fusion_modal_snapshot(), view_size)
	state.handle_input(_mouse_click(((layout.get("candidate_rects", []) as Array)[1] as Rect2).get_center()), null, registry, view_size)
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "confirm", "cancel-path fixture should reach the confirm card")
	state.handle_input(_key_press(KEY_ESCAPE), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "materials" and state.is_perk_fusion_modal_active(), "router ESC in S2 should return to S1 without closing the modal")
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "confirm", "material selection should survive the S2->S1 return")
	state.handle_input(_rt_axis(0.90), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation" and state.get_perk_fusion_revision() == 1, "post-return RT should commit normally")
	state.handle_input(_key_press(KEY_ESCAPE), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "animation", "router ESC in S3 must be a consumed no-op (no cancel after commit)")
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1, "S3 ESC must not touch the committed record")
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	state.handle_input(_key_press(KEY_ESCAPE), null, registry, view_size)
	_expect(str(state._perk_fusion_modal_flow.get_phase()) == "reveal" and state.choice_active and state.selected_choice_sequence == 0, "router ESC in S4 must be a consumed no-op on the frozen transaction")
	state.handle_input(_key_press(KEY_ENTER), null, registry, view_size)
	_expect(state.pending_skill_choices == 1 and state.selected_choice_sequence == 1, "finish after the cancel gauntlet should consume exactly one choice")

	var reset_fixture: Dictionary = _build_fixture(1)
	var reset_state: Object = reset_fixture["state"]
	var reset_registry: Object = reset_fixture["registry"]
	reset_state.choose_selected(null, reset_registry, view_size)
	reset_state.handle_input(_rt_axis(0.90), null, reset_registry, view_size)
	_expect(reset_state.is_perk_fusion_modal_active(), "reset fixture should hold an armed RT latch inside the open modal")
	reset_state.reset()
	_expect(not reset_state.is_perk_fusion_modal_active(), "new-run reset() must release the fusion modal flow")
	reset_state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	reset_state.pending_skill_choices = 1
	reset_state.choice_active = true
	reset_state.animation_time = 10.0
	reset_state.current_choice_context = {"source": "battle_starpoint"}
	reset_state.current_choices = [_fusion_card(["item_luck", "common_bulk_up"]), _reserved_card(), _dowsing_card(), _gold_card()]
	reset_state.selected_index = 0
	reset_state.choose_selected(null, reset_registry, view_size)
	_select_pair_and_enter_confirm(reset_state)
	reset_state.handle_input(_rt_axis(0.90), null, reset_registry, view_size)
	_expect(
		str(reset_state._perk_fusion_modal_flow.get_phase()) == "animation"
			and (reset_state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1,
		"reset must clear the RT latch so the next run's first RT press commits"
	)


# 코덱스 보강 #1(렌더 팬아웃): 실 CanvasItem draw 시그널 안에서 프로덕션
# RuntimePerkOverlayRenderer.draw()가 융합 모달 프레임을 전용 렌더러로
# 라우팅하고, 일반 카드 경로(layout/cards perf 라벨)를 한 줄도 타지 않는지
# 행동으로 봉인한다.
func _verify_real_overlay_draw_routes_fusion_modal() -> void:
	var fixture: Dictionary = _build_fixture(1)
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(state.is_perk_fusion_modal_active(), "overlay draw fixture should hold an active fusion modal")
	_overlay_state = state
	_overlay_catalog = fixture["catalog"]
	_overlay_renderer = RuntimePerkOverlayRenderer.new()
	var fusion_probe := FusionOverlayRendererProbe.new()
	_overlay_renderer._perk_fusion_overlay_renderer = fusion_probe
	_overlay_perf_probe = PerfLabelProbe.new()
	var probe := Control.new()
	root.add_child(probe)
	probe.draw.connect(_on_overlay_probe_draw.bind(probe))
	for _redraw_attempt in range(4):
		if _overlay_draw_ran:
			break
		probe.queue_redraw()
		await process_frame
	probe.queue_free()
	_expect(_overlay_draw_ran, "the live overlay draw pass should have executed")
	_expect(fusion_probe.draw_calls >= 1, "the real overlay draw should route the frame into the fusion modal renderer")
	_expect(str(fusion_probe.last_snapshot.get("phase", "")) == "materials", "the fusion renderer should consume the real modal snapshot")
	_expect(fusion_probe.last_catalog == _overlay_catalog and fusion_probe.last_view_size == Vector2(760.0, 750.0), "the fusion renderer should receive the live catalog and view size")
	var labels: Array = (_overlay_perf_probe.labels as Array).duplicate()
	_expect(labels.has("hud.perk_overlay.snapshot") and labels.has("hud.perk_overlay.perk_fusion_modal"), "the fusion-modal frame should record its own perf labels")
	for label_value: Variant in labels:
		_expect(
			str(label_value) == "hud.perk_overlay.snapshot" or str(label_value) == "hud.perk_overlay.perk_fusion_modal",
			"fusion-modal frame must not mid-draw the standard card path (unexpected label: %s)" % str(label_value)
		)


func _on_overlay_probe_draw(probe: Control) -> void:
	_overlay_draw_ran = true
	_overlay_renderer.draw(
		probe,
		_overlay_state,
		_overlay_catalog,
		Vector2(760.0, 750.0),
		null,
		null,
		null,
		_overlay_perf_probe
	)


func _build_fixture(pending_count: int, source: String = "battle_starpoint", mythic_runtime: Object = null) -> Dictionary:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog, mythic_runtime)
	state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	state.pending_skill_choices = pending_count
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": source}
	state.current_choices = [
		_fusion_card(["item_luck", "common_bulk_up"]),
		_reserved_card(),
		_dowsing_card(),
		_gold_card(),
	]
	state.selected_index = 0
	return {"state": state, "catalog": catalog, "registry": registry}


func _select_pair_and_enter_confirm(state: Object) -> void:
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	var action: Dictionary = state._perk_fusion_modal_flow.confirm_current()
	_expect(bool(action.get("entered_confirm", false)), "two materials should enter confirmation without committing")


func _success_rolls() -> Dictionary:
	return {
		"outcome": 0.0,
		"magnitude": [0.0, 0.0],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0],
	}


func _side_effect_rolls() -> Dictionary:
	var rolls := _success_rolls()
	rolls["outcome"] = 0.60
	return rolls


func _fusion_card(source_ids: Array) -> Dictionary:
	return {
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": source_ids.duplicate(),
		"offer_lane": "fusion",
		"offer_protected": true,
	}


func _reserved_card() -> Dictionary:
	return {"id": "reserved", "offer_lane": "owned_upgrade_reserved", "offer_protected": true}


func _dowsing_card() -> Dictionary:
	return {"id": "dowsing", "offer_lane": "dowsing_bonus", "offer_protected": true, "is_dowsing_goggles_bonus": true}


func _gold_card() -> Dictionary:
	return {"id": "convert_to_gold", "offer_lane": "gold", "offer_protected": true}


func _has_dowsing_choice(choices: Array) -> bool:
	for choice_value: Variant in choices:
		if choice_value is Dictionary and bool((choice_value as Dictionary).get("is_dowsing_goggles_bonus", false)):
			return true
	return false


func _find_choice_index(choices: Array, choice_id: String) -> int:
	for index: int in range(choices.size()):
		var choice_value: Variant = choices[index]
		if choice_value is Dictionary and str((choice_value as Dictionary).get("id", "")) == choice_id:
			return index
	return -1


func _count_offer_lane(choices: Array, lane: String) -> int:
	var count := 0
	for choice_value: Variant in choices:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("offer_lane", "")) == lane:
			count += 1
	return count


func _preview_option_count(previews: Array, perk_id: String) -> int:
	for preview_value: Variant in previews:
		if preview_value is Dictionary and str((preview_value as Dictionary).get("perk_id", "")) == perk_id:
			return ((preview_value as Dictionary).get("options", []) as Array).size()
	return 0


func _rt_axis(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
