extends SceneTree

const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDashSpiritState := preload("res://scripts/characters/smasher_dash_spirit_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")

var _failures: Array[String] = []


class RegistryStub:
	extends RefCounted
	var runtime_perk_state: Object

	func _init(state: Object) -> void:
		runtime_perk_state = state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


class GaugeOwner:
	extends RefCounted
	var special_gauge := 250.0
	var special_gauge_max := 500.0


class MythicGaugeRuntime:
	extends RefCounted
	var next_unblessed_max := 500.0
	var synced_special_gauge_max := 500.0
	var synced_special_gauge_unblessed_max := 500.0
	var synced_angel_gauge_multiplier := 1.0
	var runtime_perk_state_ref: Object = null

	func get_effective_special_gauge_max(_base_max: float) -> float:
		return next_unblessed_max

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key) if owner != null else null
		return fallback if value == null else value


class DashSpiritPerkStub:
	extends RefCounted
	func get_runtime_skill_bonus(skill_id: String) -> float:
		return 1.0 if skill_id == "dash_spirit" else 0.0


func _init() -> void:
	_verify_five_surface_formulas_and_item_hud_sync()
	_verify_gauge_composition_mythic_unowned_and_full_refill()
	_verify_shared_dash_distance_and_dash_spirit_geometry()
	_verify_character_info_and_five_character_shared_route()

	if _failures.is_empty():
		print("mystic_dice_stat_apply_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_five_surface_formulas_and_item_hud_sync() -> void:
	var negative_speed_state := _state_with_raw({"player_speed": -3})
	_expect_close(negative_speed_state.get_player_speed_multiplier(), 0.97, "negative move-speed roll must survive the existing maxf floor")

	var state := _state_with_raw({
		"paddle_size": 3,
		"dash_recovery": -3,
		"dash_cooldown": -3,
		"item_cooldown": -3,
	})
	_expect_close(state.get_player_paddle_size_multiplier(), 1.03, "paddle-size roll should multiply the existing result")
	_expect_close(state.get_dash_recovery_frames(42.0), 40.74, "LIB recovery raw -3 should reduce 42 frames by 3%")
	_expect_close(state.get_dash_recharge_frames(300.0), 291.0, "LIB dash cooldown raw -3 should reduce 300 frames by 3%")
	_expect_close(state.get_dash_recovery_frames(1.0), 1.0, "recovery dice multiplier must stay inside the one-frame clamp")
	_expect_close(state.get_dash_recharge_frames(6.0), 6.0, "recharge dice multiplier must stay inside the six-frame clamp")
	_expect(state.get_active_item_cooldown_msec(10000) == 9700, "LIB item cooldown raw -3 should reduce 10000ms to 9700ms")

	var registry := RegistryStub.new(state)
	var item_data := {"cooldown_msec": 10000}
	var gameplay_cooldown := ActiveItemSlotController.new()._get_effective_active_item_cooldown_msec(item_data, registry)
	var hud_cooldown := ActiveItemHudState.new().get_active_item_cooldown_msec(item_data, registry, state)
	_expect(gameplay_cooldown == 9700 and hud_cooldown == 9700, "gameplay and HUD must read the same final item cooldown")


func _verify_gauge_composition_mythic_unowned_and_full_refill() -> void:
	var state := _state_with_raw({"skill_gauge": 3})
	var runtime := MythicGaugeRuntime.new()
	runtime.runtime_perk_state_ref = state
	var owner := GaugeOwner.new()
	var syncer := MythicItemOwnerSyncer.new()
	var constants := {"base_special_gauge_max": 500.0}
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge_max, 515.0, "mythic-unowned Dice-only gauge should grow 500 to 515")
	_expect_close(owner.special_gauge, 258.0, "Dice source change should preserve the current gauge ratio")
	_expect_close(runtime.synced_special_gauge_unblessed_max, 515.0, "Dice gauge should live in the unblessed/source cache")
	_expect_close(runtime.synced_angel_gauge_multiplier, 1.0, "Dice gauge must not contaminate the Angel multiplier cache")
	syncer.sync_fuel_pouch_gauge_max(runtime, owner, constants)
	_expect_close(owner.special_gauge, 258.0, "repeated Dice-only gauge sync should be idempotent")

	var combined_state := _state_with_raw({"skill_gauge": 3})
	combined_state.roll_angel_blessing_for_stage(
		1,
		combined_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX]
	)
	var combined_runtime := MythicGaugeRuntime.new()
	combined_runtime.next_unblessed_max = 540.0
	combined_runtime.runtime_perk_state_ref = combined_state
	var combined_owner := GaugeOwner.new()
	syncer.sync_fuel_pouch_gauge_max(combined_runtime, combined_owner, constants)
	_expect_close(combined_runtime.synced_special_gauge_unblessed_max, 556.2, "Fuel 540 should compose with Dice before Angel")
	_expect_close(combined_runtime.synced_angel_gauge_multiplier, 1.30, "Angel multiplier should remain a separate final lane")
	_expect_close(combined_owner.special_gauge_max, 723.06, "Fuel 540 x Dice 1.03 x Angel 1.30 should produce 723.06")
	_expect_close(combined_owner.special_gauge, 278.0, "simultaneous source growth should preserve ratio before Angel absolute growth")

	RuntimePerkInstantRewards.new().apply_full_gauge(
		combined_owner,
		null,
		"smasher_skill_state",
		500.0,
		Callable()
	)
	_expect_close(combined_owner.special_gauge, 723.06, "full-gauge instant should fill the real composed owner maximum")


