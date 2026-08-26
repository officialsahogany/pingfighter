extends SceneTree

const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_training_layout_flag_owns_render_and_hit_rects()
	_verify_service_card_layout_profiles()
	_verify_training_stage_reservations()
	_verify_layout_cache_is_size_owned()
	_verify_compact_description_three_row_budget()
	_verify_shop_cells_bypass_compact_card_text_layout()
	_verify_compact_hover_detail_lane_geometry()
	_verify_training_hanji_chrome_assets_and_gate()
	if _failures.is_empty():
		print("tower_training_screen_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_training_layout_flag_owns_render_and_hit_rects() -> void:
	var modal := _build_six_card_modal("training")
	var model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
	var layout_flags: Dictionary = model.get("layout_flags", {})
	_expect(
		bool(layout_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_TRAINING_STAGE, false)),
		"training view model must carry the training-stage layout flag"
	)
	var layout: Dictionary = modal.build_screen_layout(BASE_VIEW_SIZE, layout_flags)
	var card_grid_rect: Rect2 = layout.get("card_grid_rect", Rect2())
	_expect(
		card_grid_rect.is_equal_approx(TowerAscentNodeModalState.TRAINING_CARD_GRID_RECT),
		"training build_screen_layout must resolve the left card rail"
	)
	var rects: Array = model.get("action_rects", [])
	var direct_rects: Array = modal.get_action_rects(BASE_VIEW_SIZE, layout_flags)
	_expect(rects.size() == 7, "training must expose six cards plus end work")
	_expect(direct_rects == rects, "render model and direct hit-test rect builder must consume the same layout flags")
	var card_width := (
		card_grid_rect.size.x
		- TowerAscentNodeModalState.TRAINING_GRID_COLUMN_GAP
		* float(TowerAscentNodeModalState.TRAINING_CARD_GRID_COLUMNS - 1)
	) / float(TowerAscentNodeModalState.TRAINING_CARD_GRID_COLUMNS)
	var card_height := (
		card_grid_rect.size.y
		- TowerAscentNodeModalState.TRAINING_GRID_ROW_GAP
		* float(TowerAscentNodeModalState.TRAINING_CARD_GRID_ROWS - 1)
	) / float(TowerAscentNodeModalState.TRAINING_CARD_GRID_ROWS)
	_expect(is_equal_approx(card_width, 245.0), "training rail card width must resolve to 245px")
	_expect(is_equal_approx(card_height, 74.333336), "training rail card height must derive from six rows")
	for index in range(6):
		var expected_column := index % TowerAscentNodeModalState.TRAINING_CARD_GRID_COLUMNS
		var expected_row := index / TowerAscentNodeModalState.TRAINING_CARD_GRID_COLUMNS
		var expected_rect := Rect2(
			card_grid_rect.position + Vector2(
				float(expected_column) * (
					card_width + TowerAscentNodeModalState.TRAINING_GRID_COLUMN_GAP
				),
				float(expected_row) * (
					card_height + TowerAscentNodeModalState.TRAINING_GRID_ROW_GAP
				)
			),
			Vector2(card_width, card_height)
		)
		var rect := rects[index] as Rect2
		_expect(rect.is_equal_approx(expected_rect), "training card %d must occupy its flagged top-grid cell" % index)
		var top_corner := rect.position + Vector2(2.0, 2.0)
		_expect(modal.select_at_position(top_corner, BASE_VIEW_SIZE), "training card %d top corner must hit" % index)
		_expect(
			str(modal.get_selected_action().get("id", "")) == "training-card-%d" % index,
			"training card %d top-corner hit must select the rendered action" % index
		)

	# GRT-022 counterproof: use the old S2 grid's third-column top corner, not a
	# center sample. It sits above the new right stage and outside the left rail.
	var legacy_flags := {TowerAscentNodeModalState.LAYOUT_FLAG_TRAINING_STAGE: false}
	var legacy_rects: Array = modal.get_action_rects(BASE_VIEW_SIZE, legacy_flags)
	var legacy_third_column_top_corner := (legacy_rects[2] as Rect2).position + Vector2(2.0, 2.0)
	_expect(
		not (rects[2] as Rect2).has_point(legacy_third_column_top_corner),
		"counterproof requires the old third-column top corner to miss the new drawn card"
	)
	_expect(
		not modal.select_at_position(legacy_third_column_top_corner, BASE_VIEW_SIZE),
		"production hit testing must reject the legacy third-column top corner"
	)

	var live_model: Dictionary = modal.build_view_model(LIVE_VIEW_SIZE)
	var live_rects: Array = live_model.get("action_rects", [])
	var live_top_corner := (live_rects[5] as Rect2).position + Vector2(2.0, 2.0)
	_expect(
		modal.select_at_position(live_top_corner, LIVE_VIEW_SIZE),
		"scaled live-view training top corner must share the rendered layout"
	)
	_expect(
		str(modal.get_selected_action().get("id", "")) == "training-card-5",
		"scaled live-view top corner must select the sixth training card"
	)


