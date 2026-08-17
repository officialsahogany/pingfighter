extends RefCounted

const SmasherWheelCloudFxHost := preload("res://scripts/characters/smasher_wheel_cloud_fx_host.gd")

const SKILL_NAME := "smasher_wheel"
const GAUGE_COST := 240.0
const DURATION_MSEC := 1200
const CUTIN_FREEZE_DURATION := 1.65
const COMMAND_WINDOW_MSEC := 600
const COMMAND_BUFFER_MAX := 6
const ACTIVE_SPEED_MULT := 0.85
const ACTIVE_REVERSE_ACCEL_MULT := 0.18
const BALL_SPEED_MULT := 3.0
const HIT_MIN_SPEED := 30.0
const HIT_MAX_SPEED := 60.0
const HIT_ANGLE_MIN_DEG := 54.0
const HIT_ANGLE_MAX_DEG := 66.0
const HIT_CURVE_STRENGTH := 0.62
const HIT_GOLD := 30
const HIT_CURVE_PARTICLE_COUNT := 18
const HIT_TRAIL_FRAMES := 42
const PLAYER_COLLISION_COOLDOWN_FRAMES := 6.0

# --- 회선반동(rebound) ------------------------------------------------------
# 보스가 풍운천선무 반격을 가드해도 공을 곧장 낙하시키지 않는다: 보스 구역에서
# 사이클로이드 루프로 두 바퀴 휘감아 내려간 뒤 다시 보스로 재돌격한다.
# 노리는 것은 두 가지다.
#   1) 상향 — 가드 한 번으로 초식이 끝나지 않고 두 번째 타격 기회가 생긴다.
#   2) 필패 구간 봉인 — 루프가 벌어주는 시간(약 0.75초) 덕분에 리턴이 도착할
#      때는 이미 발동창(DURATION_MSEC)이 끝나 플레이어가 조작을 되찾은 상태다.
#      (발동 중에는 이동이 굼떠서, 예전처럼 곧장 낙하하면 왕복 0.75~0.95초 <
#      1.2초라 입력과 무관하게 못 막는 구간이 생겼다.)
# 공 소유(skip_ball_motion_step)가 아니라 벽력유성과 같은 "프레임별 속도 조향"
# 이라 벽 / 배리어 / 패들 판정은 평소대로 살아 있다.
const REBOUND_LOOP_FRAMES := 45.0
const REBOUND_LOOP_TURNS := 2.0
# 선회 성분과 하강 드리프트. drift < swirl 이어야 궤적에 실제 고리가 생기고,
# 합성 속도 하한(swirl - drift = 17)은 랠리 최소속도(최대 14.69)보다 커야 한다.
# 그 아래로 내려가면 enforce_minimum_rally_speed 가 루프를 부풀려 모양이 깨진다.
# drift/swirl 비율이 첫 선회의 상승 구간 높이를 정한다 — 0.346 이면 가드 지점보다
# 위로 올라가지 않아 루프 도중 보스를 다시 건드리지 않는다.
const REBOUND_SWIRL_SPEED := 26.0
const REBOUND_DRIFT_SPEED := 13.0
# 속도 엔벨로프: 가드 순간의 속도에서 **서서히 감속**했다가 회선 후반에 다시
# 원래 속도로 복귀한다(궤적 방향은 위 사이클로이드 그대로, 크기만 스케일).
# ⚠️감속 바닥은 랠리 최소속도(스테이지 최대 14.69)보다 커야 한다. 그 아래로
# 내리면 enforce_minimum_rally_speed 가 매 프레임 되밀고 ball_impact_boost 가
# 프레임마다 부풀어(= min_rally / raw 가 1을 넘음) 회선 뒤까지 새 캡을 연다.
const REBOUND_SLOW_SPEED := 16.0
const REBOUND_DECEL_FRAMES := 12.0
const REBOUND_ACCEL_FRAMES := 14.0
# 가드 직후 실측 속도를 "원래 속도"로 쓰되 상/하한을 둔다.
# ⚠️상한이 밸런스 다이얼이다. 실효속도(= ball_vel x ball_impact_boost)를 그대로
# 쓰면, 60짜리 천선무 반격이 만든 큰 impact boost 가 그대로 실려 재돌격이 원래
# 반격만큼 빨라진다(보스 리턴 자체는 max_ball_speed 26 으로 클램프되지만 boost 는
# 남는다). 라이브 테스트에서 "보스가 오히려 가드하기 힘들 정도"로 과상향된 지점.
# 기준점: 26 = 평범한 랠리 캡 / 34 = 램프 도입 전 고정 발사 속도.
const REBOUND_ENTRY_SPEED_MIN := 20.0
const REBOUND_ENTRY_SPEED_MAX := 30.0
# 마지막 단계(재돌격 비행): 발사 직후부터 보스에 닿을 때까지 **계속** 힘이
# 빠진다. 방향은 건드리지 않고 크기만 매 프레임 깎으므로 벽 반사 / 스핀 커브가
# 그대로 살아 있다. 부수 효과로 비행 시간이 늘어 보스가 반응할 여유가 생긴다
# (실측: 30 -> 약 19.8 로 도달, 비행 9 -> 11프레임).
# ⚠️바닥은 랠리 최소속도(스테이지 최대 14.69) 위여야 한다 — 아래로 내리면
# ball_impact_boost 가 매 프레임 부풀어 회선이 끝난 뒤까지 캡을 연다.
const REBOUND_FADE_FRAMES := 14.0
const REBOUND_FADE_END_SPEED := 17.0
const REBOUND_WALL_MARGIN := 40.0
const REBOUND_MAX_DEPTH_RATIO := 0.68
const REBOUND_ARM_TTL_FRAMES := 240.0
const REBOUND_TRAIL_FRAMES := 58
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const CLOUD_FX_CLIP_NAME := "SmasherWheelCloudFxClipHost"
const CLOUD_FX_HOST_NAME := "SmasherWheelCloudFxHost"
const BODY_SPIN_FRAME_START := 0
const BODY_SPIN_FRAME_END := 15
const BODY_SPIN_FRAME_MSEC := 40.0 / 1.5
const BODY_SPIN_GRID_COLS := 4
const BODY_SPIN_CELL_SIZE := Vector2(160.0, 160.0)
const BODY_SPIN_SHEET_FRAME_COUNT := 16
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_KEY := "smasher_wheel"
const TIMER_STACK_INDEX := 0