func _verify_shared_dash_distance_and_dash_spirit_geometry() -> void:
	var neutral_state := RuntimePerkState.new()
	var boosted_state := _state_with_raw({"dash_distance": 3})
	var base_distance := _run_full_dash(SmasherDashState.new(), neutral_state)
	var boosted_distance := _run_full_dash(SmasherDashState.new(), boosted_state)
	_expect_close(base_distance, 210.0, "baseline full dash should retain its shipped 210px motion")
	_expect_close(boosted_distance, 216.0, "dash-distance +3 raw should produce a 216px full dash (per-frame round)")

	var viper := ViperPlayerController.new()
	var shared_dash_controller: Object = viper._get_shared_dash_controller()
	var viper_dash_state := SmasherDashState.new()
	var viper_start: Dictionary = shared_dash_controller.try_start_sensor_dash(
		1.0,
		Vector2.ZERO,
		{},
		{"dash_state": viper_dash_state, "runtime_perk_state": boosted_state}
	)
	_expect(bool(viper_start.get("started", false)), "Viper should start through the shared Smasher dash controller")
	_expect_close(float(viper_dash_state.get_snapshot().get("dash_distance_multiplier", 0.0)), 1.03, "non-Smasher shared dash should snapshot the same Dice distance multiplier")

	var spirit := SmasherDashSpiritState.new()
	_expect(
		spirit.try_spawn_from_dash(
			1.0,
			false,
			Vector2.ZERO,
			Vector2(155.0, 50.0),
			{"runtime_perk_state": DashSpiritPerkStub.new()},
			15.0,
			1.03
		),
		"guaranteed Dash Spirit fixture should spawn"
	)
	var laser: Dictionary = spirit.lasers[0] as Dictionary
	_expect_close(absf((laser.get("end", Vector2.ZERO) as Vector2).x - (laser.get("start", Vector2.ZERO) as Vector2).x), 216.0, "Dash Spirit collision laser should scale with real dash distance")


func _verify_character_info_and_five_character_shared_route() -> void:
	var boosted_state := _state_with_raw({"dash_distance": 3})
	var base_display := CharacterInfoOverlayStatsPresenter.effective_dash_distance(null, null)
	var boosted_display := CharacterInfoOverlayStatsPresenter.effective_dash_distance(boosted_state, null)
	_expect_close(boosted_display, 216.0, "TAB dash-distance row should match the real 216px dice-boosted dash")

	var character_runtime := PlayerCharacterRuntime.new()
	for character_type: String in ["smasher", "viper", "soldier", "blacksmith", "optimus"]:
		_expect(character_runtime.get_dash_state_key(character_type) == "smasher_dash_state", "%s should share the canonical dash state" % character_type)
	for controller_path: String in [
		"res://scripts/characters/viper_player_controller.gd",
		"res://scripts/characters/commando_player_controller.gd",
		"res://scripts/characters/blacksmith_player_controller.gd",
		"res://scripts/characters/optimus_player_controller.gd",
	]:
		var source := FileAccess.get_file_as_string(controller_path)
		_expect(source.contains("SmasherPlayerController") and source.contains("shared_controller"), "%s should retain the shared dash controller route" % controller_path)


func _state_with_raw(overrides: Dictionary) -> Object:
	var state := RuntimePerkState.new()
	var raw := {
		"player_speed": 0,
		"paddle_size": 0,
		"skill_gauge": 0,
		"dash_distance": 0,
		"dash_recovery": 0,
		"dash_cooldown": 0,
		"item_cooldown": 0,
	}
	for stat_key: Variant in overrides.keys():
		raw[stat_key] = int(overrides[stat_key])
	var commit: Dictionary = state.commit_mystic_dice_roll(raw)
	_expect(bool(commit.get("accepted", false)), "stat fixture raw should satisfy one-roll bounds")
	return state


func _run_full_dash(dash_state: Object, runtime_perk_state: Object) -> float:
	var started: bool = bool(dash_state.start(1.0, false, runtime_perk_state, null, false))
	_expect(started, "full dash fixture should start")
	var position := Vector2.ZERO
	for _frame: int in range(20):
		var result: Dictionary = dash_state.update(
			1.0 / 60.0,
			position,
			0.0,
			10000.0,
			0.0,
			runtime_perk_state,
			null
		)
		position = result.get("player_pos", position) as Vector2
	return position.x


func _passthrough_stat_chain(base_value: float, _stat_sources: Array, _method_name: String) -> float:
	return base_value


func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
