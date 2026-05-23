extends RefCounted


func update(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	if not runtime._has_runtime_update_work():
		_update_idle(runtime, owner, registry, delta)
		return

	var update_scope: Dictionary = runtime.update_gate.build_update_scope(runtime)
	var fps_scale: float = max(0.0, delta * 60.0)
	runtime.acquisition_cinematic_runtime.update(runtime, delta, registry)
	runtime.pandora_legacy_runtime.update_selection_frames(runtime, fps_scale)
	runtime._update_ragnarok_runtime(owner, registry, delta, fps_scale)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, fps_scale)
	runtime.knee_pads_runtime.update_runtime(runtime, fps_scale)
	runtime.soul_burst_runtime.update_runtime(runtime, fps_scale)
	runtime.foul_whistle_runtime.update_runtime(runtime, fps_scale)
	runtime.revival_runtime.update_runtime(runtime, fps_scale)
	runtime.auto_defense_runtime.update_sensor_runtime(runtime, fps_scale)
	runtime.venom_mist_runtime.update_runtime(runtime, owner, registry, fps_scale)
	runtime.rainbow_fur_glove_runtime.update_runtime(runtime, fps_scale)
	runtime._update_adversity_armor_runtime(owner, registry, fps_scale)
	runtime._update_shrapnel_armor_runtime(owner, registry, fps_scale)
	runtime._update_poseidon_runtime(owner, registry, fps_scale)
	runtime.celestial_armor_runtime.update_runtime(runtime, fps_scale)
	runtime.hermes_shoes_runtime.update_runtime(runtime, owner, fps_scale)
	runtime._update_baal_boots_runtime(owner, registry, fps_scale)
	runtime.horn_strawberry_mask_runtime.update(runtime, owner, registry, delta)
	runtime.update_gate.sync_after_update(runtime, owner, registry, update_scope)


func _update_idle(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	var idle_fps_scale: float = max(0.0, delta * 60.0)
	runtime._poll_idle_poseidon_dash_trigger(owner, registry)
	var previous_smartphone_item: String = str(runtime.smartphone_last_auto_item)
	var previous_smartphone_cooldown: float = float(runtime.smartphone_cooldown_frames)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, idle_fps_scale)
	if (
		previous_smartphone_item != runtime.smartphone_last_auto_item
		or not is_equal_approx(previous_smartphone_cooldown, runtime.smartphone_cooldown_frames)
	):
		runtime._sync_owner(owner, registry)
