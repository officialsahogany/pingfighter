extends RefCounted


static func get_reward_color(reward_type: String) -> Color:
	match reward_type:
		"active":
			return Color(0.10, 0.52, 0.62, 1.0)
		"passive":
			return Color(0.50, 0.36, 0.10, 1.0)
		"mythic":
			return Color(0.32, 0.10, 0.50, 1.0)
		"mythic_perk":
			return Color(0.42, 0.14, 0.62, 1.0)
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
		"mythic_perk":
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
		"mythic_perk":
			return {
				"disc_color": Color(0.22, 0.06, 0.36, 0.92),
				"rim_color": Color(0.92, 0.58, 1.0, 1.0),
			}
	return {
		"disc_color": Color(0.18, 0.18, 0.24, 0.88),
		"rim_color": Color(0.85, 0.85, 0.92, 1.0),
	}


static func get_reward_label_visual_state(
	box: Dictionary,
	box_draw_center: Vector2,
	box_half_y: float,
	draw_scale: float,
	global_alpha: float,
	timer: float,
	reward_hover_offset: float
) -> Dictionary:
	var reward: Dictionary = box.get("reward", {}) if box.get("reward", {}) is Dictionary else {}
	if reward.is_empty() or global_alpha <= 0.02:
		return {}
	var emerge: float = float(box.get("reward_emerge", 0.0))
	var emerge_eased: float = smooth01(emerge)
	var combined_alpha: float = emerge_eased * global_alpha
	if combined_alpha <= 0.02:
		return {}

	var phase: float = float(box.get("phase", 0.0))
	var rise: float = lerp(20.0 * draw_scale, reward_hover_offset * draw_scale, emerge_eased)
	var bob: float = sin(timer * 2.6 + phase) * 4.0 * draw_scale * emerge_eased
	return {
		"reward": reward,
		"reward_type": str(reward.get("type", "")),
		"anchor": box_draw_center + Vector2(0.0, -box_half_y - rise + bob),
		"alpha": combined_alpha,
		"emerge_eased": emerge_eased,
		"phase": phase,
	}


static func get_reward_item_icon_visual_state(reward_type: String, anchor: Vector2, draw_scale: float, alpha: float) -> Dictionary:
	var icon_size: float = 96.0 * draw_scale
	var disc_radius: float = 60.0 * draw_scale
	var palette: Dictionary = get_reward_item_icon_palette(reward_type)
	var disc_color: Color = palette.get("disc_color", Color(0.18, 0.18, 0.24, 0.88))
	var rim_color: Color = palette.get("rim_color", Color(0.85, 0.85, 0.92, 1.0))
	var glow_color: Color = rim_color
	glow_color.a = 0.32 * alpha
	var disc_fill: Color = disc_color
	disc_fill.a *= alpha
	var ring_color: Color = rim_color
	ring_color.a *= alpha
	return {
		"icon_rect": Rect2(anchor - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)),
		"disc_radius": disc_radius,
		"glow_color": glow_color,
		"disc_fill": disc_fill,
		"ring_color": ring_color,
		"ring_width": max(2.0, 2.8 * draw_scale),
		"fallback_text_rect": Rect2(anchor - Vector2(disc_radius * 0.95, 18.0 * draw_scale), Vector2(disc_radius * 1.9, 36.0 * draw_scale)),
		"fallback_text_color": Color(1.0, 1.0, 1.0, alpha),
		"fallback_font_preferred_size": int(round(22.0 * draw_scale)),
		"fallback_font_min_size": int(round(13.0 * draw_scale)),
	}


static func get_reward_card_visual_state(reward: Dictionary, rect: Rect2, draw_scale: float, alpha: float) -> Dictionary:
	var reward_type: String = str(reward.get("type", ""))
	var base_color: Color = get_reward_color(reward_type)
	base_color.a = 0.18 * alpha
	var border_color: Color = get_reward_color(reward_type).lerp(Color(0.06, 0.84, 0.96, 1.0), 0.34)
	border_color.a = 0.78 * alpha
	var badge_rect := Rect2(rect.position + Vector2(8.0, 7.0) * draw_scale, Vector2(58.0, 20.0) * draw_scale)
	var label_rect := Rect2(rect.position + Vector2(8.0, 84.0) * draw_scale, Vector2(rect.size.x - 16.0 * draw_scale, 22.0 * draw_scale))
	return {
		"reward_type": reward_type,
		"base_color": base_color,
		"border_color": border_color,
		"border_width": max(1.0, 1.6 * draw_scale),
		"corner_radius": 8.0 * draw_scale,
		"badge_text": get_reward_badge(reward),
		"badge_rect": badge_rect,
		"badge_fill": Color(0.02, 0.08, 0.11, 0.64 * alpha),
		"badge_border_width": max(1.0, 1.0 * draw_scale),
		"badge_corner_radius": 6.0 * draw_scale,
		"badge_font_size": int(round(10.0 * draw_scale)),
		"badge_text_color": Color(0.86, 1.0, 1.0, alpha),
		"icon_rect": Rect2(rect.position + Vector2(42.0, 30.0) * draw_scale, Vector2(64.0, 54.0) * draw_scale),
		"label_rect": label_rect,
		"label_plate_rect": label_rect.grow_individual(2.0 * draw_scale, 0.0, 2.0 * draw_scale, 0.0),
		"label_plate_fill": Color(0.95, 0.99, 0.96, 0.44 * alpha),
		"label_font_preferred_size": int(round(14.0 * draw_scale)),
		"label_font_min_size": int(round(9.0 * draw_scale)),
		"label_text_color": Color(0.04, 0.08, 0.10, alpha),
	}


