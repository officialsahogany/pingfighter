extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemGaugeActions := preload("res://scripts/items/active_item_gauge_actions.gd")
const ActiveItemGaugeRuntime := preload("res://scripts/items/active_item_gauge_runtime.gd")
const ActiveItemLifeElixirParticles := preload("res://scripts/items/active_item_life_elixir_particles.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 200.0
	var player_paddle_height := 40.0


class FakeMythicRuntime:
	extends RefCounted

	var calls: Array[float] = []

	func apply_gold_digger_gauge_bonus(gauge_gain: float) -> float:
		calls.append(gauge_gain)
		return gauge_gain * 2.0


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0
	var shakes: Array[Vector2] = []

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_drink() -> void:
		calls.append("play_drink")


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_gauge_actions()
	_verify_controller_delegates_gauge_actions()

	if _failures.is_empty():
		print("active_item_gauge_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_gauge_actions() -> void:
	seed(707)
	var actions: Object = ActiveItemGaugeActions.new()
	var runtime: Object = ActiveItemGaugeRuntime.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"battle_feedback_state": feedback,
		"game_audio": audio,
	})
	var owner := FakeOwner.new()

	_expect(actions.apply_gauge_charge({"gauge_gain": 10.0}, owner, registry, runtime, ActiveItemEffectFeedback.new()), "Gauge actions should apply gauge charge")
	_expect(is_equal_approx(owner.special_gauge, 110.0), "Gauge actions should mutate owner gauge")
	_expect(feedback.gauge_flashes == 1, "Gauge actions should trigger gauge flash")
	_expect(feedback.shakes == [Vector2(0.06, 1.6)], "Gauge actions should dispatch reference shake")
	_expect(audio.calls == ["play_drink"], "Gauge actions should play drink audio")

	var mythic := FakeMythicRuntime.new()
	var mythic_registry := FakeRegistry.new({"mythic_item_runtime": mythic})
	_expect(actions.apply_gauge_charge({"gauge_gain": 20.0}, owner, mythic_registry, runtime, ActiveItemEffectFeedback.new()), "Gauge actions should apply mythic gauge charge")
	_expect(mythic.calls == [20.0], "Gauge actions should pass mythic runtime into gauge helper")
	_expect(is_equal_approx(owner.special_gauge, 150.0), "Gauge actions should apply mythic-adjusted gauge result")

	var life_owner := FakeOwner.new()
	life_owner.special_gauge = 200.0
	life_owner.special_gauge_max = 650.0
	var particles: Array[Dictionary] = []
	_expect(actions.apply_life_elixir(
		{},
		life_owner,
		null,
		particles,
		runtime,
		ActiveItemPlayerCenterReader.new(),
		ActiveItemLifeElixirParticles.new(),
		ActiveItemEffectFeedback.new()
	), "Gauge actions should apply Life Elixir")
	_expect(is_equal_approx(life_owner.special_gauge, 650.0), "Life Elixir actions should respect owner max gauge")
	_expect(particles.size() == 22, "Life Elixir actions should spawn burst particles")
	_expect(_particle_near(particles[0], Vector2(200.0, 700.0)), "Life Elixir actions should use player center for particles")


func _verify_controller_delegates_gauge_actions() -> void:
	seed(708)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"battle_feedback_state": feedback,
		"game_audio": audio,
	})

	_expect(controller.apply_gauge_charge({"gauge_gain": 10.0}, owner, registry), "controller should delegate gauge charge")
	_expect(is_equal_approx(owner.special_gauge, 110.0), "controller delegated gauge charge should mutate owner gauge")
	_expect(feedback.gauge_flashes == 1, "controller delegated gauge charge should preserve flash")
	_expect(feedback.shakes == [Vector2(0.06, 1.6)], "controller delegated gauge charge should preserve shake")
	_expect(audio.calls == ["play_drink"], "controller delegated gauge charge should preserve audio")

	owner.special_gauge = 200.0
	owner.special_gauge_max = 650.0
	_expect(controller.apply_life_elixir({}, owner, null), "controller should delegate Life Elixir")
	_expect(is_equal_approx(owner.special_gauge, 650.0), "controller delegated Life Elixir should fill to owner max")
	_expect(controller.pickup_particles.size() == 22, "controller delegated Life Elixir should spawn particles")
	_expect(_particle_near(controller.pickup_particles[0], Vector2(200.0, 700.0)), "controller delegated Life Elixir should use player center")


func _particle_near(particle: Dictionary, center: Vector2) -> bool:
	var position := _get_vector2(particle, "position", Vector2.ZERO)
	return abs(position.x - center.x) <= 18.0 and abs(position.y - center.y) <= 14.0


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
