shader_type canvas_item;
render_mode blend_mix;

// Compatibility resource path for the reward now presented to players as
// 무혼. One quad renders an upright crimson soul flame with a warm inner core;
// there is deliberately no star polygon or lens-flare cross in this shader.

uniform float elapsed = 0.0;
uniform float alpha = 1.0;
uniform float glow_intensity = 1.0;
// Runtime drop rotation remains a stable compatibility field. Here it is used
// as a per-drop phase so the flame sways without rotating away from upright.
uniform float rotation = 0.0;
uniform float size_norm : hint_range(0.05, 0.5) = 0.25;
uniform vec4 glow_color : source_color = vec4(0.92, 0.08, 0.18, 1.0);
uniform vec4 fill_color : source_color = vec4(0.68, 0.015, 0.07, 1.0);
uniform vec4 mid_color : source_color = vec4(0.98, 0.18, 0.055, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.70, 1.0);
// Bonus drops keep a restrained cyan contour pulse while retaining the same
// crimson 무혼 body, so the bonus reads clearly without becoming a new object.
uniform float detector_shimmer_intensity : hint_range(0.0, 1.0) = 0.0;


// Pointed-at-the-top, rounded-at-the-base flame profile. `q` uses local flame
// radii, with y=-1.15 at the crown and y=0.92 at the lower tip.
float flame_profile_sdf(vec2 q) {
	float top = -1.15;
	float shoulder = 0.10;
	float bottom = 0.92;
	float width = 0.0;
	if (q.y < shoulder) {
		float t = clamp((q.y - top) / (shoulder - top), 0.0, 1.0);
		width = 0.70 * pow(t, 0.58);
	} else {
		float t = clamp((q.y - shoulder) / (bottom - shoulder), 0.0, 1.0);
		width = 0.70 * sqrt(max(0.0, 1.0 - t * t));
	}
	// A small asymmetric fold prevents the silhouette from reading as a plain
	// water drop while preserving a bold shape at the 12px gameplay radius.
	width *= 1.0 + 0.055 * sin(q.y * 8.0 + 0.7);
	float horizontal = abs(q.x) - width;
	float vertical = max(top - q.y, q.y - bottom);
	return max(horizontal, vertical);
}


float soul_flame_sdf(vec2 p, float radius, float phase) {
	vec2 q = p / max(radius, 0.0001);
	float upper_weight = pow(clamp((-q.y + 0.18) / 1.35, 0.0, 1.0), 2.0);
	q.x += sin(elapsed * 2.8 + phase) * 0.10 * upper_weight;
	float main_flame = flame_profile_sdf(q);

	// Split crown: a smaller side tongue joins the body but keeps its own tip.
	vec2 side_q = q - vec2(0.34, -0.10);
	side_q /= vec2(0.54, 0.70);
	float side_flame = flame_profile_sdf(side_q) * 0.54;
	return min(main_flame, side_flame) * radius;
}


float soul_fold_mask(vec2 p, float radius, float phase) {
	vec2 q = p / max(radius, 0.0001);
	float center_x = 0.11 + (q.y + 0.12) * 0.15;
	center_x += sin(elapsed * 1.9 + phase) * 0.018;
	float line = abs(q.x - center_x);
	float vertical_window = 1.0 - smoothstep(0.24, 0.78, abs(q.y + 0.02));
	return (1.0 - smoothstep(0.025, 0.072, line)) * vertical_window;
}


void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 col = vec3(0.0);
	float total_alpha = 0.0;

	// Four soft crimson aura layers preserve the existing readability radius.
	float glow_alpha_total = alpha * 0.46 * glow_intensity;
	for (int layer = 0; layer < 4; layer++) {
		float glow_radius_norm = size_norm * (4.0 - float(layer) * 0.7);
		float layer_alpha = glow_alpha_total / float(4 - layer);
		float disc = 1.0 - smoothstep(0.0, glow_radius_norm, r);
		col += glow_color.rgb * disc * layer_alpha;
		total_alpha = max(total_alpha, disc * layer_alpha);
	}

	float d = soul_flame_sdf(p, size_norm, rotation);
	float aa = max(fwidth(d), 0.0025);
	float flame_mask = smoothstep(aa, -aa, d);
	float outline_width = size_norm * 0.105;
	float outline_mask = 1.0 - smoothstep(outline_width - aa, outline_width + aa, abs(d));

	// Deep crimson rim toward a hotter lower body. Interior depth prevents the
	// reward from reading as a flat red sticker at close result-screen scale.
	float vertical_heat = clamp((p.y / size_norm + 1.0) * 0.48, 0.0, 1.0);
	float interior_depth = clamp(-d / max(size_norm * 0.62, 0.0001), 0.0, 1.0);
	vec3 body_rgb = mix(fill_color.rgb * 0.54, fill_color.rgb, vertical_heat * 0.55 + interior_depth * 0.45);
	col = mix(col, body_rgb, flame_mask * fill_color.a * alpha);
	total_alpha = max(total_alpha, flame_mask * fill_color.a * alpha);
	col = mix(col, outline_color.rgb, outline_mask * outline_color.a * alpha);
	total_alpha = max(total_alpha, outline_mask * outline_color.a * alpha);

	// A restrained crimson crease plus a vermilion middle flame create a clear
	// three-layer hierarchy: shell -> living flame -> white-gold soul core.
	float fold_mask = soul_fold_mask(p, size_norm, rotation) * flame_mask;
	col = mix(col, fill_color.rgb * 0.28, fold_mask * alpha * 0.44);

	vec2 middle_p = p - vec2(size_norm * 0.015, size_norm * 0.10);
	float middle_d = soul_flame_sdf(middle_p, size_norm * 0.72, rotation + 1.15);
	float middle_mask = smoothstep(aa, -aa, middle_d);
	float middle_heat = clamp((middle_p.y / max(size_norm, 0.0001) + 0.82), 0.0, 1.0);
	vec3 middle_rgb = mix(mid_color.rgb * 0.76, mid_color.rgb, middle_heat * 0.52);
	col = mix(col, middle_rgb, middle_mask * mid_color.a * alpha * 0.96);
	total_alpha = max(total_alpha, middle_mask * mid_color.a * alpha);

	// A third, smaller flame forms the white-gold soul core.
	// 두 성분 모두 size_norm(불꽃 반경) 단위여야 한다. x만 raw 쿼드 단위로 두면
	// GPU 경로가 CPU 폴백보다 1/size_norm 배(=4배) 왼쪽에 심지를 그린다.
	vec2 inner_p = p - vec2(size_norm * -0.04, size_norm * 0.22);
	float inner_d = soul_flame_sdf(inner_p, size_norm * 0.43, rotation + 2.1);
	float inner_mask = smoothstep(aa, -aa, inner_d);
	float inner_heat = clamp((inner_p.y / max(size_norm, 0.0001) + 0.6), 0.0, 1.0);
	vec3 inner_rgb = mix(core_color.rgb, vec3(1.0, 0.76, 0.26), inner_heat * 0.24);
	col = mix(col, inner_rgb, inner_mask * core_color.a * alpha);
	total_alpha = max(total_alpha, inner_mask * core_color.a * alpha);

	vec2 core_delta = p - vec2(size_norm * -0.03, size_norm * 0.30);
	vec2 core_scale = vec2(size_norm * 0.085, size_norm * 0.15);
	float core_metric = length(core_delta / max(core_scale, vec2(0.0001)));
	float core_dot = 1.0 - smoothstep(0.48, 1.0, core_metric);
	float core_alpha = core_dot * alpha * glow_intensity;
	col = mix(col, vec3(1.0, 0.98, 0.86), core_alpha);
	total_alpha = max(total_alpha, core_alpha);

	if (detector_shimmer_intensity > 0.001) {
		float shimmer_band = 1.0 - smoothstep(outline_width * 1.8, outline_width * 3.4, abs(d));
		float pulse = 0.55 + 0.45 * sin(elapsed * 5.4);
		vec3 cyan = vec3(0.42, 0.96, 1.0);
		float shimmer = shimmer_band * pulse * detector_shimmer_intensity;
		col += cyan * shimmer * 0.48;
		total_alpha = max(total_alpha, shimmer * 0.42);
	}

	COLOR = vec4(col, total_alpha) * COLOR.a;
}
