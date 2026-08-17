extends RefCounted

# 스매셔 풍운천선무(風雲天旋舞) 회선반동 공 VFX — 순수 절차적(텍스처 없음).
#
# 이 초식은 이펙트가 캐릭터 모션에만 붙어 있어서, 정작 하이라이트인 **공의
# 회선**이 1차 반격과 똑같이 보였다. 여기서 공 쪽 정체성을 따로 세운다.
#
# 정체성 = 풍운(감긴 구름) + 천선무(회전). 3단계를 시각으로 분리한다:
#   · 선회  = 공 경로 자체가 사이클로이드 고리 → 두껍고 긴 구름 띠로 그 고리를
#             드러내고, 바깥으로 구름 조각을 흘린다
#   · 재발사 = 감았던 기운이 한 점에서 터지는 단발 순간(시드 고정)
#   · 감속  = 감고 있던 구름 띠가 **뒤로 벗겨져 흩어진다**. 추진력을 잃는 게
#             아니라 "감았던 기운이 풀린다"로 읽히게 한다(사용자 확정 방향).
#
# 신호 계약 소비(구독자, Opus 비주얼 레인): 배선이 노출한 스냅샷
# (wheel_rebound_looping / _fading / _fade_ratio / _speed_ratio / _serial)만
# 읽어 얹는다. 물리·속도는 건드리지 않는다 — 조향은 smasher_wheel_state 소유다.
#
# 좌표: draw()가 받는 pos 는 이미 보간 + shake 가 반영된 스크린 draw 좌표라,
# 매 렌더 프레임 그 pos 를 히스토리에 샘플링하면 공의 실제 경로가 곧 트레일이
# 된다(별도 좌표 변환 불필요) — 벽력유성 트레일과 같은 규약.
#
# ⚠️히스토리는 벽력유성(26)보다 길어야 한다. 회선은 45프레임 동안 고리를 두
# 바퀴 그리므로, 짧으면 꼬리가 고리를 다 못 담아 "빙글"이 아니라 그냥 곡선이 된다.
#
# ⚠️흔들림 정책(벽력유성과 동일 규칙): **재발사 폭발은 시드 고정(형태 불변),
# 구름 조각의 부유는 점멸**이다. 폭발이 매 프레임 재추첨되면 "한 번 터짐"이
# 노이즈로 뭉개진다.

const PALE := Color(0.64, 0.84, 1.0)      # smasher_wheel 초식 색
const HOT := Color(0.92, 0.97, 1.0)
const HISTORY_MAX := 52                    # 2바퀴 고리를 담는 길이
const PUFF_MAX := 14
const PUFF_LIFE := 26.0
const PUFF_STRIDE := 5                     # 몇 번째 히스토리 점마다 구름을 흘릴지
const BURST_CORE_RATIO := 0.24
const BURST_RING_MAX_R := 46.0
const BURST_ARC_COUNT := 7
const BURST_LIFE := 16.0
# 감속 = 띠가 뒤로 벗겨진다. 꼬리 앞부분부터 투명해지며 폭이 부풀어 흩어진다.
const SHED_WIDEN := 2.6                    # 벗겨질수록 띠 폭 배수
const SHED_PUFF_BURST := 3                 # 감속 진입 시 한 번에 떨구는 조각 수
const TRAIL_WIDTH := 7.0
const FLICKER_STEP := 3.0

var _history: PackedVector2Array = PackedVector2Array()
var _puffs: Array = []                     # {"pos", "age", "drift", "seed", "radius"}
var _last_serial := -1
var _fade := 0.0                           # 0..1 인/아웃 엔벨로프
var _shed := 0.0                           # 0..1 감속(벗겨짐) 진행도
var _burst_age := -1.0
var _burst_pos := Vector2.ZERO
var _burst_seed := 0
var _clock := 0.0


func clear() -> void:
	_history = PackedVector2Array()
	_puffs.clear()
	_last_serial = -1
	_fade = 0.0
	_shed = 0.0
	_burst_age = -1.0
	_burst_pos = Vector2.ZERO
	_burst_seed = 0
	_clock = 0.0


