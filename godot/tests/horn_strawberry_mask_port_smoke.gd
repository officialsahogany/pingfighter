extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const BattleUpdatePlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"special_gauge": 500.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 35.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeFeedback:
	extends RefCounted

	var gauge_flash_count := 0
	var screen_shakes: Array[Dictionary] = []

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1

	func max_screen_shake(amount: float, intensity: float) -> void:
		screen_shakes.append({"amount": amount, "intensity": intensity})


class FakeStatusEffectState:
	extends RefCounted

	var applied_statuses: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied_statuses.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		})
		return {"active": true}


class FakeBossAiState:
	extends RefCounted

	var clear_count := 0
	var knockback_requests: Array[Dictionary] = []

	func clear_paddle_hit_knockback() -> void:
		clear_count += 1

	func start_paddle_hit_knockback(
		velocity: float,
		frames: float = 36.0,
		decay_per_frame: float = 0.85,
		replace_current: bool = true
	) -> void:
		knockback_requests.append({
			"velocity": velocity,
			"frames": frames,
			"decay_per_frame": decay_per_frame,
			"replace_current": replace_current,
		})


class FakeDashTokenState:
	extends RefCounted

	var dash_tokens := 0
	var dash_tokens_max := 1
	var dash_charge_timer := 120.0


class FakeDashState:
	extends RefCounted

	var token_state: Object = FakeDashTokenState.new()

	func get_snapshot() -> Dictionary:
		return {
			"tokens": token_state.dash_tokens,
			"max_tokens": token_state.dash_tokens_max,
		}


