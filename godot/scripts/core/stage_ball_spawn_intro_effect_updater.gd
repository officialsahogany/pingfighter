extends RefCounted


func update_quantum_particle(p: Dictionary, progress: float, dt: float, start_pos: Vector2) -> void:
	var brightness: float = 0.5 + 0.5 * sin(p.brightness_phase)
	var trail_arr: Array = p.trail
	trail_arr.append(Vector4(p.x, p.y, p.size, brightness))
	if trail_arr.size() > p.trail_length:
		trail_arr.pop_front()

	var accel: float = 1.0 + progress * 3.0 + progress * progress * 2.0
	p.angle += p.speed * accel * dt * 6.0
	p.radial_pulse_phase += p.radial_pulse_freq * dt
	var pulse_factor: float = 1.0 + sin(p.radial_pulse_phase) * p.radial_pulse_amp
	var target_radius: float = p.radius * (1.0 - progress * 0.95) * pulse_factor

	p.wobble_phase += p.wobble_freq * dt
	var wobble_off: float = sin(p.wobble_phase) * p.wobble_amp * (1.0 - progress * 0.7)

	p.x = start_pos.x + cos(p.angle) * target_radius + cos(p.angle + PI * 0.5) * wobble_off
	p.y = start_pos.y + sin(p.angle) * target_radius + sin(p.angle + PI * 0.5) * wobble_off

	p.pulse_phase += p.pulse_speed * dt
	var pulse: float = 1.0 + sin(p.pulse_phase) * p.pulse_amp
	p.size = max(1.5, p.base_size * pulse * (1.0 + progress * 0.15))

	p.brightness_phase += p.brightness_speed * dt

	if p.has_flare:
		p.flare_angle += p.flare_rotation_speed * dt


func update_vortex_ring(r: Dictionary, progress: float, dt: float) -> void:
	r.angle += r.rotation_speed * dt
	r.time += dt
	r.radius *= max(0.0, 1.0 - progress * 0.02 * dt)


func update_electric_arc(
	rng: RandomNumberGenerator,
	arc: Dictionary,
	dt: float,
	new_center: Vector2
) -> void:
	arc.angle += arc.rotation_speed * dt
	arc.center = new_center
	for i in range(arc.noise.size()):
		arc.noise[i] = clamp(arc.noise[i] + rng.randf_range(-2.0, 2.0), -8.0, 8.0)


func update_hologram_ring(
	rng: RandomNumberGenerator,
	h: Dictionary,
	dt: float,
	new_center: Vector2
) -> void:
	h.flicker_phase += h.flicker_speed * dt
	h.center = new_center
	h.radius += (h.target_radius - h.radius) * 0.1
	for i in range(h.distortion.size()):
		h.distortion[i] = clamp(h.distortion[i] + rng.randf_range(-1.0, 1.0), -5.0, 5.0)


func update_spark(sp: Dictionary, dt: float) -> void:
	sp.trail.append(sp.pos)
	if sp.trail.size() > sp.trail_length:
		sp.trail.pop_front()
	sp.pos += sp.vel * dt
	sp.vel.y += sp.gravity * dt
	sp.vel *= 0.98


func update_energy_ring(ring: Dictionary, dt: float, new_center: Vector2) -> void:
	ring.radius += ring.expansion_speed * dt
	ring.center = new_center


func prune_lifetime(arr: Array, dt: float) -> void:
	var keep: Array = []
	for e in arr:
		if e.has("max_radius") and e.has("lifetime"):
			e.lifetime -= dt
			if e.lifetime > 0.0 and e.radius < e.max_radius:
				keep.append(e)
			continue
		if e.has("bolts") and e.has("lifetime"):
			e.lifetime -= dt
			var alive_bolts: Array = []
			for b in e.bolts:
				b.lifetime -= dt
				if b.lifetime > 0.0:
					alive_bolts.append(b)
			e.bolts = alive_bolts
			if e.lifetime > 0.0 and not alive_bolts.is_empty():
				keep.append(e)
			continue
		if e.has("lifetime"):
			e.lifetime -= dt
			if e.lifetime > 0.0:
				keep.append(e)
		else:
			keep.append(e)
	arr.clear()
	for k in keep:
		arr.append(k)
