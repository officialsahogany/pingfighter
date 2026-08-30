extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerTrainingStrikePresentationState := preload(
	"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
)
const TowerTrainingTimingState := preload(
	"res://scripts/tower_ascent/tower_training_timing_state.gd"
)
const TowerGuardianSpringPresentationState := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_presentation_state.gd"
)
const TowerCampfirePresentationState := preload(
	"res://scripts/tower_ascent/tower_campfire_presentation_state.gd"
)
const TowerTaijiElderPresentationState := preload(
	"res://scripts/tower_ascent/tower_taiji_elder_presentation_state.gd"
)

const ACTION_END_WORK := "end_work"
const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const MODAL_RECT := Rect2(24.0, 28.0, 712.0, 694.0)
const ACTION_LIST_RECT := Rect2(126.0, 301.0, 508.0, 302.0)
const ACTION_ROW_HEIGHT := 38.0
const ACTION_ROW_GAP := 5.0
const CARD_NODE_KINDS := ["shop", "training", "fallen_monk", "guardian_spring", "rest"]
const PAGED_CARD_NODE_KINDS := ["guardian_spring"]
const HERO_CARD_NODE_KINDS := ["rest"]
const CARD_GRID_RECT := Rect2(43.0, 150.0, 674.0, 438.0)
const CARD_GRID_COLUMNS := 3
const CARD_GRID_ROWS := 2
const CARD_PAGE_SIZE := CARD_GRID_COLUMNS * CARD_GRID_ROWS
const GRID_COLUMN_GAP := 12.0
const GRID_ROW_GAP := 14.0
const HERO_CARD_RECT := Rect2(164.0, 150.0, 432.0, 438.0)
const END_WORK_RECT := Rect2(246.0, 602.0, 268.0, 40.0)
const PAGE_PREVIOUS_RECT := Rect2(156.0, 602.0, 68.0, 40.0)
const PAGE_NEXT_RECT := Rect2(536.0, 602.0, 68.0, 40.0)
const PAGE_LABEL_RECT := Rect2(208.0, 646.0, 344.0, 24.0)
const STATUS_BASELINE := Vector2(126.0, 680.0)
const LAYOUT_FLAG_TRAINING_STAGE := "training_stage"
const LAYOUT_FLAG_SHOP_COMPACT := "shop_compact"
const LAYOUT_FLAG_SHOP_TRADE_PANELS := "shop_trade_panels"
const LAYOUT_FLAG_SHOP_STACKED := "shop_stacked"
const LAYOUT_FLAG_HERO_CARD := "hero_card"
const LAYOUT_FLAG_PAGE_CONTROLS := "page_controls"
const SHOP_CARD_GRID_RECT := Rect2(43.0, 150.0, 674.0, 226.0)
const SHOP_CARD_GRID_COLUMNS := 3
const SHOP_CARD_GRID_ROWS := 2
const SHOP_GRID_COLUMN_GAP := 12.0
const SHOP_GRID_ROW_GAP := 14.0
# Feedback 7 option (b): these values intentionally mirror
# plaza_interior_layout.gd's shop panels, but remain Tower-owned because this
# fullscreen modal and the plaza use different scaling contracts.
const SHOP_TRADE_PLAYER_PANEL_RECT := Rect2(90.0, 215.0, 280.0, 320.0)
const SHOP_TRADE_STOCK_PANEL_RECT := Rect2(390.0, 215.0, 280.0, 320.0)
const SHOP_TRADE_CELL_SIZE := 42.0
const SHOP_TRADE_CELL_GAP := 6.0
const SHOP_TRADE_CELL_START_OFFSET := Vector2(14.0, 38.0)
const SHOP_TRADE_MAX_COLUMNS := 5
const SHOP_TRADE_MAX_ROWS := 6
const SHOP_TRADE_MAX_VISIBLE_CELLS := SHOP_TRADE_MAX_COLUMNS * SHOP_TRADE_MAX_ROWS
const SHOP_STACKED_MODAL_RECT := Rect2(10.0, 10.0, 740.0, 730.0)
const SHOP_STACKED_STOCK_PANEL_RECT := Rect2(18.0, 130.0, 724.0, 336.0)
const SHOP_STACKED_STOCK_COLUMNS := 8
const SHOP_STACKED_STOCK_INSET_X := 14.0
const SHOP_STACKED_STOCK_TOP_INSET := 42.0
const SHOP_STACKED_STOCK_CARD_GAP := 6.0
const SHOP_STACKED_STOCK_CARD_HEIGHT := 276.0
const SHOP_STACKED_OWNED_PANEL_RECT := Rect2(58.0, 494.0, 644.0, 142.0)
const SHOP_STACKED_OWNED_SLOT_AREA_RECT := Rect2(86.0, 544.0, 588.0, 72.0)
const SHOP_STACKED_OWNED_SLOT_MAX_SIZE := 68.0
const SHOP_STACKED_OWNED_SLOT_MIN_GAP := 8.0
const SHOP_STACKED_OWNED_SLOT_MAX_GAP := 16.0
const SHOP_STACKED_END_WORK_RECT := Rect2(566.0, 668.0, 166.0, 42.0)
const SHOP_STACKED_STATUS_BASELINE := Vector2(58.0, 704.0)
const TRAINING_CARD_GRID_RECT := Rect2(52.0, 150.0, 245.0, 476.0)
const TRAINING_CARD_GRID_COLUMNS := 1
const TRAINING_CARD_GRID_ROWS := 4
const TRAINING_GRID_COLUMN_GAP := 0.0
const TRAINING_GRID_ROW_GAP := 6.0
const TRAINING_STAGE_RECT := Rect2(312.0, 150.0, 405.0, 210.0)
const TRAINING_PLAYER_SLOT_RECT := Rect2(329.0, 154.0, 174.0, 202.0)
const TRAINING_DUMMY_SLOT_RECT := Rect2(526.0, 154.0, 174.0, 202.0)
const TRAINING_STATS_RECT := Rect2(312.0, 372.0, 405.0, 254.0)
const TRAINING_END_WORK_RECT := Rect2(246.0, 638.0, 268.0, 40.0)
const TRAINING_STATUS_BASELINE := Vector2(126.0, 705.0)
const HOVER_ENTER_MSEC := 120
const HOVER_EXIT_MSEC := 90
const SUCCESS_RECEIPT_MSEC := 420
const REJECTION_FEEDBACK_MSEC := 160

var _node_id := ""
var _node_kind := "common_shell"
var _actions: Array[Dictionary] = []
var _keyboard_selected_index := 0
var _hovered_index := -1
var _pressed_index := -1
var _visible_page := 0
var _hovered_page_direction := 0
var _pressed_page_direction := 0
var _balances := {"gold": 0, "muhon": 0, "chance_gems": 0}
var _status_text := ""
var _hover_transitions: Dictionary = {}
var _interaction_receipt: Dictionary = {}
var _clock_override_msec := -1
var _training_stage_presentation: Object = null
var _training_timing_state: Object = null
var _training_timing_pending: Dictionary = {}
var _training_timing_strike_started := false
var _guardian_spring_presentation: Object = TowerGuardianSpringPresentationState.new()
var _campfire_presentation: Object = TowerCampfirePresentationState.new()
var _taiji_elder_presentation: Object = TowerTaijiElderPresentationState.new()
var _pointer_position := Vector2(-1.0, -1.0)
var _training_stats_hovered := false
var _shop_owned_items: Array[Dictionary] = []
var _hovered_owned_index := -1
# GRT-028: layout geometry is a retained size/flag product. The fullscreen
# renderer and pointer hit-test share this exact dictionary instead of rebuilding
# their own rects every frame.
var _layout_cache_signature := 0
var _layout_cache: Dictionary = {}
var _layout_build_count := 0


func open(
	node_id: String,
	node_kind: String,
	balances: Dictionary,
	actions: Array = []
) -> void:
	_clear_training_stage_presentation()
	_clear_training_timing()
	_guardian_spring_presentation.close_scene(false)
	_campfire_presentation.reset()
	_taiji_elder_presentation.reset()
	_node_id = node_id.strip_edges()
	_node_kind = node_kind.strip_edges().to_lower()
	if not TowerAscentNodeModalLocalization.NODE_TITLE_KEYS.has(_node_kind):
		_node_kind = "common_shell"
	_balances = _normalize_balances(balances)
	_replace_actions(actions)
	_keyboard_selected_index = 0
	_hovered_index = -1
	_pressed_index = -1
	_visible_page = 0
	_hovered_page_direction = 0
	_pressed_page_direction = 0
	_hover_transitions.clear()
	_interaction_receipt.clear()
	_pointer_position = Vector2(-1.0, -1.0)
	_training_stats_hovered = false
	_shop_owned_items.clear()
	_hovered_owned_index = -1
	_status_text = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_STATUS_READY
	)