class FakeContextBuilder:
	extends RefCounted

	func build_player_control_config(_character_type: String) -> Dictionary:
		return {
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary = {}) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_registration()
	_verify_runtime_command_transform_and_stage_policy()
	_verify_runtime_stat_hooks_and_skill_lock()
	_verify_eat_and_field_runtime()
	_verify_horn_charge_and_bomb_runtime()

	if _failures.is_empty():
		print("horn_strawberry_mask_port_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("horn_strawberry_mask")
	_expect(not item_data.is_empty(), "horn strawberry mask should build from catalog")
	_expect(str(item_data.get("slot", "")) == "head", "horn strawberry mask should use the head slot")
	_expect(str(item_data.get("display_name", "")) == "뿔딸기 변신가면", "horn strawberry mask should expose the Korean display name")
	_expect(_catalog_has_field_spawn(catalog, "horn_strawberry_mask"), "horn strawberry mask should be in the field spawn pool")
	_expect(_catalog_has_debug_item(catalog, "horn_strawberry_mask"), "horn strawberry mask should be in the debug item list")

	var rolls: Array = catalog.get_roll_options("horn_strawberry_mask")
	_expect(rolls.size() == 1, "horn strawberry mask should expose one roll option")
	var duration_roll: Dictionary = _find_roll(rolls, "transform_duration")
	_expect(not duration_roll.is_empty(), "horn strawberry mask should expose transform_duration")
	_expect(is_equal_approx(float(duration_roll.get("min", 0.0)), 50.0), "transform duration min should match the reference")
	_expect(is_equal_approx(float(duration_roll.get("max", 0.0)), 70.0), "transform duration max should match the reference")
	_expect(is_equal_approx(float(duration_roll.get("default", 0.0)), 60.0), "transform duration default should match the reference")
	_expect(is_equal_approx(float(duration_roll.get("step", 0.0)), 5.0), "transform duration step should match the reference")
	_verify_icon_asset("res://assets/sprites/items/horn_strawberry_mask.png", Vector2i(32, 32), "static icon")
	_verify_icon_asset("res://assets/sprites/items/horn_strawberry_mask_icon_sheet.png", Vector2i(1024, 32), "animated icon sheet")


func _verify_runtime_command_transform_and_stage_policy() -> void:
	var owner := FakeOwner.new()
	var input_reader := FakeInputReader.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": input_reader,
		"battle_feedback_state": feedback,
	})
	var runtime: Object = MythicItemRuntime.new()

	_expect(
		runtime.equip_item("horn_strawberry_mask", owner, registry, {"transform_duration": 55.0}, false),
		"horn strawberry mask should equip through mythic runtime"
	)
	_expect(str(owner.values.get("equipment_slots", {}).get("head", {}).get("name", "")) == "horn_strawberry_mask", "horn strawberry mask should sync into the head slot")
	_expect(bool(owner.values.get("horn_strawberry_mask_equipped", false)), "owner should expose horn strawberry equipped state")
	_expect(str(runtime.get_horn_strawberry_context().get("state", "")) == "idle", "equipped horn strawberry mask should start idle")
	_expect(is_equal_approx(float(runtime.get_horn_strawberry_context().get("transform_duration_sec", 0.0)), 55.0), "runtime should use the rolled transform duration")

	_feed_command_through_update(runtime, owner, registry, input_reader)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", -1.0)), 0.0), "transform command should spend 500 gauge")
	_expect(feedback.gauge_flash_count >= 1, "transform command should trigger gauge feedback")
	_expect(runtime.is_horn_strawberry_event_playing(), "transform command should start the transform event")
	_expect(runtime.should_pause_game(), "transform event should freeze gameplay through the mythic pause gate")
	_expect(bool(runtime.get_horn_strawberry_context().get("used_this_stage", false)), "transform should mark the stage use")
	_expect(bool(owner.values.get("horn_strawberry_event_playing", false)), "transient owner sync should expose transform event")

	runtime.update(owner, registry, 4.5)
	_expect(runtime.is_horn_strawberry_transformed(), "transform event should finalize into transformed state")
	_expect(not runtime.should_pause_game(), "finished transform should release the mythic pause gate")
	_expect(runtime.has_visible_field_effects(), "transformed horn strawberry should keep the duration timer draw path alive")
	_expect(runtime.is_horn_strawberry_skills_locked(), "transformed state should lock character skills")
	_expect(is_equal_approx(float(runtime.get_horn_strawberry_move_speed()), 8.0), "transformed move speed should match the reference")
	_expect(is_equal_approx(runtime.get_horn_strawberry_gauge_on_hit(), 80.0), "transformed gauge-on-hit should match the reference")
	_expect(is_equal_approx(runtime.get_horn_strawberry_paddle_size_bonus_pct(), 0.0), "base transformed paddle bonus should stay zero")

	runtime.update(owner, registry, 55.0)
	_expect(runtime.is_horn_strawberry_event_playing(), "rolled transform duration should enter detransform event")
	_expect(not runtime.is_horn_strawberry_transformed(), "detransform event should clear transformed state")
	runtime.update(owner, registry, 2.0)
	_expect(str(runtime.get_horn_strawberry_context().get("state", "")) == "idle", "detransform event should return to idle")

	owner.values["special_gauge"] = 500.0
	_expect(not runtime.try_horn_strawberry_transform(owner, registry), "same-stage second transform should be blocked")
	runtime.reset_round(registry)
	_expect(not runtime.try_horn_strawberry_transform(owner, registry), "round reset should preserve the stage-use lock")

	runtime.on_stage_advance(owner, registry)
	owner.values["special_gauge"] = 500.0
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "stage advance should clear the one-use lock")


