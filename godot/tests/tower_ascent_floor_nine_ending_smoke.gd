extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentEndingLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_ending_localization.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var save_path := "user://tower_ascent_floor_nine_ending_%d.cfg" % Time.get_ticks_usec()
	_cleanup(save_path)
	_verify_first_clear_and_snapshot_resume(save_path)
	_verify_reclear_does_not_repeat_teaser(save_path)
	_cleanup(save_path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_floor_nine_ending_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_first_clear_and_snapshot_resume(save_path: String) -> void:
	var flow := _begin_flow(save_path, "ending-first")
	_expect(flow != null, "first-clear fixture should start")
	if flow == null:
		return
	var result: Dictionary = flow.begin_floor_nine_resolution("ending-first:floor09")
	_expect(bool(result.get("accepted", false)), "first floor-nine judgment should commit")
	_expect(flow.get_phase_name() == "FAKE_ENDING_TEASER", "first clear should open teaser, not a choice modal")
	var ending: Dictionary = flow.get_ending_state_snapshot()
	_expect(str(ending.get("judgment", "")) == "standard_clear", "first clear must resolve STANDARD_CLEAR")
	_expect(not bool(ending.get("choice_required", true)), "first clear must not show the continue-choice modal")
	_expect(bool(ending.get("terminal_committed", false)), "standard clear must commit before settlement")
	var records: Dictionary = flow.get_record_snapshot()
	_expect(bool(records.get("fake_ending_cleared", false)), "first clear should persist fake-ending completion immediately")
	_expect(int(records.get("clear_count", -1)) == 1, "first clear should increment the persistent clear count once")

	var view_model: Dictionary = flow.get_ending_view_model()
	var body := str(view_model.get("body", ""))
	_expect(body == "왕의 시련은 아직 끝나지 않았다", "teaser copy should match the canonical Korean promise")
	_expect(body.find("—") < 0 and body.find("–") < 0, "player-facing teaser copy must not use dash punctuation")
	var registered_keys := TowerAscentEndingLocalization.get_registered_keys()
	_expect(
		registered_keys.has(TowerAscentEndingLocalization.KEY_TEASER_TITLE)
			and registered_keys.has(TowerAscentEndingLocalization.KEY_TEASER_BODY)
			and registered_keys.has(TowerAscentEndingLocalization.KEY_TEASER_PROMPT),
		"all teaser localization keys should remain registered"
	)

	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "teaser should be a stable snapshot boundary")
	_expect((snapshot.get("ending_state", {}) as Dictionary) == ending, "snapshot should own judgment and presentation flags")
	var restored := TowerAscentFlowOwner.new()
	restored.set_record_store_path_for_tests(save_path)
	_expect(restored.restore_snapshot(snapshot), "crash resume should restore the pending teaser")
	_expect(restored.get_phase_name() == "FAKE_ENDING_TEASER", "resume should not duplicate or skip the teaser")
	var duplicate: Dictionary = restored.begin_floor_nine_resolution("ending-first:floor09")
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("changed", true)), "replayed judgment should be idempotent")
	_expect(int(restored.get_record_snapshot().get("clear_count", -1)) == 1, "crash replay must not duplicate persistent clear count")

	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	_expect(restored.handle_input(confirm), "pending teaser should consume confirm input")
	_expect(not restored.is_active(), "teaser confirm should close the tower overlay")
	_expect(bool(restored.get_ending_state_snapshot().get("teaser_presented", false)), "teaser execution flag should advance once")
	_expect(not restored.handle_input(confirm), "closed teaser must not execute twice")


func _verify_reclear_does_not_repeat_teaser(save_path: String) -> void:
	var flow := _begin_flow(save_path, "ending-reclear")
	_expect(flow != null, "reclear fixture should start")
	if flow == null:
		return
	var result: Dictionary = flow.begin_floor_nine_resolution("ending-reclear:floor09")
	_expect(bool(result.get("accepted", false)), "reclear judgment should resolve")
	var ending: Dictionary = flow.get_ending_state_snapshot()
	_expect(str(ending.get("judgment", "")) == "choice_required", "reclear should reserve the later continue-choice path")
	_expect(not bool(ending.get("teaser_required", true)), "reclear must not repeat the first-clear teaser")
	_expect(flow.get_phase_name() == "ENDING_CHOICE", "reclear should open the item-3 choice modal only after the prior fake-ending record")
	_expect(int(flow.get_record_snapshot().get("clear_count", -1)) == 1, "judgment alone must not record a second clear")


func _begin_flow(save_path: String, run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": run_id,
		"current_stage": 9,
		"map_seed": 9409,
	}):
		return null
	return flow


func _cleanup(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
