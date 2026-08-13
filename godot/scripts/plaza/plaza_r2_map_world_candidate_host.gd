extends Control

# R2-B candidate-only retained map owner. This file is intentionally not
# referenced by PlazaScene: it proves the projection/Y-sort ownership shape
# before the production street, interior, movement, and minimap migrate as one
# atomic slice.

const PlazaBackgroundProjection := preload("res://scripts/plaza/plaza_background_projection.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")

const SCHEMA_VERSION := "plaza_r2_map_world_candidate_host_v1"
const DEFAULT_FILL_COLOR := Color(0.010, 0.009, 0.008, 1.0)
const DEFAULT_MAP_COLOR := Color(0.055, 0.049, 0.038, 1.0)
const DEFAULT_ACTOR_COLOR := Color(0.05, 0.92, 1.0, 1.0)
const DEFAULT_ACTOR_RECT_WORLD := Rect2(-48.0, -126.0, 96.0, 144.0)
const DEFAULT_GUARDIAN_COLOR := Color(0.72, 0.55, 1.0, 1.0)
const DEFAULT_GUARDIAN_RECT_WORLD := Rect2(-34.0, -88.0, 68.0, 100.0)

var _active := false
var _last_sync_rejection_reason := "not_synced"
var _successful_sync_count := 0
var _layout_fingerprint := ""
var _projection: Dictionary = {}
var _layout: Dictionary = {}
var _safe_rect := Rect2()
var _map_content_rect := Rect2()
var _ticks_msec := -1
var _road_draw_records: Array[Dictionary] = []

var _sort_root: Node2D = null
var _building_items: Array[Node2D] = []
var _actor_item: Node2D = null
var _guardian_item: Node2D = null
var _guardian_requested := false
var _mix_material: CanvasItemMaterial = null
var _add_material: CanvasItemMaterial = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)
	visible = false
	_build_retained_tree()


func _ready() -> void:
	set_process(false)
	set_active(false)


