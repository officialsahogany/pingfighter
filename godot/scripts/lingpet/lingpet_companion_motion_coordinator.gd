extends RefCounted

const LingpetRingDashState := preload("res://scripts/lingpet/lingpet_ring_dash_state.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")

var _current_profile: Object = null
var _active_skill_slot_resolver: Object = null
var _skill_visual_resolver: Object = null
var _skill_runtime_host: Object = null
var _skill_runtime_surface: Object = null
var _mount_state: Object = null
var _motion_state: Object = null
var _click_reaction_state: Object = null
var _ring_dash_state: Object = null
var _ring_dash_vfx: Object = null
var _starlight_tracking_state: Object = null
var _profile_runtime_surface: Object = null
var _skill_persistence: Object = null
var _skill_states: Array = []
var _debug_stat_overrides: Object = null
var _sprite_animator: Object = null
var _audio_dispatcher: Object = null
var _player_runtime_resolver: Object = null
var _runtime_facade_ref: WeakRef = null
var _hit_half_width := 0.0
var _hit_half_height := 0.0
var _defense_rate_default := 0.0
var _patrol_speed_default := 0.0
var _patrol_speed_min := 0.0
var _patrol_speed_max := 0.0
var _position := Vector2.ZERO
var _facing_left := false


func configure(
	current_profile: Object,
	active_skill_slot_resolver: Object,
	skill_visual_resolver: Object,
	skill_runtime_host: Object,
	skill_runtime_surface: Object,
	mount_state: Object,
	motion_state: Object,
	click_reaction_state: Object,
	ring_dash_state: Object,
	ring_dash_vfx: Object,
	starlight_tracking_state: Object,
	profile_runtime_surface: Object,
	skill_persistence: Object,
	skill_states: Array,
	debug_stat_overrides: Object,
	sprite_animator: Object,
	audio_dispatcher: Object,
	player_runtime_resolver: Object,
	runtime_facade: Object,
	hit_half_width: float,
	hit_half_height: float,
	defense_rate_default: float,
	patrol_speed_default: float,
	patrol_speed_min: float,
	patrol_speed_max: float
) -> void:
	_current_profile = current_profile
	_active_skill_slot_resolver = active_skill_slot_resolver
	_skill_visual_resolver = skill_visual_resolver
	_skill_runtime_host = skill_runtime_host
	_skill_runtime_surface = skill_runtime_surface
	_mount_state = mount_state
	_motion_state = motion_state
	_click_reaction_state = click_reaction_state
	_ring_dash_state = ring_dash_state
	_ring_dash_vfx = ring_dash_vfx
	_starlight_tracking_state = starlight_tracking_state
	_profile_runtime_surface = profile_runtime_surface
	_skill_persistence = skill_persistence
	_skill_states = skill_states
	_debug_stat_overrides = debug_stat_overrides
	_sprite_animator = sprite_animator
	_audio_dispatcher = audio_dispatcher
	_player_runtime_resolver = player_runtime_resolver
	_runtime_facade_ref = weakref(runtime_facade) if runtime_facade != null else null
	_hit_half_width = maxf(0.0, hit_half_width)
	_hit_half_height = maxf(0.0, hit_half_height)
	_defense_rate_default = clampf(defense_rate_default, 0.0, 1.0)
	_patrol_speed_default = maxf(0.0, patrol_speed_default)
	_patrol_speed_min = maxf(0.0, patrol_speed_min)
	_patrol_speed_max = maxf(_patrol_speed_min, patrol_speed_max)
	if _motion_state != null:
		_motion_state.pos = _position


func get_position() -> Vector2:
	return _position


func set_position(value: Vector2) -> void:
	_position = value
	if _motion_state != null:
		_motion_state.pos = value


func is_facing_left() -> bool:
	return _facing_left


func set_facing_left(value: bool) -> void:
	_facing_left = value


