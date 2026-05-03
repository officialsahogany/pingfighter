extends RefCounted

const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var shared_controller: Object = SmasherPlayerController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var viper_config: Dictionary = config.duplicate(true)
	viper_config["paddle_speed"] = float(viper_config.get("paddle_speed", 3.0))
	viper_config["paddle_max_speed"] = float(viper_config.get("paddle_max_speed", 3.0))
	viper_config["paddle_accel"] = float(viper_config.get("paddle_accel", 0.38))
	return shared_controller.update(delta, frame_counter, player_pos, player_speed, viper_config, deps)
