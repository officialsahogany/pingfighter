extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentRestNode := preload(
	"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
)

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)

var _failures: Array[String] = []


class FakeRunState:
	extends RefCounted
	var muhon := 99
	var chance_gems := 1

	func export_economy() -> Dictionary:
		return {"muhon": muhon, "gold": 0, "chance_gems": chance_gems}

	func get_chance_gems() -> int:
		return chance_gems


class FakeLingpetRuntime:
	extends RefCounted

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		return [{"type": "duration", "label": "지속시간 강화", "weight": 1.0}]


class FakeRegistry:
	extends RefCounted
	var runtime: Object

	func _init(runtime_value: Object) -> void:
		runtime = runtime_value

	func get_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null


class FakeOwner:
	extends RefCounted
	var sealed_projection: Array = []

	func set_tower_ascent_guardian_projection(
		sealed_guardians: Array,
		_soul_summoning_owned: bool
	) -> void:
		sealed_projection = sealed_guardians.duplicate(true)


class CardDrawProbe:
	extends Node2D
	var renderer: Object
	var actions: Array[Dictionary] = []
	var rects: Array[Rect2] = []

	func _draw() -> void:
		for index in range(mini(actions.size(), rects.size())):
			renderer.draw_tower_node_card(
				self,
				actions[index],
				rects[index],
				false,
				null,
				index,
				null,
				{}
			)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var spring_fixture := _build_full_spring_fixture()
	_verify_live_portrait_adapter(spring_fixture)
	_verify_portrait_prewarm_registration()
	_verify_visible_page_contract(spring_fixture)
	_verify_rest_hero_adapter()
	_verify_seven_locale_append_budgets(spring_fixture)
	await _verify_no_hover_draw_gate(spring_fixture)
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("tower_guardian_spring_rest_card_adapter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_full_spring_fixture() -> Dictionary:
	var pet_ids := LingpetCatalog.get_debug_pet_ids()
	_expect(pet_ids.size() >= 4, "full spring fixture requires at least four live guardians")
	if pet_ids.is_empty():
		return {}
	var active_pet_id := str(pet_ids[0])
	var sealed_guardians: Array[Dictionary] = []
	for index in range(1, pet_ids.size()):
		var pet_id := str(pet_ids[index])
		sealed_guardians.append({
			"pet_id": pet_id,
			"display_name": LingpetCatalog.get_display_name(pet_id),
		})
	var spring := TowerAscentGuardianSpringNode.new()
	spring.restore_state({
		"soul_summoning_owned": true,
		"soul_summoning_node_id": "earlier-spring",
		"active_guardian": {
			"pet_id": active_pet_id,
			"display_name": LingpetCatalog.get_display_name(active_pet_id),
		},
		"sealed_guardians": sealed_guardians,
	})
	var run_state := FakeRunState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(FakeLingpetRuntime.new())
	var actions: Array[Dictionary] = spring.build_actions(
		"s4-full-spring",
		41204,
		run_state,
		owner,
		registry
	)
	_expect(
		actions.size() == 1,
		"retired sealed roster must leave only the active guardian enhancement action"
	)
	_expect((spring.export_state().get("sealed_guardians", []) as Array).is_empty(), "legacy sealed entries must be discarded on restore")
	spring.sync_owner_projection(owner)
	_expect(owner.sealed_projection.is_empty(), "owner projection must publish an empty compatibility roster")
	return {
		"spring": spring,
		"run_state": run_state,
		"owner": owner,
		"registry": registry,
		"actions": actions,
		"active_pet_id": active_pet_id,
		"sealed_count": sealed_guardians.size(),
	}


func _verify_live_portrait_adapter(fixture: Dictionary) -> void:
	var actions: Array = fixture.get("actions", [])
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var payload: Dictionary = action.get("payload", {})
		var choice: Dictionary = payload.get("choice", {})
		var pet_id := str(payload.get("pet_id", ""))
		var portrait_path := str(choice.get("guardian_portrait_path", ""))
		_expect(str(choice.get("card_content_kind", "")) == "guardian_portrait", "spring guardian work must use the portrait card content mode")
		_expect(not pet_id.is_empty(), "every full-fixture spring action must identify its guardian")
		_expect(portrait_path == LingpetCatalog.get_visual_path(pet_id, "cutin_art"), "spring portrait path must come from the live cutin_art catalog")
		_expect(FileAccess.file_exists(portrait_path), "spring portrait source must already exist: %s" % portrait_path)
		_expect(bool(choice.get("tower_node_strict_text_budget", false)), "spring card copy must use the strict GRT-021 budget")
		var presentation: Dictionary = payload.get("presentation", {})
		_expect(not str(presentation.get("current", "")).is_empty(), "spring card must expose its current seal/active state")
		_expect(not str(presentation.get("result", "")).is_empty(), "spring card must expose its projected result")
		_expect(bool(presentation.get("strict_text_budget", false)), "spring hover copy must use the strict GRT-021 budget")
	var spring: Object = fixture.get("spring", null)
	var soul_action_value: Variant = spring.call("_build_soul_summoning_action")
	var soul_action: Dictionary = soul_action_value as Dictionary
	var soul_choice: Dictionary = soul_action.get("payload", {}).get("choice", {})
	_expect(str(soul_choice.get("card_content_kind", "")) == "guardian_egg", "soul summoning must keep the existing guardian egg art mode")
	_expect(str(soul_choice.get("icon_id", "")) == "guardian_spirit_egg", "soul summoning must resolve the existing guardian egg asset")


func _verify_portrait_prewarm_registration() -> void:
	var icon_renderer := RuntimePerkIconRenderer.new()
	var jobs_value: Variant = icon_renderer.call("_build_prewarm_asset_jobs")
	var portrait_paths := {}
	if jobs_value is Array:
		for job_value in jobs_value as Array:
			if not (job_value is Dictionary):
				continue
			var job := job_value as Dictionary
			if str(job.get("type", "")) == "guardian_portrait":
				portrait_paths[str(job.get("path", ""))] = true
	for pet_id in LingpetCatalog.get_debug_pet_ids():
		var expected_path := LingpetCatalog.get_visual_path(pet_id, "cutin_art")
		_expect(
			portrait_paths.has(expected_path),
			"live guardian cutin_art must be registered in the non-hot prewarm path: %s"
			% expected_path
		)


func _verify_visible_page_contract(fixture: Dictionary) -> void:
	var actions: Array = fixture.get("actions", [])
	var modal := TowerAscentNodeModalState.new()
	modal.open("s4-page", "guardian_spring", {"muhon": 99}, actions)
	_expect(modal.get_page_count() == 1, "retired sealed roster must fit the spring menu on one page")
	var model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
	var flags: Dictionary = model.get("layout_flags", {})
	_expect(not bool(flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_PAGE_CONTROLS, true)), "single-action spring model must not carry page controls")
	var rects: Array = model.get("action_rects", [])
	_expect(_count_area_rects(rects) == 2, "spring model must draw one action plus the fixed end-work action")
	var end_index := _find_action_index(model.get("actions", []), TowerAscentNodeModalState.ACTION_END_WORK)
	_expect(end_index >= 0 and (rects[end_index] as Rect2).is_equal_approx(TowerAscentNodeModalState.END_WORK_RECT), "end work must remain fixed independently of visible_page")
	var action_corner := (rects[0] as Rect2).position + Vector2(2.0, 2.0)
	_expect(modal.select_at_position(action_corner, BASE_VIEW_SIZE), "spring action top corner must share the rendered rect")
	_expect(modal.get_selected_action() == actions[0], "spring top corner must select the sole enhancement action")


