extends Node2D

const HOST_NAME := "DefeatContinueColorRestoreFxHost"
const Z_INDEX := 1280
const ACTIVE_SYNC_GRACE_MSEC := 160

static var _shader: Shader = null
static var _material_template: ShaderMaterial = null

var _back_buffer_copy: BackBufferCopy = null
var _color_rect: ColorRect = null
var _material: ShaderMaterial = null
var _last_active_sync_msec: int = 0


static func prewarm_assets() -> void:
	_get_material_template()


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"shader_ready": _shader != null,
		"material_ready": _material_template != null,
		"z_index": Z_INDEX,
		"uses_screen_texture": true,
		"uses_back_buffer_copy": true,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = Z_INDEX
	_ensure_children()
	set_active(false)


func sync_state(state: Dictionary, enabled: bool) -> void:
	_ensure_children()
	var view_size: Vector2 = _as_vector2(state.get("view_size_px", state.get("view_size", Vector2.ZERO)), Vector2.ZERO)
	var desaturate_amount := clampf(float(state.get("desaturate_amount", 0.0)), 0.0, 1.0)
	var active_state := enabled and bool(state.get("active", false)) and view_size.x > 1.0 and view_size.y > 1.0 and desaturate_amount > 0.001
	if not active_state:
		set_active(false)
		return
	_last_active_sync_msec = Time.get_ticks_msec()
	set_process(true)
	visible = true
	_back_buffer_copy.visible = true
	_color_rect.visible = true
	_back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_color_rect.position = Vector2.ZERO
	_color_rect.size = view_size
	_material.set_shader_parameter("center_px", _as_vector2(state.get("center_px", view_size * 0.5), view_size * 0.5))
	_material.set_shader_parameter("view_size_px", view_size)
	_material.set_shader_parameter("restore_radius_px", maxf(0.0, float(state.get("restore_radius_px", 0.0))))
	_material.set_shader_parameter("feather_px", maxf(1.0, float(state.get("feather_px", maxf(48.0, minf(view_size.x, view_size.y) * 0.085)))))
	_material.set_shader_parameter("desaturate_amount", desaturate_amount)


func set_active(enabled: bool) -> void:
	visible = enabled
	if _back_buffer_copy != null and is_instance_valid(_back_buffer_copy):
		_back_buffer_copy.visible = enabled
	if _color_rect != null and is_instance_valid(_color_rect):
		_color_rect.visible = enabled
	if not enabled:
		set_process(false)


func get_debug_status() -> Dictionary:
	return {
		"visible": visible,
		"z_index": z_index,
		"z_as_relative": z_as_relative,
		"has_back_buffer_copy": _back_buffer_copy != null and is_instance_valid(_back_buffer_copy),
		"has_color_rect": _color_rect != null and is_instance_valid(_color_rect),
		"material_ready": _material != null,
		"copy_mode": _back_buffer_copy.copy_mode if _back_buffer_copy != null else -1,
		"rect_size": _color_rect.size if _color_rect != null else Vector2.ZERO,
		"center_px": _material.get_shader_parameter("center_px") if _material != null else Vector2.ZERO,
		"restore_radius_px": float(_material.get_shader_parameter("restore_radius_px")) if _material != null else 0.0,
		"desaturate_amount": float(_material.get_shader_parameter("desaturate_amount")) if _material != null else 0.0,
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
	if _color_rect == null or not is_instance_valid(_color_rect):
		_color_rect = ColorRect.new()
		_color_rect.name = "ColorRestoreRect"
		_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_color_rect.color = Color.WHITE
		add_child(_color_rect)
	if _material == null:
		_material = _get_material_template().duplicate() as ShaderMaterial
		_color_rect.material = _material


static func _get_material_template() -> ShaderMaterial:
	if _material_template != null:
		return _material_template
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _shader_code()
	_material_template = ShaderMaterial.new()
	_material_template.shader = _shader
	_material_template.set_shader_parameter("center_px", Vector2.ZERO)
	_material_template.set_shader_parameter("view_size_px", Vector2(1280.0, 720.0))
	_material_template.set_shader_parameter("restore_radius_px", 0.0)
	_material_template.set_shader_parameter("feather_px", 64.0)
	_material_template.set_shader_parameter("desaturate_amount", 0.0)
	return _material_template


static func _shader_code() -> String:
	return """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center_px = vec2(640.0, 360.0);
uniform vec2 view_size_px = vec2(1280.0, 720.0);
uniform float restore_radius_px = 0.0;
uniform float feather_px = 80.0;
uniform float desaturate_amount = 0.0;

void fragment() {
	vec4 col = texture(screen_tex, SCREEN_UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float desat_amount = clamp(desaturate_amount, 0.0, 1.0);
	vec3 desat = mix(col.rgb, vec3(gray), desat_amount);
	float radius = max(restore_radius_px, 0.0);
	float feather = max(feather_px, 1.0);
	float dist_px = distance(SCREEN_UV * view_size_px, center_px);
	float restore = 0.0;
	if (radius > 0.5) {
		restore = 1.0 - smoothstep(max(radius - feather, 0.0), radius, dist_px);
	}
	COLOR = vec4(mix(desat, col.rgb, restore), 1.0);
}
"""


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