func close() -> void:
	_clear_training_stage_presentation()
	_clear_training_timing()
	_guardian_spring_presentation.close_scene()
	_campfire_presentation.reset()
	_taiji_elder_presentation.reset()
	_node_id = ""
	_actions.clear()
	_keyboard_selected_index = 0
	_hovered_index = -1
	_pressed_index = -1
	_visible_page = 0
	_hovered_page_direction = 0
	_pressed_page_direction = 0
	_status_text = ""
	_hover_transitions.clear()
	_interaction_receipt.clear()
	_pointer_position = Vector2(-1.0, -1.0)
	_training_stats_hovered = false
	_shop_owned_items.clear()
	_hovered_owned_index = -1


func configure_training_stage_presentation(
	character_type: Variant,
	texture_cache: Dictionary,
	audio: Object = null
) -> bool:
	_clear_training_stage_presentation()
	if _node_kind != "training":
		return false
	_training_stage_presentation = TowerTrainingStrikePresentationState.new()
	_training_stage_presentation.configure(character_type, texture_cache, audio)
	return bool(_training_stage_presentation.is_configured())


func configure_guardian_spring_presentation(
	ready: bool,
	acquisition_target_pos: Vector2 = Vector2(380.0, 690.0)
) -> bool:
	var enabled := _node_kind == "guardian_spring" and ready
	_guardian_spring_presentation.configure(enabled, acquisition_target_pos)
	return enabled


func has_guardian_spring_presentation() -> bool:
	return (
		_node_kind == "guardian_spring"
		and bool(_guardian_spring_presentation.is_enabled())
	)


func has_guardian_spring_statue_interaction() -> bool:
	return (
		has_guardian_spring_presentation()
		and bool(_guardian_spring_presentation.is_statue_phase())
	)


func has_active_guardian_spring_ritual() -> bool:
	return (
		has_guardian_spring_presentation()
		and bool(_guardian_spring_presentation.is_ritual_active())
	)


func has_guardian_spring_confirmation() -> bool:
	return (
		has_guardian_spring_presentation()
		and bool(_guardian_spring_presentation.is_confirmation_active())
	)


func reveal_guardian_spring_menu() -> bool:
	if not has_guardian_spring_statue_interaction():
		return false
	cancel_pointer_press()
	return bool(_guardian_spring_presentation.reveal_menu())


func begin_guardian_spring_ritual(action: Dictionary) -> bool:
	if not has_guardian_spring_presentation():
		return false
	cancel_pointer_press()
	return bool(_guardian_spring_presentation.begin_ritual(action))


func advance_guardian_spring_presentation(delta: float) -> bool:
	if not has_guardian_spring_presentation():
		return false
	return bool(_guardian_spring_presentation.advance(delta))


func take_completed_guardian_spring_action() -> Dictionary:
	if not has_guardian_spring_presentation():
		return {}
	return _guardian_spring_presentation.take_completed_action()


func handle_guardian_spring_confirmation_input(
	event: InputEvent,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	if not has_guardian_spring_confirmation():
		return false
	var model: Dictionary = _guardian_spring_presentation.build_visual_model(_actions, view_size)
	var no_rect: Rect2 = model.get("confirmation_no_rect", Rect2())
	var yes_rect: Rect2 = model.get("confirmation_yes_rect", Rect2())
	if event is InputEventMouseMotion:
		if yes_rect.has_point(event.position):
			_guardian_spring_presentation.select_confirmation(1)
		elif no_rect.has_point(event.position):
			_guardian_spring_presentation.select_confirmation(0)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and yes_rect.has_point(event.position):
			return bool(_guardian_spring_presentation.confirm_palm_absorption(true))
		if event.pressed and no_rect.has_point(event.position):
			return bool(_guardian_spring_presentation.confirm_palm_absorption(false))
		return true
	if event is InputEventScreenTouch and event.pressed:
		if yes_rect.has_point(event.position):
			return bool(_guardian_spring_presentation.confirm_palm_absorption(true))
		if no_rect.has_point(event.position):
			return bool(_guardian_spring_presentation.confirm_palm_absorption(false))
		return true
	if event.is_action_pressed("ui_cancel"):
		return bool(_guardian_spring_presentation.confirm_palm_absorption(false))
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_guardian_spring_presentation.select_confirmation(
			1 - int(model.get("confirmation_selection", 0))
		)
		return true
	if event.is_action_pressed("ui_accept"):
		return bool(_guardian_spring_presentation.activate_confirmation_selection())
	return true


func get_guardian_spring_presentation_debug_state() -> Dictionary:
	return _guardian_spring_presentation.get_debug_state()


func configure_campfire_presentation(
	restored_action_id: String = "",
	restored_result_lines: Array = []
) -> bool:
	var enabled := _node_kind == "rest"
	_campfire_presentation.configure(
		enabled,
		[
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_INTRO_APPROACH
			),
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_CAMPFIRE_INTRO_UNUSUAL
			),
		],
		restored_action_id,
		restored_result_lines
	)
	if enabled:
		_status_text = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_CAMPFIRE_CHOICE_REQUIRED
		)
	_invalidate_layout_cache()
	return enabled


func has_campfire_presentation() -> bool:
	return _node_kind == "rest" and bool(_campfire_presentation.is_enabled())


func has_campfire_ignition_interaction() -> bool:
	return has_campfire_presentation() and bool(
		_campfire_presentation.is_ignition_phase()
	)


func is_campfire_choice_ready() -> bool:
	return has_campfire_presentation() and bool(
		_campfire_presentation.is_menu_phase()
	)


func has_campfire_sequence_input_lock() -> bool:
	return has_campfire_presentation() and bool(
		_campfire_presentation.is_sequence_input_locked()
	)


func ignite_campfire() -> bool:
	if not has_campfire_presentation():
		return false
	cancel_pointer_press()
	return bool(_campfire_presentation.ignite())


func begin_campfire_result(action_id: String, lines: Array) -> bool:
	if not has_campfire_presentation():
		return false
	cancel_pointer_press()
	return bool(_campfire_presentation.begin_result(action_id, lines))


func advance_campfire_presentation(delta: float) -> bool:
	if not has_campfire_presentation():
		return false
	return bool(_campfire_presentation.advance(delta))


func take_completed_campfire_route() -> bool:
	return (
		has_campfire_presentation()
		and bool(_campfire_presentation.take_route_ready())
	)


func get_campfire_presentation_debug_state() -> Dictionary:
	return _campfire_presentation.get_debug_state()


func export_campfire_presentation_state() -> Dictionary:
	if not has_campfire_presentation():
		return {}
	return _campfire_presentation.export_state()


func restore_campfire_presentation_state(value: Variant) -> bool:
	if not has_campfire_presentation():
		return false
	return bool(_campfire_presentation.restore_state(value))


func configure_taiji_elder_presentation(offer_snapshot: Dictionary) -> bool:
	var enabled := _node_kind == "taiji_elder" and not offer_snapshot.is_empty()
	_taiji_elder_presentation.configure(
		enabled,
		offer_snapshot,
		offer_snapshot.get("dialogue_lines", []),
		str(offer_snapshot.get(
			"question",
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_TAIJI_ELDER_QUESTION
			)
		)),
		TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TAIJI_ELDER_RESULT_ACCEPT
		),
		TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TAIJI_ELDER_RESULT_DECLINE
		)
	)
	_invalidate_layout_cache()
	return enabled


func has_taiji_elder_presentation() -> bool:
	return _node_kind == "taiji_elder" and bool(
		_taiji_elder_presentation.is_enabled()
	)


func is_taiji_elder_dialogue_phase() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.is_dialogue_phase()
	)


func is_taiji_elder_decision_phase() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.is_decision_phase()
	)


func is_taiji_elder_result_phase() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.is_result_phase()
	)


func advance_taiji_elder_dialogue() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.advance_dialogue()
	)


func begin_taiji_elder_dialogue_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.begin_dialogue_press(position, view_size)
	)


func release_taiji_elder_dialogue_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.release_dialogue_press(position, view_size)
	)


func take_taiji_elder_confirmation_ready() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.take_confirmation_ready()
	)


func move_taiji_elder_selection(direction: int) -> bool:
	if not has_taiji_elder_presentation():
		return false
	var changed := bool(_taiji_elder_presentation.move_selection(direction))
	var action_id := str(_taiji_elder_presentation.get_selected_action_id())
	var selected_index := _find_action_index_by_id(action_id)
	if selected_index >= 0:
		_keyboard_selected_index = selected_index
	return changed


func get_selected_taiji_elder_action_id() -> String:
	if not has_taiji_elder_presentation():
		return ""
	return str(_taiji_elder_presentation.get_selected_action_id())


func begin_taiji_elder_result(accepted_exchange: bool) -> bool:
	if not has_taiji_elder_presentation():
		return false
	cancel_pointer_press()
	return bool(_taiji_elder_presentation.begin_result(accepted_exchange))


func advance_taiji_elder_result(delta: float) -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.advance_result(delta)
	)


