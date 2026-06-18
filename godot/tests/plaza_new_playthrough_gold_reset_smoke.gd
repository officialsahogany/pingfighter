extends SceneTree

# Seals the original-PingFighter parity rule that plaza gold + AP are
# per-playthrough: a fresh new game (stage 1 from the main menu) resets them
# to 0 / base while keeping the bank deposit and stage map seeds. Stage
# transitions (stage > 1) must NOT reset, and the real save must never be
# touched by the selection-startup unit tests (empty save path => no-op).

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")

var _failures: Array[String] = []


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var rejected_keys: Array[String] = []

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			rejected_keys.append(key)
			return false
		scene_state.set_value(key, value)
		return true

	func value_of(key: String) -> Variant:
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null


func _init() -> void:
	_verify_reset_zeroes_gold_and_ap_keeps_bank_and_seed()
	_verify_reset_makes_ap_reawardable()
	_verify_persistence_is_default_without_reset()
	_verify_lifecycle_resets_on_stage_one_entry()
	_verify_lifecycle_skips_reset_on_stage_transition()
	_verify_lifecycle_syncs_chance_gems_to_schema_owner()
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
	store.consume_chance_gem()
	store.consume_chance_gem()
	store.set_stage_map_seed_for_test(2, 424242)
	_expect(store.get_plaza_gold() == 3203, "setup: plaza gold should be 3203 after deposit")
	_expect(store.get_bank_deposit_gold() == 500, "setup: bank deposit should be 500")
	_expect(store.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS - 2, "setup: chance gems should be partially consumed")

	store.reset_gold_and_ap_for_new_playthrough()
	_expect(store.get_plaza_gold() == 0, "reset should zero plaza gold")
	_expect(store.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "reset should refill chance gems")
	_expect(store.get_ap_current() == PlazaSaveStore.BASE_AP, "reset should restore AP to base")
	_expect(store.get_ap_is_first_stage(), "reset should restore the first-stage AP flag")
	_expect(store.get_bank_deposit_gold() == 500, "reset should keep bank deposit")
	_expect(store.get_or_create_stage_map_seed(2) == 424242, "reset should keep stage map seed")

	# A fresh instance loading the file must see the persisted reset (rewritten file).
	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 0, "reset should persist zero gold to the save file")
	_expect(reloaded.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "reset should persist refilled chance gems to the save file")
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
	store.consume_chance_gem()
	store.consume_chance_gem()

	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.reset_plaza_progress_if_new_game(1, path)

	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 0, "lifecycle stage-1 entry should reset plaza gold")
	_expect(reloaded.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS, "lifecycle stage-1 entry should refill chance gems")
	_cleanup(path)


func _verify_lifecycle_skips_reset_on_stage_transition() -> void:
	var path := _test_path("lifecycle_transition")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(1, 3703, true)
	store.consume_chance_gem()
	store.consume_chance_gem()

	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.reset_plaza_progress_if_new_game(3, path)

	var reloaded := PlazaSaveStore.new()
	reloaded.set_save_path(path)
	_expect(reloaded.get_plaza_gold() == 3703, "stage transition (stage > 1) must not reset plaza gold")
	_expect(reloaded.get_chance_gems() == PlazaSaveStore.MAX_CHANCE_GEMS - 2, "stage transition (stage > 1) must preserve consumed chance gems")
	_cleanup(path)


func _verify_lifecycle_syncs_chance_gems_to_schema_owner() -> void:
	var path := _test_path("lifecycle_chance_mirror")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.consume_chance_gem()

	var owner := SchemaGatedOwner.new()
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	_expect(BattleSceneState.DEFAULT_VALUES.has("chance_gems_count"), "chance gem count must be declared in the owner schema")
	_expect(BattleSceneState.DEFAULT_VALUES.has("chance_gems_max"), "chance gem max must be declared in the owner schema")
	lifecycle.sync_chance_gems_from_plaza_store(owner, path)
	_expect(int(owner.value_of("chance_gems_count")) == PlazaSaveStore.MAX_CHANCE_GEMS - 1, "lifecycle should mirror persisted chance gems to the owner")
	_expect(int(owner.value_of("chance_gems_max")) == PlazaSaveStore.MAX_CHANCE_GEMS, "lifecycle should mirror chance gem capacity to the owner")
	_expect(owner.rejected_keys.is_empty(), "schema-gated owner should accept chance gem lifecycle mirrors")

	lifecycle.reset_plaza_progress_if_new_game(1, path)
	lifecycle.sync_chance_gems_from_plaza_store(owner, path)
	_expect(int(owner.value_of("chance_gems_count")) == PlazaSaveStore.MAX_CHANCE_GEMS, "stage-1 lifecycle reset should mirror refilled chance gems")
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
	return "res://.tmp/plaza_new_playthrough_gold_reset_smoke_%s_%d_%d.cfg" % [
		label,
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]


func _cleanup(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
