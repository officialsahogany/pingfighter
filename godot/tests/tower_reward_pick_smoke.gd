extends SceneTree

const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentChestContextBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_chest_context_builder.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const TowerRewardPickOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_reward_pick_offer_builder.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentTrainingOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
)
const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkChoiceLayout := preload(
	"res://scripts/characters/runtime_perk_choice_layout.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const RuntimePerkEffectiveLevels := preload(
	"res://scripts/characters/runtime_perk_effective_levels.gd"
)
const RuntimePerkEffectiveStatQuerySurface := preload(
	"res://scripts/characters/runtime_perk_effective_stat_query_surface.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)
const VictoryLootPhaseState := preload(
	"res://scripts/core/victory_loot_phase_state.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []
var _finish_calls := 0
var _effect_calls := 0
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class ShellLikeOwner:
	extends RefCounted

	var values: Dictionary = {}

	func _init(initial_values: Dictionary) -> void:
		values = initial_values.duplicate(true)

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeSkillConfig:
	extends RefCounted

	var full := false

	func is_shared_slot_full() -> bool:
		return full

	func get_shared_slot_swap_candidates(_skill_id: String) -> Array:
		return ["drive"] if full else []

	func get_skill_data(skill_id: String) -> Dictionary:
		if skill_id == "ghost_shot":
			return {"id": skill_id, "name": "Ghost Shot"}
		return {}


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var current_choice_context: Dictionary = {}
	var fusion_active := false
	var pending_unlock_swap := false
	var pending_unlock_choice: Dictionary = {}
	var apply_calls := 0
	var stats_capture_calls := 0
	var stats_context_owner: Object = null
	var stats_context_registry_ref: WeakRef = null
	var snapshot_calls := 0
	var fusion_cost_query_calls := 0
	var physique_training := {"power": 1}
	var fusion_candidate_ids: Array[String] = ["mugong_a", "mugong_b"]

	func capture_stats_context(owner: Object, registry: Object) -> bool:
		stats_capture_calls += 1
		stats_context_owner = owner
		stats_context_registry_ref = weakref(registry) if registry != null else null
		return owner != null and registry != null

	func get_stats_context_owner() -> Object:
		return stats_context_owner

	func get_stats_context_registry() -> Object:
		return stats_context_registry_ref.get_ref() if stats_context_registry_ref != null else null

	func get_status_hover_mouse_pos() -> Vector2:
		return Vector2(7.0, 7.0)

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"pending_skill_choices": 0,
			"gold_from_perks": 0,
			"current_choices": [],
			"physique_training": physique_training.duplicate(true),
		}

	func get_physique_training_count(_training_id: String) -> int:
		return 0

	func is_physique_training_saturated(_training_id: String, _registry: Object = null) -> bool:
		return false

	func get_physique_training_multiplier() -> float:
		return 1.0

	func get_perk_fusion_candidate_ids(_catalog: Object) -> Array:
		return fusion_candidate_ids.duplicate()

	func get_downtown_treasure_map_mythic_multiplier() -> float:
		return 1.0

	func get_downtown_treasure_map_fusion_muhon_cost(base_cost: int) -> int:
		fusion_cost_query_calls += 1
		return RuntimePerkEffectiveLevels.new().get_downtown_treasure_map_fusion_muhon_cost(
			runtime_skill_levels,
			0,
			false,
			base_cost
		)

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		var choice_id := str(choice.get("id", ""))
		if choice_id.is_empty():
			return false
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {"runtime_skill_levels": runtime_skill_levels.duplicate(true)}

	func apply_unlock_save_snapshot(
		snapshot: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		var value: Variant = snapshot.get("runtime_skill_levels", {})
		if not (value is Dictionary):
			return {"restored": false}
		runtime_skill_levels = (value as Dictionary).duplicate(true)
		return {"restored": true}

	func begin_tower_reward_fusion_modal(_choice: Dictionary, _registry: Object) -> bool:
		fusion_active = true
		return true

	func is_perk_fusion_modal_active() -> bool:
		return fusion_active

	func begin_tower_reward_unlock_swap(
		choice: Dictionary,
		_owner: Object,
		_registry: Object
	) -> bool:
		pending_unlock_choice = choice.duplicate(true)
		pending_unlock_swap = true
		return true

	func has_pending_unlock_swap() -> bool:
		return pending_unlock_swap

	func confirm_pending_unlock_swap() -> void:
		var choice_id := str(pending_unlock_choice.get("id", ""))
		if not choice_id.is_empty():
			runtime_skill_levels[choice_id] = 1
		pending_unlock_swap = false

	func end_tower_reward_external_modal(_owner: Object) -> void:
		pending_unlock_choice.clear()

	func cancel_pending_unlock_swap(_owner: Object = null) -> bool:
		var was_pending := pending_unlock_swap
		pending_unlock_swap = false
		pending_unlock_choice.clear()
		return was_pending


class FakeCatalog:
	extends RefCounted

	var slot_status_calls := 0
	var choices_override_enabled := false
	var choices_override: Array = []

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		if choices_override_enabled:
			return choices_override.duplicate(true)
		var candidates := [
			{"id": "common_expansion", "name": "Retired Expansion", "max_level": 5},
			{"id": "mugong_a", "name": "Mugong A", "max_level": 5},
			{"id": "mugong_b", "name": "Mugong B", "max_level": 5},
			{"id": "mugong_c", "name": "Mugong C", "max_level": 5},
			{"id": "mugong_d", "name": "Mugong D", "max_level": 5},
			{"id": "mugong_e", "name": "Mugong E", "max_level": 5},
			{"id": "mugong_f", "name": "Mugong F", "max_level": 5},
		]
		return candidates.slice(0, mini(candidates.size(), maxi(0, _base_choice_count)))

	func has_open_perk_slot(_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_data(perk_id: String) -> Dictionary:
		return {
			"id": perk_id,
			"name": "Peerless %s" % perk_id,
			"max_level": 1,
		}

	func get_all_perk_data() -> Dictionary:
		var result := {
			"unlock_ghost_shot": {
				"name": "Ghost Shot Manual",
				"max_level": 1,
				"rarity": "rare",
				"character_restriction": "smasher",
				"unlocks_skill": "ghost_shot",
			},
		}
		var candidates: Array = (
			choices_override.duplicate(true)
			if choices_override_enabled
			else [
				{"id": "common_expansion", "name": "Retired Expansion", "max_level": 5},
				{"id": "mugong_a", "name": "Mugong A", "max_level": 5},
				{"id": "mugong_b", "name": "Mugong B", "max_level": 5},
				{"id": "mugong_c", "name": "Mugong C", "max_level": 5},
				{"id": "mugong_d", "name": "Mugong D", "max_level": 5},
				{"id": "mugong_e", "name": "Mugong E", "max_level": 5},
				{"id": "mugong_f", "name": "Mugong F", "max_level": 5},
			]
		)
		for choice_value: Variant in candidates:
			if not (choice_value is Dictionary):
				continue
			var choice := (choice_value as Dictionary).duplicate(true)
			var choice_id := str(choice.get("id", ""))
			if choice_id.is_empty():
				continue
			choice.erase("id")
			result[choice_id] = choice
		return result

	func get_perk_slot_status(runtime_levels: Dictionary, _slot_context: Object = null) -> Dictionary:
		slot_status_calls += 1
		return {
			"count": runtime_levels.size(),
			"limit": 6,
			"is_full": runtime_levels.size() >= 6,
		}


class CharacterAwareFakeCatalog:
	extends RefCounted

	func get_choices(
		character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		if character_type == "viper":
			return [{
				"id": "kick_enhance",
				"name": "천각심법",
				"max_level": 3,
				"character_restriction": "viper",
			}]
		return [{
			"id": "dash_spirit",
			"name": "잔영호법",
			"max_level": 3,
			"character_restriction": "smasher",
		}]


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeCardRenderer:
	extends RefCounted

	var prewarm_calls := 0
	var draw_calls := 0
	var last_catalog: Object = null
	var last_snapshot: Dictionary = {}
	var last_mouse_pos := Vector2.ZERO
	var last_view_size := Vector2.ZERO

	func prewarm_traditional_choice_assets() -> void:
		prewarm_calls += 1

	func draw_tower_reward_pick(
		_canvas: CanvasItem,
		_view_model: Dictionary,
		_runtime_state: Object,
		catalog: Object,
		_icon_renderer: Object,
		view_size: Vector2,
		snapshot: Dictionary,
		mouse_pos: Vector2
	) -> void:
		draw_calls += 1
		last_catalog = catalog
		last_snapshot = snapshot.duplicate(true)
		last_mouse_pos = mouse_pos
		last_view_size = view_size


class FakeIconRenderer:
	extends RefCounted

	var prewarm_calls := 0

	func prewarm_assets() -> void:
		prewarm_calls += 1


class FakeFlowOwner:
	extends RefCounted

	var context := {
		"node_resolution_id": "reward-state-node",
		"boss_slot_id": "floor_01_dalji",
	}
	var balances := {"muhon": 10, "gold": 0, "chance_gems": 3}
	var resolution_ids: Dictionary = {}
	var burned_boss_ids: Array[String] = []
	var finalize_calls := 0
	var prepare_calls := 0
	var margin_reward_calls := 0
	var begin_calls := 0
	var active := false
	var phase := "COMBAT"
	var finalize_result := {"accepted": true}

	func prepare_vertical_slice_combat(
		_owner: Object,
		_context: Dictionary = {}
	) -> bool:
		prepare_calls += 1
		return true

	func begin_vertical_slice(
		_owner: Object,
		_finish_callback: Callable,
		_context: Dictionary = {}
	) -> bool:
		begin_calls += 1
		active = true
		phase = "ROUTE_AIM"
		return true

	func apply_victory_margin_reward(player_score: int, boss_score: int) -> Dictionary:
		margin_reward_calls += 1
		var resolution_id := "victory_margin_muhon"
		var amount := maxi(0, player_score - boss_score)
		if resolution_ids.has(resolution_id):
			return {
				"accepted": true,
				"applied": false,
				"reason": "already_committed",
				"amount": amount,
			}
		resolution_ids[resolution_id] = true
		balances["muhon"] = int(balances.get("muhon", 0)) + amount
		context["victory_margin_reward"] = {
			"node_resolution_id": resolution_id,
			"player_score": player_score,
			"boss_score": boss_score,
			"amount": amount,
		}
		return {
			"accepted": true,
			"applied": true,
			"reason": "committed",
			"amount": amount,
		}

	func is_active() -> bool:
		return active

	func get_phase_name() -> String:
		return phase

	func get_reward_pick_context() -> Dictionary:
		return context.duplicate(true)

	func get_run_state_snapshot() -> Dictionary:
		return balances.duplicate(true)

	func apply_reward_pick_purchase(
		slot_index: int,
		_choice: Dictionary,
		cost: int,
		effect_callback: Callable,
		rollback_callback: Callable = Callable(),
		offer_generation: int = 0
	) -> Dictionary:
		var resolution_id := "generation_%d:slot_%d" % [
			maxi(0, offer_generation),
			slot_index,
		]
		if resolution_ids.has(resolution_id):
			return {"accepted": true, "applied": false, "reason": "already_committed"}
		if int(balances.get("muhon", 0)) < cost:
			return {"accepted": false, "applied": false, "reason": "insufficient_muhon"}
		if not bool(effect_callback.call()):
			if rollback_callback.is_valid():
				rollback_callback.call()
			return {"accepted": false, "applied": false, "reason": "effect_rejected"}
		balances["muhon"] = int(balances.get("muhon", 0)) - cost
		resolution_ids[resolution_id] = true
		return {"accepted": true, "applied": true, "reason": "applied"}

	func mark_reward_pick_vision_burned(boss_slot_id: String) -> Dictionary:
		if not boss_slot_id.is_empty() and not burned_boss_ids.has(boss_slot_id):
			burned_boss_ids.append(boss_slot_id)
		return {"accepted": true}

	func finalize_reward_pick(vision_boss_slot_id: String) -> Dictionary:
		finalize_calls += 1
		if not vision_boss_slot_id.is_empty() and not burned_boss_ids.has(vision_boss_slot_id):
			burned_boss_ids.append(vision_boss_slot_id)
		return finalize_result.duplicate(true)


class FakeOfferBuilder:
	extends RefCounted

	var offer: Dictionary = {}

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {},
		_reroll_counter: int = 0
	) -> Dictionary:
		return offer.duplicate(true)


class FakeScoreboard:
	extends RefCounted

	func get_player_points() -> int:
		return 7

	func get_boss_points() -> int:
		return 3


class FakeFusionEffectiveLevelRuntime:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {"dash_amplification": 2}
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false

	func get_perk_fusion_effective_level_bonus(perk_id: String) -> int:
		return 1 if perk_id == "dash_amplification" else 0


class RewardHoverDrawProbe:
	extends Node2D

	var renderer: Object
	var view_model: Dictionary
	var catalog: Object
	var snapshot: Dictionary
	var mouse_pos: Vector2
	var view_size: Vector2

	func _draw() -> void:
		renderer.draw_tower_reward_pick(
			self,
			view_model,
			null,
			catalog,
			null,
			view_size,
			snapshot,
			mouse_pos
		)


class RewardHoverDrawCallSpy:
	extends RefCounted

	var draw_rect_calls: Array[Dictionary] = []

	func draw_rect(
		rect: Rect2,
		color: Color,
		filled: bool = true,
		width: float = -1.0,
		antialiased: bool = false
	) -> void:
		draw_rect_calls.append({
			"rect": rect,
			"color": color,
			"filled": filled,
			"width": width,
			"antialiased": antialiased,
		})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_seven_locale_copy_contract()
	_verify_reward_balance_row_budget()
	_verify_flag_on_training_candidates_exclude_retired_expansion()
	_verify_shell_owner_preserves_character_specific_training_candidate()
	_verify_offer_order_eligibility_and_prices()
	_verify_chosik_shared_price_and_three_muhon_gate()
	_verify_treasure_map_fusion_cost_offer_and_debit()
	_verify_vision_and_chosik_probability_contracts()
	_verify_vision_identity_fail_closed_and_legacy_parity()
	_verify_no_training_seed_sweep_and_saturated_fallback()
	_verify_stable_four_card_multi_buy_and_fusion_return()
	_verify_slot_limit_rechecks_each_purchase()
	_verify_fullscreen_stats_ledger_hover_and_cache_contract()
	_verify_reward_hover_highlight_contract()
	_verify_reward_hover_draw_output_contract()
	await _verify_reward_hover_draw_wiring_behavior()
	_verify_unaffordable_board_auto_finish_and_failure_latch()
	_verify_vision_purchase_and_continue_burn_semantics()
	_verify_full_slot_vision_swap_confirm_and_cancel()
	_verify_production_flow_transactions_and_burn_snapshot()
	_verify_victory_highlight_reward_pick_route_sequence()
	_verify_f9_debug_path_still_enters_reward_pick()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("tower_reward_pick_chosik_cost_seal: owner=shared display=4 debit=4 insufficient=3 rejected=1")
		print("tower_reward_pick_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_seven_locale_copy_contract() -> void:
	var required_locales := ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]
	for key_value in TowerRewardPickLocalization.TEXT.keys():
		var key := str(key_value)
		var entries: Dictionary = TowerRewardPickLocalization.TEXT.get(key, {})
		_expect(entries.size() == required_locales.size(), "reward-pick copy must have exactly seven locales: %s" % key)
		for locale in required_locales:
			var copy := str(entries.get(locale, ""))
			_expect(not copy.is_empty(), "reward-pick copy must include %s for %s" % [locale, key])
			_expect(copy.find("—") < 0, "reward-pick copy must not use an em dash: %s/%s" % [key, locale])
	_expect(
		TowerRewardPickLocalization.TEXT.balance.ko == "무혼 : {amount}개",
		"Korean reward balance must keep the icon-colon-count copy contract"
	)


func _verify_reward_balance_row_budget() -> void:
	var layout := RuntimePerkChoiceLayout.new().build_layout(
		LIVE_VIEW_SIZE,
		4,
		true,
		TowerRewardPickState.TEMP_REWARD_PICK_PANEL_GAP_PX
	)
	var renderer := RuntimePerkOverlayRenderer.new()
	var rows := renderer.build_tower_reward_balance_rows(
		LIVE_VIEW_SIZE,
		layout.get("title_pos", Vector2.ZERO),
		minf(float(layout.get("layout_scale", 1.0)), 1.0),
		"무혼 : 7개"
	)
	_expect(rows.size() == 1, "2020x1246 reward layout must append exactly one Muhon balance row")
	if rows.size() == 1:
		var row := rows[0] as Dictionary
		var rect: Rect2 = row.get("rect", Rect2())
		var icon_center: Vector2 = row.get("icon_center", Vector2.ZERO)
		var text_rect: Rect2 = row.get("text_rect", Rect2())
		_expect(Rect2(Vector2.ZERO, LIVE_VIEW_SIZE).encloses(rect), "reward balance row must remain inside the live viewport")
		_expect(rect.has_point(icon_center), "reward balance icon must be derived inside the appended row")
		_expect(text_rect.position.x > icon_center.x, "reward balance copy must follow the Muhon icon")
		_expect(int(row.get("font_size", 0)) == int(RuntimePerkOverlayRenderer.TOWER_REWARD_BALANCE_FONT_SIZE), "live reward balance must use the enlarged base font")
	var undersized_rows := renderer.build_tower_reward_balance_rows(
		Vector2(220.0, 80.0),
		Vector2(110.0, 40.0),
		0.58,
		"무혼 : 1234567개"
	)
	_expect(undersized_rows.size() == 0, "undersized reward layout must append zero clipped balance rows")


func _verify_flag_on_training_candidates_exclude_retired_expansion() -> void:
	var runtime := FakeRuntimeState.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), null)
	var offer: Dictionary = TowerAscentTrainingOfferBuilder.new().build_offer(
		"retired-expansion-filter",
		77,
		FakeOwner.new(),
		registry,
		TowerAscentTrainingOfferBuilder.OFFER_KIND_MIXED_REWARD
	)
	_expect(bool(offer.get("accepted", false)), "flag-ON mixed reward source offer must remain available")
	_expect(
		str(offer.get("offer_version", ""))
		== TowerAscentTrainingOfferBuilder.MIXED_REWARD_OFFER_VERSION,
		"Z17 training-card migration must preserve the Z16 mixed-reward v2 contract"
	)
	var mugong_choices: Array = offer.get("mugong_choices", [])
	_expect(
		mugong_choices.size() == 5,
		"mixed reward source must request six rows and retain five eligible Mugong choices"
	)
	for choice_value in mugong_choices:
		if choice_value is Dictionary:
			_expect(
				str((choice_value as Dictionary).get("id", "")) != "common_expansion",
				"retired common_expansion leaked into a tower reward candidate"
			)


func _verify_shell_owner_preserves_character_specific_training_candidate() -> void:
	var registry := _build_registry(FakeRuntimeState.new(), FakeSkillConfig.new(), null)
	registry.instances["runtime_perk_catalog"] = CharacterAwareFakeCatalog.new()
	var offer: Dictionary = TowerAscentTrainingOfferBuilder.new().build_offer(
		"shell-owner-character-candidate",
		77,
		ShellLikeOwner.new({"selected_character_type": "viper"}),
		registry,
		TowerAscentTrainingOfferBuilder.OFFER_KIND_MIXED_REWARD
	)
	var has_viper_perk := false
	var has_smasher_perk := false
	for choice_value in offer.get("mugong_choices", []):
		if choice_value is Dictionary:
			var choice_id := str((choice_value as Dictionary).get("id", ""))
			has_viper_perk = has_viper_perk or choice_id == "kick_enhance"
			has_smasher_perk = has_smasher_perk or choice_id == "dash_spirit"
	var passed := (
		bool(offer.get("accepted", false))
		and has_viper_perk
		and not has_smasher_perk
	)
	_expect(
		passed,
		"shell _get owner must return the Viper-specific training candidate instead of the Smasher fallback"
	)
	if passed:
		print("tower_reward_pick_smoke: shell_owner_character=viper returned_perk=kick_enhance")


func _verify_offer_order_eligibility_and_prices() -> void:
	_expect(TowerRewardPickOfferBuilder.OFFER_VERSION == "tower_reward_pick_v3", "reward offer version must advance after RNG consumption changes")
	_expect(TowerRewardPickOfferBuilder.TEMP_MUGONG_COST == 2, "Mugong reward card must cost two Muhon")
	_expect(TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST == 4, "Chosik reward card must cost four Muhon from the shared owner")
	_expect(TowerRewardPickOfferBuilder.TEMP_DASH_AMPLIFICATION_COST == 3, "Glide Orb reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_FUSION_COST == 3, "fusion reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_VISION_COST == 3, "Vision reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_SUPREME_COST == 5, "Peerless reward card must cost five Muhon")
	_expect(is_equal_approx(TowerRewardPickOfferBuilder.TEMP_VISION_DROP_CHANCE, 0.20), "Vision reward chance must remain 20 percent")
	_expect(is_equal_approx(TowerRewardPickOfferBuilder.TEMP_REWARD_CHOSIK_CHANCE, 0.25), "provisional Chosik reward chance must remain 25 percent")
	_expect(
		TowerRewardPickOfferBuilder.resolve_basic_reward_pick_cost({
			"id": "dash_amplification",
			"reward_pick_kind": "mugong",
		}) == 3,
		"Glide Orb must use its temporary three-Muhon reward-pick exception"
	)
	_expect(
		TowerRewardPickOfferBuilder.resolve_basic_reward_pick_cost({
			"id": "mugong_a",
			"reward_pick_kind": "mugong",
		}) == 2,
		"other Mugong cards must retain the two-Muhon price"
	)

	var runtime := FakeRuntimeState.new()
	var skill_config := FakeSkillConfig.new()
	var registry := _build_registry(runtime, skill_config, null)
	var builder := TowerRewardPickOfferBuilder.new()
	var context := {
		"node_resolution_id": "offer-order",
		"boss_slot_id": "floor_01_dalji",
		"floor": 1,
		"map_seed": 77,
		"skipped_boss_ids": [],
		"burned_vision_boss_ids": [],
	}
	var offer: Dictionary = builder.build_offer(
		context,
		FakeOwner.new(),
		registry,
		{"vision": 0.19, "supreme": 0.0, "chosik": 1.0}
	)
	_expect(bool(offer.get("accepted", false)), "eligible reward pick must generate")
	var choices: Array = offer.get("choices", [])
	_expect(choices.size() == 4, "reward pick must materialize exactly four cards")
	_expect(str((choices[0] as Dictionary).get("reward_pick_kind", "")) == "vision", "eligible Vision must reserve slot one")
	_expect(str((choices[1] as Dictionary).get("reward_pick_kind", "")) == "supreme", "forced Peerless roll must use the remaining probability lane")
	_expect(bool(offer.get("vision_roll_performed", false)), "eligible Vision must perform exactly one screen-level roll")
	_expect(is_equal_approx(float(offer.get("vision_roll", -1.0)), 0.19), "Vision boundary fixture must expose its deterministic override")
	_expect(_unique_choice_count(choices) == 4, "one reward pick must not duplicate card ids")
	_expect(_count_kind(choices, "active") == 0, "active items must never enter the reward-card pool")
	var repeated: Dictionary = builder.build_offer(
		context,
		FakeOwner.new(),
		registry,
		{"vision": 0.19, "supreme": 0.0, "chosik": 1.0}
	)
	_expect(var_to_bytes(repeated.get("choices", [])) == var_to_bytes(choices), "the same entry context must reuse deterministic four-card content")

	var skipped_context := context.duplicate(true)
	skipped_context["node_resolution_id"] = "offer-skipped"
	skipped_context["skipped_boss_ids"] = ["floor_01_dalji"]
	var skipped: Dictionary = builder.build_offer(skipped_context, FakeOwner.new(), registry, {"supreme": 1.0})
	_expect(_count_kind(skipped.get("choices", []), "vision") == 0, "skipped boss Vision must never appear")
	var burned_context := context.duplicate(true)
	burned_context["node_resolution_id"] = "offer-burned"
	burned_context["burned_vision_boss_ids"] = ["floor_01_dalji"]
	var burned: Dictionary = builder.build_offer(burned_context, FakeOwner.new(), registry, {"supreme": 1.0})
	_expect(_count_kind(burned.get("choices", []), "vision") == 0, "burned boss Vision must never reappear")
	runtime.runtime_skill_levels[TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_dalji")] = 1
	var owned_context := context.duplicate(true)
	owned_context["node_resolution_id"] = "offer-owned"
	var owned: Dictionary = builder.build_offer(owned_context, FakeOwner.new(), registry, {"supreme": 1.0})
	_expect(_count_kind(owned.get("choices", []), "vision") == 0, "owned boss Vision must never reappear")
	runtime.runtime_skill_levels.clear()
	skill_config.full = true
	var full_context := context.duplicate(true)
	full_context["node_resolution_id"] = "offer-full"
	var full_offer: Dictionary = builder.build_offer(
		full_context,
		FakeOwner.new(),
		registry,
		{"vision": 0.19, "supreme": 1.0, "chosik": 0.0}
	)
	var full_choice: Dictionary = (full_offer.get("choices", []) as Array)[0]
	_expect(bool(full_choice.get("vision_swap_required", false)), "full Chosik slots must keep Vision eligible through a swap route")
	_expect(not (full_choice.get("vision_swap_candidates", []) as Array).is_empty(), "full-slot Vision card must carry explicit swap candidates")
	_expect(_count_kind(full_offer.get("choices", []), "chosik") == 0, "full Chosik orbs must fail closed until reward-pick owns a replacement flow")


func _verify_chosik_shared_price_and_three_muhon_gate() -> void:
	var expected_cost := TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 3
	var registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
	registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var builder := FakeOfferBuilder.new()
	builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"offer_generation": 0,
		"vision_unlock_id": "",
		"choices": [
			_card("chosik", "unlock_ghost_shot", expected_cost),
			_card("training", "chosik_cost_filler_1", 99),
			_card("mugong", "chosik_cost_filler_2", 99),
			_card("supreme", "chosik_cost_filler_3", 99),
		],
	}
	var state := TowerRewardPickState.new()
	state.set("_offer_builder", builder)
	_expect(
		state.start(FakeOwner.new(), registry, Callable()),
		"three-Muhon Chosik price fixture must enter the real reward-pick state"
	)
	var model_choices: Array = state.build_view_model().get("choices", [])
	var card: Dictionary = model_choices[0] if not model_choices.is_empty() else {}
	_expect(
		int(card.get("reward_pick_cost", -1)) == expected_cost
		and str(card.get("reward_pick_price_text", ""))
		== TowerRewardPickLocalization.text("price", {"amount": expected_cost}),
		"live reward-pick Chosik must display the shared four-Muhon price"
	)
	_expect(
		not bool(card.get("reward_pick_enabled", true))
		and str(card.get("reward_pick_disabled_reason", "")) == "insufficient_muhon",
		"three Muhon must disable the live four-Muhon Chosik card"
	)
	state.call("_purchase", 0)
	_expect(
		int(flow.balances.get("muhon", -1)) == 3
		and runtime.apply_calls == 0
		and not state.spent_flags.is_empty()
		and not state.spent_flags[0],
		"direct purchase input at three Muhon must not grant, debit, or spend the card"
	)
	state.reset()


func _verify_treasure_map_fusion_cost_offer_and_debit() -> void:
	const PERK_ID := "downtown_treasure_map"
	var expected_costs := [3, 2, 0, 0]
	for level in range(expected_costs.size()):
		var expected_cost := int(expected_costs[level])
		var runtime := FakeRuntimeState.new()
		if level > 0:
			runtime.runtime_skill_levels[PERK_ID] = level
		var catalog := FakeCatalog.new()
		catalog.choices_override_enabled = true
		catalog.choices_override = []
		var registry := _build_registry(runtime, FakeSkillConfig.new(), null)
		registry.instances["runtime_perk_catalog"] = catalog
		var offer: Dictionary = TowerRewardPickOfferBuilder.new().build_offer(
			{
				"node_resolution_id": "treasure-map-fusion-cost-%d" % level,
				"boss_slot_id": "floor_01_dalji",
				"floor": 1,
				"map_seed": 7100 + level,
				"skipped_boss_ids": ["floor_01_dalji"],
				"burned_vision_boss_ids": [],
			},
			FakeOwner.new(),
			registry,
			{"supreme": 1.0, "chosik": 1.0}
		)
		var choices: Array = offer.get("choices", [])
		_expect(bool(offer.get("accepted", false)), "Treasure Map Lv.%d fusion-only production offer must generate" % level)
		var fusion_indices: Array[int] = []
		for choice_index in range(choices.size()):
			var candidate: Dictionary = choices[choice_index]
			if str(candidate.get("reward_pick_kind", "")) == "fusion":
				fusion_indices.append(choice_index)
		_expect(fusion_indices.size() == 1, "Treasure Map Lv.%d fixture must expose exactly one fusion card" % level)
		if fusion_indices.size() != 1:
			continue
		var fusion_index := fusion_indices[0]
		var fusion_card: Dictionary = choices[fusion_index]
		_expect(int(fusion_card.get("reward_pick_cost", -1)) == TowerRewardPickOfferBuilder.TEMP_FUSION_COST, "Treasure Map Lv.%d production offer must retain the base fusion cost" % level)
		_expect(
			str(fusion_card.get("reward_pick_price_text", ""))
				== TowerRewardPickLocalization.text("price", {"amount": TowerRewardPickOfferBuilder.TEMP_FUSION_COST}),
			"Treasure Map Lv.%d materialized offer must retain the base price text" % level
		)
		_expect(runtime.fusion_cost_query_calls == 0, "Treasure Map Lv.%d offer generation must not freeze the live discount" % level)

		var flow := FakeFlowOwner.new()
		flow.balances["muhon"] = expected_cost
		var state_registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
		state_registry.instances["runtime_perk_catalog"] = catalog
		state_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
		state_registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
		var offer_builder := FakeOfferBuilder.new()
		offer_builder.offer = offer
		var state := TowerRewardPickState.new()
		state.set("_offer_builder", offer_builder)
		_expect(state.start(FakeOwner.new(), state_registry, Callable(self, "_on_finish")), "Treasure Map Lv.%d offer must enter the production reward state" % level)
		var view_choices: Array = state.build_view_model().get("choices", [])
		var live_card: Dictionary = view_choices[fusion_index] if fusion_index < view_choices.size() else {}
		_expect(int(live_card.get("reward_pick_cost", -1)) == expected_cost, "Treasure Map Lv.%d live view cost must be %d" % [level, expected_cost])
		_expect(str(live_card.get("reward_pick_price_text", "")) == TowerRewardPickLocalization.text("price", {"amount": expected_cost}), "Treasure Map Lv.%d live price text must show %d" % [level, expected_cost])
		_expect(bool(live_card.get("reward_pick_enabled", false)), "Treasure Map Lv.%d fusion card must be enabled at its exact live balance" % level)
		var queries_after_view := runtime.fusion_cost_query_calls
		_expect(queries_after_view >= 2, "Treasure Map Lv.%d display and affordability must query the live cost" % level)
		state.call("_purchase", fusion_index)
		_expect(int(flow.balances.get("muhon", -1)) == 0, "Treasure Map Lv.%d reward state must debit exactly %d" % [level, expected_cost])
		_expect(state.is_external_modal_active(), "Treasure Map Lv.%d purchase, including free, must open the Fusion modal" % level)
		_expect(runtime.fusion_cost_query_calls > queries_after_view, "Treasure Map Lv.%d purchase must requery immediately before debit" % level)
		print("tower_reward_pick_smoke: treasure_map_fusion_cost level=%d cost=%d debit=%d query_calls=%d" % [
			level,
			expected_cost,
			expected_cost - int(flow.balances.get("muhon", -1)),
			runtime.fusion_cost_query_calls,
		])

	# A reward screen can stay open across multiple buys. Acquiring Treasure Map
	# first must immediately make the still-unspent Fusion card cheaper.
	var changing_runtime := FakeRuntimeState.new()
	var changing_flow := FakeFlowOwner.new()
	changing_flow.balances["muhon"] = 2
	var changing_registry := _build_registry(changing_runtime, FakeSkillConfig.new(), changing_flow)
	changing_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	changing_registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
	var changing_builder := FakeOfferBuilder.new()
	changing_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [_card("fusion", "fusion_live_cost", 3)],
	}
	var changing_state := TowerRewardPickState.new()
	changing_state.set("_offer_builder", changing_builder)
	_expect(changing_state.start(FakeOwner.new(), changing_registry, Callable()), "same-screen Treasure Map cost fixture must start")
	var before_card: Dictionary = (changing_state.build_view_model().get("choices", []) as Array)[0]
	_expect(int(before_card.get("reward_pick_cost", -1)) == 3 and not bool(before_card.get("reward_pick_enabled", true)), "unowned Treasure Map must leave the base-3 Fusion card unaffordable at 2 Muhon")
	changing_runtime.runtime_skill_levels[PERK_ID] = 1
	var after_card: Dictionary = (changing_state.build_view_model().get("choices", []) as Array)[0]
	_expect(int(after_card.get("reward_pick_cost", -1)) == 2 and bool(after_card.get("reward_pick_enabled", false)), "buying Treasure Map on the same screen must refresh Fusion to cost 2")
	changing_state.call("_purchase", 0)
	_expect(int(changing_flow.balances.get("muhon", -1)) == 0, "same-screen refreshed Fusion must debit exactly 2 Muhon")


func _verify_vision_and_chosik_probability_contracts() -> void:
	var runtime := FakeRuntimeState.new()
	var skill_config := FakeSkillConfig.new()
	var registry := _build_registry(runtime, skill_config, null)
	var builder := TowerRewardPickOfferBuilder.new()
	var vision_context := {
		"node_resolution_id": "vision-boundary",
		"boss_slot_id": "floor_01_dalji",
		"floor": 1,
		"map_seed": 812,
		"skipped_boss_ids": [],
		"burned_vision_boss_ids": [],
	}
	var vision_hit: Dictionary = builder.build_offer(
		vision_context,
		FakeOwner.new(),
		registry,
		{"vision": 0.19, "supreme": 1.0, "chosik": 1.0}
	)
	var vision_miss: Dictionary = builder.build_offer(
		vision_context,
		FakeOwner.new(),
		registry,
		{"vision": 0.21, "supreme": 1.0, "chosik": 1.0}
	)
	_expect(_count_kind(vision_hit.get("choices", []), "vision") == 1, "Vision roll 0.19 must pass the 20 percent boundary")
	_expect(_count_kind(vision_miss.get("choices", []), "vision") == 0, "Vision roll 0.21 must miss the 20 percent boundary")
	_expect(str(vision_miss.get("vision_unlock_id", "")).is_empty(), "a missed Vision roll must not be recorded as an offered or burned Vision")

	var deterministic_a: Dictionary = builder.build_offer(vision_context, FakeOwner.new(), registry)
	var deterministic_b: Dictionary = builder.build_offer(vision_context, FakeOwner.new(), registry)
	_expect(
		var_to_bytes(deterministic_a.get("choices", []))
			== var_to_bytes(deterministic_b.get("choices", [])),
		"same resolution and boss ids must not reroll reward content"
	)
	_expect(
		is_equal_approx(
			float(deterministic_a.get("vision_roll", -1.0)),
			float(deterministic_b.get("vision_roll", -2.0))
		),
		"same resolution and boss ids must reuse the Vision roll"
	)

	var chosik_context := vision_context.duplicate(true)
	chosik_context["node_resolution_id"] = "chosik-boundary"
	chosik_context["skipped_boss_ids"] = ["floor_01_dalji"]
	var chosik_hit: Dictionary = builder.build_offer(
		chosik_context,
		FakeOwner.new(),
		registry,
		{"supreme": 1.0, "chosik": 0.249999}
	)
	var chosik_miss: Dictionary = builder.build_offer(
		chosik_context,
		FakeOwner.new(),
		registry,
		{"supreme": 1.0, "chosik": 0.25}
	)
	var chosik_choices: Array = chosik_hit.get("choices", [])
	_expect(_count_kind(chosik_choices, "chosik") == 1, "Chosik roll below 0.25 must reserve exactly one reward card")
	_expect(_count_kind(chosik_choices, "mugong") > 0, "a Chosik reward must preserve at least one Mugong card")
	_expect(_count_kind(chosik_miss.get("choices", []), "chosik") == 0, "Chosik roll exactly 0.25 must miss the strict boundary")
	for choice_value: Variant in chosik_choices:
		if (
			choice_value is Dictionary
			and str((choice_value as Dictionary).get("reward_pick_kind", "")) == "chosik"
		):
			var chosik_choice := choice_value as Dictionary
			_expect(
				int(chosik_choice.get("reward_pick_cost", -1))
					== TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
				"Chosik reward cards must use the shared four-Muhon unlock price"
			)
			_expect(
				str(chosik_choice.get("reward_pick_price_text", ""))
				== TowerRewardPickLocalization.text(
					"price",
					{"amount": TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST}
				),
				"generated Chosik cards must display the shared four-Muhon price"
			)

	const SAMPLE_COUNT := 1024
	var old_compositions: Dictionary = {}
	var new_compositions: Dictionary = {}
	var new_vision_count := 0
	var new_chosik_count := 0
	for seed in range(SAMPLE_COUNT):
		var sample_context := vision_context.duplicate(true)
		sample_context["node_resolution_id"] = "reward-distribution-%04d" % seed
		sample_context["map_seed"] = seed
		var old_offer: Dictionary = builder.build_offer(
			sample_context,
			FakeOwner.new(),
			registry,
			{"vision": 0.0, "chosik": 1.0}
		)
		var new_offer: Dictionary = builder.build_offer(
			sample_context,
			FakeOwner.new(),
			registry
		)
		_increment_composition(old_compositions, old_offer.get("choices", []))
		_increment_composition(new_compositions, new_offer.get("choices", []))
		new_vision_count += _count_kind(new_offer.get("choices", []), "vision")
		new_chosik_count += _count_kind(new_offer.get("choices", []), "chosik")
	var vision_rate := float(new_vision_count) / float(SAMPLE_COUNT)
	var chosik_rate := float(new_chosik_count) / float(SAMPLE_COUNT)
	_expect(vision_rate >= 0.16 and vision_rate <= 0.24, "multi-seed Vision rate must converge around 20 percent, got %.4f" % vision_rate)
	_expect(chosik_rate >= 0.20 and chosik_rate <= 0.30, "multi-seed Chosik rate must converge around 25 percent, got %.4f" % chosik_rate)
	print(
		"tower_reward_pick_distribution: samples=%d old=%s new=%s vision_rate=%.4f chosik_rate=%.4f"
		% [SAMPLE_COUNT, old_compositions, new_compositions, vision_rate, chosik_rate]
	)


func _verify_vision_identity_fail_closed_and_legacy_parity() -> void:
	var runtime := FakeRuntimeState.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), null)
	var builder := TowerRewardPickOfferBuilder.new()
	var boss_registry := TowerAscentBossRegistry.new()
	var cases := [
		{"variant": "dalji", "slot_id": "floor_01_dalji"},
		{"variant": "gaksi", "slot_id": "floor_01_gaksital"},
		{"variant": "podo", "slot_id": "floor_01_podo"},
	]
	for case in cases:
		var owner := FakeOwner.new()
		owner.stage1_boss_variant = str(case.get("variant", ""))
		var slot_id := str(case.get("slot_id", ""))
		var choice: Dictionary = builder.call(
			"_build_vision_choice",
			slot_id,
			{},
			owner,
			registry,
			{}
		)
		var tower_vision_id := str(choice.get("id", ""))
		var legacy := VictoryLootPhaseState.new()
		legacy.set("_current_stage", 1)
		var legacy_vision_id := str(legacy.call("_get_boss_vision_offer_id", owner))
		var chest_vision_id := str(
			TowerAscentChestContextBuilder.new().call(
				"_get_boss_vision_offer_id",
				owner,
				1
			)
		)
		_expect(
			tower_vision_id == legacy_vision_id and tower_vision_id == chest_vision_id,
			"Tower reward, legacy victory, and chest copies must agree for Stage 1 %s"
			% str(case.get("variant", ""))
		)
	var shell_cases := [
		{"stage": 1, "variant": "dalji", "slot_id": "floor_01_dalji"},
		{"stage": 1, "variant": "gaksi", "slot_id": "floor_01_gaksital"},
		{"stage": 2, "variant": "cheongringwi", "slot_id": "floor_02_cheongringwi"},
		{"stage": 3, "variant": "yeonmyo", "slot_id": "floor_03_yeonmyo"},
	]
	for case in shell_cases:
		var stage := int(case.get("stage", 0))
		var variant_property := "stage1_boss_variant" if stage == 1 else "stage_boss_variant"
		var shell_values := {"current_stage": stage}
		shell_values[variant_property] = str(case.get("variant", ""))
		var shell_owner := ShellLikeOwner.new(shell_values)
		var slot_id := str(case.get("slot_id", ""))
		var shell_choice: Dictionary = builder.call(
			"_build_vision_choice",
			slot_id,
			{},
			shell_owner,
			registry,
			{}
		)
		_expect(
			str(shell_choice.get("id", ""))
				== TowerAscentBossRewardCatalog.get_vision_unlock_id(slot_id),
			"shell _get owner must retain the %s Tower Vision choice" % slot_id
		)
	var legacy_stage_cases := [
		{"stage": 2, "variant": "dalji", "expected_slot": "floor_02_cheongringwi"},
		{"stage": 2, "variant": "molewang", "expected_slot": "floor_02_cheongringwi"},
		{"stage": 2, "variant": "arachne", "expected_slot": "floor_02_cheongringwi"},
		{"stage": 3, "variant": "dalji", "expected_slot": "floor_03_yeonmyo"},
		{"stage": 3, "variant": "teddy_bear", "expected_slot": "floor_03_yeonmyo"},
		{"stage": 3, "variant": "alice", "expected_slot": "floor_03_yeonmyo"},
	]
	for case in legacy_stage_cases:
		var stage := int(case.get("stage", 0))
		var owner := ShellLikeOwner.new({
			"current_stage": stage,
			"stage_boss_variant": str(case.get("variant", "")),
		})
		var expected_id := TowerAscentBossRewardCatalog.get_vision_unlock_id(
			str(case.get("expected_slot", ""))
		)
		var legacy := VictoryLootPhaseState.new()
		legacy.set("_current_stage", stage)
		_expect(
			str(legacy.call("_get_boss_vision_offer_id", owner)) == expected_id
			and str(TowerAscentChestContextBuilder.new().call(
				"_get_boss_vision_offer_id",
				owner,
				stage
			)) == expected_id,
			"legacy Stage %d Vision coverage must ignore stale/variant owner value %s"
			% [stage, str(case.get("variant", ""))]
		)
	var mismatched_owner := FakeOwner.new()
	mismatched_owner.stage1_boss_variant = "gaksi"
	var owner_slot_id := TowerAscentBossRewardCatalog.get_boss_slot_id_for_stage_variant(
		1,
		mismatched_owner.stage1_boss_variant
	)
	var owner_key := boss_registry.canonical_encounter_key(
		boss_registry.resolve_battle_encounter(owner_slot_id)
	)
	var node_key := boss_registry.canonical_encounter_key(
		boss_registry.resolve_battle_encounter("floor_01_dalji")
	)
	_expect(
		not owner_key.is_empty() and owner_key != node_key,
		"vision mismatch fixture must carry different canonical encounter keys"
	)
	var blocked_choice: Dictionary = builder.call(
		"_build_vision_choice",
		"floor_01_dalji",
		{},
		mismatched_owner,
		registry,
		{}
	)
	_expect(
		blocked_choice.is_empty(),
		"Vision lane must fail closed when the node slot and live encounter identities differ"
	)


