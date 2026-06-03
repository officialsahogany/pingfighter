extends RefCounted

const DEFAULT_STAGE_ID := 1

const STAGE_MODULES := {
	1: {
		"actor_renderer": "stage1_actor_renderer",
		"pillar_scene_drawer": "stage1_pillar_scene_drawer",
		"stage_background": "stage1_pillar_background",
	},
	2: {
		"actor_renderer": "stage2_actor_renderer",
		"pillar_scene_drawer": "stage2_pillar_scene_drawer",
		"stage_background": "stage2_pillar_background",
	},
	3: {
		"actor_renderer": "stage3_actor_renderer",
		"pillar_scene_drawer": "stage3_pillar_scene_drawer",
		"stage_background": "stage3_pillar_background",
	},
	4: {
		"actor_renderer": "stage4_actor_renderer",
		"pillar_scene_drawer": "stage4_pillar_scene_drawer",
		"stage_background": "stage4_pillar_background",
	},
	5: {
		"actor_renderer": "stage5_hongryun_actor_renderer",
		"boss_actor_renderer": "stage5_hongryun_boss_actor_renderer",
		"pillar_scene_drawer": "stage5_hongryun_pillar_scene_drawer",
		"stage_background": "stage5_hongryun_pillar_background",
		"playfield_renderer": "stage5_hongryun_playfield_renderer",
		"boss_skill_hud_renderer": "stage5_hongryun_boss_skill_hud_renderer",
	},
	6: {
		"actor_renderer": "stage6_tetriser_actor_renderer",
		"boss_actor_renderer": "stage6_tetriser_boss_actor_renderer",
		"pillar_scene_drawer": "stage6_tetriser_pillar_scene_drawer",
		"stage_background": "stage6_tetriser_pillar_background",
		"playfield_renderer": "stage6_tetriser_playfield_renderer",
		"boss_skill_hud_renderer": "stage6_tetriser_boss_skill_hud_renderer",
	},
}


func get_module_key(stage: int, role: String) -> String:
	var modules: Dictionary = STAGE_MODULES.get(stage, STAGE_MODULES[DEFAULT_STAGE_ID])
	return str(modules.get(role, ""))


func get_instance(registry: Object, stage: int, role: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var key: String = get_module_key(stage, role)
	if key == "":
		return null
	var module: Variant = registry.get_instance(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null
