extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var selected_character_type := "smasher"
	var special_gauge := 100.0
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var sensor_equipped := false
	var sensor_enabled := false
	var sensor_ready := false
	var sensor_cooldown_sec := 0.0
	var sensor_cooldown_remaining_sec := 0.0
	var sensor_cooldown_progress := 0.0
	var sensor_auto_dash_effect_active := false
	var sensor_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {
		"down_pressed": false,
		"left_pressed": false,
		"right_pressed": false,
		"action_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeAudio:
	extends RefCounted

	var dash_start_calls := 0
	var poseidon_wave_calls := 0
	var stopped_delay := false

	func play_dash_start(_is_half: bool) -> void:
		dash_start_calls += 1

	func stop_dash_delay() -> void:
		stopped_delay = true

	func play_poseidon_wave() -> void:
		poseidon_wave_calls += 1


class FakeFeedback:
	extends RefCounted

	var shake_calls := 0
	var max_shake_calls := 0

	func set_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		max_shake_calls += 1


class FakeComboState:
	extends RefCounted

	var grace_calls := 0
	var clear_calls := 0

	func start_dash_combo_grace() -> void:
		grace_calls += 1

	func clear_effects() -> void:
		clear_calls += 1


class FakeRegistry:
	extends RefCounted

	var runtime: Object
	var dash_state: Object
	var audio: Object
	var feedback: Object

	func _init(runtime_ref: Object, dash_ref: Object, audio_ref: Object, feedback_ref: Object) -> void:
		runtime = runtime_ref
		dash_state = dash_ref
		audio = audio_ref
		feedback = feedback_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"smasher_dash_state":
				return dash_state
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
		return null


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_verify_catalog(catalog)

	var runtime: Object = MythicItemRuntime.new()
	var dash_state: Object = SmasherDashState.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, dash_state, audio, feedback)
	var round_state := FakeRoundState.new()
	var combo_state := FakeComboState.new()

	_expect(runtime.equip_item("sensor", owner, registry, {"sensor_cooldown_sec": 13.0}, false), "Danger Sensor Belt should equip")
	_expect(runtime.equip_item("poseidon_trident", owner, registry, {"gauge_cost": 20.0, "cooldown": 2.0, "vortex_size": 150.0}, false), "Poseidon Trident should equip beside the belt")
	_expect(str(owner.equipment_slots.get("belt", {}).get("name", "")) == "sensor", "Danger Sensor Belt should sync into the belt slot")
	_expect(owner.sensor_equipped, "owner should expose Danger Sensor Belt equipped state")
	_expect(owner.sensor_ready, "Danger Sensor Belt should begin ready")
	_expect_close(owner.sensor_cooldown_sec, 13.0, "owner should expose the rolled sensor cooldown")

	var danger_config: Dictionary = _build_danger_config(owner)
	var request: Dictionary = runtime.build_sensor_auto_dash_request(owner.player_pos, danger_config, {
		"owner": owner,
		"registry": registry,
		"round_state": round_state,
	})
	_expect(bool(request.get("should_dash", false)), "incoming unreachable ball should request an automatic dash")
	_expect(float(request.get("direction", 0.0)) < 0.0, "sensor dash should choose the predicted miss direction")

	var reachable_config: Dictionary = danger_config.duplicate(true)
	reachable_config["ball_pos"] = Vector2(335.0, 600.0)
	reachable_config["ball_vel"] = Vector2(0.0, 8.0)
	var reachable_request: Dictionary = runtime.build_sensor_auto_dash_request(owner.player_pos, reachable_config, {
		"owner": owner,
		"registry": registry,
		"round_state": round_state,
	})
	_expect(not bool(reachable_request.get("should_dash", true)), "reachable incoming ball should not spend the sensor cooldown")
	round_state.waiting_for_serve = true
	var blocked_request: Dictionary = runtime.build_sensor_auto_dash_request(owner.player_pos, danger_config, {
		"owner": owner,
		"registry": registry,
		"round_state": round_state,
	})
	_expect(str(blocked_request.get("reason", "")) == "blocked", "serve-wait should block sensor auto dash")
	round_state.waiting_for_serve = false

	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	var controller: Object = SmasherPlayerController.new()
	var result: Dictionary = controller.update(
		1.0 / 60.0,
		0,
		owner.player_pos,
		0.0,
		danger_config,
		{
			"owner": owner,
			"registry": registry,
			"input_reader": FakeInputReader.new(),
			"dash_state": dash_state,
			"movement_state": PlayerMovementState.new(),
			"mythic_item_runtime": runtime,
			"round_state": round_state,
			"audio": audio,
			"feedback": feedback,
			"combo_state": combo_state,
		}
	)
	_expect_close(float(result.get("special_gauge", 0.0)), 80.0, "sensor dash should preserve Poseidon sensor-dash gauge spend in the controller result")
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(dash_snapshot.get("active", false)), "sensor should start an actual dash")
	_expect(not bool(dash_snapshot.get("is_half", true)), "sensor should start a full dash")
	_expect(bool(dash_snapshot.get("skip_recovery", false)), "sensor dash should be marked as no-recovery")
	_expect(int(dash_snapshot.get("tokens", -1)) == 0, "sensor dash should not consume or create a dash token")
	_expect_close(float(dash_snapshot.get("charge_timer", 0.0)), 219.0, "sensor dash should leave the existing token recharge lane running normally")
	_expect(audio.dash_start_calls == 1 and audio.stopped_delay, "sensor dash should play the normal dash start cue")
	_expect(audio.poseidon_wave_calls == 1, "sensor dash should trigger Poseidon Trident's dash wave")
	_expect(feedback.shake_calls == 1 and feedback.max_shake_calls >= 1, "sensor and Poseidon feedback should both reach the shared feedback lane")
	_expect(combo_state.grace_calls == 0 and combo_state.clear_calls == 0, "sensor dash should not clear player-intended dash combo state")
	_expect(not runtime.is_sensor_auto_dash_ready(), "sensor should enter cooldown after auto dash")
	_expect_close(runtime.get_sensor_cooldown_remaining_seconds(), 13.0, "sensor cooldown should use the rolled value")
	_expect(bool(runtime.get_snapshot().get("sensor_auto_dash_effect_active", false)), "sensor dash should start its field effect")
	_expect(bool(runtime.get_snapshot().get("poseidon_trident_vortex_active", false)), "sensor dash should expose the Poseidon vortex trigger")

	var pos: Vector2 = owner.player_pos
	var result_pos: Variant = result.get("player_pos", owner.player_pos)
	if result_pos is Vector2:
		pos = result_pos
	for _i in range(20):
		var update_result: Dictionary = dash_state.update(1.0 / 60.0, pos, 0.0, 760.0, 155.0, null, registry)
		var update_pos: Variant = update_result.get("player_pos", pos)
		if update_pos is Vector2:
			pos = update_pos
	dash_snapshot = dash_state.get_snapshot()
	_expect(not bool(dash_snapshot.get("active", true)), "sensor dash should end after the normal dash duration")
	_expect(not bool(dash_snapshot.get("recovering", true)), "sensor dash should skip the normal dash afterdelay")
	_expect_close(float(dash_snapshot.get("stun_timer", 0.0)), 0.0, "sensor dash recovery timer should remain zero")

	runtime.update(owner, registry, 13.0)
	_expect(runtime.is_sensor_auto_dash_ready(), "sensor should become ready after its rolled cooldown elapses")

	print("danger_sensor_belt_port_smoke: ok")
	quit(0)


