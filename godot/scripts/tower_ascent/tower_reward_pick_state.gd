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
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const RuntimePerkChoiceLayout := preload(
	"res://scripts/characters/runtime_perk_choice_layout.gd"
)
const TowerCardAbsorptionTargetResolver := preload(
	"res://scripts/tower_ascent/tower_card_absorption_target_resolver.gd"
)
const RuntimePerkOverflowDescriptions := preload(
	"res://scripts/characters/runtime_perk_overflow_descriptions.gd"
)

const VIEW_SIZE := Vector2(760.0, 750.0)
const CONTINUE_SIZE := Vector2(220.0, 42.0)
const CONTINUE_BOTTOM_MARGIN := 34.0
const TEMP_REWARD_PICK_ABSORB_DURATION_SEC := 0.78
const TEMP_REWARD_PICK_PANEL_GAP_PX := 32.0
const DISABLED_REASON_INSUFFICIENT_MUHON := "insufficient_muhon"
const DISABLED_REASON_PERK_SLOT_LIMIT := "perk_slot_limit"
const UPGRADE_BASE_COST := 3
const UPGRADE_COST_STEP := 1
const MODE_BOARD := "board"
const MODE_UPGRADE := "upgrade"
const MODE_MUGONG_REPLACE := "mugong_replace"

var active := false
var animation_time := 0.0
var selected_index := 0
var choices: Array[Dictionary] = []
var spent_flags: Array[bool] = []
var purchase_absorption_effects: Array[Dictionary] = []
var stats_band_enabled := false
var reward_hover_mouse_pos := Vector2(-1.0, -1.0)

var _owner: Object = null
var _registry: Object = null
var _flow_owner: Object = null
var _runtime_state: Object = null
var _catalog: Object = null
var _card_renderer: Object = null
var _icon_renderer: Object = null
var _chosik_tooltip_renderer: Object = null
var _finish_callback: Callable = Callable()
var _offer: Dictionary = {}
var _victory_margin_reward: Dictionary = {}
var _status_text := ""
var _layout: Object = RuntimePerkChoiceLayout.new()
var _offer_builder: Object = TowerRewardPickOfferBuilder.new()
var _pending_external_kind := ""
var _pending_slot_index := -1
var _pending_runtime_snapshot: Dictionary = {}
var _auto_finish_hold_elapsed := 0.0
var _auto_finish_pending := false
var _auto_finish_attempted := false
var _current_perk_slot_status: Dictionary = {}
var _perk_slot_status_dirty := false
var _reward_session_id := 0
var _absorption_target_resolver: Object = TowerCardAbsorptionTargetResolver.new()
var _roll_overrides: Dictionary = {}
var _reroll_counter := 0
var _offered_vision_boss_slot_id := ""
var _upgrade_purchase_count := 0
var _mode := MODE_BOARD
var _upgrade_perk_id := ""
var _upgrade_show_all_levels := false
var _replacement_slot_index := -1
var _replacement_choice: Dictionary = {}
var _replacement_candidates: Array[Dictionary] = []
var _replacement_selected_index := 0


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
	var offer: Dictionary = _offer_builder.build_offer(context, owner, registry, roll_overrides, 0)
	if not bool(offer.get("accepted", false)):
		return false
	_owner = owner
	_registry = registry
	_flow_owner = flow_owner
	_runtime_state = _get_registry_instance(registry, "runtime_perk_state")
	_catalog = _get_registry_instance(registry, "runtime_perk_catalog")
	_card_renderer = _get_registry_instance(registry, "runtime_perk_overlay_renderer")
	_icon_renderer = _get_registry_instance(registry, "runtime_perk_icon_renderer")
	_chosik_tooltip_renderer = _get_registry_instance(registry, "smasher_skill_orb_tooltip_renderer")
	if _runtime_state == null or _card_renderer == null:
		reset()
		return false
	_offer = offer.duplicate(true)
	_roll_overrides = roll_overrides.duplicate(true)
	_reroll_counter = maxi(0, int(offer.get("offer_generation", 0)))
	_offered_vision_boss_slot_id = ""
	_track_offered_vision(offer)
	_upgrade_purchase_count = 0
	_clear_inline_modal()
	var margin_reward_value: Variant = context.get("victory_margin_reward", {})
	_victory_margin_reward = (
		(margin_reward_value as Dictionary).duplicate(true)
		if margin_reward_value is Dictionary
		else {}
	)
	choices.assign(_dictionary_array(offer.get("choices", [])))
	if choices.is_empty() or choices.size() > TowerRewardPickOfferBuilder.CARD_COUNT:
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
	_auto_finish_hold_elapsed = 0.0
	_auto_finish_pending = false
	_auto_finish_attempted = false
	stats_band_enabled = false
	reward_hover_mouse_pos = Vector2(-1.0, -1.0)
	_reward_session_id += 1
	_perk_slot_status_dirty = true
	_refresh_perk_slot_status_if_needed()
	purchase_absorption_effects.clear()
	_prewarm_card_assets()
	active = true
	return true


func reset() -> void:
	if _runtime_state != null and _runtime_state.has_method("capture_stats_context"):
		_runtime_state.call("capture_stats_context", null, null)
	active = false
	animation_time = 0.0
	selected_index = 0
	choices.clear()
	spent_flags.clear()
	purchase_absorption_effects.clear()
	_offer.clear()
	_victory_margin_reward.clear()
	_status_text = ""
	_finish_callback = Callable()
	_pending_external_kind = ""
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()
	_auto_finish_hold_elapsed = 0.0
	_auto_finish_pending = false
	_auto_finish_attempted = false
	stats_band_enabled = false
	reward_hover_mouse_pos = Vector2(-1.0, -1.0)
	_current_perk_slot_status.clear()
	_perk_slot_status_dirty = false
	_owner = null
	_registry = null
	_flow_owner = null
	_runtime_state = null
	_catalog = null
	_card_renderer = null
	_icon_renderer = null
	_chosik_tooltip_renderer = null
	_roll_overrides.clear()
	_reroll_counter = 0
	_offered_vision_boss_slot_id = ""
	_upgrade_purchase_count = 0
	_clear_inline_modal()


