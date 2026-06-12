extends RefCounted

# Per-tick mythic update cost showed up in BattlePerf only as the opaque
# physics.callback.mythic_items leaf (~1.1ms/tick standing late-match), so
# every family update is labeled here. Labels must keep zero uninstrumented
# gaps or the standing cost hides between them.


func update(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	ragnarok_constants: Dictionary,
	poseidon_constants: Dictionary,
	baal_boots_constants: Dictionary,
	context_constants: Dictionary,
	perf_logger: Object = null
) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	var has_update_work: bool = runtime.update_gate.has_runtime_update_work(runtime)
	_perf_end(perf_logger, "physics.items.mythic.gate", sample_start)
	if not has_update_work:
		_update_idle(runtime, owner, registry, delta, perf_logger)
		return

	sample_start = _perf_begin(perf_logger)
	var update_scope: Dictionary = runtime.update_gate.build_update_scope(runtime)
	_perf_end(perf_logger, "physics.items.mythic.scope", sample_start)
	var fps_scale: float = max(0.0, delta * 60.0)
	sample_start = _perf_begin(perf_logger)
	runtime.acquisition_cinematic_runtime.update(runtime, delta, registry)
	_perf_end(perf_logger, "physics.items.mythic.acquisition", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.pandora_legacy_runtime.update_selection_frames(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.pandora", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.ragnarok_runtime.update_runtime(runtime, owner, registry, delta, fps_scale, ragnarok_constants)
	_perf_end(perf_logger, "physics.items.mythic.ragnarok", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.smartphone", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.knee_pads_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.knee_pads", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.soul_burst_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.soul_burst", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.foul_whistle_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.foul_whistle", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.revival_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.revival", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.odins_eye_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.odins_eye", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.auto_defense_runtime.update_sensor_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.sensor", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.venom_mist_runtime.update_runtime(runtime, owner, registry, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.venom_mist", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.rainbow_fur_glove_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.rainbow_fur", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.adversity_armor_runtime.update_runtime(runtime, owner, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.adversity_armor", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.shrapnel_armor_runtime.update_runtime(runtime, owner, registry, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.shrapnel_armor", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.poseidon_runtime.update_runtime(runtime, owner, registry, fps_scale, poseidon_constants)
	_perf_end(perf_logger, "physics.items.mythic.poseidon", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.celestial_armor_runtime.update_runtime(runtime, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.celestial_armor", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.hermes_shoes_runtime.update_runtime(runtime, owner, fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.hermes", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.baal_boots_runtime.update_runtime(runtime, owner, registry, fps_scale, baal_boots_constants)
	_perf_end(perf_logger, "physics.items.mythic.baal_boots", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.horn_strawberry_mask_runtime.update(runtime, owner, registry, delta, context_constants)
	_perf_end(perf_logger, "physics.items.mythic.horn_strawberry", sample_start)
	sample_start = _perf_begin(perf_logger)
	runtime.update_gate.sync_after_update(runtime, owner, registry, update_scope)
	_perf_end(perf_logger, "physics.items.mythic.sync_after", sample_start)


func _update_idle(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	perf_logger: Object = null
) -> void:
	var idle_fps_scale: float = max(0.0, delta * 60.0)
	var sample_start: int = _perf_begin(perf_logger)
	runtime.poseidon_runtime.poll_idle_dash_trigger(runtime, owner, registry)
	_perf_end(perf_logger, "physics.items.mythic.idle.poseidon_poll", sample_start)
	sample_start = _perf_begin(perf_logger)
	var previous_smartphone_item: String = str(runtime.smartphone_last_auto_item)
	var previous_smartphone_cooldown: float = float(runtime.smartphone_cooldown_frames)
	runtime.auto_defense_runtime.update_smartphone_runtime(runtime, owner, registry, idle_fps_scale)
	_perf_end(perf_logger, "physics.items.mythic.idle.smartphone", sample_start)
	if (
		previous_smartphone_item != runtime.smartphone_last_auto_item
		or not is_equal_approx(previous_smartphone_cooldown, runtime.smartphone_cooldown_frames)
	):
		sample_start = _perf_begin(perf_logger)
		runtime._sync_owner(owner, registry)
		_perf_end(perf_logger, "physics.items.mythic.idle.sync_owner", sample_start)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
