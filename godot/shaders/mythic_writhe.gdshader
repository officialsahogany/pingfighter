shader_type canvas_item;
render_mode blend_add;

uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float distort_strength : hint_range(0.0, 0.05) = 0.012;
uniform float flow_speed : hint_range(0.0, 4.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.6;
uniform float breath_amp : hint_range(0.0, 0.6) = 0.18;
uniform float chroma_strength : hint_range(0.0, 0.01) = 0.003;
uniform float core_dim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float core_dim_radius : hint_range(0.0, 0.5) = 0.28;
uniform float core_dim_softness : hint_range(0.01, 0.5) = 0.20;
uniform vec4 hot_color : source_color = vec4(1.0, 0.75, 0.30, 1.0);
uniform vec4 cool_color : source_color = vec4(0.61, 0.30, 0.79, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
				   dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			   mix(dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				   dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = uv - vec2(0.5);
	float dist = length(center);

	vec2 nz = vec2(
		vnoise(uv * 4.5 + vec2(elapsed * 0.35, 0.0)),
		vnoise(uv * 4.5 + vec2(0.0, elapsed * 0.42))
	);
	nz += 0.5 * vec2(
		vnoise(uv * 9.0 - vec2(elapsed * 0.21, 0.0)),
		vnoise(uv * 9.0 - vec2(0.0, elapsed * 0.27))
	);
	vec2 duv = uv + nz * distort_strength;

	float chroma = chroma_strength * (0.5 + 0.5 * sin(elapsed * 2.4));
	float r = texture(TEXTURE, duv + vec2(chroma, 0.0)).r;
	vec4 base_sample = texture(TEXTURE, duv);
	float g = base_sample.g;
	float b = texture(TEXTURE, duv - vec2(chroma, 0.0)).b;
	vec3 col = vec3(r, g, b) * base_sample.a;
	float lum = max(max(col.r, col.g), col.b);
	float core_mask = smoothstep(core_dim_radius, core_dim_radius + core_dim_softness, dist);
	float core_keep = mix(1.0 - core_dim_strength, 1.0, core_mask);
	lum *= core_keep;
	col *= core_keep;

	float flow = sin(dist * 22.0 - elapsed * flow_speed * 7.0) * 0.5 + 0.5;
	flow = pow(flow, 5.0);

	float flicker = vnoise(vec2(elapsed * pulse_speed, dist * 9.0)) * 0.5 + 0.5;
	vec3 flicker_col = mix(hot_color.rgb, ember_color.rgb, flicker);
	col = mix(col, flicker_col * lum, 0.40);

	col = mix(col, cool_color.rgb * lum * 0.6, (1.0 - flicker) * 0.18);

	col += flow * lum * 0.42 * ember_color.rgb;

	float breath = 1.0 - breath_amp + breath_amp * sin(elapsed * 1.9);

	COLOR = vec4(col * intensity, lum * breath * COLOR.a);
}
