extends Control

# R3-B candidate-only exterior runtime. It binds the R3-A layout and approved
# environment plan once, compiles immutable navigation, then owns the real 2D
# player/guardian cadence, two-axis camera, full-map minimap, and portal hit.
# PlazaScene remains on the R1 street until the later atomic R3-D promotion.

const PlazaMapGuardianLocomotion := preload("res://scripts/plaza/plaza_map_guardian_locomotion.gd")
const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")
const PlazaR3ExteriorRetainedHost := preload("res://scripts/plaza/plaza_r3_exterior_retained_host.gd")
const PlazaR3MinimapCanvas := preload("res://scripts/plaza/plaza_r3_minimap_canvas.gd")
const PlazaR3MinimapProjection := preload("res://scripts/plaza/plaza_r3_minimap_projection.gd")
const PlazaR3NavigationBinding := preload("res://scripts/plaza/plaza_r3_navigation_binding.gd")

const SCHEMA_VERSION := "plaza_r3_exterior_runtime_candidate_v1"
const ENVIRONMENT_COMPOSITION_APPROVAL_ID := "r3a_environment_composition_user_approved_2026_08_15"
const CAMERA_BLEND_PER_FRAME_60 := 0.12
const PERF_WARMUP_TICKS := 120
const PERF_SAMPLE_CAPACITY := 2048
const OWNER_CADENCE_P95_LIMIT_USEC := 2000.0

var _active := false
var _bound := false
var _rejection_reason := "not_bound"
var _layout: Dictionary = {}
var _layout_fingerprint := ""
var _environment_plan: Dictionary = {}
var _compiled_navigation: Object = null
var _compiled_minimap: Dictionary = {}
var _projection: Dictionary = {}
var _safe_rect := Rect2()
var _minimap_rect := Rect2()
var _render_size := Vector2.ZERO
var _camera_zoom := 1.0
var _camera_center_world := Vector2.ZERO
var _player_world_position := Vector2.ZERO
var _guardian_world_position := Vector2.ZERO
var _guardian_enabled := false
var _guardian_locomotion_style := PlazaMapGuardianLocomotion.STYLE_GROUND
var _player_facing := 1
var _player_moving := false
var _last_ticks_msec := 0
var _successful_tick_count := 0
var _interaction_count := 0

var _perf_samples := PackedInt64Array()
var _perf_sample_count := 0
var _perf_sample_cursor := 0
var _total_tick_count := 0

var _retained_host: Control = null
var _minimap_canvas: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	set_process(false)
	_perf_samples.resize(PERF_SAMPLE_CAPACITY)
	_retained_host = PlazaR3ExteriorRetainedHost.new()
	_retained_host.name = "ExteriorRetainedHost"
	add_child(_retained_host)
	_minimap_canvas = PlazaR3MinimapCanvas.new()
	_minimap_canvas.name = "MinimapCanvas"
	add_child(_minimap_canvas)


