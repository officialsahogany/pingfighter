extends RefCounted

const PlayerCharacterPortraitCatalog := preload(
	"res://scripts/characters/player_character_portrait_catalog.gd"
)
const SCOREBOARD_FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const CEREMONIAL_BAK_TEXTURE: Texture2D = preload(
	"res://assets/sprites/hud/scoreboard_victory_ceremonial_bak_imagegen_v1.png"
)
const CEREMONIAL_BAK_RIGHT_TEXTURE: Texture2D = preload(
	"res://assets/sprites/hud/scoreboard_victory_ceremonial_bak_right_imagegen_v1.png"
)

const PORTRAIT_REVEAL_START := 0.40
const PORTRAIT_PUNCH_DURATION := 0.20
const PORTRAIT_ALPHA_DURATION := 0.025
const PORTRAIT_ALPHA_LEAD := 0.010
const PORTRAIT_FLASH_DURATION := 0.035
const PORTRAIT_START_SCALE := 1.18
const TEXT_REVEAL_DELAY := 0.08
const TEXT_PUNCH_DURATION := 0.18
const TEXT_ALPHA_DURATION := 0.018
const TEXT_ALPHA_LEAD := 0.010
const TEXT_START_SCALE := 1.40

const PORTRAIT_SIZE_MIN := 108.0
const PORTRAIT_SIZE_MAX := 126.0
const PORTRAIT_SIZE_RATIO := 0.29
const PLAYER_COLUMN_CENTER_X_RATIO := 0.468
const PLAQUE_CENTER_Y_RATIO := -0.200
const PLAQUE_LEFT_PADDING := 13.0
const PLAQUE_TOP_PADDING := 14.0
const PLAQUE_BOTTOM_PADDING := 19.0
const PLAQUE_RIGHT_EXTENSION := 72.0
const HANGER_RISE := 24.0
const BACKFLASH_RING_COUNT := 12
const BACKFLASH_MAX_ALPHA := 0.76
const CELEBRATION_OPEN_START := 0.62
const CELEBRATION_OPEN_DURATION := 0.30
const CELEBRATION_CONFETTI_START := 0.72
const CELEBRATION_CONFETTI_COUNT_PER_SIDE := 22
const CELEBRATION_BAK_HEIGHT_RATIO := 0.59
const CELEBRATION_BAK_HEIGHT_MIN := 202.0
const CELEBRATION_BAK_HEIGHT_MAX := 236.0
const CELEBRATION_BAK_CENTER_X_RATIO := 0.105
const CELEBRATION_BAK_TOP_Y_RATIO := -0.43
const FRAME_INK := Color(0.18, 0.085, 0.025, 1.0)
const FRAME_GOLD := Color(0.69, 0.43, 0.12, 1.0)
const FRAME_LIGHT := Color(0.95, 0.75, 0.31, 1.0)
const PAPER_LIGHT := Color(0.94, 0.865, 0.69, 1.0)
# Source RGB is ~2.8% brighter, but plaque shading measures 2.63% darker after compositing; preserve that final separation.
const BAY_PAPER_LIGHT := Color(0.968, 0.891, 0.716, 1.0)
const VICTORY_INK := Color(0.54, 0.055, 0.035, 1.0)
const OBANGSAEK_COLORS := [
	Color(0.68, 0.12, 0.08, 1.0),
	Color(0.14, 0.25, 0.48, 1.0),
	Color(0.88, 0.62, 0.14, 1.0),
	Color(0.24, 0.42, 0.18, 1.0),
	Color(0.90, 0.84, 0.68, 1.0),
]


