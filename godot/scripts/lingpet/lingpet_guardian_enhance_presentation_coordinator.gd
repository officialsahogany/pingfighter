extends RefCounted

const LingpetAcquireCutinAssetPrewarmState := preload(
	"res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd"
)
const LingpetGuardianEnhanceCutinState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)
const LingpetGuardianEnhanceCutinOverlayHostResolver := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_overlay_host_resolver.gd"
)
const RESULT_TAIL_DELAY_SECONDS := 0.12

var _offer_engine: Object = null
var _cutin_state: Object = LingpetGuardianEnhanceCutinState.new()
var _prewarm_state: Object = LingpetAcquireCutinAssetPrewarmState.new()
var _host_resolver: Object = LingpetGuardianEnhanceCutinOverlayHostResolver.new()
var _modal_owner_ref: WeakRef = null
var _modal_registry_ref: WeakRef = null
var _last_result: Dictionary = {}
var _audio_roll_started := false
var _audio_stamp_played := false
var _audio_result_tail_played := false


func configure(offer_engine: Object) -> void:
	_offer_engine = offer_engine


func build_display_candidate_icons(
	candidates: Array,
	result: Dictionary,
	registry: Object
) -> Array[String]:
	var display_icons: Array[String] = []
	var applied_index := int(result.get("applied_index", -1))
	var result_detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var result_icon_path := str(result_detail.get("icon_texture_path", "")).strip_edges()
	for candidate_index in range(candidates.size()):
		if display_icons.size() >= 8:
			break
		var value: Variant = candidates[candidate_index]
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value as Dictionary
		var icon_path := str(candidate.get("icon_texture_path", "")).strip_edges()
		if candidate_index == applied_index and result_icon_path != "":
			icon_path = result_icon_path
		if icon_path == "":
			# Stat, duration, and unlock candidates deliberately use the host's
			# procedural neutral glyph instead of triggering a runtime file lookup.
			display_icons.append("")
			continue
		if _host_resolver.has_cached_result_icon(registry, icon_path):
			display_icons.append(icon_path)
	return display_icons


func complete_roll(
	result: Dictionary,
	display_pet_id: String,
	current_pet_id: String,
	registry: Object = null,
	trigger_source: String = "perk",
	owner: Object = null
) -> void:
	var resolved_pet_id := display_pet_id.strip_edges()
	if resolved_pet_id == "":
		resolved_pet_id = current_pet_id
	var normalized_source := trigger_source.strip_edges().to_lower()
	if normalized_source == "":
		normalized_source = "perk"
	result["trigger_source"] = normalized_source
	result["trigger_source_label"] = _resolve_trigger_source_label(normalized_source)
	_last_result = result.duplicate(true)
	if not bool(result.get("accepted", false)):
		return
	if normalized_source == "perk" and _offer_engine != null:
		_offer_engine.mark_applied()
	_prewarm_state.reset()
	_host_resolver.prewarm_result_icon(registry, result)
	_prewarm_state.prewarm_registry_step(
		resolved_pet_id,
		registry,
		_host_resolver
	)
	_reset_audio_phase_state()
	if _cutin_state.start(resolved_pet_id, result):
		_begin_modal_time(owner, registry)


func is_active() -> bool:
	return bool(_cutin_state.active)


func get_snapshot() -> Dictionary:
	return _cutin_state.get_snapshot()


func advance(delta: float, registry: Object, current_pet_id: String) -> void:
	if not is_active():
		return
	var before_snapshot: Dictionary = _cutin_state.get_snapshot()
	var display_pet_id := str(before_snapshot.get("pet_id", current_pet_id))
	_prewarm_state.prewarm_registry_step(
		display_pet_id,
		registry,
		_host_resolver
	)
	var assets_ready := bool(_host_resolver.is_anim_ready(registry, display_pet_id))
	var animation_contract: Dictionary = _host_resolver.get_animation_contract(
		registry,
		display_pet_id
	)
	var closed := bool(_cutin_state.advance(delta, assets_ready, animation_contract))
	var after_snapshot: Dictionary = _cutin_state.get_snapshot()
	_sync_phase_audio(before_snapshot, after_snapshot, delta, closed, registry)
	if closed:
		_stop_audio(registry)
		_reset_audio_phase_state()
		_finish_modal_time(registry)


func cancel(registry: Object = null) -> bool:
	var cleanup_registry := registry
	if cleanup_registry == null:
		cleanup_registry = _resolve_weak_ref(_modal_registry_ref)
	var had_modal_context := _modal_owner_ref != null or _modal_registry_ref != null
	var cancelled := bool(_cutin_state.cancel_immediate())
	if cancelled or had_modal_context:
		_stop_audio(cleanup_registry)
		_reset_audio_phase_state()
		_finish_modal_time(cleanup_registry)
	return cancelled


func reset_for_tests() -> void:
	reset_presentation_state()
	if _offer_engine != null and _offer_engine.has_method("reset"):
		_offer_engine.reset()
	_last_result.clear()


func reset_presentation_state() -> void:
	cancel(_resolve_weak_ref(_modal_registry_ref))
	_cutin_state.reset()
	_prewarm_state.reset()
	_reset_audio_phase_state()


