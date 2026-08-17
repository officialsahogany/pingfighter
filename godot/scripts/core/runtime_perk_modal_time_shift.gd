extends RefCounted

# 퍽 선택 모달(스타포인트 / 스테이지 클리어 / 천사의 축복 / 팔자윷)은
# `battle_scene_frame_controller.process_physics` 의 modal-block 게이트에서
# 업데이트 드라이버를 통째로 막는다. 프레임 카운터로 도는 타이머는 그래서 같이
# 멈추지만, `Time.get_ticks_msec()` 에 앵커된 시각은 **계속 흐른다** — 퍽을
# 고르는 몇 초 사이에 발동창 / 입력창 / 예약 시각이 조용히 지나가 버린다.
# (풍운천선무 발동창 1.2초가 퍽 선택 중에 만료돼 모달이 닫히는 순간 모션이
# 끝나 있던 사례.)
#
# 여기 있는 헬퍼는 모달이 닫힐 때 "멈춰 있던 시간"만큼 앵커를 앞으로 밀어
# 모달 동안 벽시계가 정지했던 것처럼 만든다. 팬아웃 지점은
# `battle_scene_skill_tooltip_driver._pause_runtime_perk_modal_time` /
# `_resume_runtime_perk_modal_time` 한 곳이고, 각 상태 모듈은
# `pause_runtime_perk_modal_time` / `resume_runtime_perk_modal_time` 를 구현해
# 거기에 실린다.
#
# ⚠️**시각(anchor)만 밀어야 한다.** `windup_msec` / `cooldown_msec` /
# `switch_debounce_msec` 같은 **길이(duration)** 를 같이 밀면 지속시간이 모달을
# 연 만큼 늘어난다. 그래서 dict 키 목록은 절대 "_msec 로 끝나는 전부"가 아니라
# 호출부가 명시하는 화이트리스트다.
#
# ⭐**기록된 설계 결정 (2026-08-08 사용자 확정): 입력 커맨드 버퍼도 함께 민다.**
# 풍운천선무 A→W→D(600ms 창)와 바이퍼 `dual_glitch` / `chaos` 커맨드 버퍼는
# 활성 효과 타이머와 똑같이 취급한다 — 모달은 "게임 시간상 없던 일"이므로,
# 플레이어가 의도해서 넣은 입력을 비자발적 중단(스타포인트 획득 등)으로
# 잃게 하지 않는다. 트레이드오프는 인지된 상태다: `A`/`D`가 평소 이동키라
# 모달 직후 남은 창(최대 600ms) 안에 이동하려고 누르면 늦은 발동이 날 수 있다.
# ⚠️이 동작을 "버그"로 보고 되돌리기 전에 이 주석을 먼저 볼 것 —
# felt-gap 리포트는 방향 결정이 아니다.


# 이미 지난 시각을 뜻하는 센티널(-100000 등)과 미설정(0)은 밀지 않는다.
static func shift_anchor(value: int, delta_msec: int) -> int:
	if delta_msec <= 0 or value <= 0:
		return value
	return value + delta_msec


static func shift_dict_anchors(target: Dictionary, keys: Array[String], delta_msec: int) -> void:
	if delta_msec <= 0 or target.is_empty():
		return
	for key: String in keys:
		if not target.has(key):
			continue
		target[key] = shift_anchor(int(target[key]), delta_msec)


static func shift_dict_array_anchors(entries: Array, keys: Array[String], delta_msec: int) -> void:
	if delta_msec <= 0 or entries.is_empty():
		return
	for entry: Variant in entries:
		if entry is Dictionary:
			shift_dict_anchors(entry as Dictionary, keys, delta_msec)


# 모달이 연속으로 열릴 수 있으므로(퍽 여러 장 연속 선택) pause 는 멱등이고
# resume 은 마커가 없으면 no-op 이다 — 한 번의 정지 구간으로 합쳐진다.
static func begin_pause(pause_started_msec: int, current_msec: int) -> int:
	if pause_started_msec >= 0:
		return pause_started_msec
	return maxi(0, current_msec)


static func resolve_paused_duration(pause_started_msec: int, resumed_msec: int) -> int:
	if pause_started_msec < 0:
		return 0
	return maxi(0, resumed_msec - pause_started_msec)
