extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const BASE_WIDTH := 155.0
const BASE_HEIGHT := 50.0
const FIELD_HEIGHT := 750.0
const BULK_UP_LV1_SCALE := 1.06


class SceneStateOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.set_value("selected_character_type", "smasher")
		scene_state.set_value("player_pos", Vector2(302.5, FIELD_HEIGHT - BASE_HEIGHT))
		scene_state.set_value("player_paddle_width", BASE_WIDTH)
		scene_state.set_value("player_paddle_height", BASE_HEIGHT)
		scene_state.set_value("player_paddle_scale", 1.0)
		scene_state.set_value("runtime_paddle_scale", 1.0)

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true


class FakeRegistry:
	var active_item_runtime: Object

	func _init(active_runtime: Object) -> void:
		active_item_runtime = active_runtime

	func get_instance(key: String) -> Object:
		if key == "active_item_runtime":
			return active_item_runtime
		return null


func _init() -> void:
	var owner := SceneStateOwner.new()
	var perk_state: Object = RuntimePerkState.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var registry := FakeRegistry.new(active_runtime)

	_expect(
		perk_state.apply_choice({"id": "common_bulk_up", "name": "Bulk Up"}, owner, registry),
		"bulk up should apply as a normal runtime perk"
	)
	_expect_close(float(owner.get("runtime_paddle_scale")), BULK_UP_LV1_SCALE, "bulk up scale should be persisted on battle state")
	_expect_close(float(owner.get("player_paddle_width")), BASE_WIDTH * BULK_UP_LV1_SCALE, "bulk up should resize the live paddle width immediately")
	_expect_close(float(owner.get("player_paddle_height")), BASE_HEIGHT * BULK_UP_LV1_SCALE, "bulk up should resize the live paddle height immediately")
	_expect_close(_paddle_bottom(owner), FIELD_HEIGHT, "bulk up should keep the grounded paddle bottom aligned")

	active_runtime.effect_controller.sync_long_boost_owner_state(owner, null)
	_expect_close(float(owner.get("player_paddle_width")), BASE_WIDTH * BULK_UP_LV1_SCALE, "active-item sync must not reset bulk up width")
	_expect_close(float(owner.get("player_paddle_height")), BASE_HEIGHT * BULK_UP_LV1_SCALE, "active-item sync must not reset bulk up height")
	_expect_close(float(owner.get("player_paddle_scale")), BULK_UP_LV1_SCALE, "active-item sync must preserve bulk up draw scale")

	var ball_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	var paddle_size: Vector2 = ball_context.get("player_paddle_size", Vector2.ZERO)
	_expect_close(paddle_size.x, BASE_WIDTH * BULK_UP_LV1_SCALE, "ball collision context should use bulk up width")
	_expect_close(paddle_size.y, BASE_HEIGHT * BULK_UP_LV1_SCALE, "ball collision context should use bulk up height")
	_expect_close(float(ball_context.get("paddle_width", 0.0)), BASE_WIDTH * BULK_UP_LV1_SCALE, "legacy paddle_width context should use bulk up width")

	print("runtime_bulk_up_paddle_sync_smoke: ok")
	quit(0)


func _paddle_bottom(owner: Object) -> float:
	var player_pos: Vector2 = owner.get("player_pos")
	return player_pos.y + float(owner.get("player_paddle_height"))


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) <= 0.02:
		return
	push_error("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
