extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAcquireCutinAssetPrewarmState := preload("res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd")
const LingpetAcquireCutinOverlayHostResolver := preload("res://scripts/lingpet/lingpet_acquire_cutin_overlay_host_resolver.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const LingpetAfterglowLeakState := preload("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
const LingpetRingDashState := preload("res://scripts/lingpet/lingpet_ring_dash_state.gd")
const LingpetRingDashVfx := preload("res://scripts/lingpet/lingpet_ring_dash_vfx.gd")
const LingpetGhostBlinkVfx := preload("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
const LingpetGuardianTransitionState := preload(
	"res://scripts/lingpet/lingpet_guardian_transition_state.gd"
)
const LingpetStarlightTrackingState := preload("res://scripts/lingpet/lingpet_starlight_tracking_state.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetSpiritWaterDropState := preload("res://scripts/lingpet/lingpet_spirit_water_drop_state.gd")
const GuardianEggAccessPolicy := preload("res://scripts/lingpet/guardian_egg_access_policy.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionClickReactionState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
const LingpetCompanionClickReactionDrawSizeResolver := preload("res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd")
const LingpetCompanionClickReactionVisualPrewarmState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_visual_prewarm_state.gd")
const LingpetCompanionBodyPresenceResolver := preload("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
const LingpetCompanionPlayerBlockResolver := preload("res://scripts/lingpet/lingpet_companion_player_block_resolver.gd")
const LingpetCompanionRuntimeResetter := preload("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetGuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)
const LingpetGuardianEnhanceApplier := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_applier.gd"
)
const LingpetGuardianEnhanceCutinState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)
const LingpetGuardianEnhanceCutinOverlayHostResolver := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_overlay_host_resolver.gd"
)
const LingpetDurationRuntimeState := preload(
	"res://scripts/lingpet/lingpet_duration_runtime_state.gd"
)
const LingpetAffinityContextCoordinator := preload("res://scripts/lingpet/lingpet_affinity_context_coordinator.gd")
const LingpetAffinityHitTagResolver := preload("res://scripts/lingpet/lingpet_affinity_hit_tag_resolver.gd")
const LingpetAffinityFeedbackState := preload("res://scripts/lingpet/lingpet_affinity_feedback_state.gd")
const LingpetAudioDispatcher := preload("res://scripts/lingpet/lingpet_audio_dispatcher.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetCurrentLoadoutApplier := preload("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
const LingpetCurrentPetTransition := preload("res://scripts/lingpet/lingpet_current_pet_transition.gd")
const LingpetCurrentVisualPrewarmCoordinator := preload("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionDistanceRollState := preload("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetActiveSkillSlotResolver := preload("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd")
const LingpetCompanionSkillVisualResolver := preload("res://scripts/lingpet/lingpet_companion_skill_visual_resolver.gd")
const LingpetCompanionSkillPersistence := preload("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetCompanionSkillController := preload("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
const LingpetCompanionSkillLaunchPayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
const LingpetCompanionStrikeAnticipator := preload("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetDebugStatOverrideState := preload("res://scripts/lingpet/lingpet_debug_stat_override_state.gd")
const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")
const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
const LingpetItemEggAbsorbRouter := preload("res://scripts/lingpet/lingpet_item_egg_absorb_router.gd")
const LingpetItemEggAbsorbVfx := preload("res://scripts/lingpet/lingpet_item_egg_absorb_vfx.gd")
const LingpetItemEggLifecycleState := preload("res://scripts/lingpet/lingpet_item_egg_lifecycle_state.gd")
const LingpetEffectTextResolver := preload("res://scripts/lingpet/lingpet_effect_text_resolver.gd")
const LingpetHatchStatRollState := preload("res://scripts/lingpet/lingpet_hatch_stat_roll_state.gd")
const LingpetLoadoutState := preload("res://scripts/lingpet/lingpet_loadout_state.gd")
const LingpetNoneOwnerSyncState := preload("res://scripts/lingpet/lingpet_none_owner_sync_state.gd")
const LingpetOverflowChoiceState := preload("res://scripts/lingpet/lingpet_overflow_choice_state.gd")
const LingpetOverflowReleasePlan := preload("res://scripts/lingpet/lingpet_overflow_release_plan.gd")
const LingpetOverflowReplacePlan := preload("res://scripts/lingpet/lingpet_overflow_replace_plan.gd")
const LingpetPlazaResonanceEggSummaryBuilder := preload("res://scripts/lingpet/lingpet_plaza_resonance_egg_summary_builder.gd")
const LingpetPerfProbe := preload("res://scripts/lingpet/lingpet_perf_probe.gd")
const LingpetRuntimeSnapshotBuilder := preload("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
const LingpetRuntimeVectorResolver := preload("res://scripts/lingpet/lingpet_runtime_vector_resolver.gd")
const LingpetProfileRuntimeSurface := preload("res://scripts/lingpet/lingpet_profile_runtime_surface.gd")
const LingpetRoundResetter := preload("res://scripts/lingpet/lingpet_round_resetter.gd")
const LingpetSaveRestoreApplier := preload("res://scripts/lingpet/lingpet_save_restore_applier.gd")
const LingpetSaveRestorePlanner := preload("res://scripts/lingpet/lingpet_save_restore_planner.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetSkillRuntimeSurface := preload("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
const LingpetTutorialBootstrap := preload("res://scripts/lingpet/lingpet_tutorial_bootstrap.gd")
const LingpetUnlockLoadoutReconciler := preload("res://scripts/lingpet/lingpet_unlock_loadout_reconciler.gd")
# Lingpet field/cutin/companion visuals are resolved through LingpetCurrentProfile,
# which routes every visual key through the catalog-backed visual texture cache.

const PET_ID := LingpetCurrentProfile.DEFAULT_PET_ID
const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const REQUIRED_HITS := 1
const BALL_RADIUS_FALLBACK := 14.3
const SAVE_SNAPSHOT_VERSION := 2
const COMPANION_RADIUS := 16.0
const DEFAULT_SKILL_LEVEL := 1
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
const COMPANION_SKILL_SHARED_COOLDOWN_SECONDS := 10.0
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
const DURATION_WARNING_STAGE_COUNT := 3
const GUARDIAN_MIN_SUMMON_SECONDS := 6.0
# Runs from live companion physics, so it must not inherit the loading-screen
# short expiry that demotes a slow threaded texture to a sync main-thread load.
const CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC := 0
const CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS := 0
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
var _afterglow_leak_state: Object = LingpetAfterglowLeakState.new()
var _ring_dash_state: Object = LingpetRingDashState.new()
var _ring_dash_vfx: Object = LingpetRingDashVfx.new()
# Owns free-flight visibility edge latching so the blink "pong" VFX fires once per transition.
var _ghost_blink_vfx: Object = LingpetGhostBlinkVfx.new()
var _guardian_transition_state: Object = LingpetGuardianTransitionState.new()
var _starlight_tracking_state: Object = LingpetStarlightTrackingState.new()
var _mount_state: Object = preload("res://scripts/lingpet/lingpet_mount_state.gd").new()
var _companion_body_hit_state: Object = LingpetCompanionBodyHitState.new()
var _companion_body_presence_resolver: Object = LingpetCompanionBodyPresenceResolver.new()
var _companion_player_block_resolver: Object = LingpetCompanionPlayerBlockResolver.new()
var _companion_runtime_resetter: Object = LingpetCompanionRuntimeResetter.new()
var _collection_state: Object = LingpetCollectionState.new()
var _spirit_water_drop_state: Object = LingpetSpiritWaterDropState.new()
var _current_profile: Object = LingpetCurrentProfile.new()
# F7 debug-only stat overrides live in LingpetDebugStatOverrideState.
var _debug_stat_overrides: Object = LingpetDebugStatOverrideState.new()
# F7 debug-only defense-rate override. < 0 means "use the pet's catalog/profile
# value"; >= 0 forces that defense_rate for feel testing. Sticky across rounds so
# the override can be evaluated over a whole match; only the F7 picker writes it.
# F7 debug-only appearance-rate override (flight-style only). Same contract as the
# defense override: < 0 = use catalog/profile, >= 0 forces the value.
# F7 debug-only move-speed override. < 0 = use catalog/profile speed; >= 0 is a
# MULTIPLIER applied on top of the final (affinity/passive-included) patrol speed.
# Unlike defense/appearance this has NO motion-style gate — it scales every
# patrol_speed_* read so it reaches movement for any pet (caveat: flight pets use
# hardcoded sortie/ghost speeds so the felt effect is small). Only the F7 picker writes it.
var _companion_draw_context_builder: Object = LingpetCompanionDrawContextBuilder.new()
var _companion_renderer: Object = LingpetCompanionRenderer.new()
var _companion_sprite_animator: Object = LingpetCompanionSpriteAnimator.new()
var _companion_strike_anticipator: Object = LingpetCompanionStrikeAnticipator.new()
var _companion_skill_state: Object = LingpetCompanionSkillState.new()
var _companion_second_skill_state: Object = LingpetCompanionSkillState.new()
var _companion_skill_states: Array[Object] = []
# Cooldowns and windups are per-slot, but the trigger count seeds companion
# motion and therefore remains shared across whichever active slot launched.
var _active_skill_slot_resolver: Object = LingpetActiveSkillSlotResolver.new()
var _companion_skill_visual_resolver: Object = LingpetCompanionSkillVisualResolver.new()
var _companion_skill_persistence: Object = LingpetCompanionSkillPersistence.new()
var _companion_skill_controller: Object = LingpetCompanionSkillController.new()
var _companion_skill_launch_payload_builder: Object = LingpetCompanionSkillLaunchPayloadBuilder.new()
var _skill_runtime_host: Object = LingpetSkillRuntimeHost.new()
var _skill_runtime_surface: Object = LingpetSkillRuntimeSurface.new()
var _snapshot_builder: Object = LingpetRuntimeSnapshotBuilder.new()
var _runtime_snapshot_cache: Dictionary = {}
var _runtime_snapshot_cache_valid := false
var _runtime_snapshot_cache_revision := -1
var _runtime_snapshot_cache_process_frame := -1
var _runtime_snapshot_cache_physics_frame := -1
var _runtime_snapshot_revision := 0
var _runtime_snapshot_build_count_for_tests := 0
var _rail_card_surface_cache: Dictionary = {}
var _rail_card_surface_cache_valid := false
var _rail_card_surface_cache_process_frame := -1
var _rail_card_surface_cache_physics_frame := -1
var _rail_card_surface_build_count_for_tests := 0
var _rail_card_static_surface_cache: Dictionary = {}
var _rail_card_static_surface_key: Array = []
var _rail_card_static_surface_build_count_for_tests := 0
var _vector_resolver: Object = LingpetRuntimeVectorResolver.new()
var _profile_runtime_surface: Object = LingpetProfileRuntimeSurface.new()
var _save_restore_applier: Object = LingpetSaveRestoreApplier.new()
var _save_restore_planner: Object = LingpetSaveRestorePlanner.new()
var _acquire_cutin_asset_prewarm_state: Object = LingpetAcquireCutinAssetPrewarmState.new()
var _acquire_cutin_overlay_host_resolver: Object = LingpetAcquireCutinOverlayHostResolver.new()
var _acquire_cutin_state: Object = LingpetAcquireCutinState.new()
var _switch_transition_state: Object = LingpetCompanionSwitchState.new()
var _companion_click_reaction_state: Object = LingpetCompanionClickReactionState.new()
var _companion_click_reaction_draw_size_resolver: Object = LingpetCompanionClickReactionDrawSizeResolver.new()
var _companion_click_reaction_visual_prewarm_state: Object = LingpetCompanionClickReactionVisualPrewarmState.new()
var _current_visual_prewarm_coordinator: Object = LingpetCurrentVisualPrewarmCoordinator.new()
var _current_loadout_applier: Object = LingpetCurrentLoadoutApplier.new()
var _loadout_state: Object = LingpetLoadoutState.new()
var _plaza_resonance_egg_summary_builder: Object = LingpetPlazaResonanceEggSummaryBuilder.new()
var _perf_probe: Object = LingpetPerfProbe.new()
var _round_resetter: Object = LingpetRoundResetter.new()
var _tutorial_bootstrap: Object = LingpetTutorialBootstrap.new()
var _unlock_loadout_reconciler: Object = LingpetUnlockLoadoutReconciler.new()
var _affinity_state: Object = LingpetAffinityState.new()
var _affinity_context_coordinator: Object = LingpetAffinityContextCoordinator.new()
var _affinity_hit_tag_resolver: Object = LingpetAffinityHitTagResolver.new()
var _affinity_feedback_state: Object = LingpetAffinityFeedbackState.new()
var _duration_runtime_state: Object = LingpetDurationRuntimeState.new()
var _guardian_stowed := false
var _soul_summon_offer_guarantee_count := 0
var _soul_summon_offer_cooldown_screens := 0
var _soul_summon_offer_pending_choice := false
var _soul_summon_overflow_available_for_tests := true
var _guardian_enhance_offer_engine: Object = LingpetGuardianEnhanceOfferEngine.new()
var _guardian_enhance_roll_rng_for_tests: RandomNumberGenerator = null
var _guardian_enhance_last_result: Dictionary = {}
var _guardian_enhance_cutin_state: Object = LingpetGuardianEnhanceCutinState.new()
var _guardian_enhance_cutin_prewarm_state: Object = LingpetAcquireCutinAssetPrewarmState.new()
var _guardian_enhance_cutin_host_resolver: Object = LingpetGuardianEnhanceCutinOverlayHostResolver.new()
var _guardian_active_elapsed := 0.0
var _duration_warning_stage := 0
var _duration_roll_rng_for_tests: RandomNumberGenerator = null
var _hatch_stat_roll_state: Object = LingpetHatchStatRollState.new()
# Shell-break cinematic sequencer: the final counted egg hit no longer opens the
# acquire cut-in on the same frame. Instead the egg runs the 1.5s scripted
# shell-break (roll / staged cracks / light leak, state-owned motion), the shell
# bursts (hatch flash + shard burst), holds briefly so the burst reads, and only
# THEN commits the deferred hatch (_finish_regular_hatch / _begin_overflow_hatch)
# which opens the cut-in. Battle physics is paused for the whole window via the
# modal gate (is_hatch_break_active), so the clock advances from the frame
# controller's ungated idle pump via advance_hatch_break() -- mirrors the
# acquire cut-in's own pump contract.
const HATCH_BREAK_BURST_HOLD_SECONDS := 0.45
const HATCH_PENDING_KIND_REGULAR := "regular"
const HATCH_PENDING_KIND_OVERFLOW := "overflow"
var _hatch_break_pending_kind := ""
var _hatch_break_burst_hold := 0.0
var _audio_dispatcher: Object = LingpetAudioDispatcher.new()
var _current_pet_transition: Object = LingpetCurrentPetTransition.new()
# Distance-roll state owns frame-to-frame drawn-position movement so override-held
# companions read idle instead of marching in place.
var _companion_distance_roll_state: Object = LingpetCompanionDistanceRollState.new()
var _none_owner_sync_state: Object = LingpetNoneOwnerSyncState.new()
var _overflow_choice_state: Object = LingpetOverflowChoiceState.new()
var _overflow_release_plan: Object = LingpetOverflowReleasePlan.new()
var _overflow_replace_plan: Object = LingpetOverflowReplacePlan.new()
# Coexisting incubator egg: when the lingpet_egg active item is used while a companion
# is ALREADY on field, a SEPARATE egg incubates alongside the companion (the companion
# keeps accompanying the player + stays in the panel). On hatch the new pet is NOT made
# the companion -- it dissolves into digital energy, is absorbed into the player
# (_item_egg_absorb_vfx), and is registered into a free collection battle slot. This is
# fully independent of _state/_pet_id/the active companion. See deploy_egg_from_item.
var _item_egg_lifecycle_state: Object = LingpetItemEggLifecycleState.new()
var _item_egg_absorb_router: Object = LingpetItemEggAbsorbRouter.new()
var _item_egg_state: Object = LingpetEggFieldState.new()
var _item_egg_absorb_vfx: Object = LingpetItemEggAbsorbVfx.new()
# On hatch the incubator pet is FIRST revealed through the same acquire cut-in (획득 라투디)
# + click reaction (클릭 라투디) as a first-acquisition hatch -- the companion is briefly
# suspended so the cut-in shows the NEW pet -- and only THEN absorbed into a collection
# slot, restoring the companion. _awaiting_absorb spans the reveal; _absorb_ready fires the
# absorb on the next update(owner) after the cut-in dismisses (owner-bearing path).
# The lifecycle helper owns the dedicated profile for the coexist incubator egg.
func _init() -> void:
	_companion_skill_states = [_companion_skill_state, _companion_second_skill_state]
	_companion_skill_persistence.sync_shared_trigger_count(_companion_skill_states)
	_companion_skill_controller.configure(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_skill_runtime_surface,
		COMPANION_SKILL_WINDUP_SECONDS,
		COMPANION_RADIUS
	)


# physics.callback.lingpet.update measured ~1.0ms/tick standing as an opaque
# leaf, so every phase below carries a physics.lingpet.* label — keep the
# label set gap-free or the standing cost hides between labels again.
func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	_invalidate_runtime_snapshot_cache()
	_companion_skill_persistence.maybe_reset_runtime_transients_for_stage(
		int(BattleSceneOwnerReader.get_value(owner, "current_stage", _companion_skill_persistence.get_last_seen_stage())),
		_companion_skill_states,
		_skill_runtime_host,
		owner,
		registry
	)
	var perf_logger: Object = _perf_probe.get_runtime_logger(registry)
	var sample_start: int = _perf_probe.begin(perf_logger)
	_switch_transition_state.advance(delta)
	var completed_guardian_transition: String = str(_guardian_transition_state.advance(delta))
	if completed_guardian_transition == LingpetGuardianTransitionState.MODE_SUMMON:
		_complete_guardian_summon_transition(owner, registry)
	_egg_state.advance(delta)
	_item_egg_state.advance(delta)
	if _item_egg_absorb_vfx.has_visible_effects():
		_item_egg_absorb_vfx.advance(
			delta,
			_vector_resolver.get_owner_player_paddle_center(owner, _item_egg_state.pos)
		)
	var guardian_summoned := _is_guardian_summoned()
	if guardian_summoned:
		_companion_body_hit_state.advance(delta)
	_companion_skill_persistence.advance_states(delta, _companion_skill_states, guardian_summoned)
	_companion_skill_persistence.advance_stored_cooldowns(
		delta,
		_pet_id,
		guardian_summoned,
		_companion_skill_states.size()
	)
	if guardian_summoned:
		_companion_sprite_animator.advance(delta)
		_companion_click_reaction_state.advance(delta)
		_affinity_feedback_state.advance(delta)
	_perf_probe.end(perf_logger, "physics.lingpet.advance", sample_start)

	# Incubator-egg reveal cut-in has dismissed: restore the companion + absorb the new pet
	# now that the owner is available. Runs before the state dispatch so the companion is
	# already restored for the rest of this tick.
	if _item_egg_lifecycle_state.is_absorb_ready():
		_perform_item_egg_absorb(owner, registry)

	if _state == STATE_NONE:
		sample_start = _perf_probe.begin(perf_logger)
		var none_changed: bool = bool(_none_owner_sync_state.update_none_state(
			owner,
			registry,
			_collection_state,
			self
		))
		_perf_probe.end(perf_logger, "physics.lingpet.none_state", sample_start)
		return none_changed

	if _state == STATE_EGG:
		# The shell-break sequencer owns the egg between the final hit and the
		# acquire cut-in (the modal gate holds battle physics; advance_hatch_break
		# is pumped from the ungated idle path). Guard here too so a stray gated
		# tick cannot fight the scripted roll or re-resolve the already-hatched egg.
		if is_hatch_break_active():
			return false
		sample_start = _perf_probe.begin(perf_logger)
		var egg_phase_part_start: int = _perf_probe.begin(perf_logger)
		_egg_state.update_player_contact(delta, owner, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.contact", egg_phase_part_start)
		# Stream the heavy acquire cut-in sheets (8192px+ Live2D anim/dismiss) into the
		# texture cache across the calm egg-wait frames, BEFORE the egg hatches. The
		# reveal is only REVEAL_SECONDS (1.4s) long, so a cold draw-time stream cannot
		# always finish in time and the cut-in falls back to the static 원화 still. A
		# head start here lets the cut-in open already showing the Live2D animation.
		egg_phase_part_start = _perf_probe.begin(perf_logger)
		_acquire_cutin_asset_prewarm_state.prewarm_registry_step(
			_acquire_cutin_state.get_display_pet_id(_pet_id),
			registry,
			_acquire_cutin_overlay_host_resolver,
			perf_logger,
			"physics.lingpet.egg_phase.cutin_prewarm"
		)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.cutin_prewarm", egg_phase_part_start)
		egg_phase_part_start = _perf_probe.begin(perf_logger)
		var changed: bool = _resolve_ball_hit(owner, registry, perf_logger)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.hatch_resolve", egg_phase_part_start)
		egg_phase_part_start = _perf_probe.begin(perf_logger)
		_sync_owner(owner, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.owner_sync", egg_phase_part_start)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase", sample_start)
		return changed

	if _state == STATE_COMPANION:
		sample_start = _perf_probe.begin(perf_logger)
		_companion_click_reaction_visual_prewarm_state.prewarm_step(
			true,
			_pet_id,
			_current_profile,
			LingpetCompanionClickReactionState.PREWARM_VISUAL_KEYS,
			CLICK_REACTION_TEXTURE_PREWARM_MAX_MSEC,
			CLICK_REACTION_TEXTURE_PREWARM_MAX_POLLS
		)
		if not _loadout_state.has_applied_runtime_cache():
			_apply_current_loadout(owner, true, false, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.prewarm_step", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		_advance_duration_pool(delta, owner, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.duration", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		var starlight_passive_skill: Dictionary = _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetStarlightTrackingState.PASSIVE_ID)
		# A stowed guardian folds companion_active false so position-owning
		# passives self-reset without learning duration policy.
		_starlight_tracking_state.advance(delta, starlight_passive_skill, guardian_summoned, _companion_pos)
		_ring_dash_vfx.advance(delta)
		_ghost_blink_vfx.advance(delta)
		_perf_probe.end(perf_logger, "physics.lingpet.vfx_states", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		var affinity_hit_tags: Dictionary = _affinity_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
		if guardian_summoned:
			_update_companion_motion(delta, owner, registry)
		else:
			_companion_body_hit_state.ball_was_inside = false
		_perf_probe.end(perf_logger, "physics.lingpet.companion_motion", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		affinity_hit_tags = _affinity_hit_tag_resolver.merge(
			affinity_hit_tags,
			_affinity_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
		)
		_ghost_blink_vfx.sync_visibility(
			guardian_summoned and _profile_runtime_surface.get_motion_style(_current_profile) == "free_flight",
			bool(_companion_motion_state.motion_visible),
			_companion_pos
		)
		if not guardian_summoned:
			_companion_sprite_animator.reset_latch()
		else:
			_companion_strike_anticipator.maybe_arm_from_sources(
				owner,
				_companion_pos,
				_current_profile,
				_companion_body_hit_state,
				_companion_sprite_animator,
				_skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host),
				_active_skill_slot_resolver,
				_companion_skill_visual_resolver,
				_skill_runtime_surface,
				_skill_runtime_host,
				BALL_RADIUS_FALLBACK,
				COMPANION_HIT_HALF_WIDTH * 2.0,
				COMPANION_HIT_HALF_HEIGHT * 2.0
			)
		_perf_probe.end(perf_logger, "physics.lingpet.strike_arm", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		if guardian_summoned:
			_resolve_companion_ball_hit(owner, registry, affinity_hit_tags)
		# Stream the NEW pet's heavy acquire cut-in sheets into the cache DURING incubation
		# (the companion's _pet_id would otherwise prewarm the wrong pet), so the reveal opens
		# already animated instead of holding on the static fallback.
		var item_egg_pet_id := str(_item_egg_lifecycle_state.get_pet_id())
		if _item_egg_lifecycle_state.is_active() and item_egg_pet_id != "":
			_acquire_cutin_asset_prewarm_state.prewarm_registry_step(
				item_egg_pet_id,
				registry,
				_acquire_cutin_overlay_host_resolver
			)
		var hatched_item_egg_pet_id := str(_item_egg_lifecycle_state.advance_incubation_for_reveal(
			delta,
			owner,
			registry,
			_item_egg_state,
			REQUIRED_HITS,
			# 코이그지스트 인큐베이터 알도 공에 맞으면 메인 알과 동일한 히트 사운드를 낸다.
			func() -> void: _audio_dispatcher.play_lingpet_egg_hit(registry)
		))
		if hatched_item_egg_pet_id != "":
			_acquire_cutin_state.start(hatched_item_egg_pet_id)
			_audio_dispatcher.play_lingpet_acquire_cutin(registry)
		_perf_probe.end(perf_logger, "physics.lingpet.ball_hit", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		_afterglow_leak_state.advance(delta, owner, registry, _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetAfterglowLeakState.PASSIVE_ID), guardian_summoned)
		_perf_probe.end(perf_logger, "physics.lingpet.afterglow", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		if guardian_summoned:
			_update_companion_skill_effects(delta, owner, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.skill_effects", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		if guardian_summoned:
			_advance_companion_draw_anim(delta)
		_perf_probe.end(perf_logger, "physics.lingpet.draw_anim", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		_sync_owner(owner, registry)
		_perf_probe.end(perf_logger, "physics.lingpet.owner_sync", sample_start)
	return false


# True when the Pro/Mythic "lingpet_egg" active item should still spawn / be picked up.
# Consumed by the active-item field spawn pool + pickup gate. Allowed while NO lingpet is
# deployed (first acquisition) AND while a companion is already on field (a coexisting
# incubator egg can collect another pet). Blocked only while an egg is mid-incubation
# (STATE_EGG main egg or active coexist egg) so two eggs never incubate at once.
# Junior never offers the item (its lingpet is auto-present).
func begin_soul_summon_offer_screen(already_owned: bool) -> Dictionary:
	if already_owned:
		mark_soul_summon_art_acquired()
		return {"offer_allowed": false, "reserve": false}
	if _soul_summon_offer_pending_choice:
		_soul_summon_offer_pending_choice = false
		if _soul_summon_offer_guarantee_count >= 2:
			_soul_summon_offer_cooldown_screens = 3
	if _soul_summon_offer_cooldown_screens > 0:
		_soul_summon_offer_cooldown_screens -= 1
		return {"offer_allowed": false, "reserve": false}
	if _soul_summon_offer_guarantee_count < 2:
		_soul_summon_offer_guarantee_count += 1
	_soul_summon_offer_pending_choice = true
	return {
		"offer_allowed": true,
		"reserve": true,
		"guarantee_index": _soul_summon_offer_guarantee_count,
	}


func mark_soul_summon_art_acquired() -> void:
	_soul_summon_offer_pending_choice = false
	_soul_summon_offer_cooldown_screens = 0


func get_soul_summon_offer_state_for_tests() -> Dictionary:
	return {
		"guarantee_count": _soul_summon_offer_guarantee_count,
		"cooldown_screens": _soul_summon_offer_cooldown_screens,
		"pending_choice": _soul_summon_offer_pending_choice,
	}


func build_guardian_enhance_offer(owner: Object) -> Dictionary:
	var pet_id := _resolve_guardian_enhance_pet_id(owner)
	if pet_id == "":
		return {
			"offer_allowed": false,
			"reserve": false,
			"blocked_reason": "no_owned_guardian",
			"candidates": [],
		}
	_affinity_context_coordinator.configure(
		pet_id,
		_pet_id,
		_current_profile,
		_loadout_state,
		_affinity_state
	)
	var skill_availability: Dictionary = (
		_affinity_state.get_guardian_enhancement_skill_availability(pet_id)
	)
	var result: Dictionary = _guardian_enhance_offer_engine.build_offer(
		owner,
		_affinity_state.get_pet_data(pet_id),
		_affinity_state.get_duration_increase_count(),
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)
	result["pet_id"] = pet_id
	return result


func apply_guardian_enhance_random_roll(
	candidates: Array,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var pet_id := _resolve_guardian_enhance_pet_id(owner)
	if pet_id == "":
		return {"accepted": false, "modal_started": false, "blocked_reason": "no_owned_guardian"}
	var result := LingpetGuardianEnhanceApplier.resolve_random_roll(
		candidates,
		Callable(self, "can_apply_guardian_enhancement_candidate").bind(pet_id),
		Callable(self, "apply_guardian_enhancement_candidate").bind(owner, registry, pet_id),
		Callable(self, "apply_guardian_enhance_duration_fallback").bind(owner, registry),
		_guardian_enhance_roll_rng_for_tests
	)
	complete_guardian_enhance_roll(result, pet_id, registry)
	return result


func can_apply_guardian_enhancement_candidate(candidate: Dictionary, pet_id: String) -> bool:
	var skill_availability: Dictionary = (
		_affinity_state.get_guardian_enhancement_skill_availability(pet_id)
	)
	return _affinity_state.can_apply_guardian_enhancement(
		pet_id,
		candidate,
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)


func apply_guardian_enhancement_candidate(
	candidate: Dictionary,
	owner: Object = null,
	registry: Object = null,
	pet_id: String = ""
) -> Dictionary:
	var target_pet_id := pet_id.strip_edges().to_lower()
	if target_pet_id == "":
		target_pet_id = _resolve_guardian_enhance_pet_id(owner)
	var skill_availability: Dictionary = (
		_affinity_state.get_guardian_enhancement_skill_availability(target_pet_id)
	)
	var result: Dictionary = _affinity_state.apply_guardian_enhancement(
		target_pet_id,
		candidate,
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)
	if bool(result.get("accepted", false)):
		_affinity_context_coordinator.handle_enhancement_gain(
			target_pet_id,
			registry,
			_pet_id,
			_current_profile,
			_loadout_state,
			_affinity_state,
			_snapshot_builder
		)
		_invalidate_runtime_snapshot_cache()
		_sync_owner(owner, registry)
	return result


func apply_guardian_enhance_duration_fallback(
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var result: Dictionary = _affinity_state.apply_guardian_enhance_duration_fallback()
	if bool(result.get("accepted", false)):
		_invalidate_runtime_snapshot_cache()
		_sync_owner(owner, registry)
	return result


func complete_guardian_enhance_roll(
	result: Dictionary,
	display_pet_id: String,
	registry: Object = null
) -> void:
	if display_pet_id.strip_edges() == "":
		display_pet_id = _pet_id
	_guardian_enhance_last_result = result.duplicate(true)
	if bool(result.get("accepted", false)):
		_guardian_enhance_offer_engine.mark_applied()
		_guardian_enhance_cutin_prewarm_state.reset()
		_guardian_enhance_cutin_prewarm_state.prewarm_registry_step(
			display_pet_id,
			registry,
			_guardian_enhance_cutin_host_resolver
		)
		_guardian_enhance_cutin_state.start(display_pet_id, result)


func is_guardian_enhance_cutin_active() -> bool:
	return bool(_guardian_enhance_cutin_state.active)


func get_guardian_enhance_cutin_snapshot() -> Dictionary:
	return _guardian_enhance_cutin_state.get_snapshot()


func advance_guardian_enhance_cutin(delta: float, registry: Object = null) -> void:
	if not is_guardian_enhance_cutin_active():
		return
	var snapshot: Dictionary = _guardian_enhance_cutin_state.get_snapshot()
	var display_pet_id := str(snapshot.get("pet_id", _pet_id))
	_guardian_enhance_cutin_prewarm_state.prewarm_registry_step(
		display_pet_id,
		registry,
		_guardian_enhance_cutin_host_resolver
	)
	var assets_ready: bool = bool(_guardian_enhance_cutin_host_resolver.is_anim_ready(
		registry,
		display_pet_id
	))
	var animation_contract: Dictionary = (
		_guardian_enhance_cutin_host_resolver.get_animation_contract(
			registry,
			display_pet_id
		)
	)
	var closed := bool(_guardian_enhance_cutin_state.advance(
		delta,
		assets_ready,
		animation_contract
	))
	if closed:
		_stop_guardian_enhance_cutin_audio(registry)


func cancel_guardian_enhance_cutin(registry: Object = null) -> bool:
	var cancelled := bool(_guardian_enhance_cutin_state.cancel_immediate())
	if cancelled:
		_stop_guardian_enhance_cutin_audio(registry)
	return cancelled


func _stop_guardian_enhance_cutin_audio(registry: Object) -> void:
	if registry == null:
		return
	var audio: Variant = null
	if registry.has_method("get_cached_instance"):
		audio = registry.get_cached_instance("game_audio")
	if (typeof(audio) != TYPE_OBJECT or audio == null) and registry.has_method("get_instance"):
		audio = registry.get_instance("game_audio")
	if typeof(audio) == TYPE_OBJECT and audio != null and audio.has_method("stop_lingpet_guardian_enhance_cutin_loop"):
		audio.stop_lingpet_guardian_enhance_cutin_loop()


func set_guardian_enhance_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_guardian_enhance_roll_rng_for_tests = rng


func get_guardian_enhance_offer_state_for_tests() -> Dictionary:
	return _guardian_enhance_offer_engine.get_state_for_tests()


func get_guardian_enhance_last_result_for_tests() -> Dictionary:
	return _guardian_enhance_last_result.duplicate(true)


func _resolve_guardian_enhance_pet_id(owner: Object) -> String:
	_collection_state.sync_from_owner(owner)
	var owned: Array[String] = _collection_state.get_owned_pet_ids_from_owner(owner)
	if owned.is_empty():
		return ""
	var normalized_current: String = _current_profile.normalize_pet_id(_pet_id)
	if normalized_current != "" and owned.has(normalized_current):
		return normalized_current
	var slots: Array[String] = _collection_state.get_battle_slots_from_owner(owner)
	var active_index: int = _collection_state.get_active_slot_index_from_owner(owner)
	if active_index >= 0 and active_index < slots.size():
		var slot_pet: String = _current_profile.normalize_pet_id(str(slots[active_index]))
		if slot_pet != "":
			return slot_pet
	return _current_profile.normalize_pet_id(str(owned[0]))


func can_offer_egg_item(owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	if _state == STATE_EGG or _item_egg_lifecycle_state.has_blocking_incubation():
		return false
	if _acquire_cutin_state.active or _overflow_choice_state.has_pending_or_active():
		return false
	if _collection_state.is_auto_present_league(owner):
		return false
	return _collection_state.has_unowned_pet_candidates(owner)


# Pro/Mythic active-item deploy of a random unowned pet's egg. Two cases:
#   * NO companion yet (STATE_NONE): the egg hatches into the companion (first acquisition),
#     mirroring _spawn_egg minus the junior-only tutorial ring-core grant.
#   * companion ALREADY on field (STATE_COMPANION): a SEPARATE coexisting egg incubates
#     alongside it (the companion is untouched) and the new pet is absorbed into a free
#     collection slot after the lifecycle helper finishes the reveal transition.
# Returns false (so the slot controller does NOT consume the item or start its cooldown —
# see active_item_slot_controller._try_use_slot) when an egg is already incubating, no pet
# can be picked, or the league auto-presents its lingpet.
func deploy_egg_from_item(
	owner: Object,
	registry: Object = null,
	bypass_soul_summon_gate: bool = false
) -> bool:
	if owner == null:
		return false
	_invalidate_runtime_snapshot_cache()
	if not bypass_soul_summon_gate and not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	# Junior auto-presents its single tutorial lingpet, so the egg item must NEVER
	# deploy there. This is the central use-site seal: direct-grant reward paths
	# (Pandora active grant, plaza gacha) deliver via append_item_data, which bypasses
	# store_active_item's _is_lingpet_egg_pickup_redundant / can_offer_egg_item gate and
	# can drop an egg into a junior slot — so the league guard must live HERE too, not
	# only in the offer/spawn/pickup gates (item_runtime_checklist §1.7).
	if _collection_state.is_auto_present_league(owner):
		return false
	# Block while an incubator egg is mid-reveal (cut-in) OR in the gap between the cut-in
	# closing and the deferred absorb running (awaiting/ready) — otherwise a new egg could be
	# deployed before the previous one is absorbed.
	if _acquire_cutin_state.active or _overflow_choice_state.has_pending_or_active():
		return false
	if _item_egg_lifecycle_state.has_pending_absorb():
		return false
	_collection_state.sync_from_owner(owner)
	var pet_id: String = str(_collection_state.pick_random_unowned_pet_id(owner))
	if pet_id == "":
		return false
	_acquire_cutin_asset_prewarm_state.prewarm_registry_step(
		pet_id,
		registry,
		_acquire_cutin_overlay_host_resolver
	)
	# A companion is ALREADY on field: incubate a SEPARATE coexisting egg next to it. The
	# companion keeps accompanying the player and stays in the character-info panel
	# (_state/_pet_id are untouched); on hatch the new pet is absorbed into a collection
	# battle slot rather than replacing the companion. Only one incubator egg can run at a time.
	if _state == STATE_COMPANION:
		if _item_egg_lifecycle_state.is_active():
			return false
		_item_egg_state.spawn(owner)
		_item_egg_absorb_vfx.reset()
		_item_egg_lifecycle_state.begin_incubation(pet_id)
		return true
	# No companion yet (Pro/Mythic first acquisition): the egg itself hatches into the
	# companion, exactly like the auto-present junior egg.
	if _state != STATE_NONE:
		return false
	_state = STATE_EGG
	_reset_hatch_break_sequence()
	_set_current_pet_id(pet_id)
	_apply_companion_position_surface(_companion_runtime_resetter.reset_to_egg_wait(
		_build_companion_runtime_reset_context(owner, registry, true, true)
	))
	_sync_owner(owner, registry)
	return true


func deploy_soul_summon_egg(owner: Object, registry: Object = null) -> Dictionary:
	if owner == null:
		return {"dropped": false, "skipped_reason": "missing_owner"}
	if (
		_state == STATE_EGG
		or _item_egg_lifecycle_state.has_blocking_incubation()
		or _item_egg_lifecycle_state.has_pending_absorb()
		or _acquire_cutin_state.active
		or _overflow_choice_state.has_pending_or_active()
	):
		return {"dropped": false, "skipped_reason": "egg_already_present"}
	_collection_state.sync_from_owner(owner)
	if (
		_collection_state.is_full(owner)
		and (
			not _soul_summon_overflow_available_for_tests
			or _overflow_choice_state == null
			or not _overflow_choice_state.has_method("begin_item_egg_overflow")
		)
	):
		return {"dropped": false, "skipped_reason": "overflow_unavailable"}
	if not _collection_state.has_unowned_pet_candidates(owner):
		return {"dropped": false, "skipped_reason": "no_unowned_pet_candidates"}
	var dropped := deploy_egg_from_item(owner, registry, true)
	return {
		"dropped": dropped,
		"skipped_reason": "" if dropped else "deploy_rejected",
	}


func set_soul_summon_overflow_available_for_tests(available: bool) -> void:
	_soul_summon_overflow_available_for_tests = available


	# Fire the ghost "퐁" pop on the rabi free-flight vanish/appear edges. Only the


func prewarm_assets() -> void:
	_egg_renderer.prewarm()
	_afterglow_leak_state.prewarm()
	_guardian_transition_state.prewarm()
	if _companion_renderer != null:
		_companion_renderer.prewarm_assets()
	_item_egg_absorb_vfx.prewarm()
	_skill_runtime_host.prewarm_many(_skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host))


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, _draw_context: Dictionary = {}) -> void:
	if canvas == null:
		return
	if _state == STATE_COMPANION:
		if _is_guardian_summoned():
			# Star Coil BIND: the orosha coil body wraps the boss, so render it in this post-actor
			# FRONT pass (over the boss) instead of the behind-actors pass — body first, then the
			# skill's own sparks/VFX on top.
			var body_skill_id: String = _skill_runtime_surface.get_body_skill_id(
				_current_profile,
				_active_skill_slot_resolver,
				_companion_skill_visual_resolver,
				_skill_runtime_host,
				_companion_pos
			)
			if _companion_body_presence_resolver.is_front_pass_body_active(
				_state,
				STATE_COMPANION,
				_skill_runtime_surface,
				_skill_runtime_host,
				body_skill_id
			):
				_draw_companion(canvas, _companion_pos + shake_offset)
			_skill_runtime_host.draw(canvas, shake_offset, _perf_probe.get_draw_logger(_draw_context))
			_afterglow_leak_state.draw(canvas, shake_offset)
		# The lingpet BODY (egg sprite / companion sprite) is intentionally NOT drawn
		# here. It renders earlier, BEHIND the player, via draw_lingpet_body_behind_actors()
		# (invoked from the shared player actor renderer). Keeping it out of this
		# post-actor front pass is what makes an overlapping player render in front of the
		# lingpet. Only the companion's emanating VFX stay in front (ring dash / ghost
		# blink / affinity feedback) plus the hatch flash.
		if _is_guardian_summoned() and _ring_dash_vfx.has_visible_effects():
			_ring_dash_vfx.draw(canvas, shake_offset)
		if _ghost_blink_vfx.has_visible_effects():
			_ghost_blink_vfx.draw(canvas, shake_offset)
		if _guardian_transition_state.is_active():
			_guardian_transition_state.draw(canvas, shake_offset)
		if _affinity_feedback_state.has_visible_effects(_is_guardian_summoned()):
			_companion_renderer.draw_affinity_feedback(
				canvas,
				_companion_pos + shake_offset,
				_companion_draw_context_builder.build_affinity_feedback_config({
					"companion_active": _is_guardian_summoned(),
					"radius": COMPANION_RADIUS,
					"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
					"affinity_feedback_state": _affinity_feedback_state,
					"shake_offset": shake_offset,
				})
			)
		if bool(_egg_state.has_hatch_flash()):
			_egg_renderer.draw_hatch_flash(
				canvas,
				_egg_state.pos + shake_offset,
				float(_egg_state.get_hatch_flash_timer()),
				_egg_state.egg_color_index
			)
		# Coexist incubator-egg hatch: the new pet dissolves into digital energy and is
		# absorbed into the player. Front pass so the motes read over the field.
		if _item_egg_absorb_vfx.has_visible_effects():
			_item_egg_absorb_vfx.draw(canvas, shake_offset)


# Draws ONLY the lingpet BODY (egg sprite in STATE_EGG, companion sprite in
# STATE_COMPANION), intended to run BEHIND the player actor. The shared player actor
# renderer invokes this (through a hook the battle scene drawer injects into the actor
# context) right before it draws the player sprite -- after the opaque stage background,
# before the player -- so an overlapping player renders in front of the lingpet. Skill
# VFX, ring-dash / ghost / affinity feedback, and the hatch flash stay in draw() (the
# post-actor front pass). Mirrors the body-draw branches that used to live inside draw().
func draw_lingpet_body_behind_actors(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _state == STATE_EGG:
		if _egg_state.is_hatch_break_active():
			_egg_renderer.draw_hatch_break_egg(
				canvas,
				_egg_state.pos + shake_offset,
				float(_egg_state.get_hatch_break_progress()),
				_egg_state.wobble_angle,
				_egg_state.egg_color_index,
				_egg_state.roll_angle
			)
			return
		if _hatch_break_burst_hold > 0.0:
			# Shell just burst: the body is gone; the shard burst + flash render
			# in the front pass until the deferred hatch commits.
			return
		var required_hits: int = _get_main_egg_required_hits()
		_egg_renderer.draw_egg(
			canvas,
			_egg_state.pos + shake_offset,
			_egg_state.hatch_hits,
			required_hits,
			_egg_state.wobble_angle,
			_egg_state.egg_color_index,
			_egg_state.roll_angle
		)
		return
	if _state != STATE_COMPANION:
		return
	# The coexist incubator egg (deployed via the lingpet_egg item) renders next to the
	# companion, both behind the player, so the companion keeps accompanying the player
	# while the new egg incubates.
	if _item_egg_lifecycle_state.is_active():
		_egg_renderer.draw_profile_egg(
			canvas,
			_item_egg_state.pos + shake_offset,
			_item_egg_state.hatch_hits,
			_get_item_egg_required_hits(),
			_item_egg_state.wobble_angle,
			_item_egg_state.egg_color_index,
			_item_egg_state.roll_angle
		)
	var switch_transition_active: bool = bool(
		_switch_transition_state.get_ratio(COMPANION_SWITCH_TRANSITION_SECONDS) > 0.0
	)
	var guardian_transition_body_active: bool = (
		_guardian_transition_state.is_active()
		and float(_guardian_transition_state.get_companion_alpha()) > 0.0
	)
	if not _is_guardian_summoned() and not switch_transition_active and not guardian_transition_body_active:
		return
	var body_skill_id: String = _skill_runtime_surface.get_body_skill_id(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_skill_runtime_host,
		_companion_pos
	)
	if _skill_runtime_surface.is_companion_body_draw_suppressed(
		_skill_runtime_host,
		body_skill_id
	):
		return
	# Star Coil BIND draws the companion body in the FRONT pass (draw()) so its coils wrap OVER
	# the boss; skip the behind-actors draw here so it does not also render behind the boss.
	if _companion_body_presence_resolver.is_front_pass_body_active(
		_state,
		STATE_COMPANION,
		_skill_runtime_surface,
		_skill_runtime_host,
		body_skill_id
	):
		return
	var click_reaction_texture: Texture2D = null
	if _companion_click_reaction_state.is_active():
		click_reaction_texture = _companion_click_reaction_state.get_ready_texture(_current_profile)
	var click_reaction_visible: bool = _companion_body_presence_resolver.is_click_reaction_visible(
		bool(_companion_click_reaction_state.is_active()),
		click_reaction_texture,
		_ring_dash_state
	)
	if not click_reaction_visible or guardian_transition_body_active:
		_draw_companion(
			canvas,
			_companion_pos + shake_offset,
			float(_guardian_transition_state.get_companion_alpha()) if guardian_transition_body_active else 1.0
		)
	else:
		_companion_click_reaction_state.draw(
			canvas,
			_companion_pos + shake_offset,
			click_reaction_texture,
			_companion_click_reaction_draw_size_resolver.resolve(
				_current_profile,
				float(LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x)
			)
		)


func has_visible_effects() -> bool:
	return (
		_state == STATE_EGG
		or _is_guardian_summoned()
		or _switch_transition_state.get_ratio(COMPANION_SWITCH_TRANSITION_SECONDS) > 0.0
		or bool(_egg_state.has_hatch_flash())
		or _acquire_cutin_state.active
		or _afterglow_leak_state.has_visible_effects()
		or _ring_dash_vfx.has_visible_effects()
		or _ghost_blink_vfx.has_visible_effects()
		or _guardian_transition_state.is_active()
		or _affinity_feedback_state.has_visible_effects(_is_guardian_summoned())
		or _skill_runtime_host.has_visible_effects()
		or _item_egg_lifecycle_state.is_active()
		or _item_egg_absorb_vfx.has_visible_effects()
	)


func get_boss_ai_context() -> Dictionary:
	var runtime_state := STATE_COMPANION if _is_guardian_summoned() else STATE_NONE
	return _skill_runtime_surface.get_boss_ai_context(runtime_state, STATE_COMPANION, _skill_runtime_host)


func get_ball_collision_context() -> Dictionary:
	var runtime_state := STATE_COMPANION if _is_guardian_summoned() else STATE_NONE
	return _skill_runtime_surface.get_ball_collision_context(runtime_state, STATE_COMPANION, _skill_runtime_host)


func notify_lingpet_bone_barrier_hit(
	barrier_id: int,
	impact_pos: Vector2,
	next_ball_vel: Vector2,
	built: bool = true,
	registry: Object = null
) -> bool:
	var handled: bool = bool(_skill_runtime_surface.notify_lingpet_bone_barrier_hit(
		_skill_runtime_host,
		barrier_id,
		impact_pos,
		next_ball_vel,
		built,
		registry
	))
	if handled:
		_invalidate_runtime_snapshot_cache()
	return handled


func reset_skill_effect_update_counters_for_tests() -> void:
	_companion_skill_controller.reset_effect_update_counters_for_tests()


func get_skill_effect_idle_skip_count_for_tests() -> int:
	return int(_companion_skill_controller.get_effect_idle_skip_count_for_tests())


func get_skill_effect_runtime_update_count_for_tests() -> int:
	return int(_companion_skill_controller.get_effect_runtime_update_count_for_tests())


func set_headbutt_force_mega_roll_for_tests(value: float) -> void:
	_skill_runtime_host.set_headbutt_force_mega_roll_for_tests(value)


func is_acquire_cutin_active() -> bool:
	return _acquire_cutin_state.active


# True through the whole shell-break window: the state-scripted break motion
# PLUS the post-burst hold before the deferred hatch commit opens the cut-in.
# The modal gate reads this to hold battle physics (mirrors the cut-in).
func is_hatch_break_active() -> bool:
	return _egg_state.is_hatch_break_active() or _hatch_break_burst_hold > 0.0


# Pumped from the frame controller's ungated idle path while the modal gate
# holds battle physics (mirrors advance_acquire_cutin): drives the scripted
# shell-break motion, bursts the shell on completion, then runs a short hold so
# the shard burst reads before the acquire cut-in covers it.
func advance_hatch_break(delta: float, owner: Object = null, registry: Object = null) -> void:
	if not is_hatch_break_active():
		return
	# Keep streaming the heavy cut-in sheets through the break window too, so the
	# reveal opens on the Live2D animation instead of the static fallback.
	_acquire_cutin_asset_prewarm_state.prewarm_registry_step(
		_acquire_cutin_state.get_display_pet_id(_pet_id),
		registry,
		_acquire_cutin_overlay_host_resolver
	)
	if _egg_state.is_hatch_break_active():
		if _egg_state.advance_hatch_break(delta):
			# Shell burst: destroy the shell visual now; the cut-in waits out the hold.
			_egg_state.trigger_hatch_flash(LingpetEggFieldRenderer.HATCH_FLASH_SECONDS)
			_hatch_break_burst_hold = HATCH_BREAK_BURST_HOLD_SECONDS
			if _hatch_break_burst_hold <= 0.0:
				# A zero-tuned hold must still commit -- otherwise the pump's own
				# is_hatch_break_active() gate would never re-enter and the hatch
				# would strand behind a permanently-held modal gate.
				_commit_pending_hatch(owner, registry)
		return
	# Burst hold: tick the flash while physics is paused, then commit the hatch.
	_egg_state.advance(delta)
	_hatch_break_burst_hold = maxf(0.0, _hatch_break_burst_hold - maxf(0.0, delta))
	if _hatch_break_burst_hold <= 0.0:
		_commit_pending_hatch(owner, registry)


func _commit_pending_hatch(owner: Object, registry: Object = null) -> void:
	var pending_kind := _hatch_break_pending_kind
	_hatch_break_pending_kind = ""
	_hatch_break_burst_hold = 0.0
	if pending_kind == HATCH_PENDING_KIND_OVERFLOW:
		_begin_overflow_hatch(owner, registry)
	elif pending_kind == HATCH_PENDING_KIND_REGULAR:
		_finish_regular_hatch(owner, registry)
	else:
		return
	# The commit runs from the ungated idle pump, and the gated update tick that
	# used to sync the owner right after the hatch is held by the modal gate for
	# the whole upcoming cut-in -- publish the companion state keys here instead.
	if owner != null:
		_sync_owner(owner, registry)


func _reset_hatch_break_sequence() -> void:
	_hatch_break_pending_kind = ""
	_hatch_break_burst_hold = 0.0


# Advanced from the ungated idle pump (process_idle), so the reveal AND the exit
# action keep animating while the gated update driver is paused by the modal gate.
# The reveal is gated on the heavy Live2D acquisition sheet being cached: until then it
# holds in the reconstruction phase instead of locking solid on the static 원화 (the F7
# grant / 1-hit egg regression). We keep pumping the host's incremental stream here so
# the gate releases as soon as the sheet is ready, covering paths that skipped (or had
# too few) STATE_EGG calm frames.
func advance_acquire_cutin(delta: float, registry: Object = null) -> void:
	_invalidate_runtime_snapshot_cache()
	var cutin_pet_id: String = str(_acquire_cutin_state.get_display_pet_id(_pet_id))
	var anim_ready: bool = _acquire_cutin_overlay_host_resolver.is_anim_ready(registry, cutin_pet_id)
	if not anim_ready and registry != null:
		_acquire_cutin_asset_prewarm_state.prewarm_registry_step(
			cutin_pet_id,
			registry,
			_acquire_cutin_overlay_host_resolver
		)
	var was_active := bool(_acquire_cutin_state.active)
	_acquire_cutin_state.advance(delta, anim_ready)
	if was_active and not bool(_acquire_cutin_state.active):
		_overflow_choice_state.resolve_after_acquire_cutin(_item_egg_lifecycle_state)


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
	var cutin_pet_id: String = str(_acquire_cutin_state.get_display_pet_id(_pet_id))
	var cutin_profile: Object = _item_egg_lifecycle_state.get_profile() if _acquire_cutin_state.has_display_override() else _current_profile
	var dismiss_seconds: float = maxf(
		0.1,
		float(cutin_profile.get_visual_layout_value("cutin_dismiss_seconds", LingpetAcquireCutinState.DISMISS_SECONDS))
	)
	if not _acquire_cutin_state.begin_dismiss(dismiss_seconds):
		return false
	_invalidate_runtime_snapshot_cache()
	_audio_dispatcher.play_lingpet_acquire_click_reaction_backing(registry)
	_audio_dispatcher.play_lingpet_click_reaction(registry, cutin_pet_id)
	return true


func is_acquire_cutin_dismissing() -> bool:
	return _acquire_cutin_state.is_dismissing()


func get_acquire_cutin_dismiss_progress() -> float:
	return _acquire_cutin_state.get_dismiss_progress()


# Immediate hard close (cleanup / state-reset paths). The click handler uses
# begin_acquire_cutin_dismiss() instead so players see the exit action.
func dismiss_acquire_cutin() -> bool:
	var dismissed := bool(_acquire_cutin_state.dismiss_immediate())
	if dismissed:
		_invalidate_runtime_snapshot_cache()
		_overflow_choice_state.resolve_after_acquire_cutin(_item_egg_lifecycle_state)
	return dismissed


func is_overflow_choice_active() -> bool:
	return bool(_overflow_choice_state.is_active())


func get_overflow_choice_snapshot() -> Dictionary:
	return _overflow_choice_state.build_snapshot(_collection_state)


func commit_overflow_replace(slot_index: int, owner: Object = null, registry: Object = null) -> bool:
	var replace_plan: Dictionary = _overflow_replace_plan.consume(
		owner,
		slot_index,
		_overflow_choice_state,
		_collection_state
	)
	if not bool(replace_plan.get("handled", false)):
		return false
	_invalidate_runtime_snapshot_cache()
	if str(replace_plan.get("action", "")) == LingpetOverflowReplacePlan.ACTION_ITEM_EGG_REPLACE:
		return _commit_item_egg_overflow_replace(slot_index, owner, registry)
	var pending_pet_id := str(replace_plan.get("pending_pet_id", ""))
	var old_pet_id := str(replace_plan.get("old_pet_id", ""))
	if old_pet_id != "" and old_pet_id != pending_pet_id:
		_loadout_state.forget_pet_loadout_and_invalidate(owner, old_pet_id, _snapshot_builder)
	_finish_overflow_hatch_commit(owner, registry)
	return true


func commit_overflow_release(owner: Object = null, registry: Object = null) -> bool:
	var release_plan: Dictionary = _overflow_release_plan.consume(
		owner,
		_overflow_choice_state,
		_collection_state
	)
	if not bool(release_plan.get("handled", false)):
		return false
	_invalidate_runtime_snapshot_cache()
	var released_pet_id := str(release_plan.get("released_pet_id", ""))
	if released_pet_id != "":
		_loadout_state.forget_pet_loadout_and_invalidate(owner, released_pet_id, _snapshot_builder)
	match str(release_plan.get("action", "")):
		LingpetOverflowReleasePlan.ACTION_RESTORE_COMPANION:
			_adopt_owned_pet(owner, str(release_plan.get("restore_pet_id", "")), registry)
		LingpetOverflowReleasePlan.ACTION_CLEAR_PENDING:
			_clear_pending_egg_without_collection_reset(owner, registry)
		_:
			_sync_owner(owner, registry)
	return true


func _commit_item_egg_overflow_replace(slot_index: int, owner: Object, registry: Object) -> bool:
	var new_pet := str(_overflow_choice_state.get_pending_pet_id())
	var companion_pet := _pet_id if _state == STATE_COMPANION else ""
	var replace_result: Dictionary = _item_egg_absorb_router.commit_overflow_replace(
		owner,
		slot_index,
		new_pet,
		companion_pet,
		_collection_state
	)
	if not bool(replace_result.get("handled", false)):
		return false
	_invalidate_runtime_snapshot_cache()
	new_pet = str(replace_result.get("new_pet_id", new_pet))
	var old_pet_id := str(replace_result.get("old_pet_id", ""))
	if old_pet_id != "" and old_pet_id != new_pet:
		_loadout_state.forget_pet_loadout_and_invalidate(owner, old_pet_id, _snapshot_builder)
	_ensure_duration_pool_roll()
	_hatch_stat_roll_state.roll_item_egg_hatch_traits(new_pet, _loadout_state, _item_egg_lifecycle_state.get_profile())
	_overflow_choice_state.reset()
	if bool(replace_result.get("replaced_active_companion", false)):
		# Player chose to swap out the active companion: the new pet takes over.
		_adopt_owned_pet(owner, new_pet, registry)
	else:
		# Companion is untouched -> keep it accompanying the player.
		_sync_owner(owner, registry)
	return true


func is_maribo_companion_active() -> bool:
	return _pet_id == PET_ID and _is_guardian_summoned()


func is_companion_active(pet_id: String = "") -> bool:
	var normalized_pet_id: String = _current_profile.normalize_pet_id(pet_id)
	return _is_guardian_summoned() and (normalized_pet_id == "" or _pet_id == normalized_pet_id)


func debug_grant_and_activate_pet(
	pet_id: String,
	owner: Object = null,
	show_acquire_cutin: bool = false,
	active_skill_id: String = "",
	passive_skill_id: String = "",
	registry: Object = null,
	active_skill_level: int = 1,
	passive_skill_level: int = 1,
	second_active_skill_id: String = "",
	second_passive_skill_id: String = "",
	second_active_skill_level: int = 1,
	second_passive_skill_level: int = 1
) -> bool:
	var normalized_pet_id: String = _current_profile.normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return false
	_invalidate_runtime_snapshot_cache()
	_companion_skill_persistence.save_current(_pet_id, _companion_skill_states)
	var has_explicit_loadout := (
		active_skill_id.strip_edges() != ""
		or passive_skill_id.strip_edges() != ""
		or second_active_skill_id.strip_edges() != ""
		or second_passive_skill_id.strip_edges() != ""
	)
	if has_explicit_loadout:
		_loadout_state.set_pet_loadout_and_invalidate(
			owner,
			normalized_pet_id,
			active_skill_id,
			passive_skill_id,
			active_skill_level,
			passive_skill_level,
			_snapshot_builder,
			second_active_skill_id,
			second_passive_skill_id,
			second_active_skill_level,
			second_passive_skill_level
		)
	else:
		_loadout_state.sync_from_owner(owner)
		if not _loadout_state.get_loadouts().has(normalized_pet_id):
			_loadout_state.set_pet_loadout_and_invalidate(owner, normalized_pet_id, "", "", 0, 0, _snapshot_builder)
	_state = STATE_COMPANION
	_ensure_duration_pool_roll()
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_soul_summon_offer_guarantee_count = 0
	_soul_summon_offer_cooldown_screens = 0
	_soul_summon_offer_pending_choice = false
	_soul_summon_overflow_available_for_tests = true
	_set_current_pet_id(normalized_pet_id)
	_loadout_state.set_skip_unlock_reconcile(has_explicit_loadout)
	_apply_current_loadout(owner, true, false, registry)
	if owner != null:
		var owner_slots: Array[String] = _collection_state.get_battle_slots_from_owner(owner)
		_collection_state.set_battle_slots(owner_slots)
		_collection_state.set_active_slot_index(_collection_state.get_active_slot_index_from_owner(owner))
	# Keep the unlock-reconcile skip sticky for debug-forced loadouts so later
	# same-pet unlock reconcile cannot overwrite an F7-selected skill.
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_companion_activation(
		_build_companion_activation_context(owner, registry, true, true, true, true)
	))
	_initialize_companion_patrol(owner, true)
	if show_acquire_cutin:
		_acquire_cutin_state.start()
		_audio_dispatcher.play_lingpet_acquire_cutin(registry)
	_sync_owner(owner, registry)
	return true


func get_plaza_resonance_egg_offer(owner: Object) -> Dictionary:
	return _plaza_resonance_egg_summary_builder.build_offer(
		owner,
		_state,
		owner != null
			and _state != STATE_EGG
			and not _acquire_cutin_state.active
			and not _overflow_choice_state.has_pending_or_active()
			and _collection_state.should_spawn_egg(owner),
		_egg_state.hatch_hits,
		_get_main_egg_required_hits()
	)


func spawn_plaza_resonance_egg(owner: Object, registry: Object = null) -> Dictionary:
	var offer := get_plaza_resonance_egg_offer(owner)
	if not bool(offer.get("can_spawn", false)):
		return offer
	_collection_state.set_owned_pet_ids(_collection_state.get_owned_pet_ids_from_owner(owner))
	_collection_state.set_battle_slots(_collection_state.get_battle_slots_from_owner(owner))
	_collection_state.set_active_slot_index(_collection_state.get_active_slot_index_from_owner(owner))
	var hatch_pet_id: String = _collection_state.pick_hatch_pet_id(owner)
	if hatch_pet_id == "":
		return _plaza_resonance_egg_summary_builder.build_result(
			false,
			LingpetPlazaResonanceEggSummaryBuilder.REASON_NO_HATCH_CANDIDATES,
			_state,
			_egg_state.hatch_hits,
			_get_main_egg_required_hits()
		)

	if _state == STATE_COMPANION:
		_companion_skill_persistence.save_current(_pet_id, _companion_skill_states)
		_overflow_choice_state.begin_main_egg(_pet_id)
	else:
		_overflow_choice_state.begin_main_egg("")
	_state = STATE_EGG
	_reset_hatch_break_sequence()
	_set_current_pet_id(hatch_pet_id)
	_apply_companion_position_surface(_companion_runtime_resetter.reset_to_egg_wait(
		_build_companion_runtime_reset_context(owner, registry, true, true)
	))
	_sync_owner(owner, registry)
	return _plaza_resonance_egg_summary_builder.build_result(
		true,
		LingpetPlazaResonanceEggSummaryBuilder.REASON_OK,
		_state,
		_egg_state.hatch_hits,
		_get_main_egg_required_hits()
	)


func is_mount_active() -> bool:
	return _mount_state.is_mounted()


func get_mount_rider_lift_px() -> float:
	return _mount_state.get_rider_lift_px()


func get_lingpet_slots() -> Array[String]:
	return _collection_state.get_battle_slots()


func get_active_lingpet_slot_index() -> int:
	return _collection_state.get_active_slot_index()


func _set_current_pet_id(value: String) -> void:
	_invalidate_runtime_snapshot_cache()
	_pet_id = _current_pet_transition.apply(
		value,
		_pet_id,
		PET_ID,
		_current_profile,
		_affinity_context_coordinator,
		_loadout_state,
		_affinity_state,
		_hatch_stat_roll_state,
		_companion_distance_roll_state,
		_affinity_feedback_state,
		_companion_click_reaction_visual_prewarm_state,
		_acquire_cutin_asset_prewarm_state,
		_snapshot_builder
	)
	_mount_state.reset()
	_mount_state.set_pet_id(_pet_id)


func switch_lingpet_slot(slot_index: int, owner: Object = null, registry: Object = null) -> bool:
	_companion_skill_persistence.save_current(_pet_id, _companion_skill_states)
	var next_pet_id: String = _collection_state.select_active_slot(slot_index, owner)
	if next_pet_id == "":
		return false
	_invalidate_runtime_snapshot_cache()
	if _state != STATE_COMPANION:
		_adopt_owned_pet(owner, next_pet_id, registry)
		return true
	if next_pet_id == _pet_id:
		_sync_owner(owner, registry)
		return true
	_switch_transition_state.begin(_pet_id, next_pet_id, COMPANION_SWITCH_TRANSITION_SECONDS)
	_set_current_pet_id(next_pet_id)
	_apply_current_loadout(owner, true, false, registry)
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	_companion_runtime_resetter.prepare_companion_activation(
		_build_companion_activation_context(owner, registry, false, false, false, false)
	)
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


func set_affinity_reward_seed_for_tests(pet_id: String, reward_seed: int) -> void:
	var current_profile_changed: bool = bool(_affinity_context_coordinator.set_reward_seed_for_tests(
		pet_id,
		reward_seed,
		_pet_id,
		_current_profile,
		_loadout_state,
		_affinity_state
	))
	if current_profile_changed:
		_invalidate_runtime_snapshot_cache()
		_loadout_state.invalidate_runtime_and_snapshot_cache(_snapshot_builder)


func is_ring_dash_active_for_tests() -> bool:
	return _ring_dash_state.is_active_for_tests()


func is_ring_dash_vfx_active_for_tests() -> bool:
	return _ring_dash_vfx.has_visible_effects()


func is_ring_dash_visual_hidden_for_tests() -> bool:
	return _ring_dash_state.is_companion_visual_hidden()


func get_companion_draw_motion_speed_ratio_for_tests() -> float:
	return _companion_body_presence_resolver.get_draw_motion_speed_ratio_from_runtime(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_pos,
		_skill_runtime_host,
		_companion_skill_visual_resolver,
		_ring_dash_state,
		null,
		_starlight_tracking_state,
		_companion_motion_state,
		_companion_distance_roll_state,
		COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO
	)


func get_companion_roll_angle_for_tests() -> float:
	return float(_companion_distance_roll_state.angle)


func signed_roll_distance_for_tests(moved: Vector2) -> float:
	return _companion_distance_roll_state.signed_roll_distance(moved)


func get_companion_roll_draw_angle_for_tests() -> float:
	return _companion_distance_roll_state.get_draw_angle(_current_profile, LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x)


func get_companion_roll_angular_velocity_for_tests() -> float:
	return float(_companion_distance_roll_state.angular_velocity)


func advance_companion_draw_anim_for_tests(delta: float) -> void:
	_advance_companion_draw_anim(delta)


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
	var bonus_pct: float = _profile_runtime_surface.get_gauge_gain_bonus_pct(_current_profile, 0.0)
	if not _is_guardian_summoned() or bonus_pct <= 0.0:
		return gain
	return floor(gain * (1.0 + bonus_pct / 100.0))


func get_player_speed_multiplier() -> float:
	if not _is_guardian_summoned():
		return 1.0
	var bonus_pct: float = _profile_runtime_surface.get_player_speed_bonus_pct(_current_profile, 0.0)
	if bonus_pct <= 0.0:
		return 1.0
	return 1.0 + bonus_pct / 100.0


func update_starlight_tracking_for_starpoint_drop(drop: Dictionary, delta_seconds: float, context: Dictionary = {}) -> Dictionary:
	if drop.is_empty():
		return {}
	if not _is_guardian_summoned():
		_starlight_tracking_state.end_for_stow(drop)
		return {}
	var active_position_owner: Dictionary = _skill_runtime_surface.get_active_position_owner(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_skill_runtime_host,
		_companion_pos
	)
	if _skill_runtime_surface.has_active_position_override(_companion_skill_visual_resolver, active_position_owner):
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
	var passive_skill: Dictionary = _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetStarlightTrackingState.PASSIVE_ID)
	# Stowed guardians publish is_companion false so the delivery owner resets
	# its chase/drop state instead of moving while inactive.
	var result: Dictionary = _starlight_tracking_state.update_drop(
		maxf(0.0, delta_seconds),
		drop,
		passive_skill,
		_is_guardian_summoned(),
		_companion_pos,
		_vector_resolver.get_starlight_tracking_delivery_pos(context),
		_profile_runtime_surface.get_motion_style(_current_profile),
		context
	)
	if result.has("companion_pos"):
		var next_pos: Variant = result.get("companion_pos", _companion_pos)
		if next_pos is Vector2:
			_companion_pos = next_pos
			_companion_motion_state.pos = _companion_pos
			_companion_facing_left = _companion_motion_state.resolve_facing_left_after_motion(
				previous_pos,
				_companion_pos,
				_companion_facing_left
			)
	return result


func get_snapshot() -> Dictionary:
	var process_frame: int = int(Engine.get_process_frames())
	var physics_frame: int = int(Engine.get_physics_frames())
	if (
		_runtime_snapshot_cache_valid
		and _runtime_snapshot_cache_revision == _runtime_snapshot_revision
		and _runtime_snapshot_cache_process_frame == process_frame
		and _runtime_snapshot_cache_physics_frame == physics_frame
	):
		return _runtime_snapshot_cache
	_runtime_snapshot_cache = _build_runtime_snapshot_uncached()
	_runtime_snapshot_cache_valid = true
	_runtime_snapshot_cache_revision = _runtime_snapshot_revision
	_runtime_snapshot_cache_process_frame = process_frame
	_runtime_snapshot_cache_physics_frame = physics_frame
	return _runtime_snapshot_cache


func get_rail_card_surface() -> Dictionary:
	var process_frame: int = int(Engine.get_process_frames())
	var physics_frame: int = int(Engine.get_physics_frames())
	if (
		_rail_card_surface_cache_valid
		and _rail_card_surface_cache_process_frame == process_frame
		and _rail_card_surface_cache_physics_frame == physics_frame
	):
		return _rail_card_surface_cache
	_rail_card_surface_cache = _build_rail_card_surface_uncached()
	_rail_card_surface_cache_valid = true
	_rail_card_surface_cache_process_frame = process_frame
	_rail_card_surface_cache_physics_frame = physics_frame
	return _rail_card_surface_cache


func _build_rail_card_surface_uncached() -> Dictionary:
	_rail_card_surface_build_count_for_tests += 1
	var active_slot_count: int = _skill_runtime_surface.get_active_slot_count(_current_profile, _active_skill_slot_resolver, _skill_runtime_host)
	var primary_skill_surface: Dictionary = _skill_runtime_surface.get_active_surface_for_slot(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		0,
		active_slot_count
	)
	var second_skill_surface: Dictionary = _skill_runtime_surface.get_second_active_surface(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		active_slot_count
	)
	var surface: Dictionary = _get_rail_card_static_surface(primary_skill_surface, second_skill_surface, active_slot_count)
	var primary_active := _is_rail_card_slot_active(primary_skill_surface, active_slot_count, 0)
	var second_active := _is_rail_card_slot_active(second_skill_surface, active_slot_count, 1)
	_merge_rail_card_slot_dynamic(surface, primary_skill_surface, "", primary_active)
	_merge_rail_card_slot_dynamic(surface, second_skill_surface, "_1", second_active)
	_merge_rail_card_skill_runtime_snapshot(surface, str(primary_skill_surface.get("skill_id", "")) if primary_active else "")
	var second_skill_id := str(second_skill_surface.get("skill_id", "")) if second_active else ""
	if second_skill_id != "" and second_skill_id != str(primary_skill_surface.get("skill_id", "")):
		_merge_rail_card_skill_runtime_snapshot(surface, second_skill_id)
	return surface


func _get_rail_card_static_surface(primary_skill_surface: Dictionary, second_skill_surface: Dictionary, active_slot_count: int) -> Dictionary:
	var primary_active := _is_rail_card_slot_active(primary_skill_surface, active_slot_count, 0)
	var second_active := _is_rail_card_slot_active(second_skill_surface, active_slot_count, 1)
	var static_key := [
		_state,
		active_slot_count,
		_build_rail_card_slot_static_key(primary_skill_surface, primary_active),
		_build_rail_card_slot_static_key(second_skill_surface, second_active),
	]
	if not _rail_card_static_surface_key.is_empty() and _rail_card_static_surface_key == static_key:
		return _rail_card_static_surface_cache.duplicate()
	var surface: Dictionary = {}
	_merge_rail_card_slot_static(surface, primary_skill_surface, "", primary_active)
	_merge_rail_card_slot_static(surface, second_skill_surface, "_1", second_active)
	_rail_card_static_surface_key = static_key.duplicate(true)
	_rail_card_static_surface_cache = surface
	_rail_card_static_surface_build_count_for_tests += 1
	return surface.duplicate()


func _build_rail_card_slot_static_key(skill_surface: Dictionary, active: bool) -> Array:
	var active_skill: Dictionary = _as_dictionary(skill_surface.get("active_skill", {}))
	return [
		active,
		str(active_skill.get("id", "")) if active else "",
		str(active_skill.get("name", "")) if active else "",
		str(active_skill.get("description", "")) if active else "",
		float(active_skill.get("cooldown", 0.0)) if active else 0.0,
		str(active_skill.get("card_texture_path", "")) if active else "",
	]


func _merge_rail_card_slot_static(surface: Dictionary, skill_surface: Dictionary, suffix: String, active: bool) -> void:
	var active_skill: Dictionary = _as_dictionary(skill_surface.get("active_skill", {}))
	surface["companion_skill_id%s" % suffix] = str(active_skill.get("id", "")) if active else ""
	surface["companion_skill_name%s" % suffix] = str(active_skill.get("name", "")) if active else ""
	surface["companion_skill_description%s" % suffix] = str(active_skill.get("description", "")) if active else ""
	surface["companion_skill_card_path%s" % suffix] = str(active_skill.get("card_texture_path", "")) if active else ""
	surface["companion_skill_cooldown_duration%s" % suffix] = float(active_skill.get("cooldown", 0.0)) if active else 0.0


func _merge_rail_card_slot_dynamic(surface: Dictionary, skill_surface: Dictionary, suffix: String, active: bool) -> void:
	var skill_state: Object = skill_surface.get("skill_state", null) as Object
	var active_skill: Dictionary = _as_dictionary(skill_surface.get("active_skill", {}))
	var skill_id := str(active_skill.get("id", "")) if active else ""
	var cooldown_duration := float(active_skill.get("cooldown", 0.0)) if active else 0.0
	var windup_seconds := float(skill_surface.get("windup_seconds", 0.0)) if active else 0.0
	if skill_state != null and skill_state.has_method("get_snapshot"):
		var raw_snapshot: Variant = skill_state.get_snapshot(
			active,
			skill_id,
			cooldown_duration,
			windup_seconds,
			COMPANION_SKILL_FLASH_SECONDS,
			suffix
		)
		if raw_snapshot is Dictionary:
			surface.merge(raw_snapshot as Dictionary, true)
			return
	surface.merge(_empty_rail_card_skill_state_snapshot(suffix), true)


func _merge_rail_card_skill_runtime_snapshot(surface: Dictionary, skill_id: String) -> void:
	var normalized := skill_id.strip_edges()
	if normalized == "":
		return
	if _skill_runtime_host == null or not _skill_runtime_host.has_method("get_snapshot_for_skill_id"):
		return
	var raw_snapshot: Variant = _skill_runtime_host.get_snapshot_for_skill_id(normalized)
	if raw_snapshot is Dictionary:
		surface.merge(raw_snapshot as Dictionary, true)


func _is_rail_card_slot_active(skill_surface: Dictionary, active_slot_count: int, slot_index: int) -> bool:
	if not _is_guardian_summoned() or slot_index >= active_slot_count:
		return false
	var active_skill: Dictionary = _as_dictionary(skill_surface.get("active_skill", {}))
	return str(active_skill.get("id", "")) != "" and bool(active_skill.get("enabled", true))


func _empty_rail_card_skill_state_snapshot(suffix: String) -> Dictionary:
	return {
		"companion_skill_cooldown%s" % suffix: 0.0,
		"companion_skill_cooldown_duration%s" % suffix: 0.0,
		"companion_skill_windup_seconds%s" % suffix: 0.0,
		"companion_skill_windup_ratio%s" % suffix: 0.0,
		"companion_skill_ready%s" % suffix: false,
		"companion_skill_last_gain%s" % suffix: 0.0,
		"companion_skill_trigger_count%s" % suffix: 0,
		"companion_skill_flash_timer%s" % suffix: 0.0,
		"companion_skill_flash_ratio%s" % suffix: 0.0,
		"companion_skill_winding_up%s" % suffix: false,
		"companion_skill_origin%s" % suffix: Vector2.ZERO,
	}


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _build_runtime_snapshot_uncached() -> Dictionary:
	_runtime_snapshot_build_count_for_tests += 1
	var active_slot_count: int = _skill_runtime_surface.get_active_slot_count(_current_profile, _active_skill_slot_resolver, _skill_runtime_host)
	var primary_skill_surface: Dictionary = _skill_runtime_surface.get_active_surface_for_slot(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		0,
		active_slot_count
	)
	var second_skill_surface: Dictionary = _skill_runtime_surface.get_second_active_surface(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		active_slot_count
	)
	var profile_surface: Dictionary = _profile_runtime_surface.build_runtime_surface(
		_current_profile,
		REQUIRED_HITS,
		COMPANION_HIT_HALF_WIDTH * 2.0,
		COMPANION_HIT_HALF_HEIGHT * 2.0,
		COMPANION_HIT_GAUGE_GAIN
	)
	var patrol_speed_default: float = float(_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_default", COMPANION_PATROL_SPEED))
	var patrol_speed_min: float = float(_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN))
	var patrol_speed_max: float = float(_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX))
	var defense_rate: float = float(_debug_stat_overrides.get_defense_rate(_current_profile, COMPANION_DEFENSE_RATE))
	var appearance_rate: float = float(_debug_stat_overrides.get_appearance_rate(_current_profile, 0.0))
	var effect_text: String = LingpetEffectTextResolver.resolve(
		_state,
		_egg_state.get_required_hits(int(profile_surface.get("required_hits", REQUIRED_HITS))),
		_current_profile
	)
	var snapshot: Dictionary = _snapshot_builder.build_runtime_snapshot(
		_pet_id,
		_state,
		_is_guardian_summoned(),
		_egg_state.get_required_hits(int(profile_surface.get("required_hits", REQUIRED_HITS))),
		_companion_pos,
		float(profile_surface.get("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0)),
		float(profile_surface.get("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0)),
		primary_skill_surface.get("active_skill", {}) as Dictionary,
		float(_egg_state.get_hatch_flash_timer()),
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		float(profile_surface.get("gauge_gain_bonus_pct", 0.0)),
		_egg_state,
		_companion_motion_state,
		patrol_speed_default,
		patrol_speed_min,
		patrol_speed_max,
		defense_rate,
		_companion_body_hit_state,
		float(profile_surface.get("hit_gauge_gain", COMPANION_HIT_GAUGE_GAIN)),
		primary_skill_surface.get("skill_state", null) as Object,
		float(primary_skill_surface.get("windup_seconds", 0.0)),
		COMPANION_SKILL_FLASH_SECONDS,
		_skill_runtime_host,
		second_skill_surface.get("active_skill", {}) as Dictionary,
		second_skill_surface.get("skill_state", null) as Object,
		float(second_skill_surface.get("windup_seconds", 0.0)),
		_loadout_state.get_loadouts(),
		_profile_runtime_surface.get_active_skill_pool(_current_profile),
		profile_surface.get("passive_skill", {}) as Dictionary,
		_profile_runtime_surface.get_passive_skill_pool(_current_profile)
	)
	var character_info_display_snapshot: Dictionary = _snapshot_builder.build_character_info_display_snapshot(
		_pet_id,
		_state,
		float(profile_surface.get("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0)),
		float(profile_surface.get("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0)),
		primary_skill_surface.get("active_skill", {}) as Dictionary,
		second_skill_surface.get("active_skill", {}) as Dictionary,
		profile_surface.get("passive_skills", []) as Array,
		float(profile_surface.get("gauge_gain_bonus_pct", 0.0)),
		patrol_speed_default,
		patrol_speed_min,
		patrol_speed_max,
		defense_rate,
		float(profile_surface.get("hit_gauge_gain", COMPANION_HIT_GAUGE_GAIN)),
		appearance_rate,
		effect_text
	)
	snapshot.merge(_switch_transition_state.get_snapshot(COMPANION_SWITCH_TRANSITION_SECONDS), true)
	snapshot["guardian_transition"] = _guardian_transition_state.get_snapshot()
	snapshot["companion_skill_shared_cooldown"] = _companion_skill_persistence.get_shared_cooldown()
	snapshot["companion_skill_shared_cooldown_duration"] = COMPANION_SKILL_SHARED_COOLDOWN_SECONDS
	snapshot.merge(_afterglow_leak_state.get_snapshot(), true)
	snapshot.merge(_ring_dash_state.get_snapshot(), true)
	snapshot.merge(_starlight_tracking_state.get_snapshot(), true)
	snapshot["companion_appearance_rate"] = appearance_rate if _is_guardian_summoned() else 0.0
	snapshot["character_info_display_snapshot"] = character_info_display_snapshot
	snapshot["duration_pool_pct"] = _get_active_duration_pct()
	snapshot["duration_pool"] = _affinity_state.get_duration_pool_current()
	snapshot["duration_pool_max"] = _affinity_state.get_duration_pool_max()
	snapshot["guardian_stowed"] = _guardian_stowed
	snapshot.merge(_affinity_feedback_state.get_snapshot(_is_guardian_summoned()), true)
	snapshot["item_egg_active"] = _item_egg_lifecycle_state.is_active()
	snapshot["item_egg_pet_id"] = _item_egg_lifecycle_state.get_pet_id()
	snapshot["item_egg_hatch_hits"] = _item_egg_state.hatch_hits
	snapshot["item_egg_absorbing"] = _item_egg_absorb_vfx.has_visible_effects()
	# Reveal-only override: when the incubator egg hatches, the acquire cut-in shows THIS pet
	# while _pet_id (and everything the panel/owner reads) stays the companion. The overlay
	# host prefers this key so the reveal art is the new pet, not the companion.
	snapshot["cutin_pet_id"] = _acquire_cutin_state.get_display_override_pet_id()
	return snapshot


func _invalidate_runtime_snapshot_cache() -> void:
	_runtime_snapshot_revision += 1
	_runtime_snapshot_cache_valid = false
	_runtime_snapshot_cache = {}
	_rail_card_surface_cache_valid = false
	_rail_card_surface_cache = {}


func reset_runtime_snapshot_cache_counters_for_tests() -> void:
	_runtime_snapshot_build_count_for_tests = 0
	_rail_card_surface_build_count_for_tests = 0
	_rail_card_static_surface_build_count_for_tests = 0
	_invalidate_runtime_snapshot_cache()


func get_runtime_snapshot_build_count_for_tests() -> int:
	return _runtime_snapshot_build_count_for_tests


func get_rail_card_surface_build_count_for_tests() -> int:
	return _rail_card_surface_build_count_for_tests


func get_rail_card_static_surface_build_count_for_tests() -> int:
	return _rail_card_static_surface_build_count_for_tests


# Public accessors for the coexist incubator egg (deployed via the lingpet_egg item while
# a companion is active). Used by focused smokes; the on-field egg + absorb VFX are
# otherwise driven entirely through update()/draw().
func is_item_egg_active() -> bool:
	return _item_egg_lifecycle_state.is_active()


func get_item_egg_pet_id() -> String:
	return _item_egg_lifecycle_state.get_pet_id()


func is_item_egg_absorbing() -> bool:
	return _item_egg_absorb_vfx.has_visible_effects()


func get_save_snapshot() -> Dictionary:
	var affinity_run_state: Dictionary = _affinity_state.export_run_state()
	affinity_run_state.merge(_hatch_stat_roll_state.export_run_state(), true)
	affinity_run_state.merge(_spirit_water_drop_state.export_run_state(), true)
	var snapshot: Dictionary = _snapshot_builder.build_save_snapshot(
		SAVE_SNAPSHOT_VERSION,
		_pet_id,
		_state,
		_egg_state.hatch_hits,
		_get_main_egg_required_hits(),
		_egg_state.pos,
		_egg_state.egg_color_index,
		_companion_pos,
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_profile_runtime_surface.get_gauge_gain_bonus_pct(_current_profile, 0.0),
		_companion_motion_state,
		_loadout_state.get_loadouts(),
		affinity_run_state
	)
	snapshot["guardian_stowed"] = _guardian_stowed
	return snapshot


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func export_affinity_run_state() -> Dictionary:
	var run_state: Dictionary = _affinity_state.export_run_state()
	run_state.merge(_hatch_stat_roll_state.export_run_state(), true)
	run_state.merge(_spirit_water_drop_state.export_run_state(), true)
	return run_state


# Restore the run-scoped affinity progression carried in a save snapshot. The
# save/restore applier calls this right after reset_for_tests() (which wipes the run
# state) so a pet swap / plaza round trip / in-run restore keeps per-pet affinity AND
# the run-global ring core tier. Called before pet_id/state/loadout restore so the
# downstream profile/owner sync reads the restored affinity + ring-core cap.
func import_affinity_run_state(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return
	_invalidate_runtime_snapshot_cache()
	_hatch_stat_roll_state.import_run_state(run_state)
	_affinity_state.import_run_state(run_state)
	_spirit_water_drop_state.import_run_state(run_state)
	_loadout_state.invalidate_runtime_and_snapshot_cache(_snapshot_builder)


func apply_save_snapshot(snapshot: Dictionary, owner: Object = null, registry: Object = null) -> Dictionary:
	_invalidate_runtime_snapshot_cache()
	cancel_guardian_enhance_cutin(registry)
	_overflow_choice_state.reset()
	_reset_hatch_break_sequence()
	var result: Dictionary = _save_restore_applier.apply(
		snapshot,
		owner,
		registry,
		self,
		_collection_state,
		_loadout_state,
		_save_restore_planner,
		PET_ID,
		STATE_NONE,
		STATE_EGG,
		STATE_COMPANION,
		{
			"clear_field_state": Callable(self, "_clear_lingpet_field_state"),
			"restore_companion_patrol": Callable(self, "_restore_companion_patrol"),
		}
	)
	_guardian_stowed = (
		_state == STATE_COMPANION
		and bool(snapshot.get(
			"guardian_stowed",
			_affinity_state.is_duration_resummon_locked()
		))
	)
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = _get_duration_warning_stage()
	return result


func restore_save_snapshot(snapshot: Dictionary, owner: Object = null, registry: Object = null) -> Dictionary:
	return apply_save_snapshot(snapshot, owner, registry)


func reset_for_tests() -> void:
	_invalidate_runtime_snapshot_cache()
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_companion_skill_persistence.reset_stage_observer()
	_current_profile.set_enhancement_rewards(LingpetAffinityState.get_empty_reward_counts())
	_loadout_state.invalidate_runtime_and_snapshot_cache(_snapshot_builder)
	_affinity_state.reset_for_new_run()
	_hatch_stat_roll_state.reset_for_new_run()
	_spirit_water_drop_state.reset_run()
	_affinity_context_coordinator.reset_for_new_run()
	_affinity_feedback_state.reset_all()
	_duration_runtime_state.reset()
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_duration_roll_rng_for_tests = null
	_guardian_enhance_offer_engine.reset()
	_guardian_enhance_roll_rng_for_tests = null
	_guardian_enhance_last_result.clear()
	_guardian_enhance_cutin_state.reset()
	_guardian_enhance_cutin_prewarm_state.reset()
	_egg_state.reset_all()
	_reset_hatch_break_sequence()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_collection_state.reset()
	_loadout_state.reset()
	_reset_companion_runtime_state()
	_companion_skill_persistence.reset_store()
	_acquire_cutin_state.reset()
	_switch_transition_state.reset()
	_guardian_transition_state.reset()
	_overflow_choice_state.reset()
	_item_egg_lifecycle_state.clear_runtime_state(
		_item_egg_state,
		_item_egg_absorb_vfx,
		_acquire_cutin_state
	)
	if _skill_runtime_host != null and _skill_runtime_host.has_method("clear_for_tests"):
		_skill_runtime_host.clear_for_tests()
	if _current_profile != null and _current_profile.has_method("clear_visual_cache"):
		_current_profile.clear_visual_cache()
	_none_owner_sync_state.reset()


func reset_round(deps: Dictionary = {}) -> void:
	_invalidate_runtime_snapshot_cache()
	_guardian_transition_state.reset()
	# Round resets may cancel an unreleased portal item, but only a real stage
	# transition may rearm the one-natural-drop latch.
	_spirit_water_drop_state.cancel_pending_drop()
	_mount_state.reset()
	var owner: Object = deps.get("owner", null) as Object
	var registry: Object = deps.get("registry", null) as Object
	cancel_guardian_enhance_cutin(registry)
	if _overflow_choice_state.has_pending_or_active():
		commit_overflow_release(owner, registry)
	_round_resetter.reset_round(
		owner,
		registry,
		_affinity_state,
		_affinity_feedback_state,
		_companion_motion_state,
		_switch_transition_state,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_companion_body_hit_state,
		_afterglow_leak_state,
		_ring_dash_state,
		_ring_dash_vfx,
		_ghost_blink_vfx,
		_starlight_tracking_state,
		null
	)


func _clear_lingpet_field_state() -> void:
	_invalidate_runtime_snapshot_cache()
	_guardian_enhance_cutin_state.reset()
	_guardian_enhance_cutin_prewarm_state.reset()
	_guardian_transition_state.reset()
	_state = STATE_NONE
	_reset_hatch_break_sequence()
	_duration_runtime_state.reset()
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_set_current_pet_id(PET_ID)
	_companion_skill_persistence.reset_stage_observer()
	_loadout_state.invalidate_runtime_and_snapshot_cache(_snapshot_builder)
	_affinity_feedback_state.reset_all()
	_apply_companion_position_surface(_companion_runtime_resetter.clear_field_state(
		_build_field_cleanup_context()
	))


func _reset_companion_runtime_state(reset_defense: bool = true, owner: Object = null, registry: Object = null) -> void:
	_companion_runtime_resetter.reset_state(
		reset_defense,
		_companion_sprite_animator,
		_companion_distance_roll_state,
		_companion_body_hit_state,
		_afterglow_leak_state,
		_ring_dash_state,
		_ring_dash_vfx,
		_ghost_blink_vfx,
		_starlight_tracking_state,
		null,
		_companion_skill_persistence,
		_companion_skill_states,
		_companion_motion_state,
		_skill_runtime_host,
		owner,
		registry
	)


func _build_companion_runtime_reset_context(
	owner: Object,
	registry: Object,
	reset_defense: bool,
	reset_none_owner_sync: bool
) -> Dictionary:
	return {
		"owner": owner,
		"registry": registry,
		"egg_state": _egg_state,
		"reset_defense": reset_defense,
		"reset_none_owner_sync": reset_none_owner_sync,
		"companion_sprite_animator": _companion_sprite_animator,
		"companion_distance_roll_state": _companion_distance_roll_state,
		"companion_body_hit_state": _companion_body_hit_state,
		"afterglow_leak_state": _afterglow_leak_state,
		"ring_dash_state": _ring_dash_state,
		"ring_dash_vfx": _ring_dash_vfx,
		"ghost_blink_vfx": _ghost_blink_vfx,
		"starlight_tracking_state": _starlight_tracking_state,
		"companion_skill_persistence": _companion_skill_persistence,
		"companion_skill_states": _companion_skill_states,
		"companion_motion_state": _companion_motion_state,
		"skill_runtime_host": _skill_runtime_host,
		"acquire_cutin_state": _acquire_cutin_state,
		"switch_transition_state": _switch_transition_state,
		"none_owner_sync_state": _none_owner_sync_state,
		"current_visual_prewarm_coordinator": _current_visual_prewarm_coordinator,
		"current_profile": _current_profile,
		"companion_renderer": _companion_renderer,
		"state": _state,
		"companion_state": STATE_COMPANION,
		"pet_id": _pet_id,
		"companion_click_reaction_visual_prewarm_state": _companion_click_reaction_visual_prewarm_state,
	}


func _build_companion_activation_context(
	owner: Object,
	registry: Object,
	reset_position: bool,
	set_egg_hatched: bool,
	reset_switch_transition: bool,
	reset_acquire_cutin: bool
) -> Dictionary:
	var context: Dictionary = _build_companion_runtime_reset_context(owner, registry, true, false)
	context["reset_position"] = reset_position
	context["set_egg_hatched"] = set_egg_hatched
	context["required_hits"] = _get_main_egg_required_hits()
	context["restore_current_skill_state"] = true
	context["reset_switch_transition"] = reset_switch_transition
	context["reset_acquire_cutin"] = reset_acquire_cutin
	context["prewarm_current_visuals"] = true
	context["ensure_active_slot"] = true
	context["collection_state"] = _collection_state
	return context


func _build_clear_pending_context(owner: Object, registry: Object) -> Dictionary:
	var context: Dictionary = _build_companion_runtime_reset_context(owner, registry, true, false)
	context["item_egg_lifecycle_state"] = _item_egg_lifecycle_state
	context["item_egg_state"] = _item_egg_state
	context["item_egg_absorb_vfx"] = _item_egg_absorb_vfx
	return context


func _build_field_cleanup_context() -> Dictionary:
	return {
		"egg_state": _egg_state,
		"companion_motion_state": _companion_motion_state,
		"companion_distance_roll_state": _companion_distance_roll_state,
		"afterglow_leak_state": _afterglow_leak_state,
		"ring_dash_state": _ring_dash_state,
		"ring_dash_vfx": _ring_dash_vfx,
		"ghost_blink_vfx": _ghost_blink_vfx,
		"starlight_tracking_state": _starlight_tracking_state,
		"overflow_choice_state": _overflow_choice_state,
		"item_egg_lifecycle_state": _item_egg_lifecycle_state,
		"item_egg_state": _item_egg_state,
		"item_egg_absorb_vfx": _item_egg_absorb_vfx,
		"acquire_cutin_state": _acquire_cutin_state,
	}


func _build_hatch_reveal_context(
	registry: Object,
	start_acquire_cutin: bool,
	play_acquire_cutin_audio: bool,
	perf_logger: Object = null,
	perf_label_prefix: String = "",
	hatch_flash_seconds: float = LingpetEggFieldRenderer.HATCH_FLASH_SECONDS
) -> Dictionary:
	return {
		"registry": registry,
		"egg_state": _egg_state,
		"hatch_flash_seconds": hatch_flash_seconds,
		"switch_transition_state": _switch_transition_state,
		"acquire_cutin_state": _acquire_cutin_state,
		"start_acquire_cutin": start_acquire_cutin,
		"play_acquire_cutin_audio": play_acquire_cutin_audio,
		"audio_dispatcher": _audio_dispatcher,
		"current_visual_prewarm_coordinator": _current_visual_prewarm_coordinator,
		"current_profile": _current_profile,
		"companion_renderer": _companion_renderer,
		"state": _state,
		"companion_state": STATE_COMPANION,
		"pet_id": _pet_id,
		"companion_click_reaction_visual_prewarm_state": _companion_click_reaction_visual_prewarm_state,
		"perf_logger": perf_logger,
		"perf_label_prefix": perf_label_prefix,
	}


func _apply_companion_position_surface(position_surface: Dictionary) -> void:
	var raw_pos: Variant = position_surface.get("companion_pos", Vector2.ZERO)
	if raw_pos is Vector2:
		_companion_pos = raw_pos
	else:
		_companion_pos = Vector2.ZERO
	if position_surface.has("companion_facing_left"):
		_companion_facing_left = bool(position_surface.get("companion_facing_left", false))


func _spawn_egg(owner: Object, registry: Object = null) -> void:
	_state = STATE_EGG
	_reset_hatch_break_sequence()
	_set_current_pet_id(_collection_state.pick_hatch_pet_id(owner))
	_apply_companion_position_surface(_companion_runtime_resetter.reset_to_egg_wait(
		_build_companion_runtime_reset_context(owner, registry, true, true)
	))
	# Junior's auto-present starter egg always pops on the first hit (tutorial
	# convenience); the rolled 2/3-hit tiers are reserved for eggs earned later.
	if _collection_state.is_auto_present_league(owner):
		_egg_state.set_required_hits(1)
	_sync_owner(owner)


# Per-egg hatch difficulty: the spawn-time roll on the egg state is the
# authority; the profile/catalog value is only the legacy fallback for
# unrolled states (e.g. restored pre-roll saves).
func _get_main_egg_required_hits() -> int:
	return _egg_state.get_required_hits(
		_profile_runtime_surface.get_required_hits(_current_profile, REQUIRED_HITS)
	)


func _get_item_egg_required_hits() -> int:
	return _item_egg_state.get_required_hits(
		_item_egg_lifecycle_state.get_required_hits(REQUIRED_HITS)
	)


func _resolve_ball_hit(owner: Object, registry: Object = null, perf_logger: Object = null) -> bool:
	var hatch_resolve_part_start: int = _perf_probe.begin(perf_logger)
	var hit_result: Dictionary = _egg_state.resolve_ball_hit(owner, _get_main_egg_required_hits())
	_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.hatch_resolve.ball_hit", hatch_resolve_part_start)
	if bool(hit_result.get("hit", false)):
		# 수호령 알이 공에 맞을 때: 뼈 부러지는 임팩트 2종 중 랜덤 재생. 실제 물리 충돌
		# (패들 바운스)이 일어난 모든 히트마다 재생하며, counted 여부는 보지 않는다.
		# 단, 플레이어가 서브로 발사한 공은 알과 타격판정 자체를 하지 않아 hit=false로
		# 통과하므로 여기 SFX 경로에도 진입하지 않는다(바운스도 없음).
		_audio_dispatcher.play_lingpet_egg_hit(registry)
	if not bool(hit_result.get("changed", false)):
		return false

	if bool(hit_result.get("hatched", false)):
		hatch_resolve_part_start = _perf_probe.begin(perf_logger)
		_collection_state.sync_from_owner(owner)
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.hatch_resolve.collection_sync", hatch_resolve_part_start)
		# The hatch is DEFERRED behind the shell-break cinematic: decide the commit
		# branch now (the owner cannot change while the modal gate holds physics),
		# then advance_hatch_break() runs the break + burst hold and finally opens
		# the acquire cut-in via _commit_pending_hatch().
		hatch_resolve_part_start = _perf_probe.begin(perf_logger)
		_hatch_break_pending_kind = (
			HATCH_PENDING_KIND_OVERFLOW if _collection_state.is_full(owner)
			else HATCH_PENDING_KIND_REGULAR
		)
		_hatch_break_burst_hold = 0.0
		_egg_state.trigger_hatch_break()
		_perf_probe.end(perf_logger, "physics.lingpet.egg_phase.hatch_resolve.begin_hatch_break", hatch_resolve_part_start)
	return true


func _finish_regular_hatch(owner: Object, registry: Object = null, perf_logger: Object = null) -> void:
	_ensure_duration_pool_roll()
	_state = STATE_COMPANION
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_apply_current_loadout(owner, true, true, registry)
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_hatch_position(_egg_state))
	_initialize_companion_patrol(owner, false)
	_reset_companion_runtime_state(false, owner, registry)
	_companion_runtime_resetter.start_hatch_reveal_effects(_build_hatch_reveal_context(
		registry,
		true,
		true,
		perf_logger,
		"physics.lingpet.egg_phase.hatch_resolve.cutin_open",
		# The shell already burst at break end; re-arm the flash with its own
		# remaining time so the shard burst is not visibly restarted here.
		float(_egg_state.get_hatch_flash_timer())
	))
	_collection_state.add_pet_to_next_empty_slot(owner, _pet_id)
	_overflow_choice_state.reset()


func _begin_overflow_hatch(_owner: Object, registry: Object = null, perf_logger: Object = null) -> void:
	_overflow_choice_state.begin_main_overflow(_pet_id)
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_hatch_position(_egg_state))
	_companion_runtime_resetter.start_hatch_reveal_effects(_build_hatch_reveal_context(
		registry,
		true,
		true,
		perf_logger,
		"physics.lingpet.egg_phase.hatch_resolve.cutin_open",
		# Same continuity rule as the regular commit: keep the in-flight burst.
		float(_egg_state.get_hatch_flash_timer())
	))


func _finish_overflow_hatch_commit(owner: Object, registry: Object = null) -> void:
	var kept_pet_id := str(_overflow_choice_state.consume_commit_pet_id())
	_ensure_duration_pool_roll()
	_state = STATE_COMPANION
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_set_current_pet_id(kept_pet_id)
	_apply_current_loadout(owner, true, true, registry)
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_hatch_position(_egg_state))
	_initialize_companion_patrol(owner, false)
	_reset_companion_runtime_state(false, owner, registry)
	_companion_runtime_resetter.start_hatch_reveal_effects(_build_hatch_reveal_context(registry, false, false))
	_sync_owner(owner, registry)


# Runs on the first update(owner) after the incubator-egg reveal cut-in dismisses. The
# companion was never suspended (the reveal used a separate display identity), so there is
# nothing to restore: just clear the reveal identity, play the digital absorb VFX, and
# register the new pet into a free collection slot (or open the slot-replace choice when the
# roster is full) -- all while the companion keeps accompanying the player.
func _perform_item_egg_absorb(owner: Object, registry: Object = null) -> void:
	_invalidate_runtime_snapshot_cache()
	var absorb_context: Dictionary = _item_egg_lifecycle_state.consume_ready_absorb()
	var absorb_pet := str(absorb_context.get("pet_id", ""))
	var absorb_origin := Vector2.ZERO
	var raw_absorb_origin: Variant = absorb_context.get("origin", Vector2.ZERO)
	if raw_absorb_origin is Vector2:
		absorb_origin = raw_absorb_origin
	# Digital dissolve -> absorbed-into-player energy burst (egg origin -> player).
	_item_egg_absorb_vfx.trigger(
		absorb_origin,
		_vector_resolver.get_owner_player_paddle_center(owner, _item_egg_state.pos)
	)
	if absorb_pet == "":
		_sync_owner(owner, registry)
		return
	var absorb_route: Dictionary = _item_egg_absorb_router.route_absorbed_pet(
		owner,
		absorb_pet,
		_collection_state,
		_overflow_choice_state
	)
	if bool(absorb_route.get("opened_overflow", false)):
		_sync_owner(owner, registry)
		return
	# Free slot: register the new pet WITHOUT stealing the active companion.
	var registered := str(absorb_route.get("registered_pet_id", ""))
	if registered != "":
		_ensure_duration_pool_roll()
		_hatch_stat_roll_state.roll_item_egg_hatch_traits(registered, _loadout_state, _item_egg_lifecycle_state.get_profile())
	_sync_owner(owner, registry)


func _clear_pending_egg_without_collection_reset(owner: Object = null, registry: Object = null) -> void:
	_invalidate_runtime_snapshot_cache()
	_state = STATE_NONE
	_reset_hatch_break_sequence()
	_set_current_pet_id(PET_ID)
	_apply_companion_position_surface(_companion_runtime_resetter.reset_to_none(
		_build_clear_pending_context(owner, registry)
	))
	_sync_owner(owner, registry)


func _sync_owner(owner: Object, registry: Object = null) -> void:
	if _state == STATE_COMPANION:
		if not _loadout_state.has_applied_runtime_cache():
			_apply_current_loadout(owner, true, false, registry)
	else:
		_loadout_state.sync_owner(owner, "")
	var should_sync_loadouts: bool = bool(_loadout_state.should_sync_owner_loadouts_for_runtime(_state == STATE_COMPANION))
	var loadouts_snapshot: Dictionary = _loadout_state.get_loadouts() if should_sync_loadouts else {}
	var active_slot_count: int = _skill_runtime_surface.get_active_slot_count(_current_profile, _active_skill_slot_resolver, _skill_runtime_host)
	var primary_skill_surface: Dictionary = _skill_runtime_surface.get_active_surface_for_slot(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		0,
		active_slot_count
	)
	var second_skill_surface: Dictionary = _skill_runtime_surface.get_second_active_surface(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		active_slot_count
	)
	var profile_surface: Dictionary = _profile_runtime_surface.build_runtime_surface(
		_current_profile,
		REQUIRED_HITS,
		COMPANION_HIT_HALF_WIDTH * 2.0,
		COMPANION_HIT_HALF_HEIGHT * 2.0,
		COMPANION_HIT_GAUGE_GAIN
	)
	var runtime_state := STATE_NONE if _state == STATE_COMPANION and _guardian_stowed else _state
	_snapshot_builder.sync_owner(
		owner,
		_pet_id,
		runtime_state,
		_egg_state.hatch_hits,
		_egg_state.get_required_hits(int(profile_surface.get("required_hits", REQUIRED_HITS))),
		_egg_state.pos,
		_companion_pos,
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_default", COMPANION_PATROL_SPEED),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		float(profile_surface.get("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0)),
		float(profile_surface.get("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0)),
		_debug_stat_overrides.get_defense_rate(_current_profile, COMPANION_DEFENSE_RATE),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_companion_motion_state,
		_companion_body_hit_state,
		float(profile_surface.get("hit_gauge_gain", COMPANION_HIT_GAUGE_GAIN)),
		primary_skill_surface.get("active_skill", {}) as Dictionary,
		primary_skill_surface.get("skill_state", null) as Object,
		second_skill_surface.get("active_skill", {}) as Dictionary,
		second_skill_surface.get("skill_state", null) as Object,
		float(second_skill_surface.get("windup_seconds", 0.0)),
		float(profile_surface.get("gauge_gain_bonus_pct", 0.0)),
		LingpetEffectTextResolver.resolve(runtime_state, _egg_state.get_required_hits(int(profile_surface.get("required_hits", REQUIRED_HITS))), _current_profile),
		loadouts_snapshot,
		profile_surface.get("passive_skill", {}) as Dictionary,
		should_sync_loadouts
	)
	# Appearance rate (flight-only 출현율) is synced directly here rather than threaded
	# through the snapshot builder; the panel reads owner.lingpet_companion_appearance_rate.
	# Route through the builder's gated setters so these stable-most-ticks keys
	# share the change-gated last-pushed cache (F-lingpet-1).
	var appearance_rate: float = _debug_stat_overrides.get_appearance_rate(_current_profile, 0.0) if _is_guardian_summoned() else 0.0
	_snapshot_builder.set_owner_pair_gated(owner, "lingpet_companion_appearance_rate", "ringpet_companion_appearance_rate", appearance_rate)
	_snapshot_builder.set_owner_pair_gated(
		owner,
		"lingpet_duration_pool_pct",
		"ringpet_duration_pool_pct",
		_get_active_duration_pct()
	)
	if should_sync_loadouts:
		_loadout_state.mark_owner_loadouts_synced_for_runtime()
	_invalidate_runtime_snapshot_cache()


func _adopt_owned_pet(owner: Object, pet_id: String, registry: Object = null) -> void:
	_invalidate_runtime_snapshot_cache()
	_state = STATE_COMPANION
	_set_current_pet_id(pet_id)
	_apply_current_loadout(owner, true, false, registry)
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_companion_activation(
		_build_companion_activation_context(owner, registry, true, true, true, false)
	))
	_initialize_companion_patrol(owner, true)
	_sync_owner(owner, registry)


func set_debug_defense_rate_override(value: float) -> void:
	_invalidate_runtime_snapshot_cache()
	_debug_stat_overrides.set_defense_rate_override(value)


func get_debug_defense_rate_override() -> float:
	return float(_debug_stat_overrides.defense_rate_override)


func set_debug_appearance_rate_override(value: float) -> void:
	_invalidate_runtime_snapshot_cache()
	_debug_stat_overrides.set_appearance_rate_override(value)


func get_debug_appearance_rate_override() -> float:
	return float(_debug_stat_overrides.appearance_rate_override)


func set_debug_move_speed_override(value: float) -> void:
	_invalidate_runtime_snapshot_cache()
	_debug_stat_overrides.set_move_speed_override(value)


func get_debug_move_speed_override() -> float:
	return float(_debug_stat_overrides.move_speed_override)


func _apply_current_loadout(owner: Object, ensure: bool, randomize_missing: bool = false, registry: Object = null) -> void:
	_current_loadout_applier.apply(
		_pet_id,
		owner,
		ensure,
		randomize_missing,
		_current_profile,
		_loadout_state,
		_affinity_state,
		_unlock_loadout_reconciler,
		_hatch_stat_roll_state,
		_affinity_context_coordinator,
		_skill_runtime_host,
		_active_skill_slot_resolver,
		_snapshot_builder
	)


func get_unlock_choice_options(_pet_id: String = "", _registry: Object = null) -> Array:
	return []


func commit_unlock_pick(_pet_id_arg: String, _choice_key: String, _candidate_id: String, _owner: Object = null, _registry: Object = null) -> bool:
	# v5 / per-run: unlock choices auto-resolve into run-state (no player pick UI,
	# no store persistence). This store-backed commit is disabled.
	return false


func _update_companion_motion(delta: float, owner: Object, registry: Object = null) -> void:
	var prev_pos: Vector2 = _companion_pos
	# Resolve summoned state before position-owning passives so a manual or
	# duration-forced stow cannot launch movement, VFX, or audio.
	var companion_active := _is_guardian_summoned()
	var skill_position_override: Dictionary = _skill_runtime_surface.get_active_position_owner(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_skill_runtime_host,
		_companion_pos
	)
	var has_skill_position_override: bool = _skill_runtime_surface.has_active_position_override(_companion_skill_visual_resolver, skill_position_override)
	# 수호령 탑승: toggle + follow. Skill position overrides (sortie strikes
	# etc.) win over the mount while active; the mount wins over feed /
	# starlight loitering below.
	_mount_state.advance(
		owner,
		_companion_pos,
		companion_active and not has_skill_position_override,
		_is_right_click_claimed_by_player_skill(registry),
		delta
	)
	if _mount_state.has_companion_position_override() and not has_skill_position_override:
		_companion_pos = _mount_state.get_companion_position_override(owner, _companion_pos)
		_companion_motion_state.pos = _companion_pos
		_companion_facing_left = _companion_motion_state.resolve_facing_left_after_motion(
			prev_pos,
			_companion_pos,
			_companion_facing_left
		)
		return
	if has_skill_position_override:
		_ring_dash_state.reset_round_transients()
		_ring_dash_vfx.reset()
	else:
		var ring_dash_was_active: bool = _ring_dash_state.has_companion_position_override()
		var passive_skill: Dictionary = _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetRingDashState.PASSIVE_ID)
		var motion_style: String = _profile_runtime_surface.get_motion_style(_current_profile)
		var ring_dash_result: Dictionary = _ring_dash_state.advance(
			delta,
			owner,
			passive_skill,
			companion_active,
			_companion_pos,
			_profile_runtime_surface.get_catch_width(_current_profile, COMPANION_HIT_HALF_WIDTH * 2.0),
			_profile_runtime_surface.get_catch_height(_current_profile, COMPANION_HIT_HALF_HEIGHT * 2.0),
			motion_style,
			_resolve_player_dash_state(registry)
		)
		if _ring_dash_state.has_companion_position_override():
			_companion_pos = _ring_dash_state.get_companion_position_override(_companion_pos)
			_companion_motion_state.pos = _companion_pos
			_companion_facing_left = _companion_motion_state.resolve_facing_left_after_motion(
				prev_pos,
				_companion_pos,
				_companion_facing_left
			)
			if bool(ring_dash_result.get("started", false)):
				# prev_pos is the pre-teleport spot (departure collapse); _companion_pos
				# is the snapped intercept point (arrival burst).
				_ring_dash_vfx.trigger(prev_pos, _companion_pos)
				_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)
				_audio_dispatcher.play_lingpet_ring_dash(registry)
			return
		if ring_dash_was_active:
			if _companion_motion_state.resume_sortie_loiter_from_current(
				owner,
				_companion_skill_persistence.get_trigger_count(),
				_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
				_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
				motion_style
			):
				_companion_pos = _companion_motion_state.pos
	if _starlight_tracking_state.has_companion_position_override() and not has_skill_position_override:
		_companion_pos = _starlight_tracking_state.get_companion_position_override(_companion_pos)
		_companion_motion_state.pos = _companion_pos
		_companion_facing_left = _companion_motion_state.resolve_facing_left_after_motion(
			prev_pos,
			_companion_pos,
			_companion_facing_left
		)
		return
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.update(
		delta,
		owner,
		_companion_skill_persistence.is_any_winding_up(_companion_skill_states) or not companion_active,
		_debug_stat_overrides.get_defense_rate(_current_profile, COMPANION_DEFENSE_RATE) if companion_active else 0.0,
		_companion_skill_persistence.get_trigger_count(),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_default", COMPANION_PATROL_SPEED),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_profile_runtime_surface.get_motion_style(_current_profile),
		_debug_stat_overrides.get_appearance_rate(_current_profile, 0.0),
		1.0,
		not companion_active
	)
	_companion_pos = _companion_motion_state.pos
	_companion_facing_left = _companion_motion_state.resolve_facing_left_after_motion(
		prev_pos,
		_companion_pos,
		_companion_facing_left
	)


# 탑승 토글은 맨 우클릭을 쓰는데, 스매셔 벽력유성이 "우클릭 홀드로 무장 →
# 타구 시점 발사" 계약으로 바뀌면서 같은 버튼을 쓴다. 무장 가능한(=장착 +
# 기력 + 쿨타임 + 랠리 진행 중) 순간에는 스킬이 우클릭을 소유하고, 그 외
# (서브 대기 / 쿨타임 / 기력 부족 / 미장착 / 타 캐릭터)에는 탑승이 그대로
# 가져간다. 그래서 랠리 밖에서는 탑승이 100% 종전대로 동작한다.
# ⚠️peek 전용(`get_cached_instance`) — 매 컴패니언 프레임 경로라 콜드
# 인스턴스화가 끼면 첫 호출이 히치가 된다(Hot-Path Lazy Init Trap).
func _is_right_click_claimed_by_player_skill(registry: Object) -> bool:
	if registry == null or not registry.has_method("get_cached_instance"):
		return false
	var cached: Variant = registry.get_cached_instance("smasher_overdrive_state")
	if typeof(cached) != TYPE_OBJECT or not is_instance_valid(cached):
		return false
	var overdrive_state: Object = cached as Object
	if overdrive_state.has_method("is_active") and bool(overdrive_state.is_active()):
		return true
	return overdrive_state.has_method("is_armed") and bool(overdrive_state.is_armed())


# 링크포트(ring_dash) 이중수비 게이트용 플레이어 대쉬 스냅샷.
# ⚠️peek 전용(`get_cached_instance`) — `get_instance` 폴백을 넣지 마라.
# 여기는 매 물리 프레임 도는 컴패니언 모션 경로이고, 콜드 인스턴스화가 끼면
# 첫 호출이 100ms+ 히치가 된다(Godot Hot-Path Lazy Init Trap).
# `smasher_dash_state`는 부트 프리웜 대상이라 실전에선 peek이 항상 적중하고,
# 미캐시(=대쉬 시스템 미가동)면 빈 dict로 정적 패들 게이트만 남는다.
# 스냅샷 dict 생성도 대쉬 중일 때만 — 비대쉬 프레임은 bool 한 번으로 끝난다.
func _resolve_player_dash_state(registry: Object) -> Dictionary:
	if registry == null or not registry.has_method("get_cached_instance"):
		return {}
	var cached: Variant = registry.get_cached_instance("smasher_dash_state")
	if typeof(cached) != TYPE_OBJECT or not is_instance_valid(cached):
		return {}
	var dash_state: Object = cached as Object
	if not dash_state.has_method("is_active") or not bool(dash_state.is_active()):
		return {}
	if not dash_state.has_method("get_snapshot"):
		return {}
	var snapshot: Variant = dash_state.get_snapshot()
	return snapshot if snapshot is Dictionary else {}


func _initialize_companion_patrol(owner: Object, randomize_x: bool) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.initialize(
		owner,
		randomize_x,
		_companion_skill_persistence.get_trigger_count(),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_profile_runtime_surface.get_motion_style(_current_profile)
	)
	_companion_pos = _companion_motion_state.pos
	_companion_facing_left = _companion_motion_state.resolve_facing_left_from_patrol_dir(_companion_facing_left)


func _restore_companion_patrol(snapshot: Dictionary) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.restore(
		snapshot,
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_profile_runtime_surface.get_motion_style(_current_profile)
	)
	_companion_pos = _companion_motion_state.pos
	_companion_facing_left = _companion_motion_state.resolve_facing_left_from_patrol_dir(_companion_facing_left)


func _reset_companion_patrol() -> void:
	_apply_companion_position_surface(_companion_runtime_resetter.reset_companion_position(
		_companion_motion_state,
		_companion_distance_roll_state
	))


func _resolve_companion_ball_hit(owner: Object, registry: Object = null, captured_affinity_hit_tags: Dictionary = {}) -> bool:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		_companion_body_hit_state.ball_was_inside = false
		return false
	if not _is_guardian_summoned():
		_companion_body_hit_state.ball_was_inside = false
		return false
	# 탑승 중엔 수비 정지 (parked != disabled trap: the suppression must be
	# explicit, not implied by the position override).
	if _mount_state.is_mounted():
		_companion_body_hit_state.ball_was_inside = false
		return false
	var visual_surface: Dictionary = _skill_runtime_surface.get_visual_surface(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_companion_pos,
		COMPANION_SKILL_WINDUP_SECONDS
	)
	var body_skill_id: String = str(visual_surface.get("body_skill_id", ""))
	if _skill_runtime_surface.is_companion_body_hit_suppressed(
		_skill_runtime_host,
		body_skill_id
	):
		_companion_body_hit_state.ball_was_inside = false
		return false
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	if not _companion_body_presence_resolver.is_available_for_hit_from_surface(
		visual_surface,
		_ring_dash_state,
		null,
		_starlight_tracking_state,
		_companion_motion_state
	):
		_companion_body_hit_state.ball_was_inside = false
		return false
	# Player-priority: when the player paddle can reach this ball, defer to the player
	# instead of letting the companion steal the bounce (the "overlapping pet shouldn't
	# take the player's ball" rule). The companion still GUARDS balls the player CANNOT
	# reach -- this mirrors the defense-intercept / ring-dash `_player_can_block` gate, so
	# a far guard (e.g. the maribo defense smoke's x=650 ball) is unaffected. Geometric,
	# not probabilistic: clearing ball_was_inside keeps it per-entry, not per-frame.
	# True when the player paddle can reach the ball at its current X, in which case the
	# companion must NOT bounce it (the player takes priority). Mirrors the defense /
	# ring-dash player-block gates, so raw proximity body-hit is consistent with them.
	if _companion_player_block_resolver.can_player_block(owner, BALL_RADIUS_FALLBACK, 155.0):
		_companion_body_hit_state.ball_was_inside = false
		return false

	var affinity_hit_tags: Dictionary = _affinity_hit_tag_resolver.merge(
		captured_affinity_hit_tags,
		_affinity_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
	)
	var hit_result: Dictionary = _companion_body_hit_state.resolve_ball_hit(
		owner,
		registry,
		_companion_pos,
		_profile_runtime_surface.get_catch_width(_current_profile, COMPANION_HIT_HALF_WIDTH * 2.0),
		_profile_runtime_surface.get_catch_height(_current_profile, COMPANION_HIT_HALF_HEIGHT * 2.0),
		_profile_runtime_surface.get_hit_gauge_gain(_current_profile, COMPANION_HIT_GAUGE_GAIN),
		_is_guardian_summoned(),
		_companion_sprite_animator.strike_active
	)
	if not bool(hit_result.get("hit", false)):
		return false
	if _affinity_hit_tag_resolver.has_defense_tag(affinity_hit_tags):
		_affinity_feedback_state.trigger_guard_label(_companion_body_hit_state.last_contact_pos)
	if bool(affinity_hit_tags.get("defense_intercept", false)):
		_companion_motion_state.clear_defense_intercept()

	# If the anticipatory predictor already started the swing for this approach,
	# leave it running (do NOT restart -- mirrors boss trigger_hit's hit_active
	# early-return). Only if the prediction missed do we fall back to a reactive
	# strike entering at the thrust apex so the spear still snaps on contact.
	if bool(hit_result.get("should_begin_strike", false)):
		_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_IMPACT_FRAME)
	_afterglow_leak_state.spawn_from_hit(_companion_body_hit_state.last_contact_pos, _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetAfterglowLeakState.PASSIVE_ID), _is_guardian_summoned())
	# Guard against a boss skill that owns the ball each frame (e.g. Dalji's
	# 상모돌리기 whip forces the ball downward via update_ball_motion). Notify it
	# like a player-paddle guard so it stops controlling the ball; otherwise the
	# whip re-forces the ball down next frame and the companion bounce is ignored.
	return true


func _update_companion_skill_effects(delta: float, owner: Object, registry: Object = null) -> void:
	_companion_pos = _companion_skill_controller.update_active_slots(
		delta,
		_state,
		STATE_COMPANION,
		owner,
		registry,
		_switch_transition_state.get_ratio(COMPANION_SWITCH_TRANSITION_SECONDS) > 0.0,
		_companion_motion_state.motion_visible,
		_companion_pos,
		_profile_runtime_surface.get_catch_height(_current_profile, COMPANION_HIT_HALF_HEIGHT * 2.0),
		not _is_guardian_summoned(),
		self
	)
	_companion_motion_state.pos = _companion_pos


func ensure_companion_position_for_skill_tick(owner: Object) -> Vector2:
	_initialize_companion_patrol(owner, true)
	return _companion_pos


func launch_companion_skill_from_controller(owner: Object, registry: Object, slot: int) -> Vector2:
	_launch_companion_skill(owner, registry, slot)
	return _companion_pos


func begin_companion_skill_strike_from_controller() -> void:
	_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)


func _launch_companion_skill(owner: Object, registry: Object, slot_index: int = 0) -> void:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	var skill_surface: Dictionary = _skill_runtime_surface.get_active_surface_for_slot(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		COMPANION_SKILL_WINDUP_SECONDS,
		slot_index
	)
	var skill_id: String = str(skill_surface.get("skill_id", ""))
	if skill_id == "":
		return
	var current_active_skill: Dictionary = skill_surface.get("active_skill", {}) as Dictionary
	var origin: Vector2 = _skill_runtime_host.get_launch_origin(skill_id, _companion_pos, COMPANION_RADIUS)
	var launched: bool = _companion_skill_controller.complete_launch(
		skill_surface.get("skill_state", null) as Object,
		_skill_runtime_host,
		skill_id,
		origin,
		float(current_active_skill.get("cooldown", COMPANION_SKILL_COOLDOWN_SECONDS)),
		COMPANION_SKILL_FLASH_SECONDS,
		registry,
		owner,
		_companion_skill_launch_payload_builder.build(
			current_active_skill,
			skill_id,
			int(skill_surface.get("active_skill_level_fallback", 0)),
			_companion_pos,
			COMPANION_RADIUS,
			registry
		)
	)
	if launched:
		_companion_skill_persistence.record_launch(slot_index, _companion_skill_states)
		_companion_skill_persistence.start_shared_cooldown(COMPANION_SKILL_SHARED_COOLDOWN_SECONDS, _companion_skill_states)


func _advance_companion_draw_anim(delta: float) -> void:
	# Measure how far the drawn companion position actually moved since the previous tick,
	# normalized to a 0..1 walk ratio. Position-override systems (skill / starlight) set
	# _companion_pos directly and run on their own driver, so a hardcoded draw ratio cannot
	# tell "holding" from "moving" — this real-movement signal can. Captured here (after
	# both patrol motion and skill-effect overrides have written _companion_pos) so it
	# reflects the whole frame.
	var speed_max: float = maxf(1.0, _debug_stat_overrides.get_patrol_speed(_current_profile, "patrol_speed_max", COMPANION_PATROL_SPEED_MAX))
	_companion_distance_roll_state.advance_draw_movement(
		_companion_pos,
		delta,
		speed_max,
		_current_profile,
		LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x,
		float(_companion_motion_state.motion_speed_ratio)
	)
	# Drive the walk animation from an accumulator that only advances on this
	# (update_lingpet) tick, NOT raw wall-clock. When a pause branch in
	# battle_frame_flow_controller skips update_lingpet (power-smash freeze, mythic
	# cinematic, scoreboard fade), this is not called, so the walk frame freezes into a
	# still pose instead of marching in place while the frozen pet never moves.
	_companion_sprite_animator.advance_walk_phase(delta, _companion_body_presence_resolver.get_draw_motion_speed_ratio_from_runtime(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_pos,
		_skill_runtime_host,
		_companion_skill_visual_resolver,
		_ring_dash_state,
		null,
		_starlight_tracking_state,
		_companion_motion_state,
		_companion_distance_roll_state,
		COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO
	))


func _draw_companion(
	canvas: CanvasItem,
	center: Vector2,
	transition_alpha: float = 1.0
) -> void:
	var visual_surface: Dictionary = _skill_runtime_surface.get_visual_surface(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_companion_pos,
		COMPANION_SKILL_WINDUP_SECONDS
	)
	var guardian_inactive := not _is_guardian_summoned()
	var draw_motion_speed_ratio: float = _companion_body_presence_resolver.get_draw_motion_speed_ratio_from_surface(
		visual_surface,
		_current_profile,
		_ring_dash_state,
		null,
		_starlight_tracking_state,
		_companion_motion_state,
		_companion_distance_roll_state,
		COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO
	)
	if guardian_inactive:
		draw_motion_speed_ratio = 0.0
	_companion_renderer.draw_companion(canvas, center, _companion_draw_context_builder.build_config({
		"companion_active": _is_guardian_summoned() or transition_alpha < 1.0,
		"radius": COMPANION_RADIUS,
		"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
		"body_hit_state": _companion_body_hit_state,
		"skill_state": visual_surface.get("skill_state", null) as Object,
		"switch_state": _switch_transition_state,
		"skill_runtime_host": _skill_runtime_host,
		"current_profile": _current_profile,
		"skill_id": str(visual_surface.get("skill_id", "")),
		"skill_flash_seconds": COMPANION_SKILL_FLASH_SECONDS,
		"switch_transition_seconds": COMPANION_SWITCH_TRANSITION_SECONDS,
		"switch_particles": COMPANION_SWITCH_TRANSITION_PARTICLES,
		"animator": _companion_sprite_animator,
		"patrol_pause": _companion_motion_state.patrol_pause,
		"face_left": _companion_facing_left,
		"motion_speed_ratio": draw_motion_speed_ratio,
		"companion_roll_angle": _companion_distance_roll_state.get_draw_angle(_current_profile, LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x),
		"defense_guard_active": _companion_motion_state.defense_intercept_active,
		"defense_guard_aura_ratio": _companion_motion_state.defense_guard_aura_ratio,
		"companion_visible": _companion_body_presence_resolver.is_visible_for_draw_from_surface(
			visual_surface,
			_ring_dash_state,
			null,
			_starlight_tracking_state,
			_companion_motion_state
		),
		# Ghost (free_flight) fade alpha, 0..1. The renderer multiplies the companion
		# sprite + aura by this so rabi fades out/in instead of hard-popping. 1.0 for
		# non-ghost pets (motion state leaves ghost_alpha at 1.0 for them).
		"companion_alpha": _companion_motion_state.ghost_alpha * clampf(transition_alpha, 0.0, 1.0),
		"windup_seconds": float(visual_surface.get("windup_seconds", 0.0)),
		"affinity_feedback_state": _affinity_feedback_state,
		"mount_carry_active": _mount_state.is_mounted(),
	}))


# Begin the in-battle click-reaction playback if the click landed on the
# patrolling companion. Battle is NOT paused -- the reaction temporarily replaces
# the small SD companion at the same in-field size and fades out on its own.
# playfield_pos is in game/playfield
# coordinates (caller converts the viewport click via the layout render_scale /
# game_offset). Returns true when the click was consumed by the companion.
func try_begin_companion_click_reaction(playfield_pos: Vector2, registry: Object = null) -> bool:
	if not _is_guardian_summoned():
		return false
	if _companion_pos == Vector2.ZERO:
		return false
	if not _companion_click_reaction_state.can_start_at(playfield_pos, _companion_pos):
		return false
	if _companion_click_reaction_state.is_active():
		_audio_dispatcher.play_lingpet_click_reaction(registry, _pet_id)
		return true
	if _companion_click_reaction_state.get_ready_texture(_current_profile) == null:
		return false
	_companion_click_reaction_state.start()
	_audio_dispatcher.play_lingpet_click_reaction(registry, _pet_id)
	return true


func is_companion_click_reaction_active() -> bool:
	return _companion_click_reaction_state.is_active()


func refill_guardian_duration_for_stage_transition() -> bool:
	# Fixed order: refill first, then rearm. The full-pool eligibility gate keeps
	# spirit water out of the candidate pool until duration is spent again.
	var changed: bool = bool(_affinity_state.refill_duration_pool_for_stage_transition())
	_spirit_water_drop_state.rearm_for_stage_transition()
	_duration_warning_stage = 0
	if changed:
		_invalidate_runtime_snapshot_cache()
	return changed


func can_offer_spirit_water_drop(owner: Object = null) -> bool:
	var owned_pet_ids: Array[String] = _collection_state.get_owned_pet_ids_from_owner(owner)
	return _spirit_water_drop_state.can_offer(
		not owned_pet_ids.is_empty(),
		_affinity_state.get_duration_pool_current(),
		_affinity_state.get_duration_pool_max()
	)


func mark_spirit_water_drop_pending() -> bool:
	return _spirit_water_drop_state.mark_drop_pending()


func cancel_spirit_water_drop_pending() -> bool:
	return _spirit_water_drop_state.cancel_pending_drop()


func mark_spirit_water_field_drop_succeeded() -> bool:
	return _spirit_water_drop_state.mark_drop_succeeded()


func use_spirit_water(owner: Object = null, registry: Object = null) -> Dictionary:
	var owned_pet_ids: Array[String] = _collection_state.get_owned_pet_ids_from_owner(owner)
	if owned_pet_ids.is_empty():
		return {"accepted": false, "blocked_reason": "missing_guardian"}
	var result: Dictionary = _affinity_state.restore_duration_pool_to_full_preserving_overfill()
	if not bool(result.get("accepted", false)):
		return result
	_invalidate_runtime_snapshot_cache()
	_sync_owner(owner, registry)
	result["item_name"] = "lingpet_spirit_water"
	return result


func get_spirit_water_drop_snapshot_for_tests() -> Dictionary:
	return _spirit_water_drop_state.get_snapshot()


func get_duration_pool_current() -> float:
	return _affinity_state.get_duration_pool_current()


func get_duration_pool_max() -> float:
	return _affinity_state.get_duration_pool_max()


func get_duration_pool_pct() -> int:
	return _affinity_state.get_duration_pool_pct()


func can_resummon_guardian() -> bool:
	return _affinity_state.can_resummon_guardian()


func is_guardian_stowed() -> bool:
	return _state == STATE_COMPANION and _guardian_stowed


func try_toggle_guardian_stow(
	owner: Object = null,
	registry: Object = null
) -> bool:
	if _state != STATE_COMPANION or _pet_id.strip_edges() == "":
		return false
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	# The dedicated edge is consumed while either presentation is active. This
	# prevents key-repeat from reversing or double-committing the state machine.
	if _guardian_transition_state.is_active():
		return true
	if _guardian_stowed:
		# Consume the dedicated toggle even while recovery has not crossed the
		# strict >10s gate, so R3/Ctrl cannot leak into downstream battle input.
		if not _affinity_state.can_resummon_guardian():
			return true
		_set_guardian_stowed(false, owner, registry)
		return true
	if _guardian_active_elapsed < GUARDIAN_MIN_SUMMON_SECONDS:
		return true
	_set_guardian_stowed(true, owner, registry)
	return true


func on_soul_summon_art_removed(owner: Object, registry: Object = null) -> Dictionary:
	var stowed := false
	if _state == STATE_COMPANION:
		stowed = _set_guardian_stowed(true, owner, registry, true)
	return {
		"stowed": stowed or is_guardian_stowed(),
		"duration_pool_current": get_duration_pool_current(),
		"duration_pool_max": get_duration_pool_max(),
		"pet_id": _pet_id,
	}


func get_guardian_active_elapsed_for_tests() -> float:
	return _guardian_active_elapsed


func set_duration_pool_for_tests(current: float, maximum: float = 0.0) -> void:
	_affinity_state.set_duration_pool_for_tests(current, maximum)
	_guardian_stowed = current <= 0.0
	_duration_warning_stage = _get_duration_warning_stage()
	_invalidate_runtime_snapshot_cache()


func set_duration_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_duration_roll_rng_for_tests = rng


func get_affinity_rewards_for_tests(pet_id: String = "") -> Dictionary:
	var normalized_pet_id: String = _current_profile.normalize_pet_id(pet_id)
	return _affinity_state.get_cumulative_rewards(normalized_pet_id if normalized_pet_id != "" else _pet_id)


func _advance_duration_pool(
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> void:
	if _state != STATE_COMPANION:
		_duration_runtime_state.advance_inactive(_affinity_state)
		return
	if _is_guardian_duration_draining():
		_guardian_active_elapsed += maxf(0.0, delta)
	_duration_runtime_state.latch_drain_exempt(owner, _collection_state, _affinity_state)
	var result: Dictionary = _duration_runtime_state.advance_duration(
		delta,
		_affinity_state,
		owner,
		_collection_state,
		_profile_runtime_surface.get_passive_skills(_current_profile),
		_is_guardian_duration_draining()
	)
	if bool(result.get("expired", false)):
		_set_guardian_stowed(true, owner, registry, true)
	var warning_stage := _get_duration_warning_stage()
	if warning_stage > _duration_warning_stage:
		_audio_dispatcher.play_lingpet_duration_warning(registry, warning_stage)
	_duration_warning_stage = warning_stage
	if bool(result.get("changed", false)):
		_invalidate_runtime_snapshot_cache()


func _get_active_duration_pct() -> int:
	return _duration_runtime_state.get_active_duration_pct(
		_state == STATE_COMPANION,
		_affinity_state
	)


func _ensure_duration_pool_roll() -> Dictionary:
	return _affinity_state.ensure_duration_pool_roll(_duration_roll_rng_for_tests)


func _set_guardian_stowed(
	stowed: bool,
	owner: Object,
	registry: Object,
	forced: bool = false
) -> bool:
	if forced:
		var interrupted_transition: bool = bool(_guardian_transition_state.is_active())
		_guardian_transition_state.reset()
		if _guardian_stowed == stowed:
			return interrupted_transition
		_guardian_stowed = stowed
		_guardian_active_elapsed = 0.0
		if stowed:
			_end_guardian_runtime_for_stow(owner, registry)
			_ghost_blink_vfx.trigger_vanish(_companion_pos)
		else:
			_ghost_blink_vfx.trigger_appear(_companion_pos)
		_invalidate_runtime_snapshot_cache()
		if owner != null:
			_sync_owner(owner, registry)
		return true
	if _guardian_transition_state.is_active() or _guardian_stowed == stowed:
		return false
	if stowed and not forced and _guardian_active_elapsed < GUARDIAN_MIN_SUMMON_SECONDS:
		return false
	if stowed:
		_guardian_stowed = true
		_guardian_active_elapsed = 0.0
		_end_guardian_runtime_for_stow(owner, registry)
		_guardian_transition_state.begin_stow(
			_companion_pos,
			_vector_resolver.get_owner_player_paddle_center(owner, _companion_pos)
		)
		_ghost_blink_vfx.trigger_vanish(_companion_pos)
		_audio_dispatcher.play_lingpet_guardian_stow_transition(registry)
	else:
		if _companion_pos == Vector2.ZERO:
			_initialize_companion_patrol(owner, true)
		_guardian_active_elapsed = 0.0
		_guardian_transition_state.begin_summon(
			_vector_resolver.get_owner_player_paddle_center(owner, _companion_pos),
			_companion_pos
		)
		_audio_dispatcher.play_lingpet_guardian_summon_transition(registry)
	_invalidate_runtime_snapshot_cache()
	if owner != null:
		_sync_owner(owner, registry)
	return true


func _complete_guardian_summon_transition(owner: Object, registry: Object) -> void:
	if _state != STATE_COMPANION or not _guardian_stowed:
		return
	_guardian_stowed = false
	_ghost_blink_vfx.trigger_appear(_companion_pos)
	_invalidate_runtime_snapshot_cache()
	if owner != null:
		_sync_owner(owner, registry)


func _is_guardian_duration_draining() -> bool:
	return _is_guardian_summoned() or _guardian_transition_state.is_summoning()


func _end_guardian_runtime_for_stow(owner: Object, registry: Object) -> void:
	# Stop preparation without touching the preserved cooldown values.
	_companion_skill_persistence.cancel_windups(_companion_skill_states)
	# Every launched skill owns its own projectile/residue arrays, CC restoration,
	# and loop audio cancellation. This host boundary intentionally does not own
	# the skill-state cooldowns.
	_skill_runtime_host.end_for_stow(owner, registry)
	# Non-active-skill companion effects need the same explicit teardown. Do not
	# call broad companion resets here: those reset defense decision timers and
	# per-opportunity roll locks, enabling stow/resummon reroll farming.
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
	_affinity_feedback_state.reset_transients()


func _is_guardian_summoned() -> bool:
	return _state == STATE_COMPANION and not _guardian_stowed


func _get_duration_warning_stage() -> int:
	var current: float = float(_affinity_state.get_duration_pool_current())
	if current <= 0.0 or current > 10.0:
		return 0 if current > 10.0 else DURATION_WARNING_STAGE_COUNT
	var stage_width := 10.0 / float(DURATION_WARNING_STAGE_COUNT)
	return clampi(
		DURATION_WARNING_STAGE_COUNT - int(ceil(current / stage_width)) + 1,
		1,
		DURATION_WARNING_STAGE_COUNT
	)
