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
	_apply_player_paddle_owner_state(static_update_context, owner)
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
	config["player_paddle_width"] = max(1.0, float(owner_snapshot.get_owner_value(
		owner,
		"player_paddle_width",
		config.get("player_paddle_width", 155.0)
	)))
	config["ball_visual_type"] = str(owner_snapshot.get_owner_value(owner, "ball_visual_type", "energy"))
	return config


func _apply_player_paddle_owner_state(context: Dictionary, owner: Object) -> void:
	var default_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
	var paddle_width: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "player_paddle_width", default_size.x)))
	var paddle_height: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "player_paddle_height", default_size.y)))
	context["player_paddle_size"] = Vector2(paddle_width, paddle_height)
	context["paddle_width"] = paddle_width
