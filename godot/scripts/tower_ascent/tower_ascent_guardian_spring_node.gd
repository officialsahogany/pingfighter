extends RefCounted

const CommonSkillCatalog := preload(
	"res://scripts/characters/common_skill_catalog.gd"
)
const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const GuardianCodexDiscoveryRecorder := preload(
	"res://scripts/lingpet/guardian_codex_discovery_recorder.gd"
)
const LingpetCatalog := preload(
	"res://scripts/lingpet/lingpet_catalog.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerGuardianSpringOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_offer_builder.gd"
)

const ACTION_PREFIX := "guardian_spring:"
const OP_PALM := "palm"
const OP_PRAYER := "prayer"
const OP_ENHANCE := "enhance"
const OP_FIRST_PICK := "first_pick"
const OP_BROWSE := "browse"
const OP_BROWSE_CANDIDATE := "browse_candidate"
const RNG_VERSION := "tower_guardian_spring_v1"

var _state: Dictionary = {}
var _pending_rollback: Dictionary = {}
var _last_effect_result: Dictionary = {}
var _character_context: Object = RuntimePerkCharacterContext.new()
var _offer_builder: Object = TowerGuardianSpringOfferBuilder.new()


func _init() -> void:
	reset()


func reset() -> void:
	_state = {
		"soul_summoning_owned": false,
		"soul_summoning_node_id": "",
		"active_guardian": {},
		"sealed_guardians": [],
		"history": [],
		"runtime_snapshot": {},
		"perk_runtime_snapshot": {},
		"skill_config_snapshot": {},
		"first_pick_completed": false,
		"first_pick_candidates": [],
		"browse_sequence": 0,
		"browse_offers": [],
		"pending_browse_offer": {},
	}
	_pending_rollback.clear()
	_last_effect_result.clear()


func restore_state(value: Variant) -> void:
	reset()
	if not (value is Dictionary):
		return
	var source := value as Dictionary
	_state["soul_summoning_owned"] = bool(source.get("soul_summoning_owned", false))
	_state["soul_summoning_node_id"] = str(source.get("soul_summoning_node_id", ""))
	_state["active_guardian"] = _dictionary(source.get("active_guardian", {}))
	_state["sealed_guardians"] = []
	_state["history"] = _dictionary_array(source.get("history", []))
	_state["runtime_snapshot"] = _dictionary(source.get("runtime_snapshot", {}))
	_state["perk_runtime_snapshot"] = _dictionary(source.get("perk_runtime_snapshot", {}))
	_state["skill_config_snapshot"] = _dictionary(source.get("skill_config_snapshot", {}))
	_state["first_pick_completed"] = bool(source.get("first_pick_completed", false))
	_state["first_pick_candidates"] = _dictionary_array(source.get("first_pick_candidates", []))
	_state["browse_sequence"] = maxi(0, int(source.get("browse_sequence", 0)))
	_state["browse_offers"] = _dictionary_array(source.get("browse_offers", []))
	_state["pending_browse_offer"] = _dictionary(source.get("pending_browse_offer", {}))


func export_state() -> Dictionary:
	var result := _state.duplicate(true)
	result["sealed_guardians"] = []
	return result


func has_soul_summoning() -> bool:
	return bool(_state.get("soul_summoning_owned", false))


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_state.get("history", []))


func is_first_pick_pending() -> bool:
	return (
		has_soul_summoning()
		and not bool(_state.get("first_pick_completed", false))
		and _dictionary(_state.get("active_guardian", {})).is_empty()
	)


func record_identity_reveal(pet_id: String, registry: Object) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id.is_empty() or not LingpetCatalog.has_pet(normalized_pet_id):
		return {
			"accepted": false,
			"handled": true,
			"tower_sealed": false,
			"reason": "invalid_pet_id",
		}
	var codex_result: Dictionary = GuardianCodexDiscoveryRecorder.record_identity_reveal(
		registry,
		normalized_pet_id
	)
	if not bool(codex_result.get("accepted", false)):
		return {
			"accepted": false,
			"handled": true,
			"tower_sealed": false,
			"reason": str(codex_result.get("reason", "codex_commit_failed")),
			"pet_id": normalized_pet_id,
			"discovery_id": str(codex_result.get("discovery_id", "")),
			"codex_result": codex_result.duplicate(true),
		}
	return {
		"accepted": bool(codex_result.get("accepted", false)),
		"changed": bool(codex_result.get("changed", false)),
		"handled": true,
		"tower_sealed": false,
		"reason": str(codex_result.get("reason", "codex_commit_failed")),
		"pet_id": normalized_pet_id,
		"display_name": LingpetCatalog.get_display_name(normalized_pet_id),
		"discovery_id": str(codex_result.get("discovery_id", "")),
		"codex_result": codex_result.duplicate(true),
	}


func restore_runtime(owner: Object, registry: Object) -> bool:
	var runtime_snapshot := _dictionary(_state.get("runtime_snapshot", {}))
	var guardian_restored := _dictionary(_state.get("active_guardian", {})).is_empty()
	if not runtime_snapshot.is_empty():
		var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
		if runtime == null or not runtime.has_method("apply_save_snapshot"):
			return false
		var result_value: Variant = runtime.call(
			"apply_save_snapshot",
			runtime_snapshot,
			owner,
			registry
		)
		guardian_restored = (
			result_value is Dictionary
			and bool((result_value as Dictionary).get("restored", false))
		)
	if not guardian_restored or not has_soul_summoning():
		return guardian_restored
	return _restore_soul_unlock_runtime(owner, registry)


