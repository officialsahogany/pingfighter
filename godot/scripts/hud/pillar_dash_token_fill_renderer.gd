extends RefCounted

const PillarDashTokenDividerRenderer := preload("res://scripts/hud/pillar_dash_token_divider_renderer.gd")

var divider_renderer: Object = PillarDashTokenDividerRenderer.new()


func draw_tokens(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	t: float,
	scale_factor: float,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float
) -> void:
	if max_tokens == 1:
		_draw_single_dash_token(canvas, pillar_drawer, center, inner_radius, available_tokens, charge_progress, t)
	else:
		_draw_multi_dash_tokens(
			canvas,
			pillar_drawer,
			center,
			inner_radius,
			max_tokens,
			available_tokens,
			charge_progress,
			t,
			scale_factor,
			divider_anim_progress,
			start_angle_offset,
			sector_angle
		)


func _draw_single_dash_token(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	available_tokens: int,
	charge_progress: float,
	t: float
) -> void:
	var fill_ratio_total: float = 0.0
	if available_tokens >= 1:
		fill_ratio_total = 1.0
	elif charge_progress > 0.0:
		fill_ratio_total = charge_progress
	if fill_ratio_total <= 0.0:
		return

	pillar_drawer.draw_pillar_liquid_fill(canvas, center, inner_radius, fill_ratio_total, t, Color(0.98, 0.46, 0.36, 1.0), Color(0.42, 0.10, 0.12, 1.0), Color(1.0, 0.78, 0.70, 1.0))
	canvas.draw_circle(center, inner_radius * (0.18 + fill_ratio_total * 0.24), Color(1.0, 0.46, 0.36, 0.12 + fill_ratio_total * 0.16))
	canvas.draw_circle(center + Vector2(0.0, inner_radius * 0.10), inner_radius * (0.10 + fill_ratio_total * 0.12), Color(1.0, 0.92, 0.88, 0.06 + fill_ratio_total * 0.08))


func _draw_multi_dash_tokens(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	inner_radius: float,
	max_tokens: int,
	available_tokens: int,
	charge_progress: float,
	t: float,
	scale_factor: float,
	divider_anim_progress: float,
	start_angle_offset: float,
	sector_angle: float
) -> void:
	for i in range(max_tokens):
		var start_rad: float = start_angle_offset + sector_angle * float(i)
		var end_rad: float = start_rad + sector_angle
		if i < available_tokens:
			var token_pulse: float = 0.5 + 0.5 * sin(t * 3.5 + float(i) * 1.2)
			var base_alpha: float = 0.88 + 0.10 * token_pulse
			canvas.draw_colored_polygon(pillar_drawer.build_sector_points(center, inner_radius, start_rad, end_rad, 24), Color(0.78, 0.16, 0.20, base_alpha))
			canvas.draw_colored_polygon(pillar_drawer.build_sector_points(center, inner_radius * 0.72, start_rad, end_rad, 16), Color(1.0, 0.52, 0.42, 0.12 + 0.10 * token_pulse))
		elif charge_progress > 0.0 and i == available_tokens:
			pillar_drawer.draw_dash_sector_liquid(canvas, center, inner_radius, start_rad, end_rad, charge_progress, t, scale_factor)

	divider_renderer.draw(
		canvas,
		pillar_drawer,
		center,
		inner_radius,
		max_tokens,
		divider_anim_progress,
		start_angle_offset,
		sector_angle,
		scale_factor
	)
