extends RefCounted
# 튜토리얼 힌트 공용 렌더러: 안내 문구에서 키보드 입력 글자만 키캡 그림으로 승격해
# 화면 중앙에 한 줄로 그린다. junior_mika / character_info 튜토리얼 힌트가 공유한다.
#
# 공백으로 분리된 토큰이 KEYCAP_TOKENS와 "정확히" 일치할 때만 키캡으로 그린다.
# 부분 일치를 잡지 않으므로 "D-Pad" / "Dash" / "TAB키" 같은 단어 속 글자는 텍스트로 남는다.
# (메시지 문자열 자체는 각 힌트 모듈이 소유/로컬라이즈하고, 여기서는 렌더만 담당한다.)

const KEYCAP_TOKENS := {
	"A": true, "D": true, "S": true, "W": true, "B": true, "X": true, "Y": true,
	"↑": true, "↓": true, "←": true, "→": true,
	"SPACE": true, "TAB": true, "SHIFT": true,
}

# 마우스 입력 센티넬 토큰(언어 무관 ASCII). 로컬라이즈된 문구 안에 이 리터럴을 그대로
# 두면 렌더러가 마우스 아이콘(좌클릭 강조 / 휠 강조)으로 그린다.
const MOUSE_TOKENS := {
	"[LMB]": "left",
	"[WHEEL]": "wheel",
}


static func split_render_tokens(message: String) -> Array:
	var elements: Array = []
	var text_buffer: Array = []
	for raw in message.split(" ", false):
		var token: String = str(raw)
		if MOUSE_TOKENS.has(token):
			if not text_buffer.is_empty():
				elements.append({"type": "text", "value": " ".join(text_buffer)})
				text_buffer.clear()
			elements.append({"type": "mouse", "value": str(MOUSE_TOKENS[token])})
		elif KEYCAP_TOKENS.has(token):
			if not text_buffer.is_empty():
				elements.append({"type": "text", "value": " ".join(text_buffer)})
				text_buffer.clear()
			elements.append({"type": "key", "value": token})
		else:
			text_buffer.append(token)
	if not text_buffer.is_empty():
		elements.append({"type": "text", "value": " ".join(text_buffer)})
	return elements


static func mouse_width(font_size: int) -> float:
	return round(float(font_size) * 1.0)


static func element_gap(font_size: int) -> float:
	return round(float(font_size) * 0.34)


static func keycap_width(font: Font, text: String, font_size: int) -> float:
	var glyph_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return max(round(float(font_size) * 1.18), glyph_width + round(float(font_size) * 0.66))


# 메시지를 키캡/텍스트 요소 시퀀스로 변환하고, 각 요소 폭과 전체 렌더 폭을 계산한다.
static func build_layout(font: Font, message: String, font_size: int) -> Dictionary:
	var elements: Array = []
	var total_width: float = 0.0
	for token in split_render_tokens(message):
		var entry: Dictionary = token
		var value: String = str(entry.get("value", ""))
		var width: float = 0.0
		var entry_type: String = str(entry.get("type", "text"))
		if entry_type == "key":
			width = keycap_width(font, value, font_size)
		elif entry_type == "mouse":
			width = mouse_width(font_size)
		else:
			width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		entry["width"] = width
		elements.append(entry)
		total_width += width
	if elements.size() > 1:
		total_width += element_gap(font_size) * float(elements.size() - 1)
	return {"elements": elements, "total_width": total_width}


static func fit_font_size(font: Font, message: String, available_width: float, base_size: int, min_size: int) -> int:
	var font_size: int = base_size
	var width: float = max(80.0, available_width)
	while font_size > min_size and float(build_layout(font, message, font_size).get("total_width", 0.0)) > width:
		font_size -= 1
	return font_size


# center에 맞춰 한 줄(키캡 + 텍스트)을 그린다. alpha는 페이드 인/아웃에 그대로 반영된다.
static func draw_centered_line(canvas: CanvasItem, font: Font, message: String, center: Vector2, font_size: int, alpha: float) -> void:
	if canvas == null or font == null:
		return
	var layout: Dictionary = build_layout(font, message, font_size)
	var elements: Array = layout.get("elements", [])
	var total_width: float = float(layout.get("total_width", 0.0))
	var gap: float = element_gap(font_size)
	var cursor_x: float = center.x - total_width * 0.5
	var keycap_style := StyleBoxFlat.new()
	for element_value in elements:
		var element: Dictionary = element_value
		var element_width: float = float(element.get("width", 0.0))
		var element_type: String = str(element.get("type", "text"))
		if element_type == "key":
			_draw_keycap(canvas, font, cursor_x, center.y, str(element.get("value", "")), font_size, element_width, alpha, keycap_style)
		elif element_type == "mouse":
			_draw_mouse(canvas, cursor_x, center.y, str(element.get("value", "left")), font_size, element_width, alpha, keycap_style)
		else:
			_draw_hint_text(canvas, font, cursor_x, center.y, str(element.get("value", "")), font_size, alpha)
		cursor_x += element_width + gap


