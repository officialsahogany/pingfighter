extends RefCounted


func reset_to_egg_wait(context: Dictionary) -> Dictionary:
	var owner: Object = context.get("owner", null) as Object
	var registry: Object = context.get("registry", null) as Object
	var egg_state: Object = context.get("egg_state", null) as Object
	if egg_state != null:
		egg_state.spawn(owner)
	var position_surface: Dictionary = reset_companion_position(
		context.get("companion_motion_state", null) as Object,
		context.get("companion_distance_roll_state", null) as Object
	)
	reset_state(
		bool(context.get("reset_defense", true)),
		context.get("companion_sprite_animator", null) as Object,
		context.get("companion_distance_roll_state", null) as Object,
		context.get("companion_body_hit_state", null) as Object,
		context.get("afterglow_leak_state", null) as Object,
		context.get("ring_dash_state", null) as Object,
		context.get("ring_dash_vfx", null) as Object,
		context.get("ghost_blink_vfx", null) as Object,
		context.get("starlight_tracking_state", null) as Object,
		context.get("feed_controller", null) as Object,
		context.get("companion_skill_persistence", null) as Object,
		context.get("companion_skill_states", []) as Array,
		context.get("companion_motion_state", null) as Object,
		context.get("skill_runtime_host", null) as Object,
		owner,
		registry
	)
	var acquire_cutin_state: Object = context.get("acquire_cutin_state", null) as Object
	if acquire_cutin_state != null:
		acquire_cutin_state.reset()
	var switch_transition_state: Object = context.get("switch_transition_state", null) as Object
	if switch_transition_state != null:
		switch_transition_state.reset()
	if bool(context.get("reset_none_owner_sync", false)):
		var none_owner_sync_state: Object = context.get("none_owner_sync_state", null) as Object
		if none_owner_sync_state != null:
			none_owner_sync_state.reset()
	var current_visual_prewarm_coordinator: Object = context.get("current_visual_prewarm_coordinator", null) as Object
	if current_visual_prewarm_coordinator != null:
		current_visual_prewarm_coordinator.prewarm_current(
			context.get("current_profile", null) as Object,
			context.get("companion_renderer", null) as Object,
			str(context.get("state", "")),
			str(context.get("companion_state", "")),
			str(context.get("pet_id", "")),
			context.get("companion_click_reaction_visual_prewarm_state", null) as Object
		)
	return position_surface


func reset_to_none(context: Dictionary) -> Dictionary:
	var owner: Object = context.get("owner", null) as Object
	var registry: Object = context.get("registry", null) as Object
	var egg_state: Object = context.get("egg_state", null) as Object
	if egg_state != null and egg_state.has_method("reset_all"):
		egg_state.reset_all()
	var acquire_cutin_state: Object = context.get("acquire_cutin_state", null) as Object
	var item_egg_lifecycle_state: Object = context.get("item_egg_lifecycle_state", null) as Object
	if item_egg_lifecycle_state != null and item_egg_lifecycle_state.has_method("clear_runtime_state"):
		item_egg_lifecycle_state.clear_runtime_state(
			context.get("item_egg_state", null) as Object,
			context.get("item_egg_absorb_vfx", null) as Object,
			acquire_cutin_state
		)
	var position_surface: Dictionary = reset_companion_position(
		context.get("companion_motion_state", null) as Object,
		context.get("companion_distance_roll_state", null) as Object
	)
	reset_state(
		bool(context.get("reset_defense", true)),
		context.get("companion_sprite_animator", null) as Object,
		context.get("companion_distance_roll_state", null) as Object,
		context.get("companion_body_hit_state", null) as Object,
		context.get("afterglow_leak_state", null) as Object,
		context.get("ring_dash_state", null) as Object,
		context.get("ring_dash_vfx", null) as Object,
		context.get("ghost_blink_vfx", null) as Object,
		context.get("starlight_tracking_state", null) as Object,
		context.get("feed_controller", null) as Object,
		context.get("companion_skill_persistence", null) as Object,
		context.get("companion_skill_states", []) as Array,
		context.get("companion_motion_state", null) as Object,
		context.get("skill_runtime_host", null) as Object,
		owner,
		registry
	)
	if acquire_cutin_state != null:
		acquire_cutin_state.reset()
	var switch_transition_state: Object = context.get("switch_transition_state", null) as Object
	if switch_transition_state != null:
		switch_transition_state.reset()
	var current_visual_prewarm_coordinator: Object = context.get("current_visual_prewarm_coordinator", null) as Object
	if current_visual_prewarm_coordinator != null:
		current_visual_prewarm_coordinator.prewarm_current(
			context.get("current_profile", null) as Object,
			context.get("companion_renderer", null) as Object,
			str(context.get("state", "")),
			str(context.get("companion_state", "")),
			str(context.get("pet_id", "")),
			context.get("companion_click_reaction_visual_prewarm_state", null) as Object
		)
	return position_surface