func build_actions(
	node_id: String,
	map_seed: int,
	run_state: Object,
	owner: Object,
	registry: Object
) -> Array[Dictionary]:
	_sync_active_guardian_from_runtime(owner, registry)
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	var balances := _economy(run_state)
	var active_guardian := _dictionary(_state.get("active_guardian", {}))
	var active_pet_id := str(active_guardian.get("pet_id", ""))
	if not active_pet_id.is_empty():
		var browse_offers := _dictionary_array(_state.get("browse_offers", []))
		if (
			not browse_offers.is_empty()
			and str(browse_offers[0].get("node_id", "")) != node_id
		):
			browse_offers.clear()
			_state["browse_offers"] = []
			_state["pending_browse_offer"] = {}
		if not browse_offers.is_empty():
			var browse_actions := _build_browse_candidate_actions(browse_offers, balances)
			browse_actions.append(_build_browse_action(runtime != null))
			return browse_actions
		return [_build_enhance_action(
			node_id,
			map_seed,
			balances,
			owner,
			runtime
		), _build_browse_action(runtime != null)]
	if has_soul_summoning() and not bool(_state.get("first_pick_completed", false)):
		_ensure_first_pick_candidates(node_id, map_seed, runtime)
		return _build_first_pick_actions(
			_dictionary_array(_state.get("first_pick_candidates", [])),
			runtime != null
		)
	var palm_wiring_ready := (
		runtime != null
		and _get_registry_instance(registry, "runtime_perk_state") != null
		and _get_registry_instance(registry, "runtime_perk_catalog") != null
		and _get_skill_config(owner, registry) != null
	)
	var actions: Array[Dictionary] = [_build_palm_action(palm_wiring_ready)]
	if not _prayer_locked(run_state):
		actions.append(_build_prayer_action(run_state, balances))
	return actions


func execute_action(
	action_id: String,
	resolution_id: String,
	node_id: String,
	map_seed: int,
	run_state: Object,
	resolution_ids: Dictionary,
	action_transaction: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return {"accepted": false, "reason": "invalid_resolution_id"}
	if resolution_ids.has(normalized_resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": normalized_resolution_id,
		}
	var action := _find_action(
		action_id,
		build_actions(node_id, map_seed, run_state, owner, registry)
	)
	if action.is_empty():
		return {"accepted": false, "reason": "unknown_guardian_spring_action"}
	if not bool(action.get("enabled", false)):
		return {
			"accepted": false,
			"reason": str(action.get("disabled_reason", "guardian_spring_action_disabled")),
			"message": str(action.get("unavailable_reason", "")),
		}
	if action_transaction == null or not action_transaction.has_method("apply_once"):
		return {"accepted": false, "reason": "missing_action_transaction"}
	var payload := _dictionary(action.get("payload", {}))
	var operation := str(payload.get("operation", ""))
	if operation == OP_BROWSE_CANDIDATE:
		return _open_browse_compare(payload, owner, registry)
	var cost := maxi(0, int(payload.get("cost", 0)))
	var effect_context := {
		"operation": operation,
		"pet_id": str(payload.get("pet_id", "")),
		"node_id": node_id,
		"map_seed": map_seed,
		"owner": owner,
		"registry": registry,
		"run_state": run_state,
		"offer": _dictionary(payload.get("offer", {})),
	}
	var transaction_result: Dictionary = action_transaction.call(
		"apply_once",
		normalized_resolution_id,
		{"muhon": cost},
		{},
		run_state,
		resolution_ids,
		Callable(self, "_apply_operation").bind(effect_context),
		Callable(self, "_rollback_operation").bind(owner, registry, run_state)
	)
	_pending_rollback.clear()
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		return transaction_result
	var record := {
		"node_id": node_id,
		"node_resolution_id": normalized_resolution_id,
		"operation": operation,
		"pet_id": str(payload.get("pet_id", "")),
		"cost": cost,
		"effect_result": _last_effect_result.duplicate(true),
	}
	var history: Array = _state.get("history", [])
	history.append(record)
	_state["history"] = history
	_capture_committed_runtime_snapshot(owner, registry)
	transaction_result["record"] = record.duplicate(true)
	transaction_result["message"] = _success_message(operation, record)
	return transaction_result


func has_pending_browse_compare(pet_id: String = "") -> bool:
	var offer := _dictionary(_state.get("pending_browse_offer", {}))
	if offer.is_empty():
		return false
	var normalized := pet_id.strip_edges().to_lower()
	return normalized.is_empty() or str(offer.get("pet_id", "")) == normalized


func cancel_browse_compare() -> Dictionary:
	var offer := _dictionary(_state.get("pending_browse_offer", {}))
	if offer.is_empty():
		return {"handled": false, "accepted": false}
	_state["pending_browse_offer"] = {}
	_state["browse_offers"] = []
	return {
		"handled": true,
		"accepted": true,
		"pet_id": str(offer.get("pet_id", "")),
	}


func commit_browse_purchase(
	slot_index: int,
	run_state: Object,
	resolution_ids: Dictionary,
	action_transaction: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	var offer := _dictionary(_state.get("pending_browse_offer", {}))
	if offer.is_empty():
		return {"handled": false, "accepted": false, "reason": "no_pending_browse_offer"}
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if (
		runtime == null
		or not runtime.has_method("commit_tower_spring_overflow_replace")
		or action_transaction == null
		or not action_transaction.has_method("apply_once")
	):
		return {"handled": true, "accepted": false, "reason": "missing_browse_commit_wiring"}
	var node_id := str(offer.get("node_id", ""))
	var sequence := maxi(0, int(offer.get("browse_sequence", 0)))
	var pet_id := str(offer.get("pet_id", ""))
	var resolution_id := "guardian_spring:browse_purchase:%s:%d:%s" % [
		node_id,
		sequence,
		pet_id,
	]
	_capture_rollback(owner, registry, run_state)
	var result: Dictionary = action_transaction.call(
		"apply_once",
		resolution_id,
		{"gold": maxi(0, int(offer.get("price_gold", 0)))},
		{},
		run_state,
		resolution_ids,
		Callable(runtime, "commit_tower_spring_overflow_replace").bind(
			slot_index,
			offer.duplicate(true),
			owner,
			registry
		),
		Callable(self, "_rollback_operation").bind(owner, registry, run_state)
	)
	result["handled"] = true
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_pending_rollback.clear()
		return result
	var record := {
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"operation": OP_BROWSE_CANDIDATE,
		"pet_id": pet_id,
		"cost_gold": maxi(0, int(offer.get("price_gold", 0))),
		"applied_roll_count": int(offer.get("applied_roll_count", 0)),
	}
	var history: Array = _state.get("history", [])
	history.append(record)
	_state["history"] = history
	if runtime.has_method("record_tower_spring_guardian_purchase_discovery"):
		runtime.call(
			"record_tower_spring_guardian_purchase_discovery",
			pet_id,
			registry
		)
	_state["pending_browse_offer"] = {}
	_state["browse_offers"] = []
	_capture_committed_runtime_snapshot(owner, registry)
	_pending_rollback.clear()
	result["record"] = record.duplicate(true)
	return result


func _build_palm_action(wiring_ready: bool) -> Dictionary:
	var label := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_PALM_OPTION
	)
	var badge := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_SOUL
	)
	return {
		"id": "%s%s" % [ACTION_PREFIX, OP_PALM],
		"label": label,
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": wiring_ready and not has_soul_summoning(),
		"disabled_reason": (
			"soul_summoning_already_owned"
			if has_soul_summoning()
			else "missing_soul_summoning_wiring"
		),
		"unavailable_reason": (
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_PALM_COMPLETED
			)
			if has_soul_summoning()
			else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_RUNTIME_UNAVAILABLE
			)
		),
		"payload": {
			"operation": OP_PALM,
			"cost": 0,
			"choice": _build_guardian_card_choice(
				"",
				label,
				badge,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_SOUL_DESCRIPTION
				)
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_STATE_EMPTY
				),
				badge,
				label
			),
		},
	}


