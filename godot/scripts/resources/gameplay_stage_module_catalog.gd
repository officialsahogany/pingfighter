extends RefCounted

const MODULES := {
	"stage1_fallback_pillar_renderer": {
		"path": "res://scripts/stages/stage1/stage1_fallback_pillar_renderer.gd",
		"label": "stage1 fallback pillar renderer",
	},
	"stage1_actor_renderer": {
		"path": "res://scripts/stages/stage1/stage1_actor_renderer.gd",
		"label": "stage1 actor renderer",
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
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
