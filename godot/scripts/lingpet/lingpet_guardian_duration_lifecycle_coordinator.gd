extends RefCounted

var _guardian_run_state: Object = null
var _duration_runtime_state: Object = null
var _guardian_transition_state: Object = null
var _collection_state: Object = null
var _current_profile: Object = null
var _profile_runtime_surface: Object = null
var _spirit_water_drop_state: Object = null
var _audio_dispatcher: Object = null
var _ghost_blink_vfx: Object = null
var _vector_resolver: Object = null
var _skill_persistence: Object = null
var _skill_states: Array = []
var _skill_runtime_host: Object = null
var _afterglow_leak_state: Object = null
var _starlight_tracking_state: Object = null
var _ring_dash_state: Object = null
var _ring_dash_vfx: Object = null
var _mount_state: Object = null
var _companion_motion_state: Object = null
var _companion_body_hit_state: Object = null
var _companion_sprite_animator: Object = null
var _companion_click_reaction_state: Object = null
var _guard_feedback_state: Object = null
var _runtime_facade_ref: WeakRef = null
var _minimum_summon_seconds := 0.0
var _warning_stage_count := 1
var _stowed := false
var _active_elapsed := 0.0
var _warning_stage := 0
var _duration_roll_rng_for_tests: RandomNumberGenerator = null


func configure(
	guardian_run_state: Object,
	duration_runtime_state: Object,
	guardian_transition_state: Object,
	collection_state: Object,
	current_profile: Object,
	profile_runtime_surface: Object,
	spirit_water_drop_state: Object,
	audio_dispatcher: Object,
	ghost_blink_vfx: Object,
	vector_resolver: Object,
	skill_persistence: Object,
	skill_states: Array,
	skill_runtime_host: Object,
	afterglow_leak_state: Object,
	starlight_tracking_state: Object,
	ring_dash_state: Object,
	ring_dash_vfx: Object,
	mount_state: Object,
	companion_motion_state: Object,
	companion_body_hit_state: Object,
	companion_sprite_animator: Object,
	companion_click_reaction_state: Object,
	guard_feedback_state: Object,
	runtime_facade: Object,
	minimum_summon_seconds: float,
	warning_stage_count: int
) -> void:
	_guardian_run_state = guardian_run_state
	_duration_runtime_state = duration_runtime_state
	_guardian_transition_state = guardian_transition_state
	_collection_state = collection_state
	_current_profile = current_profile
	_profile_runtime_surface = profile_runtime_surface
	_spirit_water_drop_state = spirit_water_drop_state
	_audio_dispatcher = audio_dispatcher
	_ghost_blink_vfx = ghost_blink_vfx
	_vector_resolver = vector_resolver
	_skill_persistence = skill_persistence
	_skill_states = skill_states
	_skill_runtime_host = skill_runtime_host
	_afterglow_leak_state = afterglow_leak_state
	_starlight_tracking_state = starlight_tracking_state
	_ring_dash_state = ring_dash_state
	_ring_dash_vfx = ring_dash_vfx
	_mount_state = mount_state
	_companion_motion_state = companion_motion_state
	_companion_body_hit_state = companion_body_hit_state
	_companion_sprite_animator = companion_sprite_animator
	_companion_click_reaction_state = companion_click_reaction_state
	_guard_feedback_state = guard_feedback_state
	_runtime_facade_ref = weakref(runtime_facade) if runtime_facade != null else null
	_minimum_summon_seconds = maxf(0.0, minimum_summon_seconds)
	_warning_stage_count = maxi(1, warning_stage_count)


func is_stowed_state() -> bool:
	return _stowed


func set_stowed_state(value: bool) -> void:
	_stowed = value


func get_active_elapsed() -> float:
	return _active_elapsed


func set_active_elapsed(value: float) -> void:
	_active_elapsed = maxf(0.0, value)


func get_warning_stage_state() -> int:
	return _warning_stage


func set_warning_stage_state(value: int) -> void:
	_warning_stage = clampi(value, 0, _warning_stage_count)


func get_duration_roll_rng_for_tests() -> RandomNumberGenerator:
	return _duration_roll_rng_for_tests


func set_duration_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_duration_roll_rng_for_tests = rng


func refill_for_stage_transition() -> bool:
	# Fixed order: refill first, then rearm. The full-pool eligibility gate keeps
	# Spirit Water out of the candidate pool until duration is spent again.
	var changed := bool(_guardian_run_state.refill_duration_pool_for_stage_transition())
	_spirit_water_drop_state.rearm_for_stage_transition()
	_warning_stage = 0
	if changed:
		_invalidate_runtime_snapshot()
	return changed


func is_stowed(runtime_state: String, companion_state: String) -> bool:
	return runtime_state == companion_state and _stowed


func is_summoned(runtime_state: String, companion_state: String) -> bool:
	return runtime_state == companion_state and not _stowed