func draw_celebration_back(
	canvas: CanvasItem,
	board_rect: Rect2,
	alpha: float,
	scoreboard_timer: float
) -> void:
	if canvas == null or alpha <= 0.001 or CEREMONIAL_BAK_TEXTURE == null:
		return
	var presentation: Dictionary = resolve_celebration_presentation(scoreboard_timer)
	var open_progress: float = float(presentation.get("open_progress", 0.0))
	var ornament_alpha: float = float(presentation.get("ornament_alpha", 0.0)) * alpha
	if ornament_alpha <= 0.001:
		return
	_draw_ceremonial_bak(canvas, resolve_celebration_bak_rect(board_rect, false), false, open_progress, ornament_alpha)
	_draw_ceremonial_bak(canvas, resolve_celebration_bak_rect(board_rect, true), true, open_progress, ornament_alpha)
	_draw_obangsaek_confetti(canvas, board_rect, scoreboard_timer, alpha)


func draw(
	canvas: CanvasItem,
	board_rect: Rect2,
	alpha: float,
	draw_context: Dictionary,
	player_name: String,
	scoreboard_timer: float
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	var presentation := resolve_presentation(scoreboard_timer)
	var portrait_alpha: float = float(presentation.get("portrait_alpha", 0.0)) * alpha
	var text_alpha: float = float(presentation.get("text_alpha", 0.0)) * alpha
	if portrait_alpha <= 0.001 and text_alpha <= 0.001:
		return
	var portrait_rect := _resolve_portrait_rect(
		board_rect,
		float(presentation.get("portrait_scale", 1.0))
	)
	var plaque_rect := resolve_plaque_rect(portrait_rect)
	var texture := _get_portrait_texture(draw_context)
	_draw_hanging_plaque(
		canvas,
		plaque_rect,
		portrait_rect,
		texture,
		draw_context,
		player_name,
		portrait_alpha
	)
	_draw_victory_stamp(
		canvas,
		portrait_rect,
		plaque_rect,
		format_seal_text(player_name),
		text_alpha,
		float(presentation.get("text_scale", 1.0))
	)


func draw_backflash(
	canvas: CanvasItem,
	board_rect: Rect2,
	alpha: float,
	scoreboard_timer: float
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	var presentation := resolve_presentation(scoreboard_timer)
	var flash_alpha: float = float(presentation.get("flash_alpha", 0.0)) * alpha
	if flash_alpha <= 0.001:
		return
	var portrait_rect := _resolve_portrait_rect(
		board_rect,
		float(presentation.get("portrait_scale", 1.0))
	)
	var plaque_rect := resolve_plaque_rect(portrait_rect)
	_draw_backflash(canvas, plaque_rect.get_center(), plaque_rect.size.y, flash_alpha)


func format_victory_text(_player_name: String = "") -> String:
	return "승리"


func format_seal_text(player_name: String) -> String:
	var clean_name := player_name.strip_edges()
	return clean_name.substr(0, 1) if not clean_name.is_empty() else "印"


func resolve_presentation(scoreboard_timer: float) -> Dictionary:
	var portrait_time: float = scoreboard_timer - PORTRAIT_REVEAL_START
	var portrait_progress := clampf(portrait_time / PORTRAIT_PUNCH_DURATION, 0.0, 1.0)
	var text_time: float = portrait_time - TEXT_REVEAL_DELAY
	var text_progress := clampf(text_time / TEXT_PUNCH_DURATION, 0.0, 1.0)
	return {
		"portrait_alpha": _smoothstep01(
			(portrait_time + PORTRAIT_ALPHA_LEAD) / PORTRAIT_ALPHA_DURATION
		),
		"portrait_scale": _resolve_punch_scale(portrait_progress, PORTRAIT_START_SCALE, 0.965),
		"flash_alpha": _resolve_flash_alpha(portrait_time),
		"text_alpha": _smoothstep01((text_time + TEXT_ALPHA_LEAD) / TEXT_ALPHA_DURATION),
		"text_scale": _resolve_punch_scale(text_progress, TEXT_START_SCALE, 0.92),
	}


func resolve_celebration_presentation(scoreboard_timer: float) -> Dictionary:
	var open_time: float = scoreboard_timer - CELEBRATION_OPEN_START
	var open_progress: float = clampf(open_time / CELEBRATION_OPEN_DURATION, 0.0, 1.0)
	return {
		"open_progress": open_progress,
		"ornament_alpha": _smoothstep01(open_progress / 0.22),
		"confetti_progress": clampf(
			(scoreboard_timer - CELEBRATION_CONFETTI_START) / 0.28,
			0.0,
			1.0
		),
	}


func resolve_celebration_bak_rect(board_rect: Rect2, right_side: bool) -> Rect2:
	var texture_size: Vector2 = CEREMONIAL_BAK_TEXTURE.get_size()
	var texture_aspect: float = texture_size.x / maxf(1.0, texture_size.y)
	var height: float = clampf(
		board_rect.size.y * CELEBRATION_BAK_HEIGHT_RATIO,
		CELEBRATION_BAK_HEIGHT_MIN,
		CELEBRATION_BAK_HEIGHT_MAX
	)
	var width: float = height * texture_aspect
	var center_x_ratio: float = (
		1.0 - CELEBRATION_BAK_CENTER_X_RATIO
		if right_side
		else CELEBRATION_BAK_CENTER_X_RATIO
	)
	var center_x: float = board_rect.position.x + board_rect.size.x * center_x_ratio
	var top_y: float = board_rect.position.y + board_rect.size.y * CELEBRATION_BAK_TOP_Y_RATIO
	return Rect2(Vector2(center_x - width * 0.5, top_y), Vector2(width, height))


func _draw_ceremonial_bak(
	canvas: CanvasItem,
	final_rect: Rect2,
	right_side: bool,
	open_progress: float,
	alpha: float
) -> void:
	var eased_open: float = _ease_out_back(open_progress)
	var pivot := Vector2(final_rect.get_center().x, final_rect.position.y + final_rect.size.y * 0.19)
	var opening_scale := Vector2(
		lerpf(0.82, 1.0, eased_open),
		lerpf(0.26, 1.0, eased_open)
	)
	var draw_size := Vector2(
		final_rect.size.x * opening_scale.x,
		final_rect.size.y * opening_scale.y
	)
	var draw_rect := Rect2(
		Vector2(pivot.x - draw_size.x * 0.5, pivot.y - draw_size.y * 0.19),
		draw_size
	)
	var texture: Texture2D = CEREMONIAL_BAK_RIGHT_TEXTURE if right_side else CEREMONIAL_BAK_TEXTURE
	canvas.draw_texture_rect(
		texture,
		draw_rect,
		false,
		Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	)


func _draw_obangsaek_confetti(
	canvas: CanvasItem,
	board_rect: Rect2,
	scoreboard_timer: float,
	alpha: float
) -> void:
	var celebration_time: float = scoreboard_timer - CELEBRATION_CONFETTI_START
	if celebration_time <= 0.0:
		return
	for side_index in range(2):
		var right_side: bool = side_index == 1
		var source_rect: Rect2 = resolve_celebration_bak_rect(board_rect, right_side)
		var origin := Vector2(
			source_rect.get_center().x,
			source_rect.position.y + source_rect.size.y * 0.29
		)
		var direction: float = -1.0 if right_side else 1.0
		for particle_index in range(CELEBRATION_CONFETTI_COUNT_PER_SIDE):
			var seed_index: int = particle_index + side_index * CELEBRATION_CONFETTI_COUNT_PER_SIDE
			var spawn_delay: float = float(particle_index) * 0.018 + _stable_random(seed_index, 1.0) * 0.08
			var local_time: float = celebration_time - spawn_delay
			if local_time <= 0.0:
				continue
			var lifetime: float = 1.34 + _stable_random(seed_index, 2.0) * 0.48
			if local_time >= lifetime:
				continue
			var life_progress: float = local_time / lifetime
			var outward_speed: float = 58.0 + _stable_random(seed_index, 3.0) * 72.0
			var scatter_direction: float = lerpf(-0.58, 1.0, _stable_random(seed_index, 9.0))
			var fall_speed: float = 58.0 + _stable_random(seed_index, 4.0) * 58.0
			var drift: float = sin(local_time * (2.2 + _stable_random(seed_index, 5.0) * 2.0) + float(seed_index)) * 10.0
			var position := origin + Vector2(
				direction * scatter_direction * outward_speed * local_time + drift,
				fall_speed * local_time + 42.0 * local_time * local_time
			)
			var paper_width: float = 3.8 + _stable_random(seed_index, 6.0) * 3.8
			var paper_height: float = (
				paper_width * (2.0 + _stable_random(seed_index, 7.0) * 1.6)
				if particle_index % 3 == 0
				else paper_width * (0.78 + _stable_random(seed_index, 7.0) * 0.55)
			)
			var fade: float = 1.0 - _smoothstep01((life_progress - 0.72) / 0.28)
			var paper_color: Color = OBANGSAEK_COLORS[seed_index % OBANGSAEK_COLORS.size()]
			var rotation: float = local_time * lerpf(-4.2, 4.2, _stable_random(seed_index, 8.0))
			_draw_confetti_piece(
				canvas,
				position,
				Vector2(paper_width, paper_height),
				rotation,
				Color(paper_color.r, paper_color.g, paper_color.b, 0.82 * fade * alpha)
			)


func _draw_confetti_piece(
	canvas: CanvasItem,
	center: Vector2,
	size: Vector2,
	rotation: float,
	color: Color
) -> void:
	if color.a <= 0.001:
		return
	var half_size: Vector2 = size * 0.5
	var local_points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y * 0.82),
		Vector2(half_size.x * 0.82, half_size.y),
		Vector2(-half_size.x, half_size.y * 0.88),
	])
	var rotated_points := PackedVector2Array()
	for local_point in local_points:
		rotated_points.append(center + local_point.rotated(rotation))
	canvas.draw_colored_polygon(
		rotated_points,
		color
	)


