extends Object
class_name ScreenClipCanvasMaterial

# Control.clip_contents가 Node2D/Sprite2D/GPUParticles2D 자식에서 구조상 true여도
# 실제 픽셀을 자르지 않는 렌더러 경로를 보강하는 공용 canvas-item 재질이다.
# SCREEN_UV를 viewport pixel로 환산해 플레이필드 밖 조각을 fragment 단계에서 버린다.

# CLIP FEATHER 계약: 경계에서 곧바로 discard만 하면 하드-에지 아트(먹선 원환처럼
# 캔버스 끝까지 밀도가 있는 텍스처)가 면도날처럼 잘려 보인다("발사 투사체가
# 잘려보임" 회귀). 바깥은 그대로 discard(레터박스 무누출 씰 유지)하되, 안쪽
# feather 밴드에서 알파를 0까지 램프해 절단을 페이드로 바꾼다. feather=0이면
# 기존 하드 클립과 완전히 동일하다(기본값 = 하위호환).

const MIX_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform bool screen_clip_enabled = false;
uniform vec2 screen_clip_min_px = vec2(-100000.0);
uniform vec2 screen_clip_max_px = vec2(100000.0);
uniform float screen_clip_feather_px = 0.0;

void fragment() {
	vec2 screen_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	if (screen_clip_enabled && (
		screen_px.x < screen_clip_min_px.x
		|| screen_px.y < screen_clip_min_px.y
		|| screen_px.x >= screen_clip_max_px.x
		|| screen_px.y >= screen_clip_max_px.y
	)) {
		discard;
	}
	float clip_fade = 1.0;
	if (screen_clip_enabled && screen_clip_feather_px > 0.5) {
		vec2 lo = screen_px - screen_clip_min_px;
		vec2 hi = screen_clip_max_px - screen_px;
		float edge = min(min(lo.x, lo.y), min(hi.x, hi.y));
		float t = clamp(edge / screen_clip_feather_px, 0.0, 1.0);
		clip_fade = t * t * (3.0 - 2.0 * t);
	}
	// ⚠️ 재샘플링 금지. canvas_item fragment 진입 시 COLOR에는 이미
	// texture(TEXTURE, UV) * modulate 가 들어 있다(픽셀 실측: 텍스처 RGBA
	// (.5,.5,.5,.5) + modulate 1.0 → 무개입 0.247 / 재샘플 0.063 = 0.247²).
	// 여기서 `COLOR = texture(...) * COLOR`를 하면 texture²가 되어 먹선·반투명
	// 꼬리·헤일로가 의도보다 어둡고 얇아진다. 이 재질의 책임은 클립뿐이므로
	// 알파에 feather만 곱하고 색은 건드리지 않는다.
	COLOR.a *= clip_fade;
}
"""

const ADD_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform bool screen_clip_enabled = false;
uniform vec2 screen_clip_min_px = vec2(-100000.0);
uniform vec2 screen_clip_max_px = vec2(100000.0);
uniform float screen_clip_feather_px = 0.0;

void fragment() {
	vec2 screen_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	if (screen_clip_enabled && (
		screen_px.x < screen_clip_min_px.x
		|| screen_px.y < screen_clip_min_px.y
		|| screen_px.x >= screen_clip_max_px.x
		|| screen_px.y >= screen_clip_max_px.y
	)) {
		discard;
	}
	float clip_fade = 1.0;
	if (screen_clip_enabled && screen_clip_feather_px > 0.5) {
		vec2 lo = screen_px - screen_clip_min_px;
		vec2 hi = screen_clip_max_px - screen_px;
		float edge = min(min(lo.x, lo.y), min(hi.x, hi.y));
		float t = clamp(edge / screen_clip_feather_px, 0.0, 1.0);
		clip_fade = t * t * (3.0 - 2.0 * t);
	}
	// ⚠️ 재샘플링 금지. canvas_item fragment 진입 시 COLOR에는 이미
	// texture(TEXTURE, UV) * modulate 가 들어 있다(픽셀 실측: 텍스처 RGBA
	// (.5,.5,.5,.5) + modulate 1.0 → 무개입 0.247 / 재샘플 0.063 = 0.247²).
	// 여기서 `COLOR = texture(...) * COLOR`를 하면 texture²가 되어 먹선·반투명
	// 꼬리·헤일로가 의도보다 어둡고 얇아진다. 이 재질의 책임은 클립뿐이므로
	// 알파에 feather만 곱하고 색은 건드리지 않는다.
	COLOR.a *= clip_fade;
}
"""

static var _mix_shader: Shader = null
static var _add_shader: Shader = null


static func prewarm() -> void:
	_get_shader(false)
	_get_shader(true)


static func build_material(additive: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_shader(additive)
	return material


static func apply_clip(
	material: ShaderMaterial,
	enabled: bool,
	clip_min_px: Vector2,
	clip_max_px: Vector2,
	feather_px: float = 0.0
) -> void:
	if material == null:
		return
	material.set_shader_parameter("screen_clip_enabled", enabled)
	material.set_shader_parameter("screen_clip_min_px", clip_min_px)
	material.set_shader_parameter("screen_clip_max_px", clip_max_px)
	material.set_shader_parameter("screen_clip_feather_px", max(0.0, feather_px))


static func is_screen_clip_material(material: Material, additive: bool = false) -> bool:
	return material is ShaderMaterial and (material as ShaderMaterial).shader == _get_shader(additive)


static func _get_shader(additive: bool) -> Shader:
	if additive:
		if _add_shader == null:
			_add_shader = Shader.new()
			_add_shader.code = ADD_SHADER_CODE
		return _add_shader
	if _mix_shader == null:
		_mix_shader = Shader.new()
		_mix_shader.code = MIX_SHADER_CODE
	return _mix_shader
