extends RefCounted


static func get_reward_color(reward_type: String) -> Color:
	match reward_type:
		"active":
			return Color(0.10, 0.52, 0.62, 1.0)
		"passive":
			return Color(0.50, 0.36, 0.10, 1.0)
		"mythic":
			return Color(0.32, 0.10, 0.50, 1.0)
		"starpoint":
			return Color(0.86, 0.52, 0.10, 1.0)
		"perk", "skill":
			return Color(0.18, 0.36, 0.58, 1.0)
	return Color(0.40, 0.32, 0.20, 1.0)


static func get_reward_badge(reward: Dictionary) -> String:
	var reward_type: String = str(reward.get("type", ""))
	match reward_type:
		"active":
			return "ACTIVE"
		"passive":
			return "PASSIVE"
		"mythic":
			return "MYTHIC"
		"starpoint":
			return "PERK"
		"perk", "skill":
			return "PERK"
	return "REWARD"


static func get_result_reward_source_label(
	source_key: String,
	stage_source: String,
	box_source: String,
	stage_label: String,
	box_label: String
) -> String:
	match source_key:
		stage_source:
			return stage_label
		box_source:
			return box_label
	return ""


static func get_result_reward_source_labels(
	stage_source: String,
	box_source: String,
	stage_label: String,
	box_label: String
) -> Dictionary:
	return {
		stage_source: stage_label,
		box_source: box_label,
	}


static func get_result_reward_source_color(source_key: String, stage_source: String, box_source: String) -> Color:
	if source_key == stage_source:
		return Color(0.04, 0.32, 0.36, 1.0)
	if source_key == box_source:
		return Color(0.46, 0.22, 0.08, 1.0)
	return Color(0.18, 0.24, 0.28, 1.0)


static func get_reward_item_icon_palette(reward_type: String) -> Dictionary:
	match reward_type:
		"active":
			return {
				"disc_color": Color(0.06, 0.20, 0.28, 0.88),
				"rim_color": Color(0.55, 0.92, 1.0, 1.0),
			}
		"passive":
			return {
				"disc_color": Color(0.22, 0.14, 0.04, 0.88),
				"rim_color": Color(1.0, 0.84, 0.48, 1.0),
			}
		"mythic":
			return {
				"disc_color": Color(0.20, 0.06, 0.34, 0.92),
				"rim_color": Color(1.0, 0.78, 0.30, 1.0),
			}
	return {
		"disc_color": Color(0.18, 0.18, 0.24, 0.88),
		"rim_color": Color(0.85, 0.85, 0.92, 1.0),
	}


static func get_reward_starpoint_visual_state(
	amount: int,
	anchor: Vector2,
	draw_scale: float,
	alpha: float,
	emerge_progress: float,
	timer: float,
	phase: float
) -> Dictionary:
	var disc_radius: float = 60.0 * draw_scale
	var star_radius: float = 42.0 * draw_scale
	var spin_angle: float = timer * 8.7 + phase * 1.9
	var yaw_width: float = lerpf(0.16, 1.0, pow(absf(cos(spin_angle)), 0.62))
	var front_face: bool = cos(spin_angle) >= 0.0
	var star_center: Vector2 = anchor + Vector2(0.0, -10.0 * draw_scale)
	var sparkle_alpha: float = clamp(alpha * emerge_progress, 0.0, 1.0)
	var orbit_rect := Rect2(
		anchor - Vector2(disc_radius * 0.82, disc_radius * 0.42),
		Vector2(disc_radius * 1.64, disc_radius * 0.84)
	)
	return {
		"amount": max(1, amount),
		"disc_radius": disc_radius,
		"star_radius": star_radius,
		"yaw_width": yaw_width,
		"front_face": front_face,
		"star_center": star_center,
		"sparkle_alpha": sparkle_alpha,
		"glow_color": Color(1.0, 0.88, 0.36, 0.36 * alpha),
		"disc_fill": Color(0.30, 0.18, 0.04, 0.88 * alpha),
		"ring_color": Color(1.0, 0.86, 0.32, alpha),
		"ring_width": max(2.0, 2.8 * draw_scale),
		"orbit_rect": orbit_rect,
		"orbit_color": Color(1.0, 0.98, 0.68, 0.22 * sparkle_alpha),
		"orbit_width": max(1.0, 1.4 * draw_scale),
		"star_fill": Color(1.0, 0.88, 0.36, alpha) if front_face else Color(0.86, 0.48, 0.08, alpha),
		"star_outline": Color(0.55, 0.32, 0.04, alpha),
		"star_outline_width": max(1.5, 2.0 * draw_scale),
		"edge_line_width": max(2.0, star_radius * 0.13),
		"highlight_radius": max(1.4, 3.4 * draw_scale),
		"text_rect": Rect2(anchor + Vector2(-disc_radius, 22.0 * draw_scale), Vector2(disc_radius * 2.0, 30.0 * draw_scale)),
		"text_color": Color(1.0, 0.97, 0.70, alpha),
	}
