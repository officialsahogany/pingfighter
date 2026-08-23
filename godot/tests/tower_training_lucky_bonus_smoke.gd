extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerTrainingLuckyBonusPolicy := preload(
	"res://scripts/tower_ascent/tower_training_lucky_bonus_policy.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)

const TARGET_ID := "physique_move_speed"
const STORAGE_ID := "physique_storage"
const ALLOWED_TRAINING_IDS: Array[String] = [
	TARGET_ID,
	STORAGE_ID,
	"physique_dash_distance",
	"physique_paddle_size",
	"physique_max_gauge",
	"physique_hit_gauge",
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
		if owner == null or runtime_state == null:
			return
		var training_bonus := 0.0
		if runtime_state.has_method("get_physique_training_bonus"):
			training_bonus = float(runtime_state.get_physique_training_bonus("max_gauge_flat"))
		owner.set("special_gauge_max", 500.0 + training_bonus)

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		if runtime_state == null or not runtime_state.has_method("get_physique_training_bonus"):
			return base_charge
		var bonus_pct := float(runtime_state.get_physique_training_bonus("hit_gauge_bonus_pct"))
		return base_charge * (1.0 + bonus_pct / 100.0)

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

	func is_physique_training_saturated(
		training_id: String,
		_registry: Object = null
	) -> bool:
		return saturated_ids.has(training_id)

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var training_id := str(choice.get("id", ""))
		var effect_multiplier := float(choice.get("training_effect_multiplier", 1.0))
		if training_id == STORAGE_ID:
			effect_multiplier = 1.0
		var previous_applied_count := get_physique_training_applied_count(training_id)
		training_counts[training_id] = get_physique_training_count(training_id) + 1
		applied_counts[training_id] = previous_applied_count + effect_multiplier
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"physique_training": {
				"acquired_counts": training_counts.duplicate(true),
				"applied_counts": applied_counts.duplicate(true),
			},
		}

	func apply_unlock_save_snapshot(
		snapshot: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
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
	_verify_lucky_and_non_lucky_final_consumers()
	_verify_click_roll_gates_and_storage_exception()
	_verify_badge_and_saturation_copy()
	_verify_six_card_stats_panel_sync()
	_verify_presentation_rng_source_boundary()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)
	if _failures.is_empty():
		print("tower_training_lucky_bonus_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lucky_and_non_lucky_final_consumers() -> void:
	var lucky_seed := _find_seed(true)
	var normal_seed := _find_seed(false)
	_expect(lucky_seed > 0 and normal_seed > 0, "test must find deterministic lucky and normal seeds")

	var lucky_runtime := RuntimePerkState.new()
	var lucky_flow := _open_training_flow(lucky_runtime, 10)
	var lucky_presentation: Object = _training_presentation(lucky_flow)
	lucky_presentation.set_presentation_rng_for_tests(991, 0)
	lucky_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	lucky_flow.set_training_stage_clock_msec_for_tests(1000)
	_click_action(lucky_flow, "training_stat:%s" % TARGET_ID)
	var lucky_history: Array[Dictionary] = lucky_flow.get_training_history()
	_expect(lucky_history.size() == 1, "one valid click must produce one training record")
	var lucky_record: Dictionary = lucky_history[0]
	_expect(int(lucky_record.get("lucky_roll_count", 0)) == 1, "one valid click must roll exactly once")
	_expect(bool(lucky_record.get("lucky_triggered", false)), "lucky seed must trigger the 20 percent bonus")
	_expect(is_equal_approx(float(lucky_record.get("effect_multiplier", 0.0)), 1.5), "lucky record must carry the exact 1.5 multiplier")
	var lucky_snapshot := lucky_runtime.get_physique_training_snapshot()
	_expect(is_equal_approx(float((lucky_snapshot.get("applied_counts", {}) as Dictionary).get(TARGET_ID, 0.0)), 1.5), "authoritative snapshot must persist 1.5 applied training units")
	_expect(is_equal_approx(lucky_runtime.get_player_speed_multiplier(), 1.06), "final player-speed consumer must read the 4 percent base as an actual 6 percent lucky gain")
	_expect(str(lucky_flow.get_node_modal_view_model().get("status_text", "")) == "행운 발동! 기본 4% -> 6% 적용", "lucky receipt must show actual base and 1.5x values")

	var restored_runtime := RuntimePerkState.new()
	restored_runtime.restore_physique_training_snapshot(lucky_snapshot)
	_expect(is_equal_approx(restored_runtime.get_player_speed_multiplier(), 1.06), "restored snapshot must still reach the final player-speed consumer at 1.06")

	var rng_after_lucky: Dictionary = lucky_flow.get_training_gameplay_rng_state_for_tests()
	var presentation_rolls_before_frames := int(lucky_presentation.get_debug_state().get("presentation_rng_roll_count", -1))
	for frame_index in range(20):
		lucky_flow.set_training_stage_clock_msec_for_tests(1000 + frame_index * 16)
		lucky_flow.update_selective(0.016, null)
	_expect(lucky_flow.get_training_history().size() == 1, "twenty animation frames must not create another training resolution")
	_expect(lucky_flow.get_training_gameplay_rng_state_for_tests() == rng_after_lucky, "GRT-011 animation frames must not advance gameplay RNG")
	_expect(int(lucky_presentation.get_debug_state().get("presentation_rng_roll_count", -1)) == presentation_rolls_before_frames, "retained strike frames must not reroll presentation randomness")

	var resolution_id := str(lucky_record.get("node_resolution_id", ""))
	var duplicate_rng_before: Dictionary = lucky_flow.get_training_gameplay_rng_state_for_tests()
	var duplicate: Dictionary = lucky_flow.execute_node_action(
		"training_stat:%s" % TARGET_ID,
		resolution_id
	)
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("applied", true)), "an already handled resolution must remain an accepted no-op")
	_expect(lucky_flow.get_training_gameplay_rng_state_for_tests() == duplicate_rng_before, "an already handled resolution must consume zero rolls")

	var differential_runtime := RuntimePerkState.new()
	var differential_flow := _open_training_flow(differential_runtime, 10)
	var differential_presentation: Object = _training_presentation(differential_flow)
	differential_presentation.set_presentation_rng_for_tests(991, 37)
	differential_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	differential_flow.set_training_stage_clock_msec_for_tests(1000)
	_click_action(differential_flow, "training_stat:%s" % TARGET_ID)
	_expect(
		int(differential_presentation.get_debug_state().get("presentation_rng_roll_count", 0))
		!= presentation_rolls_before_frames,
		"differential leg must consume a different number of presentation RNG samples"
	)
	_expect(
		var_to_bytes(differential_presentation.get_visual_model().get("impact_point_offsets", []))
		!= var_to_bytes(lucky_presentation.get_visual_model().get("impact_point_offsets", [])),
		"differential presentation seeds/consumption must change retained impact points"
	)
	var differential_history: Array[Dictionary] = differential_flow.get_training_history()
	_expect(bool(differential_history[0].get("lucky_triggered", false)), "presentation RNG consumption must not change the lucky result")
	var differential_rng_after: Dictionary = differential_flow.get_training_gameplay_rng_state_for_tests()
	_expect(differential_rng_after == rng_after_lucky, "presentation RNG consumption must not change the next gameplay RNG state")
	_expect(
		is_equal_approx(
			float(TowerTrainingLuckyBonusPolicy.roll_from_gameplay_state(differential_rng_after).get("sample", -1.0)),
			float(TowerTrainingLuckyBonusPolicy.roll_from_gameplay_state(rng_after_lucky).get("sample", -2.0))
		),
		"differential presentation consumption must leave the same next gameplay RNG value"
	)

	var normal_runtime := RuntimePerkState.new()
	var normal_flow := _open_training_flow(normal_runtime, 10)
	normal_flow.set_training_gameplay_rng_state_for_tests(_rng_state(normal_seed))
	_click_action(normal_flow, "training_stat:%s" % TARGET_ID)
	var normal_record: Dictionary = normal_flow.get_training_history()[0]
	_expect(int(normal_record.get("lucky_roll_count", 0)) == 1 and not bool(normal_record.get("lucky_triggered", true)), "normal seed must still consume exactly one roll and not trigger")
	_expect(is_equal_approx(float(normal_record.get("effect_multiplier", 0.0)), 1.0), "negative leg must keep the exact base multiplier")
	_expect(is_equal_approx(normal_runtime.get_player_speed_multiplier(), 1.04), "negative leg final consumer must read exactly the 4 percent base value")
	_expect(str(normal_flow.get_node_modal_view_model().get("status_text", "")) == "4% 적용", "negative receipt must show only the actual base applied value")


