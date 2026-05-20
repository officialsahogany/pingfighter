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
// Iridescent shimmer cycles the star body fill through nearby hues so the
// normal pink drops read as "multicolor shining" rather than flat solid pink.
// 0 disables (used by stages that want a pure single-color fill).
uniform float iridescent_shimmer_intensity : hint_range(0.0, 1.0) = 0.0;
// Cross-shaped sparkle rays around the star: 4 cardinal + 4 diagonal beams of
// light that slowly rotate, pulse in brightness, and cycle through rainbow
// hues. Gives the "shining jewel / lens flare" feel that a flat glow halo
// alone cannot deliver. 0 disables (gold-palette stages keep it off).
uniform float sparkle_ray_intensity : hint_range(0.0, 1.0) = 0.0;

// N-tip star SDF based on distance to actual polygon edges (tip->valley line
// segments). Returns negative inside the star, positive outside. The earlier
// version interpolated the boundary radius linearly in polar coordinates,
// which smoothly curved the edge and produced rounded petal shapes instead
// of straight-edged star tips. This version folds the point into one
// half-sector centered on a tip, mirrors it over the sector's bisector, and
// measures the perpendicular distance to the tip->valley line segment —
// matching what `draw_colored_polygon` renders on the CPU.
float star_sdf(vec2 p, float r_outer, float r_inner, float star_rotation, int tips) {
	int n = max(3, tips);
	float sector = TAU / float(n);
	float half_sector = sector * 0.5;

	// Rotate p so the first tip aligns with the positive x-axis.
	float c = cos(-star_rotation);
	float s = sin(-star_rotation);
	vec2 q = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

	// Fold theta into the nearest tip-centered sector, then mirror y so we
	// only have to consider the upper half (tip at right, valley up-right).
	float r = length(q);
	float theta = atan(q.y, q.x);
	float local_theta = mod(theta + half_sector, sector) - half_sector;
	q = vec2(r * cos(local_theta), abs(r * sin(local_theta)));

	// Edge segment from tip (r_outer, 0) to the upper valley vertex.
	vec2 tip = vec2(r_outer, 0.0);
	vec2 valley = vec2(r_inner * cos(half_sector), r_inner * sin(half_sector));
	vec2 edge = valley - tip;
	float edge_len_sq = max(0.000001, dot(edge, edge));
	float h = clamp(dot(q - tip, edge) / edge_len_sq, 0.0, 1.0);
	vec2 closest_pt = tip + edge * h;
	float dist = length(q - closest_pt);

	// Outward-pointing normal of the tip->valley edge: rotate edge -90 degrees.
	// q is OUTSIDE the star when dot(q - tip, normal) > 0, INSIDE when < 0.
	vec2 normal = vec2(edge.y, -edge.x);
	float side = dot(q - tip, normal);
	return dist * sign(side);
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

	// Iridescent multi-frequency hue shimmer modulates the base fill toward
	// adjacent hues so the pink drop reads as "multicolor shining" instead of
	// flat solid pink. The phase combines time + 2D position so each pixel
	// inside the star catches the rainbow at a slightly different moment.
	vec3 fill_rgb = fill_color.rgb;
	if (iridescent_shimmer_intensity > 0.001 && fill_mask > 0.01) {
		float shimmer_phase = elapsed * 1.6 + p.x * 7.0 + p.y * 5.0;
		float h = fract(shimmer_phase * 0.16);
		vec3 rainbow = vec3(
			0.5 + 0.5 * cos(h * TAU + 0.0),
			0.5 + 0.5 * cos(h * TAU + 2.0944),
			0.5 + 0.5 * cos(h * TAU + 4.1888)
		);
		// Gentle 38% blend keeps the dominant pink identity while letting the
		// multicolor highlights cycle visibly across the body.
		fill_rgb = mix(fill_color.rgb, rainbow, iridescent_shimmer_intensity * 0.38);
	}
	col = mix(col, fill_rgb, fill_mask * fill_color.a * alpha);
	total_alpha = max(total_alpha, fill_mask * fill_color.a * alpha);

	// Outline band traces the polygon perimeter. The original CPU draw uses
	// `draw_line(points, color, 3.0)` for Stage 1 / `draw_polyline(..., 2.5)`
	// for Stage 2/3/4 (close enough to share one width). On a ~96px quad
	// (size 12 * QUAD_SIZE_FACTOR=4) that's ~1.5 px half-width = 0.016
	// normalized. We use 2*outline_half_width = ~3.1 px total visible width.
	// Going thicker than this (e.g. the earlier 0.032 trial) made the SDF's
	// natural corner rounding visible as a 4-leaf clover / petal shape, so
	// stay close to the CPU's original line width.
	float outline_half_width = 0.016;
	float outline_aa = 0.003;
	float outline_mask = 1.0 - smoothstep(outline_half_width - outline_aa, outline_half_width + outline_aa, abs(d));
	col = mix(col, outline_color.rgb, outline_mask * outline_color.a * alpha);
	total_alpha = max(total_alpha, outline_mask * outline_color.a * alpha);

	// --- Central white dot ---
	float center_dot_radius = size_norm * 0.18;
	float dot_mask = 1.0 - smoothstep(center_dot_radius * 0.6, center_dot_radius, r);
	float dot_alpha = alpha * glow_intensity * dot_mask;
	col = mix(col, vec3(1.0), dot_alpha);
	total_alpha = max(total_alpha, dot_alpha);

	// --- Cross-shaped sparkle rays (lens flare "shining" highlight) ---
	// 4 cardinal + 4 diagonal rays radiate from the star center, slowly rotate,
	// pulse in brightness, and cycle through rainbow hues. This is what makes
	// the drop read as "shining jewel" rather than just "softly glowing star."
	// Each ray is an exp() falloff: tight perpendicular = thin line, loose
	// along-ray = long extension. Drawn additively on top of everything else
	// (rays should brighten over the body, not be hidden by it).
	if (sparkle_ray_intensity > 0.001) {
		float ray_rot = elapsed * 0.45;
		float rc = cos(ray_rot);
		float rs = sin(ray_rot);
		vec2 pr = vec2(p.x * rc + p.y * rs, -p.x * rs + p.y * rc);
		float perp_falloff = 220.0;
		float length_falloff = 3.2;
		float ray_h = exp(-abs(pr.y) * perp_falloff) * exp(-abs(pr.x) * length_falloff);
		float ray_v = exp(-abs(pr.x) * perp_falloff) * exp(-abs(pr.y) * length_falloff);
		vec2 pd = vec2(pr.x + pr.y, -pr.x + pr.y) * 0.70710678;
		float ray_d1 = exp(-abs(pd.y) * perp_falloff * 1.35) * exp(-abs(pd.x) * length_falloff * 1.55);
		float ray_d2 = exp(-abs(pd.x) * perp_falloff * 1.35) * exp(-abs(pd.y) * length_falloff * 1.55);
		float total_ray = (ray_h + ray_v) * 0.72 + (ray_d1 + ray_d2) * 0.42;
		float pulse = 0.55 + 0.45 * sin(elapsed * 2.7);
		float hue = fract(elapsed * 0.32);
		vec3 ray_color = vec3(
			0.6 + 0.4 * cos(hue * TAU + 0.0),
			0.6 + 0.4 * cos(hue * TAU + 2.0944),
			0.6 + 0.4 * cos(hue * TAU + 4.1888)
		);
		// Boost ray center toward white-hot so the highlight pops.
		vec3 ray_rgb = mix(ray_color, vec3(1.0), clamp(total_ray * 1.5, 0.0, 1.0));
		float ray_signal = total_ray * pulse * sparkle_ray_intensity * alpha;
		col += ray_rgb * ray_signal;
		total_alpha = max(total_alpha, ray_signal * 0.7);
	}

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