func _stable_random(index: int, salt: float) -> float:
	var value: float = sin(float(index + 1) * 12.9898 + salt * 78.233) * 43758.5453
	return value - floorf(value)


func resolve_face_source_rect(texture_size: Vector2, target_size: Vector2, spec: Dictionary) -> Rect2:
	if texture_size.x <= 1.0 or texture_size.y <= 1.0:
		return Rect2(Vector2.ZERO, texture_size)
	var target_aspect: float = target_size.x / maxf(1.0, target_size.y)
	var focus_value: Variant = spec.get("face_focus", Vector2(0.5, 0.28))
	var focus: Vector2 = focus_value if focus_value is Vector2 else Vector2(0.5, 0.28)
	var height_ratio: float = clampf(float(spec.get("source_height_ratio", 0.38)), 0.24, 0.46)
	var source_height: float = texture_size.y * height_ratio
	var source_width: float = source_height * target_aspect
	if source_width > texture_size.x:
		source_width = texture_size.x
		source_height = source_width / maxf(0.01, target_aspect)
	var center := Vector2(
		texture_size.x * clampf(focus.x, 0.0, 1.0),
		texture_size.y * clampf(focus.y, 0.0, 1.0)
	)
	var max_y: float = maxf(0.0, texture_size.y * 0.66 - source_height)
	var position := Vector2(
		clampf(center.x - source_width * 0.5, 0.0, maxf(0.0, texture_size.x - source_width)),
		clampf(center.y - source_height * 0.5, 0.0, max_y)
	)
	return Rect2(position, Vector2(source_width, source_height))