func _verify_runtime_stat_hooks_and_skill_lock() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"battle_feedback_state": feedback,
	})
	_equip_and_finish_transform(runtime, owner, registry)

	var config_builder: Object = BattleScenePlayerControlConfigBuilder.new()
	var movement_config: Dictionary = config_builder.build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	_expect(is_equal_approx(float(movement_config.get("paddle_speed", 0.0)), 8.0), "transformed horn strawberry should override paddle_speed to 8")
	_expect(is_equal_approx(float(movement_config.get("paddle_max_speed", 0.0)), 8.0), "transformed horn strawberry should override paddle_max_speed to 8")
	_expect(bool(movement_config.get("player_skill_input_locked", false)), "transformed horn strawberry should mark player skill input locked")

	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {
		"left_pressed": true,
		"right_pressed": false,
		"direction": -1.0,
		"up_pressed": true,
		"down_pressed": true,
		"action_pressed": true,
		"action_just_pressed": true,
		"jetpack_pressed": true,
		"supply_drop_hold_pressed": true,
		"commando_supply_drop_hold_pressed": true,
		"power_smash_direction": -1,
	}
	var deps_builder: Object = BattleUpdatePlayerControlDepsBuilder.new()
	var deps: Dictionary = deps_builder.build_deps(FakeRegistry.new({
		"smasher_input_reader": raw_reader,
		"mythic_item_runtime": runtime,
	}), "smasher")
	var locked_reader: Object = deps.get("input_reader", null)
	var locked_snapshot: Dictionary = locked_reader.get_snapshot() if locked_reader != null and locked_reader.has_method("get_snapshot") else {}
	_expect(bool(locked_snapshot.get("left_pressed", false)), "skill lock input proxy should preserve left movement")
	_expect(is_equal_approx(float(locked_snapshot.get("direction", 0.0)), -1.0), "skill lock input proxy should preserve movement direction")
	_expect(not bool(locked_snapshot.get("up_pressed", true)), "skill lock input proxy should clear up skill input")
	_expect(not bool(locked_snapshot.get("down_pressed", true)), "skill lock input proxy should clear down skill input")
	_expect(not bool(locked_snapshot.get("action_pressed", true)), "skill lock input proxy should clear action skill input")
	_expect(not bool(locked_snapshot.get("jetpack_pressed", true)), "skill lock input proxy should clear Viper jetpack input")
	_expect(not bool(locked_snapshot.get("supply_drop_hold_pressed", true)), "skill lock input proxy should clear Commando supply input")
	_expect(int(locked_snapshot.get("power_smash_direction", 1)) == 0, "skill lock input proxy should clear power-smash direction")

	# --- Dash-during-transform regression seal (reported bug: 뿔딸기 변신 후 대쉬 불가) ---
	# Dash is core movement (Python keeps down_pressed live during transform; only the original
	# character skills are gated). The routed input_reader is a skill-lock proxy that zeroes
	# down_pressed to block down-based skills (warp gate / EMP dive), which also killed dash. The
	# controllers now read the dash trigger from deps["dash_input_reader"] (pre-skill-lock,
	# status-proxied), which must keep down_pressed live.
	var dash_reader: Object = deps.get("dash_input_reader", null)
	_expect(dash_reader != null, "transform deps should expose a pre-skill-lock dash_input_reader")
	_expect(dash_reader != locked_reader, "dash_input_reader should bypass the skill-lock proxy during transform")
	var dash_snapshot: Dictionary = dash_reader.get_snapshot() if dash_reader != null and dash_reader.has_method("get_snapshot") else {}
	_expect(bool(dash_snapshot.get("down_pressed", false)), "dash_input_reader should keep down_pressed live so dash survives the transform")
	var smasher_controller: Object = SmasherPlayerController.new()
	_expect(
		smasher_controller._read_dash_down_pressed(deps, locked_reader, locked_snapshot),
		"smasher controller should read the live down trigger for dash during transform"
	)
	# Reverse-verification: with no separate dash reader (dash_input_reader == locked_reader) the
	# controller falls back to the locked snapshot and dash stays dead — proving the plumbing is
	# load-bearing and this smoke would FAIL on the pre-fix code path.
	_expect(
		not smasher_controller._read_dash_down_pressed({"dash_input_reader": locked_reader}, locked_reader, locked_snapshot),
		"without a separate dash reader the controller reads the locked snapshot (dash blocked)"
	)

	var event_router: Object = PaddleBounceEventRouter.new()
	var gauge_after_hit: float = event_router.register_player_hit(
		Vector2(380.0, 690.0),
		0.0,
		false,
		false,
		100.0,
		{
			"gauge_charge_per_hit": 30.0,
			"gauge_max": 500.0,
			"selected_character_type": "smasher",
		},
		{
			"mythic_item_runtime": runtime,
			"feedback": feedback,
		}
	)
	_expect(is_equal_approx(gauge_after_hit, 180.0), "transformed horn strawberry should replace base hit gauge with standalone +80")

	_expect(runtime.add_horn_strawberry_eat_paddle_growth(owner, registry, 0.20), "eat paddle growth hook should add transformed paddle bonus")
	_expect(is_equal_approx(runtime.get_horn_strawberry_paddle_size_bonus_pct(), 0.20), "eat paddle growth hook should expose +20 percent bonus")
	_expect(is_equal_approx(float(owner.values.get("player_paddle_width", 0.0)), 186.0), "eat paddle growth hook should sync player paddle width")
	_expect(is_equal_approx(float(owner.values.get("player_paddle_height", 0.0)), 60.0), "eat paddle growth hook should sync player paddle height")

	var viper_owner := FakeOwner.new()
	viper_owner.values["selected_character_type"] = "viper"
	var viper_runtime: Object = MythicItemRuntime.new()
	var jetpack_state: Object = ViperJetpackState.new()
	jetpack_state.active = true
	jetpack_state.offset_y = -48.0
	var viper_registry := FakeRegistry.new({
		"mythic_item_runtime": viper_runtime,
		"viper_jetpack_state": jetpack_state,
	})
	_equip_and_finish_transform(viper_runtime, viper_owner, viper_registry)
	_expect(not bool(jetpack_state.active), "transform finalize should force Viper jetpack inactive")
	_expect(is_equal_approx(float(jetpack_state.offset_y), 0.0), "transform finalize should force Viper to land")


