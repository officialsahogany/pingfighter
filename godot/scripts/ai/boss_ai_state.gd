extends RefCounted

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")
const BossAiTurnInertiaResolver := preload("res://scripts/ai/boss_ai_turn_inertia_resolver.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const WHIP_DEACTIVATION_FAST_SPEED: float = 8.8
const WHIP_DEACTIVATION_SLOW_SPEED: float = 1.8
const WHIP_DEACTIVATION_ACCEL: float = 4.5
const WHIP_DEACTIVATION_BRAKE_DISTANCE: float = 72.0
const WHIP_DEACTIVATION_DEADZONE: float = 5.0
const CONFUSION_CHANGE_FRAMES: float = 30.0
const CONFUSION_RANDOM_TURN_CHANCE: float = 0.20
const SERVE_FEINT_PROFILES := [
	"hold_snap",
	"side_step",
	"bait_reverse",
	"double_bluff",
	"stare_down",
	"shuffle",
]
const POWER_SMASH_BOSS_REACT_PER_COMBO := 0.035
const POWER_SMASH_BOSS_REACT_CAP := 0.20
const PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME := 0.85
const PADDLE_HIT_KNOCKBACK_WALL_BOUNCE_KEEP_RATIO := 0.70
const BOSS_DASH_STAGE1_MAX_TOKENS := 1
const BOSS_DASH_STAGE1_MAX_DISTANCE := 316.8
const BOSS_DASH_STAGE1_TRIGGER_CHANCE := 0.30
const BOSS_DASH_STAGE1_COOLDOWN_SECONDS := Vector2(40.0, 55.0)
const BOSS_DASH_STAGE1_STUN_SECONDS := 0.60
const BOSS_DASH_SPEED := 40.0
const BOSS_DASH_AVERAGE_SPEED := 30.0
const BOSS_DASH_MIN_DURATION_FRAMES := 10.0
const BOSS_DASH_MAX_DURATION_FRAMES := 40.0
const BOSS_DASH_FULL_SPEED_FRAMES := 20.0
const BOSS_DASH_CLOSE_VERTICAL_GAP := 100.0
const BOSS_DASH_MAX_FRAMES_TO_CONTACT := 18.0
const BOSS_DASH_AI_COVER_MULTIPLIER := 1.5
const BOSS_DASH_REQUIRED_WIDTH_RATIO := 0.8
const BOSS_DASH_MIN_DISTANCE := 20.0
const BOSS_DASH_DEFAULT_MAX_SPEED := 6.3175
# Molotov fire barrier vertical gate — mirrors the molotov's own contact test
# (`abs(boss_center.y - center.y) < 60`, boss_center.y = boss_pos.y + 20) so a
# fire zone only blocks the boss's x while they share a y-band, never as a
# full-height wall. Keep in lockstep with active_item_throw_molotov.update_fire_zones.
const MOLOTOV_FIRE_BARRIER_Y_BAND := 60.0
const MOLOTOV_FIRE_BARRIER_BOSS_HALF_HEIGHT := 20.0
# Keep the blocked boss strictly on its approach side of the midline (never
# exactly on it) so the block direction persists frame to frame.
const MOLOTOV_FIRE_BARRIER_SIDE_EPSILON := 0.5

var prediction_state: Object = BossAiPredictionState.new()
var turn_inertia_resolver: Object = BossAiTurnInertiaResolver.new()
var confusion_target_x: float = -1.0
var confusion_direction_timer: float = 0.0
var paddle_hit_knockback_vel: float = 0.0
var paddle_hit_knockback_timer: float = 0.0
var paddle_hit_knockback_decay_per_frame: float = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME
var serve_feint_active := false
var serve_feint_profile := "hold_snap"
var serve_feint_target_x := -1.0
var serve_feint_decoy_x := -1.0
var serve_feint_second_decoy_x := -1.0
var serve_feint_release_x := -1.0
var serve_feint_hold_progress := 0.0
var serve_feint_cut_progress := 0.0
var serve_feint_release_progress := 0.0
var serve_feint_start_msec := 0
var serve_feint_phase := 0.0
var serve_feint_anchor_x := -1.0
var boss_dash_tokens := BOSS_DASH_STAGE1_MAX_TOKENS
var boss_dash_max_tokens := BOSS_DASH_STAGE1_MAX_TOKENS
var boss_dash_charge_timer_frames := 0.0
var boss_dash_recharge_frames := 1.0
var boss_dash_active := false
# stage7 극정호신 소유 대쉬의 좀비 판정용 1-AI페이즈 미러: 극정호신 플래그가
# 꺼진 프레임에 아직 살아 있는 소유 대쉬를 취소하고 같은 update에서 오딘
# 스턴을 낙하 적용한다(취소→다음 프레임 grace 중복이 61회 적용을 만들던
# 함정). 이 미러는 dash 분기 진입 시에만 갱신되는 스테일 값이므로 아이템측
# 게이트 소스로 쓰면 안 된다(runtime은 stage7 state를 직접 peek).
var _stage7_superspeed_was_active := false
var boss_dash_timer_frames := 0.0
var boss_dash_duration_frames := 0.0
var boss_dash_direction := 0
var boss_dash_target_x := 0.0
var boss_dash_stun_timer_frames := 0.0
var boss_dash_stun_total_frames := 0.0
# 매 프레임 HUD가 읽는 대쉬 토큰 스냅샷 재사용 버퍼 (get_dash_token_snapshot 참조).
var _dash_token_snapshot: Dictionary = {}
# 킥 읽기 실패가 확정된 직후의 '흠칫' 창. 반응 가속/최대속도만 잠깐 죽여서
# 억지 RNG가 아니라 보스가 한 박자 늦게 반응한 것처럼 보이게 한다.
# 렌더러 계약을 늘리지 않으려고 스프라이트가 아니라 이동으로 표현한다.
# ⚠️값의 정본은 BossAiPredictionState다 — 그쪽 도달 가능성 게이트가 이 지연
# 비용을 적분해야 "당첨 = 실제 미스"가 성립한다. 여기서 따로 정의하지 마라.
var _kick_read_flinch_frames := 0.0


func reset() -> void:
	prediction_state.reset()
	confusion_target_x = -1.0
	confusion_direction_timer = 0.0
	paddle_hit_knockback_vel = 0.0
	paddle_hit_knockback_timer = 0.0
	paddle_hit_knockback_decay_per_frame = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME
	_kick_read_flinch_frames = 0.0
	_reset_serve_feint()
	_reset_boss_dash()


# 매 프레임 HUD가 읽는 스냅샷이라 Dictionary를 재사용해 프레임당 할당을 없앤다.
# 키 집합은 고정이고 매 호출 전 키를 다시 쓴다. 반환값은 공유 참조이므로
# 소비자는 같은 프레임 안에서 읽기만 해야 한다 (현 소비자: stage1 pillar HUD,
# weather_event_state, 스모크 — 전부 즉시 읽기 전용으로 확인됨).
func get_dash_token_snapshot() -> Dictionary:
	var recharge_frames: float = max(1.0, boss_dash_recharge_frames)
	var charge_progress: float = 1.0
	if boss_dash_tokens < boss_dash_max_tokens:
		charge_progress = clamp(1.0 - boss_dash_charge_timer_frames / recharge_frames, 0.0, 1.0)
	var recovery_progress := 1.0
	if boss_dash_stun_total_frames > 0.0 and boss_dash_stun_timer_frames > 0.0:
		recovery_progress = clamp(1.0 - boss_dash_stun_timer_frames / boss_dash_stun_total_frames, 0.0, 1.0)
	_dash_token_snapshot["tokens"] = boss_dash_tokens
	_dash_token_snapshot["max_tokens"] = max(1, boss_dash_max_tokens)
	_dash_token_snapshot["charge_timer"] = boss_dash_charge_timer_frames
	_dash_token_snapshot["recharge_frames"] = recharge_frames
	_dash_token_snapshot["charge_progress"] = charge_progress
	_dash_token_snapshot["available_timer"] = 1.0 if boss_dash_tokens > 0 else 0.0
	_dash_token_snapshot["active"] = boss_dash_active
	_dash_token_snapshot["recovering"] = boss_dash_stun_timer_frames > 0.0
	_dash_token_snapshot["stun_timer"] = boss_dash_stun_timer_frames
	_dash_token_snapshot["recovery_total_frames"] = boss_dash_stun_total_frames
	_dash_token_snapshot["recovery_progress"] = recovery_progress
	_dash_token_snapshot["timer"] = boss_dash_timer_frames
	_dash_token_snapshot["duration_frames"] = boss_dash_duration_frames
	_dash_token_snapshot["direction"] = boss_dash_direction
	return _dash_token_snapshot


func get_dash_draw_context() -> Dictionary:
	var progress: float = _get_boss_dash_progress()
	return {
		"boss_dash_active": boss_dash_active,
		"boss_dash_direction": boss_dash_direction,
		"boss_dash_timer": boss_dash_timer_frames,
		"boss_dash_duration_frames": boss_dash_duration_frames,
		"boss_dash_progress": progress,
		"boss_dash_frame": _get_boss_dash_frame(progress),
		"boss_dash_recovering": boss_dash_stun_timer_frames > 0.0,
		"boss_dash_stun_timer": boss_dash_stun_timer_frames,
		"boss_dash_stun_total_frames": boss_dash_stun_total_frames,
	}


func get_serve_feint_snapshot() -> Dictionary:
	return {
		"active": serve_feint_active,
		"profile": serve_feint_profile,
		"anchor_x": serve_feint_anchor_x,
		"target_x": serve_feint_target_x,
		"decoy_x": serve_feint_decoy_x,
		"second_decoy_x": serve_feint_second_decoy_x,
		"release_x": serve_feint_release_x,
		"hold_progress": serve_feint_hold_progress,
		"cut_progress": serve_feint_cut_progress,
		"release_progress": serve_feint_release_progress,
	}


func start_paddle_hit_knockback(
	velocity: float,
	frames: float = 36.0,
	decay_per_frame: float = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME,
	replace_current: bool = true
) -> void:
	if replace_current or abs(velocity) >= abs(paddle_hit_knockback_vel):
		paddle_hit_knockback_vel = velocity
		paddle_hit_knockback_decay_per_frame = clamp(decay_per_frame, 0.0, 1.0)
	paddle_hit_knockback_timer = max(paddle_hit_knockback_timer, frames)


func clear_paddle_hit_knockback() -> void:
	paddle_hit_knockback_vel = 0.0
	paddle_hit_knockback_timer = 0.0
	paddle_hit_knockback_decay_per_frame = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME


func update(delta: float, boss_pos: Vector2, boss_vel: float, context: Dictionary) -> Dictionary:
	# Compute the boss motion, then apply the molotov fire barrier to the FINAL
	# position. The barrier must run after every movement path (normal, dash,
	# knockback) because update_active_items — where the molotov's own contact
	# bounce lives — runs a frame earlier, so a dash started/advanced here would
	# otherwise cross the fire before the molotov ever sees it.
	if bool(context.get("stage7_akamu_boss_ai_frozen", false)):
		# 아카무 연출 소유 프레임: 스크립트 좌표는 저작 값을 그대로 신뢰하고,
		# 몰로토프/모래감옥 후처리도 우회한다(연출 좌표를 공유 클램프가 밀면
		# 워프/분신 연출이 찢어진다). 스크립트 좌표가 없는 순수 freeze는 현재
		# 위치를 유지한 채 속도만 0으로 정지한다.
		var frozen_pos: Vector2 = boss_pos
		if bool(context.get("stage7_akamu_scripted_motion_active", false)):
			frozen_pos = _as_vector2(context.get("stage7_akamu_scripted_boss_pos", boss_pos), boss_pos)
		# 실 Stage7은 scripted motion 중 이 frozen 플래그를 항상 true로 내므로,
		# escape > 오딘 넉백 > 캐스팅 핀 우선순위는 이 외곽 게이트에서 성립해야
		# 한다(_update_motion 안에만 두면 실전 도달 불가). 순수 연출 동결
		# (gameplay freeze)은 CC까지 전부 동결한다.
		if (
			bool(context.get("stage7_akamu_scripted_motion_active", false))
			and not bool(context.get("stage7_akamu_gameplay_freeze_active", false))
			and not bool(context.get("stage7_akamu_escape_active", false))
			and not _is_stage2_speed_defense_status_immune(context)
			and bool(context.get("odins_eye_boss_knockback_active", false))
		):
			var frozen_odin_kb_vel: float = float(context.get("odins_eye_boss_knockback_vel", 0.0))
			var frozen_kb_pos: Vector2 = boss_pos
			frozen_kb_pos.x += frozen_odin_kb_vel * (delta * 60.0)
			frozen_kb_pos.x = clamp(
				frozen_kb_pos.x,
				float(context.get("play_left", 0.0)),
				float(context.get("play_right", float(context.get("width", 760.0)))) - float(context.get("boss_paddle_width", 100.0))
			)
			# 넉백은 실제 이동이므로 정상 이동 경로와 같은 순서로 몰로토프
			# 장벽→모래감옥 후처리를 통과해야 한다 — 조기 반환으로 우회하면
			# 캐스팅 중 늪 넉백이 화염을 관통하거나 감옥 밖으로 나간다.
			# 저작(authored) frozen 좌표의 기존 후처리 우회는 아래 반환이 유지.
			var frozen_kb_result: Dictionary = {"boss_pos": frozen_kb_pos, "boss_vel": frozen_odin_kb_vel}
			frozen_kb_result = _apply_molotov_fire_barrier(frozen_kb_result, boss_pos, context)
			return _apply_lingpet_sand_prison_clamp(frozen_kb_result, context)
		return {"boss_pos": frozen_pos, "boss_vel": 0.0}
	var entry_boss_pos: Vector2 = boss_pos
	var result: Dictionary = _update_motion(delta, boss_pos, boss_vel, context)
	result = _apply_molotov_fire_barrier(result, entry_boss_pos, context)
	return _apply_lingpet_sand_prison_clamp(result, context)


func _apply_lingpet_sand_prison_clamp(result: Dictionary, context: Dictionary) -> Dictionary:
	if bool(context.get("lingpet_puppet_grab_active", false)):
		return result
	if not bool(context.get("lingpet_sand_prison_clamp_active", false)):
		return result
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = maxf(1.0, float(context.get("boss_paddle_width", 100.0)))
	var raw_left: float = float(context.get("lingpet_sand_prison_cage_left", play_left))
	var raw_right: float = float(context.get("lingpet_sand_prison_cage_right", play_right))
	var cage_left: float = clampf(minf(raw_left, raw_right), play_left, play_right)
	var cage_right: float = clampf(maxf(raw_left, raw_right), play_left, play_right)
	if cage_right - cage_left < boss_paddle_width:
		var half := boss_paddle_width * 0.5
		var center := clampf((cage_left + cage_right) * 0.5, play_left + half, play_right - half)
		cage_left = center - half
		cage_right = center + half
	var min_x: float = clampf(cage_left, play_left, play_right - boss_paddle_width)
	var max_x: float = clampf(cage_right - boss_paddle_width, play_left, play_right - boss_paddle_width)
	if max_x < min_x:
		var midpoint := clampf((min_x + max_x) * 0.5, play_left, play_right - boss_paddle_width)
		min_x = midpoint
		max_x = midpoint
	var result_pos: Vector2 = _as_vector2(result.get("boss_pos", Vector2(play_left, 25.0)), Vector2(play_left, 25.0))
	var clamped_x: float = clampf(result_pos.x, min_x, max_x)
	if is_equal_approx(clamped_x, result_pos.x):
		return result
	var clamped_result: Dictionary = result.duplicate(true)
	clamped_result["boss_pos"] = Vector2(clamped_x, result_pos.y)
	# Preserve boss_vel: Sand Prison restricts lateral range but the boss keeps
	# its normal bounce / tracking impulse inside the cage.
	return clamped_result


# One-sided crossing barrier: the boss may not end a frame on the FAR side of an
# active molotov fire zone's midline relative to the side it entered the frame on.
# This is the hard guarantee that a fast dash cannot punch through the fire; the
# molotov's velocity bounce + 화염 감속 still own the smooth feel for normal moves.
func _apply_molotov_fire_barrier(result: Dictionary, entry_boss_pos: Vector2, context: Dictionary) -> Dictionary:
	var barriers_value: Variant = context.get("active_item_molotov_fire_barriers", [])
	if not (barriers_value is Array) or (barriers_value as Array).is_empty():
		return result
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var half: float = boss_paddle_width * 0.5
	var result_pos: Vector2 = _as_vector2(result.get("boss_pos", entry_boss_pos), entry_boss_pos)
	var entry_center: float = entry_boss_pos.x + half
	var new_center: float = result_pos.x + half
	# Mirror the molotov contact test's vertical band so a fire zone only blocks
	# while the boss shares its y. Fire zones are reused by the suicide drone at
	# arbitrary field positions, so a low zone must NOT wall off the boss's x.
	var boss_center_y: float = result_pos.y + MOLOTOV_FIRE_BARRIER_BOSS_HALF_HEIGHT
	var clamped_center: float = new_center
	for barrier_value in barriers_value:
		if not (barrier_value is Dictionary):
			continue
		if abs(boss_center_y - float(barrier_value.get("center_y", boss_center_y))) >= MOLOTOV_FIRE_BARRIER_Y_BAND:
			continue
		var bc: float = float(barrier_value.get("center_x", 0.0))
		# Clamp to a tiny epsilon on the boss's APPROACH side, never exactly onto
		# bc. Landing the boss center exactly on the midline loses the side: next
		# frame entry_center == bc is treated as "left" (<=), so a right-approaching
		# boss can no longer retreat right while a cross to the left opens up. The
		# epsilon keeps the clamped center strictly on its own side so the block
		# direction stays stable frame to frame.
		if entry_center <= bc:
			clamped_center = min(clamped_center, bc - MOLOTOV_FIRE_BARRIER_SIDE_EPSILON)
		else:
			clamped_center = max(clamped_center, bc + MOLOTOV_FIRE_BARRIER_SIDE_EPSILON)
	if is_equal_approx(clamped_center, new_center):
		return result
	var clamped_x: float = clamp(clamped_center - half, play_left, play_right - boss_paddle_width)
	var clamped_result: Dictionary = result.duplicate(true)
	clamped_result["boss_pos"] = Vector2(clamped_x, result_pos.y)
	# Kill the velocity that drove the boss into the fire so it stops ramming the
	# midline instead of pushing through every frame.
	clamped_result["boss_vel"] = 0.0
	# A dash blocked by the fire must actually STOP: end the dash and drop into its
	# normal recovery stun, otherwise boss_dash_active stays true and the dash
	# state machine re-rams the midline every frame for the rest of its timer.
	if boss_dash_active:
		_end_boss_dash_on_fire_block(context)
	return clamped_result


# Cancel an in-flight dash because a fire zone stopped it, transitioning straight
# into the dash recovery stun (NOT a chained dash — chaining could just re-cross).
# Mirrors the non-chain tail of `_finish_boss_dash`. Public so other post-AI fire
# owners (e.g. the lingpet dragon breath, which runs in update_lingpet after the
# boss AI) can stop a dash that crossed their patch. No-op if not dashing.
func cancel_dash_for_fire_block(stun_seconds: float = BOSS_DASH_STAGE1_STUN_SECONDS, audio: Object = null) -> bool:
	if not boss_dash_active:
		return false
	boss_dash_active = false
	boss_dash_timer_frames = 0.0
	boss_dash_direction = 0
	_stage7_superspeed_was_active = false
	boss_dash_stun_total_frames = max(1.0, max(0.0, stun_seconds) * 60.0)
	boss_dash_stun_timer_frames = boss_dash_stun_total_frames
	if audio != null and audio.has_method("play_dash_delay"):
		audio.play_dash_delay()
	return true


func _end_boss_dash_on_fire_block(context: Dictionary) -> void:
	var stun_seconds: float = max(0.0, float(context.get("boss_dash_stun_seconds", BOSS_DASH_STAGE1_STUN_SECONDS)))
	cancel_dash_for_fire_block(stun_seconds, context.get("audio", null))


func _update_motion(delta: float, boss_pos: Vector2, boss_vel: float, context: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var original_boss_pos: Vector2 = boss_pos
	var original_boss_vel: float = boss_vel
	var boss_center: float = boss_pos.x + boss_paddle_width * 0.5
	var future_x: float = width * 0.5
	var ball_approaching_boss: bool = false
	var stage2_status_immune: bool = _is_stage2_speed_defense_status_immune(context)

	_update_boss_dash_recharge(fps_scale, context)
	# 조기 return 분기(스톱워치 / 꼭두각시 / 스턴 등)보다 위에서 단일 지점 틱 —
	# 두 경로에서 각각 깎으면 배속으로 흐른다(two-update-path 트랩).
	_kick_read_flinch_frames = max(0.0, _kick_read_flinch_frames - fps_scale)

	if bool(context.get("active_item_stopwatch_freeze_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	if bool(context.get("viper_dmk_freeze_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	# Koyora 꼭두각시 조종 (puppet grab): the lingpet skill writes the scripted
	# boss_pos every frame while it drags/holds/returns the boss. Hold whatever
	# position the skill set this frame and never re-derive it from the ball, so
	# the puppet drag and the precise original-position restore are authoritative.
	if bool(context.get("lingpet_puppet_grab_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	if bool(context.get("stage2_boss_movement_locked", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	if bool(context.get("stage1_dalji_spinning_top_freeze_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	# 오딘 스파이크 넉백: 대쉬/후딜/극정호신 복귀보다
	# 위(Python :178176 "대쉬/후딜보다 우선 처리"). 게이트는 타이머 단독 —
	# 벽 스톱으로 속도가 0이어도 남은 프레임은 보스를 붙들고 대쉬 타이머를
	# 동결시킨다(대쉬 분기 미도달 = 타이머 미소비).
	if not stage2_status_immune and bool(context.get("odins_eye_boss_knockback_active", false)):
		var odin_knockback_vel: float = float(context.get("odins_eye_boss_knockback_vel", 0.0))
		boss_pos.x += odin_knockback_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": odin_knockback_vel,
		}

	if boss_dash_active:
		if (
			_stage7_superspeed_was_active
			and not bool(context.get("stage7_akamu_superspeed_active", false))
		):
			# 좀비 대쉬: 극정호신 소유 대쉬가 플래그 드랍 후 잔존 — 취소하고
			# 이번 update에서 아래 분기(오딘 스턴 등)로 낙하한다.
			boss_dash_active = false
			boss_dash_timer_frames = 0.0
			boss_dash_direction = 0
			_stage7_superspeed_was_active = false
		else:
			_stage7_superspeed_was_active = bool(context.get("stage7_akamu_superspeed_active", false))
			return _update_boss_dash_motion(boss_pos, context, fps_scale)

	if boss_dash_stun_timer_frames > 0.0:
		if stage2_status_immune:
			_clear_boss_dash_stun()
		else:
			return _update_boss_dash_stun(boss_pos, context, fps_scale)

	# 오딘 스턴 잔여: 대쉬 아래(Python :178654 — 대쉬가 살아 있으면 대쉬가
	# 먼저 끝나고, 아이템측 게이트가 스턴 타이머를 동결한다). 감쇠 잔여
	# 속도는 state가 소유하고 여기서는 그대로 적용만 한다.
	if not stage2_status_immune and bool(context.get("odins_eye_boss_stun_active", false)):
		var odin_stun_residual: float = float(context.get("odins_eye_boss_knockback_vel", 0.0))
		boss_pos.x += odin_stun_residual * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": odin_stun_residual,
		}

	if not stage2_status_immune and bool(context.get("stage1_dalji_whip_post_stun_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	if not stage2_status_immune and bool(context.get("ragnarok_hammer_boss_stun_active", false)):
		var ragnarok_motion_vel: float = float(context.get("ragnarok_hammer_boss_knockback_vel", 0.0))
		if not bool(context.get("ragnarok_hammer_boss_knockback_active", false)):
			ragnarok_motion_vel = float(context.get("ragnarok_hammer_electric_stun_drift_vel", 0.0))
		boss_pos.x += ragnarok_motion_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": ragnarok_motion_vel,
		}

	if not stage2_status_immune and bool(context.get("baal_boots_boss_knockback_active", false)):
		var baal_knockback_vel: float = float(context.get("baal_boots_boss_knockback_vel", 0.0))
		boss_pos.x += baal_knockback_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": baal_knockback_vel,
		}

	if not stage2_status_immune and bool(context.get("shrapnel_armor_boss_stun_active", false)):
		var shrapnel_knockback_vel: float = float(context.get("shrapnel_armor_boss_knockback_vel", 0.0))
		if not bool(context.get("shrapnel_armor_boss_knockback_active", false)):
			shrapnel_knockback_vel = 0.0
		boss_pos.x += shrapnel_knockback_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": shrapnel_knockback_vel,
		}

	if not stage2_status_immune and bool(context.get("active_item_grenade_stun_active", false)):
		var knockback_vel: float = float(context.get("active_item_grenade_knockback_vel", 0.0))
		if not bool(context.get("active_item_grenade_knockback_active", abs(knockback_vel) > 0.001)):
			knockback_vel = 0.0
		boss_pos.x += knockback_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": knockback_vel,
		}

	if stage2_status_immune:
		clear_paddle_hit_knockback()
	else:
		boss_pos = _apply_paddle_hit_knockback(
			boss_pos,
			play_left,
			play_right,
			boss_paddle_width,
			fps_scale
		)
	original_boss_pos = boss_pos
	boss_center = boss_pos.x + boss_paddle_width * 0.5

	if bool(context.get("viper_nerve_strike_freeze_active", false)):
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	var combined_banana_slip_vel := 0.0
	if bool(context.get("active_item_banana_slip_active", false)):
		combined_banana_slip_vel += (
			float(context.get("active_item_banana_slip_direction", 0.0))
			* float(context.get("active_item_banana_slip_speed", 0.0))
		)
	if bool(context.get("stage2_monkey_banana_boss_slip_active", false)):
		combined_banana_slip_vel += (
			float(context.get("stage2_monkey_banana_boss_slip_direction", 0.0))
			* float(context.get("stage2_monkey_banana_boss_slip_speed", 0.0))
		)
	if bool(context.get("lingpet_banana_slice_boss_slip_active", false)):
		combined_banana_slip_vel += (
			float(context.get("lingpet_banana_slice_boss_slip_direction", 0.0))
			* float(context.get("lingpet_banana_slice_boss_slip_speed", 0.0))
		)
	if abs(combined_banana_slip_vel) > 0.0:
		boss_pos.x += combined_banana_slip_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": combined_banana_slip_vel,
		}

	if bool(context.get("viper_emp_slip_active", false)):
		var emp_runtime: Object = context.get("viper_emp_slip_runtime", null)
		if emp_runtime != null and emp_runtime.has_method("apply_emp_slip_boss_motion"):
			return emp_runtime.apply_emp_slip_boss_motion(boss_pos, context, fps_scale)
		var emp_slip_vel: float = float(context.get("viper_emp_slip_vel", 0.0))
		boss_pos.x += emp_slip_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": emp_slip_vel,
		}

	if not stage2_status_immune and bool(context.get("active_item_flare_confusion_active", false)):
		future_x = _update_confusion_target(width, boss_paddle_width, fps_scale)
		boss_vel = turn_inertia_resolver.update_velocity(
			future_x,
			boss_center,
			boss_vel,
			fps_scale,
			false,
			1.0,
			1.0,
			context
		)
		boss_vel *= _get_active_item_slow_multiplier(context)
		boss_pos.x += boss_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		var confusion_result := {
			"boss_pos": boss_pos,
			"boss_vel": boss_vel,
		}
		if bool(context.get("active_item_soap_slip_active", false)):
			return _apply_soap_slip_blend(original_boss_pos, original_boss_vel, confusion_result, context, fps_scale)
		return confusion_result

	if bool(context.get("stage1_dalji_whip_deactivation_active", false)):
		var deactivation_ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		var deactivation_ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
		var deactivation_target_x: float = width * 0.5
		if bool(context.get("ball_active", false)) and not bool(context.get("waiting_for_serve", true)):
			deactivation_target_x = prediction_state.predict_exact_arrival_x(
				deactivation_ball_pos,
				deactivation_ball_vel,
				float(context.get("prediction_play_left", play_left)),
				float(context.get("prediction_play_right", play_right)),
				boss_paddle_width,
				context,
				fps_scale
			)
		boss_vel = _update_whip_deactivation_velocity(
			deactivation_target_x,
			boss_center,
			boss_vel,
			fps_scale,
			float(context.get("stage1_dalji_whip_deactivation_progress", 0.0))
		)
		boss_vel *= _get_active_item_slow_multiplier(context)
		boss_pos.x += boss_vel * fps_scale
		boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)
		return {
			"boss_pos": boss_pos,
			"boss_vel": boss_vel,
		}

	var waiting_for_serve: bool = bool(context.get("waiting_for_serve", true))
	var player_serves: bool = bool(context.get("player_serves", true))
	if waiting_for_serve and not player_serves:
		prediction_state.reset()
		future_x = _update_serve_feint_target(boss_pos, context)
	elif bool(context.get("ball_active", false)) and not waiting_for_serve:
		_reset_serve_feint()
		var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
		ball_approaching_boss = ball_vel.y < 0.0
		# 예측 벽 경계는 오버라이드 가능(홀로그램 기만 프레임은 분신의 시각
		# 여백 벽과 같은 경계로 예측해야 실제 분신 궤적과 일치한다). 이동
		# 클램프는 그대로 전역 play_left/right를 쓴다.
		future_x = prediction_state.predict_future_x(
			ball_pos,
			ball_vel,
			fps_scale,
			float(context.get("prediction_play_left", play_left)),
			float(context.get("prediction_play_right", play_right)),
			boss_paddle_width,
			context
		)
		# 굴림과 같은 프레임에 소비한다(아래 대쉬 분기가 early-return해도 신호가 남지 않게).
		if prediction_state.consume_kick_read_failure_flinch():
			_kick_read_flinch_frames = BossAiPredictionState.KICK_READ_FLINCH_FRAMES
	else:
		_reset_serve_feint()
		prediction_state.reset()
		future_x = width * 0.5

	if _try_start_boss_dash(boss_pos, context, future_x):
		return _update_boss_dash_motion(boss_pos, context, fps_scale)

	var reaction_multiplier: float = _get_power_smash_reaction_multiplier(context)
	if _kick_read_flinch_frames > 0.0:
		reaction_multiplier *= BossAiPredictionState.KICK_READ_FLINCH_REACTION_MULT
	var decel_multiplier := 1.0
	if bool(context.get("stage2_speed_defense_active", false)):
		var speed_multiplier: float = max(1.0, float(context.get("stage2_speed_defense_speed_multiplier", 1.0)))
		reaction_multiplier *= speed_multiplier
		decel_multiplier = max(1.0, float(context.get("stage2_speed_defense_turn_multiplier", 1.0)))
		boss_vel = _apply_stage2_speed_defense_initial_velocity(
			boss_vel,
			future_x,
			boss_center,
			context,
			speed_multiplier
		)
	boss_vel = turn_inertia_resolver.update_velocity(
		future_x,
		boss_center,
		boss_vel,
		fps_scale,
		ball_approaching_boss,
		reaction_multiplier,
		decel_multiplier,
		context
	)
	if bool(context.get("stage1_dalji_whip_active", false)):
		boss_vel = clamp(boss_vel, -1.5, 1.5) * 0.3
	boss_vel *= _get_active_item_slow_multiplier(context)
	boss_pos.x += boss_vel * fps_scale
	boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)

	var result := {
		"boss_pos": boss_pos,
		"boss_vel": boss_vel,
	}
	if bool(context.get("active_item_soap_slip_active", false)):
		return _apply_soap_slip_blend(original_boss_pos, original_boss_vel, result, context, fps_scale)
	return result


