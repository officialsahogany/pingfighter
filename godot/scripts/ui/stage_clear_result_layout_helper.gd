extends RefCounted


static func get_box_layout(count: int) -> Array:
	match count:
		1:
			return [
				{"pos": Vector2(950.0, 480.0), "rot": 0.04, "phase": 0.0},
			]
		2:
			return [
				{"pos": Vector2(760.0, 360.0), "rot": -0.08, "phase": 0.0},
				{"pos": Vector2(1160.0, 580.0), "rot": 0.10, "phase": 1.6},
			]
		3:
			return [
				{"pos": Vector2(820.0, 300.0), "rot": 0.04, "phase": 0.0, "amp": 4.0},
				{"pos": Vector2(820.0, 600.0), "rot": -0.10, "phase": 1.4},
				{"pos": Vector2(1200.0, 580.0), "rot": 0.14, "phase": 2.8},
			]
		4:
			return [
				{"pos": Vector2(720.0, 320.0), "rot": -0.10, "phase": 0.0},
				{"pos": Vector2(1060.0, 280.0), "rot": 0.06, "phase": 1.0},
				{"pos": Vector2(820.0, 620.0), "rot": -0.08, "phase": 2.0},
				{"pos": Vector2(1220.0, 560.0), "rot": 0.12, "phase": 3.0},
			]
		5:
			return [
				{"pos": Vector2(680.0, 300.0), "rot": -0.10, "phase": 0.0},
				{"pos": Vector2(960.0, 260.0), "rot": 0.05, "phase": 0.9},
				{"pos": Vector2(1240.0, 330.0), "rot": 0.12, "phase": 1.8},
				{"pos": Vector2(820.0, 630.0), "rot": -0.07, "phase": 2.7},
				{"pos": Vector2(1130.0, 610.0), "rot": 0.09, "phase": 3.6},
			]
	return []


static func get_result_box_frame_index(
	state: String,
	open_progress: float,
	is_mythic: bool,
	frame_count: int,
	common_safe_last_frame: int,
	mythic_safe_last_frame: int
) -> int:
	var last_safe_frame: int = mythic_safe_last_frame if is_mythic else common_safe_last_frame
	match state:
		"idle":
			return 0
		"opening":
			return clampi(int(open_progress * float(frame_count)), 0, last_safe_frame)
		"opened":
			return last_safe_frame
	return 0


static func get_box_draw_center(
	box: Dictionary,
	draw_scale: float,
	timer: float,
	default_amplitude: float,
	default_speed: float
) -> Vector2:
	var base_pos: Vector2 = box.get("base_pos", Vector2.ZERO)
	var phase: float = float(box.get("phase", 0.0))
	var amplitude: float = float(box.get("amplitude", default_amplitude))
	var speed: float = float(box.get("speed", default_speed))
	var float_y: float = sin(timer * speed + phase) * amplitude
	return (base_pos + Vector2(0.0, float_y)) * draw_scale


static func get_box_aabb(
	box: Dictionary,
	draw_scale: float,
	timer: float,
	base_size: Vector2,
	hover_grow: float,
	default_amplitude: float,
	default_speed: float
) -> Rect2:
	var draw_center: Vector2 = get_box_draw_center(
		box,
		draw_scale,
		timer,
		default_amplitude,
		default_speed
	)
	var half: Vector2 = base_size * draw_scale * hover_grow * 0.55
	return Rect2(draw_center - half, half * 2.0)


static func rotate_around(point: Vector2, center: Vector2, angle: float) -> Vector2:
	var rel: Vector2 = point - center
	var c: float = cos(angle)
	var s: float = sin(angle)
	return Vector2(rel.x * c - rel.y * s, rel.x * s + rel.y * c) + center


static func get_player_victory_actor_rect(view_size: Vector2, layout_ratio: float) -> Rect2:
	var actor_size := Vector2(760.0, 760.0) * layout_ratio
	return Rect2(
		Vector2(view_size.x - 650.0 * layout_ratio, 213.0 * layout_ratio),
		actor_size
	)


static func get_player_victory_click_rect(view_size: Vector2, layout_ratio: float, _cell_size: Vector2) -> Rect2:
	var actor_rect: Rect2 = get_player_victory_actor_rect(view_size, layout_ratio)
	# The click region was authored against the original 1408px source cell. We
	# express it as a fraction of the displayed actor (authored cell px), so the
	# on-screen rect is identical regardless of the imported cell size — the
	# result texture is now downscaled to 896px cells (process/size_limit) but
	# the clickable body region must not move. cell_size is intentionally unused.
	const AUTHORED_SOURCE_CELL_PX := 1408.0
	var cell_scale: float = actor_rect.size.x / AUTHORED_SOURCE_CELL_PX
	var click_rect := Rect2(
		actor_rect.position + Vector2(240.0, 100.0) * cell_scale,
		actor_rect.size - Vector2(360.0, 210.0) * cell_scale
	)
	return click_rect.intersection(Rect2(Vector2.ZERO, view_size))


