extends SceneTree

const StageClearResultScrollPresenter := preload("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_builder_contract()
	_verify_presenter_contract()
	_verify_presenter_apply_contract()
	_verify_presenter_source()
	_verify_scene_delegates_scroll_presenter()

	if _failures.is_empty():
		print("stage_clear_result_scroll_presenter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_builder_contract() -> void:
	var boxes := [{"state": "opened"}]
	var stage_snapshot := {"gold": 12}
	var reward_icon_cache := {"gold": "cached"}
	var context: Dictionary = StageClearResultScrollPresenter.get_scroll_draw_context(
		4,
		stage_snapshot,
		boxes,
		null,
		7,
		3,
		2.5,
		null,
		null,
		reward_icon_cache,
		StageClearResultScrollState.PHASE_VISIBLE,
		0.9,
		Vector2(12.0, 8.0),
		"next_stage"
	)
	_expect(int(context.get("current_stage", 0)) == 4, "scroll context should include current stage")
	_expect(context.get("stage_reward_snapshot", {}) == stage_snapshot, "scroll context should preserve stage reward snapshot")
	_expect(context.get("boxes", []) == boxes, "scroll context should preserve boxes")
	_expect(int(context.get("player_score", 0)) == 7, "scroll context should include player score")
	_expect(int(context.get("boss_score", 0)) == 3, "scroll context should include boss score")
	_expect(float(context.get("timer", 0.0)) == 2.5, "scroll context should include scene timer")
	_expect(context.get("reward_icon_cache", {}) == reward_icon_cache, "scroll context should preserve reward icon cache")
	_expect(str(context.get("scroll_phase", "")) == StageClearResultScrollState.PHASE_VISIBLE, "scroll context should include scroll phase")
	_expect(float(context.get("scroll_timer", 0.0)) == 0.9, "scroll context should include scroll timer")
	_expect(context.get("scroll_position_offset", Vector2.ZERO) == Vector2(12.0, 8.0), "scroll context should include scroll offset")
	_expect(str(context.get("hovered_button", "")) == "next_stage", "scroll context should include hovered button")


func _verify_presenter_contract() -> void:
	var hidden: Dictionary = StageClearResultScrollPresenter.draw_scroll(
		null,
		null,
		Vector2(1920.0, 1080.0),
		1.0,
		null,
		{
			"scroll_phase": StageClearResultScrollState.PHASE_HIDDEN,
			"scroll_position_offset": Vector2(40.0, 20.0),
		}
	)
	_expect(not bool(hidden.get("drawn", true)), "scroll presenter should not draw hidden scrolls")
	_expect(hidden.get("scroll_position_offset", Vector2.ZERO) == Vector2(40.0, 20.0), "hidden scrolls should preserve existing position offset")
	_expect(hidden.get("next_stage_rect", Rect2()) == Rect2(), "hidden scrolls should clear next-stage button rects")

	var unfurling: Dictionary = StageClearResultScrollPresenter.draw_scroll(
		null,
		null,
		Vector2(1920.0, 1080.0),
		1.0,
		null,
		{
			"scroll_phase": StageClearResultScrollState.PHASE_UNFURLING,
			"scroll_timer": StageClearResultScrollState.SCROLL_UNFURL_DURATION * 0.40,
			"scroll_position_offset": Vector2(12.0, 8.0),
		}
	)
	_expect(bool(unfurling.get("drawn", false)), "scroll presenter should draw an unfurling scroll frame")
	_expect(not bool(unfurling.get("content_drawn", true)), "scroll presenter should hold content until reveal threshold")
	_expect(unfurling.get("visible_rect", Rect2()) is Rect2, "scroll presenter should expose visible scroll rects")

	var visible: Dictionary = StageClearResultScrollPresenter.draw_scroll(
		null,
		null,
		Vector2(1920.0, 1080.0),
		1.0,
		null,
		{
			"scroll_phase": StageClearResultScrollState.PHASE_VISIBLE,
			"scroll_timer": StageClearResultScrollState.SCROLL_UNFURL_DURATION,
			"scroll_position_offset": Vector2.ZERO,
			"boxes": [],
			"stage_reward_snapshot": {},
		}
	)
	_expect(bool(visible.get("drawn", false)), "scroll presenter should draw visible scroll frames")
	_expect(float(visible.get("content_alpha", 0.0)) > 0.99, "visible scroll content alpha should be fully revealed")
	_expect(visible.get("content_rect", Rect2()) is Rect2, "scroll presenter should expose content rects")


func _verify_presenter_apply_contract() -> void:
	var next_rect := Rect2(Vector2(10.0, 20.0), Vector2(120.0, 44.0))
	var exit_rect := Rect2(Vector2(150.0, 20.0), Vector2(120.0, 44.0))
	var apply_result: Dictionary = StageClearResultScrollPresenter.get_scroll_draw_apply_result(
		{
			"scroll_position_offset": Vector2(24.0, 36.0),
			"next_stage_rect": next_rect,
			"exit_rect": exit_rect,
		},
		Vector2.ZERO
	)
	_expect(apply_result.get("scroll_position_offset", Vector2.ZERO) == Vector2(24.0, 36.0), "scroll draw apply helper should preserve draw-time offset")
	_expect(apply_result.get("next_stage_rect", Rect2()) == next_rect, "scroll draw apply helper should preserve next-stage rect")
	_expect(apply_result.get("exit_rect", Rect2()) == exit_rect, "scroll draw apply helper should preserve exit rect")

	var fallback_apply: Dictionary = StageClearResultScrollPresenter.get_scroll_draw_apply_result(
		{},
		Vector2(4.0, 5.0)
	)
	_expect(fallback_apply.get("scroll_position_offset", Vector2.ZERO) == Vector2(4.0, 5.0), "scroll draw apply helper should fall back to current offset")
	_expect(fallback_apply.get("next_stage_rect", Rect2()) == Rect2(), "scroll draw apply helper should clear missing next-stage rects")
	_expect(fallback_apply.get("exit_rect", Rect2()) == Rect2(), "scroll draw apply helper should clear missing exit rects")


func _verify_presenter_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_presenter.gd")
	_expect(source.find("static func get_scroll_draw_context") >= 0, "scroll presenter should expose scroll draw context assembly")
	_expect(source.find("static func get_scroll_draw_apply_result") >= 0, "scroll presenter should expose scroll draw apply payloads")
	_expect(source.find("StageClearResultScrollDrawHelper.draw_cyber_scroll_frame") >= 0, "scroll presenter should delegate frame drawing")
	_expect(source.find("StageClearResultScrollContentDrawHelper.draw_scroll_contents") >= 0, "scroll presenter should delegate content drawing")
	_expect(source.find("StageClearResultScrollState.clamp_region_offset") >= 0, "scroll presenter should own draw-time offset clamping")
	_expect(source.find("CONTENT_REVEAL_START") >= 0, "scroll presenter should name the content reveal threshold")


func _verify_scene_delegates_scroll_presenter() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultScrollPresenter.draw_scroll") >= 0, "result scene should delegate scroll drawing to the presenter")
	_expect(source.find("StageClearResultScrollPresenter.get_scroll_draw_context") >= 0, "result scene should delegate scroll draw context assembly to the presenter")
	_expect(source.find("StageClearResultScrollPresenter.get_scroll_draw_apply_result") >= 0, "result scene should delegate scroll draw apply payloads to the presenter")
	_expect(source.find("func _get_scroll_draw_context") >= 0, "result scene should keep a thin scroll draw context wrapper")
	_expect(source.find("func _apply_scroll_state_result") >= 0, "result scene should apply scroll state payloads in one helper")
	_expect(source.find("StageClearResultScrollDrawHelper.draw_cyber_scroll_frame") < 0, "result scene should not draw scroll frames directly")
	_expect(source.find("StageClearResultScrollContentDrawHelper.draw_scroll_contents") < 0, "result scene should not draw scroll content directly")
	_expect(source.find("func _draw_cyber_scroll") < 0, "result scene should not keep cyber-scroll draw sequencing wrappers")
	_expect(source.find("func _draw_cyber_scroll_contents") < 0, "result scene should not keep cyber-scroll content wrappers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