var active := false
var direction := 0
var start_msec := 0
var end_msec := 0
var collision_consumed := false
var activated_this_frame := false
var trail_timer_frames := 0
var command_buffer: Array[Dictionary] = []
var previous_command_keys := {
	"a": false,
	"w": false,
	"d": false,
}
var _last_player_pos := Vector2(FIELD_WIDTH * 0.5 - DEFAULT_PLAYER_SIZE.x * 0.5, FIELD_HEIGHT - DEFAULT_PLAYER_SIZE.y)
var _last_player_size := DEFAULT_PLAYER_SIZE
var _cached_body_spin_msec := -1
var _cached_body_spin_frame := BODY_SPIN_FRAME_START
var _timer_font: Font
var _runtime_perk_modal_pause_started_msec := -1
var cloud_fx_host: Node = null
var cloud_fx_clip_host: Control = null
var cloud_fx_host_add_pending := false
var _cloud_burst_serial := 0
var _cloud_burst_pos := Vector2.ZERO
var _rebound_armed := false
var _rebound_arm_frames := 0.0
var _rebound_used := false
var _rebound_frames_remaining := 0.0
var _rebound_angle := 0.0
var _rebound_spin_dir := 1
var _rebound_serial := 0
var _rebound_entry_speed := 0.0
var _rebound_fade_frames_remaining := 0.0
var _rebound_fade_start_speed := 0.0


func prewarm_assets() -> void:
	_get_timer_font()
	SmasherWheelCloudFxHost.prewarm_assets()


func reset() -> void:
	_hide_cloud_fx()
	active = false
	direction = 0
	start_msec = 0
	end_msec = 0
	collision_consumed = false
	activated_this_frame = false
	trail_timer_frames = 0
	_cached_body_spin_msec = -1
	_cached_body_spin_frame = BODY_SPIN_FRAME_START
	_runtime_perk_modal_pause_started_msec = -1
	_cloud_burst_serial = 0
	_cloud_burst_pos = Vector2.ZERO
	_reset_rebound()
	command_buffer.clear()
	_clear_previous_command_keys()


# 회선 토큰은 발동창(_expire_if_needed)보다 오래 살아야 한다 — 느린 로브는
# 창이 끝난 뒤에 보스에 닿기 때문이다. 그래서 만료가 아니라 라운드 / 컨텍스트
# 리셋에서만 지운다.
func _reset_rebound() -> void:
	_rebound_armed = false
	_rebound_arm_frames = 0.0
	_rebound_used = false
	_rebound_frames_remaining = 0.0
	_rebound_angle = 0.0
	_rebound_spin_dir = 1
	_rebound_serial = 0
	_rebound_entry_speed = 0.0
	_rebound_fade_frames_remaining = 0.0
	_rebound_fade_start_speed = 0.0


func reset_round() -> void:
	reset()


func pause_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec >= 0 or (not active and command_buffer.is_empty()):
		return
	_runtime_perk_modal_pause_started_msec = maxi(0, current_msec)


func resume_runtime_perk_modal_time(current_msec: int) -> void:
	if _runtime_perk_modal_pause_started_msec < 0:
		return
	var pause_started_msec := _runtime_perk_modal_pause_started_msec
	_runtime_perk_modal_pause_started_msec = -1
	var paused_duration_msec: int = maxi(0, current_msec - pause_started_msec)
	if paused_duration_msec <= 0:
		return
	if active:
		start_msec += paused_duration_msec
		end_msec += paused_duration_msec
		_cached_body_spin_msec = -1
	for command: Dictionary in command_buffer:
		if command.has("msec"):
			command["msec"] = int(command.get("msec", 0)) + paused_duration_msec


func is_active() -> bool:
	return active


func was_activated_this_frame() -> bool:
	return activated_this_frame


func has_visible_effects() -> bool:
	return active


# 회선 토큰 / 회선 진행은 발동창 밖에서도 살아 있는 비-시각 상태다. 여기에
# 등재하지 않으면 게이트가 update_effects 를 통째로 끊어 TTL 이 영원히 얼어붙는다
# (링펫 idle-게이트 "보이는 것 != 살아있는 것" 트랩의 동일 계열).
func needs_effect_update() -> bool:
	return active or trail_timer_frames > 0 or _rebound_armed or is_rebound_active()


func get_remaining_ratio(current_msec: int = -1) -> float:
	if not active:
		return 0.0
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	return clamp(float(end_msec - now_msec) / float(max(1, DURATION_MSEC)), 0.0, 1.0)


func get_status_context() -> Dictionary:
	var now_msec: int = Time.get_ticks_msec() if active else 0
	return {
		"active": active,
		"direction": direction,
		"remaining_ratio": get_remaining_ratio(now_msec) if active else 0.0,
		"remaining_msec": max(0, end_msec - now_msec) if active else 0,
		"collision_consumed": collision_consumed,
		"trail_timer_frames": trail_timer_frames,
		"cloud_burst_serial": _cloud_burst_serial,
		"cloud_burst_pos": _cloud_burst_pos,
		"rebound_armed": _rebound_armed,
		"rebound_used": _rebound_used,
		"rebound_frames_remaining": _rebound_frames_remaining,
		"rebound_serial": _rebound_serial,
		"rebound_entry_speed": _rebound_entry_speed,
		"rebound_speed": _resolve_rebound_speed() if _rebound_frames_remaining > 0.0 else 0.0,
		"rebound_fade_frames_remaining": _rebound_fade_frames_remaining,
	}


func get_body_spin_frame(current_msec: int = -1) -> int:
	var frame_span: int = max(1, BODY_SPIN_FRAME_END - BODY_SPIN_FRAME_START + 1)
	if not active:
		return BODY_SPIN_FRAME_START
	var now_msec: int = current_msec if current_msec >= 0 else Time.get_ticks_msec()
	if now_msec == _cached_body_spin_msec:
		return _cached_body_spin_frame
	var elapsed_msec: int = max(0, now_msec - start_msec)
	_cached_body_spin_msec = now_msec
	_cached_body_spin_frame = BODY_SPIN_FRAME_START + (int(elapsed_msec / BODY_SPIN_FRAME_MSEC) % frame_span)
	return _cached_body_spin_frame