func take_completed_taiji_elder_route() -> bool:
	return has_taiji_elder_presentation() and bool(
		_taiji_elder_presentation.take_route_ready()
	)


func get_taiji_elder_presentation_debug_state() -> Dictionary:
	return _taiji_elder_presentation.get_debug_state()


func export_taiji_elder_presentation_state() -> Dictionary:
	if not has_taiji_elder_presentation():
		return {}
	return _taiji_elder_presentation.export_state()


func restore_taiji_elder_presentation_state(value: Variant) -> bool:
	if not has_taiji_elder_presentation():
		return false
	return bool(_taiji_elder_presentation.restore_state(value))


func begin_training_strike(
	judgment_kind: String = "",
	message_text: String = ""
) -> bool:
	if _training_stage_presentation == null:
		return false
	var started := bool(_training_stage_presentation.start(judgment_kind, message_text))
	if started and _training_timing_state != null:
		_training_timing_strike_started = true
	return started


func begin_training_timing(
	pending_action: Dictionary,
	target_roll: Dictionary
) -> bool:
	_clear_training_timing()
	if _node_kind != "training" or pending_action.is_empty():
		return false
	var state := TowerTrainingTimingState.new()
	if _clock_override_msec >= 0:
		state.set_clock_msec_for_tests(_clock_override_msec)
	if not state.start(target_roll):
		return false
	_training_timing_state = state
	_training_timing_pending = pending_action.duplicate(true)
	_training_timing_strike_started = false
	cancel_pointer_press()
	return true


func stop_training_timing() -> Dictionary:
	if _training_timing_state == null:
		return {"accepted": false, "reason": "training_timing_not_running"}
	var result: Dictionary = _training_timing_state.stop()
	if bool(result.get("accepted", false)):
		result["pending_action"] = _training_timing_pending.duplicate(true)
	return result


func cancel_training_timing() -> Dictionary:
	var had_interaction := _training_timing_state != null
	_clear_training_timing()
	cancel_pointer_press()
	return {
		"accepted": had_interaction,
		"muhon_spent": 0,
		"reason": "training_timing_cancelled",
	}


func has_running_training_timing() -> bool:
	return (
		_training_timing_state != null
		and bool(_training_timing_state.is_running())
	)


func has_training_timing_interaction() -> bool:
	return _training_timing_state != null


func get_training_timing_presentation() -> Object:
	return _training_timing_state


func get_training_timing_debug_state() -> Dictionary:
	if _training_timing_state == null:
		return {
			"running": false,
			"resolved": false,
			"host_node_count": 0,
			"dynamic_layer_count": 0,
		}
	return _training_timing_state.get_debug_state()


func get_training_timing_visual_model_for_tests() -> Dictionary:
	if _training_timing_state == null:
		return {}
	return _training_timing_state.get_visual_model()


func update_training_strike_wall_clock() -> bool:
	if _training_stage_presentation == null:
		return false
	return bool(_training_stage_presentation.update_wall_clock())


func update_training_presentations_wall_clock() -> bool:
	var remains_active := false
	if has_running_training_timing():
		_training_timing_state.update_wall_clock()
		remains_active = true
	if has_active_training_strike():
		var strike_active := bool(_training_stage_presentation.update_wall_clock())
		remains_active = remains_active or strike_active
		if not strike_active and _training_timing_strike_started:
			_clear_training_timing()
	return remains_active


func has_active_training_strike() -> bool:
	return (
		_training_stage_presentation != null
		and bool(_training_stage_presentation.is_active())
	)


func get_training_stage_presentation() -> Object:
	return _training_stage_presentation


func get_training_stage_debug_state() -> Dictionary:
	if _training_stage_presentation == null:
		return {
			"configured": false,
			"active": false,
			"host_node_count": 0,
			"dynamic_layer_count": 0,
		}
	return _training_stage_presentation.get_debug_state()


func set_training_stage_clock_msec_for_tests(value: int) -> void:
	_clock_override_msec = value
	if _training_stage_presentation != null:
		_training_stage_presentation.set_clock_msec_for_tests(value)
	if _training_timing_state != null:
		_training_timing_state.set_clock_msec_for_tests(value)


func get_training_stage_visual_model_for_tests() -> Dictionary:
	if _training_stage_presentation == null:
		return {}
	return _training_stage_presentation.get_visual_model()


func _clear_training_stage_presentation() -> void:
	if _training_stage_presentation != null:
		_training_stage_presentation.clear()
	_training_stage_presentation = null


func _clear_training_timing() -> void:
	if _training_timing_state != null:
		_training_timing_state.cancel()
	_training_timing_state = null
	_training_timing_pending.clear()
	_training_timing_strike_started = false


func set_actions(actions: Array) -> void:
	var previous_keyboard_index := _keyboard_selected_index
	var keyboard_action_id := _action_id_at_index(_keyboard_selected_index)
	var hovered_action_id := _action_id_at_index(_hovered_index)
	_replace_actions(actions)
	if _actions.is_empty():
		_keyboard_selected_index = -1
		_hovered_index = -1
		_pressed_index = -1
		_pressed_page_direction = 0
		_visible_page = 0
		return
	var restored_keyboard_index := _find_action_index_by_id(keyboard_action_id)
	if restored_keyboard_index >= 0:
		_keyboard_selected_index = restored_keyboard_index
	else:
		_keyboard_selected_index = clampi(previous_keyboard_index, 0, _actions.size() - 1)
	_hovered_index = _find_action_index_by_id(hovered_action_id)
	_pressed_index = -1
	_pressed_page_direction = 0
	_visible_page = clampi(_visible_page, 0, get_page_count() - 1)
	_ensure_selection_visible()


func set_shop_owned_items(items: Array) -> void:
	_shop_owned_items.clear()
	for item_value in items:
		if item_value is Dictionary:
			_shop_owned_items.append((item_value as Dictionary).duplicate(true))
	_hovered_owned_index = -1
	_invalidate_layout_cache()


func get_shop_owned_items() -> Array[Dictionary]:
	return _shop_owned_items.duplicate(true)


func get_hovered_owned_index() -> int:
	return _hovered_owned_index


func has_shop_item_hover() -> bool:
	if _node_kind != "shop":
		return false
	if _hovered_index >= 0 and _action_id_at_index(_hovered_index) != ACTION_END_WORK:
		return true
	return (
		_hovered_owned_index >= 0
		and _hovered_owned_index < _shop_owned_items.size()
		and not bool(_shop_owned_items[_hovered_owned_index].get("empty_slot", false))
		and not _shop_owned_items[_hovered_owned_index].is_empty()
	)


func set_balances(balances: Dictionary) -> void:
	_balances = _normalize_balances(balances)


func set_status_text(value: String) -> void:
	_status_text = value.strip_edges()


func move_selection(direction: int) -> void:
	if has_taiji_elder_presentation():
		move_taiji_elder_selection(direction)
		return
	if has_guardian_spring_statue_interaction() or has_active_guardian_spring_ritual():
		return
	if has_campfire_presentation() and not _campfire_presentation.is_menu_phase():
		return
	if _actions.is_empty() or direction == 0:
		return
	_keyboard_selected_index = posmod(
		_keyboard_selected_index + signi(direction),
		_actions.size()
	)
	_ensure_selection_visible()


func select_index(index: int) -> bool:
	if index < 0 or index >= _actions.size():
		return false
	_keyboard_selected_index = index
	_ensure_selection_visible()
	return true


func select_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	return select_index(_action_index_at_position(position, view_size))


func update_hover_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	_pointer_position = position
	if has_campfire_ignition_interaction():
		_hovered_index = -1
		_hovered_page_direction = 0
		return bool(_campfire_presentation.update_fire_hover(position, view_size))
	if has_campfire_sequence_input_lock():
		return false
	if has_guardian_spring_statue_interaction():
		_hovered_index = -1
		_hovered_page_direction = 0
		return bool(_guardian_spring_presentation.update_statue_hover(position, view_size))
	if has_active_guardian_spring_ritual():
		return false
	var previous_stats_hovered := _training_stats_hovered
	_training_stats_hovered = _training_stats_rect(view_size).has_point(position)
	var next_hovered_index := _action_index_at_position(position, view_size)
	var next_hovered_owned_index := (
		get_owned_cell_index_at(position, view_size)
		if next_hovered_index < 0
		else -1
	)
	var next_page_direction := (
		_page_direction_at_position(position, view_size)
		if next_hovered_index < 0
		else 0
	)
	if (
		next_hovered_index == _hovered_index
		and next_hovered_owned_index == _hovered_owned_index
		and next_page_direction == _hovered_page_direction
	):
		return previous_stats_hovered != _training_stats_hovered
	var now_msec := _now_msec()
	var previous_action_id := _action_id_at_index(_hovered_index)
	if not previous_action_id.is_empty():
		_set_hover_target(previous_action_id, 0.0, now_msec, HOVER_EXIT_MSEC)
	_hovered_index = next_hovered_index
	_hovered_owned_index = next_hovered_owned_index
	_hovered_page_direction = next_page_direction
	var next_action_id := _action_id_at_index(_hovered_index)
	if not next_action_id.is_empty():
		_set_hover_target(next_action_id, 1.0, now_msec, HOVER_ENTER_MSEC)
	return true