func _verify_rest_hero_adapter() -> void:
	var run_state := FakeRunState.new()
	var rest := TowerAscentRestNode.new()
	var actions: Array[Dictionary] = rest.build_actions("s4-rest", run_state)
	_expect(actions.size() == 1, "rest must keep one authoritative recovery action")
	var action: Dictionary = actions[0]
	var payload: Dictionary = action.get("payload", {})
	var choice: Dictionary = payload.get("choice", {})
	var presentation: Dictionary = payload.get("presentation", {})
	_expect(str(choice.get("presentation_mode", "")) == "hero", "rest must request the shared hero card presentation mode")
	_expect(str(choice.get("card_content_kind", "")) == "chance_gem", "rest hero card must reuse the existing chance-gem symbol")
	_expect(str(presentation.get("current", "")) == "1" and str(presentation.get("result", "")) == "2", "rest hero card must show current to projected chance gems")
	var modal := TowerAscentNodeModalState.new()
	modal.open("s4-rest", "rest", run_state.export_economy(), actions)
	var model: Dictionary = modal.build_view_model(BASE_VIEW_SIZE)
	var flags: Dictionary = model.get("layout_flags", {})
	_expect(bool(flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_HERO_CARD, false)), "rest model must carry the hero-card layout flag")
	_expect(not bool(flags.get(TowerAscentNodeModalState.LAYOUT_FLAG_PAGE_CONTROLS, true)), "rest hero card must not inherit spring page controls")
	var rects: Array = model.get("action_rects", [])
	_expect(rects.size() == 2, "rest model must expose one hero card plus end work")
	_expect((rects[0] as Rect2).is_equal_approx(TowerAscentNodeModalState.HERO_CARD_RECT), "rest action must occupy the centered hero rect")
	var hero_top_corner := (rects[0] as Rect2).position + Vector2(2.0, 2.0)
	_expect(modal.select_at_position(hero_top_corner, BASE_VIEW_SIZE), "rest hero top corner must hit the same rendered rect")
	_expect(str(modal.get_selected_action().get("id", "")) == TowerAscentRestNode.ACTION_RESTORE, "rest hero top corner must select the recovery action")


