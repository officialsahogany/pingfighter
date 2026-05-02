extends RefCounted

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallRoundEffectCleanup := preload("res://scripts/ball/ball_round_effect_cleanup.gd")

var actor_cleanup: Object = BallRoundActorCleanup.new()
var effect_cleanup: Object = BallRoundEffectCleanup.new()


func reset_for_ball_reset(deps: Dictionary) -> void:
	reset_power_and_drive(deps)
	reset_combo(deps)
	effect_cleanup.clear_ball_effects(deps, true)
	effect_cleanup.clear_impact_effects(deps)
	effect_cleanup.clear_ball_renderer(deps)
	effect_cleanup.reset_ball_rally(deps)
	actor_cleanup.reset_round_wait(deps)
	actor_cleanup.reset_actor_round_state(deps)


func reset_for_serve(deps: Dictionary) -> void:
	reset_power_and_drive(deps)
	reset_combo_effects(deps)
	effect_cleanup.clear_ball_effects(deps, true)
	effect_cleanup.clear_impact_effects(deps)
	effect_cleanup.clear_ball_renderer(deps)


func reset_power_and_drive(deps: Dictionary) -> void:
	var power_state = deps.get("power_state", null)
	if power_state != null:
		power_state.reset()

	var drive_input_state = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.reset()


func reset_combo(deps: Dictionary) -> void:
	var combo_state = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.reset_combo()
		combo_state.clear_effects()


func reset_combo_effects(deps: Dictionary) -> void:
	var combo_state = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.clear_effects()
