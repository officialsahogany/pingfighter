extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var revival_equipped := false
	var revival_available := false
	var revival_used := false
	var revival_effect_active := false

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var round_set_count := 0
	var stopped: Dictionary = {}

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
	var score_wait_calls := 0
	var restart_notice_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting_for_serve = true
		reset_wait_calls += 1

	func start_scoreboard_wait() -> void:
		waiting_for_serve = true
		score_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeRegistry:
	var runtime: Object
	var audio: Object

	func _init(next_runtime: Object, next_audio: Object = null) -> void:
		runtime = next_runtime
		audio = next_audio

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_verify_catalog(catalog)
	_verify_field_pickup(catalog)
	_verify_match_loss_revival(catalog)

	print("revival_port_smoke: ok")
	quit(0)


func _verify_catalog(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("revival")
	_expect(not item_data.is_empty(), "Revival should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "윤회의 부적", "Revival should keep the Python Korean display name")
	_expect(str(item_data.get("type", "")) == "passive", "Revival should be passive")
	_expect(str(item_data.get("slot", "")) == "accessory", "Revival should use accessory slots")
	_expect_close(float(item_data.get("chance", 0.0)), 0.005, "Revival field chance should match Python")
	_expect(catalog.get_roll_options("revival").is_empty(), "Revival should not expose roll options")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "revival"), "Revival should be in the passive field-spawn list")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Revival icon should load")
	_expect_transparent_icon_corners(str(item_data.get("icon_path", "")))


func _verify_field_pickup(catalog: Object) -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	var active_runtime: Object = ActiveItemRuntime.new()
	var active_slots: Array = []
	_expect(
		active_runtime._store_active_item({"item_data": catalog.build_item_by_name("revival")}, active_slots, registry, owner),
		"field Revival pickup should route into passive inventory"
	)
	_expect(active_slots.is_empty(), "Revival pickup should not consume an active slot")
	_expect(owner.revival_equipped, "field pickup should auto-equip Revival")
	_expect(owner.revival_available, "field pickup should expose Revival as available")
	_expect(owner.equipment_slots.has("accessory1"), "Revival should resolve into the first accessory slot")


func _verify_match_loss_revival(_catalog: Object) -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, audio)
	_expect(runtime.equip_item("revival", owner, registry, {}, false), "Revival should equip")

	var match_flow: Object = MatchFlowController.new()
	var score_state: Object = MatchScoreState.new()
	var round_state := FakeRoundState.new()

	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": audio,
		"owner": owner,
		"registry": registry,
	}, {})
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 1, "non-fatal boss score should still count")
	_expect(owner.revival_available, "Revival should not be consumed before match loss")

	for _i in range(3):
		score_state.score_for("boss")
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 4, "test setup should reach boss match point")
	_expect(score_state.would_score_finish("boss"), "next boss score should be fatal")

	round_state = FakeRoundState.new()
	audio.round_set_count = 0
	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": audio,
		"owner": owner,
		"registry": registry,
	}, {})
	var revived_snapshot: Dictionary = score_state.get_snapshot()
	_expect(int(revived_snapshot.get("player_score", -1)) == 0, "Revival should reset the player score to 0 (stage restart)")
	_expect(int(revived_snapshot.get("boss_score", -1)) == 0, "Revival should reset the boss score to 0 (stage restart)")
	_expect(not bool(revived_snapshot.get("deuce_mode", true)), "Revival should clear deuce mode on stage restart")
	_expect(round_state.waiting_for_serve and round_state.player_serves, "Revival should hold the round for a player rematch serve")
	_expect(round_state.restart_notice_calls == 1, "Revival should show the restart notice on stage restart")
	_expect(audio.round_set_count == 0, "Revival cancel should not play normal score audio")
	_expect(not owner.revival_equipped and not owner.revival_available, "Revival should be consumed and unequipped")
	_expect(owner.revival_used, "owner should remember Revival was used")
	_expect(runtime.has_revival_used(), "runtime should remember Revival was used")
	_expect(not _inventory_has_item(runtime, "revival"), "consumed Revival should leave passive inventory")
	_expect(runtime.is_revival_effect_active(), "Revival should start a short activation effect")

	var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	_expect(
		not _array_has_item(spawn_pool.build_spawn_candidates(registry, owner), "revival"),
		"used Revival should be excluded from field spawn candidates"
	)
	var treasure_runtime: Object = TreasureHuntRuntime.new()
	_expect(
		not treasure_runtime._get_passive_reward_pool(registry).has("revival"),
		"used Revival should be excluded from treasure-hunt passive rewards"
	)

	# After the stage-restart reset the score is back to 0-0, so climb to match
	# point again before exercising the post-consumption fatal-score path.
	for _i in range(4):
		score_state.score_for("boss")
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 4, "boss should reach match point again after revival reset")
	_expect(score_state.would_score_finish("boss"), "next boss score should be fatal again after climbing back")

	match_flow.handle_score_event("boss", {
		"score_state": score_state,
		"round_state": FakeRoundState.new(),
		"mythic_item_runtime": runtime,
		"audio": audio,
	}, {})
	_expect(int(score_state.get_snapshot().get("boss_score", -1)) == 5, "second fatal boss score should count after Revival is gone")

	runtime.reset()
	_expect(not runtime.has_revival_used(), "full runtime reset should clear used Revival state")
	_expect(
		_array_has_item(spawn_pool.build_spawn_candidates(registry, owner), "revival"),
		"fresh game state should allow Revival to spawn again"
	)


func _expect_transparent_icon_corners(path: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_expect(not bytes.is_empty(), "Revival icon image should be readable")
	if bytes.is_empty():
		return
	var image := Image.new()
	var err: Error = image.load_png_from_buffer(bytes)
	_expect(err == OK, "Revival icon image should be readable")
	if err != OK:
		return
	var width := image.get_width()
	var height := image.get_height()
	for point in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		_expect(image.get_pixelv(point).a <= 0.01, "Revival icon corners should remain transparent")


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	for item_value in snapshot.get("inventory_items", []):
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
