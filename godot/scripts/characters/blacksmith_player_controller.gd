extends RefCounted

const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

const MOVEMENT_SPEED_KEYS := [
	"paddle_speed",
	"paddle_max_speed",
	"paddle_accel",
	"paddle_decel",
	"paddle_turn_decel",
]

var shared_controller: Object = SmasherPlayerController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null and input_reader.has_method("get_snapshot") else {}
	var motion_config: Dictionary = config.duplicate(true)
	if _is_active_item_control_locked(deps.get("active_item_runtime", null)) or _is_shared_player_stun_active(deps):
		motion_config["player_skill_input_locked"] = true
	var next_special_gauge: float = float(motion_config.get("special_gauge", 0.0))
	var shield_state: Object = deps.get("blacksmith_thor_shield_state", null)
	var shield_result: Dictionary = {}
	var shield_hard_rooted := false
	if shield_state != null and shield_state.has_method("update_input"):
		shield_result = shield_state.update_input(
			delta,
			input_snapshot,
			Time.get_ticks_msec(),
			next_special_gauge,
			player_pos,
			motion_config,
			deps
		)
		next_special_gauge = float(shield_result.get("special_gauge", next_special_gauge))
		if not bool(motion_config.get("horn_strawberry_transformed", false)):
			shield_hard_rooted = _apply_speed_multiplier(motion_config, shield_state)
	motion_config["special_gauge"] = next_special_gauge
	var shared_result: Dictionary = shared_controller.update(
		delta,
		frame_counter,
		player_pos,
		# A multiplier of 0 zeroes accel/max_speed/decel, but move_toward with a
		# 0 decel step PRESERVES pre-existing speed — the paddle would keep
		# sliding through the whole deploy. Zero the carried speed itself so the
		# Thor Shield deploy/retract root is an actual stop (original
		# umbrella_lock_active sets current_speed = 0).
		0.0 if shield_hard_rooted else player_speed,
		motion_config,
		deps
	)
	if shared_result.has("special_gauge"):
		shield_result["special_gauge"] = float(shared_result.get("special_gauge", next_special_gauge))
	for key in shield_result.keys():
		shared_result[str(key)] = shield_result[key]
	return shared_result


func _apply_speed_multiplier(config: Dictionary, source: Object) -> bool:
	# Returns true when the multiplier is a hard root (0) so the caller can also
	# zero the carried player_speed.
	if source == null or not source.has_method("get_player_speed_multiplier"):
		return false
	var speed_multiplier: float = max(0.0, float(source.get_player_speed_multiplier()))
	if abs(speed_multiplier - 1.0) <= 0.001:
		return false
	for key in MOVEMENT_SPEED_KEYS:
		if config.has(key):
			config[key] = float(config[key]) * speed_multiplier
	return speed_multiplier <= 0.001


func _is_active_item_control_locked(active_item_runtime: Object) -> bool:
	return (
		active_item_runtime != null
		and active_item_runtime.has_method("is_player_control_locked")
		and bool(active_item_runtime.is_player_control_locked())
	)


func _is_shared_player_stun_active(deps: Dictionary) -> bool:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null:
		return false
	if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
		return true
	if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
		return true
	if status_effect_state.has_method("get_player_control_context"):
		var context: Variant = status_effect_state.get_player_control_context()
		if context is Dictionary:
			return bool(context.get("player_stun_active", false)) or float(context.get("player_stun_ratio", 0.0)) > 0.0
	return false
