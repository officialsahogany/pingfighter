extends RefCounted

const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")

const FUSION_CARD_GAP := 8.0
const FUSION_CARD_LINE_HEIGHT := 18.0
const FUSION_CARD_ICON_SIZE := 42.0
const FUSION_SOURCE_A_BORDER := Color(0.42, 0.72, 1.0, 0.88)
const FUSION_SOURCE_B_BORDER := Color(0.48, 0.86, 0.72, 0.88)
const FUSION_OUTCOME_BORDER := Color(1.0, 0.64, 0.28, 0.90)
const FUSION_CARD_FILL := Color(0.045, 0.060, 0.105, 0.985)
const FUSION_OUTCOME_FILL := Color(0.070, 0.055, 0.090, 0.985)



# 삭제 흉터의 명시 취소선: 폰트 스택에 U+0336 결합 글리프가 없어 결합
# 문자를 주입하면 tofu가 된다 — 렌더러가 텍스트 폭(패널 폭 클램프) 기준의
# 수평 세그먼트를 직접 긋는다. 반환은 [시작점, 끝점] 2점.
static func build_strikethrough_segment(
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	max_width: float
) -> PackedVector2Array:
	if font == null or text.strip_edges().is_empty():
		return PackedVector2Array()
	var text_width: float = font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x
	var width: float = clampf(text_width, 1.0, maxf(1.0, max_width))
	var strike_y: float = baseline.y - font.get_ascent(font_size) * 0.32
	return PackedVector2Array([
		Vector2(baseline.x, strike_y),
		Vector2(baseline.x + width, strike_y),
	])

