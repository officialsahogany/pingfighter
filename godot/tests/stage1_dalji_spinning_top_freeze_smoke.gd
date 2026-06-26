extends SceneTree

const BossAI := preload("res://scripts/ai/boss_ai_state.gd")
const BossAIContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const SpinningTop := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var selected_character_type := "smasher"
	var ai_mode := "champion"
	var ball_active := true
	var ball_pos := Vector2(700.0, 400.0)
	var ball_vel := Vector2(2.0, -4.0)
	var boss_hitbox_height := 40.0
	var boss_paddle_width := 100.0
	var boss_pos := Vector2(330.0, 25.0)
	var player_pos := Vector2(300.0, 675.0)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_context_builder_merges_freeze_flag()
	_verify_freeze_holds_boss()
	_verify_freeze_releases_after_one_second()

	if _failures.is_empty():
		print("stage1_dalji_spinning_top_freeze_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base_ctx() -> Dictionary:
	return {
		"current_stage": 1,
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_mistake_chance": 0.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(700.0, 400.0),
		"ball_vel": Vector2(2.0, -4.0),
	}


func _verify_freeze_holds_boss() -> void:
	var top: Object = SpinningTop.new()
	_expect(top.activate({"current_stage": 1, "boss_pos": Vector2(330.0, 25.0)}, {}), "spinning top should activate")
	_expect(
		bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]),
		"freeze should be active immediately after activation"
	)

	var ctx: Dictionary = _base_ctx()
	ctx.merge(top.get_ai_context(), true)
	var boss_in := Vector2(330.0, 25.0)
	var frozen_result: Dictionary = BossAI.new().update(1.0 / 60.0, boss_in, 0.0, ctx)
	_expect(absf(float(frozen_result["boss_vel"])) < 0.0001, "frozen boss velocity should be zero")
	_expect(frozen_result["boss_pos"] == boss_in, "frozen boss position should be held")

	var ctx_off: Dictionary = _base_ctx()
	var moving_result: Dictionary = BossAI.new().update(1.0 / 60.0, boss_in, 0.0, ctx_off)
	_expect(absf(float(moving_result["boss_vel"])) > 0.0001, "without the freeze flag, boss AI should still move")


func _verify_context_builder_merges_freeze_flag() -> void:
	var top: Object = SpinningTop.new()
	_expect(top.activate({"current_stage": 1, "boss_pos": Vector2(330.0, 25.0)}, {}), "spinning top should activate for context merge")
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage1_dalji_spinning_top_skill_state": top,
	}
	var context: Dictionary = BossAIContextBuilder.new().build_context(FakeOwner.new(), registry)
	_expect(
		bool(context.get("stage1_dalji_spinning_top_freeze_active", false)),
		"boss AI context builder should merge spinning top freeze flag"
	)


func _verify_freeze_releases_after_one_second() -> void:
	var top: Object = SpinningTop.new()
	_expect(top.activate({"current_stage": 1, "boss_pos": Vector2(330.0, 25.0)}, {}), "spinning top should activate for release check")
	var scene := {
		"ball_pos": Vector2(380.0, 400.0),
		"ball_vel": Vector2.ZERO,
	}
	for _i in range(60):
		top.update_and_collide(1.0, scene, _base_ctx(), {})
	_expect(
		not bool(top.get_ai_context()["stage1_dalji_spinning_top_freeze_active"]),
		"freeze should release after 60 frames"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
