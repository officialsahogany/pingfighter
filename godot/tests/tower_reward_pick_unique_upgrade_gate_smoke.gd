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
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)

const VIEW_SIZE := Vector2(2020.0, 1246.0)
const DASH_ID := "dash_amplification"
const ORDINARY_ID := "common_bulk_up"
const READ_ONLY_REASON := "count_type"
const READ_ONLY_REASON_KEY := "upgrade_count_type_read_only"
const REQUIRED_LOCALES := ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]

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


class StaticOfferBuilder:
	extends RefCounted

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {},
		_reroll_counter: int = 0
	) -> Dictionary:
		return {
			"accepted": true,
			"boss_slot_id": "floor_01_dalji",
			"offer_generation": 0,
			"choices": [{
				"id": "tower_bag_expansion",
				"name": "tower_bag_expansion",
				"reward_pick_kind": "bag_expansion",
				"reward_pick_cost": 99,
				"is_instant": true,
			}],
		}


class FakeFlowOwner:
	extends RefCounted

	var balances: Dictionary = {"muhon": 30, "gold": 0, "chance_gems": 0}
	var upgrade_call_count := 0
	var upgrade_costs: Array[int] = []
	var upgrade_targets: Array[int] = []

	func get_reward_pick_context() -> Dictionary:
		return {
			"node_resolution_id": "reward-pick-unique-upgrade-gate",
			"boss_slot_id": "floor_01_dalji",
		}

	func get_run_state_snapshot() -> Dictionary:
		return balances.duplicate(true)

	func apply_reward_pick_upgrade(
		_upgrade_sequence: int,
		_choice: Dictionary,
		target_level: int,
		cost: int,
		effect_callback: Callable,
		_rollback_callback: Callable = Callable()
	) -> Dictionary:
		upgrade_call_count += 1
		upgrade_costs.append(cost)
		upgrade_targets.append(target_level)
		if int(balances.get("muhon", 0)) < cost:
			return {"accepted": false, "applied": false, "reason": "insufficient_muhon"}
		if not effect_callback.is_valid() or not bool(effect_callback.call()):
			return {"accepted": false, "applied": false, "reason": "effect_rejected"}
		balances["muhon"] = int(balances.get("muhon", 0)) - cost
		return {"accepted": true, "applied": true, "reason": "committed"}

	func finalize_reward_pick(_vision_boss_slot_id: String = "") -> Dictionary:
		return {"accepted": true, "applied": true, "reason": "committed"}