static func draw_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	empty_roll_entries: Array,
	accent_blue: Color,
	text_soft: Color,
	panel_fill: Color,
	draw_text_callable: Callable,
	wrap_text_callable: Callable,
	tooltip_width_callable: Callable,
	draw_dual_item_tooltip_callable: Callable,
	tooltip_subtitle_color_callable: Callable,
	breakdown_icon_drawer: Callable = Callable()
) -> void:
	var color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("color", accent_blue))
	var title: String = str(data.get("title", ""))
	var title_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("title_color", Color.WHITE))
	var subtitle: String = str(data.get("subtitle", ""))
	var body: String = str(data.get("body", ""))
	var roll_entries: Array = CharacterInfoOverlayValueUtils.get_array(data.get("roll_options")) if data.has("roll_options") else CharacterInfoOverlayValueUtils.get_array(data.get("options")) if data.has("options") else empty_roll_entries
	var fusion_sections: Array = CharacterInfoOverlayValueUtils.get_array(data.get("fusion_sections"))
	if str(data.get("tooltip_kind", "")) == "fusion" and fusion_sections.size() == 3:
		draw_fusion_tooltip(
			canvas,
			data,
			mouse_pos,
			view_size,
			font,
			color,
			title,
			subtitle,
			fusion_sections,
			text_soft,
			panel_fill,
			draw_text_callable,
			wrap_text_callable,
			tooltip_subtitle_color_callable,
			breakdown_icon_drawer
		)
		return
	if not roll_entries.is_empty() and body != "":
		draw_dual_item_tooltip_callable.call(canvas, data, mouse_pos, view_size, font, color, title, subtitle, body, roll_entries)
		return
	# 소스별 증감 내역 행 (2026-07-12): [{text, icon_id}]. 본문 아래에 원인
	# 아이콘 + 텍스트로 그린다.
	var breakdown_rows: Array = CharacterInfoOverlayValueUtils.get_array(data.get("breakdown_rows"))
	var breakdown_line_height := 18.0
	var breakdown_icon_size := 13.0
	var breakdown_text_indent := 18.0
	var width: float = float(tooltip_width_callable.call(font, title, subtitle, body, view_size))
	if not breakdown_rows.is_empty() and font != null:
		var max_breakdown_w := 0.0
		for row_value in breakdown_rows:
			if row_value is Dictionary:
				var row_w := font.get_string_size(str((row_value as Dictionary).get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x + breakdown_text_indent
				max_breakdown_w = maxf(max_breakdown_w, row_w)
		width = maxf(width, minf(view_size.x - 16.0, max_breakdown_w + 28.0))
	var text_width: float = width - 28.0
	var title_lines: Array = _call_array(wrap_text_callable, [font, title, 15, text_width, 2])
	var subtitle_lines: Array = _call_array(wrap_text_callable, [font, subtitle, 12, text_width, 2])
	var line_height := 20.0
	var max_tooltip_height: float = max(80.0, view_size.y - 16.0)
	var fixed_height: float = 38.0 + float(title_lines.size() + subtitle_lines.size()) * line_height
	var body_line_limit: int = max(1, int(floor((max_tooltip_height - fixed_height) / line_height)))
	var body_lines: Array = _call_array(wrap_text_callable, [font, body, 13, text_width, body_line_limit])
	var breakdown_block_h: float = (6.0 + float(breakdown_rows.size()) * breakdown_line_height) if not breakdown_rows.is_empty() else 0.0
	var height: float = fixed_height + float(body_lines.size()) * line_height + breakdown_block_h
	var anchor_rect: Rect2 = CharacterInfoOverlayValueUtils.tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.end.y + 12.0
	if pos_x + width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - width
	if pos_y + height > view_size.y - 8.0:
		pos_y = anchor_rect.position.y - height - 12.0
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - height - 8.0))
	var rect := Rect2(pos_x, pos_y, width, height)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, panel_fill, color, 2.0)
	var text_x: float = pos_x + 14.0
	var y := pos_y + 24.0
	for line in title_lines:
		draw_text_callable.call(canvas, font, str(line), text_x, y, 15, title_color)
		y += line_height
	if not subtitle_lines.is_empty():
		var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)
		for line in subtitle_lines:
			draw_text_callable.call(canvas, font, str(line), text_x, y, 12, subtitle_color)
			y += line_height
	for line in body_lines:
		draw_text_callable.call(canvas, font, str(line), text_x, y, 13, text_soft)
		y += line_height
	if not breakdown_rows.is_empty():
		y += 6.0
		var breakdown_color := Color(text_soft.r, text_soft.g, text_soft.b, text_soft.a * 0.88)
		for row_value in breakdown_rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			var icon_id: String = str(row.get("icon_id", ""))
			var drew_icon := false
			if breakdown_icon_drawer.is_valid() and icon_id != "":
				var icon_rect := Rect2(text_x, y - breakdown_icon_size + 1.0, breakdown_icon_size, breakdown_icon_size)
				drew_icon = bool(breakdown_icon_drawer.call(canvas, icon_id, icon_rect))
			draw_text_callable.call(canvas, font, str(row.get("text", "")), text_x + breakdown_text_indent, y, 12, breakdown_color)
			y += breakdown_line_height


