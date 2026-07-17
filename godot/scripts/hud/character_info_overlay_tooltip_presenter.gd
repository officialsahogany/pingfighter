extends RefCounted

const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")



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
	tooltip_entry_line_color_cache: Array[Color]
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
	draw_text_callable.call(canvas, font, "롤 옵션", roll_text_x, pos_y + 24.0, 13, accent_gold)
	var roll_y := pos_y + 44.0
	for i in range(roll_lines.size()):
		draw_text_callable.call(canvas, font, tooltip_entry_line_text_cache[i], roll_text_x, roll_y, 13, tooltip_entry_line_color_cache[i])
		# 삭제 흉터: U+0336 결합 글리프 대신 렌더러 소유 명시 취소선.
		var roll_line_value: Variant = roll_lines[i]
		if roll_line_value is Dictionary and bool((roll_line_value as Dictionary).get("strikethrough", false)):
			var strike_segment: PackedVector2Array = build_strikethrough_segment(
				font,
				tooltip_entry_line_text_cache[i],
				Vector2(roll_text_x, roll_y),
				13,
				roll_width - 24.0
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
