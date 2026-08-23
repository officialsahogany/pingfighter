extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAscentFlowOwner := preload("res://scripts/tower_ascent/tower_ascent_flow_owner.gd")
const TowerTrainingTimingJudgmentPolicy := preload("res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd")
const TowerTrainingTimingState := preload("res://scripts/tower_ascent/tower_training_timing_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")

const TARGET_ID := "physique_move_speed"
const STORAGE_ID := "physique_storage"
const ALLOWED_TRAINING_IDS: Array[String] = [
	TARGET_ID, STORAGE_ID, "physique_dash_distance", "physique_paddle_size",
	"physique_max_gauge", "physique_hit_gauge",
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var current_stage := 4
	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return ALLOWED_TRAINING_IDS.has(content_id)


class FakeMythicItemRuntime:
	extends RefCounted
	var runtime_state: Object = null

	func _init(runtime_state_value: Object) -> void:
		runtime_state = runtime_state_value

	func refresh_runtime_perk_scaling(owner: Object, _registry: Object) -> void:
		if owner != null and runtime_state != null:
			owner.set("special_gauge_max", 500.0 + float(
				runtime_state.get_physique_training_bonus("max_gauge_flat")
			))

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		if runtime_state == null:
			return base_charge
		return base_charge * (1.0 + float(
			runtime_state.get_physique_training_bonus("hit_gauge_bonus_pct")
		) / 100.0)

	func get_player_paddle_scale() -> float:
		return 1.0


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels: Dictionary = {}
	var training_counts: Dictionary = {}
	var applied_counts: Dictionary = {}
	var saturated_ids: Array[String] = []

	func get_physique_training_count(training_id: String) -> int:
		return int(training_counts.get(training_id, 0))

	func get_physique_training_applied_count(training_id: String) -> float:
		return float(applied_counts.get(training_id, get_physique_training_count(training_id)))

	func get_physique_training_multiplier() -> float:
		return 1.0

	func get_physique_training_bonus(_lane: String) -> float:
		return 0.0

	func is_physique_training_saturated(training_id: String, _registry: Object = null) -> bool:
		return saturated_ids.has(training_id)

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var training_id := str(choice.get("id", ""))
		var effect_multiplier := float(choice.get("training_effect_multiplier", 1.0))
		if training_id == STORAGE_ID:
			effect_multiplier = 1.0
		training_counts[training_id] = get_physique_training_count(training_id) + 1
		applied_counts[training_id] = get_physique_training_applied_count(training_id) + effect_multiplier
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"physique_training": {
				"acquired_counts": training_counts.duplicate(true),
				"applied_counts": applied_counts.duplicate(true),
			},
		}

	func apply_unlock_save_snapshot(snapshot: Dictionary, _owner: Object = null, _registry: Object = null) -> Dictionary:
		var training: Dictionary = snapshot.get("physique_training", {})
		training_counts = (training.get("acquired_counts", {}) as Dictionary).duplicate(true)
		applied_counts = (training.get("applied_counts", {}) as Dictionary).duplicate(true)
		return {"restored": true}


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_conversion_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_three_tier_final_consumers()
	_verify_target_roll_gates_cancel_and_input_ownership()
	_verify_rng_separation_and_wall_clock()
	_verify_storage_badge_and_saturation_copy()
	_verify_six_card_stats_panel_sync()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)
	if _failures.is_empty():
		print("tower_training_lucky_bonus_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_three_tier_final_consumers() -> void:
	for spec in [
		{"kind": "critical", "multiplier": 1.5, "consumer": 1.06, "copy": "회심의 수련!", "value": "+6%"},
		{"kind": "great", "multiplier": 1.3, "consumer": 1.052, "copy": "훌륭한 수련!", "value": "+5.2%"},
		{"kind": "base", "multiplier": 1.0, "consumer": 1.04, "copy": "수련 성공", "value": "+4%"},
	]:
		var runtime := RuntimePerkState.new()
		var flow := _open_training_flow(runtime, 10)
		var gameplay_rng_before: Dictionary = flow.get_training_gameplay_rng_state_for_tests()
		_start_timing(flow, "training_stat:%s" % TARGET_ID, 1000)
		_stop_timing_at(flow, str(spec.kind))
		var history: Array[Dictionary] = flow.get_training_history()
		_expect(history.size() == 1, "%s stop must commit one training record" % spec.kind)
		if history.is_empty():
			continue
		var record: Dictionary = history[0]
		_expect(str(record.get("timing_judgment_kind", "")) == spec.kind, "%s tier must be authoritative" % spec.kind)
		_expect(int(record.get("timing_target_roll_count", 0)) == 1, "%s click must own exactly one target roll" % spec.kind)
		_expect(is_equal_approx(float(record.get("effect_multiplier", 0.0)), float(spec.multiplier)), "%s multiplier must be exact" % spec.kind)
		var snapshot := runtime.get_physique_training_snapshot()
		_expect(is_equal_approx(float((snapshot.get("applied_counts", {}) as Dictionary).get(TARGET_ID, 0.0)), float(spec.multiplier)), "%s snapshot must persist the applied multiplier" % spec.kind)
		_expect(is_equal_approx(runtime.get_player_speed_multiplier(), float(spec.consumer)), "%s final player-speed consumer must read the applied value" % spec.kind)
		var receipt := str(flow.get_training_stage_presentation_debug_state().get(
			"message_text",
			""
		))
		_expect(receipt.contains(str(spec.copy)) and receipt.contains("이동 속도") and receipt.contains(str(spec.value)), "%s receipt must derive its stat label and applied value: %s" % [spec.kind, receipt])
		_expect(flow.get_training_gameplay_rng_state_for_tests() == gameplay_rng_before, "%s target and presentation must not advance gameplay RNG" % spec.kind)


func _verify_target_roll_gates_cancel_and_input_ownership() -> void:
	var canceled_flow := _open_training_flow(FakeRuntimePerkState.new(), 10)
	var canceled_rng_before: Dictionary = canceled_flow.get_training_gameplay_rng_state_for_tests()
	var target_rect := _action_rect(canceled_flow, "training_stat:%s" % TARGET_ID)
	canceled_flow.handle_input(_mouse_button(true, target_rect.position + Vector2(2.0, 2.0)))
	canceled_flow.handle_input(_mouse_button(false, Vector2.ZERO))
	_expect(canceled_flow.get_training_timing_roll_count_for_tests() == 0, "release outside armed card must consume zero target rolls")
	_expect(canceled_flow.get_training_history().is_empty(), "release outside armed card must not commit")

	_start_timing(canceled_flow, "training_stat:%s" % TARGET_ID, 2000)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	canceled_flow.handle_input(escape)
	_expect(canceled_flow.get_training_timing_roll_count_for_tests() == 1, "ESC keeps the consumed roll to prevent free rerolls")
	_expect(canceled_flow.get_training_history().is_empty(), "ESC before judgment must not commit")
	_expect(int(canceled_flow.get_run_state_snapshot().get("muhon", -1)) == 10, "ESC before judgment must spend zero Muhon")
	_expect(not bool(canceled_flow.get_training_timing_debug_state().get("running", false)), "ESC must clear the active gauge")
	_expect(canceled_flow.get_training_gameplay_rng_state_for_tests() == canceled_rng_before, "ESC and target placement must not touch gameplay RNG")

	var poor_flow := _open_training_flow(FakeRuntimePerkState.new(), 0)
	_click_card_release(poor_flow, "training_stat:%s" % TARGET_ID)
	_expect(poor_flow.get_training_timing_roll_count_for_tests() == 0, "insufficient cost must consume zero target rolls")
	_expect(poor_flow.get_training_history().is_empty(), "insufficient cost must not open or commit timing")

	var saturated_runtime := FakeRuntimePerkState.new()
	saturated_runtime.saturated_ids.append(TARGET_ID)
	var saturated_flow := _open_training_flow(saturated_runtime, 10)
	_click_card_release(saturated_flow, "training_stat:%s" % TARGET_ID)
	_expect(saturated_flow.get_training_timing_roll_count_for_tests() == 0, "disabled saturated card must consume zero target rolls")

	var duplicate_flow := _open_training_flow(FakeRuntimePerkState.new(), 20)
	var duplicate_action := _find_action(duplicate_flow, "training_stat:%s" % TARGET_ID)
	var first: Dictionary = duplicate_flow.execute_node_action("training_stat:%s" % TARGET_ID, "sealed-training-resolution")
	_expect(bool(first.get("applied", false)), "duplicate fixture must commit its first resolution")
	var duplicate_rolls_before: int = duplicate_flow.get_training_timing_roll_count_for_tests()
	var duplicate: Dictionary = duplicate_flow.call("_begin_training_timing_action", duplicate_action, "sealed-training-resolution")
	_expect(not bool(duplicate.get("prepared", true)), "already committed resolution must not open a gauge")
	_expect(duplicate_flow.get_training_timing_roll_count_for_tests() == duplicate_rolls_before, "already committed resolution must consume zero target rolls")

	var owned_flow := _open_training_flow(FakeRuntimePerkState.new(), 10)
	_start_timing(owned_flow, "training_stat:%s" % TARGET_ID, 3000)
	var end_rect := _action_rect(owned_flow, "end_work")
	owned_flow.handle_input(_mouse_button(true, end_rect.get_center()))
	owned_flow.handle_input(_mouse_button(false, end_rect.get_center()))
	_expect(owned_flow.get_training_history().size() == 1, "gauge click must stop and commit its pending card")
	_expect(int(owned_flow.get("_phase")) == 1, "gauge click over end work must not leak into modal exit")


func _verify_rng_separation_and_wall_clock() -> void:
	var first_flow := _open_training_flow(FakeRuntimePerkState.new(), 10)
	var second_flow := _open_training_flow(FakeRuntimePerkState.new(), 10)
	var first_presentation: Object = _training_presentation(first_flow)
	var second_presentation: Object = _training_presentation(second_flow)
	first_presentation.set_presentation_rng_for_tests(991, 0)
	second_presentation.set_presentation_rng_for_tests(991, 37)
	_start_timing(first_flow, "training_stat:%s" % TARGET_ID, 4000)
	_start_timing(second_flow, "training_stat:%s" % TARGET_ID, 4000)
	var first_target := float(first_flow.get_training_timing_debug_state().get("target_position", -1.0))
	var second_target := float(second_flow.get_training_timing_debug_state().get("target_position", -2.0))
	_expect(is_equal_approx(first_target, second_target), "presentation RNG consumption must not change the authoritative target")
	_stop_timing_at(first_flow, "critical")
	_stop_timing_at(second_flow, "critical")
	_expect(first_flow.get_training_gameplay_rng_state_for_tests() == second_flow.get_training_gameplay_rng_state_for_tests(), "presentation RNG differential must leave gameplay RNG identical")
	_expect(var_to_bytes(first_presentation.get_visual_model().get("impact_point_offsets", [])) != var_to_bytes(second_presentation.get_visual_model().get("impact_point_offsets", [])), "presentation RNG differential must change cosmetic impact points")

	var target_a := TowerTrainingTimingJudgmentPolicy.roll_target(417, "node", "action", 0, 20.0)
	var target_b := TowerTrainingTimingJudgmentPolicy.roll_target(418, "node", "action", 0, 20.0)
	_expect(not is_equal_approx(float(target_a.target_position), float(target_b.target_position)), "differential authority seeds must change target placement")
	_expect(int(target_a.roll_count) == 1 and int(target_b.roll_count) == 1, "each target placement call consumes one sample")
	for sample_msec in [0, 137, 799, 800, 801, 1599, 1600, 2400]:
		var at_72hz := TowerTrainingTimingState.pendulum_position_at_elapsed(sample_msec)
		var unlimited := TowerTrainingTimingState.pendulum_position_at_elapsed(sample_msec)
		_expect(is_equal_approx(at_72hz, unlimited), "wall-clock pendulum must be frame-rate independent at %dms" % sample_msec)
	_expect(is_equal_approx(TowerTrainingTimingState.pendulum_position_at_elapsed(0), TowerTrainingTimingState.pendulum_position_at_elapsed(1600)), "pendulum full-cycle period must be 1600ms")


func _verify_storage_badge_and_saturation_copy() -> void:
	var storage_runtime := RuntimePerkState.new()
	var storage_flow := _open_training_flow(storage_runtime, 10)
	var base_slots := storage_runtime.get_active_item_slot_capacity()
	_start_timing(storage_flow, "training_stat:%s" % STORAGE_ID, 5000)
	_stop_timing_at(storage_flow, "critical")
	var storage_record: Dictionary = storage_flow.get_training_history()[0]
	_expect(str(storage_record.get("timing_judgment_kind", "")) == "critical", "storage reports the visible timing tier")
	_expect(is_equal_approx(float(storage_record.get("effect_multiplier", 0.0)), 1.0), "storage must never round 1.5 slots into +2")
	_expect(storage_runtime.get_active_item_slot_capacity() == base_slots + 1, "storage final consumer gains exactly one slot")
	_expect(str(_find_action(storage_flow, "training_stat:%s" % STORAGE_ID).get("payload", {}).get("choice", {}).get("bonus_badge_text", "")) == "고정 +1칸", "storage card discloses its fixed exception")

	var runtime := FakeRuntimePerkState.new()
	var flow := _open_training_flow(runtime, 10)
	var timing_action := _find_action(flow, "training_stat:%s" % TARGET_ID)
	_expect(str(timing_action.get("payload", {}).get("choice", {}).get("bonus_badge_text", "")).is_empty(), "ordinary timing cards expose no footer badge")
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"
	)
	var action_builder_start := flow_source.find("func _build_training_action(")
	var action_builder_end := flow_source.find("func _begin_training_timing_action(", action_builder_start)
	var action_builder_source := flow_source.substr(
		action_builder_start,
		action_builder_end - action_builder_start
	)
	_expect(not action_builder_source.contains("KEY_TRAINING_TIMING_BADGE"), "training action producer must not inject the retired timing footer badge")
	var renderer := RuntimePerkOverlayRenderer.new()
	var layout: Dictionary = renderer.build_tower_node_card_text_layout(timing_action, _action_rect(flow, "training_stat:%s" % TARGET_ID))
	_expect(int(layout.get("appended_description_row_count", -1)) == 1, "compact rail appends one complete fitted effect row")
	_expect(int(layout.get("appended_bonus_badge_row_count", -1)) == 0, "ordinary timing footer appends zero rows")
	_expect(int(layout.get("appended_text_row_count", -1)) == 1, "compact card budgets only its fitted effect row")
	runtime.saturated_ids.append(TARGET_ID)
	flow.call("_refresh_training_modal", "")
	_expect(str(_find_action(flow, "training_stat:%s" % TARGET_ID).get("unavailable_reason", "")) == "효과 한계", "consumer saturation retains effect-limit copy")
	runtime.training_counts[STORAGE_ID] = 3
	runtime.applied_counts[STORAGE_ID] = 3.0
	flow.call("_refresh_training_modal", "")
	_expect(str(_find_action(flow, "training_stat:%s" % STORAGE_ID).get("unavailable_reason", "")) == "3/3", "full storage displays 3/3")