func _resolve_portrait_rect(board_rect: Rect2, scale: float) -> Rect2:
	var portrait_size: float = clampf(
		board_rect.size.y * PORTRAIT_SIZE_RATIO,
		PORTRAIT_SIZE_MIN,
		PORTRAIT_SIZE_MAX
	) * maxf(0.01, scale)
	var center := Vector2(
		board_rect.position.x + board_rect.size.x * PLAYER_COLUMN_CENTER_X_RATIO,
		board_rect.position.y + board_rect.size.y * PLAQUE_CENTER_Y_RATIO
	)
	return Rect2(center - Vector2.ONE * portrait_size * 0.5, Vector2.ONE * portrait_size)


func resolve_plaque_rect(portrait_rect: Rect2) -> Rect2:
	return Rect2(
		portrait_rect.position - Vector2(PLAQUE_LEFT_PADDING, PLAQUE_TOP_PADDING),
		Vector2(
			portrait_rect.size.x + PLAQUE_LEFT_PADDING + PLAQUE_RIGHT_EXTENSION,
			portrait_rect.size.y + PLAQUE_TOP_PADDING + PLAQUE_BOTTOM_PADDING
		)
	)


func _draw_hanging_plaque(
	canvas: CanvasItem,
	plaque_rect: Rect2,
	portrait_rect: Rect2,
	texture: Texture2D,
	draw_context: Dictionary,
	player_name: String,
	alpha: float
) -> void:
	var frame_alpha: float = clampf(alpha, 0.0, 1.0)
	_draw_plaque_hangers(canvas, plaque_rect, frame_alpha)
	var shoulder: float = minf(plaque_rect.size.x, plaque_rect.size.y) * 0.10
	var plaque_points := PackedVector2Array([
		plaque_rect.position + Vector2(shoulder, 0.0),
		Vector2(plaque_rect.end.x - shoulder, plaque_rect.position.y),
		plaque_rect.end - Vector2(0.0, shoulder),
		plaque_rect.end - Vector2(shoulder, 0.0),
		Vector2(plaque_rect.position.x + shoulder, plaque_rect.end.y),
		plaque_rect.position + Vector2(0.0, plaque_rect.size.y - shoulder),
	])
	var shadow_points := PackedVector2Array()
	for point in plaque_points:
		shadow_points.append(point + Vector2(4.0, 6.0))
	canvas.draw_colored_polygon(shadow_points, Color(0.08, 0.025, 0.01, 0.36 * frame_alpha))
	canvas.draw_colored_polygon(plaque_points, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, frame_alpha))
	var inner_points := PackedVector2Array()
	var plaque_center := plaque_rect.get_center()
	for point in plaque_points:
		inner_points.append(plaque_center + (point - plaque_center) * 0.955)
	canvas.draw_colored_polygon(inner_points, Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, frame_alpha))
	_draw_plaque_rails(canvas, plaque_rect, frame_alpha)
	_draw_plaque_crown(canvas, plaque_rect, frame_alpha)
	canvas.draw_rect(portrait_rect.grow(2.0), Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, frame_alpha))
	var stamp_bay_rect := resolve_stamp_bay_rect(plaque_rect, portrait_rect)
	_draw_stamp_bay(canvas, stamp_bay_rect, frame_alpha)
	_draw_vertical_calligraphy(canvas, stamp_bay_rect, format_victory_text(), frame_alpha)
	if texture != null:
		var character_type: String = str(draw_context.get("selected_character_type", "smasher"))
		var portrait_spec: Dictionary = PlayerCharacterPortraitCatalog.get_portrait_spec(character_type)
		var source_rect := resolve_face_source_rect(texture.get_size(), portrait_rect.size, portrait_spec)
		canvas.draw_texture_rect_region(
			texture,
			portrait_rect,
			source_rect,
			Color(1.0, 1.0, 1.0, frame_alpha),
			false,
			true
		)
	canvas.draw_rect(portrait_rect, Color(FRAME_LIGHT.r, FRAME_LIGHT.g, FRAME_LIGHT.b, frame_alpha), false, 2.0)
	_draw_winner_name_slip(canvas, portrait_rect, player_name, frame_alpha)
	_draw_plaque_tassels(canvas, plaque_rect, frame_alpha)


