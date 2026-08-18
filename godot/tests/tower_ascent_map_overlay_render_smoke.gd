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

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_full_disclosure_projection_and_states()
	_verify_fullscreen_projection_and_existing_art_slots()
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
	_expect(nodes.size() == 34, "the overlay must expose every generated node")
	var visible_kinds: Dictionary = {}
	var has_current := false
	var has_completed := false
	var has_vanished := false
	var has_locked := false
	for node in nodes:
		var kind_label := TowerAscentMapOverlayLocalization.node_kind_label(
			str(node.get("kind", "")),
			bool(node.get("enraged", false))
		)
		visible_kinds[kind_label] = true
		has_current = has_current or str(node.get("id", "")) == flow.get_current_node_id()
		has_completed = has_completed or bool(node.get("completed", false))
		has_vanished = has_vanished or bool(node.get("skipped", false))
		has_locked = has_locked or bool(node.get("route_locked", false))
	for required_label in ["전투", "광폭화", "상점", "수련장", "파계승", "수호의 샘터", "휴식"]:
		_expect(visible_kinds.has(required_label), "full disclosure must expose node kind: %s" % required_label)
	_expect(has_current, "the overlay graph must contain the current player node")
	_expect(has_completed, "the overlay graph must distinguish a completed node")
	_expect(has_vanished, "the overlay graph must preserve a vanished skipped boss marker")
	_expect(has_locked, "the overlay graph must preserve locked floors 10 through 12")


func _verify_localization_catalog() -> void:
	var required_keys := [
		TowerAscentMapOverlayLocalization.KEY_TITLE,
		TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT,
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
	_expect((model.get("floor_bands", []) as Array).size() == 12, "vertical castle must expose one visible tier per floor")
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
