extends RefCounted

const MODULES := {
	"lingpet_egg_runtime": {
		"path": "res://scripts/lingpet/lingpet_egg_runtime.gd",
		"label": "lingpet egg runtime",
	},
	"lingpet_save_store": {
		"path": "res://scripts/lingpet/lingpet_save_store.gd",
		"label": "lingpet save store",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
