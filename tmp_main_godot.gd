extends Node2D

# ============================================
# 핑파이터 Phase 1 - 공 + 패들 + 대시 + 점수 + HUD
# 명세: 섹션 1, 2, 3, 4, 5, 6
# ============================================

# --- 화면 상수 (명세 섹션 1) ---
const WIDTH := 760
const HEIGHT := 750
const PILLAR_WIDTH := 80
const PLAY_LEFT := 80
const PLAY_RIGHT := 680

# --- 공 상수 (명세 섹션 2) ---
const BALL_SIZE := 10
const BALL_RENDER_RADIUS := 12
const INITIAL_BALL_SPEED := 6.0
const MIN_BALL_SPEED := 3.0
const MAX_BALL_SPEED := 60.0
const SPEED_SCALE_THRESHOLD := 51.0
const WALL_DAMPING := 0.95
const PADDLE_HIT_BOOST := 1.1
const EDGE_HIT_BOOST := 1.2
const MAX_BOUNCE_ANGLE := 60.0

# --- 패들 상수 (명세 섹션 3) ---
const PADDLE_WIDTH := 155
const PADDLE_HEIGHT := 50
const PADDLE_SPEED := 6.0
const PADDLE_MAX_SPEED := 6.0
const PADDLE_ACCEL := 0.5
const PLAYER_Y := 700  # 750 - 50(패들높이) = 700 → 패들 바닥이 화면 하단에 딱 맞음
const BOSS_Y := 25
const BOSS_PADDLE_WIDTH := 100
const BOSS_PADDLE_HEIGHT := 40  # 시각적으로 보이게 (히트박스는 별도)
const BOSS_HITBOX_HEIGHT := 10  # 실제 충돌 판정용
const HITBOX_PADDING := 5

# --- 대시 상수 (명세 섹션 4) ---
const DASH_DURATION := 15.0
const HALF_DASH_DURATION := 11.0
const DASH_BASE_SPEED := 40.0
const DASH_DECEL_FRAMES := 20.0
const DASH_RECOVERY_FRAMES := 42.0
const HALF_DASH_RECOVERY_MULT := 1.5
const DASH_TOKEN_RECHARGE_FRAMES := 90.0
const CONSECUTIVE_DASH_START_DELAY_FRAMES := 12.0

const GAUGE_MAX := 350.0        # 특수 게이지 최대
const GAUGE_CHARGE_PER_HIT := 50.0  # 패들 타격 시 게이지 충전

# --- 점수 상수 (명세 섹션 5) ---
const WIN_GOAL := 5
const DEUCE_TRIGGER := 4
const DEUCE_GOAL_1 := 6
const DEUCE_GOAL_2 := 7

# --- 서브 ---
const SERVE_DELAY := 1.0

# --- 게임 상태 ---
var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_active := false
var ball_trail: Array[Vector2] = []

var player_pos := Vector2.ZERO
var player_speed := 0.0

var boss_pos := Vector2.ZERO

var player_score := 0
var boss_score := 0
var deuce_mode := false
var deuce_goal := DEUCE_GOAL_1

var serve_timer := 0.0
var waiting_for_serve := true
var player_serves := true

# --- 대시 상태 (명세 섹션 4) ---
var dash_tokens := 1            # 대시 토큰
var dash_tokens_max := 1
var dash_active := false
var dash_timer := 0.0
var dash_direction := 0.0
var dash_is_half := false       # 하프대시 여부
var dash_stun_timer := 0.0      # 원본 rolling_stun_timer 대응
var dash_available_timer := 0.0 # 원본 rolling_dash_available_timer 대응
var dash_charge_timer := 0.0    # 토큰 재충전 타이머
var dash_consecutive_count := 0
var dash_key_released_since_last := true
var dash_elapsed_frames := 0.0
var special_gauge := 0.0        # 특수 게이지

# --- 화면 흔들림 (명세 섹션 18) ---
var screen_shake := 0.0
var screen_shake_intensity := 0.0

# --- 히트 이펙트 ---
var hit_flash_timer := 0.0
var hit_particles: Array = []

