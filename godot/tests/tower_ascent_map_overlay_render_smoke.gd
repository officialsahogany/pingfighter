extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const TowerAscentTransitionFadeState := preload(
	"res://scripts/tower_ascent/tower_ascent_transition_fade_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_full_disclosure_projection_and_states()
	_verify_fullscreen_projection_and_existing_art_slots()
	_verify_live_resolution_map_content_scales_proportionally()
	_verify_map_cache_and_six_beat_transition_contract()
	_verify_live_viewport_owns_fullscreen_rect()
	_verify_localization_catalog()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("tower_ascent_map_overlay_render_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_full_disclosure_projection_and_states() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-render",
		"map_seed": 83521,
	}), "map-overlay render fixture must begin")
	var nodes := flow.get_graph_nodes()
	var skipped_slot_id := ""
	for node in nodes:
		if str(node.get("boss_slot_id", "")).is_empty():
			continue
		if str(node.get("id", "")) != flow.get_current_node_id():
			skipped_slot_id = str(node.get("boss_slot_id", ""))
			break
	if not skipped_slot_id.is_empty():
		flow.call("_mark_boss_slot_skipped_in_graph", skipped_slot_id)
	flow.handle_input(_key_event(KEY_M))
	_expect(flow.get_phase_name() == "MAP_OVERLAY", "M must project the dedicated map-overlay phase")
	nodes = flow.get_graph_nodes()
	_expect(nodes.size() == 25, "the overlay must expose every generated human-realm node")
	var visible_kinds: Dictionary = {}
	var has_current := false
	var has_completed := false
	var has_vanished := false
	for node in nodes:
		var kind_label := TowerAscentMapOverlayLocalization.node_kind_label(
			str(node.get("kind", "")),
			bool(node.get("enraged", false))
		)
		visible_kinds[kind_label] = true
		has_current = has_current or str(node.get("id", "")) == flow.get_current_node_id()
		has_completed = has_completed or bool(node.get("completed", false))
		has_vanished = has_vanished or bool(node.get("skipped", false))
	for required_label in ["전투", "광폭화", "상점", "수련장", "파계승", "수호의 샘터", "휴식"]:
		_expect(visible_kinds.has(required_label), "full disclosure must expose node kind: %s" % required_label)
	_expect(has_current, "the overlay graph must contain the current player node")
	_expect(has_completed, "the overlay graph must distinguish a completed node")
	_expect(has_vanished, "the overlay graph must preserve a vanished skipped boss marker")
	var locked_hints: Array = flow.get_locked_phase_hints()
	_expect(locked_hints.size() == 1, "the human-realm overlay must preserve the locked phase-2 hint")
	if not locked_hints.is_empty():
		_expect(int((locked_hints[0] as Dictionary).get("floor_start", 0)) == 10 and int((locked_hints[0] as Dictionary).get("floor_end", 0)) == 12, "the locked hint must identify floors 10 through 12 without disclosing their nodes")


func _verify_localization_catalog() -> void:
	var required_keys := [
		TowerAscentMapOverlayLocalization.KEY_TITLE,
		TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT,
		TowerAscentMapOverlayLocalization.KEY_REALM_HUMAN,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL_LOCKED,
		TowerAscentMapOverlayLocalization.KEY_ENTER_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_NODE_GUARDIAN_SPRING,
		TowerAscentMapOverlayLocalization.KEY_STATE_CURRENT,
		TowerAscentMapOverlayLocalization.KEY_STATE_COMPLETED,
		TowerAscentMapOverlayLocalization.KEY_STATE_UNVISITED,
		TowerAscentMapOverlayLocalization.KEY_STATE_VANISHED,
		TowerAscentMapOverlayLocalization.KEY_STATE_LOCKED,
	]
	var registered := TowerAscentMapOverlayLocalization.get_registered_keys()
	for key in required_keys:
		_expect(registered.has(key), "map-overlay localization must register %s" % key)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "the Korean overlay title must be exactly 지도")
	for text_value in TowerAscentMapOverlayLocalization.TEXT_BY_LOCALE.get(
		LanguageSettings.LANGUAGE_KOREAN,
		{}
	).values():
		_expect(not str(text_value).contains("—"), "new Korean map copy must not contain an em dash")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "missing translations must fall back to Korean map copy")
	_expect(TowerAscentMapOverlayLocalization.get_missing_translation_locales().has(LanguageSettings.LANGUAGE_ENGLISH), "the map catalog must report untranslated supported locales")
	LanguageSettings.set_test_locale_override("")


