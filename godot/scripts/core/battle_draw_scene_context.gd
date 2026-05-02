extends RefCounted

const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const BattleDrawPillarContext := preload("res://scripts/core/battle_draw_pillar_context.gd")

var playfield_context: Object = BattleDrawPlayfieldSceneContext.new()
var pillar_context: Object = BattleDrawPillarContext.new()


func build_pillar_scene_context(
	owner: Object,
	view_size: Vector2,
	layout: Dictionary,
	top_mini_score_sparkle_duration: float
) -> Dictionary:
	return pillar_context.build_scene_context(owner, view_size, layout, top_mini_score_sparkle_duration)


func build_pillar_scene_states(registry) -> Dictionary:
	return pillar_context.build_scene_states(registry)


func build_scene_context(owner: Object, shake_offset: Vector2, registry) -> Dictionary:
	return playfield_context.build(owner, shake_offset, registry)


func build_scene_deps(registry, feedback, power_state) -> Dictionary:
	return {
		"feedback": feedback,
		"animation_state": registry.get_instance("actor_animation_state"),
		"pillar_drawer": registry.get_instance("pillar_orb_drawer"),
		"ball_effects": registry.get_instance("ball_effects"),
		"ball_intensity": registry.get_instance("ball_intensity"),
		"impact_effects": registry.get_instance("impact_effects"),
		"round_state": registry.get_instance("round_flow_state"),
		"power_state": power_state,
	}
