extends SceneTree

const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const TEST_SCENE_PATH := "res://scenes/main_menu.tscn"

var failure_count: int = 0


func _init() -> void:
	var prewarm := CharacterSelectPrewarm.new()
	prewarm.begin(TEST_SCENE_PATH)
	_expect(prewarm.active, "prewarm should be active after begin")

	prewarm.cancel_and_drain_current_request()
	_expect(not prewarm.active, "cancel should deactivate the prewarm")
	_expect(prewarm.finished, "cancel should leave the prewarm terminal")
	_expect(prewarm.jobs.is_empty(), "cancel should discard jobs that were not requested")
	_expect(prewarm.current_path == "", "cancel should release the current threaded request path")
	_expect(prewarm.current_job.is_empty(), "cancel should clear current job metadata")
	_expect(is_equal_approx(prewarm.get_progress(), 1.0), "canceled terminal state should report complete progress")
	_expect(prewarm.get_loaded_scene() == null, "cancel should not retain a scene for a dead owner")
	_expect(prewarm.update(), "a canceled prewarm should remain terminal on later updates")

	# Repeated teardown calls must be harmless because scene exit and test
	# cleanup can converge on the same owner.
	prewarm.cancel_and_drain_current_request()
	_expect(prewarm.finished, "cancel should be idempotent")

	if failure_count > 0:
		quit(1)
		return
	print("character_select_prewarm_cancel_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
