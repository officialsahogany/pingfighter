extends RefCounted

# 오른쪽 필러 리액티브 초상화 위젯 (Phase 1 슬라이스).
# 보스 대쉬토큰 오브(상단)와 플레이어 대쉬토큰 오브(하단) 사이의 빈 세로 밴드에
# 두 박스를 세로로 쌓아 그린다: 상단 = 보스 초상화, 하단 = 플레이어 초상화.
# 표정(neutral / happy / sad / pained)은 stage1_pillar_hud_scene_drawer가
# 현재 스턴 / 승·패 플래그로부터 계산해 ui_context에 실어 준다 (무상태 직접 매핑).
#
# Step 1 = 아트 무관 플레이스홀더: 절차적 얼굴을 그려 레이아웃 적합성과 리액션
# 배선을 인게임에서 먼저 검증한다. Step 2에서 이 절차적 얼굴을 실제 head-crop
# 텍스처로 교체한다.
#
# 좌표는 필러와 동일하게 스크린/뷰 공간(draw_set_transform(game_offset) 바깥)이며
# stage1_pillar_ui_renderer.draw()가 이미 계산한 layout 기하를 그대로 재사용한다.
# TextureRect 대신 immediate-mode 드로우만 사용한다(민-사이즈 클램프 함정 회피).

const EXPRESSION_NEUTRAL := "neutral"
const EXPRESSION_HAPPY := "happy"
const EXPRESSION_SAD := "sad"
const EXPRESSION_PAINED := "pained"

# 밴드 안에서 오브를 침범하지 않도록 두는 상/하 여백 (스케일 곱 적용 전, px).
const BAND_TOP_GAP := 14.0
const BAND_BOTTOM_GAP := 14.0
# 두 박스 사이 간격.
const BOX_GAP := 10.0
# 박스 목표 크기 (px, 스케일 곱 전). 세로가 약간 긴 초상화 비율.
const BOX_WIDTH := 118.0
const BOX_HEIGHT := 132.0
# Dalji portrait crop keeps the sangmo streamer and janggu edge readable at HUD scale.
const CROP_DALJI := Rect2(0.13, 0.03, 0.68, 0.80)
# 박스가 최소한 이 높이(스케일 곱 후)는 확보돼야 그린다. 밴드가 더 짧으면
# 두 박스가 오브 클러스터를 침범하므로 통째로 스킵한다 (draw-time 용량 규율).
const MIN_BOX_HEIGHT := 44.0

# 오브 팔레트 재사용 — 보스 = 보라, 플레이어 = 레드 (좌우 오브와 톤 통일).
const BOSS_BG := Color(0.10, 0.06, 0.15, 0.80)
const BOSS_BORDER := Color(0.72, 0.48, 0.92, 0.94)
const BOSS_BRACKET := Color(0.86, 0.62, 1.0, 0.95)
const PLAYER_BG := Color(0.13, 0.06, 0.06, 0.80)
const PLAYER_BORDER := Color(0.92, 0.50, 0.46, 0.94)
const PLAYER_BRACKET := Color(1.0, 0.62, 0.52, 0.95)

const FACE_SKIN := Color(0.98, 0.86, 0.74, 1.0)
const FACE_SKIN_SHADE := Color(0.86, 0.70, 0.58, 1.0)
const FACE_INK := Color(0.15, 0.10, 0.12, 1.0)


# 초상화 두 박스를 그린다. 표정 키가 모두 neutral이고 위젯이 꺼져 있어도 박스
# 자체는 항상 그려 정체성 프레임이 유지되게 한다 (표정만 리액션).
func draw(canvas: CanvasItem, layout: Dictionary, time_seconds: float, context: Dictionary) -> void:
	if canvas == null or layout == null:
		return
	if not bool(context.get("portrait_enabled", true)):
		return
	var boxes: Dictionary = compute_boxes(layout)
	if not bool(boxes.get("ok", false)):
		return
	var scale_factor: float = float(layout.get("scale_factor", 1.0))
	var boss_rect: Rect2 = boxes["boss_rect"]
	var player_rect: Rect2 = boxes["player_rect"]

	var boss_expression: String = _normalize_expression(context.get("portrait_boss_expression", EXPRESSION_NEUTRAL))
	var player_expression: String = _normalize_expression(context.get("portrait_player_expression", EXPRESSION_NEUTRAL))
	var boss_face: Dictionary = _get_dict(context.get("portrait_boss_face", {}))
	var player_face: Dictionary = _get_dict(context.get("portrait_player_face", {}))

	_draw_portrait_box(canvas, boss_rect, scale_factor, time_seconds, boss_expression, true, boss_face)
	_draw_portrait_box(canvas, player_rect, scale_factor, time_seconds, player_expression, false, player_face)


# 밴드/박스 기하 계산 (단일 소스). 밴드가 두 박스를 담기엔 너무 짧으면 ok=false.
func compute_boxes(layout: Dictionary) -> Dictionary:
	var scale_factor: float = float(layout.get("scale_factor", 1.0))
	var orb_radius: float = float(layout.get("orb_radius", 55.0 * scale_factor))
	var boss_center: Vector2 = _as_vec2(layout.get("boss_right_top_center", Vector2.ZERO))
	var player_center: Vector2 = _as_vec2(layout.get("right_center", Vector2.ZERO))
	if boss_center == Vector2.ZERO or player_center == Vector2.ZERO:
		return {"ok": false}

	var band_top: float = boss_center.y + orb_radius + BAND_TOP_GAP * scale_factor
	var band_bottom: float = player_center.y - orb_radius - BAND_BOTTOM_GAP * scale_factor
	var band_height: float = band_bottom - band_top
	var box_gap: float = BOX_GAP * scale_factor
	# 목표 높이를 밴드에 맞춰 축소 (두 박스 + 간격이 밴드에 들어가도록).
	var wanted_h: float = BOX_HEIGHT * scale_factor
	var available_per_box: float = (band_height - box_gap) * 0.5
	var box_h: float = min(wanted_h, available_per_box)
	if box_h < MIN_BOX_HEIGHT * scale_factor:
		return {"ok": false}
	var box_w: float = min(BOX_WIDTH * scale_factor, box_h * (BOX_WIDTH / BOX_HEIGHT))
	# 밴드 세로 중앙 정렬로 두 박스 스택 배치.
	var stack_h: float = box_h * 2.0 + box_gap
	var stack_top: float = band_top + (band_height - stack_h) * 0.5
	var center_x: float = boss_center.x
	var boss_rect := Rect2(Vector2(center_x - box_w * 0.5, stack_top), Vector2(box_w, box_h))
	var player_rect := Rect2(Vector2(center_x - box_w * 0.5, stack_top + box_h + box_gap), Vector2(box_w, box_h))
	return {
		"ok": true,
		"boss_rect": boss_rect,
		"player_rect": player_rect,
	}


func _draw_portrait_box(
	canvas: CanvasItem,
	rect: Rect2,
	scale_factor: float,
	time_seconds: float,
	expression: String,
	is_boss: bool,
	face_data: Dictionary
) -> void:
	var bg: Color = BOSS_BG if is_boss else PLAYER_BG
	var border: Color = BOSS_BORDER if is_boss else PLAYER_BORDER
	var bracket: Color = BOSS_BRACKET if is_boss else PLAYER_BRACKET
	var border_width: float = max(2.0, 2.0 * scale_factor)
	PremiumPanelFrame.draw_panel(canvas, rect, PremiumPanelFrame.KIND_SECTION, bg, border, border_width)
	PremiumPanelFrame.draw_corner_brackets(
		canvas,
		rect.grow(max(1.0, 1.5 * scale_factor)),
		bracket,
		1.0,
		0.30,
		max(5.0, 11.0 * scale_factor)
	)

	# 얼굴은 박스 안쪽에 클립되도록 살짝 여백을 준 원형 헤드로 그린다.
	var inset: float = border_width + 4.0 * scale_factor
	var face_area := rect.grow(-inset)
	# 미세한 아이들 바브 (front-facing 생동감).
	var bob: float = sin(time_seconds * 2.2 + (0.0 if is_boss else 1.6)) * face_area.size.y * 0.012
	var face_box := Rect2(
		face_area.get_center().x - face_area.size.x * 0.5,
		face_area.get_center().y + bob - face_area.size.y * 0.5,
		face_area.size.x,
		face_area.size.y
	)
	if face_data.is_empty():
		var face_center := face_box.get_center()
		var face_radius: float = min(face_box.size.x, face_box.size.y) * 0.40
		_draw_face(canvas, face_center, face_radius, expression, scale_factor, time_seconds)
	else:
		_draw_portrait_face_texture(canvas, face_box, face_data)


# 절차적 플레이스홀더 얼굴. neutral / happy / sad / pained 4종.
func _draw_portrait_face_texture(
	canvas: CanvasItem,
	face_box: Rect2,
	face_data: Dictionary
) -> void:
	var texture: Variant = face_data.get("texture", null)
	if not (texture is Texture2D):
		return
	var texture_obj := texture as Texture2D
	var cols: int = max(1, int(face_data.get("cols", 1)))
	var rows: int = max(1, int(face_data.get("rows", 1)))
	var frame_count: int = cols * rows
	var frame: int = max(0, int(face_data.get("frame", 0)))
	if frame_count > 0:
		frame %= frame_count
	var texture_size: Vector2 = texture_obj.get_size()
	var cell_size: Vector2 = Vector2(texture_size.x / float(cols), texture_size.y / float(rows))
	var row: int = frame / cols
	var col: int = frame - row * cols
	var head_rect := Rect2(
		cell_size.x * float(col),
		cell_size.y * float(row),
		cell_size.x,
		cell_size.y
	)
	var head_source := _get_rect2(face_data.get("head_source_rect", CROP_DALJI))
	var source_rect := Rect2(
		head_rect.position.x + head_rect.size.x * head_source.position.x,
		head_rect.position.y + head_rect.size.y * head_source.position.y,
		head_rect.size.x * head_source.size.x,
		head_rect.size.y * head_source.size.y
	)
	var dest_rect := _fit_center_crop_dest(face_box, source_rect.size)
	var tint: Color = face_data.get("tint", Color.WHITE)
	canvas.draw_texture_rect_region(texture_obj, dest_rect, source_rect, tint, false, true)


func _fit_center_crop_dest(container: Rect2, source_size: Vector2) -> Rect2:
	var source_aspect: float = source_size.x / max(1.0, source_size.y)
	var container_aspect: float = container.size.x / max(1.0, container.size.y)
	var scale: float = 1.0
	if source_aspect > container_aspect:
		scale = container.size.x / max(1.0, source_size.x)
	else:
		scale = container.size.y / max(1.0, source_size.y)
	var target_size := source_size * scale
	return Rect2(
		container.position.x + (container.size.x - target_size.x) * 0.5,
		container.position.y + (container.size.y - target_size.y) * 0.5,
		target_size.x,
		target_size.y
	)


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2(0.0, 0.0, 1.0, 1.0)


func _draw_face(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	expression: String,
	scale_factor: float,
	time_seconds: float
) -> void:
	var line_w: float = max(1.5, 2.0 * scale_factor)
	# 헤드 (하단 살짝 어두운 셰이드 + 본체).
	canvas.draw_circle(center + Vector2(0.0, radius * 0.10), radius, FACE_SKIN_SHADE)
	canvas.draw_circle(center, radius * 0.98, FACE_SKIN)

	var eye_dx: float = radius * 0.42
	var eye_y: float = center.y - radius * 0.12
	var left_eye := Vector2(center.x - eye_dx, eye_y)
	var right_eye := Vector2(center.x + eye_dx, eye_y)
	var eye_r: float = max(1.5, radius * 0.13)
	var mouth_y: float = center.y + radius * 0.36
	var mouth_hw: float = radius * 0.40

	match expression:
		EXPRESSION_HAPPY:
			# 눈: ^ ^ 아치, 볼 홍조, 큰 미소 아크.
			_draw_arc_eye(canvas, left_eye, eye_r * 1.2, true, line_w)
			_draw_arc_eye(canvas, right_eye, eye_r * 1.2, true, line_w)
			canvas.draw_circle(left_eye + Vector2(-eye_r * 0.4, eye_r * 1.3), eye_r * 0.7, Color(1.0, 0.62, 0.58, 0.55))
			canvas.draw_circle(right_eye + Vector2(eye_r * 0.4, eye_r * 1.3), eye_r * 0.7, Color(1.0, 0.62, 0.58, 0.55))
			_draw_smile(canvas, Vector2(center.x, mouth_y), mouth_hw, radius * 0.34, line_w)
		EXPRESSION_SAD:
			# 눈: 아래로 처진 눈 + 눈물, 찡그린 눈썹, 프라운.
			canvas.draw_circle(left_eye, eye_r, FACE_INK)
			canvas.draw_circle(right_eye, eye_r, FACE_INK)
			_draw_brow(canvas, left_eye, eye_r, true, line_w)
			_draw_brow(canvas, right_eye, eye_r, false, line_w)
			var tear_a: float = 0.5 + 0.5 * sin(time_seconds * 3.0)
			canvas.draw_circle(left_eye + Vector2(-eye_r * 0.2, eye_r * 1.8 + tear_a * radius * 0.1), eye_r * 0.55, Color(0.5, 0.8, 1.0, 0.85))
			canvas.draw_circle(right_eye + Vector2(eye_r * 0.2, eye_r * 1.8 + (1.0 - tear_a) * radius * 0.1), eye_r * 0.55, Color(0.5, 0.8, 1.0, 0.85))
			_draw_smile(canvas, Vector2(center.x, mouth_y + radius * 0.14), mouth_hw * 0.85, -radius * 0.26, line_w)
		EXPRESSION_PAINED:
			# 눈: >< (X 아픈 눈), 찡그린 눈썹, 앙다문 지그재그 입, 땀방울.
			_draw_x_eye(canvas, left_eye, eye_r * 1.1, line_w)
			_draw_x_eye(canvas, right_eye, eye_r * 1.1, line_w)
			_draw_brow(canvas, left_eye, eye_r, true, line_w)
			_draw_brow(canvas, right_eye, eye_r, false, line_w)
			_draw_gritted_mouth(canvas, Vector2(center.x, mouth_y), mouth_hw * 0.9, radius * 0.14, line_w)
			var sweat := center + Vector2(radius * 0.62, -radius * 0.30)
			canvas.draw_circle(sweat, max(1.0, radius * 0.11), Color(0.55, 0.82, 1.0, 0.9))
		_:
			# neutral: 점 눈 + 평평한 입.
			canvas.draw_circle(left_eye, eye_r, FACE_INK)
			canvas.draw_circle(right_eye, eye_r, FACE_INK)
			canvas.draw_line(
				Vector2(center.x - mouth_hw * 0.6, mouth_y),
				Vector2(center.x + mouth_hw * 0.6, mouth_y),
				FACE_INK,
				line_w
			)


