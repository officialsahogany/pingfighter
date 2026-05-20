extends RefCounted


func update_pending_throws(
	pending_throws: Array[Dictionary],
	owner: Object,
	registry: Object,
	release_callback: Callable
) -> Array[Dictionary]:
	if pending_throws.is_empty() or not release_callback.is_valid():
		return pending_throws

	var now_msec: int = Time.get_ticks_msec()
	var next_pending: Array[Dictionary] = []
	for pending_throw in pending_throws:
		if now_msec < int(pending_throw.get("release_msec", now_msec)):
			next_pending.append(pending_throw)
			continue
		release_callback.call(owner, pending_throw, registry)
	return next_pending


func release_pending_throw(
	_controller: Object,
	owner: Object,
	pending_throw: Dictionary,
	registry: Object,
	release_callbacks: Dictionary,
	fallback_callback: Callable = Callable()
) -> void:
	var item_name: String = str(pending_throw.get("item_name", "grenade"))
	var callback_value: Variant = release_callbacks.get(item_name, fallback_callback)
	if not (callback_value is Callable):
		return
	var callback: Callable = callback_value
	if callback.is_valid():
		callback.call(owner, pending_throw, registry)


func build_draw_context(
	pending_throws: Array[Dictionary],
	fallback_duration_msec: int,
	hold_angle_degrees: float,
	release_angle_degrees: float
) -> Dictionary:
	if pending_throws.is_empty():
		return {
			"active": false,
		}
	var pending_throw: Dictionary = pending_throws[0]
	var progress: float = get_windup_progress(pending_throw, fallback_duration_msec)
	return {
		"active": true,
		"progress": progress,
		"angle_degrees": get_pose_angle_degrees(progress, hold_angle_degrees, release_angle_degrees),
		"item_name": str(pending_throw.get("item_name", "grenade")),
	}


func get_windup_progress(pending_throw: Dictionary, fallback_duration_msec: int) -> float:
	var now_msec: int = Time.get_ticks_msec()
	var start_msec: int = int(pending_throw.get("start_msec", now_msec))
	var release_msec: int = int(pending_throw.get("release_msec", start_msec + fallback_duration_msec))
	var duration_msec: int = max(1, release_msec - start_msec)
	return clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)


func get_pose_angle_degrees(
	progress: float,
	hold_angle_degrees: float,
	release_angle_degrees: float
) -> float:
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	if clamped_progress < 0.30:
		return hold_angle_degrees * (clamped_progress / 0.30)
	if clamped_progress < 0.70:
		return hold_angle_degrees
	return lerp(
		hold_angle_degrees,
		release_angle_degrees,
		(clamped_progress - 0.70) / 0.30
	)