func _verify_service_card_layout_profiles() -> void:
	var shop_modal := _build_six_card_modal("shop")
	var shop_model: Dictionary = shop_modal.build_view_model(BASE_VIEW_SIZE)
	var shop_flags: Dictionary = shop_model.get("layout_flags", {})
	_expect(
		bool(shop_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_SHOP_COMPACT, false)),
		"shop view model must preserve its compatibility compact-layout flag"
	)
	_expect(
		bool(shop_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_SHOP_TRADE_PANELS, false)),
		"shop view model must carry its split trade-panel layout flag"
	)
	var shop_layout: Dictionary = shop_modal.build_screen_layout(BASE_VIEW_SIZE, shop_flags)
	_expect(
		(shop_layout.get("shop_player_panel_rect", Rect2()) as Rect2).is_equal_approx(TowerAscentNodeModalState.SHOP_TRADE_PLAYER_PANEL_RECT),
		"shop must resolve the Tower-owned player panel geometry"
	)
	_expect(
		(shop_layout.get("shop_stock_panel_rect", Rect2()) as Rect2).is_equal_approx(TowerAscentNodeModalState.SHOP_TRADE_STOCK_PANEL_RECT),
		"shop must resolve the Tower-owned stock panel geometry"
	)
	var shop_rects: Array = shop_model.get("action_rects", [])
	var shop_card := shop_rects[0] as Rect2
	# Feedback 7 keeps the old compact flag for compatibility, while the visible
	# surface now uses occupied 42px cells instead of the 106px card renderer.
	_expect(shop_card.size.is_equal_approx(Vector2.ONE * TowerAscentNodeModalState.SHOP_TRADE_CELL_SIZE), "shop stock must use 42px cells")
	_expect(
		int(shop_layout.get("shop_stock_columns", 0)) == 3
		and int(shop_layout.get("shop_stock_rows", 0)) == 2,
		"six stock items must derive a 3x2 occupied grid"
	)
	_expect(
		int(shop_layout.get("shop_player_columns", -1)) == 0
		and int(shop_layout.get("shop_player_rows", -1)) == 0,
		"empty owned inventory must derive a 0x0 grid without placeholder cells"
	)
	_expect(
		(shop_rects[6] as Rect2).is_equal_approx(TowerAscentNodeModalState.END_WORK_RECT),
		"shop must retain the established end-work footer"
	)

	var fallen_monk_modal := _build_six_card_modal("fallen_monk")
	var fallen_monk_model: Dictionary = fallen_monk_modal.build_view_model(BASE_VIEW_SIZE)
	var fallen_monk_flags: Dictionary = fallen_monk_model.get("layout_flags", {})
	_expect(
		not bool(fallen_monk_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_TRAINING_STAGE, true))
		and not bool(fallen_monk_flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_SHOP_COMPACT, true)),
		"fallen monk must inherit neither compact service layout"
	)
	var fallen_monk_layout: Dictionary = fallen_monk_modal.build_screen_layout(BASE_VIEW_SIZE, fallen_monk_flags)
	_expect(
		(fallen_monk_layout.get("card_grid_rect", Rect2()) as Rect2).is_equal_approx(TowerAscentNodeModalState.CARD_GRID_RECT),
		"fallen monk must retain the established 438px card grid"
	)