func _apply_stage2_speed_defense_initial_velocity(
	boss_vel: float,
	future_x: float,
	boss_center: float,
	context: Dictionary,
	speed_multiplier: float
) -> float:
	var initial_ratio: float = max(0.0, float(context.get("stage2_speed_defense_initial_speed_ratio", 0.0)))
	if initial_ratio <= 0.0:
		return boss_vel
	var target_dir := 0
	if future_x < boss_center:
		target_dir = -1
	elif future_x > boss_center:
		target_dir = 1
	if target_dir == 0:
		return boss_vel
	var base_max_speed: float = max(1.0, float(context.get("boss_max_speed", BOSS_DASH_DEFAULT_MAX_SPEED)))
	var initial_speed: float = base_max_speed * speed_multiplier * initial_ratio
	if boss_vel * float(target_dir) >= initial_speed:
		return boss_vel
	return float(target_dir) * initial_speed


func _reset_boss_dash() -> void:
	_stage7_superspeed_was_active = false
	boss_dash_max_tokens = BOSS_DASH_STAGE1_MAX_TOKENS
	boss_dash_tokens = boss_dash_max_tokens
	boss_dash_charge_timer_frames = 0.0
	boss_dash_recharge_frames = 1.0
	boss_dash_active = false
	boss_dash_timer_frames = 0.0
	boss_dash_duration_frames = 0.0
	boss_dash_direction = 0
	boss_dash_target_x = 0.0
	boss_dash_stun_timer_frames = 0.0
	boss_dash_stun_total_frames = 0.0