# body_presentation_incompatible(S3-a §C-3c)은 egg 가 "탑다운 모델 × 플레이어
# 본체 대체(오딘/뿔딸기 5조건)"를 곱해 만든 필수 인자다 — 기본값은 호출 누락을
# 조용히 숨기므로 두지 않는다(S2 fail-open 교훈). 판정은 egg, 철회 전이는
# mount_state 소유이고 이 코디네이터는 통과만 시킨다.
func update(
	delta: float,
	owner: Object,
	registry: Object,
	pet_id: String,
	companion_active: bool,
	body_presentation_incompatible: bool,
	topdown_mount_not_ready: bool
) -> void:
	if not _is_configured():
		return
	var previous_position := _position
	var skill_position_override: Dictionary = _skill_runtime_surface.get_active_position_owner(
		_current_profile,
		_active_skill_slot_resolver,
		_skill_visual_resolver,
		_skill_runtime_host,
		_position
	)
	var has_skill_position_override: bool = _skill_runtime_surface.has_active_position_override(
		_skill_visual_resolver,
		skill_position_override
	)
	var mount_permitted: bool = _mount_state.is_mount_permitted(
		pet_id,
		_skill_runtime_surface.get_active_skill_ids(
			_current_profile,
			_active_skill_slot_resolver,
			_skill_runtime_host
		)
	)
	var right_click_claimed := bool(
		_player_runtime_resolver.is_right_click_claimed_by_player_skill(
			owner,
			registry
		)
	)
	var mount_advance_result: Dictionary = _mount_state.advance(
		owner,
		_position,
		companion_active and not has_skill_position_override,
		right_click_claimed,
		delta,
		mount_permitted,
		body_presentation_incompatible,
		topdown_mount_not_ready
	)
	if bool(mount_advance_result.get("toggled", false)):
		_invalidate_runtime_snapshot()
	if _mount_state.has_companion_position_override() and not has_skill_position_override:
		_motion_state.clear_defense_intercept()
		_click_reaction_state.reset()
		_set_position_and_facing(
			_mount_state.get_companion_position_override(owner, _position),
			previous_position
		)
		return
	if has_skill_position_override:
		_ring_dash_state.reset_round_transients()
		_ring_dash_vfx.reset()
	else:
		var ring_dash_was_active: bool = _ring_dash_state.has_companion_position_override()
		var passive_skill: Dictionary = _profile_runtime_surface.get_passive_skill_by_id(
			_current_profile,
			LingpetRingDashState.PASSIVE_ID
		)
		var motion_style: String = _profile_runtime_surface.get_motion_style(_current_profile)
		var player_dash_state: Dictionary = (
			_player_runtime_resolver.resolve_player_dash_state(registry)
		)
		var player_guard_available := bool(
			_player_runtime_resolver.is_player_guard_available(registry)
		)
		var ring_dash_result: Dictionary = _ring_dash_state.advance(
			delta,
			owner,
			passive_skill,
			companion_active,
			_position,
			_profile_runtime_surface.get_catch_width(_current_profile, _hit_half_width * 2.0),
			_profile_runtime_surface.get_catch_height(_current_profile, _hit_half_height * 2.0),
			motion_style,
			player_dash_state,
			player_guard_available
		)
		if _ring_dash_state.has_companion_position_override():
			_set_position_and_facing(
				_ring_dash_state.get_companion_position_override(_position),
				previous_position
			)
			if bool(ring_dash_result.get("started", false)):
				_ring_dash_vfx.trigger(previous_position, _position)
				_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)
				_audio_dispatcher.play_lingpet_ring_dash(registry)
			return
		if ring_dash_was_active:
			if _motion_state.resume_sortie_loiter_from_current(
				owner,
				_skill_persistence.get_trigger_count(),
				_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", _patrol_speed_min),
				_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", _patrol_speed_max),
				motion_style
			):
				set_position(_motion_state.pos)
	if _starlight_tracking_state.has_companion_position_override() and not has_skill_position_override:
		_set_position_and_facing(
			_starlight_tracking_state.get_companion_position_override(_position),
			previous_position
		)
		return
	_motion_state.pos = _position
	_motion_state.update(
		delta,
		owner,
		_skill_persistence.is_any_winding_up(_skill_states) or not companion_active,
		_debug_stat_overrides.get_defense_rate(_current_profile, _defense_rate_default) if companion_active else 0.0,
		_skill_persistence.get_trigger_count(),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_default", _patrol_speed_default),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", _patrol_speed_min),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", _patrol_speed_max),
		_profile_runtime_surface.get_motion_style(_current_profile),
		_debug_stat_overrides.get_appearance_rate(_current_profile, 0.0),
		1.0,
		not companion_active
	)
	_set_position_and_facing(_motion_state.pos, previous_position)


func _set_position_and_facing(value: Vector2, previous_position: Vector2) -> void:
	set_position(value)
	_facing_left = _motion_state.resolve_facing_left_after_motion(
		previous_position,
		_position,
		_facing_left
	)


func _invalidate_runtime_snapshot() -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_invalidate_runtime_snapshot_cache"):
		runtime_facade.call("_invalidate_runtime_snapshot_cache")


func _get_runtime_facade() -> Object:
	if _runtime_facade_ref == null:
		return null
	var value: Variant = _runtime_facade_ref.get_ref()
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _is_configured() -> bool:
	return (
		_current_profile != null
		and _active_skill_slot_resolver != null
		and _skill_visual_resolver != null
		and _skill_runtime_host != null
		and _skill_runtime_surface != null
		and _mount_state != null
		and _motion_state != null
		and _click_reaction_state != null
		and _ring_dash_state != null
		and _ring_dash_vfx != null
		and _starlight_tracking_state != null
		and _profile_runtime_surface != null
		and _skill_persistence != null
		and _debug_stat_overrides != null
		and _sprite_animator != null
		and _audio_dispatcher != null
		and _player_runtime_resolver != null
	)
