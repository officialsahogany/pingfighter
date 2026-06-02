extends RefCounted

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")

const ACTION_NONE := "none"
const ACTION_ARM := "arm"
const ACTION_LAUNCH := "launch"


func update(delta: float, params: Dictionary) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	var skill_id := str(params.get("skill_id", ""))
	var skill_state: Object = params.get("skill_state", null) as Object
	var skill_runtime_host: Object = params.get("skill_runtime_host", null) as Object
	if skill_state == null:
		return _make_action(ACTION_NONE)
	if not LingpetSkillDispatcher.has_supported_runtime(skill_id):
		skill_state.cancel_windup()
		return _make_action(ACTION_NONE)
	if skill_runtime_host != null:
		skill_runtime_host.update(safe_delta, params.get("owner", null) as Object, params.get("registry", null) as Object, skill_id)
	if bool(skill_state.advance_windup(safe_delta, maxf(0.0, float(params.get("windup_seconds", 0.0))))):
		return _make_action(ACTION_LAUNCH)
	if _should_arm(skill_id, skill_state, skill_runtime_host, params):
		return _make_action(ACTION_ARM)
	return _make_action(ACTION_NONE)


func arm_windup(skill_state: Object, skill_runtime_host: Object, skill_id: String) -> bool:
	if skill_state == null or not LingpetSkillDispatcher.has_supported_runtime(skill_id):
		return false
	if skill_runtime_host != null:
		skill_runtime_host.prewarm(skill_id)
	skill_state.arm_windup()
	return true


func complete_launch(
	skill_state: Object,
	skill_runtime_host: Object,
	skill_id: String,
	origin: Vector2,
	cooldown_seconds: float,
	flash_seconds: float,
	registry: Object,
	owner: Object = null
) -> bool:
	if skill_state == null or skill_runtime_host == null:
		return false
	if not skill_runtime_host.launch(skill_id, origin, owner):
		skill_state.cancel_windup()
		return false
	skill_state.complete_launch(origin, cooldown_seconds, flash_seconds)
	skill_runtime_host.trigger_launch_feedback(skill_id, registry)
	return true


func _should_arm(skill_id: String, skill_state: Object, skill_runtime_host: Object, params: Dictionary) -> bool:
	if str(params.get("state", "")) != str(params.get("companion_state", "companion")):
		return false
	if bool(skill_state.windup_active) or float(skill_state.cooldown) > 0.0:
		return false
	if not bool(params.get("ball_active", false)):
		return false
	if skill_runtime_host != null and bool(skill_runtime_host.is_launch_blocked(skill_id)):
		return false
	return true


func _make_action(action: String) -> Dictionary:
	return {
		"action": action,
	}