func _clear_boss_dash_stun() -> void:
	boss_dash_stun_timer_frames = 0.0
	boss_dash_stun_total_frames = 0.0


func _try_start_boss_dash(
	boss_pos: Vector2,
	context: Dictionary,
	predicted_target_x: float,
	force_trigger: bool = false
) -> bool:
	if not bool(context.get("boss_dash_enabled", true)):
		return false
	if boss_dash_active or boss_dash_stun_timer_frames > 0.0:
		return false
	if boss_dash_tokens <= 0:
		return false
	if bool(context.get("waiting_for_serve", true)) or not bool(context.get("ball_active", false)):
		return false
	if bool(context.get("stage1_dalji_whip_active", false)):
		return false
	if bool(context.get("stage1_dalji_whip_deactivation_active", false)):
		return false
	if bool(context.get("active_item_flare_confusion_active", false)):
		return false
	if bool(context.get("active_item_banana_slip_active", false)):
		return false
	if bool(context.get("stage2_monkey_banana_boss_slip_active", false)):
		return false
	if bool(context.get("lingpet_banana_slice_boss_slip_active", false)):
		return false
	if bool(context.get("lingpet_star_coil_block_boss_dash", false)):
		return false

	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y >= 0.0:
		return false

	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	var boss_bottom: float = boss_pos.y + boss_hitbox_height
	var vertical_gap: float = ball_pos.y - boss_bottom
	if vertical_gap <= 0.0 or vertical_gap > BOSS_DASH_CLOSE_VERTICAL_GAP:
		return false

	var impact_boost: float = max(0.01, float(context.get("ball_impact_boost", 1.0)))
	var upward_speed: float = max(1.0, abs(ball_vel.y) * impact_boost)
	var frames_to_contact: float = vertical_gap / upward_speed
	if frames_to_contact > BOSS_DASH_MAX_FRAMES_TO_CONTACT:
		return false

	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_center: float = boss_pos.x + boss_paddle_width * 0.5
	var predicted_x: float = predicted_target_x
	predicted_x = clamp(predicted_x, play_left + boss_paddle_width * 0.5, play_right - boss_paddle_width * 0.5)
	var required_distance: float = abs(predicted_x - boss_center)
	var effective_speed: float = float(context.get("boss_max_speed", BOSS_DASH_DEFAULT_MAX_SPEED)) * BOSS_DASH_AI_COVER_MULTIPLIER
	if required_distance <= effective_speed * frames_to_contact:
		return false
	if required_distance < boss_paddle_width * BOSS_DASH_REQUIRED_WIDTH_RATIO:
		return false

	var direction := 1 if predicted_x > boss_center else -1
	var max_dash_distance: float = float(context.get("boss_dash_max_distance", BOSS_DASH_STAGE1_MAX_DISTANCE))
	var target_center_x: float = clamp(
		boss_center + float(direction) * max_dash_distance,
		play_left + boss_paddle_width * 0.5,
		play_right - boss_paddle_width * 0.5
	)
	var dash_distance: float = abs(target_center_x - boss_center)
	if dash_distance < BOSS_DASH_MIN_DISTANCE:
		return false

	if not force_trigger:
		var trigger_chance: float = clamp(float(context.get("boss_dash_trigger_chance", BOSS_DASH_STAGE1_TRIGGER_CHANCE)), 0.0, 1.0)
		if randf() >= trigger_chance:
			return false

	_start_boss_dash(direction, target_center_x, dash_distance, context)
	return true


