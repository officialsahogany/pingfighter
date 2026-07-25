extends RefCounted

const WRITHE_SHADER := preload("res://shaders/mythic_writhe.gdshader")
const ARC_SHADER := preload("res://shaders/mythic_arc_flow.gdshader")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BACKPLATE_BASE_SIZE := 620.0
const ARC_LENGTH := 720.0
const ARC_THICKNESS := 96.0
const ARC_COUNT := 4


static func build(
	parent: Node2D,
	backplate_texture: Texture2D,
	arc_texture: Texture2D,
	shard_texture: Texture2D,
	icon_backdrop_texture: Texture2D
) -> Dictionary:
	if parent == null:
		return {}
	var center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	var backplate := _build_backplate(backplate_texture, center)
	parent.add_child(backplate)

	var arcs: Array[Sprite2D] = []
	for index in range(ARC_COUNT):
		var arc := _build_arc(arc_texture, center, index)
		parent.add_child(arc)
		arcs.append(arc)

	var ambient_particles := _build_ambient_particles(shard_texture, center)
	var burst_particles := _build_burst_particles(shard_texture, center)
	var absorb_particles := _build_absorb_particles(shard_texture, center)
	parent.add_child(ambient_particles)
	parent.add_child(burst_particles)
	parent.add_child(absorb_particles)

	var icon_backdrop := Sprite2D.new()
	icon_backdrop.texture = icon_backdrop_texture
	icon_backdrop.centered = true
	icon_backdrop.position = center
	icon_backdrop.scale = Vector2.ZERO
	icon_backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	icon_backdrop.z_index = 4
	parent.add_child(icon_backdrop)

	var icon_sprite := Sprite2D.new()
	icon_sprite.centered = true
	icon_sprite.position = center
	icon_sprite.scale = Vector2.ZERO
	icon_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	icon_sprite.z_index = 5
	parent.add_child(icon_sprite)

	var text_nodes := _build_text_nodes(parent)
	return {
		"backplate": backplate,
		"backplate_material": backplate.material as ShaderMaterial,
		"arcs": arcs,
		"ambient_particles": ambient_particles,
		"burst_particles": burst_particles,
		"absorb_particles": absorb_particles,
		"icon_backdrop": icon_backdrop,
		"icon_sprite": icon_sprite,
		"text_band": text_nodes.get("text_band"),
		"name_label": text_nodes.get("name_label"),
		"description_label": text_nodes.get("description_label"),
	}


static func _build_backplate(texture: Texture2D, center: Vector2) -> Sprite2D:
	var backplate := Sprite2D.new()
	backplate.texture = texture
	backplate.centered = true
	backplate.position = center
	backplate.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = WRITHE_SHADER
	material.set_shader_parameter("elapsed", 0.0)
	material.set_shader_parameter("intensity", 0.0)
	material.set_shader_parameter("distort_strength", 0.012)
	material.set_shader_parameter("flow_speed", 1.0)
	material.set_shader_parameter("pulse_speed", 1.6)
	material.set_shader_parameter("breath_amp", 0.18)
	material.set_shader_parameter("chroma_strength", 0.003)
	material.set_shader_parameter("core_dim_strength", 0.0)
	material.set_shader_parameter("core_dim_radius", 0.28)
	material.set_shader_parameter("core_dim_softness", 0.20)
	backplate.material = material
	var texture_width: float = max(1.0, float(texture.get_width()) if texture != null else BACKPLATE_BASE_SIZE)
	var base_unit := BACKPLATE_BASE_SIZE / texture_width
	backplate.set_meta("base_unit", base_unit)
	backplate.scale = Vector2(base_unit * 0.6, base_unit * 0.6)
	return backplate


static func _build_arc(texture: Texture2D, center: Vector2, index: int) -> Sprite2D:
	var arc := Sprite2D.new()
	arc.texture = texture
	arc.centered = true
	arc.position = center
	arc.rotation = float(index) * (PI * 0.5) + PI * 0.25
	arc.scale = Vector2.ZERO
	arc.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = ARC_SHADER
	material.set_shader_parameter("elapsed", 0.0)
	material.set_shader_parameter("intensity", 1.0)
	material.set_shader_parameter("scroll_speed", 1.5)
	material.set_shader_parameter("fade_softness", 0.18)
	material.set_shader_parameter("pulse_amp", 0.15)
	material.set_shader_parameter("tint", Color(1.0, 0.92, 0.55, 1.0))
	arc.material = material
	return arc


