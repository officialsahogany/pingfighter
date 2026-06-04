extends SceneTree

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")

var _failures: Array[String] = []


func _init() -> void:
	var screen: Control = CharacterSelectScreen.new()
	screen.set("characters", CharacterSelectData.get_characters())
	screen.set("selected_index", 0)

	var characters_value: Variant = screen.get("characters")
	var characters: Array = characters_value if characters_value is Array else []
	_expect(not characters.is_empty(), "character select data should be loaded")
	if not characters.is_empty() and characters[0] is Dictionary:
		var smasher: Dictionary = characters[0]
		var skill_ids_value: Variant = screen.call("_get_character_skill_preview_ids", smasher)
		var skill_ids: Array = skill_ids_value if skill_ids_value is Array else []
		_expect(skill_ids.size() >= 3, "smasher representative icons should resolve skill ids")
		_expect(skill_ids[0] == "power_smashing", "first smasher icon should resolve to power_smashing")
		_expect(skill_ids[2] == "shield_kiting", "third smasher representative skill should resolve to shield_kiting")
		var skill_data_value: Variant = screen.call("_get_skill_preview_data", smasher, 0)
		var skill_data: Dictionary = skill_data_value if skill_data_value is Dictionary else {}
		_expect(str(skill_data.get("korean", "")) == "파워스매싱", "hover data should expose localized skill name")
		_expect(str(skill_data.get("description", "")).find("강력한 스매시") >= 0, "hover data should include the skill description")

	var commando := _get_character_by_runtime_id(characters, "soldier")
	_expect(not commando.is_empty(), "commando character data should be present")
	if not commando.is_empty():
		var commando_skill_ids_value: Variant = screen.call("_get_character_skill_preview_ids", commando)
		var commando_skill_ids: Array = commando_skill_ids_value if commando_skill_ids_value is Array else []
		_expect(commando_skill_ids.size() >= 1, "commando representative icons should resolve skill ids")
		_expect(commando_skill_ids[0] == "commando_pistol", "commando pistol should keep its full runtime skill id")
		var pistol_data_value: Variant = screen.call("_get_skill_preview_data", commando, 0)
		var pistol_data: Dictionary = pistol_data_value if pistol_data_value is Dictionary else {}
		_expect(str(pistol_data.get("korean", "")) == "베레타", "commando pistol hover data should resolve the tooltip name")
		_expect(str(pistol_data.get("description", "")).strip_edges() != "", "commando pistol hover data should include a description")

	var viper := _get_character_by_runtime_id(characters, "viper")
	_expect(not viper.is_empty(), "viper character data should be present")
	if not viper.is_empty():
		var viper_skill_ids_value: Variant = screen.call("_get_character_skill_preview_ids", viper)
		var viper_skill_ids: Array = viper_skill_ids_value if viper_skill_ids_value is Array else []
		_expect(viper_skill_ids.size() >= 3, "viper representative icons should resolve skill ids")
		_expect(viper_skill_ids[0] == "shadow_step", "Serin first representative skill should be Shadow Backstep")
		_expect(viper_skill_ids[1] == "marshal_kick", "Serin second representative skill should be Marshal Kick")
		_expect(viper_skill_ids[2] == "blade_rush", "Serin third representative skill should be Air Blade")

	var blacksmith := _get_character_by_runtime_id(characters, "blacksmith")
	_expect(not blacksmith.is_empty(), "Kohaku / Baltor character data should be present")
	if not blacksmith.is_empty():
		_expect(bool(blacksmith.get("unlocked", false)), "Kohaku / Baltor should be unlocked in character select")

	screen.set("skill_icon_rects", {0: Rect2(Vector2(10.0, 10.0), Vector2(50.0, 50.0))})
	screen.call("_update_hover_from_mouse", Vector2(20.0, 20.0))
	_expect(int(screen.get("hovered_skill_index")) == 0, "skill icon hit-test should set hovered_skill_index")
	screen.call("_update_hover_from_mouse", Vector2(200.0, 200.0))
	_expect(int(screen.get("hovered_skill_index")) == -1, "skill icon miss should clear hovered_skill_index")

	screen.free()
	if _failures.is_empty():
		print("character_select_skill_hover_tooltip_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_character_by_runtime_id(characters: Array, runtime_id: String) -> Dictionary:
	for character_value in characters:
		if character_value is Dictionary:
			var character: Dictionary = character_value
			if str(character.get("runtime_id", "")).strip_edges().to_lower() == runtime_id:
				return character
	return {}
