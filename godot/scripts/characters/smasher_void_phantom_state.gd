extends RefCounted

# 허공환영(虛空幻影) — 한미량 초식.
#
# 접촉 발동(contact-launch) 계열: ↓/S + 좌클릭을 유지한 채 공을 받아친 그
# 순간, 실제 공과 같은 형태의 반투명 환영공 2개가 좌우로 같이 솟아오른다. 보스
# 예측기는 확률적으로 그중 하나를 진짜로 착각한다.
#
# 이 모듈은 구 액티브 아이템 "홀로그램 디스크"(active_item_hologram_disk_runtime)의
# 분신 시뮬레이션을 초식으로 이관한 것이다. 이관하며 바뀐 계약:
#   - 지속시간형 → 1회성. 타구 1회당 환영 1세트, 재상승 재스폰 없음(타이머 게이지도 없음).
#   - 화면상 구성은 실제 공 1 + 좌우 환영 2 = 총 3개로 고정.
#   - 아이템 사용 → 기력 320 / 쿨타임 70초의 5-오브 초식.
const SKILL_NAME := "void_phantom"
const DEFAULT_COST := 320.0

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BOSS_Y := 25.0
const DECEPTION_CHANCE := 0.65
# 환영이 갈라지는 각도(라디안). 24° ~ 35°.
# 실제 공이 보스 라인에 닿는 시점의 좌우 분리폭 ≈ 비행거리 × sin(θ) 이므로,
# 스테이지1 기준(비행 ~596px) 대략 242~342px 이 벌어진다 — 보스 패들(100px)
# 두세 칸. 좁으면 보스가 한 자리에서 둘 다 커버해 기만이 성립하지 않는다.
# ⚠️각도를 넓히면 환영의 |vel.y| 가 cos(θ) 만큼 줄어 보스 라인 도착이 늦어진다.
# 간파 시점을 환영 기준으로 재면 각도를 넓힐수록 리액션 여유가 사라지므로,
# 간파는 '실제 공'의 남은 프레임으로 잰다(_update_deception_reveal 참조).
const DECOY_ANGLE_MIN := 0.4188790205
const DECOY_ANGLE_MAX := 0.6108652382
const DECOY_KILL_Y := BOSS_Y + 40.0
# 벽 반사 여백은 충돌 반지름(BALL_SIZE/2)이 아니라 에너지볼 본체 반경 기준이다.
# ⚠️클립 보증은 아니다. 실제 EnergyBallRenderer의 토성링/궤도도 이 반경보다
# 넓고 플레이필드 즉시 드로우 패스에는 개별 FX 클립이 없다. 이 값은 환영 운동과
# 보스 예측이 공유하는 반사 경계이므로, 연출 외곽이 커졌다는 이유만으로 바꾸면
# 기만 궤적까지 달라진다. 발동/팝 연출은 렌더러의 짧은 LOD 레이어로 따로 제한한다.
const EnergyBallRendererScript := preload("res://scripts/ball/energy_ball_renderer.gd")
const VoidPhantomRendererScript := preload("res://scripts/characters/smasher_void_phantom_renderer.gd")
const DECOY_WALL_MARGIN := EnergyBallRendererScript.BALL_RENDER_RADIUS
const PHASE_ADVANCE_PER_FRAME := 0.11
const POP_LIFETIME_FRAMES := 12.0
# 발동 타구의 나가는 공속을 -40% 눌러 기만 비행을 길게 만든다. 보스 예측기가
# 잠긴 환영을 향해 자리를 잡을 시간을 벌어주는 것이 이 초식의 값이므로, 감속은
# 연출이 아니라 기만 성능 그 자체다. 창은 "보스가 가드할 때까지"이고, 원속은
# 보스 반사 지점(paddle_bounce_controller)에서 크기만 복원된다.
const LAUNCH_SPEED_SLOW_FACTOR := 0.6
const CHARGE_DURATION_FRAMES := 60.0
const CUTIN_FREEZE_DURATION := 1.65
const CHARGE_SPRITE_FRAME_COUNT := 16
const CHARGE_BALL_FORWARD_GAP_MULT := 1.75
# --- 보스 주의(attention) 모델 ---
# 보스가 한 공만 완벽히 주시하고 있으면 "속고 있다"가 아니라 "기다린다"로 읽힌다.
# 확정 목표(잠긴 환영 / 기만 실패 시 실제 공) 사이사이 다른 후보를 잠깐 쳐다봤다가
# 되돌아오게 해 "어느 걸 막지" 하고 얼타는 그림을 만든다.
# ⚠️곁눈질은 판정을 바꾸지 않는다 — 간파(reveal) 전에 항상 확정 목표로 복귀한다.
const ATTENTION_GLANCE_INTERVAL_FRAMES := 26.0
const ATTENTION_GLANCE_HOLD_FRAMES := 9.0
# 간파: '실제 공'이 보스 라인에 이만큼(60fps 프레임) 남았을 때 가짜임을 알아챈다.
# ⚠️기준이 실제 공인 이유 = 각도 독립성. 환영 기준으로 재면 DECOY_ANGLE 을 넓힐
# 때마다 환영이 느려져(cos θ) 리액션 여유가 조용히 줄어든다 — 35°에서는 실제 공이
# 도착하기 8프레임 전에야 간파가 걸려 대쉬가 사실상 안 보인다.
const DECEPTION_REVEAL_LEAD_FRAMES := 18.0
# 실제 공이 보스에게 잡히는 y. boss_ai_prediction_state._get_boss_intercept_y 의
# 기본값(BOSS_Y 25 + 히트박스 40 + 패딩 5 + 공 반지름 14.3)과 같은 라인이다.
const REAL_BALL_INTERCEPT_Y := 84.3
# 간파 직후 보스 AI가 반응 대쉬를 시도할 수 있는 창(프레임).
const REVEAL_DASH_WINDOW_FRAMES := 10.0
# 화면상 공 총 개수 3개 = 실제 공 1개 + 좌우 환영 2개.
const DECOY_COUNT := 2

