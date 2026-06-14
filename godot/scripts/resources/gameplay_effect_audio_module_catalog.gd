extends RefCounted

const MODULES := {
	"game_audio": {
		"path": "res://scripts/audio/game_audio.gd",
		"label": "game audio",
	},
	"battle_feedback_state": {
		"path": "res://scripts/effects/battle_feedback_state.gd",
		"label": "battle feedback state",
	},
	"battle_effects_update_controller": {
		"path": "res://scripts/effects/battle_effects_update_controller.gd",
		"label": "battle effects update controller",
	},
	"impact_effects": {
		"path": "res://scripts/effects/impact_effects.gd",
		"label": "impact effects state",
	},
	"impact_effects_renderer": {
		"path": "res://scripts/effects/impact_effects_renderer.gd",
		"label": "impact effects renderer",
	},
	"impact_effect_payload_factory": {
		"path": "res://scripts/effects/impact_effect_payload_factory.gd",
		"label": "impact effect payload factory",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