func _verify_fullscreen_projection_and_existing_art_slots() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-fullscreen",
		"map_seed": 83521,
	}), "fullscreen map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	_expect(model.get("viewport_rect", Rect2()) == viewport_rect, "fullscreen model must preserve the full screen rect")
	_expect((model.get("nodes", []) as Array).size() == flow.get_graph_nodes().size(), "fullscreen map must project every disclosed node")
	_expect((model.get("floor_bands", []) as Array).size() == 9, "human-realm castle must expose one visible tier per active floor")
	_expect(str(model.get("realm_kind", "")) == "human_realm", "phase-1 fullscreen projection must own the human-realm treatment")
	_expect((model.get("locked_phase_hints", []) as Array).size() == 1, "phase-1 fullscreen projection must carry the 10 through 12 lock hint")
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var min_node_y := INF
	var max_node_y := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var screen_position: Vector2 = node.get("screen_position", Vector2.ZERO)
		var art_rect: Rect2 = node.get("art_rect", Rect2())
		var art_path := str(node.get("art_path", ""))
		_expect(content_rect.grow(0.1).has_point(screen_position), "every projected node center must remain inside the fullscreen map content")
		_expect(art_rect.size.x >= 18.0 and art_rect.size.y >= 18.0, "every node must own a readable art slot")
		_expect(not art_path.is_empty() and FileAccess.file_exists(art_path), "every node art slot must reuse an existing asset: %s" % art_path)
		min_node_y = minf(min_node_y, screen_position.y)
		max_node_y = maxf(max_node_y, screen_position.y)
	_expect(min_node_y < content_rect.get_center().y and max_node_y > content_rect.get_center().y, "the castle route must visibly ascend from bottom to top")
	for art_path in renderer.get_node_art_asset_paths():
		_expect(FileAccess.file_exists(art_path), "the node-art catalog must never reserve a missing draw path: %s" % art_path)


func _verify_live_resolution_map_content_scales_proportionally() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-live-resolution",
		"map_seed": 83521,
	}), "live-resolution map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var reference_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	)
	var live_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var expected_scale := 1246.0 / 800.0
	var art_scale := float(live_model.get("art_size", 0.0)) / maxf(
		1.0,
		float(reference_model.get("art_size", 0.0))
	)
	var reference_lane_span := _projected_node_x_span(reference_model)
	var live_lane_span := _projected_node_x_span(live_model)
	var lane_scale := live_lane_span / maxf(1.0, reference_lane_span)
	_expect(float(live_model.get("art_size", 0.0)) > 34.0, "2020x1246 node art must not stop at the old 34px absolute cap")
	_expect(live_lane_span > 660.0, "2020x1246 node lanes must use the actual source min/max instead of half of the capped span")
	_expect(absf(art_scale - expected_scale) <= 0.04, "node art must scale with the live viewport height")
	_expect(absf(lane_scale - expected_scale) <= 0.06, "node lane span must scale with the live viewport height")
	var live_content: Rect2 = live_model.get("content_rect", Rect2())
	for node_variant in live_model.get("nodes", []):
		if node_variant is Dictionary:
			_expect(
				live_content.grow(0.1).has_point((node_variant as Dictionary).get("screen_position", Vector2.ZERO)),
				"proportional live map sizing must keep every disclosed node visible"
			)


func _projected_node_x_span(model: Dictionary) -> float:
	var min_x := INF
	var max_x := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var position: Vector2 = (node_variant as Dictionary).get("screen_position", Vector2.ZERO)
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
	return 0.0 if not is_finite(min_x) or not is_finite(max_x) else max_x - min_x


