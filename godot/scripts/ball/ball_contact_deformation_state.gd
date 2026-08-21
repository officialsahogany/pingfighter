extends RefCounted

# 실제 충돌/속도는 건드리지 않는 표시 전용 squash-and-stretch 상태.
# 한 번의 패들 접촉을 짧은 압축 -> 출사 신장 -> 약한 탄성 복원으로 투영한다.
const SPEED_START := 12.0
const SPEED_FULL := 35.0
const COMPRESSION_HOLD_END_MSEC := 18.0
const STRETCH_PEAK_MSEC := 42.0
const REBOUND_MSEC := 78.0
const LIFETIME_MSEC := 112.0
const MAX_COMPRESSION := 0.24
const MAX_STRETCH := 0.16
const MAX_REBOUND_COMPRESSION := 0.035

var _last_event_id := -1
var _started_msec := -1.0
var _axis := Vector2.UP
var _strength := 0.0


func clear() -> void:
	_last_event_id = -1
	_started_msec = -1.0
	_axis = Vector2.UP
	_strength = 0.0


func sync_event(event: Dictionary, now_msec: float) -> void:
	var event_id: int = int(event.get("id", -1))
	if event_id < 0 or event_id == _last_event_id:
		return
	_last_event_id = event_id
	var kind: String = str(event.get("kind", ""))
	if kind != "player_paddle" and kind != "boss_paddle":
		_deactivate()
		return
	var velocity: Vector2 = _as_vector2(event.get("velocity", Vector2.ZERO))
	var speed: float = velocity.length()
	var speed_ratio: float = clampf(
		inverse_lerp(SPEED_START, SPEED_FULL, speed),
		0.0,
		1.0
	)
	# 저속 경계에서 갑자기 켜져 보이지 않도록 smoothstep으로 진입한다.
	_strength = speed_ratio * speed_ratio * (3.0 - 2.0 * speed_ratio)
	if _strength <= 0.001:
		_deactivate()
		return
	_axis = velocity.normalized() if velocity.length_squared() > 0.001 else (
		Vector2.UP if kind == "player_paddle" else Vector2.DOWN
	)
	_started_msec = now_msec


func get_snapshot(now_msec: float) -> Dictionary:
	if _started_msec < 0.0 or _strength <= 0.001:
		return {}
	var elapsed_msec: float = maxf(0.0, now_msec - _started_msec)
	if elapsed_msec > LIFETIME_MSEC:
		_deactivate()
		return {}
	var deformation: float = _get_axis_deformation(elapsed_msec, _strength)
	var axis_scale: float = clampf(1.0 + deformation, 0.72, 1.18)
	# 구형 공의 체적을 근사 보존해 고무풍선처럼 커졌다 작아지는 인상을 막는다.
	var perpendicular_scale: float = 1.0 / sqrt(axis_scale)
	return {
		"active": true,
		"axis": _axis,
		"axis_scale": axis_scale,
		"perpendicular_scale": perpendicular_scale,
		"strength": _strength,
		"elapsed_msec": elapsed_msec,
		"phase": _get_phase(elapsed_msec),
	}


func get_last_event_id_for_tests() -> int:
	return _last_event_id


static func map_point(point: Vector2, pivot: Vector2, snapshot: Dictionary) -> Vector2:
	if not bool(snapshot.get("active", false)):
		return point
	var axis: Vector2 = _as_vector2(snapshot.get("axis", Vector2.UP))
	if axis.length_squared() <= 0.001:
		return point
	axis = axis.normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var offset: Vector2 = point - pivot
	return (
		pivot
		+ axis * offset.dot(axis) * float(snapshot.get("axis_scale", 1.0))
		+ perpendicular
			* offset.dot(perpendicular)
			* float(snapshot.get("perpendicular_scale", 1.0))
	)


static func _get_axis_deformation(elapsed_msec: float, strength: float) -> float:
	var compression: float = MAX_COMPRESSION * strength
	var stretch: float = MAX_STRETCH * strength
	var rebound: float = MAX_REBOUND_COMPRESSION * strength
	if elapsed_msec <= COMPRESSION_HOLD_END_MSEC:
		var hold_t: float = _smooth01(elapsed_msec / COMPRESSION_HOLD_END_MSEC)
		return lerpf(-compression, -compression * 0.72, hold_t)
	if elapsed_msec <= STRETCH_PEAK_MSEC:
		var launch_t: float = _smooth01(
			(elapsed_msec - COMPRESSION_HOLD_END_MSEC)
			/ (STRETCH_PEAK_MSEC - COMPRESSION_HOLD_END_MSEC)
		)
		return lerpf(-compression * 0.72, stretch, launch_t)
	if elapsed_msec <= REBOUND_MSEC:
		var rebound_t: float = _smooth01(
			(elapsed_msec - STRETCH_PEAK_MSEC)
			/ (REBOUND_MSEC - STRETCH_PEAK_MSEC)
		)
		return lerpf(stretch, -rebound, rebound_t)
	var settle_t: float = _smooth01(
		(elapsed_msec - REBOUND_MSEC) / (LIFETIME_MSEC - REBOUND_MSEC)
	)
	return lerpf(-rebound, 0.0, settle_t)


static func _get_phase(elapsed_msec: float) -> String:
	if elapsed_msec <= COMPRESSION_HOLD_END_MSEC:
		return "compression"
	if elapsed_msec <= REBOUND_MSEC:
		return "launch_stretch"
	return "settle"


static func _smooth01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _as_vector2(value: Variant) -> Vector2:
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _deactivate() -> void:
	_started_msec = -1.0
	_strength = 0.0
