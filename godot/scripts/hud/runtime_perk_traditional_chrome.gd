extends RefCounted

# Shared traditional chrome for the standard runtime Mugong-choice modal. The
# renderer supplies prewarmed painted-paper and ornament textures; deterministic
# procedural motifs remain available as a load-failure fallback.

const INK_NAVY := Color(13.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0)
const LACQUER_BLACK := Color(18.0 / 255.0, 14.0 / 255.0, 12.0 / 255.0)
const DARK_WOOD := Color(52.0 / 255.0, 35.0 / 255.0, 23.0 / 255.0)
const AGED_BRASS := Color(151.0 / 255.0, 112.0 / 255.0, 52.0 / 255.0)
const BRASS_LIGHT := Color(211.0 / 255.0, 172.0 / 255.0, 89.0 / 255.0)
const HANJI := Color(216.0 / 255.0, 200.0 / 255.0, 165.0 / 255.0)
const HANJI_LIGHT := Color(225.0 / 255.0, 210.0 / 255.0, 174.0 / 255.0)
const HANJI_SHADOW := Color(169.0 / 255.0, 143.0 / 255.0, 92.0 / 255.0)
const INK_TEXT := Color(45.0 / 255.0, 35.0 / 255.0, 27.0 / 255.0)
const JADE := Color(98.0 / 255.0, 155.0 / 255.0, 139.0 / 255.0)
const SEAL_RED := Color(139.0 / 255.0, 44.0 / 255.0, 33.0 / 255.0)
const BACKDROP_DIM_ALPHA := 0.64
const BACKDROP_WASH_ALPHA := 0.06
const CARD_PAPER_VARIANT_COUNT := 4
# 카드 바깥 테두리(어두운 목재 + 황동 선) 두께. 종이면은 여기서 시작하므로 카드
# 안쪽에 무언가를 앉히는 소비자는 이 상수를 읽어야 한다 -- 리터럴 8.0을 다시
# 타이핑하면 테두리를 바꿀 때 조용히 어긋난다.
const CARD_PAPER_INSET := 8.0
const CARD_PAPER_TEXTURE_ALPHA := 0.46
const PAPER_FIBER_ALPHA := 0.036
const PAPER_PATINA_ALPHA := 0.070
const PAPER_LANDSCAPE_ALPHA := 0.080
const PAINTED_CARD_ORNAMENT_ALPHA := 0.16
const CARD_CORNER_ORNAMENT_SIZE := 24.0
const CARD_CORNER_ORNAMENT_STROKE := 1.35
const TITLE_PLAQUE_FILL_ALPHA := 0.64
const TITLE_RAIL_WIDTH_RATIO := 0.68
const ORNAMENT_ATLAS_GRID := Vector2i(2, 2)
const ORNAMENT_MOUNTAIN_CELL := Vector2i(0, 0)
const ORNAMENT_PINE_CLOUD_CELL := Vector2i(0, 1)
const ORNAMENT_RIVER_CELL := Vector2i(1, 1)


static func draw_backdrop(canvas: CanvasItem, view_size: Vector2, alpha: float, ornament_atlas: Texture2D = null) -> Rect2:
	var full := Rect2(Vector2.ZERO, view_size)
	# Preserve the live game scene under the modal, matching the original perk
	# overlay contract. The traditional chrome is an outer frame plus a restrained
	# navy wash, never an opaque fullscreen replacement background.
	canvas.draw_rect(full, Color(0.0, 0.0, 20.0 / 255.0, BACKDROP_DIM_ALPHA * alpha))
	var outer := full.grow(-8.0)
	canvas.draw_rect(outer, Color(LACQUER_BLACK.r, LACQUER_BLACK.g, LACQUER_BLACK.b, 0.88 * alpha), false, 9.0)
	canvas.draw_rect(outer.grow(-5.0), Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, 0.98 * alpha), false, 5.0)
	canvas.draw_rect(outer.grow(-10.0), Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.86 * alpha), false, 2.0)
	var inner := outer.grow(-15.0)
	canvas.draw_rect(inner, Color(INK_NAVY.r, INK_NAVY.g, INK_NAVY.b, BACKDROP_WASH_ALPHA * alpha))
	canvas.draw_rect(inner, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.34 * alpha), false, 1.0)
	_draw_hanji_wash(canvas, inner, alpha)
	if not _draw_backdrop_painted_ornaments(canvas, inner, ornament_atlas, alpha):
		_draw_ink_landscape(canvas, inner, alpha)
	_draw_vignette(canvas, inner, alpha)
	_draw_outer_corners(canvas, outer, alpha)
	_draw_outer_knots(canvas, outer, alpha)
	return inner


