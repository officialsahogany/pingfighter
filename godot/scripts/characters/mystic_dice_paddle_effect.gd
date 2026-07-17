extends RefCounted

const DURATION_SECONDS := 3.0

var _remaining_seconds := 0.0
var _elapsed_seconds := 0.0
var _revision := 0
var _bound_host: Node = null


func start() -> Dictionary:
	_remaining_seconds = DURATION_SECONDS
	_elapsed_seconds = 0.0
	_revision += 1
	return get_snapshot()


func update(delta_seconds: float) -> bool:
	if not is_active():
		return false
	var before := _remaining_seconds
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta_seconds))
	_elapsed_seconds = minf(DURATION_SECONDS, DURATION_SECONDS - _remaining_seconds)
	if _remaining_seconds <= 0.0:
		_hide_bound_host()
	return not is_equal_approx(before, _remaining_seconds)


func reset() -> void:
	_remaining_seconds = 0.0
	_elapsed_seconds = 0.0
	_revision += 1
	_hide_bound_host()


func is_active() -> bool:
	return _remaining_seconds > 0.0


func bind_host(host: Node) -> void:
	if host == _bound_host:
		if not is_active():
			_hide_bound_host()
		return
	_hide_bound_host()
	_bound_host = host if _is_valid_host(host) else null
	if not is_active():
		_hide_bound_host()


func get_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"remaining_seconds": _remaining_seconds,
		"duration_seconds": DURATION_SECONDS,
		"elapsed_seconds": _elapsed_seconds,
		"intensity": clampf(_remaining_seconds / DURATION_SECONDS, 0.0, 1.0),
		"revision": _revision,
	}


func get_bound_host() -> Node:
	return _bound_host if _is_valid_host(_bound_host) else null


func _hide_bound_host() -> void:
	if not _is_valid_host(_bound_host):
		_bound_host = null
		return
	if _bound_host.has_method("set_active"):
		_bound_host.call("set_active", false)
	elif _bound_host.has_method("tear_down"):
		_bound_host.call("tear_down", false)
	else:
		_bound_host.visible = false


# freed 인스턴스는 typed Node 인자도, `is` 타입 검사도 통과하지 못하고
# 에러를 뿜는다(씬 해제 후 재바인딩 전 구간 매 프레임 스팸) — Variant로
# 받아 is_instance_valid를 반드시 먼저 통과시킨 뒤에만 타입을 본다.
func _is_valid_host(host: Variant) -> bool:
	if not is_instance_valid(host):
		return false
	return host is Node and not (host as Node).is_queued_for_deletion()
