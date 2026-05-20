extends SceneTree

const EffectsFrameContextBuilder := preload("res://scripts/core/battle_update_effects_frame_context_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)


class FakeDashState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"tokens": 4,
			"max_tokens": 5,
			"active": true,
			"direction": 1.0,
		}


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		instances["smasher_dash_state"] = FakeDashState.new()
		instances["round_flow_state"] = FakeRoundState.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var texture: Texture2D = _make_texture()
	var owner := FakeOwner.new({
		"battle_textures": {
			"viper_player_sprite_texture": texture,
			"viper_player_idle_sprite_texture": texture,
		},
		"selected_character_type": "ViPeR",
		"current_stage": 2,
		"player_pos": Vector2(321.0, 654.0),
		"player_paddle_width": 145.0,
		"player_paddle_height": 44.0,
		"ball_pos": Vector2(111.0, 222.0),
		"ball_active": true,
		"special_gauge": 250.0,
	})
	var registry := FakeRegistry.new()
	var builder: Object = EffectsFrameContextBuilder.new()

	_verify_frame_context(builder.build_context(owner, registry), owner, registry, "direct builder")
	_verify_frame_context(BattleUpdateEffectsContext.new().build_context(owner, registry), owner, registry, "effects context facade")

	var default_context: Dictionary = builder.build_context(FakeOwner.new({}), null)
	_expect(str(default_context.get("selected_character_type", "")) == "smasher", "missing owner state should default to Smasher")
	_expect(int(default_context.get("dash_snapshot", {}).get("tokens", -1)) == 0, "missing registry should use default dash snapshot")

	if _failures.is_empty():
		print("effects_frame_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_frame_context(context: Dictionary, owner: Object, registry: Object, source: String) -> void:
	_expect(context.get("owner", null) == owner, "%s should keep owner reference" % source)
	_expect(context.get("registry", null) == registry, "%s should keep registry reference" % source)
	_expect(str(context.get("selected_character_type", "")) == "viper", "%s should normalize character through sprite context" % source)
	_expect(bool(context.get("player_has_sprite", false)), "%s should merge player sprite availability" % source)
	_expect(bool(context.get("player_has_idle_sprite", false)), "%s should merge player idle sprite availability" % source)
	_expect(int(context.get("player_sprite_frame_count", 0)) == 8, "%s should keep Viper sprite frame count" % source)
	_expect(int(context.get("current_stage", 0)) == 2, "%s should keep owner stage" % source)
	_expect(context.get("player_pos", Vector2.ZERO) == Vector2(321.0, 654.0), "%s should keep owner player position" % source)
	_expect(context.get("player_paddle_size", Vector2.ZERO) == Vector2(145.0, 44.0), "%s should keep owner paddle size" % source)
	_expect(context.get("ball_pos", Vector2.ZERO) == Vector2(111.0, 222.0), "%s should keep ball position" % source)
	_expect(bool(context.get("ball_active", false)), "%s should keep ball active state" % source)
	_expect(not bool(context.get("waiting_for_serve", true)), "%s should keep round wait state" % source)
	_expect(float(context.get("special_gauge", 0.0)) == 250.0, "%s should keep special gauge" % source)
	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	_expect(int(dash_snapshot.get("tokens", 0)) == 4, "%s should merge live dash tokens" % source)
	_expect(bool(dash_snapshot.get("active", false)), "%s should merge live dash active state" % source)


func _make_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
