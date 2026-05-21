extends SceneTree

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_frames()
	_verify_direct_alpha()
	_verify_scene_wrappers()

	if _failures.is_empty():
		print("stage_clear_result_click_reaction_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_frames() -> void:
	_expect(StageClearResultClickReactionState.get_base_frame(0.11, 0.055, 98) == 2, "base frame should advance from timer and interval")
	_expect(StageClearResultClickReactionState.get_base_frame(99.0, 0.055, 1) == 0, "base frame should clamp frame count safely")
	_expect(StageClearResultClickReactionState.get_reaction_frame(0.072, 3.5, 0.036, 98) == 2, "reaction frame should advance from click interval")
	_expect(StageClearResultClickReactionState.get_reaction_frame(4.0, 3.5, 0.036, 98) == 97, "reaction frame should hold the last frame after reaction duration")
	_expect(StageClearResultClickReactionState.get_transition_base_frame(0.05, 0.16, 7, 12) == 7, "transition base should use captured base frame during transition")
	_expect(StageClearResultClickReactionState.get_transition_base_frame(0.20, 0.16, 7, 12) == 12, "transition base should return to current base frame after transition")


func _verify_direct_alpha() -> void:
	_expect(
		_is_close(StageClearResultClickReactionState.get_reaction_alpha(0.08, 3.5, 0.16, 0.18, 0.05, 3.73), 0.5),
		"reaction alpha should smooth in during the transition"
	)
	_expect(StageClearResultClickReactionState.get_reaction_alpha(1.0, 3.5, 0.16, 0.18, 0.05, 3.73) == 1.0, "reaction alpha should hold during the main reaction")
	_expect(StageClearResultClickReactionState.get_reaction_alpha(3.60, 3.5, 0.16, 0.18, 0.05, 3.73) == 1.0, "reaction alpha should hold during return hold")
	_expect(
		StageClearResultClickReactionState.get_reaction_alpha(3.71, 3.5, 0.16, 0.18, 0.05, 3.73) < 1.0,
		"reaction alpha should fade during return fade"
	)
	_expect(StageClearResultClickReactionState.get_reaction_alpha(3.73, 3.5, 0.16, 0.18, 0.05, 3.73) == 0.0, "reaction alpha should be zero once inactive")
	_expect(StageClearResultClickReactionState.is_reaction_active(3.72, 3.73), "reaction should stay active before total duration")
	_expect(not StageClearResultClickReactionState.is_reaction_active(3.73, 3.73), "reaction should stop at total duration")
	_expect(StageClearResultClickReactionState.is_return_blend_active(3.5, 3.5, 3.73), "return blend should start at reaction duration")


func _verify_scene_wrappers() -> void:
	var scene := StageClearResultScene.new()
	scene.timer = 0.11
	_expect(scene._get_player_victory_base_frame() == 2, "scene player base-frame wrapper should delegate")
	scene._player_victory_click_transition_base_frame = 9
	scene._player_victory_click_reaction_timer = 0.08
	_expect(scene._get_player_victory_transition_base_frame() == 9, "scene player transition-base wrapper should delegate")
	_expect(_is_close(scene._get_player_victory_reaction_alpha(), 0.5), "scene player alpha wrapper should delegate")
	scene._dalji_base_timer = 0.11
	_expect(scene._get_dalji_base_frame() == 2, "scene Dalji base-frame wrapper should delegate")
	scene._dalji_click_transition_base_frame = 6
	scene._dalji_click_reaction_timer = 0.08
	_expect(scene._get_dalji_transition_base_frame() == 6, "scene Dalji transition-base wrapper should delegate")
	_expect(_is_close(scene._get_dalji_reaction_alpha(), 0.5), "scene Dalji alpha wrapper should delegate")
	scene.free()


func _is_close(actual: float, expected: float, tolerance: float = 0.001) -> bool:
	return abs(actual - expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