func _start_boss_dash(direction: int, target_center_x: float, dash_distance: float, context: Dictionary) -> void:
	boss_dash_active = true
	# 극정호신 소유권은 대쉬 시작 시점에 명시 래치한다 — 활성 분기에서만
	# 갱신하면 이전 극정호신 대쉬의 잔존 true가 다음 일반 대쉬를 첫 업데이트에
	# 좀비로 오인·즉시 취소시킨다.
	_stage7_superspeed_was_active = bool(context.get("stage7_akamu_superspeed_active", false))
	boss_dash_direction = direction
	boss_dash_target_x = target_center_x
	boss_dash_stun_timer_frames = 0.0
	boss_dash_stun_total_frames = 0.0
	boss_dash_duration_frames = clamp(
		dash_distance / BOSS_DASH_AVERAGE_SPEED,
		BOSS_DASH_MIN_DURATION_FRAMES,
		BOSS_DASH_MAX_DURATION_FRAMES
	)
	boss_dash_timer_frames = boss_dash_duration_frames
	boss_dash_tokens = max(0, boss_dash_tokens - 1)
	_start_boss_dash_recharge(context)
	var audio: Variant = context.get("audio", null)
	if audio != null and audio.has_method("play_dash_start"):
		audio.play_dash_start(false)


