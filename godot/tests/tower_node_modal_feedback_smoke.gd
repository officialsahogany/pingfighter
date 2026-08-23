extends SceneTree

const TowerAscentFlowOwner := preload("res://scripts/tower_ascent/tower_ascent_flow_owner.gd")
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)

const VIEW_SIZE := Vector2(2020.0, 1246.0)

var _failures: Array[String] = []


class FakeRunState:
	extends RefCounted
	var balances := {"gold": 30, "muhon": 8, "chance_gems": 0}

	func can_afford(costs: Dictionary) -> Dictionary:
		for currency_value in costs.keys():
			var currency := str(currency_value)
			if int(balances.get(currency, 0)) < int(costs.get(currency, 0)):
				return {"accepted": false, "reason": "insufficient", "balances": balances.duplicate(true)}
		return {"accepted": true, "balances": balances.duplicate(true)}

	func apply_economy_transaction(costs: Dictionary, rewards: Dictionary) -> Dictionary:
		for currency_value in costs.keys():
			var currency := str(currency_value)
			balances[currency] = int(balances.get(currency, 0)) - int(costs.get(currency, 0))
		for currency_value in rewards.keys():
			var currency := str(currency_value)
			balances[currency] = int(balances.get(currency, 0)) + int(rewards.get(currency, 0))
		return {
			"accepted": true,
			"costs": costs.duplicate(true),
			"rewards": rewards.duplicate(true),
			"balances": balances.duplicate(true),
		}


class CountingRegistry:
	extends RefCounted
	var renderer: Object
	var runtime_state_requests := 0

	func _init(renderer_value: Object) -> void:
		renderer = renderer_value

	func get_cached_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			runtime_state_requests += 1
			return null
		if key == "runtime_perk_overlay_renderer":
			return renderer
		return null


