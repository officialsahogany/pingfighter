extends RefCounted
## 엘릭서 오브 마스터리 시네마틱 드로우 헬퍼
## ElixirOfMasteryRuntime.get_draw_context()를 받아 _draw() 호출 시 렌더링

const ElixirRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.78)
const BOTTLE_BODY_COLOR := Color(0.47, 0.2, 0.78)
const BOTTLE_LIQUID_COLOR := Color(0.78, 0.39, 1.0)
const BOTTLE_NECK_COLOR := Color(0.59, 0.31, 0.86)
const BOTTLE_CAP_COLOR := Color(1.0, 0.84, 0.0)
const TITLE_COLOR := Color(1.0, 0.84, 0.0)
const SUBTITLE_COLOR := Color(0.86, 0.78, 1.0)
const FRAME_BG_COLOR := Color(0.08, 0.04, 0.16, 0.86)
const FRAME_OUTER_COLOR := Color(0.71, 0.39, 1.0)
const FRAME_INNER_COLOR := Color(1.0, 0.84, 0.2)
const LEVEL_COLOR := Color(0.39, 1.0, 0.78)
const HINT_COLOR := Color(0.78, 0.78, 1.0)


func draw_cinematic(canvas: CanvasItem, ctx: Dictionary, view_size: Vector2) -> void:
	if not bool(ctx.get("active", false)):
		return

	var cx: float = view_size.x * 0.5
	var cy: float = view_size.y * 0.5

	# 어두운 오버레이
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), OVERLAY_COLOR)

	var phase: int = int(ctx.get("phase", 0))
	match phase:
		ElixirRuntime.Phase.BUILDUP:
			_draw_buildup(canvas, ctx, cx, cy, view_size)
		ElixirRuntime.Phase.REVEAL, ElixirRuntime.Phase.CELEBRATION:
			_draw_result(canvas, ctx, cx, cy, view_size)

	# 플래시 효과
	var flash_a: float = float(ctx.get("flash_alpha", 0.0))
	if flash_a > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 1.0, 1.0, minf(1.0, flash_a)))


@warning_ignore("unused_parameter")
func _draw_buildup(canvas: CanvasItem, ctx: Dictionary, cx: float, cy: float, view_size: Vector2) -> void:
	var timer: float = float(ctx.get("timer", 0.0))
	var progress: float = minf(1.0, timer / ElixirRuntime.BUILDUP_DURATION)

	# 룬 서클
	var rune_circles: Array = ctx.get("rune_circles", []) if ctx.get("rune_circles") is Array else []
	for rc in rune_circles:
		var alpha: float = float(rc.get("alpha", 0.5)) * (0.5 + 0.5 * sin(timer * 2.0))
		var r: float = float(rc.get("radius", 100.0)) * (1.0 - progress * 0.3)
		var segments: int = int(rc.get("segments", 6))
		var rot: float = float(rc.get("rotation", 0.0))
		var color := Color(0.71, 0.39, 1.0, alpha)
		for i in range(segments):
			var angle1: float = rot + (TAU * float(i) / float(segments))
			var angle2: float = rot + (TAU * (float(i) + 0.7) / float(segments))
			var p1 := Vector2(cx + r * cos(angle1), cy + r * sin(angle1))
			var p2 := Vector2(cx + r * cos(angle2), cy + r * sin(angle2))
			canvas.draw_line(p1, p2, color, 2.0)
			canvas.draw_circle(p1, 3.0, Color(1.0, 0.78, 0.39, alpha))

	# 마법 입자
	var particles: Array = ctx.get("particles", []) if ctx.get("particles") is Array else []
	for p in particles:
		var dist: float = float(p.get("dist", 100.0))
		var angle: float = float(p.get("angle", 0.0))
		var px: float = cx + dist * cos(angle)
		var py: float = cy + dist * sin(angle)
		var pulse: float = 0.5 + 0.5 * sin(timer * 4.0 + float(p.get("phase_offset", 0.0)))
		var size: float = maxf(1.0, float(p.get("size", 3.0)) * pulse)
		var p_color: Color = p.get("color", Color.WHITE) if p.get("color") is Color else Color.WHITE
		p_color.a = float(p.get("alpha", 0.8)) * pulse
		canvas.draw_circle(Vector2(px, py), size, p_color)

	# 중앙 물약 글로우
	var glow_r: float = 80.0 + 40.0 * sin(timer * 3.0)
	var glow_alpha: float = (100.0 + 50.0 * progress) / 255.0
	canvas.draw_circle(Vector2(cx, cy), glow_r, Color(0.71, 0.39, 1.0, glow_alpha * 0.5))
	canvas.draw_circle(Vector2(cx, cy), glow_r * 0.5, Color(0.86, 0.71, 1.0, glow_alpha * 0.7))

	# 물약병 본체 (간략화 - 회전 없이 중앙에 그리기)
	var bs: float = float(ctx.get("bottle_scale", 1.0))
	var bottle_w: float = 36.0 * bs
	var bottle_h: float = 30.0 * bs
	var neck_w: float = 12.0 * bs
	var neck_h: float = 18.0 * bs
	var cap_w: float = 16.0 * bs
	var cap_h: float = 6.0 * bs
	# 병 몸체
	canvas.draw_rect(Rect2(cx - bottle_w * 0.5, cy - 5.0 * bs, bottle_w, bottle_h), BOTTLE_BODY_COLOR)
	# 액체
	canvas.draw_rect(Rect2(cx - bottle_w * 0.4, cy, bottle_w * 0.8, bottle_h * 0.7), BOTTLE_LIQUID_COLOR)
	# 병목
	canvas.draw_rect(Rect2(cx - neck_w * 0.5, cy - neck_h - 5.0 * bs, neck_w, neck_h), BOTTLE_NECK_COLOR)
	# 뚜껑
	canvas.draw_rect(Rect2(cx - cap_w * 0.5, cy - neck_h - 5.0 * bs - cap_h, cap_w, cap_h), BOTTLE_CAP_COLOR)

	# 타이틀 텍스트
	if progress > 0.3:
		var text_alpha: float = minf(1.0, (progress - 0.3) * 2.5)
		var title_pos := Vector2(cx, cy + 100.0)
		_draw_centered_text(canvas, LanguageSettings.translate_text("엘릭서 오브 마스터리"), title_pos, 28, Color(TITLE_COLOR, text_alpha))

	if progress > 0.5:
		var sub_alpha: float = minf(0.8, (progress - 0.5) * 2.0)
		var sub_pos := Vector2(cx, cy + 130.0)
		_draw_centered_text(canvas, LanguageSettings.translate_text("퍽의 운명이 결정됩니다..."), sub_pos, 16, Color(SUBTITLE_COLOR, sub_alpha))


