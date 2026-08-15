extends SceneTree

const PlazaR3ProductionEntryHost := preload("res://scripts/plaza/plaza_r3_production_entry_host.gd")

const EXPECTED_LEGS := 3
const MIN_ASSERTIONS := {
	"normal_timeline": 14,
	"stalled_prewarm": 7,
	"duplicate_begin": 3,
}

class FakeLifecycle:
	extends Control

	var stalled := false
	var phase := "idle"
	var step := 0
	var begin_count := 0
	var activation_count := 0

	func begin_prewarm(_config: Dictionary) -> bool:
		begin_count += 1
		phase = "resource_base"
		visible = false
		return true

	func advance_prewarm_step() -> bool:
		if stalled:
			return false
		step += 1
		if step >= 3:
			phase = "ready"
			return true
		phase = "compile" if step == 1 else "gpu_submit"
		return false

	func get_prewarm_progress_snapshot() -> Dictionary:
		return {
			"phase": phase,
			"progress": 0.2 if stalled else minf(1.0, float(step) / 3.0),
			"progress_token": "stalled" if stalled else "%s:%d" % [phase, step],
		}

	func activate_exterior() -> bool:
		if phase != "ready":
			return false
		activation_count += 1
		phase = "exterior"
		visible = true
		return true

	func teardown_scene() -> void:
		phase = "torn_down"
		visible = false

	func get_debug_status() -> Dictionary:
		return {"phase": phase, "rejection_reason": ""}

	func get_layout_snapshot_for_test() -> Dictionary:
		return {"fingerprint": "fake-layout"}


var _failures: Array[String] = []
var _completed_legs: Dictionary = {}
var _assertions_by_leg: Dictionary = {}
var _current_leg := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_normal_timeline()
	await _verify_stalled_prewarm()
	await _verify_duplicate_begin()
	_verify_completion_gate()
	if _failures.is_empty():
		print("plaza_r3d_atomic_transition_smoke: ok legs=%d assertions=%d" % [
			_completed_legs.size(),
			_total_assertions(),
		])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_normal_timeline() -> void:
	_begin_leg("normal_timeline")
	var lifecycle := FakeLifecycle.new()
	var host := PlazaR3ProductionEntryHost.new()
	_expect(host.set_lifecycle_for_test(lifecycle), "fake lifecycle should inject before tree entry")
	root.add_child(host)
	_expect(host.begin_entry(_config()), "normal entry should begin")
	await process_frame
	await process_frame
	var loading_status := host.get_debug_status()
	_expect(bool(loading_status.get("loading_visible", false)), "loading cover should be visible immediately")
	_expect(int(loading_status.get("loading_draw_count", 0)) > 0, "loading cover should draw before readiness")
	_expect(not bool(loading_status.get("lifecycle_visible", true)), "R3 runtime must remain hidden while loading")
	_expect(not host.advance_entry(1.0 / 72.0), "step one should remain loading")
	_expect(not host.advance_entry(1.0 / 72.0), "step two should remain loading")
	_expect(host.advance_entry(1.0 / 72.0), "step three should reach ready")
	_expect(not bool(host.get_debug_status().get("lifecycle_visible", true)), "ready runtime must remain hidden before activation")
	_expect(host.activate_under_loading(), "ready runtime should activate under opaque cover")
	var covered := host.get_debug_status()
	_expect(bool(covered.get("loading_visible", false)), "loading must still cover the activated runtime")
	_expect(bool(covered.get("lifecycle_visible", false)), "runtime should be active under the cover")
	_expect(host.finish_atomic_reveal(), "atomic reveal should succeed")
	var revealed := host.get_debug_status()
	_expect(not bool(revealed.get("loading_visible", true)), "loading must hide at reveal")
	_expect(int(revealed.get("atomic_reveal_count", 0)) == 1, "atomic reveal must happen exactly once")
	_expect(int(revealed.get("pre_reveal_runtime_visible_count", -1)) == 0, "runtime must never be visible during prewarm")
	_expect(int(revealed.get("loading_first_draw_usec", -1)) <= int(revealed.get("prewarm_ready_usec", -2)), "loading draw must precede readiness")
	_expect(int(revealed.get("prewarm_ready_usec", -1)) <= int(revealed.get("activation_usec", -2)), "activation must follow readiness")
	_expect(int(revealed.get("activation_usec", -1)) <= int(revealed.get("loading_hidden_usec", -2)), "loading hide must follow activation")
	host.teardown_scene()
	host.queue_free()
	_complete_leg("normal_timeline")