# --- 색상 ---
const BG_COLOR := Color(0.03, 0.03, 0.08)
const LINE_COLOR := Color(1, 1, 1, 0.1)
const PLAYER_COLOR := Color(0.25, 0.45, 1.0)
const PLAYER_COLOR_LIGHT := Color(0.4, 0.6, 1.0)
const BOSS_COLOR := Color(1.0, 0.25, 0.25)
const BOSS_COLOR_LIGHT := Color(1.0, 0.45, 0.35)
const BALL_COLOR := Color.WHITE
const PILLAR_COLOR := Color(0.06, 0.06, 0.1)
const GAUGE_COLOR := Color(0.2, 0.8, 1.0)
const GAUGE_BG_COLOR := Color(0.15, 0.15, 0.2)
const DASH_TRAIL_COLOR := Color(0.3, 0.5, 1.0, 0.3)
const HALF_DASH_COLOR := Color(0.6, 0.6, 1.0, 0.4)

func _ready() -> void:
	player_pos = Vector2(WIDTH / 2.0 - PADDLE_WIDTH / 2.0, PLAYER_Y)
	boss_pos = Vector2(WIDTH / 2.0 - BOSS_PADDLE_WIDTH / 2.0, BOSS_Y)
	_reset_ball()

# 물리는 _physics_process (고정 60Hz), 렌더만 _process
func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_update_dash(delta)
	_update_boss_ai(delta)

	if waiting_for_serve:
		serve_timer += delta
		if serve_timer >= SERVE_DELAY:
			_serve_ball()
	else:
		_update_ball(delta)

	_update_effects(delta)
	queue_redraw()

# ============================================
# 입력 처리 + 대시 (명세 섹션 3, 4)
# ============================================
func _handle_input(delta: float) -> void:
	var down_pressed = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	if not down_pressed:
		dash_key_released_since_last = true

	var direction := 0.0
	# WASD + 방향키 양쪽 지원
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction += 1.0

	if dash_active:
		# 원본처럼 일정 시간이 지나면 남은 토큰으로 연속대시 캔슬 가능
		if (
			not dash_is_half
			and dash_tokens > 0
			and dash_elapsed_frames >= CONSECUTIVE_DASH_START_DELAY_FRAMES
			and down_pressed
			and direction != 0.0
		):
			_start_dash(direction, false)
		return  # 대시 중에는 일반 입력 무시

	if dash_stun_timer > 0.0:
		player_speed = 0.0
		return

	# 원본처럼 아래키를 떼었다가 다시 눌러야 다음 대시가 가능함
	if down_pressed and direction != 0.0 and dash_available_timer <= 0.0 and dash_key_released_since_last:
		if dash_tokens > 0:
			_start_dash(direction, false)
			return
		else:
			_start_dash(direction, true)
			return

	# 일반 이동
	var fps_scale = delta * 60.0
	if direction != 0.0:
		player_speed = move_toward(player_speed, direction * PADDLE_MAX_SPEED, PADDLE_ACCEL * fps_scale)
		if abs(player_speed) < PADDLE_SPEED:
			player_speed = direction * PADDLE_SPEED
	else:
		player_speed = move_toward(player_speed, 0.0, PADDLE_ACCEL * 2 * fps_scale)

	player_pos.x += player_speed * fps_scale
	player_pos.x = clamp(player_pos.x, 0, WIDTH - PADDLE_WIDTH)

func _start_dash(direction: float, is_half: bool) -> void:
	dash_active = true
	dash_direction = direction
	dash_is_half = is_half
	dash_elapsed_frames = 0.0
	player_speed = 0.0  # 기존 관성 초기화
	dash_key_released_since_last = false

	if is_half:
		dash_timer = HALF_DASH_DURATION
	else:
		dash_timer = DASH_DURATION
		dash_tokens -= 1
		dash_charge_timer = DASH_TOKEN_RECHARGE_FRAMES
		dash_consecutive_count += 1

	# 화면 흔들림 (대시 방향으로 강하게)
	screen_shake = 0.12
	screen_shake_intensity = 4.0