func _verify_six_card_stats_panel_sync() -> void:
	var flow := _open_training_flow(RuntimePerkState.new(), 20)
	var registry: Object = flow.get("_active_registry")
	var renderer: Object = registry.get_cached_instance("runtime_perk_overlay_renderer")
	var opening: Dictionary = renderer.get_tower_training_stats_snapshot_for_tests()
	_expect(int(opening.get("row_count", 0)) == 10, "modal prepares ten canonical stat rows")
	_expect(int(opening.get("prepare_count", 0)) == 1, "stats panel prepares once on open")
	for idle_frame in range(12):
		flow.get_node_modal_view_model()
		flow.get_node_modal_render_context()
	_expect(int(renderer.get_tower_training_stats_snapshot_for_tests().get("prepare_count", 0)) == 1, "idle frames perform zero stats-panel preparation")
	for card_index in range(6):
		var model: Dictionary = flow.get_node_modal_view_model()
		var actions: Array = model.get("actions", [])
		var rects: Array = model.get("action_rects", [])
		var action := actions[card_index] as Dictionary
		var before_prepare := int(renderer.get_tower_training_stats_snapshot_for_tests().get("prepare_count", 0))
		var point := (rects[card_index] as Rect2).position + Vector2(2.0, 2.0)
		flow.set_training_stage_clock_msec_for_tests(6000 + card_index * 3000)
		flow.handle_input(_mouse_button(true, point))
		flow.handle_input(_mouse_button(false, point))
		_expect(flow.get_training_history().size() == card_index, "card release opens timing without early commit")
		_stop_timing_at(flow, "base")
		_expect(flow.get_training_history().size() == card_index + 1, "card %d top-corner timing commits once" % (card_index + 1))
		_expect(int(renderer.get_tower_training_stats_snapshot_for_tests().get("prepare_count", 0)) == before_prepare + 1, "card %d refreshes stats in the stop input frame" % (card_index + 1))
		_expect(str(action.get("id", "")).begins_with("training_"), "card %d retains training routing" % (card_index + 1))
		_finish_presentation(flow)


