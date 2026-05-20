extends RefCounted

const MODULES := {
	"battle_scene_bootstrap": {
		"path": "res://scripts/core/battle_scene_bootstrap.gd",
		"label": "battle scene bootstrap",
	},
	"battle_scene_lifecycle": {
		"path": "res://scripts/core/battle_scene_lifecycle.gd",
		"label": "battle scene lifecycle",
	},
	"battle_scene_modal_gate_controller": {
		"path": "res://scripts/core/battle_scene_modal_gate_controller.gd",
		"label": "battle scene modal gate controller",
	},
	"battle_scene_overlay_input_controller": {
		"path": "res://scripts/core/battle_scene_overlay_input_controller.gd",
		"label": "battle scene overlay input controller",
	},
	"weather_debug_picker": {
		"path": "res://scripts/core/weather_debug_picker.gd",
		"label": "weather debug picker",
	},
	"penguin_logo_intro": {
		"path": "res://scripts/core/penguin_logo_intro.gd",
		"label": "penguin logo intro",
	},
	"stage_landing_intro": {
		"path": "res://scripts/core/stage_landing_intro.gd",
		"label": "stage landing intro",
	},
	"battle_scene_config": {
		"path": "res://scripts/core/battle_scene_config.gd",
		"label": "battle scene config",
	},
	"battle_scene_owner_reader": {
		"path": "res://scripts/core/battle_scene_owner_reader.gd",
		"label": "battle scene owner reader",
	},
	"battle_context_reader": {
		"path": "res://scripts/core/battle_context_reader.gd",
		"label": "battle context reader",
	},
	"battle_scene_api": {
		"path": "res://scripts/core/battle_scene_api.gd",
		"label": "battle scene api",
	},
	"battle_scene_state": {
		"path": "res://scripts/core/battle_scene_state.gd",
		"label": "battle scene state",
	},
	"battle_frame_flow_controller": {
		"path": "res://scripts/core/battle_frame_flow_controller.gd",
		"label": "battle frame flow controller",
	},
	"serve_flow_controller": {
		"path": "res://scripts/core/serve_flow_controller.gd",
		"label": "serve flow controller",
	},
	"battle_scene_drawer": {
		"path": "res://scripts/core/battle_scene_drawer.gd",
		"label": "battle scene drawer",
	},
	"battle_scene_pillar_draw_pass": {
		"path": "res://scripts/core/battle_scene_pillar_draw_pass.gd",
		"label": "battle scene pillar draw pass",
	},
	"battle_playfield_scene_drawer": {
		"path": "res://scripts/core/battle_playfield_scene_drawer.gd",
		"label": "battle playfield scene drawer",
	},
	"battle_perf_logger": {
		"path": "res://scripts/core/battle_perf_logger.gd",
		"label": "battle performance logger",
	},
	"battle_boot_resource_prewarm_controller": {
		"path": "res://scripts/core/battle_boot_resource_prewarm_controller.gd",
		"label": "battle boot resource prewarm controller",
	},
	"battle_scene_update_driver": {
		"path": "res://scripts/core/battle_scene_update_driver.gd",
		"label": "battle scene update driver",
	},
	"battle_scene_actor_update_driver": {
		"path": "res://scripts/core/battle_scene_actor_update_driver.gd",
		"label": "battle scene actor update driver",
	},
	"battle_scene_weather_update_driver": {
		"path": "res://scripts/core/battle_scene_weather_update_driver.gd",
		"label": "battle scene weather update driver",
	},
	"battle_scene_ball_update_driver": {
		"path": "res://scripts/core/battle_scene_ball_update_driver.gd",
		"label": "battle scene ball update driver",
	},
	"battle_view_layout": {
		"path": "res://scripts/core/battle_view_layout.gd",
		"label": "battle view layout",
	},
	"battle_draw_context": {
		"path": "res://scripts/core/battle_draw_context.gd",
		"label": "battle draw context",
	},
	"battle_update_context": {
		"path": "res://scripts/core/battle_update_context.gd",
		"label": "battle update context",
	},
	"match_score_state": {
		"path": "res://scripts/core/match_score_state.gd",
		"label": "match score state",
	},
	"match_flow_controller": {
		"path": "res://scripts/core/match_flow_controller.gd",
		"label": "match flow controller",
	},
	"round_flow_state": {
		"path": "res://scripts/core/round_flow_state.gd",
		"label": "round flow state",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
