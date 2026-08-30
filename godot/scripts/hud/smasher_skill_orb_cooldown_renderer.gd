extends RefCounted

const COOLDOWN_SECTOR_SEGMENTS := 14
const COOLDOWN_RING_SEGMENTS := 14
const COOLDOWN_RING_SEGMENTS_STATIC_LOD := 14
const FILLED_RECOVERY_SEGMENTS := 18
const FILLED_RECOVERY_HALO_LAYERS := 3


func draw(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	cooldown_ratio: float,
	pillar_drawer,
	static_hud_lod: bool = false
) -> void:
	var clamped_ratio: float = clamp(cooldown_ratio, 0.0, 1.0)
	canvas.draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.45))
	if clamped_ratio > 0.0 and not static_hud_lod:
		var points: PackedVector2Array
		if pillar_drawer != null and pillar_drawer.has_method("build_sector_points"):
			points = pillar_drawer.build_sector_points(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clamped_ratio, COOLDOWN_SECTOR_SEGMENTS)
		else:
			points = _build_sector_points(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clamped_ratio, COOLDOWN_SECTOR_SEGMENTS)
		canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.42))
	var ring_radius: float = radius + 1.5
	var ring_width: float = max(4.0, floor(radius * 0.17))
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * clamped_ratio
	var ring_segments: int = COOLDOWN_RING_SEGMENTS_STATIC_LOD if static_hud_lod else COOLDOWN_RING_SEGMENTS
	if not static_hud_lod:
		canvas.draw_arc(
			center,
			ring_radius,
			start_angle,
			end_angle,
			ring_segments,
			Color(0.0, 0.0, 0.0, 0.72),
			ring_width + 3.0,
			true
		)
		canvas.draw_arc(
			center,
			ring_radius + 0.5,
			start_angle,
			end_angle,
			ring_segments,
			Color(0.12, 0.72, 1.0, 0.24),
			ring_width + 6.0,
			true
		)
	canvas.draw_arc(
		center,
		ring_radius,
		start_angle,
		end_angle,
		ring_segments,
		Color(0.72, 0.95, 1.0, 0.96),
		ring_width,
		true
	)


func draw_filled_recovery(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	cooldown_ratio: float,
	time_seconds: float,
	phase_offset: float,
	skill_color: Color,
	static_hud_lod: bool = false
) -> void:
	var clamped_ratio := clampf(cooldown_ratio, 0.0, 1.0)
	canvas.draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.54))
	if clamped_ratio <= 0.0:
		return
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * clamped_ratio
	var shadow_fill := _build_sector_points(
		center,
		radius,
		start_angle,
		end_angle,
		FILLED_RECOVERY_SEGMENTS
	)
	canvas.draw_colored_polygon(shadow_fill, Color(0.01, 0.035, 0.055, 0.62))
	var inner_fill := _build_sector_points(
		center,
		radius * 0.84,
		start_angle,
		end_angle,
		FILLED_RECOVERY_SEGMENTS
	)
	canvas.draw_colored_polygon(
		inner_fill,
		Color(skill_color.r * 0.24, skill_color.g * 0.34, skill_color.b * 0.42, 0.20)
	)
	if static_hud_lod:
		return
	var pulse := 0.5 + 0.5 * sin(time_seconds * 4.6 + phase_offset)
	var light_angle := end_angle - 0.08
	var light_center := center + Vector2.from_angle(light_angle) * radius * 0.62
	for layer_index in range(FILLED_RECOVERY_HALO_LAYERS):
		var layer_ratio := float(layer_index) / float(FILLED_RECOVERY_HALO_LAYERS - 1)
		var drift := Vector2(
			cos(time_seconds * 1.4 + phase_offset + layer_ratio * 3.1),
			sin(time_seconds * 1.1 + phase_offset + layer_ratio * 2.3)
		) * (1.2 + layer_ratio * 1.8)
		canvas.draw_circle(
			light_center + drift,
			7.0 - layer_ratio * 3.8 + pulse * 0.8,
			Color(skill_color.r, skill_color.g, skill_color.b, 0.045 + layer_ratio * 0.045)
		)
	canvas.draw_circle(
		light_center,
		2.6 + pulse * 0.7,
		Color(skill_color.r, skill_color.g, skill_color.b, 0.34)
	)
	canvas.draw_circle(
		light_center,
		1.1 + pulse * 0.25,
		Color(0.90, 0.99, 1.0, 0.86)
	)


func _build_sector_points(
	center: Vector2,
	outer_radius: float,
	start_rad: float,
	end_rad: float,
	segments: int = 32
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(center)
	for i in range(segments + 1):
		var ratio: float = float(i) / float(max(1, segments))
		var angle: float = start_rad + (end_rad - start_rad) * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	return points
