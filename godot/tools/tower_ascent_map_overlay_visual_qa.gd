extends SceneTree

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

const GAME_SIZE := Vector2i(1280, 800)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_overlay"
const OUTPUT_NAME_PHASE_1 := "map_overlay_human_realm.png"
const OUTPUT_NAME_PHASE_2 := "map_overlay_immortal_realm.png"


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
	var runtime_perk_state: Object = FakeRuntimePerkState.new()
	var game_audio: Object = FakeAudio.new()

	func _init(new_flow_owner: Object) -> void:
		flow_owner = new_flow_owner

	func get_instance(key: String) -> Variant:
		match key:
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


class ProductionScreenCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattleSceneDrawer.new()
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
		drawer.draw(self, registry, {"context_owner": self})


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
	var capture_phase := OS.get_environment("TOWER_ASCENT_MAP_QA_PHASE").strip_edges().to_lower()
	if capture_phase not in ["phase1", "phase2"]:
		capture_phase = "phase1"
	var record_path := "user://tower_map_overlay_visual_%d.cfg" % Time.get_ticks_usec()
	if capture_phase == "phase2":
		var store := TowerAscentRecordStore.new()
		store.set_save_path(record_path)
		var seeded: Dictionary = store.record_clear(
			9,
			TowerAscentRecordStore.ENDING_STANDARD,
			false,
			"map-overlay-visual:seed"
		)
		if not bool(seeded.get("accepted", false)):
			_fail("phase-2 record fixture could not seed the prior clear")
			return
		flow_owner.set_record_store_path_for_tests(record_path)
	var registry := CaptureRegistry.new(flow_owner)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionScreenCanvas.new(registry)
	viewport.add_child(canvas)
	if not flow_owner.open_map_overlay(canvas, registry, {
		"run_id": "map-overlay-visual-qa",
		"current_stage": 4,
		"map_seed": 83521,
	}):
		_fail("combat map overlay fixture could not open")
		return
	if capture_phase == "phase2":
		flow_owner.close_map_overlay()
		var judgment: Dictionary = flow_owner.begin_floor_nine_resolution(
			"map-overlay-visual:floor09",
			Callable(),
			canvas,
			registry
		)
		if not bool(judgment.get("accepted", false)):
			_fail("phase-2 ending judgment fixture failed")
			return
		var choice: Dictionary = flow_owner.choose_ending_route("continue")
		if not bool(choice.get("accepted", false)) or flow_owner.get_active_graph_phase_index() != 1:
			_fail("phase-2 graph transition fixture failed")
			return
	_decorate_state_evidence(flow_owner)
	var expected_phase := "MAP_TRANSITION" if capture_phase == "phase2" else "MAP_OVERLAY"
	if flow_owner.get_phase_name() != expected_phase:
		_fail("map-overlay visual fixture phase mismatch: %s" % flow_owner.get_phase_name())
		return
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_name := OUTPUT_NAME_PHASE_2 if capture_phase == "phase2" else OUTPUT_NAME_PHASE_1
	var output_path := output_dir.path_join(output_name)
	if (
		image == null
		or image.is_empty()
		or image.get_size() != GAME_SIZE
		or image.save_png(output_path) != OK
	):
		_fail("map-overlay visual QA capture failed: %s" % output_path)
		return
	print("[TowerMapOverlayVisualQA] %s" % output_path)
	print("tower_ascent_map_overlay_visual_qa: phase=%s captures=1" % capture_phase)
	print("tower_ascent_map_overlay_visual_qa: ok")
	if flow_owner.is_map_overlay_active():
		flow_owner.close_map_overlay()
	if flow_owner.is_active():
		flow_owner.call("_finish_vertical_slice")
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(record_path))
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
	var selected_target_id := str(flow_owner.get_selected_target_id())
	for node in nodes:
		var node_id := str(node.get("id", ""))
		if node_id != flow_owner.get_current_node_id() and node_id != selected_target_id:
			flow_owner.call(
				"_commit_node_resolution",
				node_id,
				"visual_visited",
				{}
			)
			break
	for node in nodes:
		var slot_id := str(node.get("boss_slot_id", ""))
		if (
			not slot_id.is_empty()
			and str(node.get("id", "")) != flow_owner.get_current_node_id()
			and str(node.get("id", "")) != selected_target_id
		):
			flow_owner.call("_mark_boss_slot_skipped_in_graph", slot_id)
			break


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
