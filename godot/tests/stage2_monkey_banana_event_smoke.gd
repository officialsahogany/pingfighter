extends SceneTree

const Stage2MonkeyBananaEvent := preload("res://scripts/stages/stage2/stage2_monkey_banana_event.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")


class FakeAudio:
	extends RefCounted

	var banana_throw_count := 0
	var banana_slip_count := 0

	func play_banana_throw() -> void:
		banana_throw_count += 1

	func play_banana_slip() -> void:
		banana_slip_count += 1


func _init() -> void:
	var event: Object = Stage2MonkeyBananaEvent.new()
	event.sync_layout({
		"view_size": Vector2(1488.0, 918.0),
		"game_offset": Vector2(364.0, 84.0),
		"game_size": Vector2(760.0, 750.0),
	})
	event.prewarm_assets()
	_expect(event.tree_source_image != null and not event.tree_source_image.is_empty(), "Stage 2 monkey prewarm should load the source tree image during transition loading")
	_expect(event.tree_source_path_cache.has("left"), "Stage 2 monkey prewarm should cache the left tree path before the first spawn")
	_expect(event.tree_source_path_cache.has("right"), "Stage 2 monkey prewarm should cache the right tree path before the first spawn")
	var snapshot: Dictionary = event.get_debug_snapshot()
	_expect(abs(float(snapshot.get("first_event_min", 0.0)) - 5.0) <= 0.001, "first monkey spawn minimum should match the original 5 seconds")
	_expect(abs(float(snapshot.get("first_event_max", 0.0)) - 10.0) <= 0.001, "first monkey spawn maximum should match the original 10 seconds")
	_expect(abs(float(snapshot.get("repeat_event_min", 0.0)) - 15.0) <= 0.001, "repeat monkey spawn minimum should match the original 15 seconds")
	_expect(abs(float(snapshot.get("repeat_event_max", 0.0)) - 30.0) <= 0.001, "repeat monkey spawn maximum should match the original 30 seconds")
	_expect(abs(float(snapshot.get("player_target_probability", 0.0)) - 0.4) <= 0.001, "banana target probability should keep player at 40 percent")
	_expect(abs(float(snapshot.get("boss_target_probability", 0.0)) - 0.6) <= 0.001, "banana target probability should keep boss at 60 percent")
	_expect(abs(float(snapshot.get("throw_delay_min", 0.0)) - 1.5) <= 0.001, "monkey throw delay minimum should match the original")
	_expect(abs(float(snapshot.get("throw_delay_max", 0.0)) - 3.0) <= 0.001, "monkey throw delay maximum should match the original")
	_expect(str(snapshot.get("tree_path_source", "")) == "stage2_tree_alpha_median", "monkey climb path should be built from the pillar tree alpha median")
	var left_trunk_points: Array = event.debug_get_trunk_points("left")
	var right_trunk_points: Array = event.debug_get_trunk_points("right")
	_expect(left_trunk_points.size() == int(snapshot.get("tree_trunk_segments", 0)) + 1, "left monkey tree path should expose the original segment count")
	_expect(right_trunk_points.size() == int(snapshot.get("tree_trunk_segments", 0)) + 1, "right monkey tree path should expose the original segment count")
	_expect(_as_vector2(left_trunk_points[0], Vector2.ZERO).y > _as_vector2(left_trunk_points[left_trunk_points.size() - 1], Vector2.ZERO).y, "left monkey should climb upward along the rendered pillar tree")
	_expect(_as_vector2(right_trunk_points[0], Vector2.ZERO).y > _as_vector2(right_trunk_points[right_trunk_points.size() - 1], Vector2.ZERO).y, "right monkey should climb upward along the rendered pillar tree")

	var context := _build_context()
	var throw_audio := FakeAudio.new()
	event.reset()
	_expect(event.force_spawn_monkey("left"), "monkey should force-spawn on the left tree")
	for _frame in range(11 * 60):
		event.update(1.0 / 60.0, context, {"audio": throw_audio})
	_expect(throw_audio.banana_throw_count >= 1, "monkey should throw after climbing and waiting")

	event.reset()
	var player_slip_audio := FakeAudio.new()
	event.debug_spawn_landed_banana(Vector2(320.0, 700.0), true)
	var slip_result: Dictionary = event.update(1.0 / 60.0, context, {"audio": player_slip_audio})
	_expect(player_slip_audio.banana_slip_count == 1, "player banana collision should play slip sound")
	_expect(slip_result.has("player_pos"), "player banana collision should move the player through the effects result")

	event.reset()
	var boss_slip_audio := FakeAudio.new()
	context["boss_vel"] = 5.0
	event.debug_spawn_landed_banana(Vector2(340.0, 50.0), false)
	event.update(1.0 / 60.0, context, {"audio": boss_slip_audio})
	var ai_context: Dictionary = event.get_boss_ai_context()
	_expect(bool(ai_context.get("stage2_monkey_banana_boss_slip_active", false)), "boss banana collision should expose monkey-banana slip context")
	var boss_result: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(300.0, 25.0), 5.0, ai_context)
	_expect(float(boss_result.get("boss_vel", 0.0)) > 0.0, "boss AI should slide in the monkey-banana slip direction")

	print("stage2_monkey_banana_event_smoke: ok")
	quit(0)


func _build_context() -> Dictionary:
	return {
		"current_stage": 2,
		"width": 760.0,
		"height": 750.0,
		"view_size": Vector2(1488.0, 918.0),
		"game_offset": Vector2(364.0, 84.0),
		"game_size": Vector2(760.0, 750.0),
		"player_pos": Vector2(280.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false, "direction": 0},
		"boss_pos": Vector2(320.0, 25.0),
		"boss_vel": 0.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"special_gauge": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
