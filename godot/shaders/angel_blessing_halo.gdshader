shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform vec2 center_uv = vec2(0.5, 0.43);
uniform vec4 inner_color : source_color = vec4(0.96, 0.76, 0.30, 1.0);
uniform vec4 outer_color : source_color = vec4(0.66, 0.14, 0.10, 1.0);
uniform vec4 jade_color : source_color = vec4(0.20, 0.54, 0.52, 1.0);

void fragment() {
	vec2 aspect_uv = UV - center_uv;
	aspect_uv.x *= 760.0 / 750.0;
	float radius = length(aspect_uv);
	float angle = atan(aspect_uv.y, aspect_uv.x);
	float breath = 0.93 + 0.07 * sin(elapsed * 4.4);
	float core = exp(-radius * radius * 21.0) * breath;
	float ring_radius = 0.19 + 0.012 * sin(elapsed * 3.1);
	float ring = exp(-pow(abs(radius - ring_radius) * 22.0, 2.0));
	float divination_marks = 0.48 + 0.52 * smoothstep(-0.10, 0.38, sin(angle * 12.0 - elapsed * 1.8));
	float marked_ring = ring * divination_marks;
	float outer = exp(-radius * radius * 6.4) * 0.18;
	float jade_ring = exp(-pow(abs(radius - 0.245) * 25.0, 2.0)) * 0.23;
	vec3 color = inner_color.rgb * (core + marked_ring * 0.58)
		+ outer_color.rgb * outer
		+ jade_color.rgb * jade_ring;
	float alpha = clamp((core * 0.68 + marked_ring * 0.38 + jade_ring * 0.18 + outer) * intensity, 0.0, 0.78);
	COLOR = vec4(color * intensity, alpha);
}
