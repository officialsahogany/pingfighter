shader_type canvas_item;
render_mode blend_add;

// Commando firearm HUD acquired-weapon rainbow border overlay.
//
// One additive shader quad sits behind the firearm panel for the brief window
// after a new firearm is acquired (perk unlock OR supply_drop rental). The
// quad covers the panel rect inflated by `outer_glow_extent_px`, and the
// shader paints:
//   * a rainbow border band whose hue rotates around the rect perimeter
//   * a bright "sweep" highlight that travels around the perimeter
//   * 4 corner accent halos that pop brighter than the rest of the border
//   * a soft outer glow that bleeds beyond the panel edge
//
// `intensity` is driven by the weapon controller's HUD highlight timer ratio
// and controls overall opacity; `pop_progress` is the 0..1 tween used for the
// initial pop-in scale; `elapsed` drives the rainbow hue cycle and the sweep
// rotation.

uniform float elapsed = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pop_progress : hint_range(0.0, 1.0) = 1.0;

// Quad spans the panel rect plus an outer glow margin. `panel_half_size_uv`
// is the half-size of the actual panel in UV units (centered on UV 0.5).
uniform vec2 panel_half_size_uv = vec2(0.34, 0.40);
// Border band thickness expressed in UV units. The band lies INSIDE the panel
// rect; pixels outside the panel rect are treated as outer glow.
uniform float border_thickness_uv : hint_range(0.005, 0.20) = 0.045;
// Outer glow extent in UV units beyond the panel rect.
uniform float outer_glow_uv : hint_range(0.0, 0.40) = 0.10;
// Hue rotation speed (cycles per second). Higher = more aggressive rainbow.
uniform float hue_speed = 0.85;
// Sweep speed in cycles per second.
uniform float sweep_speed = 0.55;

uniform vec4 corner_accent_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

vec3 rainbow_color(float phase) {
	vec3 c = hsv_to_rgb(vec3(fract(phase), 0.72, 1.0));
	return c * 0.86 + vec3(0.14);
}

// Returns a 0..1 perimeter parameter for a point on the rectangle boundary,
// starting from the top-right corner and walking clockwise.
float rect_perimeter_param(vec2 q, vec2 half_size) {
	vec2 r = q / half_size;
	float ax = abs(r.x);
	float ay = abs(r.y);
	// Decide which edge q is closest to.
	if (ax > ay) {
		// Right or left edge dominant.
		if (r.x > 0.0) {
			// Right edge: param goes from 0.875 (top-right) through 0.0/1.0 to 0.125 (bottom-right)
			float t = (r.y + 1.0) * 0.5;
			return fract(0.875 + t * 0.25);
		}
		// Left edge: param goes from 0.375 (bottom-left) to 0.625 (top-left)
		float t = (1.0 - r.y) * 0.5;
		return 0.375 + t * 0.25;
	}
	// Top or bottom edge dominant.
	if (r.y < 0.0) {
		// Top edge: param goes from 0.625 (top-left) to 0.875 (top-right)
		float t = (r.x + 1.0) * 0.5;
		return 0.625 + t * 0.25;
	}
	// Bottom edge: param goes from 0.125 (bottom-right) to 0.375 (bottom-left)
	float t = (1.0 - r.x) * 0.5;
	return 0.125 + t * 0.25;
}