func _verify_training_stage_reservations() -> void:
	var modal := _build_six_card_modal("training")
	var model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
	var card_grid: Rect2 = model.get("card_grid_rect", Rect2())
	var stage: Rect2 = model.get("training_stage_rect", Rect2())
	var player_slot: Rect2 = model.get("training_player_slot_rect", Rect2())
	var dummy_slot: Rect2 = model.get("training_dummy_slot_rect", Rect2())
	var stats: Rect2 = model.get("training_stats_rect", Rect2())
	var rects: Array = model.get("action_rects", [])
	var end_work: Rect2 = rects[6] as Rect2
	_expect(stage.is_equal_approx(TowerAscentNodeModalState.TRAINING_STAGE_RECT), "training stage must use the approved upper-right reservation")
	_expect(stats.is_equal_approx(TowerAscentNodeModalState.TRAINING_STATS_RECT), "stats panel must use the approved lower-right reservation")
	_expect(stage.encloses(player_slot), "training stage must enclose the player character slot")
	_expect(stage.encloses(dummy_slot), "training stage must enclose the dummy slot")
	_expect(player_slot.end.x < dummy_slot.position.x, "player slot must sit immediately left of the dummy slot")
	_expect(card_grid.end.x < stage.position.x, "left card rail must not overlap the right training stage")
	_expect(card_grid.end.x < stats.position.x, "left card rail must not overlap the right stats panel")
	_expect(stage.end.y < stats.position.y, "upper training stage must not overlap the lower stats panel")
	_expect(stats.end.y < end_work.position.y, "stats panel must not overlap the end-work footer")
	_expect(stage.get_center().y < TowerAscentNodeModalState.MODAL_RECT.get_center().y, "training stage must occupy the upper half")
	_expect(stats.get_center().y > stage.get_center().y, "stats panel must sit below the training stage")
	_expect(
		TowerAscentNodeModalState.MODAL_RECT.encloses(stage),
		"training stage must remain inside the modal safe rect"
	)
	_expect(
		TowerAscentNodeModalState.MODAL_RECT.encloses(stats),
		"training stats panel must remain inside the modal safe rect"
	)
	_expect(
		RuntimePerkOverlayRenderer.tower_training_stats_visible_capacity(stats) == 10,
		"GRT-021 accepted stats panel height must budget all ten canonical rows"
	)
	_expect(
		(model.get("interaction_visuals", []) as Array).is_empty(),
		"GRT-043 idle training layout must allocate zero pointer visual entries"
	)
	_expect(
		not bool(model.get("has_pointer_visuals", true)),
		"GRT-043 idle training layout must remain outside the dynamic pointer path"
	)


func _verify_layout_cache_is_size_owned() -> void:
	var modal := _build_six_card_modal("training")
	_expect(modal.get_layout_build_count_for_tests() == 0, "layout cache must be cold before its first consumer")
	var first_model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
	_expect(first_model.get("action_rects", []).size() == 7, "first layout build must expose all training actions")
	_expect(modal.get_layout_build_count_for_tests() == 1, "first viewport size must build layout exactly once")
	for frame in range(8):
		modal.build_view_model(BASE_VIEW_SIZE)
		modal.get_action_rects(BASE_VIEW_SIZE)
	_expect(modal.get_layout_build_count_for_tests() == 1, "GRT-028 repeated idle frames must reuse retained layout rects")
	modal.build_view_model(LIVE_VIEW_SIZE)
	_expect(modal.get_layout_build_count_for_tests() == 2, "viewport size change must rebuild layout exactly once")