func _verify_eat_and_field_runtime() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var input_reader := FakeInputReader.new()
	var status_state := FakeStatusEffectState.new()
	var dash_state := FakeDashState.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"smasher_input_reader": input_reader,
		"status_effect_state": status_state,
		"smasher_dash_state": dash_state,
		"battle_feedback_state": feedback,
	})
	_equip_and_finish_transform(runtime, owner, registry)

	input_reader.snapshot = {
		"action_pressed": true,
		"action_just_pressed": true,
	}
	owner.values["special_gauge"] = 500.0
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", 0.0)), 450.0), "strawberry eat should spend 50 gauge from raw action input")
	_expect(is_equal_approx(runtime.get_horn_strawberry_paddle_size_bonus_pct(), 0.20), "strawberry eat should immediately apply +20 percent paddle growth")
	_expect(bool(runtime.get_horn_strawberry_eat_context().get("eating", false)), "strawberry eat should enter the eating state")

	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.8)
	_expect(int(dash_state.token_state.dash_tokens) == 1, "strawberry eat finish should recover one dash token")
	var eat_context: Dictionary = runtime.get_horn_strawberry_eat_context()
	_expect(int(eat_context.get("projectile_count", 0)) >= 1, "strawberry eat finish should fire the first stem projectile")
	owner.values["boss_pos"] = _get_first_projectile_boss_pos(eat_context)
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(status_state.applied_statuses.size() >= 1, "stem projectile should apply boss stun on contact")
	var applied: Dictionary = status_state.applied_statuses[0]
	_expect(str(applied.get("target", "")) == "boss", "stem projectile status should target the boss")
	_expect(str(applied.get("status_id", "")) == "stun", "stem projectile status should be stun")
	_expect(is_equal_approx(float(applied.get("duration_frames", 0.0)), 18.0), "stem projectile stun should last 0.3 seconds")
	var stem_shake: Dictionary = feedback.screen_shakes.back() if not feedback.screen_shakes.is_empty() else {}
	_expect(
		is_equal_approx(float(stem_shake.get("amount", 0.0)), 12.0 / 30.0)
		and is_equal_approx(float(stem_shake.get("intensity", 0.0)), 15.0 * 9.0 / 35.0),
		"stem boss hit should trigger the Python-parity screen shake (12f/15)"
	)

	owner.values["special_gauge"] = 200.0
	owner.values["player_pos"] = Vector2(300.0, 700.0)
	input_reader.snapshot = {"down_pressed": true}
	runtime.update(owner, registry, 0.5)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", 0.0)), 150.0), "strawberry field should drain gauge while held")
	runtime.update(owner, registry, 0.5)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", 0.0)), 100.0), "strawberry field should spend 100 gauge over the 1 second hold")
	var field_context: Dictionary = runtime.get_horn_strawberry_field_context()
	_expect(int(field_context.get("barrier_count", 0)) == 1, "strawberry field should spawn one barrier after the hold")
	_expect(is_equal_approx(float(field_context.get("field_width", 0.0)), 120.0), "strawberry field width should match the Python live BoneBarrier core (120), not the dead 180 constant")
	var raw_field_barriers: Array = field_context.get("barriers", [])
	if not raw_field_barriers.is_empty() and raw_field_barriers[0] is Dictionary:
		var raw_barrier: Dictionary = raw_field_barriers[0]
		var expected_field_y: float = minf(
			float(owner.values["player_pos"].y) + float(owner.values["player_paddle_height"]),
			750.0 - 12.0
		)
		_expect(is_equal_approx(float(raw_barrier.get("rect_y", -999.0)), expected_field_y), "strawberry field should anchor to the paddle BOTTOM line (Python floor-guard placement)")
		_expect(_as_array(raw_barrier.get("seeds", [])).size() >= 8, "strawberry field should carry seeded berry-surface visual points")
	else:
		_expect(false, "strawberry field should expose raw barrier data for visual placement")

	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.5)
	var building_context: Dictionary = runtime.get_ball_collision_context()
	var building_barriers: Array = building_context.get("horn_strawberry_field_barriers", [])
	_expect(
		not building_barriers.is_empty()
		and building_barriers[0] is Dictionary
		and not bool(building_barriers[0].get("built", true)),
		"strawberry field should still be BUILDING 0.5s after cast (Python 3.0s build time)"
	)
	runtime.update(owner, registry, 2.5)
	var collision_context: Dictionary = runtime.get_ball_collision_context()
	_expect(bool(collision_context.get("horn_strawberry_field_active", false)), "built strawberry field should expose ball collision context")
	var barriers: Array = collision_context.get("horn_strawberry_field_barriers", [])
	_expect(
		not barriers.is_empty() and barriers[0] is Dictionary and bool(barriers[0].get("built", false)),
		"strawberry field should finish building after 3.0 seconds"
	)
	var barrier_rect: Rect2 = barriers[0].get("rect", Rect2()) if not barriers.is_empty() and barriers[0] is Dictionary else Rect2()
	# Move the paddle away from the cast lane so the floor-guard barrier (not the
	# paddle) resolves the descending ball, mirroring the live save scenario.
	owner.values["player_pos"] = Vector2(600.0, 700.0)
	var scene := {
		"ball_pos": Vector2(barrier_rect.position.x + barrier_rect.size.x * 0.5 + 20.0, barrier_rect.position.y - 8.0),
		"ball_vel": Vector2(0.0, 10.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	var context := {
		"ball_size": 16.0,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": owner.values["player_pos"],
		"player_paddle_size": Vector2(owner.values["player_paddle_width"], owner.values["player_paddle_height"]),
		"boss_pos": owner.values["boss_pos"],
		"boss_paddle_size": Vector2(owner.values["boss_paddle_width"], owner.values["boss_hitbox_height"]),
	}
	var processor: Object = BallMotionEventProcessor.new()
	var score_event: String = processor.step_motion(scene, 1.0, context, {
		"motion_stepper": BallMotionStepper.new(),
		"mythic_item_runtime": runtime,
	}, {})
	_expect(score_event == "", "strawberry field reflection should not score")
	_expect(_get_vector2(scene, "ball_vel").y < 0.0, "strawberry field should reflect a downward ball upward")
	_expect(_get_vector2(scene, "ball_vel").x > 0.5, "strawberry field reflect should nudge ball_vel.x by hit offset (Python vx += offset * 0.03)")
	_expect(int(runtime.get_horn_strawberry_field_context().get("last_reflect_count", 0)) == 1, "strawberry field should consume the barrier on reflect")

	# Python parity: a barrier hit while still BUILDING is destroyed WITHOUT reflecting.
	runtime.update(owner, registry, 0.7)
	runtime.update(owner, registry, 10.0)
	owner.values["special_gauge"] = 200.0
	owner.values["player_pos"] = Vector2(300.0, 700.0)
	input_reader.snapshot = {"down_pressed": true}
	runtime.update(owner, registry, 1.0)
	input_reader.snapshot = {}
	var building_hit_context: Dictionary = runtime.get_ball_collision_context()
	var building_hit_barriers: Array = building_hit_context.get("horn_strawberry_field_barriers", [])
	_expect(
		not building_hit_barriers.is_empty()
		and building_hit_barriers[0] is Dictionary
		and not bool(building_hit_barriers[0].get("built", true)),
		"second strawberry field cast should expose a BUILDING barrier to ball collision"
	)
	var building_rect: Rect2 = building_hit_barriers[0].get("rect", Rect2()) if not building_hit_barriers.is_empty() and building_hit_barriers[0] is Dictionary else Rect2()
	owner.values["player_pos"] = Vector2(600.0, 700.0)
	var building_scene := {
		"ball_pos": Vector2(building_rect.position.x + building_rect.size.x * 0.5, building_rect.position.y - 8.0),
		"ball_vel": Vector2(0.0, 10.0),
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	context["player_pos"] = owner.values["player_pos"]
	processor.step_motion(building_scene, 1.0, context, {
		"motion_stepper": BallMotionStepper.new(),
		"mythic_item_runtime": runtime,
	}, {})
	_expect(_get_vector2(building_scene, "ball_vel").y > 0.0, "building strawberry field hit should NOT reflect the ball (destroyed instead, Python parity)")
	_expect(int(runtime.get_horn_strawberry_field_context().get("last_reflect_count", 0)) == 1, "building strawberry field destruction should not count as a reflect")
	_expect(int(runtime.get_horn_strawberry_field_context().get("barrier_count", 0)) == 0, "building strawberry field should be destroyed by the ball contact")


func _verify_horn_charge_and_bomb_runtime() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var input_reader := FakeInputReader.new()
	var status_state := FakeStatusEffectState.new()
	var boss_ai_state := FakeBossAiState.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"smasher_input_reader": input_reader,
		"status_effect_state": status_state,
		"boss_ai_state": boss_ai_state,
		"battle_feedback_state": feedback,
	})
	_equip_and_finish_transform(runtime, owner, registry)

	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"up_pressed": true,
		"up_just_pressed": true,
	}
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", 0.0)), 200.0), "horn charge should spend 300 gauge from raw W input")
	var horn_context: Dictionary = runtime.get_horn_strawberry_horn_charge_context()
	_expect(bool(horn_context.get("active", false)), "horn charge should enter its active phase")
	_expect(str(horn_context.get("phase", "")) == "charging", "horn charge should start in charging phase")
	_expect(runtime.is_horn_strawberry_control_locked(), "horn charge should lock horizontal control while active")

	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.43)
	horn_context = runtime.get_horn_strawberry_horn_charge_context()
	_expect(str(horn_context.get("phase", "")) == "impact", "horn charge should reach impact after 0.43 seconds")
	_expect(_has_status(status_state, "horn_strawberry_horn_charge", "stun"), "horn charge impact should apply boss stun")
	var horn_status: Dictionary = _find_status(status_state, "horn_strawberry_horn_charge", "stun")
	_expect(is_equal_approx(float(horn_status.get("duration_frames", 0.0)), 180.0), "horn charge boss stun should last 3.0 seconds")
	var horn_status_data: Dictionary = horn_status.get("data", {})
	_expect(is_equal_approx(abs(float(horn_status_data.get("knockback_vel", 0.0))), 73.0), "horn charge boss knockback should use the reference strong velocity")
	_expect(bool(horn_status_data.get("suppress_paddle_hit_knockback", false)), "horn charge status should mark paddle-hit knockback suppression")
	_expect(int(boss_ai_state.clear_count) >= 1, "horn charge should clear older boss paddle-hit knockback before applying strong knockback")
	var impact_shake: Dictionary = feedback.screen_shakes.back() if not feedback.screen_shakes.is_empty() else {}
	_expect(
		is_equal_approx(float(impact_shake.get("amount", 0.0)), 24.0 / 30.0)
		and is_equal_approx(float(impact_shake.get("intensity", 0.0)), 9.0),
		"horn charge impact should trigger the Python-parity screen shake (24f/35 -> 0.8/9.0)"
	)

	var boss_post_hit_handler: Object = PaddleBounceBossPostHitHandler.new()
	var boss_result: Dictionary = boss_post_hit_handler.apply(
		Vector2(380.0, 74.0),
		Vector2(0.0, -14.0),
		0.0,
		0.0,
		false,
		false,
		false,
		{
			"boss_pos": owner.values["boss_pos"],
			"boss_paddle_width": owner.values["boss_paddle_width"],
			"boss_y": 35.0,
			"boss_hitbox_height": owner.values["boss_hitbox_height"],
			"ball_size": 16.0,
		},
		{
			"mythic_item_runtime": runtime,
			"status_effect_state": status_state,
			"boss_ai_state": boss_ai_state,
		},
		null
	)
	_expect(bool(boss_result.get("suppress_paddle_hit_knockback", false)), "boss post-hit should return the horn charge suppress flag")
	_expect(bool(boss_result.get("horn_strawberry_horn_charge_hit", false)), "boss post-hit should consume the horn charge hit marker")

	runtime.horn_strawberry_horn_charge_state.reset()
	status_state.applied_statuses.clear()
	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"left_pressed": true,
		"right_pressed": true,
	}
	runtime.update(owner, registry, 0.5)
	_expect(is_equal_approx(float(owner.values.get("special_gauge", 0.0)), 100.0), "strawberry bomb should spend 400 gauge after A+D hold")
	var bomb_context: Dictionary = runtime.get_horn_strawberry_bomb_context()
	_expect(int(bomb_context.get("thrown_count", 0)) > 0, "strawberry bomb should start throwing bombs over one second")
	_expect(int(bomb_context.get("bomb_count", 0)) == 30, "strawberry bomb should preserve the 30-bomb count")
	_expect(is_equal_approx(float(bomb_context.get("paint_slow_multiplier", 0.0)), 0.70), "strawberry bomb paint slow should be 30 percent")

	var bombs: Array = bomb_context.get("bombs", [])
	if not bombs.is_empty() and bombs[0] is Dictionary:
		var first_bomb: Dictionary = bombs[0]
		var bomb_pos: Vector2 = _get_vector2(first_bomb, "position")
		var bomb_base_pos: Vector2 = _get_vector2(first_bomb, "base_position")
		input_reader.snapshot = {}
		runtime.update(owner, registry, 0.1)
		var moved_bombs: Array = runtime.get_horn_strawberry_bomb_context().get("bombs", [])
		if not moved_bombs.is_empty() and moved_bombs[0] is Dictionary:
			var moved_bomb: Dictionary = moved_bombs[0]
			_expect(_get_vector2(moved_bomb, "base_position").y <= bomb_base_pos.y, "strawberry bombs should hop upward without gravity drift")
			_expect(_get_vector2(moved_bomb, "position").y <= bomb_pos.y, "strawberry bomb visual hop should not fall below its launch path")
		# LIVE trigger leg (Force-Injected-State trap guard): the boss stays parked at
		# its real top-lane position. Bombs must FLY there and detonate at the boss
		# hitbox bottom edge — the old bottom+40px threshold detonated every bomb
		# 40px short, so hit/stun/paint never reached the boss in real play.
		var boss_bottom_y: float = (owner.values["boss_pos"] as Vector2).y + float(owner.values.get("boss_hitbox_height", 40.0))
		var saw_hit_boss_explosion := false
		var min_explosion_y := 100000.0
		for _frame in range(360):
			runtime.update(owner, registry, 1.0 / 60.0)
			for explosion_value in runtime.get_horn_strawberry_bomb_context().get("explosions", []):
				if not (explosion_value is Dictionary):
					continue
				saw_hit_boss_explosion = saw_hit_boss_explosion or bool(explosion_value.get("hit_boss", false))
				min_explosion_y = minf(min_explosion_y, _get_vector2(explosion_value, "position").y)
			if saw_hit_boss_explosion and _has_status(status_state, "horn_strawberry_bomb_paint", "slow"):
				break
		_expect(saw_hit_boss_explosion, "LIVE bomb flight should produce at least one hit_boss explosion without moving the boss onto the bomb")
		_expect(min_explosion_y <= boss_bottom_y + 6.0, "bombs should detonate at the boss hitbox bottom edge, not 40px short of it")
		_expect(_has_status(status_state, "horn_strawberry_bomb", "stun"), "strawberry bomb should stun the boss on explosion contact")
		_expect(_has_status(status_state, "horn_strawberry_bomb_paint", "slow"), "strawberry bomb paint should apply boss slow while the boss overlaps paint")
		var bomb_status: Dictionary = _find_status(status_state, "horn_strawberry_bomb", "stun")
		_expect(is_equal_approx(float(bomb_status.get("duration_frames", 0.0)), 60.0), "strawberry bomb stun should last 1 second")
		var bomb_status_data: Dictionary = bomb_status.get("data", {})
		_expect(is_equal_approx(abs(float(bomb_status_data.get("knockback_vel", 0.0))), 50.0), "strawberry bomb knockback should match the reference")
		var bomb_shake: Dictionary = feedback.screen_shakes.back() if not feedback.screen_shakes.is_empty() else {}
		_expect(
			is_equal_approx(float(bomb_shake.get("amount", 0.0)), 8.0 / 30.0)
			and is_equal_approx(float(bomb_shake.get("intensity", 0.0)), 12.0 * 9.0 / 35.0),
			"strawberry bomb boss hit should trigger the Python-parity screen shake (8f/12)"
		)
	else:
		_expect(false, "strawberry bomb should expose at least one bomb for collision smoke")