func begin_pointer_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	_pointer_position = position
	if has_taiji_elder_presentation():
		_pressed_index = -1
		_pressed_page_direction = 0
		return bool(_taiji_elder_presentation.begin_pointer_press(position, view_size))
	if has_campfire_ignition_interaction():
		_pressed_index = -1
		_pressed_page_direction = 0
		return bool(_campfire_presentation.begin_fire_press(position, view_size))
	if has_campfire_sequence_input_lock():
		return false
	if has_guardian_spring_statue_interaction():
		_pressed_index = -1
		_pressed_page_direction = 0
		return bool(_guardian_spring_presentation.begin_statue_press(position, view_size))
	if has_active_guardian_spring_ritual():
		return false
	_training_stats_hovered = _training_stats_rect(view_size).has_point(position)
	_pressed_index = _action_index_at_position(position, view_size)
	_pressed_page_direction = (
		_page_direction_at_position(position, view_size)
		if _pressed_index < 0
		else 0
	)
	return _pressed_index >= 0 or _pressed_page_direction != 0


func release_pointer_at_position(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> Dictionary:
	_pointer_position = position
	if has_taiji_elder_presentation():
		var action_id := str(
			_taiji_elder_presentation.release_pointer_press(position, view_size)
		)
		if action_id.is_empty():
			return {}
		var action_index := _find_action_index_by_id(action_id)
		if action_index >= 0:
			_keyboard_selected_index = action_index
		return _action_at_index(action_index)
	if has_campfire_ignition_interaction():
		if bool(_campfire_presentation.release_fire_press(position, view_size)):
			return {"_modal_control": "campfire_ignite"}
		return {}
	if has_campfire_sequence_input_lock():
		return {}
	if has_guardian_spring_statue_interaction():
		if bool(_guardian_spring_presentation.release_statue_press(position, view_size)):
			return {"_modal_control": "guardian_statue"}
		return {}
	if has_active_guardian_spring_ritual():
		return {}
	_training_stats_hovered = _training_stats_rect(view_size).has_point(position)
	var armed_index := _pressed_index
	var armed_page_direction := _pressed_page_direction
	_pressed_index = -1
	_pressed_page_direction = 0
	if armed_page_direction != 0:
		if armed_page_direction != _page_direction_at_position(position, view_size):
			return {}
		return {
			"_modal_control": "page",
			"direction": armed_page_direction,
			"changed": change_visible_page(armed_page_direction),
		}
	if armed_index < 0 or armed_index != _action_index_at_position(position, view_size):
		return {}
	return _action_at_index(armed_index)


func cancel_pointer_press() -> void:
	_pressed_index = -1
	_pressed_page_direction = 0
	_guardian_spring_presentation.cancel_pointer_press()
	_campfire_presentation.cancel_pointer_press()
	_taiji_elder_presentation.cancel_pointer_press()


func record_action_feedback(action: Dictionary, result: Dictionary) -> void:
	var action_id := str(action.get("id", "")).strip_edges()
	if action_id.is_empty():
		return
	var accepted := bool(result.get("accepted", false))
	var applied := bool(result.get("applied", false))
	var success := accepted and applied
	# Internal transaction reasons are diagnostics, not player copy. Only an
	# explicit localized message or the action's localized unavailable copy may
	# enter the visible receipt.
	var message := str(result.get("message", "")).strip_edges()
	if not success and message.is_empty():
		message = str(action.get("unavailable_reason", "")).strip_edges()
	if not success and message.is_empty():
		message = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_STATUS_DISABLED
		)
	_interaction_receipt = {
		"action_id": action_id,
		"fallback_index": int(action.get(
			"_feedback_index",
			_find_action_index_by_id(action_id)
		)),
		"success": success,
		"rejected": not success,
		"message": message,
		"started_msec": _now_msec(),
		"duration_msec": SUCCESS_RECEIPT_MSEC if success else REJECTION_FEEDBACK_MSEC,
		# These are presentation snapshots copied from the transaction authority.
		# The modal never reconstructs a purchase from prices or tuning constants.
		"costs": _dictionary_copy(result.get("costs", {})),
		"rewards": _dictionary_copy(result.get("rewards", {})),
		"balances_before": _dictionary_copy(result.get("balances_before", {})),
		"balances": _dictionary_copy(result.get("balances", {})),
	}


func set_clock_msec_for_tests(value: int) -> void:
	_clock_override_msec = value


func clear_clock_msec_for_tests() -> void:
	_clock_override_msec = -1


func get_keyboard_selected_index() -> int:
	return _keyboard_selected_index


func get_hovered_index() -> int:
	return _hovered_index


func get_pressed_index() -> int:
	return _pressed_index


func get_visible_page() -> int:
	return _visible_page


func get_page_count() -> int:
	if not _uses_paged_cards():
		return 1
	return maxi(1, int(ceil(float(_card_action_count()) / float(CARD_PAGE_SIZE))))


func change_visible_page(direction: int) -> bool:
	if direction == 0 or get_page_count() <= 1:
		return false
	var next_page := clampi(_visible_page + signi(direction), 0, get_page_count() - 1)
	if next_page == _visible_page:
		return false
	_visible_page = next_page
	_hovered_index = -1
	_hovered_page_direction = 0
	_pressed_index = -1
	_pressed_page_direction = 0
	_select_first_action_on_visible_page()
	return true


func set_visible_page(page: int) -> bool:
	var next_page := clampi(page, 0, get_page_count() - 1)
	if next_page == _visible_page:
		return false
	_visible_page = next_page
	_hovered_index = -1
	_hovered_page_direction = 0
	_pressed_index = -1
	_pressed_page_direction = 0
	_select_first_action_on_visible_page()
	return true


func get_hovered_page_direction() -> int:
	return _hovered_page_direction


func get_pressed_page_direction() -> int:
	return _pressed_page_direction


func has_hover_visuals() -> bool:
	_prune_hover_transitions(_now_msec())
	return (
		not _hover_transitions.is_empty()
		or _hovered_page_direction != 0
		or _hovered_owned_index >= 0
	)


func has_training_stats_hover() -> bool:
	return _node_kind == "training" and _training_stats_hovered


func get_pointer_position() -> Vector2:
	return _pointer_position


func get_layout_build_count_for_tests() -> int:
	return _layout_build_count


func get_action_index_by_id(action_id: String) -> int:
	return _find_action_index_by_id(action_id)