func sync_state(state: Dictionary, active: bool = true) -> bool:
	# Retained children survive quiet early returns. Always fail closed before
	# touching any caller-owned state, then reveal the complete tree only after
	# every projection, layout, texture, and sort-anchor check succeeds.
	set_active(false)
	if not active:
		return _reject("inactive")
	if not state.has("render_size"):
		return _reject("missing_render_size")
	if not state.has("layout"):
		return _reject("missing_layout")
	if not state.has("player_world_pos"):
		return _reject("missing_player_world_pos")
	if not state.has("ticks_msec"):
		return _reject("missing_ticks_msec")

	var render_size_value: Variant = state.get("render_size", null)
	var layout_value: Variant = state.get("layout", null)
	var player_value: Variant = state.get("player_world_pos", null)
	var ticks_value: Variant = state.get("ticks_msec", null)
	var insets_value: Variant = state.get("safe_insets", {})
	if not (render_size_value is Vector2):
		return _reject("invalid_render_size_type")
	if not (layout_value is Dictionary):
		return _reject("invalid_layout_type")
	if not (player_value is Vector2):
		return _reject("invalid_player_world_pos_type")
	if typeof(ticks_value) != TYPE_INT:
		return _reject("invalid_ticks_msec_type")
	if not (insets_value is Dictionary):
		return _reject("invalid_safe_insets_type")

	var render_size := render_size_value as Vector2
	var layout := layout_value as Dictionary
	var player_world_pos := player_value as Vector2
	var ticks_msec := int(ticks_value)
	if not render_size.is_finite() or render_size.x <= 1.0 or render_size.y <= 1.0:
		return _reject("degenerate_render_size")
	if not player_world_pos.is_finite():
		return _reject("invalid_player_world_pos")
	if ticks_msec < 0:
		return _reject("invalid_ticks_msec")
	if not bool(layout.get("candidate_only", false)) or bool(layout.get("production_connected", true)):
		return _reject("layout_not_candidate_only")

	var validation := PlazaMapLayoutGenerator.validate_layout(layout)
	if not bool(validation.get("valid", false)):
		return _reject("invalid_layout")
	var provided_fingerprint_value: Variant = layout.get("fingerprint", null)
	if not (provided_fingerprint_value is String) or str(provided_fingerprint_value).length() != 64:
		return _reject("invalid_layout_fingerprint")
	var provided_fingerprint := str(provided_fingerprint_value)
	var computed_fingerprint := PlazaMapLayoutGenerator.build_fingerprint(layout)
	if computed_fingerprint != provided_fingerprint:
		return _reject("stale_layout_fingerprint")

	var safe_rect := PlazaMapProjection.derive_safe_rect(render_size, insets_value as Dictionary)
	if not safe_rect.has_area():
		return _reject("invalid_safe_rect")
	var camera_center_value: Variant = state.get("camera_center_world", player_world_pos)
	var camera_zoom_value: Variant = state.get("camera_zoom", 1.0)
	if not (camera_center_value is Vector2) or not _is_finite_number(camera_zoom_value):
		return _reject("invalid_camera_request")
	var world_size_value: Variant = layout.get("world_size", null)
	if not (world_size_value is Vector2):
		return _reject("invalid_world_size")
	var world_size := world_size_value as Vector2
	if not Rect2(Vector2.ZERO, world_size).has_point(player_world_pos):
		return _reject("player_out_of_world")
	var projection := PlazaMapProjection.build_snapshot(
		world_size,
		safe_rect,
		camera_center_value as Vector2,
		float(camera_zoom_value)
	)
	if not PlazaMapProjection.is_valid_snapshot(projection):
		return _reject("invalid_projection")

	var building_specs_value: Variant = layout.get("building_specs", null)
	if not (building_specs_value is Array):
		return _reject("invalid_building_specs")
	var building_compile := _compile_building_visual_records(
		building_specs_value as Array,
		projection,
		ticks_msec,
		state.get("ysort_probe", {})
	)
	if not bool(building_compile.get("valid", false)):
		return _reject(str(building_compile.get("reason", "invalid_building_visual")))
	var actor_compile := _compile_actor_visual(player_world_pos, projection, state)
	if not bool(actor_compile.get("valid", false)):
		return _reject(str(actor_compile.get("reason", "invalid_actor_visual")))
	var guardian_requested := state.has("guardian_world_pos")
	var guardian_compile := {"valid": true, "record": {}}
	if guardian_requested:
		var guardian_value: Variant = state.get("guardian_world_pos", null)
		if not (guardian_value is Vector2):
			return _reject("invalid_guardian_world_pos_type")
		var guardian_world_pos := guardian_value as Vector2
		if not guardian_world_pos.is_finite():
			return _reject("invalid_guardian_world_pos")
		if not Rect2(Vector2.ZERO, world_size).has_point(guardian_world_pos):
			return _reject("guardian_out_of_world")
		guardian_compile = _compile_role_visual(
			guardian_world_pos,
			projection,
			state.get("guardian_rect_relative_world", DEFAULT_GUARDIAN_RECT_WORLD),
			state.get("guardian_color", DEFAULT_GUARDIAN_COLOR)
		)
		if not bool(guardian_compile.get("valid", false)):
			return _reject(str(guardian_compile.get("reason", "invalid_guardian_visual")))
	var road_compile := _compile_road_draw_records(layout, projection)
	if not bool(road_compile.get("valid", false)):
		return _reject(str(road_compile.get("reason", "invalid_road_visual")))

	# Compilation above is deliberately side-effect free. Invalid caller art can
	# never partially rewrite a retained node before the fail-closed rejection.
	_build_retained_tree()
	# A prior RED counterproof may have changed the actual nodes. Every valid
	# sync restores the canonical contract rather than trusting cached flags.
	_sort_root.y_sort_enabled = true
	_sort_root.z_index = 0
	_sort_root.z_as_relative = true
	_sort_root.top_level = false
	_sort_root.modulate = Color.WHITE
	_apply_building_visual_records(building_compile.get("records", []) as Array)
	_apply_actor_visual_record(actor_compile.get("record", {}) as Dictionary)
	_guardian_requested = guardian_requested
	if guardian_requested:
		_apply_guardian_visual_record(guardian_compile.get("record", {}) as Dictionary)

	_layout = layout.duplicate(true)
	_layout_fingerprint = provided_fingerprint
	_projection = projection.duplicate(true)
	_safe_rect = safe_rect
	_map_content_rect = PlazaMapProjection.get_map_content_screen_rect(projection)
	_road_draw_records.assign((road_compile.get("records", []) as Array).duplicate(true))
	_ticks_msec = ticks_msec
	size = render_size
	_last_sync_rejection_reason = ""
	_successful_sync_count += 1
	_active = true
	visible = true
	_sort_root.visible = true
	for item in _building_items:
		item.visible = true
	_actor_item.visible = true
	_guardian_item.visible = _guardian_requested
	set_process(false)
	queue_redraw()
	return true


func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(false)
	if _sort_root != null:
		_sort_root.visible = active
	for item in _building_items:
		if item != null:
			item.visible = active
	if _actor_item != null:
		_actor_item.visible = active
	if _guardian_item != null:
		_guardian_item.visible = active and _guardian_requested
	queue_redraw()


func clear_transient_canvas_items() -> void:
	set_active(false)
	_guardian_requested = false
	_projection.clear()
	_layout.clear()
	_layout_fingerprint = ""
	_safe_rect = Rect2()
	_map_content_rect = Rect2()
	_road_draw_records.clear()
	_ticks_msec = -1
	_last_sync_rejection_reason = "cleared"
	queue_redraw()


func get_sort_root_for_test() -> Node2D:
	return _sort_root


