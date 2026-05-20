extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")
const ActiveItemRegenerationPotionActions := preload("res://scripts/items/active_item_regeneration_potion_actions.gd")
const ActiveItemRegenerationPotionEffect := preload("res://scripts/items/active_item_regeneration_potion_effect.gd")

var _failures: Array[String] = []


class FakeCooldownState:
	extends RefCounted

	var reset_cooldowns_calls := 0

	func reset_cooldowns() -> void:
		reset_cooldowns_calls += 1


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
	_verify_direct_regeneration_actions()
	_verify_controller_delegates_regeneration_actions()

	if _failures.is_empty():
		print("active_item_regeneration_potion_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_regeneration_actions() -> void:
	seed(404)
	var actions: Object = ActiveItemRegenerationPotionActions.new()
	var reader: Object = ActiveItemPlayerCenterReader.new()
	var effect: Object = ActiveItemRegenerationPotionEffect.new()
	var feedback_helper: Object = ActiveItemEffectFeedback.new()
	var particles: Array[Dictionary] = []
	var rings: Array[Dictionary] = []
	var registry := _build_registry()
	var owner := FakeOwner.new()

	_expect(actions.apply(owner, registry, particles, rings, reader, effect, feedback_helper), "Regeneration Potion actions should apply")
	_expect(registry.instances.get("smasher_skill_state").reset_cooldowns_calls == 1, "actions should reset Smasher cooldowns")
	_expect(registry.instances.get("viper_skill_state").reset_cooldowns_calls == 1, "actions should reset Viper cooldowns")
	_expect(registry.instances.get("smasher_drive_input_state").reset_cooldowns_calls == 1, "actions should reset drive input cooldowns")
	_expect(registry.instances.get("smasher_dash_state").refill_calls == 1, "actions should refill dash tokens")
	_expect(registry.instances.get("orb_hud_state").reset_values == [4], "actions should sync orb HUD dash tokens")
	_expect(registry.instances.get("battle_feedback_state").gauge_flashes == 1, "actions should trigger gauge flash")
	_expect(registry.instances.get("battle_feedback_state").dash_flashes == 1, "actions should trigger dash flash")
	_expect(registry.instances.get("battle_feedback_state").shakes == [Vector2(0.04, 1.25)], "actions should trigger reference shake")
	_expect(registry.instances.get("game_audio").calls == ["play_drink", "play_active_item"], "actions should play regeneration audio cues")
	_expect(rings.size() == 1, "actions should spawn regeneration ring")
	_expect(particles.size() == 12, "actions should spawn regeneration particles")
	_expect(rings[0].get("position", Vector2.ZERO) == Vector2(160.0, 618.0), "actions should preserve regeneration effect anchor")


func _verify_controller_delegates_regeneration_actions() -> void:
	seed(405)
	var controller: Object = ActiveItemEffectController.new()
	var registry := _build_registry()

	_expect(controller.apply_regeneration_potion(FakeOwner.new(), registry), "controller should delegate regeneration actions")
	_expect(registry.instances.get("smasher_skill_state").reset_cooldowns_calls == 1, "controller should reset Smasher cooldowns through actions")
	_expect(registry.instances.get("viper_skill_state").reset_cooldowns_calls == 1, "controller should reset Viper cooldowns through actions")
	_expect(registry.instances.get("smasher_drive_input_state").reset_cooldowns_calls == 1, "controller should reset drive input cooldowns through actions")
	_expect(registry.instances.get("orb_hud_state").reset_values == [4], "controller should sync dash HUD tokens through actions")
	_expect(registry.instances.get("battle_feedback_state").gauge_flashes == 1, "controller should preserve regeneration gauge flash")
	_expect(registry.instances.get("battle_feedback_state").dash_flashes == 1, "controller should preserve regeneration dash flash")
	_expect(registry.instances.get("battle_feedback_state").shakes == [Vector2(0.04, 1.25)], "controller should preserve regeneration shake")
	_expect(registry.instances.get("game_audio").calls == ["play_drink", "play_active_item"], "controller should preserve regeneration audio cues")
	_expect(controller.regeneration_potion_rings.size() == 1, "controller should spawn regeneration ring through actions")
	_expect(controller.regeneration_potion_particles.size() == 12, "controller should spawn regeneration particles through actions")
	_expect(controller.regeneration_potion_rings[0].get("position", Vector2.ZERO) == Vector2(160.0, 618.0), "controller should preserve regeneration anchor through actions")


func _build_registry() -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"smasher_skill_state": FakeCooldownState.new(),
		"viper_skill_state": FakeCooldownState.new(),
		"smasher_drive_input_state": FakeCooldownState.new(),
		"smasher_dash_state": FakeDashState.new(),
		"orb_hud_state": FakeOrbHud.new(),
		"battle_feedback_state": FakeFeedback.new(),
		"game_audio": FakeAudio.new(),
	}
	return registry


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
