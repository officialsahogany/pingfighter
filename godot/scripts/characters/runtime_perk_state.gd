extends RefCounted

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")
const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
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


func reset() -> void:
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
	_update_flow.update_internal_from_runtime_state(
		delta,
		view_size,
		owner,
		registry,
		self,
		perf_logger
	)


func handle_input(event: InputEvent, owner: Object, registry: Object, view_size: Vector2) -> bool:
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


func choose_selected(owner: Object, registry: Object, view_size: Vector2 = Vector2.ZERO) -> void:
	_choice_confirm_flow.choose_selected_from_runtime_state(
		self,
		owner,
		registry,
		view_size
	)


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
) -> void:
	_choice_finish_flow.finish_successful_choice_from_runtime_state(
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
	var result: Dictionary = _choice_apply_flow.apply_choice_from_runtime_state(self, choice, owner, registry, perf_logger)
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


func on_ball_spawn_intro_finished(owner: Object, registry: Object) -> Dictionary:
	return _instant_choice_flow.on_ball_spawn_intro_finished_from_runtime_state(self, owner, registry)


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