func _verify_click_roll_gates_and_storage_exception() -> void:
	var lucky_seed := _find_seed(true)
	var canceled_runtime := FakeRuntimePerkState.new()
	var canceled_flow := _open_training_flow(canceled_runtime, 10)
	canceled_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	var canceled_rng_before: Dictionary = canceled_flow.get_training_gameplay_rng_state_for_tests()
	var action_rect := _action_rect(canceled_flow, "training_stat:%s" % TARGET_ID)
	var press := _mouse_button(true, action_rect.position + Vector2(2.0, 2.0))
	var canceled_release := _mouse_button(false, Vector2.ZERO)
	canceled_flow.handle_input(press)
	canceled_flow.handle_input(canceled_release)
	_expect(canceled_flow.get_training_history().is_empty(), "release outside the armed card must cancel the click")
	_expect(canceled_flow.get_training_gameplay_rng_state_for_tests() == canceled_rng_before, "canceled press/release must consume zero rolls")

	var poor_runtime := FakeRuntimePerkState.new()
	var poor_flow := _open_training_flow(poor_runtime, 0)
	poor_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	var poor_rng_before: Dictionary = poor_flow.get_training_gameplay_rng_state_for_tests()
	_click_action(poor_flow, "training_stat:%s" % TARGET_ID)
	_expect(poor_flow.get_training_history().is_empty(), "insufficient Muhon card must not commit")
	_expect(poor_flow.get_training_gameplay_rng_state_for_tests() == poor_rng_before, "insufficient cost must consume zero rolls")

	var saturated_runtime := FakeRuntimePerkState.new()
	saturated_runtime.saturated_ids.append(TARGET_ID)
	var saturated_flow := _open_training_flow(saturated_runtime, 10)
	saturated_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	var saturated_rng_before: Dictionary = saturated_flow.get_training_gameplay_rng_state_for_tests()
	_click_action(saturated_flow, "training_stat:%s" % TARGET_ID)
	_expect(saturated_flow.get_training_history().is_empty(), "disabled saturated card must not commit")
	_expect(saturated_flow.get_training_gameplay_rng_state_for_tests() == saturated_rng_before, "disabled saturated card must consume zero rolls")

	var storage_runtime := RuntimePerkState.new()
	var storage_flow := _open_training_flow(storage_runtime, 10)
	storage_flow.set_training_gameplay_rng_state_for_tests(_rng_state(lucky_seed))
	var storage_rng_before: Dictionary = storage_flow.get_training_gameplay_rng_state_for_tests()
	var base_slots := storage_runtime.get_active_item_slot_capacity()
	_click_action(storage_flow, "training_stat:%s" % STORAGE_ID)
	var storage_record: Dictionary = storage_flow.get_training_history()[0]
	_expect(int(storage_record.get("lucky_roll_count", -1)) == 0, "storage training must be excluded from lucky rolls")
	_expect(storage_flow.get_training_gameplay_rng_state_for_tests() == storage_rng_before, "storage training must not advance gameplay RNG")
	_expect(storage_runtime.get_active_item_slot_capacity() == base_slots + 1, "storage final consumer must gain exactly one slot")
	var storage_snapshot := storage_runtime.get_physique_training_snapshot()
	_expect(is_equal_approx(float((storage_snapshot.get("applied_counts", {}) as Dictionary).get(STORAGE_ID, 0.0)), 1.0), "storage snapshot must persist exactly one applied slot")
	_expect(str(storage_flow.get_node_modal_view_model().get("status_text", "")) == "1칸 적용", "storage receipt must report the fixed one-slot value")


