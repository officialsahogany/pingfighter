extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const ACTION_REST := "rest:rest"
const ACTION_COOK_BANANA := "rest:cook_banana"
const ACTION_TAKE_CAMPFIRE := "rest:take_campfire"

var _history: Array[Dictionary] = []
var _next_battle_full_gauge_pending := false


func reset() -> void:
	_history.clear()
	_next_battle_full_gauge_pending = false


func restore_state(value: Variant) -> void:
	_history.clear()
	_next_battle_full_gauge_pending = false
	if value is Dictionary:
		var state := value as Dictionary
		_history = _dictionary_array(state.get("history", []))
		_next_battle_full_gauge_pending = bool(
			state.get("next_battle_full_gauge_pending", false)
		)
	elif value is Array:
		# Legacy snapshots stored only the old chance-gem history array.
		_history = _dictionary_array(value)


func export_state() -> Dictionary:
	return {
		"history": _dictionary_array(_history),
		"next_battle_full_gauge_pending": _next_battle_full_gauge_pending,
	}


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_history)


func has_next_battle_full_gauge() -> bool:
	return _next_battle_full_gauge_pending


func has_committed_choice(node_id: String) -> bool:
	return not get_committed_action_id(node_id).is_empty()


func get_committed_action_id(node_id: String) -> String:
	for record in _history:
		if str(record.get("node_id", "")) == node_id:
			return str(record.get("action_id", ""))
	return ""


func build_actions(
	node_id: String,
	_run_state: Object,
	owner: Object = null,
	registry: Object = null
) -> Array[Dictionary]:
	var used := has_committed_choice(node_id)
	var active_item_runtime := _get_registry_instance(registry, "active_item_runtime")
	var runtime_ready := active_item_runtime != null
	var has_banana := bool(
		active_item_runtime.call("has_banana", owner)
		if runtime_ready and active_item_runtime.has_method("has_banana")
		else false
	)
	var completed_copy := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_CAMPFIRE_COMPLETED
	)
	var runtime_copy := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_CAMPFIRE_RUNTIME_UNAVAILABLE
	)
	var banana_reason := ""
	var banana_unavailable := ""
	if used:
		banana_reason = "rest_already_used"
		banana_unavailable = completed_copy
	elif not runtime_ready:
		banana_reason = "active_item_runtime_unavailable"
		banana_unavailable = runtime_copy
	elif not has_banana:
		banana_reason = "banana_missing"
		banana_unavailable = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_REQUIRED
		)
	var campfire_reason := ""
	var campfire_unavailable := ""
	if used:
		campfire_reason = "rest_already_used"
		campfire_unavailable = completed_copy
	elif not runtime_ready:
		campfire_reason = "active_item_runtime_unavailable"
		campfire_unavailable = runtime_copy
	return [
		_build_action(
			ACTION_REST,
			TowerAscentNodeModalLocalization.KEY_CAMPFIRE_REST_OPTION,
			not used,
			"rest_already_used" if used else "",
			completed_copy if used else "",
			not used
		),
		_build_action(
			ACTION_COOK_BANANA,
			TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_OPTION,
			not used and runtime_ready and has_banana,
			banana_reason,
			banana_unavailable,
			not used
		),
		_build_action(
			ACTION_TAKE_CAMPFIRE,
			TowerAscentNodeModalLocalization.KEY_CAMPFIRE_TAKE_OPTION,
			not used and runtime_ready,
			campfire_reason,
			campfire_unavailable,
			not used
		),
	]


func execute_action(
	action_id: String,
	resolution_id: String,
	node_id: String,
	run_state: Object,
	resolution_ids: Dictionary,
	_action_transaction: Object,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return {"accepted": false, "applied": false, "reason": "invalid_resolution_id"}
	if resolution_ids.has(normalized_resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": normalized_resolution_id,
		}
	if has_committed_choice(node_id):
		return _rejection(
			"rest_already_used",
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_COMPLETED
			)
		)
	var action := _find_action(
		build_actions(node_id, run_state, owner, registry),
		action_id
	)
	if action.is_empty():
		return {"accepted": false, "applied": false, "reason": "unknown_rest_action"}
	if not bool(action.get("enabled", false)):
		return _rejection(
			str(action.get("disabled_reason", "campfire_action_disabled")),
			str(action.get("unavailable_reason", ""))
		)
	var effect_receipt: Dictionary = {}
	match action_id:
		ACTION_REST:
			_next_battle_full_gauge_pending = true
			effect_receipt = {"next_battle_full_gauge": true}
		ACTION_COOK_BANANA:
			var active_item_runtime := _get_registry_instance(
				registry,
				"active_item_runtime"
			)
			if (
				active_item_runtime == null
				or not active_item_runtime.has_method(
					"consume_banana_and_grant_mastery"
				)
			):
				return _rejection(
					"active_item_runtime_unavailable",
					TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_CAMPFIRE_RUNTIME_UNAVAILABLE
					)
				)
			var effect_value: Variant = active_item_runtime.call(
				"consume_banana_and_grant_mastery",
				owner,
				registry
			)
			if not (effect_value is Dictionary):
				return _rejection(
					"banana_master_transaction_invalid",
					TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_CAMPFIRE_RUNTIME_UNAVAILABLE
					)
				)
			effect_receipt = (effect_value as Dictionary).duplicate(true)
			if (
				not bool(effect_receipt.get("accepted", false))
				or not bool(effect_receipt.get("applied", false))
			):
				var reason := str(effect_receipt.get(
					"reason",
					"banana_master_rejected"
				))
				return _rejection(reason, _localized_rejection(reason))
		ACTION_TAKE_CAMPFIRE:
			var active_item_runtime := _get_registry_instance(
				registry,
				"active_item_runtime"
			)
			if (
				active_item_runtime == null
				or not active_item_runtime.has_method("grant_item_to_slot")
			):
				return _rejection(
					"active_item_runtime_unavailable",
					TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_CAMPFIRE_RUNTIME_UNAVAILABLE
					)
				)
			if not bool(active_item_runtime.call(
				"grant_item_to_slot",
				"campfire",
				owner,
				registry,
				false
			)):
				return _rejection(
					"active_item_slot_full",
					TowerAscentNodeModalLocalization.text(
						TowerAscentNodeModalLocalization.KEY_CAMPFIRE_ACTIVE_SLOT_FULL
					)
				)
			effect_receipt = {"item_id": "campfire", "count": 1}
		_:
			return {"accepted": false, "applied": false, "reason": "unknown_rest_action"}
	return _commit_choice(
		action_id,
		normalized_resolution_id,
		node_id,
		run_state,
		resolution_ids,
		effect_receipt
	)


