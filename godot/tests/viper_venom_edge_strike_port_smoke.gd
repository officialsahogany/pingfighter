extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


func _init() -> void:
	var runtime: Object = ViperSkillRuntime.new()

	var initial_context: Dictionary = runtime.get_actor_draw_context()
	_expect(not bool(initial_context.get("viper_venom_edge_strike_active", false)), "venom edge strike should start inactive")
	_expect(int(initial_context.get("viper_venom_edge_strike_frame", -1)) == 0, "venom edge strike frame should be 0 when inactive")

	runtime.trigger_venom_edge_strike()
	var after_trigger: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(after_trigger.get("viper_venom_edge_strike_active", false)), "trigger_venom_edge_strike() should activate the strike state")
	_expect(int(after_trigger.get("viper_venom_edge_strike_frame", -1)) == 0, "venom edge strike frame should start at cell 0 right after trigger")

	# Advance ~half the strike duration (18 game frames at 60fps); cell index
	# should land on 4 (the X-cut peak frame).
	for i in range(18):
		runtime.update_effects(1.0, i, {}, {})
	var mid_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(mid_context.get("viper_venom_edge_strike_active", false)), "strike should still be active mid-animation")
	var mid_frame: int = int(mid_context.get("viper_venom_edge_strike_frame", -1))
	_expect(mid_frame == 4, "venom edge strike frame should land on cell 4 (X-cut peak) at mid-animation, got %d" % mid_frame)

	# Advance past total duration (36 frames); strike should auto-clear.
	for i in range(20):
		runtime.update_effects(1.0, 100 + i, {}, {})
	var done_context: Dictionary = runtime.get_actor_draw_context()
	_expect(not bool(done_context.get("viper_venom_edge_strike_active", false)), "strike should auto-clear after VENOM_EDGE_STRIKE_TOTAL_FRAMES game frames")
	_expect(int(done_context.get("viper_venom_edge_strike_frame", -1)) == 0, "venom edge strike frame should reset to 0 after auto-clear")

	# Re-trigger after clear should work cleanly.
	runtime.trigger_venom_edge_strike()
	var retrigger_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(retrigger_context.get("viper_venom_edge_strike_active", false)), "re-triggering after auto-clear should re-activate the strike")

	# reset_round must clear the strike state cleanly.
	runtime.reset_round({})
	var reset_context: Dictionary = runtime.get_actor_draw_context()
	_expect(not bool(reset_context.get("viper_venom_edge_strike_active", false)), "reset_round() should clear venom edge strike state")

	# Stationary state — independent of strike, held until end_venom_edge_stationary().
	_expect(not bool(reset_context.get("viper_venom_edge_stationary_active", false)), "venom edge stationary should default to inactive")
	runtime.start_venom_edge_stationary()
	var stationary_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(stationary_context.get("viper_venom_edge_stationary_active", false)), "start_venom_edge_stationary() should activate the stationary state")
	# Stationary should NOT auto-clear from update_effects (it's held indefinitely).
	for i in range(VIPER_AUTO_CLEAR_GUARD_FRAMES):
		runtime.update_effects(1.0, 200 + i, {}, {})
	var still_stationary: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(still_stationary.get("viper_venom_edge_stationary_active", false)), "stationary state must persist across update_effects ticks")
	# end_venom_edge_stationary() clears it.
	runtime.end_venom_edge_stationary()
	var stationary_ended: Dictionary = runtime.get_actor_draw_context()
	_expect(not bool(stationary_ended.get("viper_venom_edge_stationary_active", false)), "end_venom_edge_stationary() should clear the stationary state")
	# reset_round() also clears stationary.
	runtime.start_venom_edge_stationary()
	runtime.reset_round({})
	var stationary_reset_context: Dictionary = runtime.get_actor_draw_context()
	_expect(not bool(stationary_reset_context.get("viper_venom_edge_stationary_active", false)), "reset_round() should clear venom edge stationary state")

	print("viper_venom_edge_strike_port_smoke: ok")
	quit(0)


const VIPER_AUTO_CLEAR_GUARD_FRAMES := 60


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
