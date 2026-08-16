extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var qa_source := FileAccess.get_file_as_string(
		"res://tools/tower_ascent_phase_c_node_visual_qa.gd"
	)
	var wrapper_source := FileAccess.get_file_as_string(
		"res://tools/run_tower_ascent_phase_c_node_visual_qa.ps1"
	)
	for output_name in [
		"common_shell.png",
		"shop.png",
		"training.png",
		"fallen_monk.png",
		"guardian_spring.png",
		"rest.png",
	]:
		_expect(qa_source.find('"file": "%s"' % output_name) >= 0, "visual QA must own %s" % output_name)
	_expect(qa_source.find("BattlePlayfieldSceneDrawer") >= 0, "visual QA must render through the production playfield consumer")
	_expect(qa_source.find("TowerAscentFlowRenderer") >= 0, "visual QA must use the production tower renderer")
	_expect(qa_source.find("CAPTURE_SPECS.size()") >= 0, "visual QA must drive its exact capture manifest")
	_expect(qa_source.find("—") < 0, "visual QA player-facing fixture copy must not use an em dash")
	_expect(wrapper_source.find("-AllowDuringPlay") >= 0, "visual wrapper must explicitly declare play-mode-safe execution")
	_expect(wrapper_source.find("BelowNormal") < 0, "visual wrapper must leave priority enforcement to the shared guard")
	_expect(wrapper_source.find("$PID") >= 0 and wrapper_source.find("yyyyMMddHHmmssfff") >= 0, "visual wrapper must allocate a process-unique log")
	_expect(wrapper_source.find("--rendering-driver vulkan") >= 0, "visual wrapper must require Vulkan")
	_expect(wrapper_source.find("captures=6") >= 0, "visual wrapper must require the six-capture terminal marker")
	if _failures.is_empty():
		print("tower_ascent_phase_c_node_visual_qa_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
