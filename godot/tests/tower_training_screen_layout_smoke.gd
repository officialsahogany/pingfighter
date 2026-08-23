extends SceneTree

const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)
const LONGEST_KOREAN_BONUS_BADGE := "행운 발동 시 수련 효과 +50%"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_training_layout_flag_owns_render_and_hit_rects()
	_verify_shared_six_card_layouts_are_unchanged()
	_verify_training_stage_reservations()
	_verify_layout_cache_is_size_owned()
	_verify_bonus_badge_four_row_budget()
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


func _verify_shared_six_card_layouts_are_unchanged() -> void:
	for node_kind in ["shop", "fallen_monk"]:
		var modal := _build_six_card_modal(node_kind)
		var model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
		var flags: Dictionary = model.get("layout_flags", {})
		_expect(
			not bool(flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_TRAINING_STAGE, true)),
			"%s must not inherit the training-stage layout" % node_kind
		)
		var layout: Dictionary = modal.build_screen_layout(BASE_VIEW_SIZE, flags)
		_expect(
			(layout.get("card_grid_rect", Rect2()) as Rect2).is_equal_approx(TowerAscentNodeModalState.CARD_GRID_RECT),
			"%s must retain the established 438px card grid" % node_kind
		)
		var rects: Array = model.get("action_rects", [])
		_expect(
			(rects[6] as Rect2).is_equal_approx(TowerAscentNodeModalState.END_WORK_RECT),
			"%s must retain the established end-work footer" % node_kind
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


func _verify_bonus_badge_four_row_budget() -> void:
	var modal := _build_six_card_modal("training")
	var card_rect := modal.get_action_rects(BASE_VIEW_SIZE)[0] as Rect2
	var renderer := RuntimePerkOverlayRenderer.new()
	var action := _training_card_action(0)
	var choice: Dictionary = action.get("payload", {}).get("choice", {})
	choice["description"] = "수련 효과와 실제 적용값을 확인하는 가장 긴 설명 문구를 세 행 예산으로 정확하게 검증합니다 반복 문장"
	choice["bonus_badge_text"] = LONGEST_KOREAN_BONUS_BADGE
	var layout: Dictionary = renderer.build_tower_node_card_text_layout(action, card_rect)
	var description_rows: Array = layout.get("description_rows", [])
	var badge_rows: Array = layout.get("bonus_badge_rows", [])
	_expect(bool(layout.get("compact_card", false)), "production training card rect must select the compact card builder")
	_expect(description_rows.size() == 3, "longest compact training description must append exactly three rows")
	_expect(int(layout.get("appended_description_row_count", -1)) == 3, "description append count must be the actual three drawn rows")
	_expect(badge_rows.size() == 1, "longest Korean bonus badge must append exactly one complete row")
	_expect(str(badge_rows[0]) == LONGEST_KOREAN_BONUS_BADGE, "bonus badge row must preserve the complete Korean copy")
	_expect(not str(badge_rows[0]).ends_with("..."), "bonus badge must never be clipped with an ellipsis")
	_expect(int(layout.get("appended_bonus_badge_row_count", -1)) == 1, "bonus badge append count must equal its one drawn row")
	_expect(int(layout.get("appended_text_row_count", -1)) == 4, "GRT-021 compact training card must consume exactly 3 description rows plus 1 badge row")
	var live_card_rect := modal.get_action_rects(LIVE_VIEW_SIZE)[0] as Rect2
	var live_layout: Dictionary = renderer.build_tower_node_card_text_layout(action, live_card_rect)
	_expect(
		bool(live_layout.get("compact_card", false)),
		"large Vulkan viewport must keep the same aspect-ratio compact card profile"
	)
	_expect(
		int(live_layout.get("appended_description_row_count", -1)) == 2,
		"wide Vulkan training rail must append exactly two description rows"
	)
	_expect(
		int(live_layout.get("appended_text_row_count", -1)) == 3,
		"wide Vulkan training rail must append exactly two description rows plus one badge row"
	)
	var live_badge_rows: Array = live_layout.get("bonus_badge_rows", [])
	_expect(live_badge_rows.size() == 1, "large Vulkan viewport must append one complete badge row")
	if live_badge_rows.size() == 1:
		_expect(
			str(live_badge_rows[0]) == LONGEST_KOREAN_BONUS_BADGE,
			"large Vulkan viewport must preserve the complete Korean badge copy"
		)

	choice["bonus_badge_text"] = "행운 발동 시 이번 수련의 실제 능력치 적용값이 기본 수련값보다 오십 퍼센트 더 증가합니다"
	var insufficient_layout: Dictionary = renderer.build_tower_node_card_text_layout(action, card_rect)
	_expect(
		not bool(insufficient_layout.get("bonus_badge_visible", true)),
		"an over-budget Korean badge must be disabled as a whole"
	)
	_expect(
		(insufficient_layout.get("bonus_badge_rows", []) as Array).is_empty(),
		"an over-budget Korean badge must append zero partial rows"
	)
	_expect(
		bool(insufficient_layout.get("bonus_badge_hidden_by_budget", false)),
		"the builder must report the whole-badge budget rejection"
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