func get_actor_draw_context(current_msec: int = -1) -> Dictionary:
	return {
		"player_wheel_spin_active": active,
		"player_wheel_spin_frame": get_body_spin_frame(current_msec),
		"player_wheel_spin_cell_width": BODY_SPIN_CELL_SIZE.x,
		"player_wheel_spin_cell_height": BODY_SPIN_CELL_SIZE.y,
		"player_wheel_spin_frame_count": BODY_SPIN_SHEET_FRAME_COUNT,
		"player_wheel_spin_grid_cols": BODY_SPIN_GRID_COLS,
		"player_wheel_spin_draw_size": BODY_SPIN_CELL_SIZE,
	}


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	activated_this_frame = false
	_expire_if_needed(current_msec)
	var result := {
		"special_gauge": special_gauge,
		"activated": false,
	}
	if bool(config.get("player_skill_input_locked", false)):
		reset()
		return result
	_update_command_buffer(input_snapshot, current_msec)

	if active:
		command_buffer.clear()
		_clear_previous_command_keys()
		return result

	# 대시 후딜 중에는 A-W-D 완성 프레임에 즉시 발동한다. 단순 예약으로 두면
	# 42프레임 후딜이 끝날 때까지 컷인이 늦어져 사용자가 의도한 후딜 캔슬이 아니다.
	# 실제 발동 직전에 후딜 상태와 지연음을 함께 끝내, wheel_active 게이트가 이후
	# 대시 update 를 건너뛰어도 통제불능 타이머 / 루프음이 남지 않게 한다.
	# 대시 비행 중이나 변신·기절·타 스킬 잠금은 기존대로 발동을 막는다.
	var dash_recovering: bool = _is_dash_recovering(deps)
	if not _can_activate(current_msec, special_gauge, config, deps, dash_recovering):
		return result

	var triggered_dir: int = _consume_command_direction(current_msec)
	if triggered_dir == 0:
		return result
	if dash_recovering:
		_release_dash_recovery_for_activation(deps)

	var cost: float = _get_skill_cost(deps.get("skill_config", null))
	var next_gauge: float = max(0.0, special_gauge - cost)
	_activate(current_msec, triggered_dir, player_pos, config, deps)
	_trigger_cooldown(current_msec, deps)
	result["special_gauge"] = next_gauge
	result["activated"] = true
	result["player_speed"] = _get_active_launch_speed(config) * float(triggered_dir)
	return result


func get_movement_direction(input_direction: float) -> float:
	if not active:
		return input_direction
	# 발동 커맨드(A-W-D / D-W-A)가 정한 진행 방향을 창 끝까지 유지한다.
	# 활성 중의 좌우 입력은 새 방향을 고르는 조향 입력이 아니다.
	return float(direction)


func apply_movement_config(config: Dictionary, player_speed: float, input_direction: float) -> Dictionary:
	if not active:
		return config
	var motion_config := config.duplicate()
	motion_config["paddle_max_speed"] = float(motion_config.get("paddle_max_speed", 6.0)) * ACTIVE_SPEED_MULT
	# 진행 방향 소유권은 get_movement_direction()이 발동창 끝까지 유지한다.
	# 타격 뒤에는 기반 이동 관성 설정만 정상값으로 돌리지만, 좌우 입력으로 커맨드
	# 방향을 바꿀 수는 없다. 이동속도 -15%와 활주 불가도 창 끝까지 그대로다.
	if not collision_consumed:
		motion_config["paddle_turn_decel"] = 0.0
		if _is_reversing(player_speed, input_direction):
			motion_config["paddle_accel"] = float(motion_config.get("paddle_accel", 0.5)) * ACTIVE_REVERSE_ACCEL_MULT
	return motion_config


func update_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	if active:
		_expire_if_needed(current_msec)
	_tick_rebound_arm(fps_scale)
	_update_trail(context, deps)


# 무장 토큰 실패안전: 보스가 끝내 이 공을 가드하지 않는 경로(벽 핑퐁 등)에서도
# 토큰이 영원히 남아 나중 랠리의 보스 가드에서 유령 회선이 터지지 않게 한다.
func _tick_rebound_arm(fps_scale: float) -> void:
	if not _rebound_armed:
		return
	_rebound_arm_frames -= maxf(0.0, fps_scale)
	if _rebound_arm_frames > 0.0:
		return
	_rebound_armed = false
	_rebound_arm_frames = 0.0