func get_toggle_slot_state(
	runtime_state: String,
	companion_state: String,
	pet_id: String
) -> Dictionary:
	var has_guardian := runtime_state == companion_state and pet_id.strip_edges() != ""
	if not has_guardian:
		return {
			"ready": false,
			"cooldown_ratio": 0.0,
			"guardian_stowed": false,
			"transition_active": false,
		}
	var recovery_ratio := float(
		_guardian_run_state.get_duration_resummon_cooldown_ratio()
	)
	var transition_active := bool(_guardian_transition_state.is_active())
	if transition_active:
		var transition_remaining := 1.0 - float(_guardian_transition_state.get_progress())
		return {
			"ready": false,
			"cooldown_ratio": maxf(recovery_ratio, transition_remaining),
			"guardian_stowed": _stowed,
			"transition_active": true,
		}
	if _stowed:
		var can_resummon := bool(_guardian_run_state.can_resummon_guardian())
		return {
			"ready": can_resummon,
			"cooldown_ratio": 0.0 if can_resummon else recovery_ratio,
			"guardian_stowed": true,
			"transition_active": false,
		}
	var summon_hold_ratio := 0.0
	if _minimum_summon_seconds > 0.0 and _active_elapsed < _minimum_summon_seconds:
		summon_hold_ratio = clampf(
			1.0 - _active_elapsed / _minimum_summon_seconds,
			0.0,
			1.0
		)
	return {
		"ready": summon_hold_ratio <= 0.0,
		"cooldown_ratio": summon_hold_ratio,
		"guardian_stowed": false,
		"transition_active": false,
	}


func try_toggle(
	runtime_state: String,
	companion_state: String,
	pet_id: String,
	owner: Object,
	registry: Object
) -> bool:
	if runtime_state != companion_state or pet_id.strip_edges() == "":
		return false
	var slot_state := get_toggle_slot_state(runtime_state, companion_state, pet_id)
	# Consume the dedicated edge while the shared HUD/input predicate is closed,
	# so key repeat cannot leak through or reverse an in-flight transition.
	if not bool(slot_state.get("ready", false)):
		return true
	if _stowed:
		set_stowed(runtime_state, companion_state, false, owner, registry)
		return true
	set_stowed(runtime_state, companion_state, true, owner, registry)
	return true


func advance(
	delta: float,
	owner: Object,
	registry: Object,
	runtime_state: String,
	companion_state: String,
	pet_id: String
) -> void:
	if runtime_state != companion_state:
		_duration_runtime_state.advance_inactive(_guardian_run_state)
		return
	var draining := is_duration_draining(runtime_state, companion_state)
	if draining:
		_active_elapsed += maxf(0.0, delta)
	_duration_runtime_state.latch_drain_exempt(
		owner,
		_collection_state,
		_guardian_run_state
	)
	var result: Dictionary = _duration_runtime_state.advance_duration(
		delta,
		_guardian_run_state,
		owner,
		_collection_state,
		_profile_runtime_surface.get_passive_skills(_current_profile),
		draining
	)
	if bool(result.get("expired", false)):
		set_stowed(
			runtime_state,
			companion_state,
			true,
			owner,
			registry,
			true,
			pet_id == "nekuring"
		)
	var next_warning_stage := get_duration_warning_stage()
	if next_warning_stage > _warning_stage:
		_audio_dispatcher.play_lingpet_duration_warning(registry, next_warning_stage)
	_warning_stage = next_warning_stage
	if bool(result.get("changed", false)):
		_invalidate_runtime_snapshot()


func get_active_duration_pct(runtime_state: String, companion_state: String) -> int:
	return _duration_runtime_state.get_active_duration_pct(
		runtime_state == companion_state,
		_guardian_run_state
	)


func ensure_duration_pool_roll() -> Dictionary:
	return _guardian_run_state.ensure_duration_pool_roll(_duration_roll_rng_for_tests)


func refill_for_guardian_replacement() -> Dictionary:
	var result: Dictionary = (
		_guardian_run_state.restore_duration_pool_to_full_preserving_overfill()
	)
	_warning_stage = 0
	return result


func set_duration_pool_for_tests(current: float, maximum: float = 0.0) -> void:
	_guardian_run_state.set_duration_pool_for_tests(current, maximum)
	_stowed = current <= 0.0
	_warning_stage = get_duration_warning_stage()
	_invalidate_runtime_snapshot()


