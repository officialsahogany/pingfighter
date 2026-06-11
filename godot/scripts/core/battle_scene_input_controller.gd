extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0
const FULLSCREEN_TOGGLE_KEY := KEY_F11
const BGM_TOGGLE_KEY := KEY_B
const FORCE_STAGE_CLEAR_KEY := KEY_F9
const FORCE_STAGE_CLEAR_PLAYER_SCORE := 5
const FORCE_STAGE_CLEAR_BOSS_SCORE := 0
const LINGPET_CYCLE_KEY := KEY_L
const RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC := 450

var _right_stick_mouse_wheel_suppress_until_msec := 0


func handle_unhandled_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> void:
	if _handle_window_shortcut(event, owner, module_getter):
		return
	if _handle_bgm_shortcut(event, owner, module_getter):
		return
	if _handle_right_stick_suppression(event, owner):
		return
	if _is_stage_transition_loading_active(module_getter):
		_queue_redraw(owner)
		_mark_handled(owner)
		return
	if _handle_mobile_touch_input(event, owner, module_getter, bool(context.get("mobile_touch_scene_ready", false))):
		return
	if _handle_force_stage_clear_shortcut(event, owner, registry, module_getter, context):
		return
	if _is_intro_or_warmup_blocking(module_getter, context):
		return
	var intro_input: Object = _get_intro_input_controller(module_getter)
	if intro_input != null and intro_input.has_method("handle_input"):
		if bool(intro_input.handle_input(event, owner, registry, module_getter, context)):
			return

	if _handle_lingpet_acquire_cutin_input(event, owner, registry, module_getter):
		return
	if _handle_stage_clear_result_input(event, owner, registry, module_getter):
		return
	if _handle_runtime_perk_choice_input(event, owner, registry, module_getter):
		return
	if _handle_mythic_acquisition_input(event, owner, registry, module_getter):
		return
	if _handle_pandora_legacy_selection_input(event, owner, registry, module_getter):
		return

	var overlay_input: Object = _get_overlay_input_controller(module_getter)
	if overlay_input != null and overlay_input.has_method("handle_input"):
		if bool(overlay_input.handle_input(event, owner, registry, module_getter, context)):
			return
	if _handle_lingpet_companion_click(event, owner, registry, module_getter):
		return
	if _handle_lingpet_slot_switch(event, owner, registry, module_getter):
		return
	if _handle_skill_orb_tooltip_cycle(event, owner, registry, module_getter):
		return
	if _handle_commando_weapon_switch(event, owner, registry, module_getter):
		return


func _handle_mobile_touch_input(event: InputEvent, owner: Object, module_getter: Callable, scene_ready: bool) -> bool:
	var mobile_touch: Object = _get_module(module_getter, "battle_mobile_touch_controller")
	if mobile_touch == null or not mobile_touch.has_method("handle_input"):
		return false
	return bool(mobile_touch.handle_input(event, owner, module_getter, scene_ready))


func _handle_right_stick_suppression(event: InputEvent, owner: Object) -> bool:
	if GamepadInput.should_suppress_right_stick_event(event):
		_right_stick_mouse_wheel_suppress_until_msec = Time.get_ticks_msec() + RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC
		_mark_handled(owner)
		return true
	if _is_mouse_wheel_event(event) and Time.get_ticks_msec() <= _right_stick_mouse_wheel_suppress_until_msec:
		_mark_handled(owner)
		return true
	return false


func _handle_window_shortcut(event: InputEvent, owner: Object, module_getter: Callable) -> bool:
	if not _is_key_pressed(event, FULLSCREEN_TOGGLE_KEY):
		return false
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout == null or not view_layout.has_method("toggle_fullscreen"):
		return false
	if owner == null or not owner.has_method("get_window"):
		return false
	view_layout.toggle_fullscreen(owner.get_window())
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_bgm_shortcut(event: InputEvent, owner: Object, module_getter: Callable) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio == null or not audio.has_method("toggle_bgm"):
		return false
	audio.toggle_bgm()
	_mark_handled(owner)
	return true