func get_actor_sort_item_for_test() -> Node2D:
	return _actor_item


func get_guardian_sort_item_for_test() -> Node2D:
	return _guardian_item


func get_building_sort_item_for_test(building_type: String) -> Node2D:
	for item in _building_items:
		if str(item.get_meta("building_type", "")) == building_type:
			return item
	return null


func get_projection_snapshot_for_test() -> Dictionary:
	return _projection.duplicate(true)


func get_road_draw_records_for_test() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_road_draw_records.duplicate(true))
	return result


func get_sort_contract_status() -> Dictionary:
	var direct_children: Array[Node] = []
	if _sort_root != null:
		direct_children.assign(_sort_root.get_children())
	var actor_count := 0
	var guardian_count := 0
	var building_count := 0
	var all_direct_parent_match := true
	var all_direct_z_zero := true
	var all_direct_relative := true
	var all_direct_not_top_level := true
	var all_wrapper_modulate_white := true
	var all_wrappers_group_children := true
	var all_layer_z_zero := true
	var all_layer_relative := true
	var all_layer_not_top_level := true
	var all_layer_self_modulate_white := true
	var all_layer_not_show_behind_parent := true
	var all_layer_not_using_parent_material := true
	var all_layer_material_contract_valid := true
	var layer_material_records: Array[Dictionary] = []
	var mix_material_id := _mix_material.get_instance_id() if _mix_material != null else 0
	var add_material_id := _add_material.get_instance_id() if _add_material != null else 0
	var mix_blend_mode := int(_mix_material.blend_mode) if _mix_material != null else -1
	var add_blend_mode := int(_add_material.blend_mode) if _add_material != null else -1
	var shared_material_blend_contract_valid := (
		_mix_material != null
		and _add_material != null
		and _mix_material.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX
		and _add_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
	)
	var sort_root_modulate_white := _sort_root != null and _sort_root.modulate.is_equal_approx(Color.WHITE)
	var actor_wrapper_visible := false
	var actor_body_visible := false
	var guardian_wrapper_visible := false
	var guardian_body_visible := false
	var records: Array[Dictionary] = []
	for child in direct_children:
		if not (child is Node2D):
			all_direct_parent_match = false
			all_direct_z_zero = false
			continue
		var item := child as Node2D
		var role := str(item.get_meta("sort_role", ""))
		if role == "actor":
			actor_count += 1
		elif role == "guardian":
			guardian_count += 1
		elif role == "building":
			building_count += 1
		all_direct_parent_match = all_direct_parent_match and item.get_parent() == _sort_root
		all_direct_z_zero = all_direct_z_zero and item.z_index == 0
		all_direct_relative = all_direct_relative and item.z_as_relative
		all_direct_not_top_level = all_direct_not_top_level and not item.top_level
		all_wrapper_modulate_white = all_wrapper_modulate_white and item.modulate.is_equal_approx(Color.WHITE)
		all_wrappers_group_children = all_wrappers_group_children and not item.y_sort_enabled
		if role == "actor":
			actor_wrapper_visible = item.visible
		elif role == "guardian":
			guardian_wrapper_visible = item.visible
		for layer in item.get_children():
			if layer is CanvasItem:
				var canvas_layer := layer as CanvasItem
				all_layer_z_zero = all_layer_z_zero and canvas_layer.z_index == 0
				all_layer_relative = all_layer_relative and canvas_layer.z_as_relative
				all_layer_not_top_level = all_layer_not_top_level and not canvas_layer.top_level
				all_layer_self_modulate_white = all_layer_self_modulate_white and canvas_layer.self_modulate.is_equal_approx(Color.WHITE)
				all_layer_not_show_behind_parent = all_layer_not_show_behind_parent and not canvas_layer.show_behind_parent
				all_layer_not_using_parent_material = all_layer_not_using_parent_material and not canvas_layer.use_parent_material
				if role == "actor" and str(layer.name) == "Body":
					actor_body_visible = canvas_layer.visible
				if role == "guardian" and str(layer.name) == "Body":
					guardian_body_visible = canvas_layer.visible
				var expected_material: Material = null
				var expected_blend_mode := -1
				var material_role_known := true
				match str(layer.name):
					"Base":
						expected_material = _mix_material
						expected_blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
					"SignEmissive", "WindowGlowMask":
						expected_material = _add_material
						expected_blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
					"YSortProbe", "Body":
						expected_material = null
					_:
						material_role_known = false
				var actual_material := canvas_layer.material
				var actual_material_id := actual_material.get_instance_id() if actual_material != null else 0
				var expected_material_id := expected_material.get_instance_id() if expected_material != null else 0
				var actual_blend_mode := (
					int((actual_material as CanvasItemMaterial).blend_mode)
					if actual_material is CanvasItemMaterial
					else -1
				)
				var material_valid := (
					material_role_known
					and actual_material == expected_material
					and actual_blend_mode == expected_blend_mode
					and not canvas_layer.use_parent_material
				)
				all_layer_material_contract_valid = all_layer_material_contract_valid and material_valid
				layer_material_records.append({
					"parent_name": item.name,
					"parent_role": role,
					"building_type": str(item.get_meta("building_type", "")),
					"layer_name": layer.name,
					"actual_material_id": actual_material_id,
					"expected_material_id": expected_material_id,
					"actual_blend_mode": actual_blend_mode,
					"expected_blend_mode": expected_blend_mode,
					"actual_use_parent_material": canvas_layer.use_parent_material,
					"expected_use_parent_material": false,
					"actual_self_modulate": canvas_layer.self_modulate,
					"expected_self_modulate": Color.WHITE,
					"actual_show_behind_parent": canvas_layer.show_behind_parent,
					"expected_show_behind_parent": false,
					"valid": material_valid,
				})
		records.append({
			"name": item.name,
			"role": role,
			"building_type": str(item.get_meta("building_type", "")),
			"parent_id": item.get_parent().get_instance_id() if item.get_parent() != null else 0,
			"position": item.position,
			"z_index": item.z_index,
			"z_as_relative": item.z_as_relative,
			"top_level": item.top_level,
			"y_sort_enabled": item.y_sort_enabled,
		})
	var expected_building_count := _building_items.size()
	var contract_valid := (
		_sort_root != null
		and _sort_root.y_sort_enabled
		and _sort_root.z_index == 0
		and _sort_root.z_as_relative
		and not _sort_root.top_level
		and sort_root_modulate_white
		and actor_count == 1
		and guardian_count == 1
		and building_count == expected_building_count
		and direct_children.size() == expected_building_count + 2
		and all_direct_parent_match
		and all_direct_z_zero
		and all_direct_relative
		and all_direct_not_top_level
		and all_wrapper_modulate_white
		and all_wrappers_group_children
		and all_layer_z_zero
		and all_layer_relative
		and all_layer_not_top_level
		and all_layer_self_modulate_white
		and all_layer_not_show_behind_parent
		and all_layer_not_using_parent_material
		and all_layer_material_contract_valid
		and shared_material_blend_contract_valid
		and actor_wrapper_visible
		and actor_body_visible
		and ((not _guardian_requested) or (guardian_wrapper_visible and guardian_body_visible))
	)
	return {
		"valid": contract_valid,
		"sort_root_id": _sort_root.get_instance_id() if _sort_root != null else 0,
		"sort_root_y_sort_enabled": _sort_root != null and _sort_root.y_sort_enabled,
		"sort_root_z_index": _sort_root.z_index if _sort_root != null else -999,
		"sort_root_modulate_white": sort_root_modulate_white,
		"direct_child_count": direct_children.size(),
		"building_count": building_count,
		"actor_count": actor_count,
		"all_direct_parent_match": all_direct_parent_match,
		"all_direct_z_zero": all_direct_z_zero,
		"all_direct_relative": all_direct_relative,
		"all_direct_not_top_level": all_direct_not_top_level,
		"all_wrapper_modulate_white": all_wrapper_modulate_white,
		"all_wrappers_group_children": all_wrappers_group_children,
		"all_layer_z_zero": all_layer_z_zero,
		"all_layer_relative": all_layer_relative,
		"all_layer_not_top_level": all_layer_not_top_level,
		"all_layer_self_modulate_white": all_layer_self_modulate_white,
		"all_layer_not_show_behind_parent": all_layer_not_show_behind_parent,
		"all_layer_not_using_parent_material": all_layer_not_using_parent_material,
		"all_layer_material_contract_valid": all_layer_material_contract_valid,
		"shared_material_blend_contract_valid": shared_material_blend_contract_valid,
		"mix_material_id": mix_material_id,
		"add_material_id": add_material_id,
		"mix_blend_mode": mix_blend_mode,
		"add_blend_mode": add_blend_mode,
		"actor_wrapper_visible": actor_wrapper_visible,
		"actor_body_visible": actor_body_visible,
		"guardian_count": guardian_count,
		"guardian_requested": _guardian_requested,
		"guardian_wrapper_visible": guardian_wrapper_visible,
		"guardian_body_visible": guardian_body_visible,
		"layer_material_records": layer_material_records,
		"records": records,
	}


