extends RefCounted

const PLAYER_SKILL_ORB_RADIUS := 24.0
const PLAYER_SKILL_ORB_GAUGE_GAP := 28.0
const PLAYER_SKILL_ORB_SOCKET_RADIUS_OVERLAP := 1.0
const PLAYER_SKILL_ORB_FRAME_SAFE_PAD := 8.0
const PLAYER_SKILL_CLUSTER_SOURCE_SIZE := Vector2(250.0, 650.0)
const PLAYER_SKILL_CLUSTER_GAUGE_CENTER := Vector2(141.0, 564.0)

const PILLAR_UI_SURFACE_LEFT_SIZE := Vector2(250.0, 650.0)
const PILLAR_UI_SIDE_MARGIN := 25.0
const PILLAR_UI_BOTTOM_MARGIN := 10.0
const PILLAR_ORB_RADIUS_BASE := 55.0


func build_layout(game_offset: Vector2, game_size: Vector2, context: Dictionary) -> Dictionary:
	var height: float = float(context.get("height", 750.0))
	var scale_factor: float = game_size.y / height
	var left_center := Vector2(
		game_offset.x - (PILLAR_UI_SIDE_MARGIN + (PILLAR_UI_SURFACE_LEFT_SIZE.x - PILLAR_ORB_RADIUS_BASE * 2.0) * 0.5) * scale_factor,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor
	)
	var right_center := Vector2(
		game_offset.x + game_size.x + (PILLAR_UI_SIDE_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + 70.0) * scale_factor
	)
	return {
		"scale_factor": scale_factor,
		"left_center": left_center,
		"right_center": right_center,
		"orb_radius": PILLAR_ORB_RADIUS_BASE * scale_factor,
	}


func build_skill_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	var skill_config_snapshot: Dictionary = _get_dict(context.get("skill_config_snapshot", {}))
	return {
		"cluster_frame_texture": context.get("cluster_frame_texture", null),
		"skill_orb_frame_texture": context.get("skill_orb_frame_texture", null),
		"skill_icons": context.get("skill_icons", {}),
		"skill_state": context.get("skill_state", null),
		"pillar_drawer": orb_drawer,
		"special_gauge": context.get("special_gauge", 0.0),
		"max_slots": skill_config_snapshot.get("max_slots", 5),
		"equipped_skills": skill_config_snapshot.get("equipped_skills", []),
		"skill_costs": skill_config_snapshot.get("skill_costs", {}),
		"skill_colors": skill_config_snapshot.get("skill_colors", {}),
		"cooldown_seconds": skill_config_snapshot.get("cooldown_seconds", {}),
		"skill_orb_radius": PLAYER_SKILL_ORB_RADIUS,
		"gauge_gap": PLAYER_SKILL_ORB_GAUGE_GAP,
		"socket_overlap": PLAYER_SKILL_ORB_SOCKET_RADIUS_OVERLAP,
		"frame_safe_pad": PLAYER_SKILL_ORB_FRAME_SAFE_PAD,
		"cluster_source_size": PLAYER_SKILL_CLUSTER_SOURCE_SIZE,
		"cluster_gauge_center": PLAYER_SKILL_CLUSTER_GAUGE_CENTER,
		"orb_radius_base": PILLAR_ORB_RADIUS_BASE,
	}


func build_combo_rect(game_offset: Vector2, left_center: Vector2, scale_factor: float) -> Rect2:
	var combo_anchor_size := Vector2(116.0, 42.0) * scale_factor
	var combo_anchor_pos := Vector2(
		left_center.x - combo_anchor_size.x * 0.5,
		game_offset.y + 12.0 * scale_factor
	)
	return Rect2(combo_anchor_pos, combo_anchor_size)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