var active := false
var charging := false
var phase := 0.0
var decoys: Array[Dictionary] = []
var pop_particles: Array[Dictionary] = []
var locked_decoy_index := -1
var roll_count := 0
# 발동 프레임 advance 가드. 발동은 step_motion(패들 반사) 안에서 일어나고,
# 같은 ball_update_controller 프레임이 그 '뒤'에서 환영 틱을 한 번 더 부른다.
# 그런데 실제 공은 이번 프레임에 접촉 지점에 머무르고(나가는 속도는 다음
# 프레임부터 적분된다) 환영만 그 자리에서 한 틱 나가면, 첫 렌더부터 환영이
# 실제 공보다 앞서 가는 눈에 보이는 텔이 된다. 구 아이템은 스폰이 advance
# '뒤'에 있어 구조적으로 이 문제가 없었다 — 포팅하며 순서가 뒤집혔으므로
# 발동 프레임 한 번만 advance 를 건너뛴다.
var _skip_advance_on_launch_frame := false
# 발동 시 눌러둔 원래 공속(px/frame). 0 이면 감속 창이 닫힌 것이다. 이 값이
# 살아 있는 동안에만 랠리 최저속 하한도 함께 중지된다(아래 주석 참조).
var _suppressed_launch_speed := 0.0
var _charge_elapsed_frames := 0.0
# 차징 라이저 SFX 1회 발사 래치. 컷인 동결 동안 볼-패스가 멈추므로 시전 프레임이
# 아니라 실제로 경과가 전진한 첫 차징 틱에서 재생한다(발동 시 재생하면 컷인에만
# 울리고 정작 차징 구간이 무음이 된다).
var _charge_audio_started := false
var _charge_ball_pos := Vector2.ZERO
var _pending_launch_velocity := Vector2.ZERO
# 보스가 지금 쳐다보는 대상. -1 = 실제 공, >=0 = decoys 인덱스.
var _attention_index := -1
# >0 이면 곁눈질 유지 중(끝나면 확정 목표로 복귀).
var _attention_hold_frames := 0.0
var _attention_next_glance_frames := ATTENTION_GLANCE_INTERVAL_FRAMES
# 이번 발동에서 이미 간파했는가(1회성).
var _deception_revealed := false
var _reveal_dash_window_frames := 0.0
# 발동 균열의 고정 앵커. 환영 현재 위치 평균으로 다시 계산하면 14프레임 동안
# 공을 따라 100px 이상 올라가 "타구 지점 균열"이 아니라 추적 오라가 된다.
var _launch_origin := Vector2.ZERO
var _has_launch_origin := false
static var _launch_serial_counter := 0
var _launch_serial := 0
# 테스트 전용 확률 고정 훅. 0 미만이면 DECEPTION_CHANCE 를 쓴다.
var deception_chance_override := -1.0
# 곁눈질 on/off 훅. false 면 확정 목표만 계속 주시한다(= 곁눈질 도입 이전 거동).
# '확정 추적' 계약 씰이 곁눈질 노이즈 없이 순수 거동만 보게 하는 용도이기도 하다.
var attention_glance_enabled := true


# ---------------------------------------------------------------------------
# 접촉 발동
# ---------------------------------------------------------------------------

# 소유권 주장의 **단일 술어**. 입력은 보지 않는다 — 호출자가 자기 입력
# 스냅샷으로 커맨드 성립 여부를 판단하고, "그래서 실제로 발동할 수 있는가"는
# 전부 여기로 모은다. 좌클릭 접촉(파워스매싱/벽력타)과 ↓ 홀드(건곤환문)가
# 서로 다른 경로에서 물어보므로, 술어가 갈라지면 한쪽만 계약을 어긴다.
# ⚠️상태를 바꾸지 않는다(peek 전용). 핫패스에서 접촉/프레임당 한 번 불린다.
func is_command_armable(
	current_msec: int,
	special_gauge: float,
	config: Dictionary,
	deps: Dictionary
) -> bool:
	# 이미 환영이 날고 있으면 재발동 불가 = 이 입력의 임자가 아니다.
	if active or charging:
		return false
	if _is_player_skill_input_locked(config, deps):
		return false
	return _can_activate(
		current_msec,
		special_gauge,
		bool(config.get("ball_active", true)),
		deps
	)