class CardDrawProbe:
	extends Node2D
	var renderer: Object
	var action: Dictionary
	var visual_state: Dictionary
	var returned_layout: Dictionary = {}

	func _draw() -> void:
		returned_layout = renderer.draw_tower_node_card(
			self,
			action,
			Rect2(40.0, 40.0, 212.0, 212.0),
			false,
			null,
			0,
			null,
			visual_state
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_wall_clock_hover_and_fixed_rect()
	_verify_authoritative_receipt_and_deadlines()
	_verify_visual_plan_and_longest_hover_rows()
	_verify_no_hover_lookup_gate()
	_verify_shop_presentation_adapter()
	_verify_training_presentation_adapter()
	_verify_fallen_monk_presentation_adapter()
	_verify_feedback_localization_coverage()
	await _verify_no_hover_dynamic_layer_gate()
	_verify_presentation_rng_is_absent()
	if _failures.is_empty():
		print("tower_node_modal_feedback_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wall_clock_hover_and_fixed_rect() -> void:
	var modal := _build_modal()
	modal.set_clock_msec_for_tests(1000)
	var fixed_rects: Array = modal.get_action_rects(VIEW_SIZE)
	var top_corner := (fixed_rects[0] as Rect2).position + Vector2(2.0, 2.0)
	_expect(modal.update_hover_at_position(top_corner, VIEW_SIZE), "top-corner +2px must start hover")
	var start_visual: Dictionary = modal.build_view_model(VIEW_SIZE).get("interaction_visuals", [])[0]
	_expect(is_equal_approx(float(start_visual.get("hover_blend", -1.0)), 0.0), "hover must start at blend zero")
	modal.set_clock_msec_for_tests(1119)
	var before_enter: Dictionary = modal.build_view_model(VIEW_SIZE).get("interaction_visuals", [])[0]
	_expect(float(before_enter.get("hover_blend", 0.0)) < 1.0, "hover must not finish before 120ms")
	modal.set_clock_msec_for_tests(1120)
	var entered: Dictionary = modal.build_view_model(VIEW_SIZE).get("interaction_visuals", [])[0]
	_expect(is_equal_approx(float(entered.get("hover_blend", 0.0)), 1.0), "hover must finish at 120ms wall time")
	_expect(modal.update_hover_at_position(Vector2.ZERO, VIEW_SIZE), "moving outside must start hover release")
	modal.set_clock_msec_for_tests(1209)
	var before_exit: Dictionary = modal.build_view_model(VIEW_SIZE).get("interaction_visuals", [])[0]
	_expect(float(before_exit.get("hover_blend", 0.0)) > 0.0, "hover release must remain visible through 89ms")
	modal.set_clock_msec_for_tests(1210)
	var exited_model: Dictionary = modal.build_view_model(VIEW_SIZE)
	_expect(not bool(exited_model.get("has_pointer_visuals", true)), "hover release must finish at 90ms wall time")
	var after_rects: Array = modal.get_action_rects(VIEW_SIZE)
	_expect(after_rects.size() == fixed_rects.size(), "feedback must preserve action rect count")
	for index in range(fixed_rects.size()):
		_expect((after_rects[index] as Rect2).is_equal_approx(fixed_rects[index] as Rect2), "feedback must preserve fixed rect %d" % index)


func _verify_authoritative_receipt_and_deadlines() -> void:
	var run_state := FakeRunState.new()
	var result := TowerAscentNodeActionTransaction.new().apply_once(
		"feedback-transaction",
		{"muhon": 2},
		{},
		run_state,
		{}
	)
	_expect(result.get("balances_before", {}) == {"gold": 30, "muhon": 8, "chance_gems": 0}, "transaction must return its real pre-commit balances")
	_expect(result.get("balances", {}) == {"gold": 30, "muhon": 6, "chance_gems": 0}, "transaction must return its real post-commit balances")
	var modal := _build_modal()
	modal.set_balances(result.get("balances", {}))
	modal.set_clock_msec_for_tests(2000)
	modal.record_action_feedback(modal.get_selected_action(), result.merged({"message": "수련 완료"}, true))
	var receipt_model: Dictionary = modal.build_view_model()
	_expect(str(receipt_model.get("muhon_text", "")) == "무혼 8 → 6, -2", "currency receipt must use authoritative before/after values")
	var receipt: Dictionary = receipt_model.get("interaction_receipt", {})
	_expect(receipt.get("costs", {}) == result.get("costs", {}), "receipt costs must be copied from transaction result")
	_expect(receipt.get("balances", {}) == result.get("balances", {}), "receipt balances must be copied from transaction result")
	modal.set_clock_msec_for_tests(2419)
	_expect(not (modal.build_view_model().get("interaction_receipt", {}) as Dictionary).is_empty(), "success receipt must remain through 419ms")
	modal.set_clock_msec_for_tests(2420)
	_expect((modal.build_view_model().get("interaction_receipt", {}) as Dictionary).is_empty(), "success receipt must expire at 420ms")
	modal.set_clock_msec_for_tests(3000)
	modal.record_action_feedback(modal.get_selected_action(), {"accepted": false, "message": "무혼 부족"})
	_expect(str(modal.build_view_model().get("muhon_text", "")) == "무혼 6", "rejection must not start a currency delta")
	modal.set_clock_msec_for_tests(3159)
	_expect(not (modal.build_view_model().get("interaction_receipt", {}) as Dictionary).is_empty(), "rejection must remain through 159ms")
	modal.set_clock_msec_for_tests(3160)
	_expect((modal.build_view_model().get("interaction_receipt", {}) as Dictionary).is_empty(), "rejection must expire at 160ms")


func _verify_visual_plan_and_longest_hover_rows() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var pressed_plan := renderer.build_tower_node_card_visual_plan({"pressed": true})
	_expect((pressed_plan.get("content_offset", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(0.0, 2.0)), "press must move content down exactly 2px")
	_expect(is_equal_approx(float(pressed_plan.get("border_inset", 0.0)), 6.0), "press must contract the border inward")
	var hover_plan := renderer.build_tower_node_card_visual_plan({"hover_blend": 1.0})
	_expect(is_equal_approx(float(hover_plan.get("icon_scale", 0.0)), 1.08), "full hover must enlarge the icon by 8 percent")
	var longest_action := _action_fixture()
	longest_action["unavailable_reason"] = "효과 한계"
	var layout := renderer.build_tower_node_hover_detail_layout(
		longest_action,
		Rect2(0.0, 0.0, 212.0, 212.0)
	)
	var rows: Array = layout.get("rows", [])
	_expect(int(layout.get("appended_hover_row_count", -1)) == rows.size(), "GRT-021 must report the actual appended hover row count")
	_expect(rows.size() == 2, "training hover detail must consume exactly its target-cost and rejection rows")
	_expect(str(rows[1]).contains("거부"), "the longest disabled training hover copy must retain its rejection row")


func _verify_no_hover_lookup_gate() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var registry := CountingRegistry.new(renderer)
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active_registry", registry)
	flow.set("_active_owner", RefCounted.new())
	flow.set("_node_modal_kind", "training")
	var modal: Object = flow.get("_node_modal_state")
	modal.open("no-hover-gate", "training", {"muhon": 8}, [_action_fixture()])
	var idle_context := flow.get_node_modal_render_context()
	_expect(registry.runtime_state_requests == 0, "GRT-043 no-hover frame must request zero training runtime projections")
	_expect(not idle_context.has("hover_detail_context"), "idle training context must expose no retired hover projection payload")
	var corner := (modal.get_action_rects()[0] as Rect2).position + Vector2(2.0, 2.0)
	modal.update_hover_at_position(corner)
	var hover_context := flow.get_node_modal_render_context()
	_expect(registry.runtime_state_requests == 0, "GRT-043 hovered training card must also request zero runtime projections")
	_expect(not hover_context.has("hover_detail_context"), "hovered training context must expose no retired projection payload")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/hud/runtime_perk_overlay_renderer.gd"
	)
	var context_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_node_progress.gd"
	)
	_expect(not renderer_source.contains("_tower_node_training_hover_preview"), "retired training hover preview builder must be removed")
	_expect(not renderer_source.contains("_tower_node_hover_detail_preview"), "retired training hover preview cache must be removed")
	_expect(not context_source.contains("hover_detail_context"), "flow render context must remove the retired training hover projection injection")


func _verify_shop_presentation_adapter() -> void:
	var flow := TowerAscentFlowOwner.new()
	var run_state: Object = flow.get("_run_state")
	run_state.begin("shop-adapter", {"gold": 30, "muhon": 8})
	flow.set("_current_node_id", "shop-node")
	# GRT-051 sibling: _generated_shop_inventory is a TYPED Array[Dictionary].
	# set() with an untyped literal silently no-ops, so build the typed value
	# first. The old fixture never actually injected its stock and only passed
	# because the inventory builder happened to generate content.
	var fixture_inventory: Array[Dictionary] = [{
		"node_id": "shop-node",
		"stock": [{
			"stock_id": "shop-stock",
			"kind": "premium",
			"price": 12,
			"sold": false,
			"item_name": "adapter_item",
			"display_name": "검증 귀물",
			"description": "상점 어댑터 검증",
		}],
	}]
	flow.set("_generated_shop_inventory", fixture_inventory)
	var injected: Variant = flow.get("_generated_shop_inventory")
	_expect(
		injected is Array and (injected as Array).size() == 1,
		"shop adapter fixture inventory must actually be injected"
	)
	var actions: Array = flow.call("_build_shop_actions")
	_expect(not actions.is_empty(), "shop adapter must build at least one action from the injected stock")
	if actions.is_empty():
		return
	var presentation: Dictionary = actions[0].get("payload", {}).get("presentation", {})
	_expect(not str(presentation.get("current", "")).is_empty(), "shop adapter must expose current state")
	_expect(not str(presentation.get("result", "")).is_empty(), "shop adapter must expose result state")
	_expect(not str(presentation.get("target", "")).is_empty(), "shop adapter must expose its transaction target")


func _verify_training_presentation_adapter() -> void:
	var flow := TowerAscentFlowOwner.new()
	var action_value: Variant = flow.call("_build_training_action", "stat", {
		"id": "adapter_training",
		"name": "검증 체질",
		"current_level": 4,
		"next_level": 5,
		"description": "수련 어댑터 검증",
	}, 2, {"muhon": 8})
	var action: Dictionary = action_value as Dictionary
	var presentation: Dictionary = action.get("payload", {}).get("presentation", {})
	_expect(not presentation.has("current"), "training adapter must omit the retired current-value hover row")
	_expect(not presentation.has("result"), "training adapter must omit the retired result-value hover row")
	_expect(str(presentation.get("target", "")) == "검증 체질", "training adapter must expose its stat target")
	var layout := RuntimePerkOverlayRenderer.new().build_tower_node_hover_detail_layout(
		action,
		Rect2(0.0, 0.0, 212.0, 212.0)
	)
	var rows: Array = layout.get("rows", [])
	_expect(rows.size() == 1, "enabled training hover must expose only its target-cost row")
	if rows.size() == 1:
		_expect(not str(rows[0]).contains("→"), "training hover must not recreate a current-to-result row")


func _verify_fallen_monk_presentation_adapter() -> void:
	var flow := TowerAscentFlowOwner.new()
	var monk_node: Object = flow.get("_fallen_monk_node")
	var action_value: Variant = monk_node.call("_build_action", "remove", {
		"id": "adapter_chosik",
		"name": "검증 초식",
		"current_level": 1,
		"next_level": 2,
	}, "adapter_skill", null, {"muhon": 99})
	var action: Dictionary = action_value as Dictionary
	var presentation: Dictionary = action.get("payload", {}).get("presentation", {})
	_expect(str(presentation.get("current", "")) == "검증 초식", "fallen-monk adapter must expose the removed current target")
	_expect(not str(presentation.get("result", "")).is_empty(), "fallen-monk adapter must expose the resulting empty slot")
	_expect(str(presentation.get("target", "")) == "검증 초식", "fallen-monk adapter must expose its operation target")


func _verify_feedback_localization_coverage() -> void:
	var feedback_keys := [
		TowerAscentNodeModalLocalization.KEY_BALANCE_RECEIPT_MUHON,
		TowerAscentNodeModalLocalization.KEY_BALANCE_RECEIPT_GOLD,
		TowerAscentNodeModalLocalization.KEY_HOVER_CURRENT_RESULT,
		TowerAscentNodeModalLocalization.KEY_HOVER_TARGET_COST,
		TowerAscentNodeModalLocalization.KEY_HOVER_REJECTION,
		TowerAscentNodeModalLocalization.KEY_STATE_LISTED,
		TowerAscentNodeModalLocalization.KEY_STATE_OWNED,
		TowerAscentNodeModalLocalization.KEY_STATE_EMPTY,
	]
	_expect(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.size() == 7, "feedback copy seal requires all seven supported locale blocks")
	for locale_value in TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.keys():
		var locale_text: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(locale_value, {})
		for key in feedback_keys:
			_expect(locale_text.has(key) and not str(locale_text.get(key, "")).is_empty(), "feedback key missing from locale %s: %s" % [str(locale_value), str(key)])
	var source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd")
	_expect(source.find("—") < 0, "new Korean node-modal copy must not contain an em dash")


func _verify_no_hover_dynamic_layer_gate() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var probe := CardDrawProbe.new()
	probe.renderer = renderer
	probe.action = _action_fixture()
	probe.visual_state = {}
	get_root().add_child(probe)
	renderer.reset_tower_node_feedback_debug_counters()
	probe.queue_redraw()
	await process_frame
	await process_frame
	var idle_counters := renderer.get_tower_node_feedback_debug_counters()
	_expect(int(idle_counters.get("hover_layout_build_count", -1)) == 0, "GRT-043 idle draw must build zero hover layouts")
	_expect(not idle_counters.has("hover_detail_build_count"), "retired training projection counter must be removed")
	_expect(int(idle_counters.get("dynamic_layer_draw_count", -1)) == 0, "GRT-043 idle draw must add zero dynamic layers")
	renderer.reset_tower_node_feedback_debug_counters()
	probe.visual_state = {"hover_blend": 1.0, "node_accent": Color(0.84, 0.61, 0.28)}
	probe.queue_redraw()
	await process_frame
	await process_frame
	var hover_counters := renderer.get_tower_node_feedback_debug_counters()
	_expect(int(hover_counters.get("hover_layout_build_count", 0)) == 1, "hover layout must build once and remain cached across redraws")
	_expect(int(hover_counters.get("dynamic_layer_draw_count", 0)) > 0, "hover draw fixture must exercise the dynamic feedback path")
	probe.queue_free()


func _verify_presentation_rng_is_absent() -> void:
	for path in [
		"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd",
		"res://scripts/hud/runtime_perk_overlay_renderer.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(source.find("RandomNumberGenerator") < 0 and source.find("randf(") < 0 and source.find("randi(") < 0, "presentation feedback must consume no RNG: %s" % path)


func _build_modal() -> Object:
	var modal := TowerAscentNodeModalState.new()
	modal.open("feedback", "training", {"gold": 30, "muhon": 8}, [_action_fixture()])
	return modal


func _action_fixture() -> Dictionary:
	return {
		"id": "training_stat:common_bulk_up",
		"label": "체질 수련: 철산공",
		"cost_text": "2 무혼",
		"enabled": true,
		"payload": {
			"choice": {
				"id": "common_bulk_up",
				"name": "철산공",
				"description": "몸을 단련해 튕겨내는 힘과 버티는 힘을 함께 높입니다.",
				"current_level": 2,
				"next_level": 3,
				"level_text": "Lv.2 → Lv.3",
			},
			"presentation": {"target": "철산공"},
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
