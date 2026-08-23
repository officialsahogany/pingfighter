extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const BattleResources := preload(
	"res://scripts/resources/battle_resources.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_training_relayout"
const ALLOWED_TRAINING_IDS: Array[String] = [
	"physique_move_speed",
	"physique_storage",
	"physique_dash_distance",
	"physique_paddle_size",
	"physique_max_gauge",
	"physique_hit_gauge",
]


class CaptureOwner:
	extends Node2D
	var current_stage := 4
	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class CaptureUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return ALLOWED_TRAINING_IDS.has(content_id)


class CaptureMythicItemRuntime:
	extends RefCounted
	var runtime_state: Object = null

	func _init(runtime_state_value: Object) -> void:
		runtime_state = runtime_state_value

	func refresh_runtime_perk_scaling(owner: Object, _registry: Object) -> void:
		var bonus := 0.0
		if runtime_state != null and runtime_state.has_method("get_physique_training_bonus"):
			bonus = float(runtime_state.get_physique_training_bonus("max_gauge_flat"))
		owner.set("special_gauge_max", 500.0 + bonus)

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		if runtime_state == null or not runtime_state.has_method("get_physique_training_bonus"):
			return base_charge
		var bonus_pct := float(runtime_state.get_physique_training_bonus("hit_gauge_bonus_pct"))
		return base_charge * (1.0 + bonus_pct / 100.0)

	func get_player_paddle_scale() -> float:
		return 1.0


class CaptureBattleResources:
	extends RefCounted
	var cache: Dictionary = {}

	func get_resource_cache() -> Dictionary:
		return cache


class CaptureRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class CaptureCanvas:
	extends Node2D
	var flow: Object = null
	var renderer := TowerAscentFlowRenderer.new()

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


var _capture_count := 0
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("capture directory creation failed")
		return

	var original_conversion_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var owner := CaptureOwner.new()
	viewport.add_child(owner)
	var runtime_state := RuntimePerkState.new()
	var card_renderer := RuntimePerkOverlayRenderer.new()
	var registry := CaptureRegistry.new()
	var battle_resources := CaptureBattleResources.new()
	battle_resources.cache = _load_training_texture_cache()
	if battle_resources.cache.size() != 2:
		_fail("production Smasher idle/attack textures did not load")
		_finish_flags(original_conversion_flag)
		return
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"tower_ascent_unlock_store": CaptureUnlockStore.new(),
		"runtime_perk_overlay_renderer": card_renderer,
		"mythic_item_runtime": CaptureMythicItemRuntime.new(runtime_state),
		"battle_resources": battle_resources,
	}
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active", true)
	flow.set("_phase", 1)
	flow.set("_node_modal_kind", "training")
	flow.set("_current_node_id", "training-relayout-visual")
	flow.set("_map_seed", 689)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", registry)
	var run_state: Object = flow.get("_run_state")
	if not bool(run_state.begin("training-relayout-visual-run", {"muhon": 30})):
		_fail("training visual run state did not begin")
		_finish_flags(original_conversion_flag)
		return
	flow.call("_open_node_modal")

	var canvas := CaptureCanvas.new()
	canvas.flow = flow
	viewport.add_child(canvas)
	var frames: Array[Image] = []
	var idle := await _capture_frame(
		viewport,
		canvas,
		output_dir.path_join("training_relayout_00_idle.png")
	)
	if idle == null:
		_fail("idle capture failed")
		_finish_flags(original_conversion_flag)
		return
	frames.append(idle)

	for card_index in range(6):
		var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
		var actions: Array = model.get("actions", [])
		var rects: Array = model.get("action_rects", [])
		if actions.size() != 7 or rects.size() != 7:
			_fail("training rail lost its six-card action contract")
			break
		var before_values: Array = card_renderer.get_tower_training_stats_snapshot_for_tests().get(
			"values",
			[]
		)
		var clock_base := 10000 + card_index * 2000
		flow.set_training_stage_clock_msec_for_tests(clock_base)
		var top_corner := (rects[card_index] as Rect2).position + Vector2(2.0, 2.0)
		flow.handle_input(_mouse_button(true, top_corner))
		flow.handle_input(_mouse_button(false, top_corner))
		var timing_debug: Dictionary = flow.get_training_timing_debug_state()
		var target_position := float(timing_debug.get("target_position", 0.5))
		var stop_position := 0.0 if target_position >= 0.5 else 1.0
		var stop_elapsed := int(roundf(stop_position * 800.0))
		flow.set_training_stage_clock_msec_for_tests(
			int(timing_debug.get("started_msec", clock_base)) + stop_elapsed
		)
		flow.handle_input(_mouse_button(true, Vector2(8.0, 8.0)))
		flow.handle_input(_mouse_button(false, Vector2(8.0, 8.0)))
		var strike_debug: Dictionary = flow.get_training_stage_presentation_debug_state()
		flow.set_training_stage_clock_msec_for_tests(
			int(strike_debug.get("started_msec", clock_base)) + 360
		)
		flow.update_selective(0.016, null)
		var after_values: Array = card_renderer.get_tower_training_stats_snapshot_for_tests().get(
			"values",
			[]
		)
		if var_to_bytes(after_values) == var_to_bytes(before_values):
			_fail("card %d did not update a canonical stat row" % (card_index + 1))
			break
		var frame := await _capture_frame(
			viewport,
			canvas,
			output_dir.path_join("training_relayout_%02d_card_%d_hit.png" % [
				card_index + 1,
				card_index + 1,
			])
		)
		if frame == null:
			_fail("card %d capture failed" % (card_index + 1))
			break
		frames.append(frame)
		flow.set_training_stage_clock_msec_for_tests(
			int(strike_debug.get("started_msec", clock_base)) + 1300
		)
		flow.update_selective(0.016, null)

	if not _failed:
		var returned := await _capture_frame(
			viewport,
			canvas,
			output_dir.path_join("training_relayout_07_returned.png")
		)
		if returned == null:
			_fail("returned capture failed")
		else:
			frames.append(returned)
	if not _failed and flow.get_training_history().size() != 6:
		_fail("six top-corner clicks did not produce six training commits")
	if not _failed and not _verify_region_contract(flow):
		_fail("three-region layout contract failed")
	if not _failed and not _save_frame_strip(
		frames,
		output_dir.path_join("training_relayout_six_click_sequence_4x2.png")
	):
		_fail("six-click frame strip save failed")
	if not _failed and not _save_direction_comparison(
		idle,
		output_dir.path_join("training_relayout_mockup_direction_comparison.png")
	):
		_fail("mockup-direction comparison save failed")

	_finish_flags(original_conversion_flag)
	if _failed:
		quit(1)
		return
	print("tower_training_relayout_visual_qa: evidence=%s" % output_dir)
	print("tower_training_relayout_visual_qa: captures=%d" % _capture_count)
	print("tower_training_relayout_visual_qa: six_clicks=ok")
	print("tower_training_relayout_visual_qa: stats_same_frame=ok")
	print("tower_training_relayout_visual_qa: comparison=ok")
	print("tower_training_relayout_visual_qa: ok")
	quit(0)


