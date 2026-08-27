extends SceneTree

const TowerAscentFlowEconomyProgress := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)

var _failures: Array[String] = []


class CapacityRuntime:
	extends RefCounted
	var capacity := 3

	func _init(capacity_value: int) -> void:
		capacity = capacity_value

	func get_active_item_slot_capacity(_base_count: int) -> int:
		return capacity


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeOwner:
	extends RefCounted
	var active_item_slots: Array = []


class ShopDrawProbe:
	extends Node2D
	var flow_renderer: Object
	var card_renderer: Object
	var model: Dictionary = {}

	func _draw() -> void:
		flow_renderer.call(
			"_draw_node_modal",
			self,
			model,
			{"card_renderer": card_renderer}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_production_capacity_projection()
	await _verify_actual_draw_path_budget_and_negative_leg()
	if _failures.is_empty():
		print("tower_shop_owned_slot_capacity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_production_capacity_projection() -> void:
	for expected_capacity in [3, 5, 8]:
		var registry := FakeRegistry.new()
		if expected_capacity >= 5:
			registry.instances["runtime_perk_state"] = CapacityRuntime.new(5)
		if expected_capacity == 8:
			registry.instances["mythic_item_runtime"] = CapacityRuntime.new(8)
		var owner := FakeOwner.new()
		owner.active_item_slots = [{
			"name": "capacity-probe",
			"display_name": "용량 표본",
			"description": "capacity projection",
		}]
		var economy := TowerAscentFlowEconomyProgress.new()
		economy.set("_active_registry", registry)
		economy.set("_active_owner", owner)
		var projected: Array = economy.call("_build_shop_owned_items")
		_expect(
			projected.size() == expected_capacity,
			"production shop owner projection must expose %d active-item slots" % expected_capacity
		)
		_expect(
			not bool((projected[0] as Dictionary).get("empty_slot", false)),
			"the filled active slot must retain its original capacity index"
		)
		for slot_index in range(1, projected.size()):
			_expect(
				bool((projected[slot_index] as Dictionary).get("empty_slot", false))
				and int((projected[slot_index] as Dictionary).get("slot_index", -1)) == slot_index,
				"unused active slot %d/%d must be an explicit stable placeholder" % [slot_index, expected_capacity]
			)


func _verify_actual_draw_path_budget_and_negative_leg() -> void:
	var shop_modal := TowerAscentNodeModalState.new()
	shop_modal.open("draw-probe", "shop", {"gold": 830, "muhon": 12}, _shop_actions())
	var owned_items: Array[Dictionary] = []
	for slot_index in range(8):
		owned_items.append({"empty_slot": true, "slot_index": slot_index})
	shop_modal.set_shop_owned_items(owned_items)
	var flow_renderer := TowerAscentFlowRenderer.new()
	var shop_probe := ShopDrawProbe.new()
	shop_probe.flow_renderer = flow_renderer
	shop_probe.card_renderer = RuntimePerkOverlayRenderer.new()
	shop_probe.model = shop_modal.build_view_model()
	get_root().add_child(shop_probe)
	await process_frame
	shop_probe.queue_redraw()
	await process_frame
	var debug: Dictionary = flow_renderer.get_tower_shop_draw_debug_state_for_tests()
	_expect(int(debug.get("product_count", -1)) == 8, "actual shop _draw path must render exactly eight product cards")
	_expect(int(debug.get("owned_slot_count", -1)) == 8, "actual shop _draw path must render all eight capacity slots")
	_expect(int(debug.get("currency_entry_count", -1)) == 2, "shop header must render exactly gold and Muhon")
	_expect(bool(debug.get("used_stacked_layout", false)), "actual shop _draw path must use the stacked layout")
	_expect(
		bool(debug.get("within_ceiling", false))
		and int(debug.get("draw_ops", 9999)) <= int(debug.get("draw_op_ceiling", -1)),
		"actual shop _draw path must stay within its declared draw-operation ceiling"
	)
	shop_probe.queue_free()
	await process_frame

	var training_modal := TowerAscentNodeModalState.new()
	training_modal.open("negative-probe", "training", {"gold": 10, "muhon": 2}, [{
		"id": "training-probe",
		"label": "수련 표본",
		"payload": {"choice": {"name": "수련 표본", "description": "negative leg"}},
	}])
	var nonshop_renderer := TowerAscentFlowRenderer.new()
	var training_probe := ShopDrawProbe.new()
	training_probe.flow_renderer = nonshop_renderer
	training_probe.card_renderer = RuntimePerkOverlayRenderer.new()
	training_probe.model = training_modal.build_view_model()
	get_root().add_child(training_probe)
	await process_frame
	training_probe.queue_redraw()
	await process_frame
	_expect(
		nonshop_renderer.get_tower_shop_draw_debug_state_for_tests().is_empty(),
		"training draw must not enter or mutate the shop-specific renderer path"
	)
	training_probe.queue_free()
	await process_frame


func _shop_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for index in range(8):
		actions.append({
			"id": "shop_purchase:draw-%d" % index,
			"label": "상품 %d" % (index + 1),
			"cost_gold": 60 + index * 10,
			"cost_text": "%d 금화" % (60 + index * 10),
			"enabled": true,
			"payload": {"choice": {
				"id": "draw-%d" % index,
				"name": "상품 %d" % (index + 1),
				"description": "한 줄 전체가 들어갈 때만 보이는 상품 설명",
				"level_text": "탑 물자",
				"card_content_kind": "chance_gem",
				"icon_color": Color(0.35, 0.72, 0.94),
			}},
		})
	return actions


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
