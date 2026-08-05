extends RefCounted

# 수호령 지속시간 필드 게이지.
#
# 인게임에서 동행 중인 수호령 SD 캐릭터 바로 왼쪽에 세로로 서는 잔여 지속시간
# 바. 컴패니언 본체와 "같은" 드로우 패스(lingpet_companion_renderer.draw_companion
# 내부)에서 그려지므로, 본체가 숨거나(링대쉬 은신) 페이드하면(고스트 소멸 /
# 소환·수납 트랜지션) 게이지도 같이 사라진다 -- 본체가 없는데 게이지만 떠 있는
# "떠다니는 UI" 상태가 구조적으로 불가능하다.
#
# 색 임계값 / 경고·위험 색은 TAB 캐릭터 정보 패널의 지속시간 스트립과 같은
# 소유자(character_info_overlay_lingpet_vitality_projection)를 읽는다. 두 표시면이
# 서로 다른 임계값으로 조용히 갈라지지 않게 하기 위한 의도적 단일 소스다.

const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetDurationVitality := preload("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")

const GAUGE_WIDTH := 6.0
# 셀 여백을 제외한 실제 몸통 반폭 근사치. SD 시트는 셀 대비 몸이 좁아서
# draw_size 절반(0.5)으로 잡으면 게이지가 몸에서 너무 멀리 떨어져 보인다.
const BODY_HALF_WIDTH_RATIO := 0.30
const GAUGE_BODY_GAP := 7.0
const GAUGE_HEIGHT_RATIO := 0.52
const GAUGE_HEIGHT_MIN := 34.0
const GAUGE_HEIGHT_MAX := 58.0
# 스프라이트는 WALK_Y_OFFSET 만큼 위로 앵커되므로 게이지도 같은 만큼 올려
# 몸통 중앙 밴드에 나란히 선다.
const GAUGE_Y_OFFSET := LingpetCompanionSpriteAnimator.WALK_Y_OFFSET
# 플레이필드는 클립이 없어서 x<0 으로 새면 좌측 필러 레터박스 위에 그려진다.
const FIELD_LEFT_MARGIN := 2.0
const OVERFILL_EPSILON := 0.001

const COLOR_NORMAL := Color(0.34, 1.0, 0.78, 1.0)
const COLOR_OVERFILL := Color(1.0, 0.88, 0.42, 1.0)
const COLOR_DRAIN_EXEMPT_BORDER := Color(0.56, 0.86, 1.0, 1.0)


# 순수 기하 / 상태 해석. 캔버스 없이 단언할 수 있게 draw 와 분리한다.
static func resolve_layout(center: Vector2, config: Dictionary) -> Dictionary:
	if not bool(config.get("duration_gauge_enabled", false)):
		return _hidden_layout()
	var pool_max: float = maxf(0.0, float(config.get("duration_pool_max", 0.0)))
	if pool_max <= 0.0:
		# 아직 초기 굴림이 없는 풀 = 표시할 계약 자체가 없다 (빈 바 노출 금지).
		return _hidden_layout()
	var pool_current: float = maxf(0.0, float(config.get("duration_pool_current", 0.0)))
	var raw_ratio: float = pool_current / pool_max
	var ratio: float = clampf(raw_ratio, 0.0, 1.0)
	var body_px: float = float(config.get("walk_draw_size", 0.0))
	if body_px <= 0.0:
		body_px = LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x
	var gauge_height: float = clampf(body_px * GAUGE_HEIGHT_RATIO, GAUGE_HEIGHT_MIN, GAUGE_HEIGHT_MAX)
	var right_edge_x: float = center.x - (body_px * BODY_HALF_WIDTH_RATIO + GAUGE_BODY_GAP)
	var left_x: float = maxf(FIELD_LEFT_MARGIN, right_edge_x - GAUGE_WIDTH)
	var top_y: float = center.y + GAUGE_Y_OFFSET - gauge_height * 0.5
	var track_rect := Rect2(left_x, top_y, GAUGE_WIDTH, gauge_height)
	var fill_height: float = gauge_height * ratio
	return {
		"visible": true,
		"track_rect": track_rect,
		"fill_rect": Rect2(left_x, track_rect.end.y - fill_height, GAUGE_WIDTH, fill_height),
		"ratio": ratio,
		"pct": clampi(roundi(raw_ratio * 100.0), 0, 100),
		"color_key": resolve_color_key(clampi(roundi(raw_ratio * 100.0), 0, 100)),
		"overfilled": raw_ratio > 1.0 + OVERFILL_EPSILON,
		"drain_exempt": bool(config.get("duration_drain_exempt", false)),
	}


