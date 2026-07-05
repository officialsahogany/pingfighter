extends SceneTree

const StageClearResultCinematicPositionHelper := preload("res://scripts/ui/stage_clear_result_cinematic_position_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_box_pickup_position()
	_verify_live2d_target_position()
	_verify_reward_position_pair()
	_verify_scene_uses_cinematic_helper()

	if _failures.is_empty():
		print("stage_clear_result_cinematic_position_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_box_pickup_position() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var field_size := Vector2(760.0, 750.0)
	var field_origin: Vector2 = (view_size - field_size) * 0.5
	var pickup: Vector2 = StageClearResultCinematicPositionHelper.get_box_pickup_position(
		{"base_pos": field_origin + Vector2(120.0, 210.0), "amplitude": 0.0},
		view_size,
		1.0,
		0.0,
		field_size,
		0.0,
		1.0
	)
	_expect(pickup == Vector2(120.0, 210.0), "box pickup helper should convert screen box centers to cinematic-local coordinates")
	var clamped: Vector2 = StageClearResultCinematicPositionHelper.get_box_pickup_position(
		{"base_pos": field_origin + Vector2(900.0, -50.0), "amplitude": 0.0},
		view_size,
		1.0,
		0.0,
		field_size,
		0.0,
		1.0
	)
	_expect(clamped == Vector2(760.0, 0.0), "box pickup helper should clamp outside points to the cinematic field")


func _verify_live2d_target_position() -> void:
	var target: Vector2 = StageClearResultCinematicPositionHelper.get_live2d_target_position(
		Vector2(1920.0, 1080.0),
		1.0,
		Vector2(760.0, 750.0)
	)
	_expect(target.x > 760.0, "Live2D target helper should sit to the right of the cinematic playfield")
	_expect(target.y > 0.0, "Live2D target helper should preserve a visible vertical target")


func _verify_reward_position_pair() -> void:
	var positions: Dictionary = StageClearResultCinematicPositionHelper.get_reward_cinematic_positions(
		{"base_pos": Vector2(700.0, 365.0), "amplitude": 0.0},
		Vector2(1920.0, 1080.0),
		1.0,
		0.0,
		0.0,
		1.0,
		Vector2(760.0, 750.0)
	)
	_expect(positions.get("pickup_position", null) is Vector2, "cinematic position helper should expose pickup_position")
	_expect(positions.get("target_player_center", null) is Vector2, "cinematic position helper should expose target_player_center")


func _verify_scene_uses_cinematic_helper() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var update_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	var box_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var box_update_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_update_handler.gd")
	var immediate_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_immediate_reward_helper.gd")
	_expect(
		update_scene_handler_source.find("StageClearResultBoxSceneHandler.update_boxes") >= 0
			and box_scene_handler_source.find("StageClearResultBoxUpdateHandler.update_boxes") >= 0,
		"update scene handler should delegate reward box updates through the box scene handler"
	)
	_expect(source.find("func _update_boxes") < 0, "result scene should not keep box update fanout wrappers")
	_expect(
		box_update_source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") >= 0,
		"box update handler should delegate immediate reward grants through the helper"
	)
	_expect(
		immediate_source.find("StageClearResultCinematicPositionHelper.get_reward_cinematic_positions") >= 0,
		"immediate reward helper should delegate reward cinematic positions to the helper"
	)
	_expect(
		source.find("func _get_box_cinematic_pickup_position") < 0
		and source.find("func _get_result_live2d_cinematic_target_position") < 0,
		"result scene should not keep cinematic position pass-through helpers"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