func _clear_inline_modal() -> void:
	_mode = MODE_BOARD
	_upgrade_perk_id = ""
	_upgrade_show_all_levels = false
	_replacement_slot_index = -1
	_replacement_choice.clear()
	_replacement_candidates.clear()
	_replacement_selected_index = 0


func _track_offered_vision(offer: Dictionary) -> void:
	if not str(offer.get("vision_unlock_id", "")).strip_edges().is_empty():
		_offered_vision_boss_slot_id = str(offer.get("boss_slot_id", "")).strip_edges()


func update(delta: float) -> void:
	if not active:
		return
	stats_band_enabled = _capture_stats_context()
	if _auto_finish_pending:
		_auto_finish_pending = false
		if _can_auto_finish():
			_auto_finish_attempted = true
			_finish()
			if not active:
				return
	animation_time = minf(1.0, animation_time + maxf(0.0, delta))
	_update_external_modal_return()
	if _mode == MODE_BOARD and not is_external_modal_active():
		_refresh_perk_slot_status_if_needed()
		var had_absorption_effects := not purchase_absorption_effects.is_empty()
		_update_purchase_absorption_effects(delta)
		_update_auto_finish_hold(delta, had_absorption_effects)
	else:
		_reset_auto_finish_hold()


func handle_input(event: InputEvent, view_size: Vector2 = VIEW_SIZE) -> bool:
	if not active or is_external_modal_active():
		return false
	if _mode == MODE_UPGRADE:
		return _handle_upgrade_input(event, view_size)
	if _mode == MODE_MUGONG_REPLACE:
		return _handle_mugong_replace_input(event, view_size)
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		reward_hover_mouse_pos = motion.position
		var hover_index := get_card_index_at(motion.position, view_size)
		if hover_index >= 0:
			selected_index = hover_index
		return hover_index >= 0 or not _get_status_cell_at(motion.position, view_size).is_empty()
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
			_purchase(selected_index, view_size)
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
			_purchase(index, view_size)
			return true
		var status_cell := _get_status_cell_at(mouse.position, view_size)
		if not status_cell.is_empty():
			_open_upgrade_modal(status_cell)
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
			_purchase(index, view_size)
			return true
		var status_cell := _get_status_cell_at(touch.position, view_size)
		if not status_cell.is_empty():
			_open_upgrade_modal(status_cell)
			return true
		if get_continue_rect(view_size).has_point(touch.position):
			_finish()
			return true
	return false


func draw(canvas: CanvasItem, view_size: Vector2 = VIEW_SIZE) -> void:
	if not active or _card_renderer == null:
		return
	if _card_renderer.has_method("draw_tower_reward_pick"):
		var snapshot := _build_reward_runtime_snapshot()
		_card_renderer.call(
			"draw_tower_reward_pick",
			canvas,
			build_view_model(view_size),
			_runtime_state,
			_catalog,
			_icon_renderer,
			view_size,
			snapshot,
			reward_hover_mouse_pos
		)


func build_view_model(view_size: Vector2 = VIEW_SIZE) -> Dictionary:
	var balances := _get_balances()
	var layout := _build_reward_layout(view_size)
	var model_choices: Array[Dictionary] = []
	for index in range(choices.size()):
		var choice := choices[index].duplicate(true)
		var absorption: Dictionary = _get_purchase_absorption_for_slot(index)
		var disabled_reason := _get_purchase_disabled_reason(index, choice, balances)
		choice["reward_pick_spent"] = spent_flags[index]
		choice["reward_pick_absorbing"] = not absorption.is_empty()
		choice["reward_pick_empty"] = spent_flags[index] and absorption.is_empty()
		choice["reward_pick_enabled"] = disabled_reason.is_empty()
		choice["reward_pick_disabled_reason"] = disabled_reason
		model_choices.append(choice)
	return {
		"title": TowerRewardPickLocalization.text("title"),
		"continue_text": TowerRewardPickLocalization.text("continue"),
		"balance_text": TowerRewardPickLocalization.text(
			"balance",
			{"amount": int(balances.get("muhon", 0))}
		),
		"acquisition_text": _get_victory_margin_reward_text(),
		"spent_text": TowerRewardPickLocalization.text("spent"),
		"status_text": _status_text,
		"choices": model_choices,
		"spent_flags": spent_flags.duplicate(),
		"selected_index": selected_index,
		"animation_time": animation_time,
		"purchase_absorption_effects": _build_purchase_absorption_view_models(view_size),
		"layout": layout,
		"card_rects": get_card_rects(view_size),
		"continue_rect": get_continue_rect(view_size),
		"stats_band_enabled": (
			stats_band_enabled
			and (layout.get("stats_rect", Rect2()) as Rect2).size.y > 0.0
		),
		"reward_session_id": _reward_session_id,
		"chosik_tooltip_context": _build_chosik_tooltip_context(),
		"status_title": TowerRewardPickLocalization.text("owned_upgrade_title"),
		"status_upgrade_cta": TowerRewardPickLocalization.text("owned_upgrade_cta"),
		"status_max_rank_text": TowerRewardPickLocalization.text("upgrade_max_rank"),
		"inline_modal": _build_inline_modal_model(view_size),
	}


