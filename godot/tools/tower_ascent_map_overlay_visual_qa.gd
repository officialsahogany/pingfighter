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
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_overlay"
const OUTPUT_NAME := "map_overlay_combat.png"


class FakeRuntimePerkState:
	extends RefCounted

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeAudio:
	extends RefCounted

	func stop_dash_delay() -> void:
		pass


class CaptureRegistry:
	extends RefCounted

	var flow_owner: Object
	var ball_renderer: Object = BallRenderer.new()
	var battle_draw_context: Object = BattleDrawContext.new()
	var round_flow_state: Object = RoundFlowState.new()
	var runtime_perk_state: Object = FakeRuntimePerkState.new()
	var game_audio: Object = FakeAudio.new()

	func _init(new_flow_owner: Object) -> void:
		flow_owner = new_flow_owner
		round_flow_state.waiting_for_serve = false

	func get_instance(key: String) -> Variant:
		match key:
			"ball_renderer":
				return ball_renderer
			"battle_draw_context":
				return battle_draw_context
			"round_flow_state":
				return round_flow_state
			"runtime_perk_state":
				return runtime_perk_state
			"game_audio":
				return game_audio
			"tower_ascent_flow_owner":
				return flow_owner
		return null

	func get_cached_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return get_instance(key)


class ProductionPlayfieldCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattlePlayfieldSceneDrawer.new()
	var current_stage := 4
	var ball_active := true
	var ball_pos := Vector2(380.0, 440.0)
	var ball_pos_prev := Vector2(378.0, 446.0)
	var ball_vel := Vector2(120.0, -310.0)
	var ball_size := 28.6
	var ball_visual_type := "energy"
	var ball_render_interpolation_enabled := false
	var ball_interp_reset_requested := false
	var ball_interp_last_physics_usec := 0

	func _init(new_registry: Object) -> void:
		registry = new_registry

	func request_battle_redraw() -> void:
		queue_redraw()

	func _draw() -> void:
		drawer.draw(self, registry, Vector2.ZERO, 760.0, 750.0, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_ascent_map_overlay_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_ascent_map_overlay_visual_qa requires a Vulkan rendering device")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_fail("map-overlay capture directory creation failed: %d" % mkdir_error)
		return

	var flow_owner := TowerAscentFlowOwner.new()
	var registry := CaptureRegistry.new(flow_owner)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionPlayfieldCanvas.new(registry)
	viewport.add_child(canvas)
	if not flow_owner.open_map_overlay(canvas, registry, {
		"run_id": "map-overlay-visual-qa",
		"current_stage": 4,
		"map_seed": 83521,
	}):
		_fail("combat map overlay fixture could not open")
		return
	_decorate_state_evidence(flow_owner)
	if flow_owner.get_phase_name() != "MAP_OVERLAY":
		_fail("map-overlay visual fixture phase mismatch: %s" % flow_owner.get_phase_name())
		return
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(OUTPUT_NAME)
	if (
		image == null
		or image.is_empty()
		or image.get_size() != GAME_SIZE
		or image.save_png(output_path) != OK
	):
		_fail("map-overlay visual QA capture failed: %s" % output_path)
		return
	print("[TowerMapOverlayVisualQA] %s" % output_path)
	print("tower_ascent_map_overlay_visual_qa: captures=1")
	print("tower_ascent_map_overlay_visual_qa: ok")
	flow_owner.close_map_overlay()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	registry = null
	flow_owner = null
	await process_frame
	await process_frame
	quit(0)


func _decorate_state_evidence(flow_owner: Object) -> void:
	var nodes: Array[Dictionary] = flow_owner.get_graph_nodes()
	for node in nodes:
		var node_id := str(node.get("id", ""))
		if node_id != flow_owner.get_current_node_id():
			flow_owner.call(
				"_commit_node_resolution",
				node_id,
				"visual_visited",
				{}
			)
			break
	for node in nodes:
		var slot_id := str(node.get("boss_slot_id", ""))
		if not slot_id.is_empty() and str(node.get("id", "")) != flow_owner.get_current_node_id():
			flow_owner.call("_mark_boss_slot_skipped_in_graph", slot_id)
			break


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
