extends Node2D

const HOST_NAME := "PonkIllusionRippleFxHost"
const Z_INDEX := 1272
const ACTIVE_SYNC_GRACE_MSEC := 160
const DEFAULT_VIEW_SIZE := Vector2(1280.0, 720.0)
const DEFAULT_INTENSITY_PX := 12.0
const DEFAULT_WAVE_FREQ_A := 9.0
const DEFAULT_WAVE_FREQ_B := 17.0
const DEFAULT_WAVE_SPEED := 2.2
const DEFAULT_HUE_WAVE_AMP := 0.9
const DEFAULT_HUE_WAVE_FREQ := 5.0
const DEFAULT_HUE_TIME_SPEED := 0.9
const DEFAULT_CHROMA_OFFSET_PX := 3.5
const DEFAULT_SATURATION_BOOST := 0.25
const EASE_IN_SECONDS := 0.40
const EASE_OUT_SECONDS := 0.60

static var _shader: Shader = null
static var _material_template: ShaderMaterial = null
static var _prewarm_assets_done := false

var _back_buffer_copy: BackBufferCopy = null
var _ripple_rect: ColorRect = null
var _material: ShaderMaterial = null
var _last_active_sync_msec: int = 0


static func prewarm_assets() -> void:
	_get_material_template()
	_prewarm_assets_done = true


static func prewarm_assets_step() -> bool:
	if _prewarm_assets_done:
		return true
	prewarm_assets()
	return true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"illusion_ripple_fx_shader_host_pipeline": _shader != null and _material_template != null,
		"illusion_ripple_shader_ready": _shader != null,
		"illusion_ripple_material_ready": _material_template != null,
		"illusion_ripple_uses_screen_texture": true,
		"illusion_ripple_uses_back_buffer_copy": true,
		"illusion_ripple_z_index": Z_INDEX,
		"illusion_ripple_active_sync_grace_msec": ACTIVE_SYNC_GRACE_MSEC,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	_ensure_children()
	if _last_active_sync_msec <= 0:
		set_active(false)


func prewarm_runtime_nodes() -> void:
	prewarm_assets()
	_ensure_children()
	set_active(false)


func sync_state(state: Dictionary, enabled: bool) -> void:
	_ensure_children()
	var view_size: Vector2 = _as_vector2(state.get("view_size_px", state.get("view_size", DEFAULT_VIEW_SIZE)), DEFAULT_VIEW_SIZE)
	var strength: float = clampf(float(state.get("strength", _calculate_envelope_strength(state))), 0.0, 1.0)
	var active_state := enabled and bool(state.get("active", false)) and view_size.x > 1.0 and view_size.y > 1.0 and strength > 0.001
	if not active_state:
		set_active(false)
		return

	_last_active_sync_msec = Time.get_ticks_msec()
	set_process(true)
	visible = true
	_back_buffer_copy.visible = true
	_ripple_rect.visible = true
	_back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_ripple_rect.position = Vector2.ZERO
	_ripple_rect.size = view_size
	_material.set_shader_parameter("view_size_px", view_size)
	_material.set_shader_parameter("strength", strength)
	_material.set_shader_parameter("intensity_px", maxf(0.0, float(state.get("intensity_px", DEFAULT_INTENSITY_PX))))
	_material.set_shader_parameter("wave_freq_a", maxf(0.1, float(state.get("wave_freq_a", DEFAULT_WAVE_FREQ_A))))
	_material.set_shader_parameter("wave_freq_b", maxf(0.1, float(state.get("wave_freq_b", DEFAULT_WAVE_FREQ_B))))
	_material.set_shader_parameter("wave_speed", float(state.get("wave_speed", DEFAULT_WAVE_SPEED)))
	_material.set_shader_parameter("hue_wave_amp", maxf(0.0, float(state.get("hue_wave_amp", DEFAULT_HUE_WAVE_AMP))))
	_material.set_shader_parameter("hue_wave_freq", maxf(0.1, float(state.get("hue_wave_freq", DEFAULT_HUE_WAVE_FREQ))))
	_material.set_shader_parameter("hue_time_speed", clampf(float(state.get("hue_time_speed", DEFAULT_HUE_TIME_SPEED)), 0.0, 3.0))
	_material.set_shader_parameter("chroma_offset_px", maxf(0.0, float(state.get("chroma_offset_px", DEFAULT_CHROMA_OFFSET_PX))))
	_material.set_shader_parameter("saturation_boost", maxf(0.0, float(state.get("saturation_boost", DEFAULT_SATURATION_BOOST))))
	_material.set_shader_parameter("elapsed_sec", float(state.get("elapsed_sec", Time.get_ticks_msec() / 1000.0)))


