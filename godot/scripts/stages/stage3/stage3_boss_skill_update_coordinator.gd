extends RefCounted

## Owns the Stage 3 boss-skill frame order. Focused owners retain their clocks,
## payloads, and state; this coordinator preserves when each owner advances,
## the Psychoball hitstop short circuit, cross-owner handoffs, and stage-leave
## cleanup without owning rendering or a persistent reference to the host.

var _stage_id: int
var _scheduler: Object
var _handoff_coordinator: Object
var _tear_shower_state: Object
var _curse_chest_state: Object
var _psychoball_state: Object
var _tail_whip_state: Object
var _kuromi_awakening_state: Object
var _kuromi_eating_state: Object
var _prism_burst_state: Object
var _starpoint_state: Object


func _init(
	stage_id: int,
	scheduler: Object,
	handoff_coordinator: Object,
	tear_shower_state: Object,
	curse_chest_state: Object,
	psychoball_state: Object,
	tail_whip_state: Object,
	kuromi_awakening_state: Object,
	kuromi_eating_state: Object,
	prism_burst_state: Object,
	starpoint_state: Object
) -> void:
	_stage_id = stage_id
	_scheduler = scheduler
	_handoff_coordinator = handoff_coordinator
	_tear_shower_state = tear_shower_state
	_curse_chest_state = curse_chest_state
	_psychoball_state = psychoball_state
	_tail_whip_state = tail_whip_state
	_kuromi_awakening_state = kuromi_awakening_state
	_kuromi_eating_state = kuromi_eating_state
	_prism_burst_state = prism_burst_state
	_starpoint_state = starpoint_state


func update(host: Object, delta: float, context: Dictionary, deps: Dictionary, red_target: float) -> Dictionary:
	if int(context.get("current_stage", _stage_id)) != _stage_id:
		var had_starpoints: bool = bool(_starpoint_state.has_runtime_state())
		host.reset()
		if had_starpoints:
			_starpoint_state.hide_all_existing_visual_hosts()
		return {}

	var result: Dictionary = {}
	var clamped_delta := clampf(delta, 0.0, 0.05)
	if bool(context.get("stage3_kuromi_awakened", false)) or bool(context.get("enraged_boss_active", false)):
		_kuromi_awakening_state.force_awake()
	_kuromi_awakening_state.maybe_start(int(context.get("player_score", 0)), deps)
	_kuromi_awakening_state.update(clamped_delta, deps)
	_tail_whip_state.update_bursts(clamped_delta)
	_starpoint_state.update(clamped_delta * 60.0, context, deps)
	if _psychoball_state.is_hitstop_active():
		_psychoball_state.update_hitstop(clamped_delta)
		_psychoball_state.update_neutralize_particles(clamped_delta)
		_psychoball_state.sync_audio(deps)
		host.status = _resolve_status(false)
		return result

	var boss_skill_cooldown_paused: bool = _scheduler.is_cooldown_paused(context)
	if not boss_skill_cooldown_paused:
		_scheduler.update_cooldowns(
			clamped_delta,
			bool(_kuromi_awakening_state.kuromi_awakened),
			bool(_psychoball_state.overdrive_active),
			_psychoball_state,
			_tear_shower_state,
			_curse_chest_state,
			_tail_whip_state,
			_kuromi_eating_state
		)
	_update_red_intensity(host, clamped_delta, red_target)
	_tear_shower_state.update(clamped_delta, context, deps)
	_curse_chest_state.update(clamped_delta, context, deps)
	_update_kuromi(clamped_delta, context, deps, result)
	var tail_hit_event: Dictionary = _tail_whip_state.update(
		clamped_delta,
		context,
		result,
		Time.get_ticks_msec()
	)
	_handoff_coordinator.apply_tail_hit_event(tail_hit_event, deps, context)
	_psychoball_state.update(clamped_delta, context, deps, result)
	_psychoball_state.update_neutralize_particles(clamped_delta)
	_prism_burst_state.update(clamped_delta)
	if not boss_skill_cooldown_paused:
		_scheduler.try_activate_skills(
			context,
			deps,
			bool(_kuromi_awakening_state.kuromi_awakening),
			bool(_kuromi_awakening_state.kuromi_awakened),
			bool(_psychoball_state.overdrive_active),
			_tear_shower_state,
			_curse_chest_state,
			_tail_whip_state
		)
	_psychoball_state.sync_audio(deps)
	host.status = _resolve_status(boss_skill_cooldown_paused)
	return result


func _update_red_intensity(host: Object, delta: float, red_target: float) -> void:
	var lerp_ratio := minf(1.0, delta * 6.0)
	host.boss_red_intensity = lerpf(float(host.boss_red_intensity), red_target, lerp_ratio)


func _update_kuromi(delta: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	_kuromi_eating_state.update(
		delta,
		context,
		deps,
		result,
		not bool(_kuromi_awakening_state.kuromi_petrified)
			and not bool(_kuromi_awakening_state.kuromi_awakening)
			and bool(_kuromi_awakening_state.kuromi_awakened)
			and not bool(_psychoball_state.overdrive_active)
	)
	_handoff_coordinator.consume_kuromi_prism_request()


func _resolve_status(cooldown_paused: bool) -> String:
	return _scheduler.resolve_status(
		cooldown_paused,
		bool(_kuromi_awakening_state.kuromi_awakening),
		bool(_kuromi_eating_state.kuromi_eating_active),
		bool(_psychoball_state.overdrive_active),
		bool(_tail_whip_state.tail_whip_active),
		str(_curse_chest_state.curse_phase),
		bool(_tear_shower_state.tears_active)
	)
