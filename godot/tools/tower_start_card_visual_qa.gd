extends SceneTree

const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneIntroFrameController := preload("res://scripts/core/battle_scene_intro_frame_controller.gd")
const BattleSceneReadinessController := preload("res://scripts/core/battle_scene_readiness_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const Stage1HanMiryangProloguePresentation := preload(
	"res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd"
)
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerStartCardState := preload("res://scripts/tower_ascent/tower_start_card_state.gd")

const CAPTURE_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_start_card"


class CaptureRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class CaptureWarmup:
	extends RefCounted

	func is_finished() -> bool:
		return true


class CaptureLoadingRenderer:
	extends RefCounted

	func should_hold_completion(_owner: Object, _module_getter: Callable) -> bool:
		return false

	func hide_loading() -> void:
		pass

	func release_stained_glass_hosts(_owner: Object) -> void:
		pass


class CaptureFlowOwner:
	extends RefCounted
	var start_card_result: Dictionary = {}

	func get_run_id() -> String:
		return "tower-start-card-visual-qa"

	func record_start_card_result(result: Dictionary) -> bool:
		start_card_result = result.duplicate(true)
		return true


class CaptureUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class CaptureRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {
		"common_swiftness": 1,
		"megingjord": 1,
	}
	var current_choice_context: Dictionary = {}
	var _stats_owner: Object = null
	var _stats_registry_ref: WeakRef = null

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var perk_id := str(choice.get("id", ""))
		if perk_id.is_empty():
			return false
		runtime_skill_levels[perk_id] = int(runtime_skill_levels.get(perk_id, 0)) + 1
		return true

	func apply_choice_at_target_level(
		choice: Dictionary,
		target_level: int,
		_owner: Object,
		_registry: Object
	) -> bool:
		var perk_id := str(choice.get("id", ""))
		if perk_id.is_empty():
			return false
		runtime_skill_levels[perk_id] = target_level
		return true

	func has_pending_unlock_swap() -> bool:
		return false

	func capture_stats_context(owner: Object, registry: Object) -> bool:
		_stats_owner = owner
		_stats_registry_ref = weakref(registry) if registry != null else null
		return owner != null and registry != null

	func get_stats_context_owner() -> Object:
		return _stats_owner

	func get_stats_context_registry() -> Object:
		return _stats_registry_ref.get_ref() if _stats_registry_ref != null else null

	func get_physique_training_snapshot() -> Dictionary:
		return {"power": 1, "guard": 1}

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"pending_skill_choices": 0,
			"gold_from_perks": 0,
			"current_choices": [],
			"particles": [],
			"physique_training": get_physique_training_snapshot(),
		}