func _draw_stamp_bay(
	canvas: CanvasItem,
	bay_rect: Rect2,
	alpha: float
) -> void:
	canvas.draw_rect(bay_rect, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha))
	canvas.draw_rect(
		bay_rect.grow(-2.0),
		Color(BAY_PAPER_LIGHT.r, BAY_PAPER_LIGHT.g, BAY_PAPER_LIGHT.b, 0.94 * alpha)
	)
	_draw_hanji_bay_texture(canvas, bay_rect.grow(-3.0), alpha)


func _draw_hanji_bay_texture(canvas: CanvasItem, bay_rect: Rect2, alpha: float) -> void:
	var fiber_color := Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, 0.055 * alpha)
	for fiber_index in range(7):
		var y_ratio: float = 0.10 + float(fiber_index) * 0.125
		var x_inset: float = 4.0 + float(fiber_index % 3) * 2.0
		canvas.draw_line(
			Vector2(bay_rect.position.x + x_inset, bay_rect.position.y + bay_rect.size.y * y_ratio),
			Vector2(bay_rect.end.x - 4.0, bay_rect.position.y + bay_rect.size.y * (y_ratio + 0.018)),
			fiber_color,
			0.7
		)
	var flower_center := bay_rect.position + Vector2(bay_rect.size.x * 0.68, bay_rect.size.y * 0.73)
	var flower_color := Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, 0.07 * alpha)
	for petal_index in range(5):
		var angle: float = -PI * 0.5 + TAU * float(petal_index) / 5.0
		canvas.draw_circle(flower_center + Vector2.from_angle(angle) * 6.0, 3.5, flower_color)
	canvas.draw_circle(flower_center, 2.4, flower_color)


