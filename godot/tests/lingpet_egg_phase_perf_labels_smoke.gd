extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_verify_egg_phase_sub_labels_are_wired()
	_verify_hatch_reveal_cutin_open_labels_are_wired()
	_verify_transition_round_dep_labels_are_wired()

	if _failures.is_empty():
		print("lingpet_egg_phase_perf_labels_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_egg_phase_sub_labels_are_wired() -> void:
	var source := _read_source("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(source.contains("physics.lingpet.egg_phase.contact"), "egg_phase should expose contact timing")
	_expect(source.contains("physics.lingpet.egg_phase.cutin_prewarm"), "egg_phase should expose acquire cut-in prewarm timing")
	_expect(source.contains("physics.lingpet.egg_phase.hatch_resolve"), "egg_phase should expose hatch resolve timing")
	_expect(source.contains("physics.lingpet.egg_phase.owner_sync"), "egg_phase should expose owner sync timing")


func _verify_hatch_reveal_cutin_open_labels_are_wired() -> void:
	var runtime_source := _read_source("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resetter_source := _read_source("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
	var host_source := _read_source("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(
		runtime_source.contains("\"physics.lingpet.egg_phase.hatch_resolve.cutin_open\""),
		"hatch reveal should pass the cut-in open label prefix"
	)
	_expect(host_source.contains("\"static_art\""), "cut-in prewarm should expose static art timing")
	_expect(host_source.contains("\"anim_sheet\""), "cut-in prewarm should expose animation sheet timing")
	_expect(host_source.contains("\"reconstruction_mask\""), "cut-in prewarm should expose reconstruction mask timing")
	_expect(resetter_source.contains("\"begin\""), "cut-in open should expose begin timing")
	_expect(resetter_source.contains("\"audio\""), "cut-in open should expose audio timing")
	_expect(resetter_source.contains("\"companion_sheet\""), "cut-in open should expose companion sheet prewarm timing")
	_expect(resetter_source.contains("_perf_end_with_prefix"), "hatch reveal should suppress labels when no prefix is passed")


func _verify_transition_round_dep_labels_are_wired() -> void:
	var source := _read_source("res://scripts/core/battle_scene_match_event_driver.gd")
	_expect(
		source.contains("process.frame.stage_transition_loading.step.1.round_dep.%s"),
		"stage-transition round-dep prewarm should expose the module key timing"
	)


func _read_source(path: String) -> String:
	if not FileAccess.file_exists(path):
		_failures.append("missing source file: %s" % path)
		return ""
	return FileAccess.get_file_as_string(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
