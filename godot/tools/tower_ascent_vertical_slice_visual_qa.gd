extends SceneTree

const BattlePlayfieldSceneDrawer := preload(
	"res://scripts/core/battle_playfield_scene_drawer.gd"
)
const BallRenderer := preload("res://scripts/ball/ball_renderer.gd")
const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const RoundFlowState := preload("res://scripts/core/round_flow_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)

const GAME_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_ascent_phase_b"


class CaptureRegistry:
	extends RefCounted

	var flow_owner: Object
	var ball_renderer: Object = BallRenderer.new()
	var battle_draw_context: Object = BattleDrawContext.new()
	var round_flow_state: Object = RoundFlowState.new()
	var live_ball_enabled := false

	func _init(new_flow_owner: Object, enable_live_ball: bool = false) -> void:
		flow_owner = new_flow_owner
		live_ball_enabled = enable_live_ball
		round_flow_state.waiting_for_serve = false

	func get_instance(key: String) -> Variant:
		if live_ball_enabled and key == "ball_renderer":
			return ball_renderer
		if live_ball_enabled and key == "battle_draw_context":
			return battle_draw_context
		if live_ball_enabled and key == "round_flow_state":
			return round_flow_state
		return null

	func get_cached_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return null


class ProductionPlayfieldCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattlePlayfieldSceneDrawer.new()
	var ball_active := false
	var ball_pos := Vector2(380.0, 665.0)
	var ball_pos_prev := Vector2(380.0, 665.0)
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6
	var ball_visual_type := "energy"
	var ball_render_interpolation_enabled := false
	var ball_interp_reset_requested := false
	var ball_interp_last_physics_usec := 0

	func _init(new_registry: Object) -> void:
		registry = new_registry

	func _draw() -> void:
		drawer.draw(self, registry, Vector2.ZERO, 760.0, 750.0, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_ascent_vertical_slice_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_ascent_vertical_slice_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("tower-ascent capture directory creation failed: %d" % mkdir_error)
		quit(1)
		return
	if not await _capture_phase("route_targets.png", "ROUTE_TARGETS", output_dir):
		return
	if not await _capture_phase("route_serve.png", "ROUTE_SERVE", output_dir):
		return
	if not await _capture_phase("map_transition.png", "MAP_TRANSITION", output_dir):
		return
	if not await _capture_phase("node_modal_arrival.png", "NODE_MODAL_ARRIVAL", output_dir):
		return
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print("tower_ascent_vertical_slice_visual_qa: evidence=%s" % output_dir)
	print("tower_ascent_vertical_slice_visual_qa: captures=4")
	print("tower_ascent_vertical_slice_visual_qa: ok")
	quit(0)


func _capture_phase(output_name: String, phase_name: String, output_dir: String) -> bool:
	var flow_owner := TowerAscentFlowOwner.new()
	if not flow_owner.begin_vertical_slice(null, Callable(), {"run_id": "visual-qa", "current_stage": 4, "map_seed": 83521}):
		push_error("tower-ascent visual fixture could not begin")
		quit(1)
		return false
	if phase_name == "ROUTE_SERVE":
		flow_owner.debug_launch_at_target(0)
		flow_owner.update_selective(0.35)
	elif phase_name == "MAP_TRANSITION":
		flow_owner.debug_launch_at_target(1)
		flow_owner.update_selective(1.2)
		flow_owner.update_selective(0.45)
	elif phase_name == "NODE_MODAL_ARRIVAL":
		flow_owner.debug_launch_at_target(0)
		flow_owner.update_selective(1.2)
		flow_owner.update_selective(1.0)
	var expected_phase := (
		"ROUTE_AIM"
		if phase_name in ["ROUTE_TARGETS", "ROUTE_SERVE"]
		else "NODE_MODAL" if phase_name == "NODE_MODAL_ARRIVAL" else phase_name
	)
	if flow_owner.get_phase_name() != expected_phase:
		push_error("tower-ascent visual fixture phase mismatch: %s" % flow_owner.get_phase_name())
		quit(1)
		return false

	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionPlayfieldCanvas.new(
		CaptureRegistry.new(flow_owner, phase_name == "ROUTE_SERVE")
	)
	if phase_name == "ROUTE_SERVE":
		canvas.ball_active = flow_owner.is_selector_launched()
		canvas.ball_pos = flow_owner.get_selector_position()
		canvas.ball_pos_prev = canvas.ball_pos
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(output_name)
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE or image.save_png(output_path) != OK:
		push_error("tower-ascent visual QA capture failed: %s" % output_path)
		quit(1)
		return false
	print("[TowerAscentVisualQA] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true
