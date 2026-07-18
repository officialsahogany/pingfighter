extends SceneTree

const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")
const PerkFusionModalFlow := preload("res://scripts/characters/perk_fusion_modal_flow.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_beat_boundaries_and_settle()
	_verify_multi_beat_delta_emits_ordered_events()
	_verify_skip_from_every_beat_converges_to_settle()
	_verify_flow_integration_drives_beats_and_reveal_settles()
	_verify_flow_skip_settles_timeline()
	_verify_flow_update_fanout_consumes_events_exactly_once()
	_verify_skip_path_event_reaches_consumer_once()
	_verify_state_facade_drains_events_from_real_update()
	_verify_duration_single_authority()
	_verify_reset_clears_timeline()

	if _failures.is_empty():
		print("perk_fusion_cold_boot_timeline_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


# B0~B4 경계 전이(0.5 / 0.9 / 1.8 / 2.05 / 2.75)와 총길이-후 SETTLE 홀드.
func _verify_beat_boundaries_and_settle() -> void:
	var timeline := PerkFusionColdBootTimelineState.new()
	timeline.begin({"outcome": "success"})
	_expect(timeline.get_snapshot().get("beat") == "dock_in", "begin should start at B0 DOCK_IN")
	timeline.advance(0.49)
	_expect(timeline.get_snapshot().get("beat") == "dock_in", "B0 should hold until its 0.5s boundary")
	var events: Array[String] = timeline.advance(0.02)
	_expect(events == ["enter_twist_lock"], "crossing 0.5s should enter B1 TWIST_LOCK exactly once")
	timeline.advance(0.40)
	_expect(timeline.get_snapshot().get("beat") == "boot_post", "crossing 0.9s should enter B2 BOOT_POST")
	timeline.advance(0.90)
	_expect(timeline.get_snapshot().get("beat") == "ignition_crest", "crossing 1.8s should enter B3 IGNITION_CREST")
	timeline.advance(0.25)
	_expect(timeline.get_snapshot().get("beat") == "reveal", "crossing 2.05s should enter B4 REVEAL")
	var settle_events: Array[String] = timeline.advance(0.70)
	_expect(settle_events == ["enter_settle"], "crossing the 2.75s total should enter B5 SETTLE")
	_expect(timeline.is_settled(), "post-total timeline should report settled")
	timeline.advance(5.0)
	_expect(timeline.get_snapshot().get("beat") == "settle", "SETTLE must hold indefinitely (B5 waits for confirm)")
	var record: Dictionary = timeline.get_snapshot().get("committed_record", {}) as Dictionary
	_expect(str(record.get("outcome", "")) == "success", "timeline snapshot should carry the committed record for tier branching")


# 저프레임 안전: 한 delta가 여러 경계를 관통하면 전이 이벤트를 순서대로 전부 낸다.
func _verify_multi_beat_delta_emits_ordered_events() -> void:
	var timeline := PerkFusionColdBootTimelineState.new()
	timeline.begin({})
	var events: Array[String] = timeline.advance(10.0)
	_expect(
		events == [
			"enter_twist_lock",
			"enter_boot_post",
			"enter_ignition_crest",
			"enter_reveal",
			"enter_settle",
		],
		"one huge delta should emit every beat transition in storyboard order"
	)
	_expect(timeline.is_settled(), "one huge delta should end settled")


func _verify_skip_from_every_beat_converges_to_settle() -> void:
	var lead_times: Array = [0.0, 0.6, 1.0, 1.9, 2.1]
	for lead_value: Variant in lead_times:
		var timeline := PerkFusionColdBootTimelineState.new()
		timeline.begin({})
		timeline.advance(float(lead_value))
		var events: Array[String] = timeline.skip_to_settle()
		_expect(events == ["enter_settle"], "skip at t=%s should jump straight to SETTLE" % str(lead_value))
		_expect(timeline.is_settled(), "skip at t=%s should leave the timeline settled" % str(lead_value))
		_expect(timeline.skip_to_settle().is_empty(), "a second skip must be a no-op")


# flow 통합: 커밋이 타임라인을 시작하고, flow.update가 비트를 굴리며,
# 자연 완주가 flow reveal과 함께 SETTLE로 수렴한다.
func _verify_flow_integration_drives_beats_and_reveal_settles() -> void:
	var flow := _committed_flow()
	var boot_snapshot: Dictionary = flow.get_snapshot().get("cold_boot", {}) as Dictionary
	_expect(bool(boot_snapshot.get("active", false)) and str(boot_snapshot.get("beat", "")) == "dock_in", "committed flow should start the cold-boot timeline at B0")
	flow.update(0.6)
	_expect(str((flow.get_snapshot().get("cold_boot", {}) as Dictionary).get("beat", "")) == "twist_lock", "flow.update should drive the timeline into B1")
	var total: float = PerkFusionColdBootTimelineState.TOTAL_ANIMATION_DURATION
	var reveal_result: Dictionary = flow.update(total)
	_expect(bool(reveal_result.get("entered_reveal", false)), "natural completion should reveal at the timeline total")
	_expect(str((flow.get_snapshot().get("cold_boot", {}) as Dictionary).get("beat", "")) == "settle", "natural reveal should settle the timeline")


func _verify_flow_skip_settles_timeline() -> void:
	var flow := _committed_flow()
	flow.update(0.2)
	var skip_result: Dictionary = flow.confirm_current()
	_expect(bool(skip_result.get("skipped_animation", false)), "confirm during animation should skip")
	_expect(str((flow.get_snapshot().get("cold_boot", {}) as Dictionary).get("beat", "")) == "settle", "skip must jump the timeline to the confirmed core reveal (SETTLE)")


# 코덱스 CB1-P1: 저프레임 실경로(flow.update(10.0))에서 전이 이벤트 전체가
# 순서대로 정확히 한 번 소비되는지 — 반환값 폐기가 아니라 큐-드레인 계약.
func _verify_flow_update_fanout_consumes_events_exactly_once() -> void:
	var flow := _committed_flow()
	flow.update(10.0)
	var events: Array = flow.consume_cold_boot_events()
	_expect(
		events == [
			"enter_twist_lock",
			"enter_boot_post",
			"enter_ignition_crest",
			"enter_reveal",
			"enter_settle",
		],
		"one low-frame flow.update must deliver every beat transition in order through the real fanout"
	)
	_expect((flow.consume_cold_boot_events() as Array).is_empty(), "a second drain must be empty (exactly-once consumption)")


func _verify_skip_path_event_reaches_consumer_once() -> void:
	var flow := _committed_flow()
	flow.update(0.2)
	flow.confirm_current()
	var events: Array = flow.consume_cold_boot_events()
	_expect(events == ["enter_settle"], "an early skip should deliver exactly the settle transition")
	_expect((flow.consume_cold_boot_events() as Array).is_empty(), "the skip event must not be re-delivered")


# runtime_perk_state 파사드: 실 state.update() 경로가 flow를 틱한 뒤 CB3
# 소비자가 state에서 드레인한다.
func _verify_state_facade_drains_events_from_real_update() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := StateRegistryStub.new(state, catalog)
	state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [{
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": ["item_luck", "common_bulk_up"],
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	state._perk_fusion_modal_flow.confirm_current()
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, {
		"outcome": 0.0,
		"magnitude": [0.0, 0.0],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0],
	})
	_expect(bool(commit_result.get("accepted", false)), "state facade fixture should commit")
	state.update(10.0, Vector2(760.0, 750.0), null, registry)
	var events: Array = state.consume_perk_fusion_cold_boot_events()
	_expect(
		events == [
			"enter_twist_lock",
			"enter_boot_post",
			"enter_ignition_crest",
			"enter_reveal",
			"enter_settle",
		],
		"the real state.update path should deliver the full ordered transition stream to the state drain"
	)
	_expect((state.consume_perk_fusion_cold_boot_events() as Array).is_empty(), "the state drain must also be exactly-once")


# duration 단일 권위: flow와 렌더러의 DEFAULT_ANIMATION_DURATION이 타임라인
# 총길이의 파생인지 — 값 동일 + 소스가 파생식인지(리터럴 재분기 금지).
func _verify_duration_single_authority() -> void:
	var total: float = PerkFusionColdBootTimelineState.TOTAL_ANIMATION_DURATION
	_expect(is_equal_approx(total, 2.75), "storyboard total (B0..B4) should be 2.75s")
	_expect(is_equal_approx(float(PerkFusionModalFlow.DEFAULT_ANIMATION_DURATION), total), "modal flow duration must equal the timeline total")
	_expect(is_equal_approx(float(PerkFusionOverlayRenderer.DEFAULT_ANIMATION_DURATION), total), "overlay renderer duration must equal the timeline total")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_modal_flow.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	var derived := "DEFAULT_ANIMATION_DURATION := PerkFusionColdBootTimelineState.TOTAL_ANIMATION_DURATION"
	_expect(flow_source.contains(derived), "modal flow must DERIVE its duration from the timeline authority (no literal re-fork)")
	_expect(renderer_source.contains(derived), "overlay renderer must DERIVE its duration from the timeline authority (no literal re-fork)")
	# 코덱스 CB1-P2: 공개 duration 주입 인자는 제거됨 — 시그니처 차원에서
	# 권위 우회를 막는다.
	_expect(flow_source.contains("func begin_committed_result(record: Dictionary) -> bool:"), "begin_committed_result must not accept a caller-supplied duration")
	_expect(not flow_source.contains("duration: float = DEFAULT_ANIMATION_DURATION"), "no caller-supplied duration bypass may remain")


func _verify_reset_clears_timeline() -> void:
	var flow := _committed_flow()
	flow.update(0.6)
	flow.reset()
	var boot_snapshot: Dictionary = flow.get_snapshot().get("cold_boot", {}) as Dictionary
	_expect(not bool(boot_snapshot.get("active", true)), "flow reset must deactivate the cold-boot timeline")
	_expect(str(boot_snapshot.get("beat", "")) == "dock_in", "flow reset should rewind the timeline to B0")


class StateRegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object

	func _init(state_value: Object, catalog_value: Object) -> void:
		state = state_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
		return null


func _committed_flow() -> Object:
	var flow := PerkFusionModalFlow.new()
	flow.start({"id": "perk_fusion"}, [], ["item_luck", "common_bulk_up"])
	flow.select_source_at(0)
	flow.select_source_at(1)
	flow.confirm_current()
	flow.confirm_current()
	flow.begin_committed_result({"fusion_id": "cb1", "outcome": "success"})
	return flow


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