func get_debug_status() -> Dictionary:
	var visible_buildings := 0
	for item in _building_items:
		if item != null and item.visible:
			visible_buildings += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"active": _active,
		"visible": visible,
		"process_enabled": is_processing(),
		"last_sync_rejection_reason": _last_sync_rejection_reason,
		"successful_sync_count": _successful_sync_count,
		"layout_fingerprint": _layout_fingerprint,
		"projection_valid": PlazaMapProjection.is_valid_snapshot(_projection),
		"safe_rect": _safe_rect,
		"map_content_rect": _map_content_rect,
		"ticks_msec": _ticks_msec,
		"road_draw_record_count": _road_draw_records.size(),
		"building_item_count": _building_items.size(),
		"visible_building_count": visible_buildings,
		"actor_visible": _actor_item != null and _actor_item.visible,
		"guardian_visible": _guardian_item != null and _guardian_item.visible,
		"guardian_requested_debug": _guardian_requested,
		"sort_contract": get_sort_contract_status(),
	}


func _draw() -> void:
	if not _active or not PlazaMapProjection.is_valid_snapshot(_projection):
		return
	draw_rect(Rect2(Vector2.ZERO, size), DEFAULT_FILL_COLOR, true)
	draw_rect(_safe_rect, Color(0.075, 0.061, 0.043, 1.0), true)
	draw_rect(_map_content_rect, DEFAULT_MAP_COLOR, true)
	for record in _road_draw_records:
		draw_polyline(
			record.get("screen_points", PackedVector2Array()) as PackedVector2Array,
			record.get("outline_color", Color.TRANSPARENT) as Color,
			float(record.get("outline_width", 0.0)),
			true
		)
		draw_polyline(
			record.get("screen_points", PackedVector2Array()) as PackedVector2Array,
			record.get("fill_color", Color.TRANSPARENT) as Color,
			float(record.get("fill_width", 0.0)),
			true
		)