func _verify_badge_and_saturation_copy() -> void:
	var runtime := FakeRuntimePerkState.new()
	var flow := _open_training_flow(runtime, 10)
	var lucky_action := _find_action(flow, "training_stat:%s" % TARGET_ID)
	var lucky_choice: Dictionary = lucky_action.get("payload", {}).get("choice", {})
	_expect(str(lucky_choice.get("bonus_badge_text", "")) == "행운 20% · 효과 +50%", "production lucky card must supply the exact always-on badge")
	var storage_action := _find_action(flow, "training_stat:%s" % STORAGE_ID)
	var storage_choice: Dictionary = storage_action.get("payload", {}).get("choice", {})
	_expect(str(storage_choice.get("bonus_badge_text", "")) == "고정 +1칸", "storage card must disclose its fixed integer exception")

	var renderer := RuntimePerkOverlayRenderer.new()
	var longest_action := lucky_action.duplicate(true)
	var longest_choice: Dictionary = longest_action.get("payload", {}).get("choice", {})
	longest_choice["description"] = "수련 효과와 실제 적용값을 확인하는 가장 긴 설명 문구를 세 행 예산으로 정확하게 검증합니다 반복 문장"
	var layout: Dictionary = renderer.build_tower_node_card_text_layout(
		longest_action,
		_action_rect(flow, "training_stat:%s" % TARGET_ID)
	)
	_expect(int(layout.get("appended_description_row_count", -1)) == 3, "production longest Korean training copy must append exactly three description rows")
	_expect(int(layout.get("appended_bonus_badge_row_count", -1)) == 1, "production lucky badge must append exactly one whole row")
	_expect(int(layout.get("appended_text_row_count", -1)) == 4, "GRT-021 production card must append exactly four rows")
	_expect(
		renderer.should_draw_tower_node_bonus_badge(layout, {}),
		"idle training card must draw its complete lucky badge"
	)
	_expect(
		not renderer.should_draw_tower_node_bonus_badge(
			layout,
			{"success_progress": 0.5}
		),
		"GRT-021 success receipt must temporarily replace the whole badge row"
	)

	runtime.saturated_ids.append(TARGET_ID)
	flow.call("_refresh_training_modal", "")
	var saturated_action := _find_action(flow, "training_stat:%s" % TARGET_ID)
	_expect(str(saturated_action.get("unavailable_reason", "")) == "효과 한계", "consumer saturation must replace the retired maximum-level copy with effect limit")

	runtime.training_counts[STORAGE_ID] = 3
	runtime.applied_counts[STORAGE_ID] = 3.0
	flow.call("_refresh_training_modal", "")
	var full_storage_action := _find_action(flow, "training_stat:%s" % STORAGE_ID)
	_expect(str(full_storage_action.get("payload", {}).get("choice", {}).get("level_text", "")) == "3/3", "full storage must display exactly 3/3")
	_expect(str(full_storage_action.get("unavailable_reason", "")) == "3/3", "full storage rejection must display exactly 3/3")
	var unlimited_choice: Dictionary = lucky_action.get("payload", {}).get("choice", {})
	var presentation: Dictionary = lucky_action.get("payload", {}).get("presentation", {})
	_expect(str(unlimited_choice.get("level_text", "")) == "Lv.0", "unlimited training must retain its Lv.N label")
	_expect(str(presentation.get("current", "")) == "0%" and str(presentation.get("result", "")) == "4%", "unlimited training hover fallback must show only current and applied values")