static func get_player_victory_panel_rect(view_size: Vector2, layout_ratio: float) -> Rect2:
	return Rect2(
		Vector2(view_size.x - 495.0 * layout_ratio, 190.0 * layout_ratio),
		Vector2(410.0, 750.0) * layout_ratio
	)


static func screen_to_acquisition_cinematic_local(
	screen_position: Vector2,
	view_size: Vector2,
	field_size: Vector2
) -> Vector2:
	var field_origin: Vector2 = (view_size - field_size) * 0.5
	return screen_position - field_origin


static func get_scroll_content_rect(scroll_rect: Rect2, draw_scale: float, content_margin: Vector4) -> Rect2:
	var left: float = content_margin.x * draw_scale
	var top: float = content_margin.y * draw_scale
	var right: float = content_margin.z * draw_scale
	var bottom: float = content_margin.w * draw_scale
	return Rect2(
		scroll_rect.position + Vector2(left, top),
		Vector2(max(1.0, scroll_rect.size.x - left - right), max(1.0, scroll_rect.size.y - top - bottom))
	)


static func get_dalji_draw_rect(view_size: Vector2, draw_scale: float) -> Rect2:
	var draw_size := Vector2(624.0, 624.0) * draw_scale
	var position := Vector2(-16.0, 471.0) * draw_scale
	if view_size.x < 1280.0:
		draw_size = Vector2(520.0, 520.0) * draw_scale
		position = Vector2(-16.0, 480.0) * draw_scale
	return Rect2(position, draw_size)


static func get_stage2_boss_result_draw_rect(view_size: Vector2, draw_scale: float) -> Rect2:
	var draw_size := Vector2(634.8, 469.2) * draw_scale
	var position := Vector2(-6.4, 602.8) * draw_scale
	if view_size.x < 1280.0:
		draw_size = Vector2(515.2, 380.8) * draw_scale
		position = Vector2(-1.6, 611.2) * draw_scale
	return Rect2(position, draw_size)


static func calculate_reward_section_layout(reward_count: int, rect: Rect2, ui_scale: float) -> Dictionary:
	var gap: float = 16.0 * ui_scale
	var card_scale: float = ui_scale
	var card_size := Vector2(148.0, 112.0) * card_scale
	var columns: int = get_reward_section_columns(rect.size.x, card_size.x, gap, 4)
	var rows: int = int(ceil(float(max(1, reward_count)) / float(columns)))
	var available_height: float = max(1.0, rect.size.y - 42.0 * ui_scale)
	var required_height: float = float(rows) * card_size.y + float(max(0, rows - 1)) * gap
	if required_height > available_height:
		var fitted_height: float = max(64.0 * ui_scale, (available_height - float(max(0, rows - 1)) * gap) / float(rows))
		var fitted_scale: float = clamp(fitted_height / max(1.0, card_size.y), 0.56, 1.0)
		card_scale *= fitted_scale
		card_size = Vector2(148.0, 112.0) * card_scale
		gap = max(8.0 * ui_scale, gap * fitted_scale)
		columns = get_reward_section_columns(rect.size.x, card_size.x, gap, 5)
		rows = int(ceil(float(max(1, reward_count)) / float(columns)))
		required_height = float(rows) * card_size.y + float(max(0, rows - 1)) * gap
	return {
		"columns": columns,
		"rows": rows,
		"gap": gap,
		"card_size": card_size,
		"card_scale": card_scale,
		"cards_top": 38.0 * ui_scale,
		"available_height": available_height,
		"required_height": required_height,
	}


static func get_reward_section_columns(width: float, card_width: float, gap: float, max_columns: int) -> int:
	var columns: int = max(1, int(floor((width + gap) / (card_width + gap))))
	return min(columns, max(1, max_columns))


static func sheet_source_rect(frame: int, grid_cols: int, cell_size: Vector2) -> Rect2:
	var safe_cols: int = max(1, grid_cols)
	var col: int = frame % safe_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / safe_cols)
	return Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size)


static func cover_source_rect(texture_size: Vector2, target_size: Vector2) -> Rect2:
	var target_ratio: float = target_size.x / max(1.0, target_size.y)
	var texture_ratio: float = texture_size.x / max(1.0, texture_size.y)
	if texture_ratio > target_ratio:
		var width: float = texture_size.y * target_ratio
		return Rect2(Vector2((texture_size.x - width) * 0.5, 0.0), Vector2(width, texture_size.y))
	var height: float = texture_size.x / target_ratio
	return Rect2(Vector2(0.0, (texture_size.y - height) * 0.5), Vector2(texture_size.x, height))
