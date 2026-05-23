extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
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


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary = {}) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


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

	func clear_paddle_hit_knockback() -> void:
		pass

	func start_paddle_hit_knockback(
		_velocity: float,
		_frames: float = 36.0,
		_decay_per_frame: float = 0.85,
		_replace_current: bool = true
	) -> void:
		pass


class FakeDashTokenState:
	extends RefCounted

	var dash_tokens := 0
	var dash_tokens_max := 1
	var dash_charge_timer := 120.0


class FakeDashState:
	extends RefCounted

	var token_state: Object = FakeDashTokenState.new()


class FakeScoreState:
	extends RefCounted

	var reset_calls := 0
	var score_calls := 0

	func reset() -> void:
		reset_calls += 1

	func score_for(side: String) -> Dictionary:
		score_calls += 1
		return {
			"player_score": 1 if side == "player" else 0,
			"boss_score": 1 if side == "boss" else 0,
			"match_finished": false,
			"next_player_serves": side == "boss",
		}

	func would_score_finish(_side: String) -> bool:
		return false


class FakeRoundState:
	extends RefCounted

	var scoreboard_wait_calls := 0
	var reset_game_calls := 0
	var reset_round_wait_calls := 0
	var round_restart_notice_calls := 0

	func start_scoreboard_wait() -> void:
		scoreboard_wait_calls += 1

	func reset_game() -> void:
		reset_game_calls += 1

	func reset_round_wait() -> void:
		reset_round_wait_calls += 1

	func start_round_restart_notice() -> void:
		round_restart_notice_calls += 1

	func set_player_serves(_value: bool) -> void:
		pass


class FakeScoreboardState:
	extends RefCounted

	var reset_calls := 0
	var start_calls := 0

	func reset() -> void:
		reset_calls += 1

	func trigger_top_mini_sparkle() -> void:
		pass

	func start(_player_score: int, _boss_score: int, _match_finished: bool, _scoring_side: String) -> void:
		start_calls += 1


class FakeAudio:
	extends RefCounted

	var play_round_set_calls := 0

	func play_round_set() -> void:
		play_round_set_calls += 1

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


var _failures: Array[String] = []
var _reset_ball_calls := 0


func _init() -> void:
	_verify_score_event_does_not_clear_before_serve_wait()
	_verify_serve_wait_round_start_preserves_transform_event()
	_verify_serve_wait_round_start_preserves_transformed_state()
	_verify_round_restart_preserves_field_and_paint_lingerers()
	_verify_stage_advance_clears_stage_lock_and_lingerers()
	_verify_main_menu_reset_clears_everything()

	if _failures.is_empty():
		print("horn_strawberry_round_boundary_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_score_event_does_not_clear_before_serve_wait() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	_finish_transform(runtime, owner, registry)
	var round_state := FakeRoundState.new()
	var scoreboard_state := FakeScoreboardState.new()
	_reset_ball_calls = 0

	MatchFlowController.new().handle_score_event("boss", {
		"score_state": FakeScoreState.new(),
		"round_state": round_state,
		"scoreboard_state": scoreboard_state,
		"audio": FakeAudio.new(),
		"mythic_item_runtime": runtime,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})

	_expect(scoreboard_state.start_calls == 1, "score_event should enter scoreboard flow")
	_expect(round_state.scoreboard_wait_calls == 1, "score_event should start serve wait instead of clearing immediately")
	_expect(_reset_ball_calls == 0, "score_event with scoreboard should not reset the ball immediately")
	_expect(runtime.is_horn_strawberry_transformed(), "score_event should not clear horn strawberry before the serve boundary")


func _verify_serve_wait_round_start_preserves_transform_event() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "transform should start for transform-event round boundary")
	_expect(runtime.is_horn_strawberry_event_playing(), "transform start should enter event state")

	runtime.on_round_start(owner, registry)

	_expect(runtime.is_horn_strawberry_event_playing(), "serve_wait round start should preserve transform event")
	_expect(bool(owner.values.get("horn_strawberry_event_playing", false)), "owner sync should preserve horn strawberry event flag")
	_expect(bool(runtime.get_horn_strawberry_context().get("used_this_stage", false)), "serve_wait round start should preserve used_this_stage")
	owner.values["special_gauge"] = 500.0
	_expect(not runtime.try_horn_strawberry_transform(owner, registry), "same-stage transform should stay spent while the transform event survives a round boundary")


func _verify_serve_wait_round_start_preserves_transformed_state() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	_finish_transform(runtime, owner, registry)
	_expect(runtime.is_horn_strawberry_transformed(), "transform should be active before transformed round boundary")

	runtime.on_round_start(owner, registry)

	_expect(runtime.is_horn_strawberry_transformed(), "serve_wait round start should preserve transformed state")
	_expect(runtime.is_horn_strawberry_skills_locked(), "serve_wait round start should keep normal character skills locked")
	_expect(bool(runtime.get_horn_strawberry_context().get("used_this_stage", false)), "transformed round loss should preserve used_this_stage")
	_expect(bool(owner.values.get("horn_strawberry_transformed", false)), "owner sync should preserve horn strawberry transformed flag")


