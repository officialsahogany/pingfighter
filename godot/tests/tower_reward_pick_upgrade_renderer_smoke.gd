extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)

const REFERENCE_VIEW := Vector2(1400.0, 1050.0)

var _failures: Array[String] = []


func _init() -> void:
	_verify_upgrade_compare_layout_and_hit_rects()
	_verify_all_level_and_max_rank_layouts()
	_verify_wrapped_replacement_layout_and_hit_rects()
	_verify_shared_status_interaction_model()
	_verify_folded_fusion_and_effective_projection()
	_verify_delta_rows_and_card_row_budget()
	_verify_localization_and_bag_icon_contract()
	if _failures.is_empty():
		print("tower_reward_pick_upgrade_renderer_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_upgrade_compare_layout_and_hit_rects() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var modal := {
		"kind": "upgrade",
		"cards": [_level_card(1, "current"), _level_card(2, "next")],
		"show_all_levels": false,
		"can_upgrade": true,
		"max_level": 5,
	}
	var layout: Dictionary = renderer.build_tower_reward_upgrade_layout(
		REFERENCE_VIEW,
		modal
	)
	var expected_panel := Rect2(149.0, 79.0, 1123.0, 916.0)
	var panel: Rect2 = layout.get("panel_rect", Rect2())
	var cards: Array = layout.get("card_rects", []) as Array
	_expect(panel == expected_panel, "image2 reference view must preserve the authored modal frame")
	_expect(cards.size() == 2, "collapsed upgrade comparison must expose current and next cards")
	if cards.size() == 2:
		var current_rect: Rect2 = cards[0]
		var next_rect: Rect2 = cards[1]
		_expect(current_rect.end.x < next_rect.position.x, "comparison cards must leave room for the gold arrow")
		_expect(panel.encloses(current_rect) and panel.encloses(next_rect), "comparison cards must stay inside the frame")
		_expect(
			renderer.get_tower_reward_upgrade_card_index_at(
				current_rect.position + Vector2.ONE,
				REFERENCE_VIEW,
				modal
			) == 0,
			"current-card top-left corner must share the painted card hit rect"
		)
		_expect(
			renderer.get_tower_reward_upgrade_card_index_at(
				next_rect.end - Vector2.ONE,
				REFERENCE_VIEW,
				modal
			) == 1,
			"next-card bottom-right corner must share the painted card hit rect"
		)
	for action_name: String in ["back_arrow", "checkbox", "back", "confirm"]:
		var key: String = str({
			"back_arrow": "back_arrow_rect",
			"checkbox": "checkbox_rect",
			"back": "back_button_rect",
			"confirm": "confirm_button_rect",
		}[action_name])
		var action_rect: Rect2 = layout.get(key, Rect2())
		var modal_with_layout := modal.duplicate(true)
		modal_with_layout["layout"] = layout
		_expect(
			renderer.get_tower_reward_upgrade_action_at(
				action_rect.position + Vector2.ONE,
				REFERENCE_VIEW,
				modal_with_layout
			) == action_name,
			"%s top-left corner must use the shared action rect" % action_name
		)


func _verify_all_level_and_max_rank_layouts() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var all_cards: Array[Dictionary] = []
	for level in range(1, 6):
		all_cards.append(_level_card(level, "level"))
	var all_modal := {
		"cards": all_cards,
		"show_all_levels": true,
		"can_upgrade": true,
		"max_level": 5,
	}
	var all_layout: Dictionary = renderer.build_tower_reward_upgrade_layout(
		REFERENCE_VIEW,
		all_modal
	)
	var all_rects: Array = all_layout.get("card_rects", []) as Array
	var card_band: Rect2 = all_layout.get("card_band_rect", Rect2())
	var checkbox: Rect2 = all_layout.get("checkbox_rect", Rect2())
	_expect(all_rects.size() == 5, "all-level mode must enumerate the catalog maximum instead of hardcoding three")
	for index in range(all_rects.size()):
		var rect: Rect2 = all_rects[index]
		_expect(card_band.encloses(rect), "all-level card %d must stay inside the computed card band" % index)
		_expect(not rect.intersects(checkbox), "all-level card %d must not collide with the checkbox" % index)
		if index > 0:
			_expect(not rect.intersects(all_rects[index - 1] as Rect2), "all-level cards must not overlap")

	var max_modal := {
		"cards": [_level_card(5, "current")],
		"show_all_levels": false,
		"can_upgrade": false,
		"max_level": 5,
	}
	var max_layout: Dictionary = renderer.build_tower_reward_upgrade_layout(
		REFERENCE_VIEW,
		max_modal
	)
	_expect(
		(max_layout.get("card_rects", []) as Array).size() == 1,
		"maximum rank must show one read-only current card"
	)
	_expect(
		not (max_layout.get("arrow_rect", Rect2()) as Rect2).has_area(),
		"maximum rank must omit the comparison arrow and phantom next card"
	)