static func draw_title_plaque(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	# An open ink-cloud title composition replaces the former rigid black box.  The
	# short lacquer rails still anchor the heading to the outer frame without making
	# it read as a modern button.
	var center := rect.get_center()
	var cloud_color := Color(INK_NAVY.r, INK_NAVY.g, INK_NAVY.b, TITLE_PLAQUE_FILL_ALPHA * alpha)
	# Uneven dry-brush bands soften the silhouette without adding glow. The three
	# widths deliberately differ so the heading reads as painted ink, not a button.
	canvas.draw_line(center + Vector2(-rect.size.x * 0.38, -8.0), center + Vector2(rect.size.x * 0.35, -8.0), cloud_color, rect.size.y * 0.30)
	canvas.draw_line(center + Vector2(-rect.size.x * 0.43, 1.0), center + Vector2(rect.size.x * 0.41, 1.0), cloud_color, rect.size.y * 0.31)
	canvas.draw_line(center + Vector2(-rect.size.x * 0.34, 10.0), center + Vector2(rect.size.x * 0.38, 10.0), cloud_color, rect.size.y * 0.27)
	canvas.draw_circle(center + Vector2(-rect.size.x * 0.34, 3.0), rect.size.y * 0.18, Color(INK_NAVY.r, INK_NAVY.g, INK_NAVY.b, 0.30 * alpha))
	canvas.draw_circle(center + Vector2(rect.size.x * 0.35, -1.0), rect.size.y * 0.16, Color(INK_NAVY.r, INK_NAVY.g, INK_NAVY.b, 0.26 * alpha))
	var rail_half_width: float = rect.size.x * TITLE_RAIL_WIDTH_RATIO * 0.5
	var rail_left: float = center.x - rail_half_width
	var rail_right: float = center.x + rail_half_width
	for rail_y: float in [rect.position.y + 9.0, rect.end.y - 9.0]:
		canvas.draw_line(Vector2(rail_left, rail_y), Vector2(rail_right, rail_y), Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, 0.82 * alpha), 4.5)
		canvas.draw_line(Vector2(rail_left, rail_y), Vector2(rail_right, rail_y), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.62 * alpha), 1.2)
		canvas.draw_circle(Vector2(rail_left, rail_y), 3.2, Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.82 * alpha))
		canvas.draw_circle(Vector2(rail_right, rail_y), 3.2, Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.82 * alpha))
	var halo_center := rect.get_center() + Vector2(0.0, 2.0)
	var halo_radius: float = minf(rect.size.x * 0.22, rect.size.y * 0.46)
	canvas.draw_circle(halo_center, halo_radius, Color(72.0 / 255.0, 63.0 / 255.0, 48.0 / 255.0, 0.11 * alpha))
	canvas.draw_arc(halo_center, halo_radius * 0.82, -2.7, 1.85, 24, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.21 * alpha), 1.1)
	canvas.draw_arc(halo_center, halo_radius * 0.65, 0.25, 2.45, 18, Color(INK_TEXT.r, INK_TEXT.g, INK_TEXT.b, 0.16 * alpha), 1.0)
	_draw_cloud_curl(canvas, Vector2(rect.position.x + 14.0, center.y), 1.0, alpha)
	_draw_cloud_curl(canvas, Vector2(rect.end.x - 14.0, center.y), -1.0, alpha)
	_draw_title_seal(canvas, Rect2(Vector2(rect.end.x - 48.0, rect.end.y - 31.0), Vector2(21.0, 21.0)), alpha)


static func draw_card_base(
	canvas: CanvasItem,
	rect: Rect2,
	selected: bool,
	premium: bool,
	alpha: float,
	pulse: float,
	variant: int = 0,
	ornament_atlas: Texture2D = null,
	paper_texture: Texture2D = null
) -> Rect2:
	var selection_alpha: float = (0.24 + pulse * 0.18) * alpha
	if selected:
		canvas.draw_rect(rect.grow(16.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.055 * alpha))
		canvas.draw_rect(rect.grow(13.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, selection_alpha), false, 5.0)
		canvas.draw_rect(rect.grow(7.0), Color(1.0, 220.0 / 255.0, 120.0 / 255.0, 0.78 * alpha), false, 2.5)
	var card_shadow := Rect2(rect.position - Vector2(3.0, 2.0) + Vector2(2.0, 4.0), rect.size + Vector2(6.0, 4.0))
	canvas.draw_rect(card_shadow, Color(0.0, 0.0, 0.0, 0.32 * alpha))
	canvas.draw_rect(rect, Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, 0.98 * alpha))
	canvas.draw_rect(rect.grow(-4.0), Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.96 * alpha), false, 2.0)
	var paper := rect.grow(-CARD_PAPER_INSET)
	var paper_color := HANJI_LIGHT.lerp(Color(218.0 / 255.0, 190.0 / 255.0, 126.0 / 255.0), 0.20) if premium else HANJI_LIGHT
	canvas.draw_rect(paper, Color(paper_color.r, paper_color.g, paper_color.b, 0.98 * alpha))
	canvas.draw_rect(paper, Color(HANJI_SHADOW.r, HANJI_SHADOW.g, HANJI_SHADOW.b, 0.66 * alpha), false, 1.0)
	# The surface recipe is deterministic per card position: enough variation to
	# avoid a cloned-panel read, with no random state churn or texture upload in the
	# always-redrawn choice modal.
	var paper_variant: int = wrapi(variant, 0, CARD_PAPER_VARIANT_COUNT)
	_draw_card_paper_texture(canvas, paper, paper_variant, paper_texture, alpha)
	_draw_paper_tone_variation(canvas, paper, paper_variant, alpha)
	_draw_paper_fibres(canvas, paper, paper_variant, alpha)
	_draw_paper_flecks(canvas, paper, paper_variant, alpha)
	_draw_paper_patina(canvas, paper, paper_variant, alpha)
	if not _draw_card_painted_ornament(canvas, paper, paper_variant, ornament_atlas, alpha):
		_draw_lower_ink_landscape(canvas, paper, paper_variant, alpha)
	_draw_card_corner_ornaments(canvas, paper.grow(-1.0), alpha, selected or premium)
	if selected:
		_draw_selection_sparks(canvas, rect, alpha, pulse)
	return paper


static func _draw_card_paper_texture(canvas: CanvasItem, rect: Rect2, variant: int, texture: Texture2D, alpha: float) -> bool:
	if canvas == null or texture == null or not rect.has_area():
		return false
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	# Each card samples a nearby crop of the same authored hanji master. This keeps
	# one cache-friendly resource while avoiding four visibly cloned fibre fields.
	var crop_size := texture_size * Vector2(0.91, 0.93)
	var travel := texture_size - crop_size
	var x_phase: float = float(variant % 2)
	var y_phase: float = floorf(float(variant) / 2.0)
	var source := Rect2(Vector2(travel.x * x_phase, travel.y * y_phase), crop_size)
	canvas.draw_texture_rect_region(
		texture,
		rect,
		source,
		Color(1.0, 1.0, 1.0, CARD_PAPER_TEXTURE_ALPHA * alpha),
		false,
		true
	)
	return true


