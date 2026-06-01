extends SceneTree

const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")

const BASE_WIDTH := 155.0
const BASE_HEIGHT := 50.0
const JUNIOR_SCALE := 1.5
const BULK_UP_SCALE := 1.06
const LONG_BOOST_SCALE := 1.5

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage := 1
	var selected_character_type := "smasher"
	var arena_mode_enabled := false
	var weather_type := ""
	var player_pos := Vector2.ZERO
	var player_paddle_width := BASE_WIDTH
	var player_paddle_height := BASE_HEIGHT
	var player_paddle_scale := 1.0
	var player_paddle_visual_scale_override := -1.0
	var runtime_paddle_base_width := BASE_WIDTH
	var runtime_paddle_base_height := BASE_HEIGHT


class FakeRegistry:
	extends RefCounted

	var dash_state := FakeDashState.new()

	func get_instance(key: String) -> Object:
		if key == "smasher_dash_state":
			return dash_state
		return null


class FakeDashState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {}


func _init() -> void:
	_verify_junior_base_visual_override_suppresses_only_league_scale()
	_verify_junior_visual_override_preserves_bulk_up_delta()
	_verify_junior_visual_override_preserves_active_item_delta()
	_verify_no_override_uses_total_runtime_scale()

	if _failures.is_empty():
		print("player_paddle_visual_scale_override_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_junior_base_visual_override_suppresses_only_league_scale() -> void:
	var owner := _make_junior_owner(1.0)
	_expect_close(
		_build_draw_scale(owner),
		1.0,
		"junior visual override should keep league-only larger hitbox from enlarging the image"
	)
	owner.free()


func _verify_junior_visual_override_preserves_bulk_up_delta() -> void:
	var owner := _make_junior_owner(BULK_UP_SCALE)
	_expect_close(
		_build_draw_scale(owner),
		BULK_UP_SCALE,
		"junior visual override should still show Bulk Up's extra body scale"
	)
	owner.free()


func _verify_junior_visual_override_preserves_active_item_delta() -> void:
	var owner := _make_junior_owner(LONG_BOOST_SCALE)
	_expect_close(
		_build_draw_scale(owner),
		LONG_BOOST_SCALE,
		"junior visual override should still show active item body scale"
	)
	owner.free()


func _verify_no_override_uses_total_runtime_scale() -> void:
	var owner := FakeOwner.new()
	owner.player_paddle_width = BASE_WIDTH * BULK_UP_SCALE
	owner.player_paddle_height = BASE_HEIGHT * BULK_UP_SCALE
	owner.player_paddle_scale = BULK_UP_SCALE
	owner.player_paddle_visual_scale_override = -1.0
	_expect_close(_build_draw_scale(owner), BULK_UP_SCALE, "normal visual path should use the total runtime scale")
	owner.free()


func _make_junior_owner(dynamic_scale: float) -> FakeOwner:
	var owner := FakeOwner.new()
	owner.runtime_paddle_base_width = BASE_WIDTH * JUNIOR_SCALE
	owner.runtime_paddle_base_height = BASE_HEIGHT * JUNIOR_SCALE
	owner.player_paddle_width = owner.runtime_paddle_base_width * dynamic_scale
	owner.player_paddle_height = owner.runtime_paddle_base_height * dynamic_scale
	owner.player_paddle_scale = JUNIOR_SCALE * dynamic_scale
	owner.player_paddle_visual_scale_override = 1.0
	return owner


func _build_draw_scale(owner: Object) -> float:
	var context: Dictionary = BattleDrawPlayfieldSceneContext.new().build(owner, Vector2.ZERO, FakeRegistry.new())
	return float(context.get("player_paddle_scale", 0.0))


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.001:
		return
	_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])