func get_action_rects(
	view_size: Vector2 = BASE_VIEW_SIZE,
	layout_flags: Dictionary = {}
) -> Array[Rect2]:
	if has_taiji_elder_presentation():
		return _taiji_elder_presentation.get_action_rects(_actions, view_size)
	if has_guardian_spring_presentation():
		return _guardian_spring_presentation.get_action_rects(_actions, view_size)
	if has_campfire_presentation():
		return _campfire_presentation.get_action_rects(_actions, view_size)
	var result: Array[Rect2] = []
	var layout := build_screen_layout(view_size, layout_flags)
	if _node_kind in CARD_NODE_KINDS:
		var uses_shop_stacked := bool(layout.get("layout_flags", {}).get(
			LAYOUT_FLAG_SHOP_STACKED,
			false
		))
		if uses_shop_stacked:
			var stock_card_rects: Array = layout.get("shop_stock_card_rects", [])
			var stock_visible_index := 0
			for action in _actions:
				if str(action.get("id", "")) == ACTION_END_WORK:
					result.append(layout.get("end_work_rect", SHOP_STACKED_END_WORK_RECT))
				elif stock_visible_index >= stock_card_rects.size():
					result.append(Rect2())
					stock_visible_index += 1
				else:
					result.append(stock_card_rects[stock_visible_index] as Rect2)
					stock_visible_index += 1
			return result
		var uses_shop_trade_panels := bool(layout.get("layout_flags", {}).get(
			LAYOUT_FLAG_SHOP_TRADE_PANELS,
			false
		))
		if uses_shop_trade_panels:
			var stock_panel_rect: Rect2 = layout.get("shop_stock_panel_rect", Rect2())
			var stock_columns := int(layout.get("shop_stock_columns", 0))
			var stock_visible_count := int(layout.get("shop_stock_visible_count", 0))
			var stock_visible_index := 0
			for action in _actions:
				if str(action.get("id", "")) == ACTION_END_WORK:
					result.append(layout.get("end_work_rect", END_WORK_RECT))
				elif stock_visible_index >= stock_visible_count:
					result.append(Rect2())
					stock_visible_index += 1
				else:
					result.append(get_shop_cell_rect(
						stock_panel_rect,
						stock_visible_index,
						stock_columns,
						float(layout.get("shop_cell_size", SHOP_TRADE_CELL_SIZE)),
						float(layout.get("shop_cell_gap", SHOP_TRADE_CELL_GAP)),
						layout.get("shop_cell_start_offset", SHOP_TRADE_CELL_START_OFFSET)
					))
					stock_visible_index += 1
			return result
		var uses_hero_card := bool(layout.get("layout_flags", {}).get(
			LAYOUT_FLAG_HERO_CARD,
			false
		))
		if uses_hero_card:
			var hero_card_used := false
			for action in _actions:
				if str(action.get("id", "")) == ACTION_END_WORK:
					result.append(layout.get("end_work_rect", END_WORK_RECT))
				elif not hero_card_used:
					result.append(layout.get("hero_card_rect", HERO_CARD_RECT))
					hero_card_used = true
				else:
					result.append(Rect2())
			return result
		var card_grid_rect: Rect2 = layout.get("card_grid_rect", CARD_GRID_RECT)
		var column_gap := float(layout.get("grid_column_gap", GRID_COLUMN_GAP))
		var row_gap := float(layout.get("grid_row_gap", GRID_ROW_GAP))
		var columns := maxi(1, int(layout.get("card_grid_columns", CARD_GRID_COLUMNS)))
		var rows := maxi(1, int(layout.get("card_grid_rows", CARD_GRID_ROWS)))
		var column_width := (
			card_grid_rect.size.x - column_gap * float(columns - 1)
		) / float(columns)
		var row_height := (
			card_grid_rect.size.y - row_gap * float(rows - 1)
		) / float(rows)
		var card_index := 0
		var page_start := _visible_page * CARD_PAGE_SIZE if _uses_paged_cards() else 0
		var page_end := page_start + CARD_PAGE_SIZE
		for index in range(_actions.size()):
			if str(_actions[index].get("id", "")) == ACTION_END_WORK:
				result.append(layout.get("end_work_rect", END_WORK_RECT))
				continue
			if card_index < page_start or card_index >= page_end:
				result.append(Rect2())
				card_index += 1
				continue
			var visible_card_index := card_index - page_start
			var column := visible_card_index % columns
			var row := visible_card_index / columns
			result.append(Rect2(
				card_grid_rect.position + Vector2(
					float(column) * (column_width + column_gap),
					float(row) * (row_height + row_gap)
				),
				Vector2(column_width, row_height)
			))
			card_index += 1
		return result
	var content_scale := float(layout.get("content_scale", 1.0))
	var content_offset: Vector2 = layout.get("content_offset", Vector2.ZERO)
	for index in range(_actions.size()):
		result.append(_scale_rect(Rect2(
			ACTION_LIST_RECT.position + Vector2(0.0, float(index) * (ACTION_ROW_HEIGHT + ACTION_ROW_GAP)),
			Vector2(ACTION_LIST_RECT.size.x, ACTION_ROW_HEIGHT)
		), content_scale, content_offset))
	return result


func get_selected_action() -> Dictionary:
	if has_taiji_elder_presentation():
		return _action_at_index(_find_action_index_by_id(
			str(_taiji_elder_presentation.get_selected_action_id())
		))
	return _action_at_index(_keyboard_selected_index)


func build_view_model(view_size: Vector2 = BASE_VIEW_SIZE) -> Dictionary:
	var layout_flags := _build_layout_flags()
	var layout := build_screen_layout(view_size, layout_flags)
	var interaction_model := _build_interaction_model()
	var balance_receipt_texts: Dictionary = interaction_model.get(
		"balance_receipt_texts",
		{}
	)
	var node_description := TowerAscentNodeModalLocalization.node_description(_node_kind)
	if _node_kind == "guardian_spring":
		for action in _actions:
			if action is Dictionary and bool((action as Dictionary).get("first_visit_spoiler_gate", false)):
				node_description = ""
				break
	var result := {
		"node_id": _node_id,
		"node_kind": _node_kind,
		"title": TowerAscentNodeModalLocalization.node_title(_node_kind),
		"description": node_description,
		"balances": _balances.duplicate(true),
		"muhon_text": str(balance_receipt_texts.get("muhon", TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_BALANCE_MUHON,
			{"amount": int(_balances.get("muhon", 0))}
		))),
		"gold_text": str(balance_receipt_texts.get("gold", TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_BALANCE_GOLD,
			{"amount": int(_balances.get("gold", 0))}
		))),
		"actions": _actions.duplicate(true),
		"action_rects": get_action_rects(view_size, layout_flags),
		"selected_index": _keyboard_selected_index,
		"keyboard_selected_index": _keyboard_selected_index,
		"hovered_index": _hovered_index,
		"hovered_owned_index": _hovered_owned_index,
		"pressed_index": _pressed_index,
		"visible_page": _visible_page,
		"page_count": get_page_count(),
		"hovered_page_direction": _hovered_page_direction,
		"pressed_page_direction": _pressed_page_direction,
		"interaction_visuals": interaction_model.get("visuals", []),
		"has_pointer_visuals": bool(interaction_model.get("has_pointer_visuals", false)),
		"interaction_receipt": interaction_model.get("receipt", {}),
		"status_text": _status_text,
		"view_size": view_size,
		"modal_rect": layout.get("modal_rect", MODAL_RECT),
		"content_scale": layout.get("content_scale", 1.0),
		"content_offset": layout.get("content_offset", Vector2.ZERO),
		"layout_flags": layout.get("layout_flags", {}).duplicate(true),
		"card_grid_rect": layout.get("card_grid_rect", Rect2()),
		"shop_owned_items": _shop_owned_items.duplicate(true),
		"shop_stock_card_rects": (layout.get("shop_stock_card_rects", []) as Array).duplicate(),
		"shop_owned_slot_rects": (layout.get("shop_owned_slot_rects", []) as Array).duplicate(),
		"shop_owned_slot_capacity": _shop_owned_items.size(),
		"shop_owned_panel_rect": layout.get("shop_owned_panel_rect", Rect2()),
		"shop_player_panel_rect": layout.get("shop_player_panel_rect", Rect2()),
		"shop_stock_panel_rect": layout.get("shop_stock_panel_rect", Rect2()),
		"shop_player_columns": int(layout.get("shop_player_columns", 0)),
		"shop_player_rows": int(layout.get("shop_player_rows", 0)),
		"shop_stock_columns": int(layout.get("shop_stock_columns", 0)),
		"shop_stock_rows": int(layout.get("shop_stock_rows", 0)),
		"shop_player_visible_count": int(layout.get("shop_player_visible_count", 0)),
		"shop_stock_visible_count": int(layout.get("shop_stock_visible_count", 0)),
		"shop_cell_size": float(layout.get("shop_cell_size", 0.0)),
		"shop_cell_gap": float(layout.get("shop_cell_gap", 0.0)),
		"shop_cell_start_offset": layout.get("shop_cell_start_offset", Vector2.ZERO),
		"shop_player_label": "소지 아이템",
		"shop_stock_label": "상점 상품",
		"shop_owned_read_only_text": "소지 중 · 판매 불가",
		"shop_purchase_available_text": "구매 가능",
		"hero_card_rect": layout.get("hero_card_rect", Rect2()),
		"page_previous_rect": layout.get("page_previous_rect", Rect2()),
		"page_next_rect": layout.get("page_next_rect", Rect2()),
		"page_label_rect": layout.get("page_label_rect", Rect2()),
		"training_stage_rect": layout.get("training_stage_rect", Rect2()),
		"training_player_slot_rect": layout.get("training_player_slot_rect", Rect2()),
		"training_dummy_slot_rect": layout.get("training_dummy_slot_rect", Rect2()),
		"training_stats_rect": layout.get("training_stats_rect", Rect2()),
		"pointer_position": _pointer_position,
		"status_baseline": layout.get("status_baseline", STATUS_BASELINE),
	}
	if has_guardian_spring_presentation():
		var guardian_presentation: Dictionary = (
			_guardian_spring_presentation.build_visual_model(_actions, view_size)
		)
		guardian_presentation["confirmation_question"] = (
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_PALM_CONFIRM
			)
		)
		guardian_presentation["confirmation_no_text"] = LanguageSettings.translate("main_menu.no")
		guardian_presentation["confirmation_yes_text"] = LanguageSettings.translate("main_menu.yes")
		result["guardian_spring_presentation"] = guardian_presentation
		result["guardian_spring_prompt_text"] = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_PROMPT
		)
	if has_campfire_presentation():
		result["campfire_presentation"] = _campfire_presentation.build_visual_model(
			_actions,
			view_size
		)
	if has_taiji_elder_presentation():
		result["taiji_elder_presentation"] = (
			_taiji_elder_presentation.build_visual_model(_actions, view_size)
		)
	return result


