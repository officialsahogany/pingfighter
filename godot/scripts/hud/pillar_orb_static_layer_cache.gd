extends RefCounted

# 필러 HUD 오브 체인의 "정적 레이어"(오브 글래스 하이라이트, 보스 대쉬 컴팩트
# 폴백 프레임, 정착 상태의 대쉬 토큰 분할선, 컴팩트 풀 단일 토큰)를 한 번만
# ImageTexture로 베이크해서, 매 프레임 N개의 벡터 프리미티브 대신 blit 1회로
# 그리게 하는 캐시. pillar_orb_background_cache.gd 의 키/바운드 정책을 따른다.
#
# 시각 패리티 규칙 (이 모듈의 존재 이유):
# - 래스터는 "지오메트리 동일" 원칙: 폴리곤 / 폴리라인 밴드는 즉시 드로우 경로가
#   draw_colored_polygon / draw_arc 에 넘기는 것과 동일한 점 리스트를 픽셀 중심
#   스캔라인으로 채운다(GPU 비-AA 래스터와 같은 커버리지 규칙). 원은 해석적으로
#   채운다(Godot draw_circle 의 내부 다각형 근사와의 편차는 HUD 반경에서 0.1px
#   미만).
# - 한 베이크 안의 레이어 순서는 즉시 드로우 순서와 같고, straight-alpha
#   "over" 블렌드는 결합법칙이 성립하므로 blit 결과는 개별 드로우 합성과 동일.
# - AA 아크(antialiased=true 로 그리던 림 아크)만 해석적 1px 페더 밴드로
#   래스터한다(세그먼트 현 편차 0.2px 미만 케이스에만 사용).
#
# 빌드 스케줄 (Godot Hot-Path Lazy Init Trap 준수):
# - request_build() 는 핫 프레임에서 통째로 베이크하지 않는다. 누락 키는 큐에
#   넣고 모든 캐시 인스턴스가 공유하는 프레임당 시간 예산
#   (BUILD_BUDGET_USEC_PER_FRAME) 안에서만 진행한다. 호출자는 텍스처가 준비될
#   때까지 기존 즉시 벡터 경로를 그대로 사용한다(빌드 중에도 시각 동일).
# - build_now() 는 로딩 프리웜 단계 전용 동기 빌드 경로다.

const MAX_CACHE_ENTRIES := 24
const BUILD_BUDGET_USEC_PER_FRAME := 700
const ROWS_PER_BUDGET_CHECK := 8
const ROW_CURSOR_UNSET := -2147483648

# 프레임당 빌드 예산은 스크립트 단위로 공유한다. 여러 렌더러가 각자 캐시
# 인스턴스를 들고 있어도 한 프레임의 총 베이크 비용이 예산을 넘지 않는다.
static var _shared_budget_frame: int = -1
static var _shared_budget_used_usec: int = 0

var _texture_cache: Dictionary = {}
var _pending_jobs: Dictionary = {}
var _pending_order: Array[String] = []


func get_texture(key: String) -> Texture2D:
	if not _pending_order.is_empty():
		_advance_pending_with_frame_budget()
	var cached: Variant = _texture_cache.get(key, null)
	if cached is Texture2D:
		return cached
	return null


func is_pending(key: String) -> bool:
	return _pending_jobs.has(key)


# 누락 키를 빌드 큐에 등록하고, 이번 프레임 예산 안에서 진행한다. 예산 안에
# 완성되면 텍스처를, 아니면 null 을 돌려준다(호출자는 즉시 경로로 폴백).
func request_build(key: String, ops: Array) -> Texture2D:
	var cached: Variant = _texture_cache.get(key, null)
	if cached is Texture2D:
		return cached
	if not _pending_jobs.has(key):
		_enqueue_job(key, ops)
	_advance_pending_with_frame_budget()
	cached = _texture_cache.get(key, null)
	if cached is Texture2D:
		return cached
	return null


# 로딩 프리웜 전용 동기 빌드. 큐 앞쪽의 다른 보류 작업도 함께 처리한다.
func build_now(key: String, ops: Array) -> Texture2D:
	var cached: Variant = _texture_cache.get(key, null)
	if cached is Texture2D:
		return cached
	if not _pending_jobs.has(key):
		_enqueue_job(key, ops)
	while _pending_jobs.has(key):
		_advance_pending_until(Time.get_ticks_usec() + 1000000)
	cached = _texture_cache.get(key, null)
	if cached is Texture2D:
		return cached
	return null