static func _draw_backdrop_painted_ornaments(canvas: CanvasItem, rect: Rect2, texture: Texture2D, alpha: float) -> bool:
	if texture == null or not rect.has_area():
		return false
	var lower_height: float = minf(rect.size.y * 0.22, 250.0)
	var lower_y: float = rect.end.y - lower_height - 3.0
	var left_dest := Rect2(
		Vector2(rect.position.x + rect.size.x * 0.02, lower_y),
		Vector2(rect.size.x * 0.34, lower_height)
	)
	var right_dest := Rect2(
		Vector2(rect.end.x - rect.size.x * 0.38, lower_y),
		Vector2(rect.size.x * 0.36, lower_height)
	)
	var left_drawn := _draw_ornament_cell(
		canvas,
		texture,
		left_dest,
		ORNAMENT_PINE_CLOUD_CELL,
		Color(0.50, 0.47, 0.40, 0.10 * alpha),
		Rect2(0.0, 0.20, 1.0, 0.75)
	)
	var right_drawn := _draw_ornament_cell(
		canvas,
		texture,
		right_dest,
		ORNAMENT_RIVER_CELL,
		Color(0.48, 0.45, 0.39, 0.09 * alpha),
		Rect2(0.0, 0.16, 1.0, 0.78)
	)
	return left_drawn and right_drawn


static func _draw_card_painted_ornament(canvas: CanvasItem, rect: Rect2, variant: int, texture: Texture2D, alpha: float) -> bool:
	if texture == null or not rect.has_area():
		return false
	var margin: float = maxf(4.0, rect.size.x * 0.025)
	var band_height: float = rect.size.y * 0.30
	var band_dest := Rect2(
		Vector2(rect.position.x + margin, rect.end.y - band_height - margin),
		Vector2(rect.size.x - margin * 2.0, band_height)
	)
	match wrapi(variant, 0, CARD_PAPER_VARIANT_COUNT):
		0:
			return _draw_ornament_cell(
				canvas,
				texture,
				band_dest,
				ORNAMENT_MOUNTAIN_CELL,
				Color(0.58, 0.53, 0.44, PAINTED_CARD_ORNAMENT_ALPHA * alpha),
				Rect2(0.0, 0.32, 1.0, 0.64)
			)
		1:
			return _draw_ornament_cell(
				canvas,
				texture,
				band_dest,
				ORNAMENT_PINE_CLOUD_CELL,
				Color(0.54, 0.50, 0.42, PAINTED_CARD_ORNAMENT_ALPHA * 0.72 * alpha),
				Rect2(0.34, 0.40, 0.64, 0.52)
			)
		2:
			return _draw_ornament_cell(
				canvas,
				texture,
				band_dest,
				ORNAMENT_PINE_CLOUD_CELL,
				Color(0.56, 0.51, 0.42, PAINTED_CARD_ORNAMENT_ALPHA * 0.92 * alpha),
				Rect2(0.0, 0.20, 1.0, 0.74)
			)
		_:
			return _draw_ornament_cell(
				canvas,
				texture,
				band_dest,
				ORNAMENT_RIVER_CELL,
				Color(0.60, 0.53, 0.43, PAINTED_CARD_ORNAMENT_ALPHA * alpha),
				Rect2(0.0, 0.16, 1.0, 0.78)
			)


static func _draw_ornament_cell(
	canvas: CanvasItem,
	texture: Texture2D,
	dest: Rect2,
	cell: Vector2i,
	modulate: Color,
	cell_uv: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
) -> bool:
	if canvas == null or texture == null or not dest.has_area():
		return false
	var atlas_size: Vector2 = texture.get_size()
	if atlas_size.x <= 0.0 or atlas_size.y <= 0.0:
		return false
	var cell_size := Vector2(
		atlas_size.x / float(ORNAMENT_ATLAS_GRID.x),
		atlas_size.y / float(ORNAMENT_ATLAS_GRID.y)
	)
	var cell_origin := Vector2(float(cell.x), float(cell.y)) * cell_size
	var source := Rect2(
		cell_origin + cell_uv.position * cell_size,
		cell_uv.size * cell_size
	)
	canvas.draw_texture_rect_region(texture, dest, source, modulate, false, true)
	return true


static func draw_nameplate(canvas: CanvasItem, rect: Rect2, selected: bool, premium: bool, alpha: float) -> void:
	var fill := Color(56.0 / 255.0, 37.0 / 255.0, 23.0 / 255.0, 0.94 * alpha)
	if premium:
		fill = Color(70.0 / 255.0, 47.0 / 255.0, 23.0 / 255.0, 0.97 * alpha)
	var tip: float = minf(7.0, rect.size.y * 0.22)
	var plate := PackedVector2Array([
		Vector2(rect.position.x + tip, rect.position.y),
		Vector2(rect.end.x - tip, rect.position.y),
		Vector2(rect.end.x, rect.get_center().y),
		Vector2(rect.end.x - tip, rect.end.y),
		Vector2(rect.position.x + tip, rect.end.y),
		Vector2(rect.position.x, rect.get_center().y),
	])
	canvas.draw_colored_polygon(plate, Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, 0.98 * alpha))
	var inner := rect.grow(-3.0)
	canvas.draw_rect(inner, fill)
	var border := BRASS_LIGHT if selected or premium else AGED_BRASS
	canvas.draw_line(Vector2(rect.position.x + tip, rect.position.y), Vector2(rect.end.x - tip, rect.position.y), Color(border.r, border.g, border.b, (0.92 if selected else 0.65) * alpha), 1.4)
	canvas.draw_line(Vector2(rect.position.x + tip, rect.end.y), Vector2(rect.end.x - tip, rect.end.y), Color(border.r, border.g, border.b, (0.92 if selected else 0.65) * alpha), 1.4)
	canvas.draw_circle(Vector2(rect.position.x + tip + 3.0, rect.get_center().y), 1.5, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.64 * alpha))
	canvas.draw_circle(Vector2(rect.end.x - tip - 3.0, rect.get_center().y), 1.5, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.64 * alpha))