func resolve_stamp_bay_rect(plaque_rect: Rect2, portrait_rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(portrait_rect.end.x + 4.0, portrait_rect.position.y - 2.0),
		Vector2(
			maxf(1.0, plaque_rect.end.x - portrait_rect.end.x - 10.0),
			portrait_rect.size.y + 4.0
		)
	)


func _draw_vertical_calligraphy(
	canvas: CanvasItem,
	bay_rect: Rect2,
	text: String,
	alpha: float
) -> void:
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else ThemeDB.fallback_font
	if font == null or text.is_empty():
		return
	var font_size: int = int(clampf(roundf(bay_rect.size.x * 0.48), 23.0, 29.0))
	var first_center_y: float = bay_rect.position.y + bay_rect.size.y * 0.22
	var row_gap: float = font_size * 1.16
	var character_count: int = mini(2, text.length())
	for character_index in range(character_count):
		var character: String = text.substr(character_index, 1)
		var text_size := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var center := Vector2(
			bay_rect.get_center().x,
			first_center_y + float(character_index) * row_gap
		)
		var baseline := Vector2(
			center.x - text_size.x * 0.5,
			center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		)
		canvas.draw_string(
			font,
			baseline + Vector2(1.0, 1.0),
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, 0.22 * alpha)
		)
		canvas.draw_string(
			font,
			baseline,
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha)
		)


func _draw_plaque_rails(canvas: CanvasItem, plaque_rect: Rect2, alpha: float) -> void:
	var top_left := Vector2(plaque_rect.position.x - 8.0, plaque_rect.position.y + 5.0)
	var top_right := Vector2(plaque_rect.end.x + 8.0, plaque_rect.position.y + 5.0)
	var bottom_left := Vector2(plaque_rect.position.x - 4.0, plaque_rect.end.y - 5.0)
	var bottom_right := Vector2(plaque_rect.end.x + 4.0, plaque_rect.end.y - 5.0)
	for rail in [[top_left, top_right], [bottom_left, bottom_right]]:
		var rail_start: Vector2 = rail[0]
		var rail_end: Vector2 = rail[1]
		canvas.draw_line(
			rail_start,
			rail_end,
			Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha),
			8.0
		)
		canvas.draw_line(
			rail_start,
			rail_end,
			Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, alpha),
			4.0
		)
		canvas.draw_circle(rail_start, 4.5, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha))
		canvas.draw_circle(rail_start, 2.4, Color(FRAME_LIGHT.r, FRAME_LIGHT.g, FRAME_LIGHT.b, alpha))
		canvas.draw_circle(rail_end, 4.5, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha))
		canvas.draw_circle(rail_end, 2.4, Color(FRAME_LIGHT.r, FRAME_LIGHT.g, FRAME_LIGHT.b, alpha))


