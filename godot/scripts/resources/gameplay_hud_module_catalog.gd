extends RefCounted

const MODULES := {
	"scoreboard_state": {
		"path": "res://scripts/hud/scoreboard_state.gd",
		"label": "scoreboard state",
	},
	"scoreboard_renderer": {
		"path": "res://scripts/hud/scoreboard_renderer.gd",
		"label": "scoreboard renderer",
	},
	"serve_wait_indicator_renderer": {
		"path": "res://scripts/hud/serve_wait_indicator_renderer.gd",
		"label": "serve wait indicator renderer",
	},
	"orb_hud_state": {
		"path": "res://scripts/hud/orb_hud_state.gd",
		"label": "orb HUD state",
	},
	"pillar_orb_drawer": {
		"path": "res://scripts/hud/pillar_orb_drawer.gd",
		"label": "pillar orb drawer",
	},
	"pillar_status_orb_renderer": {
		"path": "res://scripts/hud/pillar_status_orb_renderer.gd",
		"label": "pillar status orb renderer",
	},
	"stage1_pillar_ui_renderer": {
		"path": "res://scripts/hud/stage1_pillar_ui_renderer.gd",
		"label": "stage1 pillar ui renderer",
	},
	"stage1_pillar_ui_layout": {
		"path": "res://scripts/hud/stage1_pillar_ui_layout.gd",
		"label": "stage1 pillar ui layout",
	},
	"stage1_pillar_status_orb_context_builder": {
		"path": "res://scripts/hud/stage1_pillar_status_orb_context_builder.gd",
		"label": "stage1 pillar status orb context builder",
	},
	"active_item_hud_state": {
		"path": "res://scripts/hud/active_item_hud_state.gd",
		"label": "active item HUD state",
	},
	"active_item_hud_layout": {
		"path": "res://scripts/hud/active_item_hud_layout.gd",
		"label": "active item HUD layout",
	},
	"active_item_hud_visuals": {
		"path": "res://scripts/hud/active_item_hud_visuals.gd",
		"label": "active item HUD visuals",
	},
	"active_item_hud_renderer": {
		"path": "res://scripts/hud/active_item_hud_renderer.gd",
		"label": "active item HUD renderer",
	},
	"smasher_skill_orb_renderer": {
		"path": "res://scripts/hud/smasher_skill_orb_renderer.gd",
		"label": "smasher skill orb renderer",
	},
	"smasher_skill_orb_tooltip_renderer": {
		"path": "res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd",
		"label": "smasher skill orb tooltip renderer",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
