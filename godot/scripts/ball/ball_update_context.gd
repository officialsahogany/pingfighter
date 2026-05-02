extends RefCounted

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

var dependency_context: Object = BallDependencyContext.new()
var owner_snapshot: Object = BallUpdateOwnerSnapshot.new()
var static_config: Object = BallUpdateStaticConfig.new()


func build_update_context(owner: Object) -> Dictionary:
	var update_context: Dictionary = owner_snapshot.build(owner)
	var static_update_context: Dictionary = static_config.build_update_config()
	for key in static_update_context:
		update_context[key] = static_update_context[key]
	return update_context


func build_update_deps(registry) -> Dictionary:
	return dependency_context.build_update_deps(registry)


func build_round_deps(registry) -> Dictionary:
	return dependency_context.build_round_deps(registry)


func build_reset_config(owner: Object) -> Dictionary:
	return static_config.build_reset_config(
		owner_snapshot.get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		owner_snapshot.get_owner_vector2(owner, "boss_pos", Vector2.ZERO)
	)


func build_serve_config(owner: Object) -> Dictionary:
	var config: Dictionary = static_config.build_serve_config(
		owner_snapshot.get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		owner_snapshot.get_owner_vector2(owner, "boss_pos", Vector2.ZERO)
	)
	config["ball_visual_type"] = str(owner_snapshot.get_owner_value(owner, "ball_visual_type", "energy"))
	return config