static func _build_ambient_particles(texture: Texture2D, center: Vector2) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 24
	particles.lifetime = 1.35
	particles.preprocess = 0.45
	particles.randomness = 0.6
	particles.texture = texture
	particles.position = center
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_material.emission_ring_radius = 340.0
	process_material.emission_ring_inner_radius = 285.0
	process_material.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	process_material.emission_ring_height = 0.0
	process_material.direction = Vector3.ZERO
	process_material.spread = 180.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.0
	process_material.initial_velocity_max = 14.0
	process_material.radial_accel_min = -18.0
	process_material.radial_accel_max = 12.0
	process_material.tangential_accel_min = 14.0
	process_material.tangential_accel_max = 46.0
	process_material.scale_min = 0.006
	process_material.scale_max = 0.017
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -45.0
	process_material.angular_velocity_max = 45.0
	process_material.color = Color(1.0, 0.84, 0.45, 1.0)
	process_material.color_ramp = _build_gradient_texture([
		[0.0, Color(1.0, 0.84, 0.45, 0.0)],
		[0.25, Color(1.0, 0.84, 0.45, 0.34)],
		[0.85, Color(0.78, 0.45, 0.95, 0.16)],
		[1.0, Color(0.78, 0.45, 0.95, 0.0)],
	])
	_apply_particle_materials(particles, process_material)
	return particles


static func _build_burst_particles(texture: Texture2D, center: Vector2) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 200
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.4
	particles.texture = texture
	particles.position = center
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_material.direction = Vector3.ZERO
	process_material.spread = 180.0
	process_material.gravity = Vector3(0.0, 80.0, 0.0)
	process_material.initial_velocity_min = 360.0
	process_material.initial_velocity_max = 680.0
	process_material.damping_min = 90.0
	process_material.damping_max = 190.0
	process_material.scale_min = 0.018
	process_material.scale_max = 0.048
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -240.0
	process_material.angular_velocity_max = 240.0
	process_material.color_ramp = _build_gradient_texture([
		[0.0, Color(1.0, 1.0, 0.95, 1.0)],
		[0.30, Color(1.0, 0.85, 0.4, 1.0)],
		[0.70, Color(0.95, 0.55, 0.85, 0.6)],
		[1.0, Color(0.55, 0.30, 0.85, 0.0)],
	])
	_apply_particle_materials(particles, process_material)
	return particles


static func _build_absorb_particles(texture: Texture2D, center: Vector2) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 90
	particles.lifetime = 1.3
	particles.preprocess = 0.0
	particles.randomness = 0.45
	particles.texture = texture
	particles.position = center
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_material.emission_ring_radius = 220.0
	process_material.emission_ring_inner_radius = 100.0
	process_material.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	process_material.emission_ring_height = 0.0
	process_material.direction = Vector3.ZERO
	process_material.spread = 180.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.0
	process_material.initial_velocity_max = 30.0
	process_material.radial_accel_min = -380.0
	process_material.radial_accel_max = -260.0
	process_material.tangential_accel_min = 240.0
	process_material.tangential_accel_max = 380.0
	process_material.scale_min = 0.020
	process_material.scale_max = 0.050
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -180.0
	process_material.angular_velocity_max = 180.0
	process_material.color_ramp = _build_gradient_texture([
		[0.0, Color(1.0, 0.95, 0.7, 1.0)],
		[0.5, Color(1.0, 0.78, 0.32, 0.95)],
		[1.0, Color(0.78, 0.45, 0.95, 0.0)],
	])
	_apply_particle_materials(particles, process_material)
	return particles


static func _build_gradient_texture(points: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	for point_value: Variant in points:
		var point: Array = point_value if point_value is Array else []
		if point.size() >= 2:
			gradient.add_point(float(point[0]), point[1] as Color)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _apply_particle_materials(particles: GPUParticles2D, process_material: ParticleProcessMaterial) -> void:
	particles.process_material = process_material
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = canvas_material
	particles.emitting = false


static func _build_text_nodes(parent: Node2D) -> Dictionary:
	var text_band := ColorRect.new()
	text_band.color = Color(0.018, 0.014, 0.035, 0.68)
	text_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_band.z_index = 6
	text_band.visible = false
	parent.add_child(text_band)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.46, 1.0))
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.z_index = 7
	name_label.visible = false
	parent.add_child(name_label)

	var description_label := Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	description_label.clip_text = true
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0, 1.0))
	description_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	description_label.add_theme_constant_override("shadow_offset_x", 1)
	description_label.add_theme_constant_override("shadow_offset_y", 1)
	description_label.z_index = 7
	description_label.visible = false
	parent.add_child(description_label)
	return {
		"text_band": text_band,
		"name_label": name_label,
		"description_label": description_label,
	}
