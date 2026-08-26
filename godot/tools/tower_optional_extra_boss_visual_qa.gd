extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const DETAIL_OUTPUT_PATH := (
	"res://.godot/codex_captures/tower_optional_extra_boss/optional_extra_boss.png"
)
const FULL_MAP_OUTPUT_PATH := (
	"res://.godot/codex_captures/tower_optional_extra_boss/"
	+ "floor23_three_bosses_full_map.png"
)
const FLOOR23_OUTPUT_PATH := (
	"res://.godot/codex_captures/tower_optional_extra_boss/"
	+ "floor23_three_bosses_visible.png"
)
const SAMPLE_SEED_COUNT := 128
const SAMPLE_SEED_START := 9109
const SAMPLE_SEED_STEP := 7919


class MapCanvas:
	extends Node2D

	var flow: Object

	func _init(flow_owner: Object) -> void:
		flow = flow_owner

	func _draw() -> void:
		flow.draw_fullscreen_map(
			self,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0)),
			{}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_optional_extra_boss_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_optional_extra_boss_visual_qa requires Vulkan")
		return
	var fixture := _find_spawned_optional_boss_fixture()
	if fixture.is_empty():
		_fail("128-seed sample did not produce an optional extra boss")
		return
	var output_dir := ProjectSettings.globalize_path(DETAIL_OUTPUT_PATH.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create optional extra-boss capture directory")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := MapCanvas.new(flow)
	viewport.add_child(canvas)
	var map_seed := int(fixture.get("map_seed", 0))
	var optional_node_id := str(fixture.get("node_id", ""))
	if not flow.open_map_overlay(canvas, null, {
		"run_id": "tower-optional-extra-boss-vulkan",
		"map_seed": map_seed,
	}):
		_fail("could not open production map overlay")
		return
	# Reveal through 3F so the overview capture can show the two target floors.
	(flow.get("_run_state") as Object).call(
		"reveal_floor",
		3
	)
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	var renderer: Object = flow.get("_renderer")
	var initial_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var optional_node := _find_model_node(initial_model, optional_node_id)
	if optional_node.is_empty():
		_fail("production renderer model omitted the optional extra-boss node")
		return
	var initial_camera: Dictionary = initial_model.get("camera", {})
	var fit_all_zoom := float(initial_camera.get("minimum_fit_all_zoom", 1.0))
	var fit_all_world_rect: Rect2 = initial_model.get(
		"fit_all_camera_world_rect",
		initial_model.get("world_rect", Rect2())
	)
	var drag_state: Object = flow.get("_map_drag_state")
	var fit_all_offset := (
		VIEWPORT_RECT.get_center() - fit_all_world_rect.get_center() * fit_all_zoom
	)
	drag_state.call("apply_zoom_override", fit_all_zoom, fit_all_offset)
	var full_map_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var floor_boss_counts := _count_bosses_by_floor(full_map_model, [2, 3])
	for floor_number in [2, 3]:
		if int(floor_boss_counts.get(floor_number, 0)) != 3:
			_fail(
				"full-map model expected 3 bosses on %dF, got %d"
				% [floor_number, int(floor_boss_counts.get(floor_number, 0))]
			)
			return
	var full_map_image: Image = await _capture(canvas, viewport)
	if full_map_image == null:
		_fail("floor 2/3 full-map Vulkan capture failed")
		return
	var full_map_output_path := ProjectSettings.globalize_path(FULL_MAP_OUTPUT_PATH)
	if full_map_image.save_png(full_map_output_path) != OK:
		_fail("could not save floor 2/3 full-map Vulkan capture")
		return
	var floor23_world_rect := _world_bounds_for_floors(full_map_model, [2, 3]).grow(96.0)
	if not floor23_world_rect.has_area():
		_fail("could not resolve floor 2/3 world bounds")
		return
	var camera_view_rect: Rect2 = full_map_model.get("camera_view_rect", VIEWPORT_RECT)
	var floor23_zoom := clampf(
		minf(
			camera_view_rect.size.x / floor23_world_rect.size.x,
			camera_view_rect.size.y / floor23_world_rect.size.y
		) * 0.9,
		fit_all_zoom,
		float(initial_camera.get("maximum_zoom", 1.5))
	)
	var floor23_offset := (
		camera_view_rect.get_center() - floor23_world_rect.get_center() * floor23_zoom
	)
	drag_state.call("apply_zoom_override", floor23_zoom, floor23_offset)
	var floor23_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	if not _all_bosses_visible_for_floors(floor23_model, [2, 3], 64.0):
		_fail("floor 2/3 capture did not keep all six bosses visible")
		return
	var floor23_image: Image = await _capture(canvas, viewport)
	if floor23_image == null:
		_fail("floor 2/3 visible-boss Vulkan capture failed")
		return
	var floor23_output_path := ProjectSettings.globalize_path(FLOOR23_OUTPUT_PATH)
	if floor23_image.save_png(floor23_output_path) != OK:
		_fail("could not save floor 2/3 visible-boss Vulkan capture")
		return
	var target_zoom := clampf(
		1.5,
		float(initial_camera.get("minimum_fit_all_zoom", 1.0)),
		float(initial_camera.get("maximum_zoom", 1.5))
	)
	var target_offset := (
		VIEWPORT_RECT.get_center()
		- (optional_node.get("world_position", Vector2.ZERO) as Vector2) * target_zoom
	)
	drag_state.call("apply_zoom_override", target_zoom, target_offset)
	var zoom_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	optional_node = _find_model_node(zoom_model, optional_node_id)
	if optional_node.is_empty():
		_fail("cover-zoom model omitted the optional extra-boss node")
		return
	target_offset = (
		VIEWPORT_RECT.get_center()
		- (optional_node.get("world_position", Vector2.ZERO) as Vector2) * target_zoom
	)
	drag_state.call("apply_zoom_override", target_zoom, target_offset)
	var final_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	optional_node = _find_model_node(final_model, optional_node_id)
	var camera: Dictionary = final_model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var screen_position := (
		(optional_node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
	)
	if not VIEWPORT_RECT.grow(-96.0).has_point(screen_position):
		_fail("optional extra-boss node is outside the intended capture inset")
		return
	var visible_bypass_siblings := _count_visible_row_siblings(
		final_model,
		optional_node,
		zoom,
		offset
	)
	if visible_bypass_siblings < 1:
		_fail("capture must retain a visible same-row bypass sibling")
		return
	var presentation: Dictionary = renderer.build_map_icon_presentation(optional_node)
	if not (presentation.get("icon_texture") is Texture2D):
		_fail("optional extra boss did not load its existing boss icon texture")
		return
	if not str(presentation.get("fallback_label", "")).is_empty():
		_fail("optional extra boss unexpectedly rendered through text fallback")
		return
	var image: Image = await _capture(canvas, viewport)
	if image == null:
		_fail("optional extra-boss Vulkan capture failed")
		return
	var output_path := ProjectSettings.globalize_path(DETAIL_OUTPUT_PATH)
	if image.save_png(output_path) != OK:
		_fail("could not save optional extra-boss Vulkan capture")
		return
	print(
		"[TowerOptionalExtraBossVisualQA] seed=%d floor_boss_counts=%s full_map_output=%s floor23_zoom=%.6f floor23_output=%s floor=%d node=%s slot=%s encounter=%s icon=%s screen=%s zoom=%.6f visible_bypass_siblings=%d detail_output=%s"
		% [
			map_seed,
			str(floor_boss_counts),
			full_map_output_path,
			floor23_zoom,
			floor23_output_path,
			int(optional_node.get("segment_floor", 0)),
			optional_node_id,
			str(optional_node.get("boss_slot_id", "")),
			str(optional_node.get("boss_encounter_key", "")),
			str(presentation.get("icon_path", "")),
			str(screen_position),
			zoom,
			visible_bypass_siblings,
			output_path,
		]
	)
	print("tower_optional_extra_boss_visual_qa: ok")
	flow.close_map_overlay()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	flow = null
	await process_frame
	await process_frame
	quit(0)


func _find_spawned_optional_boss_fixture() -> Dictionary:
	var generator := TowerAscentMapGenerator.new()
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := SAMPLE_SEED_START + seed_offset * SAMPLE_SEED_STEP
		var graph: Dictionary = generator.generate_tower(map_seed)
		for phase_variant in graph.get("phases", []):
			if not (phase_variant is Dictionary):
				continue
			for node_variant in (phase_variant as Dictionary).get("nodes", []):
				if not (node_variant is Dictionary):
					continue
				var node := node_variant as Dictionary
				if bool(node.get("optional_extra_boss", false)):
					return {
						"map_seed": map_seed,
						"node_id": str(node.get("id", "")),
						"segment_floor": int(node.get("segment_floor", 0)),
					}
	return {}


func _find_model_node(model: Dictionary, node_id: String) -> Dictionary:
	for node_variant in model.get("nodes", []):
		if (
			node_variant is Dictionary
			and str((node_variant as Dictionary).get("id", "")) == node_id
		):
			return node_variant as Dictionary
	return {}


func _count_bosses_by_floor(model: Dictionary, floor_numbers: Array) -> Dictionary:
	var result := {}
	for floor_number in floor_numbers:
		result[int(floor_number)] = 0
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if (
			result.has(floor_number)
			and str(node.get("kind", "")) in TowerAscentMapGenerator.COMBAT_NODE_KINDS
		):
			result[floor_number] = int(result.get(floor_number, 0)) + 1
	return result


func _world_bounds_for_floors(model: Dictionary, floor_numbers: Array) -> Rect2:
	var result := Rect2()
	var has_position := false
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if floor_number not in floor_numbers:
			continue
		var world_position: Vector2 = node.get("world_position", Vector2.ZERO)
		if not has_position:
			result = Rect2(world_position, Vector2.ZERO)
			has_position = true
		else:
			result = result.expand(world_position)
	return result


func _all_bosses_visible_for_floors(
	model: Dictionary,
	floor_numbers: Array,
	screen_inset: float
) -> bool:
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var visible_rect := VIEWPORT_RECT.grow(-screen_inset)
	var visible_boss_count := 0
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if (
			floor_number not in floor_numbers
			or str(node.get("kind", "")) not in TowerAscentMapGenerator.COMBAT_NODE_KINDS
		):
			continue
		var screen_position := (
			(node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
		)
		if not visible_rect.has_point(screen_position):
			return false
		visible_boss_count += 1
	return visible_boss_count == 6


func _count_visible_row_siblings(
	model: Dictionary,
	optional_node: Dictionary,
	zoom: float,
	offset: Vector2
) -> int:
	var result := 0
	var target_row := int(optional_node.get("global_row", -1))
	var optional_node_id := str(optional_node.get("id", ""))
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			str(node.get("id", "")) == optional_node_id
			or int(node.get("global_row", -2)) != target_row
		):
			continue
		var sibling_screen_position := (
			(node.get("world_position", Vector2.ZERO) as Vector2) * zoom + offset
		)
		if VIEWPORT_RECT.grow(-96.0).has_point(sibling_screen_position):
			result += 1
	return result


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE:
		return null
	return image


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
