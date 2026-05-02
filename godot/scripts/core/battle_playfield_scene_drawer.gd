extends RefCounted

const BattlePlayfieldBallDrawer := preload("res://scripts/core/battle_playfield_ball_drawer.gd")
const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const BattlePlayfieldOverlayDrawer := preload("res://scripts/core/battle_playfield_overlay_drawer.gd")

var ball_drawer: Object = BattlePlayfieldBallDrawer.new()
var effects_drawer: Object = BattlePlayfieldEffectsDrawer.new()
var overlay_drawer: Object = BattlePlayfieldOverlayDrawer.new()


func draw(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	width: float,
	height: float,
	pillar_width: float
) -> void:
	if canvas == null or registry == null:
		return
	var draw_context_builder: Object = _get_instance(registry, "battle_draw_context")
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	var power_state: Object = _get_instance(registry, "smasher_power_smash_state")
	var draw_context: Dictionary = {}
	var draw_deps: Dictionary = {}
	if draw_context_builder != null:
		draw_context = draw_context_builder.build_scene_context(canvas, shake_offset, registry)
		draw_deps = draw_context_builder.build_scene_deps(registry, feedback, power_state)

	effects_drawer.draw_actors(canvas, registry, draw_context_builder, draw_context, draw_deps)
	ball_drawer.draw_ball_effects(canvas, registry, draw_context_builder, draw_context, draw_deps, shake_offset)
	effects_drawer.draw_power_smash_effects(canvas, registry, power_state, shake_offset)
	ball_drawer.draw_ball(canvas, registry, draw_context_builder, draw_context, draw_deps, shake_offset)
	effects_drawer.draw_impact_and_combo_effects(canvas, registry, shake_offset)
	effects_drawer.draw_inner_wall_vignettes(canvas, registry, width, height, pillar_width)
	overlay_drawer.draw_skill_banners(canvas, registry, draw_context_builder, draw_context, draw_deps, width, height)
	overlay_drawer.draw_scoreboard_overlay(canvas, registry, width, height)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
