extends SceneTree

const LingpetAffinityFeedbackState := preload("res://scripts/lingpet/lingpet_affinity_feedback_state.gd")
const LingpetAffinityGrantController := preload("res://scripts/lingpet/lingpet_affinity_grant_controller.gd")
const LingpetAffinityIncomeTracker := preload("res://scripts/lingpet/lingpet_affinity_income_tracker.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")

var _failures: Array[String] = []


class FakePerfLogger:
	extends RefCounted

	var totals: Dictionary = {}

	func record_counter_sample(label: String, value: float) -> void:
		totals[label] = float(totals.get(label, 0.0)) + value


class FakeRegistry:
	extends RefCounted

	var perf_logger: Object
	var game_audio: Object

	func _init(perf_logger_value: Object, game_audio_value: Object) -> void:
		perf_logger = perf_logger_value
		game_audio = game_audio_value

	func get_instance(key: String) -> Object:
		match key:
			"battle_perf_logger":
				return perf_logger
			"game_audio":
				return game_audio
		return null


class FakeAudio:
	extends RefCounted

	var feedback_state: Object
	var level_up_count := 0
	var feedback_trigger_count_at_play := -1

	func _init(feedback_state_value: Object) -> void:
		feedback_state = feedback_state_value

	func play_lingpet_affinity_level_up() -> void:
		level_up_count += 1
		feedback_trigger_count_at_play = int(feedback_state.trigger_count)


class CallbackProbe:
	extends RefCounted

	var feedback_state: Object
	var events: Array[String] = []
	var sync_trigger_count := -1
	var synced_pet_id := ""
	var synced_registry: Object = null

	func _init(feedback_state_value: Object) -> void:
		feedback_state = feedback_state_value

	func on_level_gain(pet_id: String, registry: Object = null) -> void:
		events.append("sync")
		sync_trigger_count = int(feedback_state.trigger_count)
		synced_pet_id = pet_id
		synced_registry = registry

func _init() -> void:
	_run()


func _run() -> void:
	_verify_grant_lifecycle_and_ordering()
	_verify_blocked_and_non_current_feedback_gates()
	_verify_source_ownership()

	if _failures.is_empty():
		print("lingpet_affinity_grant_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_grant_lifecycle_and_ordering() -> void:
	var controller := LingpetAffinityGrantController.new()
	var state := LingpetAffinityState.new()
	var tracker := LingpetAffinityIncomeTracker.new()
	var feedback := LingpetAffinityFeedbackState.new()
	var perf_logger := FakePerfLogger.new()
	var audio := FakeAudio.new(feedback)
	var registry := FakeRegistry.new(perf_logger, audio)
	var probe := CallbackProbe.new(feedback)
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)

	for _i in range(10):
		controller.grant(
			"maribo",
			LingpetAffinityState.SOURCE_ROUND_COMMIT,
			{},
			registry,
			state,
			tracker,
			feedback,
			true,
			true,
			Callable(probe, "on_level_gain")
		)

	_expect_eq(state.get_level("maribo"), 1, "ten round commits should reach affinity Lv.1")
	_expect_float(float(tracker.get_summary().get("total", 0.0)), 50.0, "grant controller should record all granted affinity income")
	_expect_float(float(perf_logger.totals.get("lingpet.affinity.income.round_commit", 0.0)), 50.0, "grant controller should preserve the source BattlePerf counter")
	_expect_eq(feedback.trigger_count, 1, "grant controller should trigger one level-up feedback event")
	_expect_eq(probe.events.size(), 1, "level-up should dispatch the profile-sync callback exactly once")
	if probe.events.size() == 1:
		_expect_str(probe.events[0], "sync", "profile sync should run before level-up feedback audio")
	_expect_eq(probe.sync_trigger_count, 0, "profile sync callback should run before feedback is triggered")
	_expect_eq(audio.level_up_count, 1, "grant controller should dispatch level-up audio exactly once")
	_expect_eq(audio.feedback_trigger_count_at_play, 1, "grant controller should play audio after feedback is triggered")
	_expect_str(probe.synced_pet_id, "maribo", "level-gain callback should receive the normalized pet id")
	_expect(probe.synced_registry == registry, "level-gain callback should preserve the grant registry")
	var popups: Array = feedback.get_point_popups()
	_expect(popups.size() == 1, "rapid current-companion gains should coalesce into one popup")
	if not popups.is_empty():
		_expect_float(float((popups[0] as Dictionary).get("amount", 0.0)), 50.0, "coalesced popup should contain the full granted amount")


func _verify_blocked_and_non_current_feedback_gates() -> void:
	var controller := LingpetAffinityGrantController.new()
	var state := LingpetAffinityState.new()
	var tracker := LingpetAffinityIncomeTracker.new()
	var feedback := LingpetAffinityFeedbackState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)

	var first: Dictionary = controller.grant(
		"maribo",
		LingpetAffinityState.SOURCE_HATCH,
		{},
		null,
		state,
		tracker,
		feedback,
		true,
		true
	)
	var popup_amount_before := _latest_popup_amount(feedback)
	var total_before := float(tracker.get_summary().get("total", 0.0))
	var blocked: Dictionary = controller.grant(
		"maribo",
		LingpetAffinityState.SOURCE_HATCH,
		{},
		null,
		state,
		tracker,
		feedback,
		true,
		true
	)
	_expect(float(first.get("granted_points", 0.0)) > 0.0, "first hatch grant should succeed")
	_expect_float(float(blocked.get("granted_points", -1.0)), 0.0, "duplicate hatch grant should remain blocked")
	_expect_float(_latest_popup_amount(feedback), popup_amount_before, "blocked grants should not spawn or merge point popups")
	_expect_float(float(tracker.get_summary().get("total", 0.0)), total_before, "blocked grants should not increase the income tracker")

	feedback.reset_transients()
	controller.grant(
		"lunabi",
		LingpetAffinityState.SOURCE_ROUND_COMMIT,
		{},
		null,
		state,
		tracker,
		feedback,
		false,
		true
	)
	_expect((feedback.get_point_popups() as Array).is_empty(), "non-current pet grants should not create companion point popups")


func _verify_source_ownership() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_grant_controller.gd")
	_expect(runtime_source.find("LingpetAffinityGrantController") >= 0, "egg runtime should delegate configured affinity grants to the focused controller")
	_expect(runtime_source.find("_affinity_income_tracker.record") < 0, "egg runtime should not retain affinity income-recording ownership")
	_expect(runtime_source.find("play_lingpet_affinity_level_up") < 0, "egg runtime should not retain affinity level-up audio dispatch")
	_expect(controller_source.find("income_tracker.record") >= 0, "grant controller should own affinity income recording")
	_expect(controller_source.find("trigger_point_gain") >= 0 and controller_source.find("trigger_level_up") >= 0, "grant controller should own point and level-up feedback dispatch")
	_expect(controller_source.find("play_lingpet_affinity_level_up") >= 0, "grant controller should own level-up audio dispatch")


func _latest_popup_amount(feedback: Object) -> float:
	var popups: Array = feedback.get_point_popups()
	if popups.is_empty():
		return 0.0
	return float((popups[popups.size() - 1] as Dictionary).get("amount", 0.0))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
