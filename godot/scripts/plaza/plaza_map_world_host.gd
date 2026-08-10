extends Control

# R1 production retained-world owner. PlazaScene attaches this host atomically
# with removal of its former root opaque fill.

const PlazaBackgroundRenderer := preload("res://scripts/plaza/plaza_background_renderer.gd")
const PlazaBuildingRenderer := preload("res://scripts/plaza/plaza_building_renderer.gd")

const HOST_Z_INDEX := -1
const DEFAULT_FILL_COLOR := Color(0.012, 0.014, 0.022, 1.0)
const RENDER_SIZE_STATE_KEY := "render_size"
const LEGACY_VIEWPORT_SIZE_STATE_KEY := "viewport_size"

var _active := false
var _draw_state: Dictionary = {}
var _building_visuals: Array[Node2D] = []
var _draw_opaque_fill := false
var _successful_sync_count := 0
var _previous_synced_ticks_msec := -1
var _last_synced_ticks_msec := -1
var _ticks_advanced_on_last_sync := false
var _consecutive_non_advancing_tick_syncs := 0
var _last_sync_rejection_reason := "not_synced"


func _init() -> void:
	z_as_relative = true
	z_index = HOST_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false


func _ready() -> void:
	# z=-1 is intentionally relative to the plaza root (currently z=1200).
	# Making it absolute would sink this host behind the full UI stack.
	z_as_relative = true
	z_index = HOST_Z_INDEX
	set_process(false)
	set_active(false)


static func prewarm_owned_assets_step(
	manifest_paths: Array[String],
	use_threaded_texture_loads: bool = true,
	prewarm_key: String = "hwangyeok_2d_v1"
) -> bool:
	return PlazaBuildingRenderer.prewarm_assets_step(
		manifest_paths,
		use_threaded_texture_loads,
		prewarm_key
	)


func prewarm_assets_step(
	manifest_paths: Array[String],
	use_threaded_texture_loads: bool = true,
	prewarm_key: String = "hwangyeok_2d_v1"
) -> bool:
	return prewarm_owned_assets_step(
		manifest_paths,
		use_threaded_texture_loads,
		prewarm_key
	)


func sync_state(state: Dictionary, active: bool = true) -> bool:
	# Fail closed before every validation branch. Retained children otherwise
	# survive the quiet early returns used by the immediate-mode plaza.
	# This host never self-processes: PlazaScene calls sync_state() once per
	# rendered owner frame with that frame's current ticks_msec value.
	set_active(false)
	if not active:
		_last_sync_rejection_reason = "inactive"
		return false
	# Reject even when both keys are present. This seals stale callers instead
	# of silently preferring render_size and hiding a partial migration.
	if state.has(LEGACY_VIEWPORT_SIZE_STATE_KEY):
		_last_sync_rejection_reason = "legacy_viewport_size_key"
		return false
	if not state.has(RENDER_SIZE_STATE_KEY):
		_last_sync_rejection_reason = "missing_render_size"
		return false
	if not state.has("ticks_msec"):
		_last_sync_rejection_reason = "missing_ticks_msec"
		return false
	if typeof(state.get("ticks_msec")) != TYPE_INT:
		_last_sync_rejection_reason = "invalid_ticks_msec_type"
		return false
	var render_size := _coerce_vector2(state.get(RENDER_SIZE_STATE_KEY, Vector2.ZERO))
	var game_size := _coerce_vector2(state.get("game_size", Vector2.ZERO))
	var render_scale := float(state.get("render_scale", 0.0))
	var ticks_msec := int(state.get("ticks_msec", -1))
	if render_size.x <= 1.0 or render_size.y <= 1.0:
		_last_sync_rejection_reason = "degenerate_render_size"
		return false
	if game_size.x <= 1.0 or game_size.y <= 1.0 or render_scale <= 0.0:
		_last_sync_rejection_reason = "invalid_game_projection"
		return false
	if ticks_msec < 0:
		_last_sync_rejection_reason = "invalid_ticks_msec"
		return false
	var specs_value: Variant = state.get("building_specs", [])
	if not (specs_value is Array):
		_last_sync_rejection_reason = "invalid_building_specs"
		return false

	size = render_size
	_draw_state = state.duplicate(false)
	_draw_state[RENDER_SIZE_STATE_KEY] = render_size
	_draw_state["game_size"] = game_size
	_draw_state["render_scale"] = render_scale
	_draw_state["ticks_msec"] = ticks_msec
	_draw_opaque_fill = bool(state.get("draw_opaque_fill", false))
	_record_sync_ticks(ticks_msec)
	_sync_buildings(
		specs_value as Array,
		float(state.get("camera_x", 0.0)),
		render_size.x,
		float(state.get("building_baseline_y", 0.0)),
		render_scale,
		ticks_msec
	)
	_last_sync_rejection_reason = ""
	_active = true
	visible = true
	set_process(false)
	queue_redraw()
	return true


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(false)
	if active:
		return
	for visual in _building_visuals:
		if visual != null and visual.has_method("set_active"):
			visual.call("set_active", false)
	queue_redraw()


