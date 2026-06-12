extends RefCounted

const DURATION_SEC := 2.20
const PARTICLE_COUNT := 58
const BOLT_COUNT := 24


func reset(runtime: Object) -> void:
	runtime.activation_started_msec = -1000000
	runtime.activation_particles.clear()
	runtime.activation_bolts.clear()


func is_active(runtime: Object) -> bool:
	return get_elapsed(runtime) < DURATION_SEC


func start(runtime: Object, owner: Object, registry: Object) -> void:
	runtime.activation_started_msec = Time.get_ticks_msec()
	build_particles(runtime)
	build_bolts(runtime)
	runtime.audio_router.play_activation_audio(runtime, registry)
	if owner != null and owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
	elif owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func draw(runtime: Object, canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null or not is_active(runtime):
		return
	runtime.activation_effect_renderer.draw_activation_effect(
		canvas,
		view_size,
		get_elapsed(runtime),
		runtime.activation_particles,
		runtime.activation_bolts,
		DURATION_SEC
	)


func build_particles(runtime: Object) -> void:
	runtime.activation_particles = runtime.activation_effect_renderer.build_activation_particles(PARTICLE_COUNT)


func build_bolts(runtime: Object) -> void:
	runtime.activation_bolts = runtime.activation_effect_renderer.build_activation_bolts(BOLT_COUNT)


func make_bolt_points(runtime: Object, start_pos: Vector2, end_pos: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	return runtime.activation_effect_renderer.make_bolt_points(start_pos, end_pos, segments, jitter)


func get_elapsed(runtime: Object) -> float:
	return float(Time.get_ticks_msec() - runtime.activation_started_msec) / 1000.0
