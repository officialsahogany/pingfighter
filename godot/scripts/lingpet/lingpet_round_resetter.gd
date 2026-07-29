extends RefCounted


func reset_round(
	owner: Object,
	registry: Object,
	guardian_run_state: Object,
	guard_feedback_state: Object,
	companion_motion_state: Object,
	switch_transition_state: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	companion_body_hit_state: Object,
	afterglow_leak_state: Object,
	ring_dash_state: Object,
	ring_dash_vfx: Object,
	ghost_blink_vfx: Object,
	starlight_tracking_state: Object
) -> void:
	companion_skill_persistence.reset_runtime_transients(
		companion_skill_states,
		skill_runtime_host,
		owner,
		registry,
		true
	)
	guardian_run_state.reset_round_caps()
	guard_feedback_state.reset_round_transients()
	companion_motion_state.reset_defense()
	switch_transition_state.reset()
	companion_skill_persistence.reset_round_transients(companion_skill_states)
	companion_body_hit_state.reset_round_transients()
	afterglow_leak_state.reset_round_transients()
	ring_dash_state.reset_round_transients()
	ring_dash_vfx.reset()
	ghost_blink_vfx.reset()
	starlight_tracking_state.reset_round_transients()
