extends SceneTree

const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")
const PillarOrbChromeDrawer := preload("res://scripts/hud/pillar_orb_chrome_drawer.gd")
const PillarStatusOrbRenderer := preload("res://scripts/hud/pillar_status_orb_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_build_now_geometry()
	_verify_budgeted_request_falls_back_then_resumes()
	_verify_bounded_cache()
	_verify_prewarm_populates_static_layer_caches()

	if _failures.is_empty():
		print("pillar_orb_static_layer_cache_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# build_now 는 동기적으로 텍스처를 만들고, 베이크 결과는 op 지오메트리를
# 그대로 담아야 한다 (디스크 중심 = 채움 색, 모서리 = 투명).
func _verify_build_now_geometry() -> void:
	var cache := PillarOrbStaticLayerCache.new()
	var disc_color := Color(0.8, 0.2, 0.1, 1.0)
	var ops: Array = [PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 10.0, disc_color)]
	var texture: Texture2D = cache.build_now("disc", ops)
	_expect(texture != null, "build_now should return a texture synchronously")
	if texture == null:
		return
	var image: Image = texture.get_image()
	var size: int = image.get_width()
	var center_pixel: Color = image.get_pixel(size / 2, size / 2)
	_expect(center_pixel.a > 0.99 and absf(center_pixel.r - disc_color.r) < 0.01, "baked disc center should match the op color")
	_expect(image.get_pixel(0, 0).a < 0.001, "baked texture corners should stay transparent")
	_expect(cache.get_texture("disc") == texture, "second lookup should hit the cache")

	# 닫힌 아크 밴드(풀 서클 링): 링 중심선 위는 칠해지고 한가운데는 비어야 함.
	var ring_ops: Array = [PillarOrbStaticLayerCache.make_arc_band(Vector2.ZERO, 10.0, 0.0, TAU, 24, 3.0, Color(0.1, 0.9, 0.3, 1.0))]
	var ring_texture: Texture2D = cache.build_now("ring", ring_ops)
	_expect(ring_texture != null, "closed arc band should bake")
	if ring_texture != null:
		var ring_image: Image = ring_texture.get_image()
		var ring_size: int = ring_image.get_width()
		var ring_center: float = float(ring_size) * 0.5
		_expect(ring_image.get_pixel(int(ring_center + 10.0), int(ring_center)).a > 0.5, "ring band centerline should be filled")
		_expect(ring_image.get_pixel(int(ring_center), int(ring_center)).a < 0.001, "ring interior should stay empty")


# 핫 프레임에서는 예산을 넘는 빌드가 보류되고(null 반환 = 즉시 경로 폴백),
# 이후 build_now 가 보류 작업을 이어받아 완성할 수 있어야 한다.
func _verify_budgeted_request_falls_back_then_resumes() -> void:
	var cache := PillarOrbStaticLayerCache.new()
	var heavy_ops: Array = []
	for i in range(8):
		heavy_ops.append(PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 120.0, Color(0.2, 0.3, 0.4, 0.5)))
	var first: Texture2D = cache.request_build("heavy", heavy_ops)
	if first == null:
		_expect(cache.is_pending("heavy"), "unfinished budgeted build should stay pending")
		var resumed: Texture2D = cache.build_now("heavy", heavy_ops)
		_expect(resumed != null, "build_now should resume and finish a pending budgeted build")
	else:
		# 머신이 충분히 빨라 예산 안에 끝난 경우도 유효한 결과다.
		_expect(cache.get_texture("heavy") != null, "fast budgeted build should be cached")


func _verify_bounded_cache() -> void:
	var cache := PillarOrbStaticLayerCache.new()
	for i in range(PillarOrbStaticLayerCache.MAX_CACHE_ENTRIES + 1):
		cache.build_now("key_%d" % i, [PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 3.0, Color.WHITE)])
	_expect(cache.get_texture("key_0") == null, "cache should clear on overflow (bounded like pillar_orb_background_cache)")
	_expect(
		cache.get_texture("key_%d" % PillarOrbStaticLayerCache.MAX_CACHE_ENTRIES) != null,
		"newest entry should survive the overflow clear"
	)


# 프리웜 경로가 정적 레이어 캐시(글래스 / 컴팩트 프레임 / 컴팩트 토큰 /
# 정착 분할선)를 실제로 채워야 한다.
func _verify_prewarm_populates_static_layer_caches() -> void:
	var chrome := PillarOrbChromeDrawer.new()
	var steps := 0
	while not chrome.prewarm_static_layers_step() and steps < 32:
		steps += 1
	_expect(
		chrome._static_layer_cache._texture_cache.size() >= PillarOrbChromeDrawer.GLASS_PREWARM_RADII.size(),
		"glass prewarm should bake one texture per radius/rim color"
	)

	var status_renderer := PillarStatusOrbRenderer.new()
	status_renderer.prewarm_caches([20.0])
	var body_cache_size: int = status_renderer.dash_renderer.body_renderer._static_layer_cache._texture_cache.size()
	_expect(body_cache_size >= 1, "boss dash prewarm should bake the compact fallback frame")
	var fill_renderer: Object = status_renderer.dash_renderer.token_renderer.fill_renderer
	_expect(
		fill_renderer._static_layer_cache._texture_cache.size() >= 2,
		"dash prewarm should bake compact full single tokens for player + boss palettes"
	)
	var divider_cache_size: int = fill_renderer.divider_renderer._static_layer_cache._texture_cache.size()
	_expect(divider_cache_size >= 2, "player dash prewarm should bake settled dividers for the common token counts")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
