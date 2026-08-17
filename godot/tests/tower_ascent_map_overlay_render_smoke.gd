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
	_verify_full_disclosure_projection_and_states()
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


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
