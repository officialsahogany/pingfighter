extends RefCounted

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkAngelBlessingCooldownCapability := preload("res://scripts/characters/runtime_perk_angel_blessing_cooldown_capability.gd")
const RuntimePerkAngelBlessingStageLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd")
const RuntimePerkAngelBlessingModalFlow := preload("res://scripts/characters/runtime_perk_angel_blessing_modal_flow.gd")
const RuntimePerkAngelBlessingAcquisitionLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_acquisition_lifecycle.gd")
const RuntimePerkAngelBlessingLocalization := preload("res://scripts/characters/runtime_perk_angel_blessing_localization.gd")
const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkActiveUnlockFlight := preload("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
const RuntimePerkUnlockShowcase := preload("res://scripts/characters/runtime_perk_unlock_showcase.gd")
const RuntimePerkSkillCooldownPause := preload("res://scripts/characters/runtime_perk_skill_cooldown_pause.gd")
const RuntimePerkDeferredInstants := preload("res://scripts/characters/runtime_perk_deferred_instants.gd")
const RuntimePerkInstantRewards := preload("res://scripts/characters/runtime_perk_instant_rewards.gd")
const RuntimePerkInstantChoiceFlow := preload("res://scripts/characters/runtime_perk_instant_choice_flow.gd")
const RuntimePerkLevelSideEffects := preload("res://scripts/characters/runtime_perk_level_side_effects.gd")
const RuntimePerkLingpetRewards := preload("res://scripts/characters/runtime_perk_lingpet_rewards.gd")
const RuntimePerkOwnerEffectSync := preload("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
const RuntimePerkOwnerSyncFlow := preload("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
const RuntimePerkResumeSafety := preload("res://scripts/characters/runtime_perk_resume_safety.gd")
const RuntimePerkStarpointAbsorption := preload("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
const RuntimePerkStarpointCollectionFlow := preload("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
const RuntimePerkUnlockSwapLayout := preload("res://scripts/characters/runtime_perk_unlock_swap_layout.gd")
const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const RuntimePerkGamepadNavigation := preload("res://scripts/characters/runtime_perk_gamepad_navigation.gd")
const RuntimePerkSnapshotBuilder := preload("res://scripts/characters/runtime_perk_snapshot_builder.gd")
const RuntimePerkEffectiveStatQuerySurface := preload("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
const RuntimePerkChoiceAudio := preload("res://scripts/characters/runtime_perk_choice_audio.gd")
const RuntimePerkChoiceFeedback := preload("res://scripts/characters/runtime_perk_choice_feedback.gd")
const RuntimePerkChoiceOfferModifiers := preload("res://scripts/characters/runtime_perk_choice_offer_modifiers.gd")
const RuntimePerkChoiceOpening := preload("res://scripts/characters/runtime_perk_choice_opening.gd")
const RuntimePerkChoiceSelection := preload("res://scripts/characters/runtime_perk_choice_selection.gd")
const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const RuntimePerkChoiceActionRunner := preload("res://scripts/characters/runtime_perk_choice_action_runner.gd")
const RuntimePerkChoiceStandardPath := preload("res://scripts/characters/runtime_perk_choice_standard_path.gd")
const RuntimePerkChoiceOpenFlow := preload("res://scripts/characters/runtime_perk_choice_open_flow.gd")
const RuntimePerkChoiceApplyFlow := preload("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
const RuntimePerkChoiceConfirmFlow := preload("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
const RuntimePerkUnlockShowcaseFlow := preload("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
const RuntimePerkUpdateFlow := preload("res://scripts/characters/runtime_perk_update_flow.gd")
const RuntimePerkChoiceFinishFlow := preload("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
const RuntimePerkDebugGrants := preload("res://scripts/characters/runtime_perk_debug_grants.gd")
const RuntimePerkOwnerProjection := preload("res://scripts/characters/runtime_perk_owner_projection.gd")
const RuntimePerkGoldAwardFlow := preload("res://scripts/characters/runtime_perk_gold_award_flow.gd")
const RuntimePerkResetState := preload("res://scripts/characters/runtime_perk_reset_state.gd")
const RuntimePerkModalInput := preload("res://scripts/characters/runtime_perk_modal_input.gd")
const RuntimePerkUnlockChoiceApply := preload("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")
const RuntimePerkDynamicEffects := preload("res://scripts/characters/runtime_perk_dynamic_effects.gd")

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
const ITEM_RECYCLE_ID := RuntimePerkEffectiveLevels.ITEM_RECYCLE_ID
const ITEM_RECYCLE_CHANCE_PER_LEVEL := RuntimePerkEffectiveLevels.ITEM_RECYCLE_CHANCE_PER_LEVEL
const MAX_ITEM_RECYCLE_CHANCE := RuntimePerkEffectiveLevels.MAX_ITEM_RECYCLE_CHANCE
const PERK_LAUREL_SHIELD_ID := RuntimePerkEffectiveLevels.PERK_LAUREL_SHIELD_ID
const DASH_ACCELERATION_ID := RuntimePerkEffectiveLevels.DASH_ACCELERATION_ID
const DASH_ACCELERATION_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.DASH_ACCELERATION_BONUS_PER_LEVEL
const CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END := RuntimePerkDeferredInstants.DEFER_DIMENSION_GATE_CONTEXT_KEY
const CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END := RuntimePerkDeferredInstants.DEFER_FULL_GAUGE_CONTEXT_KEY
const DOWNTOWN_TREASURE_MAP_ID := RuntimePerkEffectiveLevels.DOWNTOWN_TREASURE_MAP_ID
const TREASURE_MAP_FIELD_MYTHIC_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.TREASURE_MAP_FIELD_MYTHIC_BONUS_PER_LEVEL
const TREASURE_MAP_PASSIVE_DROP_SHARE_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.TREASURE_MAP_PASSIVE_DROP_SHARE_BONUS_PER_LEVEL
const TREASURE_MAP_HUNT_LEGENDARY_BONUS_PER_LEVEL := RuntimePerkEffectiveLevels.TREASURE_MAP_HUNT_LEGENDARY_BONUS_PER_LEVEL
const PERK_POLISH_AMPLIFIABLE_BONUS_IDS := RuntimePerkEffectiveLevels.PERK_POLISH_AMPLIFIABLE_BONUS_IDS
const LINGPET_AFFINITY_CHIP_CHOICE_ID := "lingpet_affinity_chip"
const LINGPET_RING_CORE_UPGRADE_CHOICE_ID := "lingpet_ring_core_upgrade"
const VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS := RuntimePerkEffectiveLevels.VIPER_IGNITION_AURA_LEVEL_BONUS_EXCLUDED_IDS

var runtime_skill_levels: Dictionary = {}
var starpoint_for_skills := 0
var pending_skill_choices := 0
var choice_active := false
var current_choices: Array = []
var selected_index := 0
var animation_time := 0.0
var particles: Array = []
var gold_from_perks := 0
# ---- 퍽 융합 위임 계층 ----
# 코어(records/커밋/오버레이/한계돌파)는 PerkFusionState가 소유하고, 이
# 래퍼는 central getter·projection·부산물 런타임을 잇는 접착만 담당한다.
var _perk_fusion_state: Object = null
var _perk_fusion_byproduct_runtime: Object = null
var _perk_fusion_offer_planner: Object = null
var _perk_fusion_display_projector: Object = null
var _perk_fusion_display_catalog: Object = null
var _perk_fusion_projection_cache: Dictionary = {}
var _perk_fusion_projection_cache_key := 0
var _perk_fusion_projection_cache_ready := false
var _perk_fusion_projection_builds := 0
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
var _character_context: Object = RuntimePerkCharacterContext.new()
var _registry_lookup: Object = RuntimePerkRegistryLookup.new()
var _choice_layout: Object = RuntimePerkChoiceLayout.new()
var _active_unlock_flight: Object = RuntimePerkActiveUnlockFlight.new()
var _unlock_showcase_controller: Object = RuntimePerkUnlockShowcase.new()
var _skill_cooldown_pause: Object = RuntimePerkSkillCooldownPause.new()
var _deferred_instants: Object = RuntimePerkDeferredInstants.new()
var _effective_levels: Object = RuntimePerkEffectiveLevels.new()
var _instant_rewards: Object = RuntimePerkInstantRewards.new()
var _instant_choice_flow: Object = RuntimePerkInstantChoiceFlow.new()
var _level_side_effects: Object = RuntimePerkLevelSideEffects.new()
var _lingpet_rewards: Object = RuntimePerkLingpetRewards.new()
var _owner_effect_sync: Object = RuntimePerkOwnerEffectSync.new()
var _owner_sync_flow: Object = RuntimePerkOwnerSyncFlow.new()
var _resume_safety: Object = RuntimePerkResumeSafety.new()
var _starpoint_absorption: Object = RuntimePerkStarpointAbsorption.new()
var _starpoint_collection_flow: Object = RuntimePerkStarpointCollectionFlow.new()
var _unlock_swap_layout: Object = RuntimePerkUnlockSwapLayout.new()
var _unlock_swap_flow: Object = RuntimePerkUnlockSwapFlow.new()
var _gamepad_navigation: Object = RuntimePerkGamepadNavigation.new()
var _snapshot_builder: Object = RuntimePerkSnapshotBuilder.new()
var _effective_stat_queries: Object = RuntimePerkEffectiveStatQuerySurface.new()
var _angel_blessing_state: Object = RuntimePerkAngelBlessingState.new()
var _angel_blessing_cooldown_capability: Object = RuntimePerkAngelBlessingCooldownCapability.new()
var _angel_blessing_stage_lifecycle: Object = RuntimePerkAngelBlessingStageLifecycle.new()
var _angel_blessing_modal_flow: Object = RuntimePerkAngelBlessingModalFlow.new()
var _angel_blessing_acquisition_lifecycle: Object = RuntimePerkAngelBlessingAcquisitionLifecycle.new()
var _choice_audio: Object = RuntimePerkChoiceAudio.new()
var _choice_feedback: Object = RuntimePerkChoiceFeedback.new()
var _choice_offer_modifiers: Object = RuntimePerkChoiceOfferModifiers.new()
var _choice_opening: Object = RuntimePerkChoiceOpening.new()
var _choice_selection: Object = RuntimePerkChoiceSelection.new()
var _choice_completion: Object = RuntimePerkChoiceCompletion.new()
var _choice_dispatch: Object = RuntimePerkChoiceDispatch.new()
var _choice_action_runner: Object = RuntimePerkChoiceActionRunner.new()
var _choice_standard_path: Object = RuntimePerkChoiceStandardPath.new()
var _choice_open_flow: Object = RuntimePerkChoiceOpenFlow.new()
var _choice_apply_flow: Object = RuntimePerkChoiceApplyFlow.new()
var _choice_confirm_flow: Object = RuntimePerkChoiceConfirmFlow.new()
var _unlock_showcase_flow: Object = RuntimePerkUnlockShowcaseFlow.new()
var _update_flow: Object = RuntimePerkUpdateFlow.new()
var _choice_finish_flow: Object = RuntimePerkChoiceFinishFlow.new()
var _debug_grants: Object = RuntimePerkDebugGrants.new()
var _owner_projection: Object = RuntimePerkOwnerProjection.new()
var _gold_award_flow: Object = RuntimePerkGoldAwardFlow.new()
var _reset_state: Object = RuntimePerkResetState.new()
var _modal_input: Object = RuntimePerkModalInput.new()
var _unlock_choice_apply: Object = RuntimePerkUnlockChoiceApply.new()
var _dynamic_effects: Object = RuntimePerkDynamicEffects.new()


func _get_perk_fusion_state() -> Object:
	if _perk_fusion_state == null:
		_perk_fusion_state = load("res://scripts/characters/perk_fusion_state.gd").new()
	return _perk_fusion_state


func _get_perk_fusion_byproduct_runtime() -> Object:
	if _perk_fusion_byproduct_runtime == null:
		_perk_fusion_byproduct_runtime = load("res://scripts/characters/perk_fusion_byproduct_runtime.gd").new()
	return _perk_fusion_byproduct_runtime


func get_perk_fusion_state() -> Object:
	return _get_perk_fusion_state()


# 커밋: 코어가 record를 소유하고 revision을 올린다 — projection 캐시 키에
# revision이 들어가므로 커밋은 자동으로 캐시를 무효화한다.
func commit_perk_fusion(source_ids: Array, outcome_data: Dictionary, catalog: Object) -> Dictionary:
	return _get_perk_fusion_state().commit_fusion(source_ids, outcome_data, catalog, runtime_skill_levels)


func restore_perk_fusion_snapshot(snapshot: Dictionary, catalog: Object) -> Dictionary:
	return _get_perk_fusion_state().restore_snapshot(snapshot, catalog, runtime_skill_levels)


func apply_perk_fusion_option_value(perk_id: String, option_key: String, base_value: float) -> float:
	return float(_get_perk_fusion_state().apply_option_value(perk_id, option_key, base_value))


func get_perk_fusion_snapshot() -> Dictionary:
	return _get_perk_fusion_state().get_snapshot()


func get_perk_fusion_effective_level_bonus(perk_id: String) -> int:
	return int(_get_perk_fusion_state().get_effective_level_bonus(perk_id))


func get_perk_fusion_owned_byproduct_ids() -> Array[String]:
	return _get_perk_fusion_state().get_owned_byproduct_ids()


func get_perk_fusion_slot_reduction() -> int:
	return int(_get_perk_fusion_state().get_slot_reduction())


# 황금 궤적: 부산물 런타임이 라운드 40 실골드 캡을 소유한다. 골드 배수
# (아이템 배수·점화 오라)는 클램프 "이전"에 적용해, 배수로 부풀린 지급이
# 실 저장 골드 기준 캡을 넘지 못하게 한다.
func award_perk_fusion_wall_bounce_gold(_context: Dictionary, _deps: Dictionary) -> int:
	var byproduct_runtime: Object = _get_perk_fusion_byproduct_runtime()
	var offer: int = int(byproduct_runtime.get_wall_bounce_gold_offer(get_perk_fusion_owned_byproduct_ids()))
	if offer <= 0:
		return 0
	var modified := float(offer) * maxf(0.0, item_gold_gain_multiplier)
	if viper_ignition_aura_active:
		modified *= 2.0
	var remaining: int = int(byproduct_runtime.get_remaining_wall_bounce_gold())
	var actual: int = mini(int(round(modified)), remaining)
	if actual <= 0:
		return 0
	byproduct_runtime.record_wall_bounce_gold(actual)
	gold_from_perks += actual
	return actual


func get_perk_fusion_round_golden_trajectory_gold() -> int:
	var byproduct_runtime: Object = _get_perk_fusion_byproduct_runtime()
	return int(byproduct_runtime.GOLDEN_TRAJECTORY_ROUND_CAP) - int(byproduct_runtime.get_remaining_wall_bounce_gold())


# 융합 결과 컨텍스트(모달/부산물 payload 후보): 한계돌파 자격은 "base 레벨이
# 저작 테이블 최대"인 소스 — 자격 판정은 catalog의 max_level과 비교한다.
func _build_perk_fusion_result_context(source_ids: Array, catalog: Object) -> Dictionary:
	var eligible: Array[String] = []
	for source_value: Variant in source_ids:
		var perk_id := str(source_value).strip_edges()
		if perk_id.is_empty():
			continue
		var base_level := int(runtime_skill_levels.get(perk_id, 0))
		var max_level := 5
		if catalog != null and catalog.has_method("get_perk_data"):
			var data: Dictionary = catalog.get_perk_data(perk_id)
			max_level = int(data.get("max_level", 5)) if not data.is_empty() else 5
		if base_level > 0 and base_level >= max_level:
			eligible.append(perk_id)
	return {"limit_break_eligible_sources": eligible}


# TAB/모달이 매 프레임 읽는 표시 projection의 캐시 래퍼. 키=레벨 해시 ×
# fusion revision × locale × 유효레벨 보정(왕관/반지 성장이 라이브 hover
# 값을 바꾼다) — reset은 코어 revision 증가로 자동 무효화된다.
func get_perk_fusion_display_projection(catalog: Object = null) -> Dictionary:
	# catalog 미지정(스냅샷 경로)은 state 소유 기본 표시 카탈로그를 쓴다 —
	# 저작 slot_cost 등 카탈로그 파생 필드가 커밋 전에도 보존돼야 한다.
	if catalog == null:
		if _perk_fusion_display_catalog == null:
			_perk_fusion_display_catalog = load("res://scripts/characters/runtime_perk_catalog.gd").new()
		catalog = _perk_fusion_display_catalog
	var cache_key: int = hash([
		runtime_skill_levels.hash(),
		_get_perk_fusion_state().get_revision(),
		# 주사위 리비전: 합성 채널이 주사위 synthetic 엔트리를 함께 실으므로
		# 주사위 커밋/리셋도 표시 캐시를 무효화해야 한다.
		get_mystic_dice_revision(),
		_get_perk_fusion_display_locale(),
		item_perk_level_bonus,
		int(viper_ignition_aura_active),
		catalog.get_instance_id() if catalog != null else 0,
	])
	if _perk_fusion_projection_cache_ready and cache_key == _perk_fusion_projection_cache_key:
		return _perk_fusion_projection_cache
	if _perk_fusion_display_projector == null:
		_perk_fusion_display_projector = load("res://scripts/characters/perk_fusion_display_projection.gd").new()
	_perk_fusion_projection_builds += 1
	var projection: Dictionary = _perk_fusion_display_projector.build(
		runtime_skill_levels,
		get_perk_fusion_snapshot(),
		catalog,
		get_effective_runtime_skill_levels(),
		_build_perk_fusion_live_source_options()
	)
	# 주사위 synthetic 엔트리를 기존 합성 채널에 병합 — HUD/TAB 소비자가
	# 두 번째 merge 정책을 배우지 않게 한다(projector.merge 소유).
	if _mystic_dice_display_projector == null:
		_mystic_dice_display_projector = load("res://scripts/characters/mystic_dice_display_projection.gd").new()
	projection = _mystic_dice_display_projector.merge(projection, get_mystic_dice_snapshot())
	projection["cache_signature"] = cache_key
	_perk_fusion_projection_cache = projection
	_perk_fusion_projection_cache_key = cache_key
	_perk_fusion_projection_cache_ready = true
	return projection


func get_perk_fusion_display_cache_stats() -> Dictionary:
	return {"projection_builds": _perk_fusion_projection_builds}


func _get_perk_fusion_display_locale() -> String:
	var language_settings: Object = load("res://scripts/core/language_settings.gd")
	if language_settings != null and language_settings.has_method("get_language"):
		return str(language_settings.get_language())
	return ""


# 라이브 hover 옵션: value=성장한 base(융합 이전), adjusted_value=production
# central getter와 일치하는 값(이중 페널티 금지 — 오버레이는 한 번만).
func _build_perk_fusion_live_source_options() -> Dictionary:
	var live: Dictionary = {}
	var conversion_values: Object = load("res://scripts/characters/perk_conversion_values.gd")
	for record: Dictionary in _get_perk_fusion_state().get_all_records():
		var penalties: Dictionary = record.get("option_penalties", {}) as Dictionary
		var snapshots: Dictionary = record.get("commit_value_snapshots", {}) as Dictionary
		var deleted: Dictionary = record.get("deleted_options", {}) as Dictionary
		for source_value: Variant in record.get("sources", []) as Array:
			var perk_id := str(source_value)
			var option_keys: Array[String] = []
			for key_source: Dictionary in [
				penalties.get(perk_id, {}) as Dictionary,
				snapshots.get(perk_id, {}) as Dictionary,
			]:
				for option_value: Variant in key_source.keys():
					var option_key := str(option_value)
					if option_key not in option_keys:
						option_keys.append(option_key)
			for option_value: Variant in deleted.get(perk_id, []) as Array:
				var deleted_key := str(option_value)
				if deleted_key not in option_keys:
					option_keys.append(deleted_key)
			if option_keys.is_empty():
				continue
			var per_perk: Dictionary = {}
			var effective_level: int = get_runtime_skill_level(perk_id)
			for option_key: String in option_keys:
				var base_value: float
				if option_key == "runtime_skill_bonus":
					base_value = _effective_stat_queries.get_runtime_skill_bonus_before_fusion_from_runtime_state(self, perk_id)
				else:
					base_value = float(conversion_values.get_value(perk_id, option_key, effective_level))
				per_perk[option_key] = {
					"value": base_value,
					"adjusted_value": apply_perk_fusion_option_value(perk_id, option_key, base_value),
				}
			live[perk_id] = per_perk
	return live


# ── 신비의 주사위 위임 계층 (융합 위임 패턴 미러) ────────────────────
# 코어 모듈(state/roller/planner/modal flow/input/paddle effect)은 각자
# 소유 파일에 살고, 이 파사드는 배선·리비전·리셋 경계만 소유한다.

var _mystic_dice_state: Object = null
var _mystic_dice_roller: Object = null
var _mystic_dice_offer_planner: Object = null
var _mystic_dice_modal_flow: Object = null
var _mystic_dice_modal_input: Object = null
var _mystic_dice_display_projector: Object = null
var _mystic_dice_paddle_effect: Object = null
var _mystic_dice_paddle_effect_pending := false
var _mystic_dice_last_finished_revision := 0


func _get_mystic_dice_state() -> Object:
	if _mystic_dice_state == null:
		_mystic_dice_state = load("res://scripts/characters/mystic_dice_state.gd").new()
	return _mystic_dice_state


func _get_mystic_dice_offer_planner() -> Object:
	if _mystic_dice_offer_planner == null:
		_mystic_dice_offer_planner = load("res://scripts/characters/mystic_dice_offer_planner.gd").new()
	return _mystic_dice_offer_planner


func _get_mystic_dice_modal_flow() -> Object:
	if _mystic_dice_modal_flow == null:
		_mystic_dice_modal_flow = load("res://scripts/characters/mystic_dice_modal_flow.gd").new()
	return _mystic_dice_modal_flow


func _get_mystic_dice_modal_input() -> Object:
	if _mystic_dice_modal_input == null:
		_mystic_dice_modal_input = load("res://scripts/characters/mystic_dice_modal_input.gd").new()
	return _mystic_dice_modal_input


func _get_mystic_dice_paddle_effect() -> Object:
	if _mystic_dice_paddle_effect == null:
		_mystic_dice_paddle_effect = load("res://scripts/characters/mystic_dice_paddle_effect.gd").new()
	return _mystic_dice_paddle_effect


func commit_mystic_dice_roll(raw_roll: Dictionary) -> Dictionary:
	return _get_mystic_dice_state().commit_roll(raw_roll)


func get_mystic_dice_raw(stat_key: String) -> int:
	return int(_get_mystic_dice_state().get_raw(stat_key))


func get_mystic_dice_multiplier(stat_key: String) -> float:
	return float(_get_mystic_dice_state().get_multiplier(stat_key))


func get_mystic_dice_revision() -> int:
	return int(_get_mystic_dice_state().get_revision())


func get_mystic_dice_snapshot() -> Dictionary:
	return _get_mystic_dice_state().get_snapshot()


func get_mystic_dice_display_projection() -> Dictionary:
	if _mystic_dice_display_projector == null:
		_mystic_dice_display_projector = load("res://scripts/characters/mystic_dice_display_projection.gd").new()
	return _mystic_dice_display_projector.build(get_mystic_dice_snapshot())


# 오퍼 후처리(이벤트 시점 1회 — per-frame 확률 롤 금지): 골드 lane만 신비의
# 주사위 카드로 스왑한다. roll_unit < 0 → 실 랜덤 1회(플래너는 순수 주입형).
func _try_inject_mystic_dice_offer(roll_unit: float = -1.0) -> Dictionary:
	if not choice_active:
		return {"rolled": false}
	var planner: Object = _get_mystic_dice_offer_planner()
	var offer_source := str(current_choice_context.get("source", ""))
	var remaining_uses: int = int(_get_mystic_dice_state().get_remaining_uses())
	# 부적격 오퍼(source 비허용/골드 lane 부재/캡 소진)는 전역 RNG를 한 번도
	# 소비하지 않는다 — randf 선소비는 rolled=false여도 이후 보상 난수열을
	# 교란한다. can_roll 통과 후에만 롤 유닛을 뽑는다.
	if not bool(planner.can_roll(current_choices, offer_source, remaining_uses)):
		return {"rolled": false}
	var unit: float = roll_unit if roll_unit >= 0.0 else randf()
	var result: Dictionary = planner.plan_offer(current_choices, offer_source, remaining_uses, unit)
	if bool(result.get("appeared", false)):
		current_choices = result.get("choices", current_choices) as Array
	return result


# 융합 오퍼 후처리: 주사위보다 먼저 돈다(주사위는 골드 lane만 스왑하므로
# 융합 카드 주입 뒤에 돌아야 서로 간섭이 없다). 전체 행동 봉인·자격 정책
# 정련은 융합 core 슬라이스의 offer 통합 스모크 소유 — 여기서는 생존
# 플래너에 소유 퍽(카탈로그 인지 + Lv≥1) 후보를 위임하는 접착만 놓는다.
func _try_inject_perk_fusion_offer(catalog: Object, roll_unit: float = -1.0) -> Dictionary:
	if not choice_active:
		return {"rolled": false}
	if _perk_fusion_offer_planner == null:
		_perk_fusion_offer_planner = load("res://scripts/characters/perk_fusion_offer_planner.gd").new()
	var offer_source := str(current_choice_context.get("source", ""))
	var eligible_sources: Array = []
	for skill_id_value: Variant in runtime_skill_levels.keys():
		var skill_id := str(skill_id_value)
		if int(runtime_skill_levels[skill_id_value]) <= 0:
			continue
		if catalog != null and catalog.has_method("get_perk_data") and (catalog.get_perk_data(skill_id) as Dictionary).is_empty():
			continue
		eligible_sources.append(skill_id)
	# 주사위와 동일한 RNG 무소비 계약: 부적격(비허용 source/재료 2종 미만/
	# 교체 가능 lane 부재 — all-protected 오퍼 포함) 경로는 난수를 한 번도
	# 뽑지 않는다. 자격 판별은 플래너 can_roll 단일 소스.
	if not bool(_perk_fusion_offer_planner.can_roll(current_choices, eligible_sources, offer_source)):
		return {"rolled": false}
	var appearance_unit: float = roll_unit if roll_unit >= 0.0 else randf()
	var replacement_unit: float = roll_unit if roll_unit >= 0.0 else randf()
	var result: Dictionary = _perk_fusion_offer_planner.plan_offer(
		current_choices,
		eligible_sources,
		offer_source,
		appearance_unit,
		replacement_unit
	)
	if bool(result.get("appeared", false)):
		current_choices = result.get("choices", current_choices) as Array
	return result


func is_mystic_dice_modal_active() -> bool:
	return _mystic_dice_modal_flow != null and bool(_mystic_dice_modal_flow.is_active())


func get_mystic_dice_modal_snapshot() -> Dictionary:
	if _mystic_dice_modal_flow == null:
		return {}
	return _mystic_dice_modal_flow.get_snapshot()


# D0→D1: 주사위 카드는 표준 apply_choice를 타지 않는다. raw choice_active/
# pending 큐는 전 구간 유지(새 freeze actor / modal-gate OR 금지 계약).
# roll_units 비움 → 실 랜덤 7유닛 1회.
func _begin_mystic_dice_modal(selected_choice: Dictionary, registry: Object, roll_units: Array = [], entered_via_rt: bool = false) -> bool:
	var roll_payload: Dictionary = _roll_mystic_dice(roll_units)
	if not bool(roll_payload.get("accepted", false)):
		return false
	var flow: Object = _get_mystic_dice_modal_flow()
	if not bool(flow.start(selected_choice, current_choices.duplicate(true), roll_payload)):
		return false
	_get_mystic_dice_modal_input().reset()
	# 진입 입력원이 실제 RT일 때만 래치를 무장한다 — D0에서 눌려 있던 RT가
	# D2 확정으로 캐스케이드하는 것을 막되, 키보드/마우스/A 진입 후의 첫
	# RT press까지 삼키면 안 된다(입력원별 계약).
	if entered_via_rt:
		_get_mystic_dice_modal_input().suppress_confirm_until_release()
	_play_perk_select_audio(registry)
	return true


func _roll_mystic_dice(roll_units: Array = []) -> Dictionary:
	if _mystic_dice_roller == null:
		_mystic_dice_roller = load("res://scripts/characters/mystic_dice_roller.gd").new()
	var units: Array = roll_units
	if units.is_empty():
		units = []
		for _index: int in range(_mystic_dice_roller.get_stat_keys().size()):
			units.append(randf())
	return _mystic_dice_roller.roll(units)


func _handle_mystic_dice_modal_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	var resolution: Dictionary = _get_mystic_dice_modal_input().resolve(
		event,
		get_mystic_dice_modal_snapshot(),
		view_size
	)
	var flow: Object = _get_mystic_dice_modal_flow()
	if resolution.has("move"):
		flow.move_selection(int(resolution.get("move", 0)))
	if resolution.has("selected_action") and int(resolution.get("selected_action", -1)) >= 0:
		flow.set_selected_action(int(resolution.get("selected_action", -1)))
	# cancel(ESC/X)은 의도적 no-op — 주사위는 커밋 의사 흐름이라 취소 불가.
	if bool(resolution.get("activate", false)):
		_activate_mystic_dice_selected_action(owner, registry)
	return bool(resolution.get("consumed", true))


func _activate_mystic_dice_selected_action(owner: Object, registry: Object, reroll_units: Array = []) -> Dictionary:
	var flow: Object = _get_mystic_dice_modal_flow()
	var request: Dictionary = flow.request_selected_action()
	if bool(request.get("reroll_requested", false)):
		var payload: Dictionary = _roll_mystic_dice(reroll_units)
		if bool(flow.begin_reroll(payload)):
			return {"rerolled": true}
		return {"rerolled": false}
	if bool(request.get("commit_requested", false)):
		return _finish_mystic_dice_modal(owner, registry, request)
	return request


# D3: 원자 커밋 + 표준 finish 위임. 커밋 실패(캡)는 요청 래치를 되돌리고
# 모달을 유지한다.
func _finish_mystic_dice_modal(owner: Object, registry: Object, request: Dictionary) -> Dictionary:
	var finish_result: Dictionary = commit_mystic_dice_roll(request.get("raw", {}) as Dictionary)
	if not bool(finish_result.get("accepted", false)):
		_get_mystic_dice_modal_flow().reject_commit_request()
		return finish_result
	# 스탯 소비자(일반+mythic) 즉시 1회 갱신 — 모달이 닫히기 전에 착지.
	_owner_sync_flow.sync_owner_effects_from_runtime_state(self, owner, registry)
	_owner_sync_flow.refresh_mythic_runtime_perk_consumers_from_runtime_state(self, owner, registry)
	# 모달 physics 차단 중에는 패들 연출 시작을 미룬다 — 재개 첫 게임플레이
	# 틱(update_mystic_dice_paddle_effect)이 시작한다.
	_mystic_dice_paddle_effect_pending = true
	var committed_choice: Dictionary = {
		"id": "mystic_dice",
		"type": "mystic_dice",
		"mystic_dice_revision": get_mystic_dice_revision(),
	}
	_get_mystic_dice_modal_flow().mark_committed(finish_result, committed_choice)
	var finish: Dictionary = _finish_successful_choice("mystic_dice", owner, registry, null, committed_choice)
	_get_mystic_dice_modal_flow().reset()
	_get_mystic_dice_modal_input().reset()
	var merged: Dictionary = finish_result.duplicate(true)
	merged["finish"] = finish
	return merged


func start_mystic_dice_paddle_effect() -> Dictionary:
	_mystic_dice_paddle_effect_pending = false
	return _get_mystic_dice_paddle_effect().start()


func bind_mystic_dice_paddle_fx_host(host: Node) -> void:
	_get_mystic_dice_paddle_effect().bind_host(host)


func get_mystic_dice_paddle_effect_snapshot() -> Dictionary:
	var snapshot: Dictionary = _get_mystic_dice_paddle_effect().get_snapshot()
	snapshot["pending_start"] = _mystic_dice_paddle_effect_pending
	return snapshot


func get_mystic_dice_paddle_fx_host() -> Node:
	if _mystic_dice_paddle_effect == null:
		return null
	return _mystic_dice_paddle_effect.get_bound_host()


# 게임플레이 시간 전용 3초 시계: 모달 차단 중엔 드라이버가 안 불러서
# 자연 정지, 재개 첫 틱이 지연 시작한다(그 틱의 delta는 소모하지 않음).
func update_mystic_dice_paddle_effect(delta: float) -> bool:
	if _mystic_dice_paddle_effect_pending:
		start_mystic_dice_paddle_effect()
		return true
	if _mystic_dice_paddle_effect == null:
		return false
	return bool(_mystic_dice_paddle_effect.update(delta))


func clear_mystic_dice_paddle_effect() -> void:
	_mystic_dice_paddle_effect_pending = false
	if _mystic_dice_paddle_effect != null:
		_mystic_dice_paddle_effect.reset()


# 라운드/스코어/스테이지 경계 공통 훅: 진행 중 3초 패들 연출만 걷는다 —
# 주사위 영구 스탯은 런 스코프라 보존된다(new-run reset만 지운다).
func reset_mystic_dice_round_visuals() -> void:
	clear_mystic_dice_paddle_effect()


# new-run 리셋 파사드 위임(runtime_perk_reset_state 소유): 영구 raw·사용
# 횟수를 지우고 revision을 올려 표시 캐시를 무효화한다.
func reset_mystic_dice_state() -> void:
	if _mystic_dice_state != null:
		_mystic_dice_state.reset()


func reset() -> void:
	if _perk_fusion_state != null:
		_perk_fusion_state.reset()
	if _perk_fusion_byproduct_runtime != null:
		_perk_fusion_byproduct_runtime.reset()
	_perk_fusion_projection_cache_ready = false
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
	# 오퍼 후처리(오퍼 생성 직후 1회): 융합 → 주사위 순서 고정.
	_try_inject_perk_fusion_offer(catalog)
	_try_inject_mystic_dice_offer()


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
	return _choice_opening.is_choice_active_from_runtime_state(self)


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
	# 융합 재료쌍 아이콘 스테이지드 프리웜: 업데이트 경로(배틀 오버레이 프레임
	# 컨트롤러·플라자·결과화면 스타포인트 핸들러 공통) 소유 — 리비전 변경 후
	# 첫 update 틱에서 합성되고, CanvasItem draw 프레임은 조회 히트만 본다.
	_prewarm_fusion_pair_icons(registry)
	# 주사위 모달 시계(D1 굴림 진행/D2 바운디드 hover)는 모달 활성 중에만
	# 전진한다 — 표준 update 흐름과 같은 틱에서 함께 돈다.
	if is_mystic_dice_modal_active():
		_mystic_dice_modal_flow.update(delta)
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


func _prewarm_fusion_pair_icons(registry: Object) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var icon_renderer: Object = registry.get_instance("runtime_perk_icon_renderer")
	if icon_renderer != null and icon_renderer.has_method("prewarm_fusion_pair_icons_for_state"):
		icon_renderer.prewarm_fusion_pair_icons_for_state(self)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
	# 주사위 모달이 열려 있는 동안은 모든 입력을 모달이 우선 소비한다
	# (ESC 포함 — 커밋 의사 흐름이라 취소 no-op).
	if is_mystic_dice_modal_active():
		return _handle_mystic_dice_modal_input(event, owner, registry, view_size)
	return _modal_input.handle_input_from_runtime_state(self, event, owner, registry, view_size)


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
		# D0 주사위 가로채기: 주사위 카드는 표준 apply_choice를 타지 않는다 —
		# 모달(D1~D3)이 굴림·커밋을 소유하고, raw choice_active/pending 큐는
		# 전 구간 유지된다(새 freeze actor / modal-gate OR 금지 계약).
		var selected_choice: Dictionary = _get_selected_choice_snapshot()
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
	# 주사위 D3 리비전 가드: 같은 커밋 리비전의 중복 finish는 pending/
	# sequence/다음 모달을 두 번 소비하지 않는 no-op이어야 한다.
	if str(choice.get("type", "")) == "mystic_dice":
		var dice_revision := int(choice.get("mystic_dice_revision", 0))
		if dice_revision > 0 and dice_revision <= _mystic_dice_last_finished_revision:
			return {"already_finished": true}
		_mystic_dice_last_finished_revision = maxi(_mystic_dice_last_finished_revision, dice_revision)
	var result: Dictionary = _choice_finish_flow.finish_successful_choice_from_runtime_state(
		self,
		choice_id,
		owner,
		registry,
		perf_logger,
		choice
	)
	return result


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
			_angel_blessing_acquisition_lifecycle.on_accepted_choice(
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


func get_runtime_skill_level(skill_id: String) -> int:
	return _effective_stat_queries.get_runtime_skill_level_from_runtime_state(self, skill_id)


# apply_choice의 소스 계약(모듈분리 씰)은 본문에 raw 레벨 딕셔너리 직접 접근을
# 금지한다. angel 획득 훅이 필요로 하는 raw 레벨 스냅샷은 이 헬퍼로 우회한다.
func _get_raw_runtime_perk_level(perk_id: String) -> int:
	return int(runtime_skill_levels.get(perk_id, 0))


func get_converted_perk_effect_level(perk_id: String) -> int:
	return _effective_stat_queries.get_converted_perk_effect_level_from_runtime_state(self, perk_id)


func get_effective_runtime_skill_levels() -> Dictionary:
	return _effective_stat_queries.get_effective_runtime_skill_levels_from_runtime_state(self)


func get_runtime_skill_bonus(skill_id: String) -> float:
	return _effective_stat_queries.get_runtime_skill_bonus_from_runtime_state(self, skill_id)


func _get_perk_amplify_multiplier(skill_id: String) -> float:
	return _effective_stat_queries.get_perk_amplify_multiplier_from_runtime_state(self, skill_id)


# Smasher 콤보증폭칩: 콤보 소모형 드라이브/파워스매싱의 콤보 비례 항을 추가 증폭.
# Python get_combo_amplifier_chip_bonus()(pingfighter.py) 패리티. GDScript는 튜플
# 미지원이라 Dictionary 반환. 레벨은 유효레벨(아이템/점화 오버플로우 포함)을 쓰되,
# 커브 레인만 mini(level,3)로 Lv3 하드캡(밸런스 보호) — drive/power-smash 주입부에서
# (1.0 + amp)로 콤보 항에만 곱한다(base 상수는 비증폭).
func get_combo_amplifier_chip_bonus() -> Dictionary:
	return _effective_stat_queries.get_combo_amplifier_chip_bonus_from_runtime_state(self)


func get_angel_blessing_state() -> Object:
	return _angel_blessing_state


func roll_angel_blessing_for_stage(
	stage: int,
	eligible_buff_ids: Array = [],
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	return _angel_blessing_state.roll_for_stage(
		stage,
		eligible_buff_ids,
		forced_face,
		forced_candidate_order
	)


func get_angel_blessing_eligible_buff_ids(character_type: String, registry: Object) -> Array[String]:
	return _angel_blessing_cooldown_capability.get_eligible_buff_ids(
		_angel_blessing_state,
		character_type,
		registry
	)


func get_angel_blessing_skill_cooldown_capability(character_type: String, registry: Object) -> Dictionary:
	return _angel_blessing_cooldown_capability.get_capability(character_type, registry)


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
	return _angel_blessing_state.get_snapshot()


func get_angel_blessing_acquisition_snapshot() -> Dictionary:
	var snapshot: Dictionary = _angel_blessing_modal_flow.get_snapshot()
	snapshot["roll_state"] = get_angel_blessing_snapshot()
	return snapshot


func get_angel_blessing_presentation_snapshot() -> Dictionary:
	return get_angel_blessing_acquisition_snapshot()


func has_angel_blessing_visual_work() -> bool:
	return _angel_blessing_modal_flow.has_visual_work()


func get_runtime_status_lines(perk_id: String) -> Array[String]:
	if perk_id.strip_edges() != RuntimePerkAngelBlessingState.PERK_ID:
		return []
	return RuntimePerkAngelBlessingLocalization.build_status_lines(
		get_angel_blessing_snapshot(),
		get_angel_blessing_acquisition_snapshot(),
		int(runtime_skill_levels.get(RuntimePerkAngelBlessingState.PERK_ID, 0)) > 0
	)


func has_pending_angel_blessing_acquisition() -> bool:
	return _angel_blessing_modal_flow.has_work()


func is_angel_blessing_modal_active() -> bool:
	return _angel_blessing_modal_flow.is_modal_active()


func has_angel_blessing_modal_work() -> bool:
	if _angel_blessing_modal_flow.has_visual_work() or _angel_blessing_modal_flow.has_pending_reveals():
		return true
	return _angel_blessing_modal_flow.has_ready_current_stage_roll()


func update_angel_blessing_acquisition(
	delta: float,
	owner: Object,
	registry: Object,
	blockers: Dictionary = {},
	roll_options: Dictionary = {}
) -> Dictionary:
	var update_result: Dictionary = _angel_blessing_modal_flow.update(delta)
	_play_angel_blessing_absorb_cues(registry, update_result)
	if is_angel_blessing_modal_active():
		update_result["snapshot"] = get_angel_blessing_acquisition_snapshot()
		return update_result
	if _is_angel_blessing_open_blocked(owner, registry, blockers):
		update_result["blocked"] = true
		update_result["snapshot"] = get_angel_blessing_acquisition_snapshot()
		return update_result
	if choice_active or has_pending_unlock_swap():
		update_result["blocked"] = true
		update_result["blocked_reason"] = "runtime_perk_choice"
		update_result["snapshot"] = get_angel_blessing_acquisition_snapshot()
		return update_result
	if pending_skill_choices > 0:
		update_result["choice_resume"] = _try_resume_deferred_runtime_choices(owner, registry)
		if choice_active or has_pending_unlock_swap():
			update_result["blocked"] = true
			update_result["blocked_reason"] = "runtime_perk_choice"
			update_result["snapshot"] = get_angel_blessing_acquisition_snapshot()
			return update_result

	var stage: int = _get_angel_blessing_owner_stage(owner)
	var pending_roll: Dictionary = _angel_blessing_modal_flow.take_ready_roll_for_stage(stage, false)
	if not pending_roll.is_empty():
		var roll_result: Dictionary = _roll_angel_blessing_current_stage_only(
			owner,
			registry,
			roll_options
		)
		update_result["pending_roll"] = pending_roll
		update_result["roll_result"] = roll_result
		if bool(roll_result.get("rolled", false)):
			_angel_blessing_modal_flow.queue_reveal_from_roll_result(
				roll_result,
				str(pending_roll.get("reason", "first_acquisition"))
			)

	if _angel_blessing_modal_flow.has_pending_reveals():
		var begin_result: Dictionary = _angel_blessing_modal_flow.begin_next_pending_reveal(stage)
		update_result["begin_result"] = begin_result
		if bool(begin_result.get("started", false)):
			_pause_skill_cooldowns_for_choice(owner, registry)
			var game_audio: Object = _get_instance(registry, "game_audio")
			if game_audio != null and game_audio.has_method("play_angel_blessing_roll"):
				game_audio.play_angel_blessing_roll()
	update_result["snapshot"] = get_angel_blessing_acquisition_snapshot()
	return update_result


func _play_angel_blessing_absorb_cues(registry: Object, update_result: Dictionary) -> void:
	var absorption_value: Variant = update_result.get("absorption", {})
	if not (absorption_value is Dictionary):
		return
	var cues_value: Variant = (absorption_value as Dictionary).get("arrival_cues", [])
	if not (cues_value is Array) or (cues_value as Array).is_empty():
		return
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio == null or not game_audio.has_method("play_angel_blessing_absorb"):
		return
	for _cue: Variant in cues_value:
		game_audio.play_angel_blessing_absorb()


func handle_angel_blessing_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	_view_size: Vector2 = Vector2.ZERO
) -> bool:
	if not is_angel_blessing_modal_active():
		return false
	var input_result: Dictionary = _angel_blessing_modal_flow.handle_input(event)
	if bool(input_result.get("dismissed", false)):
		_finalize_angel_blessing_deferred_choice_chain(owner, registry, true)
	return bool(input_result.get("consumed", false))


func on_angel_blessing_acquisition_cinematic_finished(
	perk_id: String,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var result: Dictionary = _angel_blessing_acquisition_lifecycle.on_acquisition_cinematic_finished(
		self,
		perk_id
	)
	if bool(result.get("ignored", false)) or perk_id.strip_edges() != "angel_blessing":
		return result
	if int(result.get("released", result.get("released_count", 0))) <= 0:
		result["ready_work"] = has_angel_blessing_modal_work()
		return result
	if owner == null or registry == null:
		return result
	if pending_skill_choices > 0 and not choice_active and not has_pending_unlock_swap():
		result["choice_resume"] = _try_resume_deferred_runtime_choices(owner, registry)
		result["opened_next_choice"] = choice_active
		if choice_active or has_pending_unlock_swap():
			return result
	result["angel_update"] = update_angel_blessing_acquisition(0.0, owner, registry)
	if (
		not choice_active
		and not has_pending_unlock_swap()
		and not has_angel_blessing_modal_work()
	):
		_finalize_angel_blessing_deferred_choice_chain(owner, registry)
	return result


func on_angel_blessing_round_boundary() -> void:
	var cancel_result: Dictionary = _angel_blessing_modal_flow.cancel_active_presentation()
	_angel_blessing_modal_flow.reset_for_round_boundary()
	if bool(cancel_result.get("canceled", false)):
		current_choice_context.clear()
		_resume_skill_cooldowns_for_choice()


func on_angel_blessing_stage_transition(_next_stage: int = 0) -> void:
	var had_discarded_work: bool = _has_current_stage_angel_blessing_work()
	_angel_blessing_modal_flow.reset_for_stage_boundary()
	if (
		not choice_active
		and not has_pending_unlock_swap()
		and (
			had_discarded_work
			or (
				_skill_cooldown_pause != null
				and _skill_cooldown_pause.has_method("is_active")
				and bool(_skill_cooldown_pause.is_active())
			)
		)
	):
		current_choice_context.clear()
		_resume_skill_cooldowns_for_choice()


func _should_defer_next_choice_for_angel_acquisition() -> bool:
	for pending_value: Variant in _angel_blessing_modal_flow.get_snapshot().get("pending_rolls", []):
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if bool(pending.get("waiting_for_cinematic", false)):
			return true
	return false


func _has_angel_blessing_post_choice_blocker() -> bool:
	if is_angel_blessing_modal_active() or _angel_blessing_modal_flow.has_pending_reveals():
		return true
	for pending_value: Variant in _angel_blessing_modal_flow.get_snapshot().get("pending_rolls", []):
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if (
			str(pending.get("policy", "")) == RuntimePerkAngelBlessingModalFlow.POLICY_CURRENT_STAGE
			or bool(pending.get("waiting_for_cinematic", false))
		):
			return true
	return false


func _has_current_stage_angel_blessing_work() -> bool:
	if is_angel_blessing_modal_active() or _angel_blessing_modal_flow.has_pending_reveals():
		return true
	for pending_value: Variant in _angel_blessing_modal_flow.get_snapshot().get("pending_rolls", []):
		if (
			pending_value is Dictionary
			and str((pending_value as Dictionary).get("policy", "")) == RuntimePerkAngelBlessingModalFlow.POLICY_CURRENT_STAGE
		):
			return true
	return false


func _continue_angel_blessing_after_choice(owner: Object, registry: Object) -> void:
	if choice_active or pending_skill_choices > 0 or _should_defer_next_choice_for_angel_acquisition():
		return
	update_angel_blessing_acquisition(0.0, owner, registry)


func _try_resume_deferred_runtime_choices(owner: Object, registry: Object) -> Dictionary:
	if pending_skill_choices <= 0 or choice_active or has_pending_unlock_swap():
		return {"opened": false, "pending_skill_choices": pending_skill_choices}
	var catalog: Object = _get_catalog(registry)
	if catalog != null:
		open_next_choice(
			_get_character_type(owner),
			catalog,
			false,
			owner,
			registry,
			null,
			current_choice_context.duplicate(true)
		)
	if not choice_active and not has_pending_unlock_swap() and pending_skill_choices > 0:
		# Match the established empty-catalog recursion: an earned choice with no
		# legal cards is consumed instead of leaving a non-renderable permanent
		# blocker between the acquisition cinematic and Angel.
		while pending_skill_choices > 0:
			_apply_choice_opening_update(
				_choice_opening.build_empty_choices_state_update(pending_skill_choices)
			)
	return {
		"opened": choice_active,
		"pending_skill_choices": pending_skill_choices,
		"catalog_available": catalog != null,
	}


func _finalize_angel_blessing_deferred_choice_chain(
	owner: Object,
	registry: Object,
	force_resume_effects: bool = false
) -> void:
	current_choice_context.clear()
	var had_cooldown_pause: bool = (
		_skill_cooldown_pause != null
		and _skill_cooldown_pause.has_method("is_active")
		and bool(_skill_cooldown_pause.is_active())
	)
	if had_cooldown_pause or force_resume_effects:
		_resume_skill_cooldowns_for_choice()
		_try_arm_resume_safety(owner, registry)
		_start_starpoint_absorption_effect(owner)
	_sync_owner(owner)


func _roll_angel_blessing_current_stage_only(
	owner: Object,
	registry: Object,
	roll_options: Dictionary = {}
) -> Dictionary:
	var forced_order_value: Variant = roll_options.get("forced_candidate_order", [])
	var forced_order: Array = forced_order_value if forced_order_value is Array else []
	return _angel_blessing_stage_lifecycle.on_ball_spawn_intro_finished(
		self,
		owner,
		registry,
		int(roll_options.get("forced_face", 0)),
		forced_order
	)


func _get_angel_blessing_owner_stage(owner: Object) -> int:
	if owner == null:
		return 0
	if _character_context != null and _character_context.has_method("get_current_stage"):
		return max(0, int(_character_context.get_current_stage(owner)))
	var stage_value: Variant = owner.get("current_stage")
	return max(0, int(stage_value)) if stage_value != null else 0


func _is_angel_blessing_open_blocked(
	owner: Object,
	registry: Object,
	blockers: Dictionary
) -> bool:
	for blocker_key in [
		"blocked",
		"higher_priority_modal_active",
		"stage_clear_result_active",
		"stage_clear_result_screen_active",
		"mythic_acquisition_active",
		"mythic_acquisition_cinematic_active",
		"scoreboard_active",
		"runtime_perk_choice_active",
	]:
		if bool(blockers.get(blocker_key, false)):
			return true
	var cached_module_getter := Callable()
	if registry != null and registry.has_method("get_cached_instance"):
		cached_module_getter = Callable(registry, "get_cached_instance")
	elif registry != null and registry.has_method("_get_cached_module"):
		cached_module_getter = Callable(registry, "_get_cached_module")
	elif registry != null and registry.has_method("get_instance"):
		cached_module_getter = Callable(registry, "get_instance")
	var shared_modal_gate: Object = _get_cached_angel_blocker_module(
		registry,
		"battle_scene_modal_gate_controller"
	)
	if (
		shared_modal_gate != null
		and shared_modal_gate.has_method("should_block_battle_physics")
		and cached_module_getter.is_valid()
		and bool(shared_modal_gate.should_block_battle_physics(cached_module_getter))
	):
		return true
	var result_screen: Object = _get_cached_angel_blocker_module(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active()):
		return true
	var scoreboard_state: Object = _get_cached_angel_blocker_module(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active()):
		return true
	var mythic_runtime: Object = _get_cached_angel_blocker_module(registry, "mythic_item_runtime")
	if mythic_runtime == null:
		return false
	for method_name in [
		"is_acquisition_cinematic_active",
		"is_pandora_legacy_selection_active",
		"is_debug_management_menu_open",
	]:
		if mythic_runtime.has_method(method_name) and bool(mythic_runtime.call(method_name)):
			return true
	return false


func _get_cached_angel_blocker_module(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.call("get_cached_instance", key)
	elif registry.has_method("_get_cached_module"):
		value = registry.call("_get_cached_module", key)
	elif registry.has_method("get_instance"):
		value = registry.call("get_instance", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


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


func get_downtown_treasure_map_field_mythic_bonus() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_field_mythic_bonus_from_runtime_state(self)


func get_downtown_treasure_map_field_mythic_multiplier() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_field_mythic_multiplier_from_runtime_state(self)


func get_downtown_treasure_map_passive_drop_share_bonus() -> float:
	return _effective_stat_queries.get_downtown_treasure_map_passive_drop_share_bonus_from_runtime_state(self)


func get_treasure_hunt_legendary_chance_bonus() -> float:
	return _effective_stat_queries.get_treasure_hunt_legendary_chance_bonus_from_runtime_state(self)


func get_treasure_hunt_legendary_chance(base_chance: float) -> float:
	return _effective_stat_queries.get_treasure_hunt_legendary_chance_from_runtime_state(self, base_chance)


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
	var forced_order_value: Variant = angel_roll_options.get("forced_candidate_order", [])
	var forced_order: Array = forced_order_value if forced_order_value is Array else []
	var current_stage: int = _get_angel_blessing_owner_stage(owner)
	var acquisition_reservation: Dictionary = _angel_blessing_modal_flow.take_ready_roll_for_stage(
		current_stage,
		true
	)
	var angel_result: Dictionary = _angel_blessing_stage_lifecycle.on_ball_spawn_intro_finished(
		self,
		owner,
		registry,
		int(angel_roll_options.get("forced_face", 0)),
		forced_order
	)
	if not angel_result.is_empty():
		result["angel_blessing"] = angel_result
	if bool(angel_result.get("rolled", false)):
		var reveal_reason: String = str(acquisition_reservation.get("reason", "stage_intro"))
		result["angel_blessing_reveal"] = _angel_blessing_modal_flow.queue_reveal_from_roll_result(
			angel_result,
			reveal_reason
		)
		result["angel_blessing_modal"] = update_angel_blessing_acquisition(
			0.0,
			owner,
			registry,
			{},
			angel_roll_options
		)
	if not acquisition_reservation.is_empty():
		result["angel_blessing_acquisition_reservation"] = acquisition_reservation
	return result


func _apply_monkey_blessing_choice(owner: Object, registry: Object, choice_name: String = "") -> Dictionary:
	return _instant_choice_flow.apply_monkey_blessing_choice_from_runtime_state(self, owner, registry, choice_name)


func _apply_treasure_hunt_choice(owner: Object, registry: Object) -> Dictionary:
	return _instant_choice_flow.apply_treasure_hunt_choice_from_runtime_state(self, owner, registry)


func _apply_lingpet_affinity_chip(owner: Object, registry: Object, choice_name: String = "") -> Dictionary:
	return _lingpet_rewards.apply_affinity_chip_from_runtime_state(self, owner, registry, choice_name)


func _apply_lingpet_ring_core_upgrade(
	owner: Object,
	registry: Object,
	requested_tier: int = 0,
	choice_name: String = ""
) -> Dictionary:
	return _lingpet_rewards.apply_ring_core_upgrade_from_runtime_state(self, owner, registry, requested_tier, choice_name)


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


func _tick_lingpet_ring_core_offer_cooldown(registry: Object) -> void:
	_lingpet_rewards.tick_ring_core_offer_cooldown_from_runtime_state(self, registry)


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
