extends RefCounted

const BURST_SEED := 0.35

var pulse_value := 0.0
var burst_value := 0.0


func seed_burst() -> void:
	burst_value = BURST_SEED


func reset() -> void:
	pulse_value = 0.0
	burst_value = 0.0


func build_particle_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 42.0
	material.gravity = Vector3(0.0, -42.0, 0.0)
	material.initial_velocity_min = 7.0
	material.initial_velocity_max = 38.0
	material.damping_min = 5.0
	material.damping_max = 26.0
	material.scale_min = 0.022
	material.scale_max = 0.060
	material.color = Color(1.0, 0.82, 0.30, 0.42)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(42.0, 14.0, 0.0)
	return material


func build_particle_snapshot(rect: Rect2, scale: float, hover: float, flare: float) -> Dictionary:
	var intensity := clampf(hover * 0.90 + flare * 0.45 + burst_value * 0.85, 0.0, 1.0)
	if intensity <= 0.03:
		return {
			"visible": false,
			"intensity": intensity,
		}
	return {
		"visible": true,
		"intensity": intensity,
		"position": rect.get_center() * scale + Vector2(0.0, -5.0) * scale,
		"visibility_rect": Rect2(-150.0 * scale, -118.0 * scale, 300.0 * scale, 220.0 * scale),
		"color": Color(1.0, 0.82, 0.30, 0.24 + intensity * 0.48),
		"emission_box_extents": Vector3(
			maxf(34.0, rect.size.x * 0.48) * scale,
			maxf(12.0, rect.size.y * 0.22) * scale,
			0.0
		),
		"initial_velocity_min": 7.0 + burst_value * 24.0,
		"initial_velocity_max": 38.0 + burst_value * 72.0,
		"scale_min": 0.022 + burst_value * 0.010,
		"scale_max": 0.060 + burst_value * 0.025,
	}


func is_animating(
	building_type: String,
	trade_ui_open: bool,
	has_coin_spec: bool,
	hover_visible: bool,
	clicked_coin: bool,
	flare_timer: float
) -> bool:
	if building_type != "shop" or trade_ui_open:
		return false
	if burst_value > 0.01:
		return true
	if not has_coin_spec:
		return false
	return hover_visible or (clicked_coin and flare_timer > 0.0)


func build_aura_snapshot(rect: Rect2, scale: float, hover: float, flare: float) -> Dictionary:
	var energy := clampf(hover * 0.95 + flare * 0.42 + burst_value * 0.92, 0.0, 1.75)
	if energy <= 0.01:
		return {}
	var center_px := rect.get_center() * scale + Vector2(0.0, 4.0) * scale
	var base_size := float(max(rect.size.x, rect.size.y)) * scale
	var backplate_size := Vector2(
		base_size * (2.12 + hover * 0.22 + burst_value * 0.42),
		base_size * (1.30 + hover * 0.14 + burst_value * 0.28)
	)
	var ring_size := Vector2(
		base_size * (1.86 + hover * 0.24 + burst_value * 0.38),
		base_size * (0.92 + hover * 0.12 + burst_value * 0.22)
	)
	var accent_size := ring_size * Vector2(0.78 + pulse_value * 0.05, 0.62 + pulse_value * 0.04)
	var snapshot := {
		"energy": energy,
		"backplate_rect": Rect2(center_px - backplate_size * 0.5, backplate_size),
		"backplate_color": Color(
			1.0,
			0.62,
			0.16,
			clampf(0.10 + hover * 0.26 + flare * 0.10 + burst_value * 0.18 + pulse_value * 0.04, 0.0, 0.58)
		),
		"ring_rect": Rect2(center_px - ring_size * 0.5, ring_size),
		"ring_color": Color(1.0, 0.82, 0.30, clampf(0.16 + hover * 0.34 + burst_value * 0.22, 0.0, 0.72)),
		"ring_intensity": 0.80 + energy * 0.34,
		"accent_rect": Rect2(center_px - accent_size * 0.5 + Vector2(0.0, -2.0) * scale, accent_size),
		"accent_color": Color(0.22, 0.95, 1.0, clampf(0.06 + hover * 0.14 + burst_value * 0.18, 0.0, 0.34)),
		"accent_intensity": 0.62 + energy * 0.24,
		"burst_visible": burst_value > 0.01,
	}
	if burst_value > 0.01:
		var burst_size := Vector2(
			base_size * (1.36 + burst_value * 0.86),
			base_size * (1.02 + burst_value * 0.42)
		)
		var burst_ring_size := ring_size * (1.00 + burst_value * 0.42)
		snapshot["burst_rect"] = Rect2(center_px - burst_size * 0.5, burst_size)
		snapshot["burst_color"] = Color(1.0, 0.86, 0.32, 0.26 * burst_value)
		snapshot["burst_ring_rect"] = Rect2(center_px - burst_ring_size * 0.5, burst_ring_size)
		snapshot["burst_ring_color"] = Color(1.0, 0.94, 0.56, 0.34 * burst_value)
		snapshot["burst_ring_intensity"] = 1.08 + burst_value * 0.72
	return snapshot