func _update_boss_dash_motion(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> Dictionary:
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	if boss_dash_timer_frames <= 0.0 or boss_dash_direction == 0:
		_finish_boss_dash(boss_pos, context, fps_scale)
		return {"boss_pos": boss_pos, "boss_vel": 0.0}

	boss_dash_timer_frames = max(0.0, boss_dash_timer_frames - fps_scale)
	var high_phase_frames: float = min(BOSS_DASH_FULL_SPEED_FRAMES, max(1.0, boss_dash_duration_frames))
	var speed_factor := 1.0
	if boss_dash_timer_frames <= high_phase_frames:
		speed_factor = clamp(boss_dash_timer_frames / high_phase_frames, 0.0, 1.0)
	var move_step: float = BOSS_DASH_SPEED * float(boss_dash_direction) * speed_factor * fps_scale
	boss_pos.x += move_step

	var current_center_x: float = boss_pos.x + boss_paddle_width * 0.5
	if boss_dash_direction > 0 and current_center_x > boss_dash_target_x:
		boss_pos.x = boss_dash_target_x - boss_paddle_width * 0.5
	elif boss_dash_direction < 0 and current_center_x < boss_dash_target_x:
		boss_pos.x = boss_dash_target_x - boss_paddle_width * 0.5
	boss_pos.x = clamp(boss_pos.x, play_left, play_right - boss_paddle_width)

	var reached_target: bool = (
		(boss_dash_direction > 0 and boss_pos.x + boss_paddle_width * 0.5 >= boss_dash_target_x - 0.1)
		or (boss_dash_direction < 0 and boss_pos.x + boss_paddle_width * 0.5 <= boss_dash_target_x + 0.1)
	)
	if boss_dash_timer_frames <= 0.0 or reached_target:
		_finish_boss_dash(boss_pos, context, fps_scale)
		return {
			"boss_pos": boss_pos,
			"boss_vel": 0.0,
		}

	return {
		"boss_pos": boss_pos,
		"boss_vel": BOSS_DASH_SPEED * float(boss_dash_direction) * speed_factor,
	}


func _finish_boss_dash(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> void:
	if not boss_dash_active:
		return
	boss_dash_active = false
	boss_dash_timer_frames = 0.0
	_stage7_superspeed_was_active = false
	if _try_start_chained_boss_dash(boss_pos, context, fps_scale):
		return
	var stun_seconds: float = max(0.0, float(context.get("boss_dash_stun_seconds", BOSS_DASH_STAGE1_STUN_SECONDS)))
	boss_dash_stun_total_frames = max(1.0, stun_seconds * 60.0)
	boss_dash_stun_timer_frames = boss_dash_stun_total_frames
	var audio: Variant = context.get("audio", null)
	if audio != null and audio.has_method("play_dash_delay"):
		audio.play_dash_delay()


func _try_start_chained_boss_dash(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> bool:
	if not bool(context.get("boss_dash_chain_enabled", false)):
		return false
	if boss_dash_max_tokens < 2 or boss_dash_tokens <= 0:
		return false
	if bool(context.get("waiting_for_serve", true)) or not bool(context.get("ball_active", false)):
		return false
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y >= 0.0:
		return false
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var predicted_x: float = prediction_state.predict_future_x(
		ball_pos,
		ball_vel,
		fps_scale,
		float(context.get("prediction_play_left", play_left)),
		float(context.get("prediction_play_right", play_right)),
		boss_paddle_width,
		context
	)
	var trigger_chance: float = clamp(
		float(context.get("boss_dash_chain_trigger_chance", context.get("boss_dash_trigger_chance", BOSS_DASH_STAGE1_TRIGGER_CHANCE))),
		0.0,
		1.0
	)
	if randf() >= trigger_chance:
		return false
	return _try_start_boss_dash(boss_pos, context, predicted_x, true)


func _update_boss_dash_stun(boss_pos: Vector2, context: Dictionary, fps_scale: float) -> Dictionary:
	var was_recovering := boss_dash_stun_timer_frames > 0.0
	boss_dash_stun_timer_frames = max(0.0, boss_dash_stun_timer_frames - fps_scale)
	if was_recovering and boss_dash_stun_timer_frames <= 0.0:
		boss_dash_stun_total_frames = 0.0
		var audio: Variant = context.get("audio", null)
		if audio != null and audio.has_method("stop_dash_delay"):
			audio.stop_dash_delay()
	return {
		"boss_pos": boss_pos,
		"boss_vel": 0.0,
	}


func _update_boss_dash_recharge(fps_scale: float, context: Dictionary) -> void:
	boss_dash_max_tokens = max(1, int(context.get("boss_dash_max_tokens", BOSS_DASH_STAGE1_MAX_TOKENS)))
	boss_dash_tokens = clamp(boss_dash_tokens, 0, boss_dash_max_tokens)
	if boss_dash_tokens >= boss_dash_max_tokens:
		boss_dash_charge_timer_frames = 0.0
		return
	if boss_dash_charge_timer_frames > 0.0:
		boss_dash_charge_timer_frames = max(0.0, boss_dash_charge_timer_frames - fps_scale)
	if boss_dash_charge_timer_frames <= 0.0:
		boss_dash_tokens = min(boss_dash_max_tokens, boss_dash_tokens + 1)


func _start_boss_dash_recharge(context: Dictionary) -> void:
	if boss_dash_tokens >= boss_dash_max_tokens:
		boss_dash_charge_timer_frames = 0.0
		return
	var min_seconds: float = float(context.get("boss_dash_cooldown_min_seconds", BOSS_DASH_STAGE1_COOLDOWN_SECONDS.x))
	var max_seconds: float = float(context.get("boss_dash_cooldown_max_seconds", BOSS_DASH_STAGE1_COOLDOWN_SECONDS.y))
	var cooldown_multiplier: float = _get_boss_dash_league_cooldown_multiplier(str(context.get("ai_mode", "champion")))
	min_seconds *= cooldown_multiplier
	max_seconds *= cooldown_multiplier
	if max_seconds < min_seconds:
		max_seconds = min_seconds
	boss_dash_recharge_frames = max(1.0, randf_range(min_seconds, max_seconds) * 60.0)
	boss_dash_charge_timer_frames = boss_dash_recharge_frames


func _get_boss_dash_league_cooldown_multiplier(ai_mode: String) -> float:
	match BattleSceneConfig.normalize_league_mode(ai_mode):
		"champion", "limit", "mythic":
			return 0.4
		_:
			return 1.0


func _predict_x_with_walls(x: float, vx: float, frames: float, play_left: float, play_right: float) -> float:
	if abs(vx) < 0.001 or frames <= 0.0:
		return x
	var remaining: float = frames
	var predicted_x: float = x
	var predicted_vx: float = vx
	for _i in range(4):
		if remaining <= 0.0:
			break
		var t_wall := INF
		if predicted_vx > 0.0:
			t_wall = (play_right - predicted_x) / predicted_vx
		elif predicted_vx < 0.0:
			t_wall = (play_left - predicted_x) / predicted_vx
		if t_wall <= 0.0 or t_wall >= remaining:
			predicted_x += predicted_vx * remaining
			remaining = 0.0
			break
		predicted_x += predicted_vx * t_wall
		remaining -= t_wall
		predicted_vx = -predicted_vx
	return clamp(predicted_x, play_left, play_right)


func _get_boss_dash_progress() -> float:
	if boss_dash_duration_frames <= 0.0:
		return 0.0
	return clamp(1.0 - boss_dash_timer_frames / boss_dash_duration_frames, 0.0, 0.999)


func _get_boss_dash_frame(progress: float) -> int:
	var p: float = clamp(progress, 0.0, 0.999)
	if p < 0.08:
		return 0
	if p < 0.18:
		return 1
	if p < 0.55:
		return 2
	return 3


func _apply_paddle_hit_knockback(
	boss_pos: Vector2,
	play_left: float,
	play_right: float,
	boss_paddle_width: float,
	fps_scale: float
) -> Vector2:
	if paddle_hit_knockback_timer <= 0.0 or abs(paddle_hit_knockback_vel) <= 0.3:
		paddle_hit_knockback_vel = 0.0
		paddle_hit_knockback_timer = 0.0
		paddle_hit_knockback_decay_per_frame = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME
		return boss_pos

	boss_pos.x += paddle_hit_knockback_vel * fps_scale
	var min_x: float = play_left
	var max_x: float = play_right - boss_paddle_width
	if boss_pos.x < min_x:
		boss_pos.x = min_x
		paddle_hit_knockback_vel = abs(paddle_hit_knockback_vel) * PADDLE_HIT_KNOCKBACK_WALL_BOUNCE_KEEP_RATIO
	elif boss_pos.x > max_x:
		boss_pos.x = max_x
		paddle_hit_knockback_vel = -abs(paddle_hit_knockback_vel) * PADDLE_HIT_KNOCKBACK_WALL_BOUNCE_KEEP_RATIO

	paddle_hit_knockback_vel *= pow(paddle_hit_knockback_decay_per_frame, fps_scale)
	paddle_hit_knockback_timer = max(0.0, paddle_hit_knockback_timer - fps_scale)
	if paddle_hit_knockback_timer <= 0.0 or abs(paddle_hit_knockback_vel) <= 0.3:
		paddle_hit_knockback_vel = 0.0
		paddle_hit_knockback_timer = 0.0
		paddle_hit_knockback_decay_per_frame = PADDLE_HIT_KNOCKBACK_DECAY_PER_FRAME
	return boss_pos


func _is_stage2_speed_defense_status_immune(context: Dictionary) -> bool:
	if int(context.get("current_stage", 0)) != 2:
		return false
	return (
		bool(context.get("stage2_speed_defense_status_immunity_active", false))
		or bool(context.get("stage2_speed_defense_active", false))
	)


func _update_serve_feint_target(boss_pos: Vector2, context: Dictionary) -> float:
	var width: float = float(context.get("width", 760.0))
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", width))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_center: float = boss_pos.x + boss_paddle_width * 0.5
	var min_center: float = play_left + boss_paddle_width * 0.5
	var max_center: float = play_right - boss_paddle_width * 0.5
	var now_msec: int = Time.get_ticks_msec()

	if not serve_feint_active:
		_begin_serve_feint(boss_center, context, min_center, max_center, now_msec)

	var progress: float = _get_serve_feint_progress(context, now_msec)
	var base_target: float = _resolve_serve_feint_target(progress, boss_center)
	var jitter: float = _get_serve_feint_jitter(progress, now_msec)
	serve_feint_target_x = clamp(base_target + jitter, min_center, max_center)
	return serve_feint_target_x


func _begin_serve_feint(
	boss_center: float,
	context: Dictionary,
	min_center: float,
	max_center: float,
	now_msec: int
) -> void:
	serve_feint_active = true
	serve_feint_anchor_x = clamp(boss_center, min_center, max_center)
	serve_feint_start_msec = now_msec
	serve_feint_phase = randf() * TAU
	var override_profile: String = str(context.get("boss_serve_feint_profile_override", ""))
	if SERVE_FEINT_PROFILES.has(override_profile):
		serve_feint_profile = override_profile
	else:
		serve_feint_profile = SERVE_FEINT_PROFILES[randi() % SERVE_FEINT_PROFILES.size()]

	var side: float = _pick_serve_feint_side(serve_feint_anchor_x, context, min_center, max_center)
	var short_step: float = randf_range(42.0, 86.0)
	var long_step: float = randf_range(118.0, 210.0)
	var reverse_step: float = randf_range(105.0, 190.0)
	var player_center: float = _get_player_center(context)
	var player_bait_x: float = clamp(
		lerp(serve_feint_anchor_x, player_center, 0.48) + randf_range(-48.0, 48.0),
		min_center,
		max_center
	)

	match serve_feint_profile:
		"hold_snap":
			serve_feint_decoy_x = serve_feint_anchor_x
			serve_feint_second_decoy_x = serve_feint_anchor_x
			serve_feint_release_x = _offset_serve_feint_center(serve_feint_anchor_x, side * long_step, min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.46, 0.62), randf_range(0.68, 0.80), randf_range(0.86, 0.95))
		"side_step":
			serve_feint_decoy_x = _offset_serve_feint_center(serve_feint_anchor_x, side * short_step, min_center, max_center)
			serve_feint_second_decoy_x = serve_feint_decoy_x
			serve_feint_release_x = _offset_serve_feint_center(serve_feint_anchor_x, side * long_step, min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.16, 0.28), randf_range(0.44, 0.58), randf_range(0.72, 0.88))
		"bait_reverse":
			serve_feint_decoy_x = _offset_serve_feint_center(player_bait_x, side * randf_range(10.0, 50.0), min_center, max_center)
			serve_feint_second_decoy_x = serve_feint_decoy_x
			serve_feint_release_x = _offset_serve_feint_center(serve_feint_anchor_x, -side * reverse_step, min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.22, 0.36), randf_range(0.50, 0.66), randf_range(0.78, 0.92))
		"double_bluff":
			serve_feint_decoy_x = _offset_serve_feint_center(serve_feint_anchor_x, side * short_step, min_center, max_center)
			serve_feint_second_decoy_x = _offset_serve_feint_center(serve_feint_anchor_x, -side * randf_range(52.0, 115.0), min_center, max_center)
			serve_feint_release_x = _offset_serve_feint_center(serve_feint_anchor_x, side * randf_range(82.0, 165.0), min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.18, 0.30), randf_range(0.42, 0.58), randf_range(0.74, 0.90))
		"stare_down":
			serve_feint_decoy_x = serve_feint_anchor_x
			serve_feint_second_decoy_x = serve_feint_anchor_x
			serve_feint_release_x = _offset_serve_feint_center(player_bait_x, side * randf_range(70.0, 145.0), min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.58, 0.74), randf_range(0.74, 0.84), randf_range(0.88, 0.97))
		_:
			serve_feint_decoy_x = _offset_serve_feint_center(serve_feint_anchor_x, side * randf_range(58.0, 125.0), min_center, max_center)
			serve_feint_second_decoy_x = _offset_serve_feint_center(serve_feint_anchor_x, -side * randf_range(45.0, 105.0), min_center, max_center)
			serve_feint_release_x = _offset_serve_feint_center(serve_feint_anchor_x, side * randf_range(55.0, 150.0), min_center, max_center)
			_set_serve_feint_progress_marks(randf_range(0.18, 0.34), randf_range(0.42, 0.62), randf_range(0.76, 0.94))
	serve_feint_target_x = serve_feint_anchor_x


