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
	"horizontal_timer_gauge_stack": {
		"path": "res://scripts/hud/horizontal_timer_gauge_stack.gd",
		"label": "horizontal timer gauge stack",
	},
	"smasher_skill_orb_renderer": {
		"path": "res://scripts/hud/smasher_skill_orb_renderer.gd",
		"label": "smasher skill orb renderer",
	},
	"smasher_skill_orb_tooltip_renderer": {
		"path": "res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd",
		"label": "smasher skill orb tooltip renderer",
	},
	"skill_orb_tooltip_effect_preview_renderer": {
		"path": "res://scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd",
		"label": "skill orb tooltip effect preview renderer",
	},
	"commando_firearm_selector_renderer": {
		"path": "res://scripts/hud/commando_firearm_selector_renderer.gd",
		"label": "commando firearm selector renderer",
	},
	"commando_firearm_tooltip_renderer": {
		"path": "res://scripts/hud/commando_firearm_tooltip_renderer.gd",
		"label": "commando firearm tooltip renderer",
	},
	"skill_orb_tooltip_overlay_host": {
		"path": "res://scripts/hud/skill_orb_tooltip_overlay_host.gd",
		"label": "skill orb tooltip overlay host",
	},
	"skill_orb_tooltip_hover_state": {
		"path": "res://scripts/hud/skill_orb_tooltip_hover_state.gd",
		"label": "skill orb tooltip hover state",
	},
	"runtime_perk_overlay_renderer": {
		"path": "res://scripts/hud/runtime_perk_overlay_renderer.gd",
		"label": "runtime perk overlay renderer",
	},
	"runtime_perk_icon_renderer": {
		"path": "res://scripts/hud/runtime_perk_icon_renderer.gd",
		"label": "runtime perk icon renderer",
	},
	"runtime_perk_debug_picker": {
		"path": "res://scripts/hud/runtime_perk_debug_picker.gd",
		"label": "runtime perk debug picker",
	},
	"character_info_overlay": {
		"path": "res://scripts/hud/character_info_overlay.gd",
		"label": "character info overlay",
	},
	"pause_menu_overlay": {
		"path": "res://scripts/hud/pause_menu_overlay.gd",
		"label": "pause menu overlay",
	},
	"ball_speed_debug_overlay": {
		"path": "res://scripts/hud/ball_speed_debug_overlay.gd",
		"label": "ball speed debug overlay",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
