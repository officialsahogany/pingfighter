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
	"battle_scene_startup_controller": {
		"path": "res://scripts/core/battle_scene_startup_controller.gd",
		"label": "battle scene startup controller",
	},
	"battle_scene_flow_controller": {
		"path": "res://scripts/core/battle_scene_flow_controller.gd",
		"label": "battle scene flow controller",
	},
	"battle_scene_readiness_controller": {
		"path": "res://scripts/core/battle_scene_readiness_controller.gd",
		"label": "battle scene readiness controller",
	},
	"battle_scene_modal_gate_controller": {
		"path": "res://scripts/core/battle_scene_modal_gate_controller.gd",
		"label": "battle scene modal gate controller",
	},
	"battle_boot_warmup_controller": {
		"path": "res://scripts/core/battle_boot_warmup_controller.gd",
		"label": "battle boot warmup controller",
	},
	"battle_boot_warmup_plan": {
		"path": "res://scripts/core/battle_boot_warmup_plan.gd",
		"label": "battle boot warmup plan",
	},
	"battle_boot_resource_prewarm_controller": {
		"path": "res://scripts/core/battle_boot_resource_prewarm_controller.gd",
		"label": "battle boot resource prewarm controller",
	},
	"battle_mobile_touch_controller": {
		"path": "res://scripts/core/battle_mobile_touch_controller.gd",
		"label": "battle mobile touch controller",
	},
	"gamepad_input": {
		"path": "res://scripts/core/gamepad_input.gd",
		"label": "gamepad input helper",
	},
	"gamepad_vibration_settings": {
		"path": "res://scripts/core/gamepad_vibration_settings.gd",
		"label": "gamepad vibration settings",
	},
	"battle_scene_input_controller": {
		"path": "res://scripts/core/battle_scene_input_controller.gd",
		"label": "battle scene input controller",
	},
	"battle_scene_intro_input_controller": {
		"path": "res://scripts/core/battle_scene_intro_input_controller.gd",
		"label": "battle scene intro input controller",
	},
	"battle_scene_overlay_input_controller": {
		"path": "res://scripts/core/battle_scene_overlay_input_controller.gd",
		"label": "battle scene overlay input controller",
	},
	"battle_scene_frame_controller": {
		"path": "res://scripts/core/battle_scene_frame_controller.gd",
		"label": "battle scene frame controller",
	},
	"battle_scene_intro_frame_controller": {
		"path": "res://scripts/core/battle_scene_intro_frame_controller.gd",
		"label": "battle scene intro frame controller",
	},
	"battle_loading_screen_renderer": {
		"path": "res://scripts/core/battle_loading_screen_renderer.gd",
		"label": "battle loading screen renderer",
	},
	"battle_scene_overlay_frame_controller": {
		"path": "res://scripts/core/battle_scene_overlay_frame_controller.gd",
		"label": "battle scene overlay frame controller",
	},
	"character_debug_picker": {
		"path": "res://scripts/core/character_debug_picker.gd",
		"label": "character debug picker",
	},
	"stage_debug_picker": {
		"path": "res://scripts/core/stage_debug_picker.gd",
		"label": "stage debug picker",
	},
	"weather_debug_picker": {
		"path": "res://scripts/core/weather_debug_picker.gd",
		"label": "weather debug picker",
	},
	"lingpet_debug_picker": {
		"path": "res://scripts/core/lingpet_debug_picker.gd",
		"label": "lingpet debug picker",
	},
	"penguin_logo_intro": {
		"path": "res://scripts/core/penguin_logo_intro.gd",
		"label": "penguin logo intro",
	},
	"stage_landing_intro": {
		"path": "res://scripts/core/stage_landing_intro.gd",
		"label": "stage landing intro",
	},
	"stage_ball_spawn_intro": {
		"path": "res://scripts/core/stage_ball_spawn_intro.gd",
		"label": "stage ball spawn intro",
	},
	"stage_clear_result_screen": {
		"path": "res://scripts/core/stage_clear_result_screen.gd",
		"label": "stage clear result screen",
	},
	"defeat_chance_gems_continue_screen": {
		"path": "res://scripts/core/defeat_chance_gems_continue_screen.gd",
		"label": "defeat chance gems continue screen",
	},
	"defeat_continue_revival_beat_state": {
		"path": "res://scripts/core/defeat_continue_revival_beat_state.gd",
		"label": "defeat continue revival beat state",
	},
	"defeat_settlement_screen": {
		"path": "res://scripts/core/defeat_settlement_screen.gd",
		"label": "defeat settlement screen",
	},
	"plaza_save_store": {
		"path": "res://scripts/plaza/plaza_save_store.gd",
		"label": "plaza save store",
	},
	"stage_clear_reward_resolver": {
		"path": "res://scripts/core/stage_clear_reward_resolver.gd",
		"label": "stage clear reward resolver",
	},
	"stage_ball_spawn_intro_atmosphere_renderer": {
		"path": "res://scripts/core/stage_ball_spawn_intro_atmosphere_renderer.gd",
		"label": "stage ball spawn intro atmosphere renderer",
	},
	"stage_ball_spawn_intro_ball_state": {
		"path": "res://scripts/core/stage_ball_spawn_intro_ball_state.gd",
		"label": "stage ball spawn intro ball state",
	},
	"stage_ball_spawn_intro_ball_renderer": {
		"path": "res://scripts/core/stage_ball_spawn_intro_ball_renderer.gd",
		"label": "stage ball spawn intro ball renderer",
	},
	"stage_ball_spawn_intro_effect_factory": {
		"path": "res://scripts/core/stage_ball_spawn_intro_effect_factory.gd",
		"label": "stage ball spawn intro effect factory",
	},
	"stage_ball_spawn_intro_effect_renderer": {
		"path": "res://scripts/core/stage_ball_spawn_intro_effect_renderer.gd",
		"label": "stage ball spawn intro effect renderer",
	},
	"stage_ball_spawn_intro_effect_updater": {
		"path": "res://scripts/core/stage_ball_spawn_intro_effect_updater.gd",
		"label": "stage ball spawn intro effect updater",
	},
	"stage_ball_spawn_intro_texture_cache": {
		"path": "res://scripts/core/stage_ball_spawn_intro_texture_cache.gd",
		"label": "stage ball spawn intro texture cache",
	},
	"stage_ball_spawn_intro_fx_host": {
		"path": "res://scripts/core/stage_ball_spawn_intro_fx_host.gd",
		"label": "stage ball spawn intro fx host",
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
	"victory_loot_phase_state": {
		"path": "res://scripts/core/victory_loot_phase_state.gd",
		"label": "victory loot phase state",
	},
	"tower_ascent_flow_owner": {
		"path": "res://scripts/tower_ascent/tower_ascent_flow_owner.gd",
		"label": "tower ascent run-map flow owner",
	},
	"victory_highlight_recorder": {
		"path": "res://scripts/core/victory_highlight_recorder.gd",
		"label": "victory highlight recorder",
	},
	"victory_highlight_actor_resolver": {
		"path": "res://scripts/core/victory_highlight_actor_resolver.gd",
		"label": "victory highlight actor resolver",
	},
	"victory_highlight_playback_state": {
		"path": "res://scripts/core/victory_highlight_playback_state.gd",
		"label": "victory highlight playback state",
	},
	"victory_highlight_renderer": {
		"path": "res://scripts/core/victory_highlight_renderer.gd",
		"label": "victory highlight renderer",
	},
	"battle_frame_flow_deps_builder": {
		"path": "res://scripts/core/battle_frame_flow_deps_builder.gd",
		"label": "battle frame flow deps builder",
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
	"battle_scene_update_driver": {
		"path": "res://scripts/core/battle_scene_update_driver.gd",
		"label": "battle scene update driver",
	},
	"battle_scene_update_prewarm_driver": {
		"path": "res://scripts/core/battle_scene_update_prewarm_driver.gd",
		"label": "battle scene update prewarm driver",
	},
	"battle_scene_actor_update_driver": {
		"path": "res://scripts/core/battle_scene_actor_update_driver.gd",
		"label": "battle scene actor update driver",
	},
	"battle_scene_actor_update_result_applier": {
		"path": "res://scripts/core/battle_scene_actor_update_result_applier.gd",
		"label": "battle scene actor update result applier",
	},
	"battle_scene_player_control_config_builder": {
		"path": "res://scripts/core/battle_scene_player_control_config_builder.gd",
		"label": "battle scene player control config builder",
	},
	"battle_scene_item_update_driver": {
		"path": "res://scripts/core/battle_scene_item_update_driver.gd",
		"label": "battle scene item update driver",
	},
	"battle_scene_weather_update_driver": {
		"path": "res://scripts/core/battle_scene_weather_update_driver.gd",
		"label": "battle scene weather update driver",
	},
	"battle_scene_skill_tooltip_driver": {
		"path": "res://scripts/core/battle_scene_skill_tooltip_driver.gd",
		"label": "battle scene skill tooltip driver",
	},
	"battle_scene_runtime_perk_update_driver": {
		"path": "res://scripts/core/battle_scene_runtime_perk_update_driver.gd",
		"label": "battle scene runtime perk update driver",
	},
	"battle_scene_scoreboard_update_driver": {
		"path": "res://scripts/core/battle_scene_scoreboard_update_driver.gd",
		"label": "battle scene scoreboard update driver",
	},
	"battle_scene_match_event_driver": {
		"path": "res://scripts/core/battle_scene_match_event_driver.gd",
		"label": "battle scene match event driver",
	},
	"battle_scene_effects_update_driver": {
		"path": "res://scripts/core/battle_scene_effects_update_driver.gd",
		"label": "battle scene effects update driver",
	},
	"battle_scene_effects_update_result_applier": {
		"path": "res://scripts/core/battle_scene_effects_update_result_applier.gd",
		"label": "battle scene effects update result applier",
	},
	"battle_scene_boss_health_flow": {
		"path": "res://scripts/core/battle_scene_boss_health_flow.gd",
		"label": "battle scene boss health flow",
	},
	"battle_scene_match_flow_driver": {
		"path": "res://scripts/core/battle_scene_match_flow_driver.gd",
		"label": "battle scene match flow driver",
	},
	"battle_scene_match_reset_result_applier": {
		"path": "res://scripts/core/battle_scene_match_reset_result_applier.gd",
		"label": "battle scene match reset result applier",
	},
	"battle_scene_ball_update_driver": {
		"path": "res://scripts/core/battle_scene_ball_update_driver.gd",
		"label": "battle scene ball update driver",
	},
	"battle_view_layout": {
		"path": "res://scripts/core/battle_view_layout.gd",
		"label": "battle view layout",
	},
	"mobile_touch_controls": {
		"path": "res://scripts/core/mobile_touch_controls.gd",
		"label": "mobile touch controls",
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
	"match_score_event_controller": {
		"path": "res://scripts/core/match_score_event_controller.gd",
		"label": "match score event controller",
	},
	"match_scoreboard_flow_controller": {
		"path": "res://scripts/core/match_scoreboard_flow_controller.gd",
		"label": "match scoreboard flow controller",
	},
	"match_round_restart_controller": {
		"path": "res://scripts/core/match_round_restart_controller.gd",
		"label": "match round restart controller",
	},
	"match_reset_controller": {
		"path": "res://scripts/core/match_reset_controller.gd",
		"label": "match reset controller",
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