func get_last_result_for_tests() -> Dictionary:
	return _last_result.duplicate(true)


func _resolve_trigger_source_label(trigger_source: String) -> String:
	if _offer_engine != null and _offer_engine.has_method("get_trigger_source_label"):
		return str(_offer_engine.get_trigger_source_label(trigger_source))
	return trigger_source


func _begin_modal_time(owner: Object, registry: Object) -> void:
	_modal_owner_ref = weakref(owner) if owner != null else null
	_modal_registry_ref = weakref(registry) if registry != null else null
	var runtime_perk_state := _get_runtime_perk_state(registry)
	if (
		runtime_perk_state != null
		and runtime_perk_state.has_method("_pause_skill_cooldowns_for_choice")
	):
		runtime_perk_state.call("_pause_skill_cooldowns_for_choice", owner, registry)


func _finish_modal_time(registry: Object = null) -> void:
	var modal_owner: Object = _resolve_weak_ref(_modal_owner_ref)
	var modal_registry: Object = registry
	if modal_registry == null:
		modal_registry = _resolve_weak_ref(_modal_registry_ref)
	_modal_owner_ref = null
	_modal_registry_ref = null
	var runtime_perk_state := _get_runtime_perk_state(modal_registry)
	if runtime_perk_state == null:
		return
	if runtime_perk_state.has_method("_resume_skill_cooldowns_for_choice"):
		runtime_perk_state.call("_resume_skill_cooldowns_for_choice")
	if runtime_perk_state.has_method("_try_arm_resume_safety"):
		runtime_perk_state.call("_try_arm_resume_safety", modal_owner, modal_registry)


static func _resolve_weak_ref(reference: WeakRef) -> Object:
	if reference == null:
		return null
	var value: Variant = reference.get_ref()
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


static func _get_runtime_perk_state(registry: Object) -> Object:
	if registry == null:
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.get_cached_instance("runtime_perk_state")
	if (typeof(value) != TYPE_OBJECT or value == null) and registry.has_method("get_instance"):
		value = registry.get_instance("runtime_perk_state")
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _sync_phase_audio(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	delta: float,
	closed: bool,
	registry: Object
) -> void:
	var before_phase := str(before_snapshot.get("phase", ""))
	var after_phase := str(after_snapshot.get("phase", ""))
	var before_rank := _phase_rank(before_phase)
	var after_rank := 5 if closed else _phase_rank(after_phase)
	if not _audio_roll_started and before_rank < 1 and after_rank >= 1:
		_call_audio(registry, "play_lingpet_guardian_enhance_roll_loop")
		_audio_roll_started = true
	if not _audio_stamp_played and after_rank >= 2:
		_call_audio(registry, "stop_lingpet_guardian_enhance_roll_loop")
		_call_audio(registry, "play_lingpet_guardian_enhance_stamp")
		_audio_stamp_played = true
	var crossed_tail_delay := after_rank > 2
	if after_rank == 2:
		crossed_tail_delay = float(after_snapshot.get("phase_elapsed", 0.0)) >= RESULT_TAIL_DELAY_SECONDS
	if before_rank == 2:
		var before_elapsed := float(before_snapshot.get("phase_elapsed", 0.0))
		crossed_tail_delay = crossed_tail_delay or (
			before_elapsed < RESULT_TAIL_DELAY_SECONDS
			and before_elapsed + maxf(0.0, delta) >= RESULT_TAIL_DELAY_SECONDS
		)
	if not _audio_result_tail_played and crossed_tail_delay:
		_call_audio(registry, "play_lingpet_guardian_enhance_result_tail")
		_audio_result_tail_played = true


func _reset_audio_phase_state() -> void:
	_audio_roll_started = false
	_audio_stamp_played = false
	_audio_result_tail_played = false


static func _phase_rank(phase: String) -> int:
	match phase:
		LingpetGuardianEnhanceCutinState.PHASE_INTRO:
			return 0
		LingpetGuardianEnhanceCutinState.PHASE_ROLL:
			return 1
		LingpetGuardianEnhanceCutinState.PHASE_STAMP:
			return 2
		LingpetGuardianEnhanceCutinState.PHASE_REACTION:
			return 3
		LingpetGuardianEnhanceCutinState.PHASE_OUTRO:
			return 4
	return -1


static func _get_audio(registry: Object) -> Object:
	if registry == null:
		return null
	var audio: Variant = null
	if registry.has_method("get_cached_instance"):
		audio = registry.get_cached_instance("game_audio")
	if (typeof(audio) != TYPE_OBJECT or audio == null) and registry.has_method("get_instance"):
		audio = registry.get_instance("game_audio")
	if typeof(audio) == TYPE_OBJECT and audio != null and is_instance_valid(audio):
		return audio as Object
	return null


static func _call_audio(registry: Object, method_name: String) -> void:
	var audio := _get_audio(registry)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


static func _stop_audio(registry: Object) -> void:
	_call_audio(registry, "stop_lingpet_guardian_enhance_cutin_loop")
