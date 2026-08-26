extends RefCounted

const CharacterInfoLingpetPrewarmFilter := preload(
	"res://scripts/hud/character_info_lingpet_prewarm_filter.gd"
)

const CHARACTER_INFO_KEY := KEY_TAB


func handle_active_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if not _call_modal_gate_bool(module_getter, "is_character_info_active"):
		return false
	var character_info := _get_module(module_getter, "character_info_overlay")
	if character_info != null and character_info.has_method("handle_input"):
		var handled := bool(character_info.handle_input(
			event,
			owner,
			registry,
			view_size
		))
		if handled:
			if _should_queue_input_redraw(character_info):
				_queue_overlay_redraw(owner, registry, module_getter)
			_mark_handled(owner)
	return true


func handle_open_shortcut(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if not _is_key_pressed(event, CHARACTER_INFO_KEY):
		return false
	var character_info := _get_module(module_getter, "character_info_overlay")
	if character_info != null and character_info.has_method("open"):
		_close_overlay("pause_menu_overlay", "close", module_getter)
		_prewarm(character_info, owner, registry, module_getter, view_size)
		# 열기 큐는 여기서 재생하지 않는다 — 정본은 CharacterInfoOverlay.open()이라
		# 광장 TAB / 일시정지 메뉴 진입도 같은 소리를 상속한다.
		_open(character_info, owner, registry)
		_queue_overlay_redraw(owner, registry, module_getter)
		_mark_handled(owner)
		return true
	return false


func open_from_pause(
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	var character_info := _get_module(module_getter, "character_info_overlay")
	if character_info == null or not character_info.has_method("open"):
		return
	_prewarm(character_info, owner, registry, module_getter, view_size)
	_open(character_info, owner, registry)


func _prewarm(
	character_info: Object,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	if not character_info.has_method("prewarm_assets"):
		return
	var lingpet_prewarm_pet_ids := (
		CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids(
			owner,
			registry,
			module_getter
		)
	)
	character_info.prewarm_assets(
		owner,
		registry,
		module_getter,
		true,
		view_size,
		lingpet_prewarm_pet_ids
	)


func _open(character_info: Object, owner: Object, registry: Object) -> void:
	if _method_accepts_argument_count(character_info, "open", 2):
		character_info.open(owner, registry)
	else:
		character_info.open()


func _should_queue_input_redraw(character_info: Object) -> bool:
	if character_info.has_method("consume_input_redraw_request"):
		return bool(character_info.consume_input_redraw_request())
	return true


func _queue_overlay_redraw(
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var overlay_frame := _get_module(
		module_getter,
		"battle_scene_overlay_frame_controller"
	)
	if overlay_frame != null and overlay_frame.has_method(
		"queue_character_info_overlay_redraw"
	):
		if bool(overlay_frame.queue_character_info_overlay_redraw(
			owner,
			registry,
			module_getter,
			true
		)):
			return
	_queue_redraw(owner)


func _close_overlay(
	module_key: String,
	close_method: String,
	module_getter: Callable
) -> void:
	var module := _get_module(module_getter, module_key)
	if module != null and module.has_method(close_method):
		module.call(close_method)


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _call_modal_gate_bool(module_getter: Callable, method_name: String) -> bool:
	var modal_gate := _get_module(
		module_getter,
		"battle_scene_modal_gate_controller"
	)
	if modal_gate == null or not modal_gate.has_method(method_name):
		return false
	return bool(modal_gate.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()


func _method_accepts_argument_count(
	target: Object,
	method_name: String,
	argument_count: int
) -> bool:
	if target == null:
		return false
	for method_value in target.get_method_list():
		var method_info: Dictionary = (
			method_value if method_value is Dictionary else {}
		)
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() >= argument_count
	return false
