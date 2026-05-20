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
	"weather_event_renderer": {
		"path": "res://scripts/stages/common/weather_event_renderer.gd",
		"label": "common weather event renderer",
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
	"stage1_dalji_boss_skill_cooldown_state": {
		"path": "res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd",
		"label": "stage1 Dalji boss skill cooldown state",
	},
	"stage1_dalji_boss_skill_hud_renderer": {
		"path": "res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
		"label": "stage1 Dalji boss skill HUD renderer",
	},
	"stage1_balloon_event": {
		"path": "res://scripts/stages/stage1/stage1_balloon_event.gd",
		"label": "stage1 balloon machine event",
	},
	"stage1_context_reader": {
		"path": "res://scripts/stages/stage1/stage1_context_reader.gd",
		"label": "stage1 context reader",
	},
	"stage1_pillar_background": {
		"path": "res://scripts/stages/stage1/stage1_pillar_background.gd",
		"label": "stage1 pillar background",
	},
	"stage1_pillar_scene_drawer": {
		"path": "res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd",
		"label": "stage1 pillar scene drawer",
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
	"stage5_hongryun_state": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_state.gd",
		"label": "stage5 Hongryun boss state",
	},
	"stage5_hongryun_fire_machine_event": {
		"path": "res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd",
		"label": "stage5 Hongryun fire machine event",
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
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