static func draw_status_ledger(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> Rect2:
	var ledger_shadow := Rect2(rect.position - Vector2(4.0, 5.0) + Vector2(2.0, 3.0), rect.size + Vector2(8.0, 10.0))
	canvas.draw_rect(ledger_shadow, Color(0.0, 0.0, 0.0, 0.30 * alpha))
	canvas.draw_rect(rect, Color(9.0 / 255.0, 19.0 / 255.0, 31.0 / 255.0, 0.96 * alpha))
	canvas.draw_rect(rect, Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.92 * alpha), false, 3.0)
	canvas.draw_rect(rect.grow(-5.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.34 * alpha), false, 1.0)
	var inner := rect.grow(-9.0)
	canvas.draw_rect(inner, Color(15.0 / 255.0, 29.0 / 255.0, 43.0 / 255.0, 0.82 * alpha))
	canvas.draw_line(Vector2(inner.position.x + 8.0, inner.position.y + 28.0), Vector2(inner.end.x - 8.0, inner.position.y + 28.0), Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.28 * alpha), 1.0)
	var wash_center := inner.position + Vector2(inner.size.x * 0.46, inner.size.y * 0.72)
	canvas.draw_arc(wash_center, inner.size.y * 0.28, PI, TAU, 18, Color(JADE.r, JADE.g, JADE.b, 0.055 * alpha), 2.0)
	_draw_corner_brackets(canvas, rect.grow(-2.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.72 * alpha), 12.0, 2.0)
	return inner


static func draw_status_counter_board(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> Rect2:
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.28 * alpha))
	canvas.draw_rect(rect, Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, 0.96 * alpha))
	var inner := rect.grow(-4.0)
	canvas.draw_rect(inner, Color(20.0 / 255.0, 31.0 / 255.0, 39.0 / 255.0, 0.94 * alpha))
	canvas.draw_rect(inner, Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.48 * alpha), false, 1.0)
	for ratio: float in [0.34, 0.67]:
		var y: float = inner.position.y + inner.size.y * ratio
		canvas.draw_line(Vector2(inner.position.x + 8.0, y), Vector2(inner.end.x - 8.0, y), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.18 * alpha), 1.0)
	_draw_corner_brackets(canvas, rect, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.55 * alpha), 7.0, 1.0)
	return inner


# 하단 능력치 원장(2026-08-06). 무공 원장(draw_status_ledger)과 같은 황동 프레임
# 언어를 쓰되 지면은 한지(밝은 종이)로 간다 -- 안에 그려지는 행이 캐릭터 정보창의
# 공용 프레젠터(draw_cached_player_stat_rows)이고, 그 프레젠터의 라벨/수치/게이지
# 색은 전부 밝은 한지 배경 기준의 먹색이라 어두운 원장 위에 얹으면 읽히지 않는다.
static func draw_stats_ledger(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> Rect2:
	var ledger_shadow := Rect2(rect.position - Vector2(2.0, 2.0), rect.size + Vector2(6.0, 8.0))
	canvas.draw_rect(ledger_shadow, Color(0.0, 0.0, 0.0, 0.30 * alpha))
	canvas.draw_rect(rect, Color(HANJI.r, HANJI.g, HANJI.b, 0.97 * alpha))
	_draw_paper_tone_variation(canvas, rect, 1, alpha * 0.9)
	canvas.draw_rect(rect, Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.92 * alpha), false, 3.0)
	canvas.draw_rect(rect.grow(-5.0), Color(HANJI_SHADOW.r, HANJI_SHADOW.g, HANJI_SHADOW.b, 0.42 * alpha), false, 1.0)
	_draw_corner_brackets(canvas, rect.grow(-2.0), Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.62 * alpha), 12.0, 2.0)
	return rect.grow(-11.0)


static func draw_talisman_slot(canvas: CanvasItem, rect: Rect2, filled: bool, accent: Color, alpha: float = 1.0) -> Rect2:
	canvas.draw_rect(Rect2(rect.position + Vector2(1.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.30 * alpha))
	canvas.draw_rect(rect, Color(11.0 / 255.0, 18.0 / 255.0, 24.0 / 255.0, 0.94 * alpha))
	var border := accent if filled else AGED_BRASS
	canvas.draw_rect(rect, Color(border.r, border.g, border.b, (0.82 if filled else 0.48) * alpha), false, 1.5)
	canvas.draw_rect(rect.grow(-4.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.18 * alpha), false, 1.0)
	canvas.draw_line(Vector2(rect.position.x + 6.0, rect.position.y + 7.0), Vector2(rect.end.x - 6.0, rect.position.y + 7.0), Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.28 * alpha), 1.0)
	var knot := Vector2(rect.get_center().x, rect.end.y - 5.0)
	canvas.draw_circle(knot, 2.0, Color(border.r, border.g, border.b, 0.42 * alpha))
	canvas.draw_line(knot + Vector2(-1.0, 2.0), knot + Vector2(-3.0, 6.0), Color(border.r, border.g, border.b, 0.34 * alpha), 1.0)
	canvas.draw_line(knot + Vector2(1.0, 2.0), knot + Vector2(3.0, 6.0), Color(border.r, border.g, border.b, 0.34 * alpha), 1.0)
	_draw_corner_brackets(canvas, rect, Color(border.r, border.g, border.b, 0.55 * alpha), 6.0, 1.0)
	return rect.grow(-6.0)


