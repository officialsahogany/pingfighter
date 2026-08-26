extends RefCounted

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallRoundEffectCleanup := preload("res://scripts/ball/ball_round_effect_cleanup.gd")

var actor_cleanup: Object = BallRoundActorCleanup.new()
var effect_cleanup: Object = BallRoundEffectCleanup.new()


func reset_for_ball_reset(deps: Dictionary) -> void:
	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	reset_wall_bounce_guard(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.wall_bounce", sample_start)
	sample_start = _perf_begin(perf_logger)
	reset_power_and_drive(deps, true)
	_perf_end(perf_logger, "process.reset_ball.cleanup.power_drive", sample_start)
	sample_start = _perf_begin(perf_logger)
	reset_combo(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.combo", sample_start)
	sample_start = _perf_begin(perf_logger)
	effect_cleanup.clear_ball_effects(deps, true)
	_perf_end(perf_logger, "process.reset_ball.cleanup.ball_effects", sample_start)
	sample_start = _perf_begin(perf_logger)
	effect_cleanup.clear_impact_effects(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.impact_effects", sample_start)
	sample_start = _perf_begin(perf_logger)
	effect_cleanup.clear_ball_renderer(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.ball_renderer", sample_start)
	sample_start = _perf_begin(perf_logger)
	effect_cleanup.reset_ball_rally(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.rally", sample_start)
	sample_start = _perf_begin(perf_logger)
	actor_cleanup.reset_round_wait(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.round_wait", sample_start)
	sample_start = _perf_begin(perf_logger)
	actor_cleanup.reset_actor_round_state(deps)
	_perf_end(perf_logger, "process.reset_ball.cleanup.actor_round", sample_start)


func reset_for_serve(deps: Dictionary) -> void:
	reset_power_and_drive(deps, false)
	_clear_yangui_hoechun_for_serve(deps)
	reset_combo_effects(deps)
	effect_cleanup.clear_ball_effects(deps, true)
	effect_cleanup.clear_impact_effects(deps)
	effect_cleanup.clear_ball_renderer(deps)


func _clear_yangui_hoechun_for_serve(deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null:
		return
	var yangui_runtime: Object = mythic_item_runtime.get("yangui_hoechun_runtime")
	if yangui_runtime != null and yangui_runtime.has_method("clear_runtime"):
		yangui_runtime.clear_runtime()


func reset_wall_bounce_guard(deps: Dictionary) -> void:
	var wall_bounce_controller = deps.get("wall_bounce_controller", null)
	if wall_bounce_controller != null and wall_bounce_controller.has_method("reset_round"):
		wall_bounce_controller.reset_round()


func reset_power_and_drive(deps: Dictionary, reset_mythic: bool = true) -> void:
	var dalji_vision_state: Object = deps.get("dalji_vision_chosik_state", null)
	if dalji_vision_state != null and dalji_vision_state.has_method("reset_round"):
		dalji_vision_state.reset_round()
	var gaksital_vision_state: Object = deps.get("gaksital_vision_chosik_state", null)
	if gaksital_vision_state != null and gaksital_vision_state.has_method("reset_round"):
		gaksital_vision_state.reset_round()
	var cheongringwi_vision_state: Object = deps.get("cheongringwi_vision_chosik_state", null)
	if cheongringwi_vision_state != null and cheongringwi_vision_state.has_method("reset_round"):
		cheongringwi_vision_state.reset_round()
	var yeonmyo_vision_state: Object = deps.get("yeonmyo_vision_chosik_state", null)
	if yeonmyo_vision_state != null and yeonmyo_vision_state.has_method("reset_round"):
		yeonmyo_vision_state.reset_round(deps)

	var power_state = deps.get("power_state", null)
	if power_state != null:
		power_state.reset()

	var drive_input_state = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.reset()

	var magnum_state = deps.get("smasher_magnum_grip_state", null)
	if magnum_state != null and magnum_state.has_method("reset_round"):
		magnum_state.reset_round()

	var recovery_state = deps.get("smasher_recovery_state", null)
	if recovery_state != null and recovery_state.has_method("reset_round"):
		recovery_state.reset_round()

	var cleanse_state = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("reset_round"):
		cleanse_state.reset_round()

	var status_effect_state = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("reset_round"):
		status_effect_state.reset_round()

	var warp_gate_state = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state != null and warp_gate_state.has_method("reset_round"):
		warp_gate_state.reset_round()
		var audio = deps.get("audio", null)
		if audio != null and audio.has_method("stop_warp_gate_loop"):
			audio.stop_warp_gate_loop()

	var wheel_state = deps.get("smasher_wheel_state", null)
	if wheel_state != null and wheel_state.has_method("reset_round"):
		wheel_state.reset_round()

	var overdrive_state = deps.get("smasher_overdrive_state", null)
	if overdrive_state != null and overdrive_state.has_method("reset_round"):
		overdrive_state.reset_round()

	var void_phantom_state = deps.get("smasher_void_phantom_state", null)
	if void_phantom_state != null and void_phantom_state.has_method("reset_round"):
		void_phantom_state.reset_round()

	var dash_spirit_state = deps.get("smasher_dash_spirit_state", null)
	if dash_spirit_state != null and dash_spirit_state.has_method("reset_round"):
		dash_spirit_state.reset_round()

	var shield_kiting_state = deps.get("smasher_shield_kiting_state", null)
	if shield_kiting_state != null and shield_kiting_state.has_method("reset_round"):
		shield_kiting_state.reset_round(deps)

	var blacksmith_shield_state = deps.get("blacksmith_thor_shield_state", null)
	if blacksmith_shield_state != null and blacksmith_shield_state.has_method("reset_round"):
		blacksmith_shield_state.reset_round(deps)

	var mythic_item_runtime = deps.get("mythic_item_runtime", null)
	if reset_mythic and mythic_item_runtime != null and mythic_item_runtime.has_method("reset_round"):
		mythic_item_runtime.reset_round(deps.get("registry", null))


func reset_combo(deps: Dictionary) -> void:
	var combo_state = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.reset_combo()
		combo_state.clear_effects()


func reset_combo_effects(deps: Dictionary) -> void:
	var combo_state = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.clear_effects()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
