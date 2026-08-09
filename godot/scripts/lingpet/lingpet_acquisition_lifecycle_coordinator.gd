extends RefCounted

const LingpetAcquireCutinState := preload(
	"res://scripts/lingpet/lingpet_acquire_cutin_state.gd"
)

const PENDING_KIND_REGULAR := "regular"
const PENDING_KIND_OVERFLOW := "overflow"
const HATCH_BREAK_BURST_HOLD_SECONDS := 0.45

var _acquire_cutin_state: Object = null
var _asset_prewarm_state: Object = null
var _overlay_host_resolver: Object = null
var _egg_state: Object = null
var _overflow_choice_state: Object = null
var _item_egg_lifecycle_state: Object = null
var _current_profile: Object = null
var _audio_dispatcher: Object = null
var _runtime_facade_ref: WeakRef = null
var _hatch_flash_seconds := 0.0
var _burst_hold_seconds := HATCH_BREAK_BURST_HOLD_SECONDS
var _pending_hatch_kind := ""
var _burst_hold_remaining := 0.0


func configure(
	acquire_cutin_state: Object,
	asset_prewarm_state: Object,
	overlay_host_resolver: Object,
	egg_state: Object,
	overflow_choice_state: Object,
	item_egg_lifecycle_state: Object,
	current_profile: Object,
	audio_dispatcher: Object,
	runtime_facade: Object,
	hatch_flash_seconds: float
) -> void:
	_acquire_cutin_state = acquire_cutin_state
	_asset_prewarm_state = asset_prewarm_state
	_overlay_host_resolver = overlay_host_resolver
	_egg_state = egg_state
	_overflow_choice_state = overflow_choice_state
	_item_egg_lifecycle_state = item_egg_lifecycle_state
	_current_profile = current_profile
	_audio_dispatcher = audio_dispatcher
	_runtime_facade_ref = weakref(runtime_facade) if runtime_facade != null else null
	_hatch_flash_seconds = maxf(0.0, hatch_flash_seconds)


func prewarm_registry_step(
	pet_id: String,
	registry: Object,
	perf_logger: Object = null,
	perf_label_prefix: String = ""
) -> bool:
	if _asset_prewarm_state == null:
		return true
	return bool(_asset_prewarm_state.prewarm_registry_step(
		pet_id,
		registry,
		_overlay_host_resolver,
		perf_logger,
		perf_label_prefix
	))


func start_acquire_cutin(display_pet_id: String, registry: Object) -> void:
	_acquire_cutin_state.start(display_pet_id)
	_audio_dispatcher.play_lingpet_acquire_cutin(registry)


func is_acquire_cutin_active() -> bool:
	return bool(_acquire_cutin_state.active)


func get_hatch_break_burst_hold() -> float:
	return _burst_hold_remaining


func is_hatch_break_active() -> bool:
	return bool(_egg_state.is_hatch_break_active()) or _burst_hold_remaining > 0.0


func begin_hatch_break(overflow: bool) -> void:
	_pending_hatch_kind = PENDING_KIND_OVERFLOW if overflow else PENDING_KIND_REGULAR
	_burst_hold_remaining = 0.0
	_egg_state.trigger_hatch_break()


func advance_hatch_break(
	delta: float,
	owner: Object,
	registry: Object,
	current_pet_id: String
) -> void:
	if not is_hatch_break_active():
		return
	# Continue the incremental heavy-sheet stream while the modal gate holds
	# physics, so the cut-in can enter directly on its animated asset.
	prewarm_registry_step(
		_acquire_cutin_state.get_display_pet_id(current_pet_id),
		registry
	)
	if _egg_state.is_hatch_break_active():
		if _egg_state.advance_hatch_break(delta):
			_egg_state.trigger_hatch_flash(_hatch_flash_seconds)
			_burst_hold_remaining = _burst_hold_seconds
			if _burst_hold_remaining <= 0.0:
				_commit_pending_hatch(owner, registry)
		return
	_egg_state.advance(delta)
	_burst_hold_remaining = maxf(
		0.0,
		_burst_hold_remaining - maxf(0.0, delta)
	)
	if _burst_hold_remaining <= 0.0:
		_commit_pending_hatch(owner, registry)