func _capture_frame(
	viewport: SubViewport,
	canvas: CanvasItem,
	path: String
) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		return null
	_capture_count += 1
	return image


func _save_frame_strip(frames: Array[Image], path: String) -> bool:
	if frames.size() != 8:
		return false
	var cell_size := Vector2i(VIEW_SIZE.x / 4, VIEW_SIZE.y / 4)
	var strip := Image.create(cell_size.x * 4, cell_size.y * 2, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.025, 0.02, 0.016, 1.0))
	for index in range(frames.size()):
		var thumbnail := frames[index].duplicate()
		thumbnail.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		thumbnail.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			thumbnail,
			Rect2i(Vector2i.ZERO, thumbnail.get_size()),
			Vector2i(index % 4, index / 4) * cell_size
		)
	return strip.save_png(path) == OK


func _save_direction_comparison(actual: Image, path: String) -> bool:
	var half_size := Vector2i(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2)
	var board := Image.create(half_size.x * 2, half_size.y, false, Image.FORMAT_RGBA8)
	board.fill(Color(0.035, 0.025, 0.018, 1.0))
	var reference := Image.create(half_size.x, half_size.y, false, Image.FORMAT_RGBA8)
	reference.fill(Color(0.82, 0.76, 0.62, 1.0))
	var base_scale := minf(float(half_size.x) / 760.0, float(half_size.y) / 750.0)
	var base_offset := (Vector2(half_size) - Vector2(760.0, 750.0) * base_scale) * 0.5
	_fill_reference_rect(reference, TowerAscentNodeModalState.MODAL_RECT, base_scale, base_offset, Color(0.91, 0.85, 0.70, 1.0))
	_fill_reference_rect(reference, Rect2(126.0, 52.0, 508.0, 80.0), base_scale, base_offset, Color(0.69, 0.50, 0.26, 0.42))
	for row in range(6):
		var card_height := (
			TowerAscentNodeModalState.TRAINING_CARD_GRID_RECT.size.y
			- TowerAscentNodeModalState.TRAINING_GRID_ROW_GAP * 5.0
		) / 6.0
		_fill_reference_rect(
			reference,
			Rect2(
				TowerAscentNodeModalState.TRAINING_CARD_GRID_RECT.position
				+ Vector2(0.0, float(row) * (card_height + TowerAscentNodeModalState.TRAINING_GRID_ROW_GAP)),
				Vector2(TowerAscentNodeModalState.TRAINING_CARD_GRID_RECT.size.x, card_height)
			),
			base_scale,
			base_offset,
			Color(0.40, 0.22 + 0.025 * float(row), 0.10, 0.92)
		)
	_fill_reference_rect(reference, TowerAscentNodeModalState.TRAINING_STAGE_RECT, base_scale, base_offset, Color(0.16, 0.09, 0.055, 0.96))
	_fill_reference_rect(reference, TowerAscentNodeModalState.TRAINING_STATS_RECT, base_scale, base_offset, Color(0.70, 0.62, 0.45, 0.98))
	_fill_reference_rect(reference, TowerAscentNodeModalState.TRAINING_END_WORK_RECT, base_scale, base_offset, Color(0.49, 0.30, 0.12, 0.96))
	var actual_half := actual.duplicate()
	actual_half.resize(half_size.x, half_size.y, Image.INTERPOLATE_LANCZOS)
	actual_half.convert(Image.FORMAT_RGBA8)
	board.blit_rect(reference, Rect2i(Vector2i.ZERO, reference.get_size()), Vector2i.ZERO)
	board.blit_rect(actual_half, Rect2i(Vector2i.ZERO, actual_half.get_size()), Vector2i(half_size.x, 0))
	return board.save_png(path) == OK


