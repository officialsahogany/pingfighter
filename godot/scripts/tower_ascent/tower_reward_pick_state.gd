extends RefCounted

const TowerRewardPickOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const RuntimePerkChoiceLayout := preload(
	"res://scripts/characters/runtime_perk_choice_layout.gd"
)

const VIEW_SIZE := Vector2(760.0, 750.0)
const CONTINUE_SIZE := Vector2(220.0, 42.0)
const CONTINUE_BOTTOM_MARGIN := 34.0
const TEMP_REWARD_PICK_ABSORB_DURATION_SEC := 0.78

var active := false
var animation_time := 0.0
var selected_index := 0
var choices: Array[Dictionary] = []
var spent_flags: Array[bool] = []
var purchase_absorption_effects: Array[Dictionary] = []

var _owner: Object = null
var _registry: Object = null
var _flow_owner: Object = null
var _runtime_state: Object = null
var _card_renderer: Object = null
var _icon_renderer: Object = null
var _finish_callback: Callable = Callable()
var _offer: Dictionary = {}
var _status_text := ""
var _layout: Object = RuntimePerkChoiceLayout.new()
var _offer_builder: Object = TowerRewardPickOfferBuilder.new()
var _pending_external_kind := ""
var _pending_slot_index := -1
var _pending_runtime_snapshot: Dictionary = {}


func start(
	owner: Object,
	registry: Object,
	finish_callback: Callable,
	roll_overrides: Dictionary = {}
) -> bool:
	if active:
		return false
	var flow_owner := _get_registry_instance(registry, "tower_ascent_flow_owner")
	if flow_owner == null or not flow_owner.has_method("get_reward_pick_context"):
		return false
	var context_value: Variant = flow_owner.call("get_reward_pick_context")
	var context: Dictionary = context_value if context_value is Dictionary else {}
	if context.is_empty():
		return false
	var offer: Dictionary = _offer_builder.build_offer(context, owner, registry, roll_overrides)
	if not bool(offer.get("accepted", false)):
		return false
	_owner = owner
	_registry = registry
	_flow_owner = flow_owner
	_runtime_state = _get_registry_instance(registry, "runtime_perk_state")
	_card_renderer = _get_registry_instance(registry, "runtime_perk_overlay_renderer")
	_icon_renderer = _get_registry_instance(registry, "runtime_perk_icon_renderer")
	if _runtime_state == null or _card_renderer == null:
		reset()
		return false
	_offer = offer.duplicate(true)
	choices.assign(_dictionary_array(offer.get("choices", [])))
	if choices.size() != TowerRewardPickOfferBuilder.CARD_COUNT:
		reset()
		return false
	spent_flags.clear()
	for _index in range(choices.size()):
		spent_flags.append(false)
	selected_index = 0
	animation_time = 0.0
	_status_text = TowerRewardPickLocalization.text("hint")
	_finish_callback = finish_callback
	_pending_external_kind = ""
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()
	purchase_absorption_effects.clear()
	_prewarm_card_assets()
	active = true
	return true


func reset() -> void:
	active = false
	animation_time = 0.0
	selected_index = 0
	choices.clear()
	spent_flags.clear()
	purchase_absorption_effects.clear()
	_offer.clear()
	_status_text = ""
	_finish_callback = Callable()
	_pending_external_kind = ""
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()
	_owner = null
	_registry = null
	_flow_owner = null
	_runtime_state = null
	_card_renderer = null
	_icon_renderer = null


func update(delta: float) -> void:
	if not active:
		return
	animation_time = minf(1.0, animation_time + maxf(0.0, delta))
	_update_external_modal_return()
	if not is_external_modal_active():
		_update_purchase_absorption_effects(delta)


func handle_input(event: InputEvent, view_size: Vector2 = VIEW_SIZE) -> bool:
	if not active or is_external_modal_active():
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		if key.keycode in [KEY_LEFT, KEY_A] or key.physical_keycode in [KEY_LEFT, KEY_A]:
			_move_selection(-1)
			return true
		if key.keycode in [KEY_RIGHT, KEY_D] or key.physical_keycode in [KEY_RIGHT, KEY_D]:
			_move_selection(1)
			return true
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_purchase(selected_index)
			return true
		if key.keycode in [KEY_SPACE, KEY_ESCAPE] or key.physical_keycode in [KEY_SPACE, KEY_ESCAPE]:
			_finish()
			return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return false
		var index := get_card_index_at(mouse.position, view_size)
		if index >= 0:
			selected_index = index
			_purchase(index)
			return true
		if get_continue_rect(view_size).has_point(mouse.position):
			_finish()
			return true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return false
		var index := get_card_index_at(touch.position, view_size)
		if index >= 0:
			selected_index = index
			_purchase(index)
			return true
		if get_continue_rect(view_size).has_point(touch.position):
			_finish()
			return true
	return false


