extends RefCounted

const Stage4PonkIllusionState := preload("res://scripts/stages/stage4/stage4_ponk_illusion_state.gd")
const Stage4PonkMagneticFieldState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_field_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")
const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")

const MAGNETIC_SKILL_ID := "magnetic_field"
const MEDITATION_SKILL_ID := "meditation"
const ILLUSION_SKILL_ID := "illusion_ripple"

# Pure Stage 4 Ponk boss-skill-card projection. Runtime owners retain all
# mutable clocks and activation rules; this builder owns card order, Korean
# display copy, normalized progress, status, and trigger metadata only.


func build_context(
	magnetic_state: Object,
	meditation_state: Object,
	illusion_state: Object,
	meditation_trigger_chance: float
) -> Dictionary:
	return {
		"stage4_ponk_boss_skill_hud_active": true,
		"stage4_ponk_boss_skill_hud_skills": [
			_build_magnetic_skill(magnetic_state, bool(meditation_state.meditation_active)),
			_build_meditation_skill(
				meditation_state,
				bool(magnetic_state.magnetic_active),
				meditation_trigger_chance
			),
			_build_illusion_skill(illusion_state),
		],
	}


func _build_magnetic_skill(state: Object, meditation_active: bool) -> Dictionary:
	var active: bool = bool(state.magnetic_active)
	var cooldown: float = float(state.magnetic_cooldown_seconds)
	var cooldown_ready: bool = cooldown <= 0.0
	var ready: bool = cooldown_ready and not active and not meditation_active
	var status := "casting" if active else ("ready" if ready else "charging")
	var progress: float = 1.0 if active or cooldown_ready else _cooldown_progress(
		cooldown,
		Stage4PonkMagneticFieldState.COOLDOWN_SEC
	)
	return {
		"id": MAGNETIC_SKILL_ID,
		"name": "굴절 자기장",
		"short_label": "자기장",
		"trigger": "25초마다 자동 발동",
		"trigger_type": BossSkillTriggerClass.TRIGGER_INSTANT,
		"status": status,
		"ready": ready,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"active": active,
		"progress": progress,
		"remaining": maxf(0.0, cooldown),
		"total": Stage4PonkMagneticFieldState.COOLDOWN_SEC,
		"cooldown_remaining": maxf(0.0, cooldown),
		"cooldown_total": Stage4PonkMagneticFieldState.COOLDOWN_SEC,
		"cooldown_seconds": Stage4PonkMagneticFieldState.COOLDOWN_SEC,
		"duration_remaining": float(state.magnetic_timer_frames),
		"duration_total": (
			Stage4PonkMagneticFieldState.ENRAGED_DURATION_FRAMES
			if bool(state.magnetic_enraged)
			else Stage4PonkMagneticFieldState.DURATION_FRAMES
		),
		"color": Color(0.50, 0.95, 1.0, 1.0),
		"description": "공을 보스 주변에서 굴절시키고 종료 시 감속 구체를 발사합니다.",
	}


func _build_meditation_skill(
	state: Object,
	magnetic_active: bool,
	trigger_chance: float
) -> Dictionary:
	var active: bool = bool(state.meditation_active)
	var cooldown: float = float(state.meditation_cooldown_seconds)
	var cooldown_ready: bool = cooldown <= 0.0
	var ready: bool = cooldown_ready and not magnetic_active and not active
	var status := "casting" if active else ("ready" if ready else "charging")
	var progress: float = 1.0 if active or cooldown_ready else _cooldown_progress(
		cooldown,
		Stage4PonkMeditationState.COOLDOWN_SEC
	)
	return {
		"id": MEDITATION_SKILL_ID,
		"name": "위빠사나 명상",
		"short_label": "명상",
		"trigger": "18초 쿨타임 후 보스 타격",
		"trigger_type": BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT,
		"trigger_chance": trigger_chance,
		"status": status,
		"ready": ready,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"active": active,
		"progress": progress,
		"remaining": maxf(0.0, cooldown),
		"total": Stage4PonkMeditationState.COOLDOWN_SEC,
		"cooldown_remaining": maxf(0.0, cooldown),
		"cooldown_total": Stage4PonkMeditationState.COOLDOWN_SEC,
		"cooldown_seconds": Stage4PonkMeditationState.COOLDOWN_SEC,
		"duration_remaining": float(state.meditation_timer_frames),
		"duration_total": Stage4PonkMeditationState.DURATION_FRAMES,
		"color": Color(1.0, 0.76, 0.26, 1.0),
		"description": "공을 숫자 8 궤도로 붙잡고 명상 종료 후 추가 가속으로 플레이어 쪽으로 쏩니다.",
	}


func _build_illusion_skill(state: Object) -> Dictionary:
	var active: bool = bool(state.illusion_active)
	var cooldown: float = float(state.illusion_cooldown_seconds)
	var awaken_stage: int = int(state.illusion_awaken_stage)
	var unlocked: bool = bool(state.illusion_unlocked)
	var cooldown_ready: bool = cooldown <= 0.0
	var card_unlocked := (
		unlocked
		and awaken_stage >= Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_SERVE_WAIT
	)
	var first_cast_building := (
		unlocked
		and awaken_stage >= Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_SERVE_WAIT
		and awaken_stage < Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_LOOP
	)
	var ready := (
		card_unlocked
		and awaken_stage >= Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_LOOP
		and cooldown_ready
		and not active
	)
	var status := "locked"
	if active:
		status = "casting"
	elif ready:
		status = "ready"
	elif card_unlocked:
		status = "charging"
	var progress := 0.0
	if active or ready:
		progress = 1.0
	elif awaken_stage == Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_COUNTDOWN:
		progress = _cooldown_progress(
			float(state.illusion_first_cast_delay_frames),
			Stage4PonkIllusionState.ILLUSION_FIRST_CAST_DELAY_FRAMES
		)
	elif awaken_stage >= Stage4PonkIllusionState.ILLUSION_AWAKEN_STAGE_LOOP:
		progress = _cooldown_progress(
			cooldown,
			Stage4PonkIllusionState.ILLUSION_COOLDOWN_SEC
		)
	var remaining: float = maxf(0.0, cooldown)
	var total: float = Stage4PonkIllusionState.ILLUSION_COOLDOWN_SEC
	if first_cast_building:
		remaining = maxf(0.0, float(state.illusion_first_cast_delay_frames)) / 60.0
		total = Stage4PonkIllusionState.ILLUSION_FIRST_CAST_DELAY_FRAMES / 60.0
	var duration_seconds: int = int(round(Stage4PonkIllusionState.ILLUSION_DURATION_FRAMES / 60.0))
	return {
		"id": ILLUSION_SKILL_ID,
		"name": "몽환포영",
		"short_label": "포영",
		"trigger": "플레이어 %d점에 각성" % Stage4PonkIllusionState.ILLUSION_UNLOCK_PLAYER_SCORE,
		"trigger_type": BossSkillTriggerClass.TRIGGER_INSTANT,
		"status": status,
		"ready": ready,
		"cooldown_contract": "score_latched",
		"initial_ready_allowed": false,
		"active": active,
		"progress": progress,
		"remaining": remaining,
		"total": total,
		"cooldown_remaining": maxf(0.0, cooldown),
		"cooldown_total": Stage4PonkIllusionState.ILLUSION_COOLDOWN_SEC,
		"cooldown_seconds": Stage4PonkIllusionState.ILLUSION_COOLDOWN_SEC,
		"duration_remaining": float(state.illusion_timer_frames),
		"duration_total": Stage4PonkIllusionState.ILLUSION_DURATION_FRAMES,
		"color": Color(0.62, 0.45, 0.85, 1.0),
		"description": "화면 전체를 물결처럼 일그러뜨려 %d초 동안 시야를 방해합니다." % duration_seconds,
	}


func _cooldown_progress(remaining: float, total: float) -> float:
	return clampf(1.0 - maxf(0.0, remaining) / maxf(0.001, total), 0.0, 1.0)