func reset_hatch_break_sequence() -> void:
	_pending_hatch_kind = ""
	_burst_hold_remaining = 0.0


func advance_acquire_cutin(
	delta: float,
	registry: Object,
	current_pet_id: String
) -> void:
	_invalidate_runtime_snapshot()
	var cutin_pet_id: String = str(
		_acquire_cutin_state.get_display_pet_id(current_pet_id)
	)
	var anim_ready := bool(
		_overlay_host_resolver.is_anim_ready(registry, cutin_pet_id)
	)
	if not anim_ready and registry != null:
		prewarm_registry_step(cutin_pet_id, registry)
	var was_active := bool(_acquire_cutin_state.active)
	_acquire_cutin_state.advance(delta, anim_ready)
	if was_active and not bool(_acquire_cutin_state.active):
		_overflow_choice_state.resolve_after_acquire_cutin(
			_item_egg_lifecycle_state
		)


func get_acquire_cutin_progress() -> float:
	return float(_acquire_cutin_state.get_progress())


func is_acquire_cutin_awaiting_dismiss() -> bool:
	return bool(_acquire_cutin_state.is_awaiting_dismiss())


func begin_acquire_cutin_dismiss(
	registry: Object,
	current_pet_id: String
) -> bool:
	var cutin_pet_id: String = str(
		_acquire_cutin_state.get_display_pet_id(current_pet_id)
	)
	var cutin_profile: Object = (
		_item_egg_lifecycle_state.get_profile()
		if _acquire_cutin_state.has_display_override()
		else _current_profile
	)
	var dismiss_seconds := maxf(
		0.1,
		float(cutin_profile.get_visual_layout_value(
			"cutin_dismiss_seconds",
			LingpetAcquireCutinState.DISMISS_SECONDS
		))
	)
	if not _acquire_cutin_state.begin_dismiss(dismiss_seconds):
		return false
	_invalidate_runtime_snapshot()
	_audio_dispatcher.play_lingpet_acquire_click_reaction_backing(registry)
	_audio_dispatcher.play_lingpet_click_reaction(registry, cutin_pet_id)
	return true


func is_acquire_cutin_dismissing() -> bool:
	return bool(_acquire_cutin_state.is_dismissing())


func get_acquire_cutin_dismiss_progress() -> float:
	return float(_acquire_cutin_state.get_dismiss_progress())


func dismiss_acquire_cutin() -> bool:
	var dismissed := bool(_acquire_cutin_state.dismiss_immediate())
	if dismissed:
		_invalidate_runtime_snapshot()
		_overflow_choice_state.resolve_after_acquire_cutin(
			_item_egg_lifecycle_state
		)
	return dismissed


func _commit_pending_hatch(owner: Object, registry: Object) -> void:
	var pending_kind := _pending_hatch_kind
	var commit_method := ""
	if pending_kind == PENDING_KIND_OVERFLOW:
		commit_method = "_begin_overflow_hatch"
	elif pending_kind == PENDING_KIND_REGULAR:
		commit_method = "_finish_regular_hatch"
	else:
		_pending_hatch_kind = ""
		_burst_hold_remaining = 0.0
		return
	var runtime_facade := _get_runtime_facade()
	if runtime_facade == null or not runtime_facade.has_method(commit_method):
		return
	_pending_hatch_kind = ""
	_burst_hold_remaining = 0.0
	runtime_facade.call(commit_method, owner, registry)
	# The normal update path stays gated for the upcoming cut-in, so publish the
	# committed companion state immediately from this ungated lifecycle pump.
	if owner != null and runtime_facade.has_method("_sync_owner"):
		runtime_facade.call("_sync_owner", owner, registry)


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
