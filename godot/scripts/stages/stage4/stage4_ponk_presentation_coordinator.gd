extends RefCounted

const Stage4PonkMagneticFxHost := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd")
const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")
const Stage4PonkIllusionRippleFxHost := preload("res://scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")

# Presentation-only fanout for Ponk's skill set. Runtime state owners keep all
# gameplay clocks and payloads; this coordinator owns staged asset preparation,
# draw-clock synchronization, exact host/fallback order, and asset diagnostics.

var fallback_fx_renderer: Object

var _prewarm_assets_done := false
var _prewarm_step_index := 0
var _fx_host_coordinator: Object
var _fx_context_builder: Object
var _runtime_coordinator: Object
var _magnetic_field_state: Object
var _magnetic_projectile_state: Object
var _meditation_state: Object
var _illusion_state: Object


func _init(
	fx_host_coordinator: Object,
	fx_context_builder: Object,
	fallback_renderer: Object,
	runtime_coordinator: Object,
	magnetic_field_state: Object,
	magnetic_projectile_state: Object,
	meditation_state: Object,
	illusion_state: Object
) -> void:
	_fx_host_coordinator = fx_host_coordinator
	_fx_context_builder = fx_context_builder
	fallback_fx_renderer = fallback_renderer
	_runtime_coordinator = runtime_coordinator
	_magnetic_field_state = magnetic_field_state
	_magnetic_projectile_state = magnetic_projectile_state
	_meditation_state = meditation_state
	_illusion_state = illusion_state


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	match _prewarm_step_index:
		0:
			ensure_textures()
		1:
			if not Stage4PonkMagneticFxHost.prewarm_assets_step():
				return false
		2:
			if not Stage4PonkMeditationFxHost.prewarm_assets_step():
				return false
		3:
			if not Stage4PonkIllusionRippleFxHost.prewarm_assets_step():
				return false
		4:
			if not Stage4PonkAwakenAuraFxHost.prewarm_assets_step():
				return false
		_:
			_prewarm_assets_done = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 4:
		_prewarm_assets_done = true
		_prewarm_step_index = 0
		return true
	return false


func prewarm_runtime_hosts(canvas: CanvasItem) -> void:
	_fx_host_coordinator.prewarm_runtime_hosts(canvas)


func prewarm_runtime_hosts_step(canvas: CanvasItem) -> bool:
	return _fx_host_coordinator.prewarm_runtime_hosts_step(canvas)


func get_asset_status() -> Dictionary:
	ensure_textures()
	var status: Dictionary = fallback_fx_renderer.call("get_asset_status")
	status.merge(Stage4PonkMagneticFxHost.build_pipeline_status(), true)
	status.merge(Stage4PonkMeditationFxHost.build_pipeline_status(), true)
	status.merge(Stage4PonkIllusionRippleFxHost.build_pipeline_status(), true)
	status.merge(Stage4PonkAwakenAuraFxHost.build_pipeline_status(), true)
	status["magnetic_fx_host_attached"] = is_valid_magnetic_fx_host()
	status["meditation_fx_host_attached"] = is_valid_meditation_fx_host()
	status["illusion_fx_host_attached"] = is_valid_illusion_fx_host()
	status["awaken_aura_fx_host_attached"] = is_valid_awaken_aura_fx_host()
	return status


func has_loaded_awaken_aura_pipeline() -> bool:
	return Stage4PonkAwakenAuraFxHost.has_loaded_pipeline()


