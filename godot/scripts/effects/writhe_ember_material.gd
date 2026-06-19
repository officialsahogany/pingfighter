extends Object
class_name WritheEmberMaterial

const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity = 1.0;
uniform float distort_strength : hint_range(0.0, 0.15) = 0.055;
uniform float lateral_strength : hint_range(0.0, 0.15) = 0.045;
uniform float jitter_strength : hint_range(0.0, 0.04) = 0.014;
uniform float bolt_flow_speed = 4.5;
uniform float flicker_speed = 9.0;
uniform float pulse_speed = 1.6;
uniform float breath_amp = 0.18;
uniform vec4 hot_color : source_color = vec4(1.0, 0.40, 0.78, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.74, 0.30, 1.0);
uniform vec4 amethyst_color : source_color = vec4(0.84, 0.52, 1.00, 1.0);

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
			dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)),
			u.x
		),
		mix(
			dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)),
			u.x
		),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 center = uv - vec2(0.5);
	float dist = length(center);
	vec2 radial = vec2(0.0, -1.0);
	if (dist > 0.001) {
		radial = center / dist;
	}
	vec2 perp = vec2(-radial.y, radial.x);
	float angle = atan(center.y, center.x);

	vec2 base = vec2(
		fbm(uv * 4.5 + vec2(elapsed * 0.65, 0.0)),
		fbm(uv * 4.5 + vec2(0.0, elapsed * 0.78))
	);
	float lat = fbm(vec2(dist * 14.0 + angle * 3.0, elapsed * 2.2));
	vec2 lat_offset = perp * (lat * 2.0 - 1.0) * lateral_strength;
	vec2 jit = vec2(
		vnoise(uv * 28.0 + vec2(elapsed * 7.0, 0.0)),
		vnoise(uv * 28.0 + vec2(0.0, elapsed * 8.4))
	);
	vec2 duv = uv + base * distort_strength + lat_offset + jit * jitter_strength;
	duv = clamp(duv, vec2(0.0), vec2(1.0));

	float chroma = 0.005 * (0.5 + 0.5 * sin(elapsed * 3.2));
	vec4 red_sample = texture(TEXTURE, clamp(duv + radial * chroma, vec2(0.0), vec2(1.0)));
	vec4 mid_sample = texture(TEXTURE, duv);
	vec4 blue_sample = texture(TEXTURE, clamp(duv - radial * chroma, vec2(0.0), vec2(1.0)));
	float r = red_sample.r;
	float g = mid_sample.g;
	float b = blue_sample.b;
	float a = mid_sample.a;
	vec3 col = vec3(r, g, b);
	float brightness = max(max(col.r, col.g), col.b);

	float fp = dist * 24.0 - elapsed * bolt_flow_speed;
	float flow = pow(sin(fp) * 0.5 + 0.5, 6.0);
	float flow2 = pow(sin(fp * 0.55 + 1.7) * 0.5 + 0.5, 8.0);

	float sector = floor(angle * 8.0 / 3.14159);
	float flick_rand = vnoise(vec2(sector, floor(elapsed * flicker_speed)));
	float flicker = step(0.55, flick_rand) * 0.6 + 0.4;

	float cmix = vnoise(vec2(elapsed * pulse_speed, dist * 6.0)) * 0.5 + 0.5;
	vec3 flick_col = mix(hot_color.rgb, ember_color.rgb, cmix);
	col = mix(col, flick_col * brightness, 0.50);
	col = mix(col, amethyst_color.rgb * brightness * 0.55, (1.0 - cmix) * 0.20);
	col += (flow * 0.55 + flow2 * 0.35) * brightness * flicker * ember_color.rgb;
	col += flow * 0.30 * brightness * vec3(1.0);

	float breath = 1.0 - breath_amp + breath_amp * sin(elapsed * 2.1);
	COLOR = vec4(col * intensity * COLOR.rgb, a * breath * COLOR.a);
}
"""

const PRESETS := {
	"chaos_cracks": {
		"distort_strength": 0.055,
		"lateral_strength": 0.045,
		"jitter_strength": 0.014,
		"bolt_flow_speed": 4.5,
		"flicker_speed": 9.0,
		"pulse_speed": 1.6,
		"breath_amp": 0.18,
		"hot_color": Color(1.0, 0.40, 0.78, 1.0),
		"ember_color": Color(1.0, 0.74, 0.30, 1.0),
		"amethyst_color": Color(0.84, 0.52, 1.00, 1.0),
	},
	"chaos_cracks_enraged": {
		"distort_strength": 0.080,
		"lateral_strength": 0.065,
		"jitter_strength": 0.022,
		"bolt_flow_speed": 6.0,
		"flicker_speed": 12.0,
		"pulse_speed": 2.4,
		"breath_amp": 0.28,
		"hot_color": Color(1.0, 0.40, 0.78, 1.0),
		"ember_color": Color(1.0, 0.74, 0.30, 1.0),
		"amethyst_color": Color(0.84, 0.52, 1.00, 1.0),
	},
	"meditation_mandala": {
		"distort_strength": 0.025,
		"lateral_strength": 0.020,
		"jitter_strength": 0.008,
		"bolt_flow_speed": 0.6,
		"flicker_speed": 4.0,
		"pulse_speed": 0.8,
		"breath_amp": 0.12,
		"hot_color": Color(1.0, 0.84, 0.42, 1.0),
		"ember_color": Color(1.0, 0.92, 0.62, 1.0),
		"amethyst_color": Color(0.65, 0.50, 0.85, 1.0),
	},
	# Plaza VR shop coin-pile trade affordance. Warm, soft, and slow so it reads
	# as a premium UI aura instead of a hard warning ring.
	"shop_coin_trade_aura": {
		"distort_strength": 0.022,
		"lateral_strength": 0.018,
		"jitter_strength": 0.007,
		"bolt_flow_speed": 0.7,
		"flicker_speed": 4.0,
		"pulse_speed": 0.9,
		"breath_amp": 0.12,
		"hot_color": Color(1.0, 0.86, 0.42, 1.0),
		"ember_color": Color(1.0, 0.92, 0.60, 1.0),
		"amethyst_color": Color(0.30, 0.85, 0.95, 1.0),
	},
	# Short click envelope for the same shop coin trade FX. Same shader family,
	# only stronger flow/flicker uniforms.
	"shop_coin_trade_burst": {
		"distort_strength": 0.036,
		"lateral_strength": 0.030,
		"jitter_strength": 0.012,
		"bolt_flow_speed": 2.2,
		"flicker_speed": 8.5,
		"pulse_speed": 1.8,
		"breath_amp": 0.18,
		"hot_color": Color(1.0, 0.94, 0.62, 1.0),
		"ember_color": Color(1.0, 0.72, 0.24, 1.0),
		"amethyst_color": Color(0.26, 0.95, 1.0, 1.0),
	},
	"magnetic_lattice": {
		"distort_strength": 0.045,
		"lateral_strength": 0.040,
		"jitter_strength": 0.018,
		"bolt_flow_speed": 1.8,
		"flicker_speed": 11.0,
		"pulse_speed": 2.5,
		"breath_amp": 0.22,
		"hot_color": Color(0.0, 1.0, 1.0, 1.0),
		"ember_color": Color(0.5, 0.7, 1.0, 1.0),
		"amethyst_color": Color(0.58, 0.44, 0.86, 1.0),
	},
	"magnetic_lattice_enraged": {
		"distort_strength": 0.065,
		"lateral_strength": 0.060,
		"jitter_strength": 0.022,
		"bolt_flow_speed": 2.7,
		"flicker_speed": 14.0,
		"pulse_speed": 3.5,
		"breath_amp": 0.30,
		"hot_color": Color(0.0, 1.0, 1.0, 1.0),
		"ember_color": Color(1.0, 0.45, 0.55, 1.0),
		"amethyst_color": Color(0.58, 0.44, 0.86, 1.0),
	},
	"magnetic_charge_glyph": {
		"distort_strength": 0.020,
		"lateral_strength": 0.018,
		"jitter_strength": 0.010,
		"bolt_flow_speed": 1.0,
		"flicker_speed": 7.0,
		"pulse_speed": 1.2,
		"breath_amp": 0.15,
		"hot_color": Color(0.5, 0.9, 1.0, 1.0),
		"ember_color": Color(0.3, 0.6, 1.0, 1.0),
		"amethyst_color": Color(0.58, 0.44, 0.86, 1.0),
	},
	"air_blade_charge_glyph": {
		"distort_strength": 0.030,
		"lateral_strength": 0.025,
		"jitter_strength": 0.008,
		"bolt_flow_speed": 1.2,
		"flicker_speed": 5.0,
		"pulse_speed": 1.0,
		"breath_amp": 0.14,
		"hot_color": Color(1.0, 1.0, 1.0, 1.0),
		"ember_color": Color(0.66, 0.90, 1.00, 1.0),
		"amethyst_color": Color(0.72, 1.00, 0.88, 1.0),
	},
	"ball_spawn_vortex": {
		"distort_strength": 0.035,
		"lateral_strength": 0.030,
		"jitter_strength": 0.012,
		"bolt_flow_speed": 2.2,
		"flicker_speed": 6.0,
		"pulse_speed": 1.8,
		"breath_amp": 0.20,
		"hot_color": Color(0.0, 1.0, 1.0, 1.0),
		"ember_color": Color(0.5, 0.85, 1.0, 1.0),
		"amethyst_color": Color(0.58, 0.44, 0.86, 1.0),
	},
	"ball_spawn_orbit_rings": {
		"distort_strength": 0.020,
		"lateral_strength": 0.015,
		"jitter_strength": 0.006,
		"bolt_flow_speed": 0.8,
		"flicker_speed": 4.0,
		"pulse_speed": 1.2,
		"breath_amp": 0.16,
		"hot_color": Color(0.85, 0.92, 1.0, 1.0),
		"ember_color": Color(0.95, 0.78, 0.95, 1.0),
		"amethyst_color": Color(0.65, 0.80, 0.95, 1.0),
	},
	"result_box_burst_common": {
		"distort_strength": 0.045,
		"lateral_strength": 0.038,
		"jitter_strength": 0.014,
		"bolt_flow_speed": 3.8,
		"flicker_speed": 10.0,
		"pulse_speed": 2.4,
		"breath_amp": 0.26,
		"hot_color": Color(0.40, 0.92, 1.00, 1.0),
		"ember_color": Color(1.00, 0.84, 0.42, 1.0),
		"amethyst_color": Color(0.66, 0.86, 1.00, 1.0),
	},
	"result_box_burst_mythic": {
		"distort_strength": 0.060,
		"lateral_strength": 0.052,
		"jitter_strength": 0.022,
		"bolt_flow_speed": 5.2,
		"flicker_speed": 13.0,
		"pulse_speed": 3.1,
		"breath_amp": 0.34,
		"hot_color": Color(1.00, 0.42, 0.92, 1.0),
		"ember_color": Color(1.00, 0.82, 0.30, 1.0),
		"amethyst_color": Color(0.92, 0.62, 1.00, 1.0),
	},
	"hongryun_inferno_charge": {
		"distort_strength": 0.040,
		"lateral_strength": 0.030,
		"jitter_strength": 0.012,
		"bolt_flow_speed": 2.2,
		"flicker_speed": 7.0,
		"pulse_speed": 1.4,
		"breath_amp": 0.22,
		"hot_color": Color(1.00, 0.18, 0.12, 1.0),
		"ember_color": Color(1.00, 0.62, 0.20, 1.0),
		"amethyst_color": Color(0.42, 0.06, 0.10, 1.0),
	},
	"hongryun_inferno_charge_peak": {
		"distort_strength": 0.060,
		"lateral_strength": 0.048,
		"jitter_strength": 0.018,
		"bolt_flow_speed": 3.4,
		"flicker_speed": 10.0,
		"pulse_speed": 2.0,
		"breath_amp": 0.30,
		"hot_color": Color(1.00, 0.78, 0.42, 1.0),
		"ember_color": Color(1.00, 0.88, 0.38, 1.0),
		"amethyst_color": Color(0.52, 0.04, 0.08, 1.0),
	},
	"hongryun_inferno_dragon_ring": {
		"distort_strength": 0.020,
		"lateral_strength": 0.014,
		"jitter_strength": 0.006,
		"bolt_flow_speed": 1.2,
		"flicker_speed": 5.0,
		"pulse_speed": 1.0,
		"breath_amp": 0.16,
		"hot_color": Color(1.00, 0.55, 0.18, 1.0),
		"ember_color": Color(1.00, 0.80, 0.34, 1.0),
		"amethyst_color": Color(0.62, 0.10, 0.08, 1.0),
	},
	"hongryun_inferno_trail": {
		"distort_strength": 0.045,
		"lateral_strength": 0.038,
		"jitter_strength": 0.014,
		"bolt_flow_speed": 2.8,
		"flicker_speed": 9.0,
		"pulse_speed": 1.6,
		"breath_amp": 0.20,
		"hot_color": Color(1.00, 0.42, 0.18, 1.0),
		"ember_color": Color(1.00, 0.78, 0.30, 1.0),
		"amethyst_color": Color(0.55, 0.05, 0.05, 1.0),
	},
	"hongryun_inferno_burst": {
		"distort_strength": 0.075,
		"lateral_strength": 0.060,
		"jitter_strength": 0.025,
		"bolt_flow_speed": 5.5,
		"flicker_speed": 14.0,
		"pulse_speed": 3.0,
		"breath_amp": 0.0,
		"hot_color": Color(1.00, 0.95, 0.78, 1.0),
		"ember_color": Color(1.00, 0.62, 0.18, 1.0),
		"amethyst_color": Color(0.62, 0.08, 0.05, 1.0),
	},
	# Red Dragon lingpet "Dragon Breath" exhaled fire jet (the pour at the
	# dragon's mouth + the leading breath cone). Warmer / more golden than the
	# boss Hongryun inferno so the friendly companion's flame reads distinct:
	# orange hot core, golden ember licks, deep-red shadow. Lively forward flow.
	"red_dragon_breath_jet": {
		"distort_strength": 0.052,
		"lateral_strength": 0.042,
		"jitter_strength": 0.016,
		"bolt_flow_speed": 3.4,
		"flicker_speed": 9.5,
		"pulse_speed": 1.9,
		"breath_amp": 0.18,
		"hot_color": Color(1.00, 0.55, 0.12, 1.0),
		"ember_color": Color(1.00, 0.82, 0.32, 1.0),
		"amethyst_color": Color(0.70, 0.16, 0.04, 1.0),
	},
	# Lingering ground fire patch left where the breath embers die. Calmer,
	# embery, slower writhe so it reads as a sustained burning floor rather than
	# an active jet. Same shader, only uniforms differ.
	"red_dragon_breath_zone": {
		"distort_strength": 0.038,
		"lateral_strength": 0.030,
		"jitter_strength": 0.012,
		"bolt_flow_speed": 2.0,
		"flicker_speed": 6.5,
		"pulse_speed": 1.2,
		"breath_amp": 0.24,
		"hot_color": Color(1.00, 0.46, 0.10, 1.0),
		"ember_color": Color(1.00, 0.76, 0.28, 1.0),
		"amethyst_color": Color(0.55, 0.10, 0.04, 1.0),
	},
	# Smasher Drive cut-in: cyan/teal drive energy with a warm gold rim (only
	# color/speed uniforms differ from the shared writhe-ember shader). The cut-in
	# is a non-freezing left-corner portrait, so motion is calmer than the inferno
	# presets.
	"drive_cutin": {
		"distort_strength": 0.042,
		"lateral_strength": 0.034,
		"jitter_strength": 0.012,
		"bolt_flow_speed": 2.6,
		"flicker_speed": 8.0,
		"pulse_speed": 1.6,
		"breath_amp": 0.20,
		"hot_color": Color(0.58, 1.00, 0.96, 1.0),
		"ember_color": Color(0.04, 0.86, 1.00, 1.0),
		"amethyst_color": Color(1.00, 0.88, 0.36, 1.0),
	},
	# Enraged drive tuning table (perfect / combo-charged drive): punchier flow,
	# faster flicker, hotter core. Same shader, only uniforms change.
	"drive_cutin_enraged": {
		"distort_strength": 0.064,
		"lateral_strength": 0.052,
		"jitter_strength": 0.018,
		"bolt_flow_speed": 3.7,
		"flicker_speed": 11.0,
		"pulse_speed": 2.3,
		"breath_amp": 0.28,
		"hot_color": Color(0.76, 1.00, 0.98, 1.0),
		"ember_color": Color(0.00, 0.74, 1.00, 1.0),
		"amethyst_color": Color(1.00, 0.74, 0.22, 1.0),
	},
	# Shared boss electrocution field (source-agnostic "감전" symptom: Ragnarok
	# Hammer, Lumion thunder orb, and any future electric stun all reuse this).
	# Cyan-white high-voltage identity: high jitter + fast flicker give the buzzy
	# convulsing read; only color/speed uniforms differ from the shared shader.
	"electrocution_field": {
		"distort_strength": 0.050,
		"lateral_strength": 0.042,
		"jitter_strength": 0.022,
		"bolt_flow_speed": 3.2,
		"flicker_speed": 13.0,
		"pulse_speed": 2.2,
		"breath_amp": 0.20,
		"hot_color": Color(0.58, 0.95, 1.00, 1.0),
		"ember_color": Color(0.86, 0.98, 1.00, 1.0),
		"amethyst_color": Color(0.42, 0.66, 1.00, 1.0),
	},
	# Peak / high-intensity tuning (strong sources, enraged bosses): punchier
	# distort, faster flicker, hotter near-white core. Same shader, uniforms only.
	"electrocution_field_peak": {
		"distort_strength": 0.072,
		"lateral_strength": 0.060,
		"jitter_strength": 0.028,
		"bolt_flow_speed": 4.6,
		"flicker_speed": 16.0,
		"pulse_speed": 3.0,
		"breath_amp": 0.30,
		"hot_color": Color(0.80, 1.00, 1.00, 1.0),
		"ember_color": Color(1.00, 1.00, 1.00, 1.0),
		"amethyst_color": Color(0.50, 0.80, 1.00, 1.0),
	},
}

static var _shader: Shader = null


static func prewarm() -> void:
	get_shader()


static func get_shader() -> Shader:
	if _shader != null:
		return _shader
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader = shader
	return _shader


static func build_material(preset_name: String = "chaos_cracks") -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = get_shader()
	apply_preset(mat, preset_name)
	return mat


static func apply_preset(mat: ShaderMaterial, preset_name: String) -> void:
	if mat == null:
		return
	if not PRESETS.has(preset_name):
		push_warning("WritheEmberMaterial: unknown preset '%s'" % preset_name)
		return
	var preset: Dictionary = PRESETS[preset_name]
	for key in preset:
		mat.set_shader_parameter(key, preset[key])


static func has_preset(preset_name: String) -> bool:
	return PRESETS.has(preset_name)


static func is_material_using_shader(mat: ShaderMaterial) -> bool:
	return mat != null and mat.shader == get_shader()
