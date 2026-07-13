extends RefCounted

# 스매셔 오버드라이브 "폭주" 공 VFX — 순수 절차적(텍스처 없음).
#
# 신호 계약 소비(구독자, Opus 비주얼 레인): 배선이 노출한 스냅샷
# (smasher_overdrive_active / kink_serial / remaining_ratio)만 읽어 얹는다.
# base_heading·물리는 건드리지 않는다.
#
# 좌표: draw()가 받는 pos 는 이미 보간 + shake 가 반영된 스크린 draw 좌표라,
# 매 렌더 프레임 그 pos 를 히스토리에 샘플링하면 공의 실제 지그재그 경로가 곧
# 트레일이 된다(별도 좌표 변환 불필요). 각진 코너는 히스토리 자체가 지그재그라
# 자동으로 나타나고, 킹크 순간엔 kink_serial 증가를 감지해 스파크를 얹는다.

const CYAN := Color(80.0 / 255.0, 225.0 / 255.0, 1.0)
const HOT := Color(0.78, 0.98, 1.0)
const HISTORY_MAX := 26
const SPARK_LIFE := 9.0
const SPARK_MAX := 6

var _history: PackedVector2Array = PackedVector2Array()
var _last_serial := -1
var _sparks: Array = []          # 각 항목: {"pos": Vector2, "age": float, "dir": Vector2}
var _fade := 0.0                 # 0..1 부드러운 인/아웃 엔벨로프
var _pulse_clock := 0.0


func clear() -> void:
	_history = PackedVector2Array()
	_sparks.clear()
	_last_serial = -1
	_fade = 0.0
	_pulse_clock = 0.0


func draw(canvas: CanvasItem, pos: Vector2, fx: Dictionary, ball_vel: Vector2, lod_scale: float) -> void:
	if canvas == null:
		return
	var active: bool = bool(fx.get("smasher_overdrive_active", false))
	advance(pos, active, int(fx.get("kink_serial", 0)), ball_vel)

	if _fade <= 0.001 and _history.size() < 2 and _sparks.is_empty():
		return

	var detail: float = clampf(lod_scale, 0.35, 1.0)
	_draw_trail(canvas, detail)
	_draw_sparks(canvas, detail)
	if active or _fade > 0.02:
		_draw_ball_shell(canvas, pos, detail)


# 상태 전진(렌더와 분리 — 스모크가 draw_* 없이 트레일 로직을 봉인할 수 있게).
func advance(pos: Vector2, active: bool, kink_serial: int, ball_vel: Vector2) -> void:
	_fade = move_toward(_fade, 1.0 if active else 0.0, 0.12)
	_pulse_clock += 0.10
	if active:
		_history.push_back(pos)
		while _history.size() > HISTORY_MAX:
			_history.remove_at(0)
		if _last_serial < 0:
			_last_serial = kink_serial
		elif kink_serial > _last_serial:
			_spawn_kink_spark(pos, ball_vel)
			_last_serial = kink_serial
	elif _history.size() > 0:
		# 비활성: 꼬리부터 한 점씩 흘려보내 트레일을 소멸시킨다.
		_history.remove_at(0)
	_advance_sparks()


func _draw_trail(canvas: CanvasItem, detail: float) -> void:
	var n: int = _history.size()
	if n < 2:
		return
	for i in range(n - 1):
		var head: float = float(i) / float(n - 1)   # 0=꼬리(오래됨) .. 1=머리(공)
		var alpha: float = _fade * lerpf(0.0, 0.60, head)
		if alpha <= 0.01:
			continue
		var a_from: Vector2 = _history[i]
		var a_to: Vector2 = _history[i + 1]
		var glow_w: float = lerpf(3.0, 12.0, head) * detail
		var core_w: float = lerpf(1.0, 4.5, head) * detail
		canvas.draw_line(a_from, a_to, Color(CYAN.r, CYAN.g, CYAN.b, alpha * 0.35), glow_w, true)
		canvas.draw_line(a_from, a_to, Color(HOT.r, HOT.g, HOT.b, alpha), core_w, true)


func _spawn_kink_spark(pos: Vector2, ball_vel: Vector2) -> void:
	var dir: Vector2 = ball_vel.normalized() if ball_vel.length_squared() > 0.01 else Vector2(0.0, -1.0)
	_sparks.push_back({"pos": pos, "age": 0.0, "dir": dir})
	while _sparks.size() > SPARK_MAX:
		_sparks.remove_at(0)


func _advance_sparks() -> void:
	var i: int = _sparks.size() - 1
	while i >= 0:
		var spark: Dictionary = _sparks[i]
		var age: float = float(spark.get("age", 0.0)) + 1.0
		spark["age"] = age
		if age >= SPARK_LIFE:
			_sparks.remove_at(i)
		i -= 1


func _draw_sparks(canvas: CanvasItem, detail: float) -> void:
	for spark_variant in _sparks:
		if not (spark_variant is Dictionary):
			continue
		var spark: Dictionary = spark_variant
		var life_t: float = clampf(float(spark.get("age", 0.0)) / SPARK_LIFE, 0.0, 1.0)
		# 스파크는 개별 이벤트라 _fade 와 무관하게 자기 수명 알파로 그린다.
		var fade_out: float = 1.0 - life_t
		var reach: float = lerpf(6.0, 26.0, _ease_out(life_t)) * detail
		var p: Vector2 = _dict_vec(spark, "pos")
		var dir: Vector2 = _dict_vec(spark, "dir")
		var perp := Vector2(-dir.y, dir.x)
		var hot_col := Color(HOT.r, HOT.g, HOT.b, fade_out * 0.9)
		canvas.draw_line(p, p + perp * reach, hot_col, 2.4 * detail, true)
		canvas.draw_line(p, p - perp * reach, hot_col, 2.4 * detail, true)
		canvas.draw_line(p, p + dir * (reach * 0.5), Color(CYAN.r, CYAN.g, CYAN.b, fade_out * 0.5), 2.0 * detail, true)


func _draw_ball_shell(canvas: CanvasItem, pos: Vector2, detail: float) -> void:
	var r: float = 20.0 * detail
	var pulse: float = 0.5 + 0.5 * sin(_pulse_clock * 2.3)
	var a: float = _fade * lerpf(0.30, 0.55, pulse)
	if a <= 0.01:
		return
	var seg: int = 20
	canvas.draw_arc(pos, r + pulse * 3.0, 0.0, TAU, seg, Color(CYAN.r, CYAN.g, CYAN.b, a), 2.2 * detail, true)
	canvas.draw_arc(pos, r * 0.7, 0.0, TAU, seg, Color(HOT.r, HOT.g, HOT.b, a * 0.6), 1.4 * detail, true)
	# 회전하는 과부하 틱 4개
	var base_ang: float = _pulse_clock * 1.7
	for k in range(4):
		var ang: float = base_ang + float(k) * (TAU / 4.0)
		var d := Vector2(cos(ang), sin(ang))
		canvas.draw_line(pos + d * (r * 0.9), pos + d * (r * 1.5), Color(HOT.r, HOT.g, HOT.b, a * 0.7), 2.0 * detail, true)


func _dict_vec(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _ease_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)
