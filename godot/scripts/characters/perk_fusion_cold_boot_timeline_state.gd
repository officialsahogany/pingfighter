extends RefCounted

const PerkFusionColdBootPresentation := preload("res://scripts/characters/perk_fusion_cold_boot_presentation.gd")

# 퍽 융합 "링코어 콜드부트" 시네마틱 6비트 타임라인(B0~B5) — 스토리보드
# 권위는 docs/perk_fusion_cold_boot_cinematic_plan.md §3. 모달 flow의
# PHASE_ANIMATION 구간을 B0~B4로 세분하고, flow가 reveal로 넘어가면(자연
# 완주든 스킵이든) B5 SETTLE로 수렴한다. outcome은 committed_record에 이미
# 롤려 있으므로 이 타임라인은 라이브 RNG 없이 결정론적으로 재생만 한다.
const BEAT_DOCK_IN := "dock_in"
const BEAT_TWIST_LOCK := "twist_lock"
const BEAT_BOOT_POST := "boot_post"
const BEAT_IGNITION_CREST := "ignition_crest"
const BEAT_REVEAL := "reveal"
const BEAT_SETTLE := "settle"

const DOCK_IN_DURATION := 0.5
const TWIST_LOCK_DURATION := 0.4
const BOOT_POST_DURATION := 0.9
const IGNITION_CREST_DURATION := 0.25
const REVEAL_DURATION := 0.7
# 총 연출 길이 = B0~B4 합(B5는 확인 입력까지 홀드라 무한). 모달 flow와
# 오버레이 렌더러의 DEFAULT_ANIMATION_DURATION은 반드시 이 값을 파생으로
# 읽는다 — 이중 duration 상수 트랩(플랜 §7 체크리스트 1번) 봉인.
const TOTAL_ANIMATION_DURATION := (
	DOCK_IN_DURATION
	+ TWIST_LOCK_DURATION
	+ BOOT_POST_DURATION
	+ IGNITION_CREST_DURATION
	+ REVEAL_DURATION
)

const BEAT_SEQUENCE: Array[String] = [
	BEAT_DOCK_IN,
	BEAT_TWIST_LOCK,
	BEAT_BOOT_POST,
	BEAT_IGNITION_CREST,
	BEAT_REVEAL,
]

const EVENT_ENTER_TWIST_LOCK := "enter_twist_lock"
const EVENT_ENTER_BOOT_POST := "enter_boot_post"
const EVENT_ENTER_IGNITION_CREST := "enter_ignition_crest"
const EVENT_ENTER_REVEAL := "enter_reveal"
const EVENT_ENTER_SETTLE := "enter_settle"

var active := false
var beat := BEAT_DOCK_IN
var beat_timer := 0.0
var elapsed := 0.0
var committed_record: Dictionary = {}
# CB2: committed_record에서 begin 시 1회 파생되는 결정론적 티어 플랜
# (tell/카운트) — 스냅샷 소비자(렌더러/CB3 호스트)가 그대로 읽는다.
var presentation: Dictionary = {}


func begin(record: Dictionary) -> void:
	active = true
	beat = BEAT_DOCK_IN
	beat_timer = 0.0
	elapsed = 0.0
	committed_record = record.duplicate(true)
	presentation = PerkFusionColdBootPresentation.build_plan(committed_record)


# 한 delta가 여러 비트 경계를 관통해도 순서대로 전이 이벤트를 전부 낸다
# (저프레임 안전). SETTLE 도달 이후에는 시계만 홀드로 멈춘다.
func advance(delta_seconds: float) -> Array[String]:
	var events: Array[String] = []
	if not active or beat == BEAT_SETTLE:
		return events
	var dt: float = maxf(0.0, delta_seconds)
	elapsed += dt
	beat_timer += dt
	while beat != BEAT_SETTLE:
		var duration: float = get_beat_duration(beat)
		if beat_timer < duration:
			break
		beat_timer -= duration
		var next_beat: String = _next_beat(beat)
		beat = next_beat
		events.append(_enter_event_for(next_beat))
		if next_beat == BEAT_SETTLE:
			beat_timer = 0.0
	return events


# 스킵/자연 완주 수렴점: 어느 비트에서든 확정 코어 리빌(SETTLE)로 점프한다.
# flow가 reveal로 넘어가는 모든 경로(자연 만료·스킵 confirm)가 이걸 부른다.
func skip_to_settle() -> Array[String]:
	if not active or beat == BEAT_SETTLE:
		return []
	beat = BEAT_SETTLE
	beat_timer = 0.0
	return [EVENT_ENTER_SETTLE]


func reset() -> void:
	active = false
	beat = BEAT_DOCK_IN
	beat_timer = 0.0
	elapsed = 0.0
	committed_record.clear()
	presentation = {}


func is_settled() -> bool:
	return active and beat == BEAT_SETTLE


func get_beat_duration(target_beat: String) -> float:
	match target_beat:
		BEAT_DOCK_IN:
			return DOCK_IN_DURATION
		BEAT_TWIST_LOCK:
			return TWIST_LOCK_DURATION
		BEAT_BOOT_POST:
			return BOOT_POST_DURATION
		BEAT_IGNITION_CREST:
			return IGNITION_CREST_DURATION
		BEAT_REVEAL:
			return REVEAL_DURATION
	return 0.0


func get_snapshot() -> Dictionary:
	var duration: float = get_beat_duration(beat)
	var beat_progress := 1.0
	if duration > 0.0:
		beat_progress = clampf(beat_timer / duration, 0.0, 1.0)
	return {
		"active": active,
		"beat": beat,
		"beat_timer": beat_timer,
		"beat_progress": beat_progress,
		"elapsed": elapsed,
		"total_duration": TOTAL_ANIMATION_DURATION,
		"committed_record": committed_record.duplicate(true),
		"presentation": presentation.duplicate(true),
	}


func _next_beat(current_beat: String) -> String:
	var index: int = BEAT_SEQUENCE.find(current_beat)
	if index < 0 or index + 1 >= BEAT_SEQUENCE.size():
		return BEAT_SETTLE
	return BEAT_SEQUENCE[index + 1]


func _enter_event_for(target_beat: String) -> String:
	match target_beat:
		BEAT_TWIST_LOCK:
			return EVENT_ENTER_TWIST_LOCK
		BEAT_BOOT_POST:
			return EVENT_ENTER_BOOT_POST
		BEAT_IGNITION_CREST:
			return EVENT_ENTER_IGNITION_CREST
		BEAT_REVEAL:
			return EVENT_ENTER_REVEAL
	return EVENT_ENTER_SETTLE