# 이번 프레임의 플레이어 패들 접촉이 허공환영 소유인지. 파워스매싱/벽력타가
# 같은 접촉을 가져가지 못하도록 라우터가 먼저 물어본다(버튼 소유권 감사).
func is_contact_claimed(context: Dictionary, deps: Dictionary) -> bool:
	if not _has_command_input(deps):
		return false
	return is_command_armable(
		int(context.get("current_msec", Time.get_ticks_msec())),
		float(context.get("special_gauge", 0.0)),
		context,
		deps
	)


# 플레이어 패들 접촉이 이번 프레임에 확정된 뒤 호출된다. `ball_vel` 은 이번
# 타구의 최종 나가는 속도(파워스매싱/드라이브/스핀이 모두 말을 끝낸 뒤)라서,
# 환영이 실제 공과 같은 속력·비슷한 각으로 갈라져 나갈 수 있다.
func try_launch_on_player_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	var result := {"launched": false}
	if active or charging:
		return result
	if ball_vel.length_squared() <= 0.0001:
		return result
	# 하강 타구(=진짜 상승이 아님)는 기만할 비행이 없다.
	if ball_vel.y >= 0.0:
		return result
	if not _has_command_input(deps):
		return result
	if _is_player_skill_input_locked(context, deps):
		return result
	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var special_gauge: float = float(context.get("special_gauge", 0.0))
	if not _can_activate(current_msec, special_gauge, bool(context.get("ball_active", true)), deps):
		return result

	active = false
	charging = true
	phase = 0.0
	_skip_advance_on_launch_frame = false
	# 환영은 눌린 뒤의 속도를 복제해야 한다 — 실제 공만 느려지면 환영이 앞서
	# 나가면서 "어느 쪽이 진짜인가"가 첫 프레임부터 들통난다.
	var launch_vel: Vector2 = ball_vel * LAUNCH_SPEED_SLOW_FACTOR
	_suppressed_launch_speed = ball_vel.length()
	_pending_launch_velocity = launch_vel
	_charge_elapsed_frames = 0.0
	_charge_audio_started = false
	_charge_ball_pos = _resolve_charge_ball_pos(
		context,
		_get_vector2(context, "ball_pos", Vector2.ZERO)
	)
	decoys.clear()
	_clear_deception_lock()
	_launch_origin = Vector2.ZERO
	_has_launch_origin = false
	_begin_full_cutin(context, deps)
	_trigger_cooldown(current_msec, deps)
	_play_cast_audio(deps)
	result["launched"] = true
	result["ball_pos"] = _charge_ball_pos
	result["ball_vel"] = Vector2.ZERO
	result["skip_ball_motion_step"] = true
	result["special_gauge"] = max(0.0, special_gauge - _get_skill_cost(deps.get("skill_config", null)))
	return result