func consume_ball_hit(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active or collision_consumed:
		return {}
	var incoming_speed: float = ball_vel.length()
	var base_speed: float = max(1.0, float(context.get("base_ball_speed", 9.0)))
	var speed_cap: float = HIT_MAX_SPEED
	var launch_speed: float = max(incoming_speed * BALL_SPEED_MULT, base_speed * BALL_SPEED_MULT, HIT_MIN_SPEED)
	launch_speed = min(launch_speed, speed_cap)
	var curve_dir: int = -1 if randf() < 0.5 else 1
	var angle_rad: float = deg_to_rad(randf_range(HIT_ANGLE_MIN_DEG, HIT_ANGLE_MAX_DEG))
	var next_vel := Vector2(
		cos(angle_rad) * launch_speed * float(curve_dir),
		-abs(sin(angle_rad) * launch_speed)
	)
	collision_consumed = true
	trail_timer_frames = HIT_TRAIL_FRAMES
	# 이 반격 공에만 회선반동 권리가 붙는다(발동당 1회).
	_rebound_armed = true
	_rebound_used = false
	_rebound_arm_frames = REBOUND_ARM_TTL_FRAMES
	_rebound_frames_remaining = 0.0
	_cloud_burst_serial += 1
	_cloud_burst_pos = ball_pos
	_release_magnum_grip_on_hit(deps)
	_register_hit_feedback(ball_pos, next_vel, deps)
	return {
		"ball_pos": _snap_ball_above_player(ball_pos, context),
		"ball_vel": next_vel,
		"ball_spin_strength": HIT_CURVE_STRENGTH,
		"ball_spin_direction": curve_dir,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": max(0.0, launch_speed - incoming_speed),
		"player_collision_cooldown": PLAYER_COLLISION_COOLDOWN_FRAMES,
		"smasher_wheel_speed_cap": speed_cap,
		"smasher_wheel_hit": true,
		"runtime_perk_gold": _award_hit_gold(context, deps),
	}


# 흡인장 → 천선무 콤보의 공 소유권 인계 지점. 흡인장은 살아 있는 동안 매 프레임
# 공을 패들 쪽으로 끌어당기므로(apply_magnum_grip 은 ball_update_controller :115 로
# 이 스킬의 자체 충돌 :171 보다 **먼저** 돈다), 천선무가 공을 쳐낸 뒤에도 흡인장이
# 남아 있으면 60짜리 반격을 도로 패들 쪽으로 끌어내린다. 흡인장의 자체 해제는
# 패딩 없는 패들 rect 교차라, 천선무의 padded rect 가 먼저 먹은 프레임에는 아직
# 안 풀린다 — 그래서 여기서 명시적으로 넘겨받아야 한다.
# 정상 패들 바운스 경로(paddle_bounce_player_post_hit_handler :17~22)와 같은 순서로
# 처리한다: 릴리스 캡을 먼저 consume(안 하면 pending 45 캡이 랠리 내내 남는다)한
# 뒤 해제.
func _release_magnum_grip_on_hit(deps: Dictionary) -> void:
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state == null:
		return
	if not (magnum_state.has_method("is_active") and bool(magnum_state.is_active())):
		return
	if magnum_state.has_method("consume_release_hit_speed_cap"):
		magnum_state.consume_release_hit_speed_cap()
	if magnum_state.has_method("deactivate"):
		magnum_state.deactivate()


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not active or collision_consumed:
		return {}
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var player_pos: Vector2 = _get_vector2(context, "player_pos", _last_player_pos)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", _last_player_size)
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var ball_rect := Rect2(ball_pos.x - ball_size * 0.5, ball_pos.y - ball_size * 0.5, ball_size, ball_size)
	var player_rect := Rect2(
		player_pos.x - hitbox_padding,
		player_pos.y - hitbox_padding,
		player_size.x + hitbox_padding * 2.0,
		player_size.y + hitbox_padding * 2.0
	)
	if not _player_or_mirror_rect_hits_ball(player_rect, ball_rect, float(context.get("player_paddle_mirror_offset_x", 0.0))):
		return {}
	var hit_context: Dictionary = context.duplicate()
	hit_context.merge(scene, true)
	return consume_ball_hit(ball_pos, _get_vector2(scene, "ball_vel", Vector2.ZERO), hit_context, deps)


# 회선 소유 = 선회 루프 + 재돌격 감속 비행. 프레임 조향 게이트는 이걸 본다.
func is_rebound_active() -> bool:
	return _rebound_frames_remaining > 0.0 or _rebound_fade_frames_remaining > 0.0


func is_rebound_looping() -> bool:
	return _rebound_frames_remaining > 0.0


func is_rebound_fading() -> bool:
	return _rebound_fade_frames_remaining > 0.0


func is_rebound_armed() -> bool:
	return _rebound_armed


# 공 VFX 신호 계약(Opus 비주얼 레인 구독자용). 렌더러는 이 정규화된 값만 읽고
# 물리·속도에는 손대지 않는다 — 조향 소유는 이 모듈에 있다.
# 매 드로우 프레임 호출되므로 get_status_context() 전체를 태우지 않고 필요한
# 키만 만든다(딥카피·불필요 연산 없음).
func get_ball_fx_signals() -> Dictionary:
	return {
		"wheel_rebound_looping": _rebound_frames_remaining > 0.0,
		"wheel_rebound_fading": _rebound_fade_frames_remaining > 0.0,
		# 0(발사 직후) -> 1(감속 끝). 속도 엔벨로프와 같은 시계를 쓰므로
		# "벗겨짐" 그림이 실제 공속 감소와 정확히 동기화된다.
		"wheel_rebound_fade_ratio": (
			clampf(1.0 - (_rebound_fade_frames_remaining / maxf(1.0, REBOUND_FADE_FRAMES)), 0.0, 1.0)
			if _rebound_fade_frames_remaining > 0.0
			else 0.0
		),
		"wheel_rebound_serial": _rebound_serial,
	}


# 보스가 풍운천선무 반격을 가드한 프레임에서 불린다(커밋된 정상 보스 반사 한정).
# 발동당 1회만 성립하며, 성립하면 이번 프레임의 낙하 속도를 회선 첫 프레임
# 속도로 갈아끼운 결과를 돌려준다. 빈 Dictionary = 평소대로 낙하.
func notify_boss_guard_rebound(ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	if not _rebound_armed or _rebound_used or is_rebound_active():
		# 2차 가드: 회선은 여기서 끝난다. 감속 비행 소유를 놓아야 보스 리턴 속도를
		# 우리가 계속 덮어쓰지 않는다.
		_rebound_frames_remaining = 0.0
		_rebound_fade_frames_remaining = 0.0
		_rebound_fade_start_speed = 0.0
		return {}
	_rebound_armed = false
	_rebound_arm_frames = 0.0
	_rebound_used = true
	_rebound_frames_remaining = REBOUND_LOOP_FRAMES
	# 첫 프레임은 정확히 아래 방향에서 출발한다(가드 직후의 낙하와 이어진다).
	_rebound_angle = PI * 0.5
	# 벽 쪽이 아니라 넓은 쪽으로 첫 선회를 연다.
	_rebound_spin_dir = -1 if ball_pos.x < _get_field_width(context) * 0.5 else 1
	# "원래 속도" = 가드 직후 이 공의 실효 속도. 여기서 감속했다가 회선 끝에
	# 이 값으로 되돌린다.
	var entry: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO) * _get_impact_boost(context)
	_rebound_entry_speed = clampf(entry.length(), REBOUND_ENTRY_SPEED_MIN, REBOUND_ENTRY_SPEED_MAX)
	_rebound_serial += 1
	trail_timer_frames = maxi(trail_timer_frames, REBOUND_TRAIL_FRAMES)
	_register_rebound_feedback(ball_pos, deps)
	return {
		"ball_vel": _resolve_rebound_velocity(ball_pos, _get_impact_boost(context), context),
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"smasher_wheel_speed_cap": _rebound_speed_cap(),
	}


# 프레임별 속도 조향. 위치 전진은 step_motion 이 그대로 맡으므로 공을 소유하지
# 않는다 — 벽 / 배리어 / 패들 판정이 모두 살아 있다.
func apply_rebound_ball_motion(
	ball_pos: Vector2,
	ball_vel: Vector2,
	fps_scale: float,
	context: Dictionary
) -> Dictionary:
	if _rebound_frames_remaining <= 0.0:
		return _apply_rebound_fade(ball_vel, fps_scale, context)
	var safe_boost: float = _get_impact_boost(context)
	var step: float = clampf(fps_scale, 0.0, _rebound_frames_remaining)
	_rebound_angle += (TAU * REBOUND_LOOP_TURNS / REBOUND_LOOP_FRAMES) * float(_rebound_spin_dir) * step
	_rebound_frames_remaining = maxf(0.0, _rebound_frames_remaining - step)
	# 실패안전: 예상보다 깊게 내려가면(외부 힘 / 극단 fps_scale) 즉시 재상승으로
	# 마감해 회선이 플레이어 진영까지 흘러내리지 않게 한다.
	if ball_pos.y >= _get_field_height(context) * REBOUND_MAX_DEPTH_RATIO:
		_rebound_frames_remaining = 0.0
	if _rebound_frames_remaining <= 0.0:
		return _build_rebound_launch(ball_pos, safe_boost, context)
	return {
		"ball_vel": _resolve_rebound_velocity(ball_pos, safe_boost, context),
		"smasher_wheel_speed_cap": _rebound_speed_cap(),
	}


# 마지막 단계: 재돌격이 보스로 날아가는 동안 매 프레임 힘이 빠진다.
# **방향은 들어온 그대로 두고 크기만** 깎는다 — 벽 반사 / 스핀 커브가 만든
# 방향 변화를 우리가 되돌리지 않기 위해서다.
func _apply_rebound_fade(ball_vel: Vector2, fps_scale: float, context: Dictionary) -> Dictionary:
	if _rebound_fade_frames_remaining <= 0.0:
		return {}
	if ball_vel.length_squared() <= 0.0001:
		# 다른 소유자가 공을 세웠다면(캡처 / 프리즈) 감속 소유를 놓는다.
		_rebound_fade_frames_remaining = 0.0
		return {}
	var step: float = clampf(fps_scale, 0.0, _rebound_fade_frames_remaining)
	_rebound_fade_frames_remaining = maxf(0.0, _rebound_fade_frames_remaining - step)
	var elapsed: float = REBOUND_FADE_FRAMES - _rebound_fade_frames_remaining
	var t: float = clampf(elapsed / maxf(1.0, REBOUND_FADE_FRAMES), 0.0, 1.0)
	var speed: float = lerpf(_rebound_fade_start_speed, REBOUND_FADE_END_SPEED, t)
	return {
		"ball_vel": ball_vel.normalized() * (speed / _get_impact_boost(context)),
		"smasher_wheel_speed_cap": _rebound_speed_cap(),
	}


# 회선 권리는 이번 초식의 반격 공에만 붙는다. 풍운천선무 타격이 아닌 평범한
# 플레이어 반사가 끼어들면 즉시 해제해, 나중 보스 가드에서 유령 회선이 터지지
# 않게 한다(소유 토큰 누수 방지).
func notify_player_bounce_rebound_release() -> void:
	_rebound_armed = false
	_rebound_arm_frames = 0.0
	_rebound_frames_remaining = 0.0
	_rebound_fade_frames_remaining = 0.0
	_rebound_fade_start_speed = 0.0


func _resolve_rebound_velocity(ball_pos: Vector2, safe_boost: float, context: Dictionary) -> Vector2:
	var field_width: float = _get_field_width(context)
	var heading: Vector2 = _build_rebound_swirl_heading()
	if (
		(ball_pos.x <= REBOUND_WALL_MARGIN and heading.x < 0.0)
		or (ball_pos.x >= field_width - REBOUND_WALL_MARGIN and heading.x > 0.0)
	):
		# 벽 앞에서는 선회를 좌우 반전해 루프를 필드 안으로 되접는다. 그냥 두면
		# step_motion 의 벽 반사가 매 프레임 조향과 싸워 궤적이 뭉개진다.
		_rebound_angle = PI - _rebound_angle
		_rebound_spin_dir = -_rebound_spin_dir
		heading = _build_rebound_swirl_heading()
	return heading * (_resolve_rebound_speed() / maxf(0.001, safe_boost))


# 사이클로이드 진행 **방향**만 준다. 크기는 속도 엔벨로프가 따로 정하므로
# drift/swirl 비율(= 고리가 생기는 조건)은 감속 구간에서도 그대로 유지된다.
func _build_rebound_swirl_heading() -> Vector2:
	var composed := Vector2.from_angle(_rebound_angle) * REBOUND_SWIRL_SPEED + Vector2(0.0, REBOUND_DRIFT_SPEED)
	if composed.length_squared() <= 0.0001:
		return Vector2.DOWN
	return composed.normalized()


# 가드 속도 -> REBOUND_SLOW_SPEED -> 다시 가드 속도. 양 끝을 smoothstep 으로
# 이어 "뚝 떨어졌다 뚝 붙는" 느낌 대신 서서히 감속/복귀하게 만든다.
func _resolve_rebound_speed() -> float:
	var entry: float = maxf(REBOUND_ENTRY_SPEED_MIN, _rebound_entry_speed)
	var elapsed: float = maxf(0.0, REBOUND_LOOP_FRAMES - _rebound_frames_remaining)
	if elapsed < REBOUND_DECEL_FRAMES:
		return lerpf(entry, REBOUND_SLOW_SPEED, smoothstep(0.0, 1.0, elapsed / maxf(1.0, REBOUND_DECEL_FRAMES)))
	var accel_start: float = REBOUND_LOOP_FRAMES - REBOUND_ACCEL_FRAMES
	if elapsed < accel_start:
		return REBOUND_SLOW_SPEED
	var t: float = (elapsed - accel_start) / maxf(1.0, REBOUND_ACCEL_FRAMES)
	return lerpf(REBOUND_SLOW_SPEED, entry, smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0)))