func draw(
	canvas: CanvasItem,
	pos: Vector2,
	fx: Dictionary,
	ball_vel: Vector2,
	lod_scale: float,
	render_alpha: float = 1.0
) -> void:
	if canvas == null:
		return
	var looping: bool = bool(fx.get("wheel_rebound_looping", false))
	var fading: bool = bool(fx.get("wheel_rebound_fading", false))
	advance(
		pos,
		looping,
		fading,
		clampf(float(fx.get("wheel_rebound_fade_ratio", 0.0)), 0.0, 1.0),
		int(fx.get("wheel_rebound_serial", 0))
	)

	if _fade <= 0.001 and _history.size() < 2 and _puffs.is_empty() and _burst_age < 0.0:
		return

	var detail: float = clampf(lod_scale, 0.35, 1.0)
	var alpha_scale: float = clampf(render_alpha, 0.0, 1.0)
	_draw_trail(canvas, detail, alpha_scale)
	_draw_puffs(canvas, detail, alpha_scale)
	if _burst_age >= 0.0:
		_draw_burst(canvas, detail, alpha_scale)
	if _fade > 0.02:
		_draw_ball_wrap(canvas, pos, ball_vel, detail, alpha_scale)


# 상태 전진. 그리기와 분리해 두면 씰이 히스토리·엔벨로프만 따로 검증할 수 있다.
func advance(pos: Vector2, looping: bool, fading: bool, fade_ratio: float, serial: int) -> void:
	_clock += 1.0
	var live: bool = looping or fading
	# 새 회선 = 히스토리 리셋. 안 지우면 직전 회선의 고리가 이어붙어 보인다.
	if serial != _last_serial:
		if serial > 0 and looping:
			_history = PackedVector2Array()
			_puffs.clear()
			_shed = 0.0
		_last_serial = serial

	_fade = clampf(_fade + (0.16 if live else -0.09), 0.0, 1.0)
	# 감속 진행도는 신호를 그대로 쓴다 — 속도 숫자와 그림이 정확히 동기화된다.
	if fading:
		if _shed <= 0.0:
			_shed_burst(pos)
		_shed = maxf(_shed, fade_ratio)
	elif looping:
		_shed = 0.0

	if live:
		_history.append(pos)
		while _history.size() > HISTORY_MAX:
			_history.remove_at(0)
		if int(_clock) % PUFF_STRIDE == 0:
			_spawn_puff(pos, 1.0 + _shed * 1.4)
	elif _history.size() > 0:
		# 소멸: 꼬리를 앞에서부터 걷어낸다(뚝 끊기지 않게).
		_history.remove_at(0)

	var kept: Array = []
	for puff in _puffs:
		var next: Dictionary = puff
		next["age"] = float(next.get("age", 0.0)) + 1.0
		next["pos"] = _get_vec(next, "pos") + _get_vec(next, "drift")
		if float(next["age"]) < PUFF_LIFE:
			kept.append(next)
	_puffs = kept

	if _burst_age >= 0.0:
		_burst_age += 1.0
		if _burst_age >= BURST_LIFE:
			_burst_age = -1.0


func notify_launch_burst(pos: Vector2, seed_value: int) -> void:
	_burst_age = 0.0
	_burst_pos = pos
	_burst_seed = seed_value


func get_debug_state() -> Dictionary:
	return {
		"history_size": _history.size(),
		"puff_count": _puffs.size(),
		"fade": _fade,
		"shed": _shed,
		"burst_active": _burst_age >= 0.0,
	}


func _shed_burst(pos: Vector2) -> void:
	# 감속 진입 프레임 = 재발사 순간이다(선회가 끝나고 보스로 쏘아지는 그 프레임).
	# 시그니처 순간이므로 폭발을 여기서 단발로 띄우고, 감고 있던 구름이 한 번에
	# 벗겨지기 시작하는 신호도 같이 낸다. 시드는 serial 고정 — 매 프레임 재추첨
	# 하면 "한 번 터짐"이 노이즈로 뭉개진다.
	notify_launch_burst(pos, _last_serial * 5381 + 17)
	for i in range(SHED_PUFF_BURST):
		_spawn_puff(pos, 1.6 + float(i) * 0.3)


func _get_vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _spawn_puff(pos: Vector2, scale_hint: float) -> void:
	if _puffs.size() >= PUFF_MAX:
		_puffs.remove_at(0)
	var seed_value: int = int(_clock) * 7919 + _puffs.size() * 131
	var angle: float = float(seed_value % 360) * TAU / 360.0
	# 벗겨질수록 바깥으로 더 멀리 흩어진다.
	var drift_speed: float = 0.5 + _shed * 1.5
	_puffs.append({
		"pos": pos,
		"age": 0.0,
		"drift": Vector2.from_angle(angle) * drift_speed,
		"seed": seed_value,
		"radius": (5.0 + float(seed_value % 5)) * scale_hint,
	})