# 1초간 공을 한미량 앞에 소유·고정한다. 볼 모션 skip 게이트보다 먼저 실행돼
# 패들을 따라가고, 해제 프레임에는 stale skip을 직접 내려 정상 swept step으로
# 진입한다. 따라서 차지 중에는 다른 공 조작이 끼어들 수 없다.
func apply_charge_ball_motion(fps_scale: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not charging:
		return {}
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		# 차징이 중단되면 라이저도 같이 끊는다 — 서브 대기 화면 위로 남은
		# 기 모으기 소리가 이어지면 안 된다.
		_stop_charge_audio(deps)
		reset()
		return {"skip_ball_motion_step": false}
	_charge_ball_pos = _resolve_charge_ball_pos(context, _charge_ball_pos)
	_charge_elapsed_frames = minf(
		CHARGE_DURATION_FRAMES,
		_charge_elapsed_frames + maxf(0.0, fps_scale)
	)
	# 시간 정지(스마트폰류) 틱은 fps_scale 0 으로 들어와 경과가 전진하지 않는다 —
	# 경과가 실제로 0 을 넘은 틱에서만 라이저를 1회 발사한다.
	if not _charge_audio_started and _charge_elapsed_frames > 0.0:
		_charge_audio_started = true
		_play_charge_audio(deps)
	if _charge_elapsed_frames < CHARGE_DURATION_FRAMES:
		return {
			"ball_pos": _charge_ball_pos,
			"ball_vel": Vector2.ZERO,
			"skip_ball_motion_step": true,
			"player_collision_cooldown": maxf(
				6.0, float(context.get("player_collision_cooldown", 0.0))
			),
		}

	charging = false
	active = true
	phase = 0.0
	_skip_advance_on_launch_frame = true
	var release_velocity: Vector2 = _pending_launch_velocity
	_pending_launch_velocity = Vector2.ZERO
	_spawn_decoys(_charge_ball_pos, release_velocity)
	_play_launch_audio(deps)
	_roll_deception_once()
	_attention_index = locked_decoy_index
	_attention_hold_frames = 0.0
	_attention_next_glance_frames = ATTENTION_GLANCE_INTERVAL_FRAMES
	_deception_revealed = false
	_reveal_dash_window_frames = 0.0
	return {
		"ball_pos": _charge_ball_pos,
		"ball_vel": release_velocity,
		"skip_ball_motion_step": false,
		"player_collision_cooldown": 6.0,
	}


# ---------------------------------------------------------------------------
# 프레임 갱신
# ---------------------------------------------------------------------------

# 공 경로 틱. ball_update_controller 가 step_motion(패들 반사) '뒤'에서 부르므로,
# 발사된 그 프레임의 환영이 다음 물리 프레임의 보스 AI(공 업데이트보다 먼저
# 돈다)에 바로 보인다.
func apply_ball_path_tick(fps_scale: float, context: Dictionary, deps: Dictionary = {}) -> void:
	if not active:
		return
	if bool(context.get("waiting_for_serve", false)):
		clear_decoys_and_lock()
		active = false
		return
	# 공 소유형 스킬이 공을 붙들고 있는 프레임엔 환영도 같이 멈춘다.
	if bool(context.get("skip_ball_motion_step", false)):
		return
	var safe_scale: float = max(0.0, fps_scale)
	phase += safe_scale * PHASE_ADVANCE_PER_FRAME
	if _skip_advance_on_launch_frame:
		# 발동 프레임: 실제 공은 접촉 지점에 머문다. 환영도 같이 머물러야
		# 다음 프레임부터 나란히 출발한다(_skip_advance_on_launch_frame 주석 참조).
		_skip_advance_on_launch_frame = false
	else:
		_advance_decoys(safe_scale, deps)
	_update_deception_reveal(context)
	_update_attention(safe_scale)
	if _reveal_dash_window_frames > 0.0:
		_reveal_dash_window_frames = max(0.0, _reveal_dash_window_frames - safe_scale)
	# 실제 공이 하강 전환하면 기만 창은 닫힌다(보스가 이미 판단을 끝냈다).
	if _get_vector2(context, "ball_vel", Vector2.ZERO).y >= 0.0:
		_clear_deception_lock()
		# 보스 가드 반사는 step_motion(이 틱보다 앞) 에서 이미 원속을 소비하므로
		# 여기서는 no-op 이다. 살아 있다면 가드 없이 하강 전환한 경우(디플렉트 등)
		# 이므로 창을 닫는다 — 안 닫으면 한참 뒤의 무관한 보스 반사가 이 원속으로
		# 부풀려진다(스테일 복원).
		_suppressed_launch_speed = 0.0
	if not _has_live_decoy():
		active = false
		locked_decoy_index = -1


# 팝 파티클은 스킬이 끝난 뒤에도 남은 수명만큼 재생돼야 하므로 이펙트 경로에서
# 따로 돌린다(공 경로는 active 게이트에 걸려 멈춘다).
func update_effects(fps_scale: float) -> void:
	_update_pop_particles(max(0.0, fps_scale))


func needs_effect_update() -> bool:
	return not pop_particles.is_empty()


# ---------------------------------------------------------------------------
# 소비자 인터페이스
# ---------------------------------------------------------------------------

func is_active() -> bool:
	return active or charging


func is_charging() -> bool:
	return charging


func is_player_control_locked() -> bool:
	# 허공환영의 60프레임 기 모으기는 캐릭터 연기만 바꾸는 포즈가 아니다.
	# 공을 붙들고 있는 같은 상태 시계를 플레이어 컨트롤러도 읽어 이동·대시·
	# 다른 초식 입력을 함께 잠근다. 발사 프레임에 charging이 먼저 내려가므로
	# 다음 플레이어 업데이트부터 즉시 정상 조작으로 복귀한다.
	return charging


func prewarm_assets() -> void:
	# The selected-character boot prewarm already visits this state. Keep the
	# three modular textures and shared writhe shader out of the first cast frame.
	VoidPhantomRendererScript.prewarm_assets()


func has_visible_effects() -> bool:
	return charging or active or _has_live_decoy() or not pop_particles.is_empty()


func get_actor_draw_context() -> Dictionary:
	if not charging:
		return {"player_void_phantom_charge_active": false}
	var ratio: float = clampf(
		_charge_elapsed_frames / maxf(1.0, CHARGE_DURATION_FRAMES),
		0.0,
		1.0
	)
	return {
		"player_void_phantom_charge_active": true,
		"player_void_phantom_charge_ratio": ratio,
		"player_void_phantom_charge_frame": mini(
			CHARGE_SPRITE_FRAME_COUNT - 1,
			int(floor(ratio * float(CHARGE_SPRITE_FRAME_COUNT)))
		),
	}


# 보스 AI 가 이번 프레임에 어떤 공을 쫓을지. 잠긴 환영이 있으면 그 좌표/속도를
# 실제 공 대신 돌려준다.
# ⚠️돌려주는 것은 '잠긴 환영'이 아니라 '보스가 지금 쳐다보는 공'이다. 곁눈질 중에는
# 다른 환영이나 실제 공(-1 → active:false)이 나온다 — 얼타는 연출의 단일 소스.
# 판정을 결정하는 확정 목표는 여전히 locked_decoy_index 이고, 곁눈질은 간파 전에
# 반드시 거기로 복귀한다(_update_attention).
func peek_deception_ball_context() -> Dictionary:
	if not active or _attention_index < 0 or _attention_index >= decoys.size():
		return {"active": false}
	var decoy: Dictionary = decoys[_attention_index]
	if not bool(decoy.get("alive", false)):
		return {"active": false}
	return {
		"active": true,
		"ball_pos": _get_vector2(decoy, "pos", Vector2.ZERO),
		"ball_vel": _get_vector2(decoy, "vel", Vector2.ZERO),
		"decoy_index": _attention_index,
	}


# 간파 직후 반응 대쉬 창이 열려 있는가. ⚠️peek 전용(보스 AI 컨텍스트 빌더가
# 매 프레임 조회한다). 소비는 보스 AI 쪽 에지 래치가 담당한다.
func peek_reveal_dash_window_active() -> bool:
	return active and _reveal_dash_window_frames > 0.0


# 감속 창이 열려 있으면 발동 직전의 원래 공속(px/frame), 아니면 0.
# ⚠️peek 전용 — 매 볼 프레임(ball_frame_motion_controller 하한 게이트)에서
# 불리므로 상태를 바꾸지 않는다.
func peek_suppressed_launch_speed() -> float:
	return _suppressed_launch_speed


# 보스 가드 반사가 원속을 되찾아 갈 때 1회 소비한다. 소비 뒤에는 창이 닫혀
# 랠리 최저속 하한도 즉시 원래대로 돌아온다.
func consume_suppressed_launch_speed() -> float:
	var original_speed: float = _suppressed_launch_speed
	_suppressed_launch_speed = 0.0
	return original_speed


func build_draw_context() -> Dictionary:
	if not has_visible_effects():
		return {}
	# draw 용 환영 배열은 alive 만 남겨 압축되므로, 저장된 locked 인덱스를 그대로
	# 넘기면 [dead0, locked1] 케이스에서 잠금 강조가 엉뚱한 환영에 붙는다 —
	# 압축 후 인덱스로 재매핑해서 넘긴다.
	var draw_decoys: Array[Dictionary] = []
	var remapped_locked_index := -1
	for index in range(decoys.size()):
		var decoy: Dictionary = decoys[index]
		if bool(decoy.get("alive", false)):
			if index == locked_decoy_index:
				remapped_locked_index = draw_decoys.size()
			draw_decoys.append(decoy.duplicate(true))
	var draw_pops: Array[Dictionary] = []
	for particle in pop_particles:
		draw_pops.append(particle.duplicate(true))
	if not charging and draw_decoys.is_empty() and draw_pops.is_empty():
		return {}
	return {
		"active": active,
		"charging": charging,
		"charge_ratio": clampf(
			_charge_elapsed_frames / maxf(1.0, CHARGE_DURATION_FRAMES),
			0.0,
			1.0
		),
		"charge_ball_pos": _charge_ball_pos,
		"phase": phase,
		"decoys": draw_decoys,
		"pop_particles": draw_pops,
		"locked_decoy_index": remapped_locked_index,
		"launch_origin": _launch_origin if _has_launch_origin else Vector2.ZERO,
		"has_launch_origin": _has_launch_origin,
		"launch_serial": _launch_serial,
		# 간파 직후 10프레임 동안 환영의 시안/자홍 채널이 갈라지는 시각 에지.
		# 상태 판정은 이미 끝났고, 렌더러는 이 읽기 전용 비율만 소비한다.
		"reveal_flash_ratio": clampf(
			_reveal_dash_window_frames / maxf(1.0, REVEAL_DASH_WINDOW_FRAMES),
			0.0,
			1.0
		),
	}


func get_snapshot() -> Dictionary:
	return {
		"void_phantom_active": is_active(),
		"void_phantom_charging": charging,
		"void_phantom_charge_elapsed_frames": _charge_elapsed_frames,
		"void_phantom_charge_ball_pos": _charge_ball_pos,
		"void_phantom_decoy_count": _count_live_decoys(),
		"void_phantom_locked_decoy_index": locked_decoy_index,
		"void_phantom_roll_count": roll_count,
		"void_phantom_suppressed_launch_speed": _suppressed_launch_speed,
		"void_phantom_attention_index": _attention_index,
		"void_phantom_deception_revealed": _deception_revealed,
	}


# ---------------------------------------------------------------------------
# 정리
# ---------------------------------------------------------------------------

func reset_round() -> void:
	reset()


func reset() -> void:
	active = false
	charging = false
	phase = 0.0
	decoys.clear()
	pop_particles.clear()
	locked_decoy_index = -1
	_skip_advance_on_launch_frame = false
	_suppressed_launch_speed = 0.0
	_charge_elapsed_frames = 0.0
	_charge_audio_started = false
	_charge_ball_pos = Vector2.ZERO
	_pending_launch_velocity = Vector2.ZERO
	_attention_index = -1
	_attention_hold_frames = 0.0
	_attention_next_glance_frames = ATTENTION_GLANCE_INTERVAL_FRAMES
	_deception_revealed = false
	_reveal_dash_window_frames = 0.0
	_launch_origin = Vector2.ZERO
	_has_launch_origin = false


# 라운드 리셋 없이 공만 재실체화하는 경로(바이퍼 연습모드 재시도)용 공개 정리.
func clear_decoys_and_lock() -> void:
	active = false
	charging = false
	decoys.clear()
	pop_particles.clear()
	_clear_deception_lock()
	# 공이 새로 실체화되므로 이 원속은 더 이상 이번 공의 것이 아니다.
	_suppressed_launch_speed = 0.0
	_charge_elapsed_frames = 0.0
	_charge_audio_started = false
	_charge_ball_pos = Vector2.ZERO
	_pending_launch_velocity = Vector2.ZERO
	_attention_index = -1
	_attention_hold_frames = 0.0
	_reveal_dash_window_frames = 0.0
	_launch_origin = Vector2.ZERO
	_has_launch_origin = false


# ---------------------------------------------------------------------------
# 내부
# ---------------------------------------------------------------------------

func _resolve_charge_ball_pos(context: Dictionary, fallback: Vector2) -> Vector2:
	if not context.has("player_pos") or not context.has("player_paddle_size"):
		return fallback
	var player_pos: Vector2 = _get_vector2(context, "player_pos", fallback)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2.ZERO)
	if player_size.x <= 0.0:
		return fallback
	var ball_size: float = maxf(1.0, float(context.get("ball_size", 28.6)))
	return Vector2(
		clampf(
			player_pos.x + player_size.x * 0.5,
			DECOY_WALL_MARGIN,
			FIELD_WIDTH - DECOY_WALL_MARGIN
		),
		player_pos.y - ball_size * CHARGE_BALL_FORWARD_GAP_MULT
	)