static func draw_medallion_finish(canvas: CanvasItem, center: Vector2, radius: float, warm: bool, alpha: float = 1.0) -> void:
	var wash := Color(53.0 / 255.0, 36.0 / 255.0, 19.0 / 255.0, 0.055 * alpha) if warm else Color(9.0 / 255.0, 24.0 / 255.0, 31.0 / 255.0, 0.085 * alpha)
	canvas.draw_circle(center, radius * 0.78, wash)
	var mark_color := Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.48 * alpha)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var tangent := Vector2(-sin(angle), cos(angle))
		var mark_center := center + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(mark_center - tangent * 3.0, mark_center + tangent * 3.0, mark_color, 1.0)


static func draw_hint_ribbon(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	var center := rect.get_center()
	var cloud := Color(INK_NAVY.r, INK_NAVY.g, INK_NAVY.b, 0.68 * alpha)
	canvas.draw_rect(Rect2(Vector2(rect.position.x + 20.0, rect.position.y + 4.0), Vector2(rect.size.x - 40.0, rect.size.y - 8.0)), cloud)
	canvas.draw_circle(Vector2(rect.position.x + 21.0, center.y), rect.size.y * 0.34, cloud)
	canvas.draw_circle(Vector2(rect.end.x - 21.0, center.y), rect.size.y * 0.34, cloud)
	canvas.draw_line(Vector2(rect.position.x + 28.0, rect.position.y + 4.0), Vector2(rect.end.x - 28.0, rect.position.y + 4.0), Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.42 * alpha), 1.0)
	_draw_cloud_curl(canvas, Vector2(rect.position.x + 8.0, center.y), 1.0, alpha * 0.65)
	_draw_cloud_curl(canvas, Vector2(rect.end.x - 8.0, center.y), -1.0, alpha * 0.65)


static func draw_empty_seal(canvas: CanvasItem, center: Vector2, radius: float, alpha: float = 1.0) -> void:
	var color := Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.30 * alpha)
	canvas.draw_arc(center, radius, 0.0, TAU, 18, color, 1.2)
	canvas.draw_arc(center, radius * 0.56, -2.4, 0.8, 12, color, 1.0)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.30),
		center + Vector2(radius * 0.30, 0.0),
		center + Vector2(0.0, radius * 0.30),
		center + Vector2(-radius * 0.30, 0.0),
		center + Vector2(0.0, -radius * 0.30),
	])
	canvas.draw_polyline(diamond, color, 1.0, true)


