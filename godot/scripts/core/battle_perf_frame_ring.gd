extends RefCounted

# 프레임 단위 링 버퍼 계측 (S5 지속 프레임드랍 조사용).
#
# 왜 필요한가: `[BattlePerf-*]` 집계창은 **가변 길이**다. 모달이 열려 전투 본체
# `_draw()` 가 멈추면 flush 도 멈춰 한 창이 16초를 넘기기도 한다(2026-08-13 세션
# 창 817 = phys_n 1195 ≈ 16.6초). 그래서 창 단위 집계로는 "TAB close → 실점 →
# 첫 저fps 프레임" 의 선후를 알 수 없다. 이 링은 **프로세스 프레임과 물리 틱을
# 각각 단조시각·ID 와 함께** 기록해 그 선후를 직접 읽게 한다.
#
# 설계 계약:
# - 비활성일 때 비용은 **캐시된 bool 분기 하나**뿐이다. 시계 호출·할당·문자열
#   조립을 하지 않는다(호출부도 타임스탬프를 미리 만들어 넘기지 않는다).
# - 저장은 **미리 할당한 고정 크기 Packed 배열**이다. 프레임마다 Dictionary 를
#   만들지 않는다.
# - `process frame ID` / `physics tick ID` / 단조시각을 분리 기록해 한 프레임에
#   물린 여러 물리 틱을 정확히 연결한다.
# - `_process` 밖 시간은 원인을 단정하지 않으므로 `unattributed_residual` 로
#   중립 기록한다(엔진 작업·렌더 제출·OS 스케줄링이 모두 들어갈 수 있다).
# - 저fps 를 만나도 **파일을 즉시 쓰지 않는다**. 후속 N 프레임까지 메모리에 받은
#   뒤 링을 얼려두고, 전투 밖 안전한 시점에 호출자가 1회 덤프한다.

const DEFAULT_FRAME_CAPACITY := 2048
const DEFAULT_TICK_CAPACITY := 4096
const DEFAULT_EVENT_CAPACITY := 512
# 25ms = 40fps 아래. 72fps 예산 13.89ms 의 약 1.8배.
const DEFAULT_TRIGGER_DELTA_USEC := 25000
const DEFAULT_POST_TRIGGER_FRAMES := 360

# 이벤트 코드는 정수로만 다룬다. 이름 해석은 덤프 시점에만 한다.
const EVENT_NONE := 0
const EVENT_MODAL_OPEN := 1
const EVENT_MODAL_CLOSE := 2
const EVENT_SCORE := 3
const EVENT_ADVERSITY_ARMOR := 4
const EVENT_PERK_FUSION_COMMIT := 5
const EVENT_ROUND_RESTART := 6
const EVENT_STAGE_ENTER := 7
const EVENT_TRIGGER_ARMED := 8

# ⚠️ `PackedStringArray([...])` 는 상수식이 아니라 파스 에러가 난다. 배열 리터럴로 둘 것.
const EVENT_NAMES := [
	"none",
	"modal_open",
	"modal_close",
	"score",
	"adversity_armor",
	"perk_fusion_commit",
	"round_restart",
	"stage_enter",
	"trigger_armed",
]

# `_store_sample` 이 흘려보내는 라벨 중 링이 보는 것. 문자열 비교를 반복하지
# 않도록 단일 해시 조회로 분기한다.
const WATCHED_SAMPLES := {
	"process.shell.delta": 1,
	"physics.shell.total": 2,
	"draw.shell.total": 3,
}

var _active := false
var _frozen := false
var _pending_dump := false

var _frame_capacity := DEFAULT_FRAME_CAPACITY
var _tick_capacity := DEFAULT_TICK_CAPACITY
var _event_capacity := DEFAULT_EVENT_CAPACITY
var _trigger_delta_usec := DEFAULT_TRIGGER_DELTA_USEC
var _post_trigger_frames := DEFAULT_POST_TRIGGER_FRAMES

# --- process frame columns ---
var _f_id := PackedInt64Array()
var _f_mono_usec := PackedInt64Array()
var _f_delta_usec := PackedInt32Array()
var _f_process_usec := PackedInt32Array()
var _f_draw_usec := PackedInt32Array()
var _f_phys_usec := PackedInt32Array()
var _f_phys_tick_count := PackedInt32Array()
var _f_first_tick_id := PackedInt64Array()
var _f_residual_usec := PackedInt32Array()
var _f_write := 0
var _f_count := 0

# --- physics tick columns ---
var _t_id := PackedInt64Array()
var _t_mono_usec := PackedInt64Array()
var _t_usec := PackedInt32Array()
var _t_frame_id := PackedInt64Array()
var _t_write := 0
var _t_count := 0

# --- event columns ---
var _e_mono_usec := PackedInt64Array()
var _e_code := PackedInt32Array()
var _e_param := PackedInt32Array()
var _e_frame_id := PackedInt64Array()
var _e_tick_id := PackedInt64Array()
var _e_write := 0
var _e_count := 0

# --- open frame accumulators ---
var _next_frame_id := 0
var _next_tick_id := 0
var _open_frame_valid := false
var _open_delta_usec := 0
var _open_draw_usec := 0
var _open_phys_usec := 0
var _open_phys_tick_count := 0
var _open_first_tick_id := -1
var _armed_remaining := -1


func _init() -> void:
	_allocate()


func _allocate() -> void:
	_f_id.resize(_frame_capacity)
	_f_mono_usec.resize(_frame_capacity)
	_f_delta_usec.resize(_frame_capacity)
	_f_process_usec.resize(_frame_capacity)
	_f_draw_usec.resize(_frame_capacity)
	_f_phys_usec.resize(_frame_capacity)
	_f_phys_tick_count.resize(_frame_capacity)
	_f_first_tick_id.resize(_frame_capacity)
	_f_residual_usec.resize(_frame_capacity)
	_t_id.resize(_tick_capacity)
	_t_mono_usec.resize(_tick_capacity)
	_t_usec.resize(_tick_capacity)
	_t_frame_id.resize(_tick_capacity)
	_e_mono_usec.resize(_event_capacity)
	_e_code.resize(_event_capacity)
	_e_param.resize(_event_capacity)
	_e_frame_id.resize(_event_capacity)
	_e_tick_id.resize(_event_capacity)


func configure(frame_capacity: int, tick_capacity: int, event_capacity: int, trigger_delta_usec: int, post_trigger_frames: int) -> void:
	_frame_capacity = maxi(8, frame_capacity)
	_tick_capacity = maxi(8, tick_capacity)
	_event_capacity = maxi(8, event_capacity)
	_trigger_delta_usec = maxi(1, trigger_delta_usec)
	_post_trigger_frames = maxi(0, post_trigger_frames)
	_allocate()
	reset()


func set_active(active: bool) -> void:
	_active = active


func is_active() -> bool:
	return _active


func is_frozen() -> bool:
	return _frozen


func has_pending_dump() -> bool:
	return _pending_dump


func get_frame_count() -> int:
	return _f_count


func get_tick_count() -> int:
	return _t_count


func get_event_count() -> int:
	return _e_count


func reset() -> void:
	_frozen = false
	_pending_dump = false
	_f_write = 0
	_f_count = 0
	_t_write = 0
	_t_count = 0
	_e_write = 0
	_e_count = 0
	_next_frame_id = 0
	_next_tick_id = 0
	_armed_remaining = -1
	_clear_open_frame()


func _clear_open_frame() -> void:
	_open_frame_valid = false
	_open_delta_usec = 0
	_open_draw_usec = 0
	_open_phys_usec = 0
	_open_phys_tick_count = 0
	_open_first_tick_id = -1


# `battle_perf_logger._store_sample` 의 단일 퍼널에서 불린다. 비활성/동결이면
# bool 분기 두 개로 끝난다.
func observe_sample(label: String, elapsed_usec: int) -> void:
	if not _active or _frozen:
		return
	var kind: int = int(WATCHED_SAMPLES.get(label, 0))
	if kind == 0:
		return
	if kind == 1:
		_begin_frame(elapsed_usec)
	elif kind == 2:
		_note_physics_tick(elapsed_usec)
	else:
		_open_draw_usec += elapsed_usec


func _note_physics_tick(elapsed_usec: int) -> void:
	var tick_id := _next_tick_id
	_next_tick_id += 1
	_t_id[_t_write] = tick_id
	_t_mono_usec[_t_write] = Time.get_ticks_usec()
	_t_usec[_t_write] = elapsed_usec
	# 아직 닫히지 않은 프레임에 귀속된다. 프레임 ID 는 현재 열린 프레임 번호.
	_t_frame_id[_t_write] = _next_frame_id
	_t_write = (_t_write + 1) % _tick_capacity
	if _t_count < _tick_capacity:
		_t_count += 1
	if _open_first_tick_id < 0:
		_open_first_tick_id = tick_id
	_open_phys_usec += elapsed_usec
	_open_phys_tick_count += 1


# `process.shell.delta` 는 프로세스 프레임당 정확히 한 번 기록된다. 그 시점을
# 프레임 경계로 삼아 직전 프레임을 확정하고 새 프레임을 연다.
func _begin_frame(delta_usec: int) -> void:
	if _open_frame_valid:
		_close_open_frame()
	_clear_open_frame()
	_open_frame_valid = true
	_open_delta_usec = delta_usec


func _close_open_frame() -> void:
	var frame_id := _next_frame_id
	_next_frame_id += 1
	var process_usec := int(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
	_f_id[_f_write] = frame_id
	_f_mono_usec[_f_write] = Time.get_ticks_usec()
	_f_delta_usec[_f_write] = _open_delta_usec
	_f_process_usec[_f_write] = process_usec
	_f_draw_usec[_f_write] = _open_draw_usec
	_f_phys_usec[_f_write] = _open_phys_usec
	_f_phys_tick_count[_f_write] = _open_phys_tick_count
	_f_first_tick_id[_f_write] = _open_first_tick_id
	# 원인을 단정하지 않는 중립 이름. 엔진 작업·렌더 제출·OS 스케줄링 포함.
	_f_residual_usec[_f_write] = _open_delta_usec - process_usec
	_f_write = (_f_write + 1) % _frame_capacity
	if _f_count < _frame_capacity:
		_f_count += 1
	_advance_trigger(frame_id)


func _advance_trigger(frame_id: int) -> void:
	if _armed_remaining < 0:
		if _open_delta_usec < _trigger_delta_usec:
			return
		_armed_remaining = _post_trigger_frames
		_record_event(EVENT_TRIGGER_ARMED, _open_delta_usec, frame_id)
		if _armed_remaining <= 0:
			_freeze()
		return
	# 트리거 프레임 이후 정확히 `_post_trigger_frames` 개를 더 받는다.
	_armed_remaining -= 1
	if _armed_remaining <= 0:
		_freeze()


# 링을 얼려 트리거 창이 덮이지 않게 한다. 파일 쓰기는 호출자가 전투 밖에서 한다.
func _freeze() -> void:
	_frozen = true
	_pending_dump = true


func mark_event(code: int, param: int = 0) -> void:
	if not _active or _frozen:
		return
	_record_event(code, param, _next_frame_id)


func _record_event(code: int, param: int, frame_id: int) -> void:
	_e_mono_usec[_e_write] = Time.get_ticks_usec()
	_e_code[_e_write] = code
	_e_param[_e_write] = param
	_e_frame_id[_e_write] = frame_id
	_e_tick_id[_e_write] = _next_tick_id
	_e_write = (_e_write + 1) % _event_capacity
	if _e_count < _event_capacity:
		_e_count += 1


func _oldest_index(write_index: int, count: int, capacity: int) -> int:
	if count < capacity:
		return 0
	return write_index


# 링 순서를 시간순으로 펴서 TSV 로 1회 덤프한다. 전투 밖에서만 부를 것.
func build_dump_text() -> String:
	var lines := PackedStringArray()
	lines.append("# battle_perf_frame_ring v1")
	lines.append("# frames=%d ticks=%d events=%d frozen=%s" % [_f_count, _t_count, _e_count, str(_frozen)])
	lines.append("# trigger_delta_usec=%d post_trigger_frames=%d" % [_trigger_delta_usec, _post_trigger_frames])
	lines.append("# residual = delta_usec - process_usec (unattributed: engine work, render submit, OS scheduling)")
	lines.append("")
	lines.append("[frames]")
	lines.append("frame_id\tmono_usec\tdelta_usec\tprocess_usec\tdraw_usec\tphys_usec\tphys_ticks\tfirst_tick_id\tunattributed_residual_usec")
	var start := _oldest_index(_f_write, _f_count, _frame_capacity)
	for offset in range(_f_count):
		var i := (start + offset) % _frame_capacity
		lines.append("%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d" % [
			_f_id[i], _f_mono_usec[i], _f_delta_usec[i], _f_process_usec[i], _f_draw_usec[i],
			_f_phys_usec[i], _f_phys_tick_count[i], _f_first_tick_id[i], _f_residual_usec[i],
		])
	lines.append("")
	lines.append("[ticks]")
	lines.append("tick_id\tmono_usec\ttick_usec\tframe_id")
	start = _oldest_index(_t_write, _t_count, _tick_capacity)
	for offset in range(_t_count):
		var i := (start + offset) % _tick_capacity
		lines.append("%d\t%d\t%d\t%d" % [_t_id[i], _t_mono_usec[i], _t_usec[i], _t_frame_id[i]])
	lines.append("")
	lines.append("[events]")
	lines.append("mono_usec\tcode\tname\tparam\tframe_id\ttick_id")
	start = _oldest_index(_e_write, _e_count, _event_capacity)
	for offset in range(_e_count):
		var i := (start + offset) % _event_capacity
		var code: int = _e_code[i]
		var name_text := "unknown"
		if code >= 0 and code < EVENT_NAMES.size():
			name_text = EVENT_NAMES[code]
		lines.append("%d\t%d\t%s\t%d\t%d\t%d" % [_e_mono_usec[i], code, name_text, _e_param[i], _e_frame_id[i], _e_tick_id[i]])
	return "\n".join(lines)


func dump_to_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(build_dump_text())
	file.close()
	_pending_dump = false
	return path
