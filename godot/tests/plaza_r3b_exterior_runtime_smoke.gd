extends SceneTree

# R3-B production-disconnected exterior-runtime seal. It consumes the real
# R3-A layout/environment plan and real actor textures, then proves bind-once
# compiled navigation, shared Y-sort ownership, two-axis camera/minimap, portal
# interaction, mutation isolation, and steady owner-cadence performance. The
# GRT-040 completion gate prevents an aborted verification leg from printing ok.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMapNavigationCompiled := preload("res://scripts/plaza/plaza_map_navigation_compiled.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")
const PlazaR3ExteriorRuntimeCandidate := preload("res://scripts/plaza/plaza_r3_exterior_runtime_candidate.gd")
const PlazaR3NavigationBinding := preload("res://scripts/plaza/plaza_r3_navigation_binding.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const VIEW_SIZE := Vector2(2020.0, 1246.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)
const SAFE_INSETS := {
	"left": 72.0,
	"top": 72.0,
	"right": 360.0,
	"bottom": 120.0,
}
const MINIMAP_RECT := Rect2(1690.0, 80.0, 250.0, 174.0)
const CAMERA_ZOOM := 1.35
const GUARDIAN_ID := "onimaru"
const EXPECTED_COMPLETED_LEGS := 4
const MIN_ASSERTIONS_BY_LEG := {
	"real_retained_tree": 14,
	"two_axis_runtime": 20,
	"portal_and_fail_closed": 12,
	"owner_cadence_and_isolation": 14,
}

var _failures: Array[String] = []
var _assertion_count := 0
var _legs_completed := 0
var _leg_assertion_counts := {}
var _visual_config: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_visual_config = _build_visual_config()
	_expect(bool(_visual_config.get("valid", false)), "real player and guardian textures must load")
	if bool(_visual_config.get("valid", false)):
		_verify_real_retained_tree()
		_verify_two_axis_runtime()
		_verify_portal_and_fail_closed()
		await _verify_owner_cadence_and_isolation()
	_finish()


func _verify_real_retained_tree() -> void:
	var assertion_start := _assertion_count
	var fixture := _build_fixture(4)
	_expect(bool(fixture.get("valid", false)), "seed 4 R3 fixture must compile")
	if not bool(fixture.get("valid", false)):
		_complete_leg("real_retained_tree", assertion_start)
		return
	var hub_center := _hub_center(fixture.get("layout", {}) as Dictionary)
	var runtime := _new_runtime()
	var bound: bool = runtime.bind_candidate(_build_config(fixture, hub_center, hub_center + Vector2(-96.0, 0.0)))
	_expect(bound, "real seed 4 runtime must bind: %s" % str(runtime.get_debug_status().get("rejection_reason", "")))
	if not bound:
		runtime.free()
		_complete_leg("real_retained_tree", assertion_start)
		return
	var status: Dictionary = runtime.get_debug_status()
	_expect(bool(status.get("bound", false)) and bool(status.get("active", false)), "bound runtime must be active")
	_expect(bool(status.get("candidate_only", false)) and not bool(status.get("production_connected", true)), "R3-B must remain candidate-only")
	var host: Control = runtime.get_retained_host_for_test()
	var sort_status := host.call("get_sort_contract_status") as Dictionary
	_expect(bool(sort_status.get("valid", false)), "actual retained Y-sort contract must validate")
	_expect(int(sort_status.get("real_actor_texture_count", -1)) == 2, "player and guardian must both use real retained textures")
	_expect(int(sort_status.get("building_shadow_count", -1)) == 0, "building shadow default must remain none")
	var sort_root := host.call("get_sort_root_for_test") as Node2D
	var player_item := host.call("get_player_item_for_test") as Node2D
	var guardian_item := host.call("get_guardian_item_for_test") as Node2D
	_expect(sort_root != null and sort_root.y_sort_enabled, "one real Y-sort root must own the exterior")
	_expect(player_item != null and guardian_item != null, "both actor wrappers must exist")
	_expect(player_item != null and player_item.get_parent() == sort_root, "player must be a direct Y-sort sibling")
	_expect(guardian_item != null and guardian_item.get_parent() == sort_root, "guardian must be a direct Y-sort sibling")
	_expect(player_item != null and guardian_item != null and player_item.get_parent() == guardian_item.get_parent(), "player and guardian must share the exact parent")
	_expect(player_item != null and player_item.get_node("Sprite") is Sprite2D, "player wrapper must retain a Sprite2D")
	_expect(guardian_item != null and guardian_item.get_node("Sprite") is Sprite2D, "guardian wrapper must retain a Sprite2D")
	_expect(_count_named_descendants(host, "Shadow") == 0, "no legacy rectangular building Shadow node may survive")
	_expect(_count_named_descendants(host, "ContactShadow") == 2, "only player and guardian contact shadows must remain")
	_expect(int(sort_status.get("building_count", 0)) == (fixture.get("layout", {}) as Dictionary).get("building_specs", []).size(), "every R3 building must be retained")
	var player_sprite := player_item.get_node("Sprite") as Sprite2D
	var guardian_sprite := guardian_item.get_node("Sprite") as Sprite2D
	var building_item := host.call("get_building_item_for_test", "bank") as Node2D
	_expect(building_item != null, "fixture must expose a bank actual-tree mutation target")
	player_item.modulate = Color(1.0, 1.0, 1.0, 0.0)
	player_sprite.material = CanvasItemMaterial.new()
	player_sprite.use_parent_material = true
	player_sprite.visible = false
	guardian_sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	guardian_sprite.show_behind_parent = true
	if building_item != null:
		var base := building_item.get_node("Base") as Sprite2D
		base.material = null
		base.use_parent_material = true
	_expect(not bool((host.call("get_sort_contract_status") as Dictionary).get("valid", true)), "actual material/modulate/visibility drift must turn the live contract RED")
	var restore_tick: Dictionary = runtime.tick_candidate(Vector2.ZERO, 0.0, 1)
	_expect(bool(restore_tick.get("valid", false)), "one valid owner sync must restore mutations left in place")
	_expect(bool((host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "valid sync must restore the complete actual-tree contract")
	_expect(player_sprite.material == null and not player_sprite.use_parent_material and player_sprite.visible, "player sprite material and visibility must restore")
	_expect(guardian_sprite.self_modulate.is_equal_approx(Color.WHITE) and not guardian_sprite.show_behind_parent, "guardian sprite inherited presentation flags must restore")
	runtime.clear_transient_canvas_items()
	_expect(not bool(runtime.get_debug_status().get("active", true)) and not runtime.visible, "clear must hide the whole candidate runtime")
	runtime.free()
	_complete_leg("real_retained_tree", assertion_start)


func _verify_two_axis_runtime() -> void:
	var assertion_start := _assertion_count
	var fixture := _build_fixture(4)
	_expect(bool(fixture.get("valid", false)), "two-axis fixture must compile")
	if not bool(fixture.get("valid", false)):
		_complete_leg("two_axis_runtime", assertion_start)
		return
	var layout := fixture.get("layout", {}) as Dictionary
	var hub_center := _hub_center(layout)
	var runtime := _new_runtime()
	var bound: bool = runtime.bind_candidate(_build_config(fixture, hub_center, hub_center + Vector2(-96.0, 0.0)))
	_expect(bound, "two-axis runtime must bind at the walkable hub: %s" % str(runtime.get_debug_status().get("rejection_reason", "")))
	if not bound:
		runtime.free()
		_complete_leg("two_axis_runtime", assertion_start)
		return
	var before: Dictionary = runtime.get_debug_status()
	var before_minimap := ((before.get("minimap", {}) as Dictionary).get("snapshot", {}) as Dictionary)
	var before_player_marker := (before_minimap.get("player_marker", {}) as Dictionary).get("position", Vector2.INF) as Vector2
	var tick: Dictionary = runtime.tick_candidate(Vector2.DOWN, 1.0 / 60.0, 16)
	_expect(bool(tick.get("valid", false)), "Y-only production cadence tick must succeed")
	var applied := tick.get("player_applied_delta", Vector2.INF) as Vector2
	_expect(is_zero_approx(applied.x) and applied.y > 0.0, "Y-only input must preserve X and advance Y")
	_expect(bool(tick.get("player_moving", false)), "Y-only movement must select walking animation")
	_expect(int(tick.get("player_facing", 0)) == 1, "Y-only movement must preserve the last valid X facing")
	var after: Dictionary = runtime.get_debug_status()
	var projection := after.get("projection", {}) as Dictionary
	var camera_center := after.get("camera_center_world", Vector2.INF) as Vector2
	_expect(camera_center.y > (before.get("camera_center_world", Vector2.INF) as Vector2).y, "camera must track player Y")
	_expect(is_equal_approx(camera_center.x, (before.get("camera_center_world", Vector2.INF) as Vector2).x), "Y-only camera motion must not invent X drift")
	_expect(float(projection.get("zoom", 0.0)) > 1.0, "runtime camera must exercise zoomed 2D projection")
	var after_minimap := ((after.get("minimap", {}) as Dictionary).get("snapshot", {}) as Dictionary)
	var player_marker := after_minimap.get("player_marker", {}) as Dictionary
	var guardian_marker := after_minimap.get("guardian_marker", {}) as Dictionary
	var after_player_marker := player_marker.get("position", Vector2.INF) as Vector2
	_expect(is_equal_approx(after_player_marker.x, before_player_marker.x) and after_player_marker.y > before_player_marker.y, "minimap player marker must preserve X and track Y")
	_expect((player_marker.get("world_position", Vector2.INF) as Vector2).is_equal_approx(after.get("player_world_position", Vector2.ZERO) as Vector2), "minimap player world source must be exact")
	_expect((guardian_marker.get("world_position", Vector2.INF) as Vector2).is_equal_approx(after.get("guardian_world_position", Vector2.ZERO) as Vector2), "minimap guardian world source must be exact")
	_expect(not (after.get("guardian_world_position", Vector2.ZERO) as Vector2).is_equal_approx(before.get("guardian_world_position", Vector2.ZERO) as Vector2), "ground guardian must advance through compiled navigation on the real tick")
	var compiled: Object = runtime.get_compiled_navigation_for_test()
	_expect(compiled != null and bool(compiled.call("can_occupy", after.get("guardian_world_position", Vector2.ZERO), true)), "every intermediate ground guardian placement must remain full-body walkable")
	var expected_player_screen := PlazaMapProjection.world_to_screen(after.get("player_world_position", Vector2.ZERO) as Vector2, after_minimap.get("projection", {}) as Dictionary)
	_expect(after_player_marker.is_equal_approx(expected_player_screen), "minimap player position must use exact shared projection")
	var expected_camera_rect := PlazaMapProjection.world_rect_to_screen(projection.get("visible_world_rect", Rect2()) as Rect2, after_minimap.get("projection", {}) as Dictionary)
	_expect(_rect_equal_approx(after_minimap.get("camera_screen_rect", Rect2()) as Rect2, expected_camera_rect), "minimap camera rectangle must project both axes exactly")
	var markers := _dictionary_array(after_minimap.get("building_markers", []))
	_expect(markers.size() == _dictionary_array(layout.get("building_specs", [])).size(), "minimap must retain every authored building marker")
	var distinct_y := {}
	for marker in markers:
		var world := marker.get("world_position", Vector2.INF) as Vector2
		var screen := marker.get("position", Vector2.INF) as Vector2
		_expect(screen.is_equal_approx(PlazaMapProjection.world_to_screen(world, after_minimap.get("projection", {}) as Dictionary)), "building marker must use exact two-axis projection")
		distinct_y[snappedf(world.y, 0.01)] = true
	_expect(distinct_y.size() >= 2, "fixture buildings must occupy multiple authored Y rows")
	var exit_marker := after_minimap.get("exit_marker", {}) as Dictionary
	_expect((exit_marker.get("world_position", Vector2.INF) as Vector2).is_equal_approx(EXIT_ZONE.get_center()), "minimap exit must preserve authored world Y")
	_expect((exit_marker.get("position", Vector2.INF) as Vector2).is_equal_approx(PlazaMapProjection.world_to_screen(EXIT_ZONE.get_center(), after_minimap.get("projection", {}) as Dictionary)), "minimap exit must project both axes exactly")
	_expect(not _dictionary_array(after_minimap.get("walkable_hubs", [])).is_empty(), "minimap must expose the central walkable hub")
	_expect(not _dictionary_array(after_minimap.get("road_records", [])).is_empty(), "minimap must expose the actual R3 road graph")
	var tick_x: Dictionary = runtime.tick_candidate(Vector2.RIGHT, 1.0 / 60.0, 32)
	_expect(bool(tick_x.get("valid", false)), "X-axis production cadence tick must succeed")
	var after_x: Dictionary = runtime.get_debug_status()
	_expect((after_x.get("player_world_position", Vector2.ZERO) as Vector2).x > (after.get("player_world_position", Vector2.ZERO) as Vector2).x, "player must advance on the second world axis")
	_expect((after_x.get("camera_center_world", Vector2.ZERO) as Vector2).x > camera_center.x, "camera must track player X independently")
	var after_x_minimap := ((after_x.get("minimap", {}) as Dictionary).get("snapshot", {}) as Dictionary)
	_expect((((after_x_minimap.get("player_marker", {}) as Dictionary).get("position", Vector2.ZERO)) as Vector2).x > after_player_marker.x, "minimap marker must track X independently")
	runtime.free()
	_complete_leg("two_axis_runtime", assertion_start)


func _verify_portal_and_fail_closed() -> void:
	var assertion_start := _assertion_count
	var fixture := _build_fixture(5)
	_expect(bool(fixture.get("valid", false)), "portal fixture must compile")
	if not bool(fixture.get("valid", false)):
		_complete_leg("portal_and_fail_closed", assertion_start)
		return
	var layout := fixture.get("layout", {}) as Dictionary
	var portals := _dictionary_array(layout.get("interaction_portals", []))
	_expect(not portals.is_empty(), "portal fixture must publish at least one building portal")
	if portals.is_empty():
		_complete_leg("portal_and_fail_closed", assertion_start)
		return
	var portal := portals[0]
	var navigation_state := PlazaR3NavigationBinding.bind_layout(layout, str(layout.get("fingerprint", "")))
	_expect(bool(navigation_state.get("valid", false)), "R3 navigation binding must accept the canonical hub union")
	_expect(str(navigation_state.get("binding_kind", "")) == PlazaR3NavigationBinding.BINDING_KIND, "R3 navigation binding kind must remain explicit")
	var bound_corridors := _dictionary_array(navigation_state.get("walkable_corridor_polygons", []))
	var layout_corridors := _dictionary_array(layout.get("walkable_corridor_polygons", []))
	_expect(bound_corridors.size() == layout_corridors.size(), "navigation binding must not append the separately published hub twice")
	var layout_hubs := _dictionary_array(layout.get("walkable_hub_polygons", []))
	_expect(layout_hubs.size() == 1, "R3 fixture must publish exactly one authored central plaza hub")
	if layout_hubs.size() != 1:
		_complete_leg("portal_and_fail_closed", assertion_start)
		return
	var hub_id := str(layout_hubs[0].get("id", ""))
	var bound_hub_count := 0
	for corridor in bound_corridors:
		if str(corridor.get("id", "")) == hub_id:
			bound_hub_count += 1
	_expect(bound_hub_count == 1, "central plaza hub must occur exactly once in the bound walkable union")
	var portal_point := _find_portal_only_point(layout, portal)
	_expect(portal_point.is_finite(), "fixture must expose one full-body portal-only placement")
	if not portal_point.is_finite():
		_complete_leg("portal_and_fail_closed", assertion_start)
		return
	var runtime := _new_runtime()
	_expect(runtime.bind_candidate(_build_config(fixture, portal_point, portal_point)), "runtime must bind at a full-body portal placement")
	var compiled: Object = runtime.get_compiled_navigation_for_test()
	_expect(compiled != null and bool(compiled.call("can_occupy", portal_point, true)), "portal point must be full-body walkable with portal union")
	_expect(compiled != null and not bool(compiled.call("can_occupy", portal_point, false)), "same portal point must fail in corridors-only mode")
	var interaction: Dictionary = runtime.try_interact()
	_expect(bool(interaction.get("valid", false)), "real portal interaction must resolve")
	_expect(str(interaction.get("interaction_kind", "")) == "building", "portal must route to a building")
	_expect(str(interaction.get("building_type", "")) == str(portal.get("building_type", "")), "portal building type must remain exact")
	_expect(str(interaction.get("plot_id", "")) == str(portal.get("plot_id", "")), "portal plot ownership must remain exact")
	var stale_layout := layout.duplicate(true)
	var hubs := _dictionary_array(stale_layout.get("walkable_hub_polygons", []))
	var hub := hubs[0].duplicate(true)
	var polygon := _packed_polygon(hub.get("polygon_world", []))
	polygon[0] += Vector2(3.0, 0.0)
	hub["polygon_world"] = polygon
	hubs[0] = hub
	stale_layout["walkable_hub_polygons"] = hubs
	var stale_binding := PlazaR3NavigationBinding.bind_layout(stale_layout, str(layout.get("fingerprint", "")))
	_expect(not bool(stale_binding.get("valid", true)), "stale R3 hub geometry must fail navigation binding")
	var missing_approval := _new_runtime()
	var bad_config := _build_config(fixture, portal_point, portal_point)
	bad_config.erase("composition_approval_id")
	_expect(not missing_approval.bind_candidate(bad_config), "missing visual composition approval must fail closed")
	_expect(not missing_approval.visible and not bool(missing_approval.get_debug_status().get("active", true)), "rejected approval must leave zero visible runtime")
	var malformed_visual := _new_runtime()
	var malformed := _build_config(fixture, portal_point, portal_point)
	var malformed_visual_config := (malformed.get("visual_config", {}) as Dictionary).duplicate(false)
	malformed_visual_config["guardian_draw_size_world"] = NAN
	malformed["visual_config"] = malformed_visual_config
	_expect(not malformed_visual.bind_candidate(malformed), "NaN guardian art scalar must reject before retained-tree mutation")
	_expect(not malformed_visual.visible, "malformed art must remain fail-hidden")
	runtime.clear_transient_canvas_items()
	_expect(not bool(runtime.try_interact().get("valid", true)), "interaction after clear must reject")
	runtime.free()
	missing_approval.free()
	malformed_visual.free()
	_complete_leg("portal_and_fail_closed", assertion_start)


func _verify_owner_cadence_and_isolation() -> void:
	var assertion_start := _assertion_count
	for map_seed in [4, 12]:
		var fixture := _build_fixture(map_seed)
		_expect(bool(fixture.get("valid", false)), "seed %d cadence fixture must compile" % map_seed)
		if not bool(fixture.get("valid", false)):
			continue
		var source_layout := fixture.get("layout", {}) as Dictionary
		var source_plan := fixture.get("plan", {}) as Dictionary
		var hub_center := _hub_center(source_layout)
		var runtime := _new_runtime()
		var bound: bool = runtime.bind_candidate(_build_config(fixture, hub_center, hub_center + Vector2(-96.0, 0.0)))
		_expect(bound, "seed %d owner cadence runtime must bind: %s" % [map_seed, runtime.get_debug_status().get("rejection_reason", "")])
		if not bound:
			runtime.free()
			continue
		var first_road := _dictionary_array((source_layout.get("road_graph", {}) as Dictionary).get("edges", []))[0]
		first_road["polyline_world"] = PackedVector2Array([Vector2(1.0, 1.0), Vector2(2.0, 2.0)])
		var ground := source_plan.get("ground_draw", {}) as Dictionary
		ground["world_position"] = Vector2(9999.0, 9999.0)
		var directions: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
		var ticks := 0
		for tick_index in range(720):
			var direction: Vector2 = directions[floori(float(tick_index) / 20.0) % directions.size()]
			var result: Dictionary = runtime.tick_candidate(direction, 1.0 / 60.0, tick_index * 16)
			_expect(bool(result.get("valid", false)), "seed %d tick %d must survive source mutation and compiled cadence" % [map_seed, tick_index])
			if not bool(result.get("valid", false)):
				break
			ticks += 1
			await process_frame
		var metrics: Dictionary = runtime.get_owner_cadence_metrics()
		_expect(ticks == 720, "seed %d must complete all 720 real owner ticks" % map_seed)
		_expect(int(metrics.get("sample_count", 0)) == 600, "seed %d must measure 600 steady samples after exact warmup" % map_seed)
		_expect(float(metrics.get("p95_usec", INF)) <= PlazaR3ExteriorRuntimeCandidate.OWNER_CADENCE_P95_LIMIT_USEC, "seed %d actual owner cadence p95 must stay under 2ms, got %s" % [map_seed, metrics.get("p95_usec", INF)])
		_expect(bool(metrics.get("within_limit", false)), "seed %d p95 result must explicitly pass the activation limit" % map_seed)
		_expect(int((runtime.get_debug_status()).get("successful_tick_count", 0)) == 720, "seed %d successful tick count must be non-proxy" % map_seed)
		var status: Dictionary = runtime.get_debug_status()
		_expect(str(status.get("layout_fingerprint", "")) != "", "seed %d must retain the bound immutable layout identity" % map_seed)
		print("plaza_r3b_exterior_runtime_smoke: seed=%d owner_cadence=%s" % [map_seed, metrics])
		runtime.free()
	_expect(not FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd").contains("plaza_r3_exterior_runtime_candidate"), "PlazaScene must not consume R3-B before R3-D")
	_expect(not FileAccess.get_file_as_string("res://project.godot").contains("plaza_r3_exterior_runtime_candidate"), "project.godot must not activate R3-B")
	_complete_leg("owner_cadence_and_isolation", assertion_start)


func _build_fixture(map_seed: int) -> Dictionary:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, map_seed, false, false)
	var layout := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, specs, SPAWN_ANCHOR, EXIT_ZONE)
	if not bool((layout.get("validation", {}) as Dictionary).get("valid", false)):
		return {"valid": false}
	var plan := PlazaR3EnvironmentLayoutCompiler.compile_layout(layout)
	var approved_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(plan, layout, true)
	if not bool(approved_validation.get("valid", false)):
		return {"valid": false}
	return {"valid": true, "layout": layout, "plan": plan}


func _build_visual_config() -> Dictionary:
	var player_textures := PlazaAssetLoader.load_player_textures("smasher")
	var guardian_path := LingpetCatalog.get_visual_path(GUARDIAN_ID, "companion_walk")
	var guardian_value: Variant = ResourceLoader.load(guardian_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if not bool(player_textures.get("has_sprite", false)) or not (guardian_value is Texture2D):
		return {"valid": false}
	return {
		"valid": true,
		"player_textures": player_textures,
		"guardian_enabled": true,
		"guardian_texture": guardian_value as Texture2D,
		"guardian_grid_cols": roundi(LingpetCatalog.get_visual_layout_value(GUARDIAN_ID, "companion_walk_cols", 5.0)),
		"guardian_grid_rows": roundi(LingpetCatalog.get_visual_layout_value(GUARDIAN_ID, "companion_walk_rows", 5.0)),
		"guardian_frame_count": roundi(LingpetCatalog.get_visual_layout_value(GUARDIAN_ID, "companion_walk_frame_count", 25.0)),
		"guardian_draw_size_world": LingpetCatalog.get_visual_layout_value(GUARDIAN_ID, "companion_walk_draw_size", 92.0),
	}


func _build_config(fixture: Dictionary, player_world: Vector2, guardian_world: Vector2) -> Dictionary:
	return {
		"composition_approval_id": PlazaR3ExteriorRuntimeCandidate.ENVIRONMENT_COMPOSITION_APPROVAL_ID,
		"layout": fixture.get("layout", {}),
		"environment_plan": fixture.get("plan", {}),
		"render_size": VIEW_SIZE,
		"safe_insets": SAFE_INSETS,
		"minimap_rect": MINIMAP_RECT,
		"camera_zoom": CAMERA_ZOOM,
		"ticks_msec": 0,
		"initial_player_world_position": player_world,
		"initial_guardian_world_position": guardian_world,
		"guardian_locomotion_style": "ground",
		"visual_config": _visual_config,
	}


func _new_runtime() -> Control:
	var runtime := PlazaR3ExteriorRuntimeCandidate.new()
	runtime.name = "PlazaR3BExteriorRuntimeSmoke"
	root.add_child(runtime)
	return runtime


func _hub_center(layout: Dictionary) -> Vector2:
	var hubs := _dictionary_array(layout.get("walkable_hub_polygons", []))
	if hubs.is_empty():
		return Vector2.INF
	return _polygon_average(_packed_polygon(hubs[0].get("polygon_world", [])))


func _find_portal_only_point(layout: Dictionary, portal: Dictionary) -> Vector2:
	var fingerprint := str(layout.get("fingerprint", ""))
	var bound := PlazaR3NavigationBinding.bind_layout(layout, fingerprint)
	var compiled: Object = PlazaMapNavigationCompiled.compile(bound)
	if compiled == null or not bool(compiled.call("is_valid")):
		return Vector2.INF
	var polygon := _packed_polygon(portal.get("polygon_world", []))
	if polygon.size() < 3:
		return Vector2.INF
	var aabb := _polygon_aabb(polygon)
	var center := _polygon_average(polygon)
	var candidates: Array[Vector2] = [center]
	var x := aabb.position.x + 2.0
	while x < aabb.end.x:
		var y := aabb.position.y + 2.0
		while y < aabb.end.y:
			candidates.append(Vector2(x, y))
			y += 4.0
		x += 4.0
	for candidate in candidates:
		if not Geometry2D.is_point_in_polygon(candidate, polygon):
			continue
		if bool(compiled.call("can_occupy", candidate, true)) and not bool(compiled.call("can_occupy", candidate, false)):
			return candidate
	return Vector2.INF


func _polygon_aabb(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var aabb := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()):
		aabb = aabb.expand(polygon[index])
	return aabb


func _polygon_average(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.INF
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / float(polygon.size())


func _packed_polygon(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return (value as PackedVector2Array).duplicate()
	var result := PackedVector2Array()
	if not (value is Array):
		return result
	for point in value as Array:
		if not (point is Vector2):
			return PackedVector2Array()
		result.append(point as Vector2)
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _count_named_descendants(node: Node, node_name: String) -> int:
	var count := 1 if node.name == node_name else 0
	for child in node.get_children():
		count += _count_named_descendants(child, node_name)
	return count


func _rect_equal_approx(first: Rect2, second: Rect2) -> bool:
	return first.position.is_equal_approx(second.position) and first.size.is_equal_approx(second.size)


func _complete_leg(leg_name: String, assertion_start: int) -> void:
	if _leg_assertion_counts.has(leg_name):
		_failures.append("GRT-040 completion gate: duplicate leg completion: %s" % leg_name)
		return
	_leg_assertion_counts[leg_name] = _assertion_count - assertion_start
	_legs_completed += 1


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _legs_completed != EXPECTED_COMPLETED_LEGS:
		_failures.append("GRT-040 completion gate: expected %d completed legs, got %d" % [EXPECTED_COMPLETED_LEGS, _legs_completed])
	for leg_name_value in MIN_ASSERTIONS_BY_LEG.keys():
		var leg_name := str(leg_name_value)
		var minimum := int(MIN_ASSERTIONS_BY_LEG.get(leg_name, 0))
		var actual := int(_leg_assertion_counts.get(leg_name, 0))
		if actual < minimum:
			_failures.append("GRT-040 completion gate: leg %s executed %d assertions, expected at least %d" % [leg_name, actual, minimum])
	if _assertion_count <= 0:
		_failures.append("GRT-040 completion gate: smoke executed zero assertions")
	if _failures.is_empty() and _legs_completed == EXPECTED_COMPLETED_LEGS:
		print("plaza_r3b_exterior_runtime_smoke: ok legs=%d assertions=%d" % [_legs_completed, _assertion_count])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
