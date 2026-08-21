extends RefCounted

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkAngelBlessingLocalization := preload("res://scripts/characters/runtime_perk_angel_blessing_localization.gd")
const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkSkillCooldownPause := preload("res://scripts/characters/runtime_perk_skill_cooldown_pause.gd")
const RuntimePerkDeferredInstants := preload("res://scripts/characters/runtime_perk_deferred_instants.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkInstantChoiceFlow := preload("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
const RuntimePerkLevelSideEffects := preload("res://scripts/characters/runtime_perk_level_side_effects.gd")
const RuntimePerkOwnerEffectSync := preload("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
const RuntimePerkOwnerSyncFlow := preload("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
const RuntimePerkResumeSafety := preload("res://scripts/characters/runtime_perk_resume_safety.gd")
const RuntimePerkStarpointAbsorption := preload("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
const RuntimePerkStarpointCollectionFlow := preload("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
const RuntimePerkGamepadNavigation := preload("res://scripts/characters/runtime_perk_gamepad_navigation.gd")
const RuntimePerkSnapshotBuilder := preload("res://scripts/characters/runtime_perk_snapshot_builder.gd")
const RuntimePerkEffectiveStatQuerySurface := preload("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
const RuntimePerkChoiceAudio := preload("res://scripts/characters/runtime_perk_choice_audio.gd")
const RuntimePerkChoiceFeedback := preload("res://scripts/characters/runtime_perk_choice_feedback.gd")
const RuntimePerkChoiceOfferModifiers := preload("res://scripts/characters/runtime_perk_choice_offer_modifiers.gd")
const RuntimePerkChoiceOpening := preload("res://scripts/characters/runtime_perk_choice_opening.gd")
const RuntimePerkChoicePipelineState := preload("res://scripts/characters/runtime_perk_choice_pipeline_state.gd")
# Source-contract aliases remain on the facade while helper construction and
# mutable test seams live exclusively in RuntimePerkChoicePipelineState.
const RuntimePerkChoiceSelection := RuntimePerkChoicePipelineState.RuntimePerkChoiceSelection
const RuntimePerkChoiceCompletion := RuntimePerkChoicePipelineState.RuntimePerkChoiceCompletion
const RuntimePerkChoiceDispatch := RuntimePerkChoicePipelineState.RuntimePerkChoiceDispatch
const RuntimePerkChoiceActionRunner := RuntimePerkChoicePipelineState.RuntimePerkChoiceActionRunner
const RuntimePerkChoiceStandardPath := RuntimePerkChoicePipelineState.RuntimePerkChoiceStandardPath
const RuntimePerkChoiceOpenFlow := RuntimePerkChoicePipelineState.RuntimePerkChoiceOpenFlow
const RuntimePerkChoiceApplyFlow := RuntimePerkChoicePipelineState.RuntimePerkChoiceApplyFlow
const RuntimePerkChoiceConfirmFlow := RuntimePerkChoicePipelineState.RuntimePerkChoiceConfirmFlow
const RuntimePerkChoiceFinishFlow := RuntimePerkChoicePipelineState.RuntimePerkChoiceFinishFlow
const RuntimePerkUnlockPipelineState := preload("res://scripts/characters/runtime_perk_unlock_pipeline_state.gd")
const RuntimePerkActiveUnlockFlight := RuntimePerkUnlockPipelineState.RuntimePerkActiveUnlockFlight
const RuntimePerkUnlockShowcase := RuntimePerkUnlockPipelineState.RuntimePerkUnlockShowcase
const RuntimePerkUnlockShowcaseFlow := RuntimePerkUnlockPipelineState.RuntimePerkUnlockShowcaseFlow
const RuntimePerkUnlockSwapLayout := RuntimePerkUnlockPipelineState.RuntimePerkUnlockSwapLayout
const RuntimePerkUnlockSwapFlow := RuntimePerkUnlockPipelineState.RuntimePerkUnlockSwapFlow
const RuntimePerkUnlockChoiceApply := RuntimePerkUnlockPipelineState.RuntimePerkUnlockChoiceApply
const RuntimePerkUpdateFlow := preload("res://scripts/characters/runtime_perk_update_flow.gd")
const RuntimePerkDebugGrants := preload("res://scripts/characters/runtime_perk_debug_grants.gd")
const RuntimePerkOwnerProjection := preload("res://scripts/characters/runtime_perk_owner_projection.gd")
const RuntimePerkGoldAwardFlow := preload("res://scripts/characters/runtime_perk_gold_award_flow.gd")
const RuntimePerkResetState := preload("res://scripts/characters/runtime_perk_reset_state.gd")
const RuntimePerkModalInput := preload("res://scripts/characters/runtime_perk_modal_input.gd")
const RuntimePerkDynamicEffects := preload("res://scripts/characters/runtime_perk_dynamic_effects.gd")
const RuntimePerkDisplayProjectionState := preload("res://scripts/characters/runtime_perk_display_projection_state.gd")
const RuntimePerkFusionRuntimeState := preload("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkMysticDiceRuntimeState := preload("res://scripts/characters/runtime_perk_mystic_dice_runtime_state.gd")
const RuntimePerkPhysiqueTrainingRuntimeState := preload("res://scripts/characters/runtime_perk_physique_training_runtime_state.gd")
const RuntimePerkAngelBlessingRuntimeState := preload("res://scripts/characters/runtime_perk_angel_blessing_runtime_state.gd")
const RuntimePerkChosikEventState := preload("res://scripts/characters/runtime_perk_chosik_event_state.gd")
const RuntimePerkHyeonmunCharyeokRuntimeState := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")

const STARPOINT_PER_SKILL_CHOICE := 1
const BASE_PERK_CHOICE_COUNT := 3
const PLAYER_BASE_PADDLE_HEIGHT := RuntimePerkEffectiveLevels.PLAYER_BASE_PADDLE_HEIGHT
const SPECIAL_GAUGE_MAX := 500.0
const BASE_ACTIVE_ITEM_SLOT_LIMIT := RuntimePerkEffectiveLevels.BASE_ACTIVE_ITEM_SLOT_LIMIT
const PARTICLE_COUNT := 20
const PARTICLE_LIFE := 1.45
const ACTIVE_UNLOCK_FLIGHT_DURATION := RuntimePerkActiveUnlockFlight.DURATION
const ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT := RuntimePerkActiveUnlockFlight.PARTICLE_COUNT
const UNLOCK_SHOWCASE_MAX_AGE := RuntimePerkUnlockShowcase.MAX_AGE
const UNLOCK_SHOWCASE_MIN_DISMISS_AGE := RuntimePerkUnlockShowcase.MIN_DISMISS_AGE
const VIPER_IGNITION_AURA_LEVEL_BONUS := RuntimePerkEffectiveLevels.VIPER_IGNITION_AURA_LEVEL_BONUS
const ITEM_CAFFEINE_ID := RuntimePerkEffectiveLevels.ITEM_CAFFEINE_ID
const ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.ITEM_CAFFEINE_DURATION_BONUS_PER_LEVEL
const ITEM_POLISH_ID := RuntimePerkEffectiveLevels.ITEM_POLISH_ID
const ITEM_POLISH_ROLL_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.ITEM_POLISH_ROLL_BONUS_PER_LEVEL
const PERK_POLISH_AMPLIFY_PER_LEVEL := RuntimePerkEffectiveLevels.PERK_POLISH_AMPLIFY_PER_LEVEL
const TRAINING_MASTERY_ID := RuntimePerkEffectiveLevels.TRAINING_MASTERY_ID
const TRAINING_MASTERY_AMPLIFY_PER_LEVEL := RuntimePerkEffectiveLevels.TRAINING_MASTERY_AMPLIFY_PER_LEVEL
const ITEM_RECYCLE_ID := RuntimePerkEffectiveLevels.ITEM_RECYCLE_ID
const ITEM_RECYCLE_CHANCE_PER_LEVEL := RuntimePerkEffectiveLevels.ITEM_RECYCLE_CHANCE_PER_LEVEL
const MAX_ITEM_RECYCLE_CHANCE := RuntimePerkEffectiveLevels.MAX_ITEM_RECYCLE_CHANCE
const PERK_LAUREL_SHIELD_ID := RuntimePerkEffectiveLevels.PERK_LAUREL_SHIELD_ID
const DASH_ACCELERATION_ID := RuntimePerkEffectiveLevels.DASH_ACCELERATION_ID
const DASH_ACCELERATION_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.DASH_ACCELERATION_BONUS_PER_LEVEL
const CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END := RuntimePerkDeferredInstants.DEFER_DIMENSION_GATE_CONTEXT_KEY
const CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END := RuntimePerkDeferredInstants.DEFER_FULL_GAUGE_CONTEXT_KEY
const DOWNTOWN_TREASURE_MAP_ID := RuntimePerkEffectiveLevels.DOWNTOWN_TREASURE_MAP_ID
const TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL
const TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.TREASURE_MAP_VISION_BOX_CHANCE_BONUS_PER_LEVEL
const PERK_POLISH_AMPLIFIABLE_BONUS_IDS := RuntimePerkEffectiveLevels.PERK_POLISH_AMPLIFIABLE_BONUS_IDS
const VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS := RuntimePerkEffectiveLevels.VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS
const PROMOTED_FUSION_BYPRODUCT_IDS: Array[String] = ["gravitybelt", "smartphone"]
const DEBUG_PHYSIQUE_TRAINING_OFFER_LOG := RuntimePerkPhysiqueTrainingRuntimeState.DEBUG_OFFER_LOG
const PROBE_ACTIVE_ITEM_COOLDOWN_BASE_MSEC := RuntimePerkPhysiqueTrainingRuntimeState.PROBE_ACTIVE_ITEM_COOLDOWN_BASE_MSEC

var runtime_skill_levels: Dictionary = {}
var starpoint_for_skills := 0
var pending_skill_choices := 0
var choice_active := false
var current_choices: Array = []
var selected_index := 0
# 퍽 선택 모달의 마우스 포인터(상태 패널 "현재 퍽" hover 판정용) —
# 모달 입력 핸들러가 매 motion마다 갱신한다.
var status_hover_mouse_pos: Vector2 = Vector2(-1.0, -1.0)
var animation_time := 0.0
var particles: Array = []
var gold_from_perks := 0
# ---- 퍽 융합 위임 계층 ----
# 코어(records/커밋/오버레이/한계돌파)는 PerkFusionState가 소유하고, 이
# 래퍼는 central getter·projection·부산물 런타임을 잇는 접착만 담당한다.
var feedback_text := ""
var feedback_timer := 0.0
var last_selected_id := ""
var last_selected_choice: Dictionary = {}
var selected_choice_sequence := 0
var item_gold_gain_multiplier := 1.0
var item_perk_level_bonus := 0
var viper_ignition_aura_active := false
var viper_ignition_aura_owner_sync_dirty := false
var pending_unlock_swap: Dictionary = {}
var unlock_swap_selected_index := 0
var choice_flight_effect: Dictionary = {}
var unlock_showcase: Dictionary = {}
var gamepad_choice_horizontal_latch := 0
var gamepad_unlock_swap_horizontal_latch := 0
var current_choice_context: Dictionary = {}
var current_perk_slot_status: Dictionary = {}
# 하단 능력치 원장(2026-08-06): 캐릭터 정보창의 "플레이어 능력치" 10행을 퍽
# 선택 모달 아래에 그대로 싣는다. owner/registry가 실제로 붙어 있는 컨텍스트
# (전투 / 광장 / 스테이지 클리어)에서만 켜지고, 레이아웃과 카드 히트테스트가
# 동일한 값을 읽어야 하므로 프레임 시작 update()에서 한 번만 갱신한다.
var stats_band_enabled := false
var _stats_context_owner: Object = null
var _stats_context_registry_ref: WeakRef = null
var _character_context: Object = RuntimePerkCharacterContext.new()
var _registry_lookup: Object = RuntimePerkRegistryLookup.new()
var _choice_layout: Object = RuntimePerkChoiceLayout.new()
var _unlock_pipeline_state: Object = RuntimePerkUnlockPipelineState.new()
var _active_unlock_flight: Object:
	get:
		return _unlock_pipeline_state.get_active_unlock_flight()
	set(value):
		_unlock_pipeline_state.set_active_unlock_flight(value)
var _unlock_showcase_controller: Object:
	get:
		return _unlock_pipeline_state.get_unlock_showcase_controller()
	set(value):
		_unlock_pipeline_state.set_unlock_showcase_controller(value)
var _unlock_showcase_flow: Object:
	get:
		return _unlock_pipeline_state.get_unlock_showcase_flow()
	set(value):
		_unlock_pipeline_state.set_unlock_showcase_flow(value)
var _unlock_swap_layout: Object:
	get:
		return _unlock_pipeline_state.get_unlock_swap_layout()
	set(value):
		_unlock_pipeline_state.set_unlock_swap_layout(value)
var _unlock_swap_flow: Object:
	get:
		return _unlock_pipeline_state.get_unlock_swap_flow()
	set(value):
		_unlock_pipeline_state.set_unlock_swap_flow(value)
var _unlock_choice_apply: Object:
	get:
		return _unlock_pipeline_state.get_unlock_choice_apply()
	set(value):
		_unlock_pipeline_state.set_unlock_choice_apply(value)
var _skill_cooldown_pause: Object = RuntimePerkSkillCooldownPause.new()
var _deferred_instants: Object = RuntimePerkDeferredInstants.new()
var _effective_levels: Object = RuntimePerkEffectiveLevels.new()
var _instant_rewards: Object = RuntimePerkInstantRewards.new()
var _instant_choice_flow: Object = RuntimePerkInstantChoiceFlow.new()
var _level_side_effects: Object = RuntimePerkLevelSideEffects.new()
var _owner_effect_sync: Object = RuntimePerkOwnerEffectSync.new()
var _owner_sync_flow: Object = RuntimePerkOwnerSyncFlow.new()
var _resume_safety: Object = RuntimePerkResumeSafety.new()
var _starpoint_absorption: Object = RuntimePerkStarpointAbsorption.new()
var _starpoint_collection_flow: Object = RuntimePerkStarpointCollectionFlow.new()
var _gamepad_navigation: Object = RuntimePerkGamepadNavigation.new()
var _snapshot_builder: Object = RuntimePerkSnapshotBuilder.new()
var _effective_stat_queries: Object = RuntimePerkEffectiveStatQuerySurface.new()
var _angel_blessing_state: Object:
	get:
		return _angel_blessing_runtime_state.get_state()
var _angel_blessing_modal_flow: Object:
	get:
		return _angel_blessing_runtime_state.get_modal_flow()
var _choice_audio: Object = RuntimePerkChoiceAudio.new()
var _choice_feedback: Object = RuntimePerkChoiceFeedback.new()
var _choice_offer_modifiers: Object = RuntimePerkChoiceOfferModifiers.new()
var _choice_opening: Object = RuntimePerkChoiceOpening.new()
var _choice_pipeline_state: Object = RuntimePerkChoicePipelineState.new()
var _choice_selection: Object:
	get:
		return _choice_pipeline_state.get_selection()
	set(value):
		_choice_pipeline_state.set_selection(value)
var _choice_completion: Object:
	get:
		return _choice_pipeline_state.get_completion()
	set(value):
		_choice_pipeline_state.set_completion(value)
var _choice_dispatch: Object:
	get:
		return _choice_pipeline_state.get_dispatch()
	set(value):
		_choice_pipeline_state.set_dispatch(value)
var _choice_action_runner: Object:
	get:
		return _choice_pipeline_state.get_action_runner()
	set(value):
		_choice_pipeline_state.set_action_runner(value)
var _choice_standard_path: Object:
	get:
		return _choice_pipeline_state.get_standard_path()
	set(value):
		_choice_pipeline_state.set_standard_path(value)
var _choice_open_flow: Object:
	get:
		return _choice_pipeline_state.get_open_flow()
	set(value):
		_choice_pipeline_state.set_open_flow(value)
var _choice_apply_flow: Object:
	get:
		return _choice_pipeline_state.get_apply_flow()
	set(value):
		_choice_pipeline_state.set_apply_flow(value)
var _choice_confirm_flow: Object:
	get:
		return _choice_pipeline_state.get_confirm_flow()
	set(value):
		_choice_pipeline_state.set_confirm_flow(value)
var _update_flow: Object = RuntimePerkUpdateFlow.new()
var _choice_finish_flow: Object:
	get:
		return _choice_pipeline_state.get_finish_flow()
	set(value):
		_choice_pipeline_state.set_finish_flow(value)
var _debug_grants: Object = RuntimePerkDebugGrants.new()
var _owner_projection: Object = RuntimePerkOwnerProjection.new()
var _gold_award_flow: Object = RuntimePerkGoldAwardFlow.new()
var _reset_state: Object = RuntimePerkResetState.new()
var _modal_input: Object = RuntimePerkModalInput.new()
var _dynamic_effects: Object = RuntimePerkDynamicEffects.new()
var _display_projection_state: Object = RuntimePerkDisplayProjectionState.new()
var _fusion_runtime_state: Object = RuntimePerkFusionRuntimeState.new()
var _mystic_dice_runtime_state: Object = RuntimePerkMysticDiceRuntimeState.new()
var _physique_training_runtime_state: Object = RuntimePerkPhysiqueTrainingRuntimeState.new()
var _physique_training_catalog: Object:
	get:
		return _physique_training_runtime_state.get_catalog()
	set(value):
		_physique_training_runtime_state.set_catalog(value)
var _physique_training_state: Object:
	get:
		return _physique_training_runtime_state.get_state()
	set(value):
		_physique_training_runtime_state.set_state(value)
var _physique_training_offer_planner: Object:
	get:
		return _physique_training_runtime_state.get_offer_planner()
	set(value):
		_physique_training_runtime_state.set_offer_planner(value)
var _angel_blessing_runtime_state: Object = RuntimePerkAngelBlessingRuntimeState.new()
var _chosik_event_state: Object = RuntimePerkChosikEventState.new()
var _hyeonmun_charyeok_runtime_state: Object = RuntimePerkHyeonmunCharyeokRuntimeState.new()
var _hyeonmun_charyeok_state: Object:
	get:
		return _hyeonmun_charyeok_runtime_state.get_state()
	set(value):
		_hyeonmun_charyeok_runtime_state.set_state(value)
var _hyeonmun_charyeok_renderer: Object:
	get:
		return _hyeonmun_charyeok_runtime_state.get_renderer()
	set(value):
		_hyeonmun_charyeok_runtime_state.set_renderer(value)


func get_perk_fusion_state() -> Object:
	return _fusion_runtime_state.get_fusion_state()


# 커밋: 코어가 record를 소유하고 revision을 올린다 — projection 캐시 키에
# revision이 들어가므로 커밋은 자동으로 캐시를 무효화한다.
func commit_perk_fusion(source_ids: Array, outcome_data: Dictionary, catalog: Object) -> Dictionary:
	return _fusion_runtime_state.commit_fusion(source_ids, outcome_data, catalog, runtime_skill_levels)


func restore_perk_fusion_snapshot(snapshot: Dictionary, catalog: Object) -> Dictionary:
	var removed_legacy_expansion := false
	if PerkConversionFlags.is_enabled() and runtime_skill_levels.has("common_expansion"):
		runtime_skill_levels.erase("common_expansion")
		removed_legacy_expansion = true
	var result: Dictionary = _fusion_runtime_state.restore_snapshot(snapshot, catalog, runtime_skill_levels)
	result["removed_legacy_common_expansion"] = removed_legacy_expansion
	return result


func apply_perk_fusion_option_value(perk_id: String, option_key: String, base_value: float) -> float:
	return _fusion_runtime_state.apply_option_value(perk_id, option_key, base_value)


func get_perk_fusion_snapshot() -> Dictionary:
	return _fusion_runtime_state.get_snapshot()


func get_perk_fusion_effective_level_bonus(perk_id: String) -> int:
	return _fusion_runtime_state.get_effective_level_bonus(perk_id)


func get_perk_fusion_byproduct_chance_bonus_percent() -> float:
	return _fusion_runtime_state.get_byproduct_chance_bonus_percent(self)


func get_perk_fusion_owned_byproduct_ids() -> Array[String]:
	var owned: Array[String] = _fusion_runtime_state.get_owned_byproduct_ids()
	# 이전 세이브의 일반 무공 레벨은 상승무공 보유로 투영한다. 신규 획득은
	# 오직 합일 레코드를 통하지만, 구 세이브의 효과/표시/중복 제외는 보존한다.
	if PerkConversionFlags.is_enabled():
		for byproduct_id: String in PROMOTED_FUSION_BYPRODUCT_IDS:
			if int(runtime_skill_levels.get(byproduct_id, 0)) > 0 and byproduct_id not in owned:
				owned.append(byproduct_id)
	owned.sort()
	return owned


func has_perk_fusion_byproduct(byproduct_id: String) -> bool:
	return byproduct_id.strip_edges() in get_perk_fusion_owned_byproduct_ids()


func get_perk_fusion_slot_reduction() -> int:
	return _fusion_runtime_state.get_slot_reduction()


func get_perk_fusion_active_item_slot_bonus() -> int:
	return _fusion_runtime_state.get_active_item_slot_bonus(
		_get_perk_fusion_dash_amplification_count()
	)


func get_perk_fusion_active_item_slot_bonus_breakdown() -> Dictionary:
	return _fusion_runtime_state.get_active_item_slot_bonus_breakdown(
		_get_perk_fusion_dash_amplification_count()
	)


func _get_perk_fusion_dash_amplification_count() -> int:
	return maxi(0, int(round(_effective_stat_queries.get_runtime_skill_bonus_from_runtime_state(
		self,
		"dash_amplification"
	))))


# 황금 궤적: 부산물 런타임이 라운드 40 실골드 캡을 소유한다. 골드 배수
# (아이템 배수·점화 오라)는 클램프 "이전"에 적용해, 배수로 부풀린 지급이
# 실 저장 골드 기준 캡을 넘지 못하게 한다.
func award_perk_fusion_wall_bounce_gold(_context: Dictionary, deps: Dictionary) -> int:
	var actual: int = int(_fusion_runtime_state.consume_wall_bounce_gold_award(
		item_gold_gain_multiplier,
		viper_ignition_aura_active
	))
	if actual <= 0:
		return 0
	# The byproduct owner has already applied every multiplier and recorded the
	# actual capped amount. Store that exact amount through the canonical gold
	# flow so feedback state stays in sync without applying modifiers twice.
	_gold_award_flow.store_gold_gain_from_runtime_state(self, actual, 1.0, true, deps)
	return actual


func get_runtime_perk_gold_total() -> int:
	return maxi(0, gold_from_perks)


func get_perk_fusion_round_golden_trajectory_gold() -> int:
	return _fusion_runtime_state.get_round_golden_trajectory_gold()


# 융합 결과 컨텍스트(모달/부산물 payload 후보): 한계돌파 자격은 "base 레벨이
# 저작 테이블 최대"인 소스 — 자격 판정은 catalog의 max_level과 비교한다.
func _build_perk_fusion_result_context(source_ids: Array, catalog: Object) -> Dictionary:
	return _fusion_runtime_state.build_result_context(source_ids, catalog, runtime_skill_levels)


func get_perk_fusion_display_projection(catalog: Object = null) -> Dictionary:
	return _display_projection_state.get_composite_projection(self, catalog)


func get_perk_fusion_display_cache_stats() -> Dictionary:
	return _display_projection_state.get_cache_stats()


# ── 신비의 주사위 위임 계층 (융합 위임 패턴 미러) ────────────────────
# 코어 모듈(state/roller/planner/modal flow/input/paddle effect)은 각자
# 소유 파일에 살고, 이 파사드는 배선·리비전·리셋 경계만 소유한다.

var _mystic_dice_modal_flow: Object:
	get:
		return _mystic_dice_runtime_state.peek_modal_flow()
	set(value):
		_mystic_dice_runtime_state.set_modal_flow(value)
var _mystic_dice_modal_input: Object:
	get:
		return _mystic_dice_runtime_state.peek_modal_input()
	set(value):
		_mystic_dice_runtime_state.set_modal_input(value)
var _mystic_dice_offer_planner: Object:
	get:
		return _mystic_dice_runtime_state.get_offer_planner()
	set(value):
		_mystic_dice_runtime_state.set_offer_planner(value)
var _mystic_dice_paddle_effect_pending: bool:
	get:
		return _mystic_dice_runtime_state.is_paddle_effect_pending()
	set(value):
		_mystic_dice_runtime_state.set_paddle_effect_pending(value)


func _get_mystic_dice_modal_flow() -> Object:
	return _mystic_dice_runtime_state.get_modal_flow()


func _get_mystic_dice_modal_input() -> Object:
	return _mystic_dice_runtime_state.get_modal_input()


func commit_mystic_dice_roll(raw_roll: Dictionary) -> Dictionary:
	return _mystic_dice_runtime_state.commit_roll(raw_roll)


func get_mystic_dice_raw(stat_key: String) -> int:
	return _mystic_dice_runtime_state.get_raw(stat_key)


func get_mystic_dice_multiplier(stat_key: String) -> float:
	return _mystic_dice_runtime_state.get_multiplier(stat_key)


func get_mystic_dice_revision() -> int:
	return _mystic_dice_runtime_state.get_revision()


func get_mystic_dice_snapshot() -> Dictionary:
	return _mystic_dice_runtime_state.get_snapshot()


func get_mystic_dice_display_projection() -> Dictionary:
	# Kept as a snapshot compatibility key; the retired perk no longer projects
	# into the acquired-Mugong grid.
	return {}


func get_physique_training_snapshot() -> Dictionary:
	return _physique_training_runtime_state.get_snapshot()


func restore_physique_training_snapshot(snapshot: Dictionary) -> Dictionary:
	return _physique_training_runtime_state.restore(snapshot)


func get_physique_training_count(training_id: String) -> int:
	return _physique_training_runtime_state.get_count(training_id)


func get_physique_training_bonus(stat_key: String) -> float:
	return _physique_training_runtime_state.get_bonus(
		stat_key,
		get_physique_training_multiplier()
	)


func get_physique_training_multiplier() -> float:
	if not PerkConversionFlags.is_enabled():
		return 1.0
	return 1.0 + maxf(0.0, get_runtime_skill_bonus(TRAINING_MASTERY_ID))


# 실효 포화 자격 판정(2026-08-08 재리뷰 P1). 카탈로그 고정 천장은 **수련 누적치만**
# 보므로, 기보유 이관 무공과 곱/합 합성되는 호환 런에서는 천장 도달 **전에** 이미
# 죽은 카드가 된다(순환결 + item_cooldown_mastery Lv.5 = 13회차에서 이미 5% 하한,
# 수세결 + dash_module_control Lv.5 = 10회차에서 1프레임 하한, 철심공 +
# bulletproof_hat Lv.5 = 16회차에서 100%). 그래서 고정 상한이 아니라
# **"한 번 더 습득하면 최종 소비자 값이 실제로 바뀌는가"** 를 실 공식으로 묻는다.
func is_physique_training_saturated(training_id: String, registry: Object = null) -> bool:
	return _physique_training_runtime_state.is_saturated_from_runtime_state(
		self,
		training_id,
		registry
	)


func _apply_physique_training_choice(choice: Dictionary, owner: Object, registry: Object) -> bool:
	return _physique_training_runtime_state.apply_choice_from_runtime_state(
		self,
		choice,
		owner,
		registry
	)


func project_next_physique_training_choice(
	choice: Dictionary,
	registry: Object,
	projector: Callable
) -> Dictionary:
	return _physique_training_runtime_state.project_next_choice_from_runtime_state(
		self,
		choice,
		registry,
		projector
	)


func _try_inject_physique_training_offer(
	_dice_appeared: bool,
	fusion_appeared: bool = false,
	appearance_roll_unit: float = -1.0,
	selection_roll_unit: float = -1.0,
	replacement_roll_unit: float = -1.0,
	registry: Object = null
) -> Dictionary:
	return _physique_training_runtime_state.try_inject_offer_from_runtime_state(
		self,
		_dice_appeared,
		fusion_appeared,
		appearance_roll_unit,
		selection_roll_unit,
		replacement_roll_unit,
		registry
	)


# Legacy test/save seam. Production offers no longer surface Mystic Dice;
# acquisition now belongs to the active-item field/reward pools.
func _try_inject_mystic_dice_offer(roll_unit: float = -1.0) -> Dictionary:
	return {
		"rolled": false,
		"retired_to_active_item": true,
		"ignored_roll_unit": roll_unit,
	}


# 융합 오퍼 후처리: 수련보다 먼저 돈다. 융합은 일반 replaceable lane만
# 교체하며, 성공한 화면은 수련 교체 판정을 건너뛴다.
# 전체 행동 봉인·자격 정책
# 정련은 융합 core 슬라이스의 offer 통합 스모크 소유 — 여기서는 생존
# 플래너에 소유 퍽(카탈로그 인지 + Lv≥1) 후보를 위임하는 접착만 놓는다.
# 테스트 전용 결정적 오퍼 RNG seam: 다음 '실제 롤이 수행되는' 실 오퍼
# open 1회에서만 소비된다(부적격 fail-closed 경로는 소비하지 않음).
# user:// 등 어디에도 저장되지 않으며 reset()이 해제한다.
func set_test_perk_fusion_offer_roll_override(appearance_roll_unit: float, replacement_roll_unit: float) -> void:
	_fusion_runtime_state.set_test_offer_roll_override(appearance_roll_unit, replacement_roll_unit)


var _test_perk_fusion_offer_roll_override: Array:
	get:
		return _fusion_runtime_state.get_test_offer_roll_override()
	set(value):
		_fusion_runtime_state.set_test_offer_roll_override_values(value)


func _try_inject_perk_fusion_offer(catalog: Object, appearance_roll_unit: float = -1.0, replacement_roll_unit: float = -1.0) -> Dictionary:
	return _fusion_runtime_state.try_inject_offer_from_runtime_state(
		self,
		catalog,
		appearance_roll_unit,
		replacement_roll_unit
	)


func is_mystic_dice_modal_active() -> bool:
	return _mystic_dice_runtime_state.is_modal_active()


func get_mystic_dice_modal_snapshot() -> Dictionary:
	return _mystic_dice_runtime_state.get_modal_snapshot()


# D0→D1: 주사위 카드는 표준 apply_choice를 타지 않는다. raw choice_active/
# pending 큐는 전 구간 유지(새 freeze actor / modal-gate OR 금지 계약).
# roll_units 비움 → 실 랜덤 7유닛 1회.
func _begin_mystic_dice_modal(selected_choice: Dictionary, registry: Object, roll_units: Array = [], entered_via_rt: bool = false) -> bool:
	return _mystic_dice_runtime_state.begin_modal_from_runtime_state(
		self,
		selected_choice,
		registry,
		roll_units,
		entered_via_rt
	)


func begin_mystic_dice_active_item(
	owner: Object,
	registry: Object,
	roll_units: Array = []
) -> bool:
	return _mystic_dice_runtime_state.begin_active_item_modal_from_runtime_state(
		self,
		owner,
		registry,
		roll_units
	)


func _roll_mystic_dice(roll_units: Array = []) -> Dictionary:
	return _mystic_dice_runtime_state.roll(roll_units)


# cancel(ESC/X)은 의도적 no-op — 주사위는 커밋 의사 흐름이라 취소 불가.
func _handle_mystic_dice_modal_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	return _mystic_dice_runtime_state.handle_modal_input_from_runtime_state(
		self,
		event,
		owner,
		registry,
		view_size
	)


func _activate_mystic_dice_selected_action(owner: Object, registry: Object, reroll_units: Array = []) -> Dictionary:
	return _mystic_dice_runtime_state.activate_selected_action_from_runtime_state(
		self,
		owner,
		registry,
		reroll_units
	)


# D3: 원자 커밋 + 표준 finish 위임. 커밋 실패(캡)는 요청 래치를 되돌리고
# 모달을 유지한다.
# 스탯 소비자 갱신과 modal-blocked paddle 예약 순서는 feature owner가 보존한다.
func _finish_mystic_dice_modal(owner: Object, registry: Object, request: Dictionary) -> Dictionary:
	return _mystic_dice_runtime_state.finish_modal_from_runtime_state(
		self,
		owner,
		registry,
		request
	)


func start_mystic_dice_paddle_effect() -> Dictionary:
	return _mystic_dice_runtime_state.start_paddle_effect()


func bind_mystic_dice_paddle_fx_host(host: Node) -> void:
	_mystic_dice_runtime_state.bind_paddle_fx_host(host)


func get_mystic_dice_paddle_effect_snapshot() -> Dictionary:
	return _mystic_dice_runtime_state.get_paddle_effect_snapshot()


func get_mystic_dice_paddle_fx_host() -> Node:
	return _mystic_dice_runtime_state.get_paddle_fx_host()


# 게임플레이 시간 전용 3초 시계: 모달 차단 중엔 드라이버가 안 불러서
# 자연 정지, 재개 첫 틱이 지연 시작한다(그 틱의 delta는 소모하지 않음).
func update_mystic_dice_paddle_effect(delta: float) -> bool:
	return _mystic_dice_runtime_state.update_paddle_effect(delta)


func clear_mystic_dice_paddle_effect() -> void:
	_mystic_dice_runtime_state.clear_paddle_effect()


# 라운드/스코어/스테이지 경계 공통 훅: 진행 중 3초 패들 연출만 걷는다 —
# 주사위 영구 스탯은 런 스코프라 보존된다(new-run reset만 지운다).
func reset_mystic_dice_round_visuals() -> void:
	clear_mystic_dice_paddle_effect()


# new-run 리셋 파사드 위임(runtime_perk_reset_state 소유): 영구 raw·사용
# 횟수를 지우고 revision을 올려 표시 캐시를 무효화한다.
func reset_mystic_dice_state() -> void:
	_mystic_dice_runtime_state.reset_state()


# ── 퍽 융합 core 위임 계층 (모달 S1~S4·부산물·오퍼) ──────────────────
# 코어 모듈(modal flow/input·outcome rules·result builder·byproduct
# runtime·penalty lane builder)은 각자 소유 파일에 산다. 기능 소유자는
# S0~S4 트랜잭션과 리셋 경계를, 이 파사드는 공개 API·업데이트/입력 순서·
# 프리뷰 표현 조합과 공통 choice-finish 구현을 유지한다.

var _perk_fusion_modal_flow: Object:
	get:
		return _fusion_runtime_state.peek_modal_flow()
	set(value):
		_fusion_runtime_state.set_modal_flow(value)
var _perk_fusion_modal_input: Object:
	get:
		return _fusion_runtime_state.peek_modal_input()
	set(value):
		_fusion_runtime_state.set_modal_input(value)
# 모달 수명 동안의 자격 판정 카탈로그(시작 시 보존): 프리뷰의 한계돌파
# 자격/가중치가 실 커밋(레지스트리 카탈로그)과 같은 max_level을 봐야 한다.
var _perk_fusion_modal_catalog: Object:
	get:
		return _fusion_runtime_state.get_modal_catalog()
	set(value):
		_fusion_runtime_state.set_modal_catalog(value)
# CB3: 콜드부트 시네마틱 Node2D 호스트(래퍼가 생성/정리 — freed 가드 필수).
var _cold_boot_cinematic_host: Object = null


# 프리뷰 캐시 경계 초기화: 캐시 키(선택·phase·리비전)에 카탈로그 식별자가
# 없으므로, 카탈로그가 바뀔 수 있는 모달 경계(시작·완전 취소·finish)에서
# 반드시 비운다. 리비전 불변 경로(취소 후 재진입)의 stale 서빙이 실 위험.
func _reset_perk_fusion_modal_preview_cache() -> void:
	_display_projection_state.reset_modal_preview_cache()


func _get_perk_fusion_modal_flow() -> Object:
	return _fusion_runtime_state.get_modal_flow()


func _get_perk_fusion_modal_input() -> Object:
	return _fusion_runtime_state.get_modal_input()


func get_perk_fusion_revision() -> int:
	return _fusion_runtime_state.get_revision()


func get_perk_fusion_token_snapshot() -> Dictionary:
	return _fusion_runtime_state.get_next_token_snapshot()


# ── 부산물 게임플레이 파사드 ──
func can_trigger_perk_fusion_dash_paddle_speed_boost() -> bool:
	return _fusion_runtime_state.can_trigger_dash_paddle_speed_boost()


func try_trigger_perk_fusion_dash_paddle_speed_boost(
	roll_unit: float,
	restore_effective_speed: float
) -> Dictionary:
	return _fusion_runtime_state.try_trigger_dash_paddle_speed_boost(
		roll_unit,
		restore_effective_speed
	)


func consume_perk_fusion_boss_guard_restore_effective_speed() -> float:
	return _fusion_runtime_state.consume_boss_guard_restore_effective_speed()


func can_activate_perk_fusion_spellbreaker_guard() -> bool:
	return _fusion_runtime_state.can_activate_spellbreaker_guard()


func try_activate_perk_fusion_spellbreaker_guard(
	roll_unit: float,
	player_center: Vector2
) -> Dictionary:
	return _fusion_runtime_state.try_activate_spellbreaker_guard(roll_unit, player_center)


func is_perk_fusion_boss_skill_parry_active() -> bool:
	return _fusion_runtime_state.is_spellbreaker_guard_active()


func try_parry_perk_fusion_boss_skill(
	skill_id: String,
	skill_label: String,
	impact_pos: Vector2
) -> Dictionary:
	return _fusion_runtime_state.try_parry_boss_skill(skill_id, skill_label, impact_pos)


func notify_perk_fusion_player_dash() -> void:
	_fusion_runtime_state.notify_player_dash()


func notify_perk_fusion_skill_used() -> void:
	_fusion_runtime_state.notify_skill_used()
	_chosik_event_state.notify_activation()


func consume_pending_chosik_activations() -> int:
	return _chosik_event_state.consume_pending_activations()


func peek_pending_chosik_activations() -> int:
	return _chosik_event_state.peek_pending_activations()


func get_perk_fusion_move_speed_multiplier() -> float:
	return _fusion_runtime_state.get_move_speed_multiplier()


# 게임플레이 시간 부산물 시계(잔향 만료 등) — 항상 도는 update 드라이버가
# 소유한다(오버레이 없는 만료).
func update_perk_fusion_byproducts(
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	return _fusion_runtime_state.update_byproducts(delta, owner, registry)


func has_perk_fusion_byproduct_visible_effects() -> bool:
	return _fusion_runtime_state.has_byproduct_visible_effects()


func draw_perk_fusion_byproduct_effects(
	canvas: CanvasItem,
	shake_offset: Vector2 = Vector2.ZERO
) -> void:
	_fusion_runtime_state.draw_byproduct_effects(canvas, shake_offset)


func reset_perk_fusion_round_byproducts() -> void:
	_fusion_runtime_state.reset_round_byproducts()
	_chosik_event_state.reset()


# 종결 득점(match_finished)은 부산물 기회를 만들지 않는다 — pending이
# 스테이지 전환을 넘어 다음 스테이지 첫 라운드에 발동하는 이월을 차단.
func queue_perk_fusion_player_point_lost(match_finished: bool = false) -> Dictionary:
	if match_finished:
		return _fusion_runtime_state.queue_player_point_lost(true, 0.0)
	return _fusion_runtime_state.queue_player_point_lost(false, randf())


func consume_pending_perk_fusion_point_loss_effects() -> Dictionary:
	return _fusion_runtime_state.consume_pending_point_loss_effects()


# ── 융합 모달 S0(가로채기)~S4(finish) ──
func is_perk_fusion_modal_active() -> bool:
	return _fusion_runtime_state.is_modal_active()


func _begin_perk_fusion_modal(selected_choice: Dictionary, registry: Object, entered_via_rt: bool = false) -> bool:
	return _fusion_runtime_state.begin_modal_from_runtime_state(
		self,
		selected_choice,
		registry,
		entered_via_rt
	)


func _build_perk_fusion_candidate_ids(catalog: Object) -> Array:
	return _fusion_runtime_state.build_candidate_ids_from_runtime_state(self, catalog)


func get_perk_fusion_candidate_ids(catalog: Object) -> Array:
	return _build_perk_fusion_candidate_ids(catalog).duplicate()


func begin_tower_reward_fusion_modal(selected_choice: Dictionary, registry: Object) -> bool:
	if choice_active or is_perk_fusion_modal_active() or has_pending_unlock_swap():
		return false
	current_choices = [selected_choice.duplicate(true)]
	selected_index = 0
	animation_time = 1.0
	choice_active = true
	current_choice_context = {
		"source": "tower_reward_pick",
		"grant_scope": "tower_run",
	}
	if _begin_perk_fusion_modal(selected_choice, registry):
		return true
	end_tower_reward_external_modal()
	return false


func begin_tower_reward_unlock_swap(
	selected_choice: Dictionary,
	owner: Object,
	registry: Object
) -> bool:
	if choice_active or is_perk_fusion_modal_active() or has_pending_unlock_swap():
		return false
	current_choices = [selected_choice.duplicate(true)]
	selected_index = 0
	animation_time = 1.0
	choice_active = true
	current_choice_context = {
		"source": "tower_reward_pick",
		"grant_scope": "tower_run",
	}
	apply_choice(selected_choice, owner, registry)
	if has_pending_unlock_swap():
		return true
	end_tower_reward_external_modal(owner)
	return false


func end_tower_reward_external_modal(owner: Object = null) -> void:
	if has_pending_unlock_swap():
		cancel_pending_unlock_swap(owner)
	current_choices.clear()
	selected_index = 0
	animation_time = 0.0
	choice_active = false
	current_choice_context.clear()
	status_hover_mouse_pos = Vector2(-1.0, -1.0)


# 콜드부트: 애니메이션 비트 구간 판별(update 드라이버의 호스트 lifecycle
# 게이트) — 모달 활성 + flow가 PHASE_ANIMATION일 때만 호스트가 산다.
func is_perk_fusion_boot_animation_active() -> bool:
	return _fusion_runtime_state.is_boot_animation_active()


# 콜드부트 호스트 생존 판별(렌더러 degraded 폴백 게이트): 호스트가 트리에
# 살아 있고 부팅 중일 때만 true — 아니면 즉시모드가 그린다.
func is_perk_fusion_cold_boot_host_live() -> bool:
	if _cold_boot_cinematic_host == null or not is_instance_valid(_cold_boot_cinematic_host):
		return false
	return bool(_cold_boot_cinematic_host.is_boot_active())


# 콜드부트 1회성 전이 이벤트 드레인 파사드(CB3 시네마틱 호스트 소비 지점).
func consume_perk_fusion_cold_boot_events() -> Array:
	return _fusion_runtime_state.consume_cold_boot_events()


func get_perk_fusion_modal_snapshot() -> Dictionary:
	if _perk_fusion_modal_flow == null:
		return {}
	var snapshot: Dictionary = _perk_fusion_modal_flow.get_snapshot()
	if not bool(_perk_fusion_modal_flow.is_active()):
		return snapshot
	snapshot = _display_projection_state.merge_perk_fusion_modal_preview(
		self,
		snapshot,
		_perk_fusion_modal_catalog if _perk_fusion_modal_catalog != null else _get_catalog(null)
	)
	# CB3: 렌더러가 즉시모드(degraded)와 호스트 드로 중 무엇을 그릴지
	# 스냅샷 플래그로 판별한다.
	snapshot["cold_boot_host_live"] = is_perk_fusion_cold_boot_host_live()
	return snapshot


func _handle_perk_fusion_modal_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	return _fusion_runtime_state.handle_modal_input_from_runtime_state(
		self,
		event,
		owner,
		registry,
		view_size
	)


# S1 취소=frozen 오퍼 복원(완전 no-op) / S2 취소=S1 복귀 / S3·S4 취소=
# 소비만(no-op). 원 오퍼는 flow가 스냅샷을 소유한다.
func _cancel_perk_fusion_modal() -> Dictionary:
	return _fusion_runtime_state.cancel_modal_from_runtime_state(self)


# S2 원자 커밋: 롤 주입(테스트) 또는 실 랜덤 → 중앙 result builder →
# 코어 record 커밋(리비전+1) → 애니메이션 진입. raw choice 트랜잭션
# (pending/sequence/frozen 오퍼)은 S4 finish까지 동결된다.
func _confirm_perk_fusion_modal(owner: Object, registry: Object, rolls: Dictionary = {}) -> Dictionary:
	return _fusion_runtime_state.confirm_modal_from_runtime_state(
		self,
		owner,
		registry,
		rolls
	)


func _build_perk_fusion_commit_result(source_ids: Array, catalog: Object, rolls: Dictionary) -> Dictionary:
	return _fusion_runtime_state.build_commit_result_from_runtime_state(
		self,
		source_ids,
		catalog,
		rolls
	)


# S4 finish: 표준 finish 위임 — 시퀀스/다음 모달/마지막 close·ramp는
# 기존 choice finish 흐름이 소유한다. 같은 record의 중복 finish는
# 리비전 가드로 no-op.
func _finish_perk_fusion_modal(owner: Object, registry: Object, record: Dictionary) -> Dictionary:
	return _fusion_runtime_state.finish_modal_from_runtime_state(
		self,
		owner,
		registry,
		record
	)


func reset() -> void:
	_capture_stats_context(null, null)
	_fusion_runtime_state.reset()
	_physique_training_runtime_state.reset_state()
	_chosik_event_state.reset()
	_hyeonmun_charyeok_runtime_state.reset_state()
	_display_projection_state.invalidate()
	_display_projection_state.reset_modal_preview_cache()
	_reset_state.reset_from_runtime_state(self)


func collect_star_points(
	amount: int,
	character_type: String,
	catalog: Object,
	owner: Object = null,
	registry: Object = null,
	defer_choice_open: bool = false
) -> bool:
	var result: Dictionary = _starpoint_collection_flow.collect_star_points_from_runtime_state(
		self,
		amount,
		character_type,
		catalog,
		owner,
		registry,
		defer_choice_open
	)
	return bool(result.get("choice_active", choice_active))


func open_next_choice(
	character_type: String,
	catalog: Object,
	exclude_instant: bool = false,
	owner: Object = null,
	registry: Object = null,
	perf_logger: Object = null,
	choice_context: Dictionary = {}
) -> void:
	_choice_open_flow.open_next_choice_from_runtime_state(
		self,
		character_type,
		catalog,
		exclude_instant,
		owner,
		registry,
		perf_logger,
		choice_context
	)
	# 오퍼 후처리는 open-flow가 천안결 → 융합 → 주사위 → 수련 순서로
	# ready 이전에 끝낸다.


func open_mythic_perk_choice(
	count: int,
	owner: Object = null,
	registry: Object = null,
	catalog: Object = null,
	perf_logger: Object = null,
	choice_context: Dictionary = {}
) -> bool:
	var result: Dictionary = _choice_open_flow.open_mythic_perk_choice_from_runtime_state(
		self,
		count,
		owner,
		registry,
		catalog,
		perf_logger,
		choice_context
	)
	return bool(result.get("accepted", false))


func _apply_choice_opening_update(update: Dictionary) -> Dictionary:
	var result: Dictionary = _choice_opening.apply_state_update(self, update)
	if bool(result.get("resume_skill_cooldowns", false)):
		_resume_skill_cooldowns_for_choice()
	return result


func is_choice_active() -> bool:
	return (
		_choice_opening.is_choice_active_from_runtime_state(self)
		or is_mystic_dice_modal_active()
	)


func is_selectable() -> bool:
	return _choice_selection.is_selectable_from_runtime_state(self)


func is_choice_flight_active() -> bool:
	return _active_unlock_flight.is_active_from_runtime_state(self)


func is_unlock_showcase_active() -> bool:
	return _unlock_showcase_controller.is_active_from_runtime_state(self)


func has_pending_unlock_swap() -> bool:
	return _unlock_swap_flow.has_pending_swap_from_runtime_state(self)


func get_pending_unlock_swap() -> Dictionary:
	return _unlock_swap_flow.get_pending_swap_snapshot_from_runtime_state(self)


func get_unlock_swap_selected_index() -> int:
	return _unlock_swap_flow.get_selected_index_from_runtime_state(self)


func has_feedback() -> bool:
	return _choice_feedback.has_feedback_from_runtime_state(self)


func update(delta: float, view_size: Vector2, owner: Object = null, registry: Object = null) -> void:
	_update_internal(delta, view_size, owner, registry, null)


func update_with_perf(delta: float, view_size: Vector2, owner: Object = null, registry: Object = null, perf_logger: Object = null) -> void:
	_update_internal(delta, view_size, owner, registry, perf_logger)


func _update_internal(delta: float, view_size: Vector2, owner: Object, registry: Object, perf_logger: Object) -> void:
	_capture_stats_context(owner, registry)
	# 융합 재료쌍 아이콘 스테이지드 프리웜: 업데이트 경로(배틀 오버레이 프레임
	# 컨트롤러·플라자·결과화면 스타포인트 핸들러 공통) 소유 — 리비전 변경 후
	# 첫 update 틱에서 합성되고, CanvasItem draw 프레임은 조회 히트만 본다.
	_prewarm_fusion_pair_icons(registry)
	# 주사위 모달 시계(D1 굴림 진행/D2 바운디드 hover)는 모달 활성 중에만
	# 전진한다 — 표준 update 흐름과 같은 틱에서 함께 돈다.
	if is_mystic_dice_modal_active():
		_mystic_dice_modal_flow.update(delta)
	# 융합 모달 S3(연출) 시계 — reveal 진입은 flow가 소유한다.
	if is_perk_fusion_modal_active():
		_perk_fusion_modal_flow.update(delta)
	_update_flow.update_internal_from_runtime_state(
		delta,
		view_size,
		owner,
		registry,
		self,
		perf_logger
	)
	# Use live post-flow state: the ordinary choice/flight update above can close
	# or open a higher-priority modal during this same frame.
	if has_angel_blessing_modal_work():
		update_angel_blessing_acquisition(delta, owner, registry)


# 하단 능력치 원장이 소비할 owner/registry를 프레임 시작에 고정한다. 드로우와
# 입력 히트테스트가 같은 프레임 안에서 같은 레이아웃을 봐야 하므로, 렌더러가
# draw() 시점에 플래그를 뒤집는 방식은 쓰지 않는다(첫 프레임 클릭이 어긋난다).
func capture_stats_context(owner: Object, registry: Object) -> bool:
	_capture_stats_context(owner, registry)
	return stats_band_enabled


func _capture_stats_context(owner: Object, registry: Object) -> void:
	_stats_context_owner = owner if owner != null and is_instance_valid(owner) else null
	# The production registry owns this runtime state. Keep only a weak handle
	# for the draw/input consumers; a strong state -> registry edge would form a
	# cycle in RefCounted preview/test registries and retain the whole module graph.
	_stats_context_registry_ref = weakref(registry) if _stats_context_owner != null and registry != null and is_instance_valid(registry) else null
	stats_band_enabled = _stats_context_owner != null and get_stats_context_registry() != null


func get_stats_context_owner() -> Object:
	return _stats_context_owner


func get_stats_context_registry() -> Object:
	return _stats_context_registry_ref.get_ref() if _stats_context_registry_ref != null else null


func _prewarm_fusion_pair_icons(registry: Object) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var icon_renderer: Object = registry.get_instance("runtime_perk_icon_renderer")
	if icon_renderer != null and icon_renderer.has_method("prewarm_fusion_pair_icons_for_state"):
		icon_renderer.prewarm_fusion_pair_icons_for_state(self)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	# 시스템 카드 모달(융합·주사위)이 열려 있는 동안은 모든 입력을 해당
	# 모달이 우선 소비한다(융합 S3/S4의 ESC는 소비-후-no-op).
	if is_perk_fusion_modal_active():
		return _handle_perk_fusion_modal_input(event, owner, registry, view_size)
	if is_mystic_dice_modal_active():
		return _handle_mystic_dice_modal_input(event, owner, registry, view_size)
	return _modal_input.handle_input_from_runtime_state(self, event, owner, registry, view_size)


func set_status_hover_mouse_pos(position: Vector2) -> void:
	status_hover_mouse_pos = position


func get_status_hover_mouse_pos() -> Vector2:
	return status_hover_mouse_pos


func move_selection(delta_index: int) -> void:
	_choice_selection.move_selection_from_runtime_state(self, delta_index)


func _apply_choice_selection_update(update: Dictionary) -> Dictionary:
	return _choice_selection.apply_state_update(self, update)


func _consume_gamepad_choice_navigation(event: InputEvent, direction: int) -> int:
	var apply_result: Dictionary = _gamepad_navigation.consume_choice_navigation_from_runtime_state(
		self,
		event,
		direction
	)
	return int(apply_result.get("direction", 0))


func _consume_gamepad_unlock_swap_navigation(event: InputEvent, direction: int) -> int:
	var apply_result: Dictionary = _gamepad_navigation.consume_unlock_swap_navigation_from_runtime_state(
		self,
		event,
		direction
	)
	return int(apply_result.get("direction", 0))


func _get_card_index_at(position: Vector2, view_size: Vector2) -> int:
	return _choice_layout.get_card_index_at_from_runtime_state(self, position, view_size)


func build_unlock_swap_layout(view_size: Vector2) -> Dictionary:
	return _unlock_swap_layout.build_layout_from_runtime_state(self, view_size)


func get_unlock_swap_option_rects(view_size: Vector2) -> Array:
	return _unlock_swap_layout.get_option_rects_from_runtime_state(self, view_size)


func _get_unlock_swap_index_at(position: Vector2, view_size: Vector2) -> int:
	return _unlock_swap_layout.get_index_at_from_runtime_state(self, position, view_size)


func _select_choice_index(index: int) -> void:
	_choice_selection.select_index_from_runtime_state(self, index)


func _select_unlock_swap_index(index: int) -> void:
	_unlock_swap_flow.select_index_from_runtime_state(self, index)


func move_unlock_swap_selection(delta_index: int) -> void:
	_unlock_swap_flow.move_selection_from_runtime_state(self, delta_index)


# 게임패드 confirm의 실 입력원(RT 트리거 여부)을 공용 3인자 choose_selected
# 계약을 깨지 않고 전달하는 별도 note 채널 — 다음 choose_selected 1회가
# 소비하고 리셋한다.
var _choice_confirm_entered_via_rt := false


func note_choice_confirm_input_source(entered_via_rt: bool) -> void:
	_choice_confirm_entered_via_rt = entered_via_rt


func choose_selected(owner: Object, registry: Object, view_size: Vector2 = Vector2.ZERO) -> void:
	var entered_via_rt := _choice_confirm_entered_via_rt
	_choice_confirm_entered_via_rt = false
	# 공용 선택 가능 게이트를 한 번만 통과한 뒤 주사위/표준 경로로 분기한다
	# — 주사위만 게이트를 우회하면 카드 등장 애니메이션(animation_time <
	# 0.24)이나 flight/showcase/swap 전환 중 입력으로도 모달이 열린다.
	# 게이트 불통과는 표준 경로에 그대로 넘긴다(실패 피드백 소유).
	if is_selectable():
		# D0/S0 시스템 카드 가로채기: 융합·주사위 카드는 표준 apply_choice를
		# 타지 않는다 — 각 모달이 트랜잭션을 소유하고, raw choice_active/
		# pending 큐는 전 구간 유지된다(새 freeze actor / modal-gate OR 금지).
		var selected_choice: Dictionary = _get_selected_choice_snapshot()
		if bool(selected_choice.get("is_perk_fusion", false)):
			_begin_perk_fusion_modal(selected_choice, registry, entered_via_rt)
			return
		if bool(selected_choice.get("is_mystic_dice", false)):
			_begin_mystic_dice_modal(selected_choice, registry, [], entered_via_rt)
			return
	_choice_confirm_flow.choose_selected_from_runtime_state(
		self,
		owner,
		registry,
		view_size
	)


func _get_selected_choice_snapshot() -> Dictionary:
	if not choice_active or selected_index < 0 or selected_index >= current_choices.size():
		return {}
	var choice_value: Variant = current_choices[selected_index]
	return choice_value if choice_value is Dictionary else {}


func _update_choice_flight_effect(delta: float, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	_choice_confirm_flow.update_choice_flight_effect_from_runtime_state(
		self,
		delta,
		owner,
		registry,
		perf_logger
	)


func _build_flight_layout_state(registry: Object, view_size: Vector2) -> Dictionary:
	return _active_unlock_flight.build_layout_state_from_runtime_state(self, registry, view_size)


func _play_active_unlock_flight_audio(registry: Object) -> void:
	_choice_audio.play_active_unlock_flight_from_runtime_state(self, registry)


func _play_perk_select_audio(registry: Object) -> void:
	_choice_audio.play_perk_select_from_runtime_state(self, registry)


func _apply_choice_failure_feedback() -> void:
	_choice_feedback.apply_failure_feedback_from_runtime_state(self)


func is_starpoint_absorption_active() -> bool:
	return _starpoint_absorption.is_active_from_runtime_state(self)


func _start_starpoint_absorption_effect(owner: Object) -> void:
	_starpoint_absorption.start_from_runtime_state(self, owner)


func _update_starpoint_absorption_effect(delta: float, view_size: Vector2, owner: Object, registry: Object) -> void:
	_starpoint_absorption.update_from_runtime_state(self, delta, view_size, owner, registry)


func _finish_successful_choice(
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object = null,
	choice: Dictionary = {}
) -> Dictionary:
	return _choice_finish_flow.finish_successful_choice_from_runtime_state(
		self,
		choice_id,
		owner,
		registry,
		perf_logger,
		choice
	)


func _finish_or_open_unlock_showcase(
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object,
	choice: Dictionary = {}
) -> void:
	_unlock_showcase_flow.finish_or_open_unlock_showcase_from_runtime_state(
		self,
		choice_id,
		owner,
		registry,
		perf_logger,
		choice
	)


func _update_unlock_showcase(delta: float, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	_unlock_showcase_flow.update_unlock_showcase_from_runtime_state(
		self,
		delta,
		owner,
		registry,
		perf_logger
	)


func _dismiss_unlock_showcase(owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	var result: Dictionary = _unlock_showcase_flow.dismiss_unlock_showcase_from_runtime_state(
		self,
		owner,
		registry,
		perf_logger
	)
	return bool(result.get("dismissed", false))


func _handle_unlock_showcase_input(event: InputEvent, owner: Object, registry: Object) -> bool:
	_unlock_showcase_flow.handle_unlock_showcase_input_from_runtime_state(
		self,
		event,
		owner,
		registry
	)
	return true


func update_resume_safety(owner: Object, registry: Object, delta: float) -> void:
	_resume_safety.update_from_runtime_state(self, owner, registry, delta)


func get_ball_resume_context() -> Dictionary:
	return _resume_safety.get_context_from_runtime_state(self)


func consume_resume_velocity_for_stopwatch() -> Dictionary:
	return _resume_safety.consume_velocity_for_stopwatch_from_runtime_state(self)


func apply_choice(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	var choice_id: String = str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var previous_raw_level: int = _get_raw_runtime_perk_level(choice_id)
	var acquisition_context: Dictionary = current_choice_context.duplicate(true)
	var result: Dictionary = _choice_apply_flow.apply_choice_from_runtime_state(self, choice, owner, registry, perf_logger)
	if bool(result.get("accepted", false)):
		var applied_choice_id: String = str(result.get("choice_id", choice_id)).strip_edges()
		if applied_choice_id == "angel_blessing":
			_angel_blessing_runtime_state.on_accepted_choice(
				self,
				choice,
				previous_raw_level,
				_get_raw_runtime_perk_level(applied_choice_id),
				acquisition_context,
				bool(result.get("mythic_acquisition_cinematic_started", false)),
				owner,
				registry
			)
	return bool(result.get("accepted", false))


func apply_choice_at_target_level(
	choice: Dictionary,
	target_level: int,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> bool:
	var choice_id: String = str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var previous_raw_level: int = _get_raw_runtime_perk_level(choice_id)
	var acquisition_context: Dictionary = current_choice_context.duplicate(true)
	var result: Dictionary = _choice_apply_flow.apply_choice_at_target_level_from_runtime_state(
		self,
		choice,
		target_level,
		owner,
		registry,
		perf_logger
	)
	if bool(result.get("accepted", false)):
		var applied_choice_id: String = str(result.get("choice_id", choice_id)).strip_edges()
		if applied_choice_id == "angel_blessing":
			_angel_blessing_runtime_state.on_accepted_choice(
				self,
				choice,
				previous_raw_level,
				_get_raw_runtime_perk_level(applied_choice_id),
				acquisition_context,
				false,
				owner,
				registry
			)
	return bool(result.get("accepted", false))


func _apply_convert_to_gold_choice(choice: Dictionary, owner: Object, registry: Object) -> bool:
	return _gold_award_flow.apply_convert_to_gold_choice_from_runtime_state(self, choice, owner, registry)


func _apply_choice_feedback_result(result: Dictionary, choice: Dictionary, fallback_timer: float) -> bool:
	return bool(_choice_feedback.apply_result_feedback_from_runtime_state(self, result, choice, fallback_timer).get("accepted", false))


func get_card_rects(view_size: Vector2) -> Array:
	return _choice_layout.get_card_rects_from_runtime_state(self, view_size)


func build_layout(view_size: Vector2) -> Dictionary:
	return _choice_layout.build_layout_from_runtime_state(self, view_size)


func get_snapshot() -> Dictionary:
	return _snapshot_builder.build_from_runtime_state(self)


# Run-save surface for acquired perk levels. Active-skill equipped slots and
# cooldown clocks remain owned by each character's skill config/state codec.
func build_unlock_save_snapshot() -> Dictionary:
	# Keep this save codec distinct from the owner-projection contract below.
	# The local name also prevents source-contract checks from mistaking the
	# persisted snapshot for an inline owner sync payload.
	var saved_levels: Dictionary = PerkConversionValues.sanitize_runtime_levels(runtime_skill_levels)
	return {
		"version": 2,
		"runtime_skill_levels": saved_levels,
		"physique_training": get_physique_training_snapshot(),
	}


func apply_unlock_save_snapshot(snapshot: Dictionary, owner: Object = null, registry: Object = null) -> Dictionary:
	if snapshot.is_empty() or not (snapshot.get("runtime_skill_levels", null) is Dictionary):
		return {"restored": false, "reason": "invalid_snapshot"}
	var saved_levels := (snapshot.get("runtime_skill_levels", {}) as Dictionary).duplicate(true)
	var retired_entry_count := PerkConversionValues.count_retired_runtime_level_entries(saved_levels)
	runtime_skill_levels = PerkConversionValues.sanitize_runtime_levels(saved_levels)
	var training_snapshot_value: Variant = snapshot.get("physique_training", {})
	if training_snapshot_value is Dictionary:
		restore_physique_training_snapshot(training_snapshot_value as Dictionary)
	else:
		_physique_training_runtime_state.reset_state()
	if owner != null:
		_sync_runtime_perk_owner_effects(owner, registry)
		_refresh_mythic_runtime_perk_consumers(owner, registry)
	var restored_levels: Dictionary = runtime_skill_levels.duplicate(true)
	return {
		"restored": true,
		"runtime_skill_levels": restored_levels,
		"removed_retired_perks": retired_entry_count,
	}


func get_runtime_skill_level(skill_id: String) -> int:
	return _effective_stat_queries.get_runtime_skill_level_from_runtime_state(self, skill_id)


func try_proc_hyeonmun_charyeok(context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	return _hyeonmun_charyeok_runtime_state.try_proc_from_runtime_state(
		self,
		context,
		deps
	)


func update_hyeonmun_charyeok(delta: float, owner: Object = null, registry: Object = null) -> bool:
	return _hyeonmun_charyeok_runtime_state.update_from_runtime_state(
		self,
		delta,
		owner,
		registry
	)


func reset_hyeonmun_charyeok_round(registry: Object = null, owner: Object = null) -> bool:
	return _hyeonmun_charyeok_runtime_state.reset_round_from_runtime_state(
		self,
		registry,
		owner
	)


func is_hyeonmun_charyeok_active() -> bool:
	return _hyeonmun_charyeok_runtime_state.is_active()


func get_hyeonmun_charyeok_level_bonus() -> int:
	return _hyeonmun_charyeok_runtime_state.get_level_bonus()


func get_hyeonmun_charyeok_snapshot() -> Dictionary:
	return _hyeonmun_charyeok_runtime_state.get_snapshot()


func draw_hyeonmun_charyeok_timer(canvas: CanvasItem, timer_stack: Object = null) -> void:
	_hyeonmun_charyeok_runtime_state.draw_timer(canvas, timer_stack)


# apply_choice의 소스 계약(모듈분리 씰)은 본문에 raw 레벨 딕셔너리 직접 접근을
# 금지한다. angel 획득 훅이 필요로 하는 raw 레벨 스냅샷은 이 헬퍼로 우회한다.
func _get_raw_runtime_perk_level(perk_id: String) -> int:
	return int(runtime_skill_levels.get(perk_id, 0))


func get_converted_perk_effect_level(perk_id: String) -> int:
	return _effective_stat_queries.get_converted_perk_effect_level_from_runtime_state(self, perk_id)


func get_converted_perk_option_value(perk_id: String, option_key: String) -> float:
	return _effective_stat_queries.get_converted_perk_option_value_from_runtime_state(self, perk_id, option_key)


func get_effective_runtime_skill_levels() -> Dictionary:
	return _effective_stat_queries.get_effective_runtime_skill_levels_from_runtime_state(self)


func get_runtime_skill_bonus(skill_id: String) -> float:
	return _effective_stat_queries.get_runtime_skill_bonus_from_runtime_state(self, skill_id)


func get_runtime_skill_bonus_before_fusion(skill_id: String) -> float:
	return _effective_stat_queries.get_runtime_skill_bonus_before_fusion_from_runtime_state(self, skill_id)


func get_perk_amplify_multiplier(skill_id: String) -> float:
	return _effective_stat_queries.get_perk_amplify_multiplier_from_runtime_state(self, skill_id)


func _get_perk_amplify_multiplier(skill_id: String) -> float:
	return get_perk_amplify_multiplier(skill_id)


# Smasher 콤보증폭칩: 콤보 소모형 드라이브/파워스매싱의 콤보 비례 항을 추가 증폭.
# Python get_combo_amplifier_chip_bonus()(pingfighter.py) 패리티. GDScript는 튜플
# 미지원이라 Dictionary 반환. 레벨은 유효레벨(아이템/점화 오버플로우 포함)을 쓰되,
# 커브 레인만 mini(level,3)로 Lv3 하드캡(밸런스 보호) — drive/power-smash 주입부에서
# (1.0 + amp)로 콤보 항에만 곱한다(base 상수는 비증폭).
func get_combo_amplifier_chip_bonus() -> Dictionary:
	return _effective_stat_queries.get_combo_amplifier_chip_bonus_from_runtime_state(self)


func get_angel_blessing_state() -> Object:
	return _angel_blessing_runtime_state.get_state()


func roll_angel_blessing_for_stage(
	stage: int,
	eligible_buff_ids: Array = [],
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	return _angel_blessing_runtime_state.roll_for_stage(
		stage,
		eligible_buff_ids,
		forced_face,
		forced_candidate_order
	)


func get_angel_blessing_eligible_buff_ids(character_type: String, registry: Object) -> Array[String]:
	return _angel_blessing_runtime_state.get_eligible_buff_ids(character_type, registry)


func get_angel_blessing_skill_cooldown_capability(character_type: String, registry: Object) -> Dictionary:
	return _angel_blessing_runtime_state.get_cooldown_capability(character_type, registry)


func roll_angel_blessing_for_character_stage(
	stage: int,
	character_type: String,
	registry: Object,
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	return roll_angel_blessing_for_stage(
		stage,
		get_angel_blessing_eligible_buff_ids(character_type, registry),
		forced_face,
		forced_candidate_order
	)


func get_angel_blessing_snapshot() -> Dictionary:
	return _angel_blessing_runtime_state.get_snapshot()


func get_angel_blessing_acquisition_snapshot() -> Dictionary:
	return _angel_blessing_runtime_state.get_acquisition_snapshot()


func get_angel_blessing_presentation_snapshot() -> Dictionary:
	return get_angel_blessing_acquisition_snapshot()


func has_angel_blessing_visual_work() -> bool:
	return _angel_blessing_runtime_state.has_visual_work()


func get_runtime_status_lines(perk_id: String) -> Array[String]:
	if perk_id.strip_edges() != RuntimePerkAngelBlessingRuntimeState.PERK_ID:
		return []
	return RuntimePerkAngelBlessingLocalization.build_status_lines(
		get_angel_blessing_snapshot(),
		get_angel_blessing_acquisition_snapshot(),
		int(runtime_skill_levels.get(RuntimePerkAngelBlessingRuntimeState.PERK_ID, 0)) > 0
	)


func has_pending_angel_blessing_acquisition() -> bool:
	return _angel_blessing_runtime_state.has_pending_acquisition()


func is_angel_blessing_modal_active() -> bool:
	return _angel_blessing_runtime_state.is_modal_active()


func has_angel_blessing_modal_work() -> bool:
	return _angel_blessing_runtime_state.has_modal_work()


func update_angel_blessing_acquisition(
	delta: float,
	owner: Object,
	registry: Object,
	blockers: Dictionary = {},
	roll_options: Dictionary = {}
) -> Dictionary:
	return _angel_blessing_runtime_state.update_acquisition_from_runtime_state(
		self,
		delta,
		owner,
		registry,
		blockers,
		roll_options
	)


func handle_angel_blessing_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	_view_size: Vector2 = Vector2.ZERO
) -> bool:
	return _angel_blessing_runtime_state.handle_acquisition_input_from_runtime_state(
		self,
		event,
		owner,
		registry
	)


func on_angel_blessing_acquisition_cinematic_finished(
	perk_id: String,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	return _angel_blessing_runtime_state.finish_acquisition_cinematic_from_runtime_state(
		self,
		perk_id,
		owner,
		registry
	)


func on_angel_blessing_round_boundary() -> void:
	_angel_blessing_runtime_state.on_round_boundary_from_runtime_state(self)


func on_angel_blessing_stage_transition(_next_stage: int = 0) -> void:
	_angel_blessing_runtime_state.on_stage_transition_from_runtime_state(self)


func _should_defer_next_choice_for_angel_acquisition() -> bool:
	return _angel_blessing_runtime_state.should_defer_next_choice()


func _has_angel_blessing_post_choice_blocker() -> bool:
	return _angel_blessing_runtime_state.has_post_choice_blocker()


func _has_runtime_perk_post_choice_blocker(registry: Object = null) -> bool:
	if _has_angel_blessing_post_choice_blocker():
		return true
	if registry == null:
		return false
	var lingpet_runtime: Object = null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance("lingpet_egg_runtime")
		if typeof(cached) == TYPE_OBJECT and cached != null and is_instance_valid(cached):
			lingpet_runtime = cached as Object
	elif registry.has_method("get_instance"):
		lingpet_runtime = registry.get_instance("lingpet_egg_runtime")
	return (
		lingpet_runtime != null
		and lingpet_runtime.has_method("is_guardian_enhance_cutin_active")
		and bool(lingpet_runtime.is_guardian_enhance_cutin_active())
	)


func _has_current_stage_angel_blessing_work() -> bool:
	return _angel_blessing_runtime_state.has_current_stage_work()


func _continue_angel_blessing_after_choice(owner: Object, registry: Object) -> void:
	_angel_blessing_runtime_state.continue_after_choice_from_runtime_state(
		self,
		owner,
		registry
	)


func _try_resume_deferred_runtime_choices(owner: Object, registry: Object) -> Dictionary:
	return _angel_blessing_runtime_state.try_resume_deferred_choices_from_runtime_state(
		self,
		owner,
		registry
	)


func _finalize_angel_blessing_deferred_choice_chain(
	owner: Object,
	registry: Object,
	force_resume_effects: bool = false
) -> void:
	_angel_blessing_runtime_state.finalize_deferred_choice_chain_from_runtime_state(
		self,
		owner,
		registry,
		force_resume_effects
	)


func _roll_angel_blessing_current_stage_only(
	owner: Object,
	registry: Object,
	roll_options: Dictionary = {}
) -> Dictionary:
	return _angel_blessing_runtime_state.roll_current_stage_from_runtime_state(
		self,
		owner,
		registry,
		roll_options
	)


func _get_angel_blessing_owner_stage(owner: Object) -> int:
	return _angel_blessing_runtime_state.get_owner_stage_from_runtime_state(self, owner)


func get_angel_blessing_special_gauge_max(current_max: float) -> float:
	return _effective_stat_queries.get_angel_blessing_special_gauge_max_from_runtime_state(
		self,
		current_max
	)


func get_dash_recharge_frames(base_frames: float) -> float:
	return _effective_stat_queries.get_dash_recharge_frames_from_runtime_state(self, base_frames)


func get_dash_recovery_frames(base_frames: float) -> float:
	return _effective_stat_queries.get_dash_recovery_frames_from_runtime_state(self, base_frames)


func get_dash_duration_frames(base_frames: float) -> float:
	return _effective_stat_queries.get_dash_duration_frames_from_runtime_state(self, base_frames)


func get_item_spawn_delay_msec(base_delay_msec: int) -> int:
	return _effective_stat_queries.get_item_spawn_delay_msec_from_runtime_state(self, base_delay_msec)


func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
	return _effective_stat_queries.get_active_item_cooldown_msec_from_runtime_state(self, base_cooldown_msec)


func get_active_item_use_gauge_bonus() -> float:
	return _effective_stat_queries.get_active_item_use_gauge_bonus_from_runtime_state(self)


func get_active_item_slot_capacity(base_slots: int = BASE_ACTIVE_ITEM_SLOT_LIMIT) -> int:
	return _effective_stat_queries.get_active_item_slot_capacity_from_runtime_state(self, base_slots)


func get_active_item_duration_bonus() -> float:
	return _effective_stat_queries.get_active_item_duration_bonus_from_runtime_state(self)


func get_active_item_duration_multiplier() -> float:
	return _effective_stat_queries.get_active_item_duration_multiplier_from_runtime_state(self)


func get_active_item_duration_frames(base_duration_frames: float) -> float:
	return _effective_stat_queries.get_active_item_duration_frames_from_runtime_state(self, base_duration_frames)


func get_active_item_recycle_chance() -> float:
	return _effective_stat_queries.get_active_item_recycle_chance_from_runtime_state(self)


func get_effective_polish_multiplier() -> float:
	return _effective_stat_queries.get_effective_polish_multiplier_from_runtime_state(self)


func get_base_polish_multiplier() -> float:
	return _effective_stat_queries.get_base_polish_multiplier_from_runtime_state(self)


func get_downtown_treasure_map_mythic_bonus() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_mythic_bonus_from_runtime_state(self)


func get_downtown_treasure_map_mythic_multiplier() -> float:
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return 1.0
	return get_downtown_treasure_map_reward_pick_multiplier()


func get_downtown_treasure_map_reward_pick_multiplier() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_mythic_multiplier_from_runtime_state(self)


func get_downtown_treasure_map_vision_box_chance_bonus() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_vision_box_chance_bonus_from_runtime_state(self)


func get_downtown_treasure_map_vision_box_chance(base_chance: float) -> float:
	return _effective_stat_queries.get_downtown_treasure_map_vision_box_chance_from_runtime_state(self, base_chance)


func get_player_speed_multiplier() -> float:
	return _effective_stat_queries.get_player_speed_multiplier_from_runtime_state(self)


func get_player_paddle_size_multiplier() -> float:
	return _effective_stat_queries.get_player_paddle_size_multiplier_from_runtime_state(self)


func get_accessory_slot_bonus() -> int:
	return _effective_stat_queries.get_accessory_slot_bonus_from_runtime_state(self)


func get_player_skill_cooldown_multiplier() -> float:
	return _effective_stat_queries.get_player_skill_cooldown_multiplier_from_runtime_state(self)


func get_player_skill_cooldown_seconds(base_cooldown_seconds: float) -> float:
	return _effective_stat_queries.get_player_skill_cooldown_seconds_from_runtime_state(self, base_cooldown_seconds)


func get_boost_charge_chance_pct() -> float:
	return _effective_stat_queries.get_boost_charge_chance_pct_from_runtime_state(self)


func get_dash_acceleration_level() -> int:
	return _effective_stat_queries.get_dash_acceleration_level_from_runtime_state(self)


func get_dash_acceleration_bonus() -> float:
	return _effective_stat_queries.get_dash_acceleration_bonus_from_runtime_state(self)


func get_dash_acceleration_height_bonus(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return _effective_stat_queries.get_dash_acceleration_height_bonus_from_runtime_state(self, base_height)


func get_laurel_leaf_count(registry: Object = null) -> int:
	return _effective_stat_queries.get_laurel_leaf_count_from_runtime_state(self, registry)


func calculate_rally_gold(ball_vel: Vector2) -> int:
	return _gold_award_flow.calculate_rally_gold_from_runtime_state(self, ball_vel)


func award_rally_gold(ball_vel: Vector2, context: Dictionary = {}, deps: Dictionary = {}) -> int:
	return _gold_award_flow.award_rally_gold_from_runtime_state(self, ball_vel, context, deps)


func award_gold(amount: int, context: Dictionary = {}, deps: Dictionary = {}) -> int:
	return _gold_award_flow.award_gold_from_runtime_state(self, amount, context, deps)


func _store_gold_gain(boosted_amount: int, _feedback_duration: float) -> int:
	return _gold_award_flow.store_gold_gain_from_runtime_state(self, boosted_amount, _feedback_duration)


func _apply_gold_award_result(result: Dictionary) -> int:
	return _gold_award_flow.apply_gold_award_result_from_runtime_state(self, result)


func set_viper_ignition_aura_active(active: bool) -> void:
	_dynamic_effects.set_viper_ignition_aura_active_from_runtime_state(self, active)


func is_viper_ignition_aura_active() -> bool:
	return _dynamic_effects.is_viper_ignition_aura_active_from_runtime_state(self)


func get_viper_ignition_aura_level_bonus() -> int:
	return _effective_stat_queries.get_viper_ignition_aura_level_bonus_from_runtime_state(self)


func get_viper_ignition_aura_gold_bonus() -> int:
	return _gold_award_flow.get_viper_ignition_aura_gold_bonus_from_runtime_state(self)


func refresh_viper_ignition_aura_dynamic_effects(registry: Object, owner: Object = null) -> void:
	_dynamic_effects.refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(self, registry, owner)


func refresh_item_perk_level_bonus_dynamic_effects(registry: Object, owner: Object = null) -> void:
	_dynamic_effects.refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(self, registry, owner)


func _is_runtime_level_bonus_eligible(skill_id: String, base_level: int) -> bool:
	return _effective_stat_queries.is_runtime_level_bonus_eligible_from_runtime_state(self, skill_id, base_level)


func _is_ignition_aura_level_bonus_eligible(skill_id: String, base_level: int) -> bool:
	return _effective_stat_queries.is_ignition_aura_level_bonus_eligible_from_runtime_state(self, skill_id, base_level)


func set_item_gold_gain_multiplier(multiplier: float) -> void:
	_gold_award_flow.set_item_gold_gain_multiplier_from_runtime_state(self, multiplier)


func get_item_gold_gain_multiplier() -> float:
	return _gold_award_flow.get_item_gold_gain_multiplier_from_runtime_state(self)


func set_item_perk_level_bonus(bonus: int) -> bool:
	var apply_result: Dictionary = _dynamic_effects.set_item_perk_level_bonus_from_runtime_state(self, bonus)
	return bool(apply_result.get("accepted", false))


func get_item_perk_level_bonus() -> int:
	return _dynamic_effects.get_item_perk_level_bonus_from_runtime_state(self)


func _refresh_viper_ignition_aura_owner_sync_if_needed(owner: Object, registry: Object) -> void:
	_dynamic_effects.refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(self, registry, owner)


func debug_set_perk_level(perk_id: String, target_level: int, owner: Object, registry: Object, catalog: Object) -> bool:
	var grant_result: Dictionary = _debug_grants.apply_debug_grant_from_runtime_state(self, perk_id, target_level, owner, registry, catalog)
	return bool(grant_result.get("accepted", false))


func _apply_unlock_choice(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> bool:
	var result: Dictionary = _unlock_choice_apply.apply_choice_from_runtime_state(self, choice, owner, registry, perf_logger)
	return bool(result.get("accepted", false))


func cancel_pending_unlock_swap(owner: Object = null) -> bool:
	var cancel_result: Dictionary = _unlock_swap_flow.cancel_pending_swap_from_runtime_state(self, owner)
	return bool(cancel_result.get("accepted", false))


func confirm_pending_unlock_swap(owner: Object, registry: Object) -> bool:
	var confirm_result: Dictionary = _unlock_swap_flow.confirm_pending_swap_from_runtime_state(
		self,
		owner,
		registry
	)
	return bool(confirm_result.get("accepted", false))


func _apply_unlock_swap_state_update(update: Dictionary, owner: Object = null) -> bool:
	var apply_result: Dictionary = _unlock_swap_flow.apply_state_update_and_sync_owner_from_runtime_state(self, update, owner)
	return bool(apply_result.get("accepted", false))


func _apply_level_side_effect(choice: Dictionary, owner: Object, registry: Object, perf_logger: Object = null) -> void:
	_level_side_effects.apply_from_runtime_state(self, choice, owner, registry, perf_logger)


func _apply_full_gauge(owner: Object, registry: Object) -> void:
	_instant_choice_flow.apply_full_gauge_from_runtime_state(self, owner, registry, SPECIAL_GAUGE_MAX)


func _apply_full_gauge_choice(owner: Object, registry: Object) -> Dictionary:
	return _instant_choice_flow.apply_full_gauge_choice_from_runtime_state(self, owner, registry, SPECIAL_GAUGE_MAX)


func _apply_dimension_gate(registry: Object) -> bool:
	return _instant_choice_flow.apply_dimension_gate_from_runtime_state(self, registry)


func _apply_dimension_gate_choice(registry: Object) -> Dictionary:
	return _instant_choice_flow.apply_dimension_gate_choice_from_runtime_state(self, registry)


func _should_defer_dimension_gate_until_spawn_intro_end() -> bool:
	return _instant_choice_flow.should_defer_dimension_gate_from_runtime_state(self)


func _should_defer_full_gauge_until_spawn_intro_end() -> bool:
	return _instant_choice_flow.should_defer_full_gauge_from_runtime_state(self)


func _queue_dimension_gate_after_spawn_intro(owner: Object, pending_feedback_text: String = "") -> void:
	_instant_choice_flow.queue_dimension_gate_from_runtime_state(self, owner, pending_feedback_text)


func _queue_dimension_gate_after_spawn_intro_choice(owner: Object, choice_name: String = "") -> Dictionary:
	return _instant_choice_flow.queue_dimension_gate_choice_from_runtime_state(self, owner, choice_name)


func has_pending_dimension_gate_after_spawn_intro() -> bool:
	return _instant_choice_flow.has_pending_dimension_gate_from_runtime_state(self)


func _queue_full_gauge_after_spawn_intro(owner: Object, pending_feedback_text: String = "") -> void:
	_instant_choice_flow.queue_full_gauge_from_runtime_state(self, owner, pending_feedback_text)


func _queue_full_gauge_after_spawn_intro_choice(owner: Object, choice_name: String = "") -> Dictionary:
	return _instant_choice_flow.queue_full_gauge_choice_from_runtime_state(self, owner, choice_name)


func has_pending_full_gauge_after_spawn_intro() -> bool:
	return _instant_choice_flow.has_pending_full_gauge_from_runtime_state(self)


func on_ball_spawn_intro_finished(
	owner: Object,
	registry: Object,
	angel_roll_options: Dictionary = {}
) -> Dictionary:
	# Existing deferred dimension/full-gauge actions resolve first by contract.
	# Angel then atomically replaces the prior stage result and refreshes the
	# final owner/config consumers from that post-deferred value.
	var result: Dictionary = _instant_choice_flow.on_ball_spawn_intro_finished_from_runtime_state(
		self,
		owner,
		registry
	)
	var angel_result: Dictionary = _angel_blessing_runtime_state.handle_spawn_intro_completion_from_runtime_state(
		self,
		owner,
		registry,
		angel_roll_options
	)
	result.merge(angel_result, true)
	return result


func _apply_monkey_blessing_choice(owner: Object, registry: Object, choice_name: String = "") -> Dictionary:
	return _instant_choice_flow.apply_monkey_blessing_choice_from_runtime_state(self, owner, registry, choice_name)


func _capture_resume_pre_choice_velocity(owner: Object) -> void:
	_resume_safety.capture_pre_choice_velocity_from_runtime_state(self, owner)


func _try_arm_resume_safety(owner: Object, registry: Object) -> void:
	_resume_safety.try_arm_from_runtime_state(self, owner, registry)


func _clear_resume_safety() -> void:
	_resume_safety.clear_active_from_runtime_state(self)


func _clear_resume_pre_choice() -> void:
	_resume_safety.clear_pre_choice_from_runtime_state(self)


func _sync_owner(owner: Object) -> void:
	_owner_sync_flow.sync_owner_from_runtime_state(self, owner)


func _pause_skill_cooldowns_for_choice(owner: Object, registry: Object) -> void:
	_skill_cooldown_pause.pause_from_runtime_state(self, owner, registry)


func _resume_skill_cooldowns_for_choice() -> void:
	_skill_cooldown_pause.resume_from_runtime_state(self)


func _sync_runtime_perk_owner_effects(owner: Object, registry: Object, perf_logger: Object = null) -> void:
	_owner_sync_flow.sync_owner_effects_from_runtime_state(self, owner, registry, perf_logger)


func _refresh_item_polish_consumers(owner: Object, registry: Object) -> void:
	_owner_sync_flow.refresh_item_polish_consumers_from_runtime_state(self, owner, registry)


func _refresh_mythic_runtime_perk_consumers(owner: Object, registry: Object) -> void:
	_owner_sync_flow.refresh_mythic_runtime_perk_consumers_from_runtime_state(self, owner, registry)


func _apply_training_to_skill_configs(registry: Object) -> void:
	_owner_sync_flow.apply_training_to_skill_configs_from_runtime_state(self, registry)


func _build_particles() -> void:
	_choice_layout.rebuild_particles_from_runtime_state(self, PARTICLE_COUNT)


func _get_catalog(registry: Object) -> Object:
	return _registry_lookup.get_catalog(registry)


func _get_skill_config_key(character_type: String) -> String:
	return _character_context.get_skill_config_key(character_type)


func _get_instance(registry: Object, key: String) -> Object:
	return _registry_lookup.get_instance(registry, key)


func _get_character_type(owner: Object) -> String:
	return _character_context.get_owner_character_type(owner)