static func _draw_hint_text(canvas: CanvasItem, font: Font, x: float, center_y: float, text: String, font_size: int, alpha: float) -> void:
	if text == "":
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(x, center_y - text_size.y * 0.5 + font.get_ascent(font_size))
	canvas.draw_string_outline(
		font, baseline + Vector2(0.0, 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, Color(0.02, 0.04, 0.08, 0.82 * alpha)
	)
	canvas.draw_string_outline(
		font, baseline, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2, Color(0.15, 0.45, 0.80, 0.24 * alpha)
	)
	canvas.draw_string(
		font, baseline, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.92, 0.98, 1.0, alpha)
	)


static func _draw_keycap(canvas: CanvasItem, font: Font, x: float, center_y: float, text: String, font_size: int, width: float, alpha: float, style: StyleBoxFlat) -> void:
	var height: float = round(float(font_size) * 1.42)
	var top: float = center_y - height * 0.5
	var radius: int = max(2, int(round(float(font_size) * 0.28)))
	var border: int = max(1, int(round(float(font_size) * 0.09)))
	var shadow_drop: float = max(1.0, round(float(font_size) * 0.12))
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	# 살짝 떠 보이는 키캡 느낌을 위해 아래에 어두운 그림자 판을 먼저 깐다.
	style.bg_color = Color(0.01, 0.02, 0.05, 0.7 * alpha)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.draw_style_box(style, Rect2(Vector2(x, top + shadow_drop), Vector2(width, height)))
	style.bg_color = Color(0.07, 0.10, 0.17, 0.94 * alpha)
	style.border_color = Color(0.46, 0.70, 0.96, 0.92 * alpha)
	canvas.draw_style_box(style, Rect2(Vector2(x, top), Vector2(width, height)))
	var glyph_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(
		x + (width - glyph_size.x) * 0.5,
		center_y - glyph_size.y * 0.5 + font.get_ascent(font_size)
	)
	canvas.draw_string_outline(
		font, baseline, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, Color(0.02, 0.05, 0.10, 0.85 * alpha)
	)
	canvas.draw_string(
		font, baseline, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.96, 0.99, 1.0, alpha)
	)


# 마우스 아이콘: 바디 외곽 + variant("left"=좌버튼 / "wheel"=휠) 강조.
static func _draw_mouse(canvas: CanvasItem, x: float, center_y: float, variant: String, font_size: int, width: float, alpha: float, style: StyleBoxFlat) -> void:
	var height: float = round(float(font_size) * 1.42)
	var top: float = center_y - height * 0.5
	var radius: int = max(3, int(round(width * 0.42)))
	var border: int = max(1, int(round(float(font_size) * 0.09)))
	var shadow_drop: float = max(1.0, round(float(font_size) * 0.12))
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.bg_color = Color(0.01, 0.02, 0.05, 0.7 * alpha)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.draw_style_box(style, Rect2(Vector2(x, top + shadow_drop), Vector2(width, height)))
	style.bg_color = Color(0.07, 0.10, 0.17, 0.94 * alpha)
	style.border_color = Color(0.46, 0.70, 0.96, 0.92 * alpha)
	canvas.draw_style_box(style, Rect2(Vector2(x, top), Vector2(width, height)))
	# 좌우 버튼 분할선(바디 위쪽)
	var split_x: float = x + width * 0.5
	var split_top: float = top + height * 0.12
	var split_bottom: float = top + height * 0.46
	canvas.draw_line(Vector2(split_x, split_top), Vector2(split_x, split_bottom), Color(0.30, 0.45, 0.66, 0.8 * alpha), max(1.0, border * 0.8))
	# variant 강조 영역
	var accent := Color(1.0, 0.84, 0.38, 0.95 * alpha)
	if variant == "wheel":
		var wheel_w: float = max(2.0, width * 0.16)
		var wheel_h: float = max(3.0, height * 0.20)
		var wheel_rect := Rect2(Vector2(split_x - wheel_w * 0.5, top + height * 0.13), Vector2(wheel_w, wheel_h))
		canvas.draw_rect(wheel_rect, accent)
	else:
		# 좌버튼(위쪽 왼쪽) 채우기
		var pad: float = max(1.5, float(border))
		var btn_left: float = x + pad
		var btn_right: float = split_x - max(1.0, float(border) * 0.6)
		var btn_rect := Rect2(Vector2(btn_left, top + pad), Vector2(btn_right - btn_left, height * 0.34))
		canvas.draw_rect(btn_rect, accent)
