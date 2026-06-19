extends Control

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const FALLBACK_VIEW_SIZE := Vector2(760.0, 750.0)

var _overlay: Object = CharacterInfoOverlay.new()
var _owner: Object = null
var _registry: Object = null
var _module_getter: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	visible = false


func configure(owner: Object, registry: Object, module_getter: Callable) -> void:
	_owner = owner
	_registry = registry
	_module_getter = module_getter


func is_active() -> bool:
	return _overlay != null and _overlay.has_method("is_active") and bool(_overlay.is_active())


func open(owner: Object = null, registry: Object = null, module_getter: Callable = Callable()) -> void:
	configure(owner, registry, module_getter)
	var view_size := _resolve_view_size()
	if size.x <= 0.0 or size.y <= 0.0:
		size = view_size
	if _overlay != null and _overlay.has_method("prewarm_assets"):
		_overlay.prewarm_assets(_owner, _registry, _module_getter, true, view_size)
	if _overlay != null and _overlay.has_method("open"):
		_overlay.open(_owner, _registry)
	visible = is_active()
	queue_redraw()


func close(from_input: bool = false) -> void:
	if _overlay != null and _overlay.has_method("close"):
		_overlay.close(from_input)
	visible = false
	queue_redraw()


func handle_overlay_input(event: InputEvent) -> bool:
	if not is_active():
		return false
	if _overlay != null and _overlay.has_method("handle_input"):
		var handled := bool(_overlay.handle_input(event, _owner, _registry, size))
		if handled:
			_queue_input_redraw()
	visible = is_active()
	return true


func update_overlay(delta: float) -> bool:
	if not is_active():
		visible = false
		return false
	var changed := false
	if _overlay != null and _overlay.has_method("update"):
		changed = bool(_overlay.update(maxf(0.0, delta)))
	visible = true
	if changed:
		queue_redraw()
	return changed


func get_status() -> Dictionary:
	return {
		"active": is_active(),
		"visible": visible,
	}


func _draw() -> void:
	if not is_active():
		return
	if _overlay != null and _overlay.has_method("draw"):
		_overlay.draw(self, _owner, _registry, _resolve_view_size())


func _queue_input_redraw() -> void:
	if _overlay != null and _overlay.has_method("consume_input_redraw_request"):
		if bool(_overlay.consume_input_redraw_request()):
			queue_redraw()
		return
	queue_redraw()


func _resolve_view_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	var parent_node := get_parent()
	if parent_node is Control:
		var parent_control := parent_node as Control
		if parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
			return parent_control.size
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null:
			var viewport_size := viewport.get_visible_rect().size
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				return viewport_size
	return FALLBACK_VIEW_SIZE