func bind_candidate(config: Dictionary) -> bool:
	clear_transient_canvas_items()
	var compiled_config := _compile_bind_config(config)
	if not bool(compiled_config.get("valid", false)):
		return _reject(str(compiled_config.get("reason", "bind_config_invalid")))
	var layout := compiled_config.get("layout", {}) as Dictionary
	var layout_fingerprint := str(layout.get("fingerprint", ""))
	var navigation_state := PlazaR3NavigationBinding.bind_layout(layout, layout_fingerprint)
	if not bool(navigation_state.get("valid", false)):
		return _reject("r3_navigation_bind_failed:%s" % str(navigation_state.get("rejection_reason", "")))
	var compiled: Object = PlazaMapNavigationCompiled.compile(navigation_state)
	if compiled == null or not bool(compiled.call("is_valid")):
		return _reject("compiled_navigation_invalid")
	var compiled_minimap := PlazaR3MinimapProjection.compile_layout(layout, layout_fingerprint)
	if not bool(compiled_minimap.get("valid", false)):
		return _reject("compiled_minimap_invalid:%s" % str(compiled_minimap.get("rejection_reason", "")))
	var player_world := compiled_config.get("initial_player_world_position", Vector2.ZERO) as Vector2
	if not bool(compiled.call("can_occupy", player_world, true)):
		return _reject("initial_player_not_walkable")
	var guardian_enabled := bool(compiled_config.get("guardian_enabled", false))
	var guardian_world := compiled_config.get("initial_guardian_world_position", Vector2.ZERO) as Vector2
	var guardian_style := str(compiled_config.get("guardian_locomotion_style", PlazaMapGuardianLocomotion.STYLE_GROUND))
	if guardian_enabled and PlazaMapGuardianLocomotion.is_ground_style(guardian_style):
		if not bool(compiled.call("can_occupy", guardian_world, true)):
			return _reject("initial_guardian_not_walkable")
	elif guardian_enabled and not Rect2(Vector2.ZERO, layout.get("world_size", Vector2.ZERO) as Vector2).has_point(guardian_world):
		return _reject("initial_flight_guardian_out_of_world")

	var render_size := compiled_config.get("render_size", Vector2.ZERO) as Vector2
	var safe_rect := PlazaMapProjection.derive_safe_rect(render_size, compiled_config.get("safe_insets", {}) as Dictionary)
	var zoom := float(compiled_config.get("camera_zoom", 1.0))
	var projection := PlazaMapProjection.build_snapshot(layout.get("world_size", Vector2.ZERO) as Vector2, safe_rect, player_world, zoom)
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _reject("initial_projection_invalid")
	var visual_config := compiled_config.get("visual_config", {}) as Dictionary
	if not _retained_host.call("bind_scene", layout, compiled_config.get("environment_plan", {}) as Dictionary, visual_config, projection):
		return _reject("retained_host_bind_failed:%s" % str((_retained_host.call("get_debug_status") as Dictionary).get("rejection_reason", "")))

	_layout = layout.duplicate(true)
	_layout_fingerprint = layout_fingerprint
	_environment_plan = (compiled_config.get("environment_plan", {}) as Dictionary).duplicate(true)
	_compiled_navigation = compiled
	_compiled_minimap = compiled_minimap.duplicate(true)
	_render_size = render_size
	_safe_rect = safe_rect
	_minimap_rect = compiled_config.get("minimap_rect", Rect2()) as Rect2
	_camera_zoom = zoom
	_camera_center_world = projection.get("camera_center_world", player_world) as Vector2
	_projection = projection.duplicate(true)
	_player_world_position = player_world
	_guardian_enabled = guardian_enabled
	_guardian_world_position = guardian_world
	_guardian_locomotion_style = guardian_style
	_player_facing = 1
	_player_moving = false
	_last_ticks_msec = int(compiled_config.get("ticks_msec", 0))
	_bound = true
	_rejection_reason = ""
	size = render_size
	var dynamic_state := _build_dynamic_state()
	if not _retained_host.call("sync_dynamic", dynamic_state, _projection):
		clear_transient_canvas_items()
		return _reject("initial_dynamic_sync_failed")
	if not _sync_minimap():
		clear_transient_canvas_items()
		return _reject("initial_minimap_sync_failed")
	set_active(true)
	return true


