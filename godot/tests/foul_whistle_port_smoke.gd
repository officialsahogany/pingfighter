extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var foul_whistle_equipped := false
	var foul_whistle_active := false
	var foul_whistle_negate_chance_pct := 0.0
	var foul_whistle_negate_chance := 0.0
	var foul_whistle_effect_active := false
	var foul_whistle_pending_round_reset := false

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var foul_whistle_count := 0
	var active_item_count := 0
	var round_set_count := 0
	var stopped: Dictionary = {}

	func play_foul_whistle() -> void:
		foul_whistle_count += 1

	func play_active_item() -> void:
		active_item_count += 1

	func play_round_set() -> void:
		round_set_count += 1

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true


class FakeRoundState:
	var waiting_for_serve := false
	var player_serves := false
	var reset_wait_calls := 0
	var restart_notice_calls := 0
	var set_player_serves_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value
		set_player_serves_calls += 1

	func reset_round_wait() -> void:
		waiting_for_serve = true
		reset_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeBallDriver:
	var reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1


class FakeRegistry:
	var runtime: Object
	var audio: Object
	var ball_driver: Object
	var round_state: Object

	func _init(next_runtime: Object, next_audio: Object = null, next_ball_driver: Object = null, next_round_state: Object = null) -> void:
		runtime = next_runtime
		audio = next_audio
		ball_driver = next_ball_driver
		round_state = next_round_state

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		if key == "game_audio":
			return audio
		if key == "battle_scene_ball_update_driver":
			return ball_driver
		if key == "round_flow_state":
			return round_state
		return null