static func _draw_hanji_wash(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	# Deep-blue paper clouds in the lower corners, intentionally below text/card
	# contrast. These replace the flat fullscreen dim without becoming scenery art.
	for side: float in [-1.0, 1.0]:
		var x: float = rect.get_center().x + side * rect.size.x * 0.39
		var y: float = rect.end.y - rect.size.y * 0.12
		var cloud := Color(98.0 / 255.0, 117.0 / 255.0, 121.0 / 255.0, 0.055 * alpha)
		canvas.draw_circle(Vector2(x, y), rect.size.y * 0.07, cloud)
		canvas.draw_circle(Vector2(x - side * rect.size.x * 0.06, y + rect.size.y * 0.018), rect.size.y * 0.045, cloud)
		canvas.draw_line(
			Vector2(x - rect.size.x * 0.12, y + rect.size.y * 0.045),
			Vector2(x + rect.size.x * 0.12, y + rect.size.y * 0.045),
			cloud,
			2.0
		)


static func _draw_ink_landscape(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var base_y: float = rect.end.y - rect.size.y * 0.10
	var ink := Color(67.0 / 255.0, 84.0 / 255.0, 81.0 / 255.0, 0.055 * alpha)
	var points := PackedVector2Array([
		Vector2(rect.position.x + rect.size.x * 0.11, base_y),
		Vector2(rect.position.x + rect.size.x * 0.20, base_y - rect.size.y * 0.08),
		Vector2(rect.position.x + rect.size.x * 0.27, base_y - rect.size.y * 0.025),
		Vector2(rect.position.x + rect.size.x * 0.36, base_y - rect.size.y * 0.13),
		Vector2(rect.position.x + rect.size.x * 0.47, base_y),
	])
	canvas.draw_polyline(points, ink, 2.0, true)
	for offset: float in [0.0, rect.size.x * 0.42]:
		var cloud_center := Vector2(rect.position.x + rect.size.x * 0.28 + offset, rect.position.y + rect.size.y * 0.24)
		canvas.draw_arc(cloud_center, rect.size.y * 0.035, PI * 0.05, PI * 1.1, 12, ink, 1.2)
		canvas.draw_arc(cloud_center + Vector2(rect.size.x * 0.025, 2.0), rect.size.y * 0.025, PI, TAU, 10, ink, 1.0)


static func _draw_vignette(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	for index: int in range(5):
		var inset: float = float(index) * 5.0
		var strength: float = (0.18 - float(index) * 0.025) * alpha
		canvas.draw_rect(rect.grow(-inset), Color(2.0 / 255.0, 5.0 / 255.0, 10.0 / 255.0, strength), false, 10.0)


static func _draw_paper_tone_variation(canvas: CanvasItem, rect: Rect2, variant: int, alpha: float) -> void:
	# Broad translucent bands make the sheet breathe like handmade paper instead of
	# a flat beige fill. They stay well below body-text contrast.
	var band_width: float = rect.size.x / 7.0
	for index: int in range(7):
		var x: float = rect.position.x + band_width * float(index)
		var warm: bool = (index + variant) % 3 == 0
		var band_color := Color(121.0 / 255.0, 83.0 / 255.0, 45.0 / 255.0, 0.020 * alpha)
		if not warm:
			band_color = Color(246.0 / 255.0, 235.0 / 255.0, 204.0 / 255.0, 0.025 * alpha)
		canvas.draw_rect(Rect2(Vector2(x, rect.position.y + 2.0), Vector2(band_width + 1.0, rect.size.y - 4.0)), band_color)


static func _draw_paper_fibres(canvas: CanvasItem, rect: Rect2, variant: int, alpha: float) -> void:
	var warm_fibre := Color(113.0 / 255.0, 82.0 / 255.0, 52.0 / 255.0, PAPER_FIBER_ALPHA * alpha)
	var pale_fibre := Color(248.0 / 255.0, 239.0 / 255.0, 211.0 / 255.0, PAPER_FIBER_ALPHA * 0.78 * alpha)
	for index: int in range(13):
		var ratio: float = (float(index) + 0.55) / 13.0
		var offset: float = float((index * 7 + variant * 3) % 5 - 2) * rect.size.x * 0.003
		var x: float = rect.position.x + rect.size.x * ratio + offset
		var y0: float = rect.position.y + 6.0 + float((index + variant) % 4) * 2.0
		var y1: float = rect.end.y - 6.0 - float((index * 3 + variant) % 5)
		var lean: float = float((index + variant * 2) % 5 - 2) * 0.65
		var fibre := PackedVector2Array([
			Vector2(x, y0),
			Vector2(x + lean, lerpf(y0, y1, 0.48)),
			Vector2(x - lean * 0.35, y1),
		])
		canvas.draw_polyline(fibre, warm_fibre if (index + variant) % 3 == 0 else pale_fibre, 0.7, true)
	# Short cross-fibres break the computer-perfect vertical rhythm without creating
	# a noisy grid behind the copy.
	for index: int in range(7):
		var y: float = rect.position.y + rect.size.y * (0.12 + float(index) * 0.125)
		var start_ratio: float = 0.06 + float((index * 17 + variant * 11) % 54) / 100.0
		var length: float = rect.size.x * (0.10 + float((index + variant) % 4) * 0.025)
		canvas.draw_line(
			Vector2(rect.position.x + rect.size.x * start_ratio, y),
			Vector2(minf(rect.end.x - 7.0, rect.position.x + rect.size.x * start_ratio + length), y + float((index + variant) % 3 - 1)),
			Color(warm_fibre.r, warm_fibre.g, warm_fibre.b, PAPER_FIBER_ALPHA * 0.52 * alpha),
			0.7
		)


static func _draw_paper_flecks(canvas: CanvasItem, rect: Rect2, variant: int, alpha: float) -> void:
	# Sparse deterministic pulp knots and ink freckles provide micro-scale breakup.
	# The sequence is arithmetic rather than random, so the modal never shimmers.
	for index: int in range(18):
		var x_ratio: float = (float((index * 37 + variant * 19) % 89) + 5.0) / 100.0
		var y_ratio: float = (float((index * 53 + variant * 23) % 91) + 4.0) / 100.0
		var radius: float = 0.45 + float((index + variant) % 4) * 0.22
		var fleck_alpha: float = PAPER_FIBER_ALPHA * (0.40 + float(index % 3) * 0.12) * alpha
		var color := Color(95.0 / 255.0, 70.0 / 255.0, 45.0 / 255.0, fleck_alpha)
		if (index + variant) % 4 == 0:
			color = Color(250.0 / 255.0, 241.0 / 255.0, 211.0 / 255.0, fleck_alpha * 0.82)
		canvas.draw_circle(rect.position + Vector2(rect.size.x * x_ratio, rect.size.y * y_ratio), radius, color)


static func _draw_paper_patina(canvas: CanvasItem, rect: Rect2, variant: int, alpha: float) -> void:
	var edge_ink := Color(104.0 / 255.0, 72.0 / 255.0, 39.0 / 255.0, PAPER_PATINA_ALPHA * alpha)
	for index: int in range(3):
		canvas.draw_rect(rect.grow(-float(index) * 2.0), Color(edge_ink.r, edge_ink.g, edge_ink.b, edge_ink.a * (1.0 - float(index) * 0.22)), false, 2.4 - float(index) * 0.45)
	var strip_alpha: float = PAPER_PATINA_ALPHA * 0.34 * alpha
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color(edge_ink.r, edge_ink.g, edge_ink.b, strip_alpha))
	canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 7.0), Vector2(rect.size.x, 7.0)), Color(edge_ink.r, edge_ink.g, edge_ink.b, strip_alpha * 1.25))
	canvas.draw_rect(Rect2(rect.position, Vector2(5.0, rect.size.y)), Color(edge_ink.r, edge_ink.g, edge_ink.b, strip_alpha * 0.82))
	canvas.draw_rect(Rect2(Vector2(rect.end.x - 5.0, rect.position.y), Vector2(5.0, rect.size.y)), Color(edge_ink.r, edge_ink.g, edge_ink.b, strip_alpha * 0.82))
	var stain_a := rect.position + Vector2(rect.size.x * (0.16 + 0.07 * float(variant % 2)), rect.size.y * (0.18 + 0.05 * float(variant % 3)))
	var stain_b := rect.position + Vector2(rect.size.x * (0.77 - 0.05 * float(variant % 3)), rect.size.y * (0.66 + 0.045 * float(variant % 2)))
	canvas.draw_circle(stain_a, minf(rect.size.x, rect.size.y) * 0.095, Color(117.0 / 255.0, 77.0 / 255.0, 43.0 / 255.0, 0.022 * alpha))
	canvas.draw_circle(stain_b, minf(rect.size.x, rect.size.y) * 0.14, Color(86.0 / 255.0, 70.0 / 255.0, 47.0 / 255.0, 0.026 * alpha))


