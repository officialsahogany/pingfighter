extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const WASD_MOUSE_TEXTURE_PATH := "res://assets/ui/tutorial/grip_wasd_mouse.png"
const SPACE_ARROWS_TEXTURE_PATH := "res://assets/ui/tutorial/grip_space_arrows.png"
const GAMEPAD_TEXTURE_PATH := "res://assets/ui/tutorial/grip_gamepad_white.png"

const FADE_SECONDS := 0.18
const CARD_GAP := 22.0
const CARD_RADIUS := 8.0
const TITLE_FONT_SIZE := 28
const CARD_TITLE_FONT_SIZE := 18
const CARD_DESC_FONT_SIZE := 13
const HINT_FONT_SIZE := 14
const CARD_ASPECT := 16.0 / 9.0
const CLICK_CONFIRM_DELAY := 0.12
const GAMEPAD_AXIS_SELECT_THRESHOLD := 0.90
const GAMEPAD_AXIS_RELEASE_THRESHOLD := 0.42

const CARD_SPECS := [
	{
		"id": "wasd_mouse",
		"title_key": "tutorial.grip.wasd_mouse.title",
		"title_fallback": "WASD + 마우스",
		"desc_key": "tutorial.grip.wasd_mouse.desc",
		"desc_fallback": "이동과 조준을 나눠 잡는 방식",
		"texture_path": WASD_MOUSE_TEXTURE_PATH,
	},
	{
		"id": "space_arrows",
		"title_key": "tutorial.grip.space_arrows.title",
		"title_fallback": "스페이스 + 방향키",
		"desc_key": "tutorial.grip.space_arrows.desc",
		"desc_fallback": "왼손 엄지는 스페이스, 오른손은 방향키",
		"texture_path": SPACE_ARROWS_TEXTURE_PATH,
	},
	{
		"id": "gamepad",
		"title_key": "tutorial.grip.gamepad.title",
		"title_fallback": "Xbox 패드",
		"desc_key": "tutorial.grip.gamepad.desc",
		"desc_fallback": "흰색 패드 기준 양손 조작",
		"texture_path": GAMEPAD_TEXTURE_PATH,
	},
]

var active := false
var completed := false
var selected_index := 0
var hovered_index := -1
var pressed_index := -1
var alpha := 0.0
var selected_style := ""
var textures: Array[Texture2D] = []
var _text_size_cache: Dictionary = {}
var _prewarm_step_index := 0
var _pending_confirm := false
var _confirm_timer := 0.0
var _last_language := ""
var _gamepad_horizontal_latch := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_step_index >= CARD_SPECS.size():
		_prewarm_step_index = 0
		return true
	_load_texture_at(_prewarm_step_index)
	_prewarm_step_index += 1
	return false