func _pick_serve_feint_side(
	boss_center: float,
	context: Dictionary,
	min_center: float,
	max_center: float
) -> float:
	if context.has("boss_serve_feint_side_override"):
		var override_side: float = float(context.get("boss_serve_feint_side_override", 0.0))
		if abs(override_side) > 0.001:
			return sign(override_side)
	var left_space: float = boss_center - min_center
	var right_space: float = max_center - boss_center
	if left_space < 115.0 and right_space > left_space:
		return 1.0
	if right_space < 115.0 and left_space > right_space:
		return -1.0
	var player_center: float = _get_player_center(context)
	var player_side := 0.0
	if abs(player_center - boss_center) > 24.0:
		player_side = sign(player_center - boss_center)
	if player_side != 0.0 and randf() < 0.56:
		return player_side
	return -1.0 if randi() % 2 == 0 else 1.0


func _get_serve_feint_progress(context: Dictionary, now_msec: int) -> float:
	var serve_timer: float = max(0.0, float(context.get("boss_serve_timer", 0.0)))
	var serve_delay: float = max(0.0, float(context.get("boss_serve_target_delay", 0.0)))
	if serve_delay > 0.05:
		return clamp(serve_timer / serve_delay, 0.0, 1.0)
	var elapsed_seconds: float = max(0.0, float(now_msec - serve_feint_start_msec) / 1000.0)
	return clamp(elapsed_seconds / 0.75, 0.0, 1.0)


