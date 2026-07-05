extends Control

const FALLBACK_VIEW_SIZE := Vector2(760.0, 750.0)

var _overlay: Object = null
var _owner: Object = null
var _registry: Object = null
var _view_size := FALLBACK_VIEW_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	set_physics_process(false)
	visible = false


func configure(overlay: Object, owner: Object, registry: Object, view_size: Vector2) -> void:
	_overlay = overlay
	_owner = owner
	_registry = registry
	_view_size = _resolve_view_size(view_size)
	position = Vector2.ZERO
	size = _view_size


func sync_overlay(overlay: Object, owner: Object, registry: Object, view_size: Vector2, force_redraw: bool = false) -> void:
	var next_view_size := _resolve_view_size(view_size)
	var changed := _overlay != overlay or _owner != owner or _registry != registry or size != next_view_size
	configure(overlay, owner, registry, next_view_size)
	var should_show := _is_overlay_active()
	if visible != should_show:
		visible = should_show
		changed = true
	if should_show and (changed or force_redraw):
		queue_redraw()


func queue_overlay_redraw() -> void:
	if _is_overlay_active():
		visible = true
		queue_redraw()


func hide_overlay() -> void:
	visible = false


func _draw() -> void:
	if not _is_overlay_active():
		return
	if _overlay != null and _overlay.has_method("draw"):
		var perf_logger := _get_perf_logger()
		var sample_start := _perf_begin(perf_logger)
		_overlay.draw(self, _owner, _registry, _view_size)
		_perf_end(perf_logger, "draw.overlay.character_info_host", sample_start)


func _is_overlay_active() -> bool:
	return _overlay != null and _overlay.has_method("is_active") and bool(_overlay.is_active())


func _resolve_view_size(view_size: Vector2) -> Vector2:
	if view_size.x > 0.0 and view_size.y > 0.0:
		return view_size
	if _owner != null and _owner.has_method("get_viewport_rect"):
		var rect_value: Variant = _owner.get_viewport_rect()
		if rect_value is Rect2:
			var owner_rect: Rect2 = rect_value
			if owner_rect.size.x > 0.0 and owner_rect.size.y > 0.0:
				return owner_rect.size
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null:
			var viewport_size := viewport.get_visible_rect().size
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				return viewport_size
	return FALLBACK_VIEW_SIZE


func _get_perf_logger() -> Object:
	if _registry == null:
		return null
	var value: Variant = null
	if _registry.has_method("get_cached_instance"):
		value = _registry.get_cached_instance("battle_perf_logger")
	if (typeof(value) != TYPE_OBJECT or value == null) and _registry.has_method("get_instance"):
		value = _registry.get_instance("battle_perf_logger")
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