static func get_reward_source_chip_visual_state(
	source_key: String,
	source_label: String,
	rect: Rect2,
	draw_scale: float,
	alpha: float,
	stage_source: String,
	box_source: String
) -> Dictionary:
	if source_label == "":
		return {}
	var chip_size := Vector2(64.0, 20.0) * draw_scale
	var chip_color: Color = get_result_reward_source_color(source_key, stage_source, box_source)
	chip_color.a = 0.72 * alpha
	var chip_border: Color = chip_color.lerp(Color(0.86, 1.0, 1.0, 1.0), 0.46)
	chip_border.a = 0.76 * alpha
	return {
		"rect": Rect2(
			Vector2(rect.end.x - chip_size.x - 8.0 * draw_scale, rect.position.y + 7.0 * draw_scale),
			chip_size
		),
		"fill": chip_color,
		"border": chip_border,
		"border_width": max(1.0, 1.0 * draw_scale),
		"corner_radius": 6.0 * draw_scale,
		"font_preferred_size": int(round(10.0 * draw_scale)),
		"font_min_size": int(round(7.0 * draw_scale)),
		"text_color": Color(0.92, 1.0, 1.0, alpha),
	}


static func get_fallback_reward_icon_visual_state(reward_type: String, rect: Rect2, alpha: float) -> Dictionary:
	var radius: float = min(rect.size.x, rect.size.y) * 0.42
	var fill: Color = get_reward_color(reward_type)
	fill.a = 0.84 * alpha
	return {
		"center": rect.get_center(),
		"radius": radius,
		"fill": fill,
		"ring_color": Color(0.86, 1.0, 1.0, alpha * 0.80),
		"ring_width": 1.6,
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
	var star_radius: float = 34.0 * draw_scale
	var star_center: Vector2 = anchor + Vector2(0.0, -8.0 * draw_scale)
	var sparkle_alpha: float = clamp(alpha * emerge_progress, 0.0, 1.0)
	var glow_intensity: float = clampf(0.92 + sin(timer * 5.2 + phase) * 0.08, 0.0, 1.0)
	var glow_alpha_total: float = alpha * 0.5 * glow_intensity
	var glow_layers: Array = []
	for layer in range(4):
		glow_layers.append({
			"radius": star_radius * (4.0 - float(layer) * 0.7),
			"color": Color(1.0, 0.45, 0.74, glow_alpha_total / float(4 - layer)),
		})
	var shimmer_hue: float = fposmod(timer * 0.256 + phase * 0.11, 1.0)
	var shimmer_color := Color.from_hsv(shimmer_hue, 0.72, 1.0, alpha)
	var star_fill: Color = Color(1.0, 0.42, 0.78, alpha).lerp(shimmer_color, 0.26)
	var ray_hue: float = fposmod(timer * 0.32 + phase * 0.17, 1.0)
	var ray_color := Color.from_hsv(ray_hue, 0.42, 1.0, 0.34 * sparkle_alpha)
	return {
		"amount": max(1, amount),
		"star_radius": star_radius,
		"inner_radius": star_radius * 0.5,
		"star_center": star_center,
		"sparkle_alpha": sparkle_alpha,
		"glow_layers": glow_layers,
		"star_fill": star_fill,
		"star_outline": Color(1.0, 1.0, 0.0, alpha),
		"star_outline_width": max(2.5, 3.0 * draw_scale),
		"center_dot_radius": max(2.0, star_radius * 0.18),
		"center_dot_color": Color(1.0, 1.0, 1.0, alpha * glow_intensity),
		"ray_angle": timer * 0.45 + phase,
		"ray_length": star_radius * 3.15,
		"ray_color": ray_color,
		"ray_hot_color": Color(1.0, 1.0, 1.0, 0.30 * sparkle_alpha),
		"ray_width": max(1.0, 1.45 * draw_scale),
		"diagonal_ray_width": max(0.75, 0.95 * draw_scale),
		"text_rect": Rect2(anchor + Vector2(-56.0 * draw_scale, 30.0 * draw_scale), Vector2(112.0 * draw_scale, 32.0 * draw_scale)),
		"amount_font_size": int(round(22.0 * draw_scale)),
		"text_color": Color(1.0, 1.0, 0.78, alpha),
	}


static func smooth01(value: float) -> float:
	var clamped: float = clamp(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