func _update_dash(delta: float) -> void:
	var fps_scale = delta * 60.0

	if dash_charge_timer > 0.0:
		dash_charge_timer = max(0.0, dash_charge_timer - fps_scale)
		if dash_charge_timer <= 0.0 and dash_tokens < dash_tokens_max:
			dash_tokens = dash_tokens_max
			dash_consecutive_count = 0

	if not dash_active:
		if dash_stun_timer > 0.0:
			dash_stun_timer = max(0.0, dash_stun_timer - fps_scale)
		if dash_available_timer > 0.0:
			dash_available_timer = max(0.0, dash_available_timer - fps_scale)
		return

	dash_elapsed_frames += fps_scale
	dash_timer -= fps_scale

	# 원본 핑파이터 방식:
	# rolling_timer 기반 선형 감속 + 프레임 단위 이동
	var current_speed := 0.0
	if dash_timer > DASH_DECEL_FRAMES:
		current_speed = DASH_BASE_SPEED
	else:
		var dash_strength = min(1.0, max(0.0, dash_timer) / DASH_DECEL_FRAMES)
		current_speed = DASH_BASE_SPEED * dash_strength
	var frame_step = round(dash_direction * current_speed * fps_scale)
	player_pos.x += frame_step
	player_pos.x = clamp(player_pos.x, 0, WIDTH - PADDLE_WIDTH)

	if dash_timer <= 0:
		dash_active = false
		player_speed = 0.0
		dash_elapsed_frames = 0.0
		if dash_is_half:
			dash_stun_timer = DASH_RECOVERY_FRAMES * HALF_DASH_RECOVERY_MULT
		else:
			dash_stun_timer = DASH_RECOVERY_FRAMES
		dash_available_timer = dash_stun_timer

# ============================================
# 보스 AI (명세 섹션 6.1 - 풍악보이)
# ============================================
const BOSS_MAX_SPEED := 6.32
const BOSS_ACCEL := 0.80
const BOSS_INSTANT_STOP := 0.67
const BOSS_PREDICT_DIST := 160
const BOSS_FAIL_ERROR := 315

var boss_vel := 0.0
var boss_target_error := 0.0
var boss_error_timer := 0.0

func _update_boss_ai(delta: float) -> void:
	var fps_scale = delta * 60.0

	boss_error_timer -= fps_scale
	if boss_error_timer <= 0:
		boss_error_timer = 30
		boss_target_error = randf_range(-BOSS_FAIL_ERROR, BOSS_FAIL_ERROR)

	var target_x: float
	if ball_vel.y < 0 and ball_active:
		var predict_x = ball_pos.x + ball_vel.x * BOSS_PREDICT_DIST / max(1, abs(ball_vel.y))
		target_x = predict_x + boss_target_error - BOSS_PADDLE_WIDTH / 2.0
	else:
		target_x = WIDTH / 2.0 - BOSS_PADDLE_WIDTH / 2.0

	var diff = target_x - boss_pos.x

	if abs(diff) < 5:
		boss_vel *= BOSS_INSTANT_STOP
	else:
		boss_vel += sign(diff) * BOSS_ACCEL * fps_scale
		boss_vel = clamp(boss_vel, -BOSS_MAX_SPEED, BOSS_MAX_SPEED)

	boss_pos.x += boss_vel * fps_scale
	boss_pos.x = clamp(boss_pos.x, 0, WIDTH - BOSS_PADDLE_WIDTH)

# ============================================
# 공 로직 (명세 섹션 2)
# ============================================
func _reset_ball() -> void:
	ball_pos = Vector2(WIDTH / 2.0, HEIGHT / 2.0)
	ball_vel = Vector2.ZERO
	ball_active = false
	ball_trail.clear()
	waiting_for_serve = true
	serve_timer = 0.0
	dash_active = false
	dash_timer = 0.0
	dash_direction = 0.0
	dash_is_half = false
	dash_stun_timer = 0.0
	dash_available_timer = 0.0
	dash_elapsed_frames = 0.0
	player_speed = 0.0
	dash_key_released_since_last = true