func _build_inline_modal_model(view_size: Vector2) -> Dictionary:
	if _mode == MODE_UPGRADE:
		return _build_upgrade_modal_model(view_size)
	if _mode == MODE_MUGONG_REPLACE:
		return _build_mugong_replace_modal_model(view_size)
	return {}


func _get_victory_margin_reward_text() -> String:
	var amount := maxi(0, int(_victory_margin_reward.get("amount", 0)))
	if amount <= 0:
		return ""
	return TowerRewardPickLocalization.text(
		"victory_margin_reward",
		{"amount": amount}
	)


func get_card_rects(view_size: Vector2 = VIEW_SIZE) -> Array:
	return _layout.get_card_rects(
		view_size,
		choices.size(),
		animation_time,
		stats_band_enabled,
		TEMP_REWARD_PICK_PANEL_GAP_PX,
		_get_reward_footer_reserve()
	)


func get_card_index_at(position: Vector2, view_size: Vector2 = VIEW_SIZE) -> int:
	return _layout.get_card_index_at(
		position,
		view_size,
		choices.size(),
		animation_time,
		stats_band_enabled,
		TEMP_REWARD_PICK_PANEL_GAP_PX,
		_get_reward_footer_reserve()
	)


func get_continue_rect(view_size: Vector2 = VIEW_SIZE) -> Rect2:
	var layout := _build_reward_layout(view_size)
	var hint_pos: Vector2 = layout.get(
		"hint_pos",
		Vector2(view_size.x * 0.5, view_size.y - CONTINUE_BOTTOM_MARGIN)
	)
	var bottom_bound := view_size.y - CONTINUE_BOTTOM_MARGIN - CONTINUE_SIZE.y
	var top := minf(hint_pos.y + 5.0, bottom_bound)
	return Rect2(
		Vector2((view_size.x - CONTINUE_SIZE.x) * 0.5, maxf(0.0, top)),
		CONTINUE_SIZE
	)


func _get_status_interaction_model(view_size: Vector2) -> Dictionary:
	if (
		_card_renderer == null
		or not _card_renderer.has_method("build_tower_reward_status_interaction_model")
	):
		return {}
	var reward_layout := _build_reward_layout(view_size)
	var panel_rect_value: Variant = reward_layout.get("panel_rect", Rect2())
	var panel_rect: Rect2 = panel_rect_value if panel_rect_value is Rect2 else Rect2()
	if not panel_rect.has_area():
		return {}
	var model_value: Variant = _card_renderer.call(
		"build_tower_reward_status_interaction_model",
		_runtime_state,
		_catalog,
		_build_reward_runtime_snapshot(),
		panel_rect,
		{}
	)
	return (
		(model_value as Dictionary).duplicate(true)
		if model_value is Dictionary
		else {}
	)


func _get_status_cell_at(position: Vector2, view_size: Vector2) -> Dictionary:
	if _card_renderer == null or not _card_renderer.has_method("get_tower_reward_status_cell_at"):
		return {}
	var cell_value: Variant = _card_renderer.call(
		"get_tower_reward_status_cell_at",
		_get_status_interaction_model(view_size),
		position,
		true
	)
	return (cell_value as Dictionary).duplicate(true) if cell_value is Dictionary else {}


func _open_upgrade_modal(status_cell: Dictionary) -> void:
	var perk_id := str(status_cell.get("canonical_id", "")).strip_edges()
	if perk_id.is_empty() or _catalog == null or not _catalog.has_method("get_perk_data"):
		return
	var data_value: Variant = _catalog.call("get_perk_data", perk_id)
	if not (data_value is Dictionary) or (data_value as Dictionary).is_empty():
		return
	_upgrade_perk_id = perk_id
	_upgrade_show_all_levels = false
	_mode = MODE_UPGRADE
	_reset_auto_finish_hold()
	reward_hover_mouse_pos = Vector2(-1.0, -1.0)


func _handle_upgrade_input(event: InputEvent, view_size: Vector2) -> bool:
	var modal_model := _build_upgrade_modal_model(view_size)
	if modal_model.is_empty():
		_clear_inline_modal()
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				_clear_inline_modal()
			elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_try_purchase_upgrade()
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_handle_upgrade_action_at(mouse.position, view_size, modal_model)
		return true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_upgrade_action_at(touch.position, view_size, modal_model)
		return true
	return true


func _handle_upgrade_action_at(
	position: Vector2,
	view_size: Vector2,
	modal_model: Dictionary
) -> void:
	if _card_renderer == null or not _card_renderer.has_method("get_tower_reward_upgrade_action_at"):
		return
	var action := str(_card_renderer.call(
		"get_tower_reward_upgrade_action_at",
		position,
		view_size,
		modal_model
	))
	match action:
		"back_arrow", "back":
			_clear_inline_modal()
		"checkbox":
			_upgrade_show_all_levels = not _upgrade_show_all_levels
		"confirm":
			_try_purchase_upgrade()


