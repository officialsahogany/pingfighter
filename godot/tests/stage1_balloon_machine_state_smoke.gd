extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage1BalloonMachineState := preload("res://scripts/stages/stage1/stage1_balloon_machine_state.gd")


class AudioStub:
	var events: Array[String] = []

	func play_stage1_balloon_door() -> void:
		events.append("door")

	func play_stage1_balloon_machine() -> void:
		events.append("machine")

	func play_stage1_balloon_pop() -> void:
		events.append("pop")


class HostStub:
	var prewarm_calls := 0
	var shot_indices: Array[int] = []

	func _prewarm_active_event_assets() -> void:
		prewarm_calls += 1

	func _shoot_single_balloon(index: int, _deps: Dictionary) -> void:
		shot_indices.append(index)


var _failed := false


func _init() -> void:
	_verify_activation_rng_order()
	_verify_special_balloon_payout_contract()
	_verify_cooldown_activation_and_active_timeline()
	_verify_facade_shot_callback_integration()
	_verify_reset_and_stage_exit_compatibility()
	_verify_source_ownership()
	if _failed:
		quit(1)
		return
	print("stage1_balloon_machine_state_smoke: ok")
	quit(0)


func _verify_activation_rng_order() -> void:
	var state := Stage1BalloonMachineState.new()
	seed(51041)
	state.activate()
	var actual_count: int = state.total_balloon_count
	var actual_order: Array[int] = state.balloon_shoot_order.duplicate()
	var actual_special: Array[int] = state.special_balloon_indices.duplicate()
	var actual_angles: Array[float] = state.balloon_shoot_angles.duplicate()

	seed(51041)
	var expected_count := randi_range(2, 4)
	var expected_order := _build_shuffled_indices(expected_count)
	var special_candidates := _build_shuffled_indices(expected_count)
	var special_count := _roll_special_balloon_count(expected_count)
	var expected_special: Array[int] = []
	for index in range(special_count):
		expected_special.append(special_candidates[index])
	var expected_angles := _build_shoot_angles(expected_count)

	_expect(actual_count == expected_count, "activation should preserve the global-RNG balloon count")
	_expect(actual_order == expected_order, "activation should preserve shuffled balloon sprite order")
	_expect(actual_special == expected_special, "activation should preserve special-balloon selection order")
	_expect(actual_angles == expected_angles, "activation should preserve shoot-angle RNG and shuffle order")


func _verify_special_balloon_payout_contract() -> void:
	_expect(Stage1BalloonMachineState.SPECIAL_BALLOON_GUARANTEED_COUNT == 2, "starpoint balloon payout should guarantee two per activation")
	_expect(Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT == 4, "starpoint balloon payout should cap at four per activation")
	_expect(is_equal_approx(Stage1BalloonMachineState.SPECIAL_BALLOON_PRESENT_CHANCE, 0.75), "odds of paying above the guaranteed floor should stay at 75%")

	var guaranteed: int = Stage1BalloonMachineState.SPECIAL_BALLOON_GUARANTEED_COUNT
	var state := Stage1BalloonMachineState.new()
	var samples := 6000
	var min_observed: int = Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT + 1
	var max_observed := 0
	var extras_eligible := 0
	var extras_paid := 0
	var observed_counts := {}
	var entry_failed := _failed
	seed(90210)
	for _index in range(samples):
		if _failed != entry_failed:
			return
		state.active = false
		state.activate()
		var total: int = state.total_balloon_count
		var special: int = state.special_balloon_indices.size()
		var floor_for_volley: int = min(guaranteed, total)
		_expect(special >= floor_for_volley, "an activation must always pay the guaranteed golden balloon floor")
		_expect(special <= Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT, "an activation must never exceed the golden balloon cap")
		_expect(special <= total, "golden balloons must never outnumber the volley's balloons")
		_expect(state.special_balloon_indices.size() == _unique_count(state.special_balloon_indices), "golden balloon slots must be distinct")
		for slot in state.special_balloon_indices:
			_expect(int(slot) >= 0 and int(slot) < total, "golden balloon slots must index a shot balloon")
		if total > floor_for_volley:
			extras_eligible += 1
			if special > floor_for_volley:
				extras_paid += 1
		min_observed = min(min_observed, special)
		max_observed = max(max_observed, special)
		observed_counts[special] = int(observed_counts.get(special, 0)) + 1

	_expect(min_observed == guaranteed, "no activation should ever fall below the guaranteed golden balloon floor (got %d)" % min_observed)
	_expect(int(observed_counts.get(0, 0)) == 0, "a zero-golden activation must be unreachable under the guaranteed floor")
	_expect(int(observed_counts.get(1, 0)) == 0, "a single-golden activation must be unreachable under the guaranteed floor")
	_expect(extras_eligible > 0, "the sample should include volleys able to pay above the floor")
	var extras_ratio: float = float(extras_paid) / float(max(1, extras_eligible))
	_expect(extras_ratio >= 0.73 and extras_ratio <= 0.77, "about 75%% of volleys able to exceed the floor should do so (got %.4f)" % extras_ratio)
	_expect(max_observed == Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT, "a four-golden activation must be reachable")
	for expected_bucket in [2, 3, 4]:
		_expect(int(observed_counts.get(expected_bucket, 0)) > 0, "every golden balloon count from the floor to the cap should be reachable")

	_verify_special_balloon_floor_reverse_leg()