func draw_centered(canvas: CanvasItem, texture: Texture2D, center: Vector2) -> void:
	if canvas == null or texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	canvas.draw_texture_rect(texture, Rect2(center - texture_size * 0.5, texture_size), false)


static func color_key(color: Color) -> String:
	return "%03d%03d%03d%03d" % [
		int(round(clamp(color.r, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.g, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.b, 0.0, 1.0) * 255.0)),
		int(round(clamp(color.a, 0.0, 1.0) * 255.0)),
	]


# --- op 빌더 (좌표는 오브 중심 = (0, 0) 기준 로컬) ---


static func make_circle(center: Vector2, radius: float, color: Color) -> Dictionary:
	return {"kind": "circle", "center": center, "radius": max(0.0, radius), "color": color}


static func make_polygon(points: PackedVector2Array, color: Color) -> Dictionary:
	var rings: Array = [points]
	return {"kind": "poly", "rings": rings, "color": color}


# draw_line(width > 1, 비-AA)와 동일한 사각형 지오메트리.
static func make_line(from_point: Vector2, to_point: Vector2, width: float, color: Color) -> Dictionary:
	var direction: Vector2 = to_point - from_point
	if direction.length_squared() <= 0.000001:
		return make_polygon(PackedVector2Array(), color)
	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized() * (max(0.0, width) * 0.5)
	return make_polygon(PackedVector2Array([
		from_point + normal,
		to_point + normal,
		to_point - normal,
		from_point - normal,
	]), color)


# draw_arc(point_count, width, 비-AA)와 동일한 폴리라인 밴드. 닫힌(풀 서클)
# 아크는 바깥/안쪽 두 링의 even-odd 채움으로, 열린 아크는 단일 밴드 폴리곤으로
# 래스터된다. 점 샘플링은 draw_arc 와 동일(양 끝 포함 균등 분할).
static func make_arc_band(
	center: Vector2,
	radius: float,
	start_rad: float,
	end_rad: float,
	point_count: int,
	width: float,
	color: Color
) -> Dictionary:
	var count: int = max(2, point_count)
	var closed: bool = absf(absf(end_rad - start_rad) - TAU) < 0.0001
	var sample_count: int = count - 1 if closed else count
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(sample_count):
		var ratio: float = float(i) / float(count - 1)
		var angle: float = start_rad + (end_rad - start_rad) * ratio
		var direction := Vector2(cos(angle), sin(angle))
		outer.append(center + direction * (radius + width * 0.5))
		inner.append(center + direction * (radius - width * 0.5))
	if closed:
		var rings: Array = [outer, inner]
		return {"kind": "poly", "rings": rings, "color": color}
	var band := PackedVector2Array()
	band.append_array(outer)
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	return make_polygon(band, color)


# draw_arc(..., antialiased = true) 대응: 해석적 원호 밴드 + 1px 선형 페더.
static func make_arc_band_aa(
	center: Vector2,
	radius: float,
	start_rad: float,
	end_rad: float,
	width: float,
	color: Color
) -> Dictionary:
	return {
		"kind": "arc_aa",
		"center": center,
		"radius": max(0.0, radius),
		"half_width": max(0.0, width) * 0.5,
		"start_rad": start_rad,
		"end_rad": end_rad,
		"color": color,
	}


# --- 내부: 잡 큐 / 예산 ---


func _enqueue_job(key: String, ops: Array) -> void:
	var extent: float = 0.0
	for op_value in ops:
		if op_value is Dictionary:
			extent = max(extent, _op_extent(op_value))
	var size: int = max(8, int(ceil(extent * 2.0)) + 4)
	var offset := Vector2(float(size), float(size)) * 0.5
	var translated_ops: Array = []
	for op_value in ops:
		if op_value is Dictionary:
			translated_ops.append(_translate_op(op_value, offset))
	_pending_jobs[key] = {
		"image": Image.create(size, size, false, Image.FORMAT_RGBA8),
		"ops": translated_ops,
		"op_index": 0,
		"row_cursor": ROW_CURSOR_UNSET,
		"size": size,
	}
	_pending_order.append(key)


func _advance_pending_with_frame_budget() -> void:
	if _pending_order.is_empty():
		return
	var frame: int = Engine.get_process_frames()
	if frame != _shared_budget_frame:
		_shared_budget_frame = frame
		_shared_budget_used_usec = 0
	var remaining: int = BUILD_BUDGET_USEC_PER_FRAME - _shared_budget_used_usec
	if remaining <= 0:
		return
	var start_usec: int = Time.get_ticks_usec()
	_advance_pending_until(start_usec + remaining)
	_shared_budget_used_usec += int(Time.get_ticks_usec() - start_usec)