func _verify_wrapped_replacement_layout_and_hit_rects() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var candidates: Array[Dictionary] = []
	for index in range(10):
		candidates.append({"name": "perk_%d" % index})
	var modal := {"kind": "mugong_replace", "candidates": candidates}
	var layout: Dictionary = renderer.build_tower_reward_mugong_swap_layout(
		REFERENCE_VIEW,
		modal
	)
	var panel: Rect2 = layout.get("panel_rect", Rect2())
	var rects: Array = layout.get("option_rects", []) as Array
	var cancel_rect: Rect2 = layout.get("cancel_rect", Rect2())
	_expect(rects.size() == 10, "replacement modal must expose every occupied Mugong cell")
	_expect(int(layout.get("columns", 0)) <= 5 and int(layout.get("rows", 0)) == 2, "ten replacement choices must wrap instead of shrinking into one row")
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		_expect(panel.encloses(rect), "replacement option %d must stay in the panel" % index)
		_expect(not rect.intersects(cancel_rect), "replacement option %d must not collide with cancel" % index)
		var with_layout := modal.duplicate(true)
		with_layout["layout"] = layout
		_expect(
			renderer.get_tower_reward_mugong_swap_option_index_at(
				rect.end - Vector2.ONE,
				REFERENCE_VIEW,
				with_layout
			) == index,
			"replacement option %d corner must share its painted rect" % index
		)
	var cancel_modal := modal.duplicate(true)
	cancel_modal["layout"] = layout
	_expect(
		renderer.is_tower_reward_mugong_swap_cancel_at(
			cancel_rect.position + Vector2.ONE,
			REFERENCE_VIEW,
			cancel_modal
		),
		"replacement cancel top-left corner must be clickable"
	)


func _verify_shared_status_interaction_model() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var catalog := RuntimePerkCatalog.new()
	var snapshot := {
		"runtime_skill_levels": {
			"common_bulk_up": 2,
			"dash_amplification": 2,
			"common_expansion": 1,
		},
		"effective_runtime_skill_levels": {
			"common_bulk_up": 2,
			"dash_amplification": 2,
			"common_expansion": 1,
		},
		"perk_slot_status": {"count": 3, "limit": 6, "is_full": false},
		"perk_slot_status_cached": true,
	}
	var panel := Rect2(120.0, 760.0, 1160.0, 150.0)
	var model: Dictionary = renderer.build_tower_reward_status_interaction_model(
		null,
		catalog,
		snapshot,
		panel
	)
	var cells: Array = model.get("cells", []) as Array
	_expect(
		cells.size() == int(model.get("display_slots", 0)) and cells.size() == 6,
		"the six painted owned/empty slots must share the exact interaction model"
	)
	var dash_targets: Array[String] = []
	var expansion_cell: Dictionary = {}
	var bulk_cell: Dictionary = {}
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value as Dictionary
		match str(cell.get("canonical_id", "")):
			"dash_amplification":
				dash_targets.append(str(cell.get("target_key", "")))
			"common_expansion":
				expansion_cell = cell
			"common_bulk_up":
				bulk_cell = cell
	_expect(dash_targets.size() == 2 and dash_targets[0] != dash_targets[1], "each dash-token slot must retain a distinct replacement identity")
	_expect(bool(expansion_cell.get("upgrade_inspectable", false)), "legacy expansion must remain available for in-place upgrade")
	_expect(bool(expansion_cell.get("replacement_eligible", false)), "the currently slot-consuming legacy expansion must remain a replacement target")
	_expect(bool(bulk_cell.get("can_upgrade", false)), "owned nonmaximum Mugong must expose the upgrade CTA")
	var bulk_rect: Rect2 = bulk_cell.get("rect", Rect2())
	var hit: Dictionary = renderer.get_tower_reward_status_cell_at(
		model,
		bulk_rect.position + Vector2.ONE
	)
	_expect(str(hit.get("canonical_id", "")) == "common_bulk_up", "status top-left hit must resolve through the painted interaction model")
	_expect(
		renderer.get_tower_reward_status_cell_at(
			model,
			bulk_rect.position - Vector2.ONE
		).is_empty(),
		"one pixel outside the status cell must not open the upgrade modal"
	)