# 회선 구간이 실제로 쓰는 최고 속도까지만 캡을 연다. 예전 고정 40 은 회선이
# 낼 수 있는 속도보다 넉넉해서, 상한을 낮춰도 캡이 남아 다른 효과에 여지를 줬다.
func _rebound_speed_cap() -> float:
	return maxf(REBOUND_SLOW_SPEED, maxf(REBOUND_ENTRY_SPEED_MIN, _rebound_entry_speed))


func _build_rebound_launch(ball_pos: Vector2, safe_boost: float, context: Dictionary) -> Dictionary:
	var field_width: float = _get_field_width(context)
	var curve_dir: int = -1 if randf() < 0.5 else 1
	if ball_pos.x <= field_width * 0.22:
		curve_dir = 1
	elif ball_pos.x >= field_width * 0.78:
		curve_dir = -1
	var angle_rad: float = deg_to_rad(randf_range(HIT_ANGLE_MIN_DEG, HIT_ANGLE_MAX_DEG))
	# 재돌격은 회선 복귀 램프가 도달한 값 = 가드 시점의 원래 속도로 나간 뒤,
	# 여기서부터 보스에 닿을 때까지 계속 힘이 빠진다.
	var launch_speed: float = maxf(REBOUND_ENTRY_SPEED_MIN, _rebound_entry_speed)
	_rebound_fade_start_speed = launch_speed
	_rebound_fade_frames_remaining = REBOUND_FADE_FRAMES
	var effective := Vector2(
		cos(angle_rad) * launch_speed * float(curve_dir),
		-abs(sin(angle_rad) * launch_speed)
	)
	return {
		"ball_vel": effective / maxf(0.001, safe_boost),
		"ball_spin_strength": HIT_CURVE_STRENGTH,
		"ball_spin_direction": curve_dir,
		"smasher_wheel_speed_cap": _rebound_speed_cap(),
	}


