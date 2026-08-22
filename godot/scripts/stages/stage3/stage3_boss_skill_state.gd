extends "res://scripts/stages/stage3/stage3_boss_skill_compatibility_surface.gd"

const Stage3CurseChestState := preload("res://scripts/stages/stage3/stage3_curse_chest_state.gd")
const Stage3BossSkillContextBuilder := preload("res://scripts/stages/stage3/stage3_boss_skill_context_builder.gd")
const Stage3BossSkillHandoffCoordinator := preload("res://scripts/stages/stage3/stage3_boss_skill_handoff_coordinator.gd")
const Stage3BossSkillHudStateBuilder := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_state_builder.gd")
const Stage3BossSkillLifecycle := preload("res://scripts/stages/stage3/stage3_boss_skill_lifecycle.gd")
const Stage3BossSkillScheduler := preload("res://scripts/stages/stage3/stage3_boss_skill_scheduler.gd")
const Stage3BossSkillUpdateCoordinator := preload("res://scripts/stages/stage3/stage3_boss_skill_update_coordinator.gd")
const Stage3KuromiAwakeningState := preload("res://scripts/stages/stage3/stage3_kuromi_awakening_state.gd")
const Stage3KuromiEatingState := preload("res://scripts/stages/stage3/stage3_kuromi_eating_state.gd")
const Stage3PrismBurstState := preload("res://scripts/stages/stage3/stage3_prism_burst_state.gd")
const Stage3PsychoballState := preload("res://scripts/stages/stage3/stage3_psychoball_state.gd")
const Stage3StarpointState := preload("res://scripts/stages/stage3/stage3_starpoint_state.gd")
const Stage3TailWhipState := preload("res://scripts/stages/stage3/stage3_tail_whip_state.gd")
const Stage3TearShowerState := preload("res://scripts/stages/stage3/stage3_tear_shower_state.gd")
const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

const STAGE_ID := 3
const BOSS_GAUGE_MAX := 500.0
const BOSS_GAUGE_GAIN_ON_HIT := 0.0

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var boss_special_ready := false
var boss_red_intensity := 0.0
var status := "charging"
var _context_builder: Object = null
var _handoff_coordinator: Object = null
var _lifecycle: Object = null
var _hud_state_builder := Stage3BossSkillHudStateBuilder.new()
var _scheduler := Stage3BossSkillScheduler.new()
var _starpoint_state: Object = null
var _update_coordinator: Object = null


func _init() -> void:
	_tear_shower_state = Stage3TearShowerState.new(rng)
	_curse_chest_state = Stage3CurseChestState.new(rng)
	_psychoball_state = Stage3PsychoballState.new(rng)
	_tail_whip_state = Stage3TailWhipState.new(rng)
	_kuromi_awakening_state = Stage3KuromiAwakeningState.new(rng)
	_kuromi_eating_state = Stage3KuromiEatingState.new(rng)
	_prism_burst_state = Stage3PrismBurstState.new(rng)
	rng.seed = 3303
	_starpoint_state = Stage3StarpointState.new(rng)
	_handoff_coordinator = Stage3BossSkillHandoffCoordinator.new(
		_prism_burst_state,
		_starpoint_state,
		_kuromi_eating_state
	)
	_lifecycle = Stage3BossSkillLifecycle.new(
		_tear_shower_state,
		_curse_chest_state,
		_psychoball_state,
		_tail_whip_state,
		_kuromi_eating_state,
		_kuromi_awakening_state,
		_prism_burst_state,
		_starpoint_state
	)
	_context_builder = Stage3BossSkillContextBuilder.new(
		_prism_burst_state,
		_kuromi_awakening_state,
		_tear_shower_state,
		_curse_chest_state,
		_psychoball_state,
		_tail_whip_state,
		_kuromi_eating_state,
		_starpoint_state
	)
	_update_coordinator = Stage3BossSkillUpdateCoordinator.new(
		STAGE_ID,
		_scheduler,
		_handoff_coordinator,
		_tear_shower_state,
		_curse_chest_state,
		_psychoball_state,
		_tail_whip_state,
		_kuromi_awakening_state,
		_kuromi_eating_state,
		_prism_burst_state,
		_starpoint_state
	)


func reset() -> void:
	_lifecycle.reset_full(self)


func reset_round() -> void:
	_lifecycle.reset_round(self, _get_red_target())


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	return _update_coordinator.update(self, delta, context, deps, _get_red_target())


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return {}
	var triggered := false
	if _psychoball_state.can_trigger(context, kuromi_awakening):
		if BossSkillParryGate.try_parry("psychoball", "염동폭주", context, deps):
			_psychoball_state.consume_parried()
			boss_special_ready = false
			boss_special_gauge = 0.0
			boss_red_intensity = 0.0
		else:
			_activate_overdrive(context, deps)
		triggered = true
	return {
		"stage3_boss_gauge": boss_special_gauge,
		"stage3_boss_gauge_gain": BOSS_GAUGE_GAIN_ON_HIT,
		"stage3_psychoball_hit_triggered": triggered,
	}


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if scoring_side != "player":
		return
	_kuromi_awakening_state.maybe_start(int(score_result.get("player_score", 0)), deps)


func is_kuromi_awakening_active() -> bool:
	return _kuromi_awakening_state.is_active()


func is_kuromi_ball_hidden() -> bool:
	return _kuromi_eating_state.is_ball_hidden()


func force_kuromi_awake() -> void:
	_kuromi_awakening_state.force_awake()


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return _hud_state_builder.build_context(
		status,
		boss_special_gauge,
		BOSS_GAUGE_MAX,
		_tear_shower_state,
		_curse_chest_state,
		_psychoball_state
	)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return _context_builder.build_actor_draw_context(
		boss_special_gauge,
		boss_special_ready,
		boss_red_intensity,
		copy_arrays
	)


func get_boss_ai_context() -> Dictionary:
	return {
		"stage3_yeonmyo_stationary_cast_active": (
			_tear_shower_state.is_cast_active()
			or _curse_chest_state.is_throw_animation_active()
		),
	}


func get_boss_gauge_progress() -> float:
	return clamp(boss_special_gauge / BOSS_GAUGE_MAX, 0.0, 1.0)


func is_curse_reverse_active() -> bool:
	return _curse_chest_state.is_reverse_active()


func is_psychoball_hitstop_active() -> bool:
	return _psychoball_state.is_hitstop_active()


func get_snapshot() -> Dictionary:
	return _context_builder.build_snapshot(
		status,
		boss_special_gauge,
		boss_special_ready,
		boss_red_intensity
	)


func _get_red_target() -> float:
	return 0.0


func _activate_overdrive(context: Dictionary, deps: Dictionary) -> void:
	_psychoball_state.activate(context)
	boss_special_ready = false
	boss_special_gauge = 0.0
	boss_red_intensity = 0.0
	_psychoball_state.emit_activation_feedback(deps)