func _verify_folded_fusion_and_effective_projection() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var catalog := RuntimePerkCatalog.new()
	var effective_snapshot := {
		"runtime_skill_levels": {"common_bulk_up": 1},
		"effective_runtime_skill_levels": {"common_bulk_up": 3},
		"perk_slot_status": {"count": 1, "limit": 6, "is_full": false},
		"perk_slot_status_cached": true,
	}
	var effective_model: Dictionary = renderer.build_tower_reward_status_interaction_model(
		null,
		catalog,
		effective_snapshot,
		Rect2(120.0, 760.0, 1160.0, 150.0)
	)
	var effective_cell := _find_cell(
		effective_model.get("cells", []) as Array,
		"common_bulk_up"
	)
	_expect(
		int(effective_cell.get("base_level", 0)) == 1
		and int(effective_cell.get("effective_level", 0)) == 3,
		"W4 projection must display the effective rank while retaining raw upgrade ownership"
	)

	var fusion_snapshot := {
		"runtime_skill_levels": {
			"common_bulk_up": 1,
			"common_swiftness": 1,
		},
		"effective_runtime_skill_levels": {},
		"perk_slot_status": {"count": 1, "limit": 6, "is_full": false},
		"perk_slot_status_cached": true,
		"perk_fusion_display_projection": {
			"entries": [{
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
			}],
		},
	}
	var fusion_model: Dictionary = renderer.build_tower_reward_status_interaction_model(
		null,
		catalog,
		fusion_snapshot,
		Rect2(120.0, 760.0, 1160.0, 150.0)
	)
	var fusion_cell := _find_cell(fusion_model.get("cells", []) as Array, "fusion_1")
	_expect(not fusion_cell.is_empty(), "folded fusion must remain one status/replacement cell")
	_expect(not bool(fusion_cell.get("upgrade_inspectable", true)), "synthetic fusion projection must not pretend to have a next rank")
	_expect(bool(fusion_cell.get("replacement_eligible", false)), "folded fusion must remain a coherent replacement target")
	_expect(str(fusion_cell.get("target_key", "")) == "fusion:fusion_1", "fusion replacement identity must use the preserved projection id")


func _verify_delta_rows_and_card_row_budget() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var shrapnel_armor: Dictionary = RuntimePerkCatalog.CONVERTED_PERKS.get(
		"shrapnel_armor",
		{}
	)
	var shrapnel_descriptions: Dictionary = shrapnel_armor.get("descriptions", {})
	var shrapnel_rows: Array = renderer.build_tower_reward_upgrade_stat_rows(
		str(shrapnel_descriptions.get(1, "")),
		str(shrapnel_descriptions.get(2, ""))
	)
	var shrapnel_expected := ["(▲6%)", "(▲3개)", "(▲1)", "(▲10)"]
	_expect(shrapnel_rows.size() == 4, "shrapnel armor 1->2 must preserve all four option rows")
	for index in range(mini(shrapnel_rows.size(), shrapnel_expected.size())):
		_expect(
			str((shrapnel_rows[index] as Dictionary).get("delta", "")) == shrapnel_expected[index],
			"shrapnel armor option %d must expose its own typed delta" % index
		)
	var rows: Array = renderer.build_tower_reward_upgrade_stat_rows(
		"공격력 +15%, 치명타 확률 +5%",
		"공격력 +25%, 치명타 확률 +10%"
	)
	_expect(rows.size() == 2, "comparison helper must preserve both stat rows")
	if rows.size() == 2:
		_expect(str((rows[0] as Dictionary).get("delta", "")) == "(▲10%)", "first stat must expose the green ten-percent delta")
		_expect(str((rows[1] as Dictionary).get("delta", "")) == "(▲5%)", "second stat must expose the green five-percent delta")
	var mixed_unit_rows: Array = renderer.build_tower_reward_upgrade_stat_rows(
		"피해 10% 지속 2초 단계 3",
		"피해 15% 지속 3.5초 단계 5"
	)
	_expect(mixed_unit_rows.size() == 1, "multi-token option must remain one comparison row")
	if mixed_unit_rows.size() == 1:
		_expect(
			str((mixed_unit_rows[0] as Dictionary).get("delta", "")) == "(▲5%) (▲1.5초) (▲2)",
			"percent, seconds, and unitless tokens must all retain their own delta units"
		)
	var modal := {
		"cards": [_level_card(1, "level"), _level_card(2, "level"), _level_card(3, "level"), _level_card(4, "level"), _level_card(5, "level")],
		"show_all_levels": true,
		"can_upgrade": true,
		"max_level": 5,
	}
	var layout: Dictionary = renderer.build_tower_reward_upgrade_layout(
		REFERENCE_VIEW,
		modal
	)
	for rect_value: Variant in layout.get("card_rects", []) as Array:
		var content: Dictionary = renderer.build_tower_reward_upgrade_card_content_layout(
			{
				"choice": {
					"description": "공격력 +25%, 치명타 확률 +10%, 기력 회복 속도 +20%",
				},
				"previous_description": "공격력 +15%, 치명타 확률 +5%, 기력 회복 속도 +10%",
			},
			rect_value as Rect2
		)
		var content_rect: Rect2 = content.get("content_rect", Rect2())
		_expect(bool(content.get("fits", false)), "five-card all-level text must fit its computed row budget")
		_expect(float(content.get("last_baseline_y", INF)) <= content_rect.end.y, "last comparison baseline must stay inside the card")


func _verify_localization_and_bag_icon_contract() -> void:
	var required_keys := [
		"owned_upgrade_title",
		"owned_upgrade_cta",
		"upgrade_show_all",
		"upgrade_back",
		"upgrade_confirm",
		"upgrade_max_rank",
		"upgrade_cost",
		"upgrade_current",
		"upgrade_after",
		"mugong_swap_title",
		"mugong_swap_new_label",
		"mugong_swap_hint",
		"bag_expansion_name",
		"bag_expansion_description",
		"bag_expansion_detail",
	]
	var locales := ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]
	for key_value: Variant in required_keys:
		var key := str(key_value)
		var entries: Dictionary = TowerRewardPickLocalization.TEXT.get(key, {})
		for locale_value: Variant in locales:
			var locale := str(locale_value)
			var text := str(entries.get(locale, ""))
			_expect(not text.is_empty(), "%s must define the %s locale" % [key, locale])
			_expect(not text.contains("—"), "%s/%s must not use an em dash" % [key, locale])
	var bag_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(
		"tower_bag_expansion",
		""
	))
	_expect(bag_path.ends_with("item_bag_expansion_perk_icon.png"), "tower_bag_expansion must reuse the retired bag art without reusing its runtime id")
	_expect(FileAccess.file_exists(bag_path), "tower_bag_expansion icon source must exist")


func _level_card(level: int, role: String) -> Dictionary:
	return {
		"role": role,
		"display_level": level,
		"choice": {
			"id": "common_bulk_up",
			"name": "철산공",
			"description": "몸집 크기 %d%% 증가" % (level * 6),
			"next_level": level,
			"max_level": 5,
			"icon_color": Color(1.0, 0.58, 0.31),
		},
	}


func _find_cell(cells: Array, canonical_id: String) -> Dictionary:
	for cell_value: Variant in cells:
		if cell_value is Dictionary and str((cell_value as Dictionary).get("canonical_id", "")) == canonical_id:
			return (cell_value as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