func _serve_ball() -> void:
	waiting_for_serve = false
	ball_active = true

	var direction = -1.0 if player_serves else 1.0
	var angle = randf_range(-0.3, 0.3)
	ball_vel = Vector2(angle * INITIAL_BALL_SPEED, direction * INITIAL_BALL_SPEED)

	if player_serves:
		ball_pos = Vector2(player_pos.x + PADDLE_WIDTH / 2.0, PLAYER_Y - BALL_SIZE)
	else:
		# 시각/물리 통일: BOSS_PADDLE_HEIGHT 기준 (시각 하단에서 출발)
		ball_pos = Vector2(boss_pos.x + BOSS_PADDLE_WIDTH / 2.0, BOSS_Y + BOSS_PADDLE_HEIGHT + BALL_SIZE)

func _update_ball(delta: float) -> void:
	if not ball_active:
		return

	var fps_scale = delta * 60.0
	ball_pos += ball_vel * fps_scale

	# 궤적 기록
	ball_trail.append(ball_pos)
	if ball_trail.size() > 20:
		ball_trail.pop_front()

	# 속도 스케일링
	var speed = ball_vel.length()
	if speed > SPEED_SCALE_THRESHOLD:
		ball_vel = ball_vel.normalized() * SPEED_SCALE_THRESHOLD

	# 벽 충돌
	if ball_pos.x - BALL_SIZE / 2 <= 0:
		ball_pos.x = BALL_SIZE / 2.0
		ball_vel.x = abs(ball_vel.x) * WALL_DAMPING
		ball_vel.y *= WALL_DAMPING
	elif ball_pos.x + BALL_SIZE / 2 >= WIDTH:
		ball_pos.x = WIDTH - BALL_SIZE / 2.0
		ball_vel.x = -abs(ball_vel.x) * WALL_DAMPING
		ball_vel.y *= WALL_DAMPING

	# 플레이어 패들 충돌
	if ball_vel.y > 0:
		var paddle_rect = Rect2(player_pos.x - HITBOX_PADDING, player_pos.y - HITBOX_PADDING,
								PADDLE_WIDTH + HITBOX_PADDING * 2, PADDLE_HEIGHT + HITBOX_PADDING * 2)
		var ball_rect = Rect2(ball_pos.x - BALL_SIZE / 2, ball_pos.y - BALL_SIZE / 2, BALL_SIZE, BALL_SIZE)
		if paddle_rect.intersects(ball_rect):
			_bounce_off_paddle(player_pos.x, PADDLE_WIDTH, true)
			_on_player_hit()

	# 보스 패들 충돌 (시각 크기와 통일)
	if ball_vel.y < 0:
		var paddle_rect = Rect2(boss_pos.x - HITBOX_PADDING, boss_pos.y - HITBOX_PADDING,
								BOSS_PADDLE_WIDTH + HITBOX_PADDING * 2, BOSS_PADDLE_HEIGHT + HITBOX_PADDING * 2)
		var ball_rect = Rect2(ball_pos.x - BALL_SIZE / 2, ball_pos.y - BALL_SIZE / 2, BALL_SIZE, BALL_SIZE)
		if paddle_rect.intersects(ball_rect):
			_bounce_off_paddle(boss_pos.x, BOSS_PADDLE_WIDTH, false)

	# 득점 판정
	if ball_pos.y < 0:
		_player_scored()
	elif ball_pos.y > HEIGHT:
		_boss_scored()

func _bounce_off_paddle(paddle_x: float, paddle_w: float, is_player: bool) -> void:
	var hit_pos = (ball_pos.x - (paddle_x + paddle_w / 2.0)) / (paddle_w / 2.0)
	hit_pos = clamp(hit_pos, -1.0, 1.0)

	var angle = hit_pos * MAX_BOUNCE_ANGLE
	var angle_rad = deg_to_rad(angle)

	var speed = ball_vel.length() * PADDLE_HIT_BOOST

	if abs(hit_pos) > 0.8:
		speed *= EDGE_HIT_BOOST

	speed = clamp(speed, MIN_BALL_SPEED, MAX_BALL_SPEED)

	ball_vel.x = speed * sin(angle_rad)
	if is_player:
		ball_vel.y = -abs(speed * cos(angle_rad))
		ball_pos.y = PLAYER_Y - BALL_SIZE
	else:
		ball_vel.y = abs(speed * cos(angle_rad))
		ball_pos.y = BOSS_Y + BOSS_PADDLE_HEIGHT + BALL_SIZE

	# 히트 이펙트
	hit_flash_timer = 0.08
	screen_shake = 0.1
	screen_shake_intensity = 3.0
	_spawn_hit_particles(ball_pos)