func _build_upgrade_modal_model(view_size: Vector2 = VIEW_SIZE) -> Dictionary:
	if (
		_upgrade_perk_id.is_empty()
		or _catalog == null
		or not _catalog.has_method("get_perk_data")
	):
		return {}
	var data_value: Variant = _catalog.call("get_perk_data", _upgrade_perk_id)
	if not (data_value is Dictionary):
		return {}
	var perk_data := (data_value as Dictionary).duplicate(true)
	if perk_data.is_empty():
		return {}
	perk_data["id"] = _upgrade_perk_id
	var current_level := maxi(0, int(_get_runtime_skill_levels().get(_upgrade_perk_id, 0)))
	var max_level := maxi(1, int(perk_data.get("max_level", 1)))
	if current_level <= 0:
		return {}
	var effective_level := current_level
	if _runtime_state != null and _runtime_state.has_method("get_runtime_skill_level"):
		effective_level = maxi(
			current_level,
			int(_runtime_state.call("get_runtime_skill_level", _upgrade_perk_id))
		)
	var effective_bonus := maxi(0, effective_level - current_level)
	var has_next_level := current_level < max_level
	var target_level := mini(current_level + 1, max_level)
	var slot_status := _get_choice_slot_status(perk_data, target_level)
	var slot_accepted := bool(slot_status.get("accepted", false))
	var cost := _get_current_upgrade_cost()
	var affordable := int(_get_balances().get("muhon", 0)) >= cost
	var cards := _build_upgrade_cards(
		perk_data,
		current_level,
		max_level,
		effective_bonus,
		_upgrade_show_all_levels
	)
	var model := {
		"kind": "upgrade",
		"perk_id": _upgrade_perk_id,
		"title": str(perk_data.get("name", _upgrade_perk_id)),
		"base_level": current_level,
		"effective_level": effective_level,
		"max_level": max_level,
		"target_level": target_level,
		"has_next_level": has_next_level,
		"can_upgrade": has_next_level,
		"confirm_enabled": has_next_level and slot_accepted and affordable,
		"show_all_levels": _upgrade_show_all_levels,
		"cost": cost,
		"cards": cards,
		"slot_status": slot_status,
		"affordable": affordable,
		"show_all_text": TowerRewardPickLocalization.text("upgrade_show_all"),
		"back_text": TowerRewardPickLocalization.text("upgrade_back"),
		"confirm_text": TowerRewardPickLocalization.text("upgrade_confirm"),
		"cost_text": TowerRewardPickLocalization.text("upgrade_cost", {"amount": cost}),
		"max_rank_text": TowerRewardPickLocalization.text("upgrade_max_rank"),
	}
	if _card_renderer != null and _card_renderer.has_method("build_tower_reward_upgrade_layout"):
		var layout_value: Variant = _card_renderer.call(
			"build_tower_reward_upgrade_layout",
			view_size,
			model
		)
		if layout_value is Dictionary:
			model["layout"] = (layout_value as Dictionary).duplicate(true)
	return model


func _build_upgrade_cards(
	perk_data: Dictionary,
	current_level: int,
	max_level: int,
	effective_bonus: int,
	show_all_levels: bool
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if show_all_levels:
		for level in range(1, max_level + 1):
			result.append(_build_upgrade_card(
				perk_data,
				level,
				effective_bonus,
				"level",
				level > current_level
			))
		return result
	result.append(_build_upgrade_card(
		perk_data,
		current_level,
		effective_bonus,
		"current",
		false
	))
	if current_level < max_level:
		result.append(_build_upgrade_card(
			perk_data,
			current_level + 1,
			effective_bonus,
			"next",
			true
		))
	return result


func _build_upgrade_card(
	perk_data: Dictionary,
	base_level: int,
	effective_bonus: int,
	role: String,
	cool_tone: bool
) -> Dictionary:
	var choice := perk_data.duplicate(true)
	var descriptions_value: Variant = choice.get("descriptions", {})
	var descriptions: Dictionary = descriptions_value if descriptions_value is Dictionary else {}
	var display_level := base_level + effective_bonus
	var perk_id := str(choice.get("id", _upgrade_perk_id))
	var description := RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		perk_id,
		descriptions,
		display_level,
		_runtime_state
	)
	if description.is_empty():
		description = str(descriptions.get(base_level, choice.get("description", "")))
	var previous_description := ""
	if base_level > 1 and role != "current":
		previous_description = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
			perk_id,
			descriptions,
			display_level - 1,
			_runtime_state
		)
	choice["current_level"] = maxi(0, base_level - 1)
	choice["next_level"] = base_level
	choice["description"] = description
	return {
		"choice": choice,
		"role": role,
		"base_level": base_level,
		"display_level": display_level,
		"description": description,
		"previous_description": previous_description,
		"cool_tone": cool_tone,
	}


func _get_current_upgrade_cost() -> int:
	return UPGRADE_BASE_COST + _upgrade_purchase_count * UPGRADE_COST_STEP


func _try_purchase_upgrade() -> void:
	var model := _build_upgrade_modal_model()
	if model.is_empty() or not bool(model.get("has_next_level", false)):
		return
	if not bool(model.get("affordable", false)):
		_status_text = TowerRewardPickLocalization.text("insufficient")
		return
	var slot_status_value: Variant = model.get("slot_status", {})
	var slot_status: Dictionary = slot_status_value if slot_status_value is Dictionary else {}
	if not bool(slot_status.get("accepted", false)):
		_status_text = TowerRewardPickLocalization.text(DISABLED_REASON_PERK_SLOT_LIMIT)
		return
	var cards_value: Variant = model.get("cards", [])
	var cards: Array = cards_value if cards_value is Array else []
	var choice: Dictionary = {}
	if _catalog != null and _catalog.has_method("get_perk_data"):
		var choice_value: Variant = _catalog.call("get_perk_data", _upgrade_perk_id)
		if choice_value is Dictionary:
			choice = (choice_value as Dictionary).duplicate(true)
	if choice.is_empty() or cards.is_empty():
		return
	choice["id"] = _upgrade_perk_id
	var target_level := int(model.get("target_level", 0))
	var cost := int(model.get("cost", _get_current_upgrade_cost()))
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_upgrade",
		_upgrade_purchase_count,
		choice,
		target_level,
		cost,
		Callable(self, "_grant_upgrade_choice").bind(choice, target_level),
		Callable(self, "_rollback_choice")
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_status_text = str(result.get("reason", "reward_pick_upgrade_failed"))
		return
	_upgrade_purchase_count += 1
	_pending_runtime_snapshot.clear()
	_perk_slot_status_dirty = true
	_refresh_perk_slot_status_if_needed()
	_reward_session_id += 1
	_status_text = TowerRewardPickLocalization.text("upgrade_confirm")


