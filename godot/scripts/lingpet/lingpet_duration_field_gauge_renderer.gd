extends RefCounted

# 수호령 지속시간 필드 게이지.
#
# 인게임에서 동행 중인 수호령 SD 캐릭터 바로 왼쪽에 세로로 서는 잔여 지속시간 바.
#
# 소유자는 이 렌더러가 아니라 호스트(lingpet_egg_runtime)의 공통 게이지 패스
# `_draw_companion_duration_gauge()` 다. 본체 표현이 여러 갈래(일반 SD / 클릭 교감
# 반응 시트 / 스타코일 바인드)라서, 게이지를 그중 한 렌더러 안에 두면 다른 표현이
# 선택된 프레임에 게이지만 끊긴다. 호스트는 본체 분기 "뒤"에서 한 번만 이 함수를
# 부르고, 그때 넘기는 alpha 는 **본체 표현이 그 프레임에 실제로 사용한 최종 알파**다
# (교체 전환 0.42 바닥, 고스트 소멸, 클릭 교감 진입 / 종료 페이드가 이미 반영된 값).
# 여기서 알파를 다시 계산하지 않는 이유이자, alpha<=0 이면 본체가 안 나온 프레임이라
# 게이지도 그리지 않는 이유다.
#
# 화면 밖 본체(출격형 진입 / 퇴장)와 좌우 필러 유출은 resolve_layout 의 경계 판정이
# 막는다. 판정 대상은 트랙이 아니라 장식까지 포함한 visual_rect 다.
#
# 색 임계값 / 경고·위험 색은 TAB 캐릭터 정보 패널의 지속시간 스트립과 같은
# 소유자(character_info_overlay_lingpet_vitality_projection)를 읽는다. 두 표시면이
# 서로 다른 임계값으로 조용히 갈라지지 않게 하기 위한 의도적 단일 소스다.

const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
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
# 플레이필드는 클립이 없어서 x 범위를 벗어나면 좌우 필러 레터박스 위에 그려진다.
# 폭 정본은 컴패니언 이동 상태와 같은 상수를 읽는다.
const FIELD_MIN_X := 0.0
const FIELD_MAX_X := LingpetCompanionMotionState.FIELD_WIDTH
# 트랙 Rect 밖으로 나가는 장식(뒷판 grow, 오버필 캡)의 최대 여유. 경계 판정은
# 트랙이 아니라 이 패딩을 포함한 실제 시각 범위(visual_rect)로 해야 한다 --
# 트랙만 보면 좌벽에서 뒷판이 필러로 새는 걸 놓친다.
const DECOR_PADDING := 2.0
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
	var body_left_x: float = center.x - body_px * BODY_HALF_WIDTH_RATIO
	var left_x: float = body_left_x - GAUGE_BODY_GAP - GAUGE_WIDTH
	if left_x - DECOR_PADDING < FIELD_MIN_X:
		# 좌벽에 붙었을 때만 필드 안으로 밀어 넣는다. 밀어 넣은 결과가 몸통을
		# 침범하면 게이지가 설 자리가 없는 것이므로 숨긴다.
		#
		# ⚠️ 무조건 클램프는 금지: 출격형(sortie_flight) 수호령은 x=-190 같은
		# 화면 밖에서 진입/퇴장하면서 motion_visible=true 이므로, 클램프만 하면
		# 본체는 화면 밖인데 게이지만 좌측 끝에 떠 있는 유령 UI 가 된다.
		# 이 분기가 그 결함의 봉인 지점이다.
		left_x = FIELD_MIN_X + DECOR_PADDING
		# 침범 판정도 필드 경계와 같이 장식(뒷판)까지 포함한 실제 시각 우단으로 한다.
		# 공통 게이지 패스는 본체 "뒤"에 그려지므로 뒷판이 몸통 가장자리를 덮는다 --
		# 트랙만 보면 좁은 전환 구간(104px 몸통 x=40, 82px 몸통 x=33 등)에서
		# 1~2px 침범을 통과시킨다.
		if left_x + GAUGE_WIDTH + DECOR_PADDING > body_left_x:
			return _hidden_layout()
	if left_x + GAUGE_WIDTH + DECOR_PADDING > FIELD_MAX_X:
		# 우측 화면 밖 진입/퇴장. 이쪽은 밀어 넣어 봐야 본체 방향이라 무의미하다.
		return _hidden_layout()
	var top_y: float = center.y + GAUGE_Y_OFFSET - gauge_height * 0.5
	var track_rect := Rect2(left_x, top_y, GAUGE_WIDTH, gauge_height)
	var fill_height: float = gauge_height * ratio
	return {
		"visible": true,
		"track_rect": track_rect,
		# 뒷판 / 오버필 캡을 포함한 실제 시각 범위. 경계·클립 단언은 이 rect 로 한다.
		"visual_rect": track_rect.grow(DECOR_PADDING),
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
	# 컷 기준은 본체 표현들과 동일하게 0.0 -- 임계를 다르게 두면 아주 옅은 페이드
	# 프레임에서 본체는 나오는데 게이지만 사라지는 어긋남이 생긴다.
	var draw_alpha: float = clampf(alpha, 0.0, 1.0)
	if draw_alpha <= 0.0:
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
	# 뒷판은 visual_rect 와 같은 패딩을 써야 한다. 리터럴로 두면 경계 판정이
	# 참조하는 DECOR_PADDING 과 조용히 갈라진다.
	canvas.draw_rect(track_rect.grow(DECOR_PADDING), Color(0.0, 0.0, 0.0, 0.34 * draw_alpha))
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
		# 캡 선은 DECOR_PADDING 안쪽에 머문다. 트랙 밖으로 더 나가면 좌벽에서
		# 필러로 새고, visual_rect 계약도 깨진다.
		canvas.draw_line(
			Vector2(track_rect.position.x, track_rect.position.y - 1.0),
			Vector2(track_rect.end.x, track_rect.position.y - 1.0),
			border_color,
			1.6
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
		"visual_rect": Rect2(),
		"fill_rect": Rect2(),
		"ratio": 0.0,
		"pct": 0,
		"color_key": "hidden",
		"overfilled": false,
		"drain_exempt": false,
	}
