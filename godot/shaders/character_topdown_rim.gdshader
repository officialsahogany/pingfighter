shader_type canvas_item;

uniform float rim_intensity : hint_range(0.0, 1.0) = 0.65;
uniform vec4 rim_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float rim_offset_px = 2.0;
uniform vec2 sprite_pixel_size = vec2(1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 px_uv = 1.0 / max(sprite_pixel_size, vec2(1.0, 1.0));

	float alpha_above = texture(TEXTURE, UV - vec2(0.0, px_uv.y * rim_offset_px)).a;
	float top_edge = step(0.5, base.a) * (1.0 - step(0.5, alpha_above));

	vec3 final_rgb = mix(base.rgb, rim_color.rgb, top_edge * rim_intensity * rim_color.a);
	COLOR = vec4(final_rgb, base.a);
}
