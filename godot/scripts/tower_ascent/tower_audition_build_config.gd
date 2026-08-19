extends RefCounted

# TEMP: 경기게임오디션 2026 제출 구성의 단일 롤백 지점이다. 이 값을 false로
# 바꾸면 export feature가 남아 있어도 표준 9층/일반 보스 풀/환경변수 opt-in
# 동작으로 돌아간다.
const TEMP_AUDITION_BUILD_ENABLED := true
const TEMP_AUDITION_EXPORT_FEATURE := "tower_audition"
const TEMP_AUDITION_CLEAR_FLOOR := 7
const TEMP_AUDITION_LINEAR_FLOORS: Array[int] = [4, 5, 6, 7]
const STANDARD_CLEAR_FLOOR := 9

static var _enabled_override: int = -1


static func is_enabled() -> bool:
	return is_enabled_for_export_feature(OS.has_feature(TEMP_AUDITION_EXPORT_FEATURE))


static func is_enabled_for_export_feature(has_export_feature: bool) -> bool:
	if _enabled_override >= 0:
		return _enabled_override == 1
	return TEMP_AUDITION_BUILD_ENABLED and has_export_feature


static func get_clear_floor() -> int:
	return TEMP_AUDITION_CLEAR_FLOOR if is_enabled() else STANDARD_CLEAR_FLOOR


static func is_linear_floor(floor_number: int) -> bool:
	return is_enabled() and TEMP_AUDITION_LINEAR_FLOORS.has(floor_number)


static func is_terminal_floor(floor_number: int) -> bool:
	return is_enabled() and floor_number == TEMP_AUDITION_CLEAR_FLOOR


static func debug_set_enabled(enabled: bool) -> void:
	_enabled_override = 1 if enabled else 0


static func debug_clear_enabled_override() -> void:
	_enabled_override = -1
