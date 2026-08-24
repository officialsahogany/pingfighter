extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerTrainingStrikePresentationState := preload(
	"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
)
const TowerTrainingTimingState := preload(
	"res://scripts/tower_ascent/tower_training_timing_state.gd"
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
const LAYOUT_FLAG_HERO_CARD := "hero_card"
const LAYOUT_FLAG_PAGE_CONTROLS := "page_controls"
const SHOP_CARD_GRID_RECT := Rect2(43.0, 150.0, 674.0, 226.0)
const SHOP_CARD_GRID_COLUMNS := 3
const SHOP_CARD_GRID_ROWS := 2
const SHOP_GRID_COLUMN_GAP := 12.0
const SHOP_GRID_ROW_GAP := 14.0
const TRAINING_CARD_GRID_RECT := Rect2(52.0, 150.0, 245.0, 476.0)
const TRAINING_CARD_GRID_COLUMNS := 1
const TRAINING_CARD_GRID_ROWS := 6
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
var _pointer_position := Vector2(-1.0, -1.0)
var _training_stats_hovered := false
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
	_status_text = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_STATUS_READY
	)


func close() -> void:
	_clear_training_stage_presentation()
	_clear_training_timing()
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


func set_balances(balances: Dictionary) -> void:
	_balances = _normalize_balances(balances)


func set_status_text(value: String) -> void:
	_status_text = value.strip_edges()


func move_selection(direction: int) -> void:
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
	var previous_stats_hovered := _training_stats_hovered
	_training_stats_hovered = _training_stats_rect(view_size).has_point(position)
	var next_hovered_index := _action_index_at_position(position, view_size)
	var next_page_direction := (
		_page_direction_at_position(position, view_size)
		if next_hovered_index < 0
		else 0
	)
	if (
		next_hovered_index == _hovered_index
		and next_page_direction == _hovered_page_direction
	):
		return previous_stats_hovered != _training_stats_hovered
	var now_msec := _now_msec()
	var previous_action_id := _action_id_at_index(_hovered_index)
	if not previous_action_id.is_empty():
		_set_hover_target(previous_action_id, 0.0, now_msec, HOVER_EXIT_MSEC)
	_hovered_index = next_hovered_index
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


func record_action_feedback(action: Dictionary, result: Dictionary) -> void:
	var action_id := str(action.get("id", "")).strip_edges()
	if action_id.is_empty():
		return
	var accepted := bool(result.get("accepted", false))
	var applied := bool(result.get("applied", false))
	var success := accepted and applied
	var message := str(result.get("message", result.get("reason", ""))).strip_edges()
	if message.is_empty():
		message = str(action.get("unavailable_reason", "")).strip_edges()
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
	return not _hover_transitions.is_empty() or _hovered_page_direction != 0


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
	var result: Array[Rect2] = []
	var layout := build_screen_layout(view_size, layout_flags)
	if _node_kind in CARD_NODE_KINDS:
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
	return _action_at_index(_keyboard_selected_index)


func build_view_model(view_size: Vector2 = BASE_VIEW_SIZE) -> Dictionary:
	var layout_flags := _build_layout_flags()
	var layout := build_screen_layout(view_size, layout_flags)
	var interaction_model := _build_interaction_model()
	var balance_receipt_texts: Dictionary = interaction_model.get(
		"balance_receipt_texts",
		{}
	)
	return {
		"node_id": _node_id,
		"node_kind": _node_kind,
		"title": TowerAscentNodeModalLocalization.node_title(_node_kind),
		"description": TowerAscentNodeModalLocalization.node_description(_node_kind),
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
	var layout_signature := hash([safe_view_size, resolved_flags])
	if layout_signature == _layout_cache_signature and not _layout_cache.is_empty():
		return _layout_cache
	var uses_training_stage := bool(resolved_flags.get(
		LAYOUT_FLAG_TRAINING_STAGE,
		false
	))
	var uses_shop_compact := bool(resolved_flags.get(LAYOUT_FLAG_SHOP_COMPACT, false))
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
	var end_work_source := TRAINING_END_WORK_RECT if uses_training_stage else END_WORK_RECT
	_layout_cache_signature = layout_signature
	_layout_build_count += 1
	_layout_cache = {
		"content_scale": content_scale,
		"content_offset": content_offset,
		"modal_rect": _scale_rect(MODAL_RECT, content_scale, content_offset),
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
			TRAINING_STATUS_BASELINE if uses_training_stage else STATUS_BASELINE,
			content_scale,
			content_offset
		),
	}
	return _layout_cache


func _scale_rect(rect: Rect2, scale_value: float, offset: Vector2) -> Rect2:
	return Rect2(offset + rect.position * scale_value, rect.size * scale_value)


func _scale_point(point: Vector2, scale_value: float, offset: Vector2) -> Vector2:
	return offset + point * scale_value


func _build_layout_flags() -> Dictionary:
	return {
		LAYOUT_FLAG_TRAINING_STAGE: _node_kind == "training",
		LAYOUT_FLAG_SHOP_COMPACT: _node_kind == "shop",
		LAYOUT_FLAG_HERO_CARD: _node_kind in HERO_CARD_NODE_KINDS,
		LAYOUT_FLAG_PAGE_CONTROLS: _uses_paged_cards() and get_page_count() > 1,
	}


func _resolve_layout_flags(layout_flags: Dictionary) -> Dictionary:
	var result := _build_layout_flags()
	for flag in [
		LAYOUT_FLAG_TRAINING_STAGE,
		LAYOUT_FLAG_SHOP_COMPACT,
		LAYOUT_FLAG_HERO_CARD,
		LAYOUT_FLAG_PAGE_CONTROLS,
	]:
		if layout_flags.has(flag):
			result[flag] = bool(layout_flags.get(flag, false))
	return result


func _action_index_at_position(position: Vector2, view_size: Vector2) -> int:
	# GRT-022: rendering and hit testing resolve and pass the same layout flag.
	# In particular, compact training/shop grids must never be hit-tested with
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
	_actions.append(_normalize_action({
		"id": ACTION_END_WORK,
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_END_WORK
		),
		"enabled": not force_choice,
		"disabled_reason": "forced_node_choice" if force_choice else "",
		"unavailable_reason": (
			TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_PICK_REQUIRED
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
		"enabled": enabled,
		"disabled_reason": str(source.get("disabled_reason", "")).strip_edges(),
		"unavailable_reason": str(source.get(
			"unavailable_reason",
			"" if enabled else TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_STATUS_DISABLED
			)
		)).strip_edges(),
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