func build_screen_layout(
	view_size: Vector2,
	layout_flags: Dictionary = {}
) -> Dictionary:
	var safe_view_size := Vector2(
		maxf(1.0, view_size.x),
		maxf(1.0, view_size.y)
	)
	var content_scale := minf(
		safe_view_size.x / BASE_VIEW_SIZE.x,
		safe_view_size.y / BASE_VIEW_SIZE.y
	)
	var content_offset := (safe_view_size - BASE_VIEW_SIZE * content_scale) * 0.5
	var resolved_flags := _resolve_layout_flags(layout_flags)
	var stock_count := _card_action_count()
	var owned_count := _shop_owned_items.size()
	var layout_signature := hash([safe_view_size, resolved_flags, stock_count, owned_count])
	if layout_signature == _layout_cache_signature and not _layout_cache.is_empty():
		return _layout_cache
	var uses_training_stage := bool(resolved_flags.get(
		LAYOUT_FLAG_TRAINING_STAGE,
		false
	))
	var uses_shop_compact := bool(resolved_flags.get(LAYOUT_FLAG_SHOP_COMPACT, false))
	var uses_shop_trade_panels := bool(resolved_flags.get(
		LAYOUT_FLAG_SHOP_TRADE_PANELS,
		false
	))
	var uses_shop_stacked := bool(resolved_flags.get(
		LAYOUT_FLAG_SHOP_STACKED,
		false
	))
	var uses_hero_card := bool(resolved_flags.get(LAYOUT_FLAG_HERO_CARD, false))
	var uses_page_controls := bool(resolved_flags.get(LAYOUT_FLAG_PAGE_CONTROLS, false))
	var card_grid_source := CARD_GRID_RECT
	var card_grid_columns := CARD_GRID_COLUMNS
	var card_grid_rows := CARD_GRID_ROWS
	var grid_column_gap := GRID_COLUMN_GAP
	var grid_row_gap := GRID_ROW_GAP
	if uses_training_stage:
		card_grid_source = TRAINING_CARD_GRID_RECT
		card_grid_columns = TRAINING_CARD_GRID_COLUMNS
		card_grid_rows = TRAINING_CARD_GRID_ROWS
		grid_column_gap = TRAINING_GRID_COLUMN_GAP
		grid_row_gap = TRAINING_GRID_ROW_GAP
	elif uses_shop_compact:
		card_grid_source = SHOP_CARD_GRID_RECT
		card_grid_columns = SHOP_CARD_GRID_COLUMNS
		card_grid_rows = SHOP_CARD_GRID_ROWS
		grid_column_gap = SHOP_GRID_COLUMN_GAP
		grid_row_gap = SHOP_GRID_ROW_GAP
	var end_work_source := (
		SHOP_STACKED_END_WORK_RECT
		if uses_shop_stacked
		else TRAINING_END_WORK_RECT if uses_training_stage else END_WORK_RECT
	)
	var player_grid := _shop_grid_dimensions(owned_count) if uses_shop_trade_panels else Vector2i.ZERO
	var stock_grid := _shop_grid_dimensions(stock_count) if uses_shop_trade_panels else Vector2i.ZERO
	var stacked_stock_panel := (
		_scale_rect(SHOP_STACKED_STOCK_PANEL_RECT, content_scale, content_offset)
		if uses_shop_stacked
		else Rect2()
	)
	var stacked_owned_panel := (
		_scale_rect(SHOP_STACKED_OWNED_PANEL_RECT, content_scale, content_offset)
		if uses_shop_stacked
		else Rect2()
	)
	var stacked_owned_slot_area := (
		_scale_rect(SHOP_STACKED_OWNED_SLOT_AREA_RECT, content_scale, content_offset)
		if uses_shop_stacked
		else Rect2()
	)
	var stacked_stock_card_rects: Array[Rect2] = []
	var stacked_owned_slot_rects: Array[Rect2] = []
	if uses_shop_stacked:
		stacked_stock_card_rects = build_shop_stock_card_rects(
			stacked_stock_panel,
			stock_count,
			content_scale
		)
		stacked_owned_slot_rects = build_shop_owned_slot_rects(
			stacked_owned_slot_area,
			owned_count,
			content_scale
		)
	_layout_cache_signature = layout_signature
	_layout_build_count += 1
	_layout_cache = {
		"content_scale": content_scale,
		"content_offset": content_offset,
		"modal_rect": _scale_rect(
			SHOP_STACKED_MODAL_RECT if uses_shop_stacked else MODAL_RECT,
			content_scale,
			content_offset
		),
		"layout_flags": resolved_flags,
		"card_grid_rect": _scale_rect(card_grid_source, content_scale, content_offset),
		"hero_card_rect": (
			_scale_rect(HERO_CARD_RECT, content_scale, content_offset)
			if uses_hero_card
			else Rect2()
		),
		"card_grid_columns": card_grid_columns,
		"card_grid_rows": card_grid_rows,
		"grid_column_gap": grid_column_gap * content_scale,
		"grid_row_gap": grid_row_gap * content_scale,
		"end_work_rect": _scale_rect(end_work_source, content_scale, content_offset),
		"shop_stock_card_rects": stacked_stock_card_rects,
		"shop_owned_slot_rects": stacked_owned_slot_rects,
		"shop_owned_panel_rect": stacked_owned_panel,
		"shop_player_panel_rect": (
			stacked_owned_panel
			if uses_shop_stacked
			else _scale_rect(SHOP_TRADE_PLAYER_PANEL_RECT, content_scale, content_offset)
			if uses_shop_trade_panels
			else Rect2()
		),
		"shop_stock_panel_rect": (
			stacked_stock_panel
			if uses_shop_stacked
			else _scale_rect(SHOP_TRADE_STOCK_PANEL_RECT, content_scale, content_offset)
			if uses_shop_trade_panels
			else Rect2()
		),
		"shop_player_columns": owned_count if uses_shop_stacked else player_grid.x,
		"shop_player_rows": 1 if uses_shop_stacked and owned_count > 0 else player_grid.y,
		"shop_stock_columns": SHOP_STACKED_STOCK_COLUMNS if uses_shop_stacked else stock_grid.x,
		"shop_stock_rows": 1 if uses_shop_stacked and stock_count > 0 else stock_grid.y,
		"shop_player_visible_count": owned_count if uses_shop_stacked else mini(owned_count, SHOP_TRADE_MAX_VISIBLE_CELLS),
		"shop_stock_visible_count": stacked_stock_card_rects.size() if uses_shop_stacked else mini(stock_count, SHOP_TRADE_MAX_VISIBLE_CELLS),
		"shop_cell_size": SHOP_TRADE_CELL_SIZE * content_scale,
		"shop_cell_gap": SHOP_TRADE_CELL_GAP * content_scale,
		"shop_cell_start_offset": SHOP_TRADE_CELL_START_OFFSET * content_scale,
		"page_previous_rect": (
			_scale_rect(PAGE_PREVIOUS_RECT, content_scale, content_offset)
			if uses_page_controls
			else Rect2()
		),
		"page_next_rect": (
			_scale_rect(PAGE_NEXT_RECT, content_scale, content_offset)
			if uses_page_controls
			else Rect2()
		),
		"page_label_rect": (
			_scale_rect(PAGE_LABEL_RECT, content_scale, content_offset)
			if uses_page_controls
			else Rect2()
		),
		"training_stage_rect": (
			_scale_rect(TRAINING_STAGE_RECT, content_scale, content_offset)
			if uses_training_stage
			else Rect2()
		),
		"training_player_slot_rect": (
			_scale_rect(TRAINING_PLAYER_SLOT_RECT, content_scale, content_offset)
			if uses_training_stage
			else Rect2()
		),
		"training_dummy_slot_rect": (
			_scale_rect(TRAINING_DUMMY_SLOT_RECT, content_scale, content_offset)
			if uses_training_stage
			else Rect2()
		),
		"training_stats_rect": (
			_scale_rect(TRAINING_STATS_RECT, content_scale, content_offset)
			if uses_training_stage
			else Rect2()
		),
		"status_baseline": _scale_point(
			SHOP_STACKED_STATUS_BASELINE
			if uses_shop_stacked
			else TRAINING_STATUS_BASELINE if uses_training_stage else STATUS_BASELINE,
			content_scale,
			content_offset
		),
	}
	return _layout_cache


func _scale_rect(rect: Rect2, scale_value: float, offset: Vector2) -> Rect2:
	return Rect2(offset + rect.position * scale_value, rect.size * scale_value)


func _scale_point(point: Vector2, scale_value: float, offset: Vector2) -> Vector2:
	return offset + point * scale_value


