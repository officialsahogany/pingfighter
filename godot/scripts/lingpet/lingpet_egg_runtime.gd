extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAcquireCutinAssetPrewarmState := preload("res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd")
const LingpetAcquireCutinOverlayHostResolver := preload("res://scripts/lingpet/lingpet_acquire_cutin_overlay_host_resolver.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const LingpetAcquisitionLifecycleCoordinator := preload(
	"res://scripts/lingpet/lingpet_acquisition_lifecycle_coordinator.gd"
)
const LingpetAfterglowLeakState := preload("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
const LingpetRingDashState := preload("res://scripts/lingpet/lingpet_ring_dash_state.gd")
const LingpetRingDashVfx := preload("res://scripts/lingpet/lingpet_ring_dash_vfx.gd")
const LingpetGhostBlinkVfx := preload("res://scripts/lingpet/lingpet_ghost_blink_vfx.gd")
const LingpetGuardianTransitionState := preload(
	"res://scripts/lingpet/lingpet_guardian_transition_state.gd"
)
const LingpetStarlightTrackingState := preload("res://scripts/lingpet/lingpet_starlight_tracking_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetSpiritWaterDropState := preload("res://scripts/lingpet/lingpet_spirit_water_drop_state.gd")
const GuardianEggAccessPolicy := preload("res://scripts/lingpet/guardian_egg_access_policy.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionClickReactionState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
const LingpetCompanionClickReactionDrawSizeResolver := preload("res://scripts/lingpet/lingpet_companion_click_reaction_draw_size_resolver.gd")
const LingpetCompanionClickReactionVisualPrewarmState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_visual_prewarm_state.gd")
const LingpetCompanionBodyPresenceResolver := preload("res://scripts/lingpet/lingpet_companion_body_presence_resolver.gd")
const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")
const LingpetCompanionPlayerBlockResolver := preload("res://scripts/lingpet/lingpet_companion_player_block_resolver.gd")
const LingpetCompanionPlayerRuntimeResolver := preload("res://scripts/lingpet/lingpet_companion_player_runtime_resolver.gd")
const LingpetCompanionRuntimeResetter := preload("res://scripts/lingpet/lingpet_companion_runtime_resetter.gd")
const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetGuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)
const LingpetGuardianEnhanceFlowCoordinator := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_flow_coordinator.gd"
)
const LingpetGuardianEnhancePresentationCoordinator := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_presentation_coordinator.gd"
)
const LingpetDurationRuntimeState := preload(
	"res://scripts/lingpet/lingpet_duration_runtime_state.gd"
)
const LingpetGuardianDurationLifecycleCoordinator := preload(
	"res://scripts/lingpet/lingpet_guardian_duration_lifecycle_coordinator.gd"
)
const LingpetGuardianRunContextCoordinator := preload("res://scripts/lingpet/lingpet_guardian_run_context_coordinator.gd")
const LingpetGuardHitTagResolver := preload("res://scripts/lingpet/lingpet_guard_hit_tag_resolver.gd")
const LingpetGuardFeedbackState := preload("res://scripts/lingpet/lingpet_guard_feedback_state.gd")
const LingpetAudioDispatcher := preload("res://scripts/lingpet/lingpet_audio_dispatcher.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetCurrentLoadoutApplier := preload("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
const LingpetCurrentPetTransition := preload("res://scripts/lingpet/lingpet_current_pet_transition.gd")
const LingpetCurrentVisualPrewarmCoordinator := preload("res://scripts/lingpet/lingpet_current_visual_prewarm_coordinator.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionDistanceRollState := preload("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionMotionCoordinator := preload("res://scripts/lingpet/lingpet_companion_motion_coordinator.gd")
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
const LingpetOverflowAbsorbPlan := preload("res://scripts/lingpet/lingpet_overflow_absorb_plan.gd")
const LingpetOverflowGuardianSnapshotBuilder := preload("res://scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd")
const LingpetOverflowReplacePlan := preload("res://scripts/lingpet/lingpet_overflow_replace_plan.gd")
const LingpetPlazaResonanceEggSummaryBuilder := preload("res://scripts/lingpet/lingpet_plaza_resonance_egg_summary_builder.gd")
const LingpetPerfProbe := preload("res://scripts/lingpet/lingpet_perf_probe.gd")
const LingpetRailCardSurfaceBuilder := preload("res://scripts/lingpet/lingpet_rail_card_surface_builder.gd")
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
const SAVE_SNAPSHOT_VERSION := 3
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
var _companion_motion_state: Object = LingpetCompanionMotionState.new()
var _companion_motion_coordinator: Object = LingpetCompanionMotionCoordinator.new()
var _companion_pos: Vector2:
	get:
		return _companion_motion_coordinator.get_position()
	set(value):
		_companion_motion_coordinator.set_position(value)
# Latched horizontal facing for the walk-sheet mirror. Normal motion updates it
# from actual horizontal travel (see _update_companion_motion), not raw patrol_dir:
# patrol_dir toggles during pauses / reverse-and-pause decisions, which made the
# held spear snap sides while Maribo stood still. First spawn/restore is seeded
# from patrol_dir because the zero-to-spawn placement jump is not real travel.
var _companion_facing_left: bool:
	get:
		return _companion_motion_coordinator.is_facing_left()
	set(value):
		_companion_motion_coordinator.set_facing_left(value)
var _afterglow_leak_state: Object = LingpetAfterglowLeakState.new()
var _ring_dash_state: Object = LingpetRingDashState.new()
var _ring_dash_vfx: Object = LingpetRingDashVfx.new()
# Owns free-flight visibility edge latching so the blink "pong" VFX fires once per transition.
var _ghost_blink_vfx: Object = LingpetGhostBlinkVfx.new()
var _guardian_transition_state: Object = LingpetGuardianTransitionState.new()
var _starlight_tracking_state: Object = LingpetStarlightTrackingState.new()
var _mount_state: Object = preload("res://scripts/lingpet/lingpet_mount_state.gd").new()
# S3-a §A-4: 탑다운 준비도 게이트 + 최근 판정 결과(전체 dict 보존).
# ready 불리언만 남기지 않는 이유 = 슬라이스 B 가 이 결과의 rider_texture "객체"와
# rider_texture_key 를 재정규화·재조회 없이 actor context 로 그대로 전달해야
# P16② 동일 객체 계약이 성립한다. 갱신은 merge 금지·완전 교체, 펫 전환·전체
# 리셋 경계에서 fail-closed 빈 payload 로 클리어(잔재가 남으면 B 가 전환 프레임에
# 이전 펫의 N 객체를 발행한다).
var _mount_topdown_readiness: Object = preload("res://scripts/lingpet/lingpet_mount_topdown_readiness.gd").new()
var _mount_topdown_readiness_result: Dictionary = {}
var _companion_body_hit_state: Object = LingpetCompanionBodyHitState.new()
var _companion_body_presence_resolver: Object = LingpetCompanionBodyPresenceResolver.new()
var _companion_player_block_resolver: Object = LingpetCompanionPlayerBlockResolver.new()
var _companion_player_runtime_resolver: Object = LingpetCompanionPlayerRuntimeResolver.new()
var _companion_runtime_resetter: Object = LingpetCompanionRuntimeResetter.new()
var _collection_state: Object = LingpetCollectionState.new()
var _spirit_water_drop_state: Object = LingpetSpiritWaterDropState.new()
var _current_profile: Object = LingpetCurrentProfile.new()
var _overflow_guardian_snapshot_builder: Object = LingpetOverflowGuardianSnapshotBuilder.new()
# F7 debug-only stat overrides live in LingpetDebugStatOverrideState.
var _debug_stat_overrides: Object = LingpetDebugStatOverrideState.new()
# F7 debug-only defense-rate override. < 0 means "use the pet's catalog/profile
# value"; >= 0 forces that defense_rate for feel testing. Sticky across rounds so
# the override can be evaluated over a whole match; only the F7 picker writes it.
# F7 debug-only appearance-rate override (flight-style only). Same contract as the
# defense override: < 0 = use catalog/profile, >= 0 forces the value.
# F7 debug-only move-speed override. < 0 = use catalog/profile speed; >= 0 is a
# MULTIPLIER applied on top of the final enhancement/passive patrol speed.
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
var _rail_card_surface_builder: Object = LingpetRailCardSurfaceBuilder.new()
var _runtime_snapshot_cache: Dictionary = {}
var _runtime_snapshot_cache_valid := false
var _runtime_snapshot_cache_revision := -1
var _runtime_snapshot_cache_process_frame := -1
var _runtime_snapshot_cache_physics_frame := -1
var _runtime_snapshot_revision := 0
var _runtime_snapshot_build_count_for_tests := 0
var _vector_resolver: Object = LingpetRuntimeVectorResolver.new()
var _profile_runtime_surface: Object = LingpetProfileRuntimeSurface.new()
var _save_restore_applier: Object = LingpetSaveRestoreApplier.new()
var _save_restore_planner: Object = LingpetSaveRestorePlanner.new()
var _acquire_cutin_asset_prewarm_state: Object = LingpetAcquireCutinAssetPrewarmState.new()
var _acquire_cutin_overlay_host_resolver: Object = LingpetAcquireCutinOverlayHostResolver.new()
var _acquire_cutin_state: Object = LingpetAcquireCutinState.new()
var _acquisition_lifecycle: Object = LingpetAcquisitionLifecycleCoordinator.new()
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
var _guardian_run_state: Object = LingpetGuardianRunState.new()
var _guardian_run_context_coordinator: Object = LingpetGuardianRunContextCoordinator.new()
var _guard_hit_tag_resolver: Object = LingpetGuardHitTagResolver.new()
var _guard_feedback_state: Object = LingpetGuardFeedbackState.new()
var _duration_runtime_state: Object = LingpetDurationRuntimeState.new()
var _guardian_duration_lifecycle: Object = LingpetGuardianDurationLifecycleCoordinator.new()
# 직전 프레임에 실제로 그린 지속시간 게이지 레이아웃(안 그렸으면 visible=false).
# 공통 게이지 패스가 매번 덮어쓰므로 스테일 값이 남지 않는다 -- 씰이 실제 draw
# 경로를 관통해 게이지 랜딩을 관측하는 채널이다.
var _last_duration_gauge_layout: Dictionary = {}
var _guardian_stowed: bool:
	get:
		return bool(_guardian_duration_lifecycle.is_stowed_state())
	set(value):
		_guardian_duration_lifecycle.set_stowed_state(value)
var _soul_summon_overflow_available_for_tests := true
var _guardian_enhance_offer_engine: Object = LingpetGuardianEnhanceOfferEngine.new()
var _guardian_enhance_presentation: Object = LingpetGuardianEnhancePresentationCoordinator.new()
var _guardian_enhance_flow: Object = LingpetGuardianEnhanceFlowCoordinator.new()
var _guardian_active_elapsed: float:
	get:
		return float(_guardian_duration_lifecycle.get_active_elapsed())
	set(value):
		_guardian_duration_lifecycle.set_active_elapsed(value)
var _duration_warning_stage: int:
	get:
		return int(_guardian_duration_lifecycle.get_warning_stage_state())
	set(value):
		_guardian_duration_lifecycle.set_warning_stage_state(value)
var _duration_roll_rng_for_tests: RandomNumberGenerator:
	get:
		return _guardian_duration_lifecycle.get_duration_roll_rng_for_tests() as RandomNumberGenerator
	set(value):
		_guardian_duration_lifecycle.set_duration_roll_rng_for_tests(value)
var _hatch_stat_roll_state: Object = LingpetHatchStatRollState.new()
# Shell-break cinematic sequencer: the final counted egg hit no longer opens the
# acquire cut-in on the same frame. Instead the egg runs the 1.5s scripted
# shell-break (roll / staged cracks / light leak), burst hold, deferred commit,
# and acquire-cutin lifecycle now live in LingpetAcquisitionLifecycleCoordinator.
var _audio_dispatcher: Object = LingpetAudioDispatcher.new()
var _current_pet_transition: Object = LingpetCurrentPetTransition.new()
# Distance-roll state owns frame-to-frame drawn-position movement so override-held
# companions read idle instead of marching in place.
var _companion_distance_roll_state: Object = LingpetCompanionDistanceRollState.new()
var _none_owner_sync_state: Object = LingpetNoneOwnerSyncState.new()
var _overflow_choice_state: Object = LingpetOverflowChoiceState.new()
var _overflow_absorb_plan: Object = LingpetOverflowAbsorbPlan.new()
var _overflow_replace_plan: Object = LingpetOverflowReplacePlan.new()
var _pending_absorbed_collection_owner_sync: Array[String] = []
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
	_guardian_enhance_presentation.configure(_guardian_enhance_offer_engine)
	_guardian_enhance_flow.configure(
		_guardian_enhance_offer_engine,
		_guardian_enhance_presentation,
		_guardian_run_context_coordinator,
		_guardian_run_state,
		_collection_state,
		_current_profile,
		_loadout_state,
		_snapshot_builder,
		self
	)
	_acquisition_lifecycle.configure(
		_acquire_cutin_state,
		_acquire_cutin_asset_prewarm_state,
		_acquire_cutin_overlay_host_resolver,
		_egg_state,
		_overflow_choice_state,
		_item_egg_lifecycle_state,
		_current_profile,
		_audio_dispatcher,
		self,
		LingpetEggFieldRenderer.HATCH_FLASH_SECONDS
	)
	_guardian_duration_lifecycle.configure(
		_guardian_run_state,
		_duration_runtime_state,
		_guardian_transition_state,
		_collection_state,
		_current_profile,
		_profile_runtime_surface,
		_spirit_water_drop_state,
		_audio_dispatcher,
		_ghost_blink_vfx,
		_vector_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_afterglow_leak_state,
		_starlight_tracking_state,
		_ring_dash_state,
		_ring_dash_vfx,
		_mount_state,
		_companion_motion_state,
		_companion_body_hit_state,
		_companion_sprite_animator,
		_companion_click_reaction_state,
		_guard_feedback_state,
		self,
		GUARDIAN_MIN_SUMMON_SECONDS,
		DURATION_WARNING_STAGE_COUNT
	)
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
	_companion_motion_coordinator.configure(
		_current_profile,
		_active_skill_slot_resolver,
		_companion_skill_visual_resolver,
		_skill_runtime_host,
		_skill_runtime_surface,
		_mount_state,
		_companion_motion_state,
		_companion_click_reaction_state,
		_ring_dash_state,
		_ring_dash_vfx,
		_starlight_tracking_state,
		_profile_runtime_surface,
		_companion_skill_persistence,
		_companion_skill_states,
		_debug_stat_overrides,
		_companion_sprite_animator,
		_audio_dispatcher,
		_companion_player_runtime_resolver,
		self,
		COMPANION_HIT_HALF_WIDTH,
		COMPANION_HIT_HALF_HEIGHT,
		COMPANION_DEFENSE_RATE,
		COMPANION_PATROL_SPEED,
		COMPANION_PATROL_SPEED_MIN,
		COMPANION_PATROL_SPEED_MAX
	)


# physics.callback.lingpet.update measured ~1.0ms/tick standing as an opaque
# leaf, so every phase below carries a physics.lingpet.* label — keep the
# label set gap-free or the standing cost hides between labels again.
func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	_invalidate_runtime_snapshot_cache()
	_flush_pending_absorbed_collection_owner_sync(owner)
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
	# S2 permit 수신 면역 동기화: 장착 교체를 따라가도록 매 프레임 프로필 경유로
	# 갱신한다 (O(1) 인덱스 판정 — 딥카피 없음).
	for slot_index in range(_companion_skill_states.size()):
		if _companion_skill_states[slot_index] != null:
			_companion_skill_states[slot_index].shared_cooldown_immune = bool(_current_profile.is_interaction_permit_for_slot(slot_index))
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
		_guard_feedback_state.advance(delta)
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
		_acquisition_lifecycle.prewarm_registry_step(
			_acquire_cutin_state.get_display_pet_id(_pet_id),
			registry,
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
		var guard_hit_tags: Dictionary = _guard_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
		if guardian_summoned:
			_update_companion_motion(delta, owner, registry)
		else:
			_companion_body_hit_state.ball_was_inside = false
		_perf_probe.end(perf_logger, "physics.lingpet.companion_motion", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		guard_hit_tags = _guard_hit_tag_resolver.merge(
			guard_hit_tags,
			_guard_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
		)
		_ghost_blink_vfx.sync_visibility(
			guardian_summoned and _profile_runtime_surface.get_motion_style(_current_profile) == "free_flight",
			bool(_companion_motion_state.motion_visible),
			_companion_pos
		)
		# One switch must gate BOTH the body hit and the anticipatory strike. The
		# mount already suppresses `_resolve_companion_ball_hit`, so arming here
		# would animate a swing that can never connect (허공 스트라이크).
		if not guardian_summoned or _mount_state.is_mounted():
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
			_resolve_companion_ball_hit(owner, registry, guard_hit_tags)
		# Stream the NEW pet's heavy acquire cut-in sheets into the cache DURING incubation
		# (the companion's _pet_id would otherwise prewarm the wrong pet), so the reveal opens
		# already animated instead of holding on the static fallback.
		var item_egg_pet_id := str(_item_egg_lifecycle_state.get_pet_id())
		if _item_egg_lifecycle_state.is_active() and item_egg_pet_id != "":
			_acquisition_lifecycle.prewarm_registry_step(
				item_egg_pet_id,
				registry
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
			_acquisition_lifecycle.start_acquire_cutin(
				hatched_item_egg_pet_id,
				registry
			)
		_perf_probe.end(perf_logger, "physics.lingpet.ball_hit", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		_afterglow_leak_state.advance(delta, owner, registry, _profile_runtime_surface.get_passive_skill_by_id(_current_profile, LingpetAfterglowLeakState.PASSIVE_ID), guardian_summoned)
		_perf_probe.end(perf_logger, "physics.lingpet.afterglow", sample_start)
		sample_start = _perf_probe.begin(perf_logger)
		if guardian_summoned:
			_update_companion_skill_effects(delta, owner, registry)
		else:
			_skill_runtime_host.update_persistent_deployments(delta, owner, registry)
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
func build_guardian_enhance_offer(owner: Object) -> Dictionary:
	return _guardian_enhance_flow.build_offer(owner, _pet_id)


func apply_guardian_enhance_random_roll(
	candidates: Array,
	owner: Object = null,
	registry: Object = null,
	trigger_source: String = "perk"
) -> Dictionary:
	return _guardian_enhance_flow.apply_random_roll(
		candidates,
		owner,
		registry,
		trigger_source,
		_pet_id
	)


func build_guardian_enhance_live_candidates(owner: Object = null) -> Array:
	return _guardian_enhance_flow.build_live_candidates(owner, _pet_id)


func trigger_guardian_enhancement_from_absorption(
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	return _guardian_enhance_flow.trigger_from_absorption(owner, registry, _pet_id)


func can_apply_guardian_enhancement_candidate(candidate: Dictionary, pet_id: String) -> bool:
	return bool(_guardian_enhance_flow.can_apply_candidate(candidate, pet_id))


func apply_guardian_enhancement_candidate(
	candidate: Dictionary,
	owner: Object = null,
	registry: Object = null,
	pet_id: String = ""
) -> Dictionary:
	return _guardian_enhance_flow.apply_candidate(
		candidate,
		owner,
		registry,
		pet_id,
		_pet_id
	)


func apply_guardian_enhance_duration_fallback(
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	return _guardian_enhance_flow.apply_duration_fallback(owner, registry)


func complete_guardian_enhance_roll(
	result: Dictionary,
	display_pet_id: String,
	registry: Object = null,
	trigger_source: String = "perk",
	owner: Object = null
) -> void:
	_guardian_enhance_presentation.complete_roll(
		result,
		display_pet_id,
		_pet_id,
		registry,
		trigger_source,
		owner
	)


func is_guardian_enhance_cutin_active() -> bool:
	return bool(_guardian_enhance_presentation.is_active())


func get_guardian_enhance_cutin_snapshot() -> Dictionary:
	return _guardian_enhance_presentation.get_snapshot()


func advance_guardian_enhance_cutin(delta: float, registry: Object = null) -> void:
	_guardian_enhance_presentation.advance(delta, registry, _pet_id)


func cancel_guardian_enhance_cutin(registry: Object = null) -> bool:
	return bool(_guardian_enhance_presentation.cancel(registry))


func set_guardian_enhance_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_guardian_enhance_flow.set_roll_rng_for_tests(rng)


func get_guardian_enhance_offer_state_for_tests() -> Dictionary:
	return _guardian_enhance_flow.get_offer_state_for_tests()


func get_guardian_enhance_last_result_for_tests() -> Dictionary:
	return _guardian_enhance_presentation.get_last_result_for_tests()


func can_offer_egg_item(owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	if _state == STATE_EGG or _item_egg_lifecycle_state.has_blocking_incubation():
		return false
	if _acquisition_lifecycle.is_acquire_cutin_active() or _overflow_choice_state.has_pending_or_active():
		return false
	if _collection_state.is_auto_present_league(owner):
		return false
	return _collection_state.pick_random_any_pet_id() != ""


# Pro/Mythic active-item deploy of a random pet egg. Uncollected identities are
# preferred; a complete collection falls back to an absorb-only identity. Two cases:
#   * NO companion yet (STATE_NONE): the egg hatches into the companion (first acquisition),
#     mirroring _spawn_egg minus the junior-only tutorial auto-present branch.
#   * companion ALREADY on field (STATE_COMPANION): a SEPARATE coexisting egg incubates
#     alongside it (the companion is untouched) and opens Replace / Absorb after reveal.
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
	if _acquisition_lifecycle.is_acquire_cutin_active() or _overflow_choice_state.has_pending_or_active():
		return false
	if _item_egg_lifecycle_state.has_pending_absorb():
		return false
	_collection_state.sync_from_owner(owner)
	var pet_id: String = str(_collection_state.pick_random_unowned_pet_id(owner))
	if pet_id == "":
		pet_id = str(_collection_state.pick_random_any_pet_id())
	if pet_id == "":
		return false
	_acquisition_lifecycle.prewarm_registry_step(
		pet_id,
		registry
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
		or _acquisition_lifecycle.is_acquire_cutin_active()
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
	var dropped := deploy_egg_from_item(owner, registry, true)
	return {
		"dropped": dropped,
		"skipped_reason": "" if dropped else "deploy_rejected",
	}


func set_soul_summon_overflow_available_for_tests(available: bool) -> void:
	_soul_summon_overflow_available_for_tests = available


	# Fire the ghost "퐁" pop on the rabi free-flight vanish/appear edges. Only the


func prewarm_assets() -> void:
	if _prewarm_assets_complete:
		return
	_egg_renderer.prewarm()
	_afterglow_leak_state.prewarm()
	_guardian_transition_state.prewarm()
	if _companion_renderer != null:
		_companion_renderer.prewarm_assets()
	_item_egg_absorb_vfx.prewarm()
	_skill_runtime_host.prewarm_many(_skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host))
	_prewarm_assets_complete = true


var _prewarm_assets_step_index := 0
var _prewarm_skill_index := 0
var _prewarm_skill_ids: Array[String] = []
var _prewarm_assets_complete := false


func prewarm_assets_step() -> bool:
	if _prewarm_assets_complete:
		return true
	match _prewarm_assets_step_index:
		0:
			if _egg_renderer != null and _egg_renderer.has_method("prewarm_step"):
				if not bool(_egg_renderer.prewarm_step()):
					return false
			else:
				_egg_renderer.prewarm()
		1:
			if _afterglow_leak_state != null and _afterglow_leak_state.has_method("prewarm_step"):
				if not bool(_afterglow_leak_state.prewarm_step()):
					return false
			else:
				_afterglow_leak_state.prewarm()
		2:
			_guardian_transition_state.prewarm()
		3:
			if _companion_renderer != null:
				_companion_renderer.prewarm_assets()
		4:
			_item_egg_absorb_vfx.prewarm()
		5:
			if _prewarm_skill_ids.is_empty() and _prewarm_skill_index == 0:
				for skill_id_value in _skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host):
					var skill_id := str(skill_id_value)
					if skill_id != "":
						_prewarm_skill_ids.append(skill_id)
			if _prewarm_skill_index < _prewarm_skill_ids.size():
				_skill_runtime_host.prewarm(_prewarm_skill_ids[_prewarm_skill_index])
				_prewarm_skill_index += 1
				return false
		_:
			_prewarm_assets_step_index = 0
			_prewarm_skill_index = 0
			_prewarm_skill_ids.clear()
			_prewarm_assets_complete = true
			return true
	_prewarm_assets_step_index += 1
	return false


func get_prewarm_assets_debug_label() -> String:
	return str({
		0: "egg_textures",
		1: "afterglow_textures",
		2: "guardian_transition",
		3: "companion_renderer",
		4: "item_egg_absorb",
		5: "active_skill_%02d" % _prewarm_skill_index,
	}.get(_prewarm_assets_step_index, "done"))


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
				var front_body_alpha: float = _draw_companion(canvas, _companion_pos + shake_offset)
				_draw_companion_duration_gauge(
					canvas,
					_companion_pos + shake_offset,
					front_body_alpha
				)
			_afterglow_leak_state.draw(canvas, shake_offset)
		if _is_guardian_summoned() or _skill_runtime_host.has_visible_effects():
			_skill_runtime_host.draw(canvas, shake_offset, _perf_probe.get_draw_logger(_draw_context))
		# The lingpet BODY (egg sprite / companion sprite) is intentionally NOT drawn
		# here. It renders earlier, BEHIND the player, via draw_lingpet_body_behind_actors()
		# (invoked from the shared player actor renderer). Keeping it out of this
		# post-actor front pass is what makes an overlapping player render in front of the
		# lingpet. Only the companion's emanating VFX stay in front (ring dash / ghost
		# blink / guard feedback) plus the hatch flash.
		if _is_guardian_summoned() and _ring_dash_vfx.has_visible_effects():
			_ring_dash_vfx.draw(canvas, shake_offset)
		if _ghost_blink_vfx.has_visible_effects():
			_ghost_blink_vfx.draw(canvas, shake_offset)
		if _guardian_transition_state.is_active():
			_guardian_transition_state.draw(canvas, shake_offset)
		if _guard_feedback_state.has_visible_effects(_is_guardian_summoned()):
			_companion_renderer.draw_guard_feedback(
				canvas,
				_companion_pos + shake_offset,
				_companion_draw_context_builder.build_guard_feedback_config({
					"companion_active": _is_guardian_summoned(),
					"radius": COMPANION_RADIUS,
					"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
					"guard_feedback_state": _guard_feedback_state,
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
# VFX, ring-dash / ghost / guard feedback, and the hatch flash stay in draw() (the
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
		if _acquisition_lifecycle.get_hatch_break_burst_hold() > 0.0:
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
	# §C-2: 탑다운 탑승 중 메인 본체(오라·플래시·게이지 포함)는 M 콜백이 소유한다
	# — 여기서도 그리면 lane 위치와 안장 위치에 이중으로 그려진다. 공존 아이템
	# 알은 바로 위에서 이미 그렸으므로 보존된다(메서드 전체 return 금지 계약).
	if is_topdown_mount_composite_active():
		return
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
	# 게이지가 따라갈 알파는 "본체 표현이 이번 프레임에 실제로 사용한 알파"다.
	# 상수 1.0 을 가정하면 교체 전환(본체 0.42 바닥) / 클릭 교감 진입·종료 페이드
	# (본체 0 에서 시작) 구간에서 게이지만 단독으로 진하게 뜬다.
	var body_alpha: float = 0.0
	if not click_reaction_visible or guardian_transition_body_active:
		var transition_alpha: float = 1.0
		if guardian_transition_body_active:
			transition_alpha = float(_guardian_transition_state.get_companion_alpha())
		body_alpha = _draw_companion(
			canvas,
			_companion_pos + shake_offset,
			transition_alpha
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
		# 클릭 교감 반응 시트도 엄연히 "본체가 보이는" 표현이다. 이 분기가 게이지를
		# 안 태우면 교감하는 동안 게이지만 끊긴다. 알파는 반응 시트가 draw 게이트로
		# 쓰는 것과 같은 정본(get_alpha)을 읽어 진입 / 종료 페이드를 함께 탄다.
		body_alpha = clampf(float(_companion_click_reaction_state.get_alpha()), 0.0, 1.0)
	# 어느 본체 표현을 그렸든 게이지는 여기 공통 패스 한 곳에서만 나간다.
	_draw_companion_duration_gauge(
		canvas,
		_companion_pos + shake_offset,
		body_alpha
	)


func has_visible_effects() -> bool:
	return (
		_state == STATE_EGG
		or _is_guardian_summoned()
		or _switch_transition_state.get_ratio(COMPANION_SWITCH_TRANSITION_SECONDS) > 0.0
		or bool(_egg_state.has_hatch_flash())
		or _acquisition_lifecycle.is_acquire_cutin_active()
		or _afterglow_leak_state.has_visible_effects()
		or _ring_dash_vfx.has_visible_effects()
		or _ghost_blink_vfx.has_visible_effects()
		or _guardian_transition_state.is_active()
		or _guard_feedback_state.has_visible_effects(_is_guardian_summoned())
		or _skill_runtime_host.has_visible_effects()
		or _item_egg_lifecycle_state.is_active()
		or _item_egg_absorb_vfx.has_visible_effects()
	)


func get_boss_ai_context() -> Dictionary:
	var runtime_state := STATE_COMPANION if _is_guardian_summoned() else STATE_NONE
	return _skill_runtime_surface.get_boss_ai_context(runtime_state, STATE_COMPANION, _skill_runtime_host)


# D15 bridge — the ONLY surface the player-control path may read for 묵린변신.
# The deps builder wraps exactly this method in a fail-closed Callable (never the
# egg runtime object itself), and smasher_player_controller reuses the AIPill
# tracking math while it returns true. Peek-only all the way down: the host reads
# the module field without instantiating, so this is hot-path safe.
# Stow / pet-swap / round boundaries clear the module through the host fanout,
# so module state alone is authoritative — no companion-state re-check needed.
func is_mokrin_transform_active() -> bool:
	return bool(_skill_runtime_host.is_mokrin_transform_active())


# E' X1: base-paddle guard notification from the paddle-bounce event router.
# The X3 false-positive filter (thor shield / dual-glitch clone bounces) lives
# at the router call site; companion body guards and defense intercepts never
# route through register_player_hit, so they are structurally excluded.
func notify_mokrin_transform_player_guard(registry: Object = null) -> void:
	_skill_runtime_host.notify_mokrin_transform_player_guard(registry)


func get_ball_collision_context() -> Dictionary:
	var runtime_state := STATE_COMPANION if (
		_is_guardian_summoned()
		or _skill_runtime_host.has_persistent_deployments()
	) else STATE_NONE
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


# D15 seal hook: drives the INTERNAL host through its production launch entry
# (never a state-flag injection) so the narrow predicate can be sealed true/false
# against a real egg runtime. The full frame-flow activation seal (운영 launch가
# update_lingpet에서 성립 → 다음 update_player_control이 소비) needs a
# catalog-enabled baekrin profile and lands with S1b.
func launch_mokrin_transform_for_tests() -> bool:
	# Literal skill id on purpose: the delegation contract bans ANY skill-kind
	# dispatcher reference inside the egg runtime (lingpet_egg_runtime_smoke pins
	# the dispatcher class name to zero occurrences in this file, comments included).
	return bool(_skill_runtime_host.launch(
		"baekrin_mokrin_transform",
		Vector2.ZERO,
		null,
		{}
	))


func is_acquire_cutin_active() -> bool:
	return bool(_acquisition_lifecycle.is_acquire_cutin_active())


# True through the whole shell-break window: the state-scripted break motion
# PLUS the post-burst hold before the deferred hatch commit opens the cut-in.
# The modal gate reads this to hold battle physics (mirrors the cut-in).
func is_hatch_break_active() -> bool:
	return bool(_acquisition_lifecycle.is_hatch_break_active())


# Pumped from the frame controller's ungated idle path while the modal gate
# holds battle physics (mirrors advance_acquire_cutin): drives the scripted
# shell-break motion, bursts the shell on completion, then runs a short hold so
# the shard burst reads before the acquire cut-in covers it.
func advance_hatch_break(delta: float, owner: Object = null, registry: Object = null) -> void:
	_acquisition_lifecycle.advance_hatch_break(
		delta,
		owner,
		registry,
		_pet_id
	)


func _reset_hatch_break_sequence() -> void:
	_acquisition_lifecycle.reset_hatch_break_sequence()


# Advanced from the ungated idle pump (process_idle), so the reveal AND the exit
# action keep animating while the gated update driver is paused by the modal gate.
# The reveal is gated on the heavy Live2D acquisition sheet being cached: until then it
# holds in the reconstruction phase instead of locking solid on the static 원화 (the F7
# grant / 1-hit egg regression). We keep pumping the host's incremental stream here so
# the gate releases as soon as the sheet is ready, covering paths that skipped (or had
# too few) STATE_EGG calm frames.
func advance_acquire_cutin(delta: float, registry: Object = null) -> void:
	_acquisition_lifecycle.advance_acquire_cutin(delta, registry, _pet_id)


func get_acquire_cutin_progress() -> float:
	return float(_acquisition_lifecycle.get_acquire_cutin_progress())


# The reveal has finished playing and the cut-in is holding for a click/confirm.
# Excludes the dismissing phase so a click cannot re-trigger the exit action once
# it has started. Input is swallowed before this point so an early click cannot
# skip the reveal or leak into gameplay.
func is_acquire_cutin_awaiting_dismiss() -> bool:
	return bool(_acquisition_lifecycle.is_acquire_cutin_awaiting_dismiss())


# Begin the animated exit action (does NOT close immediately). The cut-in stays
# active (gameplay paused) until advance_acquire_cutin finishes the action+fade.
func begin_acquire_cutin_dismiss(registry: Object = null) -> bool:
	return bool(_acquisition_lifecycle.begin_acquire_cutin_dismiss(
		registry,
		_pet_id
	))


func is_acquire_cutin_dismissing() -> bool:
	return bool(_acquisition_lifecycle.is_acquire_cutin_dismissing())


func get_acquire_cutin_dismiss_progress() -> float:
	return float(_acquisition_lifecycle.get_acquire_cutin_dismiss_progress())


# Immediate hard close (cleanup / state-reset paths). The click handler uses
# begin_acquire_cutin_dismiss() instead so players see the exit action.
func dismiss_acquire_cutin() -> bool:
	return bool(_acquisition_lifecycle.dismiss_acquire_cutin())


func is_overflow_choice_active() -> bool:
	return bool(_overflow_choice_state.is_active())


func get_overflow_choice_snapshot() -> Dictionary:
	var snapshot: Dictionary = _overflow_choice_state.build_snapshot(_collection_state)
	return _overflow_guardian_snapshot_builder.enrich_choice_snapshot(
		snapshot,
		_overflow_choice_state.get_pending_pet_id(),
		_collection_state,
		_loadout_state,
		_guardian_run_state,
		_hatch_stat_roll_state
	)




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
		_guardian_run_state.forget_pet_data(old_pet_id)
		_companion_skill_persistence.forget_pet(old_pet_id)
	_guardian_run_state.forget_pet_data(pending_pet_id)
	_companion_skill_persistence.forget_pet(pending_pet_id)
	_finish_overflow_hatch_commit(owner, registry)
	return true


func commit_overflow_absorb(owner: Object = null, registry: Object = null) -> bool:
	var absorb_plan: Dictionary = _overflow_absorb_plan.consume(
		owner,
		_overflow_choice_state,
		_collection_state
	)
	if not bool(absorb_plan.get("handled", false)):
		return false
	_invalidate_runtime_snapshot_cache()
	var absorbed_pet_id := str(absorb_plan.get("absorbed_pet_id", ""))
	if absorbed_pet_id != "":
		if owner == null and not _pending_absorbed_collection_owner_sync.has(absorbed_pet_id):
			_pending_absorbed_collection_owner_sync.append(absorbed_pet_id)
		_loadout_state.forget_pet_loadout_and_invalidate(owner, absorbed_pet_id, _snapshot_builder)
		_guardian_run_state.forget_pet_data(absorbed_pet_id)
		_companion_skill_persistence.forget_pet(absorbed_pet_id)
	match str(absorb_plan.get("action", "")):
		LingpetOverflowAbsorbPlan.ACTION_RESTORE_COMPANION:
			_adopt_owned_pet(owner, str(absorb_plan.get("restore_pet_id", "")), registry)
		LingpetOverflowAbsorbPlan.ACTION_CLEAR_PENDING:
			_clear_pending_egg_without_collection_reset(owner, registry)
		_:
			_sync_owner(owner, registry)
	var enhancement_result := trigger_guardian_enhancement_from_absorption(owner, registry)
	return bool(enhancement_result.get("accepted", false))


func _flush_pending_absorbed_collection_owner_sync(owner: Object) -> void:
	if owner == null or _pending_absorbed_collection_owner_sync.is_empty():
		return
	for pet_id in _pending_absorbed_collection_owner_sync:
		_collection_state.record_collected_pet(owner, pet_id)
	_pending_absorbed_collection_owner_sync.clear()


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
		_guardian_run_state.forget_pet_data(old_pet_id)
		_companion_skill_persistence.forget_pet(old_pet_id)
	_guardian_run_state.forget_pet_data(new_pet)
	_companion_skill_persistence.forget_pet(new_pet)
	_ensure_duration_pool_roll()
	_refill_duration_pool_for_guardian_replacement()
	_hatch_stat_roll_state.roll_item_egg_hatch_traits(
		new_pet,
		_loadout_state,
		_item_egg_lifecycle_state.get_profile(),
		true
	)
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
	_companion_skill_persistence.save_current(_pet_id, _companion_skill_states, _skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host))
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
	_soul_summon_overflow_available_for_tests = true
	_set_current_pet_id(normalized_pet_id)
	_loadout_state.set_skip_unlock_reconcile(has_explicit_loadout)
	_apply_current_loadout(owner, true, false, registry)
	if owner != null:
		_collection_state.sync_from_owner(owner)
		var owner_slots: Array[String] = _collection_state.get_battle_slots()
		if owner_slots.is_empty():
			_collection_state.ensure_pet_active_slot(owner, normalized_pet_id)
		else:
			_collection_state.replace_slot(
				owner,
				_collection_state.get_active_slot_index(),
				normalized_pet_id
			)
	# Keep the unlock-reconcile skip sticky for debug-forced loadouts so later
	# same-pet unlock reconcile cannot overwrite an F7-selected skill.
	_apply_companion_position_surface(_companion_runtime_resetter.prepare_companion_activation(
		_build_companion_activation_context(owner, registry, true, true, true, true)
	))
	_initialize_companion_patrol(owner, true)
	if show_acquire_cutin:
		_acquisition_lifecycle.start_acquire_cutin("", registry)
	_sync_owner(owner, registry)
	return true


func get_plaza_resonance_egg_offer(owner: Object) -> Dictionary:
	return _plaza_resonance_egg_summary_builder.build_offer(
		owner,
		_state,
		owner != null
			and _state != STATE_EGG
			and not _acquisition_lifecycle.is_acquire_cutin_active()
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
		_companion_skill_persistence.save_current(_pet_id, _companion_skill_states, _skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host))
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
		_guardian_run_context_coordinator,
		_loadout_state,
		_guardian_run_state,
		_hatch_stat_roll_state,
		_companion_distance_roll_state,
		_guard_feedback_state,
		_companion_click_reaction_visual_prewarm_state,
		_acquire_cutin_asset_prewarm_state,
		_snapshot_builder
	)
	_mount_state.reset()
	_mount_state.set_pet_id(_pet_id)
	# 준비도 결과는 펫 정체성에 귀속 — 전환 경계에서 fail-closed 클리어(§A-4 rev8b).
	_mount_topdown_readiness_result = {}


func switch_lingpet_slot(slot_index: int, owner: Object = null, registry: Object = null) -> bool:
	_companion_skill_persistence.save_current(_pet_id, _companion_skill_states, _skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host))
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


func set_guardian_enhancement_reward_seed_for_tests(pet_id: String, reward_seed: int) -> void:
	var current_profile_changed: bool = bool(_guardian_run_context_coordinator.set_reward_seed_for_tests(
		pet_id,
		reward_seed,
		_pet_id,
		_current_profile,
		_loadout_state,
		_guardian_run_state
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
	return float(_profile_runtime_surface.apply_gauge_gain_per_hit(
		_current_profile,
		_is_guardian_summoned(),
		base_gain
	))


func get_player_speed_multiplier() -> float:
	return float(_profile_runtime_surface.get_player_speed_multiplier(
		_current_profile,
		_is_guardian_summoned()
	))


# Character-info stat tooltip soft contract. Passive bonuses are additive in
# LingpetCurrentProfile, so each row advances the cumulative ratio rather than
# multiplying independent 1 + pct values (which would overstate two slots).
func get_player_stat_breakdown(stat_key: String, base_value: float = 0.0) -> Array:
	return _profile_runtime_surface.build_player_stat_breakdown(
		_current_profile,
		_is_guardian_summoned(),
		stat_key,
		base_value
	)


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
	return _rail_card_surface_builder.get_surface(
		_state,
		_is_guardian_summoned(),
		_current_profile,
		_mount_state,
		_active_skill_slot_resolver,
		_companion_skill_persistence,
		_companion_skill_states,
		_skill_runtime_host,
		_skill_runtime_surface,
		COMPANION_SKILL_WINDUP_SECONDS,
		COMPANION_SKILL_FLASH_SECONDS
	)




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
	snapshot.merge(
		_rail_card_surface_builder.build_interaction_permit_projection(
			_current_profile,
			_mount_state
		),
		true
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
	snapshot["duration_pool"] = _guardian_run_state.get_duration_pool_current()
	snapshot["duration_pool_max"] = _guardian_run_state.get_duration_pool_max()
	snapshot["guardian_stowed"] = _guardian_stowed
	snapshot.merge(_guard_feedback_state.get_snapshot(_is_guardian_summoned()), true)
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
	_rail_card_surface_builder.invalidate_frame_cache()


func reset_runtime_snapshot_cache_counters_for_tests() -> void:
	_runtime_snapshot_build_count_for_tests = 0
	_rail_card_surface_builder.reset_build_counters_for_tests()
	_invalidate_runtime_snapshot_cache()


func get_runtime_snapshot_build_count_for_tests() -> int:
	return _runtime_snapshot_build_count_for_tests


func get_rail_card_surface_build_count_for_tests() -> int:
	return int(_rail_card_surface_builder.get_surface_build_count_for_tests())


func get_rail_card_static_surface_build_count_for_tests() -> int:
	return int(_rail_card_surface_builder.get_static_surface_build_count_for_tests())


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
	var guardian_run_state: Dictionary = _guardian_run_state.export_run_state()
	guardian_run_state.merge(_hatch_stat_roll_state.export_run_state(), true)
	guardian_run_state.merge(_spirit_water_drop_state.export_run_state(), true)
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
		_collection_state.get_collected_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_profile_runtime_surface.get_gauge_gain_bonus_pct(_current_profile, 0.0),
		_companion_motion_state,
		_loadout_state.get_loadouts(),
		guardian_run_state
	)
	snapshot["guardian_stowed"] = _guardian_stowed
	return snapshot


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func export_guardian_run_state() -> Dictionary:
	var run_state: Dictionary = _guardian_run_state.export_run_state()
	run_state.merge(_hatch_stat_roll_state.export_run_state(), true)
	run_state.merge(_spirit_water_drop_state.export_run_state(), true)
	return run_state


# Restore the run-scoped duration, enhancement buffs, hatch traits, and spirit-
# water latch carried in a save snapshot. The applier calls this after its reset
# and before pet/profile projection so an in-run restore preserves one run owner.
func import_guardian_run_state(run_state: Dictionary) -> void:
	if run_state.is_empty():
		return
	_invalidate_runtime_snapshot_cache()
	_hatch_stat_roll_state.import_run_state(run_state)
	_guardian_run_state.import_run_state(run_state)
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
			_guardian_run_state.is_duration_resummon_locked()
		))
	)
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = _get_duration_warning_stage()
	return result


func restore_save_snapshot(snapshot: Dictionary, owner: Object = null, registry: Object = null) -> Dictionary:
	return apply_save_snapshot(snapshot, owner, registry)


func reset_for_tests() -> void:
	_guardian_enhance_flow.reset_for_tests()
	_invalidate_runtime_snapshot_cache()
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_companion_skill_persistence.reset_stage_observer()
	_current_profile.set_enhancement_rewards(LingpetGuardianRunState.get_empty_reward_counts())
	_loadout_state.invalidate_runtime_and_snapshot_cache(_snapshot_builder)
	_guardian_run_state.reset_for_new_run()
	_hatch_stat_roll_state.reset_for_new_run()
	_spirit_water_drop_state.reset_run()
	_guardian_run_context_coordinator.reset_for_new_run()
	_guard_feedback_state.reset_all()
	_duration_runtime_state.reset()
	_guardian_stowed = false
	_guardian_active_elapsed = 0.0
	_duration_warning_stage = 0
	_duration_roll_rng_for_tests = null
	_pending_absorbed_collection_owner_sync.clear()
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
	_mount_topdown_readiness_result = {}
	var owner: Object = deps.get("owner", null) as Object
	var registry: Object = deps.get("registry", null) as Object
	cancel_guardian_enhance_cutin(registry)
	if _overflow_choice_state.has_pending_or_active():
		commit_overflow_absorb(owner, registry)
		# Round teardown may settle an unanswered hatch by absorption, but the
		# shared enhancement path must not reopen its compact presentation while
		# the battle shell is leaving the round.
		cancel_guardian_enhance_cutin(registry)
	_round_resetter.reset_round(
		owner,
		registry,
		_guardian_run_state,
		_guard_feedback_state,
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
		_starlight_tracking_state
	)


func _clear_lingpet_field_state() -> void:
	_invalidate_runtime_snapshot_cache()
	_guardian_enhance_presentation.reset_presentation_state()
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
	_guard_feedback_state.reset_all()
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
		# S2 permit: 복원 시 면역을 "현재 장착"에서 재계산하기 위한 정체성 전달
		# (저장 bool 정본 금지 — 로드아웃 교체 시 낡은 권한 함정).
		"companion_skill_ids": _skill_runtime_surface.get_active_skill_ids(_current_profile, _active_skill_slot_resolver, _skill_runtime_host),
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
		_acquisition_lifecycle.begin_hatch_break(
			_collection_state.is_full(owner)
		)
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


func _begin_overflow_hatch(owner: Object, registry: Object = null, perf_logger: Object = null) -> void:
	_prepare_overflow_preview_loadout(_pet_id)
	_overflow_choice_state.begin_main_overflow(
		_pet_id,
		_collection_state.is_absorb_only_candidate(owner, _pet_id)
	)
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


func _prepare_overflow_preview_loadout(pet_id: String) -> Dictionary:
	var normalized_pet_id: String = _loadout_state.normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	var stored_loadout: Dictionary = _loadout_state.get_stored_loadout(normalized_pet_id)
	if not stored_loadout.is_empty():
		return stored_loadout
	var rolled_loadout: Dictionary = _loadout_state.roll_and_store_pet_loadout_unsynced(normalized_pet_id, null)
	_loadout_state.invalidate_owner_loadout_sync_for_runtime()
	_overflow_guardian_snapshot_builder.invalidate_replacement()
	return rolled_loadout


func _finish_overflow_hatch_commit(owner: Object, registry: Object = null) -> void:
	var kept_pet_id := str(_overflow_choice_state.consume_commit_pet_id())
	_ensure_duration_pool_roll()
	_refill_duration_pool_for_guardian_replacement()
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
# open the shared Replace / Absorb choice -- all while the companion keeps
# accompanying the player until the player decides.
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
		_prepare_overflow_preview_loadout(absorb_pet)
		_sync_owner(owner, registry)
		return
	# The only free-slot case is the first live guardian; later eggs always opened
	# Replace / Absorb above because the live roster cap is one.
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
		_guardian_run_state,
		_unlock_loadout_reconciler,
		_hatch_stat_roll_state,
		_guardian_run_context_coordinator,
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


func _get_companion_position_for_guardian_duration() -> Vector2:
	return _companion_pos


func _update_companion_motion(delta: float, owner: Object, registry: Object = null) -> void:
	# §A-4: 매 컴패니언 갱신마다 readiness 를 cache-only 재판정해 완전 교체한다.
	# resolve 는 비탑다운 모델이면 peek 조차 하지 않으므로(온이마루 무접촉) 매
	# 프레임 비용은 모델 축 불리언 하나다.
	refresh_topdown_mount_readiness(owner, registry)
	_companion_motion_coordinator.update(
		delta,
		owner,
		registry,
		_pet_id,
		_is_guardian_summoned(),
		_compute_mount_body_presentation_incompatible(owner),
		_compute_topdown_mount_not_ready()
	)


# §A-4 런타임 fail-closed 의 게이트 항: 탑다운 모델인데 최근 판정이 ready 가
# 아니면 true(진입 차단·탑승 중 철회). 비탑다운 모델은 항상 false — 준비도가
# 목말(온이마루) 경로에 어떤 영향도 주지 않는다.
func _compute_topdown_mount_not_ready() -> bool:
	if not bool(_current_profile.is_mount_presentation_topdown()):
		return false
	return not bool(_mount_topdown_readiness_result.get("ready", false))


# S3-a §C-3c: 탑다운 모델 × 플레이어 본체 대체. 판정은 여기(egg)가 소유하고
# mount_state 는 철회 전이만 소유한다. 목말(온이마루)은 모델 축이 false 라
# 변신 중에도 항상 false = 현행 무접촉.
func _compute_mount_body_presentation_incompatible(owner: Object) -> bool:
	if not bool(_current_profile.is_mount_presentation_topdown()):
		return false
	return _is_player_body_replaced(owner)


# 플레이어 본체를 다른 렌더러가 대체하는 5조건 (renderer 실측과 동일 의미론).
# ⚠️ mythic_item_runtime.is_*() 직접 호출 금지 — 공개 메서드가
#    _ensure_helpers_ready() → prewarm_initialization_step() 동기 초기화 루프를
#    탈 수 있어 매 프레임 게이트에 못 쓴다. owner 투영을 읽는다(운영 프레임에서
#    mythic update 가 lingpet update 보다 먼저 갱신하므로 stale 하지 않다).
# ⚠️ 오딘 첫 항은 OR 가 아니라 renderer 와 같은 **fallback** 이다
#    (stage1_player_actor_renderer.gd:249-256 `odins_context.get("transformed",
#    odins_context.get("penalty_active", false))`): transformed 키가 존재하며
#    false 면 penalty_active=true 여도 본체가 대체되지 않는다.
static func _is_player_body_replaced(owner: Object) -> bool:
	var odin_transformed := bool(BattleSceneOwnerReader.get_value(
		owner,
		"odins_eye_transformed",
		BattleSceneOwnerReader.get_value(owner, "odins_eye_penalty_active", false)
	))
	return (
		odin_transformed
		or bool(BattleSceneOwnerReader.get_value(owner, "odins_eye_revival_animation_active", false))
		or bool(BattleSceneOwnerReader.get_value(owner, "odins_eye_death_animation_active", false))
		or bool(BattleSceneOwnerReader.get_value(owner, "horn_strawberry_transformed", false))
		or bool(BattleSceneOwnerReader.get_value(owner, "horn_strawberry_event_playing", false))
	)


# S3-a §C-3d: pre-pause reconcile. pause 게이트(뿔딸기 이벤트 등)가
# update_lingpet 앞에서 프레임을 반환하는 동안 advance() 가 돌지 않으므로,
# 프레임 플로가 update_mythic_items 직후·pause 재검사 앞에 이걸 부른다.
# 시계·입력·위치는 전진시키지 않는다(순수 판정 + 멱등 철회). 반환 = 실제 철회
# 발생 여부. 철회 시 같은 프레임 스냅샷 무효화(레일이 stale interaction_active
# 를 읽지 않도록). 이미 하차 상태면 캐시를 건드리지 않는다(멱등 — pause
# 프레임마다 불리므로 무효화 남발은 스냅샷 캐시 무력화다).
func reconcile_topdown_mount_body_presentation(owner: Object) -> bool:
	if not _compute_mount_body_presentation_incompatible(owner):
		return false
	if not bool(_mount_state.force_dismount_for_body_presentation()):
		return false
	_invalidate_runtime_snapshot_cache()
	return true


# S3-a §A-4: 준비도 재판정 + 결과 보존(merge 금지·완전 교체). 원시 캐릭터 id 는
# 폴백 ""(누락 = 미준비)로 읽는다 — "smasher" 폴백은 필드 누락을 fail-open 으로
# 되돌린다(normalize() 폴백과 같은 구멍). normalize() 선행 통과도 금지 — 미지
# 값이 smasher 로 둔갑해 strict 정본화가 거부할 기회를 잃는다. cache-only 판정
# (resolver 내부 계약)이라 매 프레임 안전. 슬라이스 B 가 소비 시점을 정한다.
func refresh_topdown_mount_readiness(owner: Object, registry: Object) -> Dictionary:
	var raw_character_id := str(BattleSceneOwnerReader.get_value(owner, "selected_character_type", ""))
	_mount_topdown_readiness_result = _mount_topdown_readiness.resolve(
		raw_character_id,
		bool(_current_profile.is_mount_presentation_topdown()),
		_current_profile,
		registry
	)
	return _mount_topdown_readiness_result


func get_topdown_mount_readiness() -> Dictionary:
	return _mount_topdown_readiness_result


# S3-b: 탑다운 합성 활성 = 탑다운 모델 × 실제 탑승. 준비도 게이트가 미준비
# 탑승을 같은 프레임 철회하므로(A-3) 탑승 중은 readiness ready 가 함께 성립한다.
func is_topdown_mount_composite_active() -> bool:
	return bool(_current_profile.is_mount_presentation_topdown()) and bool(_mount_state.is_mounted())


# S3-b §B-3: M 베이스 콜백. 플레이어 렌더러가 flicker return 뒤·상태 글로우 앞에서
# 최종 라이더 rect 를 넘겨 호출한다(§B-3 rev3). final_rider_rect 에는 shake 가
# 이미 포함돼 있으므로 재가산하지 않는다(§B-3b).
# M/N 텍스처 정본 = 보존된 readiness 결과(§A-4a) — 여기서 캐시를 재조회하면
# P16② 동일 객체 계약이 공허해진다.
func draw_topdown_mount_base(canvas: CanvasItem, final_rider_rect: Rect2) -> void:
	if canvas == null or not is_topdown_mount_composite_active():
		return
	var mount_texture: Texture2D = _mount_topdown_readiness_result.get("mount_texture", null) as Texture2D
	if mount_texture == null:
		return
	# §B-2 fail-closed: 6키 중 하나라도 없거나 값이 어긋나면 **그리지 않는다**.
	# 기본값 보정(1px·5×5/25·셀 중앙 소켓)은 오슬라이스·소켓 미정렬 그림을 조용히
	# 승인하는 길이라 금지다 — 결손은 저작 결함이고 화면에 남으면 안 된다.
	var layout: Dictionary = _resolve_topdown_mount_layout()
	if layout.is_empty():
		return
	var draw_size: float = float(layout["companion_mount_base_draw_size"])
	# 그리드 3값은 해석기가 이미 정수로 정규화했다(절단 아님 — roundi).
	var sheet_meta := {
		"cols": roundi(float(layout["companion_mount_base_cols"])),
		"rows": roundi(float(layout["companion_mount_base_rows"])),
		"frame_count": roundi(float(layout["companion_mount_base_frame_count"])),
	}
	# source 슬라이싱은 animator 규칙 재사용(§B-3c) — build_draw_rects() 는 금지
	# (WALK_Y_OFFSET −6 dest 보정을 다시 넣는다). 정적 1×1·1f = frame 0.
	var source_rect: Rect2 = _companion_sprite_animator.get_source_rect(mount_texture, 0, sheet_meta)
	# §B-3 배치: seat point = 라이더 rect 하단 중앙. 안장 소켓(셀-로컬 px)이
	# seat point 에 일치하도록 mount rect 를 역산한다.
	# 0 나눗셈만 막는 가드다(규격 폴백이 아니다 — 규격은 위에서 이미 확정).
	var cell_size := Vector2(
		maxf(0.001, source_rect.size.x),
		maxf(0.001, source_rect.size.y)
	)
	var saddle_local := Vector2(
		float(layout["companion_mount_base_saddle_x"]),
		float(layout["companion_mount_base_saddle_y"])
	)
	var seat_point := Vector2(final_rider_rect.position.x + final_rider_rect.size.x * 0.5, final_rider_rect.end.y)
	var dest_size := Vector2(draw_size, draw_size)
	var dest_position := seat_point - (saddle_local / cell_size) * dest_size
	var dest_rect := Rect2(dest_position, dest_size)
	var draw_config: Dictionary = _build_companion_draw_config()
	# §B-3d 반경: 베이스만 비례(16 × draw/82), 플래시 가산항은 renderer 가 불변 유지.
	var radius: float = 16.0 * (draw_size / 82.0)
	_companion_renderer.draw_topdown_mount_composite(
		canvas,
		dest_rect,
		mount_texture,
		source_rect,
		radius,
		draw_config
	)
	# §C-2: 게이지 이관 — 본체 패스와 같은 알파 정본, 기하는 M 중심·M draw_size
	# (walk 상수 미사용, 계약 14b).
	var body_alpha: float = LingpetCompanionRenderer.resolve_body_draw_alpha(draw_config)
	_last_duration_gauge_layout = LingpetDurationFieldGaugeRenderer.draw_gauge(
		canvas,
		dest_rect.get_center(),
		{
			"duration_gauge_enabled": body_alpha > 0.0 and _is_guardian_summoned(),
			"duration_pool_current": _guardian_run_state.get_duration_pool_current(),
			"duration_pool_max": _guardian_run_state.get_duration_pool_max(),
			"duration_drain_exempt": _guardian_run_state.is_duration_drain_exempt_latched(),
			"walk_draw_size": draw_size,
			"topdown_mount_draw_size": draw_size,
		},
		body_alpha
	)


# §B-2: 탑다운 M 레이아웃 6키 해석. 하나라도 부재/비유한/범위 이탈이면 빈 dict
# 를 돌려 호출자가 그리기를 포기하게 한다(fail-closed). 부재와 0.0 을 구분해야
# 하므로 조회 fallback 은 NAN 이다 — 0.0 을 쓰면 "미저작 소켓"이 좌상단 정렬로
# 조용히 통과한다.
const MOUNT_LAYOUT_INTEGRAL_KEYS := [
	"companion_mount_base_cols",
	"companion_mount_base_rows",
	"companion_mount_base_frame_count",
]
# 카탈로그 검증(`_validate_mount_presentation`)과 **같은** 정수 허용오차.
const MOUNT_LAYOUT_INTEGER_EPSILON := 0.001


func _resolve_topdown_mount_layout() -> Dictionary:
	var values: Dictionary = {}
	for layout_key in LingpetCatalog.MOUNT_TOPDOWN_REQUIRED_LAYOUT_KEYS:
		var value: float = _current_profile.get_visual_layout_value(str(layout_key), NAN)
		if not is_finite(value):
			return {}
		values[str(layout_key)] = value
	var draw_size: float = float(values["companion_mount_base_draw_size"])
	if draw_size <= 0.0:
		return {}
	# 그리드 3값은 **정수 계약**이다. 유한·양수만 보고 소비 지점에서 int() 로
	# 절단하면 두 방향으로 갈라진다: 2.5 는 조용히 2 가 되고(저작 오류가 그림으로
	# 남는다), 1.9995 는 카탈로그 ±0.001 검증을 통과하는데 int() 는 1 을 준다
	# (검증이 승인한 그리드와 실제 슬라이싱이 어긋난다). 같은 허용오차로 판정하고
	# 통과분은 roundi 로 정규화해 돌려준다 — 소비 지점에는 이미 정수만 간다.
	for integral_key in MOUNT_LAYOUT_INTEGRAL_KEYS:
		var raw: float = float(values[str(integral_key)])
		if raw < 1.0:
			return {}
		if absf(raw - roundf(raw)) > MOUNT_LAYOUT_INTEGER_EPSILON:
			return {}
		values[str(integral_key)] = float(roundi(raw))
	# 용량 판정은 정규화 뒤 값으로 한다(1.9995→2 가 승인된 그리드다).
	if float(values["companion_mount_base_frame_count"]) > float(values["companion_mount_base_cols"]) * float(values["companion_mount_base_rows"]):
		return {}
	return values


# 탑승 토글은 맨 우클릭을 쓰는데, 스매셔 벽력유성이 "우클릭 홀드로 무장 →
# 타구 시점 발사" 계약으로 바뀌면서 같은 버튼을 쓴다. 무장 가능한(=장착 +
# 기력 + 쿨타임 + 랠리 진행 중) 순간에는 스킬이 우클릭을 소유하고, 그 외
# (서브 대기 / 쿨타임 / 기력 부족 / 미장착 / 타 캐릭터)에는 탑승이 그대로
# 가져간다. 그래서 랠리 밖에서는 탑승이 100% 종전대로 동작한다.
# ⚠️peek 전용(`get_cached_instance`) — 매 컴패니언 프레임 경로라 콜드
# 인스턴스화가 끼면 첫 호출이 히치가 된다(Hot-Path Lazy Init Trap).
func _is_right_click_claimed_by_player_skill(owner: Object, registry: Object = null) -> bool:
	# Older focused fixtures called this helper with the registry as the only
	# argument. Preserve that test surface without cold-instantiating Viper.
	if registry == null:
		registry = owner
		owner = null
	return bool(_companion_player_runtime_resolver.is_right_click_claimed_by_player_skill(
		owner,
		registry
	))


func _is_player_guard_available(registry: Object) -> bool:
	return bool(_companion_player_runtime_resolver.is_player_guard_available(registry))


# 링크포트(ring_dash) 이중수비 게이트용 플레이어 대쉬 스냅샷.
# ⚠️peek 전용(`get_cached_instance`) — `get_instance` 폴백을 넣지 마라.
# 여기는 매 물리 프레임 도는 컴패니언 모션 경로이고, 콜드 인스턴스화가 끼면
# 첫 호출이 100ms+ 히치가 된다(Godot Hot-Path Lazy Init Trap).
# `smasher_dash_state`는 부트 프리웜 대상이라 실전에선 peek이 항상 적중하고,
# 미캐시(=대쉬 시스템 미가동)면 빈 dict로 정적 패들 게이트만 남는다.
# 스냅샷 dict 생성도 대쉬 중일 때만 — 비대쉬 프레임은 bool 한 번으로 끝난다.
func _resolve_player_dash_state(registry: Object) -> Dictionary:
	return _companion_player_runtime_resolver.resolve_player_dash_state(registry)


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


func _resolve_companion_ball_hit(owner: Object, registry: Object = null, captured_guard_hit_tags: Dictionary = {}) -> bool:
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
	if (
		_companion_player_runtime_resolver.is_player_guard_available(registry)
		and _companion_player_block_resolver.can_player_block(
			owner,
			BALL_RADIUS_FALLBACK,
			155.0
		)
	):
		_companion_body_hit_state.ball_was_inside = false
		return false

	var guard_hit_tags: Dictionary = _guard_hit_tag_resolver.merge(
		captured_guard_hit_tags,
		_guard_hit_tag_resolver.capture(_companion_motion_state, _ring_dash_state)
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
	if _guard_hit_tag_resolver.has_defense_tag(guard_hit_tags):
		_guard_feedback_state.trigger_guard_label(_companion_body_hit_state.last_contact_pos)
	if bool(guard_hit_tags.get("defense_intercept", false)):
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
		_starlight_tracking_state,
		_companion_motion_state,
		_companion_distance_roll_state,
		COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO
	))


# 본체 스프라이트가 이번 프레임에 실제로 사용한 최종 알파를 반환한다(안 그렸으면
# 0.0). 게이지 공통 패스가 이 값을 그대로 받아 써야 본체와 게이지가 같은 페이드를
# 탄다 -- 호출부가 1.0 을 가정하면 교체 전환에서 본체만 흐려진다.
func _draw_companion(
	canvas: CanvasItem,
	center: Vector2,
	transition_alpha: float = 1.0
) -> float:
	var draw_config: Dictionary = _build_companion_draw_config(transition_alpha)
	_companion_renderer.draw_companion(canvas, center, draw_config)
	# 렌더러가 스프라이트에 실제로 먹인 알파와 같은 정본을 읽는다.
	return LingpetCompanionRenderer.resolve_body_draw_alpha(draw_config)


# 본체/탑다운 합성이 공유하는 draw config 정본. §B-3d 이관 레이어(오라·플래시)가
# 본체 패스와 같은 소스(guard_feedback·skill state·ghost alpha)를 읽게 한다.
func _build_companion_draw_config(transition_alpha: float = 1.0) -> Dictionary:
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
		_starlight_tracking_state,
		_companion_motion_state,
		_companion_distance_roll_state,
		COMPANION_SORTIE_FLAP_MIN_SPEED_RATIO
	)
	if guardian_inactive:
		draw_motion_speed_ratio = 0.0
	# E1-③ (묵린변신): the flash palette style rides the active-skill DATA as a
	# string and must reach the draw config through this params channel — the
	# visual_layout path is float-only and would silently zero it.
	var active_skill_visual: Dictionary = {}
	var active_skill_value: Variant = visual_surface.get("active_skill", {})
	if active_skill_value is Dictionary:
		active_skill_visual = active_skill_value
	var companion_visible: bool = _companion_body_presence_resolver.is_visible_for_draw_from_surface(
		visual_surface,
		_ring_dash_state,
		_starlight_tracking_state,
		_companion_motion_state
	)
	var draw_config: Dictionary = _companion_draw_context_builder.build_config({
		"companion_skill_flash_style": str(active_skill_visual.get("companion_skill_flash_style", "")),
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
		"companion_visible": companion_visible,
		# Ghost (free_flight) fade alpha, 0..1. The renderer multiplies the companion
		# sprite + aura by this so rabi fades out/in instead of hard-popping. 1.0 for
		# non-ghost pets (motion state leaves ghost_alpha at 1.0 for them).
		"companion_alpha": _companion_motion_state.ghost_alpha * clampf(transition_alpha, 0.0, 1.0),
		"windup_seconds": float(visual_surface.get("windup_seconds", 0.0)),
		"guard_feedback_state": _guard_feedback_state,
		"mount_carry_active": _mount_state.is_mounted(),
	})
	return draw_config


# SD 캐릭터 좌측 세로 지속시간 게이지. 본체 표현이 여러 갈래(일반 SD / 클릭 교감
# 반응 시트 / 스타코일 바인드)라서 게이지는 각 분기가 아니라 분기 "뒤" 공통 패스인
# 여기 한 곳에서만 나간다 -- 분기마다 호출을 흩뿌리면 새 본체 표현이 추가될 때
# 게이지만 조용히 끊긴다(클릭 교감 중 게이지 소실이 그 사례였다).
#
# body_alpha = 본체 표현이 이번 프레임에 실제로 사용한 최종 알파. 여기서 다시
# 계산하지 않고 그대로 받아 쓴다(ghost / 교체 전환 / 클릭 페이드가 이미 반영돼
# 있으므로 재계산은 이중 적용이거나 불일치가 된다). 0 이면 본체가 안 나온
# 프레임이므로 게이지도 없다.
func _draw_companion_duration_gauge(
	canvas: CanvasItem,
	center: Vector2,
	body_alpha: float
) -> void:
	var alpha: float = clampf(body_alpha, 0.0, 1.0)
	_last_duration_gauge_layout = LingpetDurationFieldGaugeRenderer.draw_gauge(
		canvas,
		center,
		{
			"duration_gauge_enabled": alpha > 0.0 and (
				_is_guardian_summoned() or _guardian_transition_state.is_active()
			),
			"duration_pool_current": _guardian_run_state.get_duration_pool_current(),
			"duration_pool_max": _guardian_run_state.get_duration_pool_max(),
			"duration_drain_exempt": _guardian_run_state.is_duration_drain_exempt_latched(),
			"walk_draw_size": _get_companion_walk_draw_size(),
		},
		alpha
	)


func _get_companion_walk_draw_size() -> float:
	if _current_profile == null or not _current_profile.has_method("get_visual_layout_value"):
		return 0.0
	return maxf(0.0, float(_current_profile.get_visual_layout_value("companion_walk_draw_size", 0.0)))


func get_last_duration_gauge_layout_for_tests() -> Dictionary:
	return _last_duration_gauge_layout


# Begin the in-battle click-reaction playback if the click landed on the
# patrolling companion. Battle is NOT paused -- the reaction temporarily replaces
# the small SD companion at the same in-field size and fades out on its own.
# playfield_pos is in game/playfield
# coordinates (caller converts the viewport click via the layout render_scale /
# game_offset). Returns true when the click was consumed by the companion.
func try_begin_companion_click_reaction(playfield_pos: Vector2, registry: Object = null) -> bool:
	if not _is_guardian_summoned():
		return false
	# 탑승 중엔 클릭 교감 금지: the click zone overlaps the paddle while mounted, and
	# the reaction sheet REPLACES the carry composite -- the rider would hang in the
	# air while the mount swaps to a full-size reaction still.
	if _mount_state.is_mounted():
		return false
	if not _companion_body_presence_resolver.can_begin_click_reaction(
		_companion_motion_state,
		_ring_dash_state
	):
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
	return bool(_guardian_duration_lifecycle.refill_for_stage_transition())


# The natural field drop is a STRICT SUPERSET of the direct item reward gate: it
# must first satisfy the same Soul Summoning Art access + owned-guardian check
# (can_offer_spirit_water_item), then add the natural-drop-only conditions
# (unconsumed per-stage latch, drained duration pool).
#
# The access check is not redundant with the pool condition. Owned pet ids persist
# across runs in the collection save, and a restored save can carry a drained
# duration pool into a run WITHOUT the art — pool_current < pool_max then passes
# and the drop would offer spirit water the player can never use.
func can_offer_spirit_water_drop(owner: Object = null, registry: Object = null) -> bool:
	if not can_offer_spirit_water_item(owner, registry):
		return false
	return _spirit_water_drop_state.can_offer(
		true,
		_guardian_run_state.get_duration_pool_current(),
		_guardian_run_state.get_duration_pool_max()
	)


func can_offer_spirit_water_item(owner: Object = null, registry: Object = null) -> bool:
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	return not _collection_state.get_owned_pet_ids_from_owner(owner).is_empty()


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
	var result: Dictionary = _guardian_run_state.restore_duration_pool_to_full_preserving_overfill()
	if not bool(result.get("accepted", false)):
		return result
	_invalidate_runtime_snapshot_cache()
	_sync_owner(owner, registry)
	result["item_name"] = "lingpet_spirit_water"
	return result


func get_spirit_water_drop_snapshot_for_tests() -> Dictionary:
	return _spirit_water_drop_state.get_snapshot()


func get_duration_pool_current() -> float:
	return _guardian_run_state.get_duration_pool_current()


func get_duration_pool_max() -> float:
	return _guardian_run_state.get_duration_pool_max()


func get_duration_pool_pct() -> int:
	return _guardian_run_state.get_duration_pool_pct()


func can_resummon_guardian() -> bool:
	return _guardian_run_state.can_resummon_guardian()


func is_guardian_stowed() -> bool:
	return bool(_guardian_duration_lifecycle.is_stowed(_state, STATE_COMPANION))


func try_toggle_guardian_stow(
	owner: Object = null,
	registry: Object = null
) -> bool:
	if _state != STATE_COMPANION or _pet_id.strip_edges() == "":
		return false
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return false
	return bool(_guardian_duration_lifecycle.try_toggle(
		_state,
		STATE_COMPANION,
		_pet_id,
		owner,
		registry
	))


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
	return float(_guardian_duration_lifecycle.get_active_elapsed())


func set_duration_pool_for_tests(current: float, maximum: float = 0.0) -> void:
	_guardian_duration_lifecycle.set_duration_pool_for_tests(current, maximum)


func set_duration_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_guardian_duration_lifecycle.set_duration_roll_rng_for_tests(rng)


func get_guardian_enhancement_rewards_for_tests(pet_id: String = "") -> Dictionary:
	var normalized_pet_id: String = _current_profile.normalize_pet_id(pet_id)
	return _guardian_run_state.get_cumulative_rewards(normalized_pet_id if normalized_pet_id != "" else _pet_id)


func _advance_duration_pool(
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> void:
	_guardian_duration_lifecycle.advance(
		delta,
		owner,
		registry,
		_state,
		STATE_COMPANION,
		_pet_id
	)


func _get_active_duration_pct() -> int:
	return int(_guardian_duration_lifecycle.get_active_duration_pct(
		_state,
		STATE_COMPANION
	))


func _ensure_duration_pool_roll() -> Dictionary:
	return _guardian_duration_lifecycle.ensure_duration_pool_roll()


# A replacement guardian arrives at full uptime: breaking a new egg and swapping out the
# live guardian restores the run-shared duration pool to 100%. The roll itself is
# once-per-run (ensure_initial_roll returns "already_rolled"), so pool_max -- including
# every Guardian Enhancement duration increase -- is preserved and only the current value
# is restored. Overfill above the maximum (spirit water / revalidation fallback) survives,
# and the expiry resummon lock clears with the refill. Absorption is NOT a replacement and
# deliberately keeps the pool where it stands.
func _refill_duration_pool_for_guardian_replacement() -> Dictionary:
	return _guardian_duration_lifecycle.refill_for_guardian_replacement()


func _set_guardian_stowed(
	stowed: bool,
	owner: Object,
	registry: Object,
	forced: bool = false,
	preserve_nekuring_deployments: bool = false
) -> bool:
	return bool(_guardian_duration_lifecycle.set_stowed(
		_state,
		STATE_COMPANION,
		stowed,
		owner,
		registry,
		forced,
		preserve_nekuring_deployments
	))


func _complete_guardian_summon_transition(owner: Object, registry: Object) -> void:
	_guardian_duration_lifecycle.complete_summon_transition(
		_state,
		STATE_COMPANION,
		owner,
		registry
	)


func _is_guardian_duration_draining() -> bool:
	return bool(_guardian_duration_lifecycle.is_duration_draining(
		_state,
		STATE_COMPANION
	))


func _end_guardian_runtime_for_stow(
	owner: Object,
	registry: Object,
	preserve_nekuring_deployments: bool = false
) -> void:
	_guardian_duration_lifecycle.end_runtime_for_stow(
		owner,
		registry,
		preserve_nekuring_deployments
	)


func _is_guardian_summoned() -> bool:
	return bool(_guardian_duration_lifecycle.is_summoned(_state, STATE_COMPANION))


func _get_duration_warning_stage() -> int:
	return int(_guardian_duration_lifecycle.get_duration_warning_stage())
