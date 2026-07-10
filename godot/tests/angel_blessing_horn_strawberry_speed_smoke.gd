extends SceneTree

const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const BlacksmithPlayerController := preload("res://scripts/characters/blacksmith_player_controller.gd")
const BlacksmithThorShieldState := preload("res://scripts/characters/blacksmith_thor_shield_state.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const OptimusPlayerController := preload("res://scripts/characters/optimus_player_controller.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherWheelState := preload("res://scripts/characters/smasher_wheel_state.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")

const HORN_BASE_SPEED := 8.0
const SWIFTNESS_AND_ANGEL_SCALE := 1.06 * 1.30


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"ai_mode": "champion",
		"selected_character_type": "smasher",
		"selected_runtime_character_id": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"special_gauge": 500.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"runtime_paddle_base_width": 155.0,
		"runtime_paddle_base_height": 50.0,
		"runtime_paddle_scale": 1.0,
		"ball_active": true,
		"ball_pos": Vector2(380.0, 360.0),
		"ball_vel": Vector2.ZERO,
		"ball_impact_boost": 1.0,
		"boss_pos": Vector2(330.0, 35.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"current_stage": 1,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeContextBuilder:
	extends RefCounted

	var character_runtime: Object = PlayerCharacterRuntime.new()

	func build_player_control_config(character_type: String) -> Dictionary:
		return character_runtime.get_base_movement_config(character_type)


class FakeSpeedMultiplier:
	extends RefCounted

	var multiplier := 1.0

	func _init(value: float) -> void:
		multiplier = value

	func get_player_speed_multiplier() -> float:
		return multiplier


class FakeEnergyState:
	extends RefCounted

	var apply_calls := 0

	func apply_movement_config(config: Dictionary, _special_gauge: float, _special_gauge_max: float = 500.0) -> Dictionary:
		apply_calls += 1
		var next_config: Dictionary = config.duplicate(true)
		next_config["paddle_speed"] = float(next_config.get("paddle_speed", 0.0)) * 0.5
		next_config["paddle_max_speed"] = float(next_config.get("paddle_max_speed", 0.0)) * 0.5
		return next_config


class FakeFirearmRuntime:
	extends RefCounted

	var control_locked := false
	var movement_speed_multiplier := 0.5

	func is_player_control_locked() -> bool:
		return control_locked

	func get_movement_speed_multiplier() -> float:
		return movement_speed_multiplier


class FakeBlacksmithShieldState:
	extends RefCounted

	func update_input(
		_delta: float,
		_input_snapshot: Dictionary,
		_current_msec: int,
		special_gauge: float,
		_player_pos: Vector2,
		_motion_config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		return {"special_gauge": special_gauge}

	func get_player_speed_multiplier() -> float:
		return 0.5


class FakeViperJetpackState:
	extends RefCounted

	func get_movement_bonus_multiplier() -> float:
		return 2.0


class FakeHornMythicSpeedRuntime:
	extends RefCounted

	var apply_calls := 0
	var multiplier_calls := 0

	func apply_player_movement_config(config: Dictionary) -> void:
		apply_calls += 1
		config["paddle_speed"] = HORN_BASE_SPEED
		config["paddle_max_speed"] = HORN_BASE_SPEED

	func is_horn_strawberry_transformed() -> bool:
		return true

	func get_horn_strawberry_move_speed() -> float:
		return HORN_BASE_SPEED

	func get_player_speed_multiplier() -> float:
		multiplier_calls += 1
		return 1.25


class CapturingSharedController:
	extends RefCounted

	var received_config: Dictionary = {}

	func update(
		_delta: float,
		frame_counter: int,
		player_pos: Vector2,
		player_speed: float,
		config: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		received_config = config.duplicate(true)
		return {
			"frame_counter": frame_counter + 1,
			"player_pos": player_pos,
			"player_speed": player_speed,
		}


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_horn_base_precedes_angel_for_all_characters()
	_verify_mythic_speed_multiplier_applies_once_after_horn_base()
	_verify_allowed_shared_multipliers_still_compose()
	_verify_optimus_energy_multiplier_is_suppressed()
	_verify_commando_firearm_override_is_suppressed()
	_verify_blacksmith_and_viper_overrides_are_suppressed()
	_verify_smasher_wheel_is_cancelled_by_horn_skill_lock()
	_verify_tab_speed_matches_player_control()
	_verify_untransformed_smasher_recovery_still_applies()

	if _failures.is_empty():
		print("angel_blessing_horn_strawberry_speed_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_horn_base_precedes_angel_for_all_characters() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var expected_speed: float = HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE
	registry.instances["smasher_recovery_state"] = FakeSpeedMultiplier.new(1.5)

	for character_type: String in ["smasher", "viper", "soldier", "blacksmith", "optimus"]:
		owner.values["selected_character_type"] = character_type
		var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
			owner,
			registry,
			character_type,
			FakeContextBuilder.new()
		)
		_expect_close(float(config.get("paddle_speed", 0.0)), expected_speed, "%s Horn speed" % character_type)
		_expect_close(float(config.get("paddle_max_speed", 0.0)), expected_speed, "%s Horn max speed" % character_type)
		_expect(bool(config.get("horn_strawberry_transformed", false)), "%s config should expose Horn transform ordering state" % character_type)
		_expect(bool(config.get("horn_strawberry_skill_input_locked", false)), "%s config should expose Horn-specific skill lock" % character_type)


func _verify_allowed_shared_multipliers_still_compose() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	registry.instances["smasher_recovery_state"] = FakeSpeedMultiplier.new(1.5)
	registry.instances["weather_event_state"] = FakeSpeedMultiplier.new(0.8)
	registry.instances["status_effect_state"] = FakeSpeedMultiplier.new(0.9)
	registry.instances["active_item_runtime"] = FakeSpeedMultiplier.new(1.2)
	registry.instances["lingpet_egg_runtime"] = FakeSpeedMultiplier.new(1.1)
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	var expected_speed: float = HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE * 0.8 * 0.9 * 1.2 * 1.1
	_expect_close(float(config.get("paddle_speed", 0.0)), expected_speed, "Horn shared multiplier composition")
	_expect_close(float(config.get("paddle_max_speed", 0.0)), expected_speed, "Horn shared max-speed composition")


func _verify_mythic_speed_multiplier_applies_once_after_horn_base() -> void:
	var owner := FakeOwner.new()
	var mythic_runtime := FakeHornMythicSpeedRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": _build_runtime_perk_state(),
		"mythic_item_runtime": mythic_runtime,
	}
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	_expect(mythic_runtime.apply_calls == 1, "Horn replacement base should be applied exactly once")
	_expect(mythic_runtime.multiplier_calls == 1, "mythic speed multiplier should be composed exactly once")
	_expect_close(
		float(config.get("paddle_max_speed", 0.0)),
		HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE * 1.25,
		"Horn base before one mythic speed multiplier"
	)


func _verify_optimus_energy_multiplier_is_suppressed() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	owner.values["selected_character_type"] = "optimus"
	owner.values["special_gauge"] = 250.0
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"optimus",
		FakeContextBuilder.new()
	)
	var energy_state := FakeEnergyState.new()
	var shared_controller := CapturingSharedController.new()
	var controller := OptimusPlayerController.new()
	controller.shared_controller = shared_controller
	controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		config,
		{"optimus_energy_state": energy_state}
	)
	_expect(energy_state.apply_calls == 0, "Horn-transformed Optimus should skip gauge-ratio movement scaling")
	_expect_close(
		float(shared_controller.received_config.get("paddle_speed", 0.0)),
		HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE,
		"Horn-transformed Optimus controller speed"
	)


func _verify_tab_speed_matches_player_control() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var runtime_perk_state: Object = registry.instances["runtime_perk_state"]
	var mythic_runtime: Object = registry.instances["mythic_item_runtime"]
	var recovery_runtime := FakeSpeedMultiplier.new(1.5)
	var weather_runtime := FakeSpeedMultiplier.new(0.8)
	var status_runtime := FakeSpeedMultiplier.new(0.9)
	var active_runtime := FakeSpeedMultiplier.new(1.2)
	var lingpet_runtime := FakeSpeedMultiplier.new(1.1)
	registry.instances["smasher_recovery_state"] = recovery_runtime
	registry.instances["weather_event_state"] = weather_runtime
	registry.instances["status_effect_state"] = status_runtime
	registry.instances["active_item_runtime"] = active_runtime
	registry.instances["lingpet_egg_runtime"] = lingpet_runtime
	var gameplay_config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	var tab_speed: float = CharacterInfoOverlayStatsPresenter.effective_move_speed(
		"smasher",
		PlayerCharacterRuntime.new(),
		runtime_perk_state,
		recovery_runtime,
		active_runtime,
		mythic_runtime,
		lingpet_runtime,
		Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier"),
		[weather_runtime, status_runtime]
	)
	var expected_speed: float = HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE * 0.8 * 0.9 * 1.2 * 1.1
	_expect_close(tab_speed, expected_speed, "Horn TAB final speed")
	_expect_close(
		tab_speed,
		float(gameplay_config.get("paddle_speed", 0.0)),
		"Horn TAB and player-control speed parity"
	)


func _verify_commando_firearm_override_is_suppressed() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var mythic_runtime: Object = registry.instances["mythic_item_runtime"]
	owner.values["selected_character_type"] = "soldier"
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"soldier",
		FakeContextBuilder.new()
	)
	config["horizontal_input_locked"] = true
	var firearm_runtime := FakeFirearmRuntime.new()
	var shared_controller := CapturingSharedController.new()
	var controller := CommandoPlayerController.new()
	controller.shared_controller = shared_controller
	controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		config,
		{
			"commando_firearm_runtime": firearm_runtime,
			"mythic_item_runtime": mythic_runtime,
		}
	)
	_expect(
		bool(shared_controller.received_config.get("horizontal_input_locked", false)),
		"Commando firearm state must not clear an existing Horn control lock"
	)
	var effective_max_speed: float = (
		float(shared_controller.received_config.get("paddle_max_speed", 0.0))
		* float(shared_controller.received_config.get("paddle_max_speed_multiplier", 1.0))
	)
	_expect_close(
		effective_max_speed,
		HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE,
		"Horn-transformed Commando firearm speed suppression"
	)
	config["horizontal_input_locked"] = false
	firearm_runtime.control_locked = true
	firearm_runtime.movement_speed_multiplier = 0.0
	controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		config,
		{
			"commando_firearm_runtime": firearm_runtime,
			"mythic_item_runtime": mythic_runtime,
		}
	)
	_expect(
		bool(shared_controller.received_config.get("horizontal_input_locked", false)),
		"Horn-transformed Commando should preserve an active suicide-drone control lock"
	)
	_expect_close(
		float(shared_controller.received_config.get("paddle_max_speed_multiplier", 1.0)),
		0.0,
		"Horn-transformed Commando suicide-drone movement freeze"
	)

	var normal_config: Dictionary = PlayerCharacterRuntime.new().get_base_movement_config("soldier")
	normal_config["special_gauge"] = 0.0
	normal_config["selected_character_type"] = "soldier"
	firearm_runtime.control_locked = false
	firearm_runtime.movement_speed_multiplier = 0.5
	controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		normal_config,
		{"commando_firearm_runtime": firearm_runtime}
	)
	_expect_close(
		float(shared_controller.received_config.get("paddle_max_speed_multiplier", 1.0)),
		0.5,
		"untransformed Commando firearm slowdown"
	)


