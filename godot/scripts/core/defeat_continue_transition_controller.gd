extends RefCounted

const DefeatGemShatterFxHost := preload("res://scripts/effects/defeat_gem_shatter_fx_host.gd")
const DefeatContinueColorRestoreFxHost := preload("res://scripts/effects/defeat_continue_color_restore_fx_host.gd")
const DefeatContinueRevivalBeatState := preload("res://scripts/core/defeat_continue_revival_beat_state.gd")

const REVIVAL_BEAT_KEY := "defeat_continue_revival_beat_state"

var _owner: Object = null
var _registry: Object = null
var _gem_shatter_fx_host: Node = null
var _color_restore_fx_host: Node = null


static func prewarm_assets() -> void:
	DefeatGemShatterFxHost.prewarm_assets()
	DefeatContinueColorRestoreFxHost.prewarm_assets()
	DefeatContinueRevivalBeatState.prewarm_assets()


func bind(owner: Object, registry: Object) -> void:
	_deactivate_all()
	_reset_bound_revival()
	_owner = owner
	_registry = registry
	_gem_shatter_fx_host = null
	_color_restore_fx_host = null
	_ensure_gem_shatter_fx_host()
	_ensure_color_restore_fx_host()
	_deactivate_all()


func reset() -> void:
	_deactivate_all()
	_reset_bound_revival()
	_owner = null
	_registry = null
	_gem_shatter_fx_host = null
	_color_restore_fx_host = null


func deactivate_shatter() -> void:
	_set_host_active(_gem_shatter_fx_host, false)


func sync_shatter(
	view_size: Vector2,
	enabled: bool,
	gem_center: Vector2,
	progress: float,
	duration_sec: float
) -> void:
	var host := _gem_shatter_fx_host
	if not _is_valid_host(host):
		return
	if not enabled or view_size.x <= 1.0 or view_size.y <= 1.0:
		_set_host_active(host, false)
		return
	if host.has_method("sync_state"):
		var safe_progress := clampf(progress, 0.0, 1.0)
		host.sync_state({
			"view_size": view_size,
			"gem_center": gem_center,
			"progress": safe_progress,
			"elapsed": safe_progress * maxf(duration_sec, 0.0),
			"quality_scale": 1.0,
		}, true)


func sync_color_restore(view_size: Vector2) -> void:
	var host := _color_restore_fx_host
	if not _is_valid_host(host):
		return
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		_set_host_active(host, false)
		return
	var beat_state := _get_revival_beat_state()
	if beat_state == null or not beat_state.has_method("get_color_restore_status"):
		_set_host_active(host, false)
		return
	var status: Variant = beat_state.get_color_restore_status(view_size)
	if not (status is Dictionary):
		_set_host_active(host, false)
		return
	if host.has_method("sync_state"):
		host.sync_state(status, bool((status as Dictionary).get("active", false)))


func start_revival(source_screen_pos: Vector2, view_size: Vector2) -> void:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("start"):
		beat_state.start(_owner, source_screen_pos, view_size)


func update_revival(delta: float, view_size: Vector2) -> void:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("update"):
		beat_state.update(maxf(0.0, delta), _owner, view_size)


func draw_revival(canvas: CanvasItem, view_size: Vector2) -> void:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("draw_overlay"):
		beat_state.draw_overlay(canvas, _owner, view_size)


func is_revival_active() -> bool:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("blocks_battle_physics"):
		return bool(beat_state.blocks_battle_physics())
	return false


func get_revival_status() -> Dictionary:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("get_status_for_tests"):
		var status: Variant = beat_state.get_status_for_tests()
		if status is Dictionary:
			return status
	return {}


func _ensure_gem_shatter_fx_host() -> Node:
	if _is_valid_host(_gem_shatter_fx_host):
		return _gem_shatter_fx_host
	if not (_owner is Node):
		return null
	var parent := _owner as Node
	var existing := parent.get_node_or_null(DefeatGemShatterFxHost.HOST_NAME)
	if _is_valid_host(existing):
		_gem_shatter_fx_host = existing
		return _gem_shatter_fx_host
	var host := DefeatGemShatterFxHost.new()
	host.name = DefeatGemShatterFxHost.HOST_NAME
	host.visible = false
	parent.add_child(host)
	_gem_shatter_fx_host = host
	return _gem_shatter_fx_host


func _ensure_color_restore_fx_host() -> Node:
	if _is_valid_host(_color_restore_fx_host):
		return _color_restore_fx_host
	if not (_owner is Node):
		return null
	var parent := _owner as Node
	var existing := parent.get_node_or_null(DefeatContinueColorRestoreFxHost.HOST_NAME)
	if _is_valid_host(existing):
		_color_restore_fx_host = existing
		return _color_restore_fx_host
	var host := DefeatContinueColorRestoreFxHost.new()
	host.name = DefeatContinueColorRestoreFxHost.HOST_NAME
	host.visible = false
	parent.add_child(host)
	_color_restore_fx_host = host
	return _color_restore_fx_host


func _deactivate_all() -> void:
	_set_host_active(_gem_shatter_fx_host, false)
	_set_host_active(_color_restore_fx_host, false)


func _reset_bound_revival() -> void:
	var beat_state := _get_revival_beat_state()
	if beat_state != null and beat_state.has_method("reset"):
		beat_state.reset(_owner)


func _get_revival_beat_state() -> Object:
	if _registry == null or not _registry.has_method("get_instance"):
		return null
	return _registry.get_instance(REVIVAL_BEAT_KEY)


func _set_host_active(host: Node, enabled: bool) -> void:
	if _is_valid_host(host) and host.has_method("set_active"):
		host.set_active(enabled)


func _is_valid_host(host: Node) -> bool:
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()
