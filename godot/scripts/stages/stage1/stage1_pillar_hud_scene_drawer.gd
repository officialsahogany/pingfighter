extends RefCounted

const Stage1ActiveItemHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_active_item_hud_scene_drawer.gd")
const Stage1TopMiniScoreboardSceneDrawer := preload("res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd")

var active_item_drawer: Object = Stage1ActiveItemHudSceneDrawer.new()
var top_mini_scoreboard_drawer: Object = Stage1TopMiniScoreboardSceneDrawer.new()


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	top_mini_scoreboard_drawer.draw(canvas, context, registry, states, game_offset, game_size, time_seconds)
	active_item_drawer.draw(canvas, context, registry, view_size, game_offset, game_size)
	_draw_stage1_pillar_ui(canvas, context, registry, states, game_offset, game_size, time_seconds)


func _draw_stage1_pillar_ui(
	canvas: CanvasItem,
	context: Dictionary,
	registry: Object,
	states: Dictionary,
	game_offset: Vector2,
	game_size: Vector2,
	time_seconds: float
) -> void:
	var renderer: Object = registry.get_instance("stage1_pillar_ui_renderer")
	if renderer == null:
		return
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	var skill_config: Object = registry.get_instance("smasher_skill_config")
	var feedback: Object = registry.get_instance("battle_feedback_state")
	var orb_state: Object = states.get("orb_hud_state", null)
	var dash_state: Object = registry.get_instance("smasher_dash_state")
	var dash_snapshot: Dictionary = dash_state.get_snapshot() if dash_state != null else {}
	renderer.draw(canvas, game_offset, game_size, time_seconds, {
		"height": float(context.get("height", 750.0)),
		"pillar_drawer": registry.get_instance("pillar_orb_drawer"),
		"skill_orb_renderer": registry.get_instance("smasher_skill_orb_renderer"),
		"status_orb_renderer": registry.get_instance("pillar_status_orb_renderer"),
		"combo_renderer": registry.get_instance("smasher_combo_renderer"),
		"combo_state": registry.get_instance("smasher_combo_state"),
		"cluster_frame_texture": _get_value(textures, "smasher_skill_cluster_frame_texture"),
		"skill_orb_frame_texture": _get_value(textures, "skill_orb_frame_texture"),
		"skill_icons": context.get("skill_icons", {}),
		"skill_state": registry.get_instance("smasher_skill_state"),
		"skill_config_snapshot": skill_config.get_snapshot() if skill_config != null else {},
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"gauge_max": float(context.get("gauge_max", 500.0)),
		"gauge_flash_timer": feedback.get_gauge_flash_timer() if feedback != null else 0.0,
		"gauge_flash_duration": feedback.get_gauge_flash_duration() if feedback != null else 0.45,
		"gauge_frame_texture": _get_value(textures, "gauge_orb_frame_texture"),
		"gauge_frame_spin_angle": orb_state.get_gauge_spin_angle(Time.get_ticks_msec()) if orb_state != null else 0.0,
		"dash_snapshot": dash_snapshot,
		"dash_flash_timer": feedback.get_dash_flash_timer() if feedback != null else 0.0,
		"dash_flash_duration": feedback.get_dash_flash_duration() if feedback != null else 0.55,
		"dash_divider_anim_progress": feedback.get_dash_divider_anim_progress() if feedback != null else 1.0,
		"dash_frame_texture": _get_value(textures, "dash_token_frame_texture"),
		"dash_frame_spin_angle": orb_state.get_dash_token_spin_angle(Time.get_ticks_msec()) if orb_state != null else 0.0,
	})


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