func _build_prayer_action(run_state: Object, balances: Dictionary) -> Dictionary:
	var count := _prayer_count(run_state)
	var cost := count * TowerAscentTuning.TEMP_SPRING_PRAYER_COST_STEP
	var affordable := int(balances.get("muhon", 0)) >= cost
	var label := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_OPTION
	)
	return {
		"id": "%s%s:%d" % [ACTION_PREFIX, OP_PRAYER, count],
		"label": label,
		"cost_text": (
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_COST_FREE
			)
			if cost == 0
			else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_COST_MUHON,
				{"amount": cost}
			)
		),
		"enabled": affordable,
		"disabled_reason": "" if affordable else "insufficient_muhon",
		"unavailable_reason": (
			""
			if affordable
			else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
				{
					"required": cost,
					"shortfall": cost - int(balances.get("muhon", 0)),
				}
			)
		),
		"payload": {
			"operation": OP_PRAYER,
			"cost": cost,
			"choice": _build_guardian_card_choice(
				"",
				label,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_PRAYER
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_PRAYER_DESCRIPTION,
					{"bonus": TowerAscentTuning.TEMP_SPRING_PRAYER_STAT_BONUS_PCT}
				)
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_COUNT,
					{"count": count}
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_RESULT
				),
				label
			),
		},
	}


func _build_browse_action(wiring_ready: bool) -> Dictionary:
	var label := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_BROWSE_OPTION
	)
	return {
		"id": "%s%s:%d" % [ACTION_PREFIX, OP_BROWSE, int(_state.get("browse_sequence", 0))],
		"label": label,
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": wiring_ready,
		"disabled_reason": "" if wiring_ready else "missing_lingpet_runtime",
		"unavailable_reason": "" if wiring_ready else TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_RUNTIME_UNAVAILABLE
		),
		"payload": {
			"operation": OP_BROWSE,
			"cost": 0,
			"choice": _build_guardian_card_choice(
				"",
				label,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_BROWSE
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BROWSE_DESCRIPTION
				)
			),
			"presentation": _build_guardian_presentation("", "", label),
		},
	}