func _verify_seven_locale_append_budgets(fixture: Dictionary) -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var spring: Object = fixture.get("spring", null)
	var run_state: Object = fixture.get("run_state", null)
	var owner: Object = fixture.get("owner", null)
	var registry: Object = fixture.get("registry", null)
	var longest_production_append_count := 0
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(str(locale))
		var actions: Array[Dictionary] = spring.build_actions(
			"s4-full-spring",
			41204,
			run_state,
			owner,
			registry
		)
		for action in actions:
			var base_layout: Dictionary = renderer.build_tower_node_card_text_layout(
				action,
				_rect_for_card_index(0)
			)
			var appended_rows: Array = base_layout.get("description_rows", [])
			longest_production_append_count = maxi(
				longest_production_append_count,
				appended_rows.size()
			)
			_expect(int(base_layout.get("appended_description_row_count", -1)) == appended_rows.size(), "GRT-021 must report actual spring description appends in locale %s" % locale)
			_expect(int(base_layout.get("appended_text_row_count", -1)) == appended_rows.size(), "spring card append total must equal the rows really drawn in locale %s" % locale)
			if bool(base_layout.get("description_hidden_by_budget", false)):
				_expect(appended_rows.is_empty(), "over-budget production spring copy must disable the whole description in locale %s" % locale)
			else:
				_expect(appended_rows.size() <= 3, "production spring copy must remain inside its exact three-row budget in locale %s" % locale)
			var hover_layout: Dictionary = renderer.build_tower_node_hover_detail_layout(
				action,
				_rect_for_card_index(0)
			)
			var hover_rows: Array = hover_layout.get("rows", [])
			_expect(int(hover_layout.get("appended_hover_row_count", -1)) == hover_rows.size(), "GRT-021 must report actual spring hover appends in locale %s" % locale)
			_expect(hover_rows.size() <= 3, "spring hover detail must never append beyond three rows in locale %s" % locale)
			if bool(hover_layout.get("hidden_by_budget", false)):
				_expect(hover_rows.is_empty(), "over-budget spring hover detail must be disabled as a whole in locale %s" % locale)
	_expect(
		longest_production_append_count == 3,
		"seven-locale longest production spring copy must append exactly three rows, got %d"
		% longest_production_append_count
	)

	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var forced_long_action: Dictionary = (fixture.get("actions", []) as Array)[0].duplicate(true)
	var forced_payload: Dictionary = forced_long_action.get("payload", {})
	var forced_choice: Dictionary = forced_payload.get("choice", {})
	forced_choice["description"] = "수호령의 현재 봉인 상태와 활성 교체 결과와 강화 이후의 실제 적용 결과를 카드 안에서 한 글자도 잘리지 않게 모두 설명해야 하는 의도적으로 가장 긴 검증 문구입니다 반복 반복 반복"
	forced_payload["choice"] = forced_choice
	forced_payload["presentation"] = {
		"current": "현재 봉인 수호령의 아주 긴 상태 설명",
		"result": "교체 또는 흡수 뒤 적용될 아주 긴 결과 설명",
		"target": "가장 긴 이름을 가진 수호령 검증 대상",
		"strict_text_budget": true,
	}
	forced_long_action["payload"] = forced_payload
	forced_long_action["cost_text"] = "무료이지만 결과 설명의 전체 의미를 보존해야 함"
	forced_long_action["unavailable_reason"] = "현재 활성 수호령이 없어 봉인 수호령을 흡수할 수 없으며 먼저 다른 수호령을 활성화해야 합니다."
	var forced_base: Dictionary = renderer.build_tower_node_card_text_layout(
		forced_long_action,
		_rect_for_card_index(0)
	)
	_expect(bool(forced_base.get("description_hidden_by_budget", false)), "forced longest base copy must enter the insufficient-budget counterproof")
	_expect(int(forced_base.get("appended_description_row_count", -1)) == 0 and (forced_base.get("description_rows", []) as Array).is_empty(), "forced longest base copy must append zero partial rows")
	var forced_hover: Dictionary = renderer.build_tower_node_hover_detail_layout(
		forced_long_action,
		_rect_for_card_index(0)
	)
	_expect(bool(forced_hover.get("hidden_by_budget", false)), "forced longest hover copy must enter the insufficient-budget counterproof")
	_expect(int(forced_hover.get("appended_hover_row_count", -1)) == 0 and (forced_hover.get("rows", []) as Array).is_empty(), "forced longest hover copy must append zero partial rows")
	_expect(
		bool(renderer.call(
			"_tower_node_strict_receipt_owns_detail_area",
			forced_long_action,
			0.0,
			-1.0
		)),
		"strict Spring/Rest success receipt must own the lower detail area without overlap"
	)


