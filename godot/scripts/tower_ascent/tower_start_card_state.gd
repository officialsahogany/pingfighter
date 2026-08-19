extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerStartCardOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerStartCardLocalization := preload(
	"res://scripts/tower_ascent/tower_start_card_localization.gd"
)
const RuntimePerkChoiceLayout := preload(
	"res://scripts/characters/runtime_perk_choice_layout.gd"
)

var _offer_builder: Object = TowerStartCardOfferBuilder.new()
var _owner: Object = null
var _registry: Object = null
var _runtime_state: Object = null
var _flow_owner: Object = null
var _catalog: Object = null
var _card_renderer: Object = null
var _icon_renderer: Object = null
var _active := false
var _completed := false
var _skipped := false
var _elapsed_sec := 0.0
var _absorb_elapsed_sec := -1.0
var _picks_remaining := 0
var _card_choices: Array[Dictionary] = []
var _selection_result: Dictionary = {}
var _cold_build_msec := 0.0
var _selected_index := 0
var _hover_mouse_pos := Vector2(-1.0, -1.0)
var _status_text := ""
var _stats_band_enabled := false
var _session_id := 0
var _current_perk_slot_status: Dictionary = {}
var _layout: Object = RuntimePerkChoiceLayout.new()
var _stats_owner: Object = null
var _stats_registry: Object = null


func begin(owner: Object, registry: Object) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if _active:
		return true
	if not _consume_entry_request(owner):
		return false
	tear_down()
	_owner = owner
	_registry = registry
	_runtime_state = _get_registry_instance(registry, "runtime_perk_state")
	_catalog = _get_registry_instance(registry, "runtime_perk_catalog")
	_card_renderer = _get_registry_instance(registry, "runtime_perk_overlay_renderer")
	_icon_renderer = _get_registry_instance(registry, "runtime_perk_icon_renderer")
	_flow_owner = _get_registry_instance(registry, "tower_ascent_flow_owner")
	var run_id := ""
	if _flow_owner != null and _flow_owner.has_method("get_run_id"):
		run_id = str(_flow_owner.call("get_run_id"))
	if (
		run_id.is_empty()
		or _flow_owner == null
		or not _flow_owner.has_method("record_start_card_result")
	):
		_completed = true
		_skipped = true
		_selection_result = {
			"accepted": false,
			"reason": "missing_start_card_progress_owner",
			"skipped": true,
		}
		return false
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
	_selected_index = 0
	_status_text = TowerStartCardLocalization.text("instruction")
	_session_id += 1
	_refresh_perk_slot_status()
	_prewarm_card_assets()
	return true


func handle_input(event: InputEvent, owner: Object, registry: Object) -> bool:
	if not _active:
		return false
	var view_size := _get_view_size(owner)
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_mouse_pos = motion.position
		var hover_index := get_card_index_at(motion.position, view_size)
		if hover_index >= 0 and _picks_remaining > 0:
			_selected_index = hover_index
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var mouse_index := get_card_index_at(mouse.position, view_size)
			if mouse_index >= 0:
				_selected_index = mouse_index
				select_slot(mouse_index)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_hover_mouse_pos = touch.position
			var touch_index := get_card_index_at(touch.position, view_size)
			if touch_index >= 0:
				_selected_index = touch_index
				select_slot(touch_index)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var slot_index := -1
			if key_event.keycode in [KEY_LEFT, KEY_A] or key_event.physical_keycode in [KEY_LEFT, KEY_A]:
				_selected_index = wrapi(_selected_index - 1, 0, _card_choices.size())
			elif key_event.keycode in [KEY_RIGHT, KEY_D] or key_event.physical_keycode in [KEY_RIGHT, KEY_D]:
				_selected_index = wrapi(_selected_index + 1, 0, _card_choices.size())
			elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER] or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
				slot_index = _selected_index
			match key_event.keycode:
				KEY_1:
					slot_index = 0
				KEY_2:
					slot_index = 1
				KEY_3:
					slot_index = 2
			if slot_index >= 0:
				_selected_index = slot_index
				select_slot(slot_index)
	capture_stats_context(owner, registry)
	_request_redraw(owner)
	return true