func _verify_blacksmith_and_viper_overrides_are_suppressed() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var expected_speed: float = HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE

	owner.values["selected_character_type"] = "blacksmith"
	var blacksmith_config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"blacksmith",
		FakeContextBuilder.new()
	)
	var horn_shield_state := BlacksmithThorShieldState.new()
	horn_shield_state.umbrella_open = true
	horn_shield_state.umbrella_anim_timer = 0.0
	horn_shield_state.umbrella_gauge = 3
	horn_shield_state.umbrella_swing_active = true
	horn_shield_state.umbrella_swing_timer = 0.5
	var blacksmith_shared := CapturingSharedController.new()
	var blacksmith_controller := BlacksmithPlayerController.new()
	blacksmith_controller.shared_controller = blacksmith_shared
	blacksmith_controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		blacksmith_config,
		{"blacksmith_thor_shield_state": horn_shield_state}
	)
	_expect_close(
		float(blacksmith_shared.received_config.get("paddle_max_speed", 0.0)),
		expected_speed,
		"Horn-transformed Blacksmith character slowdown suppression"
	)
	_expect(not horn_shield_state.is_guard_active(), "Horn skill lock should close a pre-existing Blacksmith shield")
	_expect(not horn_shield_state.has_visible_effects(), "Horn skill lock should clear Blacksmith shield visuals")
	_expect(horn_shield_state.umbrella_gauge == 3, "Horn skill lock should preserve Blacksmith shield durability")
	var generic_lock_shield_state := BlacksmithThorShieldState.new()
	generic_lock_shield_state.umbrella_open = true
	generic_lock_shield_state.umbrella_anim_timer = 0.0
	generic_lock_shield_state.umbrella_gauge = 2
	generic_lock_shield_state.update_input(
		0.0,
		{},
		0,
		100.0,
		Vector2(302.5, 700.0),
		{
			"player_skill_input_locked": true,
			"horn_strawberry_skill_input_locked": false,
		},
		{}
	)
	_expect(generic_lock_shield_state.is_guard_active(), "generic skill lock should preserve an open Blacksmith shield")
	_expect(generic_lock_shield_state.umbrella_gauge == 2, "generic skill lock should preserve Blacksmith shield durability")

	owner.values["selected_character_type"] = "viper"
	var viper_config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"viper",
		FakeContextBuilder.new()
	)
	var viper_shared := CapturingSharedController.new()
	var viper_controller := ViperPlayerController.new()
	viper_controller.shared_controller = viper_shared
	viper_controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		viper_config,
		{"viper_jetpack_state": FakeViperJetpackState.new()}
	)
	_expect_close(
		float(viper_shared.received_config.get("paddle_max_speed", 0.0)),
		expected_speed,
		"Horn-transformed Viper airborne speed suppression"
	)

	var normal_blacksmith_config: Dictionary = PlayerCharacterRuntime.new().get_base_movement_config("blacksmith")
	normal_blacksmith_config["special_gauge"] = 100.0
	blacksmith_controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		normal_blacksmith_config,
		{"blacksmith_thor_shield_state": FakeBlacksmithShieldState.new()}
	)
	_expect_close(
		float(blacksmith_shared.received_config.get("paddle_max_speed", 0.0)),
		3.0,
		"untransformed Blacksmith character slowdown"
	)

	var normal_viper_config: Dictionary = PlayerCharacterRuntime.new().get_base_movement_config("viper")
	viper_controller.update(
		0.0,
		0,
		Vector2(302.5, 700.0),
		0.0,
		normal_viper_config,
		{"viper_jetpack_state": FakeViperJetpackState.new()}
	)
	_expect_close(
		float(viper_shared.received_config.get("paddle_max_speed", 0.0)),
		8.0,
		"untransformed Viper airborne speed bonus"
	)