class CaptureAudio:
	extends RefCounted

	func play_stage_bgm(_stage: int) -> void:
		pass

	func play_han_miryang_prologue_opening_drum() -> void:
		pass

	func play_han_miryang_prologue_rays() -> void:
		pass

	func play_han_miryang_prologue_spirit_bell() -> void:
		pass

	func stop_han_miryang_prologue_cues() -> void:
		pass

	func set_story_cinematic_bgm_gain_db(value: float) -> float:
		return value

	func clear_story_cinematic_bgm_gain() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_start_card_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_start_card_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("start-card capture directory creation failed: %d" % mkdir_error)
		quit(1)
		return

	var selection_state: Object = get_root().get_node_or_null("GameSelectionState")
	var owns_selection_state := false
	if selection_state == null:
		selection_state = GameSelectionState.new()
		selection_state.name = "GameSelectionState"
		get_root().add_child(selection_state)
		owns_selection_state = true
	while bool(selection_state.consume_tower_start_card_entry_request()):
		pass
	selection_state.request_tower_start_card_entry()
	selection_state.request_character_prologue_entry()

	var start_card := TowerStartCardState.new()
	var prologue := Stage1HanMiryangProloguePresentation.new()
	prologue.set_progress_path_for_test("user://tower_start_card_visual_qa_progress.json")
	var flow := BattleSceneFlowController.new()
	flow.set("_battle_initialized", true)
	var registry := CaptureRegistry.new()
	registry.instances = {
		"battle_scene_flow_controller": flow,
		"battle_scene_frame_controller": BattleSceneFrameController.new(),
		"battle_scene_intro_frame_controller": BattleSceneIntroFrameController.new(),
		"battle_scene_readiness_controller": BattleSceneReadinessController.new(),
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"battle_scene_input_controller": BattleSceneInputController.new(),
		"battle_boot_warmup_controller": CaptureWarmup.new(),
		"battle_loading_screen_renderer": CaptureLoadingRenderer.new(),
		"tower_start_card_state": start_card,
		"tower_ascent_flow_owner": CaptureFlowOwner.new(),
		"tower_ascent_unlock_store": CaptureUnlockStore.new(),
		"runtime_perk_state": CaptureRuntimeState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_overlay_renderer": RuntimePerkOverlayRenderer.new(),
		"runtime_perk_icon_renderer": RuntimePerkIconRenderer.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
		"stage1_han_miryang_prologue_presentation": prologue,
		"game_audio": CaptureAudio.new(),
	}

	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var shell: Node2D = BattleSceneShell.new()
	shell.gameplay_modules = registry
	shell.set_process(false)
	shell.set_physics_process(false)
	shell.set("current_stage", 1)
	shell.set("selected_character_type", "smasher")
	shell.set("selected_runtime_character_id", "smasher")
	viewport.add_child(shell)

	if not start_card.begin(shell, registry):
		push_error("start-card visual fixture could not begin: state=%s inside=%s selection=%s token=%s flag=%s" % [
			start_card.get_status_for_tests(),
			shell.is_inside_tree(),
			shell.get_node_or_null("/root/GameSelectionState"),
			selection_state.peek_tower_start_card_entry_request(),
			TowerAscentFeatureFlags.is_vertical_slice_enabled(),
		])
		quit(1)
		return
	shell._process(1.0)
	if not start_card.is_active():
		push_error("start-card visual fixture did not stay active through BattleSceneShell: %s" % [
			start_card.get_status_for_tests()
		])
		quit(1)
		return
	if not await _capture(viewport, shell, output_dir.path_join("start_card_three_choices.png")):
		return

	var choose_first := InputEventKey.new()
	choose_first.pressed = true
	choose_first.keycode = KEY_1
	shell._unhandled_input(choose_first)
	shell._process(0.24)
	if not bool(start_card.get_selection_result().get("accepted", false)):
		push_error("start-card visual fixture did not accept the first choice")
		quit(1)
		return
	if not await _capture(viewport, shell, output_dir.path_join("start_card_selected.png")):
		return

	shell._process(1.0)
	for _frame_index in range(240):
		shell._process(1.0 / 60.0)
		shell.queue_redraw()
		await process_frame
		if str(prologue.get("_phase")) == Stage1HanMiryangProloguePresentation.PHASE_ACTIVE:
			break
	if str(prologue.get("_phase")) != Stage1HanMiryangProloguePresentation.PHASE_ACTIVE:
		push_error("start-card visual fixture did not hand off to the real prologue")
		quit(1)
		return
	shell._process(0.55)
	if not await _capture(viewport, shell, output_dir.path_join("start_card_prologue_handoff.png")):
		return

	prologue.tear_down()
	start_card.tear_down()
	viewport.remove_child(shell)
	shell.free()
	get_root().remove_child(viewport)
	viewport.free()
	if owns_selection_state:
		get_root().remove_child(selection_state)
		selection_state.free()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print("tower_start_card_visual_qa: evidence=%s" % output_dir)
	print("tower_start_card_visual_qa: captures=3")
	print("tower_start_card_visual_qa: ok")
	quit(0)


func _capture(
	viewport: SubViewport,
	shell: Node2D,
	output_path: String
) -> bool:
	shell.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	if (
		image == null
		or image.is_empty()
		or image.get_size() != CAPTURE_SIZE
		or image.save_png(output_path) != OK
	):
		push_error("start-card visual QA capture failed: %s" % output_path)
		quit(1)
		return false
	print("[TowerStartCardVisualQA] %s" % output_path)
	return true
