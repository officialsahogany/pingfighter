extends RefCounted

const _LIGHT_SLIT_FLOW_SHADER := """
shader_type canvas_item;
render_mode blend_mix;

uniform float elapsed = 0.0;
uniform float opacity = 0.28;
uniform float flow_speed = 0.18;
uniform float pulse_amp = 0.08;
uniform float phase = 0.0;
uniform vec4 primary_color : source_color = vec4(0.13, 0.92, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.82, 0.98, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float center_weight = pow(clamp(1.0 - abs(UV.x - 0.5) * 2.0, 0.0, 1.0), 1.8);
	float flow_y = UV.y + elapsed * flow_speed + phase;
	float stream_a = pow(sin(flow_y * 39.0 + center_weight * 3.0) * 0.5 + 0.5, 5.0);
	float stream_b = pow(sin(flow_y * 71.0 + UV.x * 11.0) * 0.5 + 0.5, 7.0);
	float flow = stream_a * 0.20 + stream_b * 0.12;
	float breath = 1.0 + sin(elapsed * 1.1 + phase * 5.0) * pulse_amp;
	vec3 flow_color = mix(primary_color.rgb, accent_color.rgb, stream_a);
	vec3 color = tex.rgb * breath + flow_color * flow * max(tex.a, center_weight * 0.18);
	float alpha = tex.a * opacity * (1.0 + flow * 0.55);
	COLOR = vec4(color, alpha) * COLOR;
}
"""

const _FLOOR_RING_FLOW_SHADER := """
shader_type canvas_item;
render_mode blend_mix;

uniform float elapsed = 0.0;
uniform float opacity = 0.34;
uniform float spin_speed = 0.85;
uniform float pulse_amp = 0.05;
uniform vec4 primary_color : source_color = vec4(0.13, 0.92, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.82, 0.98, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV - vec2(0.5);
	vec2 ellipse_p = vec2(p.x, p.y * 4.0);
	float angle = atan(ellipse_p.y, ellipse_p.x);
	float ring_radius = length(ellipse_p);
	float band = smoothstep(0.08, 0.34, ring_radius) * (1.0 - smoothstep(0.74, 1.08, ring_radius));
	float orbit_a = pow(sin(angle * 8.0 - elapsed * spin_speed) * 0.5 + 0.5, 6.0);
	float orbit_b = pow(sin(angle * 13.0 - elapsed * spin_speed * 1.37 + 1.2) * 0.5 + 0.5, 8.0);
	float flow = (orbit_a * 0.20 + orbit_b * 0.14) * band;
	float breath = 1.0 + sin(elapsed * 1.55) * pulse_amp;
	vec3 flow_color = mix(primary_color.rgb, accent_color.rgb, orbit_a);
	vec3 color = tex.rgb * breath + flow_color * flow * max(tex.a, band * 0.22);
	float alpha = tex.a * opacity * (1.0 + flow * 0.40);
	COLOR = vec4(color, alpha) * COLOR;
}
"""

static var _light_slit_flow_shader: Shader = null
static var _floor_ring_flow_shader: Shader = null


static func prewarm() -> void:
	_get_light_slit_flow_shader()
	_get_floor_ring_flow_shader()


static func clear_caches() -> void:
	# Compatibility hook kept for callers that release shared VFX resources.
	_light_slit_flow_shader = null
	_floor_ring_flow_shader = null


static func build_additive_canvas_material() -> CanvasItemMaterial:
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return canvas_material


static func build_light_slit_flow_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_light_slit_flow_shader()
	return material


static func build_floor_ring_flow_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_floor_ring_flow_shader()
	return material


static func get_palette(character_id: String) -> Dictionary:
	match character_id:
		"soldier":
			return {
				"primary": Color(0.48, 0.58, 0.32, 1.0),
				"accent": Color(1.0, 0.78, 0.24, 1.0),
				"deep": Color(0.035, 0.050, 0.035, 1.0),
			}
		"viper":
			return {
				"primary": Color(0.63, 0.25, 1.0, 1.0),
				"accent": Color(1.0, 0.20, 0.40, 1.0),
				"deep": Color(0.035, 0.018, 0.060, 1.0),
			}
		"blacksmith":
			return {
				"primary": Color(1.0, 0.42, 0.10, 1.0),
				"accent": Color(1.0, 0.82, 0.40, 1.0),
				"deep": Color(0.070, 0.032, 0.015, 1.0),
			}
		"optimus":
			return {
				"primary": Color(0.54, 0.28, 1.0, 1.0),
				"accent": Color(1.0, 0.82, 0.28, 1.0),
				"deep": Color(0.032, 0.022, 0.070, 1.0),
			}
		_:
			return {
				"primary": Color(0.13, 0.92, 1.0, 1.0),
				"accent": Color(0.82, 0.98, 1.0, 1.0),
				"deep": Color(0.018, 0.040, 0.060, 1.0),
			}


static func _get_light_slit_flow_shader() -> Shader:
	if _light_slit_flow_shader == null:
		var shader := Shader.new()
		shader.code = _LIGHT_SLIT_FLOW_SHADER
		_light_slit_flow_shader = shader
	return _light_slit_flow_shader


static func _get_floor_ring_flow_shader() -> Shader:
	if _floor_ring_flow_shader == null:
		var shader := Shader.new()
		shader.code = _FLOOR_RING_FLOW_SHADER
		_floor_ring_flow_shader = shader
	return _floor_ring_flow_shader