func _on_player_hit() -> void:
	# 게이지 충전
	special_gauge = min(special_gauge + GAUGE_CHARGE_PER_HIT, GAUGE_MAX)

# ============================================
# 이펙트
# ============================================
func _spawn_hit_particles(pos: Vector2) -> void:
	for i in range(8):
		hit_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-3, 3), randf_range(-3, 3)),
			"life": randf_range(0.2, 0.4),
			"max_life": 0.4,
			"size": randf_range(2, 5),
			"color": PLAYER_COLOR_LIGHT if ball_vel.y < 0 else BOSS_COLOR_LIGHT
		})

func _update_effects(delta: float) -> void:
	# 화면 흔들림 감쇠
	screen_shake = move_toward(screen_shake, 0.0, delta * 2)

	# 히트 플래시
	hit_flash_timer = move_toward(hit_flash_timer, 0.0, delta)

	# 파티클 업데이트
	var to_remove := []
	for i in range(hit_particles.size()):
		var p = hit_particles[i]
		p["pos"] += p["vel"]
		p["vel"] *= 0.92
		p["life"] -= delta
		if p["life"] <= 0:
			to_remove.append(i)
	to_remove.reverse()
	for i in to_remove:
		hit_particles.remove_at(i)

# ============================================
# 점수 시스템 (명세 섹션 5)
# ============================================
func _player_scored() -> void:
	if deuce_mode:
		player_score += 1
		_check_deuce_end()
	else:
		player_score += 1
		_check_win()
	player_serves = false
	_reset_ball()

func _boss_scored() -> void:
	if deuce_mode:
		boss_score += 1
		_check_deuce_end()
	else:
		boss_score += 1
		_check_win()
	player_serves = true
	_reset_ball()

func _check_win() -> void:
	if player_score >= WIN_GOAL:
		_reset_game()
	elif boss_score >= WIN_GOAL:
		_reset_game()
	elif player_score == DEUCE_TRIGGER and boss_score == DEUCE_TRIGGER:
		deuce_mode = true
		deuce_goal = DEUCE_GOAL_1

func _check_deuce_end() -> void:
	if player_score == 5 and boss_score == 5:
		deuce_goal = DEUCE_GOAL_2
	if player_score >= deuce_goal or boss_score >= deuce_goal:
		_reset_game()

func _reset_game() -> void:
	player_score = 0
	boss_score = 0
	deuce_mode = false
	deuce_goal = DEUCE_GOAL_1
	player_serves = true
	special_gauge = 0.0
	dash_tokens = dash_tokens_max
	dash_charge_timer = 0.0
	dash_consecutive_count = 0
	_reset_ball()