func _build_first_pick_actions(
	candidates: Array[Dictionary],
	wiring_ready: bool
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for candidate in candidates:
		var pet_id := str(candidate.get("pet_id", ""))
		var display_name := str(candidate.get("display_name", LingpetCatalog.get_display_name(pet_id)))
		var choice := _build_guardian_card_choice(
			pet_id,
			display_name,
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_FIRST_PICK
			),
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_PICK_INTRO
			)
		)
		choice["guardian_blind_preview"] = true
		choice["hide_skill_details"] = true
		choice["hide_numeric_details"] = true
		actions.append({
			"id": "%s%s:%s" % [ACTION_PREFIX, OP_FIRST_PICK, pet_id],
			"label": display_name,
			"cost_text": TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_COST_FREE
			),
			"enabled": wiring_ready,
			"disabled_reason": "" if wiring_ready else "missing_lingpet_runtime",
			"unavailable_reason": "",
			"payload": {
				"operation": OP_FIRST_PICK,
				"pet_id": pet_id,
				"cost": 0,
				"choice": choice,
				"acquisition_presentation_kind": "chosik_inherit",
				"force_choice": true,
				"presentation": _build_guardian_presentation("", "", display_name),
			},
		})
	return actions


func _build_browse_candidate_actions(
	offers: Array[Dictionary],
	balances: Dictionary
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for offer in offers:
		var pet_id := str(offer.get("pet_id", ""))
		var price := maxi(0, int(offer.get("price_gold", 0)))
		var loadout := _dictionary(offer.get("loadout", {}))
		var active_skill := LingpetCatalog.get_active_skill(
			pet_id,
			str(loadout.get("active_skill_id", "")),
			maxi(1, int(loadout.get("active_skill_level", 1)))
		)
		var passive_skill := LingpetCatalog.get_passive_skill(
			pet_id,
			str(loadout.get("passive_skill_id", "")),
			maxi(1, int(loadout.get("passive_skill_level", 1)))
		)
		var second_active_id := str(loadout.get("second_active_skill_id", ""))
		var second_passive_id := str(loadout.get("second_passive_skill_id", ""))
		var reward_summary: Array = offer.get("reward_summary", []) as Array
		var active_text := "%s Lv.%d" % [
			str(active_skill.get("name", "")),
			maxi(1, int(loadout.get("active_skill_level", 1))),
		]
		if second_active_id != "":
			var second_active := LingpetCatalog.get_active_skill(
				pet_id,
				second_active_id,
				maxi(1, int(loadout.get("second_active_skill_level", 1)))
			)
			active_text += " / %s Lv.%d" % [
				str(second_active.get("name", "")),
				maxi(1, int(loadout.get("second_active_skill_level", 1))),
			]
		var passive_text := "%s Lv.%d" % [
			str(passive_skill.get("name", "")),
			maxi(1, int(loadout.get("passive_skill_level", 1))),
		]
		if second_passive_id != "":
			var second_passive := LingpetCatalog.get_passive_skill(
				pet_id,
				second_passive_id,
				maxi(1, int(loadout.get("second_passive_skill_level", 1)))
			)
			passive_text += " / %s Lv.%d" % [
				str(second_passive.get("name", "")),
				maxi(1, int(loadout.get("second_passive_skill_level", 1))),
			]
		var description := "%s\n%s" % [active_text, passive_text]
		if not reward_summary.is_empty():
			description += "\n" + ", ".join(reward_summary)
		var affordable := int(balances.get("gold", 0)) >= price
		var choice := _build_guardian_card_choice(
			pet_id,
			str(offer.get("display_name", LingpetCatalog.get_display_name(pet_id))),
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_ELITE,
				{"count": int(offer.get("applied_roll_count", 0))}
			),
			description
		)
		choice["guardian_full_preview"] = true
		choice["guardian_offer"] = offer.duplicate(true)
		actions.append({
			"id": "%s%s:%d:%s" % [
				ACTION_PREFIX,
				OP_BROWSE_CANDIDATE,
				int(_state.get("browse_sequence", 0)),
				pet_id,
			],
			"label": str(offer.get("display_name", pet_id)),
			"cost_text": TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_COST_GOLD,
				{"amount": price}
			),
			"enabled": affordable,
			"disabled_reason": "" if affordable else "insufficient_gold",
			"unavailable_reason": "" if affordable else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_GOLD,
				{
					"required": price,
					"shortfall": price - int(balances.get("gold", 0)),
				}
			),
			"payload": {
				"operation": OP_BROWSE_CANDIDATE,
				"pet_id": pet_id,
				"cost": price,
				"offer": offer.duplicate(true),
				"choice": choice,
				"presentation": _build_guardian_presentation("", "", str(offer.get("display_name", pet_id))),
			},
		})
	return actions


func _build_enhance_action(
	node_id: String,
	map_seed: int,
	balances: Dictionary,
	owner: Object,
	runtime: Object
) -> Dictionary:
	var cost := TowerAscentTuning.TEMP_PHASE_C_SPRING_ENHANCE_COST
	var candidates: Array = []
	if runtime != null and runtime.has_method("build_guardian_enhance_live_candidates"):
		var candidates_value: Variant = runtime.call("build_guardian_enhance_live_candidates", owner)
		if candidates_value is Array:
			candidates = candidates_value as Array
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := runtime != null and not candidates.is_empty() and affordable
	var unavailable_reason := ""
	var disabled_reason := ""
	if runtime == null:
		disabled_reason = "missing_lingpet_runtime"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_RUNTIME_UNAVAILABLE
		)
	elif candidates.is_empty():
		disabled_reason = "no_guardian_enhancement_candidates"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_UNAVAILABLE
		)
	elif not affordable:
		disabled_reason = "insufficient_muhon"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var sequence := _operation_count(node_id, OP_ENHANCE)
	var active_guardian := _dictionary(_state.get("active_guardian", {}))
	var pet_id := str(active_guardian.get("pet_id", ""))
	var display_name := str(active_guardian.get(
		"display_name",
		LingpetCatalog.get_display_name(pet_id)
	))
	var badge := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_ENHANCE
	)
	return {
		"id": "%s%s:%d" % [ACTION_PREFIX, OP_ENHANCE, sequence],
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_OPTION,
			{"name": display_name}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"operation": OP_ENHANCE,
			"cost": cost,
			"pet_id": pet_id,
			"rng_seed": absi(hash("%s:%d:%s:%d" % [RNG_VERSION, map_seed, node_id, sequence])),
			"choice": _build_guardian_card_choice(
				pet_id,
				display_name,
				badge,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_ENHANCE_DESCRIPTION
				)
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_STATE_ACTIVE
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_STATE_ENHANCED
				),
				display_name
			),
		},
	}


