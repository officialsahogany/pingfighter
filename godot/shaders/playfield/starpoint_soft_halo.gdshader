shader_type canvas_item;
render_mode blend_add;

// Soft aura behind the compatibility-owned starpoint reward, now presented as
// a crimson 무혼 flame. It adds a restrained, warm supernatural halo:
//   - Texture-sampled radial gradient (no banding, no per-frame CPU rebuild)
//   - Slow breathing pulse (~1.4Hz scale + intensity)
//   - 3 drifting ember wisps around the halo
//   - Subtle crimson-gold rim band
//   - Drives a `spawn_scale` uniform animated from a Tween on first claim so
//     the drop pops in with a back-eased zoom instead of appearing flat.
//
// Designed to be subtle: blend_add with low alpha output, the halo never
// overpowers the star body inside it. Per-pixel cost stays small because the
// expensive radial falloff is read from the prebaked texture.

uniform sampler2D halo_texture : source_color, filter_linear;
uniform float elapsed = 0.0;
uniform float alpha = 1.0;
uniform float glow_intensity = 1.0;
// Driven by a Godot Tween on slot first-claim: 0.3 -> 1.0 with EASE_OUT_BACK.
// Implemented in-shader as an inward UV scale so we don't fight the slot's
// per-frame size-driven Sprite2D.scale assignment.
uniform float spawn_scale : hint_range(0.1, 1.0) = 1.0;
uniform vec4 halo_color : source_color = vec4(0.92, 0.08, 0.18, 1.0);
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float iridescent_rim_intensity : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float scale = max(0.001, spawn_scale);
	vec2 p = centered / scale;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	// Sample the prebaked radial falloff. Recenter scaled p into [0,1] UV.
	vec2 sample_uv = p * 0.5 + 0.5;
	float base = texture(halo_texture, sample_uv).a;

	// Slow breathing pulse so the halo never feels static.
	float breath = 0.86 + 0.14 * sin(elapsed * 2.2);

	// Three ember wisps drift around the soul flame rather than forming the old
	// jewel-like sparkle orbit.
	float spark_total = 0.0;
	if (sparkle_intensity > 0.001) {
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float phase = elapsed * 0.55 + fi * (TAU / 3.0);
			float orbit_r = 0.56 + 0.05 * sin(elapsed * 1.7 + fi * 1.3);
			vec2 sp = vec2(cos(phase) * orbit_r, sin(phase) * orbit_r);
			float d = length(p - sp);
			float twinkle = 0.65 + 0.35 * sin(elapsed * 4.1 + fi * 2.1);
			spark_total += exp(-d * 72.0) * twinkle;
		}
	}

	// Warm rim band around r ~= 0.42. Keep it in the crimson-gold family so the
	// pickup cannot be mistaken for the old rainbow star reward.
	float rim_band = 0.0;
	vec3 rim_rgb = vec3(0.0);
	if (iridescent_rim_intensity > 0.001) {
		rim_band = exp(-pow((r - 0.42) * 5.5, 2.0));
		float heat = 0.5 + 0.5 * sin(elapsed * 1.35 + r * 4.0);
		rim_rgb = mix(halo_color.rgb, vec3(1.0, 0.58, 0.16), heat * 0.42);
	}

	vec3 col = halo_color.rgb * base * breath;
	col += rim_rgb * rim_band * iridescent_rim_intensity * 0.25;
	col += vec3(1.0, 0.72, 0.30) * spark_total * sparkle_intensity;

	float total_alpha = (
		base * breath
		+ rim_band * iridescent_rim_intensity * 0.18
		+ spark_total * sparkle_intensity * 0.55
	) * alpha * glow_intensity;

	COLOR = vec4(col, total_alpha) * COLOR.a;
}