func _verify_special_balloon_floor_reverse_leg() -> void:
	# Reverse leg: a failed extras gate must land exactly on the floor and never below
	# it, and a volley already sitting at the floor must pay every balloon as golden.
	var state := Stage1BalloonMachineState.new()
	var guaranteed: int = Stage1BalloonMachineState.SPECIAL_BALLOON_GUARANTEED_COUNT
	var floor_only := 0
	var above_floor := 0
	var entry_failed := _failed
	seed(1337)
	for _index in range(4000):
		if _failed != entry_failed:
			return
		var rolled: int = state._roll_special_balloon_count(Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT)
		_expect(rolled >= guaranteed, "a failed extras gate must fall back to the floor, not below it")
		if rolled == guaranteed:
			floor_only += 1
		else:
			above_floor += 1
	_expect(floor_only > 0, "the failed extras gate branch must be reachable")
	_expect(above_floor > 0, "the passed extras gate branch must be reachable")

	seed(4242)
	for _index in range(200):
		if _failed != entry_failed:
			return
		_expect(state._roll_special_balloon_count(guaranteed) == guaranteed, "a volley already at the floor must pay every balloon as golden")
		_expect(state._roll_special_balloon_count(0) == 0, "an empty volley must pay no golden balloons")


func _unique_count(values: Array[int]) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()


func _roll_special_balloon_count(count: int) -> int:
	var max_special: int = min(Stage1BalloonMachineState.SPECIAL_BALLOON_MAX_COUNT, count)
	if max_special <= 0:
		return 0
	var guaranteed: int = min(Stage1BalloonMachineState.SPECIAL_BALLOON_GUARANTEED_COUNT, max_special)
	var extras_gate: float = randf()
	if guaranteed >= max_special or extras_gate >= Stage1BalloonMachineState.SPECIAL_BALLOON_PRESENT_CHANCE:
		return guaranteed
	return randi_range(guaranteed + 1, max_special)


func _verify_cooldown_activation_and_active_timeline() -> void:
	var state := Stage1BalloonMachineState.new()
	var audio := AudioStub.new()
	var host := HostStub.new()
	state.cooldown_timer = 0.0
	state.update(0.0, {"audio": audio}, host)
	_expect(state.active and state.phase == "door_opening", "ready cooldown should activate without advancing the first active frame")
	_expect(host.prewarm_calls == 0 and audio.events.is_empty(), "activation frame should not prewarm or emit phase audio")

	state.update(1.0, {"audio": audio}, host)
	_expect(host.prewarm_calls == 1, "first active frame should prewarm through the host before timeline work")
	_expect(audio.events == ["door"], "door opening should emit one start-edge cue")
	state.update(1.0, {"audio": audio}, host)
	_expect(audio.events == ["door"], "door cue should not repeat after the phase start edge")

	state.phase = "shooting"
	state.timer_frames = 0.0
	state.balloon_shoot_timer = 0.0
	state.balloon_shoot_count = 0
	state.total_balloon_count = 2
	state.update(Stage1BalloonMachineState.SHOOT_INTERVAL * 2.0, {"audio": audio}, host)
	_expect(host.shot_indices == [0, 1], "shooting update should publish every elapsed shot in index order")
	_expect(state.balloon_shoot_count == 2 and state.phase == "shooting_wait", "completed volley should enter the shooting wait phase")


