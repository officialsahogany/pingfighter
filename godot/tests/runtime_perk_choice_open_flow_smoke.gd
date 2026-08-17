extends SceneTree

const RuntimePerkChoiceOpenFlow := preload("res://scripts/characters/runtime_perk_choice_open_flow.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_no_pending_closes_choice_and_resets_flight()
	_verify_ready_path_generates_choices_and_runs_side_effects()
	_verify_runtime_state_facade_generates_choices_and_runs_side_effects()
	_verify_empty_choice_result_reopens_with_preserved_context()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_open_flow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_no_pending_closes_choice_and_resets_flight() -> void:
	var helper := RuntimePerkChoiceOpenFlow.new()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 0
	state.choice_active = true
	state.current_choices = [{"id": "old"}]
	state.choice_flight_effect = {"active": true}
	var flight := FakeActiveUnlockFlight.new()
	var result: Dictionary = helper.open_next_choice(
		"smasher",
		FakeCatalog.new([[{"id": "unused"}]]),
		false,
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		{},
		state,
		flight,
		FakeChoiceOpening.new(),
		FakeOfferModifiers.new(),
		FakeChoiceFeedback.new(),
		helper.build_state_callbacks(state),
		3
	)
	_expect(bool(result.get("accepted", false)), "no-pending path should apply an unavailable state update")
	_expect(flight.reset_calls == 1, "open flow should clear active-unlock flight before opening")
	_expect(state.choice_flight_effect.is_empty(), "open flow should clear choice flight effect")
	_expect(not state.choice_active, "no-pending path should close the choice modal")
	_expect(state.current_choices.is_empty(), "no-pending path should clear stale choices")


func _verify_ready_path_generates_choices_and_runs_side_effects() -> void:
	var helper := RuntimePerkChoiceOpenFlow.new()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 1
	state.runtime_skill_levels = {"dash_acceleration": 2}
	state.feedback_timer = 0.25
	state.next_fusion_appeared = true
	var catalog := FakeCatalog.new([[{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]])
	var modifiers := FakeOfferModifiers.new()
	modifiers.item_bonus = 1
	var feedback := FakeChoiceFeedback.new()
	var perf := FakePerfLogger.new()
	var result: Dictionary = helper.open_next_choice(
		"smasher",
		catalog,
		true,
		FakeOwner.new(),
		FakeRegistry.new(),
		perf,
		{"source": "stage_clear"},
		state,
		FakeActiveUnlockFlight.new(),
		FakeChoiceOpening.new(),
		modifiers,
		feedback,
		helper.build_state_callbacks(state),
		3
	)
	_expect(bool(result.get("accepted", false)), "ready path should accept the ready state update")
	_expect(catalog.calls == 1, "ready path should query the catalog once")
	_expect(catalog.last_character_type == "smasher", "ready path should forward character type")
	_expect(catalog.last_exclude_instant, "ready path should forward exclude-instant flag")
	_expect(catalog.last_target_choice_count == 4, "ready path should include item bonus in target choice count")
	_expect(modifiers.slot_status_calls == 1, "ready path should build perk-slot status")
	_expect(modifiers.dowsing_calls == 1, "ready path should try Dowsing bonus marking")
	_expect(feedback.dowsing_calls == 1, "ready path should apply Dowsing feedback for bonus choices")
	_expect(state.choice_active, "ready path should activate the choice modal")
	_expect(state.selected_index == 1, "ready path should select center card for multiple choices")
	_expect(state.pause_cooldown_calls == 1, "ready path should pause skill cooldowns")
	_expect(state.build_particles_calls == 1, "ready path should rebuild choice particles")
	_expect(bool(_get_dict(state.current_choices[3]).get("is_dowsing_goggles_bonus", false)), "ready path should preserve the protected Dowsing bonus mark")
	_expect(state.training_injection_calls == 1, "ready path should run the training decision once")
	_expect(not state.training_received_dice_appeared, "training callback should receive the retired Dice lane as false")
	_expect(state.training_received_fusion_appeared, "training callback should receive the fusion appearance result")
	# 포화 판정이 신화 계층까지 보려면 registry 가 콜백까지 도달해야 한다.
	_expect(state.training_received_registry != null, "training callback should receive the registry for the final-consumer saturation probe")
	_expect(
		perf.labels == [
			"process.runtime_perk.open_next_choice.item_bonus",
			"process.runtime_perk.open_next_choice.catalog",
			"process.runtime_perk.open_next_choice.particles",
		],
		"ready path should emit expected perf labels"
	)


func _verify_runtime_state_facade_generates_choices_and_runs_side_effects() -> void:
	var helper := RuntimePerkChoiceOpenFlow.new()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 1
	state.runtime_skill_levels = {"dash_acceleration": 2}
	state.feedback_timer = 0.25
	var flight := FakeActiveUnlockFlight.new()
	var modifiers := FakeOfferModifiers.new()
	modifiers.item_bonus = 1
	var feedback := FakeChoiceFeedback.new()
	state._active_unlock_flight = flight
	state._choice_opening = FakeChoiceOpening.new()
	state._choice_offer_modifiers = modifiers
	state._choice_feedback = feedback
	var catalog := FakeCatalog.new([[{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]])
	var perf := FakePerfLogger.new()
	var result: Dictionary = helper.open_next_choice_from_runtime_state(
		state,
		"smasher",
		catalog,
		true,
		FakeOwner.new(),
		FakeRegistry.new(),
		perf,
		{"source": "runtime_state_facade"}
	)
	_expect(bool(result.get("accepted", false)), "runtime-state facade should accept the ready state update")
	_expect(flight.reset_calls == 1, "runtime-state facade should clear active-unlock flight")
	_expect(catalog.last_target_choice_count == 4, "runtime-state facade should apply default base count plus item bonus")
	_expect(modifiers.slot_status_calls == 1, "runtime-state facade should build perk-slot status")
	_expect(modifiers.dowsing_calls == 1, "runtime-state facade should try Dowsing bonus marking")
	_expect(feedback.dowsing_calls == 1, "runtime-state facade should apply Dowsing feedback")
	_expect(state.choice_active, "runtime-state facade should activate the choice modal")
	_expect(state.pause_cooldown_calls == 1, "runtime-state facade should pause skill cooldowns")
	_expect(state.build_particles_calls == 1, "runtime-state facade should rebuild choice particles")
	_expect(
		RuntimePerkChoiceOpenFlow.DEFAULT_BASE_PERK_CHOICE_COUNT == 3,
		"runtime-state facade default base choice count should match RuntimePerkState public wrapper policy"
	)


func _verify_empty_choice_result_reopens_with_preserved_context() -> void:
	var helper := RuntimePerkChoiceOpenFlow.new()
	var state := FakeRuntimeState.new()
	state.pending_skill_choices = 2
	var catalog := FakeCatalog.new([[], [{"id": "second"}]])
	helper.open_next_choice(
		"smasher",
		catalog,
		false,
		FakeOwner.new(),
		FakeRegistry.new(),
		null,
		{"source": "first_context"},
		state,
		FakeActiveUnlockFlight.new(),
		FakeChoiceOpening.new(),
		FakeOfferModifiers.new(),
		FakeChoiceFeedback.new(),
		helper.build_state_callbacks(state),
		3
	)
	_expect(catalog.calls == 2, "empty-choice path should recursively open the next pending choice")
	_expect(state.pending_skill_choices == 1, "empty-choice path should consume one pending choice before reopening")
	_expect(state.choice_active, "recursive open should activate the choice modal after a later non-empty batch")
	_expect(str(_get_dict(state.last_generated_context).get("source", "")) == "first_context", "recursive open should preserve choice context")
	_expect(str(_get_dict(state.current_choices[0]).get("id", "")) == "second", "recursive open should keep the later generated choices")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	var open_body: String = _function_body(state_source, "func open_next_choice(")
	var facade_body: String = _function_body(helper_source, "func open_next_choice_from_runtime_state(")
	var flow_body: String = _function_body(helper_source, "func open_next_choice(")
	_expect(state_source.find("RuntimePerkChoiceOpenFlow") >= 0, "state should preload choice open-flow helper")
	_expect(open_body.find("_choice_open_flow.open_next_choice_from_runtime_state") >= 0, "state open-next wrapper should delegate runtime-state assembly to open-flow helper")
	_expect(open_body.find("_active_unlock_flight") < 0, "state open-next wrapper should not pass active-unlock flight helper inline")
	_expect(open_body.find("_choice_opening") < 0, "state open-next wrapper should not pass choice-opening helper inline")
	_expect(open_body.find("_choice_offer_modifiers") < 0, "state open-next wrapper should not pass offer modifier helper inline")
	_expect(open_body.find("_choice_feedback") < 0, "state open-next wrapper should not pass feedback helper inline")
	_expect(open_body.find("build_state_callbacks(self)") < 0, "state open-next wrapper should not build callback map inline")
	_expect(open_body.find("BASE_PERK_CHOICE_COUNT") < 0, "state open-next wrapper should not pass base choice constants inline")
	_expect(helper_source.find("func open_next_choice_from_runtime_state(") >= 0, "open-flow helper should expose runtime-state facade")
	_expect(facade_body.find("_active_unlock_flight") >= 0, "open-flow facade should own active-unlock flight lookup")
	_expect(facade_body.find("_choice_opening") >= 0, "open-flow facade should own choice-opening lookup")
	_expect(facade_body.find("_choice_offer_modifiers") >= 0, "open-flow facade should own offer modifier lookup")
	_expect(facade_body.find("_choice_feedback") >= 0, "open-flow facade should own feedback lookup")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "open-flow facade should own callback-map assembly")
	_expect(facade_body.find("DEFAULT_BASE_PERK_CHOICE_COUNT") >= 0, "open-flow facade should own default base choice count")
	_expect(open_body.find("catalog.get_choices") < 0, "state open-next wrapper should not query catalog directly")
	_expect(open_body.find("build_target_choice_count") < 0, "state open-next wrapper should not calculate target choice count directly")
	_expect(open_body.find("build_dowsing_bonus_state_update") < 0, "state open-next wrapper should not apply Dowsing bonus directly")
	_expect(open_body.find("build_ready_state_update") < 0, "state open-next wrapper should not build ready state directly")
	_expect(open_body.find("_build_particles") < 0, "state open-next wrapper should not rebuild particles directly")
	_expect(helper_source.find("catalog.get_choices") >= 0, "open-flow helper should query catalog choices")
	_expect(helper_source.find("build_target_choice_count") >= 0, "open-flow helper should consume target choice-count helper")
	_expect(helper_source.find("build_dowsing_bonus_state_update") >= 0, "open-flow helper should consume Dowsing bonus helper")
	_expect(helper_source.find("build_ready_state_update") >= 0, "open-flow helper should build ready state")
	_expect(helper_source.find("CALLBACK_BUILD_PARTICLES") >= 0, "open-flow helper should trigger particle rebuild through callback")
	var dowsing_pos := flow_body.find("build_dowsing_bonus_state_update")
	var fusion_pos := flow_body.find("CALLBACK_INJECT_PERK_FUSION_OFFER", dowsing_pos + 1)
	var training_pos := flow_body.find("CALLBACK_INJECT_PHYSIQUE_TRAINING_OFFER", fusion_pos + 1)
	var ready_pos := flow_body.find("build_ready_state_update", training_pos + 1)
	_expect(dowsing_pos >= 0 and dowsing_pos < fusion_pos, "Dowsing must stamp its protected base card before fusion replacement")
	_expect(fusion_pos < training_pos, "auxiliary ordering should stay fusion -> training after Dice retirement")
	_expect(flow_body.find("CALLBACK_INJECT_MYSTIC_DICE_OFFER") < 0, "open flow must not invoke the retired Dice perk lane")
	_expect(training_pos < ready_pos, "all auxiliary lanes must finish before ready-state card counts")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var pending_skill_choices := 0
	var choice_active := false
	var current_choices: Array = []
	var current_choice_context: Dictionary = {}
	var current_perk_slot_status: Dictionary = {}
	var selected_index := 0
	var gamepad_choice_horizontal_latch := 0
	var animation_time := 0.0
	var feedback_text := ""
	var feedback_timer := 0.0
	var choice_flight_effect: Dictionary = {}
	var last_generated_context: Dictionary = {}
	var _active_unlock_flight: Object = null
	var _choice_opening: Object = null
	var _choice_offer_modifiers: Object = null
	var _choice_feedback: Object = null
	var pause_cooldown_calls := 0
	var build_particles_calls := 0
	var next_fusion_appeared := false
	var next_dice_appeared := false
	var training_injection_calls := 0
	var training_received_dice_appeared := false
	var training_received_fusion_appeared := false
	var training_received_registry: Object = null

	func _apply_choice_opening_update(update: Dictionary) -> Dictionary:
		if not bool(update.get("accepted", false)):
			return {"accepted": false}
		if update.has("pending_skill_choices"):
			pending_skill_choices = int(update.get("pending_skill_choices", pending_skill_choices))
		if update.has("choice_active"):
			choice_active = bool(update.get("choice_active", choice_active))
		if update.has("current_choices"):
			current_choices = _get_array(update.get("current_choices", [])).duplicate(true)
		if update.has("current_choice_context"):
			current_choice_context = _get_dict(update.get("current_choice_context", {})).duplicate(true)
			last_generated_context = current_choice_context.duplicate(true)
		if update.has("current_perk_slot_status"):
			current_perk_slot_status = _get_dict(update.get("current_perk_slot_status", {})).duplicate(true)
		if update.has("selected_index"):
			selected_index = int(update.get("selected_index", selected_index))
		if update.has("gamepad_choice_horizontal_latch"):
			gamepad_choice_horizontal_latch = int(update.get("gamepad_choice_horizontal_latch", gamepad_choice_horizontal_latch))
		if update.has("animation_time"):
			animation_time = float(update.get("animation_time", animation_time))
		if bool(update.get("clear_current_choices", false)):
			current_choices.clear()
		if bool(update.get("clear_current_choice_context", false)):
			current_choice_context.clear()
		if bool(update.get("clear_current_perk_slot_status", false)):
			current_perk_slot_status.clear()
		return {
			"accepted": true,
			"open_next_choice": bool(update.get("open_next_choice", false)),
			"pause_skill_cooldowns": bool(update.get("pause_skill_cooldowns", false)),
			"build_particles": bool(update.get("build_particles", false)),
		}

	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_cooldown_calls += 1

	func _build_particles() -> void:
		build_particles_calls += 1

	func _try_inject_perk_fusion_offer(_catalog: Object) -> Dictionary:
		return {"appeared": next_fusion_appeared}

	func _try_inject_mystic_dice_offer() -> Dictionary:
		return {"appeared": next_dice_appeared}

	# 실 호출부는 롤 시드 3개 + registry 까지 6인자로 부른다(포화 판정이 최종 소비자를
	# 호출해야 하므로 registry 필수). 인자수를 좁혀두면 그 분기가 도는 프레임에
	# `Invalid call ... Expected 2 arguments` 로 죽는다.
	func _try_inject_physique_training_offer(
		dice_appeared: bool,
		fusion_appeared: bool,
		_appearance_roll_unit: float = -1.0,
		_selection_roll_unit: float = -1.0,
		_replacement_roll_unit: float = -1.0,
		registry: Object = null
	) -> Dictionary:
		training_injection_calls += 1
		training_received_dice_appeared = dice_appeared
		training_received_fusion_appeared = fusion_appeared
		training_received_registry = registry
		return {"rolled": false}

	func _get_array(value: Variant) -> Array:
		if value is Array:
			return value
		return []

	func _get_dict(value: Variant) -> Dictionary:
		if value is Dictionary:
			return value
		return {}


class FakeChoiceOpening:
	extends RefCounted

	func build_unavailable_state_update(clear_current_choices: bool = false) -> Dictionary:
		return {
			"accepted": true,
			"choice_active": false,
			"clear_current_choices": clear_current_choices,
			"clear_current_choice_context": true,
			"clear_current_perk_slot_status": true,
		}

	func build_generated_choices_state_update(choice_context: Dictionary, choices: Array, perk_slot_status: Dictionary) -> Dictionary:
		return {
			"accepted": true,
			"current_choice_context": choice_context.duplicate(true),
			"current_choices": choices.duplicate(true),
			"current_perk_slot_status": perk_slot_status.duplicate(true),
		}

	func build_empty_choices_state_update(current_pending_skill_choices: int) -> Dictionary:
		var next_pending: int = max(0, current_pending_skill_choices - 1)
		return {
			"accepted": true,
			"pending_skill_choices": next_pending,
			"choice_active": next_pending > 0,
			"open_next_choice": next_pending > 0,
		}

	func build_ready_state_update(choice_count: int) -> Dictionary:
		return {
			"accepted": choice_count > 0,
			"choice_active": true,
			"selected_index": min(1, choice_count - 1),
			"gamepad_choice_horizontal_latch": 0,
			"animation_time": 0.0,
			"pause_skill_cooldowns": true,
			"build_particles": true,
		}


class FakeOfferModifiers:
	extends RefCounted

	var item_bonus := 0
	var slot_status_calls := 0
	var dowsing_calls := 0

	func get_item_perk_choice_count_bonus(_owner: Object, _registry: Object, _get_instance: Callable) -> int:
		return item_bonus

	func build_target_choice_count(base_choice_count: int, item_bonus_choice_count: int) -> int:
		return max(0, base_choice_count + max(0, item_bonus_choice_count))

	func build_perk_slot_status(_catalog: Object, _runtime_skill_levels: Dictionary, _registry: Object) -> Dictionary:
		slot_status_calls += 1
		return {"count": 2}

	func build_dowsing_bonus_state_update(choices: Array, item_bonus_choice_count: int, target_choice_count: int) -> Dictionary:
		dowsing_calls += 1
		if item_bonus_choice_count <= 0:
			return {"accepted": false}
		var next_choices: Array = choices.duplicate(true)
		var bonus_index: int = clamp(target_choice_count - 1, 0, max(0, next_choices.size() - 1))
		var marked: Dictionary = _get_dict(next_choices[bonus_index]).duplicate(true)
		marked["is_dowsing_goggles_bonus"] = true
		marked["offer_lane"] = "dowsing_bonus"
		marked["offer_protected"] = true
		next_choices[bonus_index] = marked
		return {
			"accepted": true,
			"current_choices": next_choices,
		}

	func _get_dict(value: Variant) -> Dictionary:
		if value is Dictionary:
			return value
		return {}


class FakeChoiceFeedback:
	extends RefCounted

	var dowsing_calls := 0

	func apply_dowsing_goggles_bonus_feedback_state_update(runtime_state: Object, current_timer: float) -> Dictionary:
		dowsing_calls += 1
		runtime_state.feedback_text = "dowsing"
		runtime_state.feedback_timer = max(current_timer, 1.25)
		return {"accepted": true}


class FakeActiveUnlockFlight:
	extends RefCounted

	var reset_calls := 0

	func reset(effect: Dictionary) -> void:
		reset_calls += 1
		effect.clear()


class FakeCatalog:
	extends RefCounted

	var batches: Array = []
	var calls := 0
	var last_character_type := ""
	var last_exclude_instant := false
	var last_target_choice_count := 0

	func _init(choice_batches: Array) -> void:
		batches = choice_batches.duplicate(true)

	func get_choices(
		character_type: String,
		_runtime_skill_levels: Dictionary,
		exclude_instant: bool,
		target_choice_count: int,
		_owner: Object,
		_registry: Object
	) -> Array:
		calls += 1
		last_character_type = character_type
		last_exclude_instant = exclude_instant
		last_target_choice_count = target_choice_count
		var index: int = min(calls - 1, max(0, batches.size() - 1))
		return _get_array(batches[index]).duplicate(true)

	func _get_array(value: Variant) -> Array:
		if value is Array:
			return value
		return []


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []
	var next_sample_id := 0

	func begin_sample() -> int:
		next_sample_id += 1
		return next_sample_id

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null