func _draw_trail(canvas: CanvasItem, detail: float, alpha_scale: float) -> void:
	if _history.size() < 2:
		return
	var count: int = _history.size()
	for i in range(count - 1):
		var head_ratio: float = float(i) / float(max(1, count - 1))
		# 꼬리 끝(오래된 점)일수록 옅다. 감속이 진행되면 앞쪽부터 추가로 벗겨진다.
		var life: float = head_ratio
		var shed_cut: float = _shed * 0.85
		if life < shed_cut:
			continue
		var alpha: float = life * _fade * 0.55 * alpha_scale
		if alpha <= 0.01:
			continue
		# 벗겨지는 구간은 폭이 부풀며 흩어진다.
		var widen: float = 1.0 + _shed * SHED_WIDEN * (1.0 - life)
		var width: float = TRAIL_WIDTH * life * widen * detail
		if width <= 0.35:
			continue
		var color := PALE
		color.a = alpha * (1.0 - _shed * 0.5)
		canvas.draw_line(_history[i], _history[i + 1], color, width)


func _draw_puffs(canvas: CanvasItem, detail: float, alpha_scale: float) -> void:
	for puff in _puffs:
		var age: float = float(puff.get("age", 0.0))
		var t: float = clampf(age / PUFF_LIFE, 0.0, 1.0)
		var alpha: float = (1.0 - t) * 0.42 * maxf(_fade, _shed) * alpha_scale
		if alpha <= 0.01:
			continue
		var radius: float = float(puff.get("radius", 6.0)) * (0.7 + t * 0.9) * detail
		var color := PALE
		color.a = alpha
		canvas.draw_circle(_get_vec(puff, "pos"), radius, color)


func _draw_burst(canvas: CanvasItem, detail: float, alpha_scale: float) -> void:
	var t: float = clampf(_burst_age / BURST_LIFE, 0.0, 1.0)
	# 코어 섬광은 앞부분에서만 산다 — "잠시 터진다"로 읽히게.
	if t < BURST_CORE_RATIO:
		var core_alpha: float = (1.0 - t / BURST_CORE_RATIO) * 0.9 * alpha_scale
		var core := HOT
		core.a = core_alpha
		canvas.draw_circle(_burst_pos, 11.0 * detail, core)
	var ring_r: float = BURST_RING_MAX_R * t * detail
	var ring := PALE
	ring.a = (1.0 - t) * 0.5 * alpha_scale
	if ring.a > 0.01 and ring_r > 1.0:
		canvas.draw_arc(_burst_pos, ring_r, 0.0, TAU, 24, ring, 2.0 * detail)
	# 갈래는 시드 고정 — 매 프레임 재추첨하면 단발 순간이 노이즈로 뭉개진다.
	for i in range(BURST_ARC_COUNT):
		var seed_value: int = _burst_seed + i * 97
		var angle: float = float(seed_value % 360) * TAU / 360.0
		var length: float = (18.0 + float(seed_value % 13)) * (0.4 + t) * detail
		var arc := PALE
		arc.a = (1.0 - t) * 0.45 * alpha_scale
		if arc.a <= 0.01:
			continue
		var dir := Vector2.from_angle(angle)
		canvas.draw_line(_burst_pos + dir * ring_r * 0.5, _burst_pos + dir * (ring_r * 0.5 + length), arc, 2.0 * detail)


func _draw_ball_wrap(
	canvas: CanvasItem,
	pos: Vector2,
	ball_vel: Vector2,
	detail: float,
	alpha_scale: float
) -> void:
	# 공을 감고 있는 구름 띠. 감속이 진행되면 벌어지며 옅어진다.
	var heading: Vector2 = ball_vel.normalized() if ball_vel.length_squared() > 0.01 else Vector2(0.0, -1.0)
	var flicker: float = float(int(_clock / FLICKER_STEP) % 3) * 0.08
	var radius: float = (12.0 + _shed * 9.0 + flicker * 4.0) * detail
	var wrap := PALE
	wrap.a = _fade * (0.5 - _shed * 0.35) * alpha_scale
	if wrap.a <= 0.01:
		return
	var start: float = heading.angle() - PI * 0.55
	canvas.draw_arc(pos, radius, start, start + PI * 1.1, 18, wrap, (2.4 - _shed * 1.2) * detail)
