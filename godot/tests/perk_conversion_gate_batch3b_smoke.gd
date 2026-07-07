extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")

const SENSOR_ID := "sensor"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var selected_character_type := "smasher"
	var special_gauge := 100.0
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeInputReader:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"down_pressed": false,
			"left_pressed": false,
			"right_pressed": false,
			"action_pressed": false,
			"direction": 0.0,
		}


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


class FakeAudio:
	extends RefCounted

	var dash_start_calls := 0
	var stopped_delay_calls := 0

	func play_dash_start(_is_half: bool) -> void:
		dash_start_calls += 1

	func stop_dash_delay() -> void:
		stopped_delay_calls += 1


class FakeFeedback:
	extends RefCounted

	var shake_calls := 0
	var dash_flash_calls := 0

	func set_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1

	func trigger_dash_flash() -> void:
		dash_flash_calls += 1


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
	var runtime_perk_state: Object
	var dash_state: Object
	var audio: Object
	var feedback: Object

	func _init(runtime_ref: Object, state_ref: Object, dash_ref: Object, audio_ref: Object, feedback_ref: Object) -> void:
		runtime = runtime_ref
		runtime_perk_state = state_ref
		dash_state = dash_ref
		audio = audio_ref
		feedback = feedback_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"runtime_perk_state":
				return runtime_perk_state
			"smasher_dash_state":
				return dash_state
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
		return null


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_off_parity_keeps_rolled_cooldown()
	_verify_on_level_one_recharges_after_real_ticks()
	_verify_on_level_three_burst_cap_and_sequential_recharge()
	_verify_on_level_five_uses_fifteen_second_recharge()
	_verify_on_level_zero_and_item_only_are_inactive()
	_verify_reset_boundaries_match_existing_sensor_cooldown()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_gate_batch3b_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_parity_keeps_rolled_cooldown() -> void:
	var env: Dictionary = _make_env({}, false)
	var runtime: Object = env["runtime"]
	var owner: FakeOwner = env["owner"]
	var registry: FakeRegistry = env["registry"]
	_expect(runtime.equip_item(SENSOR_ID, owner, registry, {"sensor_cooldown_sec": 13.0}, false), "OFF sensor fixture should equip")
	_expect(runtime.is_sensor_effect_active(), "OFF sensor effect gate should be equipped-based")
	_expect(runtime.is_sensor_auto_dash_ready(), "OFF sensor should start ready")
	_expect_close(runtime.get_sensor_cooldown_seconds(), 13.0, "OFF sensor should keep rolled cooldown seconds")

	var first: Dictionary = _attempt_sensor_dash(env)
	_expect(bool(first.get("started", false)), "OFF first danger should trigger sensor dash")
	_expect_close(runtime.get_sensor_cooldown_remaining_seconds(), 13.0, "OFF dash should reset rolled cooldown")
	_expect_close(float(first.get("special_gauge_after", 0.0)), 100.0, "OFF sensor dash should not spend special gauge")
	_expect(int(first.get("dash_tokens_after", -1)) == int(first.get("dash_tokens_before", -2)), "OFF sensor dash should not spend normal dash tokens")

	var second: Dictionary = _attempt_sensor_dash(env)
	_expect(not bool(second.get("started", true)), "OFF immediate second danger should be blocked by cooldown")
	_advance_runtime(env, 780)
	_expect(runtime.is_sensor_auto_dash_ready(), "OFF sensor should become ready after 13s of real update ticks")


func _verify_on_level_one_recharges_after_real_ticks() -> void:
	var env: Dictionary = _make_env({SENSOR_ID: 1}, true)
	var runtime: Object = env["runtime"]
	_expect(runtime.is_sensor_effect_active(), "ON Lv1 sensor effect gate should be perk-level based")
	_expect(runtime.is_sensor_auto_dash_ready(), "ON Lv1 sensor should start with a full dedicated token")
	_expect(runtime.get_sensor_auto_dash_token_capacity() == 1, "ON Lv1 sensor token capacity should be 1")
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv1 sensor should start with 1 token")
	_expect_close(runtime.get_sensor_cooldown_seconds(), 30.0, "ON Lv1 sensor cooldown should use perk table")

	var first: Dictionary = _attempt_sensor_dash(env)
	_expect(bool(first.get("started", false)), "ON Lv1 first danger should spend the dedicated token")
	_expect(runtime.get_sensor_auto_dash_tokens() == 0, "ON Lv1 first dash should consume the dedicated token")
	_expect_close(runtime.sensor_auto_dash_recharge_timer_frames, 1800.0, "ON Lv1 should start a 30s recharge timer")
	_expect_close(float(first.get("special_gauge_after", 0.0)), 100.0, "ON Lv1 sensor dash should not spend special gauge")
	_expect(int(first.get("dash_tokens_after", -1)) == int(first.get("dash_tokens_before", -2)), "ON Lv1 sensor dash should not spend normal dash tokens")

	var second: Dictionary = _attempt_sensor_dash(env)
	_expect(not bool(second.get("started", true)), "ON Lv1 immediate second danger should be blocked after token spend")
	_advance_runtime(env, 1799)
	_expect(runtime.get_sensor_auto_dash_tokens() == 0, "ON Lv1 should not recharge early before the final tick")
	_advance_runtime(env, 1)
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv1 should recharge one token after 30s of real update ticks")
	_expect_close(runtime.sensor_auto_dash_recharge_timer_frames, 0.0, "ON Lv1 full token state should stop the recharge timer")
	var third: Dictionary = _attempt_sensor_dash(env)
	_expect(bool(third.get("started", false)), "ON Lv1 should trigger again after the recharge tick")