# ============================================
# 렌더링
# ============================================
func _draw() -> void:
	# 화면 흔들림 오프셋
	var shake_offset := Vector2.ZERO
	if screen_shake > 0:
		shake_offset = Vector2(
			randf_range(-screen_shake_intensity, screen_shake_intensity),
			randf_range(-screen_shake_intensity, screen_shake_intensity)
		) * screen_shake

	# 배경
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), BG_COLOR)

	# 히트 플래시
	if hit_flash_timer > 0:
		var flash_alpha = hit_flash_timer / 0.08 * 0.06
		draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color(1, 1, 1, flash_alpha))

	# 중앙선
	draw_line(Vector2(PLAY_LEFT, HEIGHT / 2) + shake_offset,
			  Vector2(PLAY_RIGHT, HEIGHT / 2) + shake_offset, LINE_COLOR, 1)

	# 진영 경계선
	draw_line(Vector2(PLAY_LEFT, 120) + shake_offset,
			  Vector2(PLAY_RIGHT, 120) + shake_offset, LINE_COLOR, 1)
	draw_line(Vector2(PLAY_LEFT, 630) + shake_offset,
			  Vector2(PLAY_RIGHT, 630) + shake_offset, LINE_COLOR, 1)

	# 대시 잔상
	if dash_active:
		var trail_color = HALF_DASH_COLOR if dash_is_half else DASH_TRAIL_COLOR
		var trail_w = PADDLE_WIDTH
		var trail_h = PADDLE_HEIGHT
		for i in range(3):
			var offset = -dash_direction * (i + 1) * 15
			var alpha = 0.3 - i * 0.1
			draw_rect(Rect2(player_pos.x + offset + shake_offset.x,
							player_pos.y + shake_offset.y, trail_w, trail_h),
					  Color(trail_color.r, trail_color.g, trail_color.b, alpha))

	# 플레이어 패들 (그라디언트 느낌)
	draw_rect(Rect2(player_pos + shake_offset, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT)), PLAYER_COLOR)
	draw_rect(Rect2(player_pos.x + 2 + shake_offset.x, player_pos.y + 2 + shake_offset.y,
					PADDLE_WIDTH - 4, PADDLE_HEIGHT / 3), PLAYER_COLOR_LIGHT)

	# 보스 패들 (두꺼운 시각)
	draw_rect(Rect2(boss_pos + shake_offset, Vector2(BOSS_PADDLE_WIDTH, BOSS_PADDLE_HEIGHT)), BOSS_COLOR)
	draw_rect(Rect2(boss_pos.x + 2 + shake_offset.x, boss_pos.y + BOSS_PADDLE_HEIGHT - BOSS_PADDLE_HEIGHT / 3 + shake_offset.y,
					BOSS_PADDLE_WIDTH - 4, BOSS_PADDLE_HEIGHT / 3), BOSS_COLOR_LIGHT)

	# 공 궤적
	if ball_active and ball_trail.size() > 1:
		for i in range(ball_trail.size()):
			var t = float(i) / ball_trail.size()
			var r = BALL_RENDER_RADIUS * 0.3 * t
			var alpha = 0.15 * t
			draw_circle(ball_trail[i] + shake_offset, r, Color(1, 1, 1, alpha))

	# 공
	if ball_active or waiting_for_serve:
		var draw_pos = ball_pos
		if waiting_for_serve:
			if player_serves:
				draw_pos = Vector2(player_pos.x + PADDLE_WIDTH / 2.0, PLAYER_Y - BALL_RENDER_RADIUS)
			else:
				draw_pos = Vector2(boss_pos.x + BOSS_PADDLE_WIDTH / 2.0, BOSS_Y + BOSS_PADDLE_HEIGHT + BALL_RENDER_RADIUS)
		draw_pos += shake_offset

		# 그림자
		draw_circle(draw_pos + Vector2(2, 4), BALL_RENDER_RADIUS, Color(0, 0, 0, 0.3))
		# 공
		draw_circle(draw_pos, BALL_RENDER_RADIUS, BALL_COLOR)
		# 테두리
		draw_arc(draw_pos, BALL_RENDER_RADIUS, 0, TAU, 32, Color(0.8, 0.8, 0.8), 1.5)
		# 내부 패턴
		draw_arc(draw_pos, BALL_RENDER_RADIUS * 0.5, 0, TAU, 16, Color(0.85, 0.85, 0.85), 1.0)

	# 파티클
	for p in hit_particles:
		var alpha = p["life"] / p["max_life"]
		var s = p["size"] * alpha
		draw_circle(p["pos"] + shake_offset, s, Color(p["color"].r, p["color"].g, p["color"].b, alpha))

	# 필러 (게임 오브젝트 위에 덮어 그리기)
	draw_rect(Rect2(0, 0, PILLAR_WIDTH, HEIGHT), PILLAR_COLOR)
	draw_rect(Rect2(WIDTH - PILLAR_WIDTH, 0, PILLAR_WIDTH, HEIGHT), PILLAR_COLOR)
	# 필러 경계선
	draw_line(Vector2(PILLAR_WIDTH, 0), Vector2(PILLAR_WIDTH, HEIGHT), Color(1, 1, 1, 0.05), 1)
	draw_line(Vector2(WIDTH - PILLAR_WIDTH, 0), Vector2(WIDTH - PILLAR_WIDTH, HEIGHT), Color(1, 1, 1, 0.05), 1)

	# HUD
	_draw_hud()

