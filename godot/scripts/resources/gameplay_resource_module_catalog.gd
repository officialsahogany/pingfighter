extends RefCounted

const MODULES := {
	"battle_resources": {
		"path": "res://scripts/resources/battle_resources.gd",
		"label": "battle resources",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