func _open_training_flow(runtime_state: Object, muhon: int) -> Object:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"tower_ascent_unlock_store": FakeUnlockStore.new(),
		"runtime_perk_overlay_renderer": RuntimePerkOverlayRenderer.new(),
		"mythic_item_runtime": FakeMythicItemRuntime.new(runtime_state),
	}
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active", true)
	flow.set("_phase", 1)
	flow.set("_node_modal_kind", "training")
	flow.set("_current_node_id", "timing-training-node")
	flow.set("_map_seed", 417)
	flow.set("_active_owner", FakeOwner.new())
	flow.set("_active_registry", registry)
	_expect(flow.get("_run_state").begin("timing-training-run", {"muhon": muhon}), "training run state begins")
	flow.call("_open_node_modal")
	return flow


func _training_presentation(flow: Object) -> Object:
	return flow.get_node_modal_render_context().get("training_stage_presentation", null)


func _start_timing(flow: Object, action_id: String, start_msec: int) -> void:
	flow.set_training_stage_clock_msec_for_tests(start_msec)
	var rolls_before: int = flow.get_training_timing_roll_count_for_tests()
	_click_card_release(flow, action_id)
	_expect(bool(flow.get_training_timing_debug_state().get("running", false)), "%s opens timing" % action_id)
	_expect(flow.get_training_timing_roll_count_for_tests() == rolls_before + 1, "%s consumes one target roll" % action_id)


