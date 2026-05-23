extends RefCounted

const HermesShoesFxHost := preload("res://scripts/items/mythic_item_hermes_shoes_fx_host.gd")
const HERMES_SHOES_FX_HOST_NAME := "MythicHermesShoesFxHost"

var _hermes_fx_host: Node = null
var _hermes_fx_host_canvas: Object = null
var _hermes_fx_host_add_pending := false


func draw_hermes_shoes_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	active: bool,
	_trail_life_frames: float,
	_move_trail_threshold: float
) -> void:
	var host: Node = _get_or_create_hermes_fx_host(canvas)
	if host == null:
		return
	var player_center: Vector2 = Vector2.ZERO
	var player_size: Vector2 = HermesShoesFxHost.DEFAULT_PADDLE_SIZE
	var move_delta_x: float = 0.0
	if state != null:
		player_center = _as_vector2(state.get("player_center"), Vector2.ZERO)
		player_size = _as_vector2(state.get("player_size"), player_size)
		var delta_value: Variant = state.get("last_move_delta_x")
		if delta_value != null:
			move_delta_x = float(delta_value)
	if host.has_method("sync_state"):
		host.sync_state(player_center, player_size, active, move_delta_x, shake_offset, 1.0)


func _get_or_create_hermes_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_hermes_fx_host() and _hermes_fx_host_canvas == canvas:
		return _hermes_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HERMES_SHOES_FX_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_hermes_fx_host = existing
		_hermes_fx_host_canvas = canvas
		_hermes_fx_host_add_pending = false
		return _hermes_fx_host
	_hermes_fx_host = HermesShoesFxHost.new()
	_hermes_fx_host.name = HERMES_SHOES_FX_HOST_NAME
	_hermes_fx_host.visible = false
	_hermes_fx_host_canvas = canvas
	if not _hermes_fx_host_add_pending:
		_hermes_fx_host_add_pending = true
		parent.call_deferred("add_child", _hermes_fx_host)
	return _hermes_fx_host


func _is_valid_hermes_fx_host() -> bool:
	return (
		_hermes_fx_host != null
		and is_instance_valid(_hermes_fx_host)
		and not _hermes_fx_host.is_queued_for_deletion()
	)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