static func build_shop_stock_card_rects(
	panel_rect: Rect2,
	stock_count: int,
	content_scale: float = 1.0
) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var visible_count := mini(maxi(0, stock_count), SHOP_STACKED_STOCK_COLUMNS)
	if not panel_rect.has_area() or visible_count <= 0:
		return result
	var safe_scale := maxf(0.001, content_scale)
	var gap := SHOP_STACKED_STOCK_CARD_GAP * safe_scale
	var inset_x := SHOP_STACKED_STOCK_INSET_X * safe_scale
	var inner_width := maxf(0.0, panel_rect.size.x - inset_x * 2.0)
	var card_width := (
		inner_width - gap * float(SHOP_STACKED_STOCK_COLUMNS - 1)
	) / float(SHOP_STACKED_STOCK_COLUMNS)
	var card_height := minf(
		SHOP_STACKED_STOCK_CARD_HEIGHT * safe_scale,
		panel_rect.size.y - SHOP_STACKED_STOCK_TOP_INSET * safe_scale
	)
	if card_width <= 0.0 or card_height <= 0.0:
		return result
	for visible_index in range(visible_count):
		result.append(Rect2(
			panel_rect.position + Vector2(
				inset_x + float(visible_index) * (card_width + gap),
				SHOP_STACKED_STOCK_TOP_INSET * safe_scale
			),
			Vector2(card_width, card_height)
		))
	return result


static func build_shop_owned_slot_rects(
	area_rect: Rect2,
	slot_capacity: int,
	content_scale: float = 1.0
) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var safe_capacity := maxi(0, slot_capacity)
	if not area_rect.has_area() or safe_capacity <= 0:
		return result
	var safe_scale := maxf(0.001, content_scale)
	var minimum_gap := SHOP_STACKED_OWNED_SLOT_MIN_GAP * safe_scale
	var maximum_gap := SHOP_STACKED_OWNED_SLOT_MAX_GAP * safe_scale
	var slot_size := minf(
		SHOP_STACKED_OWNED_SLOT_MAX_SIZE * safe_scale,
		(
			area_rect.size.x - minimum_gap * float(maxi(0, safe_capacity - 1))
		) / float(safe_capacity)
	)
	if slot_size <= 0.0:
		return result
	var gap := 0.0
	if safe_capacity > 1:
		gap = clampf(
			(area_rect.size.x - slot_size * float(safe_capacity))
			/ float(safe_capacity - 1),
			minimum_gap,
			maximum_gap
		)
	var row_width := (
		slot_size * float(safe_capacity)
		+ gap * float(maxi(0, safe_capacity - 1))
	)
	var row_start := area_rect.position + Vector2(
		maxf(0.0, (area_rect.size.x - row_width) * 0.5),
		maxf(0.0, (area_rect.size.y - slot_size) * 0.5)
	)
	for slot_index in range(safe_capacity):
		result.append(Rect2(
			row_start + Vector2(float(slot_index) * (slot_size + gap), 0.0),
			Vector2.ONE * slot_size
		))
	return result


static func get_shop_cell_rect(
	panel_rect: Rect2,
	visible_index: int,
	columns: int = SHOP_TRADE_MAX_COLUMNS,
	cell_size: float = SHOP_TRADE_CELL_SIZE,
	cell_gap: float = SHOP_TRADE_CELL_GAP,
	start_offset: Vector2 = SHOP_TRADE_CELL_START_OFFSET
) -> Rect2:
	if not panel_rect.has_area() or visible_index < 0 or columns <= 0:
		return Rect2()
	var column := visible_index % columns
	var row := visible_index / columns
	return Rect2(
		panel_rect.position + start_offset + Vector2(
			float(column) * (cell_size + cell_gap),
			float(row) * (cell_size + cell_gap)
		),
		Vector2.ONE * cell_size
	)


