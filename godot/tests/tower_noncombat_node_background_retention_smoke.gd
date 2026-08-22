extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentScreenSpaceSurfacePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd"
)

const ACCEPTANCE_VIEWPORT := Rect2(0.0, 0.0, 2020.0, 1246.0)

var _failures: Array[String] = []


class StageFallbackFlow:
	extends RefCounted

	func has_renderable_retained_noncombat_node_background() -> bool:
		return false

	func get_retained_noncombat_node_background_resolution() -> Dictionary:
		return {
			"kind": "shop",
			"source": "bitmap",
			"texture": null,
			"fallback_to_stage_background": true,
			"reason": "missing_asset",
		}


class RestCampFlow:
	extends RefCounted

	func has_renderable_retained_noncombat_node_background() -> bool:
		return true

	func get_retained_noncombat_node_background_resolution() -> Dictionary:
		return {
			"kind": "rest",
			"source": "procedural",
			"texture": null,
			"fallback_to_stage_background": false,
			"reason": "procedural_ready",
		}


class RouteAimFlow:
	extends RefCounted

	var draw_calls := 0
	var phase := "ROUTE_AIM"

	func has_renderable_retained_noncombat_node_background() -> bool:
		return false

	func is_active() -> bool:
		return true

	func get_phase_name() -> String:
		return phase

	func get_map_transition_visual_model() -> Dictionary:
		return {}

	func draw(_canvas: CanvasItem) -> void:
		draw_calls += 1


class SelectorBallPlayfieldDrawer:
	extends RefCounted

	var selector_draw_calls := 0
	var border_draw_calls := 0
	var player_draw_calls := 0

	func draw_tower_route_playfield_border(
		_canvas: CanvasItem,
		_width: float,
		_height: float
	) -> void:
		border_draw_calls += 1

	func draw_tower_route_player(
		_canvas: CanvasItem,
		_registry: Object,
		_shake_offset: Vector2
	) -> void:
		player_draw_calls += 1

	func draw_tower_route_selector_ball(
		_canvas: CanvasItem,
		_registry: Object,
		_shake_offset: Vector2,
		_width: float,
		_height: float
	) -> void:
		selector_draw_calls += 1


class CachedFlowRegistry:
	extends RefCounted

	var flow: Object
	var playfield: Object
	var cold_get_calls := 0

	func _init(value: Object, playfield_value: Object = null) -> void:
		flow = value
		playfield = playfield_value

	func get_cached_instance(key: String) -> Object:
		if key == "tower_ascent_flow_owner":
			return flow
		if key == "battle_playfield_scene_drawer":
			return playfield
		return null

	func get_instance(_key: String) -> Object:
		cold_get_calls += 1
		return null


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_rest_work_return_phase_and_retention()
	_verify_modal_close_retains_background_until_combat_selection()
	_verify_render_order_and_stage_fallback_contract()
	_verify_noncombat_playfield_suppression_and_route_restore()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_noncombat_node_background_retention_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_rest_work_return_phase_and_retention() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "rest-return-phase-probe",
		"current_stage": 4,
		"map_seed": 4,
		"node_modal_kind": "rest",
		"run_state": {"chance_gems": 2, "gold": 0, "muhon": 0},
	}), "rest return phase probe must begin")
	var rest_target := _find_target(flow.get_route_aim_targets(), "rest")
	_expect(not rest_target.is_empty(), "rest return phase probe must expose rest")
	if rest_target.is_empty():
		return
	flow.call("_resolve_route_target", str(rest_target.get("id", "")))
	flow.call("_complete_map_transition")
	var result: Dictionary = flow.execute_node_action(
		"rest:restore_chance_gem",
		"rest-return-phase-probe:restore"
	)
	_expect(bool(result.get("accepted", false)) and bool(result.get("applied", false)), "rest return phase probe must complete its work")
	print("[TowerNoncombatReturnProbe] phase=%s retained=%s playfield_flow=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_retained_noncombat_node_background_kind()),
		str(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			str(flow.get_phase_name())
		)),
	])
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_expect(flow.handle_input(escape), "rest work end input must be consumed")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "rest work end must enter ROUTE_AIM")
	_expect(flow.get_retained_noncombat_node_background_kind() == "rest", "rest work end must retain the rest arena")
	_expect(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
		flow.get_phase_name()
	), "ROUTE_AIM must remain a playfield-flow phase")
	print("[TowerNoncombatReturnProbe] phase=%s retained=%s playfield_flow=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_retained_noncombat_node_background_kind()),
		str(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			str(flow.get_phase_name())
		)),
	])