func _build_guardian_card_choice(
	pet_id: String,
	display_name: String,
	badge: String,
	description: String
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	return {
		"id": (
			"guardian_spirit_egg"
			if normalized_pet_id.is_empty()
			else "guardian_portrait:%s" % normalized_pet_id
		),
		"icon_id": "guardian_spirit_egg" if normalized_pet_id.is_empty() else "",
		"name": display_name,
		"description": description,
		"level_text": badge,
		"tree": "guardian",
		"icon_color": Color(0.37, 0.72, 0.66),
		"card_content_kind": (
			"guardian_egg" if normalized_pet_id.is_empty() else "guardian_portrait"
		),
		"guardian_pet_id": normalized_pet_id,
		# The catalog path is presentation evidence only. The icon renderer resolves
		# and prewarms the same live catalog key; the draw path never loads it.
		"guardian_portrait_path": (
			""
			if normalized_pet_id.is_empty()
			else LingpetCatalog.get_visual_path(normalized_pet_id, "cutin_art")
		),
		"tower_node_strict_text_budget": true,
	}


func _build_guardian_presentation(
	current_text: String,
	result_text: String,
	target_text: String
) -> Dictionary:
	return {
		"current": current_text,
		"result": result_text,
		"target": target_text,
		"strict_text_budget": true,
	}


func _apply_operation(context: Dictionary) -> bool:
	_capture_rollback(
		context.get("owner", null),
		context.get("registry", null),
		context.get("run_state", null)
	)
	_last_effect_result.clear()
	var operation := str(context.get("operation", ""))
	var accepted := false
	if operation == OP_PALM:
		accepted = _apply_soul_summoning_unlock(
			context.get("owner", null),
			context.get("registry", null)
		)
		if accepted:
			_state["soul_summoning_owned"] = true
			_state["soul_summoning_node_id"] = str(context.get("node_id", ""))
			_last_effect_result = {"accepted": true, "soul_summoning_owned": true}
			accepted = _capture_committed_soul_unlock_snapshots(
				context.get("owner", null),
				context.get("registry", null)
			)
			if accepted:
				_state["first_pick_candidates"] = _offer_builder.build_first_pick_candidates(
					int(context.get("map_seed", 0)),
					str(context.get("node_id", "")),
					_runtime_owned_pet_ids(context.get("registry", null))
				)
	elif operation == OP_FIRST_PICK:
		accepted = _apply_first_pick(context)
	elif operation == OP_BROWSE:
		accepted = _apply_browse(context)
	elif operation == OP_PRAYER:
		var run_state: Object = context.get("run_state", null)
		accepted = (
			run_state != null
			and run_state.has_method("increment_guardian_prayer")
			and bool(run_state.call("increment_guardian_prayer"))
		)
		if accepted:
			_last_effect_result = {
				"accepted": true,
				"prayer_count": _prayer_count(run_state),
			}
	else:
		var runtime := _get_registry_instance(context.get("registry", null), "lingpet_egg_runtime")
		if runtime != null and operation == OP_ENHANCE:
			accepted = _apply_enhance(runtime, context)
	if accepted:
		_capture_committed_runtime_snapshot(
			context.get("owner", null),
			context.get("registry", null)
		)
	if not accepted:
		_rollback_operation(
			context.get("owner", null),
			context.get("registry", null),
			context.get("run_state", null)
		)
		_pending_rollback.clear()
	return accepted


func _apply_first_pick(context: Dictionary) -> bool:
	if bool(_state.get("first_pick_completed", false)):
		return false
	var pet_id := str(context.get("pet_id", "")).strip_edges().to_lower()
	if _find_candidate(pet_id, _dictionary_array(_state.get("first_pick_candidates", []))).is_empty():
		return false
	var runtime := _get_registry_instance(context.get("registry", null), "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("grant_and_activate_tower_spring_guardian"):
		return false
	if not bool(runtime.call(
		"grant_and_activate_tower_spring_guardian",
		pet_id,
		context.get("owner", null),
		context.get("registry", null)
	)):
		return false
	var run_state: Object = context.get("run_state", null)
	if run_state == null or not run_state.has_method("lock_guardian_prayer"):
		return false
	if not _prayer_locked(run_state) and not bool(run_state.call("lock_guardian_prayer")):
		return false
	_state["first_pick_completed"] = true
	_state["first_pick_candidates"] = []
	_last_effect_result = {
		"accepted": true,
		"pet_id": pet_id,
		"acquisition_cutin_started": true,
	}
	return true


func _apply_browse(context: Dictionary) -> bool:
	var next_sequence := maxi(0, int(_state.get("browse_sequence", 0))) + 1
	var floor_number := 1
	var run_state: Object = context.get("run_state", null)
	if run_state != null and run_state.has_method("get_revealed_floor"):
		floor_number = maxi(1, int(run_state.call("get_revealed_floor")))
	var offers: Array[Dictionary] = _offer_builder.build_browse_offers(
		int(context.get("map_seed", 0)),
		str(context.get("node_id", "")),
		next_sequence,
		floor_number,
		_runtime_owned_pet_ids(context.get("registry", null))
	)
	if offers.size() != TowerGuardianSpringOfferBuilder.OFFER_COUNT:
		return false
	for offer in offers:
		offer["node_id"] = str(context.get("node_id", ""))
		offer["browse_sequence"] = next_sequence
	_state["browse_sequence"] = next_sequence
	_state["browse_offers"] = offers
	_state["pending_browse_offer"] = {}
	_last_effect_result = {
		"accepted": true,
		"browse_sequence": next_sequence,
		"offer_count": offers.size(),
		"floor": floor_number,
	}
	return true


func _open_browse_compare(payload: Dictionary, owner: Object, registry: Object) -> Dictionary:
	var pet_id := str(payload.get("pet_id", "")).strip_edges().to_lower()
	var offer := _find_candidate(pet_id, _dictionary_array(_state.get("browse_offers", [])))
	if offer.is_empty():
		return {"accepted": false, "applied": false, "reason": "stale_browse_offer"}
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("begin_tower_spring_overflow_compare"):
		return {"accepted": false, "applied": false, "reason": "missing_browse_compare_wiring"}
	_state["pending_browse_offer"] = offer.duplicate(true)
	if not bool(runtime.call(
		"begin_tower_spring_overflow_compare",
		offer.duplicate(true),
		owner,
		registry
	)):
		_state["pending_browse_offer"] = {}
		return {"accepted": false, "applied": false, "reason": "browse_compare_rejected"}
	return {
		"accepted": true,
		"applied": false,
		"reason": "compare_opened",
		"pet_id": pet_id,
		"price_gold": int(offer.get("price_gold", 0)),
	}


func _apply_soul_summoning_unlock(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	var skill_config := _get_skill_config(owner, registry)
	if (
		runtime_state == null
		or catalog == null
		or skill_config == null
		or not runtime_state.has_method("apply_choice")
		or not catalog.has_method("get_perk_data")
	):
		return false
	var choice_value: Variant = catalog.call(
		"get_perk_data",
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	)
	if not (choice_value is Dictionary):
		return false
	var choice := (choice_value as Dictionary).duplicate(true)
	if str(choice.get("unlocks_skill", "")) != CommonSkillCatalog.SOUL_SUMMON_ART_ID:
		return false
	return bool(runtime_state.call("apply_choice", choice, owner, registry))


func _apply_enhance(runtime: Object, context: Dictionary) -> bool:
	if (
		not runtime.has_method("build_guardian_enhance_live_candidates")
		or not runtime.has_method("apply_guardian_enhance_random_roll")
	):
		return false
	var candidates_value: Variant = runtime.call(
		"build_guardian_enhance_live_candidates",
		context.get("owner", null)
	)
	if not (candidates_value is Array) or (candidates_value as Array).is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s:%d:%s:%d" % [
		RNG_VERSION,
		int(context.get("map_seed", 0)),
		str(context.get("node_id", "")),
		_operation_count(str(context.get("node_id", "")), OP_ENHANCE),
	]))
	var result_value: Variant = runtime.call(
		"apply_guardian_enhance_random_roll",
		candidates_value,
		context.get("owner", null),
		context.get("registry", null),
		"tower_guardian_spring",
		rng
	)
	if result_value is Dictionary:
		_last_effect_result = (result_value as Dictionary).duplicate(true)
	return bool(_last_effect_result.get("accepted", false))


