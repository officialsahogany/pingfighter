extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const LingpetAfterglowLeakState := preload("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
const LingpetRingDashState := preload("res://scripts/lingpet/lingpet_ring_dash_state.gd")
const LingpetRingDashVfx := preload("res://scripts/lingpet/lingpet_ring_dash_vfx.gd")
const LingpetGhostBlinkVfx := preload("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
const LingpetStarlightTrackingState := preload("res://scripts/lingpet/lingpet_starlight_tracking_state.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionClickReactionState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetAffinityFeedbackState := preload("res://scripts/lingpet/lingpet_affinity_feedback_state.gd")
const LingpetAffinityIncomeTracker := preload("res://scripts/lingpet/lingpet_affinity_income_tracker.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetCompanionSkillController := preload("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
const LingpetCompanionStrikeAnticipator := preload("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")
const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
const LingpetLoadoutState := preload("res://scripts/lingpet/lingpet_loadout_state.gd")
const LingpetRuntimeSnapshotBuilder := preload("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
const LingpetSaveRestorePlanner := preload("res://scripts/lingpet/lingpet_save_restore_planner.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
# Lingpet field/cutin/companion visuals are resolved through LingpetCurrentProfile,
# which routes every visual key through the catalog-backed visual texture cache.

const PET_ID := LingpetCurrentProfile.DEFAULT_PET_ID
const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const REQUIRED_HITS := 1
const BALL_RADIUS_FALLBACK := 14.3
const SAVE_SNAPSHOT_VERSION := 1
const COMPANION_RADIUS := 16.0
# Anticipatory strike helper mirrors player/boss _maybe_trigger_anticipated_hit:
# the swing is started BEFORE the ball arrives by predicting time-to-contact and
# choosing an entry frame so the spear-thrust APEX lands at contact -- exactly
# how the other characters' attack sheets fire. The sheet's first ~8 cells (0-7)
# are dead-air, the wind-up/coil is ~8-19, the thrust apex is ~22 (held 22-23),
# recovery ~24. A far ball enters near START_FRAME (full wind-up shown ahead of
# contact); a close ball enters deeper so the apex still lands on the ball. The
# real overlap bounce stays the gameplay trigger + a reactive fallback if the
# prediction missed. Tunables: FRAME_TIME (swing speed; higher = slower/weighty),
# START_FRAME (how much wind-up), MAX_GAP/X_TOLERANCE (how eagerly it predicts).
const COMPANION_PATROL_SPEED := 120.0
const COMPANION_PATROL_SPEED_MIN := 70.0
const COMPANION_PATROL_SPEED_MAX := 135.0
const COMPANION_DEFENSE_RATE := 0.30
# Paddle-like hit footprint: a wide axis-aligned box centered on the companion,
# so it catches the ball over a ~100px horizontal span like a mini player paddle
# (replacing the old 44px circle). Ball radius is added per-axis (paddle parity).
const COMPANION_HIT_HALF_WIDTH := 50.0   # -> ~100px wide catch footprint
const COMPANION_HIT_HALF_HEIGHT := 22.0  # vertical reach (≈ the old circle radius)
# Ball-hit reflection: launch toward the boss exactly like a player paddle.
# hit_pos (horizontal offset on the companion) maps to the launch angle via
# Vector2(0,-1).rotated(hit_pos * max_angle), matching MAX_BOUNCE_ANGLE so the
# physics is identical to a player paddle bounce. Speed preserves the incoming
# ball speed (paddle parity, no soft slowdown).
const COMPANION_HIT_GAUGE_GAIN := 40.0
const COMPANION_SKILL_COOLDOWN_SECONDS := 40.0
const COMPANION_SKILL_FLASH_SECONDS := 0.45
# Telegraphed spear-throw wind-up: when the skill arms, Maribo cocks the spear
# back for this long BEFORE the hydro projectile actually launches. The cooldown
# is set at LAUNCH (not arm), so the wind-up reads as a clear "about to throw"
# tell rather than eating into the displayed cooldown. Patrol freezes during it.
const COMPANION_SKILL_WINDUP_SECONDS := 1.0
const COMPANION_SKILL_BURST_PARTICLES := 8
const COMPANION_SWITCH_TRANSITION_SECONDS := 0.62
const COMPANION_SWITCH_TRANSITION_PARTICLES := 12
const COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO := 0.12
const CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC := 1800
const CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS := 240
# Click-reaction timing, hit zone, draw math, and prewarm keys live in
# LingpetCompanionClickReactionState. The runtime only exposes the public
# battle-input API and feeds the current pet texture into the state renderer.
# Fullscreen acquisition cut-in state lives in LingpetAcquireCutinState. The
# runtime keeps the public API because modal/input/draw controllers call it.
# The HUD host owns the artwork and restoration / exit-action rendering.

var _state := STATE_NONE
var _pet_id := PET_ID
var _egg_state: Object = LingpetEggFieldState.new()
var _egg_renderer: Object = LingpetEggFieldRenderer.new()
var _companion_pos := Vector2.ZERO
# Latched horizontal facing for the walk-sheet mirror. Normal motion updates it
# from actual horizontal travel (see _update_companion_motion), not raw patrol_dir:
# patrol_dir toggles during pauses / reverse-and-pause decisions, which made the
# held spear snap sides while Maribo stood still. First spawn/restore is seeded
# from patrol_dir because the zero-to-spawn placement jump is not real travel.
var _companion_facing_left := false
var _companion_motion_state: Object = LingpetCompanionMotionState.new()
var _hatch_flash_timer := 0.0
var _afterglow_leak_state: Object = LingpetAfterglowLeakState.new()
var _ring_dash_state: Object = LingpetRingDashState.new()
var _ring_dash_vfx: Object = LingpetRingDashVfx.new()
var _ghost_blink_vfx: Object = LingpetGhostBlinkVfx.new()
# Tracks the free-flight ghost's visibility across frames so a vanish/appear edge
# can fire the ghost blink "퐁" VFX once per transition.
var _prev_ghost_visible := true
var _starlight_tracking_state: Object = LingpetStarlightTrackingState.new()
var _companion_body_hit_state: Object = LingpetCompanionBodyHitState.new()
var _collection_state: Object = LingpetCollectionState.new()
var _current_profile: Object = LingpetCurrentProfile.new()
var _affinity_context_profile: Object = LingpetCurrentProfile.new()
# F7 debug-only defense-rate override. < 0 means "use the pet's catalog/profile
# value"; >= 0 forces that defense_rate for feel testing. Sticky across rounds so
# the override can be evaluated over a whole match; only the F7 picker writes it.
var _debug_defense_rate_override := -1.0
# F7 debug-only appearance-rate override (flight-style only). Same contract as the
# defense override: < 0 = use catalog/profile, >= 0 forces the value.
var _debug_appearance_rate_override := -1.0
var _companion_draw_context_builder: Object = LingpetCompanionDrawContextBuilder.new()
var _companion_renderer: Object = LingpetCompanionRenderer.new()
var _companion_sprite_animator: Object = LingpetCompanionSpriteAnimator.new()
var _companion_strike_anticipator: Object = LingpetCompanionStrikeAnticipator.new()
var _companion_skill_state: Object = LingpetCompanionSkillState.new()
var _companion_skill_controller: Object = LingpetCompanionSkillController.new()
var _skill_runtime_host: Object = LingpetSkillRuntimeHost.new()
var _snapshot_builder: Object = LingpetRuntimeSnapshotBuilder.new()
var _save_restore_planner: Object = LingpetSaveRestorePlanner.new()
var _acquire_cutin_state: Object = LingpetAcquireCutinState.new()
var _switch_transition_state: Object = LingpetCompanionSwitchState.new()
var _companion_click_reaction_state: Object = LingpetCompanionClickReactionState.new()
var _loadout_state: Object = LingpetLoadoutState.new()
var _affinity_state: Object = LingpetAffinityState.new()
var _affinity_feedback_state: Object = LingpetAffinityFeedbackState.new()
var _affinity_income_tracker: Object = LingpetAffinityIncomeTracker.new()
var _affinity_store_override: Object = null
var _affinity_headstart_applied_pet_ids: Dictionary = {}
var _affinity_reward_seeds_by_pet_id: Dictionary = {}
var _last_affinity_result: Dictionary = {}
var _last_affinity_bond_settlement: Dictionary = {}
var _companion_skill_state_by_pet_id: Dictionary = {}
var _has_synced_none := false
var _click_reaction_visual_prewarm_pet_id := ""
var _click_reaction_visual_prewarm_done_for := ""
var _acquire_cutin_assets_prewarm_done_for := ""
var _applied_loadout_key := ""
var _synced_owner_loadout_key := ""


# physics.callback.lingpet.update measured ~1.0ms/tick standing as an opaque
# leaf, so every phase below carries a physics.lingpet.* label — keep the
# label set gap-free or the standing cost hides between labels again.
func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	var perf_logger: Object = _get_perf_logger(registry)
	var sample_start: int = _perf_begin(perf_logger)
	_switch_transition_state.advance(delta)
	_egg_state.advance(delta)
	_companion_body_hit_state.advance(delta)
	_companion_skill_state.advance(delta)
	_advance_stored_companion_skill_cooldowns(delta)
	_hatch_flash_timer = maxf(0.0, _hatch_flash_timer - maxf(0.0, delta))
	_companion_sprite_animator.advance(delta)
	_companion_click_reaction_state.advance(delta)
	_affinity_feedback_state.advance(delta)
	_perf_end(perf_logger, "physics.lingpet.advance", sample_start)

	if _state == STATE_NONE:
		sample_start = _perf_begin(perf_logger)
		var none_changed: bool = _update_none_state(owner, registry)
		_perf_end(perf_logger, "physics.lingpet.none_state", sample_start)
		return none_changed

	if _state == STATE_EGG:
		sample_start = _perf_begin(perf_logger)
		_egg_state.update_player_contact(delta, owner)
		# Stream the heavy acquire cut-in sheets (8192px+ Live2D anim/dismiss) into the
		# texture cache across the calm egg-wait frames, BEFORE the egg hatches. The
		# reveal is only REVEAL_SECONDS (1.4s) long, so a cold draw-time stream cannot
		# always finish in time and the cut-in falls back to the static 원화 still. A
		# head start here lets the cut-in open already showing the Live2D animation.
		_prewarm_acquire_cutin_assets_step(registry)
		var changed: bool = _resolve_ball_hit(owner, registry)
		_sync_owner(owner, registry)
		_perf_end(perf_logger, "physics.lingpet.egg_phase", sample_start)
		return changed

	if _state == STATE_COMPANION:
		sample_start = _perf_begin(perf_logger)
		_prewarm_click_reaction_visual_step()
		_perf_end(perf_logger, "physics.lingpet.prewarm_step", sample_start)
		sample_start = _perf_begin(perf_logger)
		_starlight_tracking_state.advance(delta, _get_current_passive_skill(), _state == STATE_COMPANION, _companion_pos)
		_ring_dash_vfx.advance(delta)
		_ghost_blink_vfx.advance(delta)
		_perf_end(perf_logger, "physics.lingpet.vfx_states", sample_start)
		sample_start = _perf_begin(perf_logger)
		var affinity_hit_tags := _capture_affinity_hit_tags()
		_update_companion_motion(delta, owner)
		_perf_end(perf_logger, "physics.lingpet.companion_motion", sample_start)
		sample_start = _perf_begin(perf_logger)
		affinity_hit_tags = _merge_affinity_hit_tags(affinity_hit_tags, _capture_affinity_hit_tags())
		_update_ghost_blink_vfx_triggers()
		_maybe_arm_companion_strike(owner)
		_perf_end(perf_logger, "physics.lingpet.strike_arm", sample_start)
		sample_start = _perf_begin(perf_logger)
		_resolve_companion_ball_hit(owner, registry, affinity_hit_tags)
		_perf_end(perf_logger, "physics.lingpet.ball_hit", sample_start)
		sample_start = _perf_begin(perf_logger)
		_afterglow_leak_state.advance(delta, owner, registry, _get_current_passive_skill(), _state == STATE_COMPANION)
		_perf_end(perf_logger, "physics.lingpet.afterglow", sample_start)
		sample_start = _perf_begin(perf_logger)
		_update_companion_skill_effects(delta, owner, registry)
		_perf_end(perf_logger, "physics.lingpet.skill_effects", sample_start)
		sample_start = _perf_begin(perf_logger)
		_sync_owner(owner, registry)
		_perf_end(perf_logger, "physics.lingpet.owner_sync", sample_start)
	return false


func _update_none_state(owner: Object, registry: Object) -> bool:
	var owned_pet_id := _find_active_slot_pet_id(owner)
	if owned_pet_id != "":
		_adopt_owned_pet(owner, owned_pet_id, registry)
		return true
	if _should_spawn_lingpet_egg(owner):
		_spawn_egg(owner)
		return true
	if not _has_synced_none:
		_sync_owner(owner, registry)
		_has_synced_none = true
	return false


func _get_perf_logger(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("battle_perf_logger")


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _update_ghost_blink_vfx_triggers() -> void:
	# Fire the ghost "퐁" pop on the rabi free-flight vanish/appear edges. Only the
	# free-flight ghost blinks; for every other motion style this just tracks the
	# visibility so a later free-flight session does not fire a spurious pop.
	var now_visible: bool = _companion_motion_state.motion_visible
	if _state == STATE_COMPANION and _get_current_motion_style() == "free_flight" and now_visible != _prev_ghost_visible:
		if now_visible:
			_ghost_blink_vfx.trigger_appear(_companion_pos)
		else:
			_ghost_blink_vfx.trigger_vanish(_companion_pos)
	_prev_ghost_visible = now_visible


func prewarm_assets() -> void:
	_afterglow_leak_state.prewarm()
	if _companion_renderer != null and _companion_renderer.has_method("prewarm_assets"):
		_companion_renderer.prewarm_assets()
	_prewarm_current_skill_runtime()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, _draw_context: Dictionary = {}) -> void:
	if canvas == null:
		return
	if _state == STATE_EGG:
		_draw_egg(canvas, _egg_state.pos + shake_offset)
	elif _state == STATE_COMPANION:
		_skill_runtime_host.draw(canvas, shake_offset)
		_afterglow_leak_state.draw(canvas, shake_offset)
		var companion_body_draw_suppressed := _is_companion_body_draw_suppressed(_get_current_skill_id())
		var click_reaction_texture: Texture2D = null
		if _companion_click_reaction_state.is_active():
			click_reaction_texture = _get_current_cached_visual_texture(
				LingpetCompanionClickReactionState.RUNTIME_VISUAL_KEY,
				null
			)
		var click_reaction_visible: bool = bool(_companion_click_reaction_state.is_active()) and click_reaction_texture != null and not _ring_dash_state.is_companion_visual_hidden()
		if companion_body_draw_suppressed:
			pass
		elif not click_reaction_visible:
			_draw_companion(canvas, _companion_pos + shake_offset)
		else:
			_companion_click_reaction_state.draw(
				canvas,
				_companion_pos + shake_offset,
				click_reaction_texture,
				_get_companion_click_reaction_draw_size()
			)
		if _ring_dash_vfx.has_visible_effects():
			_ring_dash_vfx.draw(canvas, shake_offset)
		if _ghost_blink_vfx.has_visible_effects():
			_ghost_blink_vfx.draw(canvas, shake_offset)
		if _affinity_feedback_state.has_visible_effects(_state == STATE_COMPANION):
			_draw_affinity_feedback(canvas, _companion_pos + shake_offset)
		if _hatch_flash_timer > 0.0:
			_draw_hatch_flash(canvas, _egg_state.pos + shake_offset)


func has_visible_effects() -> bool:
	return (
		_state == STATE_EGG
		or _state == STATE_COMPANION
		or _hatch_flash_timer > 0.0
		or _acquire_cutin_state.active
		or _afterglow_leak_state.has_visible_effects()
		or _ring_dash_vfx.has_visible_effects()
		or _ghost_blink_vfx.has_visible_effects()
		or _affinity_feedback_state.has_visible_effects(_state == STATE_COMPANION)
		or _skill_runtime_host.has_visible_effects()
	)


func get_boss_ai_context() -> Dictionary:
	if _state != STATE_COMPANION or _skill_runtime_host == null:
		return {}
	if not _skill_runtime_host.has_method("get_boss_ai_context"):
		return {}
	var context: Variant = _skill_runtime_host.get_boss_ai_context()
	if context is Dictionary:
		return context
	return {}


func is_acquire_cutin_active() -> bool:
	return _acquire_cutin_state.active


# Advanced from the ungated idle pump (process_idle), so the reveal AND the exit
# action keep animating while the gated update driver is paused by the modal gate.
# The reveal is gated on the heavy Live2D acquisition sheet being cached: until then it
# holds in the reconstruction phase instead of locking solid on the static 원화 (the F7
# grant / 1-hit egg regression). We keep pumping the host's incremental stream here so
# the gate releases as soon as the sheet is ready, covering paths that skipped (or had
# too few) STATE_EGG calm frames.
func advance_acquire_cutin(delta: float, registry: Object = null) -> void:
	var anim_ready: bool = _is_acquire_cutin_anim_ready(registry)
	if not anim_ready and registry != null:
		_prewarm_acquire_cutin_assets_step(registry)
	_acquire_cutin_state.advance(delta, anim_ready)


func _is_acquire_cutin_anim_ready(registry: Object) -> bool:
	# True (no gate) when there is no host wired (smoke tests), no readiness query, or the
	# pet has no animated cut-in (static art is the intended visual). Otherwise defer to
	# the host, which checks the SAME texture cache key the draw path falls back from.
	if registry == null:
		return true
	var host: Object = _get_acquire_cutin_overlay_host(registry)
	if host == null or not host.has_method("is_pet_cutin_anim_ready"):
		return true
	return bool(host.is_pet_cutin_anim_ready(_pet_id))


func get_acquire_cutin_progress() -> float:
	return _acquire_cutin_state.get_progress()


# The reveal has finished playing and the cut-in is holding for a click/confirm.
# Excludes the dismissing phase so a click cannot re-trigger the exit action once
# it has started. Input is swallowed before this point so an early click cannot
# skip the reveal or leak into gameplay.
func is_acquire_cutin_awaiting_dismiss() -> bool:
	return _acquire_cutin_state.is_awaiting_dismiss()


# Begin the animated exit action (does NOT close immediately). The cut-in stays
# active (gameplay paused) until advance_acquire_cutin finishes the action+fade.
func begin_acquire_cutin_dismiss(registry: Object = null) -> bool:
	if not _acquire_cutin_state.begin_dismiss(_get_current_acquire_cutin_dismiss_seconds()):
		return false
	_play_acquire_click_reaction_backing_audio(registry)
	_play_click_reaction_audio(registry)
	return true


func is_acquire_cutin_dismissing() -> bool:
	return _acquire_cutin_state.is_dismissing()


func get_acquire_cutin_dismiss_progress() -> float:
	return _acquire_cutin_state.get_dismiss_progress()


# Immediate hard close (cleanup / state-reset paths). The click handler uses
# begin_acquire_cutin_dismiss() instead so players see the exit action.
func dismiss_acquire_cutin() -> bool:
	return _acquire_cutin_state.dismiss_immediate()


func is_maribo_companion_active() -> bool:
	return _pet_id == PET_ID and _state == STATE_COMPANION


func is_companion_active(pet_id: String = "") -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	return _state == STATE_COMPANION and (normalized_pet_id == "" or _pet_id == normalized_pet_id)


func debug_grant_and_activate_pet(
	pet_id: String,
	owner: Object = null,
	show_acquire_cutin: bool = false,
	active_skill_id: String = "",
	passive_skill_id: String = "",
	registry: Object = null,
	active_skill_level: int = 1,
	passive_skill_level: int = 1
) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return false
	_save_current_companion_skill_state()
	if active_skill_id.strip_edges() != "" or passive_skill_id.strip_edges() != "":
		_loadout_state.set_pet_loadout(owner, normalized_pet_id, active_skill_id, passive_skill_id, active_skill_level, passive_skill_level)
		_invalidate_current_loadout_cache()
	_state = STATE_COMPANION
	_set_current_pet_id(normalized_pet_id)
	_apply_affinity_headstart_from_store(normalized_pet_id, registry)
	_apply_current_loadout(owner, true, true)
	_egg_state.set_hatched(_get_current_required_hits())
	_companion_pos = Vector2.ZERO
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_switch_transition_state.reset()
	_hatch_flash_timer = 0.0
	_acquire_cutin_state.reset()
	_prewarm_current_visuals()
	if owner != null:
		var owner_slots: Array[String] = _collection_state.get_battle_slots_from_owner(owner)
		_collection_state.set_battle_slots(owner_slots)
		_collection_state.set_active_slot_index(_collection_state.get_active_slot_index_from_owner(owner))
	_mark_current_pet_owned(owner)
	var slots: Array[String] = _collection_state.get_battle_slots()
	var slot_index: int = slots.find(normalized_pet_id)
	if slot_index >= 0:
		_collection_state.select_active_slot(slot_index, owner)
	else:
		var active_slot_index: int = _collection_state.get_active_slot_index()
		if active_slot_index >= 0 and active_slot_index < slots.size():
			slots[active_slot_index] = normalized_pet_id
			_collection_state.set_battle_slots(slots)
			_collection_state.set_active_slot_index(active_slot_index)
	_initialize_companion_patrol(owner, true)
	if show_acquire_cutin:
		_start_acquire_cutin(registry)
	_sync_owner(owner, registry)
	return true


func get_lingpet_slots() -> Array[String]:
	return _collection_state.get_battle_slots()


func get_active_lingpet_slot_index() -> int:
	return _collection_state.get_active_slot_index()


func _set_current_pet_id(value: String) -> void:
	var previous_pet_id := _pet_id
	_pet_id = _current_profile.set_pet_id(value, PET_ID)
	_sync_current_profile_affinity(_pet_id)
	if _pet_id != previous_pet_id:
		_affinity_feedback_state.reset_transients()
		_invalidate_current_loadout_cache()
	_affinity_feedback_state.sync_for_level(_affinity_state.get_level(_pet_id), LingpetAffinityState.MAX_LEVEL)


func switch_lingpet_slot(slot_index: int, owner: Object = null, registry: Object = null) -> bool:
	_save_current_companion_skill_state()
	var next_pet_id: String = _collection_state.select_active_slot(slot_index, owner)
	if next_pet_id == "":
		return false
	if _state != STATE_COMPANION:
		_adopt_owned_pet(owner, next_pet_id, registry)
		return true
	if next_pet_id == _pet_id:
		_sync_owner(owner, registry)
		return true
	_switch_transition_state.begin(_pet_id, next_pet_id, COMPANION_SWITCH_TRANSITION_SECONDS)
	_set_current_pet_id(next_pet_id)
	_apply_affinity_headstart_from_store(next_pet_id, registry)
	_apply_current_loadout(owner, true, false)
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_prewarm_current_visuals()
	_mark_current_pet_owned(owner)
	_sync_owner(owner, registry)
	return true


func cycle_lingpet_slot(direction: int = 1, owner: Object = null, registry: Object = null) -> bool:
	var next_slot_index: int = _collection_state.find_next_occupied_slot_index(direction, owner)
	if next_slot_index < 0:
		return false
	if next_slot_index == _collection_state.get_active_slot_index_from_owner(owner):
		return false
	return switch_lingpet_slot(next_slot_index, owner, registry)


# Test-only accessors: the strike state is transient visual state that is
# intentionally NOT persisted in get_snapshot()/save schema, so the smoke reads
# it directly to assert the anticipatory pre-contact timing.
func is_companion_striking_for_tests() -> bool:
	return _companion_sprite_animator.strike_active


func get_companion_strike_frame_for_tests() -> int:
	return _companion_sprite_animator.get_strike_frame()


func is_companion_facing_left_for_tests() -> bool:
	return _companion_facing_left


func get_hydro_puddle_particle_count_for_tests() -> int:
	return _skill_runtime_host.get_hydro_puddle_particle_count_for_tests()


func get_afterglow_leak_residue_count_for_tests() -> int:
	return _afterglow_leak_state.get_residue_count_for_tests()


func get_starlight_tracking_trigger_count_for_tests() -> int:
	return _starlight_tracking_state.get_trigger_count_for_tests()


func is_starlight_tracking_active_for_tests() -> bool:
	return _starlight_tracking_state.is_active_for_tests()


func get_ring_dash_trigger_count_for_tests() -> int:
	return _ring_dash_state.get_trigger_count_for_tests()


func set_affinity_store_for_tests(store: Object) -> void:
	_affinity_store_override = store
	_affinity_headstart_applied_pet_ids.clear()


func set_affinity_reward_seed_for_tests(pet_id: String, reward_seed: int) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	_affinity_reward_seeds_by_pet_id[normalized_pet_id] = maxi(1, reward_seed % LingpetAffinityState.REWARD_DECK_SEED_MOD)
	_configure_affinity_reward_context(normalized_pet_id)
	_affinity_state.set_reward_seed_for_tests(normalized_pet_id, reward_seed)
	if normalized_pet_id == _pet_id:
		_sync_current_profile_affinity(normalized_pet_id)
		_invalidate_current_loadout_cache()


func is_ring_dash_active_for_tests() -> bool:
	return _ring_dash_state.is_active_for_tests()


func is_ring_dash_vfx_active_for_tests() -> bool:
	return _ring_dash_vfx.has_visible_effects()


func is_ring_dash_visual_hidden_for_tests() -> bool:
	return _ring_dash_state.is_companion_visual_hidden()


func get_companion_draw_motion_speed_ratio_for_tests() -> float:
	return _get_companion_draw_motion_speed_ratio()


func get_headbutt_hit_count_for_tests() -> int:
	return _skill_runtime_host.get_headbutt_hit_count_for_tests()


func get_headbutt_miss_count_for_tests() -> int:
	return _skill_runtime_host.get_headbutt_miss_count_for_tests()


func get_puppet_grab_count_for_tests() -> int:
	return _skill_runtime_host.get_puppet_grab_count_for_tests()


func get_puppet_grab_kiss_count_for_tests() -> int:
	return _skill_runtime_host.get_puppet_grab_kiss_count_for_tests()


func configure_companion_motion_for_tests(test_pos: Vector2, test_seed: int, test_decision_timer: float, test_intercept_active: bool) -> void:
	_companion_pos = test_pos
	_companion_motion_state.configure_for_tests(test_pos, test_seed, test_decision_timer, test_intercept_active)


func configure_companion_sortie_hidden_for_tests(test_pos: Vector2, test_seed: int, hidden_seconds: float) -> void:
	_companion_pos = test_pos
	_companion_motion_state.configure_sortie_hidden_for_tests(test_pos, test_seed, hidden_seconds)


func get_gauge_gain_per_hit(base_gain: float) -> float:
	var gain: float = maxf(0.0, base_gain)
	var bonus_pct := _get_current_gauge_gain_bonus_pct()
	if _state != STATE_COMPANION or bonus_pct <= 0.0:
		return gain
	return floor(gain * (1.0 + bonus_pct / 100.0))


func get_player_speed_multiplier() -> float:
	if _state != STATE_COMPANION:
		return 1.0
	var bonus_pct := _get_current_player_speed_bonus_pct()
	if bonus_pct <= 0.0:
		return 1.0
	return 1.0 + bonus_pct / 100.0


func update_starlight_tracking_for_starpoint_drop(drop: Dictionary, delta_seconds: float, context: Dictionary = {}) -> Dictionary:
	if drop.is_empty() or _state != STATE_COMPANION:
		return {}
	if _skill_runtime_host.has_companion_position_override(_get_current_skill_id()):
		_starlight_tracking_state.reset_round_transients()
		return {}
	if _ring_dash_state.has_companion_position_override():
		return {}
	if _companion_pos == Vector2.ZERO:
		var owner_value: Variant = context.get("owner", null)
		var owner: Object = null
		if owner_value is Object:
			owner = owner_value as Object
		_initialize_companion_patrol(owner, true)
	var previous_pos := _companion_pos
	var result: Dictionary = _starlight_tracking_state.update_drop(
		maxf(0.0, delta_seconds),
		drop,
		_get_current_passive_skill(),
		_state == STATE_COMPANION,
		_companion_pos,
		_get_starlight_tracking_delivery_pos(context)
	)
	if result.has("companion_pos"):
		var next_pos: Variant = result.get("companion_pos", _companion_pos)
		if next_pos is Vector2:
			_companion_pos = next_pos
			_companion_motion_state.pos = _companion_pos
			_update_companion_facing_after_motion(previous_pos)
	return result


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = _snapshot_builder.build_runtime_snapshot(
		_pet_id,
		_state,
		_get_current_required_hits(),
		_companion_pos,
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_active_skill(),
		_hatch_flash_timer,
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_get_current_gauge_gain_bonus_pct(),
		_egg_state,
		_companion_motion_state,
		_get_current_stat("patrol_speed_default", COMPANION_PATROL_SPEED),
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_defense_rate(),
		_companion_body_hit_state,
		_get_current_hit_gauge_gain(),
		_companion_skill_state,
		_get_current_skill_windup_seconds(),
		COMPANION_SKILL_FLASH_SECONDS,
		_skill_runtime_host,
		_loadout_state.get_loadouts(),
		_get_current_active_skill_pool(),
		_get_current_passive_skill(),
		_get_current_passive_skill_pool()
	)
	snapshot.merge(_switch_transition_state.get_snapshot(COMPANION_SWITCH_TRANSITION_SECONDS), true)
	snapshot.merge(_afterglow_leak_state.get_snapshot(), true)
	snapshot.merge(_ring_dash_state.get_snapshot(), true)
	snapshot.merge(_starlight_tracking_state.get_snapshot(), true)
	snapshot["companion_appearance_rate"] = _get_current_appearance_rate() if _state == STATE_COMPANION else 0.0
	var affinity_snapshot := _build_affinity_owner_snapshot()
	snapshot["affinity_level"] = int(affinity_snapshot.get("level", 0))
	snapshot["affinity_points"] = float(affinity_snapshot.get("points", 0.0))
	snapshot["affinity_next_requirement"] = float(affinity_snapshot.get("next_requirement", 0.0))
	snapshot["affinity_next_label"] = str(affinity_snapshot.get("next_label", ""))
	snapshot.merge(_affinity_feedback_state.get_snapshot(_state == STATE_COMPANION), true)
	return snapshot


func get_save_snapshot() -> Dictionary:
	return _snapshot_builder.build_save_snapshot(
		SAVE_SNAPSHOT_VERSION,
		_pet_id,
		_state,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.pos,
		_companion_pos,
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_get_current_gauge_gain_bonus_pct(),
		_companion_motion_state,
		_loadout_state.get_loadouts()
	)


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	reset_for_tests()
	var restore_reason := "ok"
	if snapshot.is_empty():
		if owner != null:
			_sync_owner(owner)
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	_set_current_pet_id(str(snapshot.get("pet_id", PET_ID)))
	_loadout_state.set_loadouts(snapshot.get("lingpet_loadouts", snapshot.get("ringpet_loadouts", {})))
	var restored_state: String = _normalize_lingpet_state(str(snapshot.get("state", STATE_NONE)))
	var restore_plan: Dictionary = _save_restore_planner.build_plan(snapshot, owner, _collection_state, _pet_id, restored_state)
	restore_reason = str(restore_plan.get("restore_reason", "ok"))
	_set_current_pet_id(str(restore_plan.get("pet_id", _pet_id)))
	var target_state := str(restore_plan.get("target_state", STATE_NONE))
	if target_state == STATE_COMPANION:
		_state = STATE_COMPANION
		_apply_current_loadout(owner, true, false)
		_egg_state.set_hatched(_get_current_required_hits())
		var companion_fallback := Vector2.ZERO
		_companion_pos = _get_vector2_from_variant(snapshot.get("companion_pos", companion_fallback), companion_fallback)
		_companion_motion_state.pos = _companion_pos
		_restore_companion_patrol(snapshot)
		if owner != null:
			_initialize_companion_patrol(owner, _companion_pos == Vector2.ZERO)
	elif target_state == STATE_EGG and bool(restore_plan.get("spawn_fresh_egg", false)):
		_spawn_egg(owner)
	else:
		_clear_lingpet_field_state()
	if owner != null:
		if _state == STATE_COMPANION:
			_mark_current_pet_owned(owner)
		_sync_owner(owner)
	return {
		"restored": true,
		"reason": restore_reason,
		"state": _state,
		"owned_pet_ids": _collection_state.get_owned_pet_ids(),
	}


func restore_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	return apply_save_snapshot(snapshot, owner)


func reset_for_tests() -> void:
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_current_profile.set_affinity_state(0, LingpetAffinityState.get_empty_reward_counts())
	_invalidate_current_loadout_cache()
	_affinity_state.reset_for_new_run()
	_affinity_feedback_state.reset_all()
	_affinity_income_tracker.reset_all()
	_affinity_headstart_applied_pet_ids.clear()
	_affinity_reward_seeds_by_pet_id.clear()
	_last_affinity_result = {}
	_last_affinity_bond_settlement = {}
	_egg_state.reset_all()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_collection_state.reset()
	_loadout_state.reset()
	_hatch_flash_timer = 0.0
	_reset_companion_runtime_state()
	_companion_skill_state_by_pet_id.clear()
	_acquire_cutin_state.reset()
	_switch_transition_state.reset()
	_has_synced_none = false


func reset_round(deps: Dictionary = {}) -> void:
	_reset_skill_runtime_transients(deps.get("owner", null) as Object, deps.get("registry", null) as Object)
	_affinity_state.reset_round_caps()
	_reset_companion_defense()
	_switch_transition_state.reset()
	_companion_skill_state.reset_round_transients()
	_companion_body_hit_state.reset_round_transients()
	_afterglow_leak_state.reset_round_transients()
	_ring_dash_state.reset_round_transients()
	_ring_dash_vfx.reset()
	_ghost_blink_vfx.reset()
	_starlight_tracking_state.reset_round_transients()


func _reset_skill_runtime_transients(owner: Object = null, registry: Object = null) -> void:
	_companion_skill_state.cancel_windup()
	_skill_runtime_host.reset(owner, registry)


func _clear_lingpet_field_state() -> void:
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_invalidate_current_loadout_cache()
	_affinity_feedback_state.reset_all()
	_egg_state.reset_all()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_afterglow_leak_state.reset_all()
	_ring_dash_state.reset_all()
	_ring_dash_vfx.reset()
	_ghost_blink_vfx.reset()
	_prev_ghost_visible = true
	_starlight_tracking_state.reset_all()


func _reset_companion_runtime_state(reset_defense: bool = true) -> void:
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_afterglow_leak_state.reset_all()
	_ring_dash_state.reset_all()
	_ring_dash_vfx.reset()
	_ghost_blink_vfx.reset()
	_prev_ghost_visible = true
	_starlight_tracking_state.reset_all()
	_companion_skill_state.reset_all()
	if reset_defense:
		_reset_companion_defense()
	_reset_skill_runtime_transients()


func _spawn_egg(owner: Object) -> void:
	_state = STATE_EGG
	_set_current_pet_id(_pick_hatch_pet_id(owner))
	_egg_state.spawn(owner)
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_hatch_flash_timer = 0.0
	_reset_companion_runtime_state()
	_acquire_cutin_state.reset()
	_switch_transition_state.reset()
	_has_synced_none = false
	_prewarm_current_visuals()
	_sync_owner(owner)


func _resolve_ball_hit(owner: Object, registry: Object = null) -> bool:
	var hit_result: Dictionary = _egg_state.resolve_ball_hit(owner, _get_current_required_hits())
	if not bool(hit_result.get("changed", false)):
		return false

	if bool(hit_result.get("hatched", false)):
		_state = STATE_COMPANION
		_apply_current_loadout(owner, true, true)
		_add_affinity_points(_pet_id, LingpetAffinityState.SOURCE_HATCH, {}, registry)
		_apply_affinity_headstart_from_store(_pet_id, registry)
		_companion_pos = _egg_state.pos
		_initialize_companion_patrol(owner, false)
		_egg_state.reset_contact_motion()
		_reset_companion_runtime_state(false)
		_switch_transition_state.reset()
		_hatch_flash_timer = LingpetEggFieldRenderer.HATCH_FLASH_SECONDS
		_start_acquire_cutin(registry)
		_prewarm_current_visuals()
		_mark_current_pet_owned(owner)
		_select_current_pet_slot(owner)
	return true


func _start_acquire_cutin(registry: Object = null) -> void:
	_acquire_cutin_state.start()
	_play_acquire_cutin_audio(registry)


func _play_acquire_cutin_audio(registry: Object = null) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var audio: Object = registry.get_instance("game_audio")
	if audio != null and audio.has_method("play_lingpet_acquire_cutin"):
		audio.play_lingpet_acquire_cutin()


func _sync_owner(owner: Object, registry: Object = null) -> void:
	if _state == STATE_COMPANION:
		if _applied_loadout_key == "":
			_apply_current_loadout(owner, true, false)
	else:
		_loadout_state.sync_owner(owner, "")
	var should_sync_loadouts := _state != STATE_COMPANION or _synced_owner_loadout_key != _applied_loadout_key
	var loadouts_snapshot: Dictionary = _loadout_state.get_loadouts() if should_sync_loadouts else {}
	_snapshot_builder.sync_owner(
		owner,
		_pet_id,
		_state,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.pos,
		_companion_pos,
		_get_current_stat("patrol_speed_default", COMPANION_PATROL_SPEED),
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_defense_rate(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_companion_motion_state,
		_companion_body_hit_state,
		_get_current_hit_gauge_gain(),
		_get_current_active_skill(),
		_companion_skill_state,
		_get_current_gauge_gain_bonus_pct(),
		_get_effect_text(),
		loadouts_snapshot,
		_get_current_passive_skill(),
		should_sync_loadouts
	)
	# Appearance rate (flight-only 출현율) is synced directly here rather than threaded
	# through the snapshot builder; the panel reads owner.lingpet_companion_appearance_rate.
	var appearance_rate: float = _get_current_appearance_rate() if _state == STATE_COMPANION else 0.0
	owner.set("lingpet_companion_appearance_rate", appearance_rate)
	owner.set("ringpet_companion_appearance_rate", appearance_rate)
	var affinity_snapshot := _build_affinity_owner_snapshot(registry)
	owner.set("lingpet_affinity_level", int(affinity_snapshot.get("level", 0)))
	owner.set("ringpet_affinity_level", int(affinity_snapshot.get("level", 0)))
	owner.set("lingpet_affinity_points", float(affinity_snapshot.get("points", 0.0)))
	owner.set("ringpet_affinity_points", float(affinity_snapshot.get("points", 0.0)))
	owner.set("lingpet_affinity_next_requirement", float(affinity_snapshot.get("next_requirement", 0.0)))
	owner.set("ringpet_affinity_next_requirement", float(affinity_snapshot.get("next_requirement", 0.0)))
	owner.set("lingpet_affinity_next_label", str(affinity_snapshot.get("next_label", "")))
	owner.set("ringpet_affinity_next_label", str(affinity_snapshot.get("next_label", "")))
	owner.set("lingpet_bond_points", int(affinity_snapshot.get("bond_points", 0)))
	owner.set("ringpet_bond_points", int(affinity_snapshot.get("bond_points", 0)))
	owner.set("lingpet_bond_title", str(affinity_snapshot.get("bond_title", "")))
	owner.set("ringpet_bond_title", str(affinity_snapshot.get("bond_title", "")))
	if should_sync_loadouts:
		_synced_owner_loadout_key = _applied_loadout_key


func _build_affinity_owner_snapshot(registry: Object = null) -> Dictionary:
	var level := 0
	var points := 0.0
	var next_requirement := 0.0
	var next_label := ""
	var bond_points := 0
	if _state == STATE_COMPANION:
		_configure_affinity_reward_context(_pet_id)
		level = _affinity_state.get_level(_pet_id)
		points = _affinity_state.get_points(_pet_id)
		next_requirement = _affinity_state.get_next_requirement(_pet_id)
		next_label = _affinity_next_label_for_pet(_pet_id)
		bond_points = _get_affinity_bond_points(_pet_id, registry)
	return {
		"level": level,
		"points": points,
		"next_requirement": next_requirement,
		"next_label": next_label,
		"bond_points": bond_points,
		"bond_title": LingpetAffinityState.get_bond_title_for_points(bond_points),
	}


func _get_affinity_bond_points(pet_id: String, registry: Object = null) -> int:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return 0
	var store: Object = _get_affinity_store(registry)
	if store == null or not store.has_method("get_bond_points"):
		return 0
	return maxi(0, int(store.get_bond_points(normalized_pet_id)))


func _affinity_next_label_for_pet(pet_id: String) -> String:
	var next_reward: Dictionary = _affinity_state.get_next_reward(_normalize_pet_id(pet_id))
	if bool(next_reward.has("title")):
		return str(next_reward.get("title", "하트 공명"))
	return str(next_reward.get("label", ""))


func _adopt_owned_pet(owner: Object, pet_id: String, registry: Object = null) -> void:
	_state = STATE_COMPANION
	_set_current_pet_id(pet_id)
	_apply_affinity_headstart_from_store(pet_id, registry)
	_apply_current_loadout(owner, true, false)
	_egg_state.set_hatched(_get_current_required_hits())
	_companion_pos = Vector2.ZERO
	_initialize_companion_patrol(owner, true)
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_switch_transition_state.reset()
	_hatch_flash_timer = 0.0
	_prewarm_current_visuals()
	_mark_current_pet_owned(owner)
	_sync_owner(owner, registry)


func _save_current_companion_skill_state() -> void:
	if _pet_id == "" or _companion_skill_state == null or not _companion_skill_state.has_method("get_persistent_snapshot"):
		return
	_companion_skill_state_by_pet_id[_pet_id] = _companion_skill_state.get_persistent_snapshot()


func _restore_current_companion_skill_state() -> void:
	if _pet_id == "" or not _companion_skill_state_by_pet_id.has(_pet_id):
		return
	var snapshot: Variant = _companion_skill_state_by_pet_id.get(_pet_id, {})
	if snapshot is Dictionary and _companion_skill_state != null and _companion_skill_state.has_method("apply_persistent_snapshot"):
		_companion_skill_state.apply_persistent_snapshot(snapshot as Dictionary)


func _advance_stored_companion_skill_cooldowns(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	if safe_delta <= 0.0 or _companion_skill_state_by_pet_id.is_empty():
		return
	for raw_pet_id in _companion_skill_state_by_pet_id.keys():
		var pet_id := str(raw_pet_id)
		if _state == STATE_COMPANION and pet_id == _pet_id:
			continue
		var snapshot: Variant = _companion_skill_state_by_pet_id.get(raw_pet_id, {})
		if not (snapshot is Dictionary):
			continue
		var updated: Dictionary = (snapshot as Dictionary).duplicate(true)
		updated["cooldown"] = maxf(0.0, float(updated.get("cooldown", 0.0)) - safe_delta)
		_companion_skill_state_by_pet_id[raw_pet_id] = updated


func _mark_current_pet_owned(owner: Object) -> void:
	_mark_pet_owned(owner, _pet_id)


func _mark_pet_owned(owner: Object, pet_id: String) -> void:
	_collection_state.add_pet(owner, pet_id)


func _select_current_pet_slot(owner: Object) -> void:
	var slots: Array[String] = _collection_state.get_battle_slots()
	var slot_index: int = slots.find(_pet_id)
	if slot_index >= 0:
		_collection_state.select_active_slot(slot_index, owner)


func _get_effect_text() -> String:
	if _state == STATE_EGG:
		return "공에 %d회 맞히면 미확인 알이 깨어납니다." % _get_current_required_hits()
	if _state == STATE_COMPANION:
		return _current_profile.get_effect_text()
	return ""


func _should_spawn_lingpet_egg(owner: Object) -> bool:
	return _collection_state.should_spawn_egg(owner)


func _find_first_owned_pet_id(owner: Object) -> String:
	return _collection_state.find_first_owned_pet_id(owner)


func _find_active_slot_pet_id(owner: Object) -> String:
	return _collection_state.find_active_slot_pet_id(owner)


func _pick_hatch_pet_id(owner: Object) -> String:
	return _collection_state.pick_hatch_pet_id(owner)


func _get_current_display_name() -> String:
	return _current_profile.get_display_name()


func _get_current_required_hits() -> int:
	return _current_profile.get_required_hits(REQUIRED_HITS)


func _get_current_stat(stat_name: String, fallback: float) -> float:
	return _current_profile.get_stat(stat_name, fallback)


func _get_current_active_skill() -> Dictionary:
	return _current_profile.get_active_skill()


func _get_current_active_skill_pool() -> Array[Dictionary]:
	return _current_profile.get_active_skill_pool()


func _get_current_passive_skill() -> Dictionary:
	return _current_profile.get_passive_skill()


func _get_current_passive_skill_pool() -> Array[Dictionary]:
	return _current_profile.get_passive_skill_pool()


func _get_current_motion_style() -> String:
	return _current_profile.get_motion_style()


func _get_current_skill_id() -> String:
	return _current_profile.get_skill_id()


func _get_current_skill_windup_seconds() -> float:
	return _current_profile.get_skill_windup_seconds(COMPANION_SKILL_WINDUP_SECONDS)


func _get_current_acquire_cutin_dismiss_seconds() -> float:
	return maxf(
		0.1,
		_current_profile.get_visual_layout_value("cutin_dismiss_seconds", LingpetAcquireCutinState.DISMISS_SECONDS)
	)


func _get_current_gauge_gain_bonus_pct() -> float:
	return _current_profile.get_gauge_gain_bonus_pct(0.0)


func _get_current_player_speed_bonus_pct() -> float:
	return _current_profile.get_player_speed_bonus_pct(0.0)


func _get_current_hit_gauge_gain() -> float:
	return _current_profile.get_hit_gauge_gain(COMPANION_HIT_GAUGE_GAIN)


func set_debug_defense_rate_override(value: float) -> void:
	# value < 0 clears the override (back to the pet's catalog/profile defense_rate).
	_debug_defense_rate_override = -1.0 if value < 0.0 else clampf(value, 0.0, 1.0)


func get_debug_defense_rate_override() -> float:
	return _debug_defense_rate_override


func set_debug_appearance_rate_override(value: float) -> void:
	# value < 0 clears the override (back to the pet's catalog/profile appearance_rate).
	_debug_appearance_rate_override = -1.0 if value < 0.0 else clampf(value, 0.0, 1.0)


func get_debug_appearance_rate_override() -> float:
	return _debug_appearance_rate_override


func _get_current_defense_rate() -> float:
	# Defense intercept is PATROL-only (flight-style companions skip it in
	# lingpet_companion_motion_state.update). Report 0 for non-patrol lingpets so the
	# character-info panel never shows a defense rate they can't act on, and so the
	# F7 defense-rate override is a no-op for flight-style pets.
	if _get_current_motion_style() != "patrol":
		return 0.0
	if _debug_defense_rate_override >= 0.0:
		return _debug_defense_rate_override
	return _current_profile.get_defense_rate(COMPANION_DEFENSE_RATE)


func _get_current_appearance_rate() -> float:
	# Appearance rate is FLIGHT-only — it shortens the hidden/vanish wait between
	# reappearances. Patrol pets return 0 (defense is their stat instead), so the
	# panel never shows it for them and the F7 override is a no-op for patrol pets.
	if _get_current_motion_style() == "patrol":
		return 0.0
	if _debug_appearance_rate_override >= 0.0:
		return _debug_appearance_rate_override
	return _current_profile.get_appearance_rate(0.0)


func _get_current_hit_half_width() -> float:
	return _current_profile.get_hit_half_width(COMPANION_HIT_HALF_WIDTH * 2.0)


func _get_current_hit_half_height() -> float:
	return _current_profile.get_hit_half_height(COMPANION_HIT_HALF_HEIGHT * 2.0)


func _normalize_pet_id(value: String) -> String:
	return _current_profile.normalize_pet_id(value)


func _apply_current_loadout(owner: Object, ensure: bool, randomize_missing: bool = false) -> void:
	if _pet_id == "":
		if _applied_loadout_key != "":
			_current_profile.set_affinity_state(0, LingpetAffinityState.get_empty_reward_counts())
			_current_profile.set_loadout("", "")
			_invalidate_current_loadout_cache()
		return
	if not randomize_missing and _applied_loadout_key != "":
		return
	var loadout: Dictionary = _loadout_state.ensure_pet_loadout(owner, _pet_id, null, randomize_missing) if ensure else _loadout_state.get_loadout(_pet_id)
	_configure_affinity_reward_context(_pet_id, loadout)
	var loadout_key := _build_loadout_key(_pet_id, loadout)
	if not randomize_missing and loadout_key == _applied_loadout_key:
		return
	_current_profile.set_loadout(
		str(loadout.get("active_skill_id", "")),
		str(loadout.get("passive_skill_id", "")),
		int(loadout.get("active_skill_level", 1)),
		int(loadout.get("passive_skill_level", 1))
	)
	_sync_current_profile_affinity(_pet_id)
	_applied_loadout_key = loadout_key
	_prewarm_current_skill_runtime()


func _invalidate_current_loadout_cache() -> void:
	_applied_loadout_key = ""
	_synced_owner_loadout_key = ""


func _build_loadout_key(pet_id: String, loadout: Dictionary) -> String:
	return "%s|%s|%d|%s|%d|%s" % [
		pet_id,
		str(loadout.get("active_skill_id", "")),
		int(loadout.get("active_skill_level", 1)),
		str(loadout.get("passive_skill_id", "")),
		int(loadout.get("passive_skill_level", 1)),
		_affinity_state.get_reward_signature(pet_id),
	]


func _prewarm_current_visuals() -> void:
	_current_profile.prewarm_visuals()
	if _companion_renderer != null and _companion_renderer.has_method("prewarm_assets"):
		_companion_renderer.prewarm_assets()
	if _state == STATE_COMPANION:
		_queue_click_reaction_visual_prewarm()


func _prewarm_current_skill_runtime() -> void:
	# The skill runtime host lazy-creates the active skill module on its first
	# per-frame update(), and heavy assets (the 512px doll curse sheet) only
	# load at first arm — both land mid-rally. Build them at the discrete
	# loadout-apply / boot-prewarm moment instead.
	if _skill_runtime_host == null:
		return
	var skill_id := _get_current_skill_id()
	if skill_id == "":
		return
	_skill_runtime_host.prewarm(skill_id)


func _get_current_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _current_profile.get_visual_texture(visual_key, fallback)


func _get_current_cached_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _current_profile.get_cached_visual_texture(visual_key, fallback)


func _get_companion_click_reaction_draw_size() -> Vector2:
	var fallback_size: float = float(LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x)
	var click_draw_size: float = _current_profile.get_visual_layout_value("click_reaction_draw_size", 0.0)
	if click_draw_size > 0.0:
		return Vector2(click_draw_size, click_draw_size)
	var draw_size: float = _current_profile.get_visual_layout_value("companion_walk_draw_size", fallback_size)
	if draw_size <= 0.0:
		draw_size = fallback_size
	return Vector2(draw_size, draw_size)


func _prewarm_acquire_cutin_assets_step(registry: Object) -> void:
	# One incremental threaded-stream step toward caching the current egg pet's
	# acquire cut-in sheets. Driven from the STATE_EGG update so the heavy sheets are
	# ready by hatch time; the overlay host's own prewarm_pet_assets_step is idempotent
	# and returns true once the pet's sheets are cached (the host then pulls them from
	# the same cache on its first reveal draw instead of holding on the static art).
	if registry == null or _pet_id == "":
		return
	if _acquire_cutin_assets_prewarm_done_for == _pet_id:
		return
	var host: Object = _get_acquire_cutin_overlay_host(registry)
	if host == null or not host.has_method("prewarm_pet_assets_step"):
		return
	if bool(host.prewarm_pet_assets_step(_pet_id)):
		_acquire_cutin_assets_prewarm_done_for = _pet_id


func _get_acquire_cutin_overlay_host(registry: Object) -> Object:
	if registry == null:
		return null
	var host: Variant = null
	if registry.has_method("get_cached_instance"):
		host = registry.get_cached_instance("lingpet_acquire_cutin_overlay_host")
	if (typeof(host) != TYPE_OBJECT or host == null) and registry.has_method("get_instance"):
		host = registry.get_instance("lingpet_acquire_cutin_overlay_host")
	if typeof(host) != TYPE_OBJECT or host == null:
		return null
	return host as Object


func _queue_click_reaction_visual_prewarm() -> void:
	if _state != STATE_COMPANION:
		return
	if _click_reaction_visual_prewarm_done_for == _pet_id:
		return
	_click_reaction_visual_prewarm_pet_id = _pet_id


func _prewarm_click_reaction_visual_step() -> bool:
	if _state != STATE_COMPANION:
		return true
	if _click_reaction_visual_prewarm_done_for == _pet_id:
		return true
	if _click_reaction_visual_prewarm_pet_id != _pet_id:
		_click_reaction_visual_prewarm_pet_id = _pet_id
	for visual_key in LingpetCompanionClickReactionState.PREWARM_VISUAL_KEYS:
		var done: bool = bool(_current_profile.prewarm_visual_key_threaded_step(
			str(visual_key),
			CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC,
			CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS
		))
		if not done:
			return false
	_click_reaction_visual_prewarm_done_for = _pet_id
	_click_reaction_visual_prewarm_pet_id = ""
	return true


func _normalize_lingpet_state(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == STATE_EGG or normalized == "hatching" or normalized == "알":
		return STATE_EGG
	if normalized == STATE_COMPANION or normalized == "active" or normalized == "owned" or normalized == "hatched" or normalized == "동행":
		return STATE_COMPANION
	return STATE_NONE


func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_starlight_tracking_delivery_pos(context: Dictionary) -> Vector2:
	var owner_value: Variant = context.get("owner", null)
	var owner: Object = null
	if owner_value is Object:
		owner = owner_value as Object
	var owner_player_pos := Vector2.ZERO
	var owner_paddle_size := Vector2(155.0, 50.0)
	if owner != null:
		owner_player_pos = _get_vector2_from_variant(BattleSceneOwnerReader.get_value(owner, "player_pos", Vector2.ZERO), owner_player_pos)
		owner_paddle_size = Vector2(
			float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", owner_paddle_size.x)),
			float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", owner_paddle_size.y))
		)
	var player_pos := _get_vector2_from_variant(context.get("player_pos", owner_player_pos), owner_player_pos)
	var player_size := _get_vector2_from_variant(context.get("player_paddle_size", owner_paddle_size), owner_paddle_size)
	return player_pos + player_size * 0.5


func _update_companion_motion(delta: float, owner: Object) -> void:
	var prev_pos: Vector2 = _companion_pos
	if _skill_runtime_host.has_companion_position_override(_get_current_skill_id()):
		_ring_dash_state.reset_round_transients()
		_ring_dash_vfx.reset()
	else:
		var ring_dash_was_active: bool = _ring_dash_state.has_companion_position_override()
		var ring_dash_result: Dictionary = _ring_dash_state.advance(
			delta,
			owner,
			_get_current_passive_skill(),
			_state == STATE_COMPANION,
			_companion_pos,
			_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
			_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0)
		)
		if _ring_dash_state.has_companion_position_override():
			_companion_pos = _ring_dash_state.get_companion_position_override(_companion_pos)
			_companion_motion_state.pos = _companion_pos
			_update_companion_facing_after_motion(prev_pos)
			if bool(ring_dash_result.get("started", false)):
				# prev_pos is the pre-teleport spot (departure collapse); _companion_pos
				# is the snapped intercept point (arrival burst).
				_ring_dash_vfx.trigger(prev_pos, _companion_pos)
				_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)
			return
		if ring_dash_was_active:
			_resume_companion_motion_after_ring_dash(owner)
	if _starlight_tracking_state.has_companion_position_override() and not _skill_runtime_host.has_companion_position_override(_get_current_skill_id()):
		_companion_pos = _starlight_tracking_state.get_companion_position_override(_companion_pos)
		_companion_motion_state.pos = _companion_pos
		_update_companion_facing_after_motion(prev_pos)
		return
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.update(
		delta,
		owner,
		_companion_skill_state.windup_active,
		_get_current_defense_rate(),
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style(),
		_get_current_appearance_rate()
	)
	_companion_pos = _companion_motion_state.pos
	_update_companion_facing_after_motion(prev_pos)


func _resume_companion_motion_after_ring_dash(owner: Object) -> void:
	if _companion_motion_state.resume_sortie_loiter_from_current(
		owner,
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	):
		_companion_pos = _companion_motion_state.pos


func _initialize_companion_patrol(owner: Object, randomize_x: bool) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.initialize(
		owner,
		randomize_x,
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	)
	_companion_pos = _companion_motion_state.pos
	_set_companion_facing_from_patrol_dir()


func _restore_companion_patrol(snapshot: Dictionary) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.restore(
		snapshot,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	)
	_companion_pos = _companion_motion_state.pos
	_set_companion_facing_from_patrol_dir()


func _reset_companion_patrol() -> void:
	_companion_motion_state.reset()
	_companion_pos = Vector2.ZERO
	_companion_facing_left = false


func _reset_companion_defense() -> void:
	_companion_motion_state.reset_defense()


func _update_companion_facing_after_motion(prev_pos: Vector2) -> void:
	# Flip the walk-sheet mirror only when Maribo VISIBLY travels left/right. Using
	# actual dx (not patrol_dir) holds the facing through pauses and reverse-and-
	# pause decisions, so the held spear no longer snaps sides while standing still.
	# The one exception is first spawn/restore from Vector2.ZERO: that "movement"
	# is a placement jump, not horizontal travel, so seed the latch from the real
	# patrol direction instead of forcing a right-facing frame.
	if _companion_pos == Vector2.ZERO:
		return
	if prev_pos == Vector2.ZERO:
		_set_companion_facing_from_patrol_dir()
		return
	var dx: float = _companion_pos.x - prev_pos.x
	if absf(dx) > 0.05:
		_companion_facing_left = dx < 0.0


func _set_companion_facing_from_patrol_dir() -> void:
	var patrol_dir: float = float(_companion_motion_state.patrol_dir)
	if absf(patrol_dir) <= 0.01:
		return
	_companion_facing_left = patrol_dir < 0.0


func _resolve_companion_ball_hit(owner: Object, registry: Object = null, captured_affinity_hit_tags: Dictionary = {}) -> bool:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		_companion_body_hit_state.ball_was_inside = false
		return false
	if _is_companion_body_hit_suppressed(_get_current_skill_id()):
		_companion_body_hit_state.ball_was_inside = false
		return false
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	if not _is_companion_body_available_for_hit():
		_companion_body_hit_state.ball_was_inside = false
		return false

	var affinity_hit_tags := _merge_affinity_hit_tags(captured_affinity_hit_tags, _capture_affinity_hit_tags())
	var hit_result: Dictionary = _companion_body_hit_state.resolve_ball_hit(
		owner,
		registry,
		_companion_pos,
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_hit_gauge_gain(),
		_state == STATE_COMPANION,
		_companion_sprite_animator.strike_active
	)
	if not bool(hit_result.get("hit", false)):
		return false
	_add_affinity_points(_pet_id, LingpetAffinityState.SOURCE_BALL_HIT, affinity_hit_tags, registry)

	# If the anticipatory predictor already started the swing for this approach,
	# leave it running (do NOT restart -- mirrors boss trigger_hit's hit_active
	# early-return). Only if the prediction missed do we fall back to a reactive
	# strike entering at the thrust apex so the spear still snaps on contact.
	if bool(hit_result.get("should_begin_strike", false)):
		_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_IMPACT_FRAME)
	_afterglow_leak_state.spawn_from_hit(_companion_body_hit_state.last_contact_pos, _get_current_passive_skill(), _state == STATE_COMPANION)
	# Guard against a boss skill that owns the ball each frame (e.g. Dalji's
	# 상모돌리기 whip forces the ball downward via update_ball_motion). Notify it
	# like a player-paddle guard so it stops controlling the ball; otherwise the
	# whip re-forces the ball down next frame and the companion bounce is ignored.
	return true


func _update_companion_skill_effects(delta: float, owner: Object, registry: Object = null) -> void:
	var skill_id := _get_current_skill_id()
	var decision: Dictionary = _companion_skill_controller.update(delta, {
		"state": _state,
		"companion_state": STATE_COMPANION,
		"owner": owner,
		"registry": registry,
		"skill_id": skill_id,
		"skill_state": _companion_skill_state,
		"skill_runtime_host": _skill_runtime_host,
		"windup_seconds": _get_current_skill_windup_seconds(),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"switch_transition_active": _switch_transition_state.get_ratio(COMPANION_SWITCH_TRANSITION_SECONDS) > 0.0,
		"companion_visible": _companion_motion_state.motion_visible,
		"companion_pos": _companion_pos,
		"companion_radius": COMPANION_RADIUS,
	})
	match str(decision.get("action", LingpetCompanionSkillController.ACTION_NONE)):
		LingpetCompanionSkillController.ACTION_ARM:
			_arm_companion_skill(owner, skill_id)
		LingpetCompanionSkillController.ACTION_LAUNCH:
			_launch_companion_skill(owner, registry)
		_:
			pass
	_trigger_companion_skill_strike_if_requested(skill_id)
	_apply_companion_skill_position_override(skill_id)


func _arm_companion_skill(owner: Object, skill_id: String) -> bool:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	return _companion_skill_controller.arm_windup(_companion_skill_state, _skill_runtime_host, skill_id)


func _launch_companion_skill(owner: Object, registry: Object) -> void:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	var skill_id := _get_current_skill_id()
	var current_active_skill := _get_current_active_skill()
	var origin: Vector2 = _skill_runtime_host.get_launch_origin(skill_id, _companion_pos, COMPANION_RADIUS)
	var launched: bool = _companion_skill_controller.complete_launch(
		_companion_skill_state,
		_skill_runtime_host,
		skill_id,
		origin,
		float(current_active_skill.get("cooldown", COMPANION_SKILL_COOLDOWN_SECONDS)),
		COMPANION_SKILL_FLASH_SECONDS,
		registry,
		owner,
		{
			"companion_pos": _companion_pos,
			"companion_radius": COMPANION_RADIUS,
			"registry": registry,
			"active_skill_id": str(current_active_skill.get("id", skill_id)),
			"active_skill_level": int(current_active_skill.get("level", _current_profile.active_skill_level)),
			"beam_homing_chance_pct": float(current_active_skill.get("beam_homing_chance_pct", -1.0)),
			"banana_count": float(current_active_skill.get("banana_count", -1.0)),
			"slip_speed": float(current_active_skill.get("slip_speed", -1.0)),
			"stun_duration_seconds": float(current_active_skill.get("stun_duration_seconds", 0.0)),
		}
	)
	if launched and _skill_runtime_host.has_companion_position_override(skill_id):
		_apply_companion_skill_position_override(skill_id)


func _trigger_companion_skill_strike_if_requested(skill_id: String) -> void:
	if not _skill_runtime_host.has_method("consume_companion_strike_request"):
		return
	if bool(_skill_runtime_host.consume_companion_strike_request(skill_id)):
		_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)


func _apply_companion_skill_position_override(skill_id: String) -> void:
	if not _skill_runtime_host.has_companion_position_override(skill_id):
		return
	_companion_pos = _skill_runtime_host.get_companion_position_override(skill_id, _companion_pos)
	_companion_motion_state.pos = _companion_pos


func _is_companion_body_hit_suppressed(skill_id: String) -> bool:
	if not _skill_runtime_host.has_method("suppresses_companion_body_hit"):
		return false
	return bool(_skill_runtime_host.suppresses_companion_body_hit(skill_id))


func _is_companion_body_draw_suppressed(skill_id: String) -> bool:
	if not _skill_runtime_host.has_method("suppresses_companion_body_draw"):
		return false
	return bool(_skill_runtime_host.suppresses_companion_body_draw(skill_id))


func _is_companion_body_available_for_hit() -> bool:
	if _ring_dash_state.has_companion_position_override():
		return not _ring_dash_state.is_companion_visual_hidden()
	if _skill_runtime_host.has_companion_position_override(_get_current_skill_id()):
		return true
	if _starlight_tracking_state.has_companion_position_override():
		return true
	return bool(_companion_motion_state.motion_visible)


func _draw_egg(canvas: CanvasItem, center: Vector2) -> void:
	_egg_renderer.draw_egg(
		canvas,
		center,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.wobble_angle,
		_get_egg_texture_for_hits()
	)


func _get_egg_texture_for_hits() -> Texture2D:
	var visual_key: String = _egg_renderer.get_visual_key_for_hits(_egg_state.hatch_hits, _get_current_required_hits())
	match visual_key:
		"egg_crack_2":
			return _get_current_visual_texture("egg_crack_2", null)
		"egg_crack_1":
			return _get_current_visual_texture("egg_crack_1", null)
		_:
			return _get_current_visual_texture("egg", null)


func _get_companion_draw_motion_speed_ratio() -> float:
	if _skill_runtime_host.has_companion_position_override(_get_current_skill_id()):
		return 1.0
	if _ring_dash_state.has_companion_position_override():
		return 0.0
	if _starlight_tracking_state.has_companion_position_override():
		return 1.0
	if not _companion_motion_state.motion_visible:
		return 0.0
	var speed_ratio: float = maxf(0.0, float(_companion_motion_state.motion_speed_ratio))
	if _get_current_motion_style() != "sortie_flight":
		return speed_ratio
	return maxf(COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO, _companion_motion_state.motion_speed_ratio)


func _draw_companion(canvas: CanvasItem, center: Vector2) -> void:
	_companion_renderer.draw_companion(canvas, center, _companion_draw_context_builder.build_config({
		"companion_active": _state == STATE_COMPANION,
		"radius": COMPANION_RADIUS,
		"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
		"body_hit_state": _companion_body_hit_state,
		"skill_state": _companion_skill_state,
		"switch_state": _switch_transition_state,
		"skill_runtime_host": _skill_runtime_host,
		"current_profile": _current_profile,
		"skill_id": _get_current_skill_id(),
		"skill_flash_seconds": COMPANION_SKILL_FLASH_SECONDS,
		"switch_transition_seconds": COMPANION_SWITCH_TRANSITION_SECONDS,
		"switch_particles": COMPANION_SWITCH_TRANSITION_PARTICLES,
		"animator": _companion_sprite_animator,
		"patrol_pause": _companion_motion_state.patrol_pause,
		"face_left": _companion_facing_left,
		"motion_speed_ratio": _get_companion_draw_motion_speed_ratio(),
		"companion_visible": _is_companion_body_visible_for_draw(),
		# Ghost (free_flight) fade alpha, 0..1. The renderer multiplies the companion
		# sprite + aura by this so rabi fades out/in instead of hard-popping. 1.0 for
		# non-ghost pets (motion state leaves ghost_alpha at 1.0 for them).
		"companion_alpha": _companion_motion_state.ghost_alpha,
		"windup_seconds": _get_current_skill_windup_seconds(),
		"affinity_feedback_state": _affinity_feedback_state,
	}))


func _draw_affinity_feedback(canvas: CanvasItem, center: Vector2) -> void:
	_companion_renderer.draw_affinity_feedback(canvas, center, _companion_draw_context_builder.build_affinity_feedback_config({
		"companion_active": _state == STATE_COMPANION,
		"radius": COMPANION_RADIUS,
		"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
		"affinity_feedback_state": _affinity_feedback_state,
	}))


func _is_companion_body_visible_for_draw() -> bool:
	if _ring_dash_state.is_companion_visual_hidden():
		return false
	return (
		_companion_motion_state.motion_visible
		or _skill_runtime_host.has_companion_position_override(_get_current_skill_id())
		or _ring_dash_state.has_companion_position_override()
		or _starlight_tracking_state.has_companion_position_override()
	)


# Begin the in-battle click-reaction playback if the click landed on the
# patrolling companion. Battle is NOT paused -- the reaction temporarily replaces
# the small SD companion at the same in-field size and fades out on its own.
# playfield_pos is in game/playfield
# coordinates (caller converts the viewport click via the layout render_scale /
# game_offset). Returns true when the click was consumed by the companion.
func try_begin_companion_click_reaction(playfield_pos: Vector2, registry: Object = null) -> bool:
	if _state != STATE_COMPANION:
		return false
	if _companion_pos == Vector2.ZERO:
		return false
	if not _companion_click_reaction_state.can_start_at(playfield_pos, _companion_pos):
		return false
	if _companion_click_reaction_state.is_active():
		_play_click_reaction_audio(registry)
		return true
	_companion_click_reaction_state.start()
	if _can_grant_click_affinity():
		_add_affinity_points(_pet_id, LingpetAffinityState.SOURCE_CLICK, {}, registry)
	_play_click_reaction_audio(registry)
	return true


func _play_click_reaction_audio(registry: Object = null) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var audio: Object = registry.get_instance("game_audio")
	if audio != null and audio.has_method("play_lingpet_click_reaction"):
		audio.play_lingpet_click_reaction(_pet_id)


func _play_acquire_click_reaction_backing_audio(registry: Object = null) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var audio: Object = registry.get_instance("game_audio")
	if audio != null and audio.has_method("play_lingpet_acquire_click_reaction_backing"):
		audio.play_lingpet_acquire_click_reaction_backing()


func is_companion_click_reaction_active() -> bool:
	return _companion_click_reaction_state.is_active()


func handle_score_event(scoring_side: String, score_result: Dictionary, _deps: Dictionary = {}) -> void:
	var affinity_pet_id := _get_active_affinity_pet_id()
	var registry: Object = _deps.get("registry", null) as Object
	if affinity_pet_id != "":
		# 2026-06-12 design decision: only PLAYER-scored commits pay the +5
		# round reward. A lost point paying affinity read as wrong once the
		# +N popup made the income visible.
		if scoring_side == "player":
			_add_affinity_points(affinity_pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
		if scoring_side == "player" and bool(score_result.get("match_finished", false)):
			_add_affinity_points(affinity_pet_id, LingpetAffinityState.SOURCE_VICTORY, {}, registry)
	if bool(score_result.get("match_finished", false)):
		if scoring_side == "player":
			_settle_affinity_bond_level_ups(registry)
		else:
			_last_affinity_bond_settlement = _affinity_state.discard_pending_bond_level_ups()


func add_affinity_points(source: String, tags: Dictionary = {}, registry: Object = null) -> Dictionary:
	return _add_affinity_points(_pet_id, source, tags, registry)


func reset_affinity_for_new_battle() -> void:
	_affinity_income_tracker.flush_battle_log("battle_reset")
	_affinity_state.reset_for_new_battle()
	_last_affinity_result = {}
	_last_affinity_bond_settlement = {}


func get_affinity_data(pet_id: String = "") -> Dictionary:
	return _affinity_state.get_pet_data(_resolve_affinity_pet_id(pet_id))


func get_affinity_level(pet_id: String = "") -> int:
	return _affinity_state.get_level(_resolve_affinity_pet_id(pet_id))


func get_affinity_points(pet_id: String = "") -> float:
	return _affinity_state.get_points(_resolve_affinity_pet_id(pet_id))


func get_last_affinity_result_for_tests() -> Dictionary:
	return _last_affinity_result.duplicate(true)


func get_last_affinity_bond_settlement_for_tests() -> Dictionary:
	return _last_affinity_bond_settlement.duplicate(true)


func get_affinity_tracked_pet_ids_for_tests() -> Array[String]:
	return _affinity_state.get_tracked_pet_ids()


func debug_add_affinity_points_for_tests(pet_id: String, source: String, tags: Dictionary = {}, registry: Object = null) -> Dictionary:
	return _add_affinity_points(_normalize_pet_id(pet_id), source, tags, registry)


func get_affinity_income_summary_for_tests() -> Dictionary:
	return _affinity_income_tracker.get_summary()


func get_affinity_reward_deck_for_tests(pet_id: String = "") -> Array[Dictionary]:
	return _affinity_state.get_reward_deck(_resolve_affinity_pet_id(pet_id))


func get_affinity_rewards_for_tests(pet_id: String = "") -> Dictionary:
	return _affinity_state.get_cumulative_rewards(_resolve_affinity_pet_id(pet_id))


func _configure_affinity_reward_context(pet_id: String, loadout: Dictionary = {}) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	var active_base_level := int(loadout.get("active_skill_level", 1))
	var passive_base_level := int(loadout.get("passive_skill_level", 1))
	if loadout.is_empty():
		var existing_loadout: Dictionary = _loadout_state.get_loadout(normalized_pet_id)
		active_base_level = int(existing_loadout.get("active_skill_level", active_base_level))
		passive_base_level = int(existing_loadout.get("passive_skill_level", passive_base_level))
	var motion_style: String = _resolve_affinity_motion_style(normalized_pet_id)
	_affinity_state.configure_reward_context(
		normalized_pet_id,
		motion_style,
		active_base_level,
		passive_base_level,
		_get_affinity_reward_seed(normalized_pet_id)
	)


func _get_affinity_reward_seed(pet_id: String) -> int:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return 0
	if not _affinity_reward_seeds_by_pet_id.has(normalized_pet_id):
		_affinity_reward_seeds_by_pet_id[normalized_pet_id] = int(randi() % (LingpetAffinityState.REWARD_DECK_SEED_MOD - 1)) + 1
	return int(_affinity_reward_seeds_by_pet_id.get(normalized_pet_id, 0))


func _resolve_affinity_motion_style(pet_id: String) -> String:
	if pet_id == _pet_id:
		return _current_profile.get_motion_style()
	_affinity_context_profile.set_pet_id(pet_id)
	return _affinity_context_profile.get_motion_style()


func _sync_current_profile_affinity(pet_id: String) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		_current_profile.set_affinity_state(0, LingpetAffinityState.get_empty_reward_counts())
		return
	_configure_affinity_reward_context(normalized_pet_id)
	_current_profile.set_affinity_state(
		_affinity_state.get_level(normalized_pet_id),
		_affinity_state.get_cumulative_rewards(normalized_pet_id)
	)


func _apply_affinity_headstart_from_store(pet_id: String, registry: Object = null) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "" or _affinity_headstart_applied_pet_ids.has(normalized_pet_id):
		return
	var store: Object = _get_affinity_store(registry)
	if store == null or not store.has_method("get_best_level"):
		return
	var best_level := clampi(int(store.get_best_level(normalized_pet_id)), 0, LingpetAffinityState.MAX_LEVEL)
	if best_level <= 0:
		_affinity_headstart_applied_pet_ids[normalized_pet_id] = true
		return
	var level_before: int = _affinity_state.get_level(normalized_pet_id)
	_configure_affinity_reward_context(normalized_pet_id)
	_affinity_state.apply_headstart_from_best(normalized_pet_id, best_level)
	var level_after: int = _affinity_state.get_level(normalized_pet_id)
	_affinity_headstart_applied_pet_ids[normalized_pet_id] = true
	if normalized_pet_id == _pet_id:
		_sync_current_profile_affinity(normalized_pet_id)
		_affinity_feedback_state.sync_for_level(level_after, LingpetAffinityState.MAX_LEVEL)
		if level_after != level_before:
			_invalidate_current_loadout_cache()


func _record_affinity_best_level_if_needed(pet_id: String, best_before: int, registry: Object = null) -> void:
	var best_after: int = _affinity_state.get_best_level(pet_id)
	if best_after <= best_before:
		return
	var store: Object = _get_affinity_store(registry)
	if store == null or not store.has_method("set_best_level"):
		return
	store.set_best_level(pet_id, best_after)


func _settle_affinity_bond_level_ups(registry: Object = null) -> void:
	_last_affinity_bond_settlement = _affinity_state.settle_bond_level_ups_for_victory()
	var store: Object = _get_affinity_store(registry)
	if store == null or not store.has_method("add_bond_levels"):
		return
	var settled: Dictionary = _last_affinity_bond_settlement.get("settled", {}) as Dictionary
	for raw_pet_id in settled.keys():
		var pet_id := str(raw_pet_id)
		var amount := int(settled.get(raw_pet_id, 0))
		if amount > 0:
			store.add_bond_levels(pet_id, amount)


func _get_affinity_store(registry: Object = null) -> Object:
	if _affinity_store_override != null:
		return _affinity_store_override
	if registry == null or not registry.has_method("get_instance"):
		return null
	var store: Object = registry.get_instance("lingpet_affinity_store")
	return store


func _add_affinity_points(pet_id: String, source: String, tags: Dictionary = {}, registry: Object = null) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		_last_affinity_result = {}
		return {}
	_configure_affinity_reward_context(normalized_pet_id)
	var best_before: int = _affinity_state.get_best_level(normalized_pet_id)
	_last_affinity_result = _affinity_state.add_points(normalized_pet_id, source, tags)
	_affinity_income_tracker.record(normalized_pet_id, source, _last_affinity_result, registry)
	if normalized_pet_id == _pet_id and _state == STATE_COMPANION:
		# Blocked / capped grants report granted_points 0 and must not popup.
		_affinity_feedback_state.trigger_point_gain(float(_last_affinity_result.get("granted_points", 0.0)))
	if normalized_pet_id == _pet_id and int(_last_affinity_result.get("levels_gained", 0)) > 0:
		var level_after: int = _affinity_state.get_level(normalized_pet_id)
		_sync_current_profile_affinity(normalized_pet_id)
		_invalidate_current_loadout_cache()
		_affinity_feedback_state.trigger_level_up(level_after, LingpetAffinityState.MAX_LEVEL, _affinity_next_label_for_pet(normalized_pet_id))
	_record_affinity_best_level_if_needed(normalized_pet_id, best_before, registry)
	return _last_affinity_result.duplicate(true)


func _resolve_affinity_pet_id(pet_id: String) -> String:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id != "":
		return normalized_pet_id
	return _pet_id


func _get_active_affinity_pet_id() -> String:
	if _state != STATE_COMPANION:
		return ""
	return _normalize_pet_id(_pet_id)


func _capture_affinity_hit_tags() -> Dictionary:
	return {
		"defense_intercept": bool(_companion_motion_state.defense_intercept_active),
		"ring_dash_block": _ring_dash_state.has_companion_position_override(),
	}


func _merge_affinity_hit_tags(first: Dictionary, second: Dictionary) -> Dictionary:
	return {
		"defense_intercept": bool(first.get("defense_intercept", false)) or bool(second.get("defense_intercept", false)),
		"ring_dash_block": bool(first.get("ring_dash_block", false)) or bool(second.get("ring_dash_block", false)),
	}


func _can_grant_click_affinity() -> bool:
	return bool(_companion_motion_state.motion_visible) and not _ring_dash_state.is_companion_visual_hidden()


func _maybe_arm_companion_strike(owner: Object) -> void:
	if _is_companion_body_hit_suppressed(_get_current_skill_id()):
		_companion_sprite_animator.reset_latch()
		return
	_companion_strike_anticipator.maybe_arm(
		owner,
		_companion_pos,
		_get_current_hit_half_width(),
		_get_current_hit_half_height(),
		_companion_body_hit_state.cooldown,
		_companion_sprite_animator,
		BALL_RADIUS_FALLBACK
	)


func _draw_hatch_flash(canvas: CanvasItem, center: Vector2) -> void:
	_egg_renderer.draw_hatch_flash(canvas, center, _hatch_flash_timer)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