func clear_field_state(context: Dictionary) -> Dictionary:
	var egg_state: Object = context.get("egg_state", null) as Object
	if egg_state != null and egg_state.has_method("reset_all"):
		egg_state.reset_all()
	var position_surface: Dictionary = reset_companion_position(
		context.get("companion_motion_state", null) as Object,
		context.get("companion_distance_roll_state", null) as Object
	)
	var afterglow_leak_state: Object = context.get("afterglow_leak_state", null) as Object
	if afterglow_leak_state != null:
		afterglow_leak_state.reset_all()
	var ring_dash_state: Object = context.get("ring_dash_state", null) as Object
	if ring_dash_state != null:
		ring_dash_state.reset_all()
	var ring_dash_vfx: Object = context.get("ring_dash_vfx", null) as Object
	if ring_dash_vfx != null:
		ring_dash_vfx.reset()
	var ghost_blink_vfx: Object = context.get("ghost_blink_vfx", null) as Object
	if ghost_blink_vfx != null:
		ghost_blink_vfx.reset()
	var starlight_tracking_state: Object = context.get("starlight_tracking_state", null) as Object
	if starlight_tracking_state != null:
		starlight_tracking_state.reset_all()
	var feed_controller: Object = context.get("feed_controller", null) as Object
	if feed_controller != null:
		feed_controller.reset_all()
	var overflow_choice_state: Object = context.get("overflow_choice_state", null) as Object
	if overflow_choice_state != null:
		overflow_choice_state.reset()
	var item_egg_lifecycle_state: Object = context.get("item_egg_lifecycle_state", null) as Object
	if item_egg_lifecycle_state != null and item_egg_lifecycle_state.has_method("clear_runtime_state"):
		item_egg_lifecycle_state.clear_runtime_state(
			context.get("item_egg_state", null) as Object,
			context.get("item_egg_absorb_vfx", null) as Object,
			context.get("acquire_cutin_state", null) as Object
		)
	return position_surface


func reset_companion_position(
	companion_motion_state: Object,
	companion_distance_roll_state: Object
) -> Dictionary:
	if companion_motion_state != null:
		companion_motion_state.reset()
	if companion_distance_roll_state != null:
		companion_distance_roll_state.reset()
	return {
		"companion_pos": Vector2.ZERO,
		"companion_facing_left": false,
	}


func prepare_hatch_position(egg_state: Object) -> Dictionary:
	var companion_pos := Vector2.ZERO
	if egg_state != null:
		var raw_pos: Variant = egg_state.get("pos")
		if raw_pos is Vector2:
			companion_pos = raw_pos
		if egg_state.has_method("reset_contact_motion"):
			egg_state.reset_contact_motion()
	return {"companion_pos": companion_pos}


func start_hatch_reveal_effects(context: Dictionary) -> void:
	var perf_logger: Object = context.get("perf_logger", null) as Object
	var perf_label_prefix := str(context.get("perf_label_prefix", ""))
	var perf_start := 0
	var switch_transition_state: Object = context.get("switch_transition_state", null) as Object
	if switch_transition_state != null:
		perf_start = _perf_begin(perf_logger)
		switch_transition_state.reset()
		_perf_end_with_prefix(perf_logger, perf_label_prefix, "switch_reset", perf_start)
	var egg_state: Object = context.get("egg_state", null) as Object
	if egg_state != null and egg_state.has_method("trigger_hatch_flash"):
		perf_start = _perf_begin(perf_logger)
		egg_state.trigger_hatch_flash(float(context.get("hatch_flash_seconds", 0.0)))
		_perf_end_with_prefix(perf_logger, perf_label_prefix, "hatch_flash", perf_start)
	var acquire_cutin_state: Object = context.get("acquire_cutin_state", null) as Object
	if bool(context.get("start_acquire_cutin", false)) and acquire_cutin_state != null:
		perf_start = _perf_begin(perf_logger)
		acquire_cutin_state.start()
		_perf_end_with_prefix(perf_logger, perf_label_prefix, "begin", perf_start)
		if bool(context.get("play_acquire_cutin_audio", false)):
			var audio_dispatcher: Object = context.get("audio_dispatcher", null) as Object
			if audio_dispatcher != null and audio_dispatcher.has_method("play_lingpet_acquire_cutin"):
				perf_start = _perf_begin(perf_logger)
				audio_dispatcher.play_lingpet_acquire_cutin(context.get("registry", null) as Object)
				_perf_end_with_prefix(perf_logger, perf_label_prefix, "audio", perf_start)
	var current_visual_prewarm_coordinator: Object = context.get("current_visual_prewarm_coordinator", null) as Object
	if current_visual_prewarm_coordinator != null:
		perf_start = _perf_begin(perf_logger)
		current_visual_prewarm_coordinator.prewarm_current(
			context.get("current_profile", null) as Object,
			context.get("companion_renderer", null) as Object,
			str(context.get("state", "")),
			str(context.get("companion_state", "")),
			str(context.get("pet_id", "")),
			context.get("companion_click_reaction_visual_prewarm_state", null) as Object
		)
		_perf_end_with_prefix(perf_logger, perf_label_prefix, "companion_sheet", perf_start)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end_with_prefix(perf_logger: Object, label_prefix: String, label_suffix: String, start_usec: int) -> void:
	if label_prefix == "":
		return
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample("%s.%s" % [label_prefix, label_suffix], start_usec)