func _verify_compact_description_three_row_budget() -> void:
	var modal := _build_six_card_modal("training")
	var card_rect := modal.get_action_rects(BASE_VIEW_SIZE)[0] as Rect2
	var renderer := RuntimePerkOverlayRenderer.new()
	var action := _training_card_action(0)
	var choice: Dictionary = action.get("payload", {}).get("choice", {})
	choice["description"] = "수련 효과와 실제 적용값을 확인하는 가장 긴 설명 문구를 세 행 예산으로 정확하게 검증합니다 반복 문장"
	var layout: Dictionary = renderer.build_tower_node_card_text_layout(action, card_rect)
	var description_rows: Array = layout.get("description_rows", [])
	var badge_rows: Array = layout.get("bonus_badge_rows", [])
	_expect(bool(layout.get("compact_card", false)), "production training card rect must select the compact card builder")
	_expect(int(layout.get("description_font_size", 0)) == 11, "base training rail must raise its compact description floor to 11px")
	_expect(description_rows.size() == 3, "longest compact training description must append exactly three rows")
	_expect(int(layout.get("appended_description_row_count", -1)) == 3, "description append count must be the actual three drawn rows")
	_expect(badge_rows.is_empty(), "ordinary training cards must reserve no bonus-badge row")
	_expect(int(layout.get("appended_bonus_badge_row_count", -1)) == 0, "ordinary training badge append count must remain zero")
	_expect(int(layout.get("appended_text_row_count", -1)) == 3, "GRT-021 compact training card must consume exactly its three description rows")
	var live_card_rect := modal.get_action_rects(LIVE_VIEW_SIZE)[0] as Rect2
	var live_layout: Dictionary = renderer.build_tower_node_card_text_layout(action, live_card_rect)
	_expect(
		bool(live_layout.get("compact_card", false)),
		"large Vulkan viewport must keep the same aspect-ratio compact card profile"
	)
	_expect(
		int(live_layout.get("description_font_size", 0)) == 14,
		"wide Vulkan training rail must scale its compact description font to 14px"
	)
	_expect(
		int(live_layout.get("appended_description_row_count", -1)) == 2,
		"wide Vulkan training rail must append exactly two description rows"
	)
	_expect(
		int(live_layout.get("appended_text_row_count", -1)) == 2,
		"wide Vulkan training rail must append exactly its two description rows"
	)
	var live_badge_rows: Array = live_layout.get("bonus_badge_rows", [])
	_expect(live_badge_rows.is_empty(), "large Vulkan viewport must also reserve no ordinary training badge row")


func _verify_shop_cells_bypass_compact_card_text_layout() -> void:
	var shop_modal := _build_six_card_modal("shop")
	var renderer := RuntimePerkOverlayRenderer.new()
	var disabled_action := _chance_gem_shop_action(false, "insufficient gold")
	for view_size in [BASE_VIEW_SIZE, LIVE_VIEW_SIZE]:
		var cell_rect := shop_modal.get_action_rects(view_size)[5] as Rect2
		var content_scale := minf(
			view_size.x / BASE_VIEW_SIZE.x,
			view_size.y / BASE_VIEW_SIZE.y
		)
		var retired_card_layout := renderer.build_tower_node_card_text_layout(
			disabled_action,
			cell_rect
		)
		_expect(
			cell_rect.size.is_equal_approx(
				Vector2.ONE * TowerAscentNodeModalState.SHOP_TRADE_CELL_SIZE * content_scale
			),
			"production shop stock must retain a scaled square cell at %s" % view_size
		)
		_expect(
			not bool(retired_card_layout.get("compact_card", true)),
			"42px square shop cells must not activate the retired compact-card profile at %s" % view_size
		)
		_expect(
			not bool(retired_card_layout.get("unavailable_reason_row_reserved", true)),
			"shop-cell unavailable copy must bypass card description reservation at %s" % view_size
		)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var shop_draw_start := renderer_source.find("func _draw_shop_trade_panels(")
	var shop_draw_end := renderer_source.find("func _draw_shop_trade_tooltip(")
	var shop_draw_source := renderer_source.substr(
		shop_draw_start,
		shop_draw_end - shop_draw_start
	)
	_expect(
		shop_draw_start >= 0
		and shop_draw_end > shop_draw_start
		and shop_draw_source.find("draw_tower_shop_item_cell") >= 0
		and shop_draw_source.find("build_tower_node_hover_detail_layout") < 0,
		"production shop cells must bypass per-card hover-detail layout"
	)


func _verify_compact_unavailable_reason_reserves_description_row() -> void:
	var shop_modal := _build_six_card_modal("shop")
	var renderer := RuntimePerkOverlayRenderer.new()
	var reason := "금화 150 필요, 30 부족"
	var disabled_action := _chance_gem_shop_action(false, reason)
	var no_reason_action := _chance_gem_shop_action(false, "")
	for view_size in [BASE_VIEW_SIZE, LIVE_VIEW_SIZE]:
		var card_rect := shop_modal.get_action_rects(view_size)[5] as Rect2
		var disabled_layout := renderer.build_tower_node_card_text_layout(
			disabled_action,
			card_rect
		)
		var no_reason_layout := renderer.build_tower_node_card_text_layout(
			no_reason_action,
			card_rect
		)
		var no_reason_rows: Array = no_reason_layout.get("description_rows", [])
		var disabled_rows: Array = disabled_layout.get("description_rows", [])
		_expect(
			bool(disabled_layout.get("compact_card", false)),
			"chance-gem overlap leg requires the compact shop profile at %s" % view_size
		)
		_expect(
			no_reason_rows.size() >= 2,
			"counterproof fixture must expose at least two compact description rows at %s" % view_size
		)
		_expect(
			bool(disabled_layout.get("unavailable_reason_row_reserved", false)),
			"a disabled compact card with a visible reason must reserve one description row at %s" % view_size
		)
		_expect(
			int(disabled_layout.get("description_row_budget", -1))
			<= int(no_reason_layout.get("description_row_budget", -1)) - 1,
			"compact unavailable reason must reduce the description row budget by at least one at %s" % view_size
		)
		_expect(
			int(disabled_layout.get("unavailable_reason_row_omitted_count", 0))
			== no_reason_rows.size() - disabled_rows.size(),
			"compact unavailable reason must report every wholly omitted row at %s" % view_size
		)
		if view_size == LIVE_VIEW_SIZE:
			_expect(
				int(disabled_layout.get("unavailable_reason_row_omitted_count", 0)) == 1,
				"the acceptance-resolution compact card must yield exactly one description row"
			)
		for row_index in range(disabled_rows.size()):
			_expect(
				str(disabled_rows[row_index]) == str(no_reason_rows[row_index]),
				"reason reservation must keep every retained description row whole at %s" % view_size
			)
		var compact_scale := float(disabled_layout.get("compact_scale", 0.0))
		var description_font_size := int(disabled_layout.get("description_font_size", 0))
		var description_start := card_rect.position.y + 64.0 * compact_scale
		var description_step := 12.0 * compact_scale
		var reason_center_y := card_rect.end.y - 31.0 * compact_scale
		var unreserved_last_baseline := (
			description_start + float(no_reason_rows.size() - 1) * description_step
		)
		_expect(
			absf(unreserved_last_baseline - reason_center_y) < float(description_font_size),
			"RED counterproof requires the unreserved last description baseline to overlap the reason lane at %s" % view_size
		)
		if not disabled_rows.is_empty():
			var reserved_last_baseline := (
				description_start + float(disabled_rows.size() - 1) * description_step
			)
			_expect(
				absf(reserved_last_baseline - reason_center_y) >= float(description_font_size),
				"reserved compact description rows must clear the unavailable-reason lane at %s" % view_size
			)

	var legacy_modal := _build_six_card_modal("fallen_monk")
	var legacy_rect := legacy_modal.get_action_rects(BASE_VIEW_SIZE)[0] as Rect2
	var legacy_reason_layout := renderer.build_tower_node_card_text_layout(
		disabled_action,
		legacy_rect
	)
	var legacy_no_reason_layout := renderer.build_tower_node_card_text_layout(
		no_reason_action,
		legacy_rect
	)
	_expect(
		not bool(legacy_reason_layout.get("compact_card", true)),
		"negative leg requires the established noncompact card profile"
	)
	_expect(
		not bool(legacy_reason_layout.get("unavailable_reason_row_reserved", true)),
		"noncompact cards must not reserve a description row for the legacy reason lane"
	)
	_expect(
		int(legacy_reason_layout.get("description_row_budget", -1))
		== int(legacy_no_reason_layout.get("description_row_budget", -2)),
		"noncompact unavailable reasons must preserve the established description budget"
	)


