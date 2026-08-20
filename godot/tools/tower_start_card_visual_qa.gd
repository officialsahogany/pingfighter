extends SceneTree

const BattleSceneShell := preload("res://scripts/core/battle_scene_shell.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneIntroFrameController := preload("res://scripts/core/battle_scene_intro_frame_controller.gd")
const BattleSceneReadinessController := preload("res://scripts/core/battle_scene_readiness_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const Stage1HanMiryangProloguePresentation := preload(
	"res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd"
)
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAscentFlowOwner := preload("res://scripts/tower_ascent/tower_ascent_flow_owner.gd")
const TowerAscentTuning := preload("res://scripts/tower_ascent/tower_ascent_tuning.gd")
const TowerStartCardState := preload("res://scripts/tower_ascent/tower_start_card_state.gd")

const CAPTURE_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_start_card"
const LIVE_RUN_IDS := [
	"gwangmaekgyeol-live-seed-101",
	"gwangmaekgyeol-live-seed-202",
	"gwangmaekgyeol-live-seed-303",
]


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


class CaptureLandingIntro:
	extends RefCounted
	var begin_calls := 0
	var active := false

	func begin(_owner: Object, _registry: Object) -> bool:
		begin_calls += 1
		active = true
		return true

	func is_active() -> bool:
		return active


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
	var play_stage_bgm_calls := 0

	func play_stage_bgm(_stage: int) -> void:
		play_stage_bgm_calls += 1

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
	PerkConversionFlags.debug_set_enabled(true)
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
	var flow_owner := TowerAscentFlowOwner.new()
	var runtime_state := CaptureRuntimeState.new()
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
		"tower_ascent_flow_owner": flow_owner,
		"tower_ascent_unlock_store": CaptureUnlockStore.new(),
		"runtime_perk_state": runtime_state,
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

	if not flow_owner.ensure_run_started(shell, {"run_id": LIVE_RUN_IDS[0]}):
		push_error("start-card visual fixture could not start the first seeded run")
		quit(1)
		return
	var prewarm: Dictionary = flow_owner.prewarm_muhon_collection(shell)
	if not bool(prewarm.get("accepted", false)):
		push_error("start-card visual fixture could not prewarm the real run owner")
		quit(1)
		return
	shell._process(1.0)
	if not start_card.is_active():
		push_error("start-card visual fixture could not begin: state=%s inside=%s selection=%s token=%s flag=%s" % [
			start_card.get_status_for_tests(),
			shell.is_inside_tree(),
			shell.get_node_or_null("/root/GameSelectionState"),
			selection_state.peek_tower_start_card_entry_request(),
			TowerAscentFeatureFlags.is_vertical_slice_enabled(),
		])
		quit(1)
		return
	var smasher_cold_msec := start_card.get_cold_build_msec()
	if smasher_cold_msec > TowerAscentTuning.TEMP_START_CARD_COLD_BUILD_BUDGET_MS:
		push_error("smasher start-card cold build exceeded budget: %.3fms" % smasher_cold_msec)
		quit(1)
		return
	var smasher_choices := start_card.get_card_choices()
	if _has_choice_id(smasher_choices, "common_expansion"):
		push_error("smasher seeded live offer exposed retired common_expansion")
		quit(1)
		return
	var smasher_chosik_count := _count_kind(smasher_choices, "chosik")
	if smasher_chosik_count < 1 or smasher_chosik_count > 2:
		push_error("smasher live offer must contain one or two Chosik cards")
		quit(1)
		return
	if not await _capture(viewport, shell, output_dir.path_join("start_card_three_choices.png")):
		return

	var smasher_mugong_index := _find_kind_index(smasher_choices, "mugong")
	if smasher_mugong_index < 0:
		push_error("smasher live offer must retain a Mugong choice")
		quit(1)
		return
	var choose_mugong := InputEventKey.new()
	choose_mugong.pressed = true
	choose_mugong.keycode = [KEY_1, KEY_2, KEY_3][smasher_mugong_index]
	shell._unhandled_input(choose_mugong)
	shell._process(0.24)
	if not bool(start_card.get_selection_result().get("accepted", false)):
		push_error("start-card visual fixture did not accept its Mugong choice")
		quit(1)
		return
	var smasher_picked_id := str(start_card.get_selection_result().get("picked_perk_id", ""))
	if (
		int(runtime_state.runtime_skill_levels.get(smasher_picked_id, 0))
		!= TowerAscentTuning.TEMP_START_CARD_MUGONG_START_LEVEL
	):
		push_error("smasher live Mugong choice did not commit actual level two")
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
	var viper_result: Dictionary = await _run_non_prologue_case(
		selection_state,
		"viper",
		"viper_skill_config",
		ViperSkillConfig.new(),
		LIVE_RUN_IDS[1]
	)
	if not bool(viper_result.get("accepted", false)):
		push_error("viper live start-card case failed: %s" % viper_result)
		quit(1)
		return
	var blacksmith_result: Dictionary = await _run_non_prologue_case(
		selection_state,
		"blacksmith",
		"blacksmith_skill_config",
		BlacksmithSkillConfig.new(),
		LIVE_RUN_IDS[2]
	)
	if not bool(blacksmith_result.get("accepted", false)):
		push_error("blacksmith live start-card case failed: %s" % blacksmith_result)
		quit(1)
		return
	var fusion_result := _run_meridian_expand_fusion_case()
	if not bool(fusion_result.get("accepted", false)):
		push_error("live meridian expansion fusion case failed: %s" % fusion_result)
		quit(1)
		return
	if owns_selection_state:
		get_root().remove_child(selection_state)
		selection_state.free()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)
	print("tower_start_card_visual_qa: evidence=%s" % output_dir)
	print("tower_start_card_visual_qa: captures=3")
	print("tower_start_card_visual_qa: live_cases=3")
	print("tower_start_card_visual_qa: live_run_ids=%s" % ",".join(LIVE_RUN_IDS))
	print("tower_start_card_visual_qa: retired_expansion_absent_cases=3")
	print("tower_start_card_visual_qa: meridian_expand_fusion=ok")
	print("tower_start_card_visual_qa: cold_build_ms=smasher=%.3f,viper=%.3f,blacksmith=%.3f,budget=%.3f" % [
		smasher_cold_msec,
		float(viper_result.get("cold_build_msec", -1.0)),
		float(blacksmith_result.get("cold_build_msec", -1.0)),
		TowerAscentTuning.TEMP_START_CARD_COLD_BUILD_BUDGET_MS,
	])
	print("tower_start_card_visual_qa: ok")
	quit(0)