static func _draw_lower_ink_landscape(canvas: CanvasItem, rect: Rect2, variant: int, alpha: float) -> void:
	var base_y: float = rect.end.y - 7.0
	var crest_y: float = rect.position.y + rect.size.y * (0.82 + 0.012 * float(variant % 3))
	var left: float = rect.position.x + 7.0
	var right: float = rect.end.x - 7.0
	var width: float = right - left
	var profile: Array[Vector2] = []
	match variant:
		0:
			profile = [Vector2(0.0, 1.0), Vector2(0.13, 0.76), Vector2(0.27, 0.16), Vector2(0.39, 0.62), Vector2(0.56, 0.02), Vector2(0.70, 0.67), Vector2(0.85, 0.34), Vector2(1.0, 1.0)]
		1:
			profile = [Vector2(0.0, 1.0), Vector2(0.16, 0.48), Vector2(0.30, 0.06), Vector2(0.45, 0.73), Vector2(0.63, 0.24), Vector2(0.78, 0.69), Vector2(0.92, 0.29), Vector2(1.0, 1.0)]
		2:
			profile = [Vector2(0.0, 1.0), Vector2(0.11, 0.68), Vector2(0.22, 0.23), Vector2(0.34, 0.72), Vector2(0.50, 0.04), Vector2(0.64, 0.57), Vector2(0.80, 0.12), Vector2(0.93, 0.74), Vector2(1.0, 1.0)]
		_:
			profile = [Vector2(0.0, 1.0), Vector2(0.15, 0.61), Vector2(0.31, 0.03), Vector2(0.46, 0.71), Vector2(0.60, 0.27), Vector2(0.73, 0.65), Vector2(0.87, 0.18), Vector2(1.0, 1.0)]
	var ridge := PackedVector2Array()
	for sample: Vector2 in profile:
		ridge.append(Vector2(left + width * sample.x, lerpf(crest_y, base_y, sample.y)))
	var wash := Color(55.0 / 255.0, 70.0 / 255.0, 63.0 / 255.0, PAPER_LANDSCAPE_ALPHA * 0.24 * alpha)
	var fill_points := ridge.duplicate()
	fill_points.append(Vector2(right, base_y))
	fill_points.append(Vector2(left, base_y))
	canvas.draw_colored_polygon(fill_points, wash)
	canvas.draw_polyline(ridge, Color(wash.r, wash.g, wash.b, PAPER_LANDSCAPE_ALPHA * 0.78 * alpha), 1.0, true)
	var distant_ridge := PackedVector2Array()
	for point: Vector2 in ridge:
		distant_ridge.append(Vector2(point.x, lerpf(point.y, base_y, 0.28)))
	canvas.draw_polyline(distant_ridge, Color(wash.r, wash.g, wash.b, PAPER_LANDSCAPE_ALPHA * 0.33 * alpha), 1.0, true)
	var mist_y: float = rect.end.y - rect.size.y * 0.075
	for index: int in range(3):
		var wash_center := Vector2(left + width * (0.24 + float(index) * 0.27), base_y - rect.size.y * (0.018 + 0.008 * float((index + variant) % 2)))
		canvas.draw_circle(wash_center, rect.size.y * (0.050 + float(index % 2) * 0.016), Color(wash.r, wash.g, wash.b, PAPER_LANDSCAPE_ALPHA * 0.15 * alpha))
	for index: int in range(4):
		var center := Vector2(left + width * (0.22 + float(index) * 0.19), mist_y + float((index + variant) % 2) * 3.0)
		canvas.draw_arc(center, rect.size.y * 0.035, PI, TAU, 12, Color(wash.r, wash.g, wash.b, PAPER_LANDSCAPE_ALPHA * 0.54 * alpha), 1.0)


static func _draw_title_seal(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	canvas.draw_rect(rect, Color(SEAL_RED.r, SEAL_RED.g, SEAL_RED.b, 0.82 * alpha))
	canvas.draw_rect(rect.grow(-3.0), Color(231.0 / 255.0, 205.0 / 255.0, 159.0 / 255.0, 0.72 * alpha), false, 1.0)
	var seal_ink := Color(235.0 / 255.0, 213.0 / 255.0, 174.0 / 255.0, 0.72 * alpha)
	var inner := rect.grow(-6.0)
	canvas.draw_line(Vector2(inner.get_center().x, inner.position.y), Vector2(inner.get_center().x, inner.end.y), seal_ink, 1.0)
	canvas.draw_line(Vector2(inner.position.x, inner.get_center().y), Vector2(inner.end.x, inner.get_center().y), seal_ink, 1.0)
	canvas.draw_line(inner.position, Vector2(inner.end.x, inner.position.y), seal_ink, 1.0)
	canvas.draw_line(Vector2(inner.position.x, inner.position.y), Vector2(inner.position.x, inner.get_center().y), seal_ink, 1.0)
	canvas.draw_line(Vector2(inner.end.x, inner.get_center().y), inner.end, seal_ink, 1.0)
	canvas.draw_line(Vector2(inner.position.x, inner.end.y), inner.end, seal_ink, 1.0)


static func _draw_cloud_curl(canvas: CanvasItem, center: Vector2, direction: float, alpha: float) -> void:
	var color := Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.44 * alpha)
	canvas.draw_arc(center, 12.0, PI * 0.15, PI * 1.65, 16, color, 1.2)
	canvas.draw_arc(center + Vector2(direction * 10.0, 3.0), 7.0, PI * 0.1, PI * 1.5, 12, color, 1.0)


