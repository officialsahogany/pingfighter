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
	var skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if skill_runtime != null and skill_runtime.has_method("try_activate_before_movement"):
		var skill_result: Dictionary = skill_runtime.try_activate_before_movement(
			delta,
			player_pos,
			float(viper_config.get("special_gauge", 0.0)),
			viper_config,
			deps
		)
		if bool(skill_result.get("activated", false)):
			return {
				"frame_counter": frame_counter + 1,
				"player_pos": skill_result.get("player_pos", player_pos),
				"player_speed": float(skill_result.get("player_speed", 0.0)),
				"special_gauge": float(skill_result.get("special_gauge", viper_config.get("special_gauge", 0.0))),
			}
	var result: Dictionary = shared_controller.update(delta, frame_counter, player_pos, player_speed, viper_config, deps)
	if skill_runtime != null and skill_runtime.has_method("observe_after_movement"):
		var next_pos: Variant = result.get("player_pos", player_pos)
		skill_runtime.observe_after_movement(
			delta,
			player_pos,
			next_pos if next_pos is Vector2 else player_pos,
			deps
		)
	return result
