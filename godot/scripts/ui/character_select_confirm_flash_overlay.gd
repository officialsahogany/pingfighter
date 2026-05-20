@tool
extends Control

signal finished

const _FIELD_AURORA_SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity = 0.0;
uniform float pulse = 0.0;
uniform vec4 accent : source_color = vec4(0.16, 0.90, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.74, 0.98, 1.0, 1.0);
uniform vec4 secondary : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 focus = vec2(0.5, 0.5);
uniform float chroma = 0.012;

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
	vec2 p = uv - focus;
	float r = length(p);
	float ang = atan(p.y, p.x);

	vec2 nz = vec2(
		vnoise(uv * 3.2 + vec2(elapsed * 0.42, 0.0)),
		vnoise(uv * 3.2 + vec2(0.0, elapsed * 0.36))
	);
	nz += 0.5 * vec2(
		vnoise(uv * 7.0 - vec2(elapsed * 0.30, 0.0)),
		vnoise(uv * 7.0 - vec2(0.0, elapsed * 0.27))
	);

	float ripple = sin(r * 14.0 - elapsed * 6.5) * 0.5 + 0.5;
	ripple = pow(ripple, 3.0);

	float spiral_phase = ang * 2.0 - 3.0 * log(r * 4.0 + 1.0) + elapsed * 1.4;
	float spiral = pow(0.5 + 0.5 * cos(spiral_phase), 2.4) * 0.6;

	float flicker = vnoise(vec2(elapsed * 1.6, r * 5.0)) * 0.5 + 0.5;
	vec3 col = mix(accent.rgb, glow.rgb, flicker);
	col = mix(col, secondary.rgb, ripple * 0.55);

	float radial = smoothstep(1.05, 0.05, r);
	vec2 dir = normalize(p + vec2(0.0001));
	float ch = chroma * (0.6 + 0.4 * pulse);
	float r_red = length(p - dir * ch);
	float r_blue = length(p + dir * ch);
	float chr = smoothstep(0.30, 0.0, abs(r_red - 0.55)) * 0.30
		+ smoothstep(0.30, 0.0, abs(r_blue - 0.55)) * 0.30;
	col += accent.rgb * chr * 0.25;

	float a = (spiral * 0.45 + ripple * 0.35 + 0.20) * radial;
	a *= intensity * (0.85 + 0.20 * pulse);
	a *= 0.85 + 0.30 * (nz.x * 0.5 + 0.5);

	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
"""

const _CARD_HALO_SHADER := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity = 0.0;
uniform float pulse = 0.0;
uniform float white_blend = 0.0;
uniform vec4 accent : source_color = vec4(0.16, 0.90, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.74, 0.98, 1.0, 1.0);
uniform vec4 secondary : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float ring_band(float r, float center, float width) {
	return smoothstep(width, 0.0, abs(r - center));
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float r = length(p) * 2.0;

	float core = pow(smoothstep(1.0, 0.0, r), 2.2);
	float ring1 = ring_band(r, 0.45 + 0.05 * sin(elapsed * 4.0), 0.10);
	float ring2 = ring_band(r, 0.72 + 0.04 * sin(elapsed * 3.2 + 1.4), 0.08);
	float ring3 = ring_band(r, 0.95, 0.07) * 0.55;

	float flick = step(0.5, fract(elapsed * 7.0)) * pulse;
	vec3 col = mix(accent.rgb, glow.rgb, 0.5 + 0.5 * sin(elapsed * 2.6));
	col = mix(col, secondary.rgb, max(flick * 0.65, white_blend));
	vec3 ring_col = mix(secondary.rgb, glow.rgb, 0.35);

	float a = core * 0.55
		+ ring1 * 0.65
		+ ring2 * 0.45
		+ ring3 * 0.40;
	a *= intensity * (0.85 + 0.25 * pulse);
	a = mix(a, max(a, 0.55), white_blend * 0.7);

	vec3 final_col = mix(col, ring_col, max(ring1, ring2) * 0.5);
	final_col = mix(final_col, secondary.rgb, white_blend);

	COLOR = vec4(final_col, clamp(a, 0.0, 0.95));
}
"""