func _build_retained_tree() -> void:
	if _mix_material == null:
		_mix_material = CanvasItemMaterial.new()
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
	_restore_shared_material_contract()
	if _sort_root == null:
		_sort_root = Node2D.new()
		_sort_root.name = "CandidateYSortRoot"
		_sort_root.y_sort_enabled = true
		_sort_root.z_index = 0
		_sort_root.z_as_relative = true
		_sort_root.top_level = false
		add_child(_sort_root)
	if _actor_item == null:
		_actor_item = _create_actor_item()
		_sort_root.add_child(_actor_item)
	if _guardian_item == null:
		_guardian_item = _create_guardian_item()
		_sort_root.add_child(_guardian_item)


func _compile_building_visual_records(
	spec_values: Array,
	projection: Dictionary,
	ticks_msec: int,
	probe_value: Variant
) -> Dictionary:
	if not (probe_value is Dictionary):
		return _compile_reject("invalid_probe_type")
	var probe := probe_value as Dictionary
	var probe_active := not probe.is_empty()
	var probe_building_type := ""
	var probe_rect := Rect2()
	var probe_color := Color.TRANSPARENT
	if probe_active:
		var probe_type_value: Variant = probe.get("building_type", null)
		var probe_rect_value: Variant = probe.get("rect_relative_world", null)
		var probe_color_value: Variant = probe.get("color", null)
		if not (probe_type_value is String) or str(probe_type_value).is_empty():
			return _compile_reject("invalid_probe_building_type")
		if not (probe_rect_value is Rect2):
			return _compile_reject("invalid_probe_rect_type")
		if not (probe_color_value is Color):
			return _compile_reject("invalid_probe_color_type")
		probe_rect = probe_rect_value as Rect2
		probe_color = probe_color_value as Color
		if not _is_finite_rect(probe_rect) or not probe_rect.has_area():
			return _compile_reject("invalid_probe_rect")
		if not _is_finite_color(probe_color):
			return _compile_reject("invalid_probe_color")
		probe_building_type = str(probe_type_value)

	var projection_scale_value: Variant = projection.get("projection_scale", null)
	if not _is_finite_number(projection_scale_value) or float(projection_scale_value) <= 0.0:
		return _compile_reject("invalid_projection_scale")
	var projection_scale := float(projection_scale_value)
	var records: Array[Dictionary] = []
	var probe_target_found := not probe_active
	for index in range(spec_values.size()):
		if not (spec_values[index] is Dictionary):
			return _compile_reject("invalid_building_spec_type")
		var spec := spec_values[index] as Dictionary
		var building_type_value: Variant = spec.get("type", null)
		var base_value: Variant = spec.get("base_texture", null)
		var sign_value: Variant = spec.get("sign_texture", null)
		var window_value: Variant = spec.get("window_texture", null)
		var visual_value: Variant = spec.get("visual_rect", null)
		var anchor_value: Variant = spec.get("sort_anchor_world", null)
		var sign_color_value: Variant = spec.get("sign_glow_color", Color.WHITE)
		var window_color_value: Variant = spec.get("window_glow_color", Color.WHITE)
		var sign_strength_value: Variant = spec.get("sign_glow_strength", 1.0)
		var window_strength_value: Variant = spec.get("window_glow_strength", 1.0)
		if not (building_type_value is String) or str(building_type_value).is_empty():
			return _compile_reject("invalid_building_type")
		if not (base_value is Texture2D) or not (sign_value is Texture2D) or not (window_value is Texture2D):
			return _compile_reject("invalid_building_texture")
		if not (visual_value is Rect2) or not (anchor_value is Vector2):
			return _compile_reject("invalid_building_geometry_type")
		if not (sign_color_value is Color) or not (window_color_value is Color):
			return _compile_reject("invalid_building_glow_color_type")
		if not _is_nonnegative_finite_number(sign_strength_value) or not _is_nonnegative_finite_number(window_strength_value):
			return _compile_reject("invalid_building_glow_strength")
		var visual_rect := visual_value as Rect2
		var anchor_world := anchor_value as Vector2
		if not _is_finite_rect(visual_rect) or not visual_rect.has_area() or not anchor_world.is_finite():
			return _compile_reject("invalid_building_geometry")
		var sign_color := sign_color_value as Color
		var window_color := window_color_value as Color
		if not _is_finite_color(sign_color) or not _is_finite_color(window_color):
			return _compile_reject("invalid_building_glow_color")
		var screen_rect := PlazaMapProjection.world_rect_to_screen(visual_rect, projection)
		var anchor_screen := PlazaMapProjection.world_to_screen(anchor_world, projection)
		if not screen_rect.has_area() or not anchor_screen.is_finite():
			return _compile_reject("invalid_projected_building_geometry")

		var building_type := str(building_type_value)
		var pulse := PlazaBackgroundProjection.discrete_flicker(
			"r2b:%s:%d" % [building_type, int(round(anchor_world.x))],
			ticks_msec
		)
		var sign_modulate := _glow_modulate(
			sign_color,
			float(sign_strength_value),
			0.72 + pulse * 0.22
		)
		var window_modulate := _glow_modulate(
			window_color,
			float(window_strength_value),
			0.56 + pulse * 0.12
		)
		if not _is_finite_color(sign_modulate) or not _is_finite_color(window_modulate):
			return _compile_reject("invalid_building_glow_modulate")
		var probe_record: Dictionary = {}
		if probe_active and building_type == probe_building_type:
			probe_target_found = true
			probe_record = {
				"rect_relative_screen": Rect2(probe_rect.position * projection_scale, probe_rect.size * projection_scale),
				"color": probe_color,
			}
		records.append({
			"building_type": building_type,
			"anchor_world": anchor_world,
			"anchor_screen": anchor_screen,
			"screen_rect": screen_rect,
			"base_texture": base_value,
			"sign_texture": sign_value,
			"window_texture": window_value,
			"sign_modulate": sign_modulate,
			"window_modulate": window_modulate,
			"probe": probe_record,
		})
	if not probe_target_found:
		return _compile_reject("missing_probe_target")
	return {"valid": true, "records": records}


