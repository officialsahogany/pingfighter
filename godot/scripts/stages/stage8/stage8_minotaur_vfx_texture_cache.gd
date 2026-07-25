extends RefCounted

# Stage 8 미노타우로스 플레이필드 이펙트의 bake-once 화이트 텍스처 캐시.
#
# Stage 7 아카무 캐시(stage7_akamu_vfx_texture_cache.gd)에서 포팅한
# 셸(Slice 1). 아직 지진/돌진/파편 등 실제 VFX가 없으므로 bake 키를 최소
# 집합(평면 디스크 + 얇은 링)으로 줄였다. 이후 슬라이스에서 미노타우로스
# 전용 이펙트가 확정되면 키/베이크 헬퍼를 확장한다.
# 텍스처는 전부 화이트 + 알파 프로파일이고 색은 호출부 modulate 소유.
#
# 핫패스 lazy bake 금지(CLAUDE.md Godot Hot-Path Lazy Init Trap):
# prewarm_step()을 스테이지 프리웜 체인에서 호출해 프레임당 1장씩 굽고,
# is_ready() 전에는 소비자(stage8_minotaur_playfield_renderer)가 기존 벡터
# 폴백을 그린다. 캐시는 static이라 씬 재진입에도 유지된다.
#
# _cache 키는 stage8 접두사로 스테이지-스코프한다. static var는 클래스별로
# 분리되지만, 접두사를 유지해 로그/디버그에서 stage7 캐시와 절대 혼동되지
# 않게 한다.

const KEY_FLAT_DISC := "stage8_minotaur_flat_disc"
const KEY_THIN_RING := "stage8_minotaur_thin_ring"
const BAKE_KEYS := [
	KEY_FLAT_DISC,
	KEY_THIN_RING,
]

# 블릿 스케일 기준 반경(px). 소비자는 (목표 반경 / 기준 반경)으로 쿼드를
# 스케일한다. 링 계열은 스케일에 따라 선폭도 같이 늘므로 실사용 반경대의
# 중간값을 기준으로 잡아 원본 대비 선폭 오차를 +-1px 안으로 유지한다.
const FLAT_DISC_BAKE_RADIUS := 30.0
const FLAT_DISC_TEXTURE_SIZE := 64
const THIN_RING_BAKE_RADIUS := 72.0
const THIN_RING_TEXTURE_SIZE := 160

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
		KEY_THIN_RING:
			return _bake_ring(
				THIN_RING_TEXTURE_SIZE,
				[[THIN_RING_BAKE_RADIUS, 1.0, 1.0]]
			)
	return null


# 평평한 채움 디스크(가장자리 ~1px 페더). 오라 꼬리/코어, 연막, 스파클,
# 스파크 등 원본 draw_circle 소비자 공용.
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