func prepare_companion_activation(context: Dictionary) -> Dictionary:
	var owner: Object = context.get("owner", null) as Object
	var registry: Object = context.get("registry", null) as Object
	var egg_state: Object = context.get("egg_state", null) as Object
	if bool(context.get("set_egg_hatched", false)) and egg_state != null and egg_state.has_method("set_hatched"):
		egg_state.set_hatched(maxi(0, int(context.get("required_hits", 0))))
	var position_surface: Dictionary = {}
	if bool(context.get("reset_position", false)):
		position_surface = reset_companion_position(
			context.get("companion_motion_state", null) as Object,
			context.get("companion_distance_roll_state", null) as Object
		)
	reset_state(
		bool(context.get("reset_defense", true)),
		context.get("companion_sprite_animator", null) as Object,
		context.get("companion_distance_roll_state", null) as Object,
		context.get("companion_body_hit_state", null) as Object,
		context.get("afterglow_leak_state", null) as Object,
		context.get("ring_dash_state", null) as Object,
		context.get("ring_dash_vfx", null) as Object,
		context.get("ghost_blink_vfx", null) as Object,
		context.get("starlight_tracking_state", null) as Object,
		context.get("feed_controller", null) as Object,
		context.get("companion_skill_persistence", null) as Object,
		context.get("companion_skill_states", []) as Array,
		context.get("companion_motion_state", null) as Object,
		context.get("skill_runtime_host", null) as Object,
		owner,
		registry
	)
	var companion_skill_persistence: Object = context.get("companion_skill_persistence", null) as Object
	if bool(context.get("restore_current_skill_state", true)) and companion_skill_persistence != null:
		companion_skill_persistence.restore_current(
			str(context.get("pet_id", "")),
			context.get("companion_skill_states", []) as Array
		)
	if bool(context.get("reset_switch_transition", false)):
		var switch_transition_state: Object = context.get("switch_transition_state", null) as Object
		if switch_transition_state != null:
			switch_transition_state.reset()
	if bool(context.get("reset_acquire_cutin", false)):
		var acquire_cutin_state: Object = context.get("acquire_cutin_state", null) as Object
		if acquire_cutin_state != null:
			acquire_cutin_state.reset()
	var current_visual_prewarm_coordinator: Object = context.get("current_visual_prewarm_coordinator", null) as Object
	if bool(context.get("prewarm_current_visuals", true)) and current_visual_prewarm_coordinator != null:
		current_visual_prewarm_coordinator.prewarm_current(
			context.get("current_profile", null) as Object,
			context.get("companion_renderer", null) as Object,
			str(context.get("state", "")),
			str(context.get("companion_state", "")),
			str(context.get("pet_id", "")),
			context.get("companion_click_reaction_visual_prewarm_state", null) as Object
		)
	var collection_state: Object = context.get("collection_state", null) as Object
	if bool(context.get("ensure_active_slot", false)) and collection_state != null:
		collection_state.ensure_pet_active_slot(owner, str(context.get("pet_id", "")))
	return position_surface


func reset_state(
	reset_defense: bool,
	companion_sprite_animator: Object,
	companion_distance_roll_state: Object,
	companion_body_hit_state: Object,
	afterglow_leak_state: Object,
	ring_dash_state: Object,
	ring_dash_vfx: Object,
	ghost_blink_vfx: Object,
	starlight_tracking_state: Object,
	feed_controller: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	companion_motion_state: Object,
	skill_runtime_host: Object,
	owner: Object,
	registry: Object
) -> void:
	companion_sprite_animator.reset_all()
	companion_distance_roll_state.reset()
	companion_body_hit_state.reset_all()
	afterglow_leak_state.reset_all()
	ring_dash_state.reset_all()
	ring_dash_vfx.reset()
	ghost_blink_vfx.reset()
	starlight_tracking_state.reset_all()
	if feed_controller != null:
		feed_controller.reset_all()
	companion_skill_persistence.reset_states(companion_skill_states)
	if reset_defense:
		companion_motion_state.reset_defense()
	companion_skill_persistence.reset_runtime_transients(
		companion_skill_states,
		skill_runtime_host,
		owner,
		registry
	)
