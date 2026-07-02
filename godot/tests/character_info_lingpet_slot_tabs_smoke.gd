extends SceneTree

# Seals the lingpet slot-tab selector in the character-info panel:
#  - snapshot.slot_tabs is built in acquisition (battle-slot) order with the
#    correct active flag (explicit index, -1 sentinel -> pet_id match, lingpet_*
#    / ringpet_* pair fallback, empty-slots single-tab fallback),
#  - clicking a tab routes to lingpet_egg_runtime.switch_lingpet_slot,
#  - the battle-slot keys are declared in the owner schema,
#  - the overlay input handler is wired to the tab click handler.

const SnapshotBuilder := preload("res://scripts/hud/character_info_overlay_lingpet_snapshot_builder.gd")
const ValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const OverlayCore := preload("res://scripts/hud/character_info_overlay_core.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")

const REQUIRED_HITS := 3

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var data: Dictionary = {}
	func _init(initial: Dictionary) -> void:
		data = initial.duplicate(true)
	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)
	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeRuntime:
	extends RefCounted
	var switched: Array[int] = []
	var switch_result := true
	func switch_lingpet_slot(slot_index: int, _owner: Object = null, _registry: Object = null) -> bool:
		switched.append(slot_index)
		return switch_result


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}
	func _init(next: Dictionary = {}) -> void:
		instances = next
	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_snapshot_order_and_active_index()
	_verify_active_index_sentinel_matches_pet_id()
	_verify_ringpet_pair_fallback()
	_verify_empty_slots_single_tab_fallback()
	_verify_schema_declares_slot_keys()
	_verify_click_switches_active_slot()
	_verify_input_handler_wires_tab_click()
	if _failures.is_empty():
		print("character_info_lingpet_slot_tabs_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_snapshot(fields: Dictionary) -> Dictionary:
	var owner := FakeOwner.new(fields)
	return SnapshotBuilder.build_panel_snapshot(owner, Callable(ValueUtils, "safe_owner_get"), REQUIRED_HITS)


func _verify_snapshot_order_and_active_index() -> void:
	var snapshot := _build_snapshot({
		"lingpet_state": "companion",
		"lingpet_id": "maribo",
		"lingpet_slots": ["maribo", "lunabi", ""],
		"lingpet_active_slot_index": 1,
	})
	var tabs: Array = snapshot.get("slot_tabs", [])
	_expect(tabs.size() == 2, "occupied slots should yield 2 tabs (got %d)" % tabs.size())
	if tabs.size() != 2:
		return
	_expect(str(tabs[0].get("pet_id", "")) == "maribo" and int(tabs[0].get("slot_index", -1)) == 0, "tab 0 should be maribo at slot 0 (acquisition order)")
	_expect(str(tabs[1].get("pet_id", "")) == "lunabi" and int(tabs[1].get("slot_index", -1)) == 1, "tab 1 should be lunabi at slot 1")
	_expect(not bool(tabs[0].get("active", true)), "explicit active index 1 must make slot 0 inactive")
	_expect(bool(tabs[1].get("active", false)), "explicit active index 1 must make slot 1 active")
	_expect(str(tabs[1].get("name", "")) != "", "tab should carry a display name")


func _verify_active_index_sentinel_matches_pet_id() -> void:
	# -1 sentinel must NOT force slot 0: resolve against the active companion pet_id.
	var snapshot := _build_snapshot({
		"lingpet_state": "companion",
		"lingpet_id": "lunabi",
		"lingpet_slots": ["maribo", "lunabi", ""],
		"lingpet_active_slot_index": -1,
	})
	var tabs: Array = snapshot.get("slot_tabs", [])
	_expect(tabs.size() == 2, "sentinel case should still yield 2 tabs")
	if tabs.size() != 2:
		return
	_expect(not bool(tabs[0].get("active", true)), "sentinel must not force slot 0 active")
	_expect(bool(tabs[1].get("active", false)), "sentinel must mark the pet_id-matching slot (lunabi) active")


func _verify_ringpet_pair_fallback() -> void:
	var snapshot := _build_snapshot({
		"lingpet_state": "companion",
		"lingpet_id": "maribo",
		"lingpet_slots": [],
		"ringpet_slots": ["maribo", "lunabi", ""],
		"lingpet_active_slot_index": -1,
		"ringpet_active_slot_index": 1,
	})
	var tabs: Array = snapshot.get("slot_tabs", [])
	_expect(tabs.size() == 2, "empty lingpet_slots should fall back to ringpet_slots (got %d)" % tabs.size())
	if tabs.size() != 2:
		return
	_expect(str(tabs[0].get("pet_id", "")) == "maribo", "ringpet fallback tab 0 should be maribo")
	_expect(bool(tabs[1].get("active", false)), "ringpet_active_slot_index 1 should mark slot 1 active")


func _verify_empty_slots_single_tab_fallback() -> void:
	# Companion present but no synced slots -> show a single tab for the active pet.
	var snapshot := _build_snapshot({
		"lingpet_state": "companion",
		"lingpet_id": "maribo",
		"lingpet_slots": [],
		"ringpet_slots": [],
	})
	var tabs: Array = snapshot.get("slot_tabs", [])
	_expect(tabs.size() == 1, "no synced slots + companion should yield a single fallback tab")
	if tabs.size() != 1:
		return
	_expect(str(tabs[0].get("pet_id", "")) == "maribo" and bool(tabs[0].get("active", false)), "fallback tab should be the active companion")


func _verify_schema_declares_slot_keys() -> void:
	# Owner-Field Schema Trap: an undeclared key silently no-ops the runtime sync,
	# so the tabs would read stale/empty. Seal that the keys are declared.
	var defaults: Dictionary = BattleSceneState.DEFAULT_VALUES
	_expect(defaults.has("lingpet_slots"), "battle scene schema must declare lingpet_slots")
	_expect(defaults.has("lingpet_active_slot_index"), "battle scene schema must declare lingpet_active_slot_index")
	_expect(int(defaults.get("lingpet_active_slot_index", 0)) == -1, "active slot index default should be the -1 not-synced sentinel")


func _verify_click_switches_active_slot() -> void:
	var overlay: Object = OverlayCore.new()
	overlay._last_lingpet_slot_tab_rects = [
		{"rect": Rect2(120.0, 10.0, 60.0, 20.0), "slot_index": 0, "pet_id": "maribo"},
		{"rect": Rect2(184.0, 10.0, 60.0, 20.0), "slot_index": 1, "pet_id": "lunabi"},
	]
	var runtime := FakeRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var owner := FakeOwner.new({})
	# Click inside tab 1 -> switch to slot 1.
	var hit: bool = bool(overlay._try_handle_lingpet_slot_tab_click(Vector2(200.0, 18.0), owner, registry))
	_expect(hit, "clicking a tab rect should be handled")
	_expect(runtime.switched == [1], "tab 1 click should call switch_lingpet_slot(1) (got %s)" % str(runtime.switched))
	# Click outside any tab -> no switch, not handled.
	var miss: bool = bool(overlay._try_handle_lingpet_slot_tab_click(Vector2(600.0, 600.0), owner, registry))
	_expect(not miss, "a click outside every tab rect must not be handled")
	_expect(runtime.switched == [1], "an off-tab click must not call switch_lingpet_slot")
	# A false switch result (empty/blocked slot) must not be reported as handled.
	runtime.switch_result = false
	var blocked: bool = bool(overlay._try_handle_lingpet_slot_tab_click(Vector2(140.0, 18.0), owner, registry))
	_expect(not blocked, "a switch that returns false must not consume the click")


func _verify_input_handler_wires_tab_click() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_input_handler.gd")
	_expect(source.find("_try_handle_lingpet_slot_tab_click") >= 0, "overlay input handler should route left clicks to the slot-tab handler")
	var support := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd")
	_expect(support.find("switch_lingpet_slot") >= 0, "slot-tab click handler should call switch_lingpet_slot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
