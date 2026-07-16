extends SceneTree

const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const BallRoundState := preload("res://scripts/ball/ball_round_state.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleSceneBallUpdateDriver := preload("res://scripts/core/battle_scene_ball_update_driver.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")

const FIELD_HEIGHT := 750.0
const PLAYER_PADDLE_HEIGHT := 50.0
const PLAYER_Y := FIELD_HEIGHT - PLAYER_PADDLE_HEIGHT

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "viper",
		"gameplay_frame_counter": 1,
		"battle_textures": {},
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"ball_pos": Vector2(340.0, 760.0),
		"ball_pos_prev": Vector2(340.0, 730.0),
		"ball_vel": Vector2(0.0, 12.0),
		"ball_active": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_vel": 3.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_max_health": 20,
		"boss_current_health": 7,
		"boss_health_damage_units": 13,
		"boss_defeated_by_health": true,
		"player_pos": Vector2(302.5, PLAYER_Y),
		"player_speed": 6.0,
		"player_paddle_width": 155.0,
		"player_paddle_height": PLAYER_PADDLE_HEIGHT,
		"starting_dash_tokens": 3,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func queue_redraw() -> void:
		values["queue_redraw_calls"] = int(values.get("queue_redraw_calls", 0)) + 1


class FakeRoundState:
	extends RefCounted

	var player_serves := false
	var waiting_for_serve := false
	var reset_wait_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting_for_serve = true
		reset_wait_calls += 1

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(owner: Object) -> void:
		reset_calls += 1
		owner.set("boss_current_health", owner.get("boss_max_health"))
		owner.set("boss_health_damage_units", 0)
		owner.set("boss_defeated_by_health", false)


class FakeAudio:
	extends RefCounted

	var viper_loop_active := false
	var viper_loop_sync_calls := 0

	func sync_viper_jetpack_loop(active: bool) -> void:
		viper_loop_active = active
		viper_loop_sync_calls += 1

	func stop_viper_jetpack_loop() -> void:
		sync_viper_jetpack_loop(false)

	func stop_stage2_quake_loop() -> void:
		pass

	func stop_stage3_psychoball_loop() -> void:
		pass

	func stop_stage5_hongryun_charge() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_odins_eye_revival_finalize_lands_viper_paddle()

	if _failures.is_empty():
		print("odins_eye_finalize_paddle_land_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_odins_eye_revival_finalize_lands_viper_paddle() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var round_state := FakeRoundState.new()
	var audio := FakeAudio.new()
	var jetpack_state: Object = ViperJetpackState.new()
	var boss_health := FakeBossHealthFlow.new()
	var context_builder: Object = BallUpdateContext.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"battle_scene_ball_update_driver": BattleSceneBallUpdateDriver.new(),
		"battle_scene_boss_health_flow": boss_health,
		"ball_round_controller": BallRoundController.new(),
		"ball_round_state": BallRoundState.new(),
		"ball_update_context": context_builder,
		"round_flow_state": round_state,
		"game_audio": audio,
		"smasher_dash_state": SmasherDashState.new(),
		"viper_jetpack_state": jetpack_state,
	})

	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"Odin's Eye should equip before finalize landing smoke"
	)
	_expect(
		runtime.try_trigger_odins_eye_revival("round", 0.0),
		"Odin's Eye should start the revival sequence"
	)

	jetpack_state.set_offset_y(-120.0, {"audio": audio})
	jetpack_state.active = true
	owner.set("player_pos", Vector2(302.5, PLAYER_Y + float(jetpack_state.get_offset_y())))
	_expect(jetpack_state.is_airborne(0.1), "smoke should begin with Viper airborne")
	_expect(not is_equal_approx(_get_vector2(owner, "player_pos").y, PLAYER_Y), "smoke should begin with airborne owner y")

	owner.set("gameplay_frame_counter", int(owner.get("gameplay_frame_counter")) + 1)
	BattleSceneItemUpdateDriver.new().update_mythic_items(owner, registry, 3.85)

	var player_pos: Vector2 = _get_vector2(owner, "player_pos")
	_expect(not runtime.is_odins_eye_revival_animation_active(), "revival animation should be finalized")
	_expect(runtime.is_odins_eye_penalty_active(), "revival finalize should keep Odin penalty active")
	_expect(runtime.has_odins_eye_revival_used(), "revival finalize should keep Odin used for the penalty cycle")
	_expect(is_equal_approx(float(jetpack_state.get_offset_y()), 0.0), "reset_ball chain should clear Viper jetpack offset")
	_expect(not jetpack_state.is_airborne(0.1), "reset_ball chain should land Viper")
	_expect(is_equal_approx(player_pos.y, PLAYER_Y), "revival finalize should snap Viper paddle back to floor Y")
	_expect(is_equal_approx(player_pos.x, 302.5), "revival finalize should keep centered player X")
	_expect(round_state.player_serves and round_state.waiting_for_serve, "revival finalize should return to player serve wait")
	_expect(round_state.reset_wait_calls >= 1, "real reset_ball chain should touch round wait cleanup")
	_expect(_get_vector2(owner, "ball_pos") == Vector2(380.0, 375.0), "real reset_ball should center the ball")
	_expect(not bool(owner.get("ball_active")), "real reset_ball should leave the ball inactive for serve wait")
	_expect(int(owner.get("boss_current_health")) == 20, "revival finalize should reset boss round health")
	_expect(int(owner.get("boss_health_damage_units")) == 0, "revival finalize should clear boss damage units")
	_expect(not bool(owner.get("boss_defeated_by_health")), "revival finalize should clear boss defeated flag")
	_clear_context_cache(context_builder)
	registry.instances.clear()


func _get_vector2(owner: Object, key: String) -> Vector2:
	var value: Variant = owner.get(key)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _clear_context_cache(context_builder: Object) -> void:
	if context_builder == null or context_builder.dependency_context == null:
		return
	var dependency_context: Object = context_builder.dependency_context
	dependency_context._cached_update_registry = null
	dependency_context._cached_update_deps.clear()
	dependency_context._has_cached_update_deps = false
	dependency_context._cached_round_registry = null
	dependency_context._cached_round_deps.clear()
	dependency_context._has_cached_round_deps = false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