func _capture_rollback(owner: Object, registry: Object, run_state: Object = null) -> void:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	_pending_rollback = {
		"state": _state.duplicate(true),
		"runtime_snapshot": _capture_runtime_snapshot(registry),
		"runtime_replace_rollback_snapshot": _capture_runtime_replace_rollback_snapshot(
			registry
		),
		"perk_runtime_snapshot": _capture_perk_runtime_snapshot(runtime_state),
		"equipped_skills": _equipped_skills(skill_config),
		"prayer_count": _prayer_count(run_state),
		"prayer_locked": _prayer_locked(run_state),
	}


func _rollback_operation(owner: Object, registry: Object, run_state: Object = null) -> void:
	if _pending_rollback.is_empty():
		return
	_state = _dictionary(_pending_rollback.get("state", {}))
	if run_state != null and run_state.has_method("restore_guardian_prayer_state"):
		run_state.call(
			"restore_guardian_prayer_state",
			int(_pending_rollback.get("prayer_count", 0)),
			bool(_pending_rollback.get("prayer_locked", false))
		)
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("cancel_pending_unlock_swap"):
		runtime_state.call("cancel_pending_unlock_swap", owner)
	var skill_config := _get_skill_config(owner, registry)
	if skill_config != null:
		_restore_equipped_skills(skill_config, _pending_rollback.get("equipped_skills", []))
	var perk_runtime_snapshot := _dictionary(
		_pending_rollback.get("perk_runtime_snapshot", {})
	)
	if (
		runtime_state != null
		and not perk_runtime_snapshot.is_empty()
		and runtime_state.has_method("apply_unlock_save_snapshot")
	):
		runtime_state.call("apply_unlock_save_snapshot", perk_runtime_snapshot, owner, registry)
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	var replace_rollback_snapshot := _dictionary(
		_pending_rollback.get("runtime_replace_rollback_snapshot", {})
	)
	var restored_replace_snapshot := false
	if (
		runtime != null
		and not replace_rollback_snapshot.is_empty()
		and runtime.has_method("restore_tower_spring_replace_rollback_snapshot")
	):
		restored_replace_snapshot = bool(runtime.call(
			"restore_tower_spring_replace_rollback_snapshot",
			replace_rollback_snapshot,
			owner,
			registry
		))
	var runtime_snapshot := _dictionary(_pending_rollback.get("runtime_snapshot", {}))
	if (
		not restored_replace_snapshot
		and not runtime_snapshot.is_empty()
		and runtime != null
		and runtime.has_method("apply_save_snapshot")
	):
		runtime.call("apply_save_snapshot", runtime_snapshot, owner, registry)
	var pending_offer := _dictionary(_state.get("pending_browse_offer", {}))
	if (
		not pending_offer.is_empty()
		and runtime != null
		and runtime.has_method("begin_tower_spring_overflow_compare")
		and (
			not runtime.has_method("is_overflow_choice_active")
			or not bool(runtime.call("is_overflow_choice_active"))
		)
	):
		runtime.call(
			"begin_tower_spring_overflow_compare",
			pending_offer.duplicate(true),
			owner,
			registry
		)


