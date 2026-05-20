extends SceneTree

const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")

var _failures: Array[String] = []


class FakeScoreboardState:
	extends RefCounted

	var active := false

	func _init(next_active: bool) -> void:
		active = next_active

	func is_active() -> bool:
		return active


class FakeAudio:
	extends RefCounted

	var update_calls := 0
	var stopped: Dictionary = {}
	var dash_sync_values: Array[bool] = []
	var warp_sync_values: Array[bool] = []
	var magnum_sync_values: Array[bool] = []
	var wheel_sync_values: Array[bool] = []
	var chaos_sync_values: Array[bool] = []

	func update(_delta: float) -> void:
		update_calls += 1

	func sync_dash_delay(active: bool) -> void:
		dash_sync_values.append(active)
		if not active:
			stop_dash_delay()

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_boomerang_loop() -> void:
		stopped["boomerang"] = true

	func stop_spider_mine_walk_loop() -> void:
		stopped["spider_mine"] = true

	func stop_plasma_charge() -> void:
		stopped["plasma_charge"] = true

	func stop_plasma_shock() -> void:
		stopped["plasma_shock"] = true

	func sync_warp_gate_loop(active: bool) -> void:
		warp_sync_values.append(active)
		if not active:
			stop_warp_gate_loop()

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func sync_magnum_grip(active: bool) -> void:
		magnum_sync_values.append(active)
		if not active:
			stop_magnum_grip()

	func stop_magnum_grip() -> void:
		stopped["magnum"] = true

	func sync_smasher_wheel_loop(active: bool) -> void:
		wheel_sync_values.append(active)
		if not active:
			stop_smasher_wheel_loop()

	func stop_smasher_wheel_loop() -> void:
		stopped["smasher_wheel"] = true

	func stop_viper_jetpack_loop() -> void:
		stopped["viper_jetpack"] = true

	func sync_chaos_spear_blackhole_loop(active: bool) -> void:
		chaos_sync_values.append(active)
		if not active:
			stop_chaos_spear_blackhole_loop()

	func stop_chaos_spear_blackhole_loop() -> void:
		stopped["chaos_blackhole"] = true

	func stop_ragnarok_shock_loop() -> void:
		stopped["ragnarok_shock"] = true

	func stop_electric_shock_loop() -> void:
		stopped["electric_shock"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true


class FakePlasmaState:
	extends RefCounted

	var muted_audio_seen := false

	func needs_effect_update() -> bool:
		return true

	func update_effects(_fps_scale: float, _context: Dictionary, deps: Dictionary) -> void:
		muted_audio_seen = deps.get("audio", RefCounted.new()) == null


class FakeWarpState:
	extends RefCounted

	var muted_audio_seen := false
	var active := true

	func needs_effect_update() -> bool:
		return true

	func update_effects(_fps_scale: float, _context: Dictionary, deps: Dictionary) -> void:
		muted_audio_seen = deps.get("audio", RefCounted.new()) == null

	func is_active() -> bool:
		return active


class FakeMagnumState:
	extends RefCounted

	var active := true

	func needs_effect_update() -> bool:
		return true

	func update_effects(_fps_scale: float, _current_msec: int, _context: Dictionary) -> Dictionary:
		return {}

	func is_active() -> bool:
		return active


class FakeWheelState:
	extends RefCounted

	var active := true
	var muted_audio_seen := false

	func needs_effect_update() -> bool:
		return true

	func update_effects(_fps_scale: float, _context: Dictionary, deps: Dictionary) -> void:
		muted_audio_seen = deps.get("audio", RefCounted.new()) == null

	func is_active() -> bool:
		return active


class FakeViperRuntime:
	extends RefCounted

	var muted_audio_seen := false
	var blackhole_audio_active := true

	func needs_effect_update() -> bool:
		return true

	func update_effects(_fps_scale: float, _current_msec: int, _context: Dictionary, deps: Dictionary) -> Dictionary:
		muted_audio_seen = deps.get("audio", RefCounted.new()) == null
		return {}

	func is_chaos_blackhole_audio_active() -> bool:
		return blackhole_audio_active


class FakeStageBackground:
	extends RefCounted

	var muted_audio_seen := false

	func update(_delta: float, _context: Dictionary, deps: Dictionary) -> void:
		muted_audio_seen = deps.get("audio", RefCounted.new()) == null


func _init() -> void:
	_verify_scoreboard_mutes_gameplay_loop_audio()
	_verify_live_round_keeps_gameplay_loop_audio()

	if _failures.is_empty():
		print("effects_audio_round_boundary_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scoreboard_mutes_gameplay_loop_audio() -> void:
	var audio := FakeAudio.new()
	var plasma := FakePlasmaState.new()
	var warp := FakeWarpState.new()
	var wheel := FakeWheelState.new()
	var viper := FakeViperRuntime.new()
	var stage_background := FakeStageBackground.new()

	BattleEffectsUpdateController.new().update(0.016, _base_context(), {
		"audio": audio,
		"scoreboard_state": FakeScoreboardState.new(true),
		"smasher_plasma_state": plasma,
		"smasher_warp_gate_state": warp,
		"smasher_wheel_state": wheel,
		"smasher_magnum_grip_state": FakeMagnumState.new(),
		"viper_skill_runtime": viper,
		"stage_background": stage_background,
	})

	_expect(audio.update_calls == 1, "audio update should still tick during scoreboard")
	_expect(audio.stopped.size() == 13 and bool(audio.stopped.get("boomerang", false)) and bool(audio.stopped.get("smasher_wheel", false)), "scoreboard effects update should stop every gameplay loop")
	_expect(plasma.muted_audio_seen and warp.muted_audio_seen and wheel.muted_audio_seen and viper.muted_audio_seen and stage_background.muted_audio_seen, "scoreboard effects update should pass muted deps to gameplay effect states")
	_expect(audio.dash_sync_values.is_empty(), "scoreboard effects update should not re-arm dash delay")
	_expect(_first_bool(audio.warp_sync_values, true) == false, "scoreboard effects update should sync warp loop off")
	_expect(_first_bool(audio.magnum_sync_values, true) == false, "scoreboard effects update should sync magnum loop off")
	_expect(_first_bool(audio.wheel_sync_values, true) == false, "scoreboard effects update should sync Smasher Wheel loop off")
	_expect(_first_bool(audio.chaos_sync_values, true) == false, "scoreboard effects update should sync chaos loop off")


func _verify_live_round_keeps_gameplay_loop_audio() -> void:
	var audio := FakeAudio.new()
	var plasma := FakePlasmaState.new()
	var warp := FakeWarpState.new()
	var wheel := FakeWheelState.new()
	var viper := FakeViperRuntime.new()
	var stage_background := FakeStageBackground.new()

	BattleEffectsUpdateController.new().update(0.016, _base_context(), {
		"audio": audio,
		"scoreboard_state": FakeScoreboardState.new(false),
		"smasher_plasma_state": plasma,
		"smasher_warp_gate_state": warp,
		"smasher_wheel_state": wheel,
		"smasher_magnum_grip_state": FakeMagnumState.new(),
		"viper_skill_runtime": viper,
		"stage_background": stage_background,
	})

	_expect(audio.stopped.is_empty(), "live effects update should not stop loops preemptively")
	_expect(not plasma.muted_audio_seen and not warp.muted_audio_seen and not wheel.muted_audio_seen and not viper.muted_audio_seen and not stage_background.muted_audio_seen, "live effects update should pass real audio deps")
	_expect(_first_bool(audio.dash_sync_values, false), "live effects update should keep dash delay sync active")
	_expect(_first_bool(audio.warp_sync_values, false), "live effects update should keep warp loop sync active")
	_expect(_first_bool(audio.magnum_sync_values, false), "live effects update should keep magnum loop sync active")
	_expect(_first_bool(audio.wheel_sync_values, false), "live effects update should keep Smasher Wheel loop sync active")
	_expect(_first_bool(audio.chaos_sync_values, false), "live effects update should keep chaos loop sync active")


func _base_context() -> Dictionary:
	return {
		"current_msec": 1000,
		"current_stage": 1,
		"selected_character_type": "smasher",
		"dash_snapshot": {
			"active": false,
			"recovering": true,
			"max_tokens": 1,
		},
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(2.0, -8.0),
		"ball_size": 28.6,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _first_bool(values: Array[bool], fallback: bool) -> bool:
	if values.is_empty():
		return fallback
	return values[0]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