func update(delta: float, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var language_changed: bool = _refresh_language_state()
	if active:
		var previous_alpha: float = alpha
		alpha = min(1.0, alpha + max(0.0, delta) / FADE_SECONDS)
		var needs_redraw: bool = language_changed or not is_equal_approx(previous_alpha, alpha)
		if _pending_confirm:
			_confirm_timer = max(0.0, _confirm_timer - max(0.0, delta))
			needs_redraw = true
			if _confirm_timer <= 0.0:
				_finish_confirm_selection(owner, registry)
		return needs_redraw
	if completed:
		return false
	if _has_stored_grip_style(owner):
		_adopt_stored_grip_style(owner)
		return false
	if not _should_open(owner, registry, module_getter):
		return false
	_open()
	return true


func draw(canvas: CanvasItem, _owner: Object, view_size: Vector2) -> void:
	if canvas == null or not active:
		return
	_ensure_textures()
	var draw_alpha: float = clampf(alpha, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.52 * draw_alpha))
	var panel_rect: Rect2 = _get_panel_rect(view_size)
	_draw_round_rect(canvas, panel_rect, CARD_RADIUS, Color(0.96, 0.97, 0.98, 0.98 * draw_alpha))
	_draw_round_rect_outline(canvas, panel_rect, CARD_RADIUS, Color(0.16, 0.20, 0.26, 0.28 * draw_alpha), 2.0)

	var title_y: float = panel_rect.position.y + 42.0
	_draw_centered_text(canvas, _tr("tutorial.grip.title", "파지법 선택"), Vector2(panel_rect.get_center().x, title_y), TITLE_FONT_SIZE, Color(0.08, 0.10, 0.13, draw_alpha))
	_draw_centered_text(
		canvas,
		_tr("tutorial.grip.subtitle", "원하는 조작 자세를 고르면 경기가 시작됩니다"),
		Vector2(panel_rect.get_center().x, title_y + 34.0),
		HINT_FONT_SIZE,
		Color(0.24, 0.28, 0.34, 0.84 * draw_alpha)
	)

	var card_rects: Array[Rect2] = get_card_rects(view_size)
	for i in range(card_rects.size()):
		_draw_card(canvas, i, card_rects[i], draw_alpha)

	_draw_centered_text(
		canvas,
		_tr("tutorial.grip.footer", "← / → 선택   Enter / Space 확정"),
		Vector2(panel_rect.get_center().x, panel_rect.end.y - 28.0),
		HINT_FONT_SIZE,
		Color(0.30, 0.34, 0.40, 0.80 * draw_alpha)
	)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	if not active:
		return false
	if _pending_confirm:
		return true
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, view_size)
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, owner, registry, view_size)
	if event is InputEventKey:
		return _handle_key(event as InputEventKey, owner, registry)
	if event is InputEventJoypadMotion:
		return _handle_gamepad_motion(event as InputEventJoypadMotion)
	if event is InputEventJoypadButton:
		return _handle_gamepad_button(event as InputEventJoypadButton, owner, registry)
	if event.is_action_pressed("ui_left"):
		_select_relative(-1)
		return true
	if event.is_action_pressed("ui_right"):
		_select_relative(1)
		return true
	if event.is_action_pressed("ui_accept"):
		_finish_confirm_selection(owner, registry)
		return true
	return false


func is_active() -> bool:
	return active


func has_completed() -> bool:
	return completed


func get_selected_style() -> String:
	return selected_style


func get_card_rects(view_size: Vector2) -> Array[Rect2]:
	var panel_rect: Rect2 = _get_panel_rect(view_size)
	var inner_margin := 38.0
	var available_width: float = max(1.0, panel_rect.size.x - inner_margin * 2.0)
	var cards_top: float = panel_rect.position.y + 106.0
	var bottom_reserved := 64.0
	if view_size.x < 900.0:
		var vertical_card_width: float = min(360.0, available_width)
		var vertical_card_height: float = min(170.0, (panel_rect.end.y - cards_top - bottom_reserved - CARD_GAP * 2.0) / 3.0)
		var result: Array[Rect2] = []
		var vertical_start_x: float = panel_rect.get_center().x - vertical_card_width * 0.5
		for i in range(CARD_SPECS.size()):
			result.append(Rect2(Vector2(vertical_start_x, cards_top + float(i) * (vertical_card_height + CARD_GAP)), Vector2(vertical_card_width, vertical_card_height)))
		return result
	var card_width: float = min(320.0, (available_width - CARD_GAP * 2.0) / 3.0)
	var card_height: float = min(270.0, panel_rect.end.y - cards_top - bottom_reserved)
	var total_width: float = card_width * 3.0 + CARD_GAP * 2.0
	var start_x: float = panel_rect.get_center().x - total_width * 0.5
	var horizontal_result: Array[Rect2] = []
	for i in range(CARD_SPECS.size()):
		horizontal_result.append(Rect2(Vector2(start_x + float(i) * (card_width + CARD_GAP), cards_top), Vector2(card_width, card_height)))
	return horizontal_result


func _get_card_index_at_position(position: Vector2, view_size: Vector2) -> int:
	var card_rects: Array[Rect2] = get_card_rects(view_size)
	for i in range(card_rects.size()):
		if card_rects[i].has_point(position):
			return i
	return -1


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"completed": completed,
		"selected_index": selected_index,
		"hovered_index": hovered_index,
		"pressed_index": pressed_index,
		"selected_style": selected_style,
		"alpha": alpha,
		"pending_confirm": _pending_confirm,
		"language": _last_language,
	}


func get_text_snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for i in range(CARD_SPECS.size()):
		cards.append({
			"id": str(_get_card_spec(i).get("id", "")),
			"title": _get_card_title(i),
			"desc": _get_card_desc(i),
		})
	return {
		"title": _tr("tutorial.grip.title", "파지법 선택"),
		"subtitle": _tr("tutorial.grip.subtitle", "원하는 조작 자세를 고르면 경기가 시작됩니다"),
		"footer": _tr("tutorial.grip.footer", "← / → 선택   Enter / Space 확정"),
		"cards": cards,
	}


