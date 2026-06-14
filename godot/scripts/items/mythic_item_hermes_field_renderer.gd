extends RefCounted

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const HermesShoesFxHost := preload("res://scripts/items/mythic_item_hermes_shoes_fx_host.gd")

const HERMES_SHOES_FX_HOST_NAME := "MythicHermesShoesFxHost"
const PLAYFIELD_GAME_WIDTH := 760.0
const PLAYFIELD_GAME_HEIGHT := 750.0

var _hermes_fx_host: Node = null
var _hermes_fx_host_canvas: Object = null
var _hermes_fx_host_add_pending := false
var _view_layout: Object = null
var _cached_viewport_size := Vector2.ZERO
var _cached_game_offset := Vector2.ZERO
var _cached_render_scale := 1.0


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
		var layout: Dictionary = _get_playfield_layout(canvas)
		var game_offset: Vector2 = _as_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
		var render_scale: float = max(0.001, float(layout.get("render_scale", 1.0)))
		var screen_center: Vector2 = game_offset + (player_center + shake_offset) * render_scale
		host.sync_state(screen_center, player_size, active, move_delta_x, Vector2.ZERO, 1.0, render_scale)


func tear_down_hermes_shoes_fx(free_host: bool = false) -> void:
	if not _is_valid_hermes_fx_host():
		return
	if _hermes_fx_host.has_method("tear_down"):
		_hermes_fx_host.tear_down(free_host)
	else:
		_hermes_fx_host.visible = false
		if free_host:
			_hermes_fx_host.queue_free()
	if free_host:
		_hermes_fx_host = null
		_hermes_fx_host_canvas = null
		_hermes_fx_host_add_pending = false


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


func _get_playfield_layout(canvas: CanvasItem) -> Dictionary:
	if canvas == null:
		return {"game_offset": Vector2.ZERO, "render_scale": 1.0}
	var viewport_size: Vector2 = canvas.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {"game_offset": Vector2.ZERO, "render_scale": 1.0}
	if not viewport_size.is_equal_approx(_cached_viewport_size) or _view_layout == null:
		if _view_layout == null:
			_view_layout = BattleViewLayout.new()
		var layout: Dictionary = _view_layout.build_game_layout(
			viewport_size,
			PLAYFIELD_GAME_WIDTH,
			PLAYFIELD_GAME_HEIGHT
		)
		_cached_viewport_size = viewport_size
		_cached_game_offset = _as_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
		_cached_render_scale = max(0.001, float(layout.get("render_scale", 1.0)))
	return {
		"game_offset": _cached_game_offset,
		"render_scale": _cached_render_scale,
	}
