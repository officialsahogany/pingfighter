extends SceneTree

const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
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
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


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
	var physique_training := {"power": 1}

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
		return ["mugong_a", "mugong_b"]

	func get_downtown_treasure_map_mythic_multiplier() -> float:
		return 1.0

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

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return [
			{"id": "common_expansion", "name": "Retired Expansion", "max_level": 5},
			{"id": "mugong_a", "name": "Mugong A", "max_level": 5},
			{"id": "mugong_b", "name": "Mugong B", "max_level": 5},
			{"id": "mugong_c", "name": "Mugong C", "max_level": 5},
		]

	func has_open_perk_slot(_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_data(perk_id: String) -> Dictionary:
		return {
			"id": perk_id,
			"name": "Peerless %s" % perk_id,
			"max_level": 1,
		}

	func get_perk_slot_status(runtime_levels: Dictionary, _slot_context: Object = null) -> Dictionary:
		slot_status_calls += 1
		return {
			"count": runtime_levels.size(),
			"limit": 6,
			"is_full": runtime_levels.size() >= 6,
		}


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
		rollback_callback: Callable = Callable()
	) -> Dictionary:
		var resolution_id := "slot_%d" % slot_index
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
		_roll_overrides: Dictionary = {}
	) -> Dictionary:
		return offer.duplicate(true)


class FakeScoreboard:
	extends RefCounted

	func get_player_points() -> int:
		return 7

	func get_boss_points() -> int:
		return 3


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_seven_locale_copy_contract()
	_verify_reward_balance_row_budget()
	_verify_flag_on_training_candidates_exclude_retired_expansion()
	_verify_offer_order_eligibility_and_prices()
	_verify_stable_four_card_multi_buy_and_fusion_return()
	_verify_fullscreen_stats_ledger_hover_and_cache_contract()
	_verify_unaffordable_board_auto_finish_and_failure_latch()
	_verify_vision_purchase_and_continue_burn_semantics()
	_verify_full_slot_vision_swap_confirm_and_cancel()
	_verify_production_flow_transactions_and_burn_snapshot()
	_verify_victory_highlight_reward_pick_route_sequence()
	_verify_f9_debug_path_still_enters_reward_pick()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
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
	var mugong_choices: Array = offer.get("mugong_choices", [])
	_expect(mugong_choices.size() == 3, "mixed reward source must retain three eligible Mugong choices")
	for choice_value in mugong_choices:
		if choice_value is Dictionary:
			_expect(
				str((choice_value as Dictionary).get("id", "")) != "common_expansion",
				"retired common_expansion leaked into a tower reward candidate"
			)


func _verify_offer_order_eligibility_and_prices() -> void:
	_expect(TowerRewardPickOfferBuilder.TEMP_TRAINING_COST == 1, "training reward card must cost one Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_MUGONG_COST == 2, "Mugong reward card must cost two Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_DASH_AMPLIFICATION_COST == 3, "Glide Orb reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_FUSION_COST == 3, "fusion reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_VISION_COST == 3, "Vision reward card must cost three Muhon")
	_expect(TowerRewardPickOfferBuilder.TEMP_SUPREME_COST == 5, "Peerless reward card must cost five Muhon")
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
	var offer: Dictionary = builder.build_offer(context, FakeOwner.new(), registry, {"supreme": 0.0})
	_expect(bool(offer.get("accepted", false)), "eligible reward pick must generate")
	var choices: Array = offer.get("choices", [])
	_expect(choices.size() == 4, "reward pick must materialize exactly four cards")
	_expect(str((choices[0] as Dictionary).get("reward_pick_kind", "")) == "vision", "eligible Vision must reserve slot one")
	_expect(str((choices[1] as Dictionary).get("reward_pick_kind", "")) == "supreme", "forced Peerless roll must use the remaining probability lane")
	_expect(_unique_choice_count(choices) == 4, "one reward pick must not duplicate card ids")
	_expect(_count_kind(choices, "active") == 0, "active items must never enter the reward-card pool")
	var repeated: Dictionary = builder.build_offer(context, FakeOwner.new(), registry, {"supreme": 0.0})
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
	var full_offer: Dictionary = builder.build_offer(full_context, FakeOwner.new(), registry, {"supreme": 1.0})
	var full_choice: Dictionary = (full_offer.get("choices", []) as Array)[0]
	_expect(bool(full_choice.get("vision_swap_required", false)), "full Chosik slots must keep Vision eligible through a swap route")
	_expect(not (full_choice.get("vision_swap_candidates", []) as Array).is_empty(), "full-slot Vision card must carry explicit swap candidates")


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
	state.call("_purchase", 0)
	state.update(0.016)
	_expect(catalog.slot_status_calls == 2, "a committed purchase must invalidate and refresh slot status once")

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
		"run_state": {"muhon": 6, "gold": 0, "chance_gems": 3},
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
	_expect(not bool(rejected.get("accepted", true)) and int(flow.get_run_state_snapshot().get("muhon", -1)) == 5, "rejected effects must not debit the run-local balance")
	var second := flow.apply_reward_pick_purchase(
		1,
		_card("mugong", "mugong_tx", 2),
		2,
		Callable(self, "_accept_effect")
	)
	_expect(bool(second.get("applied", false)) and int(flow.get_run_state_snapshot().get("muhon", -1)) == 3, "a second stable slot must remain independently purchasable")
	_expect(flow.get_reward_pick_history().size() == 2, "production flow must journal only committed reward cards")
	_expect(flow.mark_reward_pick_vision_burned("floor_01_dalji"), "production flow must burn an eligible boss Vision")
	var snapshot: Dictionary = flow.export_snapshot()
	_expect((snapshot.get("run_progress", {}) as Dictionary).get("burned_vision_boss_ids", []) == ["floor_01_dalji"], "flow snapshot must carry the burned boss-Vision set")
	_expect((snapshot.get("reward_pick_history", []) as Array).size() == 2, "flow snapshot must carry committed reward-pick history")

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
	_expect(loot.is_reward_pick_active(), "flag ON must replace the chest phase with the four-card reward pick")
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


func _on_finish() -> void:
	_finish_calls += 1


func _accept_effect() -> bool:
	_effect_calls += 1
	return true


func _reject_effect() -> bool:
	_effect_calls += 1
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
