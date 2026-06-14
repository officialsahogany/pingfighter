extends SceneTree

const Stage2PlayfieldBounds := preload("res://scripts/stages/stage2/stage2_playfield_bounds.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_common_bounds()
	_verify_stage2_wrapper_delegates()
	_verify_stage_event_sources_delegate()

	if _failures.is_empty():
		print("stage_playfield_bounds_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_common_bounds() -> void:
	_expect(StagePlayfieldBounds.get_left({"play_left": 12.0}) == 12.0, "common bounds should read play_left")
	_expect(StagePlayfieldBounds.get_left({}) == 0.0, "common bounds should default left edge to zero")
	_expect(StagePlayfieldBounds.get_right({"play_right": 700.0}, 760.0) == 700.0, "common bounds should prefer play_right")
	_expect(StagePlayfieldBounds.get_right({"width": 720.0}, 760.0) == 720.0, "common bounds should fall back to width")
	_expect(StagePlayfieldBounds.get_right({}, 760.0) == 760.0, "common bounds should use supplied default width")
	_expect(StagePlayfieldBounds.get_height({"height": 620.0}, 750.0) == 620.0, "common bounds should read height")
	_expect(StagePlayfieldBounds.get_height({}, 750.0) == 750.0, "common bounds should use supplied default height")


func _verify_stage2_wrapper_delegates() -> void:
	var bounds := Stage2PlayfieldBounds.new()
	_expect(bounds.get_left({"play_left": 9.0}) == 9.0, "Stage 2 bounds wrapper should preserve left lookup")
	_expect(bounds.get_right({"width": 600.0}) == 600.0, "Stage 2 bounds wrapper should preserve width fallback")
	_expect(bounds.get_height({}) == 750.0, "Stage 2 bounds wrapper should preserve default height")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_playfield_bounds.gd")
	_expect(source.find("StagePlayfieldBounds.get_left") >= 0, "Stage 2 bounds wrapper should delegate left lookup")
	_expect(source.find("StagePlayfieldBounds.get_right") >= 0, "Stage 2 bounds wrapper should delegate right lookup")
	_expect(source.find("StagePlayfieldBounds.get_height") >= 0, "Stage 2 bounds wrapper should delegate height lookup")


func _verify_stage_event_sources_delegate() -> void:
	for path in [
		"res://scripts/stages/stage3/stage3_boss_skill_state.gd",
		"res://scripts/stages/stage4/stage4_bird_event.gd",
	]:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StagePlayfieldBounds.get_left") >= 0, "%s should delegate left bounds lookup" % path)
		_expect(source.find("StagePlayfieldBounds.get_right") >= 0, "%s should delegate right bounds lookup" % path)
		_expect(source.find("StagePlayfieldBounds.get_height") >= 0, "%s should delegate height bounds lookup" % path)
		_expect(source.find("func _get_play_left") < 0, "%s should not keep private left bounds helper" % path)
		_expect(source.find("func _get_play_right") < 0, "%s should not keep private right bounds helper" % path)
		_expect(source.find("func _get_play_height") < 0, "%s should not keep private height bounds helper" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
