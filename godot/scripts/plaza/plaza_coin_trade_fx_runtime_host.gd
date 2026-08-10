extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const PlazaCoinTradeFxState := preload("res://scripts/plaza/plaza_coin_trade_fx_state.gd")
const WritheEmberMaterial := preload("res://scripts/effects/writhe_ember_material.gd")

var _state: PlazaCoinTradeFxState = PlazaCoinTradeFxState.new()
var _additive_material: CanvasItemMaterial = null
var _aura_material: ShaderMaterial = null
var _burst_material: ShaderMaterial = null
var _particles: GPUParticles2D = null
var _particle_process_material: ParticleProcessMaterial = null
var _pulse_tween: Tween = null
var _burst_tween: Tween = null


func _ready() -> void:
	set_process(false)
	ensure_ready()


func _exit_tree() -> void:
	tear_down()


func ensure_ready() -> void:
	set_process(false)
	_prewarm_assets()
	_ensure_particles()
	if is_inside_tree() and (_pulse_tween == null or not _pulse_tween.is_valid()):
		_start_pulse_tween()


func play_burst() -> void:
	_state.seed_burst()
	if not is_inside_tree():
		return
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(_state, "burst_value", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_property(_state, "burst_value", 0.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func sync_particles(
	building_type: String,
	trade_ui_open: bool,
	coin_spec: Dictionary,
	hover: float,
	flare: float,
	scale: float
) -> void:
	if _particles == null:
		return
	if building_type != "shop" or trade_ui_open or coin_spec.is_empty():
		_particles.emitting = false
		return
	var rect: Rect2 = coin_spec.get("rect", Rect2())
	var snapshot := _state.build_particle_snapshot(rect, scale, hover, flare)
	if not bool(snapshot.get("visible", false)):
		_particles.emitting = false
		return
	_particles.position = snapshot.get("position", Vector2.ZERO)
	_particles.visibility_rect = snapshot.get("visibility_rect", Rect2())
	_particles.emitting = true
	if _particle_process_material == null:
		return
	_particle_process_material.color = snapshot.get("color", Color.WHITE)
	_particle_process_material.emission_box_extents = snapshot.get("emission_box_extents", Vector3.ZERO)
	_particle_process_material.initial_velocity_min = float(snapshot.get("initial_velocity_min", 0.0))
	_particle_process_material.initial_velocity_max = float(snapshot.get("initial_velocity_max", 0.0))
	_particle_process_material.scale_min = float(snapshot.get("scale_min", 0.0))
	_particle_process_material.scale_max = float(snapshot.get("scale_max", 0.0))


func is_animating(
	building_type: String,
	trade_ui_open: bool,
	has_coin_spec: bool,
	hover_visible: bool,
	clicked_coin: bool,
	flare_timer: float
) -> bool:
	return _state.is_animating(
		building_type,
		trade_ui_open,
		has_coin_spec,
		hover_visible,
		clicked_coin,
		flare_timer
	)


func build_aura_snapshot(rect: Rect2, scale: float, hover: float, flare: float) -> Dictionary:
	return _state.build_aura_snapshot(rect, scale, hover, flare)


func get_additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material


func get_aura_material() -> ShaderMaterial:
	if _aura_material == null:
		_aura_material = WritheEmberMaterial.build_material("shop_coin_trade_aura")
	return _aura_material


func get_burst_material() -> ShaderMaterial:
	if _burst_material == null:
		_burst_material = WritheEmberMaterial.build_material("shop_coin_trade_burst")
	return _burst_material


func get_status() -> Dictionary:
	return {
		"particles_ready": _particles != null,
		"particle_emitting": _particles != null and _particles.emitting,
		"aura_writhe_shader": WritheEmberMaterial.is_material_using_shader(_aura_material),
		"burst_writhe_shader": WritheEmberMaterial.is_material_using_shader(_burst_material),
		"pulse_value": _state.pulse_value,
		"burst_value": _state.burst_value,
		"pulse_tween_active": _pulse_tween != null and _pulse_tween.is_valid(),
		"burst_tween_active": _burst_tween != null and _burst_tween.is_valid(),
		"process_enabled": is_processing(),
	}


func tear_down() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_pulse_tween = null
	_burst_tween = null
	if _particles != null:
		_particles.emitting = false
	_state.reset()
	set_process(false)


func _prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()
	WritheEmberMaterial.prewarm()
	get_additive_material()
	get_aura_material()
	get_burst_material()


func _ensure_particles() -> void:
	if _particles != null:
		return
	_particle_process_material = _state.build_particle_process_material()
	var particles := GPUParticles2D.new()
	particles.name = "CoinTradeSparkParticles"
	particles.amount = 34
	particles.lifetime = 0.92
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.84
	particles.fixed_fps = 60
	particles.local_coords = true
	particles.visibility_rect = Rect2(-130.0, -105.0, 260.0, 210.0)
	particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
	particles.material = get_additive_material()
	particles.process_material = _particle_process_material
	particles.emitting = false
	particles.z_index = 60
	add_child(particles)
	_particles = particles


func _start_pulse_tween() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_state, "pulse_value", 1.0, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_state, "pulse_value", 0.0, 0.64).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
