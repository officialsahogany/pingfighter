extends SceneTree

const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const BattleUpdatePlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"player_pos": Vector2(300.0, 680.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_hp": 12.0,
		"boss_max_hp": 12.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary = {}) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeScoreState:
	extends RefCounted

	var score_calls := 0
	var deuce_mode := false

	func score_for(side: String) -> Dictionary:
		score_calls += 1
		return {
			"player_score": 0,
			"boss_score": 1 if side == "boss" else 0,
			"match_finished": false,
			"next_player_serves": side == "boss",
		}

	func would_score_finish(_side: String) -> bool:
		return false

	func get_snapshot() -> Dictionary:
		return {"deuce_mode": deuce_mode}


class FakeRoundState:
	extends RefCounted

	var player_serves := false
	var reset_round_wait_calls := 0
	var restart_notice_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		reset_round_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1


class FakeAudio:
	extends RefCounted

	var change_calls := 0
	var throw_calls := 0
	var grenade_calls := 0

	func play_horn_strawberry_change() -> void:
		change_calls += 1

	func play_throw() -> void:
		throw_calls += 1

	func play_grenade_explosion() -> void:
		grenade_calls += 1

	func stop_dash_delay() -> void:
		pass

	func stop_boomerang_loop() -> void:
		pass

	func stop_spider_mine_walk_loop() -> void:
		pass

	func stop_plasma_charge() -> void:
		pass

	func stop_plasma_shock() -> void:
		pass

	func stop_warp_gate_loop() -> void:
		pass

	func stop_magnum_grip() -> void:
		pass

	func stop_viper_jetpack_loop() -> void:
		pass

	func stop_chaos_spear_blackhole_loop() -> void:
		pass

	func stop_ragnarok_shock_loop() -> void:
		pass

	func stop_electric_shock_loop() -> void:
		pass

	func stop_stage2_quake_loop() -> void:
		pass


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(owner: Object) -> void:
		reset_calls += 1
		if owner != null:
			owner.set("boss_hp", owner.get("boss_max_hp"))


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		})
		return applied.back()


class FakeFeedback:
	extends RefCounted

	var shake_amount := 0.0
	var shake_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = max(shake_amount, amount)
		shake_intensity = max(shake_intensity, intensity)


