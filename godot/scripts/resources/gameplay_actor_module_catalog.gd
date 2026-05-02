extends RefCounted

const MODULES := {
	"smasher_combo_state": {
		"path": "res://scripts/characters/smasher_combo_state.gd",
		"label": "smasher combo state",
	},
	"smasher_combo_renderer": {
		"path": "res://scripts/characters/smasher_combo_renderer.gd",
		"label": "smasher combo renderer",
	},
	"smasher_skill_state": {
		"path": "res://scripts/characters/smasher_skill_state.gd",
		"label": "smasher skill state",
	},
	"smasher_player_controller": {
		"path": "res://scripts/characters/smasher_player_controller.gd",
		"label": "smasher player controller",
	},
	"smasher_input_reader": {
		"path": "res://scripts/characters/smasher_input_reader.gd",
		"label": "smasher input reader",
	},
	"smasher_drive_input_state": {
		"path": "res://scripts/characters/smasher_drive_input_state.gd",
		"label": "smasher drive input state",
	},
	"smasher_drive_activation_controller": {
		"path": "res://scripts/characters/smasher_drive_activation_controller.gd",
		"label": "smasher drive activation controller",
	},
	"smasher_drive_bounce_state": {
		"path": "res://scripts/characters/smasher_drive_bounce_state.gd",
		"label": "smasher drive bounce state",
	},
	"smasher_drive_counter_state": {
		"path": "res://scripts/characters/smasher_drive_counter_state.gd",
		"label": "smasher drive counter state",
	},
	"smasher_power_smash_state": {
		"path": "res://scripts/characters/smasher_power_smash_state.gd",
		"label": "smasher power smash state",
	},
	"smasher_power_smash_activation_controller": {
		"path": "res://scripts/characters/smasher_power_smash_activation_controller.gd",
		"label": "smasher power smash activation controller",
	},
	"smasher_power_smash_motion_controller": {
		"path": "res://scripts/characters/smasher_power_smash_motion_controller.gd",
		"label": "smasher power smash motion controller",
	},
	"smasher_skill_feedback_renderer": {
		"path": "res://scripts/characters/smasher_skill_feedback_renderer.gd",
		"label": "smasher skill feedback renderer",
	},
	"actor_animation_state": {
		"path": "res://scripts/characters/actor_animation_state.gd",
		"label": "actor animation state",
	},
	"boss_ai_state": {
		"path": "res://scripts/ai/boss_ai_state.gd",
		"label": "boss ai state",
	},
	"smasher_dash_state": {
		"path": "res://scripts/characters/smasher_dash_state.gd",
		"label": "smasher dash state",
	},
	"smasher_skill_config": {
		"path": "res://scripts/characters/smasher_skill_config.gd",
		"label": "smasher skill config",
	},
	"player_movement_state": {
		"path": "res://scripts/characters/player_movement_state.gd",
		"label": "player movement state",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