func _advance_pending_until(deadline_usec: int) -> void:
	while not _pending_order.is_empty():
		var key: String = _pending_order[0]
		var job: Variant = _pending_jobs.get(key, null)
		if not (job is Dictionary):
			_pending_order.pop_front()
			continue
		if not _advance_job(job, deadline_usec):
			return
		_finalize_job(key, job)
		_pending_order.pop_front()
		_pending_jobs.erase(key)


# true = 잡 완료. 예산 초과 시 진행 위치(op_index / row_cursor)를 저장하고 false.
func _advance_job(job: Dictionary, deadline_usec: int) -> bool:
	var image: Image = job["image"]
	var ops: Array = job["ops"]
	var op_index: int = int(job["op_index"])
	var row_cursor: int = int(job["row_cursor"])
	var size: int = int(job["size"])
	while op_index < ops.size():
		var op: Dictionary = ops[op_index]
		var row_range: Vector2i = _op_row_range(op, size)
		if row_cursor == ROW_CURSOR_UNSET:
			row_cursor = row_range.x
		var rows_since_check := 0
		while row_cursor <= row_range.y:
			_raster_op_row(image, op, row_cursor, size)
			row_cursor += 1
			rows_since_check += 1
			if rows_since_check >= ROWS_PER_BUDGET_CHECK:
				rows_since_check = 0
				if Time.get_ticks_usec() >= deadline_usec:
					job["op_index"] = op_index
					job["row_cursor"] = row_cursor
					return false
		op_index += 1
		row_cursor = ROW_CURSOR_UNSET
	job["op_index"] = op_index
	job["row_cursor"] = ROW_CURSOR_UNSET
	return true


func _finalize_job(key: String, job: Dictionary) -> void:
	var image: Image = job["image"]
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if _texture_cache.size() >= MAX_CACHE_ENTRIES:
		_texture_cache.clear()
	_texture_cache[key] = texture


# --- 내부: 지오메트리 ---


static func _op_extent(op: Dictionary) -> float:
	match str(op.get("kind", "")):
		"circle":
			var circle_center: Vector2 = op.get("center", Vector2.ZERO)
			return max(absf(circle_center.x), absf(circle_center.y)) + float(op.get("radius", 0.0))
		"poly":
			var extent := 0.0
			for ring_value in op.get("rings", []):
				var ring: PackedVector2Array = ring_value
				for point in ring:
					extent = max(extent, max(absf(point.x), absf(point.y)))
			return extent
		"arc_aa":
			var arc_center: Vector2 = op.get("center", Vector2.ZERO)
			return (
				max(absf(arc_center.x), absf(arc_center.y))
				+ float(op.get("radius", 0.0))
				+ float(op.get("half_width", 0.0))
				+ 1.5
			)
	return 0.0


static func _translate_op(op: Dictionary, offset: Vector2) -> Dictionary:
	var translated: Dictionary = op.duplicate()
	match str(op.get("kind", "")):
		"circle", "arc_aa":
			var center: Vector2 = op.get("center", Vector2.ZERO)
			translated["center"] = center + offset
		"poly":
			var rings: Array = []
			for ring_value in op.get("rings", []):
				var ring: PackedVector2Array = ring_value
				var moved := PackedVector2Array()
				moved.resize(ring.size())
				for i in range(ring.size()):
					moved[i] = ring[i] + offset
				rings.append(moved)
			translated["rings"] = rings
	return translated


static func _op_row_range(op: Dictionary, size: int) -> Vector2i:
	var min_y: float = 0.0
	var max_y: float = float(size - 1)
	match str(op.get("kind", "")):
		"circle":
			var circle_center: Vector2 = op.get("center", Vector2.ZERO)
			var radius: float = float(op.get("radius", 0.0))
			min_y = circle_center.y - radius
			max_y = circle_center.y + radius
		"poly":
			min_y = float(size)
			max_y = -1.0
			for ring_value in op.get("rings", []):
				var ring: PackedVector2Array = ring_value
				for point in ring:
					min_y = min(min_y, point.y)
					max_y = max(max_y, point.y)
		"arc_aa":
			var arc_center: Vector2 = op.get("center", Vector2.ZERO)
			var reach: float = float(op.get("radius", 0.0)) + float(op.get("half_width", 0.0)) + 1.0
			min_y = arc_center.y - reach
			max_y = arc_center.y + reach
	return Vector2i(
		max(0, int(floor(min_y))),
		min(size - 1, int(ceil(max_y)))
	)


