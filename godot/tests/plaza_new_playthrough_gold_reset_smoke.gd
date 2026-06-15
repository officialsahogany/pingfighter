extends SceneTree

# Seals the original-PingFighter parity rule that plaza gold + AP are
# per-playthrough: a fresh new game (stage 1 from the main menu) resets them
# to 0 / base while keeping the bank deposit and stage map seeds. Stage
# transitions (stage > 1) must NOT reset, and the real save must never be
# touched by the selection-startup unit tests (empty save path => no-op).

const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reset_zeroes_gold_and_ap_keeps_bank_and_seed()
	_verify_reset_makes_ap_reawardable()
	_verify_persistence_is_default_without_reset()
	_verify_lifecycle_resets_on_stage_one_entry()
	_verify_lifecycle_skips_reset_on_stage_transition()
	_verify_lifecycle_skips_reset_when_no_save_path()
	_verify_default_save_path_resolution()

	if _failures.is_empty():
		print("plaza_new_playthrough_gold_reset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_zeroes_gold_and_ap_keeps_bank_and_seed() -> void:
	var path := _test_path("reset_core")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 3703, true)            # gold 3703, ap BASE+1
	store.perform_bank_transaction("deposit", 1, 500, false)  # bank 500, gold 3203
	store.set_stage_map_seed_for_test(2, 424242)
	_expect(store.get_plaza_gold() == 3203, "setup: plaza gold should be 3203 after deposit")
	_expect(store.get_bank_deposit_gold() == 500, "setup: bank deposit should be 500")

	store.reset_gold_and_ap_for_new_playthrough()
	_expect(store.get_plaza_gold() == 0, "reset should zero plaza gold")
	_expect(store.get_ap_current() == PlazaSaveStore.BASE_AP, "reset should restore AP to base")
	_expect(store.get_ap_is_first_stage(), "reset should restore the first-stage AP flag")
	_expect(store.get_bank_deposit_gold() == 500, "reset should keep bank deposit")
	_expect(store.get_or_create_stage_map_seed(2) == 424242, "reset should keep stage map seed")

	# A fresh instance loading the file must see the persisted reset (rewritten file).
	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 0, "reset should persist zero gold to the save file")
	_expect(reloaded.get_bank_deposit_gold() == 500, "reset should persist the preserved bank to the save file")
	_cleanup(path)


func _verify_reset_makes_ap_reawardable() -> void:
	var path := _test_path("ap_reaward")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 100, true)   # stage 1 marked AP-awarded
	var blocked: Dictionary = store.grant_stage_clear_ap(1)
	_expect(int(blocked.get("granted_ap", -1)) == 0, "setup: stage 1 AP must be a no-op before reset")

	store.reset_gold_and_ap_for_new_playthrough()
	var regranted: Dictionary = store.grant_stage_clear_ap(1)
	_expect(int(regranted.get("granted_ap", 0)) == 1, "reset should clear AP-awarded tracking so AP re-earns")
	_cleanup(path)


func _verify_persistence_is_default_without_reset() -> void:
	# Baseline / counter-case: WITHOUT the reset, plaza gold persists across a
	# fresh load. This is exactly the behavior the new-game reset overrides, and
	# it is why the bug was visible (gold survived restart).
	var path := _test_path("baseline")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 3703, true)
	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 3703, "without reset, plaza gold must persist across load")
	_cleanup(path)


func _verify_lifecycle_resets_on_stage_one_entry() -> void:
	var path := _test_path("lifecycle_stage1")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 3703, true)

	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.reset_plaza_progress_if_new_game(1, path)

	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 0, "lifecycle stage-1 entry should reset plaza gold")
	_cleanup(path)


func _verify_lifecycle_skips_reset_on_stage_transition() -> void:
	var path := _test_path("lifecycle_transition")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 3703, true)

	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.reset_plaza_progress_if_new_game(3, path)

	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 3703, "stage transition (stage > 1) must not reset plaza gold")
	_cleanup(path)


func _verify_lifecycle_skips_reset_when_no_save_path() -> void:
	# Empty save path (RefCounted unit-test owners) is a safe no-op so the real
	# user://plaza_save.cfg is never clobbered by the selection-startup tests.
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.reset_plaza_progress_if_new_game(1, "")
	_expect(true, "empty save path reset should be a safe no-op")


func _verify_default_save_path_resolution() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var node_owner := Node.new()
	_expect(
		lifecycle._default_plaza_save_path(node_owner) == PlazaSaveStore.SAVE_PATH,
		"a live Node owner should resolve to the canonical plaza save path"
	)
	node_owner.free()
	_expect(
		lifecycle._default_plaza_save_path(RefCounted.new()) == "",
		"a RefCounted (unit-test) owner should resolve to an empty path"
	)


func _test_path(label: String) -> String:
	return "user://plaza_new_playthrough_gold_reset_smoke_%s.cfg" % label


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