func _fill_reference_rect(
	image: Image,
	rect: Rect2,
	scale_value: float,
	offset: Vector2,
	color: Color
) -> void:
	var scaled := Rect2(offset + rect.position * scale_value, rect.size * scale_value)
	image.fill_rect(Rect2i(scaled), color)


func _verify_region_contract(flow: Object) -> bool:
	var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var card_rect: Rect2 = model.get("card_grid_rect", Rect2())
	var stage_rect: Rect2 = model.get("training_stage_rect", Rect2())
	var stats_rect: Rect2 = model.get("training_stats_rect", Rect2())
	return (
		card_rect.has_area()
		and stage_rect.has_area()
		and stats_rect.has_area()
		and not card_rect.intersects(stage_rect)
		and not card_rect.intersects(stats_rect)
		and not stage_rect.intersects(stats_rect)
		and stage_rect.end.y < stats_rect.position.y
	)


func _load_training_texture_cache() -> Dictionary:
	var idle := _load_source_texture(BattleResources.SMASHER_IDLE_SHEET_PATH)
	var attack := _load_source_texture(BattleResources.SMASHER_ATTACK_RIGHT_SHEET_PATH)
	if idle == null or attack == null:
		return {}
	return {
		"player_idle_back_sheet": idle,
		"player_attack_right_sheet": attack,
	}


func _load_source_texture(resource_path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event


func _finish_flags(original_conversion_flag: bool) -> void:
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)


func _fail(message: String) -> void:
	_failed = true
	push_error("tower_training_relayout_visual_qa: %s" % message)