func _verify_smasher_wheel_is_cancelled_by_horn_skill_lock() -> void:
	var fixture: Dictionary = _build_transformed_fixture()
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	var wheel_state := SmasherWheelState.new()
	wheel_state.active = true
	wheel_state.direction = 1
	wheel_state.start_msec = 1000
	wheel_state.end_msec = 100000
	wheel_state.command_buffer = [{"key": "a", "msec": 990}]
	wheel_state.previous_command_keys["a"] = true
	var result: Dictionary = wheel_state.update_input(
		{},
		1000,
		321.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect_close(float(result.get("special_gauge", 0.0)), 321.0, "Horn-cancelled Smasher wheel gauge preservation")
	_expect(not wheel_state.is_active(), "Horn skill lock should cancel an already-active Smasher wheel")
	_expect(not wheel_state.has_visible_effects(), "Horn skill lock should clear Smasher wheel visuals and collision activity")
	_expect(wheel_state.direction == 0, "Horn skill lock should clear the Smasher wheel auto-movement direction")
	_expect(wheel_state.command_buffer.is_empty(), "Horn skill lock should clear the Smasher wheel command buffer")
	_expect(not bool(wheel_state.previous_command_keys.get("a", true)), "Horn skill lock should clear Smasher wheel held-key history")
	var post_lock_config: Dictionary = wheel_state.apply_movement_config(config, 0.0, 1.0)
	_expect_close(
		float(post_lock_config.get("paddle_max_speed", 0.0)),
		HORN_BASE_SPEED * SWIFTNESS_AND_ANGEL_SCALE,
		"Horn-cancelled Smasher wheel speed"
	)


func _verify_untransformed_smasher_recovery_still_applies() -> void:
	var owner := FakeOwner.new()
	var runtime_perk_state: Object = _build_runtime_perk_state()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_perk_state,
		"smasher_recovery_state": FakeSpeedMultiplier.new(1.5),
		"mythic_item_runtime": MythicItemRuntime.new(),
	}
	var config: Dictionary = BattleScenePlayerControlConfigBuilder.new().build_config(
		owner,
		registry,
		"smasher",
		FakeContextBuilder.new()
	)
	_expect_close(
		float(config.get("paddle_speed", 0.0)),
		6.0 * SWIFTNESS_AND_ANGEL_SCALE * 1.5,
		"untransformed Smasher Recovery speed"
	)


