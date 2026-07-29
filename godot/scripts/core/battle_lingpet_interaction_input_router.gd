extends RefCounted

const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0
const LINGPET_CYCLE_KEY := KEY_L
const GUARDIAN_TOGGLE_ACTION := &"guardian_toggle"
const GUARDIAN_TOGGLE_KEY := KEY_CTRL
const GUARDIAN_TOGGLE_BUTTON := JOY_BUTTON_RIGHT_STICK

var _guardian_toggle_button_latched := false


func handle_priority_cutin_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var runtime: Object = _get_lingpet_runtime(registry, module_getter)
	if runtime == null or not runtime.has_method("is_acquire_cutin_active"):
		return false
	# The shell-break sequence is a short no-input cinematic beat. Swallow input
	# so pause/save cannot open while the hatched egg is not yet committed.
	if runtime.has_method("is_hatch_break_active") and bool(runtime.is_hatch_break_active()):
		_mark_handled(owner)
		return true
	if not bool(runtime.is_acquire_cutin_active()):
		return false
	var overlay_input: Object = _get_module(module_getter, "battle_scene_overlay_input_controller")
	if overlay_input != null and overlay_input.has_method("handle_input"):
		overlay_input.handle_input(event, owner, registry, module_getter, {})
	_mark_handled(owner)
	return true


func handle_companion_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if _handle_guardian_toggle(event, owner, registry, module_getter):
		return true
	if _handle_companion_click(event, owner, registry, module_getter):
		return true
	return _handle_slot_switch(event, owner, registry, module_getter)


func _handle_guardian_toggle(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if not _consume_guardian_toggle_edge(event):
		return false
	var runtime: Object = _get_lingpet_runtime(registry, module_getter)
	if runtime == null or not runtime.has_method("try_toggle_guardian_stow"):
		return false
	if not bool(runtime.try_toggle_guardian_stow(owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_companion_click(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var runtime: Object = _get_lingpet_runtime(registry, module_getter)
	if runtime == null or not runtime.has_method("try_begin_companion_click_reaction"):
		return false
	var layout: Dictionary = _build_input_game_layout(owner, module_getter)
	var game_offset: Vector2 = _get_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var default_game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	var game_size: Vector2 = _get_vector2(layout.get("game_size", default_game_size), default_game_size)
	var render_scale: float = maxf(0.001, float(layout.get("render_scale", 1.0)))
	if not Rect2(game_offset, game_size).has_point(mouse_event.position):
		return false
	var playfield_pos: Vector2 = (mouse_event.position - game_offset) / render_scale
	if not bool(runtime.try_begin_companion_click_reaction(playfield_pos, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_slot_switch(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var cycle_direction := _get_lingpet_cycle_direction(event)
	if cycle_direction == 0:
		return false
	var runtime: Object = _get_lingpet_runtime(registry, module_getter)
	if runtime == null or not runtime.has_method("cycle_lingpet_slot"):
		return false
	if not bool(runtime.cycle_lingpet_slot(cycle_direction, owner, registry)):
		return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _consume_guardian_toggle_edge(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return false
		return (
			event.is_action_pressed(GUARDIAN_TOGGLE_ACTION)
			or key_event.keycode == GUARDIAN_TOGGLE_KEY
			or key_event.physical_keycode == GUARDIAN_TOGGLE_KEY
		)
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event
		if button_event.button_index != GUARDIAN_TOGGLE_BUTTON:
			return false
		if not button_event.pressed:
			_guardian_toggle_button_latched = false
			return false
		if _guardian_toggle_button_latched:
			return false
		_guardian_toggle_button_latched = true
		return true
	return false


func _get_lingpet_cycle_direction(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return 0
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return 0
	if key_event.keycode == LINGPET_CYCLE_KEY or key_event.physical_keycode == LINGPET_CYCLE_KEY:
		return -1 if key_event.shift_pressed else 1
	return 0


func _get_lingpet_runtime(registry: Object, module_getter: Callable) -> Object:
	var runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		runtime = _get_instance(registry, "lingpet_egg_runtime")
	return runtime


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


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	if owner != null and owner.has_method("get_viewport"):
		var viewport: Viewport = owner.get_viewport()
		if viewport != null:
			return viewport.get_visible_rect().size
	return Vector2(GAME_WIDTH, GAME_HEIGHT)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


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


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