func set_active(enabled: bool) -> void:
	visible = enabled
	if _back_buffer_copy != null and is_instance_valid(_back_buffer_copy):
		_back_buffer_copy.visible = enabled
	if _ripple_rect != null and is_instance_valid(_ripple_rect):
		_ripple_rect.visible = enabled
	if not enabled:
		set_process(false)


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"visible": visible,
		"z_index": z_index,
		"z_as_relative": z_as_relative,
		"has_back_buffer_copy": _back_buffer_copy != null and is_instance_valid(_back_buffer_copy),
		"has_color_rect": _ripple_rect != null and is_instance_valid(_ripple_rect),
		"material_ready": _material != null,
		"copy_mode": _back_buffer_copy.copy_mode if _back_buffer_copy != null else -1,
		"rect_size": _ripple_rect.size if _ripple_rect != null else Vector2.ZERO,
		"strength": float(_material.get_shader_parameter("strength")) if _material != null else 0.0,
		"intensity_px": float(_material.get_shader_parameter("intensity_px")) if _material != null else 0.0,
		"wave_freq_a": float(_material.get_shader_parameter("wave_freq_a")) if _material != null else 0.0,
		"wave_freq_b": float(_material.get_shader_parameter("wave_freq_b")) if _material != null else 0.0,
		"wave_speed": float(_material.get_shader_parameter("wave_speed")) if _material != null else 0.0,
		"hue_wave_amp": float(_material.get_shader_parameter("hue_wave_amp")) if _material != null else 0.0,
		"hue_wave_freq": float(_material.get_shader_parameter("hue_wave_freq")) if _material != null else 0.0,
		"hue_time_speed": float(_material.get_shader_parameter("hue_time_speed")) if _material != null else 0.0,
		"chroma_offset_px": float(_material.get_shader_parameter("chroma_offset_px")) if _material != null else 0.0,
		"saturation_boost": float(_material.get_shader_parameter("saturation_boost")) if _material != null else 0.0,
	}


func force_timeout_for_tests() -> void:
	_last_active_sync_msec = Time.get_ticks_msec() - ACTIVE_SYNC_GRACE_MSEC - 1
	_process(0.0)


