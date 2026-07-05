extends SceneTree

const StageClearResultPlazaProgressHandler := preload("res://scripts/core/stage_clear_result_plaza_progress_handler.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var runtime_perk_gold := 0


class FakeSaveStore:
	extends RefCounted

	var call_count := 0
	var total_gold := 0
	var ap_grants := 0
	var last_stage := 0
	var save_path := "res://.tmp/stage_clear_result_plaza_progress_handler_smoke.cfg"

	func apply_stage_clear_progress(stage_id: int, gold_amount: int, grant_ap: bool) -> Dictionary:
		call_count += 1
		last_stage = stage_id
		total_gold += max(0, gold_amount)
		if grant_ap:
			ap_grants += 1
		return {
			"stage": stage_id,
			"transferred_gold": max(0, gold_amount),
			"granted_ap": 1 if grant_ap else 0,
			"plaza_gold": total_gold,
			"ap_current": ap_grants,
			"save": "ok",
			"save_path": save_path,
		}

	func get_summary() -> Dictionary:
		return {
			"save_path": save_path,
			"plaza_gold": total_gold,
			"ap_current": ap_grants,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_progress_is_applied_once()
	_verify_callback_context_adapter()
	_verify_reset_rearms_progress()
	_verify_missing_inputs_are_reported()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_plaza_progress_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_progress_is_applied_once() -> void:
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 321
	var save_store := FakeSaveStore.new()
	var handler := StageClearResultPlazaProgressHandler.new()

	var summary: Dictionary = handler.apply_stage_clear_progress_once(owner, save_store, 5, true)
	_expect(int(summary.get("stage", 0)) == 5, "progress handler should forward the current stage")
	_expect(int(summary.get("transferred_gold", 0)) == 321, "progress handler should transfer volatile runtime perk gold")
	_expect(int(summary.get("granted_ap", 0)) == 1, "progress handler should grant stage-clear AP when requested")
	_expect(owner.runtime_perk_gold == 0, "progress handler should consume volatile runtime perk gold")
	_expect(StageClearResultPlazaProgressHandler.get_plaza_save_path(save_store) == save_store.save_path, "progress handler should expose the plaza save path")

	summary = handler.apply_stage_clear_progress_once(owner, save_store, 5, true)
	_expect(int(summary.get("transferred_gold", -1)) == 0, "progress handler should not transfer gold twice")
	_expect(int(summary.get("granted_ap", -1)) == 0, "progress handler should not grant AP twice")
	_expect(save_store.total_gold == 321, "progress handler should keep saved gold idempotent")
	_expect(save_store.ap_grants == 1, "progress handler should keep saved AP idempotent")
	_expect(int(handler.get_cached_summary().get("plaza_gold", 0)) == 321, "progress handler should cache the last save summary")


func _verify_callback_context_adapter() -> void:
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 44
	var save_store := FakeSaveStore.new()
	var handler := StageClearResultPlazaProgressHandler.new()
	var callback := Callable(handler, "apply_stage_clear_progress_from_callback").bind(owner, save_store, 4)
	var summary: Dictionary = callback.call(true)
	_expect(int(summary.get("stage", 0)) == 4, "progress callback adapter should preserve the bound stage")
	_expect(int(summary.get("transferred_gold", 0)) == 44, "progress callback adapter should preserve the bound owner")
	_expect(int(summary.get("granted_ap", 0)) == 1, "progress callback adapter should consume the call-time AP flag")


func _verify_reset_rearms_progress() -> void:
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 12
	var save_store := FakeSaveStore.new()
	var handler := StageClearResultPlazaProgressHandler.new()
	handler.apply_stage_clear_progress_once(owner, save_store, 1, true)
	handler.reset()
	owner.runtime_perk_gold = 7
	var summary: Dictionary = handler.apply_stage_clear_progress_once(owner, save_store, 2, false)
	_expect(int(summary.get("transferred_gold", 0)) == 7, "reset should allow a later result screen to transfer gold again")
	_expect(int(summary.get("granted_ap", -1)) == 0, "grant_ap false should skip the AP reward")
	_expect(save_store.total_gold == 19, "reset should not erase the persistent save store")


func _verify_missing_inputs_are_reported() -> void:
	var handler := StageClearResultPlazaProgressHandler.new()
	var missing_owner_summary: Dictionary = handler.apply_stage_clear_progress_once(null, FakeSaveStore.new(), 1, true)
	_expect(str(missing_owner_summary.get("save", "")) == "skipped_missing_runtime_perk_gold_owner", "progress handler should report missing runtime gold owners")
	var owner := FakeOwner.new()
	owner.runtime_perk_gold = 4
	var missing_store_summary: Dictionary = handler.apply_stage_clear_progress_once(owner, null, 1, true)
	_expect(str(missing_store_summary.get("save", "")) == "missing_plaza_save_store", "progress handler should report missing plaza save stores")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_progress_handler.gd")
	var finish_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
	var finish_screen_context_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_finish_screen_context_data.gd")
	var plaza_enter_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_flow_handler.gd")
	var plaza_enter_screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_plaza_enter_screen_data.gd")
	_expect(screen_source.find("func _apply_stage_clear_progress_once") < 0, "result screen should not keep stage-clear progress pass-through helpers")
	_expect(screen_source.find("apply_stage_clear_progress_from_callback") < 0, "result screen should not bind progress callback adapters directly")
	_expect(finish_source.find("apply_stage_clear_progress_from_callback") < 0, "finish flow handler should delegate finish-flow progress callback wiring")
	_expect(finish_screen_context_source.find("apply_stage_clear_progress_from_callback") >= 0, "finish screen context data should bind finish flows to the plaza progress callback adapter")
	_expect(plaza_enter_source.find("apply_stage_clear_progress_from_callback") < 0, "plaza enter flow handler should delegate plaza-entry progress callback wiring")
	_expect(plaza_enter_screen_data_source.find("apply_stage_clear_progress_from_callback") >= 0, "plaza enter screen data should bind plaza entry to the progress callback adapter")
	_expect(handler_source.find("func apply_stage_clear_progress_from_callback") >= 0, "plaza progress handler should own callback-oriented progress entry")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
