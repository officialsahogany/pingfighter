extends RefCounted

const DriveCutinFxHost := preload("res://scripts/hud/drive_cutin_fx_host.gd")
const HOST_NAME := "SmasherDriveCutinFxHost"

var _fx_host: Node = null
var _fx_host_add_pending := false
var _fx_sync_context: Dictionary = {}


func draw_if_active(
	canvas: CanvasItem,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> void:
	if registry == null or not registry.has_method("get_cached_instance"):
		return
	var power_state: Variant = registry.get_cached_instance("smasher_power_smash_state")
	var has_power_state: bool = typeof(power_state) == TYPE_OBJECT and power_state != null
	var shield_state: Variant = registry.get_cached_instance("smasher_shield_kiting_state")
	var has_shield_state: bool = typeof(shield_state) == TYPE_OBJECT and shield_state != null
	var magnum_state: Variant = registry.get_cached_instance("smasher_magnum_grip_state")
	var has_magnum_state: bool = typeof(magnum_state) == TYPE_OBJECT and magnum_state != null
	var plasma_state: Variant = registry.get_cached_instance("smasher_plasma_state")
	var has_plasma_state: bool = typeof(plasma_state) == TYPE_OBJECT and plasma_state != null
	var overdrive_state: Variant = registry.get_cached_instance("smasher_overdrive_state")
	var has_overdrive_state: bool = typeof(overdrive_state) == TYPE_OBJECT and overdrive_state != null
	if not has_power_state and not has_shield_state and not has_magnum_state and not has_plasma_state and not has_overdrive_state:
		return

	var drive_active: bool = (
		has_power_state
		and power_state.has_method("is_drive_cutin_active")
		and bool(power_state.is_drive_cutin_active())
	)
	var shield_cutin_state: Object = null
	if has_shield_state:
		var shield_cutin_value: Variant = shield_state.get("cutin_state")
		if typeof(shield_cutin_value) == TYPE_OBJECT and shield_cutin_value != null:
			shield_cutin_state = shield_cutin_value
	var shield_active: bool = (
		shield_cutin_state != null
		and shield_cutin_state.has_method("is_active")
		and bool(shield_cutin_state.is_active())
	)
	var magnum_cutin_state: Object = null
	if has_magnum_state:
		var magnum_cutin_value: Variant = magnum_state.get("cutin_state")
		if typeof(magnum_cutin_value) == TYPE_OBJECT and magnum_cutin_value != null:
			magnum_cutin_state = magnum_cutin_value
	var magnum_active: bool = (
		magnum_cutin_state != null
		and magnum_cutin_state.has_method("is_active")
		and bool(magnum_cutin_state.is_active())
	)
	var plasma_cutin_state: Object = null
	if has_plasma_state:
		var plasma_cutin_value: Variant = plasma_state.get("cutin_state")
		if typeof(plasma_cutin_value) == TYPE_OBJECT and plasma_cutin_value != null:
			plasma_cutin_state = plasma_cutin_value
	var plasma_active: bool = (
		plasma_cutin_state != null
		and plasma_cutin_state.has_method("is_active")
		and bool(plasma_cutin_state.is_active())
	)
	var overdrive_cutin_state: Object = null
	if has_overdrive_state:
		var overdrive_cutin_value: Variant = overdrive_state.get("cutin_state")
		if typeof(overdrive_cutin_value) == TYPE_OBJECT and overdrive_cutin_value != null:
			overdrive_cutin_state = overdrive_cutin_value
	var overdrive_active: bool = (
		overdrive_cutin_state != null
		and overdrive_cutin_state.has_method("is_active")
		and bool(overdrive_cutin_state.is_active())
	)
	var blocking := _has_blocking_overlay(module_getter)
	var draw_overdrive_now: bool = overdrive_active and not blocking
	var draw_plasma_now: bool = not draw_overdrive_now and plasma_active and not blocking
	var draw_drive_now: bool = not draw_overdrive_now and not draw_plasma_now and drive_active and not blocking
	var draw_shield_now: bool = not draw_overdrive_now and not draw_plasma_now and not draw_drive_now and shield_active and not blocking
	var draw_magnum_now: bool = not draw_overdrive_now and not draw_plasma_now and not draw_drive_now and not draw_shield_now and magnum_active and not blocking
	var draw_now: bool = draw_overdrive_now or draw_plasma_now or draw_drive_now or draw_shield_now or draw_magnum_now

	var cutin_host: Variant = registry.get_cached_instance("skill_cutin_overlay_host")
	var has_cutin_host: bool = typeof(cutin_host) == TYPE_OBJECT and cutin_host != null
	_draw_immediate_layers(
		canvas,
		cutin_host,
		has_cutin_host,
		power_state,
		shield_state,
		shield_cutin_state,
		magnum_cutin_state,
		plasma_cutin_state,
		overdrive_cutin_state,
		draw_overdrive_now,
		draw_plasma_now,
		draw_drive_now,
		draw_shield_now,
		draw_magnum_now,
		view_size,
		perf_logger
	)
	_sync_fx_host(
		canvas,
		cutin_host,
		has_cutin_host,
		power_state,
		shield_cutin_state,
		magnum_cutin_state,
		plasma_cutin_state,
		overdrive_cutin_state,
		draw_overdrive_now,
		draw_plasma_now,
		draw_drive_now,
		draw_shield_now,
		draw_magnum_now,
		draw_now,
		view_size,
		perf_logger
	)


func _draw_immediate_layers(
	canvas: CanvasItem,
	cutin_host: Variant,
	has_cutin_host: bool,
	power_state: Variant,
	shield_state: Variant,
	shield_cutin_state: Object,
	magnum_cutin_state: Object,
	plasma_cutin_state: Object,
	overdrive_cutin_state: Object,
	draw_overdrive_now: bool,
	draw_plasma_now: bool,
	draw_drive_now: bool,
	draw_shield_now: bool,
	draw_magnum_now: bool,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if draw_overdrive_now and has_cutin_host and cutin_host.has_method("draw_smasher_overdrive_cutin"):
		var overdrive_start: int = _perf_begin(perf_logger)
		cutin_host.draw_smasher_overdrive_cutin(canvas, overdrive_cutin_state, view_size)
		_perf_end(perf_logger, "draw.frame.smasher_overdrive_cutin", overdrive_start)
	elif draw_plasma_now and has_cutin_host and cutin_host.has_method("draw_hanryeongtan_cutin"):
		var plasma_start: int = _perf_begin(perf_logger)
		cutin_host.draw_hanryeongtan_cutin(canvas, plasma_cutin_state, view_size)
		_perf_end(perf_logger, "draw.frame.smasher_hanryeongtan_cutin", plasma_start)
	elif draw_drive_now and has_cutin_host and cutin_host.has_method("draw_drive_cutin"):
		var drive_start: int = _perf_begin(perf_logger)
		cutin_host.draw_drive_cutin(canvas, power_state.drive_cutin_state, view_size)
		_perf_end(perf_logger, "draw.frame.drive_cutin", drive_start)
	elif draw_shield_now and has_cutin_host and cutin_host.has_method("draw_shield_kiting_cutin"):
		var shield_start: int = _perf_begin(perf_logger)
		cutin_host.draw_shield_kiting_cutin(canvas, shield_cutin_state, shield_state, view_size)
		_perf_end(perf_logger, "draw.frame.shield_kiting_cutin", shield_start)
	elif draw_magnum_now and has_cutin_host and cutin_host.has_method("draw_magnum_grip_cutin"):
		var magnum_start: int = _perf_begin(perf_logger)
		cutin_host.draw_magnum_grip_cutin(canvas, magnum_cutin_state, view_size)
		_perf_end(perf_logger, "draw.frame.magnum_grip_cutin", magnum_start)


func _sync_fx_host(
	canvas: CanvasItem,
	cutin_host: Variant,
	has_cutin_host: bool,
	power_state: Variant,
	shield_cutin_state: Object,
	magnum_cutin_state: Object,
	plasma_cutin_state: Object,
	overdrive_cutin_state: Object,
	draw_overdrive_now: bool,
	draw_plasma_now: bool,
	draw_drive_now: bool,
	draw_shield_now: bool,
	draw_magnum_now: bool,
	draw_now: bool,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	# 한령탄 원화 자체가 혼백/먹안개를 포함하므로 전기성 Drive 파티클은 끈다.
	# 기존 호스트가 보이던 중이라면 active=false 동기화로 즉시 숨긴다.
	var particle_draw_now: bool = draw_now and not draw_plasma_now
	var fx_host: Node = _get_or_create_fx_host(canvas, particle_draw_now)
	if fx_host == null or not fx_host.has_method("sync_state"):
		return
	var partial_state: Object = null
	if draw_overdrive_now:
		partial_state = overdrive_cutin_state
	elif draw_plasma_now:
		partial_state = plasma_cutin_state
	elif draw_drive_now:
		partial_state = power_state.drive_cutin_state
	elif draw_shield_now:
		partial_state = shield_cutin_state
	elif draw_magnum_now:
		partial_state = magnum_cutin_state
	var progress: float = (
		partial_state.get_progress()
		if partial_state != null and partial_state.has_method("get_progress")
		else 0.0
	)
	var slide_px := _compute_slide_px(
		cutin_host,
		has_cutin_host,
		draw_overdrive_now,
		draw_plasma_now,
		draw_shield_now,
		draw_magnum_now,
		progress,
		view_size.x
	)
	var enraged: bool = (
		draw_drive_now
		and power_state.has_method("is_drive_cutin_enraged")
		and bool(power_state.is_drive_cutin_enraged())
	)
	_fx_sync_context["view_size"] = view_size
	_fx_sync_context["progress"] = progress
	_fx_sync_context["slide_px"] = slide_px
	_fx_sync_context["enraged"] = enraged
	_fx_sync_context["quality_scale"] = 1.0
	var fx_start: int = _perf_begin(perf_logger)
	fx_host.sync_state(_fx_sync_context, particle_draw_now)
	_perf_end(perf_logger, "draw.frame.drive_cutin_fx_sync", fx_start)


func _compute_slide_px(
	cutin_host: Variant,
	has_cutin_host: bool,
	draw_overdrive_now: bool,
	draw_plasma_now: bool,
	draw_shield_now: bool,
	draw_magnum_now: bool,
	progress: float,
	view_width: float
) -> float:
	if draw_overdrive_now and has_cutin_host and cutin_host.has_method("compute_smasher_overdrive_slide_px"):
		return float(cutin_host.compute_smasher_overdrive_slide_px(progress, view_width))
	if draw_plasma_now and has_cutin_host and cutin_host.has_method("compute_hanryeongtan_slide_px"):
		return float(cutin_host.compute_hanryeongtan_slide_px(progress, view_width))
	if draw_shield_now and has_cutin_host and cutin_host.has_method("compute_shield_kiting_slide_px"):
		return float(cutin_host.compute_shield_kiting_slide_px(progress, view_width))
	if draw_magnum_now and has_cutin_host and cutin_host.has_method("compute_magnum_grip_slide_px"):
		return float(cutin_host.compute_magnum_grip_slide_px(progress, view_width))
	if has_cutin_host and cutin_host.has_method("compute_drive_slide_px"):
		return float(cutin_host.compute_drive_slide_px(progress, view_width))
	return 0.0


func _has_blocking_overlay(module_getter: Callable) -> bool:
	var overlay_frame: Object = _get_module(module_getter, "battle_scene_overlay_frame_controller")
	return (
		overlay_frame != null
		and overlay_frame.has_method("has_blocking_activity")
		and bool(overlay_frame.has_blocking_activity(module_getter))
	)


func _get_or_create_fx_host(canvas: CanvasItem, allow_create: bool) -> Node:
	if _is_valid_fx_host(_fx_host):
		return _fx_host
	if not allow_create or not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HOST_NAME)
	if _is_valid_fx_host(existing):
		_fx_host = existing
		_fx_host_add_pending = false
		return _fx_host
	_fx_host = DriveCutinFxHost.new()
	_fx_host.name = HOST_NAME
	_fx_host.visible = false
	if not _fx_host_add_pending:
		_fx_host_add_pending = true
		parent.call_deferred("add_child", _fx_host)
	return _fx_host


func _is_valid_fx_host(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
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
