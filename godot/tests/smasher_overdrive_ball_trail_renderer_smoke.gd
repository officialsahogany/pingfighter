extends SceneTree

# 스매셔 오버드라이브 폭주 트레일 렌더러의 상태 로직 봉인(Opus 비주얼 레인).
# draw_* 는 실제 _draw 컨텍스트에서만 유효하므로, 여기서는 렌더와 분리된
# advance() 상태 전진만 검증한다: 히스토리 성장/캡, 킹크 스파크 스폰(중복 방지 +
# 상한), 스파크 수명 소멸, 비활성 시 트레일 소멸 + 페이드 감쇠, null 캔버스 no-op.

const SmasherOverdriveBallTrailRenderer := preload("res://scripts/ball/smasher_overdrive_ball_trail_renderer.gd")

var _failed := false


func _init() -> void:
	_test_history_grows_and_caps()
	_test_kink_spark_dedup_and_cap()
	_test_spark_ages_out()
	_test_inactive_fades_and_drains()
	_test_null_canvas_is_noop()

	if _failed:
		quit(1)
		return
	print("smasher_overdrive_ball_trail_renderer_smoke: ok")
	quit(0)


func _test_history_grows_and_caps() -> void:
	var r := SmasherOverdriveBallTrailRenderer.new()
	for i in 5:
		r.advance(Vector2(float(i), 0.0), true, 0, Vector2(8.0, -6.0))
	_expect(r._history.size() == 5, "5 active frames should record 5 trail points")
	for i in 40:
		r.advance(Vector2(float(i), 1.0), true, 0, Vector2(8.0, -6.0))
	_expect(r._history.size() == SmasherOverdriveBallTrailRenderer.HISTORY_MAX, "trail history must cap at HISTORY_MAX")
	_expect(r._fade > 0.9, "sustained active frames should raise the fade envelope toward 1")


func _test_kink_spark_dedup_and_cap() -> void:
	var r := SmasherOverdriveBallTrailRenderer.new()
	# 첫 활성 프레임은 현재 serial 을 채택만 하고 스파크를 안 낸다.
	r.advance(Vector2.ZERO, true, 0, Vector2(8.0, -6.0))
	_expect(r._sparks.is_empty(), "adopting the first serial must not spawn a spurious spark")
	# serial 이 그대로면 스파크 없음.
	r.advance(Vector2.ZERO, true, 0, Vector2(8.0, -6.0))
	_expect(r._sparks.is_empty(), "an unchanged serial must not spawn a spark")
	# serial 증가 = 킹크 1회 = 스파크 1개.
	r.advance(Vector2(10.0, 0.0), true, 1, Vector2(8.0, -6.0))
	_expect(r._sparks.size() == 1, "a serial increment should spawn exactly one kink spark")
	# 상한 초과 스폰은 SPARK_MAX 로 유지.
	for s in range(2, 20):
		r.advance(Vector2(float(s), 0.0), true, s, Vector2(8.0, -6.0))
	_expect(r._sparks.size() <= SmasherOverdriveBallTrailRenderer.SPARK_MAX, "spark count must not exceed SPARK_MAX")


func _test_spark_ages_out() -> void:
	var r := SmasherOverdriveBallTrailRenderer.new()
	r.advance(Vector2.ZERO, true, 0, Vector2(8.0, -6.0))
	r.advance(Vector2.ZERO, true, 1, Vector2(8.0, -6.0))
	_expect(r._sparks.size() == 1, "kink should have spawned a spark to age out")
	for i in 12:
		r.advance(Vector2.ZERO, false, 1, Vector2(8.0, -6.0))
	_expect(r._sparks.is_empty(), "a spark must be removed once it exceeds SPARK_LIFE")


func _test_inactive_fades_and_drains() -> void:
	var r := SmasherOverdriveBallTrailRenderer.new()
	for i in 30:
		r.advance(Vector2(float(i), 0.0), true, 0, Vector2(8.0, -6.0))
	_expect(r._history.size() == SmasherOverdriveBallTrailRenderer.HISTORY_MAX and r._fade > 0.9, "precondition: full trail + high fade")
	for i in 40:
		r.advance(Vector2.ZERO, false, 0, Vector2.ZERO)
	_expect(r._history.size() == 0, "inactive frames must drain the trail history to empty")
	_expect(r._fade < 0.001, "inactive frames must decay the fade envelope to ~0")


func _test_null_canvas_is_noop() -> void:
	var r := SmasherOverdriveBallTrailRenderer.new()
	# null 캔버스에서 draw() 는 조용히 반환해야 한다(크래시 없음).
	r.draw(null, Vector2.ZERO, {"smasher_overdrive_active": true, "kink_serial": 1}, Vector2(8.0, -6.0), 1.0)
	_expect(true, "draw() with a null canvas must not crash")
	# clear() 는 모든 상태를 초기화한다.
	r.advance(Vector2.ONE, true, 0, Vector2(8.0, -6.0))
	r.clear()
	_expect(r._history.size() == 0 and r._sparks.is_empty() and r._last_serial == -1 and r._fade == 0.0, "clear() must reset all trail state")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
