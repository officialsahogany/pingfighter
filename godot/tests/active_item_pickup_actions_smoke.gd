extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemPickupActions := preload("res://scripts/items/active_item_pickup_actions.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_item_get() -> void:
		calls.append("play_item_get")


class FakeVisuals:
	extends RefCounted

	var calls := 0
	var texture := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))

	func get_icon_texture(_item_data: Dictionary) -> Texture2D:
		calls += 1
		return texture


class FakeRegistry:
	extends RefCounted

	var audio: Object = null
	var visuals: Object = null

	func _init(audio_state: Object = null, visual_state: Object = null) -> void:
		audio = audio_state
		visuals = visual_state

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "active_item_hud_visuals":
			return visuals
		return null


func _init() -> void:
	_verify_direct_pickup_actions()
	_verify_controller_delegates_pickup_actions()

	if _failures.is_empty():
		print("active_item_pickup_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pickup_actions() -> void:
	seed(808)
	var actions: Object = ActiveItemPickupActions.new()
	var controller: Object = ActiveItemEffectController.new()
	var audio := FakeAudio.new()
	var visuals := FakeVisuals.new()
	var field_item := {
		"item_data": {"id": "energy_drink", "icon_path": "res://fake/energy_drink.png"},
		"position": Vector2(320.0, 420.0),
	}

	actions.trigger(
		controller,
		field_item,
		"Energy Drink",
		Color.CYAN,
		FakeRegistry.new(audio, visuals),
		controller.pickup_particles,
		ActiveItemPickupEffectState.new(),
		ActiveItemEffectFeedback.new()
	)

	_expect(controller.has_pickup_effect(), "Pickup actions should activate pickup effect")
	_expect(controller.pickup_effect.get("display_name", "") == "Energy Drink", "Pickup actions should preserve display name")
	_expect(controller.pickup_effect.get("position", Vector2.ZERO) == Vector2(320.0, 420.0), "Pickup actions should preserve pickup start position")
	_expect(controller.pickup_particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "Pickup actions should spawn capped balloon pop particles")
	_expect(controller.pickup_effect.get("icon_texture", null) == visuals.texture, "Pickup actions should freeze icon texture for draw")
	_expect(visuals.calls == 1, "Pickup actions should resolve the pickup icon once")
	_expect(audio.calls == ["play_item_get"], "Pickup actions should play item-get audio")


func _verify_controller_delegates_pickup_actions() -> void:
	seed(809)
	var controller: Object = ActiveItemEffectController.new()
	var audio := FakeAudio.new()
	var field_item := {
		"item_data": {"id": "magnet_field"},
		"position": Vector2(240.0, 300.0),
	}

	controller.trigger_pickup_effect(field_item, "Magnet Field", Color.BLUE, FakeRegistry.new(audio))

	_expect(controller.has_pickup_effect(), "controller should delegate pickup effect activation")
	_expect(controller.pickup_effect.get("display_name", "") == "Magnet Field", "controller delegated pickup should preserve display name")
	_expect(controller.pickup_particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "controller delegated pickup should spawn capped particles")
	_expect(audio.calls == ["play_item_get"], "controller delegated pickup should preserve item-get audio")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