var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.55
var source_rect := Rect2()
var style: String = "burst"
var accent := Color(0.0, 0.88, 1.0, 1.0)
var glow := Color(0.72, 0.95, 1.0, 1.0)
var secondary := Color(1.0, 1.0, 1.0, 1.0)
var field_intensity: float = 1.0
var card_intensity: float = 1.0
var white_wash_target: float = 0.92
var chroma: float = 0.012
var split_intensity: float = 0.85
var split_count: int = 10
var accent_progress: float = 0.0
var accent_pulse: float = 0.0

var _field_rect: ColorRect = null
var _halo_rect: ColorRect = null
var _white_rect: ColorRect = null
var _field_material: ShaderMaterial = null
var _halo_material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build_layers()
	var resize_callback := Callable(self, "_on_resized")
	if not is_connected("resized", resize_callback):
		connect("resized", resize_callback)
	visible = false
	set_process(false)


func play(config: Dictionary) -> void:
	_build_layers()
	duration = max(0.08, float(config.get("duration", duration)))
	var source_value: Variant = config.get("source_rect", source_rect)
	source_rect = source_value if source_value is Rect2 else Rect2()
	style = str(config.get("style", "burst"))
	accent = _color_from_config(config.get("accent", accent), accent)
	glow = _color_from_config(config.get("glow", glow), glow)
	secondary = _color_from_config(config.get("secondary", secondary), secondary)
	field_intensity = max(0.0, float(config.get("field_intensity", 1.0)))
	card_intensity = max(0.0, float(config.get("card_intensity", 1.0)))
	white_wash_target = clampf(float(config.get("white_wash_target", 0.92)), 0.0, 1.0)
	chroma = max(0.0, float(config.get("chroma", 0.012)))
	split_intensity = max(0.0, float(config.get("split_intensity", 0.85)))
	split_count = clampi(int(config.get("split_count", 10)), 0, 24)
	elapsed = 0.0
	accent_progress = 0.0
	accent_pulse = 0.0
	active = true
	visible = true
	_layout_halo_rect()
	_apply_color_uniforms()
	_apply_focus_uniform()
	_set_layers_visible(true)
	_update_envelopes(0.0)
	set_process(true)
	queue_redraw()


func cancel() -> void:
	active = false
	visible = false
	_set_layers_visible(false)
	set_process(false)
	queue_redraw()


func is_playing() -> bool:
	return active


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var progress: float = clampf(elapsed / max(0.01, duration), 0.0, 1.0)
	_update_envelopes(progress)
	if elapsed >= duration:
		active = false
		visible = false
		_set_layers_visible(false)
		set_process(false)
		queue_redraw()
		finished.emit()
		return
	queue_redraw()


func _draw() -> void:
	if not active or size.x <= 1.0 or size.y <= 1.0:
		return
	if accent_progress < 0.20 or accent_progress > 0.80:
		return
	var fade: float = pow(1.0 - abs(accent_progress - 0.5) * 2.0, 1.4) * 0.7
	var center := _effect_center()
	var base_radius: float = max(source_rect.size.x, source_rect.size.y) * 0.22
	if base_radius <= 1.0:
		base_radius = min(size.x, size.y) * 0.20

	_draw_burst(center, base_radius, accent_progress, fade, accent_pulse)
	if style == "slash":
		_draw_slash_flash(center, base_radius, accent_progress, fade, accent_pulse)
	else:
		_draw_star_flash(center, base_radius, accent_progress, fade, accent_pulse)
	if split_intensity > 0.0 and split_count > 0:
		_draw_split_fracture(center, base_radius, accent_progress, fade, accent_pulse)


