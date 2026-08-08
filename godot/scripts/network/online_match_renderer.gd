extends RefCounted

const OnlinePaddleState := preload("res://scripts/network/online_paddle_state.gd")

const FIELD_SIZE := Vector2(760.0, 750.0)
const BALL_RADIUS := 14.3
const HAN_IDLE_SHEET := preload("res://assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png")
const HAN_CELL_SIZE := Vector2(160.0, 160.0)
const HAN_FRAME_COUNT := 8


func draw(canvas: CanvasItem, session: Object, view_layout: Object, view_size: Vector2) -> void:
	if canvas == null or session == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.012, 0.018, 0.035, 1.0))
	var layout: Dictionary = (
		view_layout.build_game_layout(view_size, FIELD_SIZE.x, FIELD_SIZE.y)
		if view_layout != null and view_layout.has_method("build_game_layout")
		else _fallback_layout(view_size)
	)
	var offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var scale_value := float(layout.get("render_scale", 1.0))
	canvas.draw_set_transform(offset, 0.0, Vector2.ONE * scale_value)
	_draw_playfield(canvas, session)
	# The online renderer is the terminal draw branch for this frame. Do not
	# issue an IDENTITY reset here: that repository-wide trap can strip the
	# centered game offset from any later draw accidentally added to the branch.


func _draw_playfield(canvas: CanvasItem, session: Object) -> void:
	var state: Dictionary = session.get_render_state()
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.028, 0.055, 0.090, 1.0))
	for y in range(0, int(FIELD_SIZE.y), 50):
		var line_alpha := 0.08 if y % 100 == 0 else 0.035
		canvas.draw_line(Vector2(0.0, float(y)), Vector2(FIELD_SIZE.x, float(y)), Color(0.35, 0.75, 0.92, line_alpha), 1.0)
	canvas.draw_line(Vector2(0.0, FIELD_SIZE.y * 0.5), Vector2(FIELD_SIZE.x, FIELD_SIZE.y * 0.5), Color(0.55, 0.90, 1.0, 0.28), 2.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.48, 0.86, 1.0, 0.55), false, 3.0)

	var local_pos: Vector2 = state.get("local_paddle_pos", Vector2(302.5, 700.0))
	var opponent_pos: Vector2 = state.get("opponent_paddle_pos", Vector2(302.5, 25.0))
	_draw_han_paddle(canvas, opponent_pos, false, int(state.get("tick", 0)))
	_draw_han_paddle(canvas, local_pos, true, int(state.get("tick", 0)))
	if bool(state.get("ball_active", false)):
		var ball_pos: Vector2 = state.get("ball_pos", FIELD_SIZE * 0.5)
		var draw_ball_pos := ball_pos.clamp(
			Vector2.ONE * BALL_RADIUS,
			FIELD_SIZE - Vector2.ONE * BALL_RADIUS
		)
		var glow_radius := minf(
			BALL_RADIUS + 5.0,
			minf(
				minf(draw_ball_pos.x, FIELD_SIZE.x - draw_ball_pos.x),
				minf(draw_ball_pos.y, FIELD_SIZE.y - draw_ball_pos.y)
			)
		)
		if glow_radius > 0.0:
			canvas.draw_circle(draw_ball_pos, glow_radius, Color(0.20, 0.82, 1.0, 0.18))
		canvas.draw_circle(draw_ball_pos, BALL_RADIUS, Color(0.92, 0.98, 1.0, 1.0))
		canvas.draw_circle(draw_ball_pos - Vector2(4.0, 5.0), BALL_RADIUS * 0.34, Color(1.0, 1.0, 1.0, 0.9))

	_draw_hud(canvas, session, state)


func _draw_han_paddle(canvas: CanvasItem, paddle_pos: Vector2, is_local: bool, tick: int) -> void:
	var paddle_rect := Rect2(paddle_pos, Vector2(OnlinePaddleState.PADDLE_WIDTH, OnlinePaddleState.PADDLE_HEIGHT))
	var field_rect := Rect2(Vector2.ZERO, FIELD_SIZE)
	var glow := Color(0.30, 0.95, 1.0, 0.28) if is_local else Color(0.95, 0.42, 0.78, 0.24)
	var core := Color(0.58, 0.96, 1.0, 0.96) if is_local else Color(1.0, 0.60, 0.86, 0.94)
	canvas.draw_rect(paddle_rect.grow(7.0).intersection(field_rect), glow, true)
	canvas.draw_rect(paddle_rect, core, true)
	canvas.draw_rect(paddle_rect, Color.WHITE, false, 2.0)
	if HAN_IDLE_SHEET == null:
		return
	var frame := (tick / 7) % HAN_FRAME_COUNT
	var source := Rect2(
		Vector2(float(frame % 4), float(frame / 4)) * HAN_CELL_SIZE,
		HAN_CELL_SIZE
	)
	var sprite_y := paddle_pos.y - 112.0 if paddle_pos.y > FIELD_SIZE.y * 0.5 else paddle_pos.y + 4.0
	var destination := Rect2(Vector2(paddle_pos.x - 2.5, sprite_y), HAN_CELL_SIZE)
	canvas.draw_texture_rect_region(HAN_IDLE_SHEET, destination, source)


func _draw_hud(canvas: CanvasItem, session: Object, state: Dictionary) -> void:
	var font: Font = ThemeDB.fallback_font
	var score_text := "%d  :  %d" % [int(state.get("opponent_score", 0)), int(state.get("local_score", 0))]
	var score_panel := Rect2(Vector2(280.0, 176.0), Vector2(200.0, 52.0))
	canvas.draw_rect(score_panel, Color(0.01, 0.025, 0.05, 0.78), true)
	canvas.draw_rect(score_panel, Color(0.40, 0.82, 1.0, 0.48), false, 1.5)
	canvas.draw_string(font, Vector2(280.0, 214.0), score_text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 32, Color(0.95, 0.98, 1.0))
	var phase := str(state.get("match_phase", "waiting_peer"))
	var status: String = str(session.get_status_message())
	if phase == "countdown":
		status = "대전 시작  %.1f" % maxf(0.0, float(session.countdown_remaining))
	elif phase == "serve_wait":
		status = "내 서브 — 클릭 또는 Enter" if bool(state.get("local_serves", false)) else "상대 서브 대기"
	elif phase == "finished":
		status = "승리" if bool(state.get("winner_local", false)) else "패배"
	canvas.draw_string(font, Vector2(0.0, FIELD_SIZE.y * 0.5 - 20.0), status, HORIZONTAL_ALIGNMENT_CENTER, FIELD_SIZE.x, 24, Color(0.82, 0.94, 1.0))
	var footer := "온라인 한미량 미러전 · 이동 ← → · 대시 ↓ · 서브 클릭/Enter · ESC 나가기"
	if session.role == "client":
		footer += " · RTT %dms" % int(session.get_rtt_msec())
	canvas.draw_string(font, Vector2(0.0, 250.0), footer, HORIZONTAL_ALIGNMENT_CENTER, FIELD_SIZE.x, 14, Color(0.65, 0.78, 0.88))


func _fallback_layout(view_size: Vector2) -> Dictionary:
	var scale_value := minf(view_size.x / FIELD_SIZE.x, view_size.y / FIELD_SIZE.y)
	var game_size := FIELD_SIZE * scale_value
	return {
		"game_offset": (view_size - game_size) * 0.5,
		"render_scale": scale_value,
	}
