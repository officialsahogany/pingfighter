extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

var _state: Object = null
var _roller: Object = null
var _offer_planner: Object = null
var _paddle_effect: Object = null
var _paddle_effect_pending := false
var _modal_flow: Object = null
var _modal_input: Object = null
var _modal_origin := ""


func get_state() -> Object:
	if _state == null:
		_state = load("res://scripts/characters/mystic_dice_state.gd").new()
	return _state


func commit_roll(raw_roll: Dictionary) -> Dictionary:
	return get_state().commit_roll(raw_roll)


func get_raw(stat_key: String) -> int:
	return int(get_state().get_raw(stat_key))


func get_multiplier(stat_key: String) -> float:
	return float(get_state().get_multiplier(stat_key))


func get_revision() -> int:
	return int(get_state().get_revision())


func get_snapshot() -> Dictionary:
	return get_state().get_snapshot()


func get_remaining_uses() -> int:
	return int(get_state().get_remaining_uses())


func roll(roll_units: Array = []) -> Dictionary:
	var roller: Object = _get_roller()
	var units: Array = roll_units
	if units.is_empty():
		units = []
		for _index: int in range(roller.get_stat_keys().size()):
			units.append(randf())
	return roller.roll(units)


func can_plan_offer(choices: Array, offer_source: String, remaining_uses: int) -> bool:
	return bool(get_offer_planner().can_roll(choices, offer_source, remaining_uses))


func plan_offer(choices: Array, offer_source: String, remaining_uses: int, roll_unit: float) -> Dictionary:
	var planner: Object = get_offer_planner()
	if not bool(planner.can_roll(choices, offer_source, remaining_uses)):
		return {"rolled": false}
	return planner.plan_offer(choices, offer_source, remaining_uses, roll_unit)


func get_offer_planner() -> Object:
	if _offer_planner == null:
		_offer_planner = load("res://scripts/characters/mystic_dice_offer_planner.gd").new()
	return _offer_planner


func set_offer_planner(value: Object) -> void:
	_offer_planner = value


func peek_modal_flow() -> Object:
	return _modal_flow


func get_modal_flow() -> Object:
	if _modal_flow == null:
		_modal_flow = load("res://scripts/characters/mystic_dice_modal_flow.gd").new()
	return _modal_flow


func set_modal_flow(value: Object) -> void:
	_modal_flow = value


func peek_modal_input() -> Object:
	return _modal_input


func get_modal_input() -> Object:
	if _modal_input == null:
		_modal_input = load("res://scripts/characters/mystic_dice_modal_input.gd").new()
	return _modal_input


func set_modal_input(value: Object) -> void:
	_modal_input = value


func is_modal_active() -> bool:
	return _modal_flow != null and bool(_modal_flow.is_active())


func get_modal_snapshot() -> Dictionary:
	if _modal_flow == null:
		return {}
	return _modal_flow.get_snapshot()


func begin_modal_from_runtime_state(
	runtime_state: Object,
	selected_choice: Dictionary,
	registry: Object,
	roll_units: Array = [],
	entered_via_rt: bool = false
) -> bool:
	if runtime_state == null:
		return false
	var roll_payload: Dictionary = roll(roll_units)
	if not bool(roll_payload.get("accepted", false)):
		return false
	var flow: Object = get_modal_flow()
	var origin_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
	if not bool(flow.start(selected_choice, origin_choices.duplicate(true), roll_payload)):
		return false
	_modal_origin = "perk_choice"
	var modal_input: Object = get_modal_input()
	modal_input.reset()
	if entered_via_rt:
		modal_input.suppress_confirm_until_release()
	if runtime_state.has_method("_play_perk_select_audio"):
		runtime_state.call("_play_perk_select_audio", registry)
	return true