# 무공 합일 전용 3칸 tooltip. 한 칸 안에서 원본 무공의 icon/name/level/
# detail/stats를 함께 읽고, 합일 변화는 그 무공 칸에만, 부산물은 세 번째
# 결과 칸에만 표시한다. 기존 좌/우 요약 패널은 catalog를 구할 수 없는
# 호환 경로에서만 fallback으로 남는다.
static func draw_fusion_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	color: Color,
	title: String,
	subtitle: String,
	sections: Array,
	text_soft: Color,
	panel_fill: Color,
	draw_text_callable: Callable,
	wrap_text_callable: Callable,
	tooltip_subtitle_color_callable: Callable,
	breakdown_icon_drawer: Callable = Callable()
) -> void:
	if canvas == null or font == null or sections.size() != 3:
		return
	var total_width := minf(736.0, maxf(360.0, view_size.x - 16.0))
	var outer_padding := 12.0
	var card_width := (total_width - outer_padding * 2.0 - FUSION_CARD_GAP * 2.0) / 3.0
	var title_lines: Array = _call_array(wrap_text_callable, [font, title, 15, total_width - outer_padding * 2.0, 2])
	var header_height := 16.0 + float(title_lines.size()) * 20.0
	if not subtitle.is_empty():
		header_height += 17.0
	header_height += 10.0
	var section_layouts: Array = []
	var card_height := 148.0
	for section_index in range(3):
		var section: Dictionary = sections[section_index] as Dictionary
		var layout := _build_fusion_section_layout(section, font, card_width, wrap_text_callable)
		section_layouts.append(layout)
		card_height = maxf(card_height, float(layout.get("height", 148.0)))
	var total_height := header_height + card_height + outer_padding
	var anchor_rect: Rect2 = CharacterInfoOverlayValueUtils.tooltip_anchor_rect(data, mouse_pos)
	var pos_x := anchor_rect.position.x + 10.0
	var pos_y := anchor_rect.position.y - total_height - 12.0
	if pos_y < 8.0:
		pos_y = anchor_rect.end.y + 12.0
	if pos_x + total_width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - total_width
	pos_x = clampf(pos_x, 8.0, maxf(8.0, view_size.x - total_width - 8.0))
	pos_y = clampf(pos_y, 8.0, maxf(8.0, view_size.y - total_height - 8.0))
	var outer_rect := Rect2(pos_x, pos_y, total_width, total_height)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, outer_rect, panel_fill, color, 2.0)
	var header_x := pos_x + outer_padding
	var header_y := pos_y + 23.0
	for line_value: Variant in title_lines:
		draw_text_callable.call(canvas, font, str(line_value), header_x, header_y, 15, Color.WHITE)
		header_y += 20.0
	if not subtitle.is_empty():
		var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)
		draw_text_callable.call(canvas, font, subtitle, header_x, header_y, 12, subtitle_color)
	var card_top := pos_y + header_height
	for section_index in range(3):
		var card_left := pos_x + outer_padding + float(section_index) * (card_width + FUSION_CARD_GAP)
		_draw_fusion_section_card(
			canvas,
			font,
			sections[section_index] as Dictionary,
			section_layouts[section_index] as Dictionary,
			Rect2(card_left, card_top, card_width, card_height),
			section_index,
			text_soft,
			draw_text_callable,
			breakdown_icon_drawer
		)


static func _build_fusion_section_layout(
	section: Dictionary,
	font: Font,
	card_width: float,
	wrap_text_callable: Callable
) -> Dictionary:
	var title_width := maxf(60.0, card_width - 78.0)
	var content_width := maxf(80.0, card_width - 24.0)
	var title_lines: Array = _call_array(wrap_text_callable, [font, str(section.get("title", "")), 15, title_width, 2])
	var body_lines: Array = _call_array(wrap_text_callable, [font, str(section.get("body", "")), 13, content_width, 4])
	var stats_lines: Array = _call_array(wrap_text_callable, [font, str(section.get("stats", "")), 13, content_width, 4])
	var row_lines := _build_fusion_section_row_lines(
		section.get("rows", []) as Array,
		font,
		content_width,
		wrap_text_callable
	)
	var height := 100.0 + float(body_lines.size() + stats_lines.size() + row_lines.size()) * FUSION_CARD_LINE_HEIGHT + 14.0
	if not body_lines.is_empty() and not stats_lines.is_empty():
		height += 8.0
	if not row_lines.is_empty() and (not body_lines.is_empty() or not stats_lines.is_empty()):
		height += 9.0
	return {
		"title_lines": title_lines,
		"body_lines": body_lines,
		"stats_lines": stats_lines,
		"row_lines": row_lines,
		"height": maxf(148.0, height),
	}