func _verify_catalog(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("sensor")
	_expect(not item_data.is_empty(), "Danger Sensor Belt should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "위험감지벨트", "Danger Sensor Belt should keep the Python Korean display name")
	_expect(str(item_data.get("type", "")) == "passive", "Danger Sensor Belt should be passive")
	_expect(str(item_data.get("slot", "")) == "belt", "Danger Sensor Belt should use the belt slot")
	_expect_close(float(item_data.get("chance", 0.0)), 0.005, "Danger Sensor Belt field chance should match Python")
	var cooldown_option: Dictionary = _find_roll_option(item_data, "sensor_cooldown_sec")
	_expect_close(float(cooldown_option.get("min", 0.0)), 13.0, "sensor cooldown roll should start at 13 seconds")
	_expect_close(float(cooldown_option.get("max", 0.0)), 20.0, "sensor cooldown roll should cap at 20 seconds")
	_expect_close(float(cooldown_option.get("default", 0.0)), 15.0, "sensor default cooldown should match Python")
	_expect(bool(cooldown_option.get("reverse", false)), "lower sensor cooldown rolls should be better")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "sensor"), "Danger Sensor Belt should be in the passive field-spawn list")
	_expect(_array_has_item(catalog.get_debug_items(), "sensor"), "Danger Sensor Belt should be in the passive debug item list")
	var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	_expect(spawn_pool.get_field_spawn_candidate_names().has("sensor"), "shared field-spawn pool should expose Danger Sensor Belt")
	_expect(not spawn_pool.build_catalog_item("sensor").is_empty(), "shared field-spawn catalog lookup should build Danger Sensor Belt")
	_expect_icon_asset(str(item_data.get("icon_path", "")))


func _build_danger_config(owner: FakeOwner) -> Dictionary:
	return {
		"selected_character_type": owner.selected_character_type,
		"special_gauge": owner.special_gauge,
		"ball_active": true,
		"ball_pos": Vector2(50.0, 610.0),
		"ball_vel": Vector2(-6.0, 8.0),
		"height": 750.0,
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": owner.player_paddle_width,
		"paddle_height": owner.player_paddle_height,
	}


func _expect_icon_asset(icon_path: String) -> void:
	_expect(ProjectResourceLoader.load_texture(icon_path) != null, "Danger Sensor Belt icon should load")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(icon_path)
	_expect(not bytes.is_empty(), "Danger Sensor Belt icon image should be readable")
	if bytes.is_empty():
		return
	var image := Image.new()
	var err: Error = image.load_png_from_buffer(bytes)
	_expect(err == OK, "Danger Sensor Belt icon image should be readable")
	if err != OK:
		return
	var width := image.get_width()
	var height := image.get_height()
	for point in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		_expect(image.get_pixelv(point).a <= 0.01, "Danger Sensor Belt icon corners should remain transparent")
	var bbox: Rect2i = _alpha_bbox(image)
	_expect(bbox.position.x > 0 and bbox.position.y > 0, "Danger Sensor Belt icon alpha bbox should not touch the top-left edge")
	_expect(bbox.end.x < width and bbox.end.y < height, "Danger Sensor Belt icon alpha bbox should not touch the bottom-right edge")


func _alpha_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _find_roll_option(item_data: Dictionary, key: String) -> Dictionary:
	for option_value in item_data.get("roll_options", []):
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