func begin_active_item_modal_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	roll_units: Array = []
) -> bool:
	if runtime_state == null or owner == null or is_modal_active():
		return false
	# An item cannot open over a Mugong/fusion/Training choice. Returning false
	# leaves the consumable in its slot and does not start its cooldown.
	if runtime_state.has_method("is_choice_active") and bool(runtime_state.is_choice_active()):
		return false
	if (
		runtime_state.has_method("is_angel_blessing_modal_active")
		and bool(runtime_state.is_angel_blessing_modal_active())
	):
		return false
	var roll_payload: Dictionary = roll(roll_units)
	if not bool(roll_payload.get("accepted", false)):
		return false
	var item_card := {
		"id": "mystic_dice",
		"type": "active_item",
		"is_mystic_dice": true,
		"source": "active_item",
	}
	var flow: Object = get_modal_flow()
	if not bool(flow.start(item_card, [], roll_payload)):
		return false
	_modal_origin = "active_item"
	get_modal_input().reset()
	_pause_gameplay_clocks_for_item_modal(runtime_state, owner, registry)
	return true


# 퍽 선택 모달·천사의 축복 모달과 동일한 개폐 계약을 아이템 경로에도 건다.
# 이 모달도 is_choice_active OR 로 물리를 막지만, 스킬 쿨다운과 액티브 아이템
# 쿨다운의 기준선은 프레임이 아니라 벽시계(Time.get_ticks_msec)다 — 멈추지
# 않으면 모달이 열려 있는 실시간(굴림 연출 + 리롤 2회 + 7행 판독)만큼 다른
# 아이템·스킬 쿨다운이 공짜로 흐른다(기본 액티브 쿨다운 7000ms).
func _pause_gameplay_clocks_for_item_modal(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	if runtime_state.has_method("_pause_skill_cooldowns_for_choice"):
		runtime_state.call("_pause_skill_cooldowns_for_choice", owner, registry)


# 아이템은 퍽 모달과 달리 랠리 임의 프레임에 사용할 수 있다. 커밋 직후 공이
# 원래 속도로 즉시 재개되면 회피 불가 실점이 되므로, 형제 모달과 같은 리줌
# 안전장치(프리즈 10프레임 + 60프레임 속도 복원 + 프리즈 중 실점 차단)를
# 무장한다. pause 헬퍼는 owner/registry 를 자기 안에 보관하므로 resume 은
# 인자를 받지 않고, 아직 무장되지 않았으면 양쪽 다 no-op 이다.
func _resume_gameplay_clocks_after_item_modal(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	if runtime_state.has_method("_resume_skill_cooldowns_for_choice"):
		runtime_state.call("_resume_skill_cooldowns_for_choice")
	if runtime_state.has_method("_try_arm_resume_safety"):
		runtime_state.call("_try_arm_resume_safety", owner, registry)


func handle_modal_input_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	var resolution: Dictionary = get_modal_input().resolve(event, get_modal_snapshot(), view_size)
	var flow: Object = get_modal_flow()
	if resolution.has("move"):
		flow.move_selection(int(resolution.get("move", 0)))
	if resolution.has("selected_action") and int(resolution.get("selected_action", -1)) >= 0:
		flow.set_selected_action(int(resolution.get("selected_action", -1)))
	if bool(resolution.get("activate", false)):
		activate_selected_action_from_runtime_state(runtime_state, owner, registry)
	return bool(resolution.get("consumed", true))


func activate_selected_action_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	reroll_units: Array = []
) -> Dictionary:
	var flow: Object = get_modal_flow()
	var request: Dictionary = flow.request_selected_action()
	if bool(request.get("reroll_requested", false)):
		var payload: Dictionary = roll(reroll_units)
		if bool(flow.begin_reroll(payload)):
			return {"rerolled": true}
		return {"rerolled": false}
	if bool(request.get("commit_requested", false)):
		return finish_modal_from_runtime_state(runtime_state, owner, registry, request)
	return request


func finish_modal_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	request: Dictionary
) -> Dictionary:
	if runtime_state == null:
		_reject_modal_commit_request()
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	var owner_sync_flow: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_sync_flow")
	if (
		owner_sync_flow == null
		or not owner_sync_flow.has_method("sync_owner_effects_from_runtime_state")
		or not owner_sync_flow.has_method("refresh_mythic_runtime_perk_consumers_from_runtime_state")
	):
		_reject_modal_commit_request()
		return {"accepted": false, "blocked_reason": "missing_owner_sync_flow"}
	if _modal_origin != "active_item" and not runtime_state.has_method("_finish_successful_choice"):
		_reject_modal_commit_request()
		return {"accepted": false, "blocked_reason": "missing_choice_finish"}
	var finish_result: Dictionary = commit_roll(request.get("raw", {}) as Dictionary)
	if not bool(finish_result.get("accepted", false)):
		_reject_modal_commit_request()
		return finish_result
	owner_sync_flow.sync_owner_effects_from_runtime_state(runtime_state, owner, registry)
	owner_sync_flow.refresh_mythic_runtime_perk_consumers_from_runtime_state(runtime_state, owner, registry)
	queue_paddle_effect()
	var committed_choice: Dictionary = {
		"id": "mystic_dice",
		"type": "active_item" if _modal_origin == "active_item" else "mystic_dice",
		"mystic_dice_revision": get_revision(),
	}
	get_modal_flow().mark_committed(finish_result, committed_choice)
	if _modal_origin == "active_item":
		reset_modal()
		_resume_gameplay_clocks_after_item_modal(runtime_state, owner, registry)
		var item_result: Dictionary = finish_result.duplicate(true)
		item_result["source"] = "active_item"
		return item_result
	var finish: Dictionary = {}
	var finish_value: Variant = runtime_state.call(
		"_finish_successful_choice",
		"mystic_dice",
		owner,
		registry,
		null,
		committed_choice
	)
	if finish_value is Dictionary:
		finish = finish_value
	reset_modal()
	var merged: Dictionary = finish_result.duplicate(true)
	merged["finish"] = finish
	return merged