func _register_rebound_feedback(ball_pos: Vector2, deps: Dictionary) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(ball_pos, _build_rebound_swirl_heading() * _resolve_rebound_speed(), 0.8, "smasher_wheel")
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null:
		if impact_effects.has_method("spawn_drive_particles"):
			impact_effects.spawn_drive_particles(ball_pos, HIT_CURVE_PARTICLE_COUNT)
		if impact_effects.has_method("create_energy_explosion"):
			impact_effects.create_energy_explosion(ball_pos, 0.5, 0.8)
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.08, 6.0)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.08, 6.0)


func _get_impact_boost(context: Dictionary) -> float:
	return maxf(0.001, float(context.get("ball_impact_boost", 1.0)))


func _get_field_width(context: Dictionary) -> float:
	return maxf(1.0, float(context.get("width", FIELD_WIDTH)))


func _get_field_height(context: Dictionary) -> float:
	return maxf(1.0, float(context.get("height", FIELD_HEIGHT)))


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO,
	timer_stack: Object = null,
	node_fx_layout: Dictionary = {}
) -> void:
	if canvas == null or not active:
		return
	_sync_cloud_fx(canvas, shake_offset, node_fx_layout)
	_draw_timer_bar(canvas, timer_stack, Time.get_ticks_msec())


func _activate(current_msec: int, next_direction: int, player_pos: Vector2, config: Dictionary, deps: Dictionary) -> void:
	active = true
	direction = clamp(next_direction, -1, 1)
	start_msec = current_msec
	end_msec = current_msec + DURATION_MSEC
	collision_consumed = false
	activated_this_frame = true
	_cached_body_spin_msec = current_msec
	_cached_body_spin_frame = BODY_SPIN_FRAME_START
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	_cloud_burst_serial = 0
	_cloud_burst_pos = player_pos + _last_player_size * 0.5
	command_buffer.clear()
	_clear_previous_command_keys()
	var power_state: Object = deps.get("power_state", null)
	if power_state != null and power_state.has_method("begin_cinematic_freeze"):
		end_msec += int(ceil(CUTIN_FREEZE_DURATION * 1000.0))
		power_state.begin_cinematic_freeze(CUTIN_FREEZE_DURATION, SKILL_NAME)
		# 보이스는 컷인이 실제로 열린 분기 안에서만. 천뢰격/고스트가 프리즈
		# 컷인에서만 대사를 내보내는 규칙과 같다.
		_play_cutin_voice(deps)
		_play_full_skill_cutin_sound(deps)
	_trigger_activation_feedback(deps)


func _expire_if_needed(current_msec: int) -> void:
	if not active:
		return
	if current_msec < end_msec:
		return
	active = false
	direction = 0
	start_msec = 0
	end_msec = 0
	collision_consumed = false
	_cached_body_spin_msec = -1
	_cached_body_spin_frame = BODY_SPIN_FRAME_START
	_hide_cloud_fx()


func _sync_cloud_fx(canvas: CanvasItem, shake_offset: Vector2, node_fx_layout: Dictionary) -> bool:
	if node_fx_layout.is_empty():
		return false
	var host: Node = _get_or_create_cloud_fx_host(canvas)
	if host == null or not host.has_method("sync_state") or not host.is_inside_tree():
		return false
	var render_scale: float = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
	var game_offset: Vector2 = _get_vector2(node_fx_layout, "game_offset", Vector2.ZERO)
	if cloud_fx_clip_host != null and is_instance_valid(cloud_fx_clip_host):
		cloud_fx_clip_host.position = game_offset
		cloud_fx_clip_host.size = Vector2(FIELD_WIDTH, FIELD_HEIGHT) * render_scale
		cloud_fx_clip_host.visible = true
	var player_center: Vector2 = _last_player_pos + _last_player_size * 0.5 + shake_offset
	var burst_pos: Vector2 = _cloud_burst_pos + shake_offset
	host.sync_state({
		"active": active,
		"direction": direction,
		"screen_center": player_center * render_scale,
		"burst_screen_pos": burst_pos * render_scale,
		"burst_serial": _cloud_burst_serial,
		"collision_consumed": collision_consumed,
		"current_msec": Time.get_ticks_msec(),
		"start_msec": start_msec,
		"render_scale": render_scale,
	}, true)
	return true