func _spawn_decoys(real_ball_pos: Vector2, real_ball_vel: Vector2) -> void:
	decoys.clear()
	locked_decoy_index = -1
	_launch_origin = Vector2.ZERO
	_has_launch_origin = false
	var speed: float = real_ball_vel.length()
	if speed < 0.01:
		return
	# 벽 근처 패들 히트의 최초 스폰 프레임도 시각 여백을 지켜야 한다 —
	# 클램프를 다음 advance 틱에만 맡기면 첫 렌더 프레임이 경계를 벗어난다.
	var spawn_pos := Vector2(
		clampf(real_ball_pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN),
		real_ball_pos.y
	)
	_launch_origin = spawn_pos
	_has_launch_origin = true
	_launch_serial_counter += 1
	_launch_serial = _launch_serial_counter
	for side in _roll_decoy_sides():
		var angle: float = randf_range(DECOY_ANGLE_MIN, DECOY_ANGLE_MAX) * side
		var decoy_vel: Vector2 = real_ball_vel.rotated(angle)
		if decoy_vel.y >= -0.01:
			decoy_vel = Vector2(decoy_vel.x, -max(1.0, abs(decoy_vel.y))).normalized() * speed
		decoys.append({
			"pos": spawn_pos,
			"vel": decoy_vel,
			"alive": true,
			"flicker_seed": randf() * TAU,
			"age_frames": 0.0,
			"render_slot": decoys.size(),
		})


