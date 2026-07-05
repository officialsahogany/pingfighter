extends SceneTree

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorReactionUpdateHandler := preload("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_builder_contract()
	_verify_update_handler_contract()
	_verify_update_apply_contract()
	_verify_scene_apply_contract()
	_verify_scene_applies_actor_reaction_timer_update()
	_verify_update_handler_source()
	_verify_scene_delegates_actor_reaction_updates()

	if _failures.is_empty():
		print("stage_clear_result_actor_reaction_update_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_builder_contract() -> void:
	var result: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context(
		1.25,
		0.10,
		0.20,
		0.30,
		0.40,
		0.15,
		0.50,
		0.60
	)
	_expect(float(result.get("dalji_base_timer", 0.0)) == 1.25, "context builder should include Dalji base timer")
	_expect(float(result.get("dalji_click_reaction_timer", 0.0)) == 0.10, "context builder should include Dalji reaction timer")
	_expect(float(result.get("player_victory_click_reaction_timer", 0.0)) == 0.20, "context builder should include player reaction timer")
	_expect(float(result.get("stage2_boss_defeat_click_reaction_timer", 0.0)) == 0.30, "context builder should include Stage 2 boss reaction timer")
	_expect(float(result.get("stage3_boss_defeat_click_reaction_timer", 0.0)) == 0.40, "context builder should include Stage 3 boss reaction timer")
	_expect(float(result.get("stage6_boss_defeat_click_reaction_timer", 0.0)) == 0.50, "context builder should include Stage 6 boss reaction timer")
	_expect(float(result.get("stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) == 0.60, "context builder should include Stage 4 Ponk reaction timer")
	_expect(float(result.get("dalji_dialogue_timer", 0.0)) == 0.15, "context builder should include Dalji dialogue timer")


func _verify_update_handler_contract() -> void:
	_expect(StageClearResultActorReactionUpdateHandler != null, "actor reaction update handler preload should resolve")
	var result: Dictionary = StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers(
		{
			"dalji_base_timer": 1.25,
			"dalji_click_reaction_timer": 0.10,
			"player_victory_click_reaction_timer": 0.20,
			"stage2_boss_defeat_click_reaction_timer": 0.30,
			"stage3_boss_defeat_click_reaction_timer": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
			"stage4_ponk_boss_defeat_click_reaction_timer": 0.10,
			"stage6_boss_defeat_click_reaction_timer": 0.10,
			"dalji_dialogue_timer": 0.15,
		},
		0.20
	)
	_expect(abs(float(result.get("dalji_base_timer", 0.0)) - 1.45) <= 0.001, "handler should advance Dalji base timer")
	_expect(abs(float(result.get("dalji_dialogue_timer", 0.0)) - 0.0) <= 0.001, "handler should clamp Dalji dialogue timer")
	_expect(abs(float(result.get("dalji_click_reaction_timer", 0.0)) - 0.30) <= 0.001, "handler should advance Dalji click reaction timer")
	_expect(abs(float(result.get("player_victory_click_reaction_timer", 0.0)) - 0.40) <= 0.001, "handler should advance player click reaction timer")
	_expect(abs(float(result.get("stage2_boss_defeat_click_reaction_timer", 0.0)) - 0.50) <= 0.001, "handler should advance Stage 2 boss reaction timer")
	_expect(
		abs(float(result.get("stage3_boss_defeat_click_reaction_timer", 0.0)) - StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION) <= 0.001,
		"handler should leave inactive boss reaction timers unchanged"
	)
	_expect(abs(float(result.get("stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) - 0.30) <= 0.001, "handler should advance Stage 4 Ponk reaction timer")
	_expect(abs(float(result.get("stage6_boss_defeat_click_reaction_timer", 0.0)) - 0.30) <= 0.001, "handler should advance Stage 6 boss reaction timer")


func _verify_update_apply_contract() -> void:
	var current: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context(
		1.25,
		0.10,
		0.20,
		0.30,
		0.40,
		0.15,
		0.50,
		0.60
	)
	var apply_result: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_apply_result(
		{
			"dalji_base_timer": 2.0,
			"dalji_click_reaction_timer": 0.50,
			"player_victory_click_reaction_timer": 0.60,
			"stage2_boss_defeat_click_reaction_timer": 0.70,
			"stage3_boss_defeat_click_reaction_timer": 0.80,
			"stage4_ponk_boss_defeat_click_reaction_timer": 0.25,
			"stage6_boss_defeat_click_reaction_timer": 0.20,
			"dalji_dialogue_timer": 0.0,
		},
		current
	)
	_expect(abs(float(apply_result.get("dalji_base_timer", 0.0)) - 2.0) <= 0.001, "apply payload should apply Dalji base timer")
	_expect(abs(float(apply_result.get("dalji_click_reaction_timer", 0.0)) - 0.50) <= 0.001, "apply payload should apply Dalji reaction timer")
	_expect(abs(float(apply_result.get("player_victory_click_reaction_timer", 0.0)) - 0.60) <= 0.001, "apply payload should apply player reaction timer")
	_expect(abs(float(apply_result.get("stage2_boss_defeat_click_reaction_timer", 0.0)) - 0.70) <= 0.001, "apply payload should apply Stage 2 reaction timer")
	_expect(abs(float(apply_result.get("stage3_boss_defeat_click_reaction_timer", 0.0)) - 0.80) <= 0.001, "apply payload should apply Stage 3 reaction timer")
	_expect(abs(float(apply_result.get("stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) - 0.25) <= 0.001, "apply payload should apply Stage 4 Ponk reaction timer")
	_expect(abs(float(apply_result.get("stage6_boss_defeat_click_reaction_timer", 0.0)) - 0.20) <= 0.001, "apply payload should apply Stage 6 reaction timer")
	_expect(abs(float(apply_result.get("dalji_dialogue_timer", 0.0)) - 0.0) <= 0.001, "apply payload should apply Dalji dialogue timer")

	var fallback_result: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_apply_result({}, current)
	_expect(abs(float(fallback_result.get("dalji_base_timer", 0.0)) - 1.25) <= 0.001, "missing Dalji base timer should keep current timer")
	_expect(abs(float(fallback_result.get("dalji_click_reaction_timer", 0.0)) - 0.10) <= 0.001, "missing Dalji reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("player_victory_click_reaction_timer", 0.0)) - 0.20) <= 0.001, "missing player reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("stage2_boss_defeat_click_reaction_timer", 0.0)) - 0.30) <= 0.001, "missing Stage 2 reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("stage3_boss_defeat_click_reaction_timer", 0.0)) - 0.40) <= 0.001, "missing Stage 3 reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) - 0.60) <= 0.001, "missing Stage 4 Ponk reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("stage6_boss_defeat_click_reaction_timer", 0.0)) - 0.50) <= 0.001, "missing Stage 6 reaction timer should keep current timer")
	_expect(abs(float(fallback_result.get("dalji_dialogue_timer", 0.0)) - 0.15) <= 0.001, "missing Dalji dialogue timer should keep current timer")


func _verify_scene_apply_contract() -> void:
	var current: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context(
		1.25,
		0.10,
		0.20,
		0.30,
		0.40,
		0.15,
		0.50,
		0.60
	)
	var scene_apply: Dictionary = StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_scene_apply_result(
		{
			"dalji_base_timer": 2.0,
			"dalji_click_reaction_timer": 0.50,
			"player_victory_click_reaction_timer": 0.60,
			"stage2_boss_defeat_click_reaction_timer": 0.70,
			"stage3_boss_defeat_click_reaction_timer": 0.80,
			"stage4_ponk_boss_defeat_click_reaction_timer": 0.25,
			"stage6_boss_defeat_click_reaction_timer": 0.20,
			"dalji_dialogue_timer": 0.0,
		},
		current
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(abs(float(field_payload.get("_dalji_base_timer", 0.0)) - 2.0) <= 0.001, "scene apply payload should map Dalji base timer")
	_expect(abs(float(field_payload.get("_dalji_click_reaction_timer", 0.0)) - 0.50) <= 0.001, "scene apply payload should map Dalji reaction timer")
	_expect(abs(float(field_payload.get("_player_victory_click_reaction_timer", 0.0)) - 0.60) <= 0.001, "scene apply payload should map player reaction timer")
	_expect(abs(float(field_payload.get("_stage2_boss_defeat_click_reaction_timer", 0.0)) - 0.70) <= 0.001, "scene apply payload should map Stage 2 reaction timer")
	_expect(abs(float(field_payload.get("_stage3_boss_defeat_click_reaction_timer", 0.0)) - 0.80) <= 0.001, "scene apply payload should map Stage 3 reaction timer")
	_expect(abs(float(field_payload.get("_stage4_ponk_boss_defeat_click_reaction_timer", 0.0)) - 0.25) <= 0.001, "scene apply payload should map Stage 4 Ponk reaction timer")
	_expect(abs(float(field_payload.get("_stage6_boss_defeat_click_reaction_timer", 0.0)) - 0.20) <= 0.001, "scene apply payload should map Stage 6 reaction timer")
	_expect(abs(float(field_payload.get("_dalji_dialogue_timer", 0.0)) - 0.0) <= 0.001, "scene apply payload should map Dalji dialogue timer")

	var scene := StageClearResultScene.new()
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, scene_apply)
	_expect(abs(float(scene.get("_dalji_base_timer")) - 2.0) <= 0.001, "scene field payload helper should apply Dalji base timer")
	_expect(abs(float(scene.get("_dalji_click_reaction_timer")) - 0.50) <= 0.001, "scene field payload helper should apply Dalji reaction timer")
	_expect(abs(float(scene.get("_player_victory_click_reaction_timer")) - 0.60) <= 0.001, "scene field payload helper should apply player reaction timer")
	_expect(abs(float(scene.get("_stage2_boss_defeat_click_reaction_timer")) - 0.70) <= 0.001, "scene field payload helper should apply Stage 2 reaction timer")
	_expect(abs(float(scene.get("_stage3_boss_defeat_click_reaction_timer")) - 0.80) <= 0.001, "scene field payload helper should apply Stage 3 reaction timer")
	_expect(abs(float(scene.get("_stage4_ponk_boss_defeat_click_reaction_timer")) - 0.25) <= 0.001, "scene field payload helper should apply Stage 4 Ponk reaction timer")
	_expect(abs(float(scene.get("_stage6_boss_defeat_click_reaction_timer")) - 0.20) <= 0.001, "scene field payload helper should apply Stage 6 reaction timer")
	_expect(abs(float(scene.get("_dalji_dialogue_timer")) - 0.0) <= 0.001, "scene field payload helper should apply dialogue timer")
	scene.free()


func _verify_scene_applies_actor_reaction_timer_update() -> void:
	var scene := StageClearResultScene.new()
	scene.set("_dalji_base_timer", 1.0)
	scene.set("_dalji_click_reaction_timer", 0.10)
	scene.set("_player_victory_click_reaction_timer", 0.20)
	scene.set("_stage2_boss_defeat_click_reaction_timer", 0.30)
	scene.set("_stage3_boss_defeat_click_reaction_timer", 0.40)
	scene.set("_stage4_ponk_boss_defeat_click_reaction_timer", 0.60)
	scene.set("_stage6_boss_defeat_click_reaction_timer", 0.50)
	scene.set("_dalji_dialogue_timer", 0.50)
	StageClearResultUpdateSceneHandler.apply_actor_reaction_timer_update(scene, {
		"dalji_base_timer": 2.0,
		"dalji_click_reaction_timer": 0.60,
		"player_victory_click_reaction_timer": 0.70,
		"stage2_boss_defeat_click_reaction_timer": 0.80,
		"stage3_boss_defeat_click_reaction_timer": 0.90,
		"stage4_ponk_boss_defeat_click_reaction_timer": 0.25,
		"stage6_boss_defeat_click_reaction_timer": 0.20,
		"dalji_dialogue_timer": 0.0,
	})
	_expect(abs(float(scene.get("_dalji_base_timer")) - 2.0) <= 0.001, "scene apply should write Dalji base timer")
	_expect(abs(float(scene.get("_dalji_click_reaction_timer")) - 0.60) <= 0.001, "scene apply should write Dalji reaction timer")
	_expect(abs(float(scene.get("_player_victory_click_reaction_timer")) - 0.70) <= 0.001, "scene apply should write player reaction timer")
	_expect(abs(float(scene.get("_stage2_boss_defeat_click_reaction_timer")) - 0.80) <= 0.001, "scene apply should write Stage 2 reaction timer")
	_expect(abs(float(scene.get("_stage3_boss_defeat_click_reaction_timer")) - 0.90) <= 0.001, "scene apply should write Stage 3 reaction timer")
	_expect(abs(float(scene.get("_stage4_ponk_boss_defeat_click_reaction_timer")) - 0.25) <= 0.001, "scene apply should write Stage 4 Ponk reaction timer")
	_expect(abs(float(scene.get("_stage6_boss_defeat_click_reaction_timer")) - 0.20) <= 0.001, "scene apply should write Stage 6 reaction timer")
	_expect(abs(float(scene.get("_dalji_dialogue_timer")) - 0.0) <= 0.001, "scene apply should write dialogue timer")
	scene.free()


func _verify_update_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_reaction_update_handler.gd")
	_expect(source.find("static func get_actor_reaction_timer_context") >= 0, "handler should expose actor reaction timer context assembly")
	_expect(source.find("static func update_actor_reaction_timers") >= 0, "handler should expose actor reaction timer updates")
	_expect(source.find("static func get_actor_reaction_timer_apply_result") >= 0, "handler should expose actor reaction timer apply payloads")
	_expect(source.find("static func get_actor_reaction_timer_scene_apply_result") >= 0, "handler should expose actor reaction timer scene field apply payloads")
	_expect(source.find("static func _get_reaction_timer_payload_configs") >= 0, "handler should centralize click reaction timer payload config")
	_expect(source.find("StageClearResultClickReactionState.advance_reaction_timer") >= 0, "handler should delegate reaction timer advancement")
	_expect(source.find("StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION") >= 0, "handler should use Dalji reaction duration policy")
	_expect(source.find("StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION") >= 0, "handler should use player reaction duration policy")
	_expect(source.find("StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION") >= 0, "handler should use boss reaction duration policy")
	_expect(source.find("StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION") >= 0, "handler should use Stage 4 Ponk Live2D reaction duration policy")
	_expect(source.find("StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION") >= 0, "handler should use Stage 5 Hongryun reaction duration policy")
	_expect(source.find("StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION") >= 0, "handler should use Stage 6 Tetriser reaction duration policy")


func _verify_scene_delegates_actor_reaction_updates() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	var apply_source: String = _slice_function(scene_handler_source, "static func apply_actor_reaction_timer_update", "static func _apply_scene_apply_result")
	_expect(source.find("StageClearResultUpdateSceneHandler.update_result_scene") >= 0, "result scene should delegate per-frame result updates through the update scene handler")
	_expect(scene_handler_source.find("static func get_actor_reaction_timer_context") >= 0, "update scene handler should expose actor reaction timer context scene glue")
	_expect(scene_handler_source.find("static func apply_actor_reaction_timer_update") >= 0, "update scene handler should expose actor reaction scene application")
	_expect(source.find("StageClearResultUpdateSceneHandler.get_actor_reaction_timer_context") < 0, "result scene should not keep actor reaction timer context pass-through glue")
	_expect(source.find("StageClearResultUpdateSceneHandler.apply_actor_reaction_timer_update") < 0, "result scene should not keep actor reaction scene application pass-through glue")
	_expect(scene_handler_source.find("StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers") >= 0, "update scene handler should delegate actor reaction timer updates")
	_expect(scene_handler_source.find("StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context") >= 0, "update scene handler should delegate actor reaction timer context assembly")
	_expect(scene_handler_source.find("StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_scene_apply_result") >= 0, "update scene handler should delegate actor reaction timer scene field apply payloads")
	_expect(source.find("StageClearResultActorReactionUpdateHandler.update_actor_reaction_timers") < 0, "result scene should not call actor reaction update helper directly")
	_expect(source.find("StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_context") < 0, "result scene should not call actor reaction context helper directly")
	_expect(source.find("StageClearResultActorReactionUpdateHandler.get_actor_reaction_timer_scene_apply_result") < 0, "result scene should not call actor reaction apply helper directly")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(source.find("_apply_actor_reaction_timer_update") < 0, "result scene should not keep actor reaction timer update pass-through wrappers")
	_expect(StageClearResultUpdateSceneHandler != null, "update scene handler preload should resolve")
	_expect(apply_source.find("_dalji_base_timer = float(result.get") < 0, "actor reaction applier should not inspect Dalji base timer directly")
	_expect(apply_source.find("_dalji_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect Dalji reaction timer directly")
	_expect(apply_source.find("_player_victory_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect player reaction timer directly")
	_expect(apply_source.find("_stage2_boss_defeat_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect Stage 2 reaction timer directly")
	_expect(apply_source.find("_stage3_boss_defeat_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect Stage 3 reaction timer directly")
	_expect(apply_source.find("_stage4_ponk_boss_defeat_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect Stage 4 Ponk reaction timer directly")
	_expect(apply_source.find("_stage6_boss_defeat_click_reaction_timer = float(result.get") < 0, "actor reaction applier should not inspect Stage 6 reaction timer directly")
	_expect(apply_source.find("_dalji_dialogue_timer = float(result.get") < 0, "actor reaction applier should not inspect dialogue timer directly")
	_expect(apply_source.find("_dalji_base_timer = float(apply_result.get") < 0, "actor reaction applier should not write Dalji base timer directly")
	_expect(apply_source.find("_dalji_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write Dalji reaction timer directly")
	_expect(apply_source.find("_player_victory_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write player reaction timer directly")
	_expect(apply_source.find("_stage2_boss_defeat_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write Stage 2 reaction timer directly")
	_expect(apply_source.find("_stage3_boss_defeat_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write Stage 3 reaction timer directly")
	_expect(apply_source.find("_stage4_ponk_boss_defeat_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write Stage 4 Ponk reaction timer directly")
	_expect(apply_source.find("_stage6_boss_defeat_click_reaction_timer = float(apply_result.get") < 0, "actor reaction applier should not write Stage 6 reaction timer directly")
	_expect(apply_source.find("_dalji_dialogue_timer = float(apply_result.get") < 0, "actor reaction applier should not write dialogue timer directly")
	_expect(source.find("StageClearResultClickReactionState.advance_reaction_timer") < 0, "result scene should not advance click reaction timers directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