func draw(canvas: CanvasItem, view_size: Vector2 = VIEW_SIZE) -> void:
	if not active or _card_renderer == null:
		return
	if _card_renderer.has_method("draw_tower_reward_pick"):
		_card_renderer.call(
			"draw_tower_reward_pick",
			canvas,
			build_view_model(view_size),
			_runtime_state,
			_icon_renderer,
			view_size
		)


func build_view_model(view_size: Vector2 = VIEW_SIZE) -> Dictionary:
	var balances := _get_balances()
	var model_choices: Array[Dictionary] = []
	for index in range(choices.size()):
		var choice := choices[index].duplicate(true)
		var cost := int(choice.get("reward_pick_cost", 0))
		var absorption: Dictionary = _get_purchase_absorption_for_slot(index)
		choice["reward_pick_spent"] = spent_flags[index]
		choice["reward_pick_absorbing"] = not absorption.is_empty()
		choice["reward_pick_empty"] = spent_flags[index] and absorption.is_empty()
		choice["reward_pick_enabled"] = (
			not spent_flags[index]
			and int(balances.get("muhon", 0)) >= cost
		)
		model_choices.append(choice)
	return {
		"title": TowerRewardPickLocalization.text("title"),
		"continue_text": TowerRewardPickLocalization.text("continue"),
		"balance_text": TowerRewardPickLocalization.text(
			"balance",
			{"amount": int(balances.get("muhon", 0))}
		),
		"spent_text": TowerRewardPickLocalization.text("spent"),
		"status_text": _status_text,
		"choices": model_choices,
		"spent_flags": spent_flags.duplicate(),
		"selected_index": selected_index,
		"animation_time": animation_time,
		"purchase_absorption_effects": _build_purchase_absorption_view_models(view_size),
		"layout": _layout.build_layout(view_size, choices.size(), false),
		"card_rects": get_card_rects(view_size),
		"continue_rect": get_continue_rect(view_size),
	}


func get_card_rects(view_size: Vector2 = VIEW_SIZE) -> Array:
	return _layout.get_card_rects(view_size, choices.size(), animation_time, false)


func get_card_index_at(position: Vector2, view_size: Vector2 = VIEW_SIZE) -> int:
	return _layout.get_card_index_at(
		position,
		view_size,
		choices.size(),
		animation_time,
		false
	)


func get_continue_rect(view_size: Vector2 = VIEW_SIZE) -> Rect2:
	return Rect2(
		Vector2((view_size.x - CONTINUE_SIZE.x) * 0.5, view_size.y - CONTINUE_BOTTOM_MARGIN - CONTINUE_SIZE.y),
		CONTINUE_SIZE
	)


func is_external_modal_active() -> bool:
	var mythic_item_runtime := _get_registry_instance(_registry, "mythic_item_runtime")
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		and bool(mythic_item_runtime.call("is_acquisition_cinematic_active"))
	):
		return true
	if _pending_external_kind == "fusion":
		return (
			_runtime_state != null
			and _runtime_state.has_method("is_perk_fusion_modal_active")
			and bool(_runtime_state.call("is_perk_fusion_modal_active"))
		)
	if _pending_external_kind == "vision_swap":
		return (
			_runtime_state != null
			and _runtime_state.has_method("has_pending_unlock_swap")
			and bool(_runtime_state.call("has_pending_unlock_swap"))
		)
	return false


func _move_selection(direction: int) -> void:
	if choices.is_empty() or direction == 0:
		return
	selected_index = posmod(selected_index + signi(direction), choices.size())


func _purchase(index: int) -> void:
	if index < 0 or index >= choices.size() or spent_flags[index]:
		return
	var choice := choices[index]
	var cost := maxi(0, int(choice.get("reward_pick_cost", 0)))
	var balances := _get_balances()
	if int(balances.get("muhon", 0)) < cost:
		_status_text = TowerRewardPickLocalization.text("insufficient")
		return
	if str(choice.get("reward_pick_kind", "")) == "vision" and bool(choice.get("vision_swap_required", false)):
		_begin_vision_swap(index, choice)
		return
	_pending_slot_index = index
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_purchase",
		index,
		choice,
		cost,
		Callable(self, "_grant_choice").bind(choice),
		Callable(self, "_rollback_choice")
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_status_text = str(result.get("reason", "reward_pick_purchase_failed"))
		_pending_slot_index = -1
		return
	_commit_purchased_slot(index, choice)