func _capture_committed_runtime_snapshot(owner: Object, registry: Object) -> void:
	var runtime_snapshot := _capture_runtime_snapshot(registry)
	if runtime_snapshot.is_empty():
		return
	_state["runtime_snapshot"] = runtime_snapshot
	var runtime_state := str(runtime_snapshot.get("state", "")).strip_edges().to_lower()
	var pet_id := str(runtime_snapshot.get("pet_id", "")).strip_edges().to_lower()
	if runtime_state == "companion" and not pet_id.is_empty():
		_state["active_guardian"] = {
			"pet_id": pet_id,
			"display_name": LingpetCatalog.get_display_name(pet_id),
			"guardian_run_state": _dictionary(runtime_snapshot.get("guardian_run_state", {})),
		}
	_sync_sealed_owner_projection(owner)


func _capture_committed_soul_unlock_snapshots(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	var perk_runtime_snapshot := _capture_perk_runtime_snapshot(runtime_state)
	var equipped_skills := _equipped_skills(skill_config)
	if (
		perk_runtime_snapshot.is_empty()
		or not equipped_skills.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
	):
		return false
	_state["perk_runtime_snapshot"] = perk_runtime_snapshot
	_state["skill_config_snapshot"] = {
		"character_type": _character_type(owner),
		"equipped_skills": equipped_skills,
	}
	return true


func _restore_soul_unlock_runtime(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state == null or skill_config == null:
		return false
	var perk_runtime_snapshot := _dictionary(_state.get("perk_runtime_snapshot", {}))
	var skill_config_snapshot := _dictionary(_state.get("skill_config_snapshot", {}))
	if perk_runtime_snapshot.is_empty() or skill_config_snapshot.is_empty():
		if not _apply_soul_summoning_unlock(owner, registry):
			return false
		return _capture_committed_soul_unlock_snapshots(owner, registry)
	if not _restore_equipped_skills(
		skill_config,
		skill_config_snapshot.get("equipped_skills", [])
	):
		return false
	if not runtime_state.has_method("apply_unlock_save_snapshot"):
		return false
	var result_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		perk_runtime_snapshot,
		owner,
		registry
	)
	return result_value is Dictionary and bool((result_value as Dictionary).get("restored", false))


func _sync_active_guardian_from_runtime(owner: Object, registry: Object) -> void:
	if not _dictionary(_state.get("active_guardian", {})).is_empty():
		_sync_sealed_owner_projection(owner)
		return
	_capture_committed_runtime_snapshot(owner, registry)


func sync_owner_projection(
	owner: Object,
	run_state: Object = null,
	registry: Object = null
) -> void:
	_sync_sealed_owner_projection(owner)
	var count := _prayer_count(run_state)
	var locked := _prayer_locked(run_state)
	if owner != null and owner.has_method("set_tower_ascent_prayer_projection"):
		owner.call("set_tower_ascent_prayer_projection", count, locked)
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("set_tower_spring_prayer_count"):
		runtime_state.call("set_tower_spring_prayer_count", count, owner, registry)


func _sync_sealed_owner_projection(owner: Object) -> void:
	if owner == null or not owner.has_method("set_tower_ascent_guardian_projection"):
		return
	owner.call(
		"set_tower_ascent_guardian_projection",
		[],
		has_soul_summoning()
	)


func _capture_runtime_snapshot(registry: Object) -> Dictionary:
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("build_save_snapshot"):
		return {}
	var value: Variant = runtime.call("build_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _capture_runtime_replace_rollback_snapshot(registry: Object) -> Dictionary:
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if (
		runtime == null
		or not runtime.has_method("build_tower_spring_replace_rollback_snapshot")
	):
		return {}
	var value: Variant = runtime.call("build_tower_spring_replace_rollback_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _capture_perk_runtime_snapshot(runtime_state: Object) -> Dictionary:
	if runtime_state == null or not runtime_state.has_method("build_unlock_save_snapshot"):
		return {}
	var value: Variant = runtime_state.call("build_unlock_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _restore_equipped_skills(skill_config: Object, original_value: Variant) -> bool:
	if skill_config == null or not (original_value is Array):
		return false
	var original := (original_value as Array).duplicate()
	var current := _equipped_skills(skill_config)
	for skill_value in current:
		var skill_id := str(skill_value)
		if not original.has(skill_id):
			if (
				not skill_config.has_method("unequip_skill")
				or not bool(skill_config.call("unequip_skill", skill_id))
			):
				return false
	current = _equipped_skills(skill_config)
	for skill_value in original:
		var skill_id := str(skill_value)
		if not current.has(skill_id):
			if (
				not skill_config.has_method("unlock_and_equip_skill")
				or not bool(skill_config.call("unlock_and_equip_skill", skill_id))
			):
				return false
	return _equipped_skills(skill_config) == original


func _equipped_skills(skill_config: Object) -> Array:
	if skill_config == null:
		return []
	if skill_config.has_method("get_snapshot"):
		var snapshot_value: Variant = skill_config.call("get_snapshot")
		if snapshot_value is Dictionary:
			var equipped_value: Variant = (snapshot_value as Dictionary).get(
				"equipped_skills",
				[]
			)
			if equipped_value is Array:
				return (equipped_value as Array).duplicate()
	if skill_config.has_method("get_equipped_skills"):
		var equipped_value: Variant = skill_config.call("get_equipped_skills")
		if equipped_value is Array:
			return (equipped_value as Array).duplicate()
	return []


func _character_type(owner: Object) -> String:
	return _character_context.get_owner_character_type(owner)


func _get_skill_config(owner: Object, registry: Object) -> Object:
	var key: String = str(_character_context.get_skill_config_key(_character_type(owner)))
	return _get_registry_instance(registry, key)


func _operation_count(node_id: String, operation: String) -> int:
	var count := 0
	for record in get_history():
		if str(record.get("node_id", "")) == node_id and str(record.get("operation", "")) == operation:
			count += 1
	return count


func _ensure_first_pick_candidates(node_id: String, map_seed: int, runtime: Object) -> void:
	if not _dictionary_array(_state.get("first_pick_candidates", [])).is_empty():
		return
	_state["first_pick_candidates"] = _offer_builder.build_first_pick_candidates(
		map_seed,
		node_id,
		_runtime_owned_pet_ids_from_runtime(runtime)
	)


func _runtime_owned_pet_ids(registry: Object) -> Array:
	return _runtime_owned_pet_ids_from_runtime(
		_get_registry_instance(registry, "lingpet_egg_runtime")
	)


func _runtime_owned_pet_ids_from_runtime(runtime: Object) -> Array:
	if runtime == null or not runtime.has_method("build_save_snapshot"):
		return []
	var snapshot_value: Variant = runtime.call("build_save_snapshot")
	if not (snapshot_value is Dictionary):
		return []
	var snapshot := snapshot_value as Dictionary
	var result: Array = []
	var owned_value: Variant = snapshot.get("owned_pet_ids", [])
	if owned_value is Array:
		result = (owned_value as Array).duplicate()
	var active_pet_id := str(snapshot.get("pet_id", "")).strip_edges().to_lower()
	if active_pet_id != "" and not result.has(active_pet_id):
		result.append(active_pet_id)
	return result


func _find_candidate(pet_id: String, candidates: Array[Dictionary]) -> Dictionary:
	var normalized := pet_id.strip_edges().to_lower()
	for candidate in candidates:
		if str(candidate.get("pet_id", "")).strip_edges().to_lower() == normalized:
			return candidate.duplicate(true)
	return {}


func _find_action(action_id: String, actions: Array[Dictionary]) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _success_message(operation: String, record: Dictionary) -> String:
	var pet_id := str(record.get("pet_id", ""))
	var display_name := LingpetCatalog.get_display_name(pet_id) if not pet_id.is_empty() else ""
	var key := TowerAscentNodeModalLocalization.KEY_SPRING_PALM_COMPLETED
	if operation == OP_PRAYER:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_COMPLETED
	if operation == OP_ENHANCE:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_COMPLETED
	if operation == OP_FIRST_PICK:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_PICK_COMPLETED
	if operation == OP_BROWSE:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_BROWSE_COMPLETED
	return TowerAscentNodeModalLocalization.text(key, {"name": display_name})


func _economy(run_state: Object) -> Dictionary:
	if run_state != null and run_state.has_method("export_economy"):
		var value: Variant = run_state.call("export_economy")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _prayer_count(run_state: Object) -> int:
	if run_state != null and run_state.has_method("get_prayer_count"):
		return maxi(0, int(run_state.call("get_prayer_count")))
	return 0


func _prayer_locked(run_state: Object) -> bool:
	return (
		run_state != null
		and run_state.has_method("is_guardian_prayer_locked")
		and bool(run_state.call("is_guardian_prayer_locked"))
	)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_value in (value as Array):
			if raw_value is Dictionary:
				result.append((raw_value as Dictionary).duplicate(true))
	return result