func _draw_plaque_crown(canvas: CanvasItem, plaque_rect: Rect2, alpha: float) -> void:
	var center := Vector2(plaque_rect.get_center().x, plaque_rect.position.y + 5.0)
	canvas.draw_circle(center, 7.2, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha))
	for petal_index in range(5):
		var angle: float = -PI * 0.5 + TAU * float(petal_index) / 5.0
		var petal_center: Vector2 = center + Vector2.from_angle(angle) * 4.0
		canvas.draw_circle(
			petal_center,
			2.9,
			Color(FRAME_LIGHT.r, FRAME_LIGHT.g, FRAME_LIGHT.b, alpha)
		)
	canvas.draw_circle(center, 1.9, Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, alpha))


func _draw_winner_name_slip(
	canvas: CanvasItem,
	portrait_rect: Rect2,
	player_name: String,
	alpha: float
) -> void:
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		return
	var slip_rect := Rect2(
		Vector2(portrait_rect.position.x + 7.0, portrait_rect.end.y + 2.0),
		Vector2(maxf(1.0, portrait_rect.size.x - 14.0), 14.0)
	)
	canvas.draw_rect(slip_rect, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, 0.92 * alpha))
	canvas.draw_rect(
		slip_rect.grow(-1.2),
		Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, 0.96 * alpha)
	)
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = 11
	while font_size > 8 and font.get_string_size(clean_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > slip_rect.size.x - 8.0:
		font_size -= 1
	var text_size := font.get_string_size(clean_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(
		slip_rect.get_center().x - text_size.x * 0.5,
		slip_rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	canvas.draw_string(
		font,
		baseline,
		clean_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, alpha)
	)


func _draw_plaque_hangers(canvas: CanvasItem, plaque_rect: Rect2, alpha: float) -> void:
	var rail_y: float = plaque_rect.position.y - HANGER_RISE
	var half_span: float = plaque_rect.size.x * 0.26
	var apex := Vector2(plaque_rect.get_center().x, rail_y)
	var left_attachment := Vector2(plaque_rect.get_center().x - half_span, plaque_rect.position.y + 4.0)
	var right_attachment := Vector2(plaque_rect.get_center().x + half_span, plaque_rect.position.y + 4.0)
	canvas.draw_line(apex, left_attachment, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha), 3.0)
	canvas.draw_line(apex, right_attachment, Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, alpha), 3.0)
	canvas.draw_arc(
		apex,
		5.0,
		0.0,
		TAU,
		16,
		Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, alpha),
		2.0
	)


func _draw_plaque_tassels(canvas: CanvasItem, plaque_rect: Rect2, alpha: float) -> void:
	for x_offset in [-plaque_rect.size.x * 0.31, plaque_rect.size.x * 0.31]:
		var start := Vector2(plaque_rect.get_center().x + x_offset, plaque_rect.end.y - 8.0)
		var knot := start + Vector2(0.0, 7.0)
		canvas.draw_line(start, knot, Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, alpha), 2.0)
		canvas.draw_circle(knot, 2.8, Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, alpha))
		for strand_offset in [-3.0, 0.0, 3.0]:
			canvas.draw_line(
				knot,
				knot + Vector2(strand_offset, 9.0),
				Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, 0.88 * alpha),
				1.5
			)