func get_owned_cell_index_at(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> int:
	if _node_kind != "shop" or _shop_owned_items.is_empty():
		return -1
	var layout := build_screen_layout(view_size, _build_layout_flags())
	var stacked_slot_rects: Array = layout.get("shop_owned_slot_rects", [])
	if not stacked_slot_rects.is_empty():
		for visible_index in range(stacked_slot_rects.size() - 1, -1, -1):
			var slot_rect := stacked_slot_rects[visible_index] as Rect2
			if slot_rect.has_point(position):
				return visible_index
		return -1
	var panel_rect: Rect2 = layout.get("shop_player_panel_rect", Rect2())
	var columns := int(layout.get("shop_player_columns", 0))
	var visible_count := int(layout.get("shop_player_visible_count", 0))
	for visible_index in range(visible_count - 1, -1, -1):
		var cell_rect := get_shop_cell_rect(
			panel_rect,
			visible_index,
			columns,
			float(layout.get("shop_cell_size", SHOP_TRADE_CELL_SIZE)),
			float(layout.get("shop_cell_gap", SHOP_TRADE_CELL_GAP)),
			layout.get("shop_cell_start_offset", SHOP_TRADE_CELL_START_OFFSET)
		)
		if cell_rect.has_point(position):
			return visible_index
	return -1


func _shop_grid_dimensions(item_count: int) -> Vector2i:
	var visible_count := mini(maxi(0, item_count), SHOP_TRADE_MAX_VISIBLE_CELLS)
	if visible_count == 0:
		return Vector2i.ZERO
	var columns := mini(
		SHOP_TRADE_MAX_COLUMNS,
		maxi(1, int(ceil(sqrt(float(visible_count)))))
	)
	var rows := mini(
		SHOP_TRADE_MAX_ROWS,
		int(ceil(float(visible_count) / float(columns)))
	)
	return Vector2i(columns, rows)


func _invalidate_layout_cache() -> void:
	_layout_cache_signature = 0
	_layout_cache.clear()


func _build_layout_flags() -> Dictionary:
	return {
		LAYOUT_FLAG_TRAINING_STAGE: _node_kind == "training",
		LAYOUT_FLAG_SHOP_COMPACT: false,
		LAYOUT_FLAG_SHOP_TRADE_PANELS: false,
		LAYOUT_FLAG_SHOP_STACKED: _node_kind == "shop",
		LAYOUT_FLAG_HERO_CARD: (
			_node_kind in HERO_CARD_NODE_KINDS
			and _node_kind != "rest"
		),
		LAYOUT_FLAG_PAGE_CONTROLS: _uses_paged_cards() and get_page_count() > 1,
	}


func _resolve_layout_flags(layout_flags: Dictionary) -> Dictionary:
	var result := _build_layout_flags()
	for flag in [
		LAYOUT_FLAG_TRAINING_STAGE,
		LAYOUT_FLAG_SHOP_COMPACT,
		LAYOUT_FLAG_SHOP_TRADE_PANELS,
		LAYOUT_FLAG_SHOP_STACKED,
		LAYOUT_FLAG_HERO_CARD,
		LAYOUT_FLAG_PAGE_CONTROLS,
	]:
		if layout_flags.has(flag):
			result[flag] = bool(layout_flags.get(flag, false))
	return result


func _action_index_at_position(position: Vector2, view_size: Vector2) -> int:
	# GRT-022: rendering and hit testing resolve and pass the same layout flag.
	# In particular, compact training and stacked-shop cards must never be hit-tested with
	# legacy six-card rects after their node-specific layout is exposed.
	var layout_flags := _build_layout_flags()
	var rects := get_action_rects(view_size, layout_flags)
	# Reverse iteration makes a future overlap deterministic and agrees with the
	# visual topmost-card rule instead of accepting row-gap clicks.
	for index in range(rects.size() - 1, -1, -1):
		if (rects[index] as Rect2).has_point(position):
			return index
	return -1


func _training_stats_rect(view_size: Vector2) -> Rect2:
	if _node_kind != "training":
		return Rect2()
	return build_screen_layout(view_size, _build_layout_flags()).get(
		"training_stats_rect",
		Rect2()
	)


func _page_direction_at_position(position: Vector2, view_size: Vector2) -> int:
	var layout_flags := _build_layout_flags()
	if not bool(layout_flags.get(LAYOUT_FLAG_PAGE_CONTROLS, false)):
		return 0
	var layout := build_screen_layout(view_size, layout_flags)
	var previous_rect: Rect2 = layout.get("page_previous_rect", Rect2())
	var next_rect: Rect2 = layout.get("page_next_rect", Rect2())
	if previous_rect.has_point(position):
		return -1
	if next_rect.has_point(position):
		return 1
	return 0


func _uses_paged_cards() -> bool:
	return _node_kind in PAGED_CARD_NODE_KINDS


func _card_action_count() -> int:
	var count := 0
	for action in _actions:
		if str(action.get("id", "")) != ACTION_END_WORK:
			count += 1
	return count


func _ensure_selection_visible() -> void:
	if not _uses_paged_cards() or _keyboard_selected_index < 0:
		return
	if _action_id_at_index(_keyboard_selected_index) == ACTION_END_WORK:
		return
	var card_ordinal := 0
	for index in range(_actions.size()):
		if str(_actions[index].get("id", "")) == ACTION_END_WORK:
			continue
		if index == _keyboard_selected_index:
			_visible_page = clampi(
				card_ordinal / CARD_PAGE_SIZE,
				0,
				get_page_count() - 1
			)
			return
		card_ordinal += 1


func _select_first_action_on_visible_page() -> void:
	if not _uses_paged_cards():
		return
	var target_ordinal := _visible_page * CARD_PAGE_SIZE
	var card_ordinal := 0
	for index in range(_actions.size()):
		if str(_actions[index].get("id", "")) == ACTION_END_WORK:
			continue
		if card_ordinal == target_ordinal:
			_keyboard_selected_index = index
			return
		card_ordinal += 1


func _action_at_index(index: int) -> Dictionary:
	if index < 0 or index >= _actions.size():
		return {}
	return _actions[index].duplicate(true)


func _action_id_at_index(index: int) -> String:
	if index < 0 or index >= _actions.size():
		return ""
	return str(_actions[index].get("id", ""))


func _find_action_index_by_id(action_id: String) -> int:
	if action_id.is_empty():
		return -1
	for index in range(_actions.size()):
		if str(_actions[index].get("id", "")) == action_id:
			return index
	return -1


func _replace_actions(actions: Array) -> void:
	_actions.clear()
	var force_choice := false
	for action_value in actions:
		if action_value is Dictionary:
			var normalized_action := _normalize_action(action_value as Dictionary)
			_actions.append(normalized_action)
			var payload: Dictionary = normalized_action.get("payload", {}) as Dictionary
			force_choice = force_choice or bool(payload.get("force_choice", false))
	if _node_kind == "taiji_elder":
		return
	_actions.append(_normalize_action({
		"id": ACTION_END_WORK,
		"label": TowerAscentNodeModalLocalization.text(
			(
				TowerAscentNodeModalLocalization.KEY_SHOP_EXIT
				if _node_kind == "shop"
				else TowerAscentNodeModalLocalization.KEY_SPRING_EXIT
				if _node_kind == "guardian_spring"
				else TowerAscentNodeModalLocalization.KEY_END_WORK
			)
		),
		"enabled": not force_choice,
		"disabled_reason": "forced_node_choice" if force_choice else "",
		"unavailable_reason": (
			TowerAscentNodeModalLocalization.text(
				(
					TowerAscentNodeModalLocalization.KEY_CAMPFIRE_CHOICE_REQUIRED
					if _node_kind == "rest"
					else TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_PICK_REQUIRED
				)
			)
			if force_choice
			else ""
		),
	}))


func _build_interaction_model() -> Dictionary:
	var now_msec := _now_msec()
	_prune_hover_transitions(now_msec)
	var receipt := _active_receipt(now_msec)
	# GRT-043 fast path: the prevalent idle frame allocates no per-card visual
	# dictionaries and leaves the renderer on its invariant seven-argument call.
	if _hover_transitions.is_empty() and _pressed_index < 0 and receipt.is_empty():
		return {
			"visuals": [],
			"has_pointer_visuals": (
				_hovered_page_direction != 0 or _pressed_page_direction != 0
			),
			"receipt": {},
			"balance_receipt_texts": {},
		}
	var receipt_index := -1
	if not receipt.is_empty():
		receipt_index = _find_action_index_by_id(str(receipt.get("action_id", "")))
		if receipt_index < 0:
			receipt_index = clampi(int(receipt.get("fallback_index", -1)), 0, _actions.size() - 1)
	var strongest_hover := 0.0
	var hover_blends: Array[float] = []
	for index in range(_actions.size()):
		var blend := _hover_blend(str(_actions[index].get("id", "")), now_msec)
		hover_blends.append(blend)
		strongest_hover = maxf(strongest_hover, blend)
	var visuals: Array[Dictionary] = []
	var has_pointer_visuals := _pressed_index >= 0 or not receipt.is_empty()
	for index in range(_actions.size()):
		var hover_blend := hover_blends[index]
		var visual := {
			"hover_blend": hover_blend,
			"other_dim_amount": (
				0.10 * strongest_hover
				if strongest_hover > 0.0 and hover_blend < strongest_hover
				else 0.0
			),
			"pressed": index == _pressed_index,
			"success_progress": -1.0,
			"rejection_progress": -1.0,
			"receipt_message": "",
		}
		if hover_blend > 0.0:
			has_pointer_visuals = true
		if index == receipt_index:
			var progress := float(receipt.get("progress", 0.0))
			visual["receipt_message"] = str(receipt.get("message", ""))
			if bool(receipt.get("success", false)):
				visual["success_progress"] = progress
			else:
				visual["rejection_progress"] = progress
		visuals.append(visual)
	return {
		"visuals": visuals,
		"has_pointer_visuals": has_pointer_visuals,
		"receipt": receipt,
		"balance_receipt_texts": _build_balance_receipt_texts(receipt),
	}


func _set_hover_target(action_id: String, target: float, now_msec: int, duration_msec: int) -> void:
	var current := _hover_blend(action_id, now_msec)
	_hover_transitions[action_id] = {
		"from": current,
		"target": clampf(target, 0.0, 1.0),
		"started_msec": now_msec,
		"duration_msec": maxi(1, duration_msec),
	}


func _hover_blend(action_id: String, now_msec: int) -> float:
	var transition_value: Variant = _hover_transitions.get(action_id, {})
	if not (transition_value is Dictionary) or (transition_value as Dictionary).is_empty():
		return 0.0
	var transition := transition_value as Dictionary
	var elapsed := maxi(0, now_msec - int(transition.get("started_msec", now_msec)))
	var duration := maxi(1, int(transition.get("duration_msec", 1)))
	var progress := clampf(float(elapsed) / float(duration), 0.0, 1.0)
	return lerpf(
		float(transition.get("from", 0.0)),
		float(transition.get("target", 0.0)),
		progress * progress * (3.0 - 2.0 * progress)
	)


func _prune_hover_transitions(now_msec: int) -> void:
	for action_id_value in _hover_transitions.keys():
		var action_id := str(action_id_value)
		var transition: Dictionary = _hover_transitions.get(action_id, {})
		var elapsed := maxi(0, now_msec - int(transition.get("started_msec", now_msec)))
		if elapsed < int(transition.get("duration_msec", 1)):
			continue
		if float(transition.get("target", 0.0)) <= 0.0:
			_hover_transitions.erase(action_id)


func _active_receipt(now_msec: int) -> Dictionary:
	if _interaction_receipt.is_empty():
		return {}
	var elapsed := maxi(
		0,
		now_msec - int(_interaction_receipt.get("started_msec", now_msec))
	)
	var duration := maxi(1, int(_interaction_receipt.get("duration_msec", 1)))
	if elapsed >= duration:
		_interaction_receipt.clear()
		return {}
	var result := _interaction_receipt.duplicate(true)
	result["progress"] = clampf(float(elapsed) / float(duration), 0.0, 1.0)
	return result


func _build_balance_receipt_texts(receipt: Dictionary) -> Dictionary:
	if receipt.is_empty() or not bool(receipt.get("success", false)):
		return {}
	var before: Dictionary = receipt.get("balances_before", {})
	var after: Dictionary = receipt.get("balances", {})
	var result := {}
	for currency in ["muhon", "gold"]:
		if not before.has(currency) or not after.has(currency):
			continue
		var before_value := int(before.get(currency, 0))
		var after_value := int(after.get(currency, 0))
		if before_value == after_value:
			continue
		var key := (
			TowerAscentNodeModalLocalization.KEY_BALANCE_RECEIPT_MUHON
			if currency == "muhon"
			else TowerAscentNodeModalLocalization.KEY_BALANCE_RECEIPT_GOLD
		)
		result[currency] = TowerAscentNodeModalLocalization.text(key, {
			"before": before_value,
			"after": after_value,
			"delta": "%+d" % (after_value - before_value),
		})
	return result


func _now_msec() -> int:
	return _clock_override_msec if _clock_override_msec >= 0 else int(Time.get_ticks_msec())


func _dictionary_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _normalize_action(source: Dictionary) -> Dictionary:
	var enabled := bool(source.get("enabled", true))
	return {
		"id": str(source.get("id", "")).strip_edges(),
		"label": str(source.get("label", "")).strip_edges(),
		"cost_text": str(source.get("cost_text", "")).strip_edges(),
		"cost_gold": maxi(0, int(source.get("cost_gold", 0))),
		"enabled": enabled,
		"disabled_reason": str(source.get("disabled_reason", "")).strip_edges(),
		"unavailable_reason": str(source.get(
			"unavailable_reason",
			"" if enabled else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_STATUS_DISABLED
			)
		)).strip_edges(),
		"first_visit_spoiler_gate": bool(source.get("first_visit_spoiler_gate", false)),
		"payload": (
			(source.get("payload", {}) as Dictionary).duplicate(true)
			if source.get("payload", {}) is Dictionary
			else {}
		),
	}


func _normalize_balances(source: Dictionary) -> Dictionary:
	return {
		"gold": maxi(0, int(source.get("gold", 0))),
		"muhon": maxi(0, int(source.get("muhon", 0))),
		"chance_gems": maxi(0, int(source.get("chance_gems", 0))),
	}