func tick_candidate(input_direction: Vector2, delta: float, ticks_msec: int) -> Dictionary:
	if not _bound or _compiled_navigation == null:
		return _tick_rejection("not_bound")
	if not input_direction.is_finite() or not is_finite(delta) or delta < 0.0 or ticks_msec < 0:
		return _tick_rejection("invalid_tick_input")
	var started_usec := Time.get_ticks_usec()
	var previous_player := _player_world_position
	var previous_guardian := _guardian_world_position
	var previous_camera := _camera_center_world

	var move_result: Dictionary = _compiled_navigation.call("move_actor", _player_world_position, input_direction, delta)
	if not bool(move_result.get("valid", false)):
		return _tick_rejection("player_move_failed:%s" % str(move_result.get("rejection_reason", "")))
	var next_player := move_result.get("actor_position", _player_world_position) as Vector2
	var applied_delta := next_player - _player_world_position
	_player_world_position = next_player
	_player_moving = applied_delta.length_squared() > 0.0001
	# Y-only movement is walking, but the left/right-only sheet keeps the last
	# valid X facing rather than inventing an up/down direction.
	if absf(applied_delta.x) > 0.001:
		_player_facing = -1 if applied_delta.x < 0.0 else 1

	if _guardian_enabled:
		var guardian_result := PlazaMapGuardianLocomotion.compute_follow_step(
			_compiled_navigation,
			_guardian_world_position,
			_player_world_position,
			delta,
			_guardian_locomotion_style
		)
		if not bool(guardian_result.get("valid", false)):
			_player_world_position = previous_player
			return _tick_rejection("guardian_move_failed:%s" % str(guardian_result.get("rejection_reason", "")))
		_guardian_world_position = guardian_result.get("position", _guardian_world_position) as Vector2

	var camera_blend := clampf(maxf(0.0, delta) * 60.0 * CAMERA_BLEND_PER_FRAME_60, 0.0, 1.0)
	var requested_camera := _camera_center_world.lerp(_player_world_position, camera_blend)
	var projection := PlazaMapProjection.build_snapshot(
		_layout.get("world_size", Vector2.ZERO) as Vector2,
		_safe_rect,
		requested_camera,
		_camera_zoom
	)
	if not PlazaMapProjection.is_valid_snapshot(projection):
		_player_world_position = previous_player
		_guardian_world_position = previous_guardian
		return _tick_rejection("projection_update_failed")
	_camera_center_world = projection.get("camera_center_world", requested_camera) as Vector2
	_projection = projection.duplicate(true)
	_last_ticks_msec = ticks_msec
	if not _retained_host.call("sync_dynamic", _build_dynamic_state(), _projection):
		_player_world_position = previous_player
		_guardian_world_position = previous_guardian
		_camera_center_world = previous_camera
		return _fatal_tick_rejection("retained_host_sync_failed")
	if not _sync_minimap():
		_player_world_position = previous_player
		_guardian_world_position = previous_guardian
		_camera_center_world = previous_camera
		return _fatal_tick_rejection("minimap_sync_failed")

	_total_tick_count += 1
	_successful_tick_count += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	if _total_tick_count > PERF_WARMUP_TICKS:
		_record_perf_sample(elapsed_usec)
	return {
		"valid": true,
		"rejection_reason": "",
		"player_world_position": _player_world_position,
		"guardian_world_position": _guardian_world_position if _guardian_enabled else Vector2.INF,
		"player_applied_delta": applied_delta,
		"player_moving": _player_moving,
		"player_facing": _player_facing,
		"camera_center_world": _camera_center_world,
		"camera_visible_world_rect": _projection.get("visible_world_rect", Rect2()),
		"owner_tick_usec": elapsed_usec,
	}


func request_guardian_recall(desired_world_position: Vector2) -> Dictionary:
	if not _bound or not _guardian_enabled:
		return {"valid": false, "rejection_reason": "guardian_unavailable"}
	var result := PlazaMapGuardianLocomotion.project_recall_destination(
		_compiled_navigation,
		desired_world_position,
		_guardian_locomotion_style
	)
	if not bool(result.get("valid", false)):
		return result
	var previous_guardian := _guardian_world_position
	_guardian_world_position = result.get("position", _guardian_world_position) as Vector2
	if not _retained_host.call("sync_dynamic", _build_dynamic_state(), _projection):
		_guardian_world_position = previous_guardian
		set_active(false)
		return {"valid": false, "rejection_reason": "retained_host_sync_failed"}
	if not _sync_minimap():
		_guardian_world_position = previous_guardian
		set_active(false)
		return {"valid": false, "rejection_reason": "minimap_sync_failed"}
	return result