func _verify_modal_close_retains_background_until_combat_selection() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "noncombat-background-retention",
		"map_seed": 1,
	}), "retention fixture must begin")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "fixture must begin at post-combat route aim")
	_expect(flow.get_retained_noncombat_node_background_kind().is_empty(), "combat-owned entry must not start with a retained noncombat background")

	var spring_target := _find_target(flow.get_route_aim_targets(), "guardian_spring")
	_expect(not spring_target.is_empty(), "deterministic fixture must expose guardian_spring")
	if spring_target.is_empty():
		return
	flow.call("_resolve_route_target", str(spring_target.get("id", "")))
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "noncombat selection must enter map transition")
	flow.call("_complete_map_transition")
	_expect(flow.get_phase_name() == "NODE_MODAL", "noncombat arrival must open its node modal")
	_expect(flow.get_retained_noncombat_node_background_kind() == "guardian_spring", "arrival must retain the exact node background kind")

	var renderer := TowerAscentFlowRenderer.new()
	var modal_model := renderer.build_noncombat_node_background_model(
		flow,
		ACCEPTANCE_VIEWPORT
	)
	_verify_bitmap_model(modal_model, "guardian_spring", "NODE_MODAL")
	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(str(snapshot.get("retained_noncombat_background_kind", "")) == "guardian_spring", "stable node snapshot must persist the retained background kind")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "retained node-modal snapshot must restore")
	_expect(restored.get_retained_noncombat_node_background_kind() == "guardian_spring", "snapshot restore must retain the exact noncombat background")
	_verify_bitmap_model(
		renderer.build_noncombat_node_background_model(restored, ACCEPTANCE_VIEWPORT),
		"guardian_spring",
		"restored NODE_MODAL"
	)

	flow.debug_advance_to_route_aim()
	_expect(flow.get_phase_name() == "ROUTE_AIM", "closing the node modal must enter route aim")
	_expect(flow.get_retained_noncombat_node_background_kind() == "guardian_spring", "closing the modal must not release its arena background")
	_verify_bitmap_model(
		renderer.build_noncombat_node_background_model(flow, ACCEPTANCE_VIEWPORT),
		"guardian_spring",
		"post-modal ROUTE_AIM"
	)

	var combat_target := _find_combat_target(flow.get_route_aim_targets())
	_expect(not combat_target.is_empty(), "the reached optional node must expose a combat exit")
	if combat_target.is_empty():
		return
	flow.call("_resolve_route_target", str(combat_target.get("id", "")))
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "combat selection must enter map transition")
	_expect(flow.get_retained_noncombat_node_background_kind().is_empty(), "combat selection must release the noncombat background before its first transition frame")
	_expect(renderer.build_noncombat_node_background_model(flow, ACCEPTANCE_VIEWPORT).is_empty(), "released combat transition must expose the stage-owned background")
	flow.call("_complete_map_transition")
	_expect(not flow.is_active(), "combat arrival must close the tower overlay flow")
	_expect(flow.get_retained_noncombat_node_background_kind().is_empty(), "combat handoff must not retain a noncombat background")


func _verify_render_order_and_stage_fallback_contract() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	_expect(renderer.build_noncombat_node_background_model(
		StageFallbackFlow.new(),
		ACCEPTANCE_VIEWPORT
	).is_empty(), "missing art must draw no replacement over the stage-owned fallback")
	var rest_model := renderer.build_noncombat_node_background_model(
		RestCampFlow.new(),
		ACCEPTANCE_VIEWPORT
	)
	_expect(str(rest_model.get("kind", "")) == "rest", "rest must retain the existing camp identity")
	_expect(str(rest_model.get("source", "")) == "procedural", "rest must reuse R4's procedural camp without a fifth bitmap")
	_expect(rest_model.get("target_rect", Rect2()) == ACCEPTANCE_VIEWPORT, "rest camp must share the retained route viewport")

	var drawer_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_drawer.gd"
	)
	var draw_body := _function_body(drawer_source, "func draw(")
	var pillar_index := draw_body.find("_draw_pillar_scene(canvas")
	var background_index := draw_body.find("_draw_tower_noncombat_node_background(canvas")
	var playfield_index := draw_body.find("_draw_transformed_playfield_scene(canvas")
	_expect(pillar_index >= 0 and background_index > pillar_index, "the retained arena must draw above the stage background")
	_expect(playfield_index > background_index, "the retained arena must be established before the conditional playfield pass")
	_expect(drawer_source.find("arena_background_imagegen_v1.png") < 0, "BattleSceneDrawer must not own asset path literals")
	var transformed_body := _function_body(drawer_source, "func _draw_transformed_playfield_scene(")
	_expect(transformed_body.find("_should_draw_tower_battle_playfield(registry)") >= 0, "the common transformed-playfield owner must gate stale battle composition")
	_expect(transformed_body.find("_draw_playfield_scene(canvas") >= 0, "combat and stage fallback must retain the production playfield draw")
	_expect(transformed_body.find("_draw_tower_ascent_playfield_flow_only(canvas") >= 0, "noncombat route aim must retain only the tower-owned selector overlay")

	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var modal_body := _function_body(renderer_source, "func draw_fullscreen_node_modal(")
	_expect(modal_body.find("build_noncombat_node_background_model") >= 0, "NODE_MODAL must consume the shared S4 background model")
	_expect(modal_body.find("build_noncombat_node_background_model") < modal_body.find("_draw_node_modal(canvas, model)"), "NODE_MODAL must draw the arena before its work panel")
	_expect(renderer_source.find("arena_background_imagegen_v1.png") < 0, "the renderer must consume catalog results without path literals")

	var map_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"
	)
	var resolve_body := _function_body(map_source, "func _resolve_route_target(")
	_expect(resolve_body.find("_clear_retained_noncombat_node_background()") >= 0, "combat route selection must own an explicit background release")
	_expect(resolve_body.find("_clear_retained_noncombat_node_background()") < resolve_body.find("_phase = PHASE_MAP_TRANSITION"), "combat background release must precede the first transition frame")


