extends RefCounted

const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

const STAGE_ID := 1
const SKILL_SPINNING_TOP := "spinning_top"
const SKILL_WHIP := "whip"
const TRIGGER_INSTANT := "instant"
const TRIGGER_ON_BOSS_HIT := "on_boss_hit"
const SPINNING_TOP_COOLDOWN_FRAMES := 960.0
const WHIP_COOLDOWN_FRAMES := 1320.0
const READY_FLASH_FRAMES := 24.0
const CAST_FLASH_FRAMES := 30.0
const HUD_SORT_FRAMES_PER_SECOND := 60.0

var skill_runtime := {}


func _init() -> void:
	reset()


func reset() -> void:
	_reset_skill(SKILL_SPINNING_TOP)
	_reset_skill(SKILL_WHIP)


func reset_round() -> void:
	_normalize_skill_for_next_round(SKILL_SPINNING_TOP)
	_normalize_skill_for_next_round(SKILL_WHIP)


func update(fps_scale: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		reset()
		return {}
	_tick_flash_timers(fps_scale)
	if not bool(context.get("ball_active", false)):
		return {}
	if bool(context.get("active_item_boss_skill_cooldown_paused", false)):
		_mark_charging_skills_paused()
		return {}
	_update_spinning_top(fps_scale, context, deps)
	_update_whip(fps_scale, deps)
	return {}


func consume_on_hit(skill_id: String, context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if skill_id != SKILL_WHIP:
		return false
	var runtime: Dictionary = _get_runtime(SKILL_WHIP)
	if not bool(runtime.get("ready", false)):
		return false
	runtime["timer"] = 0.0
	runtime["ready"] = false
	runtime["status"] = "casting"
	runtime["flash_timer"] = CAST_FLASH_FRAMES
	skill_runtime[SKILL_WHIP] = runtime
	if BossSkillParryGate.try_parry(SKILL_WHIP, "상모돌리기", context, deps):
		return false
	return true


func get_hud_context() -> Dictionary:
	return {
		"stage1_dalji_boss_skill_hud_active": true,
		"stage1_dalji_boss_skill_hud_boss_name": "달지",
		"stage1_dalji_boss_skill_hud_skills": [
			_build_hud_skill(
				SKILL_SPINNING_TOP,
				"팽이치기",
				TRIGGER_INSTANT,
				Color(1.0, 0.76, 0.18)
			),
			_build_hud_skill(
				SKILL_WHIP,
				"상모돌리기",
				TRIGGER_ON_BOSS_HIT,
				Color(0.72, 0.42, 1.0)
			),
		],
	}


func is_ready(skill_id: String) -> bool:
	return bool(_get_runtime(skill_id).get("ready", false))


func get_progress(skill_id: String) -> float:
	var runtime: Dictionary = _get_runtime(skill_id)
	var duration: float = max(1.0, float(runtime.get("duration", 1.0)))
	return clamp(float(runtime.get("timer", 0.0)) / duration, 0.0, 1.0)


func _update_spinning_top(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var runtime: Dictionary = _get_runtime(SKILL_SPINNING_TOP)
	var spinning_top_state: Object = deps.get("stage1_dalji_spinning_top_skill_state", null)
	if spinning_top_state != null:
		if spinning_top_state.has_method("is_active") and bool(spinning_top_state.is_active()):
			runtime["status"] = "casting"
			skill_runtime[SKILL_SPINNING_TOP] = runtime
			return

	runtime = _charge_skill(runtime, fps_scale)
	if bool(runtime.get("ready", false)):
		runtime["status"] = "ready"
		if BossSkillParryGate.try_parry(SKILL_SPINNING_TOP, "팽이치기", context, deps):
			runtime["timer"] = 0.0
			runtime["ready"] = false
			runtime["used"] = false
			runtime["status"] = "charging"
			runtime["flash_timer"] = CAST_FLASH_FRAMES
			skill_runtime[SKILL_SPINNING_TOP] = runtime
			return
		if spinning_top_state != null and spinning_top_state.has_method("activate"):
			if bool(spinning_top_state.activate(context, deps)):
				runtime["timer"] = 0.0
				runtime["ready"] = false
				runtime["used"] = false
				runtime["status"] = "casting"
				runtime["flash_timer"] = CAST_FLASH_FRAMES
	else:
		runtime["status"] = "charging"
	skill_runtime[SKILL_SPINNING_TOP] = runtime


func _update_whip(fps_scale: float, deps: Dictionary) -> void:
	var runtime: Dictionary = _get_runtime(SKILL_WHIP)
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null:
		var locked: bool = false
		if whip_state.has_method("is_active"):
			locked = locked or bool(whip_state.is_active())
		if whip_state.has_method("is_movement_locked"):
			locked = locked or bool(whip_state.is_movement_locked())
		if locked:
			runtime["status"] = "casting"
			skill_runtime[SKILL_WHIP] = runtime
			return

	runtime = _charge_skill(runtime, fps_scale)
	runtime["status"] = "ready" if bool(runtime.get("ready", false)) else "charging"
	skill_runtime[SKILL_WHIP] = runtime


func _charge_skill(runtime: Dictionary, fps_scale: float) -> Dictionary:
	if bool(runtime.get("ready", false)):
		return runtime
	var duration: float = max(1.0, float(runtime.get("duration", 1.0)))
	var old_timer: float = float(runtime.get("timer", 0.0))
	var next_timer: float = min(duration, old_timer + fps_scale)
	runtime["timer"] = next_timer
	if next_timer >= duration:
		runtime["ready"] = true
		runtime["flash_timer"] = max(float(runtime.get("flash_timer", 0.0)), READY_FLASH_FRAMES)
	return runtime


func _tick_flash_timers(fps_scale: float) -> void:
	for skill_id in [SKILL_SPINNING_TOP, SKILL_WHIP]:
		var runtime: Dictionary = _get_runtime(skill_id)
		runtime["flash_timer"] = max(0.0, float(runtime.get("flash_timer", 0.0)) - fps_scale)
		skill_runtime[skill_id] = runtime


func _mark_charging_skills_paused() -> void:
	for skill_id in [SKILL_SPINNING_TOP, SKILL_WHIP]:
		var runtime: Dictionary = _get_runtime(skill_id)
		if not bool(runtime.get("ready", false)) and str(runtime.get("status", "charging")) != "casting":
			runtime["status"] = "paused"
		skill_runtime[skill_id] = runtime


func _reset_skill(skill_id: String) -> void:
	var duration: float = SPINNING_TOP_COOLDOWN_FRAMES if skill_id == SKILL_SPINNING_TOP else WHIP_COOLDOWN_FRAMES
	skill_runtime[skill_id] = {
		"timer": 0.0,
		"duration": duration,
		"ready": false,
		"used": false,
		"status": "charging",
		"flash_timer": 0.0,
	}


func _normalize_skill_for_next_round(skill_id: String) -> void:
	var runtime: Dictionary = _get_runtime(skill_id)
	runtime["flash_timer"] = 0.0
	if bool(runtime.get("ready", false)):
		runtime["status"] = "ready"
	elif str(runtime.get("status", "charging")) in ["casting", "used"]:
		runtime["status"] = "charging"
		runtime["used"] = false
	skill_runtime[skill_id] = runtime


func _get_runtime(skill_id: String) -> Dictionary:
	if not skill_runtime.has(skill_id):
		_reset_skill(skill_id)
	return skill_runtime[skill_id]


func _build_hud_skill(skill_id: String, label: String, trigger_type: String, color: Color) -> Dictionary:
	var runtime: Dictionary = _get_runtime(skill_id)
	var duration: float = max(1.0, float(runtime.get("duration", 1.0)))
	var remaining_frames: float = max(0.0, duration - float(runtime.get("timer", 0.0)))
	var duration_seconds: float = duration / HUD_SORT_FRAMES_PER_SECOND
	var remaining_seconds: float = remaining_frames / HUD_SORT_FRAMES_PER_SECOND
	return {
		"id": skill_id,
		"label": label,
		"trigger_type": trigger_type,
		"trigger_label": "즉시" if trigger_type == TRIGGER_INSTANT else "타격",
		"progress": clamp(float(runtime.get("timer", 0.0)) / duration, 0.0, 1.0),
		"cooldown_remaining": remaining_seconds,
		"cooldown_total": duration_seconds,
		"sort_remaining": remaining_seconds,
		"ready": bool(runtime.get("ready", false)),
		"used": bool(runtime.get("used", false)),
		"status": str(runtime.get("status", "charging")),
		"flash": clamp(float(runtime.get("flash_timer", 0.0)) / READY_FLASH_FRAMES, 0.0, 1.0),
		"color": color,
	}