func _verify_on_level_three_burst_cap_and_sequential_recharge() -> void:
	var env: Dictionary = _make_env({SENSOR_ID: 3}, true)
	var runtime: Object = env["runtime"]
	_expect(runtime.is_sensor_auto_dash_ready(), "ON Lv3 sensor should initialize tokens through the runtime bridge")
	_expect(runtime.get_sensor_auto_dash_token_capacity() == 2, "ON Lv3 token capacity should be 2")
	_expect(runtime.get_sensor_auto_dash_tokens() == 2, "ON Lv3 should start full")
	_expect_close(runtime.get_sensor_cooldown_seconds(), 23.0, "ON Lv3 sensor cooldown should use perk table")

	_expect(bool(_attempt_sensor_dash(env).get("started", false)), "ON Lv3 first burst dash should trigger")
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv3 first burst should leave 1 token")
	_expect(bool(_attempt_sensor_dash(env).get("started", false)), "ON Lv3 second burst dash should trigger")
	_expect(runtime.get_sensor_auto_dash_tokens() == 0, "ON Lv3 second burst should leave 0 tokens")
	_expect(not bool(_attempt_sensor_dash(env).get("started", true)), "ON Lv3 third immediate dash should be blocked by burst cap")

	_advance_runtime(env, 1380)
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv3 should recharge only one token per cooldown interval")
	_expect_close(runtime.sensor_auto_dash_recharge_timer_frames, 1380.0, "ON Lv3 partial refill should arm the next sequential timer")


func _verify_on_level_five_uses_fifteen_second_recharge() -> void:
	var env: Dictionary = _make_env({SENSOR_ID: 5}, true)
	var runtime: Object = env["runtime"]
	_expect(runtime.is_sensor_auto_dash_ready(), "ON Lv5 sensor should initialize ready")
	_expect_close(runtime.get_sensor_cooldown_seconds(), 15.0, "ON Lv5 sensor cooldown should use 15s endpoint")
	_expect(bool(_attempt_sensor_dash(env).get("started", false)), "ON Lv5 first dash should trigger")
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv5 should have 1 token after one dash")
	_advance_runtime(env, 899)
	_expect(runtime.get_sensor_auto_dash_tokens() == 1, "ON Lv5 should not refill before 15s")
	_advance_runtime(env, 1)
	_expect(runtime.get_sensor_auto_dash_tokens() == 2, "ON Lv5 should refill to max after 15s of real update ticks")
	_expect_close(runtime.sensor_auto_dash_recharge_timer_frames, 0.0, "ON Lv5 max tokens should stop timer")


func _verify_on_level_zero_and_item_only_are_inactive() -> void:
	var no_level: Dictionary = _make_env({}, true)
	var runtime: Object = no_level["runtime"]
	_expect(not runtime.is_sensor_effect_active(), "ON level 0 sensor effect gate should be inactive")
	_expect(not runtime.is_sensor_auto_dash_ready(), "ON level 0 sensor should not be ready")
	_expect(runtime.get_sensor_auto_dash_token_capacity() == 0, "ON level 0 token capacity should be 0")
	_expect(not bool(_attempt_sensor_dash(no_level).get("started", true)), "ON level 0 danger should not auto dash")

	var item_only: Dictionary = _make_env({}, true)
	var item_runtime: Object = item_only["runtime"]
	var owner: FakeOwner = item_only["owner"]
	var registry: FakeRegistry = item_only["registry"]
	_expect(item_runtime.equip_item(SENSOR_ID, owner, registry, {"sensor_cooldown_sec": 13.0}, false), "ON item-only sensor fixture should equip")
	_expect(item_runtime.is_sensor_equipped(), "ON item-only should still expose equipment state")
	_expect(not item_runtime.is_sensor_effect_active(), "ON item-only sensor effect gate should be inactive")
	_expect(not item_runtime.is_sensor_auto_dash_ready(), "ON item-only sensor should not be ready")
	_expect_close(item_runtime.get_sensor_cooldown_seconds(), 15.0, "ON item-only should not leak rolled sensor cooldown")
	_expect(not bool(_attempt_sensor_dash(item_only).get("started", true)), "ON item-only danger should not auto dash")


