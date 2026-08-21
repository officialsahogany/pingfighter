extends RefCounted

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2BossRageState := preload("res://scripts/stages/stage2/stage2_boss_rage_state.gd")
const StageBossVariantCatalog := preload(
	"res://scripts/stages/common/stage_boss_variant_catalog.gd"
)

# 2026-07-31 7점제 재보정: 4/5(80%) -> 6/7(86%). 듀스 발동선(DEUCE_TRIGGER)과
# 같은 점수라는 관계도 5점제와 동일하게 유지된다.
const CRISIS_PLAYER_SCORE := 6
const STOMP_INTERVAL_SEC := 15.0 / 60.0
const BUILDUP_SEC := 60.0 / 60.0
const FINAL_STOMP_SEC := 80.0 / 60.0
const TOTAL_SEC := 100.0 / 60.0
const MAX_STOMP_COUNT := 4
const CRISIS_ROCK_COUNT_CHAMPION := 3
const CRISIS_ROCK_COUNT_MYTHIC := 5
const QUAKE_MIN_DURATION_SEC := 0.2
const START_WARNING_SEC := 1.25
const FINAL_WARNING_SEC := 1.25
const START_SHAKE_DURATION_SEC := 0.055
const START_SHAKE_STRENGTH := 2.2
const STOMP_SHAKE_DURATION_SEC := 0.060
const STOMP_SHAKE_BASE_STRENGTH := 2.5
const STOMP_SHAKE_STEP_STRENGTH := 0.18
const FINAL_SHAKE_DURATION_SEC := 0.082
const FINAL_SHAKE_STRENGTH := 4.0

var rage_state: Object = null
var quake_state: Object = null
var rock_lifecycle_coordinator: Object = null
var skill_warning_state: Object = null
var final_quake_duration_sec := 0.0
var quake_repeat_cooldown_sec := 0.0
var quake_boss_launch_guard_sec := 0.0

# Rage begins during serve-wait, where later effect deps may carry audio=null.
# Retain the activation-time handle so stomp and quake cues cannot disappear.
var cached_audio: Object = null


func configure(
	rage_state_ref: Object,
	quake_state_ref: Object,
	rock_lifecycle_coordinator_ref: Object,
	skill_warning_state_ref: Object,
	final_quake_duration_sec_ref: float,
	quake_repeat_cooldown_sec_ref: float,
	quake_boss_launch_guard_sec_ref: float
) -> void:
	rage_state = rage_state_ref
	quake_state = quake_state_ref
	rock_lifecycle_coordinator = rock_lifecycle_coordinator_ref
	skill_warning_state = skill_warning_state_ref
	final_quake_duration_sec = final_quake_duration_sec_ref
	quake_repeat_cooldown_sec = quake_repeat_cooldown_sec_ref
	quake_boss_launch_guard_sec = quake_boss_launch_guard_sec_ref


func reset() -> void:
	if rage_state != null:
		rage_state.reset()
	cached_audio = null


func reserve_crisis(context: Dictionary) -> bool:
	if rage_state == null:
		return false
	var stage2_variant := StageBossVariantCatalog.normalize_variant(
		2,
		context.get("stage_boss_variant", "")
	)
	if stage2_variant != StageBossVariantCatalog.get_default_variant(2):
		return false
	return rage_state.reserve_crisis(context, CRISIS_PLAYER_SCORE)


func start(deps: Dictionary = {}) -> bool:
	if rage_state == null or not rage_state.start():
		return false
	cached_audio = deps.get("audio", null)
	_trigger_warning("rage", "청린귀 폭주!", START_WARNING_SEC)
	_request_shake(deps, START_SHAKE_DURATION_SEC, START_SHAKE_STRENGTH)
	return true


func remember_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null:
		cached_audio = audio


func update(delta: float, deps: Dictionary) -> Dictionary:
	if rage_state == null:
		return {
			"stomp_steps": [],
			"final_stomp": false,
			"finished": false,
		}
	var events: Dictionary = rage_state.update(
		delta,
		STOMP_INTERVAL_SEC,
		BUILDUP_SEC,
		FINAL_STOMP_SEC,
		TOTAL_SEC,
		MAX_STOMP_COUNT
	)
	for step_value in events.get("stomp_steps", []):
		var step := int(step_value)
		Stage2AudioRouter.play_boss_cry(deps, cached_audio)
		_request_shake(
			deps,
			STOMP_SHAKE_DURATION_SEC,
			STOMP_SHAKE_BASE_STRENGTH + float(step) * STOMP_SHAKE_STEP_STRENGTH
		)
	if bool(events.get("final_stomp", false)):
		_emit_final_stomp(deps)
	return events


func get_crisis_rock_count() -> int:
	if rage_state == null:
		return CRISIS_ROCK_COUNT_CHAMPION
	return Stage2BossRageState.get_crisis_rock_count(
		str(rage_state.ai_mode),
		CRISIS_ROCK_COUNT_CHAMPION,
		CRISIS_ROCK_COUNT_MYTHIC
	)


func spawn_crisis_rock_wall(deps: Dictionary = {}) -> int:
	if rock_lifecycle_coordinator == null:
		return 0
	return rock_lifecycle_coordinator.spawn_crisis_rock_wall(get_crisis_rock_count(), deps)


func sync_quake_audio(deps: Dictionary) -> void:
	if quake_state == null:
		return
	quake_state.audio_active = Stage2AudioRouter.sync_quake_loop(
		float(quake_state.timer),
		bool(quake_state.audio_active),
		deps,
		cached_audio
	)


func play_quake_audio(deps: Dictionary) -> void:
	if quake_state == null:
		return
	quake_state.audio_active = Stage2AudioRouter.play_quake_loop(
		deps,
		cached_audio,
		bool(quake_state.audio_active)
	)


func stop_quake_audio(deps: Dictionary) -> void:
	if quake_state == null:
		return
	quake_state.audio_active = Stage2AudioRouter.stop_quake_loop(deps, cached_audio)


func _emit_final_stomp(deps: Dictionary) -> void:
	if quake_state == null:
		return
	quake_state.activate(
		final_quake_duration_sec,
		QUAKE_MIN_DURATION_SEC,
		quake_repeat_cooldown_sec,
		quake_boss_launch_guard_sec,
		false
	)
	spawn_crisis_rock_wall(deps)
	_trigger_warning("rage_wall", "방어벽 낙하!", FINAL_WARNING_SEC)
	play_quake_audio(deps)
	Stage2AudioRouter.play_boss_cry(deps, cached_audio)
	_request_shake(deps, FINAL_SHAKE_DURATION_SEC, FINAL_SHAKE_STRENGTH)


func _trigger_warning(kind: String, text: String, duration_sec: float) -> void:
	if skill_warning_state != null and skill_warning_state.has_method("trigger"):
		skill_warning_state.trigger(kind, text, duration_sec)


func _request_shake(deps: Dictionary, duration_sec: float, strength: float) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(duration_sec, strength)
