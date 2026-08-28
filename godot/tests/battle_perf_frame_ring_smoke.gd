extends SceneTree

# battle_perf_frame_ring 계약 봉인.
#
# 봉인 항목(리뷰 조건 그대로):
#   1. 비활성 비용 — 링이 꺼져 있으면 배열 할당조차 없다(frame_ring == null).
#   2. 링 wrap 순서 — 용량 초과 시 오래된 것부터 버리고 덤프는 시간순이다.
#   3. 다중 physics tick — 한 프로세스 프레임에 물린 여러 틱이 정확히 연결된다.
#   4. 이벤트 선후 — 발행 순서와 frame_id/tick_id 귀속이 보존된다.
#   5. 트리거 후 후속 N 프레임까지 받고 얼린다(전투 중 파일 쓰기 없음).
#   6. reset/teardown — 얼림/대기/카운트가 모두 풀린다.

const BattlePerfFrameRing := preload("res://scripts/core/battle_perf_frame_ring.gd")
const BattlePerfLogger := preload("res://scripts/core/battle_perf_logger.gd")

const DELTA := "process.shell.delta"
const PHYS := "physics.shell.total"
const DRAW := "draw.shell.total"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	_failed = true
	push_error("battle_perf_frame_ring_smoke: %s" % message)
	print("FAIL: %s" % message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


# 프로덕션 덤프 산출물을 그대로 파싱한다(내부 배열 훔쳐보기 금지).
func _section_rows(dump_text: String, section: String) -> Array:
	var rows: Array = []
	var in_section := false
	var header_seen := false
	for raw_line in dump_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line == "":
			continue
		if line.begins_with("["):
			in_section = line == "[%s]" % section
			header_seen = false
			continue
		if not in_section or line.begins_with("#"):
			continue
		if not header_seen:
			header_seen = true
			continue
		rows.append(line.split("\t"))
	return rows


func _new_ring(frame_capacity: int, tick_capacity: int, event_capacity: int, trigger_usec: int, post_frames: int) -> Object:
	var ring: Object = BattlePerfFrameRing.new()
	ring.configure(frame_capacity, tick_capacity, event_capacity, trigger_usec, post_frames)
	ring.set_active(true)
	return ring


func _run() -> void:
	_test_inactive_costs_nothing()
	_test_multi_physics_tick_linkage()
	_test_ring_wrap_order()
	_test_event_ordering()
	_test_trigger_freezes_after_post_frames()
	_test_reset_clears_state()

	if _failed:
		print("battle_perf_frame_ring_smoke: FAILED")
		quit(1)
		return
	print("battle_perf_frame_ring_smoke: ok")
	quit(0)


# 1. 비활성 비용 — 배열 할당도, 기록도 없다.
func _test_inactive_costs_nothing() -> void:
	var logger: Object = BattlePerfLogger.new()
	logger.debug_enable_frame_ring(false)
	for i in range(200):
		logger._store_sample(DELTA, 13889)
		logger._store_sample(PHYS, 2000)
		logger._store_sample(DRAW, 6000)
	_expect(logger.frame_ring == null, "inactive logger must never allocate the frame ring")
	_expect_eq(logger.is_frame_ring_enabled(), false, "inactive logger must report the ring disabled")
	_expect_eq(logger.has_pending_frame_ring_dump(), false, "inactive logger must not report a pending dump")
	_expect_eq(logger.dump_frame_ring("user://should_not_exist.tsv"), "", "inactive logger must not write a dump file")

	# 링 인스턴스 자체도 비활성이면 기록하지 않는다.
	var ring: Object = BattlePerfFrameRing.new()
	ring.set_active(false)
	for i in range(50):
		ring.observe_sample(DELTA, 13889)
		ring.observe_sample(PHYS, 2000)
	ring.mark_event(BattlePerfFrameRing.EVENT_SCORE, 1)
	_expect_eq(ring.get_frame_count(), 0, "inactive ring must record no frames")
	_expect_eq(ring.get_tick_count(), 0, "inactive ring must record no ticks")
	_expect_eq(ring.get_event_count(), 0, "inactive ring must record no events")


# 3. 다중 physics tick 이 한 프레임에 정확히 연결된다.
func _test_multi_physics_tick_linkage() -> void:
	var ring: Object = _new_ring(64, 128, 32, 1000000, 0)
	# 프레임 A: 물리 3틱 + draw
	ring.observe_sample(DELTA, 41000)
	ring.observe_sample(PHYS, 7000)
	ring.observe_sample(PHYS, 7100)
	ring.observe_sample(PHYS, 7200)
	ring.observe_sample(DRAW, 13000)
	# 프레임 B 시작이 프레임 A 를 확정한다.
	ring.observe_sample(DELTA, 13889)
	ring.observe_sample(PHYS, 2000)
	ring.observe_sample(DRAW, 6000)
	ring.observe_sample(DELTA, 13889)

	var rows := _section_rows(ring.build_dump_text(), "frames")
	_expect_eq(rows.size(), 2, "two closed frames expected")
	if rows.size() < 2:
		return
	var a: PackedStringArray = rows[0]
	_expect_eq(int(a[0]), 0, "first frame id")
	_expect_eq(int(a[2]), 41000, "frame A delta")
	_expect_eq(int(a[4]), 13000, "frame A draw")
	_expect_eq(int(a[5]), 21300, "frame A summed physics usec")
	_expect_eq(int(a[6]), 3, "frame A physics tick count")
	_expect_eq(int(a[7]), 0, "frame A first tick id")
	var b: PackedStringArray = rows[1]
	_expect_eq(int(b[0]), 1, "second frame id")
	_expect_eq(int(b[6]), 1, "frame B physics tick count")
	_expect_eq(int(b[7]), 3, "frame B first tick id must continue the tick sequence")

	var tick_rows := _section_rows(ring.build_dump_text(), "ticks")
	_expect_eq(tick_rows.size(), 4, "four physics ticks recorded")
	if tick_rows.size() == 4:
		# 처음 3틱은 프레임 0, 마지막 1틱은 프레임 1 에 귀속.
		_expect_eq(int((tick_rows[0] as PackedStringArray)[3]), 0, "tick 0 belongs to frame 0")
		_expect_eq(int((tick_rows[2] as PackedStringArray)[3]), 0, "tick 2 belongs to frame 0")
		_expect_eq(int((tick_rows[3] as PackedStringArray)[3]), 1, "tick 3 belongs to frame 1")


# 2. 링 wrap — 용량 초과 시 오래된 것부터 버리고 시간순으로 편다.
func _test_ring_wrap_order() -> void:
	var capacity := 8
	var ring: Object = _new_ring(capacity, 64, 16, 1000000, 0)
	# 20 프레임을 연다. 마지막 delta 는 프레임을 열기만 하므로 확정은 19개.
	for i in range(20):
		ring.observe_sample(DELTA, 10000 + i)
	var rows := _section_rows(ring.build_dump_text(), "frames")
	_expect_eq(rows.size(), capacity, "wrapped ring must hold exactly its capacity")
	if rows.size() != capacity:
		return
	var previous_id := -1
	for row in rows:
		var current_id := int((row as PackedStringArray)[0])
		_expect(current_id > previous_id, "dump must be chronological (id %d after %d)" % [current_id, previous_id])
		previous_id = current_id
	# 확정된 프레임은 0..18. 마지막 8개는 11..18 이어야 한다.
	_expect_eq(int((rows[0] as PackedStringArray)[0]), 11, "oldest surviving frame id after wrap")
	_expect_eq(int((rows[capacity - 1] as PackedStringArray)[0]), 18, "newest surviving frame id after wrap")
	_expect_eq(int((rows[0] as PackedStringArray)[2]), 10011, "oldest surviving frame keeps its own delta")


# 4. 이벤트 선후와 귀속.
func _test_event_ordering() -> void:
	var ring: Object = _new_ring(64, 128, 32, 1000000, 0)
	ring.observe_sample(DELTA, 13889)
	ring.mark_event(BattlePerfFrameRing.EVENT_MODAL_OPEN, 7)
	ring.observe_sample(PHYS, 2000)
	ring.mark_event(BattlePerfFrameRing.EVENT_SCORE, 1)
	ring.observe_sample(DELTA, 13889)
	ring.mark_event(BattlePerfFrameRing.EVENT_MODAL_CLOSE, 7)
	ring.observe_sample(DELTA, 13889)

	var rows := _section_rows(ring.build_dump_text(), "events")
	_expect_eq(rows.size(), 3, "three events recorded")
	if rows.size() != 3:
		return
	var first: PackedStringArray = rows[0]
	var second: PackedStringArray = rows[1]
	var third: PackedStringArray = rows[2]
	_expect_eq(first[2], "modal_open", "first event name")
	_expect_eq(second[2], "score", "second event name")
	_expect_eq(third[2], "modal_close", "third event name")
	_expect_eq(int(first[3]), 7, "event param preserved")
	# 발행 순서대로 단조시각이 증가한다.
	_expect(int(first[0]) <= int(second[0]), "event mono clock must not go backwards")
	_expect(int(second[0]) <= int(third[0]), "event mono clock must not go backwards")
	# modal_open/score 는 아직 열려 있던 프레임 0, modal_close 는 프레임 1.
	_expect_eq(int(first[4]), 0, "modal_open belongs to the open frame 0")
	_expect_eq(int(second[4]), 0, "score belongs to the open frame 0")
	_expect_eq(int(third[4]), 1, "modal_close belongs to frame 1")
	# score 는 물리 틱 1개가 지난 뒤라 tick_id 커서가 1이다.
	_expect_eq(int(second[5]), 1, "score event must carry the physics tick cursor")


# 5. 트리거 후 후속 프레임까지 받고 얼린다. 전투 중 파일 쓰기 없음.
func _test_trigger_freezes_after_post_frames() -> void:
	var post_frames := 3
	var ring: Object = _new_ring(64, 128, 32, 25000, post_frames)
	for i in range(4):
		ring.observe_sample(DELTA, 13889)
	_expect_eq(ring.is_frozen(), false, "normal frames must not freeze the ring")
	_expect_eq(ring.has_pending_dump(), false, "normal frames must not request a dump")

	# 느린 프레임 하나가 트리거를 무장시킨다(확정은 다음 delta 에서).
	ring.observe_sample(DELTA, 43000)
	ring.observe_sample(DELTA, 13889)
	_expect_eq(ring.is_frozen(), false, "must keep capturing during the post-trigger window")
	for i in range(post_frames):
		ring.observe_sample(DELTA, 13889)
	_expect_eq(ring.is_frozen(), true, "ring must freeze after the post-trigger window")
	_expect_eq(ring.has_pending_dump(), true, "ring must request a dump after freezing")

	var frozen_frames: int = ring.get_frame_count()
	for i in range(20):
		ring.observe_sample(DELTA, 13889)
		ring.observe_sample(PHYS, 2000)
	ring.mark_event(BattlePerfFrameRing.EVENT_SCORE, 1)
	_expect_eq(ring.get_frame_count(), frozen_frames, "frozen ring must not overwrite the captured window")

	var rows := _section_rows(ring.build_dump_text(), "frames")
	var trigger_seen := false
	for row in rows:
		if int((row as PackedStringArray)[2]) == 43000:
			trigger_seen = true
	_expect(trigger_seen, "the triggering slow frame must survive inside the frozen window")

	var events := _section_rows(ring.build_dump_text(), "events")
	var armed_seen := false
	for row in events:
		if (row as PackedStringArray)[2] == "trigger_armed":
			armed_seen = true
	_expect(armed_seen, "arming the trigger must leave a marker event")


# 6. reset 이 얼림/대기/카운트를 모두 푼다.
func _test_reset_clears_state() -> void:
	var ring: Object = _new_ring(32, 64, 16, 25000, 0)
	ring.observe_sample(DELTA, 43000)
	ring.observe_sample(DELTA, 13889)
	ring.observe_sample(DELTA, 13889)
	_expect_eq(ring.is_frozen(), true, "precondition: ring froze")
	ring.reset()
	_expect_eq(ring.is_frozen(), false, "reset must unfreeze")
	_expect_eq(ring.has_pending_dump(), false, "reset must clear the pending dump")
	_expect_eq(ring.get_frame_count(), 0, "reset must clear frames")
	_expect_eq(ring.get_tick_count(), 0, "reset must clear ticks")
	_expect_eq(ring.get_event_count(), 0, "reset must clear events")
	# reset 뒤에도 정상 기록이 재개된다.
	ring.observe_sample(DELTA, 13889)
	ring.observe_sample(DELTA, 13889)
	_expect_eq(ring.get_frame_count(), 1, "ring must record again after reset")
