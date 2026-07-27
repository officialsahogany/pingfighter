extends SceneTree

const LingpetDurationState := preload(
	"res://scripts/lingpet/lingpet_duration_state.gd"
)
const LingpetAffinityState := preload(
	"res://scripts/lingpet/lingpet_affinity_state.gd"
)
const LingpetSatietyRuntimeState := preload(
	"res://scripts/lingpet/lingpet_satiety_runtime_state.gd"
)

var _failures: Array[String] = []


class FakeCollectionState:
	extends RefCounted

	var auto_present_league := true

	func is_auto_present_league(_owner: Object) -> bool:
		return auto_present_league


func _init() -> void:
	_verify_drain_and_rest_ratio()
	_verify_real_tick_residue_snap()
	_verify_exhaustion_telegraph()
	_verify_league_exemption_latch_passthrough()
	_verify_owner_wiring()

	if _failures.is_empty():
		print("lingpet_duration_state_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_drain_and_rest_ratio() -> void:
	var state := LingpetDurationState.new()
	state.set_duration("maribo", 80.0)
	state.set_duration("lunabi", 20.0)
	var result: Dictionary = state.advance_duration(
		"maribo",
		["maribo", "lunabi", "lunabi", ""],
		3.0
	)
	_expect(bool(result.get("changed", false)), "duration tick should report mutation")
	_expect_float(
		state.get_duration("maribo"),
		78.44,
		"active pet should drain at the preserved per-second rate"
	)
	_expect_float(
		state.get_duration("lunabi"),
		20.52,
		"resting pet should recover at the preserved one-third ratio"
	)


func _verify_real_tick_residue_snap() -> void:
	var state := LingpetDurationState.new()
	var tick_delta := 1.0 / 60.0
	var tick_count := 7
	var real_tick_drain := LingpetDurationState.DRAIN_PER_SECOND * tick_delta
	state.set_duration(
		"maribo",
		real_tick_drain * float(tick_count) + LingpetDurationState.VALUE_SNAP_EPSILON * 0.5
	)
	for _tick in range(tick_count):
		state.advance_duration("maribo", ["maribo"], tick_delta)
	_expect_float(
		state.get_duration("maribo"),
		LingpetDurationState.DURATION_MIN,
		"real 60 Hz drain ticks should snap a positive sub-epsilon rail residue to zero",
		0.000001
	)


func _verify_exhaustion_telegraph() -> void:
	var state := LingpetDurationState.new()
	state.set_duration("maribo", 0.0)
	var winding: Dictionary = state.advance_exhaustion("maribo", 0.75)
	_expect(not bool(winding.get("exhausted", true)), "exhaustion should wait for the telegraph")
	_expect_float(float(winding.get("timer", 0.0)), 0.75, "telegraph timer should accumulate real delta")
	var exhausted: Dictionary = state.advance_exhaustion("maribo", 1.0)
	_expect(bool(exhausted.get("exhausted", false)), "telegraph threshold should latch exhaustion")
	_expect_float(
		float(exhausted.get("timer", 0.0)),
		LingpetDurationState.EXHAUSTION_TELEGRAPH_SECONDS,
		"exhaustion timer should preserve the 1.75 second threshold"
	)
	state.set_duration("maribo", LingpetDurationState.WAKE_THRESHOLD)
	_expect(not state.is_exhausted("maribo"), "wake threshold should clear exhaustion")
	_expect_float(state.get_exhaustion_timer("maribo"), 0.0, "wake threshold should clear the timer")


func _verify_league_exemption_latch_passthrough() -> void:
	var affinity := LingpetAffinityState.new()
	affinity.set_satiety("maribo", 0.0)
	affinity.advance_satiety_exhaustion(
		"maribo",
		LingpetDurationState.EXHAUSTION_TELEGRAPH_SECONDS
	)
	_expect(affinity.is_satiety_exhausted("maribo"), "fixture should begin exhausted")
	var runtime := LingpetSatietyRuntimeState.new()
	var collection := FakeCollectionState.new()
	var owner := RefCounted.new()
	runtime.latch_penalty_exempt(owner, collection)
	_expect(runtime.is_penalty_exempt(null, collection), "latched league exemption should survive a null-owner read")
	_expect(
		not runtime.is_companion_exhausted(true, "maribo", affinity, owner, collection),
		"league exemption should still mask duration-owner exhaustion"
	)
	_expect_float(
		runtime.get_speed_scale(true, "maribo", affinity, owner, collection),
		1.0,
		"league exemption should still pass neutral speed through the runtime fold"
	)
	runtime.advance_inactive()
	_expect(not runtime.is_penalty_exempt(null, collection), "inactive advance should clear the exemption latch")


func _verify_owner_wiring() -> void:
	var affinity_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_affinity_state.gd"
	)
	_expect(
		affinity_source.find("const LingpetDurationState := preload(") >= 0,
		"affinity facade should preload the duration owner"
	)
	_expect(
		affinity_source.find("_duration_state.advance_duration(") >= 0,
		"affinity facade should delegate duration progression"
	)
	_expect(
		affinity_source.find("func _sanitize_satiety_value(") < 0,
		"affinity facade should not retain the duration rail sanitizer"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(
	actual: float,
	expected: float,
	message: String,
	tolerance: float = 0.001
) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.6f, got %.6f)" % [message, expected, actual])