func _open() -> void:
	active = true
	alpha = 0.0
	selected_index = 2 if Input.get_connected_joypads().size() > 0 else 0
	hovered_index = -1
	pressed_index = -1
	selected_style = ""
	_pending_confirm = false
	_confirm_timer = 0.0
	_gamepad_horizontal_latch = 0
	_ensure_textures()


func _begin_confirm_selection() -> void:
	_pending_confirm = true
	_confirm_timer = CLICK_CONFIRM_DELAY
	pressed_index = selected_index


func _finish_confirm_selection(owner: Object, registry: Object) -> void:
	selected_style = str(_get_card_spec(selected_index).get("id", ""))
	active = false
	completed = true
	hovered_index = -1
	pressed_index = -1
	_pending_confirm = false
	_confirm_timer = 0.0
	if owner != null:
		owner.set_meta("tutorial_grip_style", selected_style)
		owner.set_meta("junior_mika_grip_style", selected_style)
	_sync_serve_input(registry)


func _should_open(owner: Object, _registry: Object, module_getter: Callable) -> bool:
	if not _is_junior_mika(owner):
		return false
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if ball_spawn_intro != null and _is_spawn_intro_visible(ball_spawn_intro):
		return false
	return true


func _is_junior_mika(owner: Object) -> bool:
	if owner == null:
		return false
	var ai_mode: String = _normalize_league_mode(str(owner.get("ai_mode")))
	var character_type: String = str(owner.get("selected_character_type")).strip_edges().to_lower()
	return ai_mode == "junior" and (character_type == "smasher" or character_type == "mika")


func _has_stored_grip_style(owner: Object) -> bool:
	return _get_stored_grip_style(owner) != ""


func _adopt_stored_grip_style(owner: Object) -> void:
	selected_style = _get_stored_grip_style(owner)
	if selected_style == "":
		return
	for i in range(CARD_SPECS.size()):
		if str(_get_card_spec(i).get("id", "")) == selected_style:
			selected_index = i
			break
	completed = true
	active = false
	hovered_index = -1
	pressed_index = -1
	_pending_confirm = false
	_confirm_timer = 0.0


func _get_stored_grip_style(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["tutorial_grip_style", "junior_mika_grip_style"]:
		if owner.has_meta(key):
			var normalized: String = _normalize_grip_style(str(owner.get_meta(key)))
			if normalized != "":
				return normalized
	return ""


func _is_spawn_intro_visible(ball_spawn_intro: Object) -> bool:
	if ball_spawn_intro.has_method("is_overlay_active") and bool(ball_spawn_intro.is_overlay_active()):
		return true
	if ball_spawn_intro.has_method("is_active") and bool(ball_spawn_intro.is_active()):
		return true
	return false


func _handle_mouse_motion(mouse_event: InputEventMouseMotion, view_size: Vector2) -> bool:
	var next_hovered_index: int = _get_card_index_at_position(mouse_event.position, view_size)
	var changed: bool = next_hovered_index != hovered_index
	hovered_index = next_hovered_index
	if hovered_index >= 0:
		if selected_index != hovered_index:
			selected_index = hovered_index
			changed = true
	elif pressed_index >= 0:
		pressed_index = -1
		changed = true
	return changed


func _handle_mouse_button(mouse_event: InputEventMouseButton, _owner: Object, _registry: Object, view_size: Vector2) -> bool:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return true
	var mouse_card_index: int = _get_card_index_at_position(mouse_event.position, view_size)
	hovered_index = mouse_card_index
	if mouse_event.pressed:
		pressed_index = mouse_card_index
		if mouse_card_index >= 0:
			selected_index = mouse_card_index
		return true
	var released_pressed_index: int = pressed_index
	pressed_index = -1
	if mouse_card_index >= 0 and mouse_card_index == released_pressed_index:
		selected_index = mouse_card_index
		_begin_confirm_selection()
	return true


func _handle_key(key_event: InputEventKey, owner: Object, registry: Object) -> bool:
	if not key_event.pressed or key_event.echo:
		return true
	for i in range(CARD_SPECS.size()):
		if _is_key(key_event, KEY_1 + i):
			selected_index = i
			_finish_confirm_selection(owner, registry)
			return true
	if _is_key(key_event, KEY_LEFT) or _is_key(key_event, KEY_A):
		_select_relative(-1)
		return true
	if _is_key(key_event, KEY_RIGHT) or _is_key(key_event, KEY_D):
		_select_relative(1)
		return true
	if _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE):
		_finish_confirm_selection(owner, registry)
		return true
	return true


