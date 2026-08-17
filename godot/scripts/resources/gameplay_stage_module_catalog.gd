extends RefCounted

const MODULES := {
	"stage_runtime_router": {
		"path": "res://scripts/stages/stage_runtime_router.gd",
		"label": "stage runtime router",
	},
	"weather_event_state": {
		"path": "res://scripts/stages/common/weather_event_state.gd",
		"label": "common weather event state",
	},
	"weather_event_payload_factory": {
		"path": "res://scripts/stages/common/weather_event_payload_factory.gd",
		"label": "common weather event payload factory",
	},
	"weather_event_render_budget": {
		"path": "res://scripts/stages/common/weather_event_render_budget.gd",
		"label": "common weather event render budget",
	},
	"weather_event_renderer": {
		"path": "res://scripts/stages/common/weather_event_renderer.gd",
		"label": "common weather event renderer",
	},
	"starpoint_payload_factory": {
		"path": "res://scripts/stages/common/starpoint_payload_factory.gd",
		"label": "common starpoint payload factory",
	},
	"stage1_han_miryang_prologue_presentation": {
		"path": "res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd",
		"label": "stage1 Han Miryang Araul prologue presentation",
	},
	"stage1_han_miryang_prologue_overlay_host": {
		"path": "res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd",
		"label": "stage1 Han Miryang Araul prologue overlay host",
	},
	"stage1_fallback_pillar_renderer": {
		"path": "res://scripts/stages/stage1/stage1_fallback_pillar_renderer.gd",
		"label": "stage1 fallback pillar renderer",
	},
	"stage1_actor_renderer": {
		"path": "res://scripts/stages/stage1/stage1_actor_renderer.gd",
		"label": "stage1 actor renderer",
	},
	"stage1_dalji_whip_skill_state": {
		"path": "res://scripts/stages/stage1/stage1_dalji_whip_skill_state.gd",
		"label": "stage1 Dalji whip skill state",
	},
	"stage1_dalji_spinning_top_skill_state": {
		"path": "res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd",
		"label": "stage1 Dalji spinning top skill state",
	},
	"stage1_dalji_spinning_top_payload_factory": {
		"path": "res://scripts/stages/stage1/stage1_dalji_spinning_top_payload_factory.gd",
		"label": "stage1 Dalji spinning top payload factory",
	},
	"stage1_dalji_boss_skill_cooldown_state": {
		"path": "res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd",
		"label": "stage1 Dalji boss skill cooldown state",
	},
	"stage1_dalji_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"label": "stage1 Dalji boss skill HUD renderer",
	},
	"stage1_gaksital_fan_throw_skill_state": {
		"path": "res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd",
		"label": "stage1 Gaksital fan throw skill state",
	},
	"stage1_gaksital_fan_wind_skill_state": {
		"path": "res://scripts/stages/stage1/stage1_gaksital_fan_wind_skill_state.gd",
		"label": "stage1 Gaksital fan wind skill state",
	},
	"stage1_gaksital_boss_skill_cooldown_state": {
		"path": "res://scripts/stages/stage1/stage1_gaksital_boss_skill_cooldown_state.gd",
		"label": "stage1 Gaksital boss skill cooldown state",
	},
	"stage1_gaksital_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_renderer.gd",
		"label": "stage1 Gaksital boss skill HUD renderer",
	},
	"stage1_balloon_event": {
		"path": "res://scripts/stages/stage1/stage1_balloon_event.gd",
		"label": "stage1 balloon machine event",
	},
	"stage1_balloon_payload_factory": {
		"path": "res://scripts/stages/stage1/stage1_balloon_payload_factory.gd",
		"label": "stage1 balloon payload factory",
	},
	"stage1_context_reader": {
		"path": "res://scripts/stages/stage1/stage1_context_reader.gd",
		"label": "stage1 context reader",
	},
	"stage1_pillar_background": {
		"path": "res://scripts/stages/stage1/stage1_pillar_background.gd",
		"label": "stage1 pillar background",
	},
	"stage1_pillar_ambient_payload_factory": {
		"path": "res://scripts/stages/stage1/stage1_pillar_ambient_payload_factory.gd",
		"label": "stage1 pillar ambient payload factory",
	},
	"stage1_pillar_petal_payload_factory": {
		"path": "res://scripts/stages/stage1/stage1_pillar_petal_payload_factory.gd",
		"label": "stage1 pillar petal payload factory",
	},
	"stage1_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd",
		"label": "stage1 pillar scene drawer",
	},
	"stage2_actor_renderer": {
		"path": "res://scripts/stages/stage2/stage2_actor_renderer.gd",
		"label": "stage2 actor renderer",
	},
	"stage2_actor_draw_context_builder": {
		"path": "res://scripts/stages/stage2/stage2_actor_draw_context_builder.gd",
		"label": "stage2 actor draw context builder",
	},
	"stage2_imagegen_asset_status_builder": {
		"path": "res://scripts/stages/stage2/stage2_imagegen_asset_status_builder.gd",
		"label": "stage2 imagegen asset status builder",
	},
	"stage2_pillar_background": {
		"path": "res://scripts/stages/stage2/stage2_pillar_background.gd",
		"label": "stage2 pillar background",
	},
	"stage2_perf_logger": {
		"path": "res://scripts/stages/stage2/stage2_perf_logger.gd",
		"label": "stage2 performance logger",
	},
	"stage2_perf_log_snapshot_builder": {
		"path": "res://scripts/stages/stage2/stage2_perf_log_snapshot_builder.gd",
		"label": "stage2 performance log snapshot builder",
	},
	"stage2_collision_geometry": {
		"path": "res://scripts/stages/stage2/stage2_collision_geometry.gd",
		"label": "stage2 collision geometry helper",
	},
	"stage2_playfield_bounds": {
		"path": "res://scripts/stages/stage2/stage2_playfield_bounds.gd",
		"label": "stage2 playfield bounds helper",
	},
	"stage2_pillar_imagegen_renderer": {
		"path": "res://scripts/stages/stage2/stage2_pillar_imagegen_renderer.gd",
		"label": "stage2 pillar imagegen renderer",
	},
	"stage2_pillar_imagegen_assets_builder": {
		"path": "res://scripts/stages/stage2/stage2_pillar_imagegen_assets_builder.gd",
		"label": "stage2 pillar imagegen assets builder",
	},
	"stage2_pillar_obstacle_visual_renderer": {
		"path": "res://scripts/stages/stage2/stage2_pillar_obstacle_visual_renderer.gd",
		"label": "stage2 pillar obstacle visual renderer",
	},
	"stage2_water_cannon_visual_renderer": {
		"path": "res://scripts/stages/stage2/stage2_water_cannon_visual_renderer.gd",
		"label": "stage2 water cannon visual renderer",
	},
	"stage2_water_cannon_visual_state_builder": {
		"path": "res://scripts/stages/stage2/stage2_water_cannon_visual_state_builder.gd",
		"label": "stage2 water cannon visual state builder",
	},
	"stage2_quake_wave_visual_state_builder": {
		"path": "res://scripts/stages/stage2/stage2_quake_wave_visual_state_builder.gd",
		"label": "stage2 quake wave visual state builder",
	},
	"stage2_water_cannon_geometry": {
		"path": "res://scripts/stages/stage2/stage2_water_cannon_geometry.gd",
		"label": "stage2 water cannon geometry helper",
	},
	"stage2_water_trail_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_water_trail_payload_factory.gd",
		"label": "stage2 water trail payload factory",
	},
	"stage2_fragment_hit_flash_state": {
		"path": "res://scripts/stages/stage2/stage2_fragment_hit_flash_state.gd",
		"label": "stage2 fragment hit flash state",
	},
	"stage2_water_fragment_hit_resolver": {
		"path": "res://scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd",
		"label": "stage2 water fragment hit resolver",
	},
	"stage2_water_fragment_hit_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_water_fragment_hit_payload_factory.gd",
		"label": "stage2 water fragment hit payload factory",
	},
	"stage2_water_cannon_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd",
		"label": "stage2 water cannon payload factory",
	},
	"stage2_water_cannon_payload_config_builder": {
		"path": "res://scripts/stages/stage2/stage2_water_cannon_payload_config_builder.gd",
		"label": "stage2 water cannon payload config builder",
	},
	"stage2_warning_visual_renderer": {
		"path": "res://scripts/stages/stage2/stage2_warning_visual_renderer.gd",
		"label": "stage2 warning visual renderer",
	},
	"stage2_skill_warning_state": {
		"path": "res://scripts/stages/stage2/stage2_skill_warning_state.gd",
		"label": "stage2 skill warning state",
	},
	"stage2_screen_overlay_visual_renderer": {
		"path": "res://scripts/stages/stage2/stage2_screen_overlay_visual_renderer.gd",
		"label": "stage2 screen overlay visual renderer",
	},
	"stage2_border_flash_state": {
		"path": "res://scripts/stages/stage2/stage2_border_flash_state.gd",
		"label": "stage2 border flash state",
	},
	"stage2_ambient_visual_renderer": {
		"path": "res://scripts/stages/stage2/stage2_ambient_visual_renderer.gd",
		"label": "stage2 ambient visual renderer",
	},
	"stage2_ambient_visual_snapshot_builder": {
		"path": "res://scripts/stages/stage2/stage2_ambient_visual_snapshot_builder.gd",
		"label": "stage2 ambient visual snapshot builder",
	},
	"stage2_ambient_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_ambient_payload_factory.gd",
		"label": "stage2 ambient payload factory",
	},
	"stage2_ambient_layout_helper": {
		"path": "res://scripts/stages/stage2/stage2_ambient_layout_helper.gd",
		"label": "stage2 ambient layout helper",
	},
	"stage2_rustle_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_rustle_payload_factory.gd",
		"label": "stage2 rustle payload factory",
	},
	"stage2_rustle_snapshot_builder": {
		"path": "res://scripts/stages/stage2/stage2_rustle_snapshot_builder.gd",
		"label": "stage2 rustle snapshot builder",
	},
	"stage2_rock_visual_factory": {
		"path": "res://scripts/stages/stage2/stage2_rock_visual_factory.gd",
		"label": "stage2 rock visual factory",
	},
	"stage2_rock_visual_assets_builder": {
		"path": "res://scripts/stages/stage2/stage2_rock_visual_assets_builder.gd",
		"label": "stage2 rock visual assets builder",
	},
	"stage2_rock_query": {
		"path": "res://scripts/stages/stage2/stage2_rock_query.gd",
		"label": "stage2 rock query helper",
	},
	"stage2_rock_fragment_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_rock_fragment_payload_factory.gd",
		"label": "stage2 rock fragment payload factory",
	},
	"stage2_chaos_absorb_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_chaos_absorb_payload_factory.gd",
		"label": "stage2 chaos absorb payload factory",
	},
	"stage2_rock_fragment_payload_config_builder": {
		"path": "res://scripts/stages/stage2/stage2_rock_fragment_payload_config_builder.gd",
		"label": "stage2 rock fragment payload config builder",
	},
	"stage2_boss_skill_state": {
		"path": "res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd",
		"label": "stage2 boss variant skill state",
	},
	"stage2_boss_ai_context_builder": {
		"path": "res://scripts/stages/stage2/stage2_boss_ai_context_builder.gd",
		"label": "stage2 boss AI context builder",
	},
	"stage2_boss_rage_snapshot_builder": {
		"path": "res://scripts/stages/stage2/stage2_boss_rage_snapshot_builder.gd",
		"label": "stage2 boss rage snapshot builder",
	},
	"stage2_boss_expression_state": {
		"path": "res://scripts/stages/stage2/stage2_boss_expression_state.gd",
		"label": "stage2 boss expression state",
	},
	"stage2_monkey_banana_event": {
		"path": "res://scripts/stages/stage2/stage2_monkey_banana_event.gd",
		"label": "stage2 monkey banana event",
	},
	"stage2_monkey_banana_payload_factory": {
		"path": "res://scripts/stages/stage2/stage2_monkey_banana_payload_factory.gd",
		"label": "stage2 monkey banana payload factory",
	},
	"stage2_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
		"label": "stage2 boss skill HUD renderer",
	},
	"stage2_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd",
		"label": "stage2 pillar scene drawer",
	},
	"stage3_actor_renderer": {
		"path": "res://scripts/stages/stage3/stage3_actor_renderer.gd",
		"label": "stage3 actor renderer",
	},
	"stage3_playfield_renderer": {
		"path": "res://scripts/stages/stage3/stage3_playfield_renderer.gd",
		"label": "stage3 playfield renderer",
	},
	"stage3_boss_skill_state": {
		"path": "res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd",
		"label": "stage3 boss variant skill state",
	},
	"stage3_boss_skill_payload_factory": {
		"path": "res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd",
		"label": "stage3 Menhera boss skill payload factory",
	},
	"stage3_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
		"label": "stage3 Menhera boss skill HUD renderer",
	},
	"stage3_pillar_background": {
		"path": "res://scripts/stages/stage3/stage3_pillar_background.gd",
		"label": "stage3 pillar background",
	},
	"stage3_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd",
		"label": "stage3 pillar scene drawer",
	},
	"stage4_actor_renderer": {
		"path": "res://scripts/stages/stage4/stage4_actor_renderer.gd",
		"label": "stage4 actor renderer",
	},
	"stage4_playfield_renderer": {
		"path": "res://scripts/stages/stage4/stage4_playfield_renderer.gd",
		"label": "stage4 playfield renderer",
	},
	"stage4_ponk_boss_actor_renderer": {
		"path": "res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd",
		"label": "stage4 Ponk boss actor renderer",
	},
	"stage4_pillar_background": {
		"path": "res://scripts/stages/stage4/stage4_pillar_background.gd",
		"label": "stage4 pillar background",
	},
	"stage4_pillar_background_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_pillar_background_payload_factory.gd",
		"label": "stage4 pillar background payload factory",
	},
	"stage4_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage4/stage4_pillar_scene_drawer.gd",
		"label": "stage4 pillar scene drawer",
	},
	"stage4_map_state": {
		"path": "res://scripts/stages/stage4/stage4_map_state.gd",
		"label": "stage4 map state",
	},
	"stage4_temple_destruction_event": {
		"path": "res://scripts/stages/stage4/stage4_temple_destruction_event.gd",
		"label": "stage4 temple destruction event",
	},
	"stage4_destruction_wave_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_destruction_wave_payload_factory.gd",
		"label": "stage4 destruction wave payload factory",
	},
	"stage4_temple_collapse_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_temple_collapse_payload_factory.gd",
		"label": "stage4 temple collapse payload factory",
	},
	"stage4_moon_event": {
		"path": "res://scripts/stages/stage4/stage4_moon_event.gd",
		"label": "stage4 moon event",
	},
	"stage4_moon_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_moon_payload_factory.gd",
		"label": "stage4 moon payload factory",
	},
	"stage4_bird_event": {
		"path": "res://scripts/stages/stage4/stage4_bird_event.gd",
		"label": "stage4 star bird event",
	},
	"stage4_bird_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_bird_payload_factory.gd",
		"label": "stage4 star bird payload factory",
	},
	"stage4_brazier_monk_event": {
		"path": "res://scripts/stages/stage4/stage4_brazier_monk_event.gd",
		"label": "stage4 brazier monk event",
	},
	"stage4_brazier_monk_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_brazier_monk_payload_factory.gd",
		"label": "stage4 brazier monk payload factory",
	},
	"stage4_ponk_skill_state": {
		"path": "res://scripts/stages/stage4/stage4_ponk_skill_state.gd",
		"label": "stage4 Ponk skill state",
	},
	"stage4_ponk_skill_payload_factory": {
		"path": "res://scripts/stages/stage4/stage4_ponk_skill_payload_factory.gd",
		"label": "stage4 Ponk skill payload factory",
	},
	"stage5_hongryun_actor_renderer": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_actor_renderer.gd",
		"label": "stage5 Hongryun actor renderer",
	},
	"stage5_hongryun_playfield_renderer": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd",
		"label": "stage5 Hongryun playfield renderer",
	},
	"stage5_hongryun_boss_actor_renderer": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_boss_actor_renderer.gd",
		"label": "stage5 Hongryun boss actor renderer",
	},
	"stage5_hongryun_pillar_background": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_pillar_background.gd",
		"label": "stage5 Hongryun pillar background",
	},
	"stage5_hongryun_pillar_background_payload_factory": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_pillar_background_payload_factory.gd",
		"label": "stage5 Hongryun pillar background payload factory",
	},
	"stage5_hongryun_state": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_state.gd",
		"label": "stage5 Hongryun boss state",
	},
	"stage5_hongryun_payload_factory": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_payload_factory.gd",
		"label": "stage5 Hongryun payload factory",
	},
	"stage5_hongryun_fire_machine_event": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd",
		"label": "stage5 Hongryun fire machine event",
	},
	"stage5_hongryun_fire_machine_payload_factory": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_fire_machine_payload_factory.gd",
		"label": "stage5 Hongryun fire machine payload factory",
	},
	"stage5_hongryun_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd",
		"label": "stage5 Hongryun pillar scene drawer",
	},
	"stage5_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage5/stage5_pillar_scene_drawer.gd",
		"label": "stage5 Hongryun pillar scene drawer",
	},
	"stage5_hongryun_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
		"label": "stage5 Hongryun boss skill HUD renderer",
	},
	"stage4_ponk_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
		"label": "stage4 Ponk boss skill HUD renderer",
	},
	"stage4_ponk_gauge_hud_renderer": {
		"path": "res://scripts/stages/stage4/stage4_ponk_gauge_hud_renderer.gd",
		"label": "stage4 Ponk gauge HUD renderer",
	},
	"stage6_tetriser_state": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_state.gd",
		"label": "stage6 Tetriser boss state",
	},
	"stage6_tetriser_actor_renderer": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_actor_renderer.gd",
		"label": "stage6 Tetriser actor renderer",
	},
	"stage6_tetriser_boss_actor_renderer": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_boss_actor_renderer.gd",
		"label": "stage6 Tetriser boss actor renderer",
	},
	"stage6_tetriser_playfield_renderer": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_playfield_renderer.gd",
		"label": "stage6 Tetriser playfield renderer",
	},
	"stage6_tetriser_pillar_background": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_pillar_background.gd",
		"label": "stage6 Tetriser pillar background",
	},
	"stage6_tetriser_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd",
		"label": "stage6 Tetriser pillar scene drawer",
	},
	"stage6_tetriser_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd",
		"label": "stage6 Tetriser boss skill HUD renderer",
	},
	"stage7_akamu_state": {
		"path": "res://scripts/stages/stage7/stage7_akamu_state.gd",
		"label": "stage7 Akamu boss state",
	},
	"stage7_akamu_actor_renderer": {
		"path": "res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd",
		"label": "stage7 Akamu actor renderer",
	},
	"stage7_akamu_boss_actor_renderer": {
		"path": "res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd",
		"label": "stage7 Akamu boss actor renderer",
	},
	"stage7_akamu_playfield_renderer": {
		"path": "res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd",
		"label": "stage7 Akamu playfield renderer",
	},
	"stage7_akamu_pillar_background": {
		"path": "res://scripts/stages/stage7/stage7_akamu_pillar_background.gd",
		"label": "stage7 Akamu pillar background",
	},
	"stage7_akamu_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage7/stage7_akamu_pillar_scene_drawer.gd",
		"label": "stage7 Akamu pillar scene drawer",
	},
	"stage7_akamu_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd",
		"label": "stage7 Akamu boss skill HUD renderer",
	},
	"stage7_akamu_prebattle_presentation": {
		"path": "res://scripts/stages/stage7/stage7_akamu_prebattle_presentation.gd",
		"label": "stage7 Akamu prebattle presentation",
	},
	"stage7_akamu_prebattle_overlay_host": {
		"path": "res://scripts/stages/stage7/stage7_akamu_prebattle_overlay_host.gd",
		"label": "stage7 Akamu prebattle overlay host",
	},
	"stage7_akamu_vfx_texture_cache": {
		"path": "res://scripts/stages/stage7/stage7_akamu_vfx_texture_cache.gd",
		"label": "stage7 Akamu VFX texture cache",
	},
	"stage7_akamu_boss_skill_hud_assets": {
		"path": "res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_assets.gd",
		"label": "stage7 Akamu boss skill HUD assets",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