func _equip_and_finish_transform(runtime: Object, owner: FakeOwner, registry: Object) -> void:
	owner.values["special_gauge"] = 500.0
	_expect(runtime.equip_item("horn_strawberry_mask", owner, registry, {"transform_duration": 60.0}, false), "horn strawberry mask should equip for stat hook test")
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "horn strawberry mask should begin transform for stat hook test")
	runtime.update(owner, registry, 4.5)
	_expect(runtime.is_horn_strawberry_transformed(), "horn strawberry mask should finish transform for stat hook test")


func _feed_command_through_update(
	runtime: Object,
	owner: Object,
	registry: Object,
	input_reader: FakeInputReader
) -> void:
	var frames: Array = [
		{"left_pressed": true},
		{},
		{"right_pressed": true},
		{},
		{"left_pressed": true},
		{},
		{"right_pressed": true},
		{},
		{"left_pressed": true},
		{},
		{"right_pressed": true},
	]
	for frame_value in frames:
		input_reader.snapshot = frame_value
		runtime.update(owner, registry, 0.1)


func _catalog_has_field_spawn(catalog: Object, item_name: String) -> bool:
	for item_value in catalog.get_field_spawn_items():
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _catalog_has_debug_item(catalog: Object, item_name: String) -> bool:
	for item_value in catalog.get_debug_items():
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll_data: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll_data.get("key", "")) == key:
			return roll_data
	return {}


