extends SceneTree

const LingpetDecoder := preload("res://scripts/lingpet/lingpet_decoder.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_default_and_summary_level()
	_verify_roundtrip_and_monotonic_unlock()
	_verify_clamp_and_decode_pct()
	_verify_stage_clear_milestone_ladder()
	_verify_new_playthrough_reset_keeps_decoder_level()

	if _failures.is_empty():
		print("decoder_level_store_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_and_summary_level() -> void:
	var path := _test_path("default")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	_expect(store.get_decoder_level() == 0, "new plaza save should default decoder_level to 0")
	_expect(int(store.get_summary().get("decoder_level", -1)) == 0, "summary should expose default decoder_level")
	_cleanup(path)


func _verify_roundtrip_and_monotonic_unlock() -> void:
	var path := _test_path("roundtrip")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	_expect(store.unlock_decoder_level(3), "unlock_decoder_level should accept a higher level")
	_expect(store.get_decoder_level() == 3, "decoder_level should rise to the requested level")
	_expect(not store.unlock_decoder_level(2), "unlock_decoder_level should reject lower levels")
	_expect(store.get_decoder_level() == 3, "decoder_level should stay monotonic after a lower request")

	var loaded := PlazaSaveStore.new()
	loaded.set_save_path(path)
	_expect(loaded.get_decoder_level() == 3, "decoder_level should survive save/load roundtrip")
	_expect(int(loaded.get_summary().get("decoder_level", -1)) == 3, "summary should expose reloaded decoder_level")
	_cleanup(path)


func _verify_clamp_and_decode_pct() -> void:
	var path := _test_path("clamp")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	_expect(store.unlock_decoder_level(999), "unlock_decoder_level should clamp high requests and still advance")
	_expect(store.get_decoder_level() == PlazaSaveStore.MAX_DECODER_LEVEL, "decoder_level should clamp to the max level")
	_expect(not store.unlock_decoder_level(-5), "unlock_decoder_level should reject negative lower requests")
	_expect(store.get_decoder_level() == PlazaSaveStore.MAX_DECODER_LEVEL, "negative unlock should not lower decoder_level")

	var expected_pct := {
		-1: 0,
		0: 0,
		1: 20,
		2: 40,
		3: 60,
		4: 80,
		5: 100,
		6: 100,
	}
	for raw_level in expected_pct.keys():
		_expect(
			LingpetDecoder.decode_pct_for_level(int(raw_level)) == int(expected_pct.get(raw_level)),
			"decode_pct_for_level(%d) should equal %d" % [int(raw_level), int(expected_pct.get(raw_level))]
		)
	_cleanup(path)


func _verify_stage_clear_milestone_ladder() -> void:
	var ladder_path := _test_path("stage_ladder")
	_cleanup(ladder_path)
	var ladder_store := PlazaSaveStore.new()
	ladder_store.set_save_path(ladder_path)
	ladder_store.apply_stage_clear_progress(2, 0, true)
	_expect(ladder_store.get_decoder_level() == 2, "stage 2 clear should unlock decoder_level 2")
	ladder_store.apply_stage_clear_progress(5, 0, true)
	_expect(ladder_store.get_decoder_level() == 5, "stage 5 clear should unlock decoder_level 5")
	ladder_store.apply_stage_clear_progress(6, 0, true)
	_expect(ladder_store.get_decoder_level() == PlazaSaveStore.MAX_DECODER_LEVEL, "stage 6 clear should clamp decoder_level to max")
	_cleanup(ladder_path)

	var duplicate_path := _test_path("stage_duplicate")
	_cleanup(duplicate_path)
	var duplicate_store := PlazaSaveStore.new()
	duplicate_store.set_save_path(duplicate_path)
	duplicate_store.apply_stage_clear_progress(3, 0, true)
	duplicate_store.apply_stage_clear_progress(3, 0, true)
	_expect(duplicate_store.get_decoder_level() == 3, "duplicate stage 3 clears should keep decoder_level 3")
	_cleanup(duplicate_path)

	var reverse_path := _test_path("stage_reverse")
	_cleanup(reverse_path)
	var reverse_store := PlazaSaveStore.new()
	reverse_store.set_save_path(reverse_path)
	reverse_store.apply_stage_clear_progress(5, 0, true)
	reverse_store.apply_stage_clear_progress(2, 0, true)
	_expect(reverse_store.get_decoder_level() == 5, "stage 2 after stage 5 should not lower decoder_level")
	_cleanup(reverse_path)


func _verify_new_playthrough_reset_keeps_decoder_level() -> void:
	var path := _test_path("new_playthrough")
	_cleanup(path)
	var store := PlazaSaveStore.new()
	store.set_save_path(path)
	store.apply_stage_clear_progress(4, 250, true)
	_expect(store.get_decoder_level() == 4, "stage 4 clear should unlock decoder_level 4 for reset setup")
	store.reset_gold_and_ap_for_new_playthrough()
	_expect(store.get_decoder_level() == 4, "new playthrough wallet/AP reset should keep permanent decoder_level")
	_expect(store.get_plaza_gold() == 0, "new playthrough reset should still clear plaza gold")

	var loaded := PlazaSaveStore.new()
	loaded.set_save_path(path)
	_expect(loaded.get_decoder_level() == 4, "decoder_level should persist after new playthrough reset save")
	_cleanup(path)


func _test_path(label: String) -> String:
	return "res://.tmp/decoder_level_store_smoke_%s_%d_%d.cfg" % [
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
