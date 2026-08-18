extends RefCounted

const BOOT_WARMUP_SAMPLE_LABEL_BY_STEP := {
	0: "00_idle",
	1: "01_logo_assets",
	2: "02_texture_resources",
	3: "03_player_resources",
	4: "04_boss_resources",
	5: "05_smasher_skill_icons",
	6: "06_viper_skill_icons",
	7: "07_finalize_texture_cache",
	8: "08_audio_setup",
	9: "09_bgm_prime",
	10: "10_finish_resources",
	11: "11_modules_battle_startup",
	12: "12_modules_item_runtime",
	13: "13_modules_update_runtime",
	14: "14_modules_ball_runtime",
	15: "15_modules_draw_runtime",
	16: "16_stage_intro_resources",
	17: "17_stage_runtime_resources",
	18: "18_stage_clear_result_assets",
	19: "19_initialize_battle",
	20: "20_first_redraw",
}
const STAGE_RUNTIME_COMMON_SAMPLE_LABELS := [
	"00_weather_renderer",
	"01_active_item_runtime",
	"02_mythic_item_runtime_deferred",
	"03_runtime_perk_overlay",
	"04_runtime_perk_debug_deferred",
	"05_character_info_prewarm",
	"06_selected_character",
	"07_ball_update_deps",
	"08_stage_clear_result_deferred",
	"09_lingpet_runtime",
	"10_lingpet_rail_card",
	"11_tower_ascent_runtime",
]
const STAGE1_RUNTIME_SAMPLE_LABELS := [
	"stage1_00_pillar_background",
	"stage1_01_pillar_scene_drawer",
	"stage1_02_balloon_event",
	"stage1_03_boss_skill_hud",
	"stage1_04_commando_firearm",
]
const STAGE2_RUNTIME_SAMPLE_LABELS := [
	"stage2_00_pillar_background",
	"stage2_01_playfield_resources",
	"stage2_02_boss_skill_hud",
	"stage2_03_monkey_event",
]
const STAGE3_RUNTIME_SAMPLE_LABELS := [
	"stage3_00_pillar_background",
	"stage3_01_playfield_resources",
	"stage3_02_boss_skill_hud",
]
const STAGE4_RUNTIME_SAMPLE_LABELS := [
	"stage4_00_pillar_background",
	"stage4_01_playfield_resources",
	"stage4_02_gauge_hud",
	"stage4_03_bird_event",
	"stage4_04_brazier_monk_event",
	"stage4_05_moon_event",
	"stage4_06_ponk_skill_state",
	"stage4_07_boss_skill_hud",
]
const STAGE5_RUNTIME_SAMPLE_LABELS := [
	"stage5_00_pillar_background",
	"stage5_01_actor_renderer",
	"stage5_02_pillar_scene_drawer",
	"stage5_03_boss_skill_hud",
]


static func get_bgm_setup_sample_label(step_index: int) -> String:
	match step_index:
		0:
			return "bgm_00_stage1"
		1:
			return "bgm_01_stage2"
		2:
			return "bgm_02_stage2_alt"
		3:
			return "bgm_03_stage3"
		4:
			return "bgm_04_stage4"
		5:
			return "bgm_05_stage4_phase2"
		6:
			return "bgm_06_stage5"
		7:
			return "bgm_07_finalize"
	return "bgm_%02d" % step_index


static func get_stage_intro_sample_label(step_index: int) -> String:
	match step_index:
		0:
			return "00_landing_intro"
		1:
			return "01_ball_spawn_intro"
	return "done"


static func get_stage_runtime_sample_label(current_stage: int, step_index: int) -> String:
	if step_index >= 0 and step_index < STAGE_RUNTIME_COMMON_SAMPLE_LABELS.size():
		return str(STAGE_RUNTIME_COMMON_SAMPLE_LABELS[step_index])
	var stage_step := step_index - STAGE_RUNTIME_COMMON_SAMPLE_LABELS.size()
	var labels: Array = []
	match current_stage:
		1:
			labels = STAGE1_RUNTIME_SAMPLE_LABELS
		2:
			labels = STAGE2_RUNTIME_SAMPLE_LABELS
		3:
			labels = STAGE3_RUNTIME_SAMPLE_LABELS
		4:
			labels = STAGE4_RUNTIME_SAMPLE_LABELS
		5:
			labels = STAGE5_RUNTIME_SAMPLE_LABELS
	if stage_step >= 0 and stage_step < labels.size():
		return str(labels[stage_step])
	return "stage_%d_pso_prewarmer" % current_stage
