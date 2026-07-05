extends RefCounted

const MODULES := {
	"boss_slow_tiers": {
		"path": "res://scripts/status/boss_slow_tiers.gd",
		"label": "boss slow tier constants",
	},
	"status_effect_state": {
		"path": "res://scripts/status/status_effect_state.gd",
		"label": "status effect state",
	},
	"status_effect_overlay_renderer": {
		"path": "res://scripts/status/status_effect_overlay_renderer.gd",
		"label": "status effect overlay renderer",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
