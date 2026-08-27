extends SceneTree

const CommandoSupplyDropRuntimeContext := preload("res://scripts/characters/commando_supply_drop_runtime_context.gd")

const CONTEXT_PATH := "res://scripts/characters/commando_supply_drop_runtime_context.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


class FakeActiveItemRuntime:
	extends RefCounted

	var calls := 0
	var collision_context: Dictionary = {}

	func get_ball_collision_context() -> Dictionary:
		calls += 1
		return collision_context


func _init() -> void:
	_verify_owner_boundary()
	_verify_collision_context_overlay_and_copy()
	_verify_invalid_base_context_is_safe()
	_verify_payload_spawn_projection()

	if _failures.is_empty():
		print("commando_supply_drop_runtime_context_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(CONTEXT_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropRuntimeContext := preload(\"%s\")" % CONTEXT_PATH) >= 0,
		"Supply Drop host should preload the focused runtime-context projection"
	)
	for moved_marker in [
		"func _get_aircraft_obstacle_context(",
		"func _get_payload_spawn_position(",
		"func _get_payload_center_background_bounds(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain runtime-context marker %s" % moved_marker)
	for delegation in [
		"CommandoSupplyDropRuntimeContext.build_collision_context(deps)",
		"CommandoSupplyDropRuntimeContext.get_payload_spawn_position(_aircraft_state.pos, deps)",
	]:
		_expect(host_source.find(delegation) >= 0, "Supply Drop host should delegate %s" % delegation)
	for owner_marker in [
		"static func build_collision_context(",
		"static func get_payload_spawn_position(",
		"static func get_payload_center_bounds(",
	]:
		_expect(owner_source.find(owner_marker) >= 0, "runtime-context projection should implement %s" % owner_marker)


func _verify_collision_context_overlay_and_copy() -> void:
	var active_items := FakeActiveItemRuntime.new()
	active_items.collision_context = {
		"priority": "active_item",
		"brick_walls": [Rect2(10.0, 20.0, 30.0, 40.0)],
	}
	var base_nested := {"value": 7}
	var deps := {
		"commando_supply_drop_collision_context": {
			"priority": "base",
			"player_pos": Vector2(100.0, 200.0),
			"nested": base_nested,
		},
		"active_item_runtime": active_items,
	}
	var projected: Dictionary = CommandoSupplyDropRuntimeContext.build_collision_context(deps)
	_expect(active_items.calls == 1, "runtime context should query the active-item collision facade once")
	_expect(str(projected.get("priority", "")) == "active_item", "active-item collision keys should override the base Supply Drop context")
	_expect(projected.get("player_pos", Vector2.ZERO) == Vector2(100.0, 200.0), "base player geometry should survive an unrelated active-item overlay")
	_expect((projected.get("brick_walls", []) as Array).size() == 1, "active-item obstacle geometry should reach the projected context")
	var nested: Dictionary = projected.get("nested", {})
	nested["value"] = 99
	_expect(int(base_nested.get("value", -1)) == 7, "runtime projection should deep-copy caller-owned nested context")


func _verify_invalid_base_context_is_safe() -> void:
	var active_items := FakeActiveItemRuntime.new()
	active_items.collision_context = {"player_paddle_rect": Rect2(1.0, 2.0, 3.0, 4.0)}
	var projected: Dictionary = CommandoSupplyDropRuntimeContext.build_collision_context({
		"commando_supply_drop_collision_context": "invalid",
		"active_item_runtime": active_items,
	})
	_expect(projected.get("player_paddle_rect", Rect2()) == Rect2(1.0, 2.0, 3.0, 4.0), "invalid base context should still accept a valid active-item overlay")
	_expect(CommandoSupplyDropRuntimeContext.build_collision_context({}).is_empty(), "missing collision providers should produce an empty context")


func _verify_payload_spawn_projection() -> void:
	var default_projected: Vector2 = CommandoSupplyDropRuntimeContext.get_payload_spawn_position(
		Vector2(-20.0, 700.0),
		{}
	)
	_expect(default_projected == Vector2(32.0, 735.0), "default payload projection should preserve safe X and playfield Y clamps")
	var custom_projected: Vector2 = CommandoSupplyDropRuntimeContext.get_payload_spawn_position(
		Vector2(500.0, -200.0),
		{
			"play_width": 400.0,
			"commando_supply_drop_center_min_x": 100.0,
			"commando_supply_drop_center_max_x": 300.0,
		}
	)
	_expect(custom_projected == Vector2(300.0, 15.0), "configured payload bounds should clamp both axes deterministically")
	var collapsed_bounds: Vector2 = CommandoSupplyDropRuntimeContext.get_payload_center_bounds({
		"play_width": 400.0,
		"commando_supply_drop_center_min_x": 350.0,
		"commando_supply_drop_center_max_x": 50.0,
	})
	_expect(collapsed_bounds == Vector2(200.0, 200.0), "inverted payload bounds should collapse to the playfield center")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