func _draw_result(canvas: CanvasItem, ctx: Dictionary, cx: float, cy: float, view_size: Vector2) -> void:
	var result_a: float = float(ctx.get("result_alpha", 0.0))
	var celebration: bool = bool(ctx.get("celebration_triggered", false))
	var cel_timer: float = float(ctx.get("celebration_timer", 0.0))

	# 스파클
	var sparkles: Array = ctx.get("sparkles", []) if ctx.get("sparkles") is Array else []
	for s in sparkles:
		var life_ratio: float = maxf(0.0, float(s.get("life", 0.0)) / maxf(0.01, float(s.get("max_life", 3.0))))
		var size: float = maxf(1.0, float(s.get("size", 3.0)) * life_ratio)
		var sx: float = cx + float(s.get("x", 0.0))
		var sy: float = cy + float(s.get("y", 0.0))
		var s_color: Color = s.get("color", Color.WHITE) if s.get("color") is Color else Color.WHITE
		s_color.a = life_ratio
		canvas.draw_circle(Vector2(sx, sy), size, s_color)

	var selected_data: Dictionary = ctx.get("selected_perk_data", {}) if ctx.get("selected_perk_data") is Dictionary else {}
	if selected_data.is_empty():
		return

	var icon_center_y: float = cy - 30.0

	# 축하 연출: 방사형 빛줄기
	if celebration:
		_draw_radial_rays(canvas, cx, icon_center_y, ctx)
		_draw_shockwaves(canvas, cx, icon_center_y, ctx)

	# 결과 프레임
	var frame_size: float = 120.0
	var frame_x: float = cx - frame_size * 0.5
	var frame_y: float = icon_center_y - frame_size * 0.5

	# 글로우 배경
	if result_a > 0.1:
		@warning_ignore("unused_variable")
		var glow_pulse: float = (sin(cel_timer * 4.0) + 1.0) * 0.5
		var glow_r: float = frame_size * 0.5 + 20.0
		canvas.draw_circle(Vector2(cx, icon_center_y), glow_r, Color(0.47, 0.2, 0.78, 0.3 * result_a))
		canvas.draw_circle(Vector2(cx, icon_center_y), glow_r * 0.75, Color(0.78, 0.59, 0.2, 0.35 * result_a))
		canvas.draw_circle(Vector2(cx, icon_center_y), glow_r * 0.5, Color(1.0, 1.0, 1.0, 0.4 * result_a))

	# 프레임 배경
	var frame_rect := Rect2(frame_x, frame_y, frame_size, frame_size)
	canvas.draw_rect(frame_rect, Color(FRAME_BG_COLOR, FRAME_BG_COLOR.a * result_a))
	canvas.draw_rect(frame_rect, Color(FRAME_OUTER_COLOR, result_a), false, 3.0)
	canvas.draw_rect(frame_rect.grow(-3.0), Color(FRAME_INNER_COLOR, result_a * 0.8), false, 2.0)

	# 퍽 아이콘 (색상 원으로 대체 표시)
	if result_a > 0.2:
		var icon_color: Color = selected_data.get("icon_color", Color(0.78, 0.39, 1.0)) if selected_data.get("icon_color") is Color else Color(0.78, 0.39, 1.0)
		var breath: float = float(ctx.get("icon_breath_scale", 1.0)) if celebration else 1.0
		var icon_r: float = 30.0 * breath
		canvas.draw_circle(Vector2(cx, icon_center_y), icon_r, Color(icon_color, result_a))
		# 퍽 이니셜
		var perk_name: String = str(selected_data.get("name", "?"))
		if perk_name.length() > 0:
			_draw_centered_text(canvas, perk_name.left(1).to_upper(), Vector2(cx, icon_center_y), int(24.0 * breath), Color(1.0, 1.0, 1.0, result_a))

	# 텍스트 표시
	if result_a > 0.4:
		var skill_name: String = str(selected_data.get("name", "???"))
		_draw_centered_text(canvas, skill_name, Vector2(cx, cy + 45.0), 24, Color(TITLE_COLOR, result_a))

		var old_lv: int = int(ctx.get("old_level", 0))
		var level_text: String = "Lv.%d  →  Lv.5" % old_lv
		var lv_color: Color = LEVEL_COLOR
		if celebration:
			var pulse: float = (sin(cel_timer * 6.0) + 1.0) * 0.5
			lv_color = Color(1.0, 0.84 + 0.16 * pulse, 0.31 + 0.24 * pulse)
		_draw_centered_text(canvas, level_text, Vector2(cx, cy + 72.0), 20, Color(lv_color, result_a))

	# 축하 전경 레이어
	if celebration:
		_draw_fireworks(canvas, cx, icon_center_y, ctx)
		_draw_confetti(canvas, cx, icon_center_y, ctx, view_size)
		_draw_level5_badge(canvas, cx, icon_center_y, ctx)
		_draw_celebration_banner(canvas, cx, cy, view_size, ctx)

	# 확인 안내
	if bool(ctx.get("waiting_for_confirm", false)):
		var blink: float = (sin(cel_timer * 4.0) + 1.0) * 0.5
		_draw_centered_text(canvas, LanguageSettings.translate_text("[ Space / Click 으로 계속 ]"), Vector2(cx, cy + 130.0), 14, Color(HINT_COLOR, blink))


func _draw_radial_rays(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var rays_rot: float = float(ctx.get("rays_rotation", 0.0))
	var num_rays := 12
	var length := 240.0
	for i in range(num_rays):
		var angle: float = deg_to_rad(rays_rot + float(i) * (360.0 / float(num_rays)))
		var tip := Vector2(cx + cos(angle) * length, cy + sin(angle) * length)
		var alpha: float = 0.25 if i % 2 == 0 else 0.18
		var color := Color(1.0, 0.84, 0.39, alpha) if i % 2 == 0 else Color(1.0, 1.0, 1.0, alpha)
		canvas.draw_line(Vector2(cx, cy), tip, color, 3.0)


func _draw_shockwaves(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var sws: Array = ctx.get("shockwaves", []) if ctx.get("shockwaves") is Array else []
	for sw in sws:
		if float(sw.get("delay", 0.0)) > 0.0:
			continue
		var alpha: float = float(sw.get("current_alpha", 1.0))
		if alpha <= 0.01:
			continue
		var r: float = maxf(1.0, float(sw.get("radius", 0.0)))
		var w: float = maxf(1.0, float(sw.get("width", 4.0)))
		var sw_color: Color = sw.get("color", Color.WHITE) if sw.get("color") is Color else Color.WHITE
		sw_color.a = alpha
		canvas.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 64, sw_color, w)


func _draw_fireworks(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var fws: Array = ctx.get("fireworks", []) if ctx.get("fireworks") is Array else []
	for f in fws:
		var life_ratio: float = maxf(0.0, float(f.get("life", 0.0)) / maxf(0.01, float(f.get("max_life", 1.2))))
		var size: float = maxf(1.0, float(f.get("size", 2.0)) * (0.4 + 0.8 * life_ratio))
		var fx: float = cx + float(f.get("x", 0.0))
		var fy: float = cy + float(f.get("y", 0.0))
		var f_color: Color = f.get("color", Color.WHITE) if f.get("color") is Color else Color.WHITE
		f_color.a = life_ratio
		canvas.draw_circle(Vector2(fx, fy), size * 3.0, Color(f_color, f_color.a * 0.33))
		canvas.draw_circle(Vector2(fx, fy), size, f_color)


func _draw_confetti(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary, view_size: Vector2) -> void:
	var conf: Array = ctx.get("confetti", []) if ctx.get("confetti") is Array else []
	for c in conf:
		var draw_x: float = cx + float(c.get("x", 0.0))
		var draw_y: float = cy + float(c.get("y", 0.0))
		if draw_x < -60.0 or draw_x > view_size.x + 60.0:
			continue
		if draw_y < -60.0 or draw_y > view_size.y + 60.0:
			continue
		var life_ratio: float = maxf(0.0, minf(1.0, float(c.get("life", 0.0)) / maxf(0.01, float(c.get("max_life", 4.5)))))
		var alpha: float = 0.5 + 0.5 * life_ratio
		var size: float = float(c.get("size", 6.0))
		var c_color: Color = c.get("color", Color.WHITE) if c.get("color") is Color else Color.WHITE
		c_color.a = alpha
		var w: float = maxf(2.0, size * 1.8)
		var h: float = maxf(1.0, size * 0.8)
		canvas.draw_rect(Rect2(draw_x - w * 0.5, draw_y - h * 0.5, w, h), c_color)


func _draw_level5_badge(canvas: CanvasItem, cx: float, cy: float, ctx: Dictionary) -> void:
	var scale: float = maxf(0.2, float(ctx.get("level5_impact_scale", 1.0)))
	var cel_timer: float = float(ctx.get("celebration_timer", 0.0))
	var anchor_x: float = cx + 95.0
	var anchor_y: float = cy - 10.0
	var pulse: float = (sin(cel_timer * 5.0) + 1.0) * 0.5
	var glow_r: float = 30.0 + 12.0 * pulse
	canvas.draw_circle(Vector2(anchor_x, anchor_y), glow_r, Color(1.0, 0.86, 0.39, 0.4 + 0.3 * pulse))
	_draw_centered_text(canvas, "Lv.5 !", Vector2(anchor_x, anchor_y), int(20.0 * scale), Color(1.0, 0.92, 0.35))


@warning_ignore("unused_parameter")
func _draw_celebration_banner(canvas: CanvasItem, cx: float, cy: float, view_size: Vector2, ctx: Dictionary) -> void:
	var bp: float = float(ctx.get("banner_progress", 0.0))
	if bp <= 0.0:
		return
	var eased: float = 1.0 - pow(1.0 - bp, 3.0)
	var box_w: float = 400.0
	var box_h: float = 70.0
	var target_y: float = cy - 195.0
	var start_y: float = -box_h
	var banner_y: float = start_y + (target_y - start_y) * eased
	var box_x: float = cx - box_w * 0.5
	# 박스 본체
	canvas.draw_rect(Rect2(box_x, banner_y, box_w, box_h), Color(0.12, 0.06, 0.24, 0.92))
	canvas.draw_rect(Rect2(box_x, banner_y, box_w, box_h), Color(1.0, 0.84, 0.31), false, 3.0)
	# 타이틀
	_draw_centered_text(canvas, LanguageSettings.translate_text("Lv.5 달성!"), Vector2(cx, banner_y + 28.0), 36, Color(1.0, 0.9, 0.47))
	_draw_centered_text(canvas, "MASTERY UNLOCKED", Vector2(cx, banner_y + 54.0), 16, Color(0.86, 0.78, 1.0))


func _draw_centered_text(canvas: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var draw_pos := Vector2(pos.x - text_size.x * 0.5, pos.y + text_size.y * 0.25)
	canvas.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
