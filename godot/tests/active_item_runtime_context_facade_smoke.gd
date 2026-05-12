extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeContextFacade := preload("res://scripts/items/active_item_runtime_context_facade.gd")

var _failures: Array[String] = []


class FakeThrowController:
	extends RefCounted

	var windup_active := true
	var control_locked := false

	func is_throw_windup_active() -> bool:
		return windup_active

	func is_player_control_locked() -> bool:
		return control_locked

	func get_actor_draw_context() -> Dictionary:
		return {"throw_lane": true}

	func get_boss_ai_context() -> Dictionary:
		return {"throw_boss_lane": true}


class FakeEffectController:
	extends RefCounted

	var wall_installing := false
	var time_frozen := false
	var aipill_active := true
	var holy_hit_count := 0
	var brick_hit_count := 0
	var magnet_pull_count := 0

	func is_wall_installing() -> bool:
		return wall_installing

	func get_player_paddle_scale() -> float:
		return 1.25

	func get_player_paddle_width(base_width: float) -> float:
		return base_width * 1.25

	func get_player_paddle_height(base_height: float) -> float:
		return base_height * 1.25

	func get_player_speed_multiplier() -> float:
		return 1.4

	func get_aipill_context() -> Dictionary:
		return {
			"active": true,
			"phase": 0.5,
			"flash_timer_frames": 8.0,
			"flash_initial_frames": 16.0,
		}

	func is_aipill_active() -> bool:
		return aipill_active

	func is_stopwatch_active() -> bool:
		return time_frozen

	func is_holy_barrier_active() -> bool:
		return true

	func apply_aipill_player_control(player_pos: Vector2, player_speed: float, config: Dictionary, delta: float) -> Dictionary:
		return {
			"player_pos": player_pos + Vector2(player_speed * delta, 0.0),
			"config_seen": config.get("mode", ""),
		}

	func apply_aipill_guard_drain(special_gauge: float, _context: Dictionary, _deps: Dictionary) -> float:
		return special_gauge - 3.0

	func is_time_frozen() -> bool:
		return time_frozen

	func get_holy_barrier_collision_context() -> Dictionary:
		return {"holy_barrier_active": true}

	func get_brick_wall_collision_context() -> Dictionary:
		return {"brick_wall_active": true}

	func get_stopwatch_ball_context() -> Dictionary:
		return {"stopwatch_active": time_frozen}

	func apply_magnet_field_ball_pull(_fps_scale: float, context: Dictionary) -> Dictionary:
		magnet_pull_count += 1
		var result: Dictionary = context.duplicate(true)
		result["magnet_field_pull_applied"] = true
		return result

	func notify_holy_barrier_hit(_impact_pos: Vector2) -> void:
		holy_hit_count += 1

	func notify_brick_wall_hit(wall_index: int, _impact_pos: Vector2) -> Dictionary:
		brick_hit_count += 1
		return {"wall_index": wall_index, "destroyed": brick_hit_count >= 2}


class FakeRuntime:
	extends RefCounted

	var throw_controller := FakeThrowController.new()
	var effect_controller := FakeEffectController.new()


class FakeContextFacade:
	extends RefCounted

	var actor_calls := 0
	var magnet_calls := 0
	var brick_calls := 0

	func get_actor_draw_context(_runtime: Object) -> Dictionary:
		actor_calls += 1
		return {"delegated_actor": true}

	func apply_magnet_field_ball_pull(_runtime: Object, _fps_scale: float, _context: Dictionary) -> Dictionary:
		magnet_calls += 1
		return {"delegated_magnet": true}

	func notify_brick_wall_hit(_runtime: Object, wall_index: int, _impact_pos: Vector2) -> Dictionary:
		brick_calls += 1
		return {"delegated_wall": wall_index}