func _build_transformed_fixture() -> Dictionary:
	var owner := FakeOwner.new()
	var runtime_perk_state: Object = _build_runtime_perk_state()
	var mythic_runtime: Object = MythicItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_perk_state,
		"mythic_item_runtime": mythic_runtime,
	}
	_expect(
		mythic_runtime.equip_item("horn_strawberry_mask", owner, registry, {"transform_duration": 60.0}, false),
		"Horn mask should equip for speed composition"
	)
	_expect(mythic_runtime.try_horn_strawberry_transform(owner, registry), "Horn transform should start for speed composition")
	mythic_runtime.update(owner, registry, 4.5)
	_expect(mythic_runtime.is_horn_strawberry_transformed(), "Horn transform should finish for speed composition")
	return {
		"owner": owner,
		"registry": registry,
	}


func _build_runtime_perk_state() -> Object:
	var runtime_perk_state: Object = RuntimePerkState.new()
	runtime_perk_state.runtime_skill_levels = {"common_swiftness": 1}
	var roll_result: Dictionary = runtime_perk_state.roll_angel_blessing_for_stage(
		1,
		runtime_perk_state.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED]
	)
	_expect(bool(roll_result.get("rolled", false)), "Angel move-speed lane should roll for Horn composition")
	_expect_close(
		runtime_perk_state.get_player_speed_multiplier(),
		SWIFTNESS_AND_ANGEL_SCALE,
		"real Swiftness Lv.1 plus Angel speed multiplier"
	)
	return runtime_perk_state


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(
		abs(actual - expected) <= 0.0001,
		"%s: got %.6f expected %.6f" % [message, actual, expected]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
