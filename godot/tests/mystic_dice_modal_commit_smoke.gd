extends SceneTree

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceOfferPlanner := preload("res://scripts/characters/mystic_dice_offer_planner.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class RegistryStub:
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


class OwnerSyncProbe:
	extends RefCounted
	var effect_sync_calls := 0
	var mythic_refresh_calls := 0
	var final_sync_calls := 0

	func sync_owner_effects_from_runtime_state(_runtime_state: Object, _owner: Object, _registry: Object, _perf_logger: Object = null) -> void:
		effect_sync_calls += 1

	func refresh_mythic_runtime_perk_consumers_from_runtime_state(_runtime_state: Object, _owner: Object, _registry: Object) -> void:
		mythic_refresh_calls += 1

	func sync_owner_from_runtime_state(_runtime_state: Object, _owner: Object) -> void:
		final_sync_calls += 1


func _init() -> void:
	_verify_d0_intercept_reroll_discard_pending_queue_and_idempotency()
	_verify_last_choice_cancel_noop_rt_latch_and_single_close_ramp()
	_verify_selection_gate_blocks_early_dice_entry()
	_verify_non_rt_entry_first_rt_press_confirms()
	_verify_real_router_rt_entry_latch_roundtrip()
	_verify_source_contract()

	if _failures.is_empty():
		print("mystic_dice_modal_commit_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_d0_intercept_reroll_discard_pending_queue_and_idempotency() -> void:
	var fixture := _build_fixture(2, _units(0.0))
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var cooldown: Object = fixture["cooldown"]
	var resume_safety: Object = fixture["resume_safety"]
	var absorption: Object = fixture["absorption"]
	var owner_sync: Object = fixture["owner_sync"]
	var frozen_choices: Array = state.current_choices.duplicate(true)

	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(state.is_mystic_dice_modal_active(), "D0 Mystic Dice click should enter D1 instead of standard apply_choice")
	_expect(state.choice_active and state.pending_skill_choices == 2, "D0->D1 must keep raw choice_active and pending count")
	_expect(state.current_choices == frozen_choices, "D1 should keep the frozen origin offer")
	_expect(state.get_mystic_dice_snapshot().get("use_count", -1) == 0, "D0/D1 must not consume a use")
	_expect(not state.runtime_skill_levels.has("mystic_dice"), "modal-only card must not enter runtime perk levels")

	var rolling_phase := str(state.get_mystic_dice_modal_snapshot().get("phase", ""))
	_expect(state.handle_input(_escape_key(), null, registry, Vector2(760.0, 750.0)), "D1 ESC should be consumed")
	_expect(str(state.get_mystic_dice_modal_snapshot().get("phase", "")) == rolling_phase, "D1 ESC must be a no-op")
	state._mystic_dice_modal_flow.update(2.0)
	state._mystic_dice_modal_flow.set_selected_action(MysticDiceModalFlow.ACTION_REROLL)
	var reroll_result: Dictionary = state._activate_mystic_dice_selected_action(null, registry, _units(1.0))
	_expect(bool(reroll_result.get("rerolled", false)), "D2 reroll should re-enter D1")
	_expect(state.get_mystic_dice_snapshot().get("use_count", -1) == 0, "reroll must not commit or consume a run use")
	state._mystic_dice_modal_flow.update(2.0)
	var rolled_raw: Dictionary = (state.get_mystic_dice_modal_snapshot().get("current_roll", {}) as Dictionary).get("raw", {}) as Dictionary
	_expect(int(rolled_raw.get("player_speed", 0)) == 3 and int(rolled_raw.get("dash_cooldown", 0)) == -3, "reroll should fully replace the discarded first result")

	var finish_result: Dictionary = state._activate_mystic_dice_selected_action(null, registry)
	_expect(bool(finish_result.get("accepted", false)), "D2 confirm should atomically commit and finish")
	var paddle_effect: Dictionary = state.get_mystic_dice_paddle_effect_snapshot()
	_expect(bool(paddle_effect.get("pending_start", false)) and not bool(paddle_effect.get("active", true)), "accepted finish should defer the paddle aura until modal-blocked physics resumes")
	_expect(int(state.get_mystic_dice_snapshot().get("use_count", 0)) == 1, "D3 should commit exactly one use")
	_expect(state.get_mystic_dice_raw("player_speed") == 3 and state.get_mystic_dice_raw("dash_cooldown") == -3, "D3 should commit only the final reroll")
	_expect(state.pending_skill_choices == 1 and state.selected_choice_sequence == 1, "D3 should consume exactly one pending choice and sequence")
	_expect(state.choice_active, "remaining pending choice should synchronously open the next guarded modal")
	_expect(str(state.last_selected_id) == "mystic_dice" and str(state.last_selected_choice.get("type", "")) == "mystic_dice", "finish should publish the canonical selected-choice identity")
	_expect(int(state.last_selected_choice.get("mystic_dice_revision", 0)) == 1, "finish snapshot should carry the committed revision guard")
	_expect(owner_sync.effect_sync_calls == 1 and owner_sync.mythic_refresh_calls == 1, "commit should immediately refresh ordinary and mythic stat consumers once")
	_expect(owner_sync.final_sync_calls == 1, "standard finish should perform its bookkeeping owner sync once")
	_expect(cooldown.resume_calls == 0 and resume_safety.arm_calls == 0 and absorption.start_calls == 0, "pending next modal must not run final close/ramp callbacks")

	var pending_before := int(state.pending_skill_choices)
	var sequence_before := int(state.selected_choice_sequence)
	var choices_before: Array = state.current_choices.duplicate(true)
	var duplicate: Dictionary = state._finish_successful_choice(
		"mystic_dice",
		null,
		registry,
		null,
		state.last_selected_choice.duplicate(true)
	)
	_expect(bool(duplicate.get("already_finished", false)), "revision guard should reject a repeated D3 finish")
	_expect(state.pending_skill_choices == pending_before and state.selected_choice_sequence == sequence_before, "duplicate finish must not consume pending/sequence twice")
	_expect(state.current_choices == choices_before, "duplicate finish must not replace the already-open next modal")


func _verify_last_choice_cancel_noop_rt_latch_and_single_close_ramp() -> void:
	var fixture := _build_fixture(1, _units(0.5))
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var cooldown: Object = fixture["cooldown"]
	var resume_safety: Object = fixture["resume_safety"]
	var absorption: Object = fixture["absorption"]
	# RT 트리거로 진입한 케이스: D0에서 눌려 있던 RT가 모달 첫 프레임으로
	# 이월되는 시나리오 — 실 게임패드 confirm 경로처럼 note 채널로 입력원을
	# 알린 뒤 공용 3인자 계약 그대로 호출한다.
	state.note_choice_confirm_input_source(true)
	state.choose_selected(null, registry, Vector2(760.0, 750.0))

	state._handle_mystic_dice_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(state.get_mystic_dice_snapshot().get("use_count", -1) == 0, "held RT inherited from D0 must not cascade")
	state._handle_mystic_dice_modal_input(_rt_axis(0.10), null, registry, Vector2(760.0, 750.0))
	state._mystic_dice_modal_flow.update(2.0)
	_expect(state.handle_input(_escape_key(), null, registry, Vector2(760.0, 750.0)), "D2 ESC should be consumed")
	_expect(str(state.get_mystic_dice_modal_snapshot().get("phase", "")) == MysticDiceModalFlow.PHASE_RESULT, "D2 ESC must not cancel the committed-intent flow")
	_expect(state.choice_active and state.pending_skill_choices == 1, "D2 no-cancel must retain the raw choice session")

	state._handle_mystic_dice_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(not state.choice_active, "released RT edge should confirm and close the last choice")
	_expect(state.pending_skill_choices == 0 and state.selected_choice_sequence == 1, "last D3 should consume and sequence once")
	_expect(cooldown.resume_calls == 1, "last D3 should resume cooldowns exactly once")
	_expect(resume_safety.arm_calls == 1, "last D3 should arm the resume ramp exactly once")
	_expect(absorption.start_calls == 1, "last D3 should start starpoint absorption exactly once")
	var duplicate: Dictionary = state._finish_successful_choice("mystic_dice", null, registry, null, state.last_selected_choice.duplicate(true))
	_expect(bool(duplicate.get("already_finished", false)), "last-choice duplicate should still be guarded")
	_expect(cooldown.resume_calls == 1 and resume_safety.arm_calls == 1 and absorption.start_calls == 1, "duplicate D3 must not repeat close/ramp callbacks")


# 실 라우터 관통(코덱스 v3 P2): 실제 RT 축 InputEvent를 state.handle_
# input()에 넣어 D0 RT 진입 → note 채널 → 래치 무장 → 이월 RT 무확정 →
# release → 재press 확정까지 전 구간을 프로덕션 배선으로 봉인한다(직접
# note 호출·모달 헬퍼 직접 호출로는 라우터의 note 배선 누락이 GREEN으로
# 숨는다).
func _verify_real_router_rt_entry_latch_roundtrip() -> void:
	var fixture := _build_fixture(1, _units(0.5))
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var cooldown: Object = fixture["cooldown"]
	var view_size := Vector2(760.0, 750.0)
	# D0: RT press가 실 라우터를 타고 confirm → note(entered_via_rt=true)
	# → choose_selected → 주사위 모달 진입.
	_expect(state.handle_input(_rt_axis(0.90), null, registry, view_size), "real router should consume the D0 RT press")
	_expect(state.is_mystic_dice_modal_active(), "real-router RT entry should open the dice modal")
	state._mystic_dice_modal_flow.update(2.0)
	# 이월 RT: 같은 물리 press가 계속 눌린 채 흔들리는 모션 이벤트 —
	# 래치가 무장돼 있어야 하고 확정으로 캐스케이드하면 안 된다.
	_expect(state.handle_input(_rt_axis(0.85), null, registry, view_size), "carried RT motion should be consumed by the dice modal")
	_expect(state.is_mystic_dice_modal_active() and state.choice_active, "carried-over RT must not cascade into a D3 confirm")
	_expect(int(state.get_mystic_dice_snapshot().get("use_count", -1)) == 0, "carried-over RT must not commit a use")
	# release → 재press: 이제 정상 확정.
	_expect(state.handle_input(_rt_axis(0.05), null, registry, view_size), "RT release should be consumed and clear the latch")
	_expect(state.is_mystic_dice_modal_active(), "RT release alone must not confirm")
	_expect(state.handle_input(_rt_axis(0.90), null, registry, view_size), "fresh RT press should be consumed")
	_expect(not state.choice_active, "a fresh RT press after release should confirm and close the last choice")
	_expect(int(state.get_mystic_dice_snapshot().get("use_count", -1)) == 1, "the round trip should commit exactly one use")
	_expect(cooldown.resume_calls == 1, "the confirmed last choice should resume cooldowns exactly once")


# 공용 선택 가능 게이트 음성 레그: 카드 등장 애니메이션(animation_time <
# 0.24) 중의 D0 클릭은 주사위 모달을 열지 못하고 raw 세션을 보존한다.
func _verify_selection_gate_blocks_early_dice_entry() -> void:
	var fixture := _build_fixture(1, _units(0.5))
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	state.animation_time = 0.1
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(not state.is_mystic_dice_modal_active(), "card-intro clicks must not open the dice modal before the selectable gate")
	_expect(state.choice_active and state.pending_skill_choices == 1, "gate-blocked early click must keep the raw choice session")
	state.animation_time = 10.0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(state.is_mystic_dice_modal_active(), "the same click after the gate opens should enter the dice modal")


# 입력원 매트릭스: 키보드/마우스/A 진입은 RT 래치를 무장하지 않는다 —
# 모달 안의 첫 RT press가 즉시 확정이어야 한다(첫 입력 삼킴 금지).
func _verify_non_rt_entry_first_rt_press_confirms() -> void:
	var fixture := _build_fixture(1, _units(0.5))
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var cooldown: Object = fixture["cooldown"]
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	_expect(state.is_mystic_dice_modal_active(), "non-RT entry should open the dice modal")
	state._mystic_dice_modal_flow.update(2.0)
	state._handle_mystic_dice_modal_input(_rt_axis(0.60), null, registry, Vector2(760.0, 750.0))
	_expect(not state.choice_active, "non-RT entry must not swallow the first in-modal RT press")
	_expect(cooldown.resume_calls == 1, "first-RT confirm should close and resume exactly once")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var choose_index := state_source.find("func choose_selected")
	var gate_index := state_source.find("if is_selectable():", choose_index)
	var dice_index := state_source.find("_begin_mystic_dice_modal(selected_choice, registry, [], entered_via_rt)", choose_index)
	var standard_index := state_source.find("_choice_confirm_flow.choose_selected_from_runtime_state", choose_index)
	_expect(gate_index >= 0 and dice_index > gate_index, "the shared selectable gate must run before the D0 dice interception")
	_expect(dice_index >= 0 and standard_index > dice_index, "D0 dice interception should precede the standard choice apply path")
	_expect(state_source.find("if is_mystic_dice_modal_active():\n\t\t_mystic_dice_modal_flow.update(delta)") >= 0, "runtime update should advance the dice modal")
	_expect(state_source.find("if is_mystic_dice_modal_active():\n\t\treturn _handle_mystic_dice_modal_input") >= 0, "runtime input should prioritize the dice modal")


func _build_fixture(pending_count: int, first_roll_units: Array) -> Dictionary:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	var cooldown := CooldownProbe.new()
	var resume_safety := ResumeSafetyProbe.new()
	var absorption := AbsorptionProbe.new()
	var owner_sync := OwnerSyncProbe.new()
	state._skill_cooldown_pause = cooldown
	state._resume_safety = resume_safety
	state._starpoint_absorption = absorption
	state._owner_sync_flow = owner_sync
	state.pending_skill_choices = pending_count
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [MysticDiceOfferPlanner.build_card(), _gold_card()]
	state.selected_index = 0
	# Start uses a forced pure-roll payload so this smoke never depends on RNG.
	state._begin_mystic_dice_modal(state.current_choices[0], registry, first_roll_units)
	# Return to the exact D0 state, then enter through choose_selected to prove interception.
	state._mystic_dice_modal_flow.reset()
	state._mystic_dice_modal_input.reset()
	return {
		"state": state,
		"catalog": catalog,
		"registry": registry,
		"cooldown": cooldown,
		"resume_safety": resume_safety,
		"absorption": absorption,
		"owner_sync": owner_sync,
	}


func _gold_card() -> Dictionary:
	return {"id": "convert_to_gold", "offer_lane": "gold", "offer_protected": true}


func _units(value: float) -> Array:
	var units: Array = []
	for _index: int in range(7):
		units.append(value)
	return units


func _escape_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	return event


func _rt_axis(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
