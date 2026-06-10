extends RefCounted


func update(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	ragnarok_constants: Dictionary,
	poseidon_constants: Dictionary,
	baal_boots_constants: Dictionary,
	context_constants: Dictionary
) -> void:
	if not runtime.update_gate.has_runtime_update_work(runtime):
		_update_idle(runtime, owner, registry, delta)
		return

	var update_scope: Dictionary = runtime.update_gate.build_update_scope(runtime)
	var fps_scale: float = max(0.0, delta * 60.0)
	runtime.acquisition_cinematic_runtime.update(runtime, delta, registry)
	runtime.pandora_legacy_runtime.update_selection_frames(runtime, fps_scale)
	runtime.ragnarok_runtime.update_runtime(runtime, owner, registry, delta, fps_scale, ragnarok_constants)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, fps_scale)
	runtime.knee_pads_runtime.update_runtime(runtime, fps_scale)
	runtime.soul_burst_runtime.update_runtime(runtime, fps_scale)
	runtime.foul_whistle_runtime.update_runtime(runtime, fps_scale)
	runtime.revival_runtime.update_runtime(runtime, fps_scale)
	runtime.odins_eye_runtime.update_runtime(runtime, fps_scale)
	runtime.auto_defense_runtime.update_sensor_runtime(runtime, fps_scale)
	runtime.venom_mist_runtime.update_runtime(runtime, owner, registry, fps_scale)
	runtime.rainbow_fur_glove_runtime.update_runtime(runtime, fps_scale)
	runtime.adversity_armor_runtime.update_runtime(runtime, owner, fps_scale)
	runtime.shrapnel_armor_runtime.update_runtime(runtime, owner, registry, fps_scale)
	runtime.poseidon_runtime.update_runtime(runtime, owner, registry, fps_scale, poseidon_constants)
	runtime.celestial_armor_runtime.update_runtime(runtime, fps_scale)
	runtime.hermes_shoes_runtime.update_runtime(runtime, owner, fps_scale)
	runtime.baal_boots_runtime.update_runtime(runtime, owner, registry, fps_scale, baal_boots_constants)
	runtime.horn_strawberry_mask_runtime.update(runtime, owner, registry, delta, context_constants)
	runtime.update_gate.sync_after_update(runtime, owner, registry, update_scope)


func _update_idle(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	var idle_fps_scale: float = max(0.0, delta * 60.0)
	runtime.poseidon_runtime.poll_idle_dash_trigger(runtime, owner, registry)
	var previous_smartphone_item: String = str(runtime.smartphone_last_auto_item)
	var previous_smartphone_cooldown: float = float(runtime.smartphone_cooldown_frames)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, idle_fps_scale)
	if (
		previous_smartphone_item != runtime.smartphone_last_auto_item
		or not is_equal_approx(previous_smartphone_cooldown, runtime.smartphone_cooldown_frames)
	):
		runtime._sync_owner(owner, registry)
