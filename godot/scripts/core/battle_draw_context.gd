extends RefCounted

const BattleDrawSceneContext := preload("res://scripts/core/battle_draw_scene_context.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawBallContext := preload("res://scripts/core/battle_draw_ball_context.gd")
const BattleDrawBannerContext := preload("res://scripts/core/battle_draw_banner_context.gd")

var scene_context: Object = BattleDrawSceneContext.new()
var actor_context: Object = BattleDrawActorContext.new()
var ball_context: Object = BattleDrawBallContext.new()
var banner_context: Object = BattleDrawBannerContext.new()


func build_pillar_scene_context(
	owner: Object,
	view_size: Vector2,
	layout: Dictionary,
	top_mini_score_sparkle_duration: float
) -> Dictionary:
	return scene_context.build_pillar_scene_context(owner, view_size, layout, top_mini_score_sparkle_duration)


func build_pillar_scene_states(registry) -> Dictionary:
	return scene_context.build_pillar_scene_states(registry)


func build_scene_context(owner: Object, shake_offset: Vector2, registry) -> Dictionary:
	return scene_context.build_scene_context(owner, shake_offset, registry)


func build_scene_deps(registry, feedback, power_state) -> Dictionary:
	return scene_context.build_scene_deps(registry, feedback, power_state)


func build_actor_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	return actor_context.build(context, deps)


func build_ball_effects_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	return ball_context.build_effects_context(context, deps)


func build_ball_draw(context: Dictionary, deps: Dictionary) -> Dictionary:
	return ball_context.build_draw(context, deps)


func build_banner_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	return banner_context.build(context, deps)