func _compile_actor_visual(player_world_pos: Vector2, projection: Dictionary, state: Dictionary) -> Dictionary:
	return _compile_role_visual(
		player_world_pos,
		projection,
		state.get("actor_rect_relative_world", DEFAULT_ACTOR_RECT_WORLD),
		state.get("actor_color", DEFAULT_ACTOR_COLOR)
	)


func _compile_role_visual(
	world_pos: Vector2,
	projection: Dictionary,
	rect_value: Variant,
	color_value: Variant
) -> Dictionary:
	if not (rect_value is Rect2) or not (color_value is Color):
		return _compile_reject("invalid_actor_art_type")
	var actor_rect := rect_value as Rect2
	var actor_color := color_value as Color
	if not _is_finite_rect(actor_rect) or not actor_rect.has_area() or not _is_finite_color(actor_color):
		return _compile_reject("invalid_actor_art")
	var foot_screen := PlazaMapProjection.world_to_screen(world_pos, projection)
	if not foot_screen.is_finite():
		return _compile_reject("invalid_projected_actor_foot")
	var scale_value: Variant = projection.get("projection_scale", null)
	if not _is_finite_number(scale_value) or float(scale_value) <= 0.0:
		return _compile_reject("invalid_actor_projection_scale")
	var actor_screen_rect := Rect2(actor_rect.position * float(scale_value), actor_rect.size * float(scale_value))
	if not _is_finite_rect(actor_screen_rect) or not actor_screen_rect.has_area():
		return _compile_reject("invalid_projected_actor_rect")
	return {
		"valid": true,
		"record": {
			"world_pos": world_pos,
			"foot_screen": foot_screen,
			"screen_rect_relative": actor_screen_rect,
			"color": actor_color,
		},
	}


