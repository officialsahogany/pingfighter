extends SceneTree

const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	var save_path := "user://tower_ascent_record_store_smoke_%d.cfg" % Time.get_ticks_usec()
	_verify_missing_and_persistent_records(save_path)
	_verify_corrupt_file_fail_safe(save_path)
	_cleanup(save_path)
	if _failures.is_empty():
		print("tower_ascent_record_store_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_missing_and_persistent_records(save_path: String) -> void:
	_cleanup(save_path)
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	_expect(store.load(), "missing record file should load safe defaults")
	var empty := store.get_snapshot()
	_expect(int(empty.get("highest_floor", -1)) == 0, "missing file should start at floor zero")
	_expect(int(empty.get("clear_count", -1)) == 0, "missing file should start with no clears")
	_expect(not bool(empty.get("fake_ending_cleared", true)), "missing file should not fake a standard clear")
	_expect((empty.get("league_reserved", {"unexpected": true}) as Dictionary).is_empty(), "league field must stay reserved and empty")

	var reach := store.record_floor_reached(5, "run-a:floor:5")
	_expect(bool(reach.get("accepted", false)) and bool(reach.get("changed", false)), "floor reach should commit immediately")
	var standard := store.record_clear(9, TowerAscentRecordStore.ENDING_STANDARD, false, "run-a:standard")
	_expect(bool(standard.get("accepted", false)), "standard clear should commit")
	var duplicate := store.record_clear(9, TowerAscentRecordStore.ENDING_STANDARD, false, "run-a:standard")
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("changed", true)), "same event must be idempotent")
	var conflict := store.record_clear(12, TowerAscentRecordStore.ENDING_TRUE, true, "run-a:standard")
	_expect(not bool(conflict.get("accepted", true)) and str(conflict.get("reason", "")) == "event_id_conflict", "event id reuse with different payload must fail closed")

	var restarted := TowerAscentRecordStore.new()
	restarted.set_save_path(save_path)
	_expect(restarted.load(), "records should survive a game restart")
	var after_restart := restarted.get_snapshot()
	_expect(int(after_restart.get("highest_floor", -1)) == 9, "highest floor should survive restart")
	_expect(int(after_restart.get("clear_count", -1)) == 1, "idempotent clear count should survive restart")
	_expect(bool(after_restart.get("fake_ending_cleared", false)), "fake ending record should survive restart")
	_expect(not bool(after_restart.get("true_ending_cleared", true)), "standard clear must not mark true ending")

	var true_clear := restarted.record_clear(12, TowerAscentRecordStore.ENDING_TRUE, true, "run-b:true")
	_expect(bool(true_clear.get("accepted", false)), "true ending clear should commit")
	var final_store := TowerAscentRecordStore.new()
	final_store.set_save_path(save_path)
	_expect(final_store.load(), "true ending records should reload")
	var final_snapshot := final_store.get_snapshot()
	_expect(int(final_snapshot.get("highest_floor", -1)) == 12, "true ending should raise highest floor")
	_expect(int(final_snapshot.get("clear_count", -1)) == 2, "clear count should include both run endings")
	_expect(bool(final_snapshot.get("true_ending_cleared", false)), "true ending flag should persist")
	_expect(bool(final_snapshot.get("undefeated_true_ending_medal", false)), "undefeated medal should persist")


func _verify_corrupt_file_fail_safe(save_path: String) -> void:
	# Keep the container parseable so the standard runner stays warning/error
	# clean while proving that a damaged/missing schema fails closed.
	var damaged_config := ConfigFile.new()
	damaged_config.set_value("records", "highest_floor", 99)
	_expect(damaged_config.save(save_path) == OK, "damaged-schema fixture should be writable")
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	_expect(not store.load(), "damaged-schema record file should be rejected")
	var snapshot := store.get_snapshot()
	_expect(bool(snapshot.get("load_blocked", false)), "damaged-schema record file should block writes")
	_expect(int(snapshot.get("highest_floor", -1)) == 0, "damaged-schema record file should expose safe zero defaults")
	_expect(int(snapshot.get("clear_count", -1)) == 0, "damaged-schema record file should not invent clears")
	var result := store.record_floor_reached(2, "corrupt:floor:2")
	_expect(not bool(result.get("accepted", true)), "damaged-schema record file must fail closed instead of overwriting")


func _cleanup(save_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