static func _raster_op_row(image: Image, op: Dictionary, y: int, size: int) -> void:
	match str(op.get("kind", "")):
		"circle":
			_raster_circle_row(image, op, y, size)
		"poly":
			_raster_poly_row(image, op, y, size)
		"arc_aa":
			_raster_arc_aa_row(image, op, y, size)


static func _raster_circle_row(image: Image, op: Dictionary, y: int, size: int) -> void:
	var center: Vector2 = op["center"]
	var radius: float = float(op["radius"])
	var color: Color = op["color"]
	var dy: float = (float(y) + 0.5) - center.y
	var rest: float = radius * radius - dy * dy
	if rest <= 0.0:
		return
	var half: float = sqrt(rest)
	var x_start: int = max(0, int(ceil(center.x - half - 0.5)))
	var x_end: int = min(size - 1, int(ceil(center.x + half - 0.5)) - 1)
	for x in range(x_start, x_end + 1):
		_blend_pixel(image, x, y, color)


static func _raster_poly_row(image: Image, op: Dictionary, y: int, size: int) -> void:
	var color: Color = op["color"]
	var t: float = float(y) + 0.5
	var crossings := PackedFloat32Array()
	for ring_value in op.get("rings", []):
		var ring: PackedVector2Array = ring_value
		var count: int = ring.size()
		if count < 3:
			continue
		for i in range(count):
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % count]
			if (a.y <= t) == (b.y <= t):
				continue
			crossings.append(a.x + (t - a.y) * (b.x - a.x) / (b.y - a.y))
	if crossings.size() < 2:
		return
	crossings.sort()
	var pair_index := 0
	while pair_index + 1 < crossings.size():
		var x_start: int = max(0, int(ceil(crossings[pair_index] - 0.5)))
		var x_end: int = min(size - 1, int(ceil(crossings[pair_index + 1] - 0.5)) - 1)
		for x in range(x_start, x_end + 1):
			_blend_pixel(image, x, y, color)
		pair_index += 2


static func _raster_arc_aa_row(image: Image, op: Dictionary, y: int, size: int) -> void:
	var center: Vector2 = op["center"]
	var radius: float = float(op["radius"])
	var half_width: float = float(op["half_width"])
	var start_rad: float = float(op["start_rad"])
	var sweep: float = float(op["end_rad"]) - start_rad
	var color: Color = op["color"]
	var dy: float = (float(y) + 0.5) - center.y
	var outer_limit: float = radius + half_width + 1.0
	var rest: float = outer_limit * outer_limit - dy * dy
	if rest <= 0.0:
		return
	var half: float = sqrt(rest)
	var x_start: int = max(0, int(ceil(center.x - half - 0.5)))
	var x_end: int = min(size - 1, int(ceil(center.x + half - 0.5)) - 1)
	var inner_limit: float = max(0.0, radius - half_width - 1.0)
	var inner_limit_sq: float = inner_limit * inner_limit
	for x in range(x_start, x_end + 1):
		var dx: float = (float(x) + 0.5) - center.x
		var dist_sq: float = dx * dx + dy * dy
		if dist_sq <= inner_limit_sq:
			continue
		var dist: float = sqrt(dist_sq)
		var radial_coverage: float = clamp(half_width + 0.5 - absf(dist - radius), 0.0, 1.0)
		if radial_coverage <= 0.0:
			continue
		var rel: float = fposmod(atan2(dy, dx) - start_rad, TAU)
		var inside: float = min(rel, sweep - rel)
		var angular_coverage: float = clamp(inside * dist + 0.5, 0.0, 1.0)
		if angular_coverage <= 0.0:
			continue
		_blend_pixel(image, x, y, Color(color.r, color.g, color.b, color.a * radial_coverage * angular_coverage))


# straight-alpha "over" 블렌드 (캔버스 기본 블렌드와 결합법칙으로 동치).
static func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if color.a <= 0.0005:
		return
	if color.a >= 0.9995:
		image.set_pixel(x, y, color)
		return
	var dst: Color = image.get_pixel(x, y)
	if dst.a <= 0.0005:
		image.set_pixel(x, y, color)
		return
	var out_a: float = color.a + dst.a * (1.0 - color.a)
	image.set_pixel(x, y, Color(
		(color.r * color.a + dst.r * dst.a * (1.0 - color.a)) / out_a,
		(color.g * color.a + dst.g * dst.a * (1.0 - color.a)) / out_a,
		(color.b * color.a + dst.b * dst.a * (1.0 - color.a)) / out_a,
		out_a
	))
