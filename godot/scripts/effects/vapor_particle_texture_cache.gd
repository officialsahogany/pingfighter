extends RefCounted

# 수증기(기포) 파티클용 사전-합성 알파 밴드 텍스처.
#
# 원본 `draw_laser_evaporation_particles()`는 파티클 1개마다 SRCALPHA 표면을
# 만들고 반경 s / 2s/3 / s/3 원을 큰 것부터 그린다. pygame의 `draw.circle`은
# 알파 블렌딩을 하지 않고 픽셀을 **덮어쓰므로**, 최종 알파는 누적이 아니라
# 바깥 180 / 중간 90 / 중심 60 — 가운데로 갈수록 옅어지는 속 빈 기포다.
#
# Godot 캔버스에 같은 원 3겹을 그대로 겹쳐 그리면 source-over로 합성돼
# 중심이 `1-(1-a)(1-a/2)(1-a/3)` ≈ 0.854까지 차오른 밝은 구체가 된다(원본
# 중심은 a/3 ≈ 0.235). 그래서 밴드를 텍스처에 미리 구워 **한 장**으로 그린다.
# 파티클당 드로우도 3 -> 1로 줄어 80개 이상 버스트에서도 저렴하다.
#
# 알파는 파티클 알파에 대한 **상대값**으로 굽는다(1.0 / 0.5 / 0.333). 드로우
# 시 modulate 알파에 파티클 알파 a를 넣으면 최종이 a / a/2 / a/3 이 된다.

const TEXTURE_SIZE := 64
const BAND_ALPHA_OUTER := 1.0
const BAND_ALPHA_MIDDLE := 0.5
const BAND_ALPHA_CENTER := 1.0 / 3.0

static var _texture: ImageTexture = null


static func prewarm() -> void:
	get_texture()


static func reset_for_test() -> void:
	_texture = null


# 씰 전용: 빌드 없이 캐시 적재 여부만 확인한다(`get_texture()`는 즉시 굽는다).
static func is_built() -> bool:
	return _texture != null


static func get_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	_texture = _build_texture()
	return _texture


static func draw_vapor(canvas: CanvasItem, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	if canvas == null or radius <= 0.0 or alpha <= 0.0:
		return
	var texture: ImageTexture = get_texture()
	if texture == null:
		return
	var diameter: float = radius * 2.0
	canvas.draw_texture_rect(
		texture,
		Rect2(center - Vector2(radius, radius), Vector2(diameter, diameter)),
		false,
		Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))
	)


static func band_alpha_for_distance(normalized_distance: float) -> float:
	if normalized_distance > 1.0:
		return 0.0
	if normalized_distance <= 1.0 / 3.0:
		return BAND_ALPHA_CENTER
	if normalized_distance <= 2.0 / 3.0:
		return BAND_ALPHA_MIDDLE
	return BAND_ALPHA_OUTER


static func _build_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(TEXTURE_SIZE * TEXTURE_SIZE * 4)
	var center_coord: float = (float(TEXTURE_SIZE) - 1.0) * 0.5
	var max_dist: float = max(1.0, center_coord)
	var offset := 0
	for y in range(TEXTURE_SIZE):
		var dy: float = (float(y) - center_coord) / max_dist
		for x in range(TEXTURE_SIZE):
			var dx: float = (float(x) - center_coord) / max_dist
			var band: float = band_alpha_for_distance(sqrt(dx * dx + dy * dy))
			data[offset] = 255
			data[offset + 1] = 255
			data[offset + 2] = 255
			data[offset + 3] = int(round(clamp(band, 0.0, 1.0) * 255.0))
			offset += 4
	var image := Image.create_from_data(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(image)