func draw(canvas: CanvasItem, context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	sync_draw_clock(context)
	ensure_textures()
	var magnetic_field_fx_active: bool = bool(
		context.get("stage4_magnetic_active", _magnetic_field_state.get("magnetic_active"))
	)
	var magnetic_projectile_fx_active: bool = (
		bool(context.get("stage4_magnetic_projectile_active", _magnetic_projectile_state.get("active")))
		or bool(context.get(
			"stage4_magnetic_projectile_fade_active",
			float(_magnetic_projectile_state.get("fade_timer_seconds")) > 0.0
		))
	)
	var magnetic_fx_active: bool = magnetic_field_fx_active or magnetic_projectile_fx_active
	var magnetic_fx_handled: bool = sync_magnetic_fx_host(canvas, context, shake_offset, magnetic_fx_active)
	if magnetic_field_fx_active and not magnetic_fx_handled:
		draw_magnetic_field(canvas, context, shake_offset)
	if magnetic_projectile_fx_active and not magnetic_fx_handled:
		draw_magnetic_projectile(canvas, context, shake_offset)
	var meditation_fx_active: bool = (
		bool(context.get("stage4_meditation_active", _meditation_state.get("meditation_active")))
		or bool(context.get(
			"stage4_meditation_release_fx_active",
			float(_meditation_state.get("meditation_release_fx_timer_frames")) > 0.0
		))
	)
	var meditation_fx_handled: bool = sync_meditation_fx_host(canvas, context, shake_offset, meditation_fx_active)
	if meditation_fx_active and not meditation_fx_handled:
		draw_meditation(canvas, context, shake_offset)
	var awaken_aura_intensity: float = get_illusion_awaken_aura_intensity(context)
	sync_awaken_aura_fx_host(canvas, context, shake_offset, awaken_aura_intensity > 0.001)
	var illusion_fx_active: bool = bool(context.get("stage4_illusion_active", _illusion_state.get("illusion_active")))
	sync_illusion_fx_host(canvas, context, illusion_fx_active)


func ensure_textures() -> void:
	fallback_fx_renderer.call("ensure_textures")


func sync_draw_clock(context: Dictionary) -> void:
	var frame_clock: float = float(_runtime_coordinator.get("frame_clock"))
	if context.has("stage4_effect_clock"):
		_runtime_coordinator.set(
			"frame_clock",
			maxf(0.0, float(context.get("stage4_effect_clock", frame_clock)))
		)
		return
	if (
		bool(context.get("stage4_magnetic_active", _magnetic_field_state.get("magnetic_active")))
		or bool(context.get("stage4_magnetic_projectile_active", _magnetic_projectile_state.get("active")))
		or bool(context.get(
			"stage4_magnetic_projectile_fade_active",
			float(_magnetic_projectile_state.get("fade_timer_seconds")) > 0.0
		))
		or bool(context.get("stage4_meditation_active", _meditation_state.get("meditation_active")))
		or bool(context.get(
			"stage4_meditation_release_fx_active",
			float(_meditation_state.get("meditation_release_fx_timer_frames")) > 0.0
		))
		or get_illusion_awaken_aura_intensity(context) > 0.001
		or bool(context.get("stage4_illusion_active", _illusion_state.get("illusion_active")))
	):
		_runtime_coordinator.set("frame_clock", float(Time.get_ticks_msec()) * 0.001)


func get_illusion_awaken_aura_intensity(context: Dictionary) -> float:
	return float(_illusion_state.get_awaken_aura_intensity(context))


func draw_magnetic_field(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	fallback_fx_renderer.call(
		"draw_magnetic_field",
		canvas,
		context,
		shake_offset,
		_magnetic_field_state,
		_runtime_coordinator.get("frame_clock")
	)


func draw_magnetic_projectile(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	fallback_fx_renderer.call(
		"draw_magnetic_projectile",
		canvas,
		context,
		shake_offset,
		_magnetic_projectile_state,
		_runtime_coordinator.get("frame_clock")
	)


func sync_magnetic_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _fx_host_coordinator.sync_magnetic(
		canvas,
		build_magnetic_fx_context(context, shake_offset),
		active
	)


func build_magnetic_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _fx_context_builder.build_magnetic(
		context,
		shake_offset,
		_magnetic_field_state,
		_magnetic_projectile_state,
		_runtime_coordinator.get("frame_clock")
	)


func is_valid_magnetic_fx_host() -> bool:
	return _fx_host_coordinator.is_valid_magnetic()


func sync_meditation_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _fx_host_coordinator.sync_meditation(
		canvas,
		build_meditation_fx_context(context, shake_offset),
		active
	)


func build_meditation_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _fx_context_builder.build_meditation(
		context,
		shake_offset,
		_meditation_state
	)


func is_valid_meditation_fx_host() -> bool:
	return _fx_host_coordinator.is_valid_meditation()


func sync_illusion_fx_host(canvas: CanvasItem, context: Dictionary, active: bool) -> bool:
	return _fx_host_coordinator.sync_illusion(
		canvas,
		build_illusion_fx_context(context, canvas),
		active
	)


func build_illusion_fx_context(context: Dictionary, canvas: CanvasItem = null) -> Dictionary:
	return _fx_context_builder.build_illusion(
		context,
		_illusion_state,
		_runtime_coordinator.get("frame_clock"),
		canvas
	)


func is_valid_illusion_fx_host() -> bool:
	return _fx_host_coordinator.is_valid_illusion()


func sync_awaken_aura_fx_host(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, active: bool) -> bool:
	return _fx_host_coordinator.sync_awaken_aura(
		canvas,
		build_awaken_aura_fx_context(context, shake_offset),
		active
	)


func build_awaken_aura_fx_context(context: Dictionary, shake_offset: Vector2) -> Dictionary:
	return _fx_context_builder.build_awaken_aura(
		context,
		shake_offset,
		_illusion_state,
		_runtime_coordinator.get("frame_clock")
	)


func is_valid_awaken_aura_fx_host() -> bool:
	return _fx_host_coordinator.is_valid_awaken_aura()


func draw_meditation(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	fallback_fx_renderer.call(
		"draw_meditation",
		canvas,
		context,
		shake_offset,
		_meditation_state,
		_runtime_coordinator.get("frame_clock")
	)


func get_current_frame_index() -> int:
	return int(fallback_fx_renderer.call(
		"get_current_frame_index",
		_runtime_coordinator.get("frame_clock")
	))