func update(delta: float) -> void:
	if not _active:
		return
	capture_stats_context(_owner, _registry)
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
	for choice_index in range(_card_choices.size()):
		var choice := _card_choices[choice_index]
		choice["enabled"] = false
		choice["start_card_selected"] = choice_index == index
	var selected := _card_choices[index].duplicate(true)
	var accepted := _apply_choice(selected)
	var pending_swap_started := _has_pending_unlock_swap()
	if pending_swap_started:
		if _runtime_state != null and _runtime_state.has_method("cancel_pending_unlock_swap"):
			_runtime_state.call("cancel_pending_unlock_swap", _owner)
		accepted = false
	var offer_ids := _get_offer_ids()
	var progress_result := {
		"consumed": true,
		"picked_perk_id": str(selected.get("id", "")),
		"picked_kind": str(selected.get("start_card_kind", "")),
		"offer_ids": offer_ids,
	}
	var progress_record_failed := false
	if accepted:
		accepted = bool(_flow_owner.call("record_start_card_result", progress_result))
		if not accepted:
			progress_record_failed = true
			push_error("[TowerStartCard] applied choice could not be recorded in run_progress")
	_selection_result = {
		"accepted": accepted,
		"reason": (
			"applied"
			if accepted
			else "start_card_progress_record_failed" if progress_record_failed else "start_card_grant_failed"
		),
		"skipped": not accepted,
		"picked_perk_id": str(selected.get("id", "")) if accepted else "",
		"picked_kind": str(selected.get("start_card_kind", "")) if accepted else "",
		"offer_ids": offer_ids if accepted else PackedStringArray(),
		"pending_swap_started": pending_swap_started,
	}
	if accepted:
		_absorb_elapsed_sec = 0.0
		_status_text = TowerStartCardLocalization.text("confirmed")
		_refresh_perk_slot_status()
	else:
		_skipped = true
		_finish_phase()
	return accepted


func draw(
	canvas: CanvasItem,
	_owner_override: Object,
	_registry_override: Object,
	view_size: Vector2
) -> void:
	if not _active or canvas == null:
		return
	if _card_renderer == null or not _card_renderer.has_method("draw_tower_start_card"):
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK, true)
		return
	_card_renderer.call(
		"draw_tower_start_card",
		canvas,
		build_view_model(view_size),
		_runtime_state,
		_catalog,
		_icon_renderer,
		view_size,
		_build_runtime_snapshot(),
		_hover_mouse_pos
	)


func build_view_model(view_size: Vector2) -> Dictionary:
	var layout := _build_layout(view_size)
	return {
		"title": TowerStartCardLocalization.text("title"),
		"status_text": _status_text,
		"choices": _card_choices.duplicate(true),
		"selected_index": _selected_index,
		"animation_time": _elapsed_sec,
		"absorb_elapsed_sec": _absorb_elapsed_sec,
		"absorb_duration_sec": TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC,
		"layout": layout,
		"card_rects": get_card_rects(view_size),
		"stats_band_enabled": (
			_stats_band_enabled
			and (layout.get("stats_rect", Rect2()) as Rect2).size.y > 0.0
		),
		"start_card_session_id": _session_id,
	}


func get_card_rects(view_size: Vector2) -> Array:
	return _layout.get_card_rects(
		view_size,
		_card_choices.size(),
		_elapsed_sec,
		_stats_band_enabled,
		-1.0,
		TowerAscentTuning.TEMP_START_CARD_FOOTER_RESERVE_PX
	)


func get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	return _layout.get_card_index_at(
		position,
		view_size,
		_card_choices.size(),
		_elapsed_sec,
		_stats_band_enabled,
		-1.0,
		TowerAscentTuning.TEMP_START_CARD_FOOTER_RESERVE_PX
	)


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
		"owner_attached": _owner != null,
		"registry_attached": _registry != null,
		"stats_owner_attached": _stats_owner != null,
		"stats_registry_attached": _stats_registry != null,
	}


func capture_stats_context(owner: Object, registry: Object) -> bool:
	_capture_stats_context(owner, registry)
	if _runtime_state == null or not _runtime_state.has_method("capture_stats_context"):
		_stats_band_enabled = false
		return false
	_stats_band_enabled = bool(_runtime_state.call("capture_stats_context", owner, registry))
	return _stats_band_enabled


func tear_down() -> void:
	capture_stats_context(null, null)
	_owner = null
	_registry = null
	_runtime_state = null
	_flow_owner = null
	_catalog = null
	_card_renderer = null
	_icon_renderer = null
	_active = false
	_completed = false
	_skipped = false
	_elapsed_sec = 0.0
	_absorb_elapsed_sec = -1.0
	_picks_remaining = 0
	_card_choices.clear()
	_selection_result.clear()
	_cold_build_msec = 0.0
	_selected_index = 0
	_hover_mouse_pos = Vector2(-1.0, -1.0)
	_status_text = ""
	_stats_band_enabled = false
	_current_perk_slot_status.clear()