func _draw_arc_eye(canvas: CanvasItem, eye: Vector2, r: float, up: bool, line_w: float) -> void:
	# 위로 볼록한(^) 웃는 눈.
	var a0: float = PI * 0.15
	var a1: float = PI * 0.85
	if up:
		canvas.draw_arc(eye + Vector2(0.0, r * 0.4), r, PI + a0, PI + a1, 10, FACE_INK, line_w, true)
	else:
		canvas.draw_arc(eye, r, a0, a1, 10, FACE_INK, line_w, true)


func _draw_x_eye(canvas: CanvasItem, eye: Vector2, r: float, line_w: float) -> void:
	canvas.draw_line(eye + Vector2(-r, -r), eye + Vector2(r, r), FACE_INK, line_w)
	canvas.draw_line(eye + Vector2(-r, r), eye + Vector2(r, -r), FACE_INK, line_w)


func _draw_brow(canvas: CanvasItem, eye: Vector2, eye_r: float, is_left: bool, line_w: float) -> void:
	# 안쪽이 내려간 찡그림 눈썹 (/ \ 형태).
	var brow_y: float = eye.y - eye_r * 2.2
	var inner_x: float = eye.x + (eye_r * 1.0 if is_left else -eye_r * 1.0)
	var outer_x: float = eye.x - (eye_r * 1.1 if is_left else -eye_r * 1.1)
	canvas.draw_line(
		Vector2(inner_x, brow_y + eye_r * 0.9),
		Vector2(outer_x, brow_y),
		FACE_INK,
		line_w
	)


func _draw_smile(canvas: CanvasItem, center: Vector2, half_width: float, depth: float, line_w: float) -> void:
	# depth > 0 = 미소(아래로 볼록), depth < 0 = 프라운.
	var p0 := Vector2(center.x - half_width, center.y)
	var p1 := Vector2(center.x, center.y + depth)
	var p2 := Vector2(center.x + half_width, center.y)
	var prev := p0
	var steps := 10
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var one_t: float = 1.0 - t
		var pt := one_t * one_t * p0 + 2.0 * one_t * t * p1 + t * t * p2
		canvas.draw_line(prev, pt, FACE_INK, line_w)
		prev = pt


func _draw_gritted_mouth(canvas: CanvasItem, center: Vector2, half_width: float, height: float, line_w: float) -> void:
	# 앙다문 지그재그 입 (아픔 표현).
	var teeth := 4
	var x0: float = center.x - half_width
	var seg: float = (half_width * 2.0) / float(teeth)
	# 위/아래 테두리.
	canvas.draw_line(Vector2(x0, center.y - height), Vector2(center.x + half_width, center.y - height), FACE_INK, line_w)
	canvas.draw_line(Vector2(x0, center.y + height), Vector2(center.x + half_width, center.y + height), FACE_INK, line_w)
	for i in range(teeth + 1):
		var x: float = x0 + seg * float(i)
		canvas.draw_line(Vector2(x, center.y - height), Vector2(x, center.y + height), FACE_INK, max(1.0, line_w * 0.7))


func _normalize_expression(value: Variant) -> String:
	var id: String = str(value).strip_edges().to_lower()
	if id == EXPRESSION_HAPPY or id == EXPRESSION_SAD or id == EXPRESSION_PAINED:
		return id
	return EXPRESSION_NEUTRAL


func _as_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