void fragment() {
	float intensity_safe = clamp(intensity, 0.0, 1.0);
	float pop_safe = clamp(pop_progress, 0.0, 1.0);
	if (intensity_safe <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Local coordinates centered on quad center, in UV units.
		vec2 p = UV - vec2(0.5, 0.5);
		vec2 abs_p = abs(p);
		vec2 half_size = max(panel_half_size_uv, vec2(0.001));

		// Distance into the rectangle (positive = inside, negative = outside).
		vec2 inside_vec = half_size - abs_p;
		float inside_dist = min(inside_vec.x, inside_vec.y);
		// Distance outside the rectangle (positive = outside, 0 = inside).
		vec2 outside_vec = max(abs_p - half_size, vec2(0.0));
		float outside_dist = length(outside_vec);

		// Snap a perimeter coordinate onto the rect edge for hue / sweep sampling.
		vec2 q = clamp(p, -half_size, half_size);
		// Use the actual perimeter direction (where on the panel edge this pixel
		// is closest to) for stable hue around corners.
		vec2 q_edge;
		if (inside_dist >= 0.0) {
			// Project inside point to the nearest edge.
			vec2 to_edge = half_size - abs_p;
			if (to_edge.x < to_edge.y) {
				q_edge = vec2(sign(p.x) * half_size.x, p.y);
			} else {
				q_edge = vec2(p.x, sign(p.y) * half_size.y);
			}
		} else {
			q_edge = q;
		}
		float perim = rect_perimeter_param(q_edge, half_size);

		// Hue cycles around the perimeter AND drifts with time so the border
		// "spins" continuously, not just as static stripes.
		float hue_phase = fract(perim * 2.0 + elapsed * hue_speed);
		vec3 hue_col = rainbow_color(hue_phase);

		vec3 col = vec3(0.0);
		float total_alpha = 0.0;

		// --- Inner border band (texture-free GPU "texture slice" equivalent) ---
		// Smooth band that lights up only within border_thickness_uv of the rect
		// edge. Inside-only so the panel interior stays uncovered.
		float inner_band = 0.0;
		if (inside_dist >= 0.0 && inside_dist <= border_thickness_uv) {
			// Triangular profile: brightest at the edge, fading toward the inside.
			float t = inside_dist / max(border_thickness_uv, 0.0001);
			inner_band = pow(1.0 - t, 1.4);
		}
		col += hue_col * inner_band * 1.05;
		total_alpha = max(total_alpha, inner_band * 0.85);

		// --- Sweep highlight: bright wedge that travels around the perimeter ---
		float sweep_pos = fract(elapsed * sweep_speed);
		// Two-sided distance on the wrapped perimeter (0..1 loop).
		float perim_d = abs(perim - sweep_pos);
		perim_d = min(perim_d, 1.0 - perim_d);
		float sweep = exp(-perim_d * 22.0);
		float sweep_signal = sweep * (inner_band + 0.18);
		col += mix(hue_col, vec3(1.0), 0.55) * sweep_signal * 1.4;
		total_alpha = max(total_alpha, sweep_signal * 0.95);

		// --- Corner accents: each of the 4 corners pulses brighter ---
		// Corner perimeter params: 0.125, 0.375, 0.625, 0.875
		float corner_strength = 0.0;
		float corners[4] = {0.125, 0.375, 0.625, 0.875};
		for (int i = 0; i < 4; i++) {
			float cd = abs(perim - corners[i]);
			cd = min(cd, 1.0 - cd);
			corner_strength = max(corner_strength, exp(-cd * 26.0));
		}
		float corner_pulse = 0.55 + 0.45 * sin(elapsed * 5.2);
		float corner_signal = corner_strength * inner_band * corner_pulse;
		col += corner_accent_color.rgb * corner_signal * 0.85;
		total_alpha = max(total_alpha, corner_signal * 0.55);

		// --- Outer glow: soft additive bleed past the rect edge ---
		if (outside_dist > 0.0 && outside_dist <= outer_glow_uv) {
			float glow = 1.0 - clamp(outside_dist / max(outer_glow_uv, 0.0001), 0.0, 1.0);
			glow = pow(glow, 1.8);
			col += hue_col * glow * 0.55;
			total_alpha = max(total_alpha, glow * 0.32);
		}

		// Pop-in scale: at pop_progress=0 the border is barely visible; at 1 it
		// reaches full strength. Uses a smoothstep curve for a tween-style ease.
		float pop = smoothstep(0.0, 1.0, pop_safe);
		float final_alpha = total_alpha * intensity_safe * (0.30 + 0.70 * pop);
		vec3 final_col = col * intensity_safe * (0.50 + 0.50 * pop);

		COLOR = vec4(final_col * final_alpha, final_alpha) * COLOR.a;
	}
}
