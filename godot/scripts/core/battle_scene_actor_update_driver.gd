extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()


func update_player_control(owner: Object, registry: Object, delta: float) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var controller: Object = _get_instance(registry, character_runtime.get_player_controller_key(character_type))
	if owner == null or controller == null or context_builder == null:
		return
	var result: Dictionary = controller.update(
		delta,
		int(_get_owner_value(owner, "gameplay_frame_counter", 0)),
		_get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		float(_get_owner_value(owner, "player_speed", 0.0)),
		_build_player_control_config(owner, context_builder, character_type),
		context_builder.build_player_control_deps(registry, character_type)
	)
	owner.set("gameplay_frame_counter", int(result.get(
		"frame_counter",
		int(_get_owner_value(owner, "gameplay_frame_counter", 0))
	)))
	var updated_pos: Variant = result.get("player_pos", _get_owner_vector2(owner, "player_pos", Vector2.ZERO))
	if updated_pos is Vector2:
		owner.set("player_pos", updated_pos)
	owner.set("player_speed", float(result.get("player_speed", _get_owner_value(owner, "player_speed", 0.0))))


func update_boss_ai(owner: Object, registry: Object, delta: float) -> void:
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if owner == null or ai_state == null:
		return
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	var context: Dictionary = context_builder.build_boss_ai_context(owner, registry) if context_builder != null else {}
	var result: Dictionary = ai_state.update(
		delta,
		_get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		float(_get_owner_value(owner, "boss_vel", 0.0)),
		context
	)
	var updated_pos: Variant = result.get("boss_pos", _get_owner_vector2(owner, "boss_pos", Vector2.ZERO))
	if updated_pos is Vector2:
		owner.set("boss_pos", updated_pos)
	owner.set("boss_vel", float(result.get("boss_vel", _get_owner_value(owner, "boss_vel", 0.0))))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_player_control_config(owner: Object, context_builder: Object, character_type: String) -> Dictionary:
	var config: Dictionary = context_builder.build_player_control_config(character_type)
	var paddle_width: float = float(_get_owner_value(owner, "player_paddle_width", config.get("paddle_width", 155.0)))
	config["paddle_width"] = max(1.0, paddle_width)
	return config


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)