# 환영은 항상 2개이며 수직 타구 기준 좌우 한 개씩 갈라진다. 각 환영의 세부
# 분리각은 별도로 굴려 매 발동 궤적은 달라지되, 화면상 총 3공 구성은 고정한다.
func _roll_decoy_sides() -> Array[float]:
	# ⚠️타입 배열 반환은 리터럴/삼항으로 만들면 런타임에 타입 불일치로 죽고
	# 빈 배열이 반환된다(환영 0개 = 초식이 조용히 사라짐). 선언된 배열에 append 한다.
	var sides: Array[float] = []
	for index in range(DECOY_COUNT):
		sides.append(-1.0 if index == 0 else 1.0)
	return sides


func _roll_deception_once() -> void:
	roll_count += 1
	var alive_indices: Array[int] = []
	for index in range(decoys.size()):
		if bool(decoys[index].get("alive", false)):
			alive_indices.append(index)
	if alive_indices.is_empty():
		locked_decoy_index = -1
		return
	if randf() <= _get_deception_chance():
		locked_decoy_index = int(alive_indices[randi() % alive_indices.size()])
	else:
		locked_decoy_index = -1


func _advance_decoys(fps_scale: float, deps: Dictionary) -> void:
	if decoys.is_empty():
		return
	for index in range(decoys.size()):
		var decoy: Dictionary = decoys[index]
		if not bool(decoy.get("alive", false)):
			continue
		var vel: Vector2 = _get_vector2(decoy, "vel", Vector2.ZERO)
		var pos: Vector2 = _get_vector2(decoy, "pos", Vector2.ZERO) + vel * fps_scale
		# 실 공 ball_pos 는 '중심' 좌표 규약(충돌 rect 가 -half 확장) — 환영도
		# 스폰 시 실 공 중심을 그대로 받으므로 벽 반사도 중심 기준. 여백은
		# 에너지볼 본체 반경(DECOY_WALL_MARGIN). 반사는 경계 '스냅'이 아니라 초과분을 되접는
		# '미러' — 보스 AI 예측(_advance_x_with_walls)과 같은 반사 기하를
		# 써야 벽 반사 후 예측 도착 x 가 환영 실궤적과 일치한다.
		if pos.x < DECOY_WALL_MARGIN:
			pos.x = clampf(DECOY_WALL_MARGIN * 2.0 - pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN)
			vel.x = abs(vel.x)
		elif pos.x > FIELD_WIDTH - DECOY_WALL_MARGIN:
			pos.x = clampf((FIELD_WIDTH - DECOY_WALL_MARGIN) * 2.0 - pos.x, DECOY_WALL_MARGIN, FIELD_WIDTH - DECOY_WALL_MARGIN)
			vel.x = -abs(vel.x)
		decoy["pos"] = pos
		decoy["vel"] = vel
		decoy["age_frames"] = float(decoy.get("age_frames", 0.0)) + fps_scale
		if pos.y <= DECOY_KILL_Y:
			decoy["alive"] = false
			_spawn_pop_particle(pos, float(decoy.get("flicker_seed", 0.0)))
			_play_pop_audio(deps)
			if index == locked_decoy_index:
				locked_decoy_index = -1
		decoys[index] = decoy