func _verify_round_restart_preserves_field_and_paint_lingerers() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	var input_reader: FakeInputReader = bundle.get("input_reader") as FakeInputReader
	_finish_transform(runtime, owner, registry)
	_create_field_and_paint_lingerers(runtime, owner, registry, input_reader)
	var round_state := FakeRoundState.new()
	_reset_ball_calls = 0

	MatchFlowController.new().handle_round_restart("rematch", {
		"round_state": round_state,
		"audio": FakeAudio.new(),
	}, {
		"reset_ball": Callable(self, "_record_round_start").bind(runtime, owner, registry),
	})

	_expect(_reset_ball_calls == 1, "round_restart should use the reset_ball callback")
	_expect(round_state.round_restart_notice_calls == 1, "round_restart rematch should start the restart notice")
	_expect(runtime.is_horn_strawberry_transformed(), "round_restart should preserve the transformed kit")
	_expect(int(runtime.get_horn_strawberry_field_context().get("barrier_count", 0)) >= 1, "round_restart should preserve strawberry field barriers")
	_expect(int(runtime.get_horn_strawberry_bomb_context().get("paint_count", 0)) >= 1, "round_restart should preserve strawberry bomb paint")


func _verify_stage_advance_clears_stage_lock_and_lingerers() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	var input_reader: FakeInputReader = bundle.get("input_reader") as FakeInputReader
	_finish_transform(runtime, owner, registry)
	_create_field_and_paint_lingerers(runtime, owner, registry, input_reader)

	runtime.on_stage_advance(owner, registry)

	_expect(not bool(runtime.get_horn_strawberry_context().get("used_this_stage", true)), "stage_advance should clear used_this_stage")
	_expect(int(runtime.get_horn_strawberry_field_context().get("barrier_count", -1)) == 0, "stage_advance should clear field lingerers")
	_expect(int(runtime.get_horn_strawberry_bomb_context().get("paint_count", -1)) == 0, "stage_advance should clear bomb paint lingerers")
	owner.values["special_gauge"] = 500.0
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "stage_advance should allow a new transform on the next stage")


func _verify_main_menu_reset_clears_everything() -> void:
	var bundle: Dictionary = _make_bundle()
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var registry: Object = bundle.get("registry")
	var input_reader: FakeInputReader = bundle.get("input_reader") as FakeInputReader
	_finish_transform(runtime, owner, registry)
	_create_field_and_paint_lingerers(runtime, owner, registry, input_reader)

	var result: Dictionary = MatchFlowController.new().reset_game({
		"mythic_item_runtime": runtime,
		"score_state": FakeScoreState.new(),
		"scoreboard_state": FakeScoreboardState.new(),
		"round_state": FakeRoundState.new(),
		"audio": FakeAudio.new(),
	}, {})

	_expect(not runtime.is_horn_strawberry_mask_equipped(), "main_menu_reset should clear horn strawberry equipment")
	_expect(not runtime.is_horn_strawberry_transformed(), "main_menu_reset should clear transformed state")
	_expect(int(runtime.get_horn_strawberry_field_context().get("barrier_count", -1)) == 0, "main_menu_reset should clear field lingerers")
	_expect(int(runtime.get_horn_strawberry_bomb_context().get("paint_count", -1)) == 0, "main_menu_reset should clear bomb paint lingerers")
	_expect(result.get("equipment_slots", null) is Dictionary and result.get("passive_item_inventory", null) is Array, "main_menu_reset should return a full owner reset payload")


func _make_bundle() -> Dictionary:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var input_reader := FakeInputReader.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"smasher_input_reader": input_reader,
		"status_effect_state": FakeStatusEffectState.new(),
		"boss_ai_state": FakeBossAiState.new(),
		"smasher_dash_state": FakeDashState.new(),
	})
	_expect(runtime.equip_item("horn_strawberry_mask", owner, registry, {"transform_duration": 60.0}, false), "horn strawberry should equip for round boundary smoke")
	return {
		"owner": owner,
		"runtime": runtime,
		"input_reader": input_reader,
		"registry": registry,
	}


func _finish_transform(runtime: Object, owner: FakeOwner, registry: Object) -> void:
	owner.values["special_gauge"] = 500.0
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "horn strawberry should begin transform")
	runtime.update(owner, registry, 4.5)
	_expect(runtime.is_horn_strawberry_transformed(), "horn strawberry should finish transform")


func _create_field_and_paint_lingerers(
	runtime: Object,
	owner: FakeOwner,
	registry: Object,
	input_reader: FakeInputReader
) -> void:
	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {"down_pressed": true}
	runtime.update(owner, registry, 0.5)
	runtime.update(owner, registry, 0.5)
	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.5)
	_expect(int(runtime.get_horn_strawberry_field_context().get("barrier_count", 0)) >= 1, "field setup should create a barrier before boundary tests")

	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"left_pressed": true,
		"right_pressed": true,
	}
	runtime.update(owner, registry, 0.5)
	var bombs: Array = runtime.get_horn_strawberry_bomb_context().get("bombs", [])
	if bombs.is_empty() or not (bombs[0] is Dictionary):
		_expect(false, "bomb setup should expose a bomb before boundary tests")
		return
	var first_bomb: Dictionary = bombs[0]
	owner.values["boss_pos"] = _get_vector2(first_bomb, "position") - Vector2(50.0, 20.0)
	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.0)
	_expect(int(runtime.get_horn_strawberry_bomb_context().get("paint_count", 0)) >= 1, "bomb setup should create paint before boundary tests")


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _record_round_start(runtime: Object, owner: FakeOwner, registry: Object) -> void:
	_reset_ball_calls += 1
	runtime.on_round_start(owner, registry)


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