func _verify_presentation_rng_source_boundary() -> void:
	var strike_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
	)
	var audio_source := FileAccess.get_file_as_string(
		"res://scripts/audio/game_audio.gd"
	)
	_expect(
		strike_source.contains("RandomNumberGenerator.new()")
		and strike_source.contains("impact_point_offsets")
		and not strike_source.contains("_gameplay_rng_state"),
		"impact points and fragments must use a presentation RNG with no gameplay-state access"
	)
	var training_audio_start := audio_source.find("func play_training_strike_hit")
	var training_audio_end := audio_source.find("func stop_training_strike_audio", training_audio_start)
	var training_audio_body := audio_source.substr(
		training_audio_start,
		training_audio_end - training_audio_start
	)
	_expect(
		audio_source.contains("var _core_match_feedback_rng := RandomNumberGenerator.new()")
		and training_audio_body.contains("_core_match_feedback_randf_range(0.98, 1.02)"),
		"training strike pitch must use GameAudio's separate presentation RNG"
	)


func _verify_six_card_stats_panel_sync() -> void:
	var runtime := RuntimePerkState.new()
	var flow := _open_training_flow(runtime, 20)
	var registry: Object = flow.get("_active_registry")
	var renderer: Object = registry.get_cached_instance("runtime_perk_overlay_renderer")
	var opening_snapshot: Dictionary = renderer.get_tower_training_stats_snapshot_for_tests()
	_expect(int(opening_snapshot.get("row_count", 0)) == 10, "training modal must prepare all ten canonical character-info rows")
	_expect(int(opening_snapshot.get("prepare_count", 0)) == 1, "training stats panel must prepare once on modal open")
	for idle_frame in range(12):
		flow.get_node_modal_view_model()
		flow.get_node_modal_render_context()
	_expect(
		int(renderer.get_tower_training_stats_snapshot_for_tests().get("prepare_count", 0)) == 1,
		"GRT-028 idle frames must perform zero additional stats-panel preparation"
	)

	for card_index in range(6):
		var before: Dictionary = renderer.get_tower_training_stats_snapshot_for_tests()
		var before_values: Array = before.get("values", [])
		var model: Dictionary = flow.get_node_modal_view_model()
		var actions: Array = model.get("actions", [])
		var rects: Array = model.get("action_rects", [])
		_expect(actions.size() == 7 and rects.size() == 7, "training rail must keep six offers plus end work")
		var action := actions[card_index] as Dictionary
		var rect := rects[card_index] as Rect2
		var top_corner := rect.position + Vector2(2.0, 2.0)
		flow.handle_input(_mouse_button(true, top_corner))
		flow.handle_input(_mouse_button(false, top_corner))
		var after: Dictionary = renderer.get_tower_training_stats_snapshot_for_tests()
		_expect(
			flow.get_training_history().size() == card_index + 1,
			"card %d top-corner click must commit exactly one training action" % (card_index + 1)
		)
		_expect(
			int(after.get("prepare_count", 0)) == card_index + 2,
			"card %d commit must refresh the canonical stats cache in the same input frame" % (card_index + 1)
		)
		_expect(
			var_to_bytes(after.get("values", [])) != var_to_bytes(before_values),
			"card %d (%s) commit must change a final-consumer stat row immediately: %s -> %s" % [
				card_index + 1,
				str(action.get("id", "")),
				str(before_values),
				str(after.get("values", [])),
			]
		)
		_expect(
			str(action.get("id", "")).begins_with("training_"),
			"card %d must retain the production training action route" % (card_index + 1)
		)