func _verify_no_training_seed_sweep_and_saturated_fallback() -> void:
	var runtime := FakeRuntimeState.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), null)
	registry.instances["runtime_perk_catalog"] = RuntimePerkCatalog.new()
	var builder := TowerRewardPickOfferBuilder.new()
	var migrated_ids: Array[String] = []
	var migrated_hit_counts: Dictionary = {}
	for perk_id_value: Variant in RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.keys():
		var perk_id := str(perk_id_value)
		migrated_ids.append(perk_id)
		migrated_hit_counts[perk_id] = 0
	migrated_ids.sort()
	_expect(migrated_ids.size() == 10, "reward seed sweep must cover all ten migrated IDs")
	var four_card_count := 0
	var failure_count := 0
	var total_cost := 0
	var total_cards := 0
	var training_card_count := 0
	for seed in range(128):
		var context := {
			"node_resolution_id": "no-training-seed-%03d" % seed,
			"boss_slot_id": "floor_01_dalji",
			"floor": 1 + seed % 12,
			"map_seed": seed,
			"skipped_boss_ids": ["floor_01_dalji"],
			"burned_vision_boss_ids": [],
		}
		var offer: Dictionary = builder.build_offer(
			context,
			FakeOwner.new(),
			registry
		)
		if not bool(offer.get("accepted", false)):
			failure_count += 1
			continue
		var choices: Array = offer.get("choices", [])
		if choices.size() == TowerRewardPickOfferBuilder.CARD_COUNT:
			four_card_count += 1
		training_card_count += _count_kind(choices, "training")
		_expect(
			_count_kind(choices, "mugong") > 0,
			"result reward seed %d must retain a Chosik/Mugong-family card" % seed
		)
		for choice_value in choices:
			if choice_value is Dictionary:
				var choice := choice_value as Dictionary
				var choice_id := str(choice.get("id", ""))
				if migrated_hit_counts.has(choice_id):
					migrated_hit_counts[choice_id] = int(migrated_hit_counts.get(choice_id, 0)) + 1
				total_cost += int(choice.get("reward_pick_cost", 0))
				total_cards += 1
	_expect(failure_count == 0, "128-seed reward sweep must have zero offer failures")
	_expect(four_card_count == 128, "128-seed reward sweep must fill all four cards")
	_expect(
		training_card_count == 0,
		"128-seed result rewards must collect zero training cards, got %d"
		% training_card_count
	)
	var migrated_total_hits := 0
	for perk_id in migrated_ids:
		var perk_hits := int(migrated_hit_counts.get(perk_id, 0))
		migrated_total_hits += perk_hits
		_expect(
			perk_hits == 0,
			"128-seed v3 rewards must offer migrated ID %s zero times, got %d"
			% [perk_id, perk_hits]
		)
	var average_cost := float(total_cost) / float(maxi(1, total_cards))
	print(
		"tower_reward_pick_no_training_seed_sweep: seeds=128 migrated_ids=%d four_card=%d failures=%d training=%d migrated_hits=%d average_cost=%.4f"
		% [
			migrated_ids.size(),
			four_card_count,
			failure_count,
			training_card_count,
			migrated_total_hits,
			average_cost,
		]
	)

	var refresh_runtime := FakeRuntimeState.new()
	var refresh_flow := FakeFlowOwner.new()
	refresh_flow.context = {
		"node_resolution_id": "training-migrated-refresh",
		"boss_slot_id": "floor_01_dalji",
		"floor": 7,
		"map_seed": 53053,
		"skipped_boss_ids": ["floor_01_dalji"],
		"burned_vision_boss_ids": [],
	}
	var refresh_registry := _build_registry(
		refresh_runtime,
		FakeSkillConfig.new(),
		refresh_flow
	)
	refresh_registry.instances["runtime_perk_catalog"] = RuntimePerkCatalog.new()
	refresh_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	refresh_registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
	var refresh_state := TowerRewardPickState.new()
	_expect(
		refresh_state.start(
			FakeOwner.new(),
			refresh_registry,
			Callable(),
			{"vision": 1.0, "supreme": 1.0, "refresh": 0.0, "chosik": 1.0}
		),
		"training-migrated refresh fixture must start through production state"
	)
	var refresh_index := -1
	for index in range(refresh_state.choices.size()):
		if str(refresh_state.choices[index].get("reward_pick_kind", "")) == "refresh":
			refresh_index = index
			break
	_expect(refresh_index >= 0, "production refresh fixture must expose a refresh card")
	if refresh_index >= 0:
		refresh_state.call("_purchase", refresh_index)
	var refreshed_migrated_hits := 0
	for choice in refresh_state.choices:
		if RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(str(choice.get("id", ""))):
			refreshed_migrated_hits += 1
	_expect(
		int(refresh_state.get("_reroll_counter")) == 1,
		"production refresh purchase must install generation one"
	)
	_expect(
		int(refresh_flow.balances.get("muhon", -1)) == 9,
		"production refresh purchase must commit its one-Muhon transaction"
	)
	_expect(
		refreshed_migrated_hits == 0,
		"production refresh reroll must keep all migrated IDs excluded, got %d"
		% refreshed_migrated_hits
	)
	print(
		"tower_reward_pick_training_migrated_refresh: generation=%d cards=%d migrated_hits=%d"
		% [
			int(refresh_state.get("_reroll_counter")),
			refresh_state.choices.size(),
			refreshed_migrated_hits,
		]
	)
	refresh_state.reset()

	var saturated_runtime := FakeRuntimeState.new()
	saturated_runtime.runtime_skill_levels = {
		"mugong_a": 5,
		"mugong_b": 5,
	}
	saturated_runtime.fusion_candidate_ids = ["mugong_a", "mugong_b"]
	var saturated_catalog := FakeCatalog.new()
	saturated_catalog.choices_override_enabled = true
	var saturated_flow := FakeFlowOwner.new()
	saturated_flow.context = {
		"node_resolution_id": "all-mugong-maxed",
		"boss_slot_id": "floor_01_dalji",
		"floor": 99,
		"map_seed": 9919,
		"skipped_boss_ids": ["floor_01_dalji"],
		"burned_vision_boss_ids": [],
	}
	var saturated_registry := _build_registry(
		saturated_runtime,
		FakeSkillConfig.new(),
		saturated_flow
	)
	saturated_registry.instances["runtime_perk_catalog"] = saturated_catalog
	saturated_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var saturated_offer: Dictionary = builder.build_offer(
		saturated_flow.context,
		FakeOwner.new(),
		saturated_registry,
		{"supreme": 1.0}
	)
	var saturated_choices: Array = saturated_offer.get("choices", [])
	_expect(bool(saturated_offer.get("accepted", false)), "all-maxed Mugong fallback must remain accepted")
	_expect(saturated_choices.size() == 2, "all-maxed Mugong fallback must keep fusion plus reward-only bag expansion")
	_expect(_count_kind(saturated_choices, "fusion") == 1, "all-maxed Mugong fallback must preserve the existing fusion route")
	_expect(_count_kind(saturated_choices, "bag_expansion") == 1, "all-maxed Mugong fallback must preserve the new slot-free bag card")
	_expect(_count_kind(saturated_choices, "training") == 0, "all-maxed Mugong fallback must not revive training")
	_expect(
		str(saturated_offer.get("card_count_policy", "")) == "available_stock",
		"all-maxed Mugong fallback must declare the available-stock shrink policy"
	)
	_expect(
		int(saturated_offer.get("requested_card_count", 0)) == 4
		and int(saturated_offer.get("actual_card_count", 0)) == 2,
		"all-maxed Mugong fallback must report the four-to-two stock contraction"
	)
	var saturated_state := TowerRewardPickState.new()
	_expect(
		saturated_state.start(
			FakeOwner.new(),
			saturated_registry,
			Callable(),
			{"supreme": 1.0}
		),
		"all-maxed Mugong fallback must open a non-empty reward screen"
	)
	_expect(
		saturated_state.choices.size() == 2,
		"all-maxed Mugong reward screen must expose fusion and bag expansion"
	)
	print(
		"tower_reward_pick_saturated_fallback: accepted=%s cards=%d training=%d policy=%s"
		% [
			str(bool(saturated_offer.get("accepted", false))),
			saturated_choices.size(),
			_count_kind(saturated_choices, "training"),
			str(saturated_offer.get("card_count_policy", "")),
		]
	)
	saturated_state.reset()


func _verify_stable_four_card_multi_buy_and_fusion_return() -> void:
	_finish_calls = 0
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	var card_renderer := FakeCardRenderer.new()
	var icon_renderer := FakeIconRenderer.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
	registry.instances["runtime_perk_overlay_renderer"] = card_renderer
	registry.instances["runtime_perk_icon_renderer"] = icon_renderer
	var offer_builder := FakeOfferBuilder.new()
	offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_card("training", "training_one", 1),
			_card("mugong", "mugong_one", 2),
			_card("fusion", "fusion_one", 3),
			_card("supreme", "supreme_one", 5),
		],
	}
	var state := TowerRewardPickState.new()
	state.set("_offer_builder", offer_builder)
	_expect(state.start(FakeOwner.new(), registry, Callable(self, "_on_finish")), "reward state must start from the production registry boundary")
	state.update(1.0)
	_expect(state.choices.size() == 4 and state.spent_flags == [false, false, false, false], "fresh entry must own four stable unspent slots")
	_expect(card_renderer.prewarm_calls == 1 and icon_renderer.prewarm_calls == 1, "card assets must prewarm once before first draw")
	var rects: Array = state.get_card_rects()
	_expect(rects.size() == 4, "four-card layout must expose four authoritative rectangles")
	for index in range(rects.size()):
		var rect := rects[index] as Rect2
		_expect(state.get_card_index_at(rect.position + Vector2(3.0, 3.0)) == index, "card top-corner hit test must match the drawn rectangle at slot %d" % index)

	state.call("_purchase", 0)
	_expect(int(flow.balances.get("muhon", -1)) == 9 and state.spent_flags[0], "first purchase must debit one and mark only its stable slot")
	var absorbing_model: Dictionary = state.build_view_model()
	var absorbing_choices: Array = absorbing_model.get("choices", [])
	var absorbing_effects: Array = absorbing_model.get("purchase_absorption_effects", [])
	_expect(absorbing_effects.size() == 1 and int((absorbing_effects[0] as Dictionary).get("slot_index", -1)) == 0, "purchased card must start one slot-bound absorption flight")
	_expect(bool((absorbing_choices[0] as Dictionary).get("reward_pick_absorbing", false)), "purchased slot must expose its moving-card phase")
	_expect((absorbing_model.get("card_rects", []) as Array) == rects, "absorption must not move any authoritative card slot")
	state.update(0.25)
	absorbing_model = state.build_view_model()
	absorbing_effects = absorbing_model.get("purchase_absorption_effects", [])
	_expect(float((absorbing_effects[0] as Dictionary).get("progress", 0.0)) > 0.0, "absorption must advance on the reward-state update clock")
	state.call("_purchase", 0)
	_expect(int(flow.balances.get("muhon", -1)) == 9 and state.choices.size() == 4, "re-clicking a spent card must neither debit nor shrink the array")
	state.call("_purchase", 1)
	_expect(int(flow.balances.get("muhon", -1)) == 7 and state.spent_flags[1], "second purchase must remain available in the same visit")
	_expect(state.purchase_absorption_effects.size() == 2, "another remaining card must be purchasable while the first absorption is playing")
	state.update(1.0)
	var emptied_model: Dictionary = state.build_view_model()
	var emptied_choices: Array = emptied_model.get("choices", [])
	_expect((emptied_model.get("purchase_absorption_effects", []) as Array).is_empty(), "completed absorption flights must retire deterministically")
	_expect(bool((emptied_choices[0] as Dictionary).get("reward_pick_empty", false)), "completed purchase must leave its stable slot completely empty")
	_expect(bool((emptied_choices[1] as Dictionary).get("reward_pick_empty", false)), "each completed purchase must leave only its own slot empty")
	_expect(not bool((emptied_choices[3] as Dictionary).get("reward_pick_empty", true)), "an unpurchased card must remain in its original slot")
	state.call("_purchase", 2)
	_expect(int(flow.balances.get("muhon", -1)) == 4 and state.spent_flags[2], "fusion card must debit three Muhon through the same transaction")
	_expect(state.is_external_modal_active(), "fusion purchase must enter the existing fusion modal")
	state.call("_finish")
	_expect(state.active and _finish_calls == 0, "continue must not bypass an active external modal")
	runtime.fusion_active = false
	state.update(0.1)
	_expect(state.active and state.choices.size() == 4 and state.spent_flags[0] and state.spent_flags[1] and state.spent_flags[2], "fusion return must preserve cards, spent flags, and the reward screen")
	var model: Dictionary = state.build_view_model()
	var supreme_model: Dictionary = (model.get("choices", []) as Array)[3]
	_expect(not bool(supreme_model.get("reward_pick_enabled", true)), "an unaffordable remaining card must disable without disappearing")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(renderer_source.find("CommonStarpointVisualHost.draw_muhon_fallback") >= 0, "purchase absorption must reuse the shared Muhon flame composition")
	_expect(renderer_source.find("if spent:") >= 0 and renderer_source.find("continue") >= 0, "spent cards must leave empty renderer slots after absorption")
	state.call("_finish")
	_expect(not state.active and _finish_calls == 1 and flow.finalize_calls == 1, "continue must finalize exactly once after external modal return")


func _verify_slot_limit_rechecks_each_purchase() -> void:
	var catalog := RuntimePerkCatalog.new()
	var runtime := RuntimePerkState.new()
	runtime.runtime_skill_levels = _five_slot_levels()
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 20
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"runtime_perk_overlay_renderer": FakeCardRenderer.new(),
		"runtime_perk_icon_renderer": FakeIconRenderer.new(),
		"tower_ascent_flow_owner": flow,
	}
	var offer_builder := FakeOfferBuilder.new()
	offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_reward_perk_card(catalog, "star_detector", "mugong", 1),
			_reward_perk_card(catalog, "item_recycle", "mugong", 1),
			_reward_perk_card(catalog, "common_bulk_up", "mugong", 1),
			_reward_perk_card(catalog, "dash_lightweight", "mugong", 1),
		],
	}
	var state := TowerRewardPickState.new()
	state.set("_offer_builder", offer_builder)
	_expect(state.start(null, registry, Callable()), "real reward slot fixture must start")
	for index in range(4):
		state.call("_purchase", index)
	_expect(state.spent_flags == [true, false, false, false], "five-slot reward board must commit only the first new unit-slot card")
	_expect_eq(catalog.count_owned_slot_perks(runtime.runtime_skill_levels, registry), 6, "reward purchases must stop exactly at 6/6 instead of reaching 9/6")
	_expect_eq(int(flow.balances.get("muhon", -1)), 19, "blocked reward cards must not debit Muhon")
	for blocked_id in ["item_recycle", "common_bulk_up", "dash_lightweight"]:
		_expect(not runtime.runtime_skill_levels.has(blocked_id), "blocked reward purchase must not add %s" % blocked_id)
	var blocked_model: Dictionary = state.build_view_model()
	var blocked_choices: Array = blocked_model.get("choices", [])
	for index in range(1, blocked_choices.size()):
		var blocked_choice := blocked_choices[index] as Dictionary
		_expect(bool(blocked_choice.get("reward_pick_enabled", false)), "remaining new reward card %d must stay enabled for replacement at 6/6" % index)
		_expect(str(blocked_choice.get("reward_pick_disabled_reason", "")).is_empty(), "replacement-routed reward card must not expose a disabled reason")
	_expect(str(blocked_model.get("status_text", "")) == TowerRewardPickLocalization.text("perk_slot_limit"), "blocked click must show the localized slot-limit message")
	state.reset()

	var full_runtime := RuntimePerkState.new()
	full_runtime.runtime_skill_levels = _five_slot_levels()
	full_runtime.runtime_skill_levels["star_detector"] = 1
	var full_registry := FakeRegistry.new()
	full_registry.instances = {
		"runtime_perk_state": full_runtime,
		"runtime_perk_catalog": catalog,
		"runtime_perk_overlay_renderer": FakeCardRenderer.new(),
		"runtime_perk_icon_renderer": FakeIconRenderer.new(),
		"tower_ascent_flow_owner": FakeFlowOwner.new(),
	}
	var full_offer_builder := FakeOfferBuilder.new()
	full_offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_reward_perk_card(catalog, "dash_acceleration", "mugong", 1),
			{
				"id": "perk_fusion",
				"name": "Fusion",
				"is_perk_fusion": true,
				"max_level": 0,
				"reward_pick_kind": "fusion",
				"reward_pick_cost": 1,
			},
			_reward_perk_card(catalog, "item_recycle", "mugong", 1),
		],
	}
	var full_state := TowerRewardPickState.new()
	full_state.set("_offer_builder", full_offer_builder)
	_expect(full_state.start(null, full_registry, Callable()), "full reward board fixture must start")
	var full_choices: Array = full_state.build_view_model().get("choices", [])
	_expect(bool((full_choices[0] as Dictionary).get("reward_pick_enabled", false)), "owned unit-slot upgrade must remain enabled at 6/6")
	_expect(bool((full_choices[1] as Dictionary).get("reward_pick_enabled", false)), "slot-free fusion must remain enabled at 6/6")
	_expect(bool((full_choices[2] as Dictionary).get("reward_pick_enabled", false)), "new unit-slot perk must stay enabled for replacement at 6/6")
	full_state.reset()


func _verify_fullscreen_stats_ledger_hover_and_cache_contract() -> void:
	var owner := FakeOwner.new()
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	var renderer := FakeCardRenderer.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
	registry.instances["runtime_perk_overlay_renderer"] = renderer
	registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
	var catalog := registry.instances["runtime_perk_catalog"] as FakeCatalog
	var offer_builder := FakeOfferBuilder.new()
	offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_card("training", "hover_training", 1),
			_card("mugong", "hover_mugong", 2),
			_card("fusion", "hover_fusion", 3),
			_card("supreme", "hover_supreme", 5),
		],
	}
	var state := TowerRewardPickState.new()
	state.set("_offer_builder", offer_builder)
	_expect(state.start(owner, registry, Callable()), "fullscreen reward ledger fixture must start")
	_expect(runtime.stats_capture_calls == 0, "a fresh reward pick must not inherit a stale perk-modal stats context")
	_expect(catalog.slot_status_calls == 1, "reward entry must cache perk-slot status exactly once")
	var entry_slot_status_calls := catalog.slot_status_calls
	state.update(1.0)
	_expect(
		runtime.stats_capture_calls == 1
		and runtime.stats_context_owner == owner
		and runtime.get_stats_context_registry() == registry,
		"reward update must capture stats context even when the ordinary perk modal was never opened"
	)
	_expect(bool(state.get("stats_band_enabled")), "the reward-owned stats-band flag must enable after live context capture")

	var card_rects: Array = state.get_card_rects(LIVE_VIEW_SIZE)
	_expect(card_rects.size() == 4, "fullscreen reward layout must keep all four cards")
	var hover_position := (card_rects[2] as Rect2).position + Vector2(3.0, 3.0)
	var direct_hover_index := state.get_card_index_at(hover_position, LIVE_VIEW_SIZE)
	_expect(
		direct_hover_index == 2,
		"the drawn fullscreen card top corner must resolve to its own reward slot (got %d)" % direct_hover_index
	)
	var motion := InputEventMouseMotion.new()
	motion.position = hover_position
	state.handle_input(motion, LIVE_VIEW_SIZE)
	_expect(state.selected_index == 2, "mouse motion over a card top corner must drive the existing selection highlight")
	_expect(
		(state.get("reward_hover_mouse_pos") as Vector2).is_equal_approx(hover_position),
		"reward hover must use its own pointer channel instead of runtime-state modal hover"
	)

	var model: Dictionary = state.build_view_model(LIVE_VIEW_SIZE)
	var layout: Dictionary = model.get("layout", {})
	var panel_rect: Rect2 = layout.get("panel_rect", Rect2())
	var stats_rect: Rect2 = layout.get("stats_rect", Rect2())
	var last_card_rect := card_rects[card_rects.size() - 1] as Rect2
	_expect(panel_rect.position.y - last_card_rect.end.y >= 30.0, "reward price strip and perk ledger need at least 30px separation")
	_expect(
		stats_rect.size.y >= RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT,
		"four-card reward stats band must retain the full 10-row minimum"
	)
	var stats_budget := float(layout.get("stats_budget", -1.0))
	_expect(
		stats_budget >= RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT
		and stats_budget - RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT <= 32.0,
		"the 2020x1246 four-card reward boundary must seal its narrow stats budget"
	)
	var continue_rect := state.get_continue_rect(LIVE_VIEW_SIZE)
	_expect(
		continue_rect.position.y >= stats_rect.end.y
		and Rect2(Vector2.ZERO, LIVE_VIEW_SIZE).encloses(continue_rect),
		"Continue must derive below the ledger while remaining inside the viewport"
	)

	state.draw(null, LIVE_VIEW_SIZE)
	_expect(renderer.draw_calls == 1, "reward draw must reach the shared renderer once")
	_expect(runtime.snapshot_calls == 1, "perk ledger and stats band must share one runtime snapshot per draw frame")
	_expect(renderer.last_catalog == catalog, "reward renderer must receive the production perk catalog")
	_expect(renderer.last_view_size.is_equal_approx(LIVE_VIEW_SIZE), "reward renderer must retain the live screen size")
	_expect(renderer.last_mouse_pos.is_equal_approx(hover_position), "ledger and stats hover must receive the reward-owned pointer")
	_expect(
		renderer.last_snapshot.has("perk_slot_status")
		and bool(renderer.last_snapshot.get("perk_slot_status_cached", false))
		and renderer.last_snapshot.has("physique_training")
		and renderer.last_snapshot.has("reward_pick_spent_flags"),
		"one reward snapshot must carry slot status and both purchase-sensitive stats signatures"
	)
	state.draw(null, LIVE_VIEW_SIZE)
	_expect(catalog.slot_status_calls == 1, "repeated draw frames must not rescan perk-slot status")
	var repeated_draw_slot_status_calls := catalog.slot_status_calls
	state.call("_purchase", 0)
	state.update(0.016)
	_expect(catalog.slot_status_calls == 2, "a committed purchase must invalidate and refresh slot status once")
	print(
		"tower_reward_hover_lookup_counts: entry=%d repeated_draw=%d post_purchase=%d"
		% [
			entry_slot_status_calls,
			repeated_draw_slot_status_calls,
			catalog.slot_status_calls,
		]
	)

	var highlight_value: Variant = RuntimePerkOverlayRenderer.resolve_tower_reward_slot_highlight_keys(
		["mugong_a", "mugong_b", "mugong_c"],
		["mugong_b", "mugong_c", "mugong_d"]
	)
	var highlight_keys: Array = highlight_value if highlight_value is Array else []
	_expect(
		highlight_keys == ["mugong_d"],
		"slot transition highlights must follow perk keys, never shifted slot indices"
	)
	state.reset()


func _verify_reward_hover_highlight_contract() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/hud/runtime_perk_overlay_renderer.gd"
	)
	var reward_draw_body := _extract_function_source(
		renderer_source,
		"func draw_tower_reward_pick("
	)
	_expect(
		reward_draw_body.contains("_resolve_tower_reward_hover_preview("),
		"reward draw must resolve the hover preview on the production path"
	)
	var status_panel_body := _extract_function_source(
		renderer_source,
		"func _draw_status_panel("
	)
	var status_panel_call := _extract_call_source(reward_draw_body, "_draw_status_panel(")
	_expect(
		status_panel_call.contains("reward_hover_preview"),
		"reward draw must pass its resolved hover preview into the status panel"
	)
	_expect(
		status_panel_body.contains("_reward_hover_landing_slot"),
		"status-panel draw must consume the simulated landing marker"
	)
	_expect(
		status_panel_body.contains("if reward_hover_material_keys.has(skill_key):")
		and status_panel_body.contains("_draw_tower_reward_material_preview("),
		"status-panel draw must gate and draw the fusion material preview at its consumption site"
	)
	var card_rect := Rect2(120.0, 90.0, 220.0, 310.0)
	var new_mugong := {
		"id": "mugong_mid",
		"reward_pick_kind": "mugong",
		"current_level": 0,
		"next_level": 4,
		"max_level": 5,
		"reward_pick_enabled": true,
	}
	var open_snapshot := {
		"perk_slot_status": {
			"count": 3,
			"limit": 6,
			"is_full": false,
		},
		"perk_slot_status_cached": true,
	}
	var idle_build_count := renderer.get_tower_reward_hover_preview_build_count_for_tests()
	var idle_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[new_mugong],
		[card_rect],
		Vector2(20.0, 20.0),
		open_snapshot
	)
	_expect(idle_preview.is_empty(), "no reward-card hover must keep the ledger preview empty")
	_expect(
		renderer.get_tower_reward_hover_preview_build_count_for_tests() == idle_build_count,
		"GRT-043: no reward-card hover must not invoke the preview interpreter"
	)
	var chosik_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[{
			"id": "unlock_ghost_shot",
			"reward_pick_kind": "chosik",
			"unlocks_skill": "ghost_shot",
			"current_level": 0,
			"next_level": 1,
			"reward_pick_enabled": true,
		}],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	_expect(
		chosik_preview.is_empty(),
		"Chosik hover must not project its five-orb landing into the Mugong ledger"
	)
	_expect(
		renderer.get_tower_reward_hover_preview_build_count_for_tests() == idle_build_count,
		"Chosik hover must stop before the Mugong landing-preview interpreter"
	)
	print("tower_reward_hover_chosik_target: target=five_orb_hud mugong_ledger_landing=-1")
	var bypass_gate_counterproof := RuntimePerkOverlayRenderer.build_tower_reward_hover_preview(
		new_mugong,
		open_snapshot.perk_slot_status
	)
	_expect(
		not bypass_gate_counterproof.is_empty(),
		"the no-hover fixture must turn RED if the strict hover gate is bypassed"
	)

	var landing_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[new_mugong],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	_expect(
		int(landing_preview.get("empty_slot_requests", 0)) == 1,
		"a new Mugong hover must request exactly one destination cell"
	)
	var landing_key_levels: Dictionary = landing_preview.get("landing_key_levels", {})
	_expect(
		int(landing_key_levels.get("mugong_mid", 0)) == 4,
		"the destination request must remain keyed and carry the offered next level"
	)
	_expect(
		renderer.get_tower_reward_hover_preview_build_count_for_tests() == idle_build_count + 1,
		"the first eligible reward hover must build once"
	)
	var landing_projection_count := (
		renderer.get_tower_reward_hover_landing_projection_count_for_tests()
	)
	var cached_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[new_mugong],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	_expect(cached_preview == landing_preview, "unchanged reward hover inputs must reuse the preview model")
	_expect(
		renderer.get_tower_reward_hover_preview_build_count_for_tests() == idle_build_count + 1,
		"fade redraws must not rebuild the reward hover preview"
	)
	_expect(
		renderer.get_tower_reward_hover_landing_projection_count_for_tests()
		== landing_projection_count,
		"fade redraws must not recompute landing levels before the preview cache gate"
	)
	var supreme_choice := {
		"id": "megingjord",
		"reward_pick_kind": "supreme",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
		"reward_pick_enabled": true,
	}
	var supreme_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[supreme_choice],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	_expect(
		int((supreme_preview.get("landing_key_levels", {}) as Dictionary).get("megingjord", 0)) == 1
		and int(supreme_preview.get("empty_slot_requests", 0)) == 1,
		"a new supreme perk must use the same one-slot landing path as a new Mugong"
	)
	var supreme_upgrade := supreme_choice.duplicate(true)
	supreme_upgrade["current_level"] = 1
	supreme_upgrade["next_level"] = 1
	var supreme_upgrade_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[supreme_upgrade],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	_expect(
		supreme_upgrade_preview.is_empty(),
		"an owned supreme upgrade must not request another slot destination"
	)
	var dash_upgrade := {
		"id": "dash_amplification",
		"reward_pick_kind": "mugong",
		"current_level": 1,
		"next_level": 2,
		"max_level": 3,
		"reward_pick_enabled": true,
	}
	var dash_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[dash_upgrade],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	var dash_landing_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		[{"id": "dash_amplification", "level": 1}],
		6,
		dash_preview
	)
	_expect(
		int(dash_preview.get("empty_slot_requests", 0)) == 1
		and _find_entry_index_by_flag(dash_landing_grid, "_reward_hover_landing_slot") == 1,
		"Glide Orb Lv.1-to-2 hover must preview its one additional occupied slot"
	)

	var acquired := [
		{"id": "alpha_high", "level": 5},
		{"id": "zeta_same_rank", "level": 4},
		{"id": "omega_low", "level": 1},
	]
	var stable_choices := [
		{
			"id": "zeta_new",
			"reward_pick_kind": "mugong",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"reward_pick_enabled": true,
		},
		{
			# Alphabetically precedes mugong_mid so the retired hover sort moves
			# the owned card and makes this behavioral seal RED.
			"id": "alpha_new",
			"reward_pick_kind": "mugong",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"reward_pick_enabled": true,
		},
		{
			"id": "beta_new",
			"reward_pick_kind": "mugong",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"reward_pick_enabled": true,
		},
	]
	var stable_card_rects := [
		Rect2(20.0, 20.0, 100.0, 160.0),
		Rect2(140.0, 20.0, 100.0, 160.0),
		Rect2(260.0, 20.0, 100.0, 160.0),
	]
	var stable_snapshot := {
		"perk_slot_status": {"count": 1, "limit": 6, "is_full": false},
		"perk_slot_status_cached": true,
		"runtime_skill_levels": {"mugong_mid": 1},
		"effective_runtime_skill_levels": {"mugong_mid": 1},
	}
	var stable_owned := [{"id": "mugong_mid", "level": 1}]
	var stable_existing_indices: Array[int] = []
	var stable_landing_indices: Array[int] = []
	var stable_previews: Array[Dictionary] = []
	for card_index in range(stable_choices.size()):
		var stable_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
			stable_choices,
			stable_card_rects,
			(stable_card_rects[card_index] as Rect2).get_center(),
			stable_snapshot
		)
		stable_previews.append(stable_preview)
		var stable_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
			stable_owned,
			6,
			stable_preview
		)
		stable_existing_indices.append(_find_entry_index_by_id(stable_grid, "mugong_mid"))
		stable_landing_indices.append(
			_find_entry_index_by_flag(stable_grid, "_reward_hover_landing_slot")
		)
	_expect(
		stable_existing_indices == [0, 0, 0]
		and stable_landing_indices == [1, 1, 1],
		"card 1/2/3 hover must keep the owned Mugong at cell 0 and land at its immediate right"
	)
	print(
		"tower_reward_hover_stable_slot_order: existing=%s landing=%s ids=zeta_new,alpha_new,beta_new"
		% [stable_existing_indices, stable_landing_indices]
	)

	var zero_owned_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		[],
		6,
		stable_previews[0]
	)
	_expect(
		_find_entry_index_by_flag(zero_owned_grid, "_reward_hover_landing_slot") == 0,
		"zero-owned hover must land in the first slot"
	)

	var multi_landing_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		[{"id": "mugong_mid", "level": 1}],
		6,
		{
			"empty_slot_requests": 3,
			"landing_key_levels": {"dash_amplification": 3},
		}
	)
	_expect(
		_find_entry_indices_by_flag(
			multi_landing_grid,
			"_reward_hover_landing_slot"
		) == [1, 2, 3]
		and _find_entry_index_by_id(multi_landing_grid, "mugong_mid") == 0,
		"multi-cell hover landings must remain contiguous after every owned cell"
	)

	var same_skill_acquired := [
		{"id": "alpha_anchor", "level": 1},
		{"id": "dash_amplification", "level": 1, "_slot_cell_index": 0},
	]
	var same_skill_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		same_skill_acquired,
		6,
		{
			"empty_slot_requests": 1,
			"landing_key_levels": {"dash_amplification": 2},
		}
	)
	var upgraded_same_skill: Dictionary = same_skill_grid[1]
	_expect(
		_find_entry_index_by_id(same_skill_grid, "alpha_anchor") == 0
		and _find_entry_index_by_id(same_skill_grid, "dash_amplification") == 1
		and int(upgraded_same_skill.get("level", 0)) == 2
		and int(upgraded_same_skill.get("_slot_cell_index", -1)) == 0
		and _find_entry_index_by_flag(same_skill_grid, "_reward_hover_landing_slot") == 2,
		"same-skill upgrade projection must update the owned cell in place and append only its new cell"
	)
	print(
		"tower_reward_hover_edge_slots: zero=0 multi=%s same_skill_existing=1 same_skill_landing=2"
		% [_find_entry_indices_by_flag(multi_landing_grid, "_reward_hover_landing_slot")]
	)

	var baseline_grid: Array = renderer._build_status_slot_grid(
		acquired,
		6,
		{}
	)
	var first_empty_index := -1
	for index in range(baseline_grid.size()):
		var baseline_entry: Dictionary = baseline_grid[index]
		if bool(baseline_entry.get("_empty_slot", false)):
			first_empty_index = index
			break
	var grid_build_count := renderer.get_tower_reward_hover_grid_build_count_for_tests()
	var landing_grid: Array = renderer._build_status_slot_grid(
		acquired,
		6,
		landing_preview
	)
	var landing_index := -1
	for index in range(landing_grid.size()):
		var landing_entry: Dictionary = landing_grid[index]
		if bool(landing_entry.get("_reward_hover_landing_slot", false)):
			landing_index = index
			break
	_expect(first_empty_index == 3, "counterproof fixture must expose the naive first empty cell")
	_expect(
		landing_index == first_empty_index,
		"hover destination must occupy the first empty cell after all owned Mugong"
	)
	_expect(
		_find_entry_index_by_id(landing_grid, "alpha_high") == 0
		and _find_entry_index_by_id(landing_grid, "zeta_same_rank") == 1
		and _find_entry_index_by_id(landing_grid, "omega_low") == 2,
		"hover projection must preserve the non-hover order for two or more owned Mugong"
	)
	_expect(
		baseline_grid == renderer._build_status_slot_grid(acquired, 6, {}),
		"non-hover perk-selection grid output must remain unchanged"
	)
	print(
		"tower_reward_hover_owned_order: baseline=alpha_high,zeta_same_rank,omega_low landing=%d non_hover=unchanged"
		% landing_index
	)
	_expect(
		renderer.get_tower_reward_hover_grid_build_count_for_tests() == grid_build_count + 1,
		"the first eligible hover grid must assemble once"
	)
	var _cached_landing_grid: Array = renderer._build_status_slot_grid(
		acquired,
		6,
		landing_preview
	)
	_expect(
		renderer.get_tower_reward_hover_grid_build_count_for_tests() == grid_build_count + 1,
		"continuous fade frames must not rebuild the hover slot grid"
	)
	var changed_acquired: Array = acquired.duplicate(true)
	(changed_acquired[1] as Dictionary)["level"] = 6
	var changed_acquired_build_count := renderer.get_tower_reward_hover_grid_build_count_for_tests()
	var changed_acquired_grid: Array = renderer._build_status_slot_grid(
		changed_acquired,
		6,
		landing_preview
	)
	_expect(
		renderer.get_tower_reward_hover_grid_build_count_for_tests() == changed_acquired_build_count + 1,
		"same-size acquired content changes must invalidate the hover-grid cache"
	)
	var changed_limit_build_count := renderer.get_tower_reward_hover_grid_build_count_for_tests()
	var changed_limit_grid: Array = renderer._build_status_slot_grid(
		changed_acquired,
		7,
		landing_preview
	)
	_expect(
		renderer.get_tower_reward_hover_grid_build_count_for_tests() == changed_limit_build_count + 1
		and changed_limit_grid.size() == 7
		and changed_acquired_grid.size() == 6,
		"runtime slot-limit changes must invalidate and resize the hover-grid cache"
	)

	var bonus_choice := {
		"id": "item_luck",
		"reward_pick_kind": "mugong",
		"current_level": 0,
		"next_level": 1,
		"max_level": 5,
		"reward_pick_enabled": true,
	}
	var bonus_snapshot := open_snapshot.duplicate(true)
	bonus_snapshot["runtime_skill_levels"] = {
		"alpha_high": 5,
		"omega_low": 1,
	}
	bonus_snapshot["item_perk_level_bonus"] = 2
	var bonus_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[bonus_choice],
		[card_rect],
		card_rect.get_center(),
		bonus_snapshot
	)
	var bonus_acquired := [
		{"id": "alpha_high", "level": 7},
		{"id": "omega_low", "level": 3},
	]
	var bonus_landing_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		bonus_acquired,
		6,
		bonus_preview
	)
	var bonus_landing_index := _find_entry_index_by_flag(
		bonus_landing_grid,
		"_reward_hover_landing_slot"
	)
	var purchased_levels := {"alpha_high": 7, "omega_low": 3}
	purchased_levels["item_luck"] = 3
	var purchased_acquired: Array = renderer._build_acquired_perks_for_snapshot(
		purchased_levels,
		null,
		null,
		{}
	)
	var purchased_index := _find_entry_index_by_id(purchased_acquired, "item_luck")
	_expect(
		int((bonus_preview.get("landing_key_levels", {}) as Dictionary).get("item_luck", 0)) == 3
		and bonus_landing_index == 2
		and purchased_index == 1,
		"stable hover must append after owned cells even when purchase-time sorting later reorders them"
	)
	print(
		"tower_reward_hover_effective_level_landing: bonus=2 state_order=%s hover_index=%d purchased_index=%d post_purchase_reorders=true"
		% [purchased_levels.keys(), bonus_landing_index, purchased_index]
	)

	var fusion_limit_break_snapshot := open_snapshot.duplicate(true)
	fusion_limit_break_snapshot["runtime_skill_levels"] = {"dash_amplification": 1}
	fusion_limit_break_snapshot["effective_runtime_skill_levels"] = {
		"dash_amplification": 2,
	}
	fusion_limit_break_snapshot["item_perk_level_bonus"] = 0
	var fusion_limit_break_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[dash_upgrade],
		[card_rect],
		card_rect.get_center(),
		fusion_limit_break_snapshot
	)
	var fusion_limit_break_landing_level := int(
		(fusion_limit_break_preview.get("landing_key_levels", {}) as Dictionary).get(
			"dash_amplification",
			0
		)
	)
	var pure_projected_level := RuntimePerkEffectiveLevels.new().get_runtime_skill_level(
		{"dash_amplification": 2},
		0,
		false,
		"dash_amplification"
	)
	var query_surface := RuntimePerkEffectiveStatQuerySurface.new()
	var purchased_ledger_levels: Dictionary = query_surface.get_effective_runtime_skill_levels(
		RuntimePerkEffectiveLevels.new(),
		FakeFusionEffectiveLevelRuntime.new()
	)
	_expect(
		pure_projected_level == 2
		and fusion_limit_break_landing_level == 3
		and int(purchased_ledger_levels.get("dash_amplification", 0)) == 3,
		"hover landing must preserve the query-surface fusion limit break and match the post-purchase ledger"
	)
	print(
		"tower_reward_hover_query_surface_landing: pure=%d hover=%d ledger=%d"
		% [
			pure_projected_level,
			fusion_limit_break_landing_level,
			int(purchased_ledger_levels.get("dash_amplification", 0)),
		]
	)

	var aliased_acquired := [
		{"id": "mugong_mid", "level": 1, "_slot_cell_index": 9},
	]
	var aliased_acquired_before: Array = aliased_acquired.duplicate(true)
	var alias_mutation_preview := RuntimePerkOverlayRenderer.build_tower_reward_hover_preview(
		new_mugong,
		open_snapshot.perk_slot_status,
		4
	)
	var _alias_mutation_grid: Array = (
		RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
			aliased_acquired,
			6,
			alias_mutation_preview
		)
	)
	_expect(
		aliased_acquired == aliased_acquired_before,
		"hover-grid projection must deep-copy entries before mutating level and cell index"
	)

	var ambiguous_landing_grid: Array = (
		RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
			acquired,
			6,
			{
				"empty_slot_requests": 2,
				"landing_key_levels": {"alpha": 4, "beta": 3},
			}
		)
	)
	_expect(
		_find_entry_index_by_flag(
			ambiguous_landing_grid,
			"_reward_hover_landing_slot"
		) == -1,
		"multiple landing identities must fail closed instead of starving later keys"
	)

	var fusion_projection_snapshot := {
		"effective_runtime_skill_levels": {},
		"perk_fusion_display_projection": {
			"entries": [
				{
					"type": "fusion",
					"id": "fusion_1",
					"fusion_id": "fusion_1",
					"fusion_revision": 1,
					"sources": ["common_bulk_up", "common_swiftness"],
					"source_names": ["bulk", "swift"],
					"base_levels": {"common_bulk_up": 1, "common_swiftness": 1},
					"effective_levels": {"common_bulk_up": 1, "common_swiftness": 1},
					"summary": "fusion fixture",
					"slot_cost": 1,
					"record_payload": {
						"fusion_id": "fusion_1",
						"sources": ["common_bulk_up", "common_swiftness"],
						"outcome": "success",
					},
				},
			],
		},
	}
	var fusion_slot_entries: Array = renderer._build_acquired_perks_for_snapshot(
		{},
		RuntimePerkCatalog.new(),
		null,
		fusion_projection_snapshot
	)
	_expect(fusion_slot_entries.size() == 1, "fusion landing fixture must own one folded slot")
	if fusion_slot_entries.size() == 1:
		var fusion_slot: Dictionary = fusion_slot_entries[0]
		_expect(
			str(fusion_slot.get("id", "")).begins_with("perk_fusion_pair:"),
			"status rendering must retain the transformed fusion icon identity"
		)
		_expect(
			str(fusion_slot.get("_sort_id", "")) == "fusion_1",
			"status rendering must preserve the pre-transform fusion sort identity"
		)
		var item_luck_preview := RuntimePerkOverlayRenderer.build_tower_reward_hover_preview(
			{
				"id": "item_luck",
				"reward_pick_kind": "mugong",
				"current_level": 0,
				"next_level": 1,
				"max_level": 5,
			},
			{"count": 1, "limit": 6, "is_full": false}
		)
		var fusion_landing_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
			fusion_slot_entries,
			6,
			item_luck_preview
		)
		var fusion_landing_index := -1
		for index in range(fusion_landing_grid.size()):
			var fusion_landing_entry: Dictionary = fusion_landing_grid[index]
			if bool(fusion_landing_entry.get("_reward_hover_landing_slot", false)):
				fusion_landing_index = index
				break
		_expect(
			fusion_landing_index == 1,
			"fusion_1 must remain before a level-1 item_luck landing after id transformation"
		)
		print(
			"tower_reward_hover_fusion_landing: original=fusion_1 new=item_luck landing_index=%d"
			% fusion_landing_index
		)

	var fusion_choice := {
		"id": "perk_fusion",
		"reward_pick_kind": "fusion",
		"eligible_sources": ["alpha_high", "zeta_same_rank", "omega_low"],
		"reward_pick_enabled": true,
	}
	var fusion_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[fusion_choice],
		[card_rect],
		card_rect.get_center(),
		open_snapshot
	)
	var material_keys: Dictionary = fusion_preview.get("material_keys", {})
	_expect(
		material_keys.size() == 3
		and material_keys.has("alpha_high")
		and material_keys.has("zeta_same_rank")
		and material_keys.has("omega_low"),
		"fusion hover must highlight every eligible source when the candidate pool exceeds two"
	)
	var arbitrary_two_only := {
		"alpha_high": true,
		"zeta_same_rank": true,
	}
	_expect(
		arbitrary_two_only != material_keys,
		"the three-source fixture must turn RED if the renderer arbitrarily keeps only two"
	)

	var full_snapshot := open_snapshot.duplicate(true)
	full_snapshot["perk_slot_status"] = {
		"count": 6,
		"limit": 6,
		"is_full": true,
	}
	var full_preview: Dictionary = renderer._resolve_tower_reward_hover_preview(
		[new_mugong],
		[card_rect],
		card_rect.get_center(),
		full_snapshot
	)
	_expect(bool(full_preview.get("slot_full", false)), "full-slot hover must expose the existing full state")
	_expect(
		int(full_preview.get("empty_slot_requests", -1)) == 0
		and (full_preview.get("landing_key_levels", {}) as Dictionary).is_empty(),
		"full-slot hover must not draw a false destination or duplicate W1's disabled treatment"
	)
	var full_acquired := [
		{"id": "slot_0", "level": 6},
		{"id": "slot_1", "level": 5},
		{"id": "slot_2", "level": 4},
		{"id": "slot_3", "level": 3},
		{"id": "slot_4", "level": 2},
		{"id": "slot_5", "level": 1},
	]
	var full_grid: Array = RuntimePerkOverlayRenderer.build_tower_reward_hover_slot_grid(
		full_acquired,
		6,
		full_preview
	)
	_expect(
		_find_entry_index_by_flag(full_grid, "_reward_hover_landing_slot") == -1
		and _find_entry_index_by_id(full_grid, "slot_0") == 0
		and _find_entry_index_by_id(full_grid, "slot_5") == 5,
		"full-slot hover must keep all six owned positions and draw no destination"
	)
	print("tower_reward_hover_full_slot: landing=-1 owned_positions=0..5")