func _grant_choice(choice: Dictionary) -> bool:
	_capture_runtime_snapshot()
	var kind := str(choice.get("reward_pick_kind", ""))
	if kind == "fusion":
		if not _runtime_state.has_method("begin_tower_reward_fusion_modal"):
			return false
		var started := bool(_runtime_state.call(
			"begin_tower_reward_fusion_modal",
			choice,
			_registry
		))
		if started:
			_pending_external_kind = "fusion"
		return started
	var previous_context: Dictionary = {}
	var context_value: Variant = _runtime_state.get("current_choice_context")
	if context_value is Dictionary:
		previous_context = (context_value as Dictionary).duplicate(true)
	_runtime_state.set("current_choice_context", {
		"source": "tower_reward_pick",
		"grant_scope": "tower_run",
	})
	var accepted := bool(_runtime_state.call("apply_choice", choice, _owner, _registry))
	_runtime_state.set("current_choice_context", previous_context)
	return accepted


func _rollback_choice() -> void:
	if _runtime_state != null and _runtime_state.has_method("cancel_pending_unlock_swap"):
		_runtime_state.call("cancel_pending_unlock_swap", _owner)
	_restore_runtime_snapshot()
	_cleanup_external_runtime_modal()


func _begin_vision_swap(index: int, choice: Dictionary) -> void:
	if _runtime_state == null or not _runtime_state.has_method("begin_tower_reward_unlock_swap"):
		return
	_capture_runtime_snapshot()
	_pending_slot_index = index
	if bool(_runtime_state.call(
		"begin_tower_reward_unlock_swap",
		choice,
		_owner,
		_registry
	)):
		_pending_external_kind = "vision_swap"
		return
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()


func _update_external_modal_return() -> void:
	if _pending_external_kind.is_empty() or is_external_modal_active():
		return
	if _pending_external_kind == "fusion":
		_cleanup_external_runtime_modal()
		_pending_external_kind = ""
		_pending_slot_index = -1
		_pending_runtime_snapshot.clear()
		return
	if _pending_external_kind != "vision_swap":
		return
	var index := _pending_slot_index
	var choice := choices[index] if index >= 0 and index < choices.size() else {}
	var boss_slot_id := str(choice.get("boss_slot_id", ""))
	var runtime_levels_value: Variant = _runtime_state.get("runtime_skill_levels")
	var runtime_levels: Dictionary = runtime_levels_value if runtime_levels_value is Dictionary else {}
	var confirmed := TowerAscentBossRewardCatalog.is_owned(runtime_levels, boss_slot_id)
	_cleanup_external_runtime_modal()
	_pending_external_kind = ""
	if not confirmed:
		_pending_slot_index = -1
		_pending_runtime_snapshot.clear()
		return
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_purchase",
		index,
		choice,
		int(choice.get("reward_pick_cost", 0)),
		Callable(self, "_accept_existing_external_effect"),
		Callable(self, "_restore_runtime_snapshot")
	)
	if bool(result.get("accepted", false)) and bool(result.get("applied", false)):
		_commit_purchased_slot(index, choice)
	else:
		_restore_runtime_snapshot()
		_status_text = str(result.get("reason", "vision_swap_purchase_failed"))
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()


func _accept_existing_external_effect() -> bool:
	return true


func _commit_purchased_slot(index: int, choice: Dictionary) -> void:
	spent_flags[index] = true
	_start_purchase_absorption(index)
	if str(choice.get("reward_pick_kind", "")) == "vision":
		_flow_owner.call("mark_reward_pick_vision_burned", str(choice.get("boss_slot_id", "")))
	_status_text = TowerRewardPickLocalization.text("spent")
	_pending_runtime_snapshot.clear()
	if str(choice.get("reward_pick_kind", "")) != "fusion":
		_pending_slot_index = -1
	_select_next_available_slot(index)