func _compile_road_draw_records(layout: Dictionary, projection: Dictionary) -> Dictionary:
	var road_graph_value: Variant = layout.get("road_graph", null)
	if not (road_graph_value is Dictionary):
		return _compile_reject("invalid_road_graph_type")
	var edges_value: Variant = (road_graph_value as Dictionary).get("edges", null)
	if not (edges_value is Array):
		return _compile_reject("invalid_road_edges_type")
	var projection_scale_value: Variant = projection.get("projection_scale", null)
	if not _is_finite_number(projection_scale_value) or float(projection_scale_value) <= 0.0:
		return _compile_reject("invalid_road_projection_scale")
	var projection_scale := float(projection_scale_value)
	var records: Array[Dictionary] = []
	for edge_value in edges_value as Array:
		if not (edge_value is Dictionary):
			return _compile_reject("invalid_road_edge_type")
		var edge := edge_value as Dictionary
		var polyline_compile := _compile_vector2_array(edge.get("polyline_world", null))
		if not bool(polyline_compile.get("valid", false)):
			return _compile_reject("invalid_road_polyline")
		var polyline := polyline_compile.get("points", PackedVector2Array()) as PackedVector2Array
		if polyline.size() < 2:
			return _compile_reject("short_road_polyline")
		var half_width_value: Variant = edge.get("half_width_world", null)
		var kind_value: Variant = edge.get("kind", null)
		if not _is_nonnegative_finite_number(half_width_value) or float(half_width_value) <= 0.0:
			return _compile_reject("invalid_road_half_width")
		if not (kind_value is String):
			return _compile_reject("invalid_road_kind")
		var screen_points := PlazaMapProjection.project_polygon(polyline, projection)
		if screen_points.size() < 2:
			return _compile_reject("invalid_projected_road_polyline")
		for point in screen_points:
			if not point.is_finite():
				return _compile_reject("nonfinite_projected_road_polyline")
		var road_width := float(half_width_value) * 2.0 * projection_scale
		if not is_finite(road_width) or road_width <= 0.0:
			return _compile_reject("invalid_projected_road_width")
		var is_main := str(kind_value) == "main"
		records.append({
			"screen_points": screen_points.duplicate(),
			"outline_color": Color(0.012, 0.011, 0.010, 0.98),
			"outline_width": road_width + 8.0,
			"fill_color": Color(0.115, 0.105, 0.086, 1.0) if is_main else Color(0.082, 0.078, 0.067, 1.0),
			"fill_width": road_width,
		})
	return {"valid": true, "records": records}


func _apply_building_visual_records(record_values: Array) -> void:
	while _building_items.size() < record_values.size():
		var item := _create_building_item(_building_items.size())
		# Actor remains a direct sibling and tree order is irrelevant to non-tied
		# Y anchors. Insert buildings before it for deterministic tie fallback.
		_sort_root.add_child(item)
		_sort_root.move_child(item, _building_items.size())
		_building_items.append(item)
	while _building_items.size() > record_values.size():
		var stale: Node2D = _building_items.pop_back()
		_sort_root.remove_child(stale)
		stale.free()

	for index in range(record_values.size()):
		var record := record_values[index] as Dictionary
		var item := _building_items[index]
		_restore_sort_item_contract(item)
		item.name = "Building_%s" % str(record.get("building_type", index))
		item.set_meta("sort_role", "building")
		item.set_meta("building_type", str(record.get("building_type", "")))
		item.set_meta("sort_anchor_world", record.get("anchor_world", Vector2.ZERO))
		item.position = record.get("anchor_screen", Vector2.ZERO) as Vector2
		var anchor_screen := record.get("anchor_screen", Vector2.ZERO) as Vector2
		var screen_rect := record.get("screen_rect", Rect2()) as Rect2
		var base := item.get_node("Base") as Sprite2D
		var sign := item.get_node("SignEmissive") as Sprite2D
		var window := item.get_node("WindowGlowMask") as Sprite2D
		_apply_sprite(base, record.get("base_texture", null) as Texture2D, screen_rect, anchor_screen, _mix_material)
		_apply_sprite(sign, record.get("sign_texture", null) as Texture2D, screen_rect, anchor_screen, _add_material)
		_apply_sprite(window, record.get("window_texture", null) as Texture2D, screen_rect, anchor_screen, _add_material)
		base.modulate = Color.WHITE
		sign.modulate = record.get("sign_modulate", Color.WHITE) as Color
		window.modulate = record.get("window_modulate", Color.WHITE) as Color
		_apply_probe_record(item, record.get("probe", {}) as Dictionary)


func _apply_actor_visual_record(record: Dictionary) -> void:
	_apply_role_visual_record(_actor_item, "actor", record, DEFAULT_ACTOR_COLOR)


func _apply_guardian_visual_record(record: Dictionary) -> void:
	_apply_role_visual_record(_guardian_item, "guardian", record, DEFAULT_GUARDIAN_COLOR)