class PropertyOverrideCatalog:
	extends RefCounted

	var _base: Object = RuntimePerkCatalog.new()
	var _rank_tag_overrides: Dictionary = {}

	func _init(rank_tag_overrides: Dictionary = {}) -> void:
		_rank_tag_overrides = rank_tag_overrides.duplicate(true)

	func get_perk_data(perk_id: String) -> Dictionary:
		var data_value: Variant = _base.call("get_perk_data", perk_id)
		var data: Dictionary = (
			(data_value as Dictionary).duplicate(true)
			if data_value is Dictionary
			else {}
		)
		return _apply_rank_tag_override(perk_id, data)

	func get_all_perk_data() -> Dictionary:
		var data_value: Variant = _base.call("get_all_perk_data")
		var result: Dictionary = (
			(data_value as Dictionary).duplicate(true)
			if data_value is Dictionary
			else {}
		)
		for perk_id_value: Variant in _rank_tag_overrides.keys():
			var perk_id := str(perk_id_value)
			var perk_value: Variant = result.get(perk_id, {})
			if perk_value is Dictionary:
				result[perk_id] = _apply_rank_tag_override(
					perk_id,
					(perk_value as Dictionary).duplicate(true)
				)
		return result

	func get_slot_cost_for_level(perk_data: Dictionary, level: int) -> int:
		return int(_base.call("get_slot_cost_for_level", perk_data, level))

	func get_perk_slot_status(
		runtime_levels: Dictionary,
		slot_context: Object = null
	) -> Dictionary:
		return _dictionary_result(_base.call(
			"get_perk_slot_status",
			runtime_levels,
			slot_context
		))

	func get_perk_slot_apply_status(
		perk_data: Dictionary,
		runtime_levels: Dictionary,
		slot_context: Object = null,
		target_level: int = -1
	) -> Dictionary:
		return _dictionary_result(_base.call(
			"get_perk_slot_apply_status",
			perk_data,
			runtime_levels,
			slot_context,
			target_level
		))

	func _apply_rank_tag_override(perk_id: String, data: Dictionary) -> Dictionary:
		if not _rank_tag_overrides.has(perk_id):
			return data
		var rank_tag := str(_rank_tag_overrides.get(perk_id, "")).strip_edges()
		if rank_tag.is_empty():
			data.erase("rank_tag")
		else:
			data["rank_tag"] = rank_tag
		return data

	func _dictionary_result(value: Variant) -> Dictionary:
		return (
			(value as Dictionary).duplicate(true)
			if value is Dictionary
			else {}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_localized_read_only_reason()
	_verify_unique_dash_status_and_detail_are_read_only()
	_verify_unique_dash_enter_purchase_is_noop()
	_verify_unique_dash_button_purchase_is_noop()
	_verify_ordinary_mugong_upgrade_still_commits()
	_verify_removing_unique_rank_reenables_dash_upgrade()
	_verify_assigning_unique_rank_blocks_an_ordinary_perk()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_reward_pick_unique_upgrade_gate_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_localized_read_only_reason() -> void:
	var entries_value: Variant = TowerRewardPickLocalization.TEXT.get(
		READ_ONLY_REASON_KEY,
		{}
	)
	var entries: Dictionary = entries_value if entries_value is Dictionary else {}
	_expect(not entries.is_empty(), "count-type read-only reason must have a localization entry")
	for locale_value: Variant in REQUIRED_LOCALES:
		var locale := str(locale_value)
		var text := str(entries.get(locale, ""))
		_expect(not text.is_empty(), "count-type read-only reason must define %s" % locale)
		_expect(
			not text.contains("—"),
			"count-type read-only reason must not use an em dash in %s" % locale
		)


func _verify_unique_dash_status_and_detail_are_read_only() -> void:
	var fixture := _start_fixture(
		{DASH_ID: 2},
		PropertyOverrideCatalog.new()
	)
	var state: Object = fixture.get("state")
	var cells := _status_cells(state, DASH_ID)
	var reason_text := TowerRewardPickLocalization.text(READ_ONLY_REASON_KEY)
	_expect(cells.size() == 2, "dash level two must retain two distinct status cells")
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		_expect(
			bool(cell.get("upgrade_inspectable", false)),
			"each unique dash cell must remain detail-inspectable"
		)
		_expect(
			not bool(cell.get("can_upgrade", true)),
			"each unique dash cell must reject in-place upgrade"
		)
		_expect(
			str(cell.get("upgrade_read_only_reason", "")) == READ_ONLY_REASON,
			"each unique dash cell must publish the count-type reason code"
		)
		_expect(
			str(cell.get("upgrade_read_only_reason_text", "")) == reason_text,
			"each unique dash cell must publish the localized read-only reason"
		)
		_expect(
			RuntimePerkOverlayRenderer.get_tower_reward_status_action_hint(
				cell,
				TowerRewardPickLocalization.text("owned_upgrade_cta"),
				TowerRewardPickLocalization.text("upgrade_max_rank")
			) == reason_text,
			"each unique dash hover must show the count-type reason"
		)
	if not cells.is_empty():
		_click_status_cell(state, cells[0] as Dictionary)
	var modal := _inline_modal(state)
	_expect(str(modal.get("kind", "")) == "upgrade", "unique dash details must still open")
	_expect(
		not bool(modal.get("has_next_level", true))
		and not bool(modal.get("can_upgrade", true))
		and not bool(modal.get("confirm_enabled", true)),
		"unique dash detail must reuse the read-only maximum-rank interaction shape"
	)
	_expect(
		(modal.get("cards", []) as Array).size() == 1,
		"unique dash detail must collapse to the single current card"
	)
	_expect(
		str(modal.get("upgrade_read_only_reason", "")) == READ_ONLY_REASON
		and str(modal.get("upgrade_read_only_reason_text", "")) == reason_text
		and str(modal.get("max_rank_text", "")) == reason_text,
		"unique dash detail and disabled button must show the localized count-type reason"
	)
	_reset_fixture(fixture)


func _verify_unique_dash_enter_purchase_is_noop() -> void:
	var fixture := _start_fixture(
		{DASH_ID: 2},
		PropertyOverrideCatalog.new()
	)
	_open_first_status_cell(fixture, DASH_ID)
	_press_key(fixture.get("state"), KEY_ENTER)
	_expect_purchase_noop(fixture, DASH_ID, 2, "Enter")
	_reset_fixture(fixture)


func _verify_unique_dash_button_purchase_is_noop() -> void:
	var fixture := _start_fixture(
		{DASH_ID: 2},
		PropertyOverrideCatalog.new()
	)
	_open_first_status_cell(fixture, DASH_ID)
	var state: Object = fixture.get("state")
	var modal := _inline_modal(state)
	_click_modal_rect(state, modal, "confirm_button_rect")
	_expect_purchase_noop(fixture, DASH_ID, 2, "disabled confirm button")
	_reset_fixture(fixture)


func _verify_ordinary_mugong_upgrade_still_commits() -> void:
	var fixture := _start_fixture(
		{ORDINARY_ID: 2},
		PropertyOverrideCatalog.new()
	)
	var state: Object = fixture.get("state")
	var cells := _status_cells(state, ORDINARY_ID)
	_expect(cells.size() == 1, "ordinary Mugong must retain one status cell")
	if not cells.is_empty():
		var cell: Dictionary = cells[0]
		_expect(bool(cell.get("upgrade_inspectable", false)), "ordinary Mugong must remain inspectable")
		_expect(bool(cell.get("can_upgrade", false)), "ordinary Mugong must remain upgradeable")
		_expect(
			str(cell.get("upgrade_read_only_reason", "")).is_empty(),
			"ordinary Mugong must not inherit the count-type reason"
		)
	_open_first_status_cell(fixture, ORDINARY_ID)
	var modal := _inline_modal(state)
	_expect(bool(modal.get("confirm_enabled", false)), "ordinary Mugong confirm must remain enabled")
	_press_key(state, KEY_ENTER)
	_expect_upgrade_committed(fixture, ORDINARY_ID, 3, "ordinary Mugong")
	_reset_fixture(fixture)


func _verify_removing_unique_rank_reenables_dash_upgrade() -> void:
	var fixture := _start_fixture(
		{DASH_ID: 2},
		PropertyOverrideCatalog.new({DASH_ID: ""})
	)
	var state: Object = fixture.get("state")
	var cells := _status_cells(state, DASH_ID)
	_expect(cells.size() == 2, "rank-tag removal must not change dash slot occupancy")
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value if cell_value is Dictionary else {}
		_expect(
			bool(cell.get("can_upgrade", false)),
			"dash id without the unique property must become upgradeable"
		)
		_expect(
			str(cell.get("upgrade_read_only_reason", "")).is_empty(),
			"dash id without the unique property must not retain a count-type reason"
		)
	_open_first_status_cell(fixture, DASH_ID)
	_press_key(state, KEY_ENTER)
	_expect_upgrade_committed(fixture, DASH_ID, 3, "rank-tag-removed dash")
	_reset_fixture(fixture)


func _verify_assigning_unique_rank_blocks_an_ordinary_perk() -> void:
	var fixture := _start_fixture(
		{ORDINARY_ID: 2},
		PropertyOverrideCatalog.new({ORDINARY_ID: "unique"})
	)
	var state: Object = fixture.get("state")
	var cells := _status_cells(state, ORDINARY_ID)
	_expect(cells.size() == 1, "unique-tagged ordinary fixture must retain its status cell")
	if not cells.is_empty():
		var cell: Dictionary = cells[0]
		_expect(bool(cell.get("upgrade_inspectable", false)), "unique property must preserve detail access")
		_expect(not bool(cell.get("can_upgrade", true)), "unique property must disable in-place upgrade")
		_expect(
			str(cell.get("upgrade_read_only_reason", "")) == READ_ONLY_REASON,
			"unique property must apply the count-type reason without an id special case"
		)
	_open_first_status_cell(fixture, ORDINARY_ID)
	_press_key(state, KEY_ENTER)
	_expect_purchase_noop(fixture, ORDINARY_ID, 2, "unique-tagged ordinary Enter")
	_reset_fixture(fixture)


func _start_fixture(levels: Dictionary, catalog: Object) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	runtime.runtime_skill_levels = levels.duplicate(true)
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var flow := FakeFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"runtime_perk_overlay_renderer": renderer,
		"tower_ascent_flow_owner": flow,
	}
	var state: Object = TowerRewardPickState.new()
	state.set("_offer_builder", StaticOfferBuilder.new())
	_expect(
		state.start(FakeOwner.new(), registry, Callable()),
		"unique upgrade fixture must start through TowerRewardPickState"
	)
	return {
		"runtime": runtime,
		"catalog": catalog,
		"renderer": renderer,
		"flow": flow,
		"registry": registry,
		"state": state,
	}


func _status_cells(state: Object, perk_id: String) -> Array:
	var model_value: Variant = state.call("_get_status_interaction_model", VIEW_SIZE)
	var model: Dictionary = model_value if model_value is Dictionary else {}
	var result: Array = []
	for cell_value: Variant in model.get("cells", []) as Array:
		if (
			cell_value is Dictionary
			and str((cell_value as Dictionary).get("canonical_id", "")) == perk_id
		):
			result.append((cell_value as Dictionary).duplicate(true))
	return result


func _open_first_status_cell(fixture: Dictionary, perk_id: String) -> void:
	var state: Object = fixture.get("state")
	var cells := _status_cells(state, perk_id)
	_expect(not cells.is_empty(), "%s must expose an inspectable status cell" % perk_id)
	if not cells.is_empty():
		_click_status_cell(state, cells[0] as Dictionary)
	_expect(
		str(_inline_modal(state).get("kind", "")) == "upgrade",
		"%s status cell must open the production upgrade detail" % perk_id
	)


func _click_status_cell(state: Object, cell: Dictionary) -> void:
	var rect_value: Variant = cell.get("rect", Rect2())
	if rect_value is Rect2 and (rect_value as Rect2).has_area():
		_click_at(state, (rect_value as Rect2).get_center())


func _click_modal_rect(state: Object, modal: Dictionary, rect_key: String) -> void:
	var layout_value: Variant = modal.get("layout", {})
	var layout: Dictionary = layout_value if layout_value is Dictionary else {}
	var rect_value: Variant = layout.get(rect_key, Rect2())
	_expect(
		rect_value is Rect2 and (rect_value as Rect2).has_area(),
		"upgrade modal must expose %s" % rect_key
	)
	if rect_value is Rect2 and (rect_value as Rect2).has_area():
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


func _expect_purchase_noop(
	fixture: Dictionary,
	perk_id: String,
	expected_level: int,
	label: String
) -> void:
	var runtime: Object = fixture.get("runtime")
	var flow: FakeFlowOwner = fixture.get("flow")
	_expect(
		int(runtime.runtime_skill_levels.get(perk_id, 0)) == expected_level,
		"%s must preserve the owned level" % label
	)
	_expect(
		int(flow.balances.get("muhon", -1)) == 30,
		"%s must not debit Muhon" % label
	)
	_expect(
		flow.upgrade_call_count == 0
		and flow.upgrade_costs.is_empty()
		and flow.upgrade_targets.is_empty(),
		"%s must not enter the reward-pick upgrade transaction" % label
	)


func _expect_upgrade_committed(
	fixture: Dictionary,
	perk_id: String,
	expected_level: int,
	label: String
) -> void:
	var runtime: Object = fixture.get("runtime")
	var flow: FakeFlowOwner = fixture.get("flow")
	_expect(
		flow.upgrade_call_count == 1
		and flow.upgrade_costs == [3]
		and flow.upgrade_targets == [expected_level],
		"%s must enter the normal reward-pick upgrade transaction once" % label
	)
	_expect(
		int(runtime.runtime_skill_levels.get(perk_id, 0)) == expected_level,
		"%s must commit the requested target level" % label
	)
	_expect(
		int(flow.balances.get("muhon", -1)) == 27,
		"%s must debit the ordinary three-Muhon upgrade cost" % label
	)


func _reset_fixture(fixture: Dictionary) -> void:
	var state_value: Variant = fixture.get("state", null)
	if state_value is Object and (state_value as Object).has_method("reset"):
		(state_value as Object).call("reset")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
