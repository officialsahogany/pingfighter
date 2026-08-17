extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDebugPicker := preload("res://scripts/hud/runtime_perk_debug_picker.gd")


class FakeOwner:
	var selected_character_type := "smasher"


class FakeCatalog:
	extends RefCounted

	var entries: Array = []

	func _init(initial_entries: Array) -> void:
		entries = initial_entries

	func get_debug_perk_entries(_character_type: String = "") -> Array:
		return entries


class FakeRegistry:
	extends RefCounted

	var catalog: Object = null

	func _init(initial_catalog: Object) -> void:
		catalog = initial_catalog

	func get_instance(key: String) -> Object:
		return catalog if key == "runtime_perk_catalog" else null


var _failures: Array[String] = []


func _init() -> void:
	_verify_requested_tabs_and_catalog_partition()
	_verify_tab_input_and_local_pagination()
	if _failures.is_empty():
		print("runtime_perk_debug_picker_tabs_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_requested_tabs_and_catalog_partition() -> void:
	var picker := RuntimePerkDebugPicker.new()
	var expected_labels := ["한미량 초식", "호란 초식", "세린 초식", "비전초식", "무공", "절세무공"]
	_expect(RuntimePerkDebugPicker.TAB_DEFINITIONS.size() == expected_labels.size(), "F4 picker should expose exactly six requested tabs")
	for index in range(expected_labels.size()):
		_expect(str(RuntimePerkDebugPicker.TAB_DEFINITIONS[index].get("label", "")) == expected_labels[index], "F4 tab %d label should be %s" % [index, expected_labels[index]])

	var all_entries: Array = RuntimePerkCatalog.new().get_debug_perk_entries()
	var tab_entries: Array = []
	for tab_index in range(RuntimePerkDebugPicker.TAB_DEFINITIONS.size()):
		tab_entries.append(picker._get_entries_for_tab(all_entries, tab_index))
	_expect(_has_entry_id(tab_entries[0], "unlock_smasher_wheel"), "한미량 초식 tab should include Han Miryang manuals")
	_expect(_has_entry_id(tab_entries[1], "soldier_unlock_net_gun"), "호란 초식 tab should include Horan weapon manuals")
	_expect(_has_entry_id(tab_entries[2], "unlock_wall_leap_raid"), "세린 초식 tab should include Serin manuals")
	_expect(_has_entry_id(tab_entries[3], "unlock_dalji_vision_chain_top"), "비전초식 tab should include Dalji vision chosik")
	_expect(_has_entry_id(tab_entries[3], "unlock_cheongringwi_vision_dragon_torrent"), "비전초식 tab should include Cheongringwi vision chosik")
	_expect(_has_entry_id(tab_entries[3], "unlock_yeonmyo_vision_bonghongwe"), "비전초식 tab should include Yeonmyo vision chosik")
	_expect(_has_entry_id(tab_entries[4], "dash_spirit"), "무공 tab should include ordinary growth mugong")
	_expect(_has_entry_id(tab_entries[5], "odins_eye"), "절세무공 tab should include mythic mugong")
	for chosik_tab_index in range(3):
		_expect(_has_entry_id(tab_entries[chosik_tab_index], "unlock_soul_summon_art"), "common Soul Summoning manual should appear in every character Chosik tab")
		_expect(not _has_entry_id(tab_entries[chosik_tab_index], "unlock_dalji_vision_chain_top"), "character Chosik tabs must not duplicate vision mugong")
		_expect(not _has_entry_id(tab_entries[chosik_tab_index], "unlock_cheongringwi_vision_dragon_torrent"), "character Chosik tabs must not duplicate vision mugong")
		_expect(not _has_entry_id(tab_entries[chosik_tab_index], "unlock_yeonmyo_vision_bonghongwe"), "character Chosik tabs must not duplicate Yeonmyo vision mugong")
	_expect(not _has_entry_id(tab_entries[3], "unlock_smasher_wheel"), "비전초식 tab must not mix in character Chosik manuals")
	_expect(not _has_entry_id(tab_entries[4], "unlock_smasher_wheel"), "무공 tab must not mix in Chosik manuals")
	_expect(not _has_entry_id(tab_entries[4], "odins_eye"), "무공 tab must not mix in peerless mugong")
	_expect(not _has_entry_id(tab_entries[5], "dash_spirit"), "절세무공 tab must not mix in ordinary mugong")

	for entry_value in all_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var match_count := 0
		for definition_value in RuntimePerkDebugPicker.TAB_DEFINITIONS:
			if definition_value is Dictionary and picker._entry_matches_tab(entry, definition_value):
				match_count += 1
		var is_vision_mugong: bool = picker._is_vision_mugong_entry(entry)
		var is_common_chosik: bool = picker._is_chosik_entry(entry) and str(entry.get("character_restriction", "")).strip_edges().is_empty() and not picker._is_peerless_mugong_entry(entry) and not is_vision_mugong
		var expected_match_count := 3 if is_common_chosik else 1
		_expect(match_count == expected_match_count, "debug entry %s should map to %d tab view(s), got %d" % [str(entry.get("id", "")), expected_match_count, match_count])


func _verify_tab_input_and_local_pagination() -> void:
	var picker := RuntimePerkDebugPicker.new()
	var all_entries: Array = RuntimePerkCatalog.new().get_debug_perk_entries()
	var registry := FakeRegistry.new(FakeCatalog.new(all_entries))
	var owner := FakeOwner.new()
	var view_size := Vector2(1280.0, 720.0)
	picker.toggle()
	picker.page_index = 2
	var current_entries: Array = picker._get_entries_for_tab(all_entries, picker.selected_tab_index)
	var panel_rect: Rect2 = picker._get_panel_rect(view_size, min(current_entries.size(), RuntimePerkDebugPicker.MAX_VISIBLE_CARDS))
	var tab_click := InputEventMouseButton.new()
	tab_click.button_index = MOUSE_BUTTON_LEFT
	tab_click.pressed = true
	tab_click.position = picker._get_tab_rect(3, panel_rect).get_center()
	_expect(picker.handle_input(tab_click, owner, registry, view_size), "F4 tab click should be consumed")
	_expect(picker.selected_tab_index == 3, "clicking the fourth tab should select 비전초식")
	_expect(picker.page_index == 0, "changing F4 tabs should reset tab-local pagination")

	var number_key := InputEventKey.new()
	number_key.pressed = true
	number_key.keycode = KEY_6
	_expect(picker.handle_input(number_key, owner, registry, view_size), "F4 numeric tab shortcut should be consumed")
	_expect(picker.selected_tab_index == 5, "number key 6 should select the 절세무공 tab")
	number_key.keycode = KEY_5
	_expect(picker.handle_input(number_key, owner, registry, view_size), "F4 numeric tab shortcut should be consumed")
	_expect(picker.selected_tab_index == 4, "number key 5 should select the 무공 tab")
	var mugong_entries: Array = picker._get_entries_for_tab(all_entries, picker.selected_tab_index)
	_expect(mugong_entries.size() > RuntimePerkDebugPicker.MAX_VISIBLE_CARDS, "mugong tab should preserve tab-local pagination")
	var first_page: Array = picker._get_visible_entries(mugong_entries)
	picker.page_index = 1
	var second_page: Array = picker._get_visible_entries(mugong_entries)
	_expect(not first_page.is_empty() and not second_page.is_empty(), "mugong tab should expose both first and second pages")
	_expect(str(first_page[0].get("id", "")) != str(second_page[0].get("id", "")), "mugong page changes should shift only the selected tab window")


func _has_entry_id(entries: Array, expected_id: String) -> bool:
	for entry_value in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == expected_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
