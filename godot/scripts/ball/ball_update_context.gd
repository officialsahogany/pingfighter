extends RefCounted

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallUpdateOwnerSnapshot := preload("res://scripts/ball/ball_update_owner_snapshot.gd")
const BallUpdateStaticConfig := preload("res://scripts/ball/ball_update_static_config.gd")

const MYTHIC_BOSS_PADDLE_SCALE := 1.15

var dependency_context: Object = BallDependencyContext.new()
var owner_snapshot: Object = BallUpdateOwnerSnapshot.new()
var static_config: Object = BallUpdateStaticConfig.new()


func build_update_context(owner: Object) -> Dictionary:
	var update_context: Dictionary = owner_snapshot.build(owner)
	var static_update_context: Dictionary = static_config.build_update_config()
	_apply_player_paddle_owner_state(static_update_context, owner)
	_apply_boss_paddle_owner_state(static_update_context, owner)
	for key in static_update_context:
		update_context[key] = static_update_context[key]
	_apply_league_speed_policy(update_context)
	_apply_weather_speed_policy(update_context)
	_apply_rally_speed_cap_bonus(update_context)
	_apply_commando_suicide_drone_speed_policy(update_context)
	return update_context


func build_update_deps(registry, runtime_context: Dictionary = {}) -> Dictionary:
	return dependency_context.build_update_deps(registry, runtime_context)


func build_round_deps(registry, runtime_context: Dictionary = {}) -> Dictionary:
	return dependency_context.build_round_deps(registry, runtime_context)


func build_reset_config(owner: Object) -> Dictionary:
	var player_pos: Vector2 = owner_snapshot.get_owner_vector2(owner, "player_pos", Vector2.ZERO)
	var config: Dictionary = static_config.build_reset_config(
		player_pos,
		owner_snapshot.get_owner_vector2(owner, "boss_pos", Vector2.ZERO)
	)
	if player_pos != Vector2.ZERO:
		config["player_y"] = player_pos.y
	config["player_paddle_width"] = max(1.0, float(owner_snapshot.get_owner_value(
		owner,
		"player_paddle_width",
		config.get("player_paddle_width", 155.0)
	)))
	config["player_paddle_height"] = max(1.0, float(owner_snapshot.get_owner_value(
		owner,
		"player_paddle_height",
		config.get("player_paddle_height", 50.0)
	)))
	config["boss_paddle_width"] = _get_boss_paddle_width(owner, float(config.get("boss_paddle_width", 100.0)))
	return config


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
	config["boss_paddle_width"] = _get_boss_paddle_width(owner, float(config.get("boss_paddle_width", 100.0)))
	config["boss_hitbox_height"] = max(1.0, float(owner_snapshot.get_owner_value(
		owner,
		"boss_hitbox_height",
		config.get("boss_hitbox_height", 40.0)
	)))
	config["ball_visual_type"] = str(owner_snapshot.get_owner_value(owner, "ball_visual_type", "energy"))
	return config


func _apply_player_paddle_owner_state(context: Dictionary, owner: Object) -> void:
	var default_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
	var paddle_width: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "player_paddle_width", default_size.x)))
	var paddle_height: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "player_paddle_height", default_size.y)))
	context["player_paddle_size"] = Vector2(paddle_width, paddle_height)
	context["paddle_width"] = paddle_width
	context["gauge_max"] = max(1.0, float(owner_snapshot.get_owner_value(owner, "special_gauge_max", context.get("gauge_max", 500.0))))
	var player_pos: Vector2 = owner_snapshot.get_owner_vector2(
		owner,
		"player_pos",
		Vector2(0.0, float(context.get("player_y", 700.0)))
	)
	context["player_y"] = player_pos.y


func _apply_boss_paddle_owner_state(context: Dictionary, owner: Object) -> void:
	var default_size: Vector2 = context.get("boss_paddle_size", Vector2(100.0, 40.0))
	var boss_width: float = _get_boss_paddle_width(owner, default_size.x)
	var boss_height: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "boss_hitbox_height", default_size.y)))
	context["boss_paddle_size"] = Vector2(boss_width, boss_height)
	context["boss_paddle_width"] = boss_width
	context["boss_hitbox_height"] = boss_height


func _get_boss_paddle_width(owner: Object, fallback_width: float) -> float:
	var ai_mode: String = _normalize_league_mode(str(owner_snapshot.get_owner_value(owner, "ai_mode", "champion")))
	var league_width: float = max(1.0, fallback_width) * (MYTHIC_BOSS_PADDLE_SCALE if ai_mode == "mythic" else 1.0)
	var owner_width: float = max(1.0, float(owner_snapshot.get_owner_value(owner, "boss_paddle_width", league_width)))
	if ai_mode == "mythic":
		return max(owner_width, league_width)
	return owner_width


func _apply_league_speed_policy(context: Dictionary) -> void:
	if _normalize_league_mode(str(context.get("ai_mode", "champion"))) != "mythic":
		return
	var mythic_speed_limit: float = float(context.get("mythic_max_ball_speed", 32.0))
	context["max_ball_speed"] = mythic_speed_limit
	context["impact_boost_max_ball_speed"] = mythic_speed_limit
	context["speed_limit_disabled"] = false


func _apply_weather_speed_policy(context: Dictionary) -> void:
	if _is_fire_weather_active(context):
		var fire_speed_limit: float = float(context.get("fire_weather_max_ball_speed", 35.0))
		context["max_ball_speed"] = fire_speed_limit
		context["impact_boost_max_ball_speed"] = fire_speed_limit
		context["fire_weather_speed_cap_active"] = true
		context["speed_limit_disabled"] = false


func _apply_rally_speed_cap_bonus(context: Dictionary) -> void:
	var bonus: float = max(0.0, float(context.get("rally_speed_cap_bonus", 0.0)))
	if bonus <= 0.0:
		return
	context["max_ball_speed"] = float(context.get("max_ball_speed", 26.0)) + bonus
	context["impact_boost_max_ball_speed"] = float(context.get("impact_boost_max_ball_speed", 26.0)) + bonus
	if bool(context.get("fire_weather_speed_cap_active", false)):
		context["fire_weather_max_ball_speed"] = float(context.get("fire_weather_max_ball_speed", 35.0)) + bonus


func _apply_commando_suicide_drone_speed_policy(context: Dictionary) -> void:
	var active: bool = bool(context.get("commando_suicide_drone_ball_boost_active", false))
	context["commando_suicide_drone_speed_limit_disabled"] = active
	if active:
		context["speed_limit_disabled"] = true


func _is_fire_weather_active(context: Dictionary) -> bool:
	return bool(context.get("weather_active", false)) and str(context.get("weather_type", "")) == "fire"


func _normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"