func _process(_delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if Time.get_ticks_msec() - _last_active_sync_msec > ACTIVE_SYNC_GRACE_MSEC:
		set_active(false)


func _ensure_children() -> void:
	if _back_buffer_copy == null or not is_instance_valid(_back_buffer_copy):
		_back_buffer_copy = BackBufferCopy.new()
		_back_buffer_copy.name = "BackBufferCopy"
		_back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(_back_buffer_copy)
	if _ripple_rect == null or not is_instance_valid(_ripple_rect):
		_ripple_rect = ColorRect.new()
		_ripple_rect.name = "PonkIllusionRippleRect"
		_ripple_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ripple_rect.color = Color.WHITE
		add_child(_ripple_rect)
	if _material == null:
		_material = _get_material_template().duplicate() as ShaderMaterial
		_ripple_rect.material = _material


func _calculate_envelope_strength(state: Dictionary) -> float:
	var total_frames: float = maxf(1.0, float(state.get("duration_total", 240.0)))
	var remaining_frames: float = clampf(float(state.get("timer_frames", total_frames)), 0.0, total_frames)
	var elapsed_sec: float = maxf(0.0, (total_frames - remaining_frames) / 60.0)
	var remaining_sec: float = maxf(0.0, remaining_frames / 60.0)
	var in_strength: float = smoothstep(0.0, EASE_IN_SECONDS, elapsed_sec)
	var out_strength: float = smoothstep(0.0, EASE_OUT_SECONDS, remaining_sec)
	return clampf(minf(in_strength, out_strength), 0.0, 1.0)


static func _get_material_template() -> ShaderMaterial:
	if _material_template != null:
		return _material_template
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _shader_code()
	_material_template = ShaderMaterial.new()
	_material_template.shader = _shader
	_material_template.set_shader_parameter("view_size_px", DEFAULT_VIEW_SIZE)
	_material_template.set_shader_parameter("strength", 0.0)
	_material_template.set_shader_parameter("intensity_px", DEFAULT_INTENSITY_PX)
	_material_template.set_shader_parameter("wave_freq_a", DEFAULT_WAVE_FREQ_A)
	_material_template.set_shader_parameter("wave_freq_b", DEFAULT_WAVE_FREQ_B)
	_material_template.set_shader_parameter("wave_speed", DEFAULT_WAVE_SPEED)
	_material_template.set_shader_parameter("hue_wave_amp", DEFAULT_HUE_WAVE_AMP)
	_material_template.set_shader_parameter("hue_wave_freq", DEFAULT_HUE_WAVE_FREQ)
	_material_template.set_shader_parameter("hue_time_speed", DEFAULT_HUE_TIME_SPEED)
	_material_template.set_shader_parameter("chroma_offset_px", DEFAULT_CHROMA_OFFSET_PX)
	_material_template.set_shader_parameter("saturation_boost", DEFAULT_SATURATION_BOOST)
	_material_template.set_shader_parameter("elapsed_sec", 0.0)
	return _material_template


static func _shader_code() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 view_size_px = vec2(1280.0, 720.0);
uniform float strength = 0.0;
uniform float intensity_px = 12.0;
uniform float wave_freq_a = 9.0;
uniform float wave_freq_b = 17.0;
uniform float wave_speed = 2.2;
uniform float hue_wave_amp = 0.9;
uniform float hue_wave_freq = 5.0;
uniform float hue_time_speed = 0.9;
uniform float chroma_offset_px = 3.5;
uniform float saturation_boost = 0.25;
uniform float elapsed_sec = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = elapsed_sec * wave_speed;
	float envelope = clamp(strength, 0.0, 1.0);
	float wave_x = sin(uv.y * wave_freq_a + t) + 0.6 * sin(uv.x * wave_freq_b - t * 1.3);
	float wave_y = cos(uv.x * wave_freq_a * 0.8 - t * 0.7) + 0.5 * sin((uv.x + uv.y) * wave_freq_b * 0.55 + t * 1.1);
	vec2 px_offset = vec2(wave_x, wave_y) * intensity_px * envelope;
	vec2 safe_view = max(view_size_px, vec2(1.0));
	vec2 base_uv = clamp(uv + px_offset / safe_view, vec2(0.0), vec2(1.0));
	vec2 ca = normalize(px_offset + vec2(0.0001)) * (chroma_offset_px * envelope) / safe_view;
	float r = texture(screen_tex, clamp(base_uv + ca, vec2(0.0), vec2(1.0))).r;
	vec4 gs = texture(screen_tex, base_uv);
	float b = texture(screen_tex, clamp(base_uv - ca, vec2(0.0), vec2(1.0))).b;
	vec3 col = vec3(r, gs.g, b);
	float color_t = elapsed_sec;
	float hue = hue_wave_amp * envelope
		* sin(uv.x * hue_wave_freq + color_t * hue_time_speed)
		* cos(uv.y * hue_wave_freq * 0.8 - color_t * hue_time_speed * 0.7);
	const vec3 grey_axis = vec3(0.57735);
	float ch = cos(hue);
	float sh = sin(hue);
	col = col * ch + cross(grey_axis, col) * sh + grey_axis * dot(grey_axis, col) * (1.0 - ch);
	float sat = 1.0 + saturation_boost * envelope * (0.5 + 0.5 * sin(color_t * 0.8));
	vec3 grey = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
	col = grey + (col - grey) * sat;
	COLOR = vec4(col, gs.a);
}
"""


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