func _build_layers() -> void:
	if _field_rect != null and is_instance_valid(_field_rect):
		return
	_field_rect = ColorRect.new()
	_field_rect.name = "FieldAurora"
	_field_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field_rect.color = Color.WHITE
	_field_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_rect.show_behind_parent = true
	_field_rect.z_index = -30
	_field_rect.material = _build_shader_material(_FIELD_AURORA_SHADER)
	_field_material = _field_rect.material as ShaderMaterial
	_field_rect.visible = false
	add_child(_field_rect)

	_halo_rect = ColorRect.new()
	_halo_rect.name = "CardHalo"
	_halo_rect.color = Color.WHITE
	_halo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo_rect.show_behind_parent = true
	_halo_rect.z_index = -20
	_halo_rect.material = _build_shader_material(_CARD_HALO_SHADER)
	_halo_material = _halo_rect.material as ShaderMaterial
	_halo_rect.visible = false
	add_child(_halo_rect)

	_white_rect = ColorRect.new()
	_white_rect.name = "WhiteWash"
	_white_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white_rect.color = Color.WHITE
	_white_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white_rect.show_behind_parent = true
	_white_rect.z_index = -10
	_white_rect.visible = false
	add_child(_white_rect)


func _build_shader_material(shader_code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = shader_code
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _set_layers_visible(enabled: bool) -> void:
	if _field_rect != null:
		_field_rect.visible = enabled
	if _halo_rect != null:
		_halo_rect.visible = enabled
	if _white_rect != null:
		_white_rect.visible = enabled
		if not enabled:
			_white_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _layout_halo_rect() -> void:
	if _halo_rect == null:
		return
	var view_size := _resolved_size()
	var center: Vector2 = source_rect.get_center() if source_rect.size.x > 1.0 and source_rect.size.y > 1.0 else view_size * 0.5
	var halo_radius: float = max(source_rect.size.x, source_rect.size.y) * 1.20
	if halo_radius <= 1.0:
		halo_radius = min(view_size.x, view_size.y) * 0.55
	var halo_size := Vector2(halo_radius * 2.0, halo_radius * 2.0)
	_halo_rect.position = center - halo_size * 0.5
	_halo_rect.size = halo_size


func _apply_color_uniforms() -> void:
	if _field_material != null:
		_field_material.set_shader_parameter("accent", accent)
		_field_material.set_shader_parameter("glow", glow)
		_field_material.set_shader_parameter("secondary", secondary)
		_field_material.set_shader_parameter("chroma", chroma)
	if _halo_material != null:
		_halo_material.set_shader_parameter("accent", accent)
		_halo_material.set_shader_parameter("glow", glow)
		_halo_material.set_shader_parameter("secondary", secondary)


func _apply_focus_uniform() -> void:
	if _field_material == null:
		return
	var view_size := _resolved_size()
	var center: Vector2 = source_rect.get_center() if source_rect.size.x > 1.0 and source_rect.size.y > 1.0 else view_size * 0.5
	var focus := Vector2(
		clampf(center.x / max(1.0, view_size.x), 0.0, 1.0),
		clampf(center.y / max(1.0, view_size.y), 0.0, 1.0)
	)
	_field_material.set_shader_parameter("focus", focus)


func _update_envelopes(progress: float) -> void:
	progress = clampf(progress, 0.0, 1.0)
	var pulse: float = sin(progress * PI)
	var field_alpha: float = 0.0
	if progress < 0.30:
		field_alpha = _ease_out_quad(progress / 0.30) * 0.55
	elif progress < 0.70:
		field_alpha = lerp(0.55, 0.40, (progress - 0.30) / 0.40)
	else:
		field_alpha = lerp(0.40, 0.0, _ease_in_quad((progress - 0.70) / 0.30))
	field_alpha *= field_intensity

	var halo_alpha: float = 0.0
	if progress < 0.30:
		halo_alpha = _ease_out_quad(progress / 0.30)
	elif progress < 0.70:
		halo_alpha = lerp(1.0, 0.65, (progress - 0.30) / 0.40)
	else:
		halo_alpha = lerp(0.65, 0.0, _ease_in_quad((progress - 0.70) / 0.30))
	halo_alpha *= card_intensity

	var wash_alpha: float = clampf((progress - 0.55) / 0.35, 0.0, 1.0) * white_wash_target
	var halo_white: float = clampf((progress - 0.62) / 0.32, 0.0, 1.0)

	accent_progress = progress
	accent_pulse = pulse
	if _field_material != null:
		_field_material.set_shader_parameter("elapsed", elapsed)
		_field_material.set_shader_parameter("intensity", field_alpha)
		_field_material.set_shader_parameter("pulse", pulse)
	if _halo_material != null:
		_halo_material.set_shader_parameter("elapsed", elapsed)
		_halo_material.set_shader_parameter("intensity", halo_alpha)
		_halo_material.set_shader_parameter("pulse", pulse)
		_halo_material.set_shader_parameter("white_blend", halo_white)
	if _white_rect != null:
		_white_rect.modulate = Color(1.0, 1.0, 1.0, wash_alpha)


func _on_resized() -> void:
	if not active:
		return
	_layout_halo_rect()
	_apply_focus_uniform()


func _resolved_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	if is_inside_tree() and get_viewport() != null:
		return get_viewport_rect().size
	return Vector2(1920.0, 1080.0)


func _ease_out_quad(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


func _ease_in_quad(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t


func _effect_center() -> Vector2:
	if source_rect.size.x > 1.0 and source_rect.size.y > 1.0:
		return source_rect.get_center()
	return size * 0.5


func _draw_burst(center: Vector2, base_radius: float, progress: float, fade: float, pulse: float) -> void:
	var ring_radius: float = base_radius * (0.55 + progress * 1.8)
	for ring_index in range(3):
		var ring_t: float = float(ring_index) / 2.0
		var radius: float = ring_radius + base_radius * ring_t * 0.42
		var alpha: float = (0.34 - ring_t * 0.10) * fade
		draw_circle(center, radius, Color(glow.r, glow.g, glow.b, alpha), false, 3.0 - ring_t, true)
	draw_circle(center, base_radius * (0.20 + pulse * 0.32), Color(secondary.r, secondary.g, secondary.b, 0.26 * fade), true)
	for ray_index in range(20):
		var angle: float = TAU * float(ray_index) / 20.0 + progress * 0.18
		var dir := Vector2(cos(angle), sin(angle))
		var inner: float = base_radius * (0.12 + 0.18 * pulse)
		var outer: float = base_radius * (0.86 + progress * 2.05)
		var width: float = 1.4 + 2.4 * fade
		var ray_alpha: float = (0.14 + 0.24 * pulse) * fade
		draw_line(center + dir * inner, center + dir * outer, Color(glow.r, glow.g, glow.b, ray_alpha), width)


func _draw_star_flash(center: Vector2, base_radius: float, progress: float, fade: float, pulse: float) -> void:
	var long_len: float = base_radius * (1.2 + progress * 2.3)
	var short_len: float = base_radius * (0.65 + progress * 1.3)
	var alpha: float = (0.36 + 0.22 * pulse) * fade
	for angle in [0.0, PI * 0.5, PI * 0.25, -PI * 0.25]:
		var dir := Vector2(cos(angle), sin(angle))
		var length: float = long_len if abs(angle) < 0.01 or abs(angle - PI * 0.5) < 0.01 else short_len
		draw_line(center - dir * length, center + dir * length, Color(secondary.r, secondary.g, secondary.b, alpha), 3.0 + 4.0 * fade)
		draw_line(center - dir * length * 0.72, center + dir * length * 0.72, Color(accent.r, accent.g, accent.b, alpha * 0.86), 1.4 + 2.0 * fade)


func _draw_slash_flash(center: Vector2, base_radius: float, progress: float, fade: float, pulse: float) -> void:
	var length: float = base_radius * (1.5 + progress * 2.45)
	var width: float = base_radius * (0.07 + 0.06 * fade)
	var alpha: float = (0.38 + 0.18 * pulse) * fade
	for slash_index in range(3):
		var offset: float = (float(slash_index) - 1.0) * base_radius * 0.28
		var slash_center := center + Vector2(offset * 0.58, -offset)
		var slash_alpha: float = alpha * (1.0 - abs(float(slash_index) - 1.0) * 0.22)
		_draw_slash_polygon(slash_center, -0.58, length, width, Color(glow.r, glow.g, glow.b, slash_alpha))
		_draw_slash_polygon(slash_center, -0.58, length * 0.72, width * 0.40, Color(secondary.r, secondary.g, secondary.b, slash_alpha * 0.72))


func _draw_split_fracture(center: Vector2, base_radius: float, progress: float, fade: float, pulse: float) -> void:
	var open_amount: float = _ease_out_quad(clampf((progress - 0.18) / 0.56, 0.0, 1.0))
	var seam_alpha: float = fade * split_intensity * (0.34 + 0.28 * pulse)
	var shard_alpha: float = fade * split_intensity * (0.22 + 0.20 * pulse)
	var angle_bias: float = -0.38 if style == "slash" else 0.0
	for crack_index in range(split_count):
		var crack_ratio: float = float(crack_index) / float(max(1, split_count))
		var noise_a: float = sin(float(crack_index) * 12.9898 + 4.137)
		var noise_b: float = sin(float(crack_index) * 78.233 + 1.91)
		var angle: float = TAU * crack_ratio + angle_bias + noise_a * 0.16 + noise_b * 0.08
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var inner: float = base_radius * (0.16 + 0.08 * pulse)
		var middle: float = base_radius * (0.52 + 0.24 * open_amount + 0.06 * noise_b)
		var outer: float = base_radius * (1.05 + progress * 1.58 + 0.14 * noise_a)
		var bend: float = base_radius * (0.06 + 0.10 * open_amount) * noise_b
		var p0 := center + direction * inner
		var p1 := center + direction * middle + tangent * bend
		var p2 := center + direction * outer + tangent * bend * 1.8
		var seam := PackedVector2Array([p0, p1, p2])
		draw_polyline(seam, Color(glow.r, glow.g, glow.b, seam_alpha), 3.2 + 2.4 * fade, true)
		draw_polyline(seam, Color(secondary.r, secondary.g, secondary.b, seam_alpha * 0.55), 1.0 + 1.6 * fade, true)
		if crack_index % 2 == 0:
			var branch_t: float = 0.52 + 0.16 * noise_a
			var branch_start := p1.lerp(p2, branch_t)
			var branch_direction := (direction + tangent * (0.36 if noise_b >= 0.0 else -0.36)).normalized()
			var branch_len: float = base_radius * (0.34 + 0.18 * open_amount)
			draw_line(
				branch_start,
				branch_start + branch_direction * branch_len,
				Color(accent.r, accent.g, accent.b, seam_alpha * 0.55),
				1.4 + 1.6 * fade,
				true
			)
	var shard_total: int = maxi(4, int(ceil(float(split_count) * 0.65)))
	for shard_index in range(shard_total):
		var shard_ratio: float = (float(shard_index) + 0.5) / float(shard_total)
		var shard_noise: float = sin(float(shard_index) * 19.19 + 2.7)
		var angle: float = TAU * shard_ratio + angle_bias * 0.7 + shard_noise * 0.20
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var travel: float = base_radius * (0.56 + progress * 1.05 + shard_noise * 0.08)
		var shard_center := center + direction * travel + tangent * base_radius * 0.08 * shard_noise
		var shard_length: float = base_radius * (0.16 + 0.08 * abs(shard_noise))
		var shard_width: float = base_radius * (0.045 + 0.026 * pulse)
		var points := PackedVector2Array([
			shard_center + direction * shard_length,
			shard_center - direction * shard_length * 0.42 + tangent * shard_width,
			shard_center - direction * shard_length * 0.64 - tangent * shard_width * 0.82,
		])
		var fill := Color(accent.r, accent.g, accent.b, shard_alpha)
		var outline := Color(secondary.r, secondary.g, secondary.b, shard_alpha * 0.58)
		draw_colored_polygon(points, fill)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), outline, 1.0 + fade, true)


func _draw_slash_polygon(center: Vector2, angle: float, length: float, width: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		center - dir * length * 0.5 - normal * width,
		center + dir * length * 0.5 - normal * width * 0.46,
		center + dir * length * 0.5 + normal * width,
		center - dir * length * 0.5 + normal * width * 0.46,
	])
	draw_colored_polygon(pts, color)


func _color_from_config(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback
