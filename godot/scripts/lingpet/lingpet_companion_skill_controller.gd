extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetCompanionSkillArmGate := preload("res://scripts/lingpet/lingpet_companion_skill_arm_gate.gd")
const LingpetCompanionSkillEffectUpdateGate := preload("res://scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd")
const LingpetCompanionSkillUpdateContextBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_update_context_builder.gd")

const ACTION_NONE := "none"
const ACTION_ARM := "arm"
const ACTION_LAUNCH := "launch"

var _arm_gate: Object = LingpetCompanionSkillArmGate.new()
var _effect_update_gate: Object = LingpetCompanionSkillEffectUpdateGate.new()
var _update_context_builder: Object = LingpetCompanionSkillUpdateContextBuilder.new()
var _current_profile: Object = null
var _active_skill_slot_resolver: Object = null
var _companion_skill_visual_resolver: Object = null
var _companion_skill_persistence: Object = null
var _companion_skill_states: Array = []
var _skill_runtime_host: Object = null
var _skill_runtime_surface: Object = null
var _default_windup_seconds := 0.0
var _companion_radius := 0.0


func configure(
	current_profile: Object,
	active_skill_slot_resolver: Object,
	companion_skill_visual_resolver: Object,
	companion_skill_persistence: Object,
	companion_skill_states: Array,
	skill_runtime_host: Object,
	skill_runtime_surface: Object,
	default_windup_seconds: float,
	companion_radius: float
) -> void:
	_current_profile = current_profile
	_active_skill_slot_resolver = active_skill_slot_resolver
	_companion_skill_visual_resolver = companion_skill_visual_resolver
	_companion_skill_persistence = companion_skill_persistence
	_companion_skill_states = companion_skill_states
	_skill_runtime_host = skill_runtime_host
	_skill_runtime_surface = skill_runtime_surface
	_default_windup_seconds = maxf(0.0, default_windup_seconds)
	_companion_radius = maxf(0.0, companion_radius)


func update_active_slots(
	delta: float,
	state: String,
	companion_state: String,
	owner: Object,
	registry: Object,
	switch_transition_active: bool,
	companion_visible: bool,
	companion_pos: Vector2,
	companion_catch_height: float,
	companion_exhausted: bool,
	runtime_integration: Object
) -> Vector2:
	if _skill_runtime_surface == null:
		return companion_pos

	var ball_active := bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false))
	var ball_context_ready := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6
	var active_slot_count: int = int(_skill_runtime_surface.get_active_slot_count(
		_current_profile,
		_active_skill_slot_resolver,
		_skill_runtime_host
	))
	var active_skill_ids: Array[String] = _skill_runtime_surface.get_active_skill_ids(
		_current_profile,
		_active_skill_slot_resolver,
		_skill_runtime_host
	)
	for slot in range(active_slot_count):
		var skill_surface: Dictionary = _skill_runtime_surface.get_active_surface_for_slot(
			_current_profile,
			_active_skill_slot_resolver,
			_companion_skill_persistence,
			_companion_skill_states,
			_skill_runtime_host,
			_default_windup_seconds,
			slot,
			active_slot_count
		)
		var skill_id := str(skill_surface.get("skill_id", ""))
		if skill_id == "":
			continue
		var skill_state: Object = skill_surface.get("skill_state", null) as Object
		if _effect_update_gate.can_skip_idle(skill_id, skill_state, ball_active, _skill_runtime_host):
			_effect_update_gate.record_idle_skip()
			continue
		if not ball_context_ready:
			ball_pos = _vector2_or_fallback(BattleSceneOwnerReader.get_value(owner, "ball_pos", Vector2.ZERO), Vector2.ZERO)
			ball_vel = _vector2_or_fallback(BattleSceneOwnerReader.get_value(owner, "ball_vel", Vector2.ZERO), Vector2.ZERO)
			ball_size = float(BattleSceneOwnerReader.get_value(owner, "ball_size", 28.6))
			ball_context_ready = true
		var current_active_skill: Dictionary = skill_surface.get("active_skill", {}) as Dictionary
		_effect_update_gate.record_runtime_update()
		var decision: Dictionary = update(
			delta,
			_update_context_builder.build(
				state,
				companion_state,
				owner,
				registry,
				skill_id,
				skill_state,
				_skill_runtime_host,
				float(skill_surface.get("windup_seconds", _default_windup_seconds)),
				ball_active,
				ball_pos,
				ball_vel,
				ball_size,
				switch_transition_active,
				companion_visible,
				companion_pos,
				_companion_radius,
				companion_catch_height,
				current_active_skill,
				int(skill_surface.get("active_skill_level_fallback", 0)),
				slot,
				active_skill_ids,
				_companion_skill_states,
				companion_exhausted
			)
		)
		match str(decision.get("action", ACTION_NONE)):
			ACTION_ARM:
				if companion_pos == Vector2.ZERO and runtime_integration != null:
					companion_pos = _vector2_or_fallback(
						runtime_integration.call("ensure_companion_position_for_skill_tick", owner),
						companion_pos
					)
				arm_windup(skill_state, _skill_runtime_host, skill_id)
			ACTION_LAUNCH:
				if runtime_integration != null:
					companion_pos = _vector2_or_fallback(
						runtime_integration.call("launch_companion_skill_from_controller", owner, registry, slot),
						companion_pos
					)
			_:
				pass
		if bool(_skill_runtime_surface.consume_companion_strike_request(_skill_runtime_host, skill_id)):
			if runtime_integration != null:
				runtime_integration.call("begin_companion_skill_strike_from_controller")

	var override_owner: Dictionary = _skill_runtime_surface.get_active_position_owner_for_ids(
		active_skill_ids,
		_companion_skill_visual_resolver,
		_skill_runtime_host,
		companion_pos
	)
	var has_position_override := bool(_skill_runtime_surface.has_active_position_override(
		_companion_skill_visual_resolver,
		override_owner
	))
	if has_position_override:
		companion_pos = _vector2_or_fallback(override_owner.get("pos", companion_pos), companion_pos)
	return companion_pos


func reset_effect_update_counters_for_tests() -> void:
	_effect_update_gate.reset_counters_for_tests()


func get_effect_idle_skip_count_for_tests() -> int:
	return int(_effect_update_gate.get_idle_skip_count())


func get_effect_runtime_update_count_for_tests() -> int:
	return int(_effect_update_gate.get_runtime_update_count())


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
		skill_runtime_host.update(safe_delta, params.get("owner", null) as Object, params.get("registry", null) as Object, skill_id, params)
	if bool(skill_state.windup_active) and float(skill_state.cooldown) > 0.0:
		skill_state.cancel_windup()
		return _make_action(ACTION_NONE)
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
	owner: Object = null,
	launch_context: Dictionary = {}
) -> bool:
	if skill_state == null or skill_runtime_host == null:
		return false
	if not skill_runtime_host.launch(skill_id, origin, owner, launch_context):
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
	if bool(params.get("switch_transition_active", false)):
		return false
	if bool(params.get("companion_exhausted", false)):
		return false
	if not bool(params.get("ball_active", false)):
		return false
	if skill_runtime_host != null and bool(skill_runtime_host.is_launch_blocked(skill_id)):
		return false
	if skill_runtime_host != null and skill_runtime_host.has_method("can_arm"):
		if not bool(skill_runtime_host.can_arm(skill_id, params)):
			return false
	if not bool(_arm_gate.can_arm(
		int(params.get("slot_index", 0)),
		skill_id,
		params.get("active_skill_ids", []) as Array[String],
		params.get("skill_states", []) as Array,
		skill_runtime_host
	)):
		return false
	return true


func _make_action(action: String) -> Dictionary:
	return {
		"action": action,
	}


func _vector2_or_fallback(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
