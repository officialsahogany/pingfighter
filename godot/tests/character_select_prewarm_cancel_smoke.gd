extends SceneTree

const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const TEST_SCENE_PATH := "res://scenes/main_menu.tscn"

var failure_count: int = 0


func _init() -> void:
	_verify_headless_sync_contract()
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


func _verify_headless_sync_contract() -> void:
	_expect(
		CharacterSelectPrewarm.is_synchronous_headless_prewarm_requested(
			PackedStringArray(["--unrelated", CharacterSelectPrewarm.HEADLESS_SYNC_PREWARM_ARG])
		),
		"the explicit headless sync arg should select synchronous prewarm"
	)
	_expect(
		not CharacterSelectPrewarm.is_synchronous_headless_prewarm_requested(
			PackedStringArray(["--ringpia-headless-load-quit-after=1200"])
		),
		"the graceful-quit arg alone must preserve the normal threaded prewarm path"
	)
	var wrapper_source := FileAccess.get_file_as_string("res://tools/run_headless_load_check.ps1")
	_expect(
		wrapper_source.find(CharacterSelectPrewarm.HEADLESS_SYNC_PREWARM_ARG) >= 0,
		"the full-project headless wrapper should opt into synchronous prewarm explicitly"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