func _draw_hud() -> void:
	var font = ThemeDB.fallback_font

	# === 스코어보드 (중앙 상단) ===
	var score_y := 20
	var center_x := WIDTH / 2

	# 플레이어 점수
	draw_string(font, Vector2(center_x - 55, score_y + 28), str(player_score),
				HORIZONTAL_ALIGNMENT_CENTER, -1, 36, PLAYER_COLOR)
	# VS
	draw_string(font, Vector2(center_x - 5, score_y + 24), "-",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, 0.4))
	# 보스 점수
	draw_string(font, Vector2(center_x + 30, score_y + 28), str(boss_score),
				HORIZONTAL_ALIGNMENT_CENTER, -1, 36, BOSS_COLOR)

	# 라벨
	draw_string(font, Vector2(center_x - 65, score_y + 8), "YOU",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))
	draw_string(font, Vector2(center_x + 25, score_y + 8), "BOSS",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.4))

	# 듀스 표시
	if deuce_mode:
		draw_string(font, Vector2(center_x - 25, score_y + 48), "DEUCE",
					HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)

	# === 특수 게이지 (좌측 필러 내) ===
	var gauge_x := 15
	var gauge_y := 200
	var gauge_w := 12
	var gauge_h := 300

	# 배경
	draw_rect(Rect2(gauge_x, gauge_y, gauge_w, gauge_h), GAUGE_BG_COLOR)
	# 충전량
	var fill_ratio = special_gauge / GAUGE_MAX
	var fill_h = gauge_h * fill_ratio
	if fill_h > 0:
		var gauge_col = GAUGE_COLOR
		if fill_ratio >= 1.0:
			# 만충전 시 반짝임
			var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
			gauge_col = Color(0.3, 1.0, 1.0, pulse)
		draw_rect(Rect2(gauge_x, gauge_y + gauge_h - fill_h, gauge_w, fill_h), gauge_col)
	# 테두리
	draw_rect(Rect2(gauge_x, gauge_y, gauge_w, gauge_h), Color(1, 1, 1, 0.15), false, 1)
	# 라벨
	draw_string(font, Vector2(gauge_x - 2, gauge_y - 8), "SP",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.4))

	# === 대시 토큰 (좌측 필러 내) ===
	var token_x := 15
	var token_y := 530
	draw_string(font, Vector2(token_x, token_y - 8), "DASH",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.4))

	for i in range(dash_tokens_max):
		var tx = token_x + i * 18
		var ty = token_y
		if i < dash_tokens:
			# 사용 가능
			draw_rect(Rect2(tx, ty, 14, 14), GAUGE_COLOR)
			draw_rect(Rect2(tx, ty, 14, 14), Color(1, 1, 1, 0.3), false, 1)
		else:
			# 사용됨
			draw_rect(Rect2(tx, ty, 14, 14), GAUGE_BG_COLOR)
			draw_rect(Rect2(tx, ty, 14, 14), Color(1, 1, 1, 0.1), false, 1)

	# 하프대시 가능 표시
	if dash_tokens <= 0 and dash_available_timer <= 0.0 and not dash_active:
		var pulse = sin(Time.get_ticks_msec() * 0.008) * 0.4 + 0.6
		draw_string(font, Vector2(token_x, token_y + 28), "HALF",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 1.0, pulse))

	# === 대시 중 표시 ===
	if dash_active:
		var dash_text = "HALF DASH!" if dash_is_half else "DASH!"
		var dash_col = HALF_DASH_COLOR if dash_is_half else GAUGE_COLOR
		draw_string(font, Vector2(center_x - 30, HEIGHT - 30), dash_text,
					HORIZONTAL_ALIGNMENT_CENTER, -1, 16, dash_col)
