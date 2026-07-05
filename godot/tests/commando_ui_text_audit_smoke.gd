extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const COMMANDO_UNLOCK_EXPECTED := {
	"soldier_unlock_net_gun": {"name": "그물덫총", "skill": "net_gun"},
	"soldier_unlock_fire_support": {"name": "화력지원", "skill": "fire_support"},
	"soldier_unlock_bowling_trap": {"name": "볼링트랩", "skill": "bowling_trap"},
	"soldier_unlock_suicide_drone": {"name": "자폭드론", "skill": "suicide_drone"},
	"soldier_unlock_bazooka": {"name": "바주카포", "skill": "bazooka"},
	"soldier_unlock_ak47": {"name": "AK-47", "skill": "ak47"},
	"soldier_pistol_perk": {"name": "베레타", "skill": "commando_pistol"},
}

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"selected_character_type": "soldier",
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_pos": Vector2(300.0, 700.0),
		"special_gauge": 120.0,
		"runtime_perk_gold": 0,
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_character_select_commando_copy()
	_verify_catalog_choice_copy()
	_verify_runtime_choice_overlay_labels()
	_verify_character_info_uses_commando_runtime()
	_verify_swap_dialog_copy_uses_korean_skill_names()
	_verify_feedback_copy_uses_display_names()

	if _failures.is_empty():
		print("commando_ui_text_audit_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_select_commando_copy() -> void:
	var commando: Dictionary = _find_character("soldier")
	_expect(str(commando.get("name", "")) == "코만도", "character select should use the Korean Commando name")
	_expect(str(commando.get("runtime_id", "")) == "soldier", "Commando select card should keep the soldier runtime id")
	_expect(str(commando.get("role", "")) == "전술 통제", "Commando select role should be Korean")
	_expect(str(commando.get("description", "")).contains("보급 호출"), "Commando select description should be Korean")
	_expect(str(commando.get("special", "")).contains("전술적 우위"), "Commando select special copy should be Korean")


func _verify_catalog_choice_copy() -> void:
	var catalog := RuntimePerkCatalog.new()
	var choices: Array = catalog.get_choices("soldier", {}, true, 200)
	for perk_id in COMMANDO_UNLOCK_EXPECTED.keys():
		var expected: Dictionary = COMMANDO_UNLOCK_EXPECTED[perk_id]
		var choice: Dictionary = _choice_by_id(choices, str(perk_id))
		_expect(not choice.is_empty(), "%s should appear in Commando choice data" % str(perk_id))
		_expect(str(choice.get("name", "")) == str(expected.get("name", "")), "%s choice should use Korean display name" % str(perk_id))
		_expect(str(choice.get("description", "")).contains("해금"), "%s choice description should be Korean unlock copy" % str(perk_id))
		_expect(str(choice.get("detail", "")).contains("코만도 스킬구슬") or str(perk_id) == "soldier_pistol_perk", "%s detail should explain the Commando orb path in Korean" % str(perk_id))
		_expect(str(choice.get("unlocks_skill", "")) == str(expected.get("skill", "")), "%s should keep the expected runtime skill id" % str(perk_id))


func _verify_runtime_choice_overlay_labels() -> void:
	var catalog := RuntimePerkCatalog.new()
	var overlay := RuntimePerkOverlayRenderer.new()
	var bazooka_choice: Dictionary = catalog.get_perk_data("soldier_unlock_bazooka")
	bazooka_choice["id"] = "soldier_unlock_bazooka"
	bazooka_choice["current_level"] = 0
	bazooka_choice["next_level"] = 1
	_expect(str(overlay._level_text(bazooka_choice)) == "해금", "runtime choice card should label Commando unlocks in Korean")
	_expect(str(overlay._long_level_text(bazooka_choice)).contains("액티브 해금"), "runtime choice description lane should keep Korean unlock wording")

	var gold_choice: Dictionary = catalog.get_perk_data("convert_to_gold")
	_expect(str(overlay._long_level_text(gold_choice)).contains("500골드"), "gold conversion helper should avoid English Gold text")


func _verify_character_info_uses_commando_runtime() -> void:
	var overlay := CharacterInfoOverlay.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var skill_config := CommandoSkillConfig.new()
	skill_config.unlock_and_equip_skill("bazooka")
	var catalog := RuntimePerkCatalog.new()
	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels["soldier_unlock_bazooka"] = 1
	registry.instances = {
		"commando_skill_config": skill_config,
		"runtime_perk_catalog": catalog,
		"runtime_perk_state": runtime_state,
	}

	_expect(str(CharacterInfoOverlayOwnerState.character_type_from_owner(owner, overlay._character_runtime)) == "soldier", "TAB overlay should keep soldier as Commando, not Smasher fallback")
	_expect(str(CharacterInfoOverlayOwnerState.character_display_name_from_owner(owner, "soldier")) == "레나", "TAB overlay should display the Commando's personal name (레나) left of the class label")
	_expect(CharacterInfoOverlayOwnerState.skill_config(registry, "soldier", overlay._character_runtime) == skill_config, "TAB overlay should read Commando skill config")
	var acquired: Array = overlay._build_acquired_perks(runtime_state.runtime_skill_levels, catalog)
	var bazooka: Dictionary = _first_dict(acquired)
	_expect(str(bazooka.get("name", "")) == "바주카포", "TAB perk grid should use the Korean unlock name")
	_expect(str(bazooka.get("description", "")).contains("바주카포 해금"), "TAB perk tooltip should use Korean unlock description")
	_expect(str(CharacterInfoOverlayFormatter.perk_level_text(bazooka)) == "해금", "TAB perk grid should label single-level Commando unlocks in Korean")

	var stats: Array = overlay._build_stats(owner, registry)
	_expect(_find_stat(stats, "장착 스킬").is_empty(), "TAB stats should leave skill counts to the dedicated equipped-skill panel")
	_expect(not _find_stat(stats, "이동 속도").is_empty(), "TAB stats should still render combat stat rows for Commando")


func _verify_swap_dialog_copy_uses_korean_skill_names() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var skill_config := CommandoSkillConfig.new()
	registry.instances = {
		"commando_skill_config": skill_config,
		"runtime_perk_catalog": catalog,
	}
	for perk_id in ["soldier_unlock_net_gun", "soldier_unlock_bazooka", "soldier_pistol_perk"]:
		_expect(state.apply_choice(_catalog_choice(catalog, perk_id), owner, registry), "%s should fill a Commando shared slot" % perk_id)
	var ak_choice: Dictionary = _catalog_choice(catalog, "soldier_unlock_ak47")
	_expect(not state.apply_choice(ak_choice, owner, registry), "full Commando slots should open the swap dialog")
	var swap: Dictionary = state.get_pending_unlock_swap()
	_expect(str(swap.get("new_name", "")) == "AK-47", "swap dialog should show the new firearm display name")
	var candidates: Array = _get_array(swap.get("candidates", []))
	_expect(_has_candidate_name(candidates, "그물덫총"), "swap candidates should show Korean old firearm names")
	_expect(_has_candidate_name(candidates, "바주카포"), "swap candidates should include Korean bazooka name")
	_expect(_has_candidate_name(candidates, "베레타"), "swap candidates should include the Beretta skill name")


func _verify_feedback_copy_uses_display_names() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"commando_skill_config": CommandoSkillConfig.new(),
		"runtime_perk_catalog": catalog,
	}
	_expect(state.debug_set_perk_level("soldier_unlock_bazooka", 1, owner, registry, catalog), "debug set should apply Commando unlock")
	var snapshot: Dictionary = state.get_snapshot()
	_expect(str(snapshot.get("feedback_text", "")).begins_with("바주카포"), "debug feedback should use Korean perk display name")
	_expect(not str(snapshot.get("feedback_text", "")).contains("soldier_unlock"), "debug feedback should not expose internal Commando perk id")


func _find_character(character_id: String) -> Dictionary:
	for value in CharacterSelectData.get_characters():
		if value is Dictionary and str((value as Dictionary).get("id", "")) == character_id:
			return value
	return {}


func _catalog_choice(catalog: Object, perk_id: String) -> Dictionary:
	var choice: Dictionary = catalog.get_perk_data(perk_id)
	choice["id"] = perk_id
	return choice


func _choice_by_id(choices: Array, perk_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary:
			var choice: Dictionary = value
			if str(choice.get("id", "")) == perk_id:
				return choice
	return {}


func _first_dict(values: Array) -> Dictionary:
	for value in values:
		if value is Dictionary:
			return value
	return {}


func _find_stat(stats: Array, label: String) -> Dictionary:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("label", "")) == label:
				return stat
	return {}


func _has_candidate_name(candidates: Array, name: String) -> bool:
	for value in candidates:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == name:
			return true
	return false


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
