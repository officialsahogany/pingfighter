extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerStartCardOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
)

var _offer_builder: Object = TowerStartCardOfferBuilder.new()
var _owner: Object = null
var _registry: Object = null
var _runtime_state: Object = null
var _active := false
var _completed := false
var _skipped := false
var _elapsed_sec := 0.0
var _absorb_elapsed_sec := -1.0
var _picks_remaining := 0
var _card_choices: Array[Dictionary] = []
var _selection_result: Dictionary = {}
var _cold_build_msec := 0.0


func begin(owner: Object, registry: Object) -> bool:
	tear_down()
	_owner = owner
	_registry = registry
	_runtime_state = _get_registry_instance(registry, "runtime_perk_state")
	var flow_owner := _get_registry_instance(registry, "tower_ascent_flow_owner")
	var run_id := ""
	if flow_owner != null and flow_owner.has_method("get_run_id"):
		run_id = str(flow_owner.call("get_run_id"))
	var started_usec := Time.get_ticks_usec()
	var offer: Dictionary = _offer_builder.build_offer(run_id, owner, registry)
	_cold_build_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	if not bool(offer.get("accepted", false)):
		_completed = true
		_skipped = str(offer.get("reason", "")) == "start_card_skipped"
		_selection_result = {
			"accepted": false,
			"reason": str(offer.get("reason", "start_card_skipped")),
			"skipped": _skipped,
		}
		return false
	var choices_value: Variant = offer.get("choices", [])
	if not (choices_value is Array):
		_completed = true
		_skipped = true
		_selection_result = {
			"accepted": false,
			"reason": "invalid_start_card_offer",
			"skipped": true,
		}
		return false
	for value in choices_value as Array:
		if value is Dictionary:
			_card_choices.append((value as Dictionary).duplicate(true))
	if _card_choices.size() != TowerAscentTuning.TEMP_START_CARD_TOTAL_COUNT:
		_completed = true
		_skipped = true
		_selection_result = {
			"accepted": false,
			"reason": "invalid_start_card_offer",
			"skipped": true,
		}
		return false
	_active = true
	_picks_remaining = TowerAscentTuning.TEMP_START_CARD_PICK_LIMIT
	return true


func update(delta: float) -> void:
	if not _active:
		return
	var step := maxf(0.0, delta)
	_elapsed_sec += step
	if _absorb_elapsed_sec >= 0.0:
		_absorb_elapsed_sec += step
		if _absorb_elapsed_sec >= TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC:
			_finish_phase()
		return
	if _elapsed_sec >= TowerAscentTuning.TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC:
		_selection_result = {
			"accepted": false,
			"reason": "start_card_failsafe_timeout",
			"skipped": true,
		}
		_skipped = true
		_finish_phase()


func select_slot(index: int) -> bool:
	if (
		not _active
		or _picks_remaining <= 0
		or index < 0
		or index >= _card_choices.size()
		or not bool(_card_choices[index].get("enabled", false))
	):
		return false
	_picks_remaining = 0
	for choice in _card_choices:
		choice["enabled"] = false
	var selected := _card_choices[index].duplicate(true)
	var accepted := _apply_choice(selected)
	var pending_swap_started := _has_pending_unlock_swap()
	if pending_swap_started:
		if _runtime_state != null and _runtime_state.has_method("cancel_pending_unlock_swap"):
			_runtime_state.call("cancel_pending_unlock_swap", _owner)
		accepted = false
	_selection_result = {
		"accepted": accepted,
		"reason": "applied" if accepted else "start_card_grant_failed",
		"skipped": not accepted,
		"picked_perk_id": str(selected.get("id", "")) if accepted else "",
		"picked_kind": str(selected.get("start_card_kind", "")) if accepted else "",
		"pending_swap_started": pending_swap_started,
	}
	if accepted:
		_absorb_elapsed_sec = 0.0
	else:
		_skipped = true
		_finish_phase()
	return accepted


func is_active() -> bool:
	return _active


func is_completed() -> bool:
	return _completed


func was_skipped() -> bool:
	return _skipped


func get_card_choices() -> Array[Dictionary]:
	return _card_choices.duplicate(true)


func get_selection_result() -> Dictionary:
	return _selection_result.duplicate(true)


func get_cold_build_msec() -> float:
	return _cold_build_msec


func get_status_for_tests() -> Dictionary:
	return {
		"active": _active,
		"completed": _completed,
		"skipped": _skipped,
		"picks_remaining": _picks_remaining,
		"elapsed_sec": _elapsed_sec,
		"absorb_elapsed_sec": _absorb_elapsed_sec,
		"card_count": _card_choices.size(),
		"selection_result": _selection_result.duplicate(true),
	}


func tear_down() -> void:
	_owner = null
	_registry = null
	_runtime_state = null
	_active = false
	_completed = false
	_skipped = false
	_elapsed_sec = 0.0
	_absorb_elapsed_sec = -1.0
	_picks_remaining = 0
	_card_choices.clear()
	_selection_result.clear()
	_cold_build_msec = 0.0


func _apply_choice(choice: Dictionary) -> bool:
	if _runtime_state == null or not _runtime_state.has_method("apply_choice"):
		return false
	var previous_context: Dictionary = {}
	var context_value: Variant = _runtime_state.get("current_choice_context")
	if context_value is Dictionary:
		previous_context = (context_value as Dictionary).duplicate(true)
	_runtime_state.set("current_choice_context", {
		"source": "tower_start_card",
		"grant_scope": "tower_run",
	})
	var accepted := bool(_runtime_state.call("apply_choice", choice, _owner, _registry))
	_runtime_state.set("current_choice_context", previous_context)
	return accepted


func _has_pending_unlock_swap() -> bool:
	return (
		_runtime_state != null
		and _runtime_state.has_method("has_pending_unlock_swap")
		and bool(_runtime_state.call("has_pending_unlock_swap"))
	)


func _finish_phase() -> void:
	_active = false
	_completed = true


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or key.is_empty():
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null
