extends RefCounted

const UPDATE_MODULE_KEYS := [
	"battle_frame_flow_controller",
	"battle_frame_flow_deps_builder",
	"battle_scene_actor_update_driver",
	"battle_scene_actor_update_result_applier",
	"battle_scene_player_control_config_builder",
	"battle_scene_item_update_driver",
	"battle_scene_skill_tooltip_driver",
	"battle_scene_runtime_perk_update_driver",
	"battle_scene_scoreboard_update_driver",
	"battle_scene_match_event_driver",
	"battle_scene_boss_health_flow",
	"battle_scene_effects_update_driver",
	"battle_scene_effects_update_result_applier",
	"lingpet_egg_runtime",
	"battle_scene_match_flow_driver",
	"battle_scene_match_reset_result_applier",
	"match_score_event_controller",
	"match_scoreboard_flow_controller",
	"match_round_restart_controller",
	"match_reset_controller",
	"active_item_runtime",
	"boss_ai_state",
	"serve_flow_controller",
	"skill_orb_tooltip_hover_state",
	"commando_firearm_tooltip_renderer",
]
const EFFECTS_CORE_PREWARM_KEYS := [
	"battle_feedback_state",
	"game_audio",
	"match_score_state",
	"scoreboard_state",
	"orb_hud_state",
	"actor_animation_state",
	"impact_effects",
	"ball_effects",
	"player_movement_state",
	"status_effect_state",
	"active_item_runtime",
	"mythic_item_runtime",
	"runtime_perk_state",
	"runtime_perk_catalog",
]
const EFFECTS_COMMON_CHARACTER_PREWARM_KEYS := [
	"runtime_perk_state",
	"dalji_vision_chosik_state",
	"cheongringwi_vision_chosik_state",
	"yeonmyo_vision_chosik_state",
	"monkey_blessing_delivery_state",
]
const EFFECTS_SMASHER_PREWARM_KEYS := [
	"smasher_power_smash_state",
	"smasher_plasma_state",
	"smasher_recovery_state",
	"smasher_cleanse_state",
	"smasher_warp_gate_state",
	"smasher_wheel_state",
	"smasher_overdrive_state",
	"smasher_void_phantom_state",
	"smasher_magnum_grip_state",
	"smasher_dash_spirit_state",
	"smasher_shield_kiting_state",
	"smasher_combo_state",
]
const EFFECTS_VIPER_PREWARM_KEYS := [
	"viper_skill_runtime",
	"viper_jetpack_state",
	"viper_skill_config",
	"viper_skill_state",
]
const EFFECTS_COMMANDO_PREWARM_KEYS := [
	"commando_firearm_runtime",
]
const MATCH_STATE_PREWARM_KEYS := [
	"match_score_state",
	"round_flow_state",
	"scoreboard_state",
	"ball_intensity",
	"victory_highlight_playback_state",
	"victory_highlight_recorder",
	"victory_loot_phase_state",
	"game_audio",
	"match_score_event_controller",
	"match_scoreboard_flow_controller",
	"match_round_restart_controller",
	"match_reset_controller",
]
const MATCH_ITEM_RUNTIME_PREWARM_KEYS := [
	"orb_hud_state",
	"active_item_hud_state",
	"active_item_runtime",
	"mythic_item_runtime",
]
const MATCH_PLAYER_SKILL_COMMON_PREWARM_KEYS := [
	"dalji_vision_chosik_state",
	"cheongringwi_vision_chosik_state",
	"yeonmyo_vision_chosik_state",
	"laurel_leaf_shield_state",
	"monkey_blessing_delivery_state",
	"commando_reload_delivery_state",
	"runtime_perk_state",
]
const MATCH_SMASHER_SKILL_PREWARM_KEYS := [
	"smasher_skill_state",
	"smasher_drive_input_state",
	"smasher_plasma_state",
	"smasher_recovery_state",
	"smasher_cleanse_state",
	"smasher_warp_gate_state",
	"smasher_wheel_state",
	"smasher_overdrive_state",
	"smasher_void_phantom_state",
	"smasher_magnum_grip_state",
	"smasher_dash_spirit_state",
	"smasher_shield_kiting_state",
	"smasher_skill_config",
	"smasher_dash_state",
]
const MATCH_VIPER_SKILL_PREWARM_KEYS := [
	"viper_skill_state",
	"viper_skill_config",
	"viper_skill_runtime",
]
const MATCH_COMMANDO_SKILL_PREWARM_KEYS := [
	"commando_skill_state",
	"commando_skill_config",
	"commando_emergency_supply_state",
	"commando_firearm_runtime",
	"commando_supply_drop_state",
]
const MATCH_OPTIMUS_SKILL_PREWARM_KEYS := [
	"optimus_energy_state",
]
const STAGE_RUNTIME_COMMON_PREWARM_KEYS := [
	"weather_event_state",
	"stage_runtime_router",
]
const STAGE1_RUNTIME_PREWARM_KEYS := [
	"stage1_pillar_background",
	"stage1_dalji_whip_skill_state",
	"stage1_dalji_spinning_top_skill_state",
	"stage1_dalji_boss_skill_cooldown_state",
	"stage1_gaksital_fan_throw_skill_state",
	"stage1_gaksital_fan_wind_skill_state",
	"stage1_gaksital_boss_skill_cooldown_state",
	"stage1_pododaejang_patrol_guards_skill_state",
	"stage1_pododaejang_arrest_rope_skill_state",
	"stage1_pododaejang_boss_skill_cooldown_state",
	"stage1_balloon_event",
]
const STAGE2_RUNTIME_PREWARM_KEYS := [
	"stage2_pillar_background",
	"stage2_boss_skill_state",
	"stage2_monkey_banana_event",
]
const STAGE3_RUNTIME_PREWARM_KEYS := [
	"stage3_pillar_background",
	"stage3_boss_skill_state",
]
const STAGE4_RUNTIME_PREWARM_KEYS := [
	"stage4_pillar_background",
	"stage4_map_state",
	"stage4_temple_destruction_event",
	"stage4_moon_event",
	"stage4_bird_event",
	"stage4_brazier_monk_event",
	"stage4_ponk_skill_state",
]
const STAGE5_RUNTIME_PREWARM_KEYS := [
	"stage5_hongryun_pillar_background",
	"stage5_hongryun_state",
	"stage5_hongryun_fire_machine_event",
]
const STAGE6_RUNTIME_PREWARM_KEYS := [
	"stage6_tetriser_pillar_background",
	"stage6_tetriser_state",
	"stage6_tetriser_boss_skill_hud_renderer",
]