func _draw_backflash(
	canvas: CanvasItem,
	center: Vector2,
	plaque_height: float,
	alpha: float
) -> void:
	if alpha <= 0.001:
		return
	for ring_index in range(BACKFLASH_RING_COUNT):
		var ring_progress: float = float(ring_index) / float(BACKFLASH_RING_COUNT - 1)
		var radius: float = plaque_height * lerpf(0.78, 0.54, ring_progress)
		var feather: float = _smoothstep01(ring_progress)
		var ring_alpha: float = alpha * lerpf(0.035, BACKFLASH_MAX_ALPHA, feather)
		canvas.draw_circle(center, radius, Color(1.0, 0.96, 0.78, ring_alpha))


func _draw_victory_stamp(
	canvas: CanvasItem,
	portrait_rect: Rect2,
	plaque_rect: Rect2,
	text: String,
	alpha: float,
	scale: float
) -> void:
	if alpha <= 0.001:
		return
	var font: Font = SCOREBOARD_FONT if SCOREBOARD_FONT != null else ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = int(clampf(roundf(portrait_rect.size.y * 0.17), 18.0, 22.0))
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var base_stamp_size := Vector2(text_size.x + 12.0, text_size.y + 10.0)
	var stamp_rect := resolve_stamp_rect(portrait_rect, plaque_rect, base_stamp_size, scale)
	var effective_scale: float = minf(
		stamp_rect.size.x / maxf(1.0, base_stamp_size.x),
		stamp_rect.size.y / maxf(1.0, base_stamp_size.y)
	)
	canvas.draw_rect(stamp_rect, Color(VICTORY_INK.r, VICTORY_INK.g, VICTORY_INK.b, alpha))
	canvas.draw_rect(stamp_rect.grow(-2.0), Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, 0.42 * alpha), false, 1.0)
	var scaled_font_size: int = maxi(12, int(roundf(float(font_size) * effective_scale)))
	var scaled_text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, scaled_font_size)
	var stamp_center := stamp_rect.get_center()
	var baseline := Vector2(
		stamp_center.x - scaled_text_size.x * 0.5,
		stamp_center.y + (font.get_ascent(scaled_font_size) - font.get_descent(scaled_font_size)) * 0.5
	)
	canvas.draw_string_outline(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		scaled_font_size,
		1,
		Color(FRAME_INK.r, FRAME_INK.g, FRAME_INK.b, 0.72 * alpha)
	)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		scaled_font_size,
		Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, clampf(alpha, 0.0, 1.0))
	)


func resolve_stamp_rect(
	portrait_rect: Rect2,
	plaque_rect: Rect2,
	base_size: Vector2,
	scale: float
) -> Rect2:
	var anchor := plaque_rect.end - Vector2(6.0, 12.0)
	var desired_size := base_size * maxf(0.01, scale)
	var minimum_left: float = portrait_rect.end.x + 4.0
	var left: float = maxf(minimum_left, anchor.x - desired_size.x)
	var top: float = maxf(plaque_rect.position.y + 6.0, anchor.y - desired_size.y)
	return Rect2(Vector2(left, top), Vector2(anchor.x - left, anchor.y - top))


func _resolve_punch_scale(progress: float, start_scale: float, undershoot_scale: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	if t < 0.72:
		return lerpf(start_scale, undershoot_scale, _ease_out_cubic(t / 0.72))
	return lerpf(undershoot_scale, 1.0, _smoothstep01((t - 0.72) / 0.28))


func _resolve_flash_alpha(portrait_time: float) -> float:
	if portrait_time < 0.0 or portrait_time > PORTRAIT_FLASH_DURATION:
		return 0.0
	return 1.0 - _smoothstep01(portrait_time / PORTRAIT_FLASH_DURATION)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_out_back(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	var overshoot: float = 1.35
	var shifted: float = t - 1.0
	return 1.0 + (overshoot + 1.0) * shifted * shifted * shifted + overshoot * shifted * shifted


func _smoothstep01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_portrait_texture(draw_context: Dictionary) -> Texture2D:
	var textures_value: Variant = draw_context.get("textures", {})
	if not (textures_value is Dictionary):
		return null
	var value: Variant = (textures_value as Dictionary).get("scoreboard_victory_portrait", null)
	return value as Texture2D if value is Texture2D else null
