extends RefCounted

const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const StageClearResultRewardPlanBuilder := preload("res://scripts/core/stage_clear_result_reward_plan_builder.gd")
const StageClearResultStageSnapshotBuilder := preload("res://scripts/core/stage_clear_result_stage_snapshot_builder.gd")
const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
const StageClearResultImmediateRewardFlowHandler := preload("res://scripts/core/stage_clear_result_immediate_reward_flow_handler.gd")
const StageClearResultInputFlowHandler := preload("res://scripts/core/stage_clear_result_input_flow_handler.gd")
const StageClearResultPlazaEnterFlowHandler := preload("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
const StageClearResultPlazaProgressHandler := preload("res://scripts/core/stage_clear_result_plaza_progress_handler.gd")
const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const StageClearResultPrewarmFlowHandler := preload("res://scripts/core/stage_clear_result_prewarm_flow_handler.gd")
const StageClearResultRewardGrantHandler := preload("res://scripts/core/stage_clear_result_reward_grant_handler.gd")
const StageClearResultMythicAcquisitionHandler := preload("res://scripts/core/stage_clear_result_mythic_acquisition_handler.gd")
const StageClearResultRuntimeContextHandler := preload("res://scripts/core/stage_clear_result_runtime_context_handler.gd")
const StageClearResultSceneConfigBuilder := preload("res://scripts/core/stage_clear_result_scene_config_builder.gd")
const StageClearResultSceneShellHandler := preload("res://scripts/core/stage_clear_result_scene_shell_handler.gd")
const StageClearResultSceneSpawnFlowHandler := preload("res://scripts/core/stage_clear_result_scene_spawn_flow_handler.gd")
const StageClearResultScreenStatusHandler := preload("res://scripts/core/stage_clear_result_screen_status_handler.gd")
const StageClearResultScreenStateHandler := preload("res://scripts/core/stage_clear_result_screen_state_handler.gd")
const StageClearResultShowFlowHandler := preload("res://scripts/core/stage_clear_result_show_flow_handler.gd")
const StageClearResultStarpointChoiceHandler := preload("res://scripts/core/stage_clear_result_starpoint_choice_handler.gd")
const StageClearResultUpdateFlowHandler := preload("res://scripts/core/stage_clear_result_update_flow_handler.gd")

const FIELD_NAMES := [
	"_reward_plan_builder",
	"_stage_snapshot_builder",
	"_finish_flow_handler",
	"_immediate_reward_flow_handler",
	"_input_flow_handler",
	"_plaza_enter_flow_handler",
	"_prewarm_flow_handler",
	"_reward_grant_handler",
	"_mythic_acquisition_handler",
	"_runtime_context_handler",
	"_scene_config_builder",
	"_scene_shell_handler",
	"_scene_spawn_flow_handler",
	"_screen_status_handler",
	"_screen_state_handler",
	"_show_flow_handler",
	"_starpoint_choice_handler",
	"_update_flow_handler",
	"_plaza_save_store",
	"_plaza_progress_handler",
	"_plaza_scene_handler",
]


func build_services() -> Dictionary:
	return {
		"_reward_plan_builder": StageClearResultRewardPlanBuilder.new(),
		"_stage_snapshot_builder": StageClearResultStageSnapshotBuilder.new(),
		"_finish_flow_handler": StageClearResultFinishFlowHandler.new(),
		"_immediate_reward_flow_handler": StageClearResultImmediateRewardFlowHandler.new(),
		"_input_flow_handler": StageClearResultInputFlowHandler.new(),
		"_plaza_enter_flow_handler": StageClearResultPlazaEnterFlowHandler.new(),
		"_prewarm_flow_handler": StageClearResultPrewarmFlowHandler.new(),
		"_reward_grant_handler": StageClearResultRewardGrantHandler.new(),
		"_mythic_acquisition_handler": StageClearResultMythicAcquisitionHandler.new(),
		"_runtime_context_handler": StageClearResultRuntimeContextHandler.new(),
		"_scene_config_builder": StageClearResultSceneConfigBuilder.new(),
		"_scene_shell_handler": StageClearResultSceneShellHandler.new(),
		"_scene_spawn_flow_handler": StageClearResultSceneSpawnFlowHandler.new(),
		"_screen_status_handler": StageClearResultScreenStatusHandler.new(),
		"_screen_state_handler": StageClearResultScreenStateHandler.new(),
		"_show_flow_handler": StageClearResultShowFlowHandler.new(),
		"_starpoint_choice_handler": StageClearResultStarpointChoiceHandler.new(),
		"_update_flow_handler": StageClearResultUpdateFlowHandler.new(),
		"_plaza_save_store": PlazaSaveStore.new(),
		"_plaza_progress_handler": StageClearResultPlazaProgressHandler.new(),
		"_plaza_scene_handler": StageClearResultPlazaSceneHandler.new(),
	}


func apply_to_screen(screen: Object) -> void:
	if screen == null:
		return
	var services: Dictionary = build_services()
	for field_name in FIELD_NAMES:
		screen.set(str(field_name), services.get(field_name, null))


func get_field_names() -> Array:
	return FIELD_NAMES.duplicate()


func has_service_field(field_name: String) -> bool:
	return FIELD_NAMES.has(field_name)