func _verify_reset_boundaries_match_existing_sensor_cooldown() -> void:
	var env: Dictionary = _make_env({SENSOR_ID: 3}, true)
	var runtime: Object = env["runtime"]
	var registry: FakeRegistry = env["registry"]
	_expect(bool(_attempt_sensor_dash(env).get("started", false)), "reset boundary fixture first dash should trigger")
	_expect(bool(_attempt_sensor_dash(env).get("started", false)), "reset boundary fixture second dash should trigger")
	_expect(runtime.get_sensor_auto_dash_tokens() == 0, "reset boundary fixture should have no tokens")
	_expect(runtime.sensor_auto_dash_recharge_timer_frames > 0.0, "reset boundary fixture should be recharging")
	runtime.sensor_auto_dash_effect_timer_frames = 12.0
	runtime.sensor_last_dash_direction = -1.0

	runtime.reset_round(registry)
	_expect(runtime.get_sensor_auto_dash_tokens() == 0, "round reset should preserve dedicated sensor tokens like existing cooldown")
	_expect(runtime.sensor_auto_dash_recharge_timer_frames > 0.0, "round reset should preserve dedicated sensor recharge timer like existing cooldown")
	_expect_close(runtime.sensor_auto_dash_effect_timer_frames, 0.0, "round reset should clear only sensor visual effect timer")
	_expect_close(runtime.sensor_last_dash_direction, 0.0, "round reset should clear only sensor visual direction")

	runtime.auto_defense_runtime.clear_sensor_runtime(runtime, true)
	_expect(runtime.get_sensor_auto_dash_tokens() == 2, "full sensor runtime clear should refill dedicated tokens")
	_expect_close(runtime.sensor_auto_dash_recharge_timer_frames, 0.0, "full sensor runtime clear should stop recharge timer")


func _make_env(levels: Dictionary, flag_enabled: bool) -> Dictionary:
	PerkConversionFlags.debug_set_enabled(flag_enabled)
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var state := RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	var owner := FakeOwner.new()
	var dash_state := SmasherDashState.new()
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, state, dash_state, audio, feedback)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return {
		"runtime": runtime,
		"state": state,
		"owner": owner,
		"dash_state": dash_state,
		"audio": audio,
		"feedback": feedback,
		"registry": registry,
		"controller": SmasherPlayerController.new(),
		"round_state": FakeRoundState.new(),
		"combo_state": FakeComboState.new(),
		"frame_counter": 0,
	}


func _attempt_sensor_dash(env: Dictionary) -> Dictionary:
	var runtime: Object = env["runtime"]
	var owner: FakeOwner = env["owner"]
	var dash_state: Object = env["dash_state"]
	var audio: FakeAudio = env["audio"]
	var controller: Object = env["controller"]
	var before_audio: int = audio.dash_start_calls
	var before_tokens: int = int(dash_state.get_snapshot().get("tokens", -1))
	var before_gauge: float = owner.special_gauge
	var config: Dictionary = _danger_config(owner)
	var result: Dictionary = controller.update(
		1.0 / 60.0,
		int(env.get("frame_counter", 0)),
		owner.player_pos,
		0.0,
		config,
		{
			"owner": owner,
			"registry": env["registry"],
			"input_reader": FakeInputReader.new(),
			"dash_state": dash_state,
			"movement_state": PlayerMovementState.new(),
			"mythic_item_runtime": runtime,
			"round_state": env["round_state"],
			"audio": audio,
			"feedback": env["feedback"],
			"combo_state": env["combo_state"],
		}
	)
	env["frame_counter"] = int(env.get("frame_counter", 0)) + 1
	var after_gauge: float = float(result.get("special_gauge", before_gauge))
	owner.special_gauge = after_gauge
	return {
		"started": audio.dash_start_calls > before_audio,
		"special_gauge_before": before_gauge,
		"special_gauge_after": after_gauge,
		"dash_tokens_before": before_tokens,
		"dash_tokens_after": int(dash_state.get_snapshot().get("tokens", -1)),
	}


func _advance_runtime(env: Dictionary, frames: int) -> void:
	var runtime: Object = env["runtime"]
	for _i in range(max(0, frames)):
		runtime.update(env["owner"], env["registry"], 1.0 / 60.0)


func _danger_config(owner: FakeOwner) -> Dictionary:
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


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