func _get_or_create_cloud_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_cloud_fx_host():
		if cloud_fx_host.is_inside_tree():
			cloud_fx_host_add_pending = false
		return cloud_fx_host
	cloud_fx_host = null
	cloud_fx_clip_host = null
	cloud_fx_host_add_pending = false
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing_clip: Node = parent.get_node_or_null(CLOUD_FX_CLIP_NAME)
	var existing: Node = existing_clip.get_node_or_null(CLOUD_FX_HOST_NAME) if existing_clip != null else null
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		cloud_fx_host = existing
		cloud_fx_clip_host = existing_clip as Control
		cloud_fx_host_add_pending = false
		return cloud_fx_host
	cloud_fx_clip_host = Control.new()
	cloud_fx_clip_host.name = CLOUD_FX_CLIP_NAME
	cloud_fx_clip_host.clip_contents = true
	cloud_fx_clip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_fx_clip_host.size = Vector2(FIELD_WIDTH, FIELD_HEIGHT)
	cloud_fx_clip_host.z_index = 11
	cloud_fx_host = SmasherWheelCloudFxHost.new()
	cloud_fx_host.name = CLOUD_FX_HOST_NAME
	cloud_fx_host.visible = false
	cloud_fx_clip_host.add_child(cloud_fx_host)
	if not cloud_fx_host_add_pending:
		cloud_fx_host_add_pending = true
		parent.call_deferred("add_child", cloud_fx_clip_host)
	return cloud_fx_host


func _hide_cloud_fx() -> void:
	if _is_valid_cloud_fx_host() and cloud_fx_host.has_method("set_active"):
		cloud_fx_host.set_active(false)
	if cloud_fx_clip_host != null and is_instance_valid(cloud_fx_clip_host):
		cloud_fx_clip_host.visible = false


func _is_valid_cloud_fx_host() -> bool:
	return cloud_fx_host != null and is_instance_valid(cloud_fx_host) and not cloud_fx_host.is_queued_for_deletion()


func _can_activate(
	current_msec: int,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary,
	allow_dash_recovery: bool = false
) -> bool:
	if active:
		return false
	if not bool(config.get("ball_active", false)):
		return false
	if _is_input_blocked(config, deps, allow_dash_recovery):
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	if special_gauge < _get_skill_cost(deps.get("skill_config", null)):
		return false
	if _get_cooldown_remaining(current_msec, deps) > 0.0:
		return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary, allow_dash_recovery: bool = false) -> bool:
	if bool(config.get("player_skill_input_locked", false)):
		return true
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
	var plasma_state: Object = deps.get("smasher_plasma_state", null)
	if plasma_state != null and plasma_state.has_method("is_charging") and bool(plasma_state.is_charging()):
		return true
	# 흡인장(magnum_grip)은 여기서 막지 않는다 — 흡인장은 "끌어온 공을 초식으로
	# 받아친다"는 콤보 시동기라, 흡인장이 발동을 막으면 A-W-D 커맨드가 버퍼에
	# 남았다가 흡인장 해제(= 공이 몸에 닿는 순간) 직후에야 소비돼 **공이 패들에
	# 맞고 난 뒤** 천선무가 뜬다. 원본 pingfighter.py 의 wheel_start_blocked 도
	# 같은 계약이었으나, 이건 파리티 유지 대상이 아니라 사용자 확정 설계 변경이다
	# (2026-08-08). 흡인장은 천선무가 공을 먹는 순간 consume_ball_hit 에서
	# 넘겨받는다 — 그때까지는 계속 끌어당겨 콤보 명중률을 지킨다.
	var shield_state: Object = deps.get("smasher_shield_kiting_state", null)
	if _has_live_shield_projectile(shield_state):
		return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		if dash_state.has_method("is_active") and bool(dash_state.is_active()):
			return true
		if not allow_dash_recovery and dash_state.has_method("is_recovering") and bool(dash_state.is_recovering()):
			return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return false