func _open_training_flow(runtime_state: Object, muhon: int) -> Object:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"tower_ascent_unlock_store": FakeUnlockStore.new(),
		"runtime_perk_overlay_renderer": RuntimePerkOverlayRenderer.new(),
		"mythic_item_runtime": FakeMythicItemRuntime.new(runtime_state),
	}
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active", true)
	flow.set("_phase", 1)
	flow.set("_node_modal_kind", "training")
	flow.set("_current_node_id", "s4-training-node")
	flow.set("_map_seed", 417)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", registry)
	var run_state: Object = flow.get("_run_state")
	_expect(run_state.begin("s4-training-run", {"muhon": muhon}), "training test run state must begin")
	flow.call("_open_node_modal")
	return flow


func _training_presentation(flow: Object) -> Object:
	return flow.get_node_modal_render_context().get("training_stage_presentation", null)


func _click_action(flow: Object, action_id: String) -> void:
	var rect := _action_rect(flow, action_id)
	_expect(rect.has_area(), "%s must have a production hit rect" % action_id)
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


func _find_seed(triggered: bool) -> int:
	for seed_value in range(1, 10000):
		var roll := TowerTrainingLuckyBonusPolicy.roll_from_gameplay_state(
			_rng_state(seed_value)
		)
		if bool(roll.get("triggered", false)) == triggered:
			return seed_value
	return 0


func _rng_state(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {"seed": int(rng.seed), "state": int(rng.state)}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
