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
		"shop_currency_alignment.png",
		"noncombat_arena_clean.png",
		"combat_arena_restored.png",
		"training.png",
		"training_three_purchases.png",
		"training_maximum.png",
		"training_insufficient_muhon.png",
		"fallen_monk.png",
		"guardian_spring.png",
		"rest.png",
	]:
		_expect(qa_source.find('"file": "%s"' % output_name) >= 0, "visual QA must own %s" % output_name)
	_expect(qa_source.find("TowerAscentFlowRenderer") >= 0, "visual QA must use the production tower renderer")
	_expect(qa_source.find("draw_fullscreen_node_modal") >= 0, "visual QA must render through the production fullscreen consumer")
	_expect(qa_source.find("RuntimePerkOverlayRenderer") >= 0 and qa_source.find("RuntimePerkIconRenderer") >= 0, "six-card nodes must use the canonical reward-card and icon renderers")
	_expect(qa_source.find("get_node_modal_render_context") >= 0, "visual fixture must expose the same renderer context as the production flow")
	_expect(qa_source.find("_rect_has_visual_detail") >= 0, "each captured card rect must carry a rendered-pixel counterproof")
	_expect(qa_source.find("_capture_live_training_round") >= 0 and qa_source.find("execute_node_action") >= 0, "one windowed run must enter the production flow and purchase the same card")
	_expect(qa_source.find('begins_with("training_stat:")') >= 0, "live training capture must purchase a training-only card")
	_expect(qa_source.find("무공 서가 선택지") < 0, "training capture fixtures must contain no Mugong library cards")
	_expect(qa_source.find("CAPTURE_SPECS.size()") >= 0, "visual QA must drive its exact capture manifest")
	_expect(qa_source.find("—") < 0, "visual QA player-facing fixture copy must not use an em dash")
	_expect(wrapper_source.find("-AllowDuringPlay") >= 0, "visual wrapper must explicitly declare play-mode-safe execution")
	_expect(wrapper_source.find("BelowNormal") < 0, "visual wrapper must leave priority enforcement to the shared guard")
	_expect(wrapper_source.find("$PID") >= 0 and wrapper_source.find("yyyyMMddHHmmssfff") >= 0, "visual wrapper must allocate a process-unique log")
	_expect(wrapper_source.find("--rendering-driver vulkan") >= 0, "visual wrapper must require Vulkan")
	_expect(qa_source.find("CurrencyAlignmentCanvas") >= 0 and qa_source.find("gold_hud_amount\": 120") >= 0, "currency capture must render the pillar and modal run-gold projection in one frame")
	_expect(qa_source.find("BattleSceneDrawer") >= 0 and qa_source.find("SentinelPlayfieldDrawer") >= 0, "arena captures must exercise the production battle-scene composition boundary")
	_expect(wrapper_source.find("captures=12") >= 0, "visual wrapper must require the twelve-capture terminal marker")
	_expect(wrapper_source.find("live_runs=1") >= 0, "visual wrapper must require one live production-path run")
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