func _verify_no_hover_draw_gate(fixture: Dictionary) -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var rest := TowerAscentRestNode.new()
	var rest_actions := rest.build_actions("s4-rest-idle", FakeRunState.new())
	var spring_actions: Array = fixture.get("actions", [])
	var probe := CardDrawProbe.new()
	probe.renderer = renderer
	probe.actions = [spring_actions[0], rest_actions[0]]
	probe.rects = [_rect_for_card_index(0), TowerAscentNodeModalState.HERO_CARD_RECT]
	get_root().add_child(probe)
	renderer.reset_tower_node_feedback_debug_counters()
	probe.queue_redraw()
	await process_frame
	await process_frame
	var counters: Dictionary = renderer.get_tower_node_feedback_debug_counters()
	_expect(int(counters.get("hover_layout_build_count", -1)) == 0, "GRT-043 Spring/Rest idle draw must build zero hover layouts")
	_expect(int(counters.get("dynamic_layer_draw_count", -1)) == 0, "GRT-043 Spring/Rest idle draw must append zero dynamic feedback layers")
	probe.queue_free()


func _rect_for_card_index(index: int) -> Rect2:
	var column_width := (
		TowerAscentNodeModalState.CARD_GRID_RECT.size.x
		- TowerAscentNodeModalState.GRID_COLUMN_GAP
		* float(TowerAscentNodeModalState.CARD_GRID_COLUMNS - 1)
	) / float(TowerAscentNodeModalState.CARD_GRID_COLUMNS)
	var row_height := (
		TowerAscentNodeModalState.CARD_GRID_RECT.size.y
		- TowerAscentNodeModalState.GRID_ROW_GAP
		* float(TowerAscentNodeModalState.CARD_GRID_ROWS - 1)
	) / float(TowerAscentNodeModalState.CARD_GRID_ROWS)
	return Rect2(
		TowerAscentNodeModalState.CARD_GRID_RECT.position + Vector2(
			float(index % TowerAscentNodeModalState.CARD_GRID_COLUMNS)
			* (column_width + TowerAscentNodeModalState.GRID_COLUMN_GAP),
			float(index / TowerAscentNodeModalState.CARD_GRID_COLUMNS)
			* (row_height + TowerAscentNodeModalState.GRID_ROW_GAP)
		),
		Vector2(column_width, row_height)
	)


func _count_area_rects(rects: Array) -> int:
	var count := 0
	for rect_value in rects:
		if rect_value is Rect2 and (rect_value as Rect2).has_area():
			count += 1
	return count


func _find_action_index(actions: Array, action_id: String) -> int:
	for index in range(actions.size()):
		if actions[index] is Dictionary and str((actions[index] as Dictionary).get("id", "")) == action_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