func _init() -> void:
	_verify_context_facade_merges_scene_contexts()
	_verify_context_facade_routes_interactions()
	_verify_runtime_delegates_scene_context_surface()

	if _failures.is_empty():
		print("active_item_runtime_context_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_facade_merges_scene_contexts() -> void:
	var facade: Object = ActiveItemRuntimeContextFacade.new()
	var runtime := FakeRuntime.new()

	var actor_context: Dictionary = facade.get_actor_draw_context(runtime)
	_expect(bool(actor_context.get("throw_lane", false)), "context facade should preserve throw actor context")
	_expect(bool(actor_context.get("active_item_aipill_active", false)), "context facade should merge aipill active flag")
	_expect(is_equal_approx(float(actor_context.get("active_item_aipill_phase", 0.0)), 0.5), "context facade should merge aipill phase")
	_expect(is_equal_approx(float(facade.get_player_paddle_width(runtime, 100.0)), 125.0), "context facade should delegate paddle width")
	_expect(is_equal_approx(float(facade.get_player_speed_multiplier(runtime)), 1.4), "context facade should delegate speed multiplier")

	var boss_context: Dictionary = facade.get_boss_ai_context(runtime)
	_expect(bool(boss_context.get("throw_boss_lane", false)), "context facade should preserve throw boss context")
	_expect(not bool(boss_context.get("active_item_stopwatch_freeze_active", true)), "boss context should expose stopwatch freeze state")

	runtime.effect_controller.time_frozen = true
	var ball_context: Dictionary = facade.get_ball_collision_context(runtime)
	_expect(bool(ball_context.get("holy_barrier_active", false)), "ball context should include holy barrier")
	_expect(bool(ball_context.get("brick_wall_active", false)), "ball context should include brick wall")
	_expect(bool(ball_context.get("stopwatch_active", false)), "ball context should include stopwatch")
	runtime.effect_controller.wall_installing = true
	_expect(bool(facade.is_player_control_locked(runtime)), "context facade should combine wall-install lock")


func _verify_context_facade_routes_interactions() -> void:
	var facade: Object = ActiveItemRuntimeContextFacade.new()
	var runtime := FakeRuntime.new()
	runtime.effect_controller.time_frozen = true
	_expect(facade.apply_magnet_field_ball_pull(runtime, 1.0, {"ball": true}).is_empty(), "time freeze should skip magnet pull")
	_expect(runtime.effect_controller.magnet_pull_count == 0, "skipped magnet pull should not call effect controller")

	runtime.effect_controller.time_frozen = false
	var pull_result: Dictionary = facade.apply_magnet_field_ball_pull(runtime, 1.0, {"ball": true})
	_expect(bool(pull_result.get("magnet_field_pull_applied", false)), "context facade should delegate magnet pull when time is not frozen")

	facade.notify_holy_barrier_hit(runtime, Vector2(200.0, 720.0))
	_expect(runtime.effect_controller.holy_hit_count == 1, "context facade should delegate holy barrier hit")
	_expect(
		not bool(facade.notify_brick_wall_hit(runtime, 0, Vector2(120.0, 710.0)).get("destroyed", true)),
		"context facade should delegate first brick hit"
	)
	_expect(
		bool(facade.notify_brick_wall_hit(runtime, 0, Vector2(120.0, 710.0)).get("destroyed", false)),
		"context facade should delegate second brick hit"
	)


func _verify_runtime_delegates_scene_context_surface() -> void:
	var inactive_runtime: Object = ActiveItemRuntime.new()
	_expect(not inactive_runtime.has_actor_draw_context(), "fresh runtime should skip empty actor draw context")
	_expect(inactive_runtime.get_actor_draw_context().is_empty(), "fresh runtime should return empty actor draw context")

	var runtime: Object = ActiveItemRuntime.new()
	var fake_facade := FakeContextFacade.new()
	runtime.context_facade = fake_facade

	_expect(bool(runtime.get_actor_draw_context().get("delegated_actor", false)), "runtime actor context should delegate to facade")
	_expect(bool(runtime.apply_magnet_field_ball_pull(1.0, {}).get("delegated_magnet", false)), "runtime magnet pull should delegate to facade")
	_expect(int(runtime.notify_brick_wall_hit(3, Vector2.ZERO).get("delegated_wall", -1)) == 3, "runtime brick hit should delegate to facade")
	_expect(fake_facade.actor_calls == 1, "runtime should call facade actor context once")
	_expect(fake_facade.magnet_calls == 1, "runtime should call facade magnet once")
	_expect(fake_facade.brick_calls == 1, "runtime should call facade brick once")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