func _run_non_prologue_case(
	selection_state: Object,
	character_type: String,
	skill_config_key: String,
	skill_config: Object,
	run_id: String
) -> Dictionary:
	while bool(selection_state.consume_tower_start_card_entry_request()):
		pass
	while bool(selection_state.consume_character_prologue_entry_request()):
		pass
	selection_state.request_tower_start_card_entry()
	selection_state.request_character_prologue_entry()

	var start_card := TowerStartCardState.new()
	var prologue := Stage1HanMiryangProloguePresentation.new()
	prologue.set_progress_path_for_test(
		"user://tower_start_card_visual_qa_%s_progress.json" % character_type
	)
	var landing := CaptureLandingIntro.new()
	var flow_owner := TowerAscentFlowOwner.new()
	var runtime_state := CaptureRuntimeState.new()
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
		"tower_ascent_flow_owner": flow_owner,
		"tower_ascent_unlock_store": CaptureUnlockStore.new(),
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_overlay_renderer": RuntimePerkOverlayRenderer.new(),
		"runtime_perk_icon_renderer": RuntimePerkIconRenderer.new(),
		"stage1_han_miryang_prologue_presentation": prologue,
		"stage_landing_intro": landing,
		"game_audio": CaptureAudio.new(),
	}
	if not skill_config_key.is_empty() and skill_config != null:
		registry.instances[skill_config_key] = skill_config

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
	shell.set("selected_character_type", character_type)
	shell.set("selected_runtime_character_id", character_type)
	viewport.add_child(shell)

	var result := {"accepted": false, "character_type": character_type}
	if not flow_owner.ensure_run_started(shell, {"run_id": run_id}):
		result["reason"] = "seeded_run_start_failed"
	var prewarm: Dictionary = flow_owner.prewarm_muhon_collection(shell)
	if not bool(prewarm.get("accepted", false)):
		result["reason"] = "run_prewarm_failed"
	elif str(prewarm.get("run_id", "")) != run_id:
		result["reason"] = "run_id_mismatch"
	else:
		shell._process(1.0)
		if not start_card.is_active():
			result["reason"] = "start_card_not_active"
		else:
			var choices := start_card.get_card_choices()
			var chosik_count := _count_kind(choices, "chosik")
			var mugong_count := _count_kind(choices, "mugong")
			var expected_chosik := chosik_count >= 1 and chosik_count <= 2
			if character_type == "blacksmith":
				expected_chosik = chosik_count == 0 and mugong_count == 3
			var mugong_index := _find_kind_index(choices, "mugong")
			var cold_build_msec := start_card.get_cold_build_msec()
			if _has_choice_id(choices, "common_expansion"):
				result["reason"] = "retired_expansion_exposed"
			elif not expected_chosik:
				result["reason"] = "invalid_card_mix"
			elif cold_build_msec > TowerAscentTuning.TEMP_START_CARD_COLD_BUILD_BUDGET_MS:
				result["reason"] = "cold_build_budget_exceeded"
			elif mugong_index < 0:
				result["reason"] = "missing_mugong_choice"
			else:
				var choose_mugong := InputEventKey.new()
				choose_mugong.pressed = true
				choose_mugong.keycode = [KEY_1, KEY_2, KEY_3][mugong_index]
				shell._unhandled_input(choose_mugong)
				shell._process(1.0)
				shell._process(0.1)
				var selection_result := start_card.get_selection_result()
				var picked_id := str(selection_result.get("picked_perk_id", ""))
				var recorded := flow_owner.get_start_card_result()
				if not bool(selection_result.get("accepted", false)):
					result["reason"] = "selection_rejected"
				elif (
					int(runtime_state.runtime_skill_levels.get(picked_id, 0))
					!= TowerAscentTuning.TEMP_START_CARD_MUGONG_START_LEVEL
				):
					result["reason"] = "mugong_level_mismatch"
				elif str(recorded.get("picked_perk_id", "")) != picked_id:
					result["reason"] = "run_progress_mismatch"
				elif landing.begin_calls != 1:
					result["reason"] = "landing_handoff_mismatch"
				elif str(prologue.get("_phase")) == Stage1HanMiryangProloguePresentation.PHASE_ACTIVE:
					result["reason"] = "unexpected_prologue"
				else:
					result = {
						"accepted": true,
						"character_type": character_type,
						"run_id": run_id,
						"chosik_count": chosik_count,
						"mugong_count": mugong_count,
						"picked_perk_id": picked_id,
						"cold_build_msec": cold_build_msec,
					}

	prologue.tear_down()
	start_card.tear_down()
	viewport.remove_child(shell)
	shell.free()
	get_root().remove_child(viewport)
	viewport.free()
	return result


func _run_meridian_expand_fusion_case() -> Dictionary:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["meridian_expand"]},
		catalog
	)
	if record.is_empty():
		return {"accepted": false, "reason": "fusion_commit_failed"}
	if not state.get_perk_fusion_owned_byproduct_ids().has("meridian_expand"):
		return {"accepted": false, "reason": "byproduct_not_owned"}
	if catalog.get_perk_slot_limit(state.runtime_skill_levels, state) != 7:
		return {"accepted": false, "reason": "slot_limit_not_expanded"}
	return {"accepted": true, "fusion_id": str(record.get("fusion_id", ""))}


func _count_kind(choices: Array, kind: String) -> int:
	var count := 0
	for choice_value in choices:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("start_card_kind", "")) == kind:
			count += 1
	return count


func _has_choice_id(choices: Array, perk_id: String) -> bool:
	for choice_value in choices:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("id", "")) == perk_id:
			return true
	return false


func _find_kind_index(choices: Array, kind: String) -> int:
	for index in range(choices.size()):
		if choices[index] is Dictionary and str((choices[index] as Dictionary).get("start_card_kind", "")) == kind:
			return index
	return -1


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