func _is_dash_recovering(deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	return (
		dash_state != null
		and dash_state.has_method("is_recovering")
		and bool(dash_state.is_recovering())
	)


func _release_dash_recovery_for_activation(deps: Dictionary) -> void:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("clear_recovery"):
		dash_state.clear_recovery()
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_dash_delay"):
		audio.stop_dash_delay()


func _has_live_shield_projectile(shield_state: Object) -> bool:
	if shield_state == null or not shield_state.has_method("get_snapshot"):
		return false
	var snapshot: Variant = shield_state.get_snapshot()
	if not (snapshot is Dictionary):
		return false
	var projectile: Variant = snapshot.get("projectile", {})
	return projectile is Dictionary and not projectile.is_empty() and bool(projectile.get("active", false))


func _update_command_buffer(input_snapshot: Dictionary, current_msec: int) -> void:
	var current_keys := {
		"a": bool(input_snapshot.get("left_pressed", false)),
		"w": bool(input_snapshot.get("up_pressed", false)),
		"d": bool(input_snapshot.get("right_pressed", false)),
	}
	for key in ["a", "w", "d"]:
		if bool(current_keys[key]) and not bool(previous_command_keys[key]):
			_push_command(key, current_msec)
		previous_command_keys[key] = bool(current_keys[key])
	_trim_expired_commands(current_msec)


func _consume_command_direction(current_msec: int) -> int:
	if _check_sequence(["a", "w", "d"], current_msec):
		return 1
	if _check_sequence(["d", "w", "a"], current_msec):
		return -1
	return 0


func _push_command(key: String, current_msec: int) -> void:
	command_buffer.append({
		"key": key,
		"msec": current_msec,
	})
	while command_buffer.size() > COMMAND_BUFFER_MAX:
		command_buffer.pop_front()


func _trim_expired_commands(current_msec: int) -> void:
	if command_buffer.is_empty():
		return
	var trimmed: Array[Dictionary] = []
	for item in command_buffer:
		if current_msec - int(item.get("msec", current_msec)) <= COMMAND_WINDOW_MSEC * 3:
			trimmed.append(item)
	command_buffer.clear()
	command_buffer.append_array(trimmed)


func _check_sequence(sequence: Array, current_msec: int) -> bool:
	if command_buffer.size() < 3:
		return false
	var start_index: int = command_buffer.size() - 3
	for i in range(3):
		if str(command_buffer[start_index + i].get("key", "")) != str(sequence[i]):
			return false
	var t1: int = int(command_buffer[start_index].get("msec", current_msec))
	var t2: int = int(command_buffer[start_index + 1].get("msec", current_msec))
	var t3: int = int(command_buffer[start_index + 2].get("msec", current_msec))
	if t2 - t1 > COMMAND_WINDOW_MSEC:
		return false
	if t3 - t2 > COMMAND_WINDOW_MSEC:
		return false
	if current_msec - t3 > COMMAND_WINDOW_MSEC:
		return false
	command_buffer.clear()
	return true


func _clear_previous_command_keys() -> void:
	previous_command_keys["a"] = false
	previous_command_keys["w"] = false
	previous_command_keys["d"] = false


func _is_reversing(player_speed: float, input_direction: float) -> bool:
	if abs(input_direction) <= 0.001 or abs(player_speed) <= 0.001:
		return false
	return sign(player_speed) != sign(input_direction)


func _get_active_launch_speed(config: Dictionary) -> float:
	return max(1.0, float(config.get("paddle_max_speed", 6.0))) * ACTIVE_SPEED_MULT


func _update_trail(context: Dictionary, deps: Dictionary) -> void:
	if trail_timer_frames <= 0:
		return
	var ball_pos: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var impact_effects: Object = deps.get("impact_effects", null)
	trail_timer_frames = max(0, trail_timer_frames - 1)
	if impact_effects == null or not impact_effects.has_method("spawn_drive_particles"):
		return
	if trail_timer_frames % 2 == 0:
		impact_effects.spawn_drive_particles(ball_pos, 2)
	impact_effects.spawn_drive_particles(ball_pos, 1)


func _register_hit_feedback(ball_pos: Vector2, next_vel: Vector2, deps: Dictionary) -> void:
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("register_hit"):
		ball_intensity.register_hit("player")
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(ball_pos, next_vel, 1.0, "smasher_wheel")
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null:
		if impact_effects.has_method("spawn_drive_particles"):
			impact_effects.spawn_drive_particles(ball_pos, HIT_CURVE_PARTICLE_COUNT)
		if impact_effects.has_method("spawn_paddle_hit_particles"):
			impact_effects.spawn_paddle_hit_particles(ball_pos, true, next_vel, 1.0)
		if impact_effects.has_method("create_energy_explosion"):
			impact_effects.create_energy_explosion(ball_pos, 0.72, 1.0)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.12, 9.0)
		elif feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.12, 9.0)


func _award_hit_gold(context: Dictionary, deps: Dictionary) -> int:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
		return int(_call_award_gold(runtime_perk_state, HIT_GOLD, context, deps))
	return HIT_GOLD


func _call_award_gold(runtime_perk_state: Object, amount: int, context: Dictionary, deps: Dictionary) -> int:
	if _method_accepts_arg_count(runtime_perk_state, "award_gold", 3):
		return int(runtime_perk_state.award_gold(amount, context, deps))
	return int(runtime_perk_state.award_gold(amount))


func _method_accepts_arg_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	for method in target.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size() >= arg_count
	return false


func _snap_ball_above_player(ball_pos: Vector2, context: Dictionary) -> Vector2:
	var next_pos := ball_pos
	next_pos.y = float(context.get("player_y", _last_player_pos.y)) - float(context.get("ball_size", 0.0)) - 2.0
	return next_pos


func _player_or_mirror_rect_hits_ball(player_rect: Rect2, ball_rect: Rect2, mirror_offset_x: float) -> bool:
	if player_rect.intersects(ball_rect):
		return true
	if abs(mirror_offset_x) <= 0.01:
		return false
	return Rect2(player_rect.position + Vector2(mirror_offset_x, 0.0), player_rect.size).intersects(ball_rect)


func _draw_timer_bar(canvas: CanvasItem, timer_stack: Object = null, current_msec: int = -1) -> void:
	var ratio: float = get_remaining_ratio(current_msec)
	if ratio <= 0.0:
		return
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	canvas.draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(0.035, 0.075, 0.15, 0.84))
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(0.58, 0.82, 1.0, 0.94))
	canvas.draw_rect(rect, Color(0.88, 0.95, 1.0, 0.90), false, 2.0)
	var font: Font = _get_timer_font()
	if font != null:
		canvas.draw_string(font, rect.position + Vector2(6.0, rect.size.y - 3.0), "천선무", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.92, 0.97, 1.0, 0.96))


func _get_timer_font() -> Font:
	if _timer_font == null:
		_timer_font = ThemeDB.fallback_font
	return _timer_font


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * 18.0
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_cooldown_remaining(current_msec: int, deps: Dictionary) -> float:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("get_configured_cooldown_remaining"):
		return 0.0
	return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null)))


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return float(costs.get(SKILL_NAME, GAUGE_COST))
	return GAUGE_COST


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var equipped: Variant = snapshot.get("equipped_skills", [])
			if equipped is Array:
				return equipped.has(SKILL_NAME)
	return false


func _play_cutin_voice(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_smasher_wheel_cutin_voice"):
		audio.play_smasher_wheel_cutin_voice()


func _play_full_skill_cutin_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_full_skill_cutin"):
		audio.play_full_skill_cutin()
	elif audio.has_method("play_power_smash"):
		audio.play_power_smash()


func _trigger_activation_feedback(deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		return
	if feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.06, 3.0)
	if feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _get_player_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", DEFAULT_PLAYER_SIZE.x))),
		max(1.0, float(config.get("paddle_height", DEFAULT_PLAYER_SIZE.y)))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