func _handle_gamepad_motion(motion_event: InputEventJoypadMotion) -> bool:
	if motion_event.axis != JOY_AXIS_LEFT_X:
		return true
	var axis_value: float = motion_event.axis_value
	if absf(axis_value) <= GAMEPAD_AXIS_RELEASE_THRESHOLD:
		_gamepad_horizontal_latch = 0
		return true
	var direction := 0
	if axis_value <= -GAMEPAD_AXIS_SELECT_THRESHOLD:
		direction = -1
	elif axis_value >= GAMEPAD_AXIS_SELECT_THRESHOLD:
		direction = 1
	if direction == 0:
		return true
	if _gamepad_horizontal_latch == direction:
		return true
	_gamepad_horizontal_latch = direction
	_select_relative(direction)
	return true


func _handle_gamepad_button(button_event: InputEventJoypadButton, owner: Object, registry: Object) -> bool:
	if not button_event.pressed:
		return true
	match button_event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			_gamepad_horizontal_latch = 0
			_select_relative(-1)
		JOY_BUTTON_DPAD_RIGHT:
			_gamepad_horizontal_latch = 0
			_select_relative(1)
		JOY_BUTTON_A, JOY_BUTTON_START:
			_finish_confirm_selection(owner, registry)
	return true


func _select_relative(delta: int) -> void:
	selected_index = wrapi(selected_index + delta, 0, CARD_SPECS.size())
	hovered_index = -1
	pressed_index = -1


func _draw_card(canvas: CanvasItem, index: int, card_rect: Rect2, draw_alpha: float) -> void:
	var selected: bool = index == selected_index
	var hovered: bool = index == hovered_index
	var pressed: bool = index == pressed_index or (_pending_confirm and selected)
	var visual_rect: Rect2 = card_rect
	if pressed:
		visual_rect.position.y += 2.0
	elif hovered:
		visual_rect.position.y -= 4.0
		visual_rect = visual_rect.grow(3.0)
	var shadow_alpha: float = 0.20 if (hovered or selected or pressed) else 0.08
	var shadow_offset := Vector2(0.0, 7.0 if (hovered or pressed) else 4.0)
	_draw_round_rect(canvas, Rect2(visual_rect.position + shadow_offset, visual_rect.size), CARD_RADIUS, Color(0.0, 0.0, 0.0, shadow_alpha * draw_alpha))
	var card_color := Color(1.0, 1.0, 1.0, 0.98 * draw_alpha)
	if hovered:
		card_color = Color(0.96, 0.99, 1.0, 1.0 * draw_alpha)
	if pressed:
		card_color = Color(0.88, 0.96, 1.0, 1.0 * draw_alpha)
	var border_color := Color(0.12, 0.55, 0.94, 0.95 * draw_alpha) if selected else Color(0.18, 0.22, 0.28, 0.18 * draw_alpha)
	var border_width := 3.0 if selected else 1.4
	if hovered:
		border_color = Color(0.09, 0.66, 1.0, 1.0 * draw_alpha)
		border_width = 3.6
	if pressed:
		border_color = Color(0.02, 0.42, 0.98, 1.0 * draw_alpha)
		border_width = 4.2
	_draw_round_rect(canvas, visual_rect, CARD_RADIUS, card_color)
	_draw_round_rect_outline(canvas, visual_rect, CARD_RADIUS, border_color, border_width)
	var image_margin := 12.0
	var image_rect := Rect2(
		visual_rect.position + Vector2(image_margin, image_margin),
		Vector2(visual_rect.size.x - image_margin * 2.0, (visual_rect.size.x - image_margin * 2.0) / CARD_ASPECT)
	)
	image_rect.size.y = min(image_rect.size.y, visual_rect.size.y - 92.0)
	var texture: Texture2D = _get_texture(index)
	if texture != null:
		canvas.draw_texture_rect(texture, image_rect, false, Color(1.0, 1.0, 1.0, draw_alpha))
	else:
		canvas.draw_rect(image_rect, Color(0.90, 0.92, 0.95, draw_alpha))
	_draw_centered_text(canvas, _get_card_title(index), Vector2(visual_rect.get_center().x, image_rect.end.y + 26.0), CARD_TITLE_FONT_SIZE, Color(0.08, 0.10, 0.14, draw_alpha))
	_draw_centered_text(canvas, _get_card_desc(index), Vector2(visual_rect.get_center().x, image_rect.end.y + 49.0), CARD_DESC_FONT_SIZE, Color(0.32, 0.36, 0.42, 0.86 * draw_alpha))