func _grant_upgrade_choice(choice: Dictionary, target_level: int) -> bool:
	if _runtime_state == null or not _runtime_state.has_method("apply_choice_at_target_level"):
		return false
	_capture_runtime_snapshot()
	var previous_context: Dictionary = {}
	var context_value: Variant = _runtime_state.get("current_choice_context")
	if context_value is Dictionary:
		previous_context = (context_value as Dictionary).duplicate(true)
	_runtime_state.set("current_choice_context", {
		"source": "tower_reward_pick_upgrade",
		"grant_scope": "tower_run",
	})
	var accepted := bool(_runtime_state.call(
		"apply_choice_at_target_level",
		choice,
		target_level,
		_owner,
		_registry
	))
	_runtime_state.set("current_choice_context", previous_context)
	return accepted


func _begin_mugong_replacement(
	index: int,
	choice: Dictionary,
	view_size: Vector2
) -> void:
	var interaction_model := _get_status_interaction_model(view_size)
	var cells_value: Variant = interaction_model.get("cells", [])
	var cells: Array = cells_value if cells_value is Array else []
	var candidates: Array[Dictionary] = []
	for cell_value: Variant in cells:
		if not (cell_value is Dictionary):
			continue
		var cell := (cell_value as Dictionary).duplicate(true)
		if not bool(cell.get("replacement_eligible", false)):
			continue
		var entry_value: Variant = cell.get("entry", {})
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		var target_kind := "fusion" if str(entry.get("tree", "")).to_lower() == "fusion" else "perk"
		var target_token := {
			"target_kind": target_kind,
			"target_id": str(cell.get("canonical_id", "")),
			"slot_cell_index": int(cell.get("slot_cell_index", 0)),
		}
		var plan_value: Variant = _runtime_state.call(
			"build_tower_reward_mugong_replacement_plan",
			target_token,
			choice,
			_catalog,
			_registry
		)
		if not (plan_value is Dictionary) or not bool((plan_value as Dictionary).get(
			"accepted",
			false
		)):
			continue
		cell["target_token"] = target_token
		cell["replacement_plan"] = (plan_value as Dictionary).duplicate(true)
		cell["name"] = str(entry.get("name", cell.get("canonical_id", "")))
		cell["rank_text"] = str(entry.get("rank", entry.get("tier", "")))
		candidates.append(cell)
	if candidates.is_empty():
		_status_text = TowerRewardPickLocalization.text(DISABLED_REASON_PERK_SLOT_LIMIT)
		return
	_replacement_slot_index = index
	_replacement_choice = choice.duplicate(true)
	_replacement_candidates = candidates
	_replacement_selected_index = 0
	_mode = MODE_MUGONG_REPLACE
	_reset_auto_finish_hold()
	reward_hover_mouse_pos = Vector2(-1.0, -1.0)


func _handle_mugong_replace_input(event: InputEvent, view_size: Vector2) -> bool:
	var modal_model := _build_mugong_replace_modal_model(view_size)
	if modal_model.is_empty():
		_clear_inline_modal()
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var hover_index := _get_mugong_swap_option_index_at(
			motion.position,
			view_size,
			modal_model
		)
		if hover_index >= 0:
			_replacement_selected_index = hover_index
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				_clear_inline_modal()
			elif key.keycode in [KEY_LEFT, KEY_A] or key.physical_keycode in [KEY_LEFT, KEY_A]:
				_move_replacement_selection(-1, 0, modal_model)
			elif key.keycode in [KEY_RIGHT, KEY_D] or key.physical_keycode in [KEY_RIGHT, KEY_D]:
				_move_replacement_selection(1, 0, modal_model)
			elif key.keycode in [KEY_UP, KEY_W] or key.physical_keycode in [KEY_UP, KEY_W]:
				_move_replacement_selection(0, -1, modal_model)
			elif key.keycode in [KEY_DOWN, KEY_S] or key.physical_keycode in [KEY_DOWN, KEY_S]:
				_move_replacement_selection(0, 1, modal_model)
			elif key.keycode in [KEY_ENTER, KEY_KP_ENTER] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_confirm_mugong_replacement()
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_handle_mugong_replace_click(mouse.position, view_size, modal_model)
		return true
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_mugong_replace_click(touch.position, view_size, modal_model)
		return true
	return true


func _handle_mugong_replace_click(
	position: Vector2,
	view_size: Vector2,
	modal_model: Dictionary
) -> void:
	if (
		_card_renderer != null
		and _card_renderer.has_method("is_tower_reward_mugong_swap_cancel_at")
		and bool(_card_renderer.call(
			"is_tower_reward_mugong_swap_cancel_at",
			position,
			view_size,
			modal_model
		))
	):
		_clear_inline_modal()
		return
	var option_index := _get_mugong_swap_option_index_at(position, view_size, modal_model)
	if option_index < 0:
		return
	_replacement_selected_index = option_index
	_confirm_mugong_replacement()


func _get_mugong_swap_option_index_at(
	position: Vector2,
	view_size: Vector2,
	modal_model: Dictionary
) -> int:
	if (
		_card_renderer == null
		or not _card_renderer.has_method("get_tower_reward_mugong_swap_option_index_at")
	):
		return -1
	return int(_card_renderer.call(
		"get_tower_reward_mugong_swap_option_index_at",
		position,
		view_size,
		modal_model
	))


