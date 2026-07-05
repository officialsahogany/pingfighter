extends SceneTree

const ActiveItemThrowActivation := preload("res://scripts/items/active_item_throw_activation.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw_before() -> void:
		calls.append("play_throw_before")

	func play_active_item() -> void:
		calls.append("play_active_item")


class FakeRuntime:
	extends RefCounted

	func is_reinforced_boomerang_gauntlet_equipped() -> bool:
		return true

	func get_boomerang_launch_speed_multiplier() -> float:
		return 1.4

	func get_boomerang_homing_multiplier() -> float:
		return 1.3

	func get_boomerang_knockback_multiplier() -> float:
		return 1.2

	func get_boomerang_stun_multiplier() -> float:
		return 1.1


class FakeRoundState:
	extends RefCounted

	var round_start_msec := 0

	func _init(start_msec: int) -> void:
		round_start_msec = start_msec

	func get_round_start_time_msec() -> int:
		return round_start_msec


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var runtime: Object
	var round_state: Object

	func _init(mythic_runtime: Object = null, round_flow_state: Object = null) -> void:
		runtime = mythic_runtime
		round_state = round_flow_state

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "mythic_item_runtime":
			return runtime
		if key == "round_flow_state":
			return round_state
		return null


func _init() -> void:
	_verify_activation_helper_queues_pending_throw()
	_verify_activation_helper_owns_item_targets_and_blockers()
	_verify_radial_throw_targets_stay_inside_effect_bounds()
	_verify_molotov_target_stays_inside_fire_zone_bounds()
	_verify_controller_delegates_pending_throw_activation()
	_verify_controller_delegates_spider_mine_audio()

	if _failures.is_empty():
		print("active_item_throw_activation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_activation_helper_queues_pending_throw() -> void:
	var activation: Object = ActiveItemThrowActivation.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var pending_throws: Array[Dictionary] = []
	var target := Vector2(380.0, 120.0)

	activation.queue_pending_throw(
		pending_throws,
		owner,
		registry,
		"molotov",
		600,
		target,
		true,
		{"custom_flag": true}
	)

	_expect(pending_throws.size() == 1, "activation helper should append one pending throw")
	var pending: Dictionary = pending_throws[0]
	_expect(str(pending.get("item_name", "")) == "molotov", "activation helper should preserve item name")
	_expect(_get_vector2(pending, "start_position") == Vector2(377.5, 705.0), "activation helper should preserve legacy throw start center")
	_expect(_get_vector2(pending, "target_position") == target, "activation helper should preserve target position")
	_expect(bool(pending.get("custom_flag", false)), "activation helper should copy extra fields")
	_expect(int(pending.get("release_msec", 0)) > int(pending.get("start_msec", 0)), "activation helper should set release time after start")
	_expect(registry.audio.calls == ["play_throw_before", "play_active_item"], "activation helper should play windup and active audio")


func _verify_activation_helper_owns_item_targets_and_blockers() -> void:
	var activation: Object = ActiveItemThrowActivation.new()
	var owner := FakeOwner.new()

	_expect_activation_target_y(
		Callable(activation, "activate_flare"),
		owner,
		"flare",
		135.0,
		["play_throw_before"]
	)
	_expect_activation_target_y(
		Callable(activation, "activate_tear_gas"),
		owner,
		"tear_gas",
		125.0,  # boss_pos.y(55) + 40 + TEAR_GAS_TARGET_BELOW_BOSS(30) — aim lowered so the cloud envelops the boss
		["play_throw_before", "play_active_item"]
	)
	_expect_activation_target_y(
		Callable(activation, "activate_dynamite"),
		owner,
		"dynamite",
		120.0,
		["play_throw_before", "play_active_item"]
	)
	_expect_activation_target_y(
		Callable(activation, "activate_molotov"),
		owner,
		"molotov",
		45.0,
		["play_throw_before", "play_active_item"]
	)
	var high_boss_owner := FakeOwner.new()
	high_boss_owner.boss_pos = Vector2(330.0, 25.0)
	_expect_activation_target_y(
		Callable(activation, "activate_molotov"),
		high_boss_owner,
		"molotov",
		45.0,
		["play_throw_before", "play_active_item"]
	)
	_expect_activation_target_y(
		Callable(activation, "activate_banana"),
		owner,
		"banana",
		45.0,
		["play_throw_before", "play_active_item"]
	)
	_expect_activation_target_y(
		Callable(activation, "activate_soap"),
		owner,
		"soap",
		45.0,
		["play_throw_before", "play_active_item"]
	)

	var round_start_controller: Object = ActiveItemThrowController.new()
	var round_start_registry := FakeRegistry.new(null, FakeRoundState.new(Time.get_ticks_msec()))
	_expect(
		activation.activate_grenade(round_start_controller, owner, round_start_registry),
		"activation helper should allow throws immediately after serve"
	)
	_expect(round_start_controller.get_pending_throws().size() == 1, "immediate post-serve throw should queue a pending throw")
	_expect(round_start_registry.audio.calls == ["play_throw_before"], "immediate post-serve throw should play the normal throw windup audio")

	var windup_controller: Object = ActiveItemThrowController.new()
	var windup_registry := FakeRegistry.new()
	_expect(activation.activate_flare(windup_controller, owner, windup_registry), "activation helper should seed windup blocker setup")
	_expect(
		not activation.activate_soap(windup_controller, owner, windup_registry),
		"activation helper should block a second throw while windup is active"
	)
	_expect(windup_controller.get_pending_throws().size() == 1, "windup blocker should keep only the first pending throw")


func _verify_radial_throw_targets_stay_inside_effect_bounds() -> void:
	var activation: Object = ActiveItemThrowActivation.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(-120.0, 55.0)

	var grenade_controller: Object = ActiveItemThrowController.new()
	var grenade_registry := FakeRegistry.new()
	_expect(activation.activate_grenade(grenade_controller, owner, grenade_registry), "grenade activation should succeed near the left edge")
	_expect(
		_get_vector2(grenade_controller.get_pending_throws()[0], "target_position").x >= grenade_controller.GRENADE_EXPLOSION_RADIUS,
		"grenade target should stay far enough from the left pillar for its explosion radius"
	)

	var flare_controller: Object = ActiveItemThrowController.new()
	var flare_registry := FakeRegistry.new()
	_expect(activation.activate_flare(flare_controller, owner, flare_registry), "flare activation should succeed near the left edge")
	_expect(
		_get_vector2(flare_controller.get_pending_throws()[0], "target_position").x >= flare_controller.FLARE_RADIUS,
		"flare target should stay far enough from the left pillar for its flash radius"
	)

	var gas_controller: Object = ActiveItemThrowController.new()
	var gas_registry := FakeRegistry.new()
	_expect(activation.activate_tear_gas(gas_controller, owner, gas_registry), "tear gas activation should succeed near the left edge")
	_expect(
		_get_vector2(gas_controller.get_pending_throws()[0], "target_position").x >= min(gas_controller.FIELD_WIDTH * 0.5, gas_controller.TEAR_GAS_MAX_RADIUS_X),
		"tear gas target should stay far enough from the left pillar for its full smoke width"
	)


func _verify_molotov_target_stays_inside_fire_zone_bounds() -> void:
	var activation: Object = ActiveItemThrowActivation.new()
	var owner := FakeOwner.new()
	owner.boss_pos = Vector2(-90.0, 55.0)
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()

	_expect(activation.activate_molotov(controller, owner, registry), "molotov activation should succeed near the left edge")
	_expect(controller.get_pending_throws().size() == 1, "left-edge molotov activation should queue one pending throw")
	var pending: Dictionary = controller.get_pending_throws()[0]
	_expect(
		_get_vector2(pending, "target_position").x >= controller.MOLOTOV_FIRE_WIDTH * 0.5,
		"molotov target should stay far enough from the left pillar for its full fire zone"
	)


func _verify_controller_delegates_pending_throw_activation() -> void:
	var owner := FakeOwner.new()

	var grenade_controller: Object = ActiveItemThrowController.new()
	var grenade_registry := FakeRegistry.new()
	_expect(grenade_controller.activate_grenade(owner, grenade_registry), "grenade activation should succeed")
	_expect(grenade_controller.get_pending_throws().size() == 1, "grenade activation should queue a pending throw")
	var grenade_pending: Dictionary = grenade_controller.get_pending_throws()[0]
	_expect(str(grenade_pending.get("item_name", "")) == "grenade", "grenade activation should preserve pending item name")
	_expect(_get_vector2(grenade_pending, "start_position") == Vector2(377.5, 705.0), "grenade activation should preserve legacy start center")
	_expect(grenade_registry.audio.calls == ["play_throw_before"], "grenade activation should only play throw-before audio")

	var boomerang_controller: Object = ActiveItemThrowController.new()
	var boomerang_registry := FakeRegistry.new(FakeRuntime.new())
	_expect(boomerang_controller.activate_boomerang(owner, boomerang_registry), "boomerang activation should succeed")
	_expect(boomerang_controller.get_pending_throws().size() == 1, "boomerang activation should queue a pending throw")
	var boomerang_pending: Dictionary = boomerang_controller.get_pending_throws()[0]
	_expect(str(boomerang_pending.get("item_name", "")) == "boomerang", "boomerang activation should preserve pending item name")
	_expect(bool(boomerang_pending.get("gauntlet_equipped", false)), "boomerang activation should preserve gauntlet extra field")
	_expect(boomerang_registry.audio.calls == ["play_throw_before", "play_active_item"], "boomerang activation should preserve audio order")


func _verify_controller_delegates_spider_mine_audio() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	_expect(controller.activate_spider_mine(FakeOwner.new(), registry), "spider mine activation should succeed")
	_expect(controller.get_pending_throws().is_empty(), "spider mine should not create a pending throw")
	_expect(controller.get_spider_mines().size() == 1, "spider mine should deploy immediately")
	_expect(registry.audio.calls == ["play_active_item"], "spider mine activation should play active-item audio")


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_activation_target_y(
	activation_callable: Callable,
	owner: Object,
	item_name: String,
	expected_y: float,
	expected_audio_calls: Array[String]
) -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()

	_expect(bool(activation_callable.call(controller, owner, registry)), "%s helper activation should succeed" % item_name)
	_expect(controller.get_pending_throws().size() == 1, "%s helper activation should queue one pending throw" % item_name)
	var pending: Dictionary = controller.get_pending_throws()[0]
	_expect(str(pending.get("item_name", "")) == item_name, "%s helper activation should preserve item name" % item_name)
	_expect(
		is_equal_approx(_get_vector2(pending, "target_position").y, expected_y),
		"%s helper activation should preserve target y" % item_name
	)
	_expect(registry.audio.calls == expected_audio_calls, "%s helper activation should preserve audio order" % item_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