func _verify_reward_hover_draw_wiring_behavior() -> void:
	var card_rect := Rect2(80.0, 55.0, 210.0, 260.0)
	var base_snapshot := {
		"runtime_skill_levels": {
			"common_bulk_up": 2,
			"common_swiftness": 1,
		},
		"effective_runtime_skill_levels": {
			"common_bulk_up": 2,
			"common_swiftness": 1,
		},
		"perk_slot_status": {"count": 2, "limit": 6, "is_full": false},
		"perk_slot_status_cached": true,
		"pending_skill_choices": 0,
		"gold_from_perks": 0,
	}
	var landing_choice := {
		"id": "item_luck",
		"name": "landing fixture",
		"reward_pick_kind": "mugong",
		"current_level": 0,
		"next_level": 1,
		"max_level": 5,
		"reward_pick_enabled": true,
	}
	var landing_renderer := RuntimePerkOverlayRenderer.new()
	landing_renderer.set_training_stat_preview_draw_msec_for_tests(200)
	var landing_probe := _build_reward_hover_draw_probe(
		landing_renderer,
		landing_choice,
		card_rect,
		base_snapshot
	)
	get_root().add_child(landing_probe)
	landing_probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		landing_renderer.get_tower_reward_landing_draw_count_for_tests() > 0,
		"F11 action seal: draw_tower_reward_pick must reach the cyan landing-ring draw call"
	)
	_expect(
		landing_renderer.get_tower_reward_material_draw_count_for_tests() == 0,
		"new-perk hover must not reach the fusion material-ring draw call"
	)
	landing_probe.queue_free()
	await process_frame

	var fusion_choice := {
		"id": "perk_fusion",
		"name": "fusion fixture",
		"reward_pick_kind": "fusion",
		"eligible_sources": ["common_bulk_up", "common_swiftness"],
		"reward_pick_enabled": true,
	}
	var material_renderer := RuntimePerkOverlayRenderer.new()
	material_renderer.set_training_stat_preview_draw_msec_for_tests(200)
	var material_probe := _build_reward_hover_draw_probe(
		material_renderer,
		fusion_choice,
		card_rect,
		base_snapshot
	)
	get_root().add_child(material_probe)
	material_probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		material_renderer.get_tower_reward_material_draw_count_for_tests() >= 2,
		"F11 action seal: fusion hover must reach every eligible material-ring draw call"
	)
	_expect(
		material_renderer.get_tower_reward_landing_draw_count_for_tests() == 0,
		"fusion hover must not reach the cyan destination-ring draw call"
	)
	material_probe.queue_free()
	await process_frame
	print(
		"tower_reward_hover_draw_wiring: landing_calls=%d material_calls=%d"
		% [
			landing_renderer.get_tower_reward_landing_draw_count_for_tests(),
			material_renderer.get_tower_reward_material_draw_count_for_tests(),
		]
	)


func _verify_reward_hover_draw_output_contract() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var slot_rect := Rect2(120.0, 240.0, 72.0, 88.0)
	var fade := 0.5
	var landing_spy := RewardHoverDrawCallSpy.new()
	renderer._draw_tower_reward_landing_preview(landing_spy, slot_rect, fade)
	_expect(
		landing_spy.draw_rect_calls.size() == 1,
		"G1 output seal: cyan landing hover must issue exactly one canvas.draw_rect"
	)
	if landing_spy.draw_rect_calls.size() == 1:
		var landing_call: Dictionary = landing_spy.draw_rect_calls[0]
		_expect(
			(landing_call.get("rect", Rect2()) as Rect2) == slot_rect.grow(5.0)
			and (landing_call.get("color", Color.TRANSPARENT) as Color).is_equal_approx(
				Color(0.22, 0.88, 1.0, 0.92 * fade)
			)
			and not bool(landing_call.get("filled", true))
			and is_equal_approx(float(landing_call.get("width", 0.0)), 2.5),
			"G1 output seal: cyan landing hover must emit the exact outside rect, color, and width"
		)

	var material_spy := RewardHoverDrawCallSpy.new()
	renderer._draw_tower_reward_material_preview(material_spy, slot_rect, fade)
	_expect(
		material_spy.draw_rect_calls.size() == 1,
		"G1 output seal: red material hover must issue exactly one canvas.draw_rect"
	)
	if material_spy.draw_rect_calls.size() == 1:
		var material_call: Dictionary = material_spy.draw_rect_calls[0]
		_expect(
			(material_call.get("rect", Rect2()) as Rect2) == slot_rect.grow(-3.0)
			and (material_call.get("color", Color.TRANSPARENT) as Color).is_equal_approx(
				Color(1.0, 0.32, 0.46, 0.94 * fade)
			)
			and not bool(material_call.get("filled", true))
			and is_equal_approx(float(material_call.get("width", 0.0)), 3.0),
			"G1 output seal: red material hover must emit the exact inset rect, color, and width"
		)

	var zero_fade_spy := RewardHoverDrawCallSpy.new()
	renderer._draw_tower_reward_landing_preview(zero_fade_spy, slot_rect, 0.0)
	renderer._draw_tower_reward_material_preview(zero_fade_spy, slot_rect, 0.0)
	_expect(
		zero_fade_spy.draw_rect_calls.is_empty(),
		"G2 output seal: zero fade must suppress both hover draw_rect calls"
	)
	_expect(
		renderer.get_tower_reward_landing_draw_count_for_tests() == 1
		and renderer.get_tower_reward_material_draw_count_for_tests() == 1,
		"G2 output seal: zero fade must not increment visible-output counters"
	)
	var landing_output: Dictionary = (
		landing_spy.draw_rect_calls[0]
		if landing_spy.draw_rect_calls.size() == 1
		else {}
	)
	var material_output: Dictionary = (
		material_spy.draw_rect_calls[0]
		if material_spy.draw_rect_calls.size() == 1
		else {}
	)
	print(
		"tower_reward_hover_draw_output: landing_draw_rect_calls=%d material_draw_rect_calls=%d landing_rect=%s landing_color=%s material_rect=%s material_color=%s"
		% [
			landing_spy.draw_rect_calls.size(),
			material_spy.draw_rect_calls.size(),
			landing_output.get("rect", Rect2()),
			landing_output.get("color", Color.TRANSPARENT),
			material_output.get("rect", Rect2()),
			material_output.get("color", Color.TRANSPARENT),
		]
	)
	print(
		"tower_reward_hover_zero_fade: draw_rect_calls=%d"
		% zero_fade_spy.draw_rect_calls.size()
	)


func _build_reward_hover_draw_probe(
	renderer: Object,
	choice: Dictionary,
	card_rect: Rect2,
	snapshot: Dictionary
) -> RewardHoverDrawProbe:
	var probe := RewardHoverDrawProbe.new()
	probe.renderer = renderer
	probe.catalog = RuntimePerkCatalog.new()
	probe.snapshot = snapshot.duplicate(true)
	probe.mouse_pos = card_rect.get_center()
	probe.view_size = Vector2(1024.0, 720.0)
	probe.view_model = {
		"animation_time": 1.0,
		"title": "reward hover draw fixture",
		"choices": [choice.duplicate(true)],
		"card_rects": [card_rect],
		"selected_index": 0,
		"reward_session_id": 901,
		"layout": {
			"title_pos": Vector2(512.0, 34.0),
			"layout_scale": 1.0,
			"cards_start": card_rect.position,
			"card_size": card_rect.size,
			"card_gap": 0.0,
			"desc_rect": Rect2(),
			"panel_rect": Rect2(40.0, 410.0, 900.0, 150.0),
			"stats_rect": Rect2(),
		},
	}
	return probe


func _verify_unaffordable_board_auto_finish_and_failure_latch() -> void:
	_finish_calls = 0
	var fusion_runtime := FakeRuntimeState.new()
	var fusion_flow := FakeFlowOwner.new()
	fusion_flow.balances["muhon"] = 4
	var fusion_registry := _build_registry(
		fusion_runtime,
		FakeSkillConfig.new(),
		fusion_flow
	)
	fusion_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var fusion_builder := FakeOfferBuilder.new()
	fusion_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_card("training", "auto_training", 1),
			_card("mugong", "auto_mugong", 1),
			_card("fusion", "auto_fusion", 1),
			_card("supreme", "auto_supreme", 1),
		],
	}
	var fusion_state := TowerRewardPickState.new()
	fusion_state.set("_offer_builder", fusion_builder)
	_expect(
		fusion_state.start(FakeOwner.new(), fusion_registry, Callable(self, "_on_finish")),
		"all-spent fusion auto-finish fixture must start"
	)
	fusion_state.call("_purchase", 0)
	fusion_state.call("_purchase", 1)
	fusion_state.call("_purchase", 3)
	fusion_state.call("_purchase", 2)
	_expect(fusion_state.spent_flags == [true, true, true, true], "fusion fixture must spend all four stable slots")
	_expect(fusion_state.is_external_modal_active(), "final fusion purchase must keep the external modal active")
	fusion_state.update(10.0)
	_expect(
		fusion_state.active and fusion_flow.finalize_calls == 0,
		"all-spent reward picks must never finish while the fusion modal is active"
	)
	fusion_runtime.fusion_active = false
	fusion_state.update(0.0)
	_expect(
		fusion_state.active and fusion_flow.finalize_calls == 0,
		"the frame that clears pending fusion ownership must not finish the reward pick"
	)
	fusion_state.update(1.0)
	_expect(
		fusion_state.active
		and fusion_state.purchase_absorption_effects.is_empty()
		and fusion_flow.finalize_calls == 0,
		"the final absorption frame must expose an empty board without finishing"
	)
	fusion_state.update(TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC - 0.01)
	_expect(fusion_state.active and fusion_flow.finalize_calls == 0, "empty reward board must remain visible for the full hold interval")
	fusion_state.update(0.01)
	_expect(fusion_state.active and fusion_flow.finalize_calls == 0, "hold completion must only schedule a next-frame finish")
	fusion_state.update(0.0)
	_expect(
		not fusion_state.active and fusion_flow.finalize_calls == 1 and _finish_calls == 1,
		"the frame after the empty-board hold must finalize exactly once"
	)

	var insufficient_flow := FakeFlowOwner.new()
	insufficient_flow.balances["muhon"] = 0
	var insufficient_registry := _build_registry(
		FakeRuntimeState.new(),
		FakeSkillConfig.new(),
		insufficient_flow
	)
	insufficient_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var insufficient_builder := FakeOfferBuilder.new()
	insufficient_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": "",
		"choices": [
			_card("training", "insufficient_1", 1),
			_card("mugong", "insufficient_2", 2),
			_card("fusion", "insufficient_3", 3),
			_card("supreme", "insufficient_4", 4),
		],
	}
	var insufficient_state := TowerRewardPickState.new()
	insufficient_state.set("_offer_builder", insufficient_builder)
	_expect(
		insufficient_state.start(FakeOwner.new(), insufficient_registry, Callable()),
		"insufficient-balance auto-finish fixture must start"
	)
	insufficient_state.update(TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC)
	_expect(insufficient_state.active and insufficient_flow.finalize_calls == 0, "unaffordable unspent cards must wait one deferred frame")
	insufficient_state.update(0.0)
	_expect(not insufficient_state.active and insufficient_flow.finalize_calls == 1, "zero affordable cards must auto-finish even when cards remain unspent")

	var affordable_flow := FakeFlowOwner.new()
	affordable_flow.balances["muhon"] = 1
	var affordable_registry := _build_registry(
		FakeRuntimeState.new(),
		FakeSkillConfig.new(),
		affordable_flow
	)
	affordable_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var affordable_state := TowerRewardPickState.new()
	affordable_state.set("_offer_builder", insufficient_builder)
	_expect(affordable_state.start(FakeOwner.new(), affordable_registry, Callable()), "affordable-card guard fixture must start")
	affordable_state.update(TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC * 3.0)
	affordable_state.update(0.0)
	_expect(affordable_state.active and affordable_flow.finalize_calls == 0, "any affordable unspent card must suppress auto-finish")
	affordable_state.reset()

	var rejected_flow := FakeFlowOwner.new()
	rejected_flow.balances["muhon"] = 0
	rejected_flow.finalize_result = {
		"accepted": false,
		"reason": "injected_finalize_rejection",
	}
	var rejected_registry := _build_registry(
		FakeRuntimeState.new(),
		FakeSkillConfig.new(),
		rejected_flow
	)
	rejected_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var rejected_state := TowerRewardPickState.new()
	rejected_state.set("_offer_builder", insufficient_builder)
	_expect(rejected_state.start(FakeOwner.new(), rejected_registry, Callable()), "auto-finish rejection fixture must start")
	rejected_state.update(TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC)
	rejected_state.update(0.0)
	for _frame in range(10):
		rejected_state.update(1.0 / 60.0)
	_expect(rejected_state.active and rejected_flow.finalize_calls == 1, "a rejected auto-finish transaction must latch after exactly one attempt")
	_expect(
		str(rejected_state.build_view_model().get("status_text", "")) == "injected_finalize_rejection",
		"a rejected auto-finish must surface its reason and leave manual Continue available"
	)
	rejected_state.reset()


func _verify_vision_purchase_and_continue_burn_semantics() -> void:
	_finish_calls = 0
	var runtime := FakeRuntimeState.new()
	var purchased_flow := FakeFlowOwner.new()
	purchased_flow.balances["muhon"] = 3
	var purchased_registry := _build_registry(runtime, FakeSkillConfig.new(), purchased_flow)
	purchased_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var purchased_builder := FakeOfferBuilder.new()
	var vision_id := TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_dalji")
	purchased_builder.offer = _vision_offer(vision_id)
	var purchased_state := TowerRewardPickState.new()
	purchased_state.set("_offer_builder", purchased_builder)
	_expect(purchased_state.start(FakeOwner.new(), purchased_registry, Callable(self, "_on_finish")), "Vision purchase fixture must start")
	purchased_state.call("_purchase", 0)
	_expect(purchased_state.spent_flags[0] and int(purchased_flow.balances.get("muhon", -1)) == 0, "Vision purchase must debit three Muhon and spend slot one")
	_expect(purchased_flow.burned_boss_ids == ["floor_01_dalji"], "purchased Vision must burn its boss reward immediately")

	var skipped_flow := FakeFlowOwner.new()
	var skipped_registry := _build_registry(FakeRuntimeState.new(), FakeSkillConfig.new(), skipped_flow)
	skipped_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var skipped_builder := FakeOfferBuilder.new()
	skipped_builder.offer = _vision_offer(vision_id)
	var skipped_state := TowerRewardPickState.new()
	skipped_state.set("_offer_builder", skipped_builder)
	_expect(skipped_state.start(FakeOwner.new(), skipped_registry, Callable(self, "_on_finish")), "Vision continue fixture must start")
	skipped_state.call("_finish")
	_expect(skipped_flow.burned_boss_ids == ["floor_01_dalji"], "continuing past an unbought Vision must burn the same boss reward")
	_expect(skipped_flow.finalize_calls == 1, "continue burn must finalize through one flow-owner transaction")


func _verify_full_slot_vision_swap_confirm_and_cancel() -> void:
	_finish_calls = 0
	var vision_id := TowerAscentBossRewardCatalog.get_vision_unlock_id("floor_01_dalji")
	var confirm_runtime := FakeRuntimeState.new()
	var confirm_flow := FakeFlowOwner.new()
	confirm_flow.balances["muhon"] = 3
	var confirm_registry := _build_registry(confirm_runtime, FakeSkillConfig.new(), confirm_flow)
	confirm_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var confirm_builder := FakeOfferBuilder.new()
	confirm_builder.offer = _vision_offer(vision_id)
	(confirm_builder.offer["choices"][0] as Dictionary)["vision_swap_required"] = true
	(confirm_builder.offer["choices"][0] as Dictionary)["vision_swap_candidates"] = ["drive"]
	var confirm_state := TowerRewardPickState.new()
	confirm_state.set("_offer_builder", confirm_builder)
	_expect(confirm_state.start(FakeOwner.new(), confirm_registry, Callable(self, "_on_finish")), "full-slot Vision confirmation fixture must start")
	confirm_state.call("_purchase", 0)
	_expect(confirm_state.is_external_modal_active(), "full-slot Vision purchase must enter the existing swap modal")
	_expect(int(confirm_flow.balances.get("muhon", -1)) == 3 and not confirm_state.spent_flags[0], "Vision swap must not debit or spend before confirmation")
	confirm_runtime.confirm_pending_unlock_swap()
	confirm_state.update(0.1)
	_expect(int(confirm_flow.balances.get("muhon", -1)) == 0 and confirm_state.spent_flags[0], "confirmed Vision swap must debit three and spend its stable slot")
	_expect(confirm_flow.burned_boss_ids == ["floor_01_dalji"], "confirmed Vision swap must burn the boss reward")
	_expect(confirm_flow.finalize_calls == 0, "the Vision-swap return frame must not finalize while its absorption is active")
	confirm_state.update(1.0)
	confirm_state.update(TowerAscentTuning.TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC)
	_expect(confirm_state.active and confirm_flow.finalize_calls == 0, "Vision-swap exhaustion must retain the deferred finish frame")
	confirm_state.update(0.0)
	_expect(not confirm_state.active and confirm_flow.finalize_calls == 1, "Vision-swap exhaustion must use the same one-shot auto-finish path")

	var cancel_runtime := FakeRuntimeState.new()
	var cancel_flow := FakeFlowOwner.new()
	cancel_flow.balances["muhon"] = 3
	var cancel_registry := _build_registry(cancel_runtime, FakeSkillConfig.new(), cancel_flow)
	cancel_registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	var cancel_builder := FakeOfferBuilder.new()
	cancel_builder.offer = _vision_offer(vision_id)
	(cancel_builder.offer["choices"][0] as Dictionary)["vision_swap_required"] = true
	(cancel_builder.offer["choices"][0] as Dictionary)["vision_swap_candidates"] = ["drive"]
	var cancel_state := TowerRewardPickState.new()
	cancel_state.set("_offer_builder", cancel_builder)
	_expect(cancel_state.start(FakeOwner.new(), cancel_registry, Callable(self, "_on_finish")), "full-slot Vision cancellation fixture must start")
	cancel_state.call("_purchase", 0)
	cancel_runtime.cancel_pending_unlock_swap()
	cancel_state.update(0.1)
	_expect(cancel_state.active and not cancel_state.spent_flags[0], "cancelled Vision swap must return to the same unspent reward screen")
	_expect(int(cancel_flow.balances.get("muhon", -1)) == 3 and cancel_flow.burned_boss_ids.is_empty(), "cancelled Vision swap must preserve balance and burn state")


func _verify_production_flow_transactions_and_burn_snapshot() -> void:
	_effect_calls = 0
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "reward-pick-transaction",
		"current_stage": 1,
		"map_seed": 919,
		"run_state": {"muhon": 7, "gold": 0, "chance_gems": 3},
	}), "production flow must prepare the reward-pick transaction fixture")
	var first := flow.apply_reward_pick_purchase(
		0,
		_card("training", "training_tx", 1),
		1,
		Callable(self, "_accept_effect")
	)
	_expect(bool(first.get("applied", false)) and _effect_calls == 1, "production transaction must apply the first card effect once")
	var duplicate := flow.apply_reward_pick_purchase(
		0,
		_card("training", "training_tx", 1),
		1,
		Callable(self, "_accept_effect")
	)
	_expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("applied", true)) and _effect_calls == 1, "stable slot resolution id must reject duplicate application without rerunning the effect")
	var rejected := flow.apply_reward_pick_purchase(
		1,
		_card("mugong", "mugong_rejected", 2),
		2,
		Callable(self, "_reject_effect")
	)
	_expect(not bool(rejected.get("accepted", true)) and int(flow.get_run_state_snapshot().get("muhon", -1)) == 6, "rejected effects must not debit the run-local balance")
	var second := flow.apply_reward_pick_purchase(
		1,
		_card("mugong", "mugong_tx", 2),
		2,
		Callable(self, "_accept_effect")
	)
	_expect(bool(second.get("applied", false)) and int(flow.get_run_state_snapshot().get("muhon", -1)) == 4, "a second stable slot must remain independently purchasable")
	var chosik := flow.apply_reward_pick_purchase(
		2,
		_card(
			"chosik",
			"unlock_ghost_shot",
			TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
		),
		TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
		Callable(self, "_accept_effect")
	)
	var reward_history: Array = flow.get_reward_pick_history()
	var chosik_record: Dictionary = reward_history[2] if reward_history.size() > 2 else {}
	_expect(bool(chosik.get("applied", false)) and int(flow.get_run_state_snapshot().get("muhon", -1)) == 0, "production transaction must accept an open-slot Chosik reward")
	_expect(
		reward_history.size() == 3
		and str(chosik_record.get("choice_kind", "")) == "chosik",
		"production flow must journal a committed reward Chosik with its own kind"
	)
	_expect(
		int(chosik_record.get("cost", -1))
		== TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
		"production reward history must journal the exact shared four-Muhon debit"
	)
	var insufficient_effect_calls := _effect_calls
	var insufficient_flow := TowerAscentFlowOwner.new()
	_expect(insufficient_flow.prepare_vertical_slice_combat(FakeOwner.new(), {
		"run_id": "reward-pick-chosik-insufficient",
		"current_stage": 1,
		"map_seed": 920,
		"run_state": {"muhon": 3, "gold": 0, "chance_gems": 3},
	}), "three-Muhon direct rejection fixture must prepare production flow")
	var insufficient_chosik := insufficient_flow.apply_reward_pick_purchase(
		0,
		_card(
			"chosik",
			"unlock_ghost_shot",
			TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
		),
		TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
		Callable(self, "_accept_effect")
	)
	_expect(
		not bool(insufficient_chosik.get("accepted", true))
		and str(insufficient_chosik.get("reason", "")) == "insufficient_muhon"
		and int(insufficient_flow.get_run_state_snapshot().get("muhon", -1)) == 3
		and insufficient_flow.get_reward_pick_history().is_empty()
		and _effect_calls == insufficient_effect_calls,
		"production reward purchase must reject three Muhon before grant, debit, or history"
	)
	_expect(flow.mark_reward_pick_vision_burned("floor_01_dalji"), "production flow must burn an eligible boss Vision")
	var snapshot: Dictionary = flow.export_snapshot()
	_expect((snapshot.get("run_progress", {}) as Dictionary).get("burned_vision_boss_ids", []) == ["floor_01_dalji"], "flow snapshot must carry the burned boss-Vision set")
	_expect((snapshot.get("reward_pick_history", []) as Array).size() == 3, "flow snapshot must carry committed reward-pick history")

	var run_state := TowerAscentRunState.new()
	_expect(run_state.restore_snapshot(snapshot), "current reward-pick snapshot schema must restore")
	_expect(run_state.get_burned_vision_boss_ids() == ["floor_01_dalji"], "restored run state must preserve burned boss Visions")
	var schema_eight := snapshot.duplicate(true)
	schema_eight["schema_version"] = TowerAscentRunState.PRE_VISION_BURN_SCHEMA_VERSION
	(schema_eight["run_progress"] as Dictionary).erase("burned_vision_boss_ids")
	var legacy_run_state := TowerAscentRunState.new()
	_expect(legacy_run_state.restore_snapshot(schema_eight), "schema-eight tower snapshots must remain backward compatible")
	_expect(legacy_run_state.get_burned_vision_boss_ids().is_empty(), "schema-eight restore must initialize an empty burned-Vision set")


func _verify_victory_highlight_reward_pick_route_sequence() -> void:
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
	var loot := VictoryLootPhaseState.new()
	registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
	registry.instances["scoreboard_state"] = FakeScoreboard.new()
	registry.instances["victory_loot_phase_state"] = loot
	var driver := BattleSceneMatchFlowDriver.new()
	var started: bool = bool(driver.call(
		"_try_start_victory_presentation",
		registry,
		FakeOwner.new(),
		Callable()
	))
	_expect(bool(started), "victory-highlight completion must start the production victory-loot owner")
	_expect(flow.prepare_calls == 1, "victory presentation must prepare the tower combat resolution once")
	_expect(flow.margin_reward_calls == 1, "victory presentation must apply the measured score margin before reward-pick open")
	_expect(loot.is_reward_pick_active(), "flag ON must replace the chest phase with the four-card reward pick")
	var opening_model: Dictionary = (loot.get("_reward_pick_state") as Object).build_view_model()
	_expect(str(opening_model.get("balance_text", "")) == "무혼 : 14개", "reward-pick opening balance must include the +4 victory margin")
	_expect(str(opening_model.get("acquisition_text", "")) == "무혼 +4 (점수차 보상)", "reward-pick header must show the localized victory-margin acquisition line")
	_expect(flow.begin_calls == 0, "route serving must wait until the reward pick is continued")
	var reward_state: Object = loot.get("_reward_pick_state")
	reward_state.call("_finish")
	_expect(not loot.is_active(), "continuing the reward pick must close the victory-loot owner")
	_expect(flow.begin_calls == 1, "reward completion must begin route serving exactly once, got %d" % flow.begin_calls)
	_expect(flow.get_phase_name() == "ROUTE_AIM", "reward completion must enter ROUTE_AIM, got %s" % flow.get_phase_name())


func _verify_f9_debug_path_still_enters_reward_pick() -> void:
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	var registry := _build_registry(runtime, FakeSkillConfig.new(), flow)
	var loot := VictoryLootPhaseState.new()
	registry.instances["runtime_perk_overlay_renderer"] = FakeCardRenderer.new()
	registry.instances["runtime_perk_icon_renderer"] = FakeIconRenderer.new()
	registry.instances["scoreboard_state"] = FakeScoreboard.new()
	registry.instances["victory_loot_phase_state"] = loot
	var started := BattleSceneMatchFlowDriver.new().start_debug_tower_reward_pick(
		FakeOwner.new(),
		registry,
		Callable()
	)
	_expect(started, "F9 debug transition must enter the same production reward-pick owner")
	_expect(flow.prepare_calls == 1 and loot.is_reward_pick_active(), "F9 must prepare combat and stop at reward pick instead of bypassing it")
	_expect(flow.begin_calls == 0, "F9 must not begin route serving before reward-pick continue")
	loot.reset()


func _build_registry(runtime: Object, skill_config: Object, flow: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": FakeCatalog.new(),
		"smasher_skill_config": skill_config,
		TowerAscentUnlockFilter.STORE_KEY: FakeUnlockStore.new(),
	}
	if flow != null:
		registry.instances["tower_ascent_flow_owner"] = flow
	return registry


func _vision_offer(vision_id: String) -> Dictionary:
	return {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": vision_id,
		"choices": [
			{
				"id": vision_id,
				"boss_slot_id": "floor_01_dalji",
				"reward_pick_kind": "vision",
				"reward_pick_cost": 3,
			},
			_card("training", "training_filler", 99),
			_card("mugong", "mugong_filler", 99),
			_card("supreme", "supreme_filler", 99),
		],
	}


func _card(kind: String, choice_id: String, cost: int) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"reward_pick_kind": kind,
		"reward_pick_cost": cost,
	}


func _reward_perk_card(
	catalog: Object,
	perk_id: String,
	kind: String,
	cost: int
) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(perk_id)
	choice["id"] = perk_id
	choice["reward_pick_kind"] = kind
	choice["reward_pick_cost"] = cost
	return choice


func _five_slot_levels() -> Dictionary:
	return {
		"dash_acceleration": 1,
		"item_luck": 1,
		"item_gauge_mastery": 1,
		"item_caffeine": 1,
		"item_polish": 1,
	}


func _unique_choice_count(choices: Array) -> int:
	var ids: Dictionary = {}
	for value in choices:
		if value is Dictionary:
			ids[str((value as Dictionary).get("id", ""))] = true
	return ids.size()


func _count_kind(choices: Array, kind: String) -> int:
	var count := 0
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("reward_pick_kind", "")) == kind:
			count += 1
	return count


func _increment_composition(counts: Dictionary, choices: Array) -> void:
	var kinds: Array[String] = []
	for value: Variant in choices:
		if value is Dictionary:
			kinds.append(str((value as Dictionary).get("reward_pick_kind", "unknown")))
	kinds.sort()
	var key := "+".join(kinds)
	counts[key] = int(counts.get(key, 0)) + 1


func _on_finish() -> void:
	_finish_calls += 1


func _accept_effect() -> bool:
	_effect_calls += 1
	return true


func _reject_effect() -> bool:
	_effect_calls += 1
	return false


func _extract_function_source(source: String, header: String) -> String:
	var start := source.find(header)
	if start < 0:
		return ""
	var next_instance := source.find("\nfunc ", start + header.length())
	var next_static := source.find("\nstatic func ", start + header.length())
	var next := next_instance
	if next < 0 or (next_static >= 0 and next_static < next):
		next = next_static
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _extract_call_source(source: String, call_header: String) -> String:
	var start := source.find(call_header)
	if start < 0:
		return ""
	var depth := 0
	for offset in range(start, source.length()):
		var character := source.substr(offset, 1)
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return source.substr(start, offset - start + 1)
	return ""


func _find_entry_index_by_flag(entries: Array, flag: String) -> int:
	for index in range(entries.size()):
		var entry_value: Variant = entries[index]
		if entry_value is Dictionary and bool((entry_value as Dictionary).get(flag, false)):
			return index
	return -1


func _find_entry_indices_by_flag(entries: Array, flag: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(entries.size()):
		var entry_value: Variant = entries[index]
		if entry_value is Dictionary and bool((entry_value as Dictionary).get(flag, false)):
			result.append(index)
	return result


func _find_entry_index_by_id(entries: Array, entry_id: String) -> int:
	for index in range(entries.size()):
		var entry_value: Variant = entries[index]
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == entry_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	_expect(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])
