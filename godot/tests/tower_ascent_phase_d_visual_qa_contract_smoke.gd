extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://tools/tower_ascent_phase_d_visual_qa.gd")
	var wrapper := FileAccess.get_file_as_string("res://tools/run_tower_ascent_phase_d_visual_qa.ps1")
	for file_name in [
		"01_fake_ending_teaser.png",
		"02_reclear_choice.png",
		"03_clear_settlement.png",
		"04_defeat_settlement.png",
		"05_gauntlet_transition.png",
		"06_true_ending_settlement.png",
	]:
		_expect(source.find(file_name) >= 0, "visual QA must capture %s" % file_name)
	_expect(source.find("BattlePlayfieldSceneDrawer") >= 0, "visual QA must use the production playfield drawer")
	_expect(source.find("RenderingServer.get_rendering_device()") >= 0, "visual QA must fail closed without Vulkan")
	_expect(source.find("image.get_size() != GAME_SIZE") >= 0, "visual QA must enforce the 760 by 750 acceptance size")
	_expect(wrapper.find("-AllowDuringPlay") >= 0, "wrapper must declare the play-mode validation policy")
	_expect(wrapper.find("--rendering-driver vulkan") >= 0, "wrapper must request Vulkan explicitly")
	_expect(wrapper.find("Restore-GodotValidationPriority") >= 0, "wrapper must restore caller priority in finally")
	if _failures.is_empty():
		print("tower_ascent_phase_d_visual_qa_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