func _resolve_serve_feint_target(progress: float, boss_center: float) -> float:
	match serve_feint_profile:
		"hold_snap", "stare_down":
			if progress < serve_feint_hold_progress:
				return boss_center
			return lerp(
				serve_feint_anchor_x,
				serve_feint_release_x,
				_smooth_progress(serve_feint_hold_progress, serve_feint_release_progress, progress)
			)
		"side_step", "bait_reverse":
			if progress < serve_feint_hold_progress:
				return lerp(
					serve_feint_anchor_x,
					serve_feint_decoy_x,
					_smooth_progress(0.0, serve_feint_hold_progress, progress)
				)
			if progress < serve_feint_cut_progress:
				return serve_feint_decoy_x
			return lerp(
				serve_feint_decoy_x,
				serve_feint_release_x,
				_smooth_progress(serve_feint_cut_progress, serve_feint_release_progress, progress)
			)
		"double_bluff":
			if progress < serve_feint_hold_progress:
				return lerp(
					serve_feint_anchor_x,
					serve_feint_decoy_x,
					_smooth_progress(0.0, serve_feint_hold_progress, progress)
				)
			if progress < serve_feint_cut_progress:
				return lerp(
					serve_feint_decoy_x,
					serve_feint_second_decoy_x,
					_smooth_progress(serve_feint_hold_progress, serve_feint_cut_progress, progress)
				)
			if progress < serve_feint_release_progress:
				return serve_feint_second_decoy_x
			return lerp(
				serve_feint_second_decoy_x,
				serve_feint_release_x,
				_smooth_progress(serve_feint_release_progress, 1.0, progress)
			)
		_:
			var weave: float = sin(progress * TAU * 2.0 + serve_feint_phase)
			var center: float = lerp(
				serve_feint_anchor_x,
				serve_feint_release_x,
				_smooth_progress(0.0, serve_feint_release_progress, progress)
			)
			return center + weave * 34.0


