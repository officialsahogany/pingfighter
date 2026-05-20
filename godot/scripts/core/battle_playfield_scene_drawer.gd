extends RefCounted

const BattlePlayfieldBallDrawer := preload("res://scripts/core/battle_playfield_ball_drawer.gd")
const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const BattlePlayfieldOverlayDrawer := preload("res://scripts/core/battle_playfield_overlay_drawer.gd")

var ball_drawer: Object = BattlePlayfieldBallDrawer.new()
var effects_drawer: Object = BattlePlayfieldEffectsDrawer.new()
var overlay_drawer: Object = BattlePlayfieldOverlayDrawer.new()
var _mythic_draw_field_effects_accepts_perf_logger: int = -1


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
	_draw_active_item_field(canvas, registry, shake_offset)
	_draw_mythic_item_field_effects(canvas, registry, shake_offset)
	effects_drawer.draw_inner_wall_vignettes(canvas, registry, width, height, pillar_width)
	overlay_drawer.draw_skill_banners(canvas, registry, draw_context_builder, draw_context, draw_deps, width, height)
	_draw_active_item_pickup_effect(canvas, registry)
	overlay_drawer.draw_scoreboard_overlay(canvas, registry, width, height)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _draw_active_item_field(canvas: CanvasItem, registry: Object, shake_offset: Vector2) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_field_items"):
		active_item_runtime.draw_field_items(canvas, registry, shake_offset)

func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			return args_value.size()
	return 0


func _method_accepts_argument_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_count: int = 0
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			args_count = args_value.size()
		var default_count: int = 0
		var default_value: Variant = method_info.get("default_args", [])
		if default_value is Array:
			default_count = default_value.size()
		return arg_count <= args_count + default_count
	return false


func _draw_mythic_item_field_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	perf_logger: Object = null
) -> void:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("draw_field_effects"):
		if mythic_item_runtime.has_method("has_visible_field_effects") and not bool(mythic_item_runtime.has_visible_field_effects()):
			return
		if _mythic_draw_field_effects_uses_perf_logger(mythic_item_runtime):
			mythic_item_runtime.draw_field_effects(canvas, registry, shake_offset, perf_logger)
		else:
			mythic_item_runtime.draw_field_effects(canvas, registry, shake_offset)


func _mythic_draw_field_effects_uses_perf_logger(mythic_item_runtime: Object) -> bool:
	if _mythic_draw_field_effects_accepts_perf_logger < 0:
		_mythic_draw_field_effects_accepts_perf_logger = 1 if _method_accepts_argument_count(mythic_item_runtime, "draw_field_effects", 4) else 0
	return _mythic_draw_field_effects_accepts_perf_logger == 1

func _draw_active_item_pickup_effect(canvas: CanvasItem, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_pickup_effect"):
		active_item_runtime.draw_pickup_effect(canvas, registry)
