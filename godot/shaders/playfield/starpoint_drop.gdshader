shader_type canvas_item;
render_mode blend_mix;

// Common starpoint-drop overlay. Replaces four near-identical CPU loops in
// stage1_balloon_event.gd, stage2_pillar_obstacle_visual_renderer.gd,
// stage3_menhera_skill_effect_renderer.gd, and stage4_bird_event.gd.
//
// One ColorRect / Sprite2D quad per active drop. UV is mapped to centered
// [-1, 1]; size_norm sets where the star body's outer tip radius sits inside
// that range. The quad's half-size in world units should be `size * 4.0` so
// the outermost glow layer (size * 4.0) still fits inside the quad.

uniform float elapsed = 0.0;
uniform float alpha = 1.0;
uniform float glow_intensity = 1.0;
uniform float rotation = 0.0;
uniform float size_norm : hint_range(0.05, 0.5) = 0.25;
// Inner radius ratio for the star's valley vertices (CPU code uses 0.5).
uniform float inner_radius_ratio : hint_range(0.1, 0.9) = 0.5;
// Number of star tips. Stage 1's original drop uses 4-pointed sparkles
// (STARPOINT_DROP_STAR_POINTS = 8 vertices = 4 tips), Stage 2/3/4 use 5-pointed
// stars (10 vertices = 5 tips). The shader keeps this as a uniform so each
// stage's host call selects its own original shape instead of being forced
// onto a single hardcoded 5-tip layout.
uniform int star_tip_count : hint_range(3, 8) = 5;
// Palette: glow_color (used for the 4-layer outer glow halo), fill_color
// (interior of the 5-pointed star), outline_color (star perimeter band).
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.74, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
// Star detector bonus drops shimmer with an extra cyan rim to read as the
// special variant; intensity=0 disables the shimmer for normal drops.
uniform float detector_shimmer_intensity : hint_range(0.0, 1.0) = 0.0;

// N-tip star SDF using polar reduction. Returns negative inside the star,
// positive outside. The boundary is piecewise linear between consecutive
// tip / valley vertices (2*tips vertices alternating outer/inner radius).
float star_sdf(vec2 p, float r_outer, float r_inner, float star_rotation, int tips) {
	float theta = atan(p.y, p.x) - star_rotation;
	float sector = TAU / float(max(3, tips));
	float local_theta = mod(theta + sector * 0.5, sector) - sector * 0.5;
	float t = abs(local_theta) / (sector * 0.5);
	float boundary = mix(r_outer, r_inner, t);
	return length(p) - boundary;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 col = vec3(0.0);
	float total_alpha = 0.0;

	// --- 4-layer outer glow halo ---
	// Mirrors the original CPU loop: `size * (4.0 - i * 0.7)` outer radii with
	// alpha = glow_alpha / (4 - i). Stage 1 had this collapsed to 1 layer
	// under an optimization constant; running it from the shader restores the
	// full 4-layer look across every stage at near-zero CPU cost.
	float glow_alpha_total = alpha * 0.5 * glow_intensity;
	for (int layer = 0; layer < 4; layer++) {
		float glow_radius_norm = size_norm * (4.0 - float(layer) * 0.7);
		float layer_alpha = glow_alpha_total / float(4 - layer);
		// Soft fall-off from the outer radius inward; smoothstep matches the
		// CPU draw_circle's anti-aliased disc.
		float disc = 1.0 - smoothstep(glow_radius_norm * 0.0, glow_radius_norm, r);
		col += glow_color.rgb * disc * layer_alpha;
		total_alpha = max(total_alpha, disc * layer_alpha);
	}

	// --- N-tip star body ---
	float r_outer = size_norm;
	float r_inner = size_norm * inner_radius_ratio;
	float d = star_sdf(p, r_outer, r_inner, rotation, star_tip_count);
	// Anti-aliased fill (smoothstep narrows on smaller stars; the 0.012 band
	// is calibrated against a 12px-radius drop at 1x scale).
	float fill_mask = smoothstep(0.012, -0.012, d);
	col = mix(col, fill_color.rgb, fill_mask * fill_color.a * alpha);
	total_alpha = max(total_alpha, fill_mask * fill_color.a * alpha);

	// Outline band at |sdf| ~ outline_thickness. Increased from 0.020 so the
	// yellow rim reads clearly at the 12px scale and the star no longer looks
	// like a flat red blob (the CPU draw_polyline used a 2.5px solid line; at
	// the GPU smoothstep falloff a 0.032 band gives a comparable visual width).
	float outline_thickness = 0.032;
	float outline_mask = smoothstep(outline_thickness, outline_thickness * 0.3, abs(d));
	col = mix(col, outline_color.rgb, outline_mask * outline_color.a * alpha);
	total_alpha = max(total_alpha, outline_mask * outline_color.a * alpha);

	// --- Central white dot ---
	float center_dot_radius = size_norm * 0.18;
	float dot_mask = 1.0 - smoothstep(center_dot_radius * 0.6, center_dot_radius, r);
	float dot_alpha = alpha * glow_intensity * dot_mask;
	col = mix(col, vec3(1.0), dot_alpha);
	total_alpha = max(total_alpha, dot_alpha);

	// --- Star detector shimmer (optional) ---
	// Adds a cyan rim that pulses at ~5Hz over the star outline. Only fires
	// when detector_shimmer_intensity > 0 so normal drops pay nothing extra.
	if (detector_shimmer_intensity > 0.001) {
		float shimmer_band = smoothstep(0.04, 0.0, abs(d));
		float pulse = 0.55 + 0.45 * sin(elapsed * 5.4);
		vec3 cyan = vec3(0.42, 0.96, 1.0);
		col += cyan * shimmer_band * pulse * detector_shimmer_intensity * 0.6;
		total_alpha = max(total_alpha, shimmer_band * pulse * detector_shimmer_intensity * 0.5);
	}

	COLOR = vec4(col, total_alpha) * COLOR.a;
}
