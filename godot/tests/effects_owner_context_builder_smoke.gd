extends SceneTree

const EffectsOwnerContextBuilder := preload("res://scripts/core/battle_update_effects_owner_context_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)


class FakeRoundState:
	extends RefCounted

	var waiting := false

	func _init(next_waiting: bool) -> void:
		waiting = next_waiting

	func is_waiting_for_serve() -> bool:
		return waiting


class FakeDashState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"tokens": 1,
			"max_tokens": 2,
			"active": true,
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances.duplicate()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var owner := FakeOwner.new({
		"current_stage": 2,
		"ai_mode": "test_ai",
		"enraged_boss_active": true,
		"drive_text_timer_frames": 33.0,
		"ball_pos": Vector2(111.0, 222.0),
		"ball_vel": Vector2(-3.0, 4.0),
		"ball_active": true,
		"ball_impact_boost": 1.35,
		"special_gauge": 123.0,
		"special_gauge_max": 0.2,
		"player_speed": 7.0,
		"player_collision_cooldown": 0.45,
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_width": -5.0,
		"player_paddle_height": 66.0,
		"boss_pos": Vector2(350.0, 25.0),
		"boss_vel": -2.5,
		"boss_collision_cooldown": 0.8,
		"battle_textures": {
			"viper_player_sprite_texture": _make_texture(),
		},
		"selected_character_type": "viper",
	})
	var registry := FakeRegistry.new({
		"round_flow_state": FakeRoundState.new(false),
		"smasher_dash_state": FakeDashState.new(),
	})
	var dash_snapshot := {
		"tokens": 3,
		"max_tokens": 4,
		"active": true,
	}
	var builder: Object = EffectsOwnerContextBuilder.new()
	var context: Dictionary = builder.build_context(owner, registry, "viper", dash_snapshot)

	_expect(context.get("owner", null) == owner, "owner context should keep owner reference")
	_expect(context.get("registry", null) == registry, "owner context should keep registry reference")
	_expect(int(context.get("current_msec", 0)) > 0, "owner context should include current msec")
	_expect(int(context.get("current_stage", 0)) == 2, "owner context should copy current stage")
	_expect(str(context.get("ai_mode", "")) == "test_ai", "owner context should copy AI mode")
	_expect(bool(context.get("enraged_boss_active", false)), "owner context should copy enrage state")
	_expect(str(context.get("selected_character_type", "")) == "viper", "owner context should use supplied character type")
	_expect(float(context.get("width", 0.0)) == 760.0 and float(context.get("height", 0.0)) == 750.0, "owner context should include playfield dimensions")
	_expect(float(context.get("play_left", -1.0)) == 0.0 and float(context.get("play_right", 0.0)) == 760.0, "owner context should include play bounds")
	_expect(context.get("dash_snapshot", {}) == dash_snapshot, "owner context should keep supplied dash snapshot")
	_expect(float(context.get("drive_text_timer_frames", 0.0)) == 33.0, "owner context should copy Drive text timer")
	_expect(context.get("ball_pos", Vector2.ZERO) == Vector2(111.0, 222.0), "owner context should copy ball position")
	_expect(context.get("ball_vel", Vector2.ZERO) == Vector2(-3.0, 4.0), "owner context should copy ball velocity")
	_expect(bool(context.get("ball_active", false)), "owner context should copy ball active")
	_expect(not bool(context.get("waiting_for_serve", true)), "owner context should read round wait state")
	_expect_close(float(context.get("ball_impact_boost", 0.0)), 1.35, "owner context should copy impact boost")
	_expect_close(float(context.get("ball_size", 0.0)), 28.6, "owner context should include ball size")
	_expect_close(float(context.get("special_gauge", 0.0)), 123.0, "owner context should copy special gauge")
	_expect_close(float(context.get("gauge_max", 0.0)), 1.0, "owner context should clamp max gauge")
	_expect_close(float(context.get("player_speed", 0.0)), 7.0, "owner context should copy player speed")
	_expect_close(float(context.get("player_collision_cooldown", 0.0)), 0.45, "owner context should copy collision cooldown")
	_expect(context.get("player_pos", Vector2.ZERO) == Vector2(300.0, 680.0), "owner context should copy player position")
	_expect(context.get("player_paddle_size", Vector2.ZERO) == Vector2(1.0, 66.0), "owner context should clamp player paddle size")
	_expect(context.get("boss_pos", Vector2.ZERO) == Vector2(350.0, 25.0), "owner context should copy boss position")
	_expect_close(float(context.get("boss_vel", 0.0)), -2.5, "owner context should copy boss velocity")
	_expect_close(float(context.get("boss_collision_cooldown", 0.0)), 0.8, "owner context should copy boss cooldown")
	_expect_close(float(context.get("boss_paddle_width", 0.0)), 100.0, "owner context should include boss paddle width")
	_expect_close(float(context.get("boss_hitbox_height", 0.0)), 40.0, "owner context should include boss hitbox height")

	var default_context: Dictionary = builder.build_context(FakeOwner.new({}), FakeRegistry.new(), "smasher", {})
	_expect(bool(default_context.get("waiting_for_serve", false)), "missing round state should default to waiting for serve")
	_expect(default_context.get("player_paddle_size", Vector2.ZERO) == Vector2(155.0, 50.0), "default owner context should use base paddle size")

	var facade_context: Dictionary = BattleUpdateEffectsContext.new().build_context(owner, registry)
	_expect(str(facade_context.get("selected_character_type", "")) == "viper", "effects facade should keep sprite-normalized character")
	_expect(bool(facade_context.get("player_has_sprite", false)), "effects facade should merge sprite context")
	var facade_dash: Dictionary = facade_context.get("dash_snapshot", {})
	_expect(int(facade_dash.get("tokens", 0)) == 1 and bool(facade_dash.get("active", false)), "effects facade should use live dash snapshot")
	_expect(not bool(facade_context.get("waiting_for_serve", true)), "effects facade should merge owner wait state")

	if _failures.is_empty():
		print("effects_owner_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