var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_registration()
	_verify_score_cancel_revival_flow()
	_verify_direct_runtime_transform_and_round_reset()
	_verify_bomb_spin_skill_flow()

	if _failures.is_empty():
		print("yachaman_soul_port_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("yachaman_soul")
	_expect(not item_data.is_empty(), "Yachaman Soul should build from the mythic catalog")
	_expect(str(item_data.get("slot", "")) == "head", "Yachaman Soul should use the head slot")
	_expect(str(item_data.get("name", "")) == "yachaman_soul", "Yachaman Soul catalog name should be stable")
	_expect(str(item_data.get("icon_path", "")) == "res://assets/sprites/items/yachaman_soul.png", "Yachaman Soul should expose its PNG icon")
	_expect(_catalog_has_item(catalog.get_field_spawn_items(), "yachaman_soul"), "Yachaman Soul should be in the field spawn pool")
	_expect(is_equal_approx(catalog.get_field_chance("yachaman_soul"), 0.004), "Yachaman Soul field chance should match the reference")

	var rolls: Array = catalog.get_roll_options("yachaman_soul")
	var chance_roll: Dictionary = _find_roll(rolls, "activation_chance_pct")
	_expect(not chance_roll.is_empty(), "Yachaman Soul should expose activation_chance_pct")
	_expect(is_equal_approx(float(chance_roll.get("min", 0.0)), 50.0), "activation chance min should be 50")
	_expect(is_equal_approx(float(chance_roll.get("max", 0.0)), 80.0), "activation chance max should be 80")
	_expect(is_equal_approx(float(chance_roll.get("step", 0.0)), 1.0), "activation chance step should be 1")
	_expect(is_equal_approx(float(chance_roll.get("default", 0.0)), 65.0), "activation chance default should be 65")
	_verify_icon_file("res://assets/sprites/items/yachaman_soul.png")


func _verify_score_cancel_revival_flow() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var audio := FakeAudio.new()
	var round_state := FakeRoundState.new()
	var score_state := FakeScoreState.new()
	var ball_driver := FakeBallDriver.new()
	var boss_health := FakeBossHealthFlow.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"round_flow_state": round_state,
		"battle_scene_ball_update_driver": ball_driver,
		"battle_scene_boss_health_flow": boss_health,
	})

	_expect(
		runtime.equip_item("yachaman_soul", owner, registry, {"activation_chance_pct": 100.0}, false),
		"Yachaman Soul should equip through the mythic runtime"
	)
	_force_equipped_roll(runtime, "yachaman_soul", "activation_chance_pct", 100.0)
	_expect(is_equal_approx(runtime.get_yachaman_activation_chance_pct(), 95.0), "Yachaman activation chance should respect the 95 percent cap")
	_expect(bool(owner.values.get("yachaman_soul_equipped", false)), "owner sync should expose Yachaman Soul equipped state")

	_seed_next_roll_at_or_below(runtime.get_yachaman_activation_chance_pct())
	MatchScoreEventController.new().handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"audio": audio,
		"owner": owner,
		"registry": registry,
		"mythic_item_runtime": runtime,
	}, {})

	_expect(score_state.score_calls == 0, "Yachaman revival should cancel the incoming boss score")
	_expect(round_state.player_serves, "Yachaman revival should hand the serve to the player")
	_expect(round_state.reset_round_wait_calls == 1, "Yachaman revival should enter the round restart wait")
	_expect(round_state.restart_notice_calls == 1, "Yachaman revival should show the round restart notice")
	_expect(audio.change_calls == 1, "Yachaman revival should play its temporary transform cue")
	_expect(runtime.is_yachaman_event_playing(), "Yachaman revival should start the transform event")
	_expect(runtime.is_yachaman_control_locked(), "Yachaman revival event should lock player control")
	_expect(bool(runtime.get_yachaman_context().get("used_this_round", false)), "Yachaman should mark once-this-round use")
	_expect(not runtime.consume_yachaman_revival_reset_ready(), "Yachaman reset should not be ready before the animation finishes")

	runtime.update(owner, registry, 1.5)
	_expect(runtime.is_yachaman_transformed(), "Yachaman event should finalize after 90 frames")
	_expect(bool(owner.values.get("yachaman_transformed", false)), "owner sync should expose transformed state")
	_expect(bool(runtime.get_yachaman_context().get("reset_ready", false)), "Yachaman reset should become ready on finalize")

	BattleSceneItemUpdateDriver.new().update_items(owner, registry, 1.0 / 60.0)
	_expect(ball_driver.reset_calls == 1, "Yachaman finalize should reset the ball once")
	_expect(boss_health.reset_calls == 1, "Yachaman finalize should reset boss round health once")

	var config := {
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"player_skill_input_locked": false,
		"horizontal_input_locked": false,
	}
	runtime.apply_player_movement_config(config)
	_expect(is_equal_approx(float(config.get("paddle_speed", 0.0)), 3.0), "Yachaman transformed move speed should be 3")
	_expect(is_equal_approx(float(config.get("paddle_max_speed", 0.0)), 3.0), "Yachaman transformed max speed should be 3")
	_expect(bool(config.get("player_skill_input_locked", false)), "Yachaman transformed state should lock character skills")
	_expect(not bool(config.get("horizontal_input_locked", false)), "Yachaman transformed state should keep horizontal movement enabled")
	_expect(is_equal_approx(runtime.get_player_paddle_scale(), 0.70), "Yachaman transformed paddle scale should be 70 percent")
	_verify_skill_input_proxy(runtime)

	MatchScoreEventController.new().handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"audio": audio,
		"owner": owner,
		"registry": registry,
		"mythic_item_runtime": runtime,
	}, {})
	_expect(score_state.score_calls == 1, "A later hit while transformed should consume Yachaman and allow the score")
	_expect(not runtime.is_yachaman_transformed(), "Yachaman body should clear when defeated in transformed state")