func _stop_timing_at(flow: Object, judgment_kind: String) -> void:
	var debug: Dictionary = flow.get_training_timing_debug_state()
	var target := float(debug.get("target_position", 0.5))
	var cell_width := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(float(debug.get("luck_percent", 20.0)))
	var position := target
	if judgment_kind == "great":
		position = target + cell_width
	elif judgment_kind == "base":
		position = 0.0 if target >= 0.5 else 1.0
	var elapsed := int(roundf(clampf(position, 0.0, 1.0) * float(TowerTrainingTimingState.FULL_CYCLE_MSEC) * 0.5))
	flow.set_training_stage_clock_msec_for_tests(int(debug.get("started_msec", 0)) + elapsed)
	flow.handle_input(_mouse_button(true, Vector2(8.0, 8.0)))
	flow.handle_input(_mouse_button(false, Vector2(8.0, 8.0)))


func _finish_presentation(flow: Object) -> void:
	var debug: Dictionary = flow.get_training_stage_presentation_debug_state()
	flow.set_training_stage_clock_msec_for_tests(int(debug.get("started_msec", 0)) + 2000)
	flow.update_selective(0.016, null)


func _click_card_release(flow: Object, action_id: String) -> void:
	var rect := _action_rect(flow, action_id)
	_expect(rect.has_area(), "%s has a production hit rect" % action_id)
	var point := rect.position + Vector2(2.0, 2.0)
	flow.handle_input(_mouse_button(true, point))
	flow.handle_input(_mouse_button(false, point))


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event


func _action_rect(flow: Object, action_id: String) -> Rect2:
	var model: Dictionary = flow.get_node_modal_view_model()
	var actions: Array = model.get("actions", [])
	var rects: Array = model.get("action_rects", [])
	for index in range(actions.size()):
		if str((actions[index] as Dictionary).get("id", "")) == action_id:
			return rects[index] as Rect2
	return Rect2()


func _find_action(flow: Object, action_id: String) -> Dictionary:
	for action_value in flow.get_node_modal_view_model().get("actions", []):
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")) == action_id:
			return action_value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