# 잠긴 환영이 보스 라인에 충분히 가까워지면 "가짜였다"를 알아챈다. 이후 락을 풀어
# 보스가 실제 공을 쫓게 하고, 반응 대쉬 창을 연다.
# ⚠️남은 프레임은 경과 타이머가 아니라 remaining_y/|vel.y| (60fps 명목 프레임)로
# 잰다 — fps_scale 을 곱하면 리프레시레이트마다 간파 시점이 달라진다.
func _update_deception_reveal(context: Dictionary) -> void:
	if _deception_revealed or locked_decoy_index < 0 or locked_decoy_index >= decoys.size():
		return
	if not bool(decoys[locked_decoy_index].get("alive", false)):
		return
	if _get_real_ball_frames_to_intercept(context) > DECEPTION_REVEAL_LEAD_FRAMES:
		return
	_deception_revealed = true
	_clear_deception_lock()
	_attention_index = -1
	_attention_hold_frames = 0.0
	_reveal_dash_window_frames = REVEAL_DASH_WINDOW_FRAMES


# 실제 공이 보스 라인까지 남긴 프레임(60fps 명목). 상승 중이 아니거나 좌표를
# 못 읽으면 INF 를 돌려 간파가 걸리지 않게 한다(fail-closed).
# ⚠️fps_scale 을 곱하지 않는다 — 리프레시레이트마다 간파 시점이 달라진다.
func _get_real_ball_frames_to_intercept(context: Dictionary) -> float:
	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	if ball_vel.y >= -0.001:
		return INF
	if not context.has("ball_pos"):
		return INF
	var remaining_y: float = _get_vector2(context, "ball_pos", Vector2.ZERO).y - REAL_BALL_INTERCEPT_Y
	if remaining_y <= 0.0:
		return 0.0
	return remaining_y / abs(ball_vel.y)


# 곁눈질 스케줄. 간파 이후에는 흔들리지 않는다(이미 진짜를 알고 있다).
func _update_attention(fps_scale: float) -> void:
	if _deception_revealed:
		_attention_index = -1
		return
	if not attention_glance_enabled:
		_attention_index = locked_decoy_index
		return
	if _attention_hold_frames > 0.0:
		_attention_hold_frames -= fps_scale
		if _attention_hold_frames <= 0.0:
			# 확정 목표로 복귀 — 곁눈질이 판정을 바꾸지 않게 하는 지점.
			_attention_index = locked_decoy_index
		return
	_attention_next_glance_frames -= fps_scale
	if _attention_next_glance_frames > 0.0:
		return
	_attention_next_glance_frames = ATTENTION_GLANCE_INTERVAL_FRAMES
	var candidates: Array[int] = _build_glance_candidates()
	if candidates.is_empty():
		return
	_attention_index = candidates[randi() % candidates.size()]
	_attention_hold_frames = ATTENTION_GLANCE_HOLD_FRAMES


# 곁눈질 후보 = 살아있는 환영 + 실제 공(-1), 단 확정 목표 자신은 제외.
func _build_glance_candidates() -> Array[int]:
	var candidates: Array[int] = []
	for index in range(decoys.size()):
		if index == locked_decoy_index:
			continue
		if bool(decoys[index].get("alive", false)):
			candidates.append(index)
	if locked_decoy_index >= 0:
		candidates.append(-1)
	return candidates


func _spawn_pop_particle(pos: Vector2, flicker_seed: float) -> void:
	pop_particles.append({
		"pos": pos,
		"age_frames": 0.0,
		"lifetime_frames": POP_LIFETIME_FRAMES,
		"flicker_seed": flicker_seed,
	})


func _update_pop_particles(fps_scale: float) -> void:
	for index in range(pop_particles.size() - 1, -1, -1):
		var particle: Dictionary = pop_particles[index]
		particle["age_frames"] = float(particle.get("age_frames", 0.0)) + fps_scale
		if float(particle.get("age_frames", 0.0)) >= float(particle.get("lifetime_frames", POP_LIFETIME_FRAMES)):
			pop_particles.remove_at(index)
		else:
			pop_particles[index] = particle


func _has_live_decoy() -> bool:
	for decoy in decoys:
		if bool(decoy.get("alive", false)):
			return true
	return false


func _count_live_decoys() -> int:
	var total := 0
	for decoy in decoys:
		if bool(decoy.get("alive", false)):
			total += 1
	return total


func _clear_deception_lock() -> void:
	locked_decoy_index = -1


func _get_deception_chance() -> float:
	if deception_chance_override >= 0.0:
		return clamp(deception_chance_override, 0.0, 1.0)
	return DECEPTION_CHANCE