func _start_purchase_absorption(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	purchase_absorption_effects.append({
		"slot_index": index,
		"elapsed": 0.0,
		"duration": TEMP_REWARD_PICK_ABSORB_DURATION_SEC,
	})


func _update_purchase_absorption_effects(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	for effect_index in range(purchase_absorption_effects.size() - 1, -1, -1):
		var effect: Dictionary = purchase_absorption_effects[effect_index]
		var duration: float = maxf(0.001, float(effect.get("duration", TEMP_REWARD_PICK_ABSORB_DURATION_SEC)))
		effect["elapsed"] = float(effect.get("elapsed", 0.0)) + safe_delta
		if float(effect.get("elapsed", 0.0)) >= duration:
			purchase_absorption_effects.remove_at(effect_index)
		else:
			purchase_absorption_effects[effect_index] = effect


func _get_purchase_absorption_for_slot(index: int) -> Dictionary:
	for effect in purchase_absorption_effects:
		if int(effect.get("slot_index", -1)) == index:
			return effect
	return {}


func _build_purchase_absorption_view_models(view_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target: Vector2 = _get_player_absorption_target(view_size)
	for effect in purchase_absorption_effects:
		var duration: float = maxf(0.001, float(effect.get("duration", TEMP_REWARD_PICK_ABSORB_DURATION_SEC)))
		result.append({
			"slot_index": int(effect.get("slot_index", -1)),
			"progress": clampf(float(effect.get("elapsed", 0.0)) / duration, 0.0, 1.0),
			"target_pos": target,
		})
	return result


func _get_player_absorption_target(view_size: Vector2) -> Vector2:
	var fallback := Vector2(view_size.x * 0.5, view_size.y * 0.91)
	if _owner == null:
		return fallback
	var position_value: Variant = _owner.get("player_pos")
	if not (position_value is Vector2):
		return fallback
	var position := position_value as Vector2
	var width: float = maxf(1.0, float(_owner.get("player_paddle_width")))
	var height: float = maxf(1.0, float(_owner.get("player_paddle_height")))
	var target := position + Vector2(width * 0.5, height * 0.35)
	if target.x < 0.0 or target.x > view_size.x or target.y < 0.0 or target.y > view_size.y:
		return fallback
	return target


func _select_next_available_slot(purchased_index: int) -> void:
	if spent_flags.is_empty():
		return
	for offset in range(1, spent_flags.size() + 1):
		var candidate: int = posmod(purchased_index + offset, spent_flags.size())
		if not spent_flags[candidate]:
			selected_index = candidate
			return


func _finish() -> void:
	if not active or is_external_modal_active():
		return
	var vision_boss_slot_id := ""
	if not str(_offer.get("vision_unlock_id", "")).is_empty():
		vision_boss_slot_id = str(_offer.get("boss_slot_id", ""))
	var result: Dictionary = _flow_owner.call(
		"finalize_reward_pick",
		vision_boss_slot_id
	)
	if not bool(result.get("accepted", false)):
		_status_text = str(result.get("reason", "reward_pick_finish_failed"))
		return
	var callback := _finish_callback
	reset()
	if callback.is_valid():
		callback.call()


func _capture_runtime_snapshot() -> void:
	_pending_runtime_snapshot.clear()
	if _runtime_state != null and _runtime_state.has_method("build_unlock_save_snapshot"):
		var value: Variant = _runtime_state.call("build_unlock_save_snapshot")
		if value is Dictionary:
			_pending_runtime_snapshot = (value as Dictionary).duplicate(true)


func _restore_runtime_snapshot() -> void:
	if (
		_pending_runtime_snapshot.is_empty()
		or _runtime_state == null
		or not _runtime_state.has_method("apply_unlock_save_snapshot")
	):
		return
	_runtime_state.call(
		"apply_unlock_save_snapshot",
		_pending_runtime_snapshot,
		_owner,
		_registry
	)


func _cleanup_external_runtime_modal() -> void:
	if _runtime_state != null and _runtime_state.has_method("end_tower_reward_external_modal"):
		_runtime_state.call("end_tower_reward_external_modal", _owner)


func _get_balances() -> Dictionary:
	if _flow_owner != null and _flow_owner.has_method("get_run_state_snapshot"):
		var value: Variant = _flow_owner.call("get_run_state_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _prewarm_card_assets() -> void:
	if _card_renderer != null and _card_renderer.has_method("prewarm_traditional_choice_assets"):
		_card_renderer.call("prewarm_traditional_choice_assets")
	if _icon_renderer != null and _icon_renderer.has_method("prewarm_assets"):
		_icon_renderer.call("prewarm_assets")


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null
