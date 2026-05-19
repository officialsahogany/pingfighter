shader_type canvas_item;
render_mode blend_add;

uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float scroll_speed : hint_range(0.0, 4.0) = 1.5;
uniform float fade_softness : hint_range(0.0, 1.0) = 0.18;
uniform float pulse_amp : hint_range(0.0, 0.5) = 0.15;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;

	vec2 duv = uv;
	duv.x = fract(uv.x - elapsed * scroll_speed * 0.18);

	vec4 tex = texture(TEXTURE, duv);
	vec3 col = tex.rgb * tex.a;
	float lum = max(max(col.r, col.g), col.b);

	float tip_left = smoothstep(0.0, fade_softness, uv.x);
	float tip_right = smoothstep(1.0, 1.0 - fade_softness, uv.x);
	float tip_x = tip_left * tip_right;

	float vert_top = smoothstep(0.0, 0.18, uv.y);
	float vert_bot = smoothstep(1.0, 0.82, uv.y);
	float vert = vert_top * vert_bot;

	float pulse = (1.0 - pulse_amp) + pulse_amp * sin(elapsed * 4.0 - uv.x * 6.28318);

	float final_a = lum * tip_x * vert * pulse;

	COLOR = vec4(col * tint.rgb * intensity, final_a * COLOR.a);
}