func clear_transient_canvas_items() -> void:
	for visual in _building_visuals:
		if visual != null and visual.has_method("clear_transient_canvas_items"):
			visual.call("clear_transient_canvas_items")
	_draw_state.clear()
	_draw_opaque_fill = false
	_reset_sync_timing()
	_last_sync_rejection_reason = "cleared"
	set_active(false)


func tear_down(free_self: bool = false) -> void:
	clear_transient_canvas_items()
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	var visible_building_count := 0
	var all_building_z_zero := true
	for visual in _building_visuals:
		if visual != null and visual.visible:
			visible_building_count += 1
		if visual != null and visual.z_index != 0:
			all_building_z_zero = false
	return {
		"active": _active,
		"visible": visible,
		"process_enabled": is_processing(),
		"z_index": z_index,
		"z_as_relative": z_as_relative,
		"building_node_count": _building_visuals.size(),
		"visible_building_count": visible_building_count,
		"all_building_z_zero": all_building_z_zero,
		"last_sync_rejection_reason": _last_sync_rejection_reason,
		"successful_sync_count": _successful_sync_count,
		"previous_synced_ticks_msec": _previous_synced_ticks_msec,
		"last_synced_ticks_msec": _last_synced_ticks_msec,
		"ticks_advanced_on_last_sync": _ticks_advanced_on_last_sync,
		"frozen_ticks_detected": (
			_previous_synced_ticks_msec >= 0
			and _last_synced_ticks_msec == _previous_synced_ticks_msec
		),
		"non_advancing_ticks_detected": (
			_previous_synced_ticks_msec >= 0
			and _last_synced_ticks_msec <= _previous_synced_ticks_msec
		),
		"consecutive_non_advancing_tick_syncs": _consecutive_non_advancing_tick_syncs,
	}
func get_building_layer_statuses() -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	for visual in _building_visuals:
		if visual == null or not visual.has_method("get_layer_status"):
			statuses.append({})
			continue
		var status_value: Variant = visual.call("get_layer_status")
		statuses.append((status_value as Dictionary).duplicate(true) if status_value is Dictionary else {})
	return statuses


func _draw() -> void:
	if not _active or size.x <= 1.0 or size.y <= 1.0:
		return
	if _draw_opaque_fill:
		var fill_color := _coerce_color(_draw_state.get("fill_color", DEFAULT_FILL_COLOR), DEFAULT_FILL_COLOR)
		fill_color.a = 1.0
		draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)
	if not bool(_draw_state.get("render_background", true)):
		return
	var floor_textures: Dictionary = _draw_state.get("floor_textures", {})
	PlazaBackgroundRenderer.draw(
		self,
		floor_textures,
		float(_draw_state.get("camera_x", 0.0)),
		_coerce_rect2(_draw_state.get("exit_zone", Rect2())),
		_coerce_vector2(_draw_state.get("game_size", Vector2.ZERO)),
		_coerce_vector2(_draw_state.get(RENDER_SIZE_STATE_KEY, Vector2.ZERO)),
		float(_draw_state.get("sidewalk_top", 0.0)),
		float(_draw_state.get("render_scale", 0.0)),
		int(_draw_state.get("ticks_msec", -1))
	)


func _sync_buildings(
	specs: Array,
	camera_x: float,
	render_width: float,
	building_baseline_y: float,
	render_scale: float,
	ticks_msec: int
) -> void:
	while _building_visuals.size() < specs.size():
		var visual := PlazaBuildingRenderer.create_retained_visual()
		visual.name = "BuildingVisual%d" % _building_visuals.size()
		visual.z_as_relative = true
		visual.z_index = 0
		add_child(visual)
		_building_visuals.append(visual)
	for idx in range(_building_visuals.size()):
		var visual := _building_visuals[idx]
		if idx >= specs.size() or not (specs[idx] is Dictionary):
			visual.call("set_active", false)
			continue
		visual.call(
			"sync_state",
			specs[idx] as Dictionary,
			camera_x,
			render_width,
			building_baseline_y,
			render_scale,
			ticks_msec
		)


func _record_sync_ticks(ticks_msec: int) -> void:
	_successful_sync_count += 1
	_previous_synced_ticks_msec = _last_synced_ticks_msec
	_last_synced_ticks_msec = ticks_msec
	_ticks_advanced_on_last_sync = (
		_previous_synced_ticks_msec >= 0
		and _last_synced_ticks_msec > _previous_synced_ticks_msec
	)
	if _previous_synced_ticks_msec < 0 or _ticks_advanced_on_last_sync:
		_consecutive_non_advancing_tick_syncs = 0
	else:
		_consecutive_non_advancing_tick_syncs += 1


func _reset_sync_timing() -> void:
	_successful_sync_count = 0
	_previous_synced_ticks_msec = -1
	_last_synced_ticks_msec = -1
	_ticks_advanced_on_last_sync = false
	_consecutive_non_advancing_tick_syncs = 0


func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	return Vector2.ZERO


func _coerce_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value as Rect2
	return Rect2()


func _coerce_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String:
		return Color.from_string(str(value), fallback)
	return fallback