func reset_modal() -> void:
	if _modal_flow != null:
		_modal_flow.reset()
	if _modal_input != null:
		_modal_input.reset()
	_modal_origin = ""


func _reject_modal_commit_request() -> void:
	if _modal_flow != null:
		_modal_flow.reject_commit_request()


func queue_paddle_effect() -> void:
	_paddle_effect_pending = true


func set_paddle_effect_pending(value: bool) -> void:
	_paddle_effect_pending = value


func is_paddle_effect_pending() -> bool:
	return _paddle_effect_pending


func start_paddle_effect() -> Dictionary:
	_paddle_effect_pending = false
	return _get_paddle_effect().start()


func bind_paddle_fx_host(host: Node) -> void:
	_get_paddle_effect().bind_host(host)


func get_paddle_effect_snapshot() -> Dictionary:
	var snapshot: Dictionary = _get_paddle_effect().get_snapshot()
	snapshot["pending_start"] = _paddle_effect_pending
	return snapshot


func get_paddle_fx_host() -> Node:
	if _paddle_effect == null:
		return null
	return _paddle_effect.get_bound_host()


func update_paddle_effect(delta: float) -> bool:
	if _paddle_effect_pending:
		start_paddle_effect()
		return true
	if _paddle_effect == null:
		return false
	return bool(_paddle_effect.update(delta))


func clear_paddle_effect() -> void:
	_paddle_effect_pending = false
	if _paddle_effect != null:
		_paddle_effect.reset()


func reset_state() -> void:
	if _state != null:
		_state.reset()


func _get_roller() -> Object:
	if _roller == null:
		_roller = load("res://scripts/characters/mystic_dice_roller.gd").new()
	return _roller


func _get_paddle_effect() -> Object:
	if _paddle_effect == null:
		_paddle_effect = load("res://scripts/characters/mystic_dice_paddle_effect.gd").new()
	return _paddle_effect