func set_stowed(
	runtime_state: String,
	companion_state: String,
	stowed: bool,
	owner: Object,
	registry: Object,
	forced: bool = false,
	preserve_nekuring_deployments: bool = false
) -> bool:
	if forced:
		var interrupted_transition := bool(_guardian_transition_state.is_active())
		_guardian_transition_state.reset()
		if _stowed == stowed:
			return interrupted_transition
		_stowed = stowed
		_active_elapsed = 0.0
		if stowed:
			end_runtime_for_stow(owner, registry, preserve_nekuring_deployments)
			_ghost_blink_vfx.trigger_vanish(_get_live_companion_position())
		else:
			_ghost_blink_vfx.trigger_appear(_get_live_companion_position())
		_invalidate_runtime_snapshot()
		_sync_runtime_owner(owner, registry)
		return true
	if (
		runtime_state != companion_state
		or _guardian_transition_state.is_active()
		or _stowed == stowed
	):
		return false
	if stowed and _active_elapsed < _minimum_summon_seconds:
		return false
	var companion_position := _get_live_companion_position()
	if stowed:
		_stowed = true
		_active_elapsed = 0.0
		end_runtime_for_stow(owner, registry)
		_guardian_transition_state.begin_stow(
			companion_position,
			_vector_resolver.get_owner_player_paddle_center(owner, companion_position)
		)
		_ghost_blink_vfx.trigger_vanish(companion_position)
		_audio_dispatcher.play_lingpet_guardian_stow_transition(registry)
	else:
		if companion_position == Vector2.ZERO:
			_initialize_companion_patrol(owner)
			companion_position = _get_live_companion_position()
		_active_elapsed = 0.0
		_guardian_transition_state.begin_summon(
			_vector_resolver.get_owner_player_paddle_center(owner, companion_position),
			companion_position
		)
		_audio_dispatcher.play_lingpet_guardian_summon_transition(registry)
	_invalidate_runtime_snapshot()
	_sync_runtime_owner(owner, registry)
	return true


func complete_summon_transition(
	runtime_state: String,
	companion_state: String,
	owner: Object,
	registry: Object
) -> void:
	if runtime_state != companion_state or not _stowed:
		return
	_stowed = false
	_ghost_blink_vfx.trigger_appear(_get_live_companion_position())
	_invalidate_runtime_snapshot()
	_sync_runtime_owner(owner, registry)


func is_duration_draining(runtime_state: String, companion_state: String) -> bool:
	return (
		is_summoned(runtime_state, companion_state)
		or _guardian_transition_state.is_summoning()
	)


func end_runtime_for_stow(
	owner: Object,
	registry: Object,
	preserve_nekuring_deployments: bool = false
) -> void:
	# Stop preparation without touching the preserved cooldown values.
	_skill_persistence.cancel_windups(_skill_states)
	# Every launched skill owns its projectile/residue, CC restoration, and loop
	# audio cancellation. The host intentionally does not own skill cooldowns.
	_skill_runtime_host.end_for_stow(owner, registry, preserve_nekuring_deployments)
	# Do not call broad companion resets here: they reset defense decision timers
	# and per-opportunity roll locks, enabling stow/resummon reroll farming.
	_afterglow_leak_state.reset_round_transients()
	_starlight_tracking_state.end_for_stow()
	_ring_dash_state.end_for_stow()
	_ring_dash_vfx.reset()
	_mount_state.reset()
	_companion_motion_state.clear_defense_intercept()
	_companion_body_hit_state.ball_was_inside = false
	_companion_body_hit_state.reset_round_transients()
	_companion_sprite_animator.reset_latch()
	_companion_click_reaction_state.reset()
	_guard_feedback_state.reset_transients()


func get_duration_warning_stage() -> int:
	var current := float(_guardian_run_state.get_duration_pool_current())
	if current <= 0.0 or current > 10.0:
		return 0 if current > 10.0 else _warning_stage_count
	var stage_width := 10.0 / float(_warning_stage_count)
	return clampi(
		_warning_stage_count - int(ceil(current / stage_width)) + 1,
		1,
		_warning_stage_count
	)


func _invalidate_runtime_snapshot() -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_invalidate_runtime_snapshot_cache"):
		runtime_facade.call("_invalidate_runtime_snapshot_cache")


func _sync_runtime_owner(owner: Object, registry: Object) -> void:
	var runtime_facade := _get_runtime_facade()
	if owner != null and runtime_facade != null and runtime_facade.has_method("_sync_owner"):
		runtime_facade.call("_sync_owner", owner, registry)


func _initialize_companion_patrol(owner: Object) -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_initialize_companion_patrol"):
		runtime_facade.call("_initialize_companion_patrol", owner, true)


func _get_live_companion_position() -> Vector2:
	var runtime_facade := _get_runtime_facade()
	if (
		runtime_facade == null
		or not runtime_facade.has_method("_get_companion_position_for_guardian_duration")
	):
		return Vector2.ZERO
	var value: Variant = runtime_facade.call("_get_companion_position_for_guardian_duration")
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _get_runtime_facade() -> Object:
	if _runtime_facade_ref == null:
		return null
	var value: Variant = _runtime_facade_ref.get_ref()
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null
