extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const GripStyleSelectionOverlayRenderer := preload("res://scripts/hud/grip_style_selection_overlay_renderer.gd")

const WASD_MOUSE_TEXTURE_PATH := "res://assets/ui/tutorial/grip_wasd_mouse.png"
const SPACE_ARROWS_TEXTURE_PATH := "res://assets/ui/tutorial/grip_space_arrows.png"
const GAMEPAD_TEXTURE_PATH := "res://assets/ui/tutorial/grip_gamepad_white.png"

const FADE_SECONDS := 0.18
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
	GripStyleSelectionOverlayRenderer.load_texture_at(_prewarm_step_index, textures, CARD_SPECS)
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
	var text_snapshot := get_text_snapshot()
	GripStyleSelectionOverlayRenderer.draw_overlay(
		canvas,
		view_size,
		alpha,
		selected_index,
		hovered_index,
		pressed_index,
		_pending_confirm,
		textures,
		CARD_SPECS,
		str(text_snapshot.get("title", "")),
		str(text_snapshot.get("subtitle", "")),
		str(text_snapshot.get("footer", "")),
		_text_size_cache
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
	return GripStyleSelectionOverlayRenderer.get_card_rects(view_size)


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
			"title": GripStyleSelectionOverlayRenderer.get_card_title(CARD_SPECS, i),
			"desc": GripStyleSelectionOverlayRenderer.get_card_desc(CARD_SPECS, i),
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
	GripStyleSelectionOverlayRenderer.ensure_textures(textures, CARD_SPECS)


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
	var ai_mode: String = BattleSceneConfig.normalize_league_mode(str(owner.get("ai_mode")))
	var character_type: String = str(owner.get("selected_character_type")).strip_edges().to_lower()
	# 그립 선택은 테스트(주니어) 시작 튜토리얼 캐릭터 공용: 스매셔/미카 + 코만도(soldier) + 바이퍼.
	return ai_mode == "junior" and (character_type in ["smasher", "mika", "soldier", "commando", "viper"])


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

func _get_card_spec(index: int) -> Dictionary:
	return GripStyleSelectionOverlayRenderer.get_card_spec(CARD_SPECS, index)


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