# ↓/S + 좌클릭 동시 홀드. 벽력타/천뢰격과 같은 LEVEL 읽기(에지 아님)라서
# "공이 오는 동안 눌러 두면 된다"가 성립한다.
func _has_command_input(deps: Dictionary) -> bool:
	var input_reader: Object = deps.get("input_reader", null)
	if input_reader == null or not input_reader.has_method("get_snapshot"):
		return false
	var snapshot: Variant = input_reader.get_snapshot()
	if not (snapshot is Dictionary):
		return false
	var input_snapshot: Dictionary = snapshot
	return (
		bool(input_snapshot.get("down_pressed", false))
		and bool(input_snapshot.get("action_pressed", false))
	)


func _can_activate(current_msec: int, special_gauge: float, ball_active: bool, deps: Dictionary) -> bool:
	if not ball_active:
		return false
	if _has_conflicting_ball_control(deps):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if not _is_skill_equipped(skill_config):
		return false
	if special_gauge < _get_skill_cost(skill_config):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		return float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, skill_config)) <= 0.0
	return true


func _is_skill_equipped(skill_config: Object) -> bool:
	return (
		skill_config != null
		and skill_config.has_method("is_skill_equipped")
		and bool(skill_config.is_skill_equipped(SKILL_NAME))
	)


# 환영은 실제 공의 궤적을 복제해 갈라져 나간다. 공을 직접 소유·재배치하는
# 초식이 동시에 돌면 복제 원본이 사라져 환영만 남는다.
func _has_conflicting_ball_control(deps: Dictionary) -> bool:
	for key in ["smasher_magnum_grip_state", "smasher_wheel_state", "smasher_overdrive_state"]:
		var state: Object = deps.get(key, null)
		if state != null and state.has_method("is_active") and bool(state.is_active()):
			return true
	var power_state: Object = deps.get("power_state", null)
	if power_state == null:
		return false
	for method_name in ["is_parabola_active", "is_freeze_active"]:
		if power_state.has_method(method_name) and bool(power_state.call(method_name)):
			return true
	return false


# paddle_bounce_skill_router._is_player_skill_input_locked 미러: 공 경로는 raw
# 입력 리더를 들고 있어서(스킬락/저주 프록시가 아님) 변신/스턴 락을 여기서
# 다시 검사해야 한다.
func _is_player_skill_input_locked(context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_skill_input_locked", false)) or bool(deps.get("player_skill_input_locked", false)):
		return true
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null:
		if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
			return true
		if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
			return true
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null:
		return false
	for method_name in [
		"is_horn_strawberry_skills_locked",
		"is_horn_strawberry_control_locked",
		"is_odins_eye_skills_locked",
		"is_odins_eye_control_locked",
	]:
		if mythic_item_runtime.has_method(method_name) and bool(mythic_item_runtime.call(method_name)):
			return true
	return false


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("trigger_configured_cooldown"):
		skill_state.trigger_configured_cooldown(SKILL_NAME, current_msec, deps.get("skill_config", null))


func _begin_full_cutin(context: Dictionary, deps: Dictionary) -> void:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null or not power_state.has_method("begin_cinematic_freeze"):
		return
	var duration: float = float(
		context.get("power_smash_freeze_duration", CUTIN_FREEZE_DURATION)
	)
	if duration <= 0.0:
		duration = CUTIN_FREEZE_DURATION
	power_state.begin_cinematic_freeze(duration, SKILL_NAME)
	_play_full_skill_cutin_sound(deps)


func _get_skill_cost(skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_skill_cost"):
		return float(skill_config.get_skill_cost(SKILL_NAME))
	return DEFAULT_COST


func _play_cast_audio(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio != null and audio.has_method("play_void_phantom_cast"):
		audio.play_void_phantom_cast()


func _play_full_skill_cutin_sound(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio == null:
		return
	if audio.has_method("play_full_skill_cutin"):
		audio.play_full_skill_cutin()
	elif audio.has_method("play_power_smash"):
		audio.play_power_smash()


func _play_charge_audio(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio != null and audio.has_method("play_void_phantom_charge"):
		audio.play_void_phantom_charge()


# 발사 완료는 라이저 테일(~0.6s)을 자연 소산시키고, 중단(서브 대기/공 비활성)
# 에서만 부른다.
func _stop_charge_audio(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio != null and audio.has_method("stop_void_phantom_charge"):
		audio.stop_void_phantom_charge()


func _play_launch_audio(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio != null and audio.has_method("play_void_phantom_launch"):
		audio.play_void_phantom_launch()


func _play_pop_audio(deps: Dictionary) -> void:
	var audio: Object = _resolve_audio(deps)
	if audio == null:
		return
	if audio.has_method("play_void_phantom_pop"):
		audio.play_void_phantom_pop()
	elif audio.has_method("play_stage1_balloon_pop"):
		audio.play_stage1_balloon_pop()


func _resolve_audio(deps: Dictionary) -> Object:
	# 볼 경로 frame_deps 는 오디오를 "audio" 키로 싣는다(ball_dependency_context).
	var audio: Object = deps.get("audio", null)
	if audio == null:
		audio = deps.get("game_audio", null)
	return audio


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback
