extends RefCounted

const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")

const STAGE_ID := 1
const BOSS_VARIANT := "podo"
const SKILL_PATROL_GUARDS := "patrol_guards"
const SKILL_ARREST_ROPE := "arrest_rope"
const PATROL_GUARDS_COOLDOWN_FRAMES := 960.0
const ARREST_ROPE_COOLDOWN_FRAMES := 1200.0
const READY_FLASH_FRAMES := 24.0
const CAST_FLASH_FRAMES := 30.0
const HUD_SORT_FRAMES_PER_SECOND := 60.0

var skill_runtime := {}


func _init() -> void:
	reset()


func reset() -> void:
	_reset_skill(SKILL_PATROL_GUARDS)
	_reset_skill(SKILL_ARREST_ROPE)


func reset_round() -> void:
	_normalize_skill_for_next_round(SKILL_PATROL_GUARDS)
	_normalize_skill_for_next_round(SKILL_ARREST_ROPE)


func update(fps_scale: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not _is_pododaejang_context(context):
		reset()
		return {}
	_tick_flash_timers(fps_scale)
	if not bool(context.get("ball_active", false)):
		return {}
	if bool(context.get("active_item_boss_skill_cooldown_paused", false)):
		_mark_charging_skills_paused()
		return {}
	_update_patrol_guards(fps_scale, context, deps)
	_update_arrest_rope(fps_scale, deps)
	return {}


func consume_on_hit(skill_id: String, _context: Dictionary = {}, _deps: Dictionary = {}) -> bool:
	if skill_id != SKILL_ARREST_ROPE:
		return false
	var runtime: Dictionary = _get_runtime(SKILL_ARREST_ROPE)
	if not bool(runtime.get("ready", false)):
		return false
	runtime["timer"] = 0.0
	runtime["ready"] = false
	runtime["status"] = "casting"
	runtime["flash_timer"] = CAST_FLASH_FRAMES
	skill_runtime[SKILL_ARREST_ROPE] = runtime
	return true


func get_hud_context() -> Dictionary:
	return {
		"stage1_pododaejang_boss_skill_hud_active": true,
		"stage1_pododaejang_boss_skill_hud_boss_name": "포도대장",
		"stage1_pododaejang_boss_skill_hud_skills": [
			_build_hud_skill(
				SKILL_PATROL_GUARDS,
				"포졸소환",
				BossSkillTriggerClass.TRIGGER_INSTANT,
				Color(0.55, 0.36, 0.18)
			),
			_build_hud_skill(
				SKILL_ARREST_ROPE,
				"포승줄",
				BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT,
				Color(0.74, 0.61, 0.36)
			),
		],
	}


func is_ready(skill_id: String) -> bool:
	return bool(_get_runtime(skill_id).get("ready", false))


func get_progress(skill_id: String) -> float:
	var runtime: Dictionary = _get_runtime(skill_id)
	var duration: float = maxf(1.0, float(runtime.get("duration", 1.0)))
	return clampf(float(runtime.get("timer", 0.0)) / duration, 0.0, 1.0)


func _update_patrol_guards(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var runtime: Dictionary = _get_runtime(SKILL_PATROL_GUARDS)
	var state: Object = deps.get("stage1_pododaejang_patrol_guards_skill_state", null)
	if state != null and state.has_method("is_active") and bool(state.is_active()):
		runtime["status"] = "casting"
		skill_runtime[SKILL_PATROL_GUARDS] = runtime
		return
	if state != null and state.has_method("was_used_this_round") and bool(state.was_used_this_round()):
		runtime["timer"] = 0.0
		runtime["ready"] = false
		runtime["used"] = true
		runtime["status"] = "used"
		skill_runtime[SKILL_PATROL_GUARDS] = runtime
		return
	runtime = _charge_skill(runtime, fps_scale)
	if bool(runtime.get("ready", false)):
		runtime["status"] = "ready"
		if state != null and state.has_method("activate") and bool(state.activate(context, deps)):
			runtime["timer"] = 0.0
			runtime["ready"] = false
			runtime["used"] = false
			runtime["status"] = "casting"
			runtime["flash_timer"] = CAST_FLASH_FRAMES
	else:
		runtime["status"] = "charging"
	skill_runtime[SKILL_PATROL_GUARDS] = runtime


func _update_arrest_rope(fps_scale: float, deps: Dictionary) -> void:
	var runtime: Dictionary = _get_runtime(SKILL_ARREST_ROPE)
	var state: Object = deps.get("stage1_pododaejang_arrest_rope_skill_state", null)
	if state != null and state.has_method("is_active") and bool(state.is_active()):
		runtime["status"] = "casting"
		skill_runtime[SKILL_ARREST_ROPE] = runtime
		return
	runtime = _charge_skill(runtime, fps_scale)
	runtime["status"] = "ready" if bool(runtime.get("ready", false)) else "charging"
	skill_runtime[SKILL_ARREST_ROPE] = runtime


func _charge_skill(runtime: Dictionary, fps_scale: float) -> Dictionary:
	if bool(runtime.get("ready", false)):
		return runtime
	var duration: float = maxf(1.0, float(runtime.get("duration", 1.0)))
	var next_timer: float = minf(duration, float(runtime.get("timer", 0.0)) + fps_scale)
	runtime["timer"] = next_timer
	if next_timer >= duration:
		runtime["ready"] = true
		runtime["flash_timer"] = maxf(float(runtime.get("flash_timer", 0.0)), READY_FLASH_FRAMES)
	return runtime


func _tick_flash_timers(fps_scale: float) -> void:
	for skill_id in [SKILL_PATROL_GUARDS, SKILL_ARREST_ROPE]:
		var runtime: Dictionary = _get_runtime(skill_id)
		runtime["flash_timer"] = maxf(0.0, float(runtime.get("flash_timer", 0.0)) - fps_scale)
		skill_runtime[skill_id] = runtime


func _mark_charging_skills_paused() -> void:
	for skill_id in [SKILL_PATROL_GUARDS, SKILL_ARREST_ROPE]:
		var runtime: Dictionary = _get_runtime(skill_id)
		if not bool(runtime.get("ready", false)) and str(runtime.get("status", "charging")) != "casting":
			runtime["status"] = "paused"
			skill_runtime[skill_id] = runtime


func _reset_skill(skill_id: String) -> void:
	var duration: float = PATROL_GUARDS_COOLDOWN_FRAMES if skill_id == SKILL_PATROL_GUARDS else ARREST_ROPE_COOLDOWN_FRAMES
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
	if skill_id == SKILL_PATROL_GUARDS and bool(runtime.get("used", false)):
		runtime["timer"] = 0.0
		runtime["ready"] = false
		runtime["used"] = false
		runtime["status"] = "charging"
	elif bool(runtime.get("ready", false)):
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
	var duration: float = maxf(1.0, float(runtime.get("duration", 1.0)))
	var remaining_frames: float = maxf(0.0, duration - float(runtime.get("timer", 0.0)))
	var duration_seconds: float = duration / HUD_SORT_FRAMES_PER_SECOND
	var remaining_seconds: float = remaining_frames / HUD_SORT_FRAMES_PER_SECOND
	return {
		"id": skill_id,
		"label": label,
		"name": label,
		"trigger_type": trigger_type,
		"trigger_label": BossSkillTriggerClass.get_label(trigger_type),
		"progress": clampf(float(runtime.get("timer", 0.0)) / duration, 0.0, 1.0),
		"cooldown_remaining": remaining_seconds,
		"cooldown_total": duration_seconds,
		"sort_remaining": remaining_seconds,
		"ready": bool(runtime.get("ready", false)),
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"used": bool(runtime.get("used", false)),
		"status": str(runtime.get("status", "charging")),
		"flash": clampf(float(runtime.get("flash_timer", 0.0)) / READY_FLASH_FRAMES, 0.0, 1.0),
		"color": color,
	}


func _is_pododaejang_context(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in [BOSS_VARIANT, "pododaejang", "podo_daejang"]
