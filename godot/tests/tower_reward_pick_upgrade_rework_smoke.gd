extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const RuntimePerkOverflowDescriptions := preload(
	"res://scripts/characters/runtime_perk_overflow_descriptions.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)

const VIEW_SIZE := Vector2(2020.0, 1246.0)
const BOSS_SLOT_ID := "floor_01_dalji"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"stage1_boss_variant": "dalji",
		"stage_boss_variant": "",
		"starting_dash_tokens": 1,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_pos": Vector2(302.5, 700.0),
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class GenerationOfferBuilder:
	extends RefCounted

	var offers: Dictionary = {}
	var generation_calls: Array[int] = []

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {},
		reroll_counter: int = 0
	) -> Dictionary:
		generation_calls.append(reroll_counter)
		var value: Variant = offers.get(reroll_counter, {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}


class FakeFlowOwner:
	extends RefCounted

	var context: Dictionary = {
		"node_resolution_id": "reward-pick-upgrade-rework",
		"boss_slot_id": BOSS_SLOT_ID,
	}
	var balances: Dictionary = {"muhon": 30, "gold": 0, "chance_gems": 3}
	var committed_ids: Dictionary = {}
	var purchase_ids: Array[String] = []
	var purchase_generations: Array[int] = []
	var upgrade_costs: Array[int] = []
	var upgrade_targets: Array[int] = []
	var finalize_vision_ids: Array[String] = []
	var burned_vision_ids: Array[String] = []
	var reward_session := 0
	var reject_next_upgrade_after_effect := false
	var reject_next_purchase_after_effect := false

	func begin_new_reward_session() -> void:
		reward_session += 1

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
		var generation := maxi(0, offer_generation)
		var resolution_id := "session_%d:generation_%d:slot_%d" % [
			reward_session,
			generation,
			slot_index,
		]
		if committed_ids.has(resolution_id):
			return {
				"accepted": true,
				"applied": false,
				"reason": "already_committed",
			}
		if int(balances.get("muhon", 0)) < cost:
			return {
				"accepted": false,
				"applied": false,
				"reason": "insufficient_muhon",
			}
		if not effect_callback.is_valid() or not bool(effect_callback.call()):
			return {
				"accepted": false,
				"applied": false,
				"reason": "effect_rejected",
			}
		if reject_next_purchase_after_effect:
			reject_next_purchase_after_effect = false
			if rollback_callback.is_valid():
				rollback_callback.call()
			return {
				"accepted": false,
				"applied": false,
				"reason": "injected_debit_rejection",
			}
		balances["muhon"] = int(balances.get("muhon", 0)) - cost
		committed_ids[resolution_id] = true
		purchase_ids.append(resolution_id)
		purchase_generations.append(generation)
		return {
			"accepted": true,
			"applied": true,
			"reason": "committed",
			"node_resolution_id": resolution_id,
		}

	func apply_reward_pick_upgrade(
		upgrade_sequence: int,
		_choice: Dictionary,
		target_level: int,
		cost: int,
		effect_callback: Callable,
		rollback_callback: Callable = Callable()
	) -> Dictionary:
		upgrade_costs.append(cost)
		upgrade_targets.append(target_level)
		var resolution_id := "session_%d:upgrade_%d" % [reward_session, upgrade_sequence]
		if committed_ids.has(resolution_id):
			return {
				"accepted": true,
				"applied": false,
				"reason": "already_committed",
			}
		if int(balances.get("muhon", 0)) < cost:
			return {
				"accepted": false,
				"applied": false,
				"reason": "insufficient_muhon",
			}
		if not effect_callback.is_valid() or not bool(effect_callback.call()):
			return {
				"accepted": false,
				"applied": false,
				"reason": "effect_rejected",
			}
		if reject_next_upgrade_after_effect:
			reject_next_upgrade_after_effect = false
			if rollback_callback.is_valid():
				rollback_callback.call()
			return {
				"accepted": false,
				"applied": false,
				"reason": "injected_debit_rejection",
			}
		balances["muhon"] = int(balances.get("muhon", 0)) - cost
		committed_ids[resolution_id] = true
		return {
			"accepted": true,
			"applied": true,
			"reason": "committed",
			"node_resolution_id": resolution_id,
		}

	func finalize_reward_pick(vision_boss_slot_id: String = "") -> Dictionary:
		finalize_vision_ids.append(vision_boss_slot_id)
		return {"accepted": true, "applied": true, "reason": "committed"}

	func mark_reward_pick_vision_burned(boss_slot_id: String) -> Dictionary:
		if not boss_slot_id.is_empty() and boss_slot_id not in burned_vision_ids:
			burned_vision_ids.append(boss_slot_id)
		return {"accepted": true}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_shared_status_click_upgrade_and_session_costs()
	_verify_upgrade_debit_rejection_rolls_back()
	_verify_refresh_generation_and_sticky_vision()
	_verify_full_slot_replacement_cancel_success_and_failure()
	_verify_production_flow_generation_transaction_ids()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_reward_pick_upgrade_rework_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_shared_status_click_upgrade_and_session_costs() -> void:
	var runtime: Object = RuntimePerkState.new()
	runtime.runtime_skill_levels = {
		"common_bulk_up": 2,
		"common_swiftness": 1,
	}
	runtime.item_perk_level_bonus = 1
	var catalog: Object = RuntimePerkCatalog.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 30
	var builder := GenerationOfferBuilder.new()
	builder.offers[0] = _offer([
		_card("bag_expansion", "tower_bag_expansion", 99),
	], 0)
	var registry := _registry(runtime, catalog, renderer, flow)
	var state: Object = TowerRewardPickState.new()
	state.set("_offer_builder", builder)
	_expect(
		state.start(FakeOwner.new(), registry, Callable()),
		"upgrade fixture must start through the production reward-pick state"
	)
	var bulk_cell := _find_status_cell(state, "common_bulk_up")
	_expect(not bulk_cell.is_empty(), "the shared painted status model must expose owned common_bulk_up")
	_click_status_cell(state, bulk_cell)
	var modal := _inline_modal(state)
	_expect(str(modal.get("kind", "")) == "upgrade", "clicking the painted owned cell must open the upgrade modal")
	_expect(
		int(modal.get("base_level", 0)) == 2
		and int(modal.get("max_level", 0)) == 5
		and (modal.get("cards", []) as Array).size() == 2,
		"default upgrade comparison must show current rank two and next rank three from the live catalog"
	)
	var comparison_cards: Array = modal.get("cards", []) as Array
	var bulk_data: Dictionary = catalog.get_perk_data("common_bulk_up")
	var bulk_descriptions: Dictionary = bulk_data.get("descriptions", {})
	var expected_current := RuntimePerkOverflowDescriptions.resolve_stats_text(
		"common_bulk_up",
		bulk_descriptions,
		3
	)
	var expected_next := RuntimePerkOverflowDescriptions.resolve_stats_text(
		"common_bulk_up",
		bulk_descriptions,
		4
	)
	_expect(
		int((comparison_cards[0] as Dictionary).get("display_level", 0)) == 3
		and str((comparison_cards[0] as Dictionary).get("description", "")) == expected_current
		and str((comparison_cards[0] as Dictionary).get("previous_description", "")).is_empty()
		and int((comparison_cards[1] as Dictionary).get("display_level", 0)) == 4
		and str((comparison_cards[1] as Dictionary).get("description", "")) == expected_next
		and str((comparison_cards[1] as Dictionary).get("previous_description", "")) == expected_current,
		"comparison cards must pair effective-rank labels with matching values and reserve deltas for the future card"
	)
	_click_upgrade_layout_action(state, modal, "checkbox_rect")
	modal = _inline_modal(state)
	var all_level_cards: Array = modal.get("cards", []) as Array
	_expect(
		bool(modal.get("show_all_levels", false))
		and all_level_cards.size() == 5
		and int((all_level_cards[0] as Dictionary).get("display_level", 0)) == 2
		and int((all_level_cards[4] as Dictionary).get("display_level", 0)) == 6,
		"all-level mode must derive all five cards dynamically from catalog max_level"
	)
	for _index in range(3):
		_press_key(state, KEY_ENTER)
	_expect(
		flow.upgrade_costs == [3, 4, 5]
		and flow.upgrade_targets == [3, 4, 5],
		"three successful in-session upgrades must cost 3, 4, 5 and target ranks 3, 4, 5"
	)
	_expect(
		int(runtime.runtime_skill_levels.get("common_bulk_up", 0)) == 5
		and int(flow.balances.get("muhon", -1)) == 18,
		"successful upgrades must commit the exact target rank and debit twelve Muhon total"
	)
	modal = _inline_modal(state)
	_expect(
		not bool(modal.get("has_next_level", true))
		and not bool(modal.get("confirm_enabled", true)),
		"maximum rank must remain inspectable but read-only"
	)
	_click_upgrade_layout_action(state, modal, "checkbox_rect")
	modal = _inline_modal(state)
	_expect(
		(modal.get("cards", []) as Array).size() == 1,
		"maximum-rank comparison mode must collapse to the single current card"
	)
	state.reset()
	flow.begin_new_reward_session()
	var second_state: Object = TowerRewardPickState.new()
	second_state.set("_offer_builder", builder)
	_expect(
		second_state.start(FakeOwner.new(), registry, Callable()),
		"the next reward session must reopen against the retained run state"
	)
	var swiftness_cell := _find_status_cell(second_state, "common_swiftness")
	_click_status_cell(second_state, swiftness_cell)
	var next_session_modal := _inline_modal(second_state)
	_expect(
		int(next_session_modal.get("cost", -1)) == 3,
		"upgrade cost must reset to three when the next reward-pick session starts"
	)
	second_state.reset()


func _verify_upgrade_debit_rejection_rolls_back() -> void:
	var runtime: Object = RuntimePerkState.new()
	runtime.runtime_skill_levels = {"common_bulk_up": 2}
	var catalog: Object = RuntimePerkCatalog.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 10
	flow.reject_next_upgrade_after_effect = true
	var builder := GenerationOfferBuilder.new()
	builder.offers[0] = _offer([_card("bag_expansion", "tower_bag_expansion", 99)], 0)
	var state: Object = TowerRewardPickState.new()
	state.set("_offer_builder", builder)
	var registry := _registry(runtime, catalog, renderer, flow)
	_expect(state.start(FakeOwner.new(), registry, Callable()), "upgrade rollback fixture must start")
	_click_status_cell(state, _find_status_cell(state, "common_bulk_up"))
	_press_key(state, KEY_ENTER)
	_expect(
		int(runtime.runtime_skill_levels.get("common_bulk_up", 0)) == 2
		and int(flow.balances.get("muhon", -1)) == 10,
		"a debit rejection after the upgrade effect must restore both rank and balance"
	)
	_expect(
		str(_inline_modal(state).get("kind", "")) == "upgrade"
		and str(state.build_view_model(VIEW_SIZE).get("status_text", "")) == "injected_debit_rejection",
		"failed upgrade transaction must stay in the modal and surface its rejection reason"
	)
	var calls_before_insufficient := flow.upgrade_costs.size()
	flow.balances["muhon"] = 2
	_press_key(state, KEY_ENTER)
	_expect(
		flow.upgrade_costs.size() == calls_before_insufficient
		and int(runtime.runtime_skill_levels.get("common_bulk_up", 0)) == 2,
		"an insufficient balance must reject before invoking or mutating the upgrade transaction"
	)
	state.reset()


func _verify_refresh_generation_and_sticky_vision() -> void:
	var runtime: Object = RuntimePerkState.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 10
	var builder := GenerationOfferBuilder.new()
	builder.offers[0] = _offer([
		_card("refresh", "common_refresh", 1),
		_card("vision", "vision_unbought", 3),
	], 0, "vision_unbought")
	builder.offers[1] = _offer([
		_card("bag_expansion", "tower_bag_expansion", 2),
		_card("mugong", "common_bulk_up", 99),
	], 1)
	var state: Object = TowerRewardPickState.new()
	state.set("_offer_builder", builder)
	var registry := _registry(runtime, catalog, renderer, flow)
	_expect(state.start(FakeOwner.new(), registry, Callable()), "refresh fixture must start")
	state.call("_purchase", 0, VIEW_SIZE)
	_expect(
		builder.generation_calls == [0, 1]
		and int((state.choices[0] as Dictionary).get("reward_pick_offer_generation", -1)) == 1,
		"refresh must deterministically request and install the next numbered generation"
	)
	state.call("_purchase", 0, VIEW_SIZE)
	_expect(
		flow.purchase_generations == [0, 1]
		and flow.purchase_ids.size() == 2
		and flow.purchase_ids[0] != flow.purchase_ids[1],
		"the same visible slot must use distinct generation-zero and reroll-one transaction IDs"
	)
	_expect(
		runtime.get_tower_bag_expansion_count() == 1
		and int(flow.balances.get("muhon", -1)) == 7,
		"the refreshed generation card must remain purchasable and debit independently"
	)
	state.call("_finish")
	_expect(
		flow.finalize_vision_ids == [BOSS_SLOT_ID],
		"refreshing away an offered Vision must retain the original boss burn identity until Continue"
	)


func _verify_full_slot_replacement_cancel_success_and_failure() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var initial_levels := _full_slot_levels()
	var replacement_choice := _catalog_reward_choice(catalog, "item_recycle", "mugong", 2)
	var builder := GenerationOfferBuilder.new()
	builder.offers[0] = _offer([replacement_choice], 0)

	var runtime: Object = RuntimePerkState.new()
	runtime.runtime_skill_levels = initial_levels.duplicate(true)
	var flow := FakeFlowOwner.new()
	flow.balances["muhon"] = 8
	var registry := _registry(runtime, catalog, renderer, flow)
	var state: Object = TowerRewardPickState.new()
	state.set("_offer_builder", builder)
	_expect(state.start(FakeOwner.new(), registry, Callable()), "replacement fixture must start")
	_click_reward_card(state, 0)
	var modal := _inline_modal(state)
	_expect(
		str(modal.get("kind", "")) == "mugong_replace"
		and not (modal.get("candidates", []) as Array).is_empty(),
		"a new Mugong at full capacity must open replacement against live shared status cells"
	)
	_press_key(state, KEY_ESCAPE)
	_expect(
		_inline_modal(state).is_empty()
		and runtime.runtime_skill_levels == initial_levels
		and int(flow.balances.get("muhon", -1)) == 8
		and not state.spent_flags[0],
		"replacement cancel must preserve ownership, balance, and the unspent reward card"
	)
	_click_reward_card(state, 0)
	modal = _inline_modal(state)
	var selected_candidate := ((modal.get("candidates", []) as Array)[0] as Dictionary)
	var selected_target := str(selected_candidate.get("canonical_id", ""))
	_press_key(state, KEY_ENTER)
	_expect(
		int(runtime.runtime_skill_levels.get("item_recycle", 0)) == 1
		and int(flow.balances.get("muhon", -1)) == 6
		and state.spent_flags[0],
		"replacement confirmation must atomically acquire the new Mugong, debit, and spend the card"
	)
	_expect(
		_count_owned_levels(runtime.runtime_skill_levels) == 6
		and (
			not runtime.runtime_skill_levels.has(selected_target)
			or int(runtime.runtime_skill_levels.get(selected_target, 0))
			< int(initial_levels.get(selected_target, 0))
		),
		"replacement confirmation must remove exactly the selected occupied cell while retaining 6/6 occupancy"
	)
	state.reset()

	var failing_runtime: Object = RuntimePerkState.new()
	failing_runtime.runtime_skill_levels = initial_levels.duplicate(true)
	var failing_flow := FakeFlowOwner.new()
	failing_flow.balances["muhon"] = 8
	failing_flow.reject_next_purchase_after_effect = true
	var failing_registry := _registry(failing_runtime, catalog, renderer, failing_flow)
	var failing_state: Object = TowerRewardPickState.new()
	failing_state.set("_offer_builder", builder)
	_expect(
		failing_state.start(FakeOwner.new(), failing_registry, Callable()),
		"replacement debit-rejection fixture must start"
	)
	_click_reward_card(failing_state, 0)
	_press_key(failing_state, KEY_ENTER)
	_expect(
		failing_runtime.runtime_skill_levels == initial_levels
		and int(failing_flow.balances.get("muhon", -1)) == 8
		and not failing_state.spent_flags[0],
		"a post-effect replacement debit failure must restore the exact pre-click ownership and balance"
	)
	_expect(
		str(_inline_modal(failing_state).get("kind", "")) == "mugong_replace"
		and str(failing_state.build_view_model(VIEW_SIZE).get("status_text", "")) == "injected_debit_rejection",
		"failed replacement must remain cancellable in the same modal with an explicit reason"
	)
	failing_state.reset()


func _verify_production_flow_generation_transaction_ids() -> void:
	var flow: Object = TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	_expect(
		flow.prepare_vertical_slice_combat(owner, {
			"run_id": "reward-pick-generation-transaction",
			"current_stage": 1,
			"map_seed": 1616,
			"run_state": {"muhon": 4, "gold": 0, "chance_gems": 3},
		}),
		"production flow must prepare the generation transaction fixture"
	)
	var first: Dictionary = flow.apply_reward_pick_purchase(
		0,
		_card("refresh", "common_refresh", 1),
		1,
		Callable(self, "_accept_effect"),
		Callable(),
		0
	)
	var rerolled: Dictionary = flow.apply_reward_pick_purchase(
		0,
		_card("bag_expansion", "tower_bag_expansion", 2),
		2,
		Callable(self, "_accept_effect"),
		Callable(),
		1
	)
	var history: Array = flow.get_reward_pick_history()
	_expect(
		bool(first.get("applied", false))
		and bool(rerolled.get("applied", false))
		and history.size() == 2,
		"production economy owner must commit both same-slot generations"
	)
	var first_id := str((history[0] as Dictionary).get("node_resolution_id", ""))
	var rerolled_id := str((history[1] as Dictionary).get("node_resolution_id", ""))
	_expect(
		first_id.ends_with(":reward_pick:slot_0")
		and rerolled_id.ends_with(":reward_pick:reroll_1:slot_0")
		and first_id != rerolled_id,
		"production transaction IDs must domain-separate generation zero from reroll one"
	)


func _registry(
	runtime: Object,
	catalog: Object,
	renderer: Object,
	flow: Object
) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"runtime_perk_overlay_renderer": renderer,
		"tower_ascent_flow_owner": flow,
	}
	return registry


func _offer(
	choice_values: Array,
	generation: int,
	vision_unlock_id: String = ""
) -> Dictionary:
	var choices: Array[Dictionary] = []
	for choice_value: Variant in choice_values:
		if not (choice_value is Dictionary):
			continue
		var choice := (choice_value as Dictionary).duplicate(true)
		choice["reward_pick_offer_generation"] = generation
		choices.append(choice)
	return {
		"accepted": true,
		"boss_slot_id": BOSS_SLOT_ID,
		"vision_unlock_id": vision_unlock_id,
		"offer_generation": generation,
		"choices": choices,
	}


func _card(kind: String, choice_id: String, cost: int) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"reward_pick_kind": kind,
		"reward_pick_cost": cost,
		"is_instant": kind in ["refresh", "bag_expansion"],
	}


func _catalog_reward_choice(
	catalog: Object,
	perk_id: String,
	kind: String,
	cost: int
) -> Dictionary:
	var choice_value: Variant = catalog.call("get_perk_data", perk_id)
	var choice: Dictionary = (
		(choice_value as Dictionary).duplicate(true)
		if choice_value is Dictionary
		else {}
	)
	choice["id"] = perk_id
	choice["reward_pick_kind"] = kind
	choice["reward_pick_cost"] = cost
	return choice


func _full_slot_levels() -> Dictionary:
	return {
		"common_swiftness": 2,
		"common_bulk_up": 1,
		"item_luck": 1,
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
	}


func _find_status_cell(state: Object, canonical_id: String) -> Dictionary:
	var model_value: Variant = state.call("_get_status_interaction_model", VIEW_SIZE)
	var model: Dictionary = model_value if model_value is Dictionary else {}
	var cells_value: Variant = model.get("cells", [])
	var cells: Array = cells_value if cells_value is Array else []
	for cell_value: Variant in cells:
		if cell_value is Dictionary and str((cell_value as Dictionary).get(
			"canonical_id",
			""
		)) == canonical_id:
			return (cell_value as Dictionary).duplicate(true)
	return {}


func _click_status_cell(state: Object, cell: Dictionary) -> void:
	var rect_value: Variant = cell.get("rect", Rect2())
	if not (rect_value is Rect2) or not (rect_value as Rect2).has_area():
		return
	_click_at(state, (rect_value as Rect2).get_center())


func _click_reward_card(state: Object, index: int) -> void:
	state.update(1.0)
	var rects: Array = state.get_card_rects(VIEW_SIZE)
	if index < 0 or index >= rects.size() or not (rects[index] is Rect2):
		return
	_click_at(state, (rects[index] as Rect2).get_center())


func _click_upgrade_layout_action(
	state: Object,
	modal: Dictionary,
	rect_key: String
) -> void:
	var layout_value: Variant = modal.get("layout", {})
	var layout: Dictionary = layout_value if layout_value is Dictionary else {}
	var rect_value: Variant = layout.get(rect_key, Rect2())
	if not (rect_value is Rect2) or not (rect_value as Rect2).has_area():
		return
	_click_at(state, (rect_value as Rect2).get_center())


func _click_at(state: Object, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	state.handle_input(event, VIEW_SIZE)


func _press_key(state: Object, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	state.handle_input(event, VIEW_SIZE)


func _inline_modal(state: Object) -> Dictionary:
	var value: Variant = state.build_view_model(VIEW_SIZE).get("inline_modal", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _count_owned_levels(levels: Dictionary) -> int:
	var count := 0
	for level_value: Variant in levels.values():
		if int(level_value) > 0:
			count += 1
	return count


func _accept_effect() -> bool:
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