func try_interact() -> Dictionary:
	if not _bound or _compiled_navigation == null:
		return _interaction_rejection("not_bound")
	var exit_zone := _layout.get("exit_zone", Rect2()) as Rect2
	if exit_zone.has_point(_player_world_position):
		_interaction_count += 1
		return {
			"valid": true,
			"interaction_kind": "exit",
			"exit_zone": exit_zone,
		}
	for portal in _dictionary_array(_layout.get("interaction_portals", [])):
		var polygon := _packed_polygon(portal.get("polygon_world", []))
		if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(_player_world_position, polygon):
			continue
		var plot_id := str(portal.get("plot_id", ""))
		var building_type := str(portal.get("building_type", ""))
		var building := _find_building(building_type, plot_id)
		if building.is_empty():
			return _interaction_rejection("portal_building_missing")
		_interaction_count += 1
		return {
			"valid": true,
			"interaction_kind": "building",
			"portal_id": str(portal.get("id", "")),
			"building_type": building_type,
			"plot_id": plot_id,
			"building": building.duplicate(true),
		}
	return _interaction_rejection("no_interaction_portal")


func set_active(active: bool) -> void:
	_active = active and _bound
	visible = _active
	_retained_host.call("set_active", _active)
	_minimap_canvas.call("set_active", _active)
	set_process(false)


func clear_transient_canvas_items() -> void:
	_active = false
	_bound = false
	visible = false
	_layout.clear()
	_layout_fingerprint = ""
	_environment_plan.clear()
	_compiled_navigation = null
	_compiled_minimap.clear()
	_projection.clear()
	_safe_rect = Rect2()
	_minimap_rect = Rect2()
	_render_size = Vector2.ZERO
	_player_world_position = Vector2.ZERO
	_guardian_world_position = Vector2.ZERO
	_guardian_enabled = false
	_guardian_locomotion_style = PlazaMapGuardianLocomotion.STYLE_GROUND
	_player_moving = false
	_player_facing = 1
	_camera_zoom = 1.0
	_camera_center_world = Vector2.ZERO
	_last_ticks_msec = 0
	_successful_tick_count = 0
	_interaction_count = 0
	_total_tick_count = 0
	_perf_sample_count = 0
	_perf_sample_cursor = 0
	_retained_host.call("clear_transient_canvas_items")
	_minimap_canvas.call("clear_transient_canvas_items")
	_rejection_reason = "cleared"


func get_owner_cadence_metrics() -> Dictionary:
	var samples: Array[int] = []
	for index in range(_perf_sample_count):
		samples.append(int(_perf_samples[index]))
	samples.sort()
	var p95 := 0.0
	var maximum := 0
	var mean := 0.0
	if not samples.is_empty():
		var p95_index := clampi(ceili(float(samples.size()) * 0.95) - 1, 0, samples.size() - 1)
		p95 = float(samples[p95_index])
		maximum = samples[-1]
		var total := 0
		for sample in samples:
			total += sample
		mean = float(total) / float(samples.size())
	return {
		"sample_count": samples.size(),
		"warmup_ticks": PERF_WARMUP_TICKS,
		"p95_usec": p95,
		"max_usec": maximum,
		"mean_usec": mean,
		"limit_usec": OWNER_CADENCE_P95_LIMIT_USEC,
		"within_limit": not samples.is_empty() and p95 <= OWNER_CADENCE_P95_LIMIT_USEC,
	}