func _verify_stalled_prewarm() -> void:
	_begin_leg("stalled_prewarm")
	var lifecycle := FakeLifecycle.new()
	lifecycle.stalled = true
	var host := PlazaR3ProductionEntryHost.new()
	_expect(host.set_lifecycle_for_test(lifecycle), "stalled lifecycle should inject")
	root.add_child(host)
	_expect(host.begin_entry(_config()), "stalled entry should still begin loading")
	await process_frame
	for _index in range(PlazaR3ProductionEntryHost.MAX_STALLED_UPDATE_COUNT + 2):
		host.advance_entry(1.0 / 72.0)
	var status := host.get_debug_status()
	_expect(bool(host.is_rejected()), "stalled lifecycle must reach explicit rejection")
	_expect(str(status.get("rejection_reason", "")) == "prewarm_stalled", "stalled lifecycle should report the bounded reason")
	_expect(int(status.get("stalled_update_count", 0)) > PlazaR3ProductionEntryHost.MAX_STALLED_UPDATE_COUNT, "stall counter should cross the finite budget")
	_expect(bool(status.get("loading_visible", false)), "explicit error must remain visible")
	_expect(not bool(status.get("lifecycle_visible", true)), "stalled runtime must never be exposed")
	_expect(int(status.get("atomic_reveal_count", -1)) == 0, "stalled prewarm must not reveal")
	host.queue_free()
	_complete_leg("stalled_prewarm")


func _verify_duplicate_begin() -> void:
	_begin_leg("duplicate_begin")
	var host := PlazaR3ProductionEntryHost.new()
	_expect(host.set_lifecycle_for_test(FakeLifecycle.new()), "duplicate fixture should inject")
	root.add_child(host)
	_expect(host.begin_entry(_config()), "first begin should succeed")
	_expect(not host.begin_entry(_config()), "second begin should fail closed")
	host.queue_free()
	_complete_leg("duplicate_begin")


func _config() -> Dictionary:
	return {
		"stage_id": 4,
		"map_seed": 12,
		"render_size": Vector2(2020.0, 1246.0),
		"selected_character_type": "smasher",
	}


func _begin_leg(name: String) -> void:
	_current_leg = name
	_assertions_by_leg[name] = 0


func _complete_leg(name: String) -> void:
	if _current_leg != name:
		_failures.append("GRT-040 leg completion order mismatch:%s" % name)
	if _completed_legs.has(name):
		_failures.append("GRT-040 duplicate leg completion:%s" % name)
	_completed_legs[name] = true
	_current_leg = ""


func _expect(condition: bool, message: String) -> void:
	if _current_leg != "":
		_assertions_by_leg[_current_leg] = int(_assertions_by_leg.get(_current_leg, 0)) + 1
	if not condition:
		_failures.append(message)


func _verify_completion_gate() -> void:
	if _completed_legs.size() != EXPECTED_LEGS:
		_failures.append("GRT-040 expected %d completed legs, got %d" % [EXPECTED_LEGS, _completed_legs.size()])
	for leg in MIN_ASSERTIONS.keys():
		var actual := int(_assertions_by_leg.get(leg, 0))
		var minimum := int(MIN_ASSERTIONS.get(leg, 1))
		if actual < minimum:
			_failures.append("GRT-040 leg %s executed %d assertions, expected at least %d" % [leg, actual, minimum])


func _total_assertions() -> int:
	var total := 0
	for value in _assertions_by_leg.values():
		total += int(value)
	return total
