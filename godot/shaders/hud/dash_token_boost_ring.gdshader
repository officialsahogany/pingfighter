shader_type canvas_item;
render_mode blend_add;

// Dash orb boost-state overlay shader.
//
// One quad per dash orb replaces three CPU draw paths that were heavy in the
// previous canvas.draw_* loops:
//   * sector_intensity   -> _draw_boost_charging_dash_sector (pillar_dash_token_fill_renderer.gd)
//   * rainbow_intensity  -> _draw_boost_charging_rainbow_ring (pillar_dash_orb_renderer.gd)
//   * half_ready_intensity -> "HALF" label area readiness pulse glow
//
// The quad is sized to orb_radius * QUAD_RADIUS_FACTOR (= 1.5) so it covers
// the orb body plus the outer rainbow ring band. Inside the shader UV is
// mapped to centered [-1..1]; orb_radius_norm marks the orb body edge and
// outer_extent_norm marks the rainbow ring outer edge (= 1.0).

uniform float elapsed = 0.0;
uniform float orb_radius_norm : hint_range(0.1, 1.0) = 0.6667;
uniform float outer_extent_norm : hint_range(0.5, 1.0) = 1.0;

uniform float sector_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float sector_progress : hint_range(0.0, 1.0) = 0.0;
uniform float sector_start_angle = 0.0;
uniform float sector_end_angle = 6.2831853;

uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float rainbow_rotation = 0.0;

uniform float half_ready_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_token_color : source_color = vec4(0.98, 0.46, 0.36, 1.0);

// Plasma-ball state: replaces the sparse CPU recovery sparks / chain arcs
// while the dash orb is in dash-active / recovery / stun. Reads as an electric
// core + wandering tendrils + soft inner corona.
uniform float plasma_ball_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 plasma_core_color : source_color = vec4(1.0, 0.86, 1.0, 1.0);
uniform vec4 plasma_tendril_color : source_color = vec4(0.96, 0.40, 1.0, 1.0);
uniform int plasma_tendril_count : hint_range(2, 8) = 5;

// TAU and PI are provided as built-in constants by the Godot shader language;
// redefining them would shadow the built-ins and fail compilation.

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

vec3 rainbow_color(float phase) {
	vec3 c = hsv_to_rgb(vec3(fract(phase), 0.62, 1.0));
	return c * 0.84 + vec3(0.16);
}

// 2D hash used by the plasma ball block to resample tendril endpoints / kinks
// on a discrete time grid. Discrete (per-cycle) hash sampling is what gives the
// bolts that "snap to a new shape" look instead of slow sinusoidal drift.
float hash21(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

// Distance from point p to segment a->b. Guards a==b with an epsilon so the
// zero-length collapse from a hash that randomly aligned all three control
// points doesn't divide by zero.
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float ab_len_sq = max(0.00001, dot(ab, ab));
	float t = clamp(dot(p - a, ab) / ab_len_sq, 0.0, 1.0);
	return length(a + ab * t - p);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 col = vec3(0.0);
	float total_alpha = 0.0;

	// Outside the orb's outer ring band - skip all overlay work. Godot's
	// fragment processor does not allow `return`, so we gate the rest of the
	// shader with an `if` block and write the cleared COLOR at the end.
	if (r <= outer_extent_norm + 0.02) {

	float a = atan(p.y, p.x);
	if (a < 0.0) {
		a += TAU;
	}

	// --- Sector boost fill: replaces _draw_boost_charging_dash_sector ---
	if (sector_intensity > 0.001) {
		// Normalize current angle to [0,1] within sector
		float sector_span = max(0.0001, sector_end_angle - sector_start_angle);
		float ang_norm = (a - sector_start_angle) / sector_span;
		// Handle wrap if a is just past TAU relative to start
		if (ang_norm < 0.0) {
			ang_norm += TAU / sector_span;
		}
		float in_sector = step(0.0, ang_norm) * step(ang_norm, 1.0);
		float in_progress = step(ang_norm, sector_progress);
		// Sector covers from orb_radius_norm * 0.18 to orb_radius_norm
		float inner_edge = orb_radius_norm * 0.18;
		float in_radius = step(inner_edge, r) * step(r, orb_radius_norm);

		float fill = in_sector * in_progress * in_radius;
		float hue = fract(elapsed * 0.45 + ang_norm * 0.32);
		vec3 hue_col = rainbow_color(hue);
		col += hue_col * fill * 0.78;
		total_alpha = max(total_alpha, fill * sector_intensity * 0.85);

		// Leading-edge pulse along the charging frontier
		float lead_dist = abs(ang_norm - sector_progress);
		float lead = exp(-lead_dist * 18.0) * in_sector * in_radius;
		col += hue_col * lead * 1.6;
		total_alpha = max(total_alpha, lead * sector_intensity);

		// Inner-edge soft glow so the sector reads from the orb center
		float inner_glow_band = smoothstep(orb_radius_norm * 0.6, inner_edge, r) * in_sector * in_progress;
		col += base_token_color.rgb * inner_glow_band * 0.22;
		total_alpha = max(total_alpha, inner_glow_band * sector_intensity * 0.22);
	}

	// --- Rainbow refund ring: replaces _draw_boost_charging_rainbow_ring ---
	if (rainbow_intensity > 0.001) {
		// Ring band lives between orb_radius_norm (inner) and outer_extent_norm (outer)
		float band_thickness = (outer_extent_norm - orb_radius_norm) * 0.6;
		float band_mid = orb_radius_norm + band_thickness * 0.4;
		float band = 1.0 - clamp(abs(r - band_mid) / band_thickness, 0.0, 1.0);
		band = smoothstep(0.0, 1.0, band);

		// 3 rotating arc spots equally spaced
		float arc_phase = a - rainbow_rotation;
		float arc_a = fract(arc_phase / TAU);
		float arc_strength = max(
			max(
				exp(-pow((arc_a - 0.0) * 7.5, 2.0)),
				exp(-pow((arc_a - 0.333) * 7.5, 2.0))
			),
			max(
				exp(-pow((arc_a - 0.666) * 7.5, 2.0)),
				exp(-pow((arc_a - 1.0) * 7.5, 2.0))
			)
		);

		float hue = fract(elapsed * 0.42 + arc_a * 1.4);
		vec3 hue_col = rainbow_color(hue);
		float arc_signal = band * arc_strength;
		col += hue_col * arc_signal * 0.92;
		total_alpha = max(total_alpha, arc_signal * rainbow_intensity * 0.78);

		// Outer halo (soft glow falling off past the ring band)
		float halo = smoothstep(outer_extent_norm, band_mid, r) * (1.0 - smoothstep(orb_radius_norm * 0.92, orb_radius_norm * 0.98, r));
		col += hue_col * halo * 0.34;
		total_alpha = max(total_alpha, halo * rainbow_intensity * 0.20);
	}

	// --- Half-ready inner pulse: signals "next dash will be free" readiness ---
	if (half_ready_intensity > 0.001) {
		float pulse = 0.5 + 0.5 * sin(elapsed * 6.2);
		float inner_glow = smoothstep(orb_radius_norm * 0.92, 0.0, r);
		vec3 hot = mix(base_token_color.rgb, vec3(1.0, 0.82, 0.62), 0.55);
		col += hot * inner_glow * (0.34 + 0.22 * pulse);
		total_alpha = max(total_alpha, inner_glow * half_ready_intensity * (0.30 + 0.18 * pulse));
	}

	// --- Plasma ball: replaces CPU recovery sparks / chain arcs ---
	// Real plasma globe arcs feel electric because the path itself is jagged
	// (not a single straight line) AND the path resets to a new random shape at
	// high frequency. Each tendril here is a 3-segment zig-zag whose endpoint
	// + two perpendicular kink control points re-roll on every ~250ms cycle.
	// On top of that, brightness modulates at ~47Hz and each bolt fades in /
	// out across its cycle via `sin(life * PI)`. The combination reads as
	// "crackling electricity" instead of a slow sinusoidal wave.
	if (plasma_ball_intensity > 0.001 && r < orb_radius_norm) {
		float core_radius = 0.075 + 0.020 * sin(elapsed * 5.4);
		float core = exp(-(r * r) / (core_radius * core_radius));
		col += plasma_core_color.rgb * core;
		total_alpha = max(total_alpha, core * plasma_ball_intensity);

		// Soft inner corona keeps the orb interior reading as plasma-filled
		// between bolts so empty frames don't look hollow.
		float corona = smoothstep(orb_radius_norm * 0.96, orb_radius_norm * 0.55, r);
		col += plasma_tendril_color.rgb * corona * 0.10;
		total_alpha = max(total_alpha, corona * plasma_ball_intensity * 0.14);

		int tendril_count = max(2, min(plasma_tendril_count, 8));
		float n_inv = 1.0 / float(tendril_count);
		float spin = elapsed * 0.15;
		for (int i = 0; i < 8; i++) {
			if (i >= tendril_count) {
				break;
			}
			float fi = float(i);
			// Lifecycle: each tendril lives ~250ms, phase-offset per-i so they
			// don't all flicker on the same frame.
			float cycle_pos = elapsed * 4.0 + fi * 0.37;
			float life = fract(cycle_pos);
			float life_alpha = sin(life * PI);
			float cycle_seed = floor(cycle_pos);

			// Endpoint re-rolls each cycle inside the tendril's angular wedge.
			float angle_base = fi * (TAU * n_inv);
			float angle_rand = hash21(vec2(fi, cycle_seed));
			float angle = angle_base + (angle_rand - 0.5) * 1.5 + spin;
			float endpoint_len = orb_radius_norm * (0.74 + hash21(vec2(fi, cycle_seed + 1.7)) * 0.20);
			vec2 ep = vec2(cos(angle), sin(angle)) * endpoint_len;

			// Two perpendicular kink offsets make the path zig-zag rather than
			// staying as a single straight line from origin to endpoint.
			vec2 perp = vec2(-sin(angle), cos(angle));
			float kink1 = (hash21(vec2(fi * 1.31, cycle_seed + 2.3)) - 0.5) * orb_radius_norm * 0.55;
			float kink2 = (hash21(vec2(fi * 1.31, cycle_seed + 4.1)) - 0.5) * orb_radius_norm * 0.55;
			vec2 cp1 = ep * 0.33 + perp * kink1;
			vec2 cp2 = ep * 0.66 + perp * kink2;

			// Minimum distance across the 3-segment polyline.
			float d1 = seg_dist(p, vec2(0.0, 0.0), cp1);
			float d2 = seg_dist(p, cp1, cp2);
			float d3 = seg_dist(p, cp2, ep);
			float d = min(min(d1, d2), d3);

			// High-frequency brightness flicker modulated by the lifecycle fade.
			float flicker = 0.50 + 0.50 * sin(elapsed * 47.0 + fi * 11.0);
			flicker = mix(0.30, 1.0, flicker) * life_alpha;

			// Sharp thin tendril width with per-cycle random width variation so
			// some bolts read fat and some read like fine threads.
			float width = 0.013 + 0.006 * hash21(vec2(fi, cycle_seed + 5.7));
			float tendril = exp(-(d * d) / (width * width));

			// Brightest pixels (near the bolt centerline) read white-hot, edges
			// fade to the tendril hue. Avoids flat magenta lines.
			float bright_norm = clamp(tendril * 1.5, 0.0, 1.0);
			vec3 tip_col = mix(plasma_tendril_color.rgb, plasma_core_color.rgb, bright_norm);
			col += tip_col * tendril * flicker * 1.2;
			total_alpha = max(total_alpha, tendril * plasma_ball_intensity * flicker);
		}
	}

	}  // end of `r <= outer_extent_norm + 0.02` block

	COLOR = vec4(col * total_alpha, total_alpha) * COLOR.a;
}
