extends RefCounted

const ITEM_REVIVAL := "revival"
const EFFECT_FRAMES := 120.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_REVIVAL)


func is_available(runtime: Object) -> bool:
	return runtime.revival_state.is_available(is_equipped(runtime))


func has_used(runtime: Object) -> bool:
	return bool(runtime.revival_state.used)


func is_effect_active(runtime: Object) -> bool:
	return runtime.revival_state.is_effect_active()


func try_trigger(runtime: Object, loss_type: String = "round", context: Dictionary = {}) -> bool:
	if not is_available(runtime):
		return false
	runtime.revival_state.start(loss_type, EFFECT_FRAMES)
	var owner: Object = runtime._get_dict(context).get("owner", null)
	var registry: Object = runtime._get_dict(context).get("registry", null)
	runtime.ownership_runtime.consume_equipped_item_name(runtime, ITEM_REVIVAL, owner, registry)
	return true


func draw_effect(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	field_size: Vector2
) -> void:
	runtime.support_effect_renderer.draw_revival_effect(
		canvas,
		shake_offset,
		runtime.revival_state,
		field_size,
		EFFECT_FRAMES
	)


func draw_text(runtime: Object, canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	runtime.support_effect_renderer.draw_revival_text(
		canvas,
		center,
		alpha,
		runtime.revival_state.effect_timer_frames,
		EFFECT_FRAMES
	)


func clear_runtime(runtime: Object, clear_used: bool = false) -> void:
	runtime.revival_state.clear_runtime(clear_used)


func update_runtime(runtime: Object, fps_scale: float) -> void:
	runtime.revival_state.update(fps_scale)