static func _draw_outer_knots(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	for center: Vector2 in [Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y)]:
		var knot_color := Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, 0.74 * alpha)
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -6.0),
			center + Vector2(6.0, 0.0),
			center + Vector2(0.0, 6.0),
			center + Vector2(-6.0, 0.0),
			center + Vector2(0.0, -6.0),
		])
		canvas.draw_polyline(diamond, knot_color, 1.4, true)


static func _draw_outer_corners(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	_draw_corner_brackets(canvas, rect, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.90 * alpha), 22.0, 4.0)
	for point: Vector2 in [rect.position + Vector2(8.0, 8.0), Vector2(rect.end.x - 8.0, rect.position.y + 8.0), Vector2(rect.position.x + 8.0, rect.end.y - 8.0), rect.end - Vector2(8.0, 8.0)]:
		canvas.draw_circle(point, 3.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.78 * alpha))


static func _draw_selection_sparks(canvas: CanvasItem, rect: Rect2, alpha: float, pulse: float) -> void:
	var spark_alpha: float = (0.64 + pulse * 0.30) * alpha
	var color := Color(1.0, 225.0 / 255.0, 137.0 / 255.0, spark_alpha)
	for point: Vector2 in [
		rect.position + Vector2(-7.0, -7.0),
		Vector2(rect.end.x + 7.0, rect.position.y - 7.0),
		Vector2(rect.position.x - 7.0, rect.end.y + 7.0),
		rect.end + Vector2(7.0, 7.0),
	]:
		var radius: float = 3.0 + pulse * 2.0
		canvas.draw_circle(point, radius * 1.8, Color(color.r, color.g, color.b, 0.14 * alpha))
		canvas.draw_line(point - Vector2(radius, 0.0), point + Vector2(radius, 0.0), color, 1.5)
		canvas.draw_line(point - Vector2(0.0, radius), point + Vector2(0.0, radius), color, 1.5)


static func _draw_card_corner_ornaments(canvas: CanvasItem, rect: Rect2, alpha: float, emphasized: bool) -> void:
	# Mirrored stepped lattice inspired by traditional wooden latticework and
	# brass book-corner guards. It stays inside the paper edge so card copy and
	# the medallion remain untouched at compact resolutions.
	var size: float = minf(CARD_CORNER_ORNAMENT_SIZE, minf(rect.size.x, rect.size.y) * 0.13)
	var plate_local := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size, 0.0),
		Vector2(size, size * 0.18),
		Vector2(size * 0.66, size * 0.18),
		Vector2(size * 0.66, size * 0.34),
		Vector2(size * 0.34, size * 0.34),
		Vector2(size * 0.34, size * 0.66),
		Vector2(size * 0.18, size * 0.66),
		Vector2(size * 0.18, size),
		Vector2(0.0, size),
	])
	var meander_local := PackedVector2Array([
		Vector2(size * 0.12, size * 0.82),
		Vector2(size * 0.12, size * 0.50),
		Vector2(size * 0.48, size * 0.50),
		Vector2(size * 0.48, size * 0.22),
		Vector2(size * 0.82, size * 0.22),
	])
	var origins: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		rect.end,
	]
	var x_axes: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.RIGHT, Vector2.LEFT]
	var y_axes: Array[Vector2] = [Vector2.DOWN, Vector2.DOWN, Vector2.UP, Vector2.UP]
	var plate_color := Color(DARK_WOOD.r, DARK_WOOD.g, DARK_WOOD.b, (0.76 if emphasized else 0.68) * alpha)
	var edge_color := Color(AGED_BRASS.r, AGED_BRASS.g, AGED_BRASS.b, (0.96 if emphasized else 0.86) * alpha)
	var highlight_color := Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, (0.82 if emphasized else 0.68) * alpha)
	for corner_index: int in range(origins.size()):
		var origin: Vector2 = origins[corner_index]
		var axis_x: Vector2 = x_axes[corner_index]
		var axis_y: Vector2 = y_axes[corner_index]
		var plate := PackedVector2Array()
		var outline := PackedVector2Array()
		for local_point: Vector2 in plate_local:
			var point: Vector2 = origin + axis_x * local_point.x + axis_y * local_point.y
			plate.append(point)
			outline.append(point)
		outline.append(plate[0])
		canvas.draw_colored_polygon(plate, plate_color)
		canvas.draw_polyline(outline, edge_color, CARD_CORNER_ORNAMENT_STROKE + 0.55, true)
		var meander := PackedVector2Array()
		for local_point: Vector2 in meander_local:
			meander.append(origin + axis_x * local_point.x + axis_y * local_point.y)
		canvas.draw_polyline(meander, highlight_color, CARD_CORNER_ORNAMENT_STROKE, true)
		var stud_center: Vector2 = origin + (axis_x + axis_y) * size * 0.14
		canvas.draw_circle(stud_center, maxf(1.1, size * 0.055), highlight_color)


static func _draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color, length: float, width: float) -> void:
	canvas.draw_line(rect.position, rect.position + Vector2(length, 0.0), color, width)
	canvas.draw_line(rect.position, rect.position + Vector2(0.0, length), color, width)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - length, rect.position.y), color, width)
	canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + length), color, width)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + length, rect.end.y), color, width)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - length), color, width)
	canvas.draw_line(rect.end, rect.end - Vector2(length, 0.0), color, width)
	canvas.draw_line(rect.end, rect.end - Vector2(0.0, length), color, width)
