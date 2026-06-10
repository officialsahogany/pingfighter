extends RefCounted

# TAB 캐릭터 정보 오버레이 전용 셰이핑(TextLine) 캐시 (최적화 슬라이스 S5).
#
# 왜 필요한가: CanvasItem.draw_string()은 내부적으로 Font의 64-엔트리
# TextLine LRU 캐시를 쓴다. TAB 패널은 프레임당 64개를 훨씬 넘는 고유
# 문자열(능력치 라벨/값, 장비/스킬/퍽 라벨, 링펫 패널, 툴팁 줄)을 그리므로
# 그 LRU가 매 프레임 순환 축출되어 모든 문자열이 매 프레임 재셰이핑된다
# (CJK + fallback 폰트 체인이라 특히 비쌈). 여기서는 패널 규모에 맞는
# 바운드로 셰이핑 결과를 보관해 두 번째 프레임부터는 글리프 블릿만 남긴다.
#
# 시각 패리티 규칙 (이 모듈의 존재 이유):
# - draw_string_cached()는 Font::draw_string(LEFT 정렬, width -1)과 동일한
#   시퀀스를 재현한다: 동일 폰트/사이즈로 add_string한 TextLine을
#   baseline 위치 + Vector2(0, -ascent)에 draw. TextLine 기본값
#   (direction AUTO / orientation HORIZONTAL / width -1 / LEFT)은
#   draw_string 기본 인자와 같으므로 결과 픽셀은 동일하다. 재셰이핑은
#   결정적이라 캐시 적중/미스 간에도 픽셀 차이가 없다.
# - get_string_size_cached()는 Font::get_string_size()와 동일하게 셰이핑된
#   라인의 get_size()를 돌려준다(같은 값). 측정과 드로우가 같은 엔트리를
#   공유하므로 셰이핑이 한 번만 일어난다.
# - 폰트는 항상 같은 ThemeDB.fallback_font 인스턴스이므로 폰트 id가 바뀌면
#   캐시 전체를 비운다(테마/언어 폰트 교체 안전망).
#
# 바운드 정책: 한 프레임의 풀 패널 + 툴팁 작업 셋(~200~300개)을 안정적으로
# 담아야 엔진 LRU와 같은 순환 축출이 재발하지 않는다. MAX_ENTRIES 초과 시
# clear (repo 캐시 관례). 라이브 스탯 값 문자열이 바뀌면 새 엔트리가 쌓이고
# 오래된 값은 overflow clear로 회수된다. 줄바꿈 후보 부분 문자열 측정
# (_wrap_text_to_width 내부) 같은 일회성 텍스트는 이 캐시로 라우팅하지
# 말 것 -- 정크 엔트리가 작업 셋을 밀어낸다. 매 프레임 실제로 그리는 /
# 그릴 폭을 재는 문자열만 넣는다.

const MAX_ENTRIES := 512

# 스크립트 단위 공유 캐시: 정적 프레젠터(스탯/링펫)와 오버레이 인스턴스
# 메서드가 시그니처 변경 없이 같은 셰이핑 결과를 쓰게 한다.
static var _lines: Dictionary = {}
static var _font_id: int = 0


# Font::draw_string(LEFT, width -1)과 픽셀 동일한 캐시 드로우.
# baseline_pos는 draw_string과 같은 "첫 줄 baseline" 좌표다.
static func draw_string_cached(canvas: CanvasItem, font: Font, baseline_pos: Vector2, text: String, ui_size: int, color: Color) -> void:
	if canvas == null or font == null or text == "":
		return
	var line: TextLine = _get_line(font, text, ui_size)
	line.draw(canvas.get_canvas_item(), Vector2(baseline_pos.x, baseline_pos.y - line.get_line_ascent()), color)


# Font::get_string_size(LEFT, width -1)과 동일한 값. 같은 문자열을 곧바로
# draw_string_cached로 그리는 경로 전용(셰이핑 공유). 일회성 측정에는 쓰지 말 것.
static func get_string_size_cached(font: Font, text: String, ui_size: int) -> Vector2:
	if font == null or text == "":
		return Vector2.ZERO
	return _get_line(font, text, ui_size).get_size()


static func _get_line(font: Font, text: String, ui_size: int) -> TextLine:
	var font_id: int = font.get_instance_id()
	if font_id != _font_id:
		_lines.clear()
		_font_id = font_id
	var key: String = "%d:%s" % [ui_size, text]
	var cached: Variant = _lines.get(key, null)
	if cached is TextLine:
		return cached
	if _lines.size() >= MAX_ENTRIES:
		_lines.clear()
	var line := TextLine.new()
	line.add_string(text, font, ui_size)
	_lines[key] = line
	return line