static func resolve_color_key(pct: int) -> String:
	if pct <= LingpetDurationVitality.DURATION_CRITICAL_THRESHOLD:
		return "critical"
	if pct <= LingpetDurationVitality.DURATION_WARNING_THRESHOLD:
		return "warning"
	return "normal"


static func resolve_fill_color(color_key: String) -> Color:
	return LingpetDurationVitality.strip_color({"color_key": color_key}, COLOR_NORMAL)


# 그린 레이아웃을 반환한다(안 그렸으면 visible=false). 호출자는 이 반환값을
# 그대로 관측 채널로 쓸 수 있으므로, 씰이 실제 draw 경로를 관통해 단언한다.
static func draw_gauge(
	canvas: CanvasItem,
	center: Vector2,
	config: Dictionary,
	alpha: float = 1.0
) -> Dictionary:
	if canvas == null:
		return _hidden_layout()
	var draw_alpha: float = clampf(alpha, 0.0, 1.0)
	if draw_alpha <= 0.01:
		return _hidden_layout()
	var layout: Dictionary = resolve_layout(center, config)
	if not bool(layout.get("visible", false)):
		return layout
	var track_rect: Rect2 = layout.get("track_rect", Rect2())
	if track_rect.size.x <= 0.0 or track_rect.size.y <= 0.0:
		return _hidden_layout()
	var color_key: String = str(layout.get("color_key", "normal"))
	var drain_exempt: bool = bool(layout.get("drain_exempt", false))
	var pulse: float = _resolve_pulse(color_key, drain_exempt)
	var fill_color: Color = resolve_fill_color(color_key)
	canvas.draw_rect(track_rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.34 * draw_alpha))
	canvas.draw_rect(track_rect, Color(0.04, 0.08, 0.10, 0.66 * draw_alpha))
	var fill_rect: Rect2 = layout.get("fill_rect", Rect2())
	if fill_rect.size.y > 0.0:
		canvas.draw_rect(
			fill_rect,
			Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * pulse * draw_alpha)
		)
		var cap_height: float = minf(2.0, fill_rect.size.y)
		canvas.draw_rect(
			Rect2(fill_rect.position, Vector2(fill_rect.size.x, cap_height)),
			Color(1.0, 1.0, 1.0, 0.46 * pulse * draw_alpha)
		)
	for i in range(1, 4):
		var tick_y: float = track_rect.position.y + track_rect.size.y * (float(i) / 4.0)
		canvas.draw_line(
			Vector2(track_rect.position.x, tick_y),
			Vector2(track_rect.end.x, tick_y),
			Color(0.0, 0.0, 0.0, 0.30 * draw_alpha),
			1.0
		)
	var border_color := Color(fill_color.r, fill_color.g, fill_color.b, 0.55 * draw_alpha)
	if bool(layout.get("overfilled", false)):
		border_color = Color(COLOR_OVERFILL.r, COLOR_OVERFILL.g, COLOR_OVERFILL.b, 0.92 * draw_alpha)
		canvas.draw_line(
			Vector2(track_rect.position.x - 1.0, track_rect.position.y - 2.5),
			Vector2(track_rect.end.x + 1.0, track_rect.position.y - 2.5),
			border_color,
			2.0
		)
	elif drain_exempt:
		border_color = Color(
			COLOR_DRAIN_EXEMPT_BORDER.r,
			COLOR_DRAIN_EXEMPT_BORDER.g,
			COLOR_DRAIN_EXEMPT_BORDER.b,
			0.70 * draw_alpha
		)
	canvas.draw_rect(track_rect, border_color, false, 1.0)
	return layout


# 소모 면제(자동 출전 리그)는 줄지 않으므로 펄스도 없다 -- 깜빡임은 "닳는 중"의
# 신호라서, 안 닳는 상태에서 깜빡이면 거짓 경고가 된다.
static func _resolve_pulse(color_key: String, drain_exempt: bool) -> float:
	if drain_exempt:
		return 1.0
	var now_ms: float = float(Time.get_ticks_msec())
	match color_key:
		"critical":
			return lerpf(0.62, 1.0, 0.5 + 0.5 * sin(now_ms * 0.0125))
		"warning":
			return lerpf(0.82, 1.0, 0.5 + 0.5 * sin(now_ms * 0.0062))
	return 1.0


static func _hidden_layout() -> Dictionary:
	return {
		"visible": false,
		"track_rect": Rect2(),
		"fill_rect": Rect2(),
		"ratio": 0.0,
		"pct": 0,
		"color_key": "hidden",
		"overfilled": false,
		"drain_exempt": false,
	}