static func _build_fusion_section_row_lines(
	rows: Array,
	font: Font,
	content_width: float,
	wrap_text_callable: Callable
) -> Array:
	var result: Array = []
	for row_value: Variant in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value as Dictionary
		var has_icon := not str(row.get("icon_id", "")).is_empty()
		var row_width := content_width - (18.0 if has_icon else 0.0)
		var wrapped: Array = _call_array(wrap_text_callable, [font, str(row.get("text", "")), 12, row_width, 3])
		for wrapped_index in range(wrapped.size()):
			if result.size() >= 8:
				return result
			result.append({
				"text": str(wrapped[wrapped_index]),
				"tone": str(row.get("tone", "normal")),
				"icon_id": str(row.get("icon_id", "")) if wrapped_index == 0 else "",
				"icon_indent": has_icon,
				"strikethrough": bool(row.get("strikethrough", false)),
			})
	return result


static func _draw_fusion_section_card(
	canvas: CanvasItem,
	font: Font,
	section: Dictionary,
	layout: Dictionary,
	rect: Rect2,
	section_index: int,
	text_soft: Color,
	draw_text_callable: Callable,
	breakdown_icon_drawer: Callable
) -> void:
	var border := FUSION_OUTCOME_BORDER
	if section_index == 0:
		border = FUSION_SOURCE_A_BORDER
	elif section_index == 1:
		border = FUSION_SOURCE_B_BORDER
	var fill := FUSION_OUTCOME_FILL if str(section.get("kind", "")) == "outcome" else FUSION_CARD_FILL
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, rect, fill, border, 1.5)
	var text_x := rect.position.x + 12.0
	draw_text_callable.call(canvas, font, str(section.get("eyebrow", "")), text_x, rect.position.y + 19.0, 11, Color(border.r, border.g, border.b, 0.92))
	var icon_rect := Rect2(text_x, rect.position.y + 29.0, FUSION_CARD_ICON_SIZE, FUSION_CARD_ICON_SIZE)
	var icon_id := str(section.get("icon_id", ""))
	var drew_icon := false
	if breakdown_icon_drawer.is_valid() and not icon_id.is_empty():
		drew_icon = bool(breakdown_icon_drawer.call(canvas, icon_id, icon_rect))
	if not drew_icon:
		canvas.draw_circle(icon_rect.get_center(), FUSION_CARD_ICON_SIZE * 0.46, Color(border.r, border.g, border.b, 0.18))
		canvas.draw_arc(icon_rect.get_center(), FUSION_CARD_ICON_SIZE * 0.42, 0.0, TAU, 20, border, 1.4, true)
	var title_x := text_x + FUSION_CARD_ICON_SIZE + 10.0
	var title_y := rect.position.y + 46.0
	var title_lines: Array = layout.get("title_lines", []) as Array
	for title_line: Variant in title_lines:
		draw_text_callable.call(canvas, font, str(title_line), title_x, title_y, 15, Color.WHITE)
		title_y += FUSION_CARD_LINE_HEIGHT
	var subtitle := str(section.get("subtitle", ""))
	if not subtitle.is_empty():
		draw_text_callable.call(canvas, font, subtitle, title_x, minf(rect.position.y + 85.0, title_y), 12, Color(1.0, 0.84, 0.48))
	var y := rect.position.y + 99.0
	var body_lines: Array = layout.get("body_lines", []) as Array
	var stats_lines: Array = layout.get("stats_lines", []) as Array
	var row_lines: Array = layout.get("row_lines", []) as Array
	for body_line: Variant in body_lines:
		draw_text_callable.call(canvas, font, str(body_line), text_x, y, 13, text_soft)
		y += FUSION_CARD_LINE_HEIGHT
	if not body_lines.is_empty() and not stats_lines.is_empty():
		y += 4.0
		canvas.draw_line(Vector2(text_x, y), Vector2(rect.end.x - 12.0, y), Color(border.r, border.g, border.b, 0.24), 1.0)
		y += 4.0
	for stats_line: Variant in stats_lines:
		draw_text_callable.call(canvas, font, str(stats_line), text_x, y, 13, Color(0.72, 0.86, 1.0))
		y += FUSION_CARD_LINE_HEIGHT
	if not row_lines.is_empty() and (not body_lines.is_empty() or not stats_lines.is_empty()):
		y += 4.0
		canvas.draw_line(Vector2(text_x, y), Vector2(rect.end.x - 12.0, y), Color(border.r, border.g, border.b, 0.24), 1.0)
		y += 5.0
	for row_value: Variant in row_lines:
		var row: Dictionary = row_value as Dictionary
		var line_x := text_x
		var row_icon_id := str(row.get("icon_id", ""))
		if bool(row.get("icon_indent", false)):
			line_x += 18.0
		if not row_icon_id.is_empty() and breakdown_icon_drawer.is_valid():
			breakdown_icon_drawer.call(canvas, row_icon_id, Rect2(text_x, y - 13.0, 14.0, 14.0))
		var row_color := _fusion_row_color(str(row.get("tone", "normal")), text_soft)
		var row_text := str(row.get("text", ""))
		draw_text_callable.call(canvas, font, row_text, line_x, y, 12, row_color)
		if bool(row.get("strikethrough", false)):
			var strike_segment := build_strikethrough_segment(
				font,
				row_text,
				Vector2(line_x, y),
				12,
				rect.end.x - 12.0 - line_x
			)
			if strike_segment.size() == 2:
				canvas.draw_line(strike_segment[0], strike_segment[1], row_color, 1.3, true)
		y += FUSION_CARD_LINE_HEIGHT


