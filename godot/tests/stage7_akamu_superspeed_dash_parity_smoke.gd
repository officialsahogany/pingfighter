extends SceneTree

# 극정호신(superspeed) 대시 원본 파리티 씰 (2026-07-11 라이브 QA):
#  (1) TEMPO: 목표 도달 시 대시를 즉시 종료하지 않고 타이머가 0이 될 때까지
#      목표에 머문다(원본 pingfighter.py:178296-178306). 조기 종료는 짧은
#      인터셉트마다 재대시를 앞당겨 템포를 원본보다 빠르게 만든다.
#  (2) SOUND: 대시 종료마다 후딜(dash-delay) 루프를 재생하고 1프레임 회복
#      스턴이 끝날 때 정지한다(원본 :178341-178345 / :178370-178374, 포트
#      일반 보스 대시 _finish_boss_dash / _update_boss_dash_stun와 동일 패턴).

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

var _failures: Array[String] = []


class FakeDashAudio:
	extends RefCounted

	var play_delay_calls := 0
	var stop_delay_calls := 0

	func play_dash_delay() -> void:
		play_delay_calls += 1

	func stop_dash_delay() -> void:
		stop_delay_calls += 1


func _init() -> void:
	_verify_hold_at_target_and_dash_delay_lifecycle()
	if _failures.is_empty():
		print("stage7_akamu_superspeed_dash_parity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _superspeed_context(audio: Object) -> Dictionary:
	# 짧은 인터셉트(거리 30px -> duration 10프레임): 대시가 목표에 조기 도달해
	# 잔여 프레임을 hold하는 회귀 영역(거리 <= ~180)에 들어간다.
	return {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"boss_hitbox_height": 40.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(450.0, 400.0),
		"ball_vel": Vector2(0.0, 10.0),
		"stage7_akamu_superspeed_active": true,
		"audio": audio,
	}


func _verify_hold_at_target_and_dash_delay_lifecycle() -> void:
	var audio := FakeDashAudio.new()
	var ai: Object = BossAiState.new()
	var boss_pos := Vector2(400.0, 25.0)
	var context := _superspeed_context(audio)

	# Frame 1: 미대시 -> 대시 시작 + 전진. 거리 30이라 이번 프레임에 목표(x=430,
	# center 450)에 도달하지만 대시는 유지돼야 한다.
	var result: Dictionary = ai.update(1.0 / 60.0, boss_pos, 0.0, context)
	boss_pos = result.get("boss_pos", boss_pos)
	_expect(bool(ai.get("boss_dash_active")), "superspeed dash should arm on the first superspeed frame")
	var target_x: float = float(ai.get("boss_dash_target_x"))
	var center_after_reach: float = boss_pos.x + 20.0
	_expect(
		absf(center_after_reach - target_x) < 1.0,
		"short superspeed dash should reach the predicted target in one frame"
	)

	# Frames 2..6: 목표 도달 후에도 대시가 즉시 끝나지 않고 목표에 머물러야 한다
	# (원본 hold). 조기 종료 회귀 코드에서는 여기서 active=false가 된다.
	var held_center := boss_pos.x + 20.0
	for _hold_frame in range(5):
		result = ai.update(1.0 / 60.0, boss_pos, 0.0, context)
		boss_pos = result.get("boss_pos", boss_pos)
		_expect(bool(ai.get("boss_dash_active")), "superspeed dash must HOLD at target, not early-finish (tempo parity)")
		_expect(
			absf((boss_pos.x + 20.0) - held_center) < 0.5,
			"boss must stay stationary at the target during the hold window"
		)
		_expect_close(float(result.get("boss_vel", -99.0)), 0.0, "held boss reports zero velocity at the target")
	_expect(audio.play_delay_calls == 0, "dash-delay must not fire while the dash is still holding")

	# 타이머 만료까지 마저 진행 -> _finish에서 후딜음 재생.
	var finished := false
	var play_at_finish := 0
	for _finish_frame in range(6):
		result = ai.update(1.0 / 60.0, boss_pos, 0.0, context)
		boss_pos = result.get("boss_pos", boss_pos)
		if not bool(ai.get("boss_dash_active")):
			finished = true
			play_at_finish = audio.play_delay_calls
			break
	_expect(finished, "superspeed dash should finish once its full duration timer elapses")
	_expect(play_at_finish >= 1, "superspeed dash finish should play the dash-delay recovery loop (sound parity)")

	# 회복 스턴(1프레임)이 끝나는 프레임에 후딜 루프 정지 (start->stop 완결).
	var stopped := false
	for _recover_frame in range(4):
		result = ai.update(1.0 / 60.0, boss_pos, 0.0, context)
		boss_pos = result.get("boss_pos", boss_pos)
		if audio.stop_delay_calls >= 1:
			stopped = true
			break
	_expect(stopped, "superspeed recovery expiry should stop the dash-delay loop (sound parity)")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.01:
		_failures.append("%s (got %f, expected %f)" % [message, actual, expected])