func build_presentation_lines(action_id: String) -> Array[String]:
	match action_id:
		ACTION_REST:
			return [
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_REST_MONOLOGUE
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_REST_MESSAGE
				),
			]
		ACTION_COOK_BANANA:
			return [
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_COOK
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_MASTER_NAME
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_MASTER_DESCRIPTION
				),
			]
		ACTION_TAKE_CAMPFIRE:
			return [TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_TAKE_OPTION
			)]
	return []


func consume_next_battle_full_gauge(
	owner: Object,
	registry: Object = null
) -> Dictionary:
	if not _next_battle_full_gauge_pending:
		return {"accepted": true, "applied": false, "reason": "not_pending"}
	if owner == null:
		return {"accepted": false, "applied": false, "reason": "missing_owner"}
	var gauge_max_value: Variant = owner.get("special_gauge_max")
	if gauge_max_value == null:
		return {"accepted": false, "applied": false, "reason": "missing_gauge_max"}
	var gauge_max := maxf(0.0, float(gauge_max_value))
	if gauge_max <= 0.0:
		return {"accepted": false, "applied": false, "reason": "invalid_gauge_max"}
	owner.set("special_gauge", gauge_max)
	var applied_value: Variant = owner.get("special_gauge")
	if applied_value == null or not is_equal_approx(float(applied_value), gauge_max):
		return {"accepted": false, "applied": false, "reason": "gauge_apply_failed"}
	var orb_hud_state := _get_registry_instance(registry, "orb_hud_state")
	if orb_hud_state != null and orb_hud_state.has_method("reset_gauge"):
		orb_hud_state.call("reset_gauge", int(round(gauge_max)))
	_next_battle_full_gauge_pending = false
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	return {
		"accepted": true,
		"applied": true,
		"reason": "next_battle_full_gauge_consumed",
		"special_gauge": gauge_max,
	}


func _build_action(
	action_id: String,
	label_key: String,
	enabled: bool,
	disabled_reason: String,
	unavailable_reason: String,
	force_choice: bool
) -> Dictionary:
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(label_key),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"operation": action_id.trim_prefix("rest:"),
			"force_choice": force_choice,
			"presentation_mode": "campfire_choice",
			"intro_lines": [
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_INTRO_APPROACH
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_INTRO_UNUSUAL
				),
			],
		},
	}


func _commit_choice(
	action_id: String,
	resolution_id: String,
	node_id: String,
	run_state: Object,
	resolution_ids: Dictionary,
	effect_receipt: Dictionary
) -> Dictionary:
	resolution_ids[resolution_id] = true
	var record := {
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"action_id": action_id,
		"effect_receipt": effect_receipt.duplicate(true),
	}
	_history.append(record)
	var balances := _economy_snapshot(run_state)
	var lines := build_presentation_lines(action_id)
	return {
		"accepted": true,
		"applied": true,
		"reason": "committed",
		"node_resolution_id": resolution_id,
		"record": record.duplicate(true),
		"costs": {},
		"rewards": {},
		"balances_before": balances.duplicate(true),
		"balances": balances.duplicate(true),
		"presentation_lines": lines,
		"message": lines.back() if not lines.is_empty() else "",
	}


func _localized_rejection(reason: String) -> String:
	match reason:
		"banana_missing":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_REQUIRED
			)
		"banana_master_already_owned":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_BANANA_MASTER_OWNED
			)
		"perk_slot_full":
			return TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_MARTIAL_SLOT_FULL
			)
	return TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_CAMPFIRE_RUNTIME_UNAVAILABLE
	)


func _rejection(reason: String, message: String) -> Dictionary:
	return {
		"accepted": false,
		"applied": false,
		"reason": reason,
		"message": message,
	}


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")) == action_id
		):
			return (action_value as Dictionary).duplicate(true)
	return {}


func _economy_snapshot(run_state: Object) -> Dictionary:
	if run_state != null and run_state.has_method("export_economy"):
		var value: Variant = run_state.call("export_economy")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_value in (value as Array):
			if raw_value is Dictionary:
				result.append((raw_value as Dictionary).duplicate(true))
	return result