func _verify_noncombat_playfield_suppression_and_route_restore() -> void:
	var drawer := preload("res://scripts/core/battle_scene_drawer.gd").new()
	var fallback_registry := CachedFlowRegistry.new(StageFallbackFlow.new())
	_expect(bool(drawer.call("_should_draw_tower_battle_playfield", fallback_registry)), "missing-art fallback must preserve the normal stage playfield")
	_expect(not bool(drawer.call("_should_suppress_tower_boss_skill_hud", fallback_registry)), "inactive/non-Tower fallback must preserve its battle boss-skill rail")
	_expect(fallback_registry.cold_get_calls == 0, "fallback decision must inspect only the cached tower owner")

	var rest_registry := CachedFlowRegistry.new(RestCampFlow.new())
	_expect(not bool(drawer.call("_should_draw_tower_battle_playfield", rest_registry)), "renderable noncombat rooms must suppress the previous arena and boss")
	_expect(rest_registry.cold_get_calls == 0, "noncombat suppression must inspect only the cached tower owner")

	var route_flow := RouteAimFlow.new()
	var route_playfield := SelectorBallPlayfieldDrawer.new()
	var route_registry := CachedFlowRegistry.new(route_flow, route_playfield)
	_expect(not bool(drawer.call("_should_draw_tower_battle_playfield", route_registry)), "initial ROUTE_AIM must suppress the stale full battle composition without a retained room")
	_expect(bool(drawer.call("_should_suppress_tower_boss_skill_hud", route_registry)), "active Tower route aim must suppress the previous boss-skill rail")
	drawer.call("_draw_tower_ascent_playfield_flow_only", null, route_registry)
	_expect(route_flow.draw_calls == 1, "ROUTE_AIM must keep the tower selector after stale battle composition is suppressed")
	_expect(route_playfield.border_draw_calls == 1, "ROUTE_AIM must restore the explicit playfield border slice")
	_expect(route_playfield.player_draw_calls == 1, "ROUTE_AIM must restore the production player slice")
	_expect(route_playfield.selector_draw_calls == 1, "ROUTE_AIM must restore the production selector ball slice")
	route_flow.phase = "NODE_MODAL"
	drawer.call("_draw_tower_ascent_playfield_flow_only", null, route_registry)
	_expect(route_flow.draw_calls == 1, "screen-space node modal must not double-render through the playfield-only fallback")
	_expect(route_playfield.border_draw_calls == 1, "NODE_MODAL must not draw the route border")
	_expect(route_playfield.player_draw_calls == 1, "NODE_MODAL must not draw the route player")
	_expect(route_playfield.selector_draw_calls == 1, "NODE_MODAL must not draw the route selector ball")
	_expect(route_registry.cold_get_calls == 0, "route-only draw must never cold-create the tower owner")


func _verify_bitmap_model(model: Dictionary, expected_kind: String, phase_label: String) -> void:
	_expect(not model.is_empty(), "%s must expose a retained background model" % phase_label)
	if model.is_empty():
		return
	_expect(str(model.get("kind", "")) == expected_kind, "%s must keep the reached node identity" % phase_label)
	_expect(str(model.get("source", "")) == "bitmap", "%s must use the promoted bitmap" % phase_label)
	var texture := model.get("texture", null) as Texture2D
	_expect(texture != null, "%s must retain its prewarmed Texture2D" % phase_label)
	var target_rect: Rect2 = model.get("target_rect", Rect2())
	var source_rect: Rect2 = model.get("source_rect", Rect2())
	_expect(target_rect == ACCEPTANCE_VIEWPORT, "%s must cover the acceptance viewport" % phase_label)
	if texture != null:
		_expect(source_rect.position.x >= 0.0 and source_rect.position.y >= 0.0, "%s cover crop must stay inside the texture" % phase_label)
		_expect(source_rect.end.x <= texture.get_width() and source_rect.end.y <= texture.get_height(), "%s cover crop must stay inside approved pixels" % phase_label)


func _find_target(targets: Array[Dictionary], kind: String) -> Dictionary:
	for target in targets:
		if str(target.get("kind", "")) == kind:
			return target
	return {}


func _find_combat_target(targets: Array[Dictionary]) -> Dictionary:
	for target in targets:
		if str(target.get("kind", "")) not in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
			return target
	return {}


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_func < 0 else source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