func _verify_compact_hover_detail_lane_geometry() -> void:
	var modal := _build_six_card_modal("training")
	var renderer := RuntimePerkOverlayRenderer.new()
	var action := _training_card_action(0)
	var choice: Dictionary = action.get("payload", {}).get("choice", {})
	choice["name"] = "유운보"
	choice["bonus_badge_text"] = "고정 +1칸"
	action["enabled"] = false
	action["unavailable_reason"] = "효과 한계"
	for view_size in [BASE_VIEW_SIZE, LIVE_VIEW_SIZE]:
		var card_rect := modal.get_action_rects(view_size)[0] as Rect2
		var layout: Dictionary = renderer.build_tower_node_card_text_layout(action, card_rect)
		_expect(
			bool(layout.get("compact_card", false)),
			"hover lane geometry leg requires the compact training profile at %s" % view_size
		)
		var compact_scale := float(layout.get("compact_scale", 0.0))
		var description_font := int(layout.get("description_font_size", 0))
		var description_start := card_rect.position.y + 64.0 * compact_scale
		var description_step := 12.0 * compact_scale
		var badge_lane_top := card_rect.end.y - 18.0 * compact_scale
		var training_hover_layout := renderer.build_tower_node_hover_detail_layout(
			action,
			card_rect
		)
		var training_hover_rows: Array = training_hover_layout.get("rows", [])
		_expect(
			training_hover_rows.size() == 2,
			"training hover must reach only target-cost and rejection rows at %s" % view_size
		)
		_expect(
			not RuntimePerkOverlayRenderer.tower_node_compact_hover_consumes_badge_lane(
				true,
				training_hover_rows.size()
			),
			"two-row training hover must never consume the fixed-exception badge lane at %s" % view_size
		)
		for detail_index in range(3):
			var baseline := RuntimePerkOverlayRenderer.tower_node_hover_detail_row_baseline(
				card_rect,
				true,
				compact_scale,
				detail_index
			)
			_expect(
				is_equal_approx(
					baseline,
					description_start + float(detail_index) * description_step
				),
				"compact hover detail row %d must land on the scaled description grid at %s" % [detail_index, view_size]
			)
		var two_row_last := RuntimePerkOverlayRenderer.tower_node_hover_detail_row_baseline(
			card_rect,
			true,
			compact_scale,
			1
		)
		_expect(
			two_row_last < badge_lane_top,
			"a two-row compact hover detail must stay above the badge lane at %s" % view_size
		)
		# RED counterproof: the retired bottom-anchored raw-pixel lane collides
		# with an idle compact row (Lv baseline or a description baseline) — the
		# overlap this slice removes must stay refutable.
		var idle_baselines: Array[float] = [card_rect.position.y + 45.0 * compact_scale]
		for row_index in range(3):
			idle_baselines.append(description_start + float(row_index) * description_step)
		var legacy_collides := false
		for detail_index in range(2):
			var legacy_baseline := RuntimePerkOverlayRenderer.tower_node_hover_detail_row_baseline(
				card_rect,
				false,
				compact_scale,
				detail_index
			)
			for idle_baseline in idle_baselines:
				if absf(legacy_baseline - idle_baseline) < float(description_font):
					legacy_collides = true
		_expect(
			legacy_collides,
			"counterproof requires the legacy bottom-anchored lane to overprint an idle compact row at %s" % view_size
		)
	# GRT-021 whole-row yield policy: any visible hover detail owns the
	# description grid. Training now tops out at two rows; three-row sibling-node
	# details still consume the fixed badge lane through the shared renderer.
	_expect(
		RuntimePerkOverlayRenderer.tower_node_compact_hover_owns_description_lane(true, 1),
		"one visible hover detail row must own the compact description lane"
	)
	_expect(
		not RuntimePerkOverlayRenderer.tower_node_compact_hover_owns_description_lane(true, 0),
		"an idle compact card must keep drawing its description rows"
	)
	_expect(
		not RuntimePerkOverlayRenderer.tower_node_compact_hover_owns_description_lane(false, 2),
		"the tall legacy profile must never yield its description rows to hover"
	)
	_expect(
		RuntimePerkOverlayRenderer.tower_node_compact_hover_consumes_badge_lane(true, 3),
		"a three-row compact hover detail must consume the badge lane whole"
	)
	_expect(
		not RuntimePerkOverlayRenderer.tower_node_compact_hover_consumes_badge_lane(true, 2),
		"a two-row compact hover detail must leave the fixed-exception badge visible"
	)
	# 코덱스 리뷰(8/23): 진입 120ms·이탈 90ms 블렌드 동안 설명은 이미
	# 양보했으므로 compact 상세는 원자 교체(완전 불투명)여야 한다.
	_expect(
		is_equal_approx(
			RuntimePerkOverlayRenderer.tower_node_hover_detail_alpha(true, 0.05), 1.0
		)
		and is_equal_approx(
			RuntimePerkOverlayRenderer.tower_node_hover_detail_alpha(true, 1.0), 1.0
		),
		"compact hover detail must swap in fully opaque at any live blend"
	)
	_expect(
		is_equal_approx(
			RuntimePerkOverlayRenderer.tower_node_hover_detail_alpha(true, 0.0), 0.0
		),
		"an idle compact card must not draw a hover detail surface"
	)
	_expect(
		is_equal_approx(
			RuntimePerkOverlayRenderer.tower_node_hover_detail_alpha(false, 0.4), 0.4
		),
		"the tall legacy profile keeps its fade because its rows never yield"
	)


func _verify_training_hanji_chrome_assets_and_gate() -> void:
	# 피드백2 10항: 수련장 모달 한지 크롬 자산 프리웜과 게이트 봉인.
	var renderer := TowerAscentFlowRenderer.new()
	var chrome: Dictionary = renderer.get_training_hanji_chrome_debug_state()
	_expect(
		bool(chrome.get("surface_loaded", false)),
		"training hanji surface texture must prewarm through the flow renderer"
	)
	_expect(
		bool(chrome.get("frame_loaded", false)),
		"training ledger frame texture must prewarm through the flow renderer"
	)
	_expect(
		str(chrome.get("render_mode", "")) == "hanji",
		"training modal must select the hanji chrome route with both assets live"
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var chrome_gate := source.find("training_hanji_chrome := (")
	_expect(
		chrome_gate >= 0
		and source.find("LAYOUT_FLAG_TRAINING_STAGE", chrome_gate) > chrome_gate,
		"hanji chrome must gate on the training layout flag"
	)
	_expect(
		source.find("canvas.draw_rect(modal_rect, Color(\"f7e9c8\"), true)") >= 0,
		"non-training node modals must retain the flat chrome fallback"
	)


func _build_six_card_modal(node_kind: String) -> Object:
	var modal := TowerAscentNodeModalState.new()
	var actions: Array[Dictionary] = []
	for index in range(6):
		actions.append(_training_card_action(index, node_kind))
	modal.open("layout-%s" % node_kind, node_kind, {"muhon": 20, "gold": 120}, actions)
	return modal


func _training_card_action(index: int, node_kind: String = "training") -> Dictionary:
	return {
		"id": "%s-card-%d" % [node_kind, index],
		"label": "수련 카드 %d" % index,
		"cost_text": "2 무혼",
		"enabled": true,
		"payload": {
			"choice": {
				"id": "%s-card-%d" % [node_kind, index],
				"name": "체질 수련 선택지 %d" % index,
				"description": "몸을 단련해 실제 전투 능력치를 높입니다.",
				"level_text": "Lv.2 → Lv.3",
			},
		},
	}


func _chance_gem_shop_action(enabled: bool, unavailable_reason: String) -> Dictionary:
	return {
		"id": "shop_purchase:chance_gem_1",
		"label": "기회의 보석",
		"cost_text": "150 금화",
		"enabled": enabled,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"choice": {
				"id": "chance_gem",
				"name": "기회의 보석",
				"description": "패배 후 도전을 이어갈 때 쓰는 보석을 1개 얻습니다.",
				"level_text": "탑 물자",
				"card_content_kind": "chance_gem",
				"icon_color": Color(0.33, 0.72, 1.0),
			},
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