func _verify_facade_shot_callback_integration() -> void:
	var event := Stage1BalloonEvent.new()
	var audio := AudioStub.new()
	event.active = true
	event.phase = "shooting"
	event.timer_frames = 0.0
	event.balloon_shoot_timer = 0.0
	event.balloon_shoot_count = 0
	event.total_balloon_count = 2
	event.balloon_shoot_order = [0, 1]
	event.special_balloon_indices = []
	event.balloon_shoot_angles = [0.0, PI]
	event._update_machine(Stage1BalloonMachineState.SHOOT_INTERVAL * 2.0, {"audio": audio})
	_expect(event.balloons.size() == 2, "machine owner callbacks should create both live facade balloons")
	_expect(audio.events.count("pop") == 2, "each machine-owner shot callback should retain pop audio")
	_expect(event.phase == "shooting_wait", "facade callback integration should publish the completed phase")


func _verify_reset_and_stage_exit_compatibility() -> void:
	var state := Stage1BalloonMachineState.new()
	state.activate()
	state.door_open_percent = 0.75
	state.machine_scale = 0.65
	state.reset()
	_expect(not state.active and state.phase == "idle", "reset should restore idle machine state")
	_expect(is_zero_approx(state.timer_frames) and is_zero_approx(state.door_open_percent) and is_zero_approx(state.machine_scale), "reset should clear live phase presentation")
	_expect(state.cooldown_timer >= Stage1BalloonMachineState.MIN_COOLDOWN_FRAMES, "reset should reroll the minimum cooldown")
	_expect(state.cooldown_timer <= Stage1BalloonMachineState.MAX_COOLDOWN_FRAMES, "reset should reroll within the maximum cooldown")

	var event := Stage1BalloonEvent.new()
	event.active = true
	event.phase = "machine_rising"
	event.timer_frames = 17.0
	event.update(1.0 / 60.0, {"current_stage": 2}, {})
	_expect(event.active and event.phase == "machine_rising" and is_equal_approx(event.timer_frames, 17.0), "leaving Stage 1 should keep the legacy frozen machine timeline")
	event.reset()
	_expect(not event.active and event.phase == "idle", "facade reset should delegate machine cleanup")


func _verify_source_ownership() -> void:
	var facade_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_machine_state.gd")
	_expect(facade_source.contains("Stage1BalloonMachineState"), "balloon facade should preload the machine owner")
	_expect(facade_source.contains("var machine_state: Object = Stage1BalloonMachineState.new()"), "balloon facade should retain one machine owner")
	_expect(not facade_source.contains("var active := false"), "balloon facade should not retain a mirrored active flag")
	_expect(not facade_source.contains("var phase := \"idle\""), "balloon facade should not retain a mirrored machine phase")
	_expect(_method_source(facade_source, "_activate").contains("machine_state.activate"), "activation compatibility method should delegate")
	_expect(_method_source(facade_source, "_update_machine").contains("machine_state.update_active"), "active timeline compatibility method should delegate")
	_expect(_method_source(facade_source, "_set_phase").contains("machine_state.set_phase"), "phase compatibility method should delegate")
	_expect(_method_source(facade_source, "_deactivate").contains("machine_state.deactivate"), "deactivation compatibility method should delegate")
	_expect(_method_source(facade_source, "_set_next_cooldown").contains("machine_state.set_next_cooldown"), "cooldown compatibility method should delegate")
	_expect(owner_source.contains("host.call(\"_prewarm_active_event_assets\")"), "machine owner should retain prewarm-before-phase ordering")
	_expect(owner_source.contains("host.call(\"_shoot_single_balloon\", balloon_shoot_count, deps)"), "machine owner should retain ordered host shot callbacks")


func _build_shuffled_indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(count):
		result.append(index)
	result.shuffle()
	return result


func _build_shoot_angles(count: int) -> Array[float]:
	var result: Array[float] = []
	for index in range(count):
		result.append(TAU / float(count) * float(index) + randf_range(-PI / 12.0, PI / 12.0))
	result.shuffle()
	return result


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