func _handle_commando_weapon_switch(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var input_reader: Object = _get_module(module_getter, "commando_input_reader")
	if input_reader == null or not input_reader.has_method("handle_weapon_switch_event"):
		return false
	if not bool(input_reader.handle_weapon_switch_event(event, owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_lingpet_slot_switch(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		runtime = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null:
		return false
	var cycle_direction := _get_lingpet_cycle_direction(event)
	if cycle_direction != 0:
		if not runtime.has_method("cycle_lingpet_slot"):
			return false
		if not bool(runtime.cycle_lingpet_slot(cycle_direction, owner, registry)):
			return false
		_queue_redraw(owner)
		_mark_handled(owner)
		return true
	return false


func _handle_lingpet_companion_click(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		runtime = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("try_begin_companion_click_reaction"):
		return false
	var layout: Dictionary = _build_input_game_layout(owner, module_getter)
	var game_offset: Vector2 = _get_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout.get("game_size", Vector2(GAME_WIDTH, GAME_HEIGHT)), Vector2(GAME_WIDTH, GAME_HEIGHT))
	var render_scale: float = maxf(0.001, float(layout.get("render_scale", 1.0)))
	var game_rect := Rect2(game_offset, game_size)
	if not game_rect.has_point(mouse_event.position):
		return false
	var playfield_pos: Vector2 = (mouse_event.position - game_offset) / render_scale
	if not bool(runtime.try_begin_companion_click_reaction(playfield_pos, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_lingpet_acquire_cutin_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		runtime = _get_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("is_acquire_cutin_active"):
		return false
	if not bool(runtime.is_acquire_cutin_active()):
		return false
	var overlay_input: Object = _get_overlay_input_controller(module_getter)
	if overlay_input != null and overlay_input.has_method("handle_input"):
		overlay_input.handle_input(event, owner, registry, module_getter, {})
	_mark_handled(owner)
	return true


func _get_lingpet_cycle_direction(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return 0
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return 0
	if key_event.keycode == LINGPET_CYCLE_KEY or key_event.physical_keycode == LINGPET_CYCLE_KEY:
		return -1 if key_event.shift_pressed else 1
	return 0


func _handle_stage_clear_result_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if result_screen == null or not result_screen.has_method("is_active") or not bool(result_screen.is_active()):
		return false
	if _is_runtime_perk_choice_active(module_getter):
		var overlay_input: Object = _get_overlay_input_controller(module_getter)
		if overlay_input != null and overlay_input.has_method("handle_input"):
			overlay_input.handle_input(event, owner, registry, module_getter, {})
		_queue_redraw(owner)
		_mark_handled(owner)
		return true
	if result_screen.has_method("handle_input"):
		result_screen.handle_input(event, owner, registry, _get_view_size(owner))
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_runtime_perk_choice_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	if not _is_runtime_perk_choice_active(module_getter):
		return false
	var overlay_input: Object = _get_overlay_input_controller(module_getter)
	if overlay_input != null and overlay_input.has_method("handle_input"):
		overlay_input.handle_input(event, owner, registry, module_getter, {})
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_skill_orb_tooltip_cycle(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	if not GamepadInput.is_skill_tooltip_cycle_event(event) and not _is_arrow_space_grip_skill_tooltip_event(event, owner):
		return false
	var skill_tooltip_driver: Object = _get_module(module_getter, "battle_scene_skill_tooltip_driver")
	if skill_tooltip_driver == null or not skill_tooltip_driver.has_method("cycle_gamepad_tooltip"):
		return false
	if not bool(skill_tooltip_driver.cycle_gamepad_tooltip(owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_arrow_space_grip_skill_tooltip_event(event: InputEvent, owner: Object) -> bool:
	if not _is_key_pressed(event, KEY_SHIFT):
		return false
	return _get_owner_grip_style(owner) == "space_arrows"


func _get_owner_grip_style(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["tutorial_grip_style", "junior_mika_grip_style"]:
		if owner.has_meta(key):
			var normalized: String = _normalize_grip_style(str(owner.get_meta(key, "")))
			if normalized != "":
				return normalized
	return ""


func _normalize_grip_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized == "space_arrows" or normalized == "arrows_space":
		return "space_arrows"
	return normalized


func _handle_force_stage_clear_shortcut(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	if not _is_key_pressed(event, FORCE_STAGE_CLEAR_KEY):
		return false
	if not bool(context.get("battle_initialized", false)):
		return false
	if not bool(context.get("stage_landing_intro_started", false)):
		return false

	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active()):
		_mark_handled(owner)
		return true

	_force_player_stage_clear_score(registry, module_getter)
	_start_debug_scoreboard_snapshot(registry, module_getter)
	if result_screen != null and result_screen.has_method("show_from_scoreboard"):
		var reset_callback: Callable = context.get("reset_game_after_stage_clear", Callable())
		var exit_callback: Callable = context.get("exit_to_menu_after_stage_clear", Callable())
		result_screen.show_from_scoreboard(owner, registry, reset_callback, exit_callback)

	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_mythic_acquisition_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	if not mythic_item_runtime.has_method("is_acquisition_cinematic_active"):
		return false
	if not bool(mythic_item_runtime.is_acquisition_cinematic_active()):
		return false
	if mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		mythic_item_runtime.handle_acquisition_cinematic_input(event, registry)
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_pandora_legacy_selection_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	if not mythic_item_runtime.has_method("is_pandora_legacy_selection_active"):
		return false
	if not bool(mythic_item_runtime.is_pandora_legacy_selection_active()):
		return false
	if mythic_item_runtime.has_method("handle_pandora_legacy_selection_input"):
		mythic_item_runtime.handle_pandora_legacy_selection_input(
			event,
			owner,
			registry,
			_get_view_size(owner)
		)
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _is_mouse_wheel_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return false
	return (
		mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	)


func _is_intro_or_warmup_blocking(module_getter: Callable, context: Dictionary) -> bool:
	var readiness: Object = _get_readiness_controller(module_getter)
	if readiness == null or not readiness.has_method("is_intro_or_warmup_blocking"):
		return true
	return bool(readiness.is_intro_or_warmup_blocking(
		module_getter,
		bool(context.get("battle_initialized", false)),
		bool(context.get("stage_landing_intro_started", false))
	))


func _is_stage_transition_loading_active(module_getter: Callable) -> bool:
	var match_event_driver: Object = _get_module(module_getter, "battle_scene_match_event_driver")
	return (
		match_event_driver != null
		and match_event_driver.has_method("is_stage_transition_loading_active")
		and bool(match_event_driver.is_stage_transition_loading_active())
	)


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	return (
		modal_gate != null
		and modal_gate.has_method("is_runtime_perk_choice_active")
		and bool(modal_gate.is_runtime_perk_choice_active(module_getter))
	)


func _get_readiness_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_readiness_controller")


func _get_intro_input_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_intro_input_controller")


func _get_overlay_input_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_overlay_input_controller")


func _force_player_stage_clear_score(registry: Object, module_getter: Callable) -> void:
	var score_state: Object = _get_module(module_getter, "match_score_state")
	if score_state == null:
		score_state = _get_instance(registry, "match_score_state")
	if score_state == null:
		return
	if score_state.has_method("force_score"):
		score_state.force_score(FORCE_STAGE_CLEAR_PLAYER_SCORE, FORCE_STAGE_CLEAR_BOSS_SCORE)
		return
	score_state.set("player_score", FORCE_STAGE_CLEAR_PLAYER_SCORE)
	score_state.set("boss_score", FORCE_STAGE_CLEAR_BOSS_SCORE)
	score_state.set("deuce_mode", false)


func _start_debug_scoreboard_snapshot(registry: Object, module_getter: Callable) -> void:
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	if scoreboard_state == null:
		scoreboard_state = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null:
		return
	if scoreboard_state.has_method("start"):
		scoreboard_state.start(
			FORCE_STAGE_CLEAR_PLAYER_SCORE,
			FORCE_STAGE_CLEAR_BOSS_SCORE,
			true,
			"player"
		)


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


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	if owner != null and owner.has_method("get_viewport"):
		var viewport: Viewport = owner.get_viewport()
		if viewport != null:
			return viewport.get_visible_rect().size
	return Vector2(760.0, 750.0)


func _build_input_game_layout(owner: Object, module_getter: Callable) -> Dictionary:
	var view_size := _get_view_size(owner)
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout != null and view_layout.has_method("build_game_layout"):
		return view_layout.build_game_layout(view_size, GAME_WIDTH, GAME_HEIGHT)
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	return {
		"view_size": view_size,
		"game_offset": (view_size - game_size) * 0.5,
		"game_size": game_size,
		"render_scale": 1.0,
	}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
