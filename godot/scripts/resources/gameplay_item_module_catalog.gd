extends RefCounted

const MODULES := {
	"active_item_runtime": {
		"path": "res://scripts/items/active_item_runtime.gd",
		"label": "active item runtime",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