func _draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)


func _draw_round_rect_outline(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	canvas.draw_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, PI * 1.5, TAU, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, 0.0, PI * 0.5, 10, color, width)
	canvas.draw_arc(rect.position + Vector2(radius, rect.size.y - radius), radius, PI * 0.5, PI, 10, color, width)
	canvas.draw_line(rect.position + Vector2(radius, 0.0), rect.position + Vector2(rect.size.x - radius, 0.0), color, width)
	canvas.draw_line(rect.position + Vector2(rect.size.x, radius), rect.position + Vector2(rect.size.x, rect.size.y - radius), color, width)
	canvas.draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), color, width)
	canvas.draw_line(rect.position + Vector2(0.0, radius), rect.position + Vector2(0.0, rect.size.y - radius), color, width)


func _draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = _get_text_size(font, text, font_size)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 1.0, 1.0, min(color.a, 0.80)))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_panel_rect(view_size: Vector2) -> Rect2:
	var panel_width: float = min(view_size.x - 64.0, 1120.0)
	var panel_height: float = min(view_size.y - 64.0, 472.0)
	if view_size.x < 900.0:
		panel_width = min(view_size.x - 32.0, 430.0)
		panel_height = min(view_size.y - 32.0, 690.0)
	return Rect2((view_size - Vector2(panel_width, panel_height)) * 0.5, Vector2(panel_width, panel_height))


func _get_card_spec(index: int) -> Dictionary:
	if index < 0 or index >= CARD_SPECS.size():
		return {}
	var value: Variant = CARD_SPECS[index]
	if value is Dictionary:
		return value
	return {}


func _get_card_title(index: int) -> String:
	var spec: Dictionary = _get_card_spec(index)
	return _tr(str(spec.get("title_key", "")), str(spec.get("title_fallback", "")))


func _get_card_desc(index: int) -> String:
	var spec: Dictionary = _get_card_spec(index)
	return _tr(str(spec.get("desc_key", "")), str(spec.get("desc_fallback", "")))


func _ensure_textures() -> void:
	while textures.size() < CARD_SPECS.size():
		textures.append(null)
	for i in range(CARD_SPECS.size()):
		_load_texture_at(i)


func _load_texture_at(index: int) -> void:
	while textures.size() < CARD_SPECS.size():
		textures.append(null)
	if textures[index] != null:
		return
	var texture_path: String = str(_get_card_spec(index).get("texture_path", ""))
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return
	var loaded: Resource = ResourceLoader.load(texture_path)
	if loaded is Texture2D:
		textures[index] = loaded as Texture2D


func _get_texture(index: int) -> Texture2D:
	if index < 0 or index >= textures.size():
		return null
	return textures[index]


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key := "%d:%s" % [font_size, text]
	if _text_size_cache.has(cache_key):
		var cached_size: Variant = _text_size_cache[cache_key]
		if cached_size is Vector2:
			return cached_size
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


func _sync_serve_input(registry: Object) -> void:
	var serve_flow: Object = _get_instance(registry, "serve_flow_controller")
	if serve_flow != null and serve_flow.has_method("sync_current_input_state"):
		serve_flow.sync_current_input_state()


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _normalize_league_mode(mode: String) -> String:
	var normalized := mode.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	return normalized


func _normalize_grip_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized in ["wasd_mouse", "wasd", "keyboard_mouse"]:
		return "wasd_mouse"
	if normalized in ["space_arrows", "space_arrow", "arrows", "arrow_keys", "arrows_space"]:
		return "space_arrows"
	if normalized in ["gamepad", "xbox", "controller", "pad"]:
		return "gamepad"
	return ""


func _tr(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	return LanguageSettings.translate(key, fallback)


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return true


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode
