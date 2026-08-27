extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const TowerAscentTransitionFadeState := preload(
	"res://scripts/tower_ascent/tower_ascent_transition_fade_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)


class RecordingFullscreenMapCanvas:
	extends Node2D

	var drawn_strings: Array[String] = []

	@warning_ignore("native_method_override")
	func draw_rect(
		_rect: Rect2,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_circle(
		_position: Vector2,
		_radius: float,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_line(
		_from: Vector2,
		_to: Vector2,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_dashed_line(
		_from: Vector2,
		_to: Vector2,
		_color: Color,
		_width: float = -1.0,
		_dash: float = 2.0,
		_aligned: bool = true,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_multiline(
		_points: PackedVector2Array,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_polyline(
		_points: PackedVector2Array,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_texture(
		_texture: Texture2D,
		_position: Vector2,
		_modulate: Color = Color.WHITE
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_texture_rect(
		_texture: Texture2D,
		_rect: Rect2,
		_tile: bool,
		_modulate: Color = Color.WHITE,
		_transpose: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_texture_rect_region(
		_texture: Texture2D,
		_rect: Rect2,
		_src_rect: Rect2,
		_modulate: Color = Color.WHITE,
		_transpose: bool = false,
		_clip_uv: bool = true
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_polygon(
		_points: PackedVector2Array,
		_colors: PackedColorArray,
		_uvs: PackedVector2Array = PackedVector2Array(),
		_texture: Texture2D = null
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_colored_polygon(
		_points: PackedVector2Array,
		_color: Color,
		_uvs: PackedVector2Array = PackedVector2Array(),
		_texture: Texture2D = null
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_arc(
		_center: Vector2,
		_radius: float,
		_start_angle: float,
		_end_angle: float,
		_point_count: int,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_set_transform(
		_position: Vector2 = Vector2.ZERO,
		_rotation: float = 0.0,
		_scale: Vector2 = Vector2.ONE
	) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_set_transform_matrix(_xform: Transform2D) -> void:
		pass

	@warning_ignore("native_method_override")
	func draw_string(
		_font: Font,
		_pos: Vector2,
		_text: String,
		_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		_width: float = -1.0,
		_font_size: int = 16,
		_modulate: Color = Color.WHITE,
		_justification_flags: int = 3,
		_direction: TextServer.Direction = TextServer.DIRECTION_AUTO,
		_orientation: TextServer.Orientation = TextServer.ORIENTATION_HORIZONTAL,
		_oversampling: float = 0.0
	) -> void:
		drawn_strings.append(_text)


class FakeFullscreenMapFlow:
	extends RefCounted

	func get_header_subtitle() -> String:
		return "fixture header"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_graph_state_model_survives_camera_crop()
	_verify_fullscreen_projection_and_existing_art_slots()
	_verify_fullscreen_legend_absent_and_node_catalog_preserved()
	_verify_live_resolution_map_uses_tracked_zoom()
	_verify_tracked_camera_boundaries()
	_verify_seeded_curve_geometry_preserves_connections()
	_verify_map_cache_and_six_beat_transition_contract()
	_verify_zooming_scroll_background_stays_on_pixel_grid()
	_verify_live_viewport_owns_fullscreen_rect()
	_verify_localization_catalog()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("tower_ascent_map_overlay_render_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_graph_state_model_survives_camera_crop() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-render",
		"map_seed": 83521,
	}), "map-overlay render fixture must begin")
	var nodes := flow.get_graph_nodes()
	var serialized_node_count := 0
	for floor_variant in flow.get_graph_floors():
		if not (floor_variant is Dictionary):
			continue
		for row_variant in (floor_variant as Dictionary).get("rows", []):
			if row_variant is Dictionary:
				serialized_node_count += ((row_variant as Dictionary).get("node_ids", []) as Array).size()
	var skipped_slot_id := ""
	for node in nodes:
		if str(node.get("boss_slot_id", "")).is_empty():
			continue
		if str(node.get("id", "")) != flow.get_current_node_id():
			skipped_slot_id = str(node.get("boss_slot_id", ""))
			break
	if not skipped_slot_id.is_empty():
		flow.call("_mark_boss_slot_skipped_in_graph", skipped_slot_id)
	flow.handle_input(_key_event(KEY_M))
	_expect(flow.get_phase_name() == "MAP_OVERLAY", "M must project the dedicated map-overlay phase")
	nodes = flow.get_graph_nodes()
	_expect(nodes.size() == serialized_node_count and nodes.size() > 25, "the camera map must retain every widened generated node")
	var visible_kinds: Dictionary = {}
	var has_current := false
	var has_completed := false
	var has_vanished := false
	for node in nodes:
		var kind_label := TowerAscentMapOverlayLocalization.node_kind_label(
			str(node.get("kind", "")),
			bool(node.get("enraged", false))
		)
		visible_kinds[kind_label] = true
		has_current = has_current or str(node.get("id", "")) == flow.get_current_node_id()
		has_completed = has_completed or bool(node.get("completed", false))
		has_vanished = has_vanished or bool(node.get("skipped", false))
	for required_label in ["전투", "광폭화", "상점", "수련장", "파계승", "수호의 샘터", "휴식"]:
		_expect(visible_kinds.has(required_label), "the graph model must retain node kind: %s" % required_label)
	_expect(has_current, "the overlay graph must contain the current player node")
	_expect(has_completed, "the overlay graph must distinguish a completed node")
	_expect(has_vanished, "the overlay graph must preserve a vanished skipped boss marker")
	var locked_hints: Array = flow.get_locked_phase_hints()
	_expect(locked_hints.size() == 1, "the human-realm overlay must preserve the locked phase-2 hint")
	if not locked_hints.is_empty():
		_expect(int((locked_hints[0] as Dictionary).get("floor_start", 0)) == 10 and int((locked_hints[0] as Dictionary).get("floor_end", 0)) == 12, "the locked hint must identify floors 10 through 12 without disclosing their nodes")


func _verify_fullscreen_legend_absent_and_node_catalog_preserved() -> void:
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(
		not renderer_source.contains("KEY_LEGEND_TYPES"),
		"the fullscreen renderer must not retain a hidden node-type legend draw"
	)
	var model_signature_regex := RegEx.new()
	var node_signature_regex := RegEx.new()
	var model_regex_error := model_signature_regex.compile(
		"func\\s+_draw_fullscreen_map_model\\s*\\(\\s*canvas\\s*:\\s*CanvasItem\\s*,"
	)
	var node_regex_error := node_signature_regex.compile(
		"func\\s+_draw_fullscreen_map_node\\s*\\(\\s*canvas\\s*:\\s*CanvasItem\\s*,"
	)
	_expect(model_regex_error == OK, "the fullscreen-map signature regex must compile")
	_expect(node_regex_error == OK, "the fullscreen-map node signature regex must compile")
	if model_regex_error != OK or node_regex_error != OK:
		return
	var model_signature_count := model_signature_regex.search_all(renderer_source).size()
	var node_signature_count := node_signature_regex.search_all(renderer_source).size()
	_expect(
		model_signature_count == 1,
		"the production fullscreen-map draw must retain its CanvasItem signature"
	)
	_expect(
		node_signature_count == 1,
		"the production fullscreen-map node draw must retain its CanvasItem signature"
	)
	if model_signature_count != 1 or node_signature_count != 1:
		return
	# CanvasItem's native draw calls cannot be intercepted by a scripted subclass
	# through a statically typed parameter. Compile the exact production body with
	# only the two recording boundaries widened so the parent and node labels are
	# recorded without weakening either production signature.
	var recording_source := model_signature_regex.sub(
		renderer_source,
		"func _draw_fullscreen_map_model(\n\tcanvas: Object,"
	)
	recording_source = node_signature_regex.sub(
		recording_source,
		"func _draw_fullscreen_map_node(\n\tcanvas: Object,"
	)
	var recording_fixture_script := GDScript.new()
	recording_fixture_script.source_code = recording_source
	var fixture_reload_error := recording_fixture_script.reload()
	_expect(
		fixture_reload_error == OK,
		"the recording fixture must compile from the production renderer body"
	)
	var canvas := RecordingFullscreenMapCanvas.new()
	if fixture_reload_error != OK:
		canvas.free()
		return
	var renderer: Object = recording_fixture_script.new()
	var panel_rect := Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
	var fallback_label := TowerAscentMapOverlayLocalization.node_kind_label("combat")
	var fallback_state_label := TowerAscentMapOverlayLocalization.node_state_label(
		false,
		true,
		false,
		false
	)
	renderer.call(
		"_draw_fullscreen_map_model",
		canvas,
		FakeFullscreenMapFlow.new(),
		{
			"viewport_rect": panel_rect,
			"panel_rect": panel_rect,
			"content_rect": panel_rect,
			"camera_view_rect": panel_rect,
			"world_rect": panel_rect,
			"realm_kind": "human_realm",
			"scroll_background": {"ready": true},
			"floor_bands": [],
			"edges": [],
			"nodes": [
				{
					"id": "fallback-combat-node",
					"kind": "combat",
					"boss_slot_id": "",
					"label": fallback_label,
					"completed": true,
					"world_position": panel_rect.get_center(),
					"world_art_rect": Rect2(
						panel_rect.get_center() - Vector2(20.0, 20.0),
						Vector2(40.0, 40.0)
					),
				},
			],
			"transition_marker": {},
			"cloud_layer": {},
			"floor_reveal_visual": {},
			"run_intro_title_visual": {},
			"locked_phase_hints": [],
		},
		{}
	)
	var legend_draw_count := 0
	for drawn_text in canvas.drawn_strings:
		if drawn_text.begins_with("전투 · 광폭화"):
			legend_draw_count += 1
	_expect(
		legend_draw_count == 0,
		"the fullscreen map must draw no node-type legend string"
	)
	_expect(
		canvas.drawn_strings.has("fixture header"),
		"the absence seal must traverse the full model body's direct header draw"
	)
	_expect(
		canvas.drawn_strings.has(fallback_label),
		"an iconless combat node must retain its fallback kind label"
	)
	_expect(
		canvas.drawn_strings.has(fallback_state_label),
		"an iconless combat node must retain its state label"
	)
	canvas.free()


func _verify_localization_catalog() -> void:
	var required_keys := [
		TowerAscentMapOverlayLocalization.KEY_TITLE,
		TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT,
		TowerAscentMapOverlayLocalization.KEY_REALM_HUMAN,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL_LOCKED,
		TowerAscentMapOverlayLocalization.KEY_ENTER_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_NODE_GUARDIAN_SPRING,
		TowerAscentMapOverlayLocalization.KEY_STATE_CURRENT,
		TowerAscentMapOverlayLocalization.KEY_STATE_COMPLETED,
		TowerAscentMapOverlayLocalization.KEY_STATE_UNVISITED,
		TowerAscentMapOverlayLocalization.KEY_STATE_VANISHED,
		TowerAscentMapOverlayLocalization.KEY_STATE_LOCKED,
	]
	var registered := TowerAscentMapOverlayLocalization.get_registered_keys()
	for key in required_keys:
		_expect(registered.has(key), "map-overlay localization must register %s" % key)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "the Korean overlay title must be exactly 지도")
	for text_value in TowerAscentMapOverlayLocalization.TEXT_BY_LOCALE.get(
		LanguageSettings.LANGUAGE_KOREAN,
		{}
	).values():
		_expect(not str(text_value).contains("—"), "new Korean map copy must not contain an em dash")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "missing translations must fall back to Korean map copy")
	_expect(TowerAscentMapOverlayLocalization.get_missing_translation_locales().has(LanguageSettings.LANGUAGE_ENGLISH), "the map catalog must report untranslated supported locales")
	LanguageSettings.set_test_locale_override("")


func _verify_fullscreen_projection_and_existing_art_slots() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-fullscreen",
		"map_seed": 83521,
	}), "fullscreen map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	_expect(model.get("viewport_rect", Rect2()) == viewport_rect, "fullscreen model must preserve the full screen rect")
	_expect(
		(model.get("nodes", []) as Array).size()
			== (model.get("overview_nodes", []) as Array).size(),
		"the default fullscreen map must project every full-tower overview node"
	)
	_expect((model.get("floor_bands", []) as Array).size() == 12, "the default overview must expose one visible tier for floors 1 through 12")
	_expect(str(model.get("realm_kind", "")) == "human_realm", "phase-1 fullscreen projection must own the human-realm treatment")
	_expect((model.get("locked_phase_hints", []) as Array).size() == 1, "phase-1 fullscreen projection must carry the 10 through 12 lock hint")
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var world_rect: Rect2 = model.get("world_rect", Rect2())
	var min_node_y := INF
	var max_node_y := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var world_position: Vector2 = node.get("world_position", Vector2.ZERO)
		var art_rect: Rect2 = node.get("world_art_rect", Rect2())
		var art_path := str(node.get("art_path", ""))
		_expect(world_rect.grow(0.1).has_point(world_position), "every node center must remain inside the tracked map world")
		_expect(art_rect.size.x >= 18.0 and art_rect.size.y >= 18.0, "every node must own a readable art slot")
		_expect(not art_path.is_empty() and FileAccess.file_exists(art_path), "every node art slot must reuse an existing asset: %s" % art_path)
		min_node_y = minf(min_node_y, world_position.y)
		max_node_y = maxf(max_node_y, world_position.y)
	_expect(min_node_y < world_rect.get_center().y and max_node_y > world_rect.get_center().y, "the castle route world must ascend from bottom to top")
	_expect(world_rect.size.y >= content_rect.size.y * 2.0, "v1.13 must replace full disclosure with at least a 2x tall camera world")
	for art_path in renderer.get_node_art_asset_paths():
		_expect(FileAccess.file_exists(art_path), "the node-art catalog must never reserve a missing draw path: %s" % art_path)


func _verify_live_resolution_map_uses_tracked_zoom() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-live-resolution",
		"map_seed": 83521,
	}), "live-resolution map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var reference_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	)
	var live_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var art_scale := float(live_model.get("art_size", 0.0)) / maxf(
		1.0,
		float(reference_model.get("art_size", 0.0))
	)
	var reference_lane_span := _world_node_x_span(reference_model)
	var live_lane_span := _world_node_x_span(live_model)
	var lane_scale := live_lane_span / maxf(1.0, reference_lane_span)
	var reference_map_scale := float(reference_model.get("map_scale", 0.0))
	var live_map_scale := float(live_model.get("map_scale", 0.0))
	var viewport_scale_ratio := live_map_scale / maxf(0.001, reference_map_scale)
	_expect(is_equal_approx(float(live_model.get("art_size", 0.0)), 32.0 * live_map_scale), "M-key medal nodes must follow the live content scale")
	_expect(live_lane_span > 0.0 and live_lane_span <= float((live_model.get("world_rect", Rect2()) as Rect2).size.x), "node lanes must stay inside the scaled scroll world")
	_expect(is_equal_approx(art_scale, viewport_scale_ratio), "asset-world node size must scale with the M-key content width")
	_expect(is_equal_approx(lane_scale, viewport_scale_ratio), "asset-world lane spacing must use the same uniform M-key scale")
	var live_content: Rect2 = live_model.get("content_rect", Rect2())
	var live_world: Rect2 = live_model.get("world_rect", Rect2())
	var live_camera_view: Rect2 = live_model.get("camera_view_rect", Rect2())
	var live_camera: Dictionary = live_model.get("camera", {})
	var live_zoom := float(live_camera.get("render_zoom_multiplier", 0.0))
	var visible_world: Rect2 = (live_model.get("camera", {}) as Dictionary).get(
		"visible_world_rect",
		Rect2()
	)
	var expected_default_zoom := clampf(
		float(live_model.get("minimum_cover_zoom", 0.0))
			/ TowerAscentTuning.TEMP_MAP_DEFAULT_ZOOMOUT_DIVISOR,
		float(live_model.get("minimum_fit_all_zoom", 0.0)),
		float(live_model.get("minimum_cover_zoom", 0.0))
	)
	_expect(is_equal_approx(live_zoom, expected_default_zoom), "the tracked map default must equal four wheel-down notches from cover")
	_expect(bool(live_model.get("subcover_active", false)), "the default overview must enable its scroll surround")
	_expect(live_world.size.y >= live_content.size.y * 2.0, "the map world must be cropped vertically instead of fitted into one screen")
	_expect(is_equal_approx(visible_world.size.y, live_camera_view.size.y / live_zoom), "the camera window must be the full live viewport divided by effective zoom")
	var visible_node_count := 0
	for node_variant in live_model.get("nodes", []):
		if node_variant is Dictionary:
			if visible_world.has_point((node_variant as Dictionary).get("world_position", Vector2.ZERO)):
				visible_node_count += 1
	_expect(visible_node_count > 0 and visible_node_count < (live_model.get("nodes", []) as Array).size(), "v1.13 camera must reveal only a cropped subset of the graph")
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(
		int(cache_state.get("total_map_draw_call_budget", 0))
			<= TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
		"GRT-043: default overview routes plus 12-floor clouds must stay inside the cached draw budget"
	)
	print(
		"tower_ascent_map_overlay_render_smoke: default_overview nodes=%d edges=%d path_draw_calls=%d cloud_draw_calls=%d total_draw_calls=%d" % [
			(live_model.get("nodes", []) as Array).size(),
			(live_model.get("edges", []) as Array).size(),
			int(cache_state.get("path_draw_call_budget", 0)),
			int(cache_state.get("cloud_draw_call_budget", 0)),
			int(cache_state.get("total_map_draw_call_budget", 0)),
		]
	)


func _world_node_x_span(model: Dictionary) -> float:
	var min_x := INF
	var max_x := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var position: Vector2 = (node_variant as Dictionary).get("world_position", Vector2.ZERO)
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
	return 0.0 if not is_finite(min_x) or not is_finite(max_x) else max_x - min_x


func _verify_tracked_camera_boundaries() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-camera-boundaries",
		"map_seed": 83521,
	}), "camera-boundary fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	var lower_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var lower_camera: Dictionary = lower_model.get("camera", {})
	var lower_content: Rect2 = lower_model.get("camera_view_rect", Rect2())
	var lower_world: Rect2 = lower_model.get("camera_world_rect", Rect2())
	var lower_zoom := float(lower_camera.get("render_zoom_multiplier", 1.0))
	var lower_offset := float((lower_camera.get("offset", Vector2.ZERO) as Vector2).y)
	_expect(bool(lower_camera.get("at_lower_boundary", false)), "floor 1 must clamp at the lower camera boundary")
	_expect(is_equal_approx(lower_world.end.y * lower_zoom + lower_offset, lower_content.end.y), "the lower clamp must expose no empty space below the map world")
	var middle_node_id := ""
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == 5:
			middle_node_id = str((node_variant as Dictionary).get("id", ""))
			break
	flow.set("_current_node_id", middle_node_id)
	var middle_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var middle_camera: Dictionary = middle_model.get("camera", {})
	var middle_content: Rect2 = middle_model.get("camera_view_rect", Rect2())
	var middle_focus: Vector2 = middle_camera.get("focus_screen_position", Vector2.ZERO)
	_expect(not bool(middle_camera.get("at_lower_boundary", true)) and not bool(middle_camera.get("at_upper_boundary", true)), "a middle floor must use free camera tracking")
	_expect(absf(middle_focus.y - middle_content.get_center().y) <= 0.1, "a middle-floor character must stay vertically centered")

	var top_floor := -1
	for node_variant in flow.get_graph_nodes():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("floor", 0))
		top_floor = maxi(top_floor, floor_number)
	var top_node_id := _topmost_node_id_for_floor(flow, top_floor)
	flow.set("_current_node_id", top_node_id)
	var upper_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var upper_camera: Dictionary = upper_model.get("camera", {})
	var upper_content: Rect2 = upper_model.get("camera_view_rect", Rect2())
	var upper_world: Rect2 = upper_model.get("camera_world_rect", Rect2())
	var upper_zoom := float(upper_camera.get("render_zoom_multiplier", 1.0))
	var upper_offset := float((upper_camera.get("offset", Vector2.ZERO) as Vector2).y)
	_expect(not bool(upper_camera.get("at_upper_boundary", true)), "active floor 9 must not impersonate the full-tower upper boundary while floors 10 through 12 are visible")
	_expect(upper_world.position.y * upper_zoom + upper_offset < upper_content.position.y, "the default overview must retain scroll world above active floor 9")


func _verify_seeded_curve_geometry_preserves_connections() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-seeded-curves",
		"map_seed": 83521,
	}), "seeded-curve fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var source_connections := TowerAscentMapPathGeometry.connection_signature(
		flow.get_graph_edges()
	)
	var projected_connections := TowerAscentMapPathGeometry.connection_signature(
		model.get("edges", [])
	)
	_expect(source_connections == projected_connections, "curve projection must preserve every generated from/to connection in order")
	var first_signature := TowerAscentMapPathGeometry.curve_signature(model.get("edges", []))
	var repeated_signature := TowerAscentMapPathGeometry.curve_signature(
		renderer.build_fullscreen_map_model(
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		).get("edges", [])
	)
	_expect(not first_signature.is_empty() and first_signature == repeated_signature, "the same map seed and graph must reproduce byte-identical curve geometry")
	var rebuilt_with_other_seed := TowerAscentMapPathGeometry.build(
		model.get("edges", []),
		83522,
		float(model.get("art_size", 0.0)),
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MIN_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MAX_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_SKEW_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_ENDPOINT_CLEARANCE_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MIN,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MAX
	)
	_expect(first_signature != TowerAscentMapPathGeometry.curve_signature(rebuilt_with_other_seed), "a different map seed must produce a different presentation curve")
	for edge_variant in model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_position: Vector2 = edge.get("from_position", Vector2.ZERO)
		var to_position: Vector2 = edge.get("to_position", Vector2.ZERO)
		var path_start: Vector2 = edge.get("path_start", from_position)
		var path_end: Vector2 = edge.get("path_end", to_position)
		var medal_radius := float(model.get("art_size", 0.0)) * 0.5
		var minimum_hidden_clearance := medal_radius * 0.75
		var start_clearance := path_start.distance_to(from_position)
		var end_clearance := path_end.distance_to(to_position)
		_expect(start_clearance >= minimum_hidden_clearance and start_clearance <= medal_radius, "curves must terminate beneath the source medal rim")
		_expect(end_clearance >= minimum_hidden_clearance and end_clearance <= medal_radius, "curves must terminate beneath the destination medal rim")


func _verify_map_cache_and_six_beat_transition_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-cache-and-transition",
		"map_seed": 83521,
	}), "cache and transition fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("graph_build_count", 0)) == 1, "unchanged graph draws must reuse one cached graph model")
	_expect(int(cache_state.get("fullscreen_build_count", 0)) == 1, "unchanged viewport draws must reuse one cached fullscreen projection")
	_expect(int(cache_state.get("path_build_count", 0)) == 1, "unchanged map draws must not rebuild dotted path geometry per frame")
	_expect(int(cache_state.get("path_dot_count", 0)) > 0, "the cached route must contain polygon dots")
	_expect(int(cache_state.get("path_draw_call_budget", 0)) == int(cache_state.get("path_dot_count", 0)) * 2, "the dotted path draw-call budget must stay explicit")
	print(
		"tower_ascent_map_overlay_render_smoke: dotted_path_budget edges=%d dots=%d draw_calls=%d" % [
			(_model_edge_count(renderer, flow, viewport_rect)),
			int(cache_state.get("path_dot_count", 0)),
			int(cache_state.get("path_draw_call_budget", 0)),
		]
	)

	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "transition fixture must expose a route target")
	if not target_ids.is_empty():
		var source_id := flow.get_current_node_id()
		var target_id := target_ids[0]
		flow.call("_resolve_route_target", target_id)
		_expect(flow.get_current_node_id() == source_id, "route selection must not promote the destination before arrival")
		renderer.build_fullscreen_map_model(flow, viewport_rect)
		var transition_cache_builds := int(
			renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)
		)
		flow.set_transition_progress_for_qa(0.5)
		var moving_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
		var moving_marker: Dictionary = moving_model.get("transition_marker", {})
		var moving_camera: Dictionary = moving_model.get("camera", {})
		_expect(float(moving_marker.get("progress", 0.0)) > 0.0 and float(moving_marker.get("progress", 0.0)) < 1.0, "mid-transition marker must use the eased travel window")
		_expect((moving_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(moving_camera.get("focus_world_position", Vector2.ONE)), "the tracked camera must consume the walker's curve position from the same physics-clock progress")
		_expect((moving_model.get("camera_view_rect", Rect2()) as Rect2).grow(-1.0).has_point(moving_camera.get("focus_screen_position", Vector2.ZERO)), "the tracked transition walker must remain inside the visible map crop")
		var straight_midpoint := (moving_marker.get("from_position", Vector2.ZERO) as Vector2).lerp(
			moving_marker.get("to_position", Vector2.ZERO),
			float(moving_marker.get("progress", 0.0))
		)
		_expect((moving_marker.get("world_position", Vector2.ZERO) as Vector2).distance_to(straight_midpoint) > 1.0, "the transition walker must follow the cached curve instead of cutting across it")
		_expect(int(renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)) == transition_cache_builds, "transition progress must not rebuild the cached graph projection")
		flow.call("_complete_map_transition")
		_expect(flow.get_current_node_id() == target_id, "the destination must become current only when the map transition completes")

	var timeline := TowerAscentTransitionFadeState.new()
	timeline.begin_map_transition()
	var expected_total := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	_expect(is_equal_approx(timeline.get_map_transition_duration_sec(), expected_total), "map transition duration must be the six visual beats in the tuning table")
	timeline.set_map_transition_progress_for_qa(0.0)
	var start_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(start_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_BATTLE_FADE_OUT, "progress 0 must keep the battle visible for its fade-out")
	_expect(not bool(start_model.get("map_visible", true)) and is_zero_approx(float(start_model.get("blackout_alpha", -1.0))), "battle fade must start with no map and no blackout")
	var zoom_mid_elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC * 0.5
	)
	timeline.set_map_transition_progress_for_qa(zoom_mid_elapsed / expected_total)
	var zoom_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(zoom_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_CAMERA_ZOOM_IN, "the inserted 2-b window must sit between map reveal and travel")
	_expect(is_zero_approx(float(zoom_model.get("travel_progress", -1.0))), "the walker must stay at the source throughout the camera intro window")
	_expect(is_zero_approx(float(zoom_model.get("camera_zoom_progress", -1.0))), "the intro multiplier must run before travel begins restoring the preferred base")
	var zoom_mid_multiplier := float(zoom_model.get("camera_zoom_multiplier", 0.0))
	_expect(is_equal_approx(zoom_mid_multiplier, lerpf(TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER, TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER, 0.5)), "the intro midpoint must use the symmetric smoothstep midpoint")
	var zoom_quarter_elapsed := zoom_mid_elapsed - TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC * 0.25
	timeline.set_map_transition_progress_for_qa(zoom_quarter_elapsed / expected_total)
	var zoom_quarter_multiplier := float(timeline.get_map_transition_visual_model().get("camera_zoom_multiplier", 0.0))
	var linear_quarter := lerpf(TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER, TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER, 0.25)
	_expect(zoom_quarter_multiplier < linear_quarter, "camera intro must accelerate from rest instead of using a linear zoom")
	var zoom_three_quarter_elapsed := zoom_mid_elapsed + TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC * 0.25
	timeline.set_map_transition_progress_for_qa(zoom_three_quarter_elapsed / expected_total)
	var zoom_three_quarter_multiplier := float(timeline.get_map_transition_visual_model().get("camera_zoom_multiplier", 0.0))
	var linear_three_quarter := lerpf(TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER, TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER, 0.75)
	_expect(zoom_three_quarter_multiplier > linear_three_quarter, "camera intro must decelerate into the final crop")
	timeline.set_map_transition_progress_for_qa(0.5)
	var middle_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(middle_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_TRAVEL, "progress 0.5 must land in the travel beat")
	_expect(bool(middle_model.get("map_visible", false)) and float(middle_model.get("travel_progress", 0.0)) > 0.0, "travel beat must show the fullscreen map and eased walker")
	_expect(
		is_equal_approx(
			float(middle_model.get("camera_zoom_progress", -1.0)),
			float(middle_model.get("travel_progress", -2.0))
		),
		"travel progress must own the continuing base-camera zoom"
	)
	timeline.set_map_transition_progress_for_qa(1.0)
	var end_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(end_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_MAP_FADE_OUT, "progress 1 must end on the map blackout beat")
	_expect(is_equal_approx(float(end_model.get("blackout_alpha", 0.0)), 1.0) and is_zero_approx(float(end_model.get("marker_alpha", 1.0))), "arrival must vanish before the fully black handoff")
	_expect(is_equal_approx(float(end_model.get("camera_zoom_progress", 0.0)), 1.0), "arrival and fade-out must retain the completed preferred camera base")
	timeline.begin_node_modal_fade()
	_expect(is_zero_approx(timeline.get_node_modal_fade_progress()), "noncombat arrival surface must begin fully covered")
	timeline.update_node_modal_fade(TowerAscentTuning.TEMP_NODE_MODAL_FADE_IN_SEC)
	_expect(is_equal_approx(timeline.get_node_modal_fade_progress(), 1.0), "noncombat node fade must complete on its tuning duration")


func _verify_zooming_scroll_background_stays_on_pixel_grid() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-pixel-grid",
		"map_seed": 83521,
	}), "pixel-grid fixture must begin")
	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "pixel-grid fixture must expose a route target")
	if target_ids.is_empty():
		return
	flow.call("_resolve_route_target", target_ids[0])
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	var travel_start_sec := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)
	var transition_duration_sec := (
		travel_start_sec
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	var previous_zoom := -INF
	for frame_index in range(10):
		var elapsed_sec := travel_start_sec + float(24 + frame_index) / 72.0
		flow.set_transition_progress_for_qa(elapsed_sec / transition_duration_sec)
		var model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
		var camera: Dictionary = model.get("camera", {})
		var zoom := float(camera.get("render_zoom_multiplier", 0.0))
		_expect(zoom > previous_zoom, "pixel-grid fixture zoom must advance every frame")
		previous_zoom = zoom
		var sample_count := 0
		var scroll: Dictionary = model.get("scroll_background", {})
		for chunk_variant in scroll.get("draw_chunks", scroll.get("tiles", [])):
			if not (chunk_variant is Dictionary):
				continue
			var chunk := chunk_variant as Dictionary
			var texture := chunk.get("paper_texture", null) as Texture2D
			var world_target: Rect2 = chunk.get("paper_rect", chunk.get("rect", Rect2()))
			if texture == null or not world_target.has_area():
				continue
			var offset: Vector2 = camera.get("offset", Vector2.ZERO)
			var projected := Rect2(
				world_target.position * zoom + offset,
				world_target.size * zoom
			)
			var visible := projected.intersection(viewport_rect)
			if not visible.has_area():
				continue
			var normalized_source: Rect2 = chunk.get(
				"paper_source_rect",
				Rect2(0.0, 0.0, 1.0, 1.0)
			)
			var texture_size := texture.get_size()
			var relative_position := (visible.position - projected.position) / projected.size
			var relative_size := visible.size / projected.size
			var source_rect := Rect2(
				texture_size * (
					normalized_source.position
						+ normalized_source.size * relative_position
				),
				texture_size * normalized_source.size * relative_size
			)
			var snapped_target: Rect2 = renderer.snap_scroll_background_rect(visible)
			var snapped_source: Rect2 = renderer.snap_scroll_background_rect(source_rect)
			_expect(
				_rect_has_integer_edges(snapped_target),
				"frame %d background target rect must stay on integer pixel edges"
				% frame_index
			)
			_expect(
				_rect_has_integer_edges(snapped_source),
				"frame %d background source rect must stay on integer texel edges"
				% frame_index
			)
			sample_count += 1
		_expect(sample_count > 0, "pixel-grid fixture must sample a visible scroll background")


func _rect_has_integer_edges(rect: Rect2) -> bool:
	return (
		is_equal_approx(rect.position.x, roundf(rect.position.x))
		and is_equal_approx(rect.position.y, roundf(rect.position.y))
		and is_equal_approx(rect.end.x, roundf(rect.end.x))
		and is_equal_approx(rect.end.y, roundf(rect.end.y))
	)


func _topmost_node_id_for_floor(flow: Object, floor_number: int) -> String:
	var result := ""
	var topmost_y := INF
	for node_variant in flow.get_graph_nodes():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if int(node.get("floor", 0)) != floor_number:
			continue
		var source_position: Variant = node.get("position", Vector2.ZERO)
		var source_y := (
			float(source_position.y)
			if source_position is Vector2
			else float(source_position[1])
			if source_position is Array and source_position.size() >= 2
			else 0.0
		)
		if source_y < topmost_y:
			topmost_y = source_y
			result = str(node.get("id", ""))
	return result


func _model_edge_count(
	renderer: Object,
	flow: Object,
	viewport_rect: Rect2
) -> int:
	return (renderer.build_fullscreen_map_model(flow, viewport_rect).get("edges", []) as Array).size()


func _verify_live_viewport_owns_fullscreen_rect() -> void:
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var fallback := Rect2(Vector2.ZERO, Vector2(73.0, 91.0))
	_expect(canvas.is_inside_tree(), "the viewport-sizing fixture must enter the scene tree")
	var resolved: Rect2 = renderer.resolve_fullscreen_rect(canvas, fallback)
	var live_rect := canvas.get_viewport_rect() if canvas.is_inside_tree() else Rect2()
	_expect(resolved == live_rect, "an in-tree map canvas must use the live viewport as the primary fullscreen size")
	_expect(resolved != fallback, "live viewport sizing must not collapse to a stale playfield/context fallback")
	get_root().remove_child(canvas)
	canvas.free()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