func _verify_direct_runtime_transform_and_round_reset() -> void:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var registry := FakeRegistry.new({})
	_expect(
		runtime.equip_item("yachaman_soul", owner, registry, {"activation_chance_pct": 100.0}, false),
		"direct Yachaman equip should succeed"
	)
	_force_equipped_roll(runtime, "yachaman_soul", "activation_chance_pct", 100.0)
	_seed_next_roll_at_or_below(runtime.get_yachaman_activation_chance_pct())
	_expect(runtime.try_trigger_yachaman_revival("round", {"owner": owner, "registry": registry}), "direct Yachaman trigger should succeed when the seeded roll is under the capped chance")
	runtime.update(owner, registry, 1.5)
	_expect(runtime.is_yachaman_transformed(), "direct Yachaman event should finalize")
	runtime.on_round_start(owner, registry)
	_expect(not runtime.is_yachaman_transformed(), "Yachaman should clear on the real round boundary")
	_expect(not bool(runtime.get_yachaman_context().get("used_this_round", true)), "Yachaman once-this-round flag should clear on round start")


func _verify_bomb_spin_skill_flow() -> void:
	var owner := FakeOwner.new()
	owner.values["ball_pos"] = Vector2(380.0, 634.0)
	owner.values["ball_vel"] = Vector2(0.0, 8.0)
	owner.values["ball_size"] = 28.6
	var runtime: Object = MythicItemRuntime.new()
	var audio := FakeAudio.new()
	var input_reader := FakeInputReader.new()
	var status_state := FakeStatusEffectState.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": input_reader,
		"game_audio": audio,
		"status_effect_state": status_state,
		"battle_feedback_state": feedback,
	})
	_expect(
		runtime.equip_item("yachaman_soul", owner, registry, {"activation_chance_pct": 100.0}, false),
		"bomb spin smoke should equip Yachaman Soul"
	)
	_force_equipped_roll(runtime, "yachaman_soul", "activation_chance_pct", 100.0)
	_seed_next_roll_at_or_below(runtime.get_yachaman_activation_chance_pct())
	_expect(runtime.try_trigger_yachaman_revival("round", {"owner": owner, "registry": registry}), "bomb spin smoke should trigger Yachaman revival")
	runtime.update(owner, registry, 1.5)
	_expect(runtime.is_yachaman_transformed(), "bomb spin smoke should reach transformed state")

	input_reader.snapshot = {
		"right_pressed": true,
		"action_just_pressed": true,
	}
	runtime.update(owner, registry, 1.0 / 60.0)
	var context: Dictionary = runtime.get_yachaman_context()
	_expect(bool(context.get("bomb_spin_active", false)), "Space/click plus direction should start Yachaman bomb spin")
	_expect(bool(context.get("helmet_removed", false)), "Bomb spin should remove the helmet from the transformed body")
	_expect(audio.throw_calls >= 1, "Bomb spin should play a throw-style cue")

	input_reader.snapshot = {}
	var loaded := bool(runtime.get_ball_draw_context().get("bomb_ball_loaded", false))
	for _i in range(16):
		if loaded:
			break
		var helmet_pos: Vector2 = runtime.get_yachaman_context().get("bomb_spin_helmet_pos", Vector2.ZERO)
		if helmet_pos != Vector2.ZERO:
			owner.values["ball_pos"] = helmet_pos
			owner.values["ball_vel"] = Vector2(0.0, 8.0)
		runtime.update(owner, registry, 1.0 / 60.0)
		loaded = bool(runtime.get_ball_draw_context().get("bomb_ball_loaded", false))
	_expect(loaded, "Bomb spin helmet collision should load the bomb onto the ball")
	_expect(runtime.has_ball_draw_context(), "Loaded Yachaman bomb should expose a ball draw context")
	var loaded_ball_vel: Vector2 = owner.values.get("ball_vel", Vector2.ZERO)
	_expect(loaded_ball_vel.y < 0.0, "Loaded bomb ball should bounce upward from the helmet")

	var boss_result: Dictionary = runtime.consume_yachaman_bomb_boss_hit(
		Vector2(380.0, 120.0),
		Vector2(3.0, -12.0),
		{
			"boss_pos": Vector2(330.0, 80.0),
			"boss_paddle_size": Vector2(100.0, 40.0),
		},
		{
			"registry": registry,
			"status_effect_state": status_state,
			"feedback": feedback,
		}
	)
	_expect(bool(boss_result.get("yachaman_bomb_hit", false)), "Boss counter should consume the loaded Yachaman bomb")
	_expect(not bool(runtime.get_ball_draw_context().get("bomb_ball_loaded", false)), "Bomb ball overlay should clear after boss explosion")
	_expect(status_state.applied.size() == 1, "Yachaman bomb should apply a boss stun")
	_expect(is_equal_approx(float(status_state.applied[0].get("duration_frames", 0.0)), 60.0), "Yachaman bomb stun should last 60 frames")
	_expect(abs(float(boss_result.get("boss_vel", 0.0))) >= 15.0, "Yachaman bomb should return boss knockback power")
	_expect(bool(boss_result.get("suppress_paddle_hit_knockback", false)), "Yachaman bomb should suppress normal paddle-hit knockback")
	_expect(audio.grenade_calls >= 1, "Yachaman bomb explosion should play a grenade cue")
	_expect(feedback.shake_amount > 0.0, "Yachaman bomb explosion should shake the screen")