func _apply_choice(choice: Dictionary) -> bool:
	if _runtime_state == null:
		return false
	var previous_context: Dictionary = {}
	var context_value: Variant = _runtime_state.get("current_choice_context")
	if context_value is Dictionary:
		previous_context = (context_value as Dictionary).duplicate(true)
	_runtime_state.set("current_choice_context", {
		"source": "tower_start_card",
		"grant_scope": "tower_run",
	})
	var accepted := false
	if str(choice.get("start_card_kind", "")) == "mugong":
		if _runtime_state.has_method("apply_choice_at_target_level"):
			accepted = bool(_runtime_state.call(
				"apply_choice_at_target_level",
				choice,
				TowerAscentTuning.TEMP_START_CARD_MUGONG_START_LEVEL,
				_owner,
				_registry
			))
	else:
		if _runtime_state.has_method("apply_choice"):
			accepted = bool(_runtime_state.call("apply_choice", choice, _owner, _registry))
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


func _consume_entry_request(owner: Object) -> bool:
	if owner == null or not owner.has_method("get_node_or_null"):
		return false
	var selection_state: Object = owner.call("get_node_or_null", "/root/GameSelectionState")
	return (
		selection_state != null
		and selection_state.has_method("consume_tower_start_card_entry_request")
		and bool(selection_state.call("consume_tower_start_card_entry_request"))
	)


func _capture_stats_context(owner: Object, registry: Object) -> void:
	_stats_owner = owner
	_stats_registry = registry


func _request_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _build_layout(view_size: Vector2) -> Dictionary:
	return _layout.build_layout(
		view_size,
		_card_choices.size(),
		_stats_band_enabled,
		-1.0,
		TowerAscentTuning.TEMP_START_CARD_FOOTER_RESERVE_PX
	)


func _build_runtime_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	if _runtime_state != null and _runtime_state.has_method("get_snapshot"):
		var snapshot_value: Variant = _runtime_state.call("get_snapshot")
		if snapshot_value is Dictionary:
			snapshot = (snapshot_value as Dictionary).duplicate(true)
	if not snapshot.has("runtime_skill_levels"):
		snapshot["runtime_skill_levels"] = _get_runtime_skill_levels()
	if not snapshot.has("physique_training"):
		var training_snapshot: Dictionary = {}
		if _runtime_state != null and _runtime_state.has_method("get_physique_training_snapshot"):
			var training_value: Variant = _runtime_state.call("get_physique_training_snapshot")
			if training_value is Dictionary:
				training_snapshot = (training_value as Dictionary).duplicate(true)
		snapshot["physique_training"] = training_snapshot
	snapshot["perk_slot_status"] = _current_perk_slot_status.duplicate(true)
	snapshot["perk_slot_status_cached"] = true
	return snapshot


func _get_runtime_skill_levels() -> Dictionary:
	if _runtime_state == null:
		return {}
	var levels_value: Variant = _runtime_state.get("runtime_skill_levels")
	return (
		(levels_value as Dictionary).duplicate(true)
		if levels_value is Dictionary
		else {}
	)


func _refresh_perk_slot_status() -> void:
	_current_perk_slot_status.clear()
	if _catalog == null or not _catalog.has_method("get_perk_slot_status"):
		return
	var status_value: Variant = _catalog.call(
		"get_perk_slot_status",
		_get_runtime_skill_levels(),
		_registry
	)
	if status_value is Dictionary:
		_current_perk_slot_status = (status_value as Dictionary).duplicate(true)


func _prewarm_card_assets() -> void:
	if _card_renderer != null and _card_renderer.has_method("prewarm_traditional_choice_assets"):
		_card_renderer.call("prewarm_traditional_choice_assets")
	if _icon_renderer != null and _icon_renderer.has_method("prewarm_assets"):
		_icon_renderer.call("prewarm_assets")


func _get_offer_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for choice in _card_choices:
		var perk_id := str(choice.get("id", "")).strip_edges()
		if not perk_id.is_empty() and not result.has(perk_id):
			result.append(perk_id)
	return result


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		var rect_value: Variant = owner.call("get_viewport_rect")
		if rect_value is Rect2 and (rect_value as Rect2).size.x > 0.0:
			return (rect_value as Rect2).size
	return Vector2(760.0, 750.0)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or key.is_empty():
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null
