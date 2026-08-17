extends SceneTree

const BattlePlayfieldSceneDrawer := preload(
	"res://scripts/core/battle_playfield_scene_drawer.gd"
)
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

const GAME_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_ascent_phase_d"

var _save_paths: Array[String] = []


class FakeScoreboard:
	extends RefCounted
	func is_active() -> bool:
		return false
	func get_player_points() -> int:
		return 0
	func get_boss_points() -> int:
		return MatchScoreState.WIN_GOAL
	func get_win_goal() -> int:
		return MatchScoreState.WIN_GOAL
	func get_last_scoring_side() -> String:
		return "boss"


class FakeRuntimeState:
	extends RefCounted
	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass
	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass
	func _resume_skill_cooldowns_for_choice() -> void:
		pass
	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class CaptureOwner:
	extends RefCounted
	var current_stage := 9
	var chance_gems_count := 0
	var chance_gems_max := 0
	func request_battle_redraw() -> void:
		pass


class CaptureRegistry:
	extends RefCounted
	var flow_owner: Object
	var scoreboard := FakeScoreboard.new()
	var runtime := FakeRuntimeState.new()
	func _init(new_flow_owner: Object = null) -> void:
		flow_owner = new_flow_owner
	func get_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		if key == "scoreboard_state":
			return scoreboard
		if key == "runtime_perk_state":
			return runtime
		return null
	func get_cached_instance(key: String) -> Variant:
		return get_instance(key)


class ProductionPlayfieldCanvas:
	extends Node2D
	var registry: Object
	var drawer: Object = BattlePlayfieldSceneDrawer.new()
	var ball_active := false
	var ball_visual_type := "pingpong"
	func _init(new_registry: Object) -> void:
		registry = new_registry
	func _draw() -> void:
		drawer.draw(self, registry, Vector2.ZERO, 760.0, 750.0, 0.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_ascent_phase_d_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_ascent_phase_d_visual_qa requires a Vulkan rendering device")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_fail("tower-ascent Phase-D capture directory creation failed: %d" % mkdir_error)
		return
	var fixtures := [
		{"name": "01_fake_ending_teaser.png", "flow": _build_teaser_flow()},
		{"name": "02_reclear_choice.png", "flow": _build_choice_flow()},
		{"name": "03_clear_settlement.png", "flow": _build_clear_settlement_flow()},
		{"name": "04_defeat_settlement.png", "flow": _build_defeat_settlement_flow()},
		{"name": "05_gauntlet_transition.png", "flow": _build_gauntlet_transition_flow()},
		{"name": "06_true_ending_settlement.png", "flow": _build_true_ending_flow()},
	]
	for fixture_variant in fixtures:
		var fixture: Dictionary = fixture_variant
		var flow: Object = fixture.get("flow", null)
		if flow == null or not flow.is_active():
			_fail("visual fixture failed: %s" % str(fixture.get("name", "")))
			return
		if not await _capture(flow, str(fixture.get("name", "")), output_dir):
			return
	_cleanup_save_paths()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print("tower_ascent_phase_d_visual_qa: evidence=%s" % output_dir)
	print("tower_ascent_phase_d_visual_qa: captures=6")
	print("tower_ascent_phase_d_visual_qa: ok")
	quit(0)


func _build_teaser_flow() -> Object:
	var path := _new_save_path("teaser")
	var flow := _begin_flow(path, "qa-teaser", 9)
	if flow != null:
		flow.begin_floor_nine_resolution("qa-teaser:floor09")
	return flow


func _build_choice_flow() -> Object:
	var path := _new_save_path("choice")
	_seed_fake_clear(path, "qa-choice:seed")
	var flow := _begin_flow(path, "qa-choice", 9)
	if flow != null:
		flow.begin_floor_nine_resolution("qa-choice:floor09")
	return flow


func _build_clear_settlement_flow() -> Object:
	var path := _new_save_path("clear")
	var flow := _begin_flow(path, "qa-clear", 9)
	if flow == null:
		return null
	flow.begin_floor_nine_resolution("qa-clear:floor09")
	_confirm_flow(flow)
	return flow


func _build_defeat_settlement_flow() -> Object:
	var path := _new_save_path("defeat")
	var owner := CaptureOwner.new()
	owner.current_stage = 8
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(path)
	var registry := CaptureRegistry.new()
	if not flow.prepare_vertical_slice_combat(owner, {
		"run_id": "qa-defeat",
		"current_stage": owner.current_stage,
		"map_seed": 4808,
		"run_state": {"chance_gems": 0},
		"registry": registry,
	}):
		return null
	if not flow.begin_vertical_slice(owner, Callable(), {"registry": registry}):
		return null
	if not flow.resolve_defeat(registry, owner, Callable(), Callable()):
		return null
	return flow


func _build_gauntlet_transition_flow() -> Object:
	var path := _new_save_path("gauntlet")
	var flow := _begin_flow(path, "qa-gauntlet", 11)
	if flow == null or not bool(flow.begin_floor_eleven_gauntlet().get("accepted", false)):
		return null
	var victory: Dictionary = flow.resolve_gauntlet_victory(
		Callable(),
		null,
		null,
		"qa-gauntlet:encounter:0:victory"
	)
	return flow if bool(victory.get("accepted", false)) else null


func _build_true_ending_flow() -> Object:
	var path := _new_save_path("true")
	_seed_fake_clear(path, "qa-true:seed")
	var flow := _begin_flow(path, "qa-true", 9)
	if flow == null:
		return null
	flow.begin_floor_nine_resolution("qa-true:floor09")
	if not bool(flow.choose_ending_route("continue").get("accepted", false)):
		return null
	if not bool(flow.begin_floor_eleven_gauntlet().get("accepted", false)):
		return null
	for index in range(4):
		var victory: Dictionary = flow.resolve_gauntlet_victory(
			Callable(),
			null,
			null,
			"qa-true:encounter:%d:victory" % index
		)
		if not bool(victory.get("accepted", false)):
			return null
		if index < 3:
			_confirm_flow(flow)
	var ending: Dictionary = flow.begin_floor_twelve_true_ending("qa-true:floor12")
	return flow if bool(ending.get("accepted", false)) else null


func _begin_flow(save_path: String, run_id: String, stage: int) -> Object:
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	if not flow.prepare_vertical_slice_combat(null, {
		"run_id": run_id,
		"current_stage": stage,
		"map_seed": 81000 + stage,
	}):
		return null
	if not flow.begin_vertical_slice(null, Callable()):
		return null
	return flow


func _seed_fake_clear(save_path: String, event_id: String) -> void:
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	store.record_clear(9, TowerAscentRecordStore.ENDING_STANDARD, false, event_id)


func _confirm_flow(flow: Object) -> void:
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	flow.handle_input(confirm)


func _capture(flow: Object, output_name: String, output_dir: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionPlayfieldCanvas.new(CaptureRegistry.new(flow))
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(output_name)
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE or image.save_png(output_path) != OK:
		_fail("tower-ascent Phase-D capture failed: %s" % output_path)
		return false
	print("[TowerAscentPhaseDVisualQA] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true


func _new_save_path(label: String) -> String:
	var path := "user://tower_ascent_phase_d_visual_%s_%d.cfg" % [label, Time.get_ticks_usec()]
	_save_paths.append(path)
	return path


func _cleanup_save_paths() -> void:
	for path in _save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_save_paths.clear()


func _fail(message: String) -> void:
	_cleanup_save_paths()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	push_error(message)
	quit(1)