func _get_serve_feint_jitter(progress: float, now_msec: int) -> float:
	var intensity := 0.0
	match serve_feint_profile:
		"hold_snap", "stare_down":
			if progress < serve_feint_hold_progress:
				return 0.0
			intensity = 0.18
		"side_step":
			intensity = 0.42
		"bait_reverse":
			intensity = 0.34
		"double_bluff":
			intensity = 0.48
		_:
			intensity = 0.62
	if progress >= serve_feint_release_progress:
		intensity *= 0.35
	return sin(float(now_msec) * 0.009 + serve_feint_phase) * intensity


func _set_serve_feint_progress_marks(hold: float, cut: float, release: float) -> void:
	serve_feint_hold_progress = clamp(hold, 0.0, 0.86)
	serve_feint_cut_progress = clamp(max(cut, serve_feint_hold_progress + 0.05), 0.05, 0.94)
	serve_feint_release_progress = clamp(max(release, serve_feint_cut_progress + 0.05), 0.10, 0.99)


func _offset_serve_feint_center(center: float, offset: float, min_center: float, max_center: float) -> float:
	return clamp(center + offset, min_center, max_center)


func _smooth_progress(start_progress: float, end_progress: float, progress: float) -> float:
	if end_progress <= start_progress:
		return 1.0
	var t: float = clamp((progress - start_progress) / (end_progress - start_progress), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_player_center(context: Dictionary) -> float:
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_width: float = float(context.get("player_paddle_width", 155.0))
	return player_pos.x + player_width * 0.5


func _reset_serve_feint() -> void:
	serve_feint_active = false
	serve_feint_target_x = -1.0
	serve_feint_decoy_x = -1.0
	serve_feint_second_decoy_x = -1.0
	serve_feint_release_x = -1.0
	serve_feint_hold_progress = 0.0
	serve_feint_cut_progress = 0.0
	serve_feint_release_progress = 0.0
	serve_feint_start_msec = 0
	serve_feint_phase = 0.0
	serve_feint_anchor_x = -1.0


func _apply_soap_slip_blend(
	original_boss_pos: Vector2,
	original_boss_vel: float,
	ai_result: Dictionary,
	context: Dictionary,
	fps_scale: float
) -> Dictionary:
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", float(context.get("width", 760.0))))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var blend: float = clamp(float(context.get("active_item_soap_slip_blend", 0.18)), 0.0, 1.0)
	var friction: float = clamp(float(context.get("active_item_soap_slip_friction", 0.985)), 0.0, 1.0)
	var ai_pos: Vector2 = _as_vector2(ai_result.get("boss_pos", original_boss_pos), original_boss_pos)
	var ai_vel: float = float(ai_result.get("boss_vel", original_boss_vel))
	var momentum_x: float = original_boss_pos.x + original_boss_vel * fps_scale
	var next_vel: float = (original_boss_vel + (ai_vel - original_boss_vel) * blend) * friction
	var next_pos: Vector2 = ai_pos
	next_pos.x = momentum_x + (ai_pos.x - momentum_x) * blend
	if next_pos.x < play_left:
		next_pos.x = play_left
		next_vel = abs(next_vel) * 0.3
	elif next_pos.x > play_right - boss_paddle_width:
		next_pos.x = play_right - boss_paddle_width
		next_vel = -abs(next_vel) * 0.3
	return {
		"boss_pos": next_pos,
		"boss_vel": next_vel,
	}


func _update_confusion_target(width: float, boss_paddle_width: float, fps_scale: float) -> float:
	var min_center: float = boss_paddle_width * 0.5
	var max_center: float = width - boss_paddle_width * 0.5
	if confusion_target_x < 0.0:
		confusion_target_x = randf_range(min_center, max_center)
		confusion_direction_timer = 0.0
	confusion_direction_timer += fps_scale
	if confusion_direction_timer >= CONFUSION_CHANGE_FRAMES:
		confusion_target_x = randf_range(min_center, max_center)
		confusion_direction_timer = 0.0
	if randf() < CONFUSION_RANDOM_TURN_CHANCE:
		return randf_range(min_center, max_center)
	return confusion_target_x


func _update_whip_deactivation_velocity(
	target_x: float,
	boss_center: float,
	boss_vel: float,
	fps_scale: float,
	progress: float
) -> float:
	var distance: float = target_x - boss_center
	if abs(distance) <= WHIP_DEACTIVATION_DEADZONE:
		return move_toward(boss_vel, 0.0, WHIP_DEACTIVATION_ACCEL * fps_scale)

	var time_speed: float = lerp(
		WHIP_DEACTIVATION_FAST_SPEED,
		WHIP_DEACTIVATION_SLOW_SPEED,
		clamp(progress, 0.0, 1.0)
	)
	var brake_ratio: float = clamp(abs(distance) / WHIP_DEACTIVATION_BRAKE_DISTANCE, 0.0, 1.0)
	var target_speed: float = time_speed * lerp(0.35, 1.0, brake_ratio)
	target_speed = min(target_speed, abs(distance) / max(0.001, fps_scale))

	var desired_vel: float = sign(distance) * target_speed
	var accel_step: float = WHIP_DEACTIVATION_ACCEL * fps_scale
	if boss_vel * desired_vel < 0.0:
		accel_step *= 1.5
	return move_toward(boss_vel, desired_vel, accel_step)


func _get_active_item_slow_multiplier(context: Dictionary) -> float:
	var multiplier := 1.0
	if bool(context.get("active_item_spider_mine_slow_active", false)):
		multiplier *= clamp(float(context.get("active_item_spider_mine_slow_factor", 0.4)), 0.05, 1.0)
	if bool(context.get("smasher_plasma_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("smasher_plasma_boss_slow_multiplier", 1.0)), 0.05, 1.0)
	if bool(context.get("venom_mist_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("venom_mist_boss_slow_multiplier", 0.3)), 0.05, 1.0)
	if bool(context.get("baal_boots_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("baal_boots_boss_slow_multiplier", 0.7)), 0.05, 1.0)
	if bool(context.get("lingpet_star_coil_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("lingpet_star_coil_boss_slow_multiplier", 0.4)), 0.05, 1.0)
	if bool(context.get("lingpet_dwarf_magic_boss_slow_active", false)):
		multiplier *= clamp(float(context.get("lingpet_dwarf_magic_boss_slow_multiplier", 0.55)), 0.05, 1.0)
	# Molotov fire already owns hard movement obstruction through the post-AI
	# barrier above. Keep its lingering fire slow as a standalone smooth-return
	# feel, but do not stack it on top of dedicated boss-slow debuffs.
	if is_equal_approx(multiplier, 1.0) and bool(context.get("active_item_molotov_slow_active", false)):
		multiplier *= clamp(float(context.get("active_item_molotov_slow_factor", 1.0)), 0.05, 1.0)
	return clamp(multiplier, 0.05, 1.0)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_power_smash_reaction_multiplier(context: Dictionary) -> float:
	if not bool(context.get("power_smashing_parabola_active", false)):
		return 1.0
	var combo_consumed: int = int(context.get("power_smashing_combo_consumed", 0))
	if combo_consumed < 2:
		return 1.0
	return 1.0 + min(
		float(combo_consumed) * POWER_SMASH_BOSS_REACT_PER_COMBO,
		POWER_SMASH_BOSS_REACT_CAP
	)