func _apply_role_visual_record(item: Node2D, role: String, record: Dictionary, fallback_color: Color) -> void:
	_restore_sort_item_contract(item)
	item.set_meta("sort_role", role)
	item.set_meta("building_type", "")
	item.set_meta("sort_anchor_world", record.get("world_pos", Vector2.ZERO))
	item.position = record.get("foot_screen", Vector2.ZERO) as Vector2
	var body := item.get_node("Body") as Polygon2D
	_restore_canvas_layer_contract(body)
	body.material = null
	body.visible = true
	body.polygon = _rect_polygon(record.get("screen_rect_relative", Rect2()) as Rect2)
	body.color = record.get("color", fallback_color) as Color


func _create_building_item(index: int) -> Node2D:
	var item := Node2D.new()
	item.name = "Building_%d" % index
	item.set_meta("sort_role", "building")
	_restore_sort_item_contract(item)
	var base := _make_sprite("Base", _mix_material)
	var sign := _make_sprite("SignEmissive", _add_material)
	var window := _make_sprite("WindowGlowMask", _add_material)
	var probe := Polygon2D.new()
	probe.name = "YSortProbe"
	_restore_canvas_layer_contract(probe)
	probe.visible = false
	item.add_child(base)
	item.add_child(sign)
	item.add_child(window)
	item.add_child(probe)
	return item


func _create_actor_item() -> Node2D:
	var item := Node2D.new()
	item.name = "Actor"
	item.set_meta("sort_role", "actor")
	_restore_sort_item_contract(item)
	var body := Polygon2D.new()
	body.name = "Body"
	_restore_canvas_layer_contract(body)
	body.color = DEFAULT_ACTOR_COLOR
	item.add_child(body)
	return item


func _create_guardian_item() -> Node2D:
	var item := Node2D.new()
	item.name = "Guardian"
	item.set_meta("sort_role", "guardian")
	_restore_sort_item_contract(item)
	var body := Polygon2D.new()
	body.name = "Body"
	_restore_canvas_layer_contract(body)
	body.color = DEFAULT_GUARDIAN_COLOR
	item.add_child(body)
	return item


func _make_sprite(node_name: String, layer_material: CanvasItemMaterial) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.z_index = 0
	sprite.z_as_relative = true
	sprite.top_level = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = layer_material
	return sprite


func _restore_sort_item_contract(item: Node2D) -> void:
	item.z_index = 0
	item.z_as_relative = true
	item.top_level = false
	item.y_sort_enabled = false
	item.modulate = Color.WHITE


func _apply_sprite(
	sprite: Sprite2D,
	texture: Texture2D,
	screen_rect: Rect2,
	anchor_screen: Vector2,
	expected_material: CanvasItemMaterial
) -> void:
	sprite.texture = texture
	sprite.position = screen_rect.position - anchor_screen
	sprite.scale = Vector2(
		screen_rect.size.x / maxf(1.0, texture.get_width()),
		screen_rect.size.y / maxf(1.0, texture.get_height())
	)
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.flip_v = false
	_restore_canvas_layer_contract(sprite)
	sprite.material = expected_material
	sprite.visible = true


func _apply_probe_record(item: Node2D, probe: Dictionary) -> void:
	var probe_node := item.get_node("YSortProbe") as Polygon2D
	_restore_canvas_layer_contract(probe_node)
	probe_node.material = null
	probe_node.visible = false
	if probe.is_empty():
		return
	probe_node.polygon = _rect_polygon(probe.get("rect_relative_screen", Rect2()) as Rect2)
	probe_node.color = probe.get("color", Color.TRANSPARENT) as Color
	probe_node.visible = true


func _reject(reason: String) -> bool:
	_last_sync_rejection_reason = reason
	set_active(false)
	return false


func _compile_reject(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _glow_modulate(color: Color, strength: float, alpha_factor: float) -> Color:
	return Color(
		color.r,
		color.g,
		color.b,
		clampf(color.a * maxf(0.0, strength) * alpha_factor, 0.0, 4.0)
	)


func _compile_vector2_array(value: Variant) -> Dictionary:
	var result := PackedVector2Array()
	if value is PackedVector2Array:
		for point in value as PackedVector2Array:
			if not point.is_finite():
				return _compile_reject("nonfinite_vector2")
			result.append(point)
	elif value is Array:
		for point_value in value as Array:
			if not (point_value is Vector2) or not (point_value as Vector2).is_finite():
				return _compile_reject("invalid_vector2")
			result.append(point_value as Vector2)
	else:
		return _compile_reject("invalid_vector2_array_type")
	return {"valid": true, "points": result}


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


func _is_nonnegative_finite_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0


func _is_finite_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)


func _is_finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _restore_canvas_layer_contract(layer: CanvasItem) -> void:
	layer.z_index = 0
	layer.z_as_relative = true
	layer.top_level = false
	layer.use_parent_material = false
	layer.self_modulate = Color.WHITE
	layer.show_behind_parent = false


func _restore_shared_material_contract() -> void:
	_mix_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
