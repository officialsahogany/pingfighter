extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemRegenerationPotionRuntime := preload("res://scripts/items/active_item_regeneration_potion_runtime.gd")

var _failures: Array[String] = []


class FakeCooldownState:
	extends RefCounted

	var reset_cooldowns_calls := 0

	func reset_cooldowns() -> void:
		reset_cooldowns_calls += 1


class FakeResetState:
	extends RefCounted

	var reset_calls := 0

	func reset() -> void:
		reset_calls += 1


class FakeDashState:
	extends RefCounted

	var refill_calls := 0
	var tokens := 3

	func refill_tokens() -> void:
		refill_calls += 1
		tokens = 4

	func get_snapshot() -> Dictionary:
		return {"tokens": tokens}


class FakeOrbHud:
	extends RefCounted

	var reset_values: Array[int] = []

	func reset_dash_tokens(current_charges: int) -> void:
		reset_values.append(current_charges)


class FakeFeedback:
	extends RefCounted

	var gauge_flashes := 0
	var dash_flashes := 0
	var shakes: Array[Vector2] = []

	func trigger_gauge_flash() -> void:
		gauge_flashes += 1

	func trigger_dash_flash() -> void:
		dash_flashes += 1

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_drink() -> void:
		calls.append("play_drink")

	func play_active_item() -> void:
		calls.append("play_active_item")


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_direct_regeneration_runtime()
	_verify_controller_delegates_regeneration_runtime()

	if _failures.is_empty():
		print("active_item_regeneration_potion_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_regeneration_runtime() -> void:
	var runtime: Object = ActiveItemRegenerationPotionRuntime.new()
	var registry := FakeRegistry.new()
	var smasher_skill := FakeCooldownState.new()
	var viper_skill := FakeResetState.new()
	var drive_input := FakeCooldownState.new()
	var dash := FakeDashState.new()
	var orb := FakeOrbHud.new()
	registry.instances = {
		"smasher_skill_state": smasher_skill,
		"viper_skill_state": viper_skill,
		"smasher_drive_input_state": drive_input,
		"smasher_dash_state": dash,
		"orb_hud_state": orb,
	}

	var result: Dictionary = runtime.apply(registry)

	_expect(smasher_skill.reset_cooldowns_calls == 1, "regeneration runtime should reset Smasher skill cooldowns")
	_expect(viper_skill.reset_calls == 1, "regeneration runtime should support reset fallback for Viper skill state")
	_expect(drive_input.reset_cooldowns_calls == 1, "regeneration runtime should reset drive input cooldowns")
	_expect(dash.refill_calls == 1, "regeneration runtime should refill dash tokens")
	_expect(orb.reset_values == [4], "regeneration runtime should sync HUD dash tokens from dash snapshot")
	_expect(int(result.get("dash_tokens", 0)) == 4, "regeneration runtime should expose synced dash token count")

	var empty_registry := FakeRegistry.new()
	var empty_result: Dictionary = runtime.apply(empty_registry)
	_expect(int(empty_result.get("dash_tokens", 0)) == 1, "regeneration runtime should preserve legacy default dash token fallback")


func _verify_controller_delegates_regeneration_runtime() -> void:
	seed(303)
	var controller: Object = ActiveItemEffectController.new()
	var registry := FakeRegistry.new()
	var smasher_skill := FakeCooldownState.new()
	var viper_skill := FakeCooldownState.new()
	var drive_input := FakeCooldownState.new()
	var dash := FakeDashState.new()
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	registry.instances = {
		"smasher_skill_state": smasher_skill,
		"viper_skill_state": viper_skill,
		"smasher_drive_input_state": drive_input,
		"smasher_dash_state": dash,
		"orb_hud_state": orb,
		"battle_feedback_state": feedback,
		"game_audio": audio,
	}

	_expect(controller.apply_regeneration_potion(FakeOwner.new(), registry), "controller should apply regeneration potion")
	_expect(smasher_skill.reset_cooldowns_calls == 1, "controller should delegate Smasher cooldown reset")
	_expect(viper_skill.reset_cooldowns_calls == 1, "controller should delegate Viper cooldown reset")
	_expect(drive_input.reset_cooldowns_calls == 1, "controller should delegate drive input cooldown reset")
	_expect(orb.reset_values == [4], "controller should delegate dash HUD token sync")
	_expect(feedback.gauge_flashes == 1, "controller should preserve regeneration gauge flash")
	_expect(feedback.dash_flashes == 1, "controller should preserve regeneration dash flash")
	_expect(feedback.shakes == [Vector2(0.04, 1.25)], "controller should preserve regeneration shake")
	_expect(audio.calls == ["play_drink", "play_active_item"], "controller should preserve regeneration audio cues")
	_expect(controller.regeneration_potion_rings.size() == 1, "controller should still spawn regeneration ring")
	_expect(controller.regeneration_potion_particles.size() == 12, "controller should still spawn regeneration particles")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
