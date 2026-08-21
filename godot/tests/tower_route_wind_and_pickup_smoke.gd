extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentRoutePickupState := preload(
	"res://scripts/tower_ascent/tower_ascent_route_pickup_state.gd"
)
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const EXPECTED_LEG_COUNT := 7

var _failures: Array[String] = []
var _leg_count := 0


class WindFlow:
	extends RefCounted

	var indicator_visible := false
	var gauge_model_calls := 0
	var wind_model_calls := 0

	func has_visible_route_wind_indicator() -> bool:
		return indicator_visible

	func get_route_aim_gauge_model() -> Dictionary:
		gauge_model_calls += 1
		return {"visible": true, "origin": Vector2(380.0, 650.0)}

	func get_route_wind_model() -> Dictionary:
		wind_model_calls += 1
		return TowerAscentRouteWindPolicy.build_model(1, 2)


class WindCanvas:
	extends RefCounted

	var draw_calls := 0

	func draw_rect(
		_rect: Rect2,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		draw_calls += 1

	func draw_line(
		_from: Vector2,
		_to: Vector2,
		_color: Color,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		draw_calls += 1

	func draw_circle(
		_position: Vector2,
		_radius: float,
		_color: Color,
		_filled: bool = true,
		_width: float = -1.0,
		_antialiased: bool = false
	) -> void:
		draw_calls += 1

	func draw_colored_polygon(
		_points: PackedVector2Array,
		_color: Color,
		_uvs: PackedVector2Array = PackedVector2Array(),
		_texture: Texture2D = null
	) -> void:
		draw_calls += 1


class PickupOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var chance_gems_count := 0
	var chance_gems_max := 0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class PickupRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_wind_visibility_threshold()
	_verify_calm_draw_gate_skips_models_and_canvas()
	_verify_pickup_roll_layout_and_rng()
	_verify_swept_pickup_contact()
	_verify_currency_collection_and_double_consume_guard()
	_verify_active_item_bag_open_and_full_boundaries()
	_verify_retry_preserves_layout_and_cleanup_owns_clear()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(
		_leg_count == EXPECTED_LEG_COUNT,
		"all %d wind/pickup smoke legs must execute" % EXPECTED_LEG_COUNT
	)
	if _failures.is_empty():
		print("tower_route_wind_and_pickup_smoke: ok PASS=%d" % _leg_count)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_wind_visibility_threshold() -> void:
	_leg_count += 1
	var negligible := {
		"is_windy": true,
		"strength_ratio": TowerAscentRouteWindPolicy.INDICATOR_VISIBLE_STRENGTH_THRESHOLD * 0.5,
	}
	_expect(
		not TowerAscentRouteWindPolicy.is_indicator_visible(
			TowerAscentRouteWindPolicy.calm_model()
		),
		"calm wind must hide the indicator"
	)
	_expect(
		not TowerAscentRouteWindPolicy.is_indicator_visible(negligible),
		"sub-threshold wind must hide the indicator"
	)
	_expect(
		TowerAscentRouteWindPolicy.is_indicator_visible(
			TowerAscentRouteWindPolicy.build_model(-1, 1)
		),
		"the weakest authored route wind must show the indicator"
	)


func _verify_calm_draw_gate_skips_models_and_canvas() -> void:
	_leg_count += 1
	var renderer := TowerAscentFlowRenderer.new()
	var flow := WindFlow.new()
	var canvas := WindCanvas.new()
	renderer.debug_draw_route_wind_from_flow(canvas, flow)
	_expect(flow.gauge_model_calls == 0, "GRT-043: calm wind must not build the gauge model")
	_expect(flow.wind_model_calls == 0, "GRT-043: calm wind must not build the wind draw model")
	_expect(canvas.draw_calls == 0, "GRT-043: calm wind must issue zero wind-indicator draw calls")

	flow.indicator_visible = true
	renderer.debug_draw_route_wind_from_flow(canvas, flow)
	_expect(flow.gauge_model_calls == 1, "visible wind must build one gauge model")
	_expect(flow.wind_model_calls == 1, "visible wind must build one wind draw model")
	_expect(canvas.draw_calls > 0, "visible wind must draw the wind indicator")


func _verify_pickup_roll_layout_and_rng() -> void:
	_leg_count += 1
	var first := TowerAscentRoutePickupState.new()
	var second := TowerAscentRoutePickupState.new()
	var first_result := _begin_pickup_state(first, 92741)
	var second_result := _begin_pickup_state(second, 92741)
	_expect(bool(first_result.get("accepted", false)), "pickup roll must accept a valid active pool")
	_expect(
		first_result == second_result,
		"same gameplay RNG state must reproduce pickup rewards and layout"
	)
	var pickups: Array[Dictionary] = first.get_pickups()
	var gold_count := _count_pickup_kind(pickups, TowerAscentRoutePickupState.KIND_GOLD)
	var muhon_count := _count_pickup_kind(pickups, TowerAscentRoutePickupState.KIND_MUHON)
	var bag_count := _count_pickup_kind(pickups, TowerAscentRoutePickupState.KIND_ACTIVE_ITEM)
	_expect(
		gold_count >= TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MIN
		and gold_count <= TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MAX,
		"route entry must roll two to five gold pickups"
	)
	_expect(
		muhon_count >= TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MIN
		and muhon_count <= TowerAscentTuning.TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MAX,
		"route entry must roll two to five Muhon pickups"
	)
	_expect(bag_count == 1, "route entry must roll exactly one active-item bag")
	_expect(first.get_roll_count() == 1, "one route entry must consume one pickup roll")
	for first_index in range(pickups.size()):
		var first_position := _pickup_position(pickups[first_index])
		_expect(
			TowerAscentTuning.TEMP_ROUTE_PICKUP_PLACEMENT_RECT.has_point(first_position),
			"pickup centers must stay in the authored route placement rect"
		)
		for second_index in range(first_index + 1, pickups.size()):
			_expect(
				first_position.distance_to(_pickup_position(pickups[second_index]))
				>= TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_CENTER_GAP - 0.001,
				"pickup centers must preserve the minimum spacing seal"
			)
		for target in _route_targets():
			var target_position: Vector2 = target.get("position", Vector2.ZERO)
			_expect(
				first_position.distance_to(target_position)
				>= TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_TARGET_CENTER_GAP - 0.001,
				"pickups must not overlap route targets"
			)
			_expect(
				_distance_to_segment(
					first_position,
					TowerAscentTuning.TEMP_ROUTE_PICKUP_ROUTE_ORIGIN,
					target_position
				) >= TowerAscentTuning.TEMP_ROUTE_PICKUP_MIN_PATH_CENTER_GAP - 0.001,
				"pickups must not overlap the direct route brush corridor"
			)


func _verify_swept_pickup_contact() -> void:
	_leg_count += 1
	var runtime := TowerAscentRouteServeRuntime.new()
	_expect(
		bool(runtime.begin(null, null, TowerAscentRouteWindPolicy.calm_model()).get(
			"accepted",
			false
		)),
		"fixture route serve must start"
	)
	var pickup := {
		"id": "swept_gold",
		"kind": TowerAscentRoutePickupState.KIND_GOLD,
		"position": Vector2(380.0, 400.0),
		"hit_radius": 20.0,
		"consumed": false,
	}
	var pickups: Array[Dictionary] = [pickup]
	var no_targets: Array[Dictionary] = []
	runtime.debug_serve_toward(Vector2(380.0, 100.0))
	var result: Dictionary = runtime.update(1.0, no_targets, pickups)
	_expect(
		_variant_array(result.get("pickup_ids", [])).has("swept_gold"),
		"a fast ball segment must report the crossed pickup"
	)
	pickup["consumed"] = true
	pickups = [pickup]
	runtime.debug_serve_toward(Vector2(380.0, 100.0))
	result = runtime.update(1.0, no_targets, pickups)
	_expect(
		not _variant_array(result.get("pickup_ids", [])).has("swept_gold"),
		"consumed pickups must not report a second contact"
	)


func _verify_currency_collection_and_double_consume_guard() -> void:
	_leg_count += 1
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var owner := PickupOwner.new()
	var registry := PickupRegistry.new()
	_expect(
		flow.ensure_run_started(owner, {
			"run_id": "route-pickup-currency",
			"run_state": {"gold": 10, "muhon": 20},
		}),
		"currency fixture run must start"
	)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", registry)
	var state: Object = flow.get("_route_pickup_state")
	_expect(
		bool(_begin_pickup_state(state, 44331).get("accepted", false)),
		"currency fixture pickups must roll"
	)
	var currency_ids: Array[String] = []
	var gold_count := 0
	var muhon_count := 0
	for pickup in state.get_pickups():
		match str(pickup.get("kind", "")):
			TowerAscentRoutePickupState.KIND_GOLD:
				gold_count += 1
				currency_ids.append(str(pickup.get("id", "")))
			TowerAscentRoutePickupState.KIND_MUHON:
				muhon_count += 1
				currency_ids.append(str(pickup.get("id", "")))
	flow.call("_collect_route_pickup_contacts", currency_ids)
	var balances: Dictionary = flow.get_run_state_snapshot()
	_expect(int(balances.get("gold", 0)) == 10 + gold_count, "gold contacts must update run economy immediately")
	_expect(int(balances.get("muhon", 0)) == 20 + muhon_count, "Muhon contacts must update run economy immediately")
	flow.call("_collect_route_pickup_contacts", currency_ids)
	_expect(
		flow.get_run_state_snapshot() == balances,
		"replayed contact IDs must not double-credit route currency"
	)


func _verify_active_item_bag_open_and_full_boundaries() -> void:
	_leg_count += 1
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var active_runtime := ActiveItemRuntime.new()
	var registry := PickupRegistry.new()
	registry.instances["active_item_runtime"] = active_runtime

	var open_flow := TowerAscentFlowOwner.new()
	var open_owner := PickupOwner.new()
	open_flow.ensure_run_started(open_owner, {"run_id": "route-bag-open"})
	open_flow.set("_active_owner", open_owner)
	open_flow.set("_active_registry", registry)
	var open_state: Object = open_flow.get("_route_pickup_state")
	_begin_pickup_state(open_state, 55119)
	var open_bag_id := _first_pickup_id(open_state.get_pickups(), TowerAscentRoutePickupState.KIND_ACTIVE_ITEM)
	open_flow.call("_collect_route_pickup_contacts", [open_bag_id])
	_expect(open_owner.active_item_slots.size() == 1, "an open active slot must receive the route bag item")
	_expect(
		bool(open_state.get_pickup(open_bag_id).get("consumed", false)),
		"accepted route bag must be consumed"
	)

	var full_flow := TowerAscentFlowOwner.new()
	var full_owner := PickupOwner.new()
	full_owner.active_item_slots = [
		{"name": "banana"},
		{"name": "soap"},
		{"name": "grenade"},
	]
	full_flow.ensure_run_started(full_owner, {"run_id": "route-bag-full"})
	full_flow.set("_active_owner", full_owner)
	full_flow.set("_active_registry", registry)
	var full_state: Object = full_flow.get("_route_pickup_state")
	_begin_pickup_state(full_state, 71207)
	var full_bag_id := _first_pickup_id(full_state.get_pickups(), TowerAscentRoutePickupState.KIND_ACTIVE_ITEM)
	full_flow.call("_collect_route_pickup_contacts", [full_bag_id])
	_expect(full_owner.active_item_slots.size() == 3, "a full active inventory must reject route bag overflow")
	_expect(
		not bool(full_state.get_pickup(full_bag_id).get("consumed", false)),
		"a rejected full-slot route bag must remain available on the route screen"
	)


func _verify_retry_preserves_layout_and_cleanup_owns_clear() -> void:
	_leg_count += 1
	var state := TowerAscentRoutePickupState.new()
	_begin_pickup_state(state, 81031)
	var original_pickups: Array[Dictionary] = state.get_pickups()
	var runtime := TowerAscentRouteServeRuntime.new()
	runtime.begin(null, null, TowerAscentRouteWindPolicy.calm_model())
	runtime.debug_serve_miss()
	var no_targets: Array[Dictionary] = []
	var status := ""
	for _frame in range(240):
		var result: Dictionary = runtime.update(1.0 / 60.0, no_targets, state.get_pickups())
		status = str(result.get("status", ""))
		if status == TowerAscentRouteServeRuntime.STATUS_MISS:
			break
	_expect(status == TowerAscentRouteServeRuntime.STATUS_MISS, "fixture miss must reach the retry boundary")
	_expect(state.get_pickups() == original_pickups, "a missed serve must preserve pickup layout")
	_expect(state.get_roll_count() == 1, "a missed serve must not reroll route pickups")
	var map_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"
	).replace("\r\n", "\n")
	_expect(
		map_source.find(
			"_route_serve_runtime.finish_selection()\n\t_route_pickup_state.clear_route()"
		) >= 0,
		"target resolution must clear route pickups at the phase boundary"
	)
	state.reset()
	_expect(state.get_pickups().is_empty(), "route reset must remove all pickups")
	_expect(state.get_roll_count() == 0, "run reset must reset the pickup roll counter")


func _begin_pickup_state(state: Object, seed_value: int) -> Dictionary:
	var candidates: Array[Dictionary] = [{
		"name": "gauge_charge",
		"type": "active",
		"chance": 1.0,
	}]
	return state.begin(
		{"seed": seed_value, "state": seed_value},
		_route_targets(),
		candidates
	)


func _route_targets() -> Array[Dictionary]:
	return [
		{"id": "left", "position": Vector2(220.0, 150.0), "hit_radius": 36.0},
		{"id": "right", "position": Vector2(540.0, 150.0), "hit_radius": 36.0},
	]


func _count_pickup_kind(pickups: Array[Dictionary], kind: String) -> int:
	var count := 0
	for pickup in pickups:
		if str(pickup.get("kind", "")) == kind:
			count += 1
	return count


func _first_pickup_id(pickups: Array[Dictionary], kind: String) -> String:
	for pickup in pickups:
		if str(pickup.get("kind", "")) == kind:
			return str(pickup.get("id", ""))
	return ""


func _pickup_position(pickup: Dictionary) -> Vector2:
	var value: Variant = pickup.get("position", Vector2.ZERO)
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _variant_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf(
		(point - start).dot(segment) / segment.length_squared(),
		0.0,
		1.0
	)
	return point.distance_to(start + segment * ratio)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
