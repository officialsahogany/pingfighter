extends RefCounted

const PLAYER_SKILL_ORB_RADIUS := 24.0
const PLAYER_SKILL_ORB_GAUGE_GAP := 38.0
const PLAYER_SKILL_ORB_SOCKET_RADIUS_OVERLAP := 1.0
const PLAYER_SKILL_ORB_FRAME_SAFE_PAD := 8.0
const PLAYER_SKILL_CLUSTER_SOURCE_SIZE := Vector2(250.0, 650.0)
# Source-space center of the large player gauge inside the generated full
# skill-cluster frame. Keep this aligned with the runtime slot orbit center.
const PLAYER_SKILL_CLUSTER_GAUGE_CENTER := Vector2(141.0, 559.0)

const PILLAR_UI_SURFACE_LEFT_SIZE := Vector2(250.0, 650.0)
const PILLAR_UI_SIDE_MARGIN := 25.0
const PILLAR_UI_BOTTOM_MARGIN := 10.0
const PILLAR_ORB_RADIUS_BASE := 55.0
const MOBILE_LEFT_HUD_LIFT_BASE := 155.0
const MOBILE_RIGHT_HUD_LIFT_BASE := 210.0
const SMASHER_COMBO_ANCHOR_SIZE := Vector2(116.0, 42.0)
const SMASHER_COMBO_ANCHOR_TO_BAR_GAP := 18.0
const SMASHER_COMBO_CLUSTER_GAP := 12.0
const SMASHER_COMBO_BELOW_LABEL_CLEARANCE := 24.0


func get_skill_orb_slot_layout(character_type: Variant) -> Dictionary:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "viper":
		return {
			"base_angle": 155.0,
			"angle_step": 32.0,
		}
	return {
		"base_angle": 165.0,
		"angle_step": 33.0,
	}


func build_layout(game_offset: Vector2, game_size: Vector2, context: Dictionary) -> Dictionary:
	var height: float = float(context.get("height", 750.0))
	var scale_factor: float = game_size.y / height
	var left_hud_lift: float = MOBILE_LEFT_HUD_LIFT_BASE * scale_factor if _is_mobile_runtime() else 0.0
	var right_hud_lift: float = MOBILE_RIGHT_HUD_LIFT_BASE * scale_factor if _is_mobile_runtime() else 0.0
	var left_center := Vector2(
		game_offset.x - (PILLAR_UI_SIDE_MARGIN + (PILLAR_UI_SURFACE_LEFT_SIZE.x - PILLAR_ORB_RADIUS_BASE * 2.0) * 0.5) * scale_factor,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor - left_hud_lift
	)
	var right_center_x: float = game_offset.x + game_size.x + (PILLAR_UI_SIDE_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor
	var right_center := Vector2(
		right_center_x,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + 70.0) * scale_factor - right_hud_lift
	)
	var boss_right_top_center := Vector2(
		right_center_x,
		game_offset.y + (PILLAR_ORB_RADIUS_BASE + 15.0) * scale_factor
	)
	return {
		"scale_factor": scale_factor,
		"left_center": left_center,
		"right_center": right_center,
		"boss_right_top_center": boss_right_top_center,
		"orb_radius": PILLAR_ORB_RADIUS_BASE * scale_factor,
		"mobile_hud_lifted": left_hud_lift > 0.0 or right_hud_lift > 0.0,
	}


func build_skill_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	var skill_config_snapshot: Dictionary = _get_dict(context.get("skill_config_snapshot", {}))
	var max_slots: int = int(skill_config_snapshot.get("max_slots", 5))
	var slot_layout: Dictionary = get_skill_orb_slot_layout(context.get("selected_character_type", "smasher"))
	return {
		"cluster_frame_texture": context.get("cluster_frame_texture", null),
		"cluster_frame_slots": int(context.get("cluster_frame_slots", max_slots)),
		"skill_orb_frame_texture": context.get("skill_orb_frame_texture", null),
		"skill_icons": context.get("skill_icons", {}),
		"skill_state": context.get("skill_state", null),
		"pillar_drawer": orb_drawer,
		"pillar_hud_static_lod": bool(context.get("pillar_hud_static_lod", false)),
		"special_gauge": context.get("special_gauge", 0.0),
		"max_slots": max_slots,
		"equipped_skills": skill_config_snapshot.get("equipped_skills", []),
		"skill_costs": skill_config_snapshot.get("skill_costs", {}),
		"skill_colors": skill_config_snapshot.get("skill_colors", {}),
		"cooldown_seconds": skill_config_snapshot.get("cooldown_seconds", {}),
		"cleanse_status_active": bool(context.get("cleanse_status_active", false)),
		"skill_orb_radius": PLAYER_SKILL_ORB_RADIUS,
		"gauge_gap": PLAYER_SKILL_ORB_GAUGE_GAP,
		"socket_overlap": PLAYER_SKILL_ORB_SOCKET_RADIUS_OVERLAP,
		"frame_safe_pad": PLAYER_SKILL_ORB_FRAME_SAFE_PAD,
		"slot_base_angle": slot_layout.get("base_angle", 165.0),
		"slot_angle_step": slot_layout.get("angle_step", 33.0),
		"cluster_source_size": PLAYER_SKILL_CLUSTER_SOURCE_SIZE,
		"cluster_gauge_center": PLAYER_SKILL_CLUSTER_GAUGE_CENTER,
		"orb_radius_base": PILLAR_ORB_RADIUS_BASE,
	}


func build_combo_rect(left_center: Vector2, scale_factor: float, skill_cluster_bounds: Rect2 = Rect2()) -> Rect2:
	var safe_scale: float = max(0.45, scale_factor)
	var combo_anchor_size := SMASHER_COMBO_ANCHOR_SIZE * scale_factor
	var cluster_top_y: float = left_center.y - (
		PILLAR_ORB_RADIUS_BASE
		+ PLAYER_SKILL_ORB_RADIUS
		+ PLAYER_SKILL_ORB_GAUGE_GAP
		+ PLAYER_SKILL_ORB_FRAME_SAFE_PAD
	) * scale_factor
	var cluster_center_x: float = left_center.x
	if skill_cluster_bounds.size.x > 0.0 and skill_cluster_bounds.size.y > 0.0:
		cluster_top_y = skill_cluster_bounds.position.y
		cluster_center_x = skill_cluster_bounds.position.x + skill_cluster_bounds.size.x * 0.5
	var bar_h: float = max(max(14.0, 20.0 * safe_scale), min(combo_anchor_size.y * 0.42, 22.0 * safe_scale))
	var bar_y: float = (
		cluster_top_y
		- SMASHER_COMBO_CLUSTER_GAP * safe_scale
		- SMASHER_COMBO_BELOW_LABEL_CLEARANCE * safe_scale
		- bar_h
	)
	var combo_anchor_pos := Vector2(
		cluster_center_x - combo_anchor_size.x * 0.5,
		bar_y - SMASHER_COMBO_ANCHOR_TO_BAR_GAP * safe_scale - combo_anchor_size.y
	)
	return Rect2(combo_anchor_pos, combo_anchor_size)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
