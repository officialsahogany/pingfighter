extends RefCounted

# Stage 7 아카무 플레이필드 이펙트의 bake-once 화이트 텍스처 캐시.
#
# 원본 파리티 벡터 스택(바람 오라 글로우 링 6겹, AA 서클 궤도 파티클,
# 극정호신 다크 화염 글로우 2겹+코어, 구름장막 연막 서클)은 프레임당 AA
# 프리미티브 볼륨이 커서(각성 후 actors 패스 0.7ms -> 5~7.4ms 실측,
# 2026-07-11 라이브 로그) 한 번 구운 텍스처의 modulate 블릿으로 치환한다.
# 텍스처는 전부 화이트 + 알파 프로파일이고 색은 호출부 modulate 소유.
#
# 핫패스 lazy bake 금지(CLAUDE.md Godot Hot-Path Lazy Init Trap):
# prewarm_step()을 스테이지 프리웜 체인에서 호출해 프레임당 1장씩 굽고,
# is_ready() 전에는 소비자(stage7_akamu_playfield_renderer)가 기존 벡터
# 폴백을 그린다. 캐시는 static이라 씬 재진입에도 유지된다.

const KEY_FLAT_DISC := "flat_disc"
const KEY_PARTICLE_RIM := "particle_rim"
const KEY_THIN_RING := "thin_ring"
const KEY_AURA_GLOW_STACK := "aura_glow_stack"
const KEY_DARK_FLAME := "dark_flame"
const BAKE_KEYS := [
	KEY_FLAT_DISC,
	KEY_PARTICLE_RIM,
	KEY_THIN_RING,
	KEY_AURA_GLOW_STACK,
	KEY_DARK_FLAME,
]

# 블릿 스케일 기준 반경(px). 소비자는 (목표 반경 / 기준 반경)으로 쿼드를
# 스케일한다. 링 계열은 스케일에 따라 선폭도 같이 늘므로 실사용 반경대의
# 중간값을 기준으로 잡아 원본 대비 선폭 오차를 +-1px 안으로 유지한다.
const FLAT_DISC_BAKE_RADIUS := 30.0
const FLAT_DISC_TEXTURE_SIZE := 64
const PARTICLE_RIM_BAKE_RADIUS := 7.0
const PARTICLE_RIM_TEXTURE_SIZE := 20
const THIN_RING_BAKE_RADIUS := 72.0
const THIN_RING_TEXTURE_SIZE := 160
const AURA_GLOW_BAKE_RADIUS := 70.0
const AURA_GLOW_TEXTURE_SIZE := 176
const AURA_GLOW_RING_COUNT := 6
const AURA_GLOW_RING_STEP := 5.0
const DARK_FLAME_CORE_BAKE_RADIUS := 14.0
const DARK_FLAME_TEXTURE_SIZE := 64

static var _cache: Dictionary = {}


static func is_ready() -> bool:
	for key_value in BAKE_KEYS:
		if not (_cache.get(str(key_value), null) is Texture2D):
			return false
	return true


static func prewarm() -> void:
	while not prewarm_step():
		pass


# 프레임당 1장 bake. 전부 구워지면 true.
static func prewarm_step() -> bool:
	for key_value in BAKE_KEYS:
		var key := str(key_value)
		if _cache.get(key, null) is Texture2D:
			continue
		_cache[key] = _bake(key)
		return is_ready()
	return true


static func get_texture(key: String) -> Texture2D:
	var cached: Variant = _cache.get(key, null)
	return cached as Texture2D if cached is Texture2D else null


static func debug_clear() -> void:
	_cache.clear()


static func _bake(key: String) -> Texture2D:
	match key:
		KEY_FLAT_DISC:
			return _bake_flat_disc()
		KEY_PARTICLE_RIM:
			return _bake_ring(
				PARTICLE_RIM_TEXTURE_SIZE,
				[[PARTICLE_RIM_BAKE_RADIUS, 0.5, 1.0]]
			)
		KEY_THIN_RING:
			return _bake_ring(
				THIN_RING_TEXTURE_SIZE,
				[[THIN_RING_BAKE_RADIUS, 1.0, 1.0]]
			)
		KEY_AURA_GLOW_STACK:
			var rings: Array = []
			for ring_step in range(AURA_GLOW_RING_COUNT):
				# 원본 _draw_wind_aura 글로우 스택: 반경 -5px 계단, 알파
				# (1 - step*5/30) 프로파일. 절대 알파(40/255 * strength)는
				# 호출부 modulate가 곱한다.
				rings.append([
					AURA_GLOW_BAKE_RADIUS - float(ring_step) * AURA_GLOW_RING_STEP,
					1.0,
					1.0 - float(ring_step) * AURA_GLOW_RING_STEP / 30.0,
				])
			return _bake_ring(AURA_GLOW_TEXTURE_SIZE, rings)
		KEY_DARK_FLAME:
			return _bake_dark_flame()
	return null


# 평평한 채움 디스크(가장자리 ~1px 페더). 오라 꼬리/코어, 구름 연막,
# 스파클, 다크 스파크 등 원본 draw_circle 소비자 공용.
static func _bake_flat_disc() -> Texture2D:
	var size := FLAT_DISC_TEXTURE_SIZE
	var radius := FLAT_DISC_BAKE_RADIUS
	var feather := 1.2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2((float(x) + 0.5) - half, (float(y) + 0.5) - half).length()
			var a := clampf((radius + feather - d) / feather, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


# 동심 링 묶음. rings = [[radius_px, half_width_px, alpha], ...]
static func _bake_ring(size: int, rings: Array) -> Texture2D:
	var feather := 0.7
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2((float(x) + 0.5) - half, (float(y) + 0.5) - half).length()
			var a := 0.0
			for ring_value in rings:
				var ring: Array = ring_value
				var ring_radius := float(ring[0])
				if ring_radius <= 0.5:
					continue
				var half_width := float(ring[1])
				var ring_alpha := float(ring[2])
				var edge := absf(d - ring_radius) - half_width
				var coverage := clampf(1.0 - edge / feather, 0.0, 1.0)
				a = maxf(a, coverage * ring_alpha)
			if a > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


# 극정호신 다크 화염: 원본 3서클(글로우 1.8x a=180/255*0.20, 1.3x
# a=180/255*0.32, 코어 1.0x a=200/255)을 알파 합성으로 1장에 굽는다.
# life_ratio는 호출부 modulate.a가 곱한다.
static func _bake_dark_flame() -> Texture2D:
	var size := DARK_FLAME_TEXTURE_SIZE
	var core := DARK_FLAME_CORE_BAKE_RADIUS
	var feather := 1.0
	var layers := [
		[core * 1.8, (180.0 / 255.0) * 0.20],
		[core * 1.3, (180.0 / 255.0) * 0.32],
		[core, 200.0 / 255.0],
	]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2((float(x) + 0.5) - half, (float(y) + 0.5) - half).length()
			var transparency := 1.0
			for layer_value in layers:
				var layer: Array = layer_value
				var coverage := clampf((float(layer[0]) + feather - d) / feather, 0.0, 1.0)
				transparency *= 1.0 - coverage * float(layer[1])
			var a := 1.0 - transparency
			if a > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
