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
const OUTPUT_PATH := (
	"res://.godot/codex_captures/tower_optional_extra_boss/optional_extra_boss.png"
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
	var output_dir := ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())
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
	# Capture the node in the production state where its floor has already been
	# revealed; the fresh-run cloud intentionally obscures floor 2 before travel.
	(flow.get("_run_state") as Object).call(
		"reveal_floor",
		int(fixture.get("segment_floor", 2))
	)
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	var renderer: Object = flow.get("_renderer")
	var initial_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var optional_node := _find_model_node(initial_model, optional_node_id)
	if optional_node.is_empty():
		_fail("production renderer model omitted the optional extra-boss node")
		return
	var initial_camera: Dictionary = initial_model.get("camera", {})
	var target_zoom := clampf(
		1.5,
		float(initial_camera.get("minimum_fit_all_zoom", 1.0)),
		float(initial_camera.get("maximum_zoom", 1.5))
	)
	var drag_state: Object = flow.get("_map_drag_state")
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
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if image.save_png(output_path) != OK:
		_fail("could not save optional extra-boss Vulkan capture")
		return
	print(
		"[TowerOptionalExtraBossVisualQA] seed=%d floor=%d node=%s slot=%s encounter=%s icon=%s screen=%s zoom=%.6f visible_bypass_siblings=%d output=%s"
		% [
			map_seed,
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