func _verify_map_cache_and_six_beat_transition_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-cache-and-transition",
		"map_seed": 83521,
	}), "cache and transition fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("graph_build_count", 0)) == 1, "unchanged graph draws must reuse one cached graph model")
	_expect(int(cache_state.get("fullscreen_build_count", 0)) == 1, "unchanged viewport draws must reuse one cached fullscreen projection")

	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "transition fixture must expose a route target")
	if not target_ids.is_empty():
		var source_id := flow.get_current_node_id()
		var target_id := target_ids[0]
		flow.call("_resolve_route_target", target_id)
		_expect(flow.get_current_node_id() == source_id, "route selection must not promote the destination before arrival")
		renderer.build_fullscreen_map_model(flow, viewport_rect)
		var transition_cache_builds := int(
			renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)
		)
		flow.set_transition_progress_for_qa(0.5)
		var moving_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
		var moving_marker: Dictionary = moving_model.get("transition_marker", {})
		_expect(float(moving_marker.get("progress", 0.0)) > 0.0 and float(moving_marker.get("progress", 0.0)) < 1.0, "mid-transition marker must use the eased travel window")
		_expect(int(renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)) == transition_cache_builds, "transition progress must not rebuild the cached graph projection")
		flow.call("_complete_map_transition")
		_expect(flow.get_current_node_id() == target_id, "the destination must become current only when the map transition completes")

	var timeline := TowerAscentTransitionFadeState.new()
	timeline.begin_map_transition()
	var expected_total := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	_expect(is_equal_approx(timeline.get_map_transition_duration_sec(), expected_total), "map transition duration must be the five visual beats in the tuning table")
	timeline.set_map_transition_progress_for_qa(0.0)
	var start_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(start_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_BATTLE_FADE_OUT, "progress 0 must keep the battle visible for its fade-out")
	_expect(not bool(start_model.get("map_visible", true)) and is_zero_approx(float(start_model.get("blackout_alpha", -1.0))), "battle fade must start with no map and no blackout")
	timeline.set_map_transition_progress_for_qa(0.5)
	var middle_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(middle_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_TRAVEL, "progress 0.5 must land in the travel beat")
	_expect(bool(middle_model.get("map_visible", false)) and float(middle_model.get("travel_progress", 0.0)) > 0.0, "travel beat must show the fullscreen map and eased walker")
	timeline.set_map_transition_progress_for_qa(1.0)
	var end_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(end_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_MAP_FADE_OUT, "progress 1 must end on the map blackout beat")
	_expect(is_equal_approx(float(end_model.get("blackout_alpha", 0.0)), 1.0) and is_zero_approx(float(end_model.get("marker_alpha", 1.0))), "arrival must vanish before the fully black handoff")
	timeline.begin_node_modal_fade()
	_expect(is_zero_approx(timeline.get_node_modal_fade_progress()), "noncombat arrival surface must begin fully covered")
	timeline.update_node_modal_fade(TowerAscentTuning.TEMP_NODE_MODAL_FADE_IN_SEC)
	_expect(is_equal_approx(timeline.get_node_modal_fade_progress(), 1.0), "noncombat node fade must complete on its tuning duration")


func _verify_live_viewport_owns_fullscreen_rect() -> void:
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var fallback := Rect2(Vector2.ZERO, Vector2(73.0, 91.0))
	_expect(canvas.is_inside_tree(), "the viewport-sizing fixture must enter the scene tree")
	var resolved: Rect2 = renderer.resolve_fullscreen_rect(canvas, fallback)
	var live_rect := canvas.get_viewport_rect() if canvas.is_inside_tree() else Rect2()
	_expect(resolved == live_rect, "an in-tree map canvas must use the live viewport as the primary fullscreen size")
	_expect(resolved != fallback, "live viewport sizing must not collapse to a stale playfield/context fallback")
	get_root().remove_child(canvas)
	canvas.free()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