func get_debug_status() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"active": _active,
		"bound": _bound,
		"visible": visible,
		"rejection_reason": _rejection_reason,
		"layout_fingerprint": _layout_fingerprint,
		"environment_plan_fingerprint": str(_environment_plan.get("fingerprint", "")),
		"render_size": _render_size,
		"player_world_position": _player_world_position,
		"guardian_enabled": _guardian_enabled,
		"guardian_world_position": _guardian_world_position,
		"guardian_locomotion_style": _guardian_locomotion_style,
		"player_moving": _player_moving,
		"player_facing": _player_facing,
		"camera_center_world": _camera_center_world,
		"projection": _projection.duplicate(true),
		"successful_tick_count": _successful_tick_count,
		"interaction_count": _interaction_count,
		"owner_cadence": get_owner_cadence_metrics(),
		"retained_host": _retained_host.call("get_debug_status"),
		"minimap": _minimap_canvas.call("get_debug_status"),
	}


func get_retained_host_for_test() -> Control:
	return _retained_host


func get_minimap_canvas_for_test() -> Control:
	return _minimap_canvas


func get_compiled_navigation_for_test() -> Object:
	return _compiled_navigation


func _compile_bind_config(config: Dictionary) -> Dictionary:
	if str(config.get("composition_approval_id", "")) != ENVIRONMENT_COMPOSITION_APPROVAL_ID:
		return _invalid("composition_approval_missing")
	var layout_value: Variant = config.get("layout", null)
	var plan_value: Variant = config.get("environment_plan", null)
	var render_value: Variant = config.get("render_size", null)
	var insets_value: Variant = config.get("safe_insets", null)
	var minimap_value: Variant = config.get("minimap_rect", null)
	var player_value: Variant = config.get("initial_player_world_position", null)
	var zoom_value: Variant = config.get("camera_zoom", null)
	var ticks_value: Variant = config.get("ticks_msec", 0)
	if not (layout_value is Dictionary) or not (plan_value is Dictionary):
		return _invalid("layout_or_plan_type_invalid")
	if not (render_value is Vector2) or not (insets_value is Dictionary) or not (minimap_value is Rect2):
		return _invalid("view_contract_type_invalid")
	if not (player_value is Vector2) or not _finite_number(zoom_value) or typeof(ticks_value) != TYPE_INT:
		return _invalid("initial_actor_or_time_type_invalid")
	var render_size := render_value as Vector2
	var minimap_rect := minimap_value as Rect2
	var player_world := player_value as Vector2
	var zoom := float(zoom_value)
	if not render_size.is_finite() or render_size.x <= 1.0 or render_size.y <= 1.0:
		return _invalid("render_size_invalid")
	if not _finite_rect(minimap_rect) or not minimap_rect.has_area():
		return _invalid("minimap_rect_invalid")
	if not Rect2(Vector2.ZERO, render_size).encloses(minimap_rect):
		return _invalid("minimap_rect_outside_render")
	if not player_world.is_finite() or zoom <= 1.0 or zoom > PlazaMapProjection.MAX_ZOOM or int(ticks_value) < 0:
		return _invalid("initial_actor_or_time_invalid")
	var layout := layout_value as Dictionary
	var plan := plan_value as Dictionary
	if str(plan.get("layout_fingerprint", "")) != str(layout.get("fingerprint", "")):
		return _invalid("plan_layout_fingerprint_mismatch")
	if PlazaR3EnvironmentLayoutCompiler.build_fingerprint(plan) != str(plan.get("fingerprint", "")):
		return _invalid("stale_environment_plan_fingerprint")
	var visual_value: Variant = config.get("visual_config", null)
	if not (visual_value is Dictionary):
		return _invalid("visual_config_type_invalid")
	var visual_config := visual_value as Dictionary
	var guardian_enabled_value: Variant = visual_config.get("guardian_enabled", false)
	if typeof(guardian_enabled_value) != TYPE_BOOL:
		return _invalid("guardian_enabled_type_invalid")
	var guardian_enabled := bool(guardian_enabled_value)
	var guardian_position := Vector2.ZERO
	var guardian_style := PlazaMapGuardianLocomotion.STYLE_GROUND
	if guardian_enabled:
		var guardian_position_value: Variant = config.get("initial_guardian_world_position", null)
		var guardian_style_value: Variant = config.get("guardian_locomotion_style", null)
		if not (guardian_position_value is Vector2) or not (guardian_style_value is String):
			return _invalid("guardian_bind_type_invalid")
		guardian_position = guardian_position_value as Vector2
		guardian_style = str(guardian_style_value)
		if not guardian_position.is_finite() or not [
			PlazaMapGuardianLocomotion.STYLE_GROUND,
			PlazaMapGuardianLocomotion.STYLE_PATROL,
			PlazaMapGuardianLocomotion.STYLE_FLIGHT,
		].has(guardian_style):
			return _invalid("guardian_bind_invalid")
	return {
		"valid": true,
		"layout": layout.duplicate(true),
		"environment_plan": plan.duplicate(true),
		"render_size": render_size,
		"safe_insets": (insets_value as Dictionary).duplicate(true),
		"minimap_rect": minimap_rect,
		"camera_zoom": zoom,
		"ticks_msec": int(ticks_value),
		"initial_player_world_position": player_world,
		"guardian_enabled": guardian_enabled,
		"initial_guardian_world_position": guardian_position,
		"guardian_locomotion_style": guardian_style,
		"visual_config": visual_config.duplicate(false),
	}