static func _fusion_row_color(tone: String, fallback: Color) -> Color:
	match tone:
		"penalty":
			return Color(1.0, 0.55, 0.45)
		"deleted":
			return Color(0.68, 0.68, 0.72)
		"byproduct":
			return Color(0.55, 0.85, 1.0)
		_:
			return fallback


static func draw_dual_item_tooltip(
	canvas: CanvasItem,
	data: Dictionary,
	mouse_pos: Vector2,
	view_size: Vector2,
	font: Font,
	color: Color,
	title: String,
	subtitle: String,
	body: String,
	roll_entries: Array,
	text_soft: Color,
	accent_gold: Color,
	panel_fill: Color,
	roll_panel_fill: Color,
	roll_border: Color,
	draw_text_callable: Callable,
	wrap_text_callable: Callable,
	build_entry_lines_callable: Callable,
	tooltip_subtitle_color_callable: Callable,
	tooltip_entry_line_text_cache: Array[String],
	tooltip_entry_line_color_cache: Array[Color],
	breakdown_icon_drawer: Callable = Callable()
) -> void:
	var gap := 10.0
	var desc_width: float = min(270.0, max(205.0, view_size.x * 0.52))
	var roll_width: float = min(210.0, max(154.0, view_size.x - desc_width - gap - 26.0))
	if desc_width + gap + roll_width > view_size.x - 16.0:
		var available: float = max(300.0, view_size.x - 16.0 - gap)
		desc_width = max(178.0, available * 0.58)
		roll_width = max(132.0, available - desc_width)
	# 동적 행 예산: 융합 스탯 패널(tooltip_kind == "fusion")은 2 헤더+옵션
	# 레인+부산물 레인이 8줄 legacy 캡을 초과한다 — 엔트리 수 기반으로
	# 확장하되 화면 보호를 위해 24줄에서 캡. 신비의 주사위(tooltip_kind ==
	# "mystic_dice")는 7개 로컬라이즈 스탯 행+랩 여유의 전용 14줄 프로파일.
	var tooltip_kind := str(data.get("tooltip_kind", ""))
	var is_fusion := tooltip_kind == "fusion"
	var entry_line_limit := 8
	if is_fusion or tooltip_kind == "mystic_dice":
		entry_line_limit = mini(24 if is_fusion else 14, maxi(8, roll_entries.size() + 2))
	var body_lines: Array = _call_array(wrap_text_callable, [font, body, 13, desc_width - 28.0, 8])
	var roll_lines: Array = _call_array(build_entry_lines_callable, [font, roll_entries, 13, roll_width - 24.0, entry_line_limit])
	var title_color: Color = CharacterInfoOverlayValueUtils.get_color(data.get("title_color", Color.WHITE))
	var line_height := 20.0
	var desc_height: float = 58.0 + float(body_lines.size()) * line_height
	if subtitle != "":
		desc_height += line_height
	var roll_height: float = 42.0 + float(roll_lines.size()) * line_height
	var total_width: float = desc_width + gap + roll_width
	var total_height: float = max(desc_height, roll_height)
	var anchor_rect: Rect2 = CharacterInfoOverlayValueUtils.tooltip_anchor_rect(data, mouse_pos)
	var pos_x: float = anchor_rect.position.x + 10.0
	var pos_y: float = anchor_rect.position.y - total_height - 12.0
	if pos_y < 8.0:
		pos_y = anchor_rect.end.y + 12.0
	if pos_x + total_width > view_size.x - 8.0:
		pos_x = anchor_rect.end.x - total_width
	pos_x = clamp(pos_x, 8.0, max(8.0, view_size.x - total_width - 8.0))
	pos_y = clamp(pos_y, 8.0, max(8.0, view_size.y - total_height - 8.0))

	var desc_rect := Rect2(pos_x, pos_y, desc_width, desc_height)
	var roll_rect := Rect2(pos_x + desc_width + gap, pos_y, roll_width, roll_height)
	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, desc_rect, panel_fill, color, 2.0)
	var desc_text_x: float = pos_x + 14.0
	draw_text_callable.call(canvas, font, title, desc_text_x, pos_y + 24.0, 15, title_color)
	var desc_y := pos_y + 44.0
	if subtitle != "":
		var subtitle_color: Color = _call_color(tooltip_subtitle_color_callable, color)
		draw_text_callable.call(canvas, font, subtitle, desc_text_x, desc_y, 12, subtitle_color)
		desc_y += line_height
	for line in body_lines:
		draw_text_callable.call(canvas, font, str(line), desc_text_x, desc_y, 13, text_soft)
		desc_y += line_height

	CharacterInfoOverlayTextureDrawer.draw_panel(canvas, roll_rect, roll_panel_fill, roll_border, 2.0)
	var roll_text_x: float = pos_x + desc_width + gap + 12.0
	var right_header: String = str(data.get("right_header", "롤 옵션"))
	draw_text_callable.call(canvas, font, right_header, roll_text_x, pos_y + 24.0, 13, accent_gold)
	var roll_y := pos_y + 44.0
	for i in range(roll_lines.size()):
		var roll_line_value: Variant = roll_lines[i]
		var line_text_x := roll_text_x
		if roll_line_value is Dictionary:
			var roll_line: Dictionary = roll_line_value as Dictionary
			if bool(roll_line.get("icon_indent", false)):
				line_text_x += 18.0
			var icon_id := str(roll_line.get("icon_id", ""))
			if not icon_id.is_empty() and breakdown_icon_drawer.is_valid():
				var icon_rect := Rect2(roll_text_x, roll_y - 14.0, 15.0, 15.0)
				breakdown_icon_drawer.call(canvas, icon_id, icon_rect)
		draw_text_callable.call(canvas, font, tooltip_entry_line_text_cache[i], line_text_x, roll_y, 13, tooltip_entry_line_color_cache[i])
		# 삭제 흉터: U+0336 결합 글리프 대신 렌더러 소유 명시 취소선.
		if roll_line_value is Dictionary and bool((roll_line_value as Dictionary).get("strikethrough", false)):
			var strike_segment: PackedVector2Array = build_strikethrough_segment(
				font,
				tooltip_entry_line_text_cache[i],
				Vector2(line_text_x, roll_y),
				13,
				roll_width - 24.0 - (line_text_x - roll_text_x)
			)
			if strike_segment.size() == 2:
				canvas.draw_line(strike_segment[0], strike_segment[1], tooltip_entry_line_color_cache[i], 1.5, true)
		roll_y += line_height


static func _call_array(callable: Callable, arguments: Array) -> Array:
	var value: Variant = callable.callv(arguments)
	return value if value is Array else []


static func _call_color(callable: Callable, color: Color) -> Color:
	var value: Variant = callable.call(color)
	return value if value is Color else color