func _move_replacement_selection(
	horizontal: int,
	vertical: int,
	modal_model: Dictionary
) -> void:
	var count := _replacement_candidates.size()
	if count <= 0:
		return
	if horizontal != 0:
		_replacement_selected_index = posmod(
			_replacement_selected_index + signi(horizontal),
			count
		)
		return
	var layout_value: Variant = modal_model.get("layout", {})
	var layout: Dictionary = layout_value if layout_value is Dictionary else {}
	var columns := maxi(1, int(layout.get("columns", 1)))
	var candidate := _replacement_selected_index + signi(vertical) * columns
	if candidate >= 0 and candidate < count:
		_replacement_selected_index = candidate


func _confirm_mugong_replacement() -> void:
	if (
		_replacement_slot_index < 0
		or _replacement_slot_index >= choices.size()
		or _replacement_selected_index < 0
		or _replacement_selected_index >= _replacement_candidates.size()
	):
		return
	var index := _replacement_slot_index
	var choice := _replacement_choice.duplicate(true)
	var candidate := _replacement_candidates[_replacement_selected_index]
	var token_value: Variant = candidate.get("target_token", {})
	var target_token: Dictionary = (
		(token_value as Dictionary).duplicate(true)
		if token_value is Dictionary
		else {}
	)
	if target_token.is_empty():
		return
	var cost := maxi(0, int(choice.get("reward_pick_cost", 0)))
	if int(_get_balances().get("muhon", 0)) < cost:
		_status_text = TowerRewardPickLocalization.text("insufficient")
		return
	_pending_slot_index = index
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_purchase",
		index,
		choice,
		cost,
		Callable(self, "_grant_mugong_replacement").bind(target_token, choice),
		Callable(self, "_rollback_choice"),
		_reroll_counter
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_restore_runtime_snapshot()
		_pending_runtime_snapshot.clear()
		_status_text = str(result.get("reason", "reward_pick_replacement_failed"))
		return
	_commit_purchased_slot(index, choice)
	_clear_inline_modal()


func _grant_mugong_replacement(
	target_token: Dictionary,
	choice: Dictionary
) -> bool:
	if _runtime_state == null or not _runtime_state.has_method(
		"apply_tower_reward_mugong_replacement"
	):
		return false
	_capture_runtime_snapshot()
	var previous_context: Dictionary = {}
	var context_value: Variant = _runtime_state.get("current_choice_context")
	if context_value is Dictionary:
		previous_context = (context_value as Dictionary).duplicate(true)
	_runtime_state.set("current_choice_context", {
		"source": "tower_reward_pick_replacement",
		"grant_scope": "tower_run",
	})
	var replacement_value: Variant = _runtime_state.call(
		"apply_tower_reward_mugong_replacement",
		target_token,
		choice,
		_owner,
		_registry,
		_catalog
	)
	_runtime_state.set("current_choice_context", previous_context)
	return (
		replacement_value is Dictionary
		and bool((replacement_value as Dictionary).get("accepted", false))
		and bool((replacement_value as Dictionary).get("applied", false))
	)


func _build_mugong_replace_modal_model(view_size: Vector2 = VIEW_SIZE) -> Dictionary:
	if _replacement_candidates.is_empty():
		return {}
	var model := {
		"kind": MODE_MUGONG_REPLACE,
		"candidates": _replacement_candidates.duplicate(true),
		"selected_index": _replacement_selected_index,
		"new_name": str(_replacement_choice.get("name", _replacement_choice.get("id", ""))),
		"title": TowerRewardPickLocalization.text("mugong_swap_title"),
		"new_label": TowerRewardPickLocalization.text(
			"mugong_swap_new_label",
			{"name": str(_replacement_choice.get("name", _replacement_choice.get("id", "")))}
		),
		"hint_text": TowerRewardPickLocalization.text("mugong_swap_hint"),
		"cancel_text": TowerRewardPickLocalization.text("upgrade_back"),
	}
	if _card_renderer != null and _card_renderer.has_method("build_tower_reward_mugong_swap_layout"):
		var layout_value: Variant = _card_renderer.call(
			"build_tower_reward_mugong_swap_layout",
			view_size,
			model
		)
		if layout_value is Dictionary:
			model["layout"] = (layout_value as Dictionary).duplicate(true)
	return model


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


func _purchase(index: int, view_size: Vector2 = VIEW_SIZE) -> void:
	if index < 0 or index >= choices.size() or spent_flags[index]:
		return
	var choice := choices[index]
	var cost := maxi(0, int(choice.get("reward_pick_cost", 0)))
	var balances := _get_balances()
	var slot_status := _get_choice_slot_status(choice)
	var replacement_required := _is_mugong_replacement_required(choice, slot_status)
	if not bool(slot_status.get("accepted", false)) and not replacement_required:
		_status_text = TowerRewardPickLocalization.text(DISABLED_REASON_PERK_SLOT_LIMIT)
		return
	if int(balances.get("muhon", 0)) < cost:
		_status_text = TowerRewardPickLocalization.text("insufficient")
		return
	var kind := str(choice.get("reward_pick_kind", ""))
	if replacement_required:
		_begin_mugong_replacement(index, choice, view_size)
		return
	if kind == "refresh":
		_purchase_refresh(index, choice, cost)
		return
	if kind == "vision" and bool(choice.get("vision_swap_required", false)):
		_begin_vision_swap(index, choice)
		return
	_pending_slot_index = index
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_purchase",
		index,
		choice,
		cost,
		Callable(self, "_grant_choice").bind(choice),
		Callable(self, "_rollback_choice"),
		_reroll_counter
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_status_text = str(result.get("reason", "reward_pick_purchase_failed"))
		_pending_slot_index = -1
		return
	_commit_purchased_slot(index, choice)


