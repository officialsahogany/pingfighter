extends SceneTree

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)
const BattleSmasherSpritePaths := preload(
	"res://scripts/resources/battle_smasher_sprite_paths.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_overlay"
const OUTPUT_NAME_PHASE_1 := "map_overlay_human_realm.png"
const OUTPUT_NAME_PHASE_2 := "map_overlay_immortal_realm.png"
const OUTPUT_NAME_ICON_ZOOM := "map_overlay_boss_icon_zoom8.png"
const OUTPUT_NAME_MISSING_ICON := "map_overlay_missing_icon_fallback.png"


class FakePillarDrawPass:
	extends RefCounted

	func draw(canvas: CanvasItem, _registry: Object, view_size: Vector2, layout: Dictionary) -> void:
		var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
		var game_size: Vector2 = layout.get("game_size", Vector2.ZERO)
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color("111722"), true)
		canvas.draw_rect(Rect2(game_offset - Vector2(28.0, 0.0), Vector2(24.0, game_size.y)), Color("6d4c32"), true)
		canvas.draw_rect(Rect2(Vector2(game_offset.x + game_size.x + 4.0, game_offset.y), Vector2(24.0, game_size.y)), Color("6d4c32"), true)


class FakePlayfieldDrawer:
	extends RefCounted

	func draw(canvas: CanvasItem, _registry: Object, _shake_offset: Vector2, width: float, height: float, _pillar_width: float) -> void:
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color("294b63"), true)
		canvas.draw_rect(Rect2(0.0, height * 0.72, width, height * 0.28), Color("8d6541"), true)
		canvas.draw_circle(Vector2(width * 0.5, height * 0.58), 54.0, Color("e6c867"))


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
	var pillar_draw_pass: Object = FakePillarDrawPass.new()
	var playfield_drawer: Object = FakePlayfieldDrawer.new()
	var view_layout: Object = preload("res://scripts/core/battle_view_layout.gd").new()

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
			"battle_scene_pillar_draw_pass":
				return pillar_draw_pass
			"battle_playfield_scene_drawer":
				return playfield_drawer
			"battle_view_layout":
				return view_layout
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
	var selected_character_type := "smasher"
	var battle_textures := {
		"player_walk_left_texture": preload(BattleSmasherSpritePaths.PLAYER_WALK_LEFT_SPRITE_PATH),
		"player_walk_right_texture": preload(BattleSmasherSpritePaths.PLAYER_WALK_RIGHT_SPRITE_PATH),
	}

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
	var missing_icon_probe := OS.get_environment("TOWER_ASCENT_MAP_QA_MISSING_ICON") == "1"
	var progress_text := OS.get_environment("TOWER_ASCENT_MAP_QA_PROGRESS").strip_edges()
	var injected_progress := -1.0 if progress_text.is_empty() else clampf(float(progress_text), 0.0, 1.0)
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
		flow_owner.set_transition_progress_for_qa(0.5 if injected_progress < 0.0 else injected_progress)
	else:
		flow_owner.set_map_overlay_fade_progress_for_qa(1.0)
	if missing_icon_probe and not _inject_missing_icon_probe(flow_owner):
		_fail("missing-icon fallback fixture could not find a combat node")
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
	var output_name := (
		OUTPUT_NAME_MISSING_ICON
		if missing_icon_probe
		else OUTPUT_NAME_PHASE_2
		if capture_phase == "phase2"
		else OUTPUT_NAME_PHASE_1
	)
	if capture_phase == "phase2" and injected_progress >= 0.0:
		output_name = "map_transition_progress_%03d.png" % int(round(injected_progress * 100.0))
	var output_path := output_dir.path_join(output_name)
	if (
		image == null
		or image.is_empty()
		or image.get_size() != GAME_SIZE
		or image.save_png(output_path) != OK
	):
		_fail("map-overlay visual QA capture failed: %s" % output_path)
		return
	var capture_count := 1
	if capture_phase == "phase1" and not missing_icon_probe:
		var zoom_path := output_dir.path_join(OUTPUT_NAME_ICON_ZOOM)
		if not _save_boss_icon_zoom(image, flow_owner, zoom_path):
			_fail("map-overlay boss icon zoom capture failed: %s" % zoom_path)
			return
		capture_count += 1
	print("[TowerMapOverlayVisualQA] %s" % output_path)
	print("tower_ascent_map_overlay_visual_qa: phase=%s captures=%d" % [
		capture_phase,
		capture_count,
	])
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


func _inject_missing_icon_probe(flow_owner: Object) -> bool:
	for node in flow_owner.get_graph_nodes():
		if str(node.get("kind", "")) not in ["boss", "combat", "enraged"]:
			continue
		node["map_icon_boss_id"] = "missing_contract_probe"
		node["label"] = "계약 폴백 보스"
		return true
	return false


func _save_boss_icon_zoom(image: Image, flow_owner: Object, output_path: String) -> bool:
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_fullscreen_map_model(
		flow_owner,
		Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
	)
	var camera_offset: Vector2 = (model.get("camera", {}) as Dictionary).get(
		"offset",
		Vector2.ZERO
	)
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if str(node.get("kind", "")) not in ["boss", "combat", "enraged"]:
			continue
		var world_art_rect: Rect2 = node.get("world_art_rect", Rect2())
		var art_rect := Rect2(
			world_art_rect.position + camera_offset,
			world_art_rect.size
		)
		var bounds := Rect2i(art_rect.grow(6.0)).intersection(Rect2i(Vector2i.ZERO, GAME_SIZE))
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			continue
		var zoom := image.get_region(bounds)
		zoom.resize(bounds.size.x * 8, bounds.size.y * 8, Image.INTERPOLATE_NEAREST)
		return zoom.save_png(output_path) == OK
	return false


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