func _init() -> void:
	seed(97531)

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("foul_whistle")
	_expect(not item_data.is_empty(), "Foul Whistle should build from catalog")
	_expect(str(item_data.get("slot", "")) == "accessory", "Foul Whistle should use accessory slots")
	_expect(str(item_data.get("display_name", "")) != "", "Foul Whistle should expose a display name")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Foul Whistle icon should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/foul_whistle.wav") != null, "Foul Whistle sound should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "foul_whistle"), "Foul Whistle should be in passive field-spawn list")
	_expect(_catalog_item_has_chance(catalog.get_field_spawn_items(), "foul_whistle"), "Foul Whistle should have non-zero field chance")

	var roll_options: Array = catalog.get_roll_options("foul_whistle")
	_expect(roll_options.size() == 1, "Foul Whistle should have one roll option")
	var option: Dictionary = roll_options[0]
	_expect(str(option.get("key", "")) == "negate_chance_pct", "Foul Whistle roll key should match Python reference")
	_expect(is_equal_approx(float(option.get("min", 0.0)), 4.0), "Foul Whistle roll min should be 4%")
	_expect(is_equal_approx(float(option.get("max", 0.0)), 10.0), "Foul Whistle roll max should be 10%")
	_expect(is_equal_approx(float(option.get("default", 0.0)), 7.0), "Foul Whistle default roll should be 7%")

	var pickup_runtime: Object = MythicItemRuntime.new()
	var pickup_owner := FakeOwner.new()
	var pickup_registry := FakeRegistry.new(pickup_runtime)
	var active_runtime: Object = ActiveItemRuntime.new()
	var pickup_item: Dictionary = item_data.duplicate(true)
	pickup_item["rolls"] = {"negate_chance_pct": 10.0}
	pickup_item = catalog.sync_roll_fields(pickup_item, false)
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": pickup_item}, active_slots, pickup_registry, pickup_owner),
		"field Foul Whistle pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Foul Whistle pickup should not consume an active slot")
	_expect(pickup_owner.foul_whistle_equipped, "field pickup should auto-equip Foul Whistle")
	_expect(is_equal_approx(pickup_owner.foul_whistle_negate_chance_pct, 10.0), "field pickup should preserve Foul Whistle roll")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, audio)
	_expect(runtime.equip_item("foul_whistle", owner, registry, {"negate_chance_pct": 100.0}, false), "Foul Whistle should equip")
	_expect(owner.equipment_slots.has("accessory1"), "Foul Whistle should resolve into the first accessory slot")
	_expect(owner.foul_whistle_equipped, "owner should expose Foul Whistle equipped")
	_expect(owner.foul_whistle_active, "owner should expose Foul Whistle active")
	_expect(is_equal_approx(owner.foul_whistle_negate_chance_pct, 100.0), "owner should sync Foul Whistle negate pct")
	_expect(is_equal_approx(owner.foul_whistle_negate_chance, 1.0), "owner should sync Foul Whistle negate chance")
	_expect(runtime.try_trigger_foul_whistle("round", registry), "100% Foul Whistle roll should force activation")
	_expect(audio.foul_whistle_count == 1, "Foul Whistle should play its dedicated sound")
	_expect(not runtime.consume_foul_whistle_reset_ready(), "Foul Whistle should wait before reset becomes ready")
	runtime.update(owner, registry, 70.0 / 60.0)
	_expect(runtime.consume_foul_whistle_reset_ready(), "Foul Whistle should expose delayed reset readiness")

	var score_runtime: Object = MythicItemRuntime.new()
	var score_owner := FakeOwner.new()
	var score_audio := FakeAudio.new()
	var score_registry := FakeRegistry.new(score_runtime, score_audio)
	_expect(score_runtime.equip_item("foul_whistle", score_owner, score_registry, {"negate_chance_pct": 100.0}, false), "score runtime should equip Foul Whistle")
	var score_state: Object = MatchScoreState.new()
	var round_state := FakeRoundState.new()
	var match_flow: Object = MatchFlowController.new()
	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": score_runtime,
		"audio": score_audio,
	}, {})
	var score_snapshot: Dictionary = score_state.get_snapshot()
	_expect(int(score_snapshot.get("boss_score", -1)) == 0, "Foul Whistle should cancel boss scoring")
	_expect(round_state.waiting_for_serve and round_state.player_serves, "Foul Whistle should hold the round for a player rematch serve")
	_expect(round_state.restart_notice_calls == 1, "Foul Whistle should show the round restart notice")
	_expect(score_audio.foul_whistle_count == 1 and score_audio.round_set_count == 0, "Foul Whistle score cancel should use whistle audio, not score audio")

	var normal_score_state: Object = MatchScoreState.new()
	match_flow.handle_score_event("boss", {
		"score_state": normal_score_state,
		"round_state": FakeRoundState.new(),
		"audio": FakeAudio.new(),
	}, {})
	_expect(int(normal_score_state.get_snapshot().get("boss_score", -1)) == 1, "boss scoring should still work without Foul Whistle")

	var delayed_runtime: Object = MythicItemRuntime.new()
	var delayed_owner := FakeOwner.new()
	var delayed_audio := FakeAudio.new()
	var delayed_ball := FakeBallDriver.new()
	var delayed_round := FakeRoundState.new()
	var delayed_registry := FakeRegistry.new(delayed_runtime, delayed_audio, delayed_ball, delayed_round)
	_expect(delayed_runtime.equip_item("foul_whistle", delayed_owner, delayed_registry, {"negate_chance_pct": 100.0}, false), "delayed runtime should equip Foul Whistle")
	_expect(delayed_runtime.try_trigger_foul_whistle("round", delayed_registry), "delayed Foul Whistle should activate")
	var item_update_driver: Object = BattleSceneItemUpdateDriver.new()
	item_update_driver.update_items(delayed_owner, delayed_registry, 70.0 / 60.0)
	_expect(delayed_ball.reset_calls == 1, "item update driver should reset the ball when Foul Whistle is ready")
	_expect(delayed_round.waiting_for_serve and delayed_round.player_serves, "delayed reset should return to player serve wait")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidate_names: Dictionary = field_spawn_controller.get_field_spawn_candidate_names()
	_expect(candidate_names.has("foul_whistle"), "field spawn candidates should include Foul Whistle")
	_expect(
		_array_has_item(field_spawn_controller._build_spawn_candidates(score_registry), "foul_whistle"),
		"owned Foul Whistle should remain spawnable for duplicate roll farming"
	)

	print("foul_whistle_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _catalog_item_has_chance(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return float(item.get("chance", 0.0)) > 0.0
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
