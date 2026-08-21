extends SceneTree

const BattleFeedbackState := preload("res://scripts/effects/battle_feedback_state.gd")
const SmasherPowerSmashMotionController := preload(
	"res://scripts/characters/smasher_power_smash_motion_controller.gd"
)

# 원본 pingfighter.py 파워스매싱 발사 셰이크(콤보 c >= 2):
#   screen_shake_timer = 15 + c*2 프레임, screen_shake_intensity = 10 + c*2
#   진폭은 남은 타이머와 무관하게 일정하게 유지되다가 하드 스톱한다.
# 환격전 천뢰격은 같은 상수를 쓰면서도 감쇠 채널(진폭 x 남은 타이머)에 실려
# 최고 진폭이 1/3 토막 났었다. 이 스모크가 원본 배율 복원을 봉인한다.
const FRAME_DELTA := 1.0 / 60.0
const COMBO := 2
const EXPECTED_FRAMES := 19.0
const EXPECTED_INTENSITY := 14.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_sustained_channel_holds_then_hard_stops()
	_verify_sustained_channel_beats_decaying_channel()
	_verify_decaying_channel_unchanged()
	_verify_production_launch_path_uses_sustained_channel()
	_verify_reset_round_clears_sustained_channel()

	if _failures.is_empty():
		print("smasher_power_smash_screen_shake_parity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


class FakePowerState:
	extends RefCounted

	var combo: int = 0

	var _launched := false

	func _init(combo_consumed: int) -> void:
		combo = combo_consumed

	func is_freeze_active() -> bool:
		return not _launched

	func is_freeze_ball_locked() -> bool:
		return false

	func get_freeze_ball_pos() -> Vector2:
		return Vector2.ZERO

	func update_freeze(_delta: float, _duration: float) -> bool:
		_launched = true
		return true

	func get_combo_consumed() -> int:
		return combo


func _verify_sustained_channel_holds_then_hard_stops() -> void:
	var feedback := BattleFeedbackState.new()
	feedback.max_sustained_screen_shake(EXPECTED_FRAMES * FRAME_DELTA, EXPECTED_INTENSITY)
	_expect(
		is_equal_approx(feedback.get_shake_amplitude(), EXPECTED_INTENSITY),
		"sustained shake should start at the full original intensity"
	)

	# 원본은 지속 구간 내내 진폭이 줄지 않는다(사각 포락).
	var held := true
	for _frame in range(18):
		feedback.update(FRAME_DELTA, 1)
		if not is_equal_approx(feedback.get_shake_amplitude(), EXPECTED_INTENSITY):
			held = false
	_expect(held, "sustained shake amplitude should not decay inside the original frame budget")

	# 예산이 끝나면 잔여 없이 하드 스톱한다.
	for _tail in range(2):
		feedback.update(FRAME_DELTA, 1)
	_expect(
		feedback.get_shake_amplitude() == 0.0,
		"sustained shake should hard-stop once the original frame budget is spent"
	)
	_expect(
		feedback.get_shake_offset() == Vector2.ZERO,
		"expired sustained shake should not offset the screen"
	)

	# 실제 오프셋도 원본 진폭 폭 안에서 크게 흔들려야 한다.
	var sampler := BattleFeedbackState.new()
	sampler.max_sustained_screen_shake(EXPECTED_FRAMES * FRAME_DELTA, EXPECTED_INTENSITY)
	var within_bound := true
	var peak := 0.0
	for _sample in range(256):
		var offset: Vector2 = sampler.get_shake_offset()
		peak = maxf(peak, maxf(absf(offset.x), absf(offset.y)))
		if absf(offset.x) > EXPECTED_INTENSITY or absf(offset.y) > EXPECTED_INTENSITY:
			within_bound = false
	_expect(within_bound, "sustained shake offset should stay inside the original amplitude bound")
	_expect(
		peak > EXPECTED_INTENSITY * 0.5,
		"sustained shake offset should reach a large fraction of the original amplitude"
	)


func _verify_sustained_channel_beats_decaying_channel() -> void:
	# 회귀 진단 봉인: 같은 상수를 감쇠 채널에 실으면 최고 진폭이 1/3 토막 난다.
	var decaying := BattleFeedbackState.new()
	decaying.max_screen_shake(EXPECTED_FRAMES * FRAME_DELTA, EXPECTED_INTENSITY)
	var decaying_peak: float = decaying.get_shake_amplitude()
	var sustained := BattleFeedbackState.new()
	sustained.max_sustained_screen_shake(EXPECTED_FRAMES * FRAME_DELTA, EXPECTED_INTENSITY)
	var sustained_peak: float = sustained.get_shake_amplitude()
	_expect(
		is_equal_approx(decaying_peak, EXPECTED_INTENSITY * EXPECTED_FRAMES * FRAME_DELTA),
		"decaying channel peak should still be intensity times the remaining timer"
	)
	_expect(
		sustained_peak > decaying_peak * 3.0,
		"sustained channel peak should be more than triple the old decaying peak"
	)

	var decay_frames := 0
	while decaying.get_shake_amplitude() > 0.0 and decay_frames < 600:
		decaying.update(FRAME_DELTA, 1)
		decay_frames += 1
	var sustain_frames := 0
	while sustained.get_shake_amplitude() > 0.0 and sustain_frames < 600:
		sustained.update(FRAME_DELTA, 1)
		sustain_frames += 1
	_expect(
		sustain_frames >= decay_frames * 2 - 1,
		"sustained shake should last about twice the decaying channel (%d vs %d frames)"
			% [sustain_frames, decay_frames]
	)


func _verify_decaying_channel_unchanged() -> void:
	# 부정 leg: 기존 감쇠 호출부(랠리 타격 등)의 체감은 그대로여야 한다.
	var feedback := BattleFeedbackState.new()
	feedback.max_screen_shake(0.10, 2.6)
	_expect(
		is_equal_approx(feedback.get_shake_amplitude(), 2.6 * 0.10),
		"existing decaying callers should keep the intensity times timer amplitude"
	)
	feedback.update(FRAME_DELTA, 1)
	_expect(
		feedback.get_shake_amplitude() < 2.6 * 0.10,
		"decaying channel should still shrink every frame"
	)

	var quiet := BattleFeedbackState.new()
	_expect(
		quiet.get_shake_amplitude() == 0.0 and quiet.get_shake_offset() == Vector2.ZERO,
		"an untouched feedback state should not shake"
	)


func _verify_production_launch_path_uses_sustained_channel() -> void:
	var feedback := BattleFeedbackState.new()
	var controller := SmasherPowerSmashMotionController.new()
	controller.update_freeze(
		FRAME_DELTA,
		Vector2(380.0, 600.0),
		{"freeze_duration": 0.30},
		{"power_state": FakePowerState.new(COMBO), "feedback": feedback}
	)
	_expect(
		is_equal_approx(feedback.get_shake_amplitude(), EXPECTED_INTENSITY),
		"cheonroegyeok launch should publish the original sustained amplitude"
	)
	_expect(
		feedback.screen_shake == 0.0,
		"cheonroegyeok launch should not fall back to the decaying channel"
	)

	var held_frames := 0
	while feedback.get_shake_amplitude() > 0.0 and held_frames < 600:
		feedback.update(FRAME_DELTA, 1)
		held_frames += 1
	_expect(
		held_frames >= int(EXPECTED_FRAMES),
		"cheonroegyeok shake should hold the original frame budget (got %d)" % held_frames
	)

	# 부정 leg: 콤보 2 미만이면 원본과 같이 셰이크가 아예 없다.
	var low_combo_feedback := BattleFeedbackState.new()
	SmasherPowerSmashMotionController.new().update_freeze(
		FRAME_DELTA,
		Vector2(380.0, 600.0),
		{"freeze_duration": 0.30},
		{"power_state": FakePowerState.new(1), "feedback": low_combo_feedback}
	)
	_expect(
		low_combo_feedback.get_shake_amplitude() == 0.0,
		"combo below two should not shake at all, matching the original gate"
	)


func _verify_reset_round_clears_sustained_channel() -> void:
	var feedback := BattleFeedbackState.new()
	feedback.max_sustained_screen_shake(EXPECTED_FRAMES * FRAME_DELTA, EXPECTED_INTENSITY)
	feedback.reset_round(1)
	_expect(
		feedback.get_shake_amplitude() == 0.0,
		"round reset should clear a pending sustained shake"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