func _grant_choice(choice: Dictionary) -> bool:
	_capture_runtime_snapshot()
	var kind := str(choice.get("reward_pick_kind", ""))
	if kind == "bag_expansion":
		return (
			_runtime_state.has_method("grant_tower_bag_expansion")
			and bool(_runtime_state.call("grant_tower_bag_expansion"))
		)
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


func _purchase_refresh(index: int, choice: Dictionary, cost: int) -> void:
	var next_generation := _reroll_counter + 1
	var next_offer := _build_offer_for_generation(next_generation)
	if not bool(next_offer.get("accepted", false)):
		_status_text = str(next_offer.get("reason", "reward_pick_refresh_failed"))
		return
	var next_choices := _dictionary_array(next_offer.get("choices", []))
	if next_choices.is_empty() or next_choices.size() > TowerRewardPickOfferBuilder.CARD_COUNT:
		_status_text = "reward_pick_refresh_invalid_offer"
		return
	_pending_slot_index = index
	var result: Dictionary = _flow_owner.call(
		"apply_reward_pick_purchase",
		index,
		choice,
		cost,
		Callable(self, "_accept_existing_external_effect"),
		Callable(),
		_reroll_counter
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_status_text = str(result.get("reason", "reward_pick_refresh_failed"))
		_pending_slot_index = -1
		return
	_install_refreshed_offer(next_offer, next_generation)


func _build_offer_for_generation(generation: int) -> Dictionary:
	if _flow_owner == null or not _flow_owner.has_method("get_reward_pick_context"):
		return {"accepted": false, "reason": "reward_pick_context_unavailable"}
	var context_value: Variant = _flow_owner.call("get_reward_pick_context")
	if not (context_value is Dictionary):
		return {"accepted": false, "reason": "reward_pick_context_unavailable"}
	return _offer_builder.build_offer(
		context_value as Dictionary,
		_owner,
		_registry,
		_roll_overrides,
		generation
	)


func _install_refreshed_offer(offer: Dictionary, generation: int) -> void:
	var refreshed_choices := _dictionary_array(offer.get("choices", []))
	if refreshed_choices.is_empty() or refreshed_choices.size() > TowerRewardPickOfferBuilder.CARD_COUNT:
		return
	_offer = offer.duplicate(true)
	choices.assign(refreshed_choices)
	spent_flags.clear()
	for _index in range(choices.size()):
		spent_flags.append(false)
	_reroll_counter = maxi(0, generation)
	_track_offered_vision(offer)
	selected_index = 0
	animation_time = 0.0
	reward_hover_mouse_pos = Vector2(-1.0, -1.0)
	purchase_absorption_effects.clear()
	_pending_slot_index = -1
	_pending_runtime_snapshot.clear()
	_status_text = TowerRewardPickLocalization.text("hint")
	_reset_auto_finish_hold()
	_auto_finish_attempted = false
	_perk_slot_status_dirty = true
	_refresh_perk_slot_status_if_needed()
	_reward_session_id += 1
	_prewarm_card_assets()


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
		Callable(self, "_restore_runtime_snapshot"),
		_reroll_counter
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
	_perk_slot_status_dirty = true
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


func _update_auto_finish_hold(delta: float, had_absorption_effects: bool) -> void:
	if _auto_finish_attempted or not _has_no_affordable_unspent_card():
		_reset_auto_finish_hold()
		return
	if not purchase_absorption_effects.is_empty():
		_reset_auto_finish_hold()
		return
	if had_absorption_effects:
		_auto_finish_hold_elapsed = 0.0
		_auto_finish_pending = false
		return
	_auto_finish_hold_elapsed += maxf(0.0, delta)
	if (
		_auto_finish_hold_elapsed
		>= TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC
	):
		_auto_finish_pending = true


func _can_auto_finish() -> bool:
	return (
		active
		and _mode == MODE_BOARD
		and not is_external_modal_active()
		and purchase_absorption_effects.is_empty()
		and _has_no_affordable_unspent_card()
		and not _auto_finish_attempted
	)


func _has_no_affordable_unspent_card() -> bool:
	if spent_flags.is_empty():
		return false
	var balances := _get_balances()
	for index in range(choices.size()):
		if index < spent_flags.size() and not spent_flags[index]:
			if _get_purchase_disabled_reason(index, choices[index], balances).is_empty():
				return false
	return true


func _get_purchase_disabled_reason(
	index: int,
	choice: Dictionary,
	balances: Dictionary
) -> String:
	if index < 0 or index >= spent_flags.size() or spent_flags[index]:
		return "spent"
	var slot_status := _get_choice_slot_status(choice)
	if (
		not bool(slot_status.get("accepted", false))
		and not _is_mugong_replacement_required(choice, slot_status)
	):
		return DISABLED_REASON_PERK_SLOT_LIMIT
	if int(balances.get("muhon", 0)) < maxi(0, int(choice.get("reward_pick_cost", 0))):
		return DISABLED_REASON_INSUFFICIENT_MUHON
	return ""


func _is_mugong_replacement_required(
	choice: Dictionary,
	slot_status: Dictionary
) -> bool:
	if bool(slot_status.get("accepted", false)):
		return false
	if str(slot_status.get("blocked_reason", "")) != DISABLED_REASON_PERK_SLOT_LIMIT:
		return false
	if str(choice.get("reward_pick_kind", "")) not in ["mugong", "supreme"]:
		return false
	return (
		_runtime_state != null
		and _runtime_state.has_method("build_tower_reward_mugong_replacement_plan")
		and _runtime_state.has_method("apply_tower_reward_mugong_replacement")
	)


func _get_choice_slot_status(choice: Dictionary, target_level: int = -1) -> Dictionary:
	if _catalog == null or not _catalog.has_method("get_perk_slot_apply_status"):
		return {"accepted": true, "blocked_reason": ""}
	var status_value: Variant = _catalog.call(
		"get_perk_slot_apply_status",
		choice,
		_get_runtime_skill_levels(),
		_registry,
		target_level
	)
	return (
		(status_value as Dictionary).duplicate(true)
		if status_value is Dictionary
		else {"accepted": false, "blocked_reason": DISABLED_REASON_PERK_SLOT_LIMIT}
	)


func _reset_auto_finish_hold() -> void:
	_auto_finish_hold_elapsed = 0.0
	_auto_finish_pending = false


func _get_purchase_absorption_for_slot(index: int) -> Dictionary:
	for effect in purchase_absorption_effects:
		if int(effect.get("slot_index", -1)) == index:
			return effect
	return {}


func _build_purchase_absorption_view_models(view_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in purchase_absorption_effects:
		var slot_index := int(effect.get("slot_index", -1))
		if (
			slot_index < 0
			or slot_index >= choices.size()
			or _absorption_target_resolver == null
			or not _absorption_target_resolver.has_method("resolve_target")
		):
			continue
		var target_value: Variant = _absorption_target_resolver.call(
			"resolve_target",
			choices[slot_index],
			_owner,
			_registry,
			view_size
		)
		if not (target_value is Dictionary):
			continue
		var target := target_value as Dictionary
		if not (target.get("target_pos", null) is Vector2):
			continue
		var duration: float = maxf(0.001, float(effect.get("duration", TEMP_REWARD_PICK_ABSORB_DURATION_SEC)))
		result.append({
			"slot_index": slot_index,
			"progress": clampf(float(effect.get("elapsed", 0.0)) / duration, 0.0, 1.0),
			"target_pos": target.get("target_pos", Vector2.ZERO),
			"target_slot_index": int(target.get("slot_index", -1)),
			"destination_kind": str(target.get("destination_kind", "")),
		})
	return result


func _select_next_available_slot(purchased_index: int) -> void:
	if spent_flags.is_empty():
		return
	for offset in range(1, spent_flags.size() + 1):
		var candidate: int = posmod(purchased_index + offset, spent_flags.size())
		if not spent_flags[candidate]:
			selected_index = candidate
			return


func _finish() -> void:
	if not active or _mode != MODE_BOARD or is_external_modal_active():
		return
	var result: Dictionary = _flow_owner.call(
		"finalize_reward_pick",
		_offered_vision_boss_slot_id
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
	if _runtime_state != null and _runtime_state.has_method("build_tower_reward_mutation_snapshot"):
		var mutation_value: Variant = _runtime_state.call("build_tower_reward_mutation_snapshot")
		if mutation_value is Dictionary:
			_pending_runtime_snapshot = (mutation_value as Dictionary).duplicate(true)
			return
	if _runtime_state != null and _runtime_state.has_method("build_unlock_save_snapshot"):
		var value: Variant = _runtime_state.call("build_unlock_save_snapshot")
		if value is Dictionary:
			_pending_runtime_snapshot = (value as Dictionary).duplicate(true)


func _restore_runtime_snapshot() -> void:
	if (
		_pending_runtime_snapshot.is_empty()
		or _runtime_state == null
	):
		return
	if _runtime_state.has_method("restore_tower_reward_mutation_snapshot"):
		_runtime_state.call(
			"restore_tower_reward_mutation_snapshot",
			_pending_runtime_snapshot,
			_owner,
			_registry,
			_catalog
		)
		return
	if not _runtime_state.has_method("apply_unlock_save_snapshot"):
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


func _build_reward_layout(view_size: Vector2) -> Dictionary:
	return _layout.build_layout(
		view_size,
		choices.size(),
		stats_band_enabled,
		TEMP_REWARD_PICK_PANEL_GAP_PX,
		_get_reward_footer_reserve()
	)


func _get_reward_footer_reserve() -> float:
	return CONTINUE_SIZE.y + CONTINUE_BOTTOM_MARGIN


func _capture_stats_context() -> bool:
	if _runtime_state == null or not _runtime_state.has_method("capture_stats_context"):
		return false
	return bool(_runtime_state.call("capture_stats_context", _owner, _registry))


func _refresh_perk_slot_status_if_needed() -> void:
	if not _perk_slot_status_dirty:
		return
	_perk_slot_status_dirty = false
	_current_perk_slot_status.clear()
	if _catalog == null or not _catalog.has_method("get_perk_slot_status"):
		return
	var levels := _get_runtime_skill_levels()
	var status_value: Variant = _catalog.call(
		"get_perk_slot_status",
		levels,
		_registry
	)
	if status_value is Dictionary:
		_current_perk_slot_status = (status_value as Dictionary).duplicate(true)


func _build_reward_runtime_snapshot() -> Dictionary:
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
	snapshot["reward_pick_spent_flags"] = spent_flags.duplicate()
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


func _build_chosik_tooltip_context() -> Dictionary:
	if _chosik_tooltip_renderer == null or _registry == null:
		return {}
	return {
		"renderer": _chosik_tooltip_renderer,
		"registry": _registry,
		"scene_context": {
			"selected_character_type": str(_get_owner_value(_owner, "selected_character_type", "smasher")),
			"special_gauge": float(_get_owner_value(_owner, "special_gauge", 0.0)),
		},
	}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value