func _verify_skill_input_proxy(runtime: Object) -> void:
	var input_reader := FakeInputReader.new()
	input_reader.snapshot = {
		"left_pressed": true,
		"up_pressed": true,
		"action_pressed": true,
		"action_just_pressed": true,
		"jetpack_pressed": true,
		"power_smash_direction": -1,
	}
	var deps: Dictionary = BattleUpdatePlayerControlDepsBuilder.new().build_deps(FakeRegistry.new({
		"smasher_input_reader": input_reader,
		"mythic_item_runtime": runtime,
	}), "smasher")
	var locked_reader: Object = deps.get("input_reader", null)
	var snapshot: Dictionary = locked_reader.get_snapshot() if locked_reader != null and locked_reader.has_method("get_snapshot") else {}
	_expect(bool(snapshot.get("left_pressed", false)), "Yachaman skill lock should preserve movement input")
	_expect(not bool(snapshot.get("up_pressed", true)), "Yachaman skill lock should clear up skill input")
	_expect(not bool(snapshot.get("action_pressed", true)), "Yachaman skill lock should clear action skill input")
	_expect(not bool(snapshot.get("jetpack_pressed", true)), "Yachaman skill lock should clear Viper jetpack input")
	_expect(int(snapshot.get("power_smash_direction", 1)) == 0, "Yachaman skill lock should clear power-smash direction")


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		if roll_value is Dictionary and str(roll_value.get("key", "")) == key:
			return roll_value
	return {}


func _catalog_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _verify_icon_file(path: String) -> void:
	_expect(FileAccess.file_exists(path), "Yachaman Soul icon should exist on disk")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Yachaman Soul icon should be readable")
		return
	var magic := file.get_buffer(8)
	file.close()
	_expect(magic == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]), "Yachaman Soul icon should be a PNG")


func _force_equipped_roll(runtime: Object, item_name: String, roll_key: String, value: float) -> void:
	for index in range(runtime.inventory_items.size()):
		var item_data: Dictionary = runtime._get_dict(runtime.inventory_items[index])
		if str(item_data.get("name", "")) != item_name:
			continue
		if not bool(item_data.get("equipped", false)) and str(item_data.get("_equipped_slot", "")) == "":
			continue
		var rolls: Dictionary = runtime._get_dict(item_data.get("rolls", {})).duplicate(true)
		rolls[roll_key] = value
		item_data["rolls"] = rolls
		runtime.inventory_items[index] = item_data
		return


func _seed_next_roll_at_or_below(chance_pct: float) -> void:
	for candidate in range(1, 128):
		seed(candidate)
		if randf() * 100.0 <= chance_pct:
			seed(candidate)
			return
	seed(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