func _build_dynamic_state() -> Dictionary:
	return {
		"player_world_position": _player_world_position,
		"guardian_world_position": _guardian_world_position if _guardian_enabled else null,
		"ticks_msec": _last_ticks_msec,
		"player_moving": _player_moving,
		"player_facing": _player_facing,
	}


func _sync_minimap() -> bool:
	var guardian_value: Variant = _guardian_world_position if _guardian_enabled else null
	var snapshot := PlazaR3MinimapProjection.project_compiled(
		_compiled_minimap,
		_minimap_rect,
		_player_world_position,
		guardian_value,
		_projection.get("visible_world_rect", Rect2()) as Rect2
	)
	if not bool(snapshot.get("valid", false)):
		return false
	return bool(_minimap_canvas.call("sync_snapshot", snapshot, true))


func _record_perf_sample(elapsed_usec: int) -> void:
	_perf_samples[_perf_sample_cursor] = elapsed_usec
	_perf_sample_cursor = (_perf_sample_cursor + 1) % PERF_SAMPLE_CAPACITY
	_perf_sample_count = mini(_perf_sample_count + 1, PERF_SAMPLE_CAPACITY)


func _find_building(building_type: String, plot_id: String) -> Dictionary:
	for building in _dictionary_array(_layout.get("building_specs", [])):
		if str(building.get("type", "")) == building_type and str(building.get("plot_id", "")) == plot_id:
			return building
	return {}


func _packed_polygon(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return (value as PackedVector2Array).duplicate()
	var result := PackedVector2Array()
	if not (value is Array):
		return result
	for entry in value as Array:
		if not (entry is Vector2):
			return PackedVector2Array()
		result.append(entry as Vector2)
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry in value as Array:
		if entry is Dictionary:
			result.append(entry as Dictionary)
	return result


func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _reject(reason: String) -> bool:
	_rejection_reason = reason
	set_active(false)
	return false


func _tick_rejection(reason: String) -> Dictionary:
	_rejection_reason = reason
	return {
		"valid": false,
		"rejection_reason": reason,
		"player_world_position": _player_world_position,
		"guardian_world_position": _guardian_world_position,
	}


func _fatal_tick_rejection(reason: String) -> Dictionary:
	set_active(false)
	return _tick_rejection(reason)


func _interaction_rejection(reason: String) -> Dictionary:
	return {
		"valid": false,
		"interaction_kind": "",
		"rejection_reason": reason,
	}