func _verify_icon_asset(path: String, expected_size: Vector2i, label: String) -> void:
	_expect(ResourceLoader.exists(path, "Texture2D"), "horn strawberry mask %s should be importable from %s" % [label, path])
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "horn strawberry mask %s texture should load from %s" % [label, path])
	if texture == null:
		return
	_expect(
		Vector2i(texture.get_width(), texture.get_height()) == expected_size,
		"horn strawberry mask %s should be %s" % [label, str(expected_size)]
	)


func _get_first_projectile_boss_pos(eat_context: Dictionary) -> Vector2:
	var projectiles: Array = eat_context.get("projectiles", [])
	if projectiles.is_empty() or not (projectiles[0] is Dictionary):
		return Vector2(330.0, 35.0)
	var projectile: Dictionary = projectiles[0]
	var position: Vector2 = _get_vector2(projectile, "position")
	return position - Vector2(50.0, 20.0)


func _has_status(status_state: FakeStatusEffectState, source: String, status_id: String) -> bool:
	return not _find_status(status_state, source, status_id).is_empty()


func _find_status(status_state: FakeStatusEffectState, source: String, status_id: String) -> Dictionary:
	for status_value in status_state.applied_statuses:
		var status_data: Dictionary = status_value if status_value is Dictionary else {}
		if str(status_data.get("source", "")) == source and str(status_data.get("status_id", "")) == status_id:
			return status_data
	return {}


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
