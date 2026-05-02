extends RefCounted


func draw_actors(
	canvas: CanvasItem,
	registry: Object,
	draw_context_builder: Object,
	draw_context: Dictionary,
	draw_deps: Dictionary
) -> void:
	var actor_renderer: Object = _get_instance(registry, "stage1_actor_renderer")
	if actor_renderer != null and draw_context_builder != null:
		actor_renderer.draw(canvas, draw_context_builder.build_actor_context(draw_context, draw_deps))


func draw_power_smash_effects(
	canvas: CanvasItem,
	registry: Object,
	power_state: Object,
	shake_offset: Vector2
) -> void:
	if not bool(canvas.get("ball_active")):
		return
	var skill_feedback_renderer: Object = _get_instance(registry, "smasher_skill_feedback_renderer")
	if skill_feedback_renderer != null:
		skill_feedback_renderer.draw_power_smash_effects(canvas, power_state, shake_offset)


func draw_impact_and_combo_effects(canvas: CanvasItem, registry: Object, shake_offset: Vector2) -> void:
	var impact_renderer: Object = _get_instance(registry, "impact_effects_renderer")
	if impact_renderer != null:
		impact_renderer.draw(canvas, _get_instance(registry, "impact_effects"), shake_offset)

	var combo_renderer: Object = _get_instance(registry, "smasher_combo_renderer")
	if combo_renderer != null:
		combo_renderer.draw_effect(canvas, _get_instance(registry, "smasher_combo_state"), shake_offset)


func draw_inner_wall_vignettes(
	canvas: CanvasItem,
	registry: Object,
	width: float,
	height: float,
	pillar_width: float
) -> void:
	var pillar_drawer: Object = _get_instance(registry, "pillar_orb_drawer")
	if pillar_drawer == null:
		return
	var inner_wall_time: float = float(Time.get_ticks_msec()) / 1000.0
	pillar_drawer.draw_stage1_inner_side_vignettes(canvas, width, height, pillar_width, inner_wall_time)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
