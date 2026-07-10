shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform vec2 center_uv = vec2(0.5, 0.43);
uniform vec4 inner_color : source_color = vec4(1.0, 0.91, 0.48, 1.0);
uniform vec4 outer_color : source_color = vec4(0.48, 0.24, 0.95, 1.0);

void fragment() {
	vec2 aspect_uv = UV - center_uv;
	aspect_uv.x *= 760.0 / 750.0;
	float radius = length(aspect_uv);
	float breath = 0.93 + 0.07 * sin(elapsed * 4.4);
	float core = exp(-radius * radius * 19.0) * breath;
	float ring_radius = 0.19 + 0.012 * sin(elapsed * 3.1);
	float ring = exp(-pow(abs(radius - ring_radius) * 22.0, 2.0));
	float outer = exp(-radius * radius * 5.8) * 0.22;
	vec3 color = inner_color.rgb * (core + ring * 0.52) + outer_color.rgb * outer;
	float alpha = clamp((core * 0.72 + ring * 0.34 + outer) * intensity, 0.0, 0.82);
	COLOR = vec4(color * intensity, alpha);
}
