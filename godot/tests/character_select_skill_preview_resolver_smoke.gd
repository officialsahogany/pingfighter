extends SceneTree

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const SkillPreviewResolver := preload("res://scripts/ui/character_select_skill_preview_resolver.gd")

var failure_count := 0


func _init() -> void:
	var characters := CharacterSelectData.get_characters()
	var smasher := _find_character(characters, "smasher")
	var commando := _find_character(characters, "soldier")
	var viper := _find_character(characters, "viper")
	var cache: Dictionary = {}

	_expect(SkillPreviewResolver.normalize_runtime_id(commando) == "commando", "soldier runtime id should normalize to the Commando config family")
	_expect(SkillPreviewResolver.get_character_skill_preview_ids(smasher)[0] == "power_smashing", "configured Smasher preview ids should retain their authored order")
	_expect(SkillPreviewResolver.infer_skill_id_from_icon_path("res://icons/commando_pistol.png", commando) == "commando_pistol", "Commando pistol should preserve its full runtime id")
	_expect(SkillPreviewResolver.infer_skill_id_from_icon_path("C:\\icons\\commando_supply_drop_skill_orb.png", commando) == "supply_drop", "Windows-style Commando icon paths should normalize prefix and suffix")
	_expect(SkillPreviewResolver.infer_skill_id_from_icon_path("res://icons/viper_shadow_step_skill_orb.png", viper) == "shadow_step", "Viper icon paths should normalize to the skill id")

	var smasher_config := SkillPreviewResolver.get_skill_config_for_character(smasher, cache)
	_expect(smasher_config != null and cache.has("smasher"), "resolver should lazily cache the Smasher config")
	_expect(SkillPreviewResolver.get_skill_config_for_character(smasher, cache) == smasher_config, "resolver should reuse the cached config instance")
	var commando_config := SkillPreviewResolver.get_skill_config_for_character(commando, cache)
	_expect(commando_config != null and cache.has("commando"), "resolver should lazily cache the Commando config under its normalized id")
	_expect(SkillPreviewResolver.get_skill_config_for_character({"runtime_id": "optimus"}, cache) == null, "unsupported character families should not invent a tooltip config")

	var smasher_data := SkillPreviewResolver.get_preview_data(smasher, 0, cache)
	_expect(not smasher_data.is_empty() and str(smasher_data.get("korean", "")).strip_edges() != "", "resolver should expose the configured Smasher skill data")
	_expect(SkillPreviewResolver.get_preview_data(smasher, -1, cache).is_empty(), "negative preview index should resolve empty")
	_expect(SkillPreviewResolver.get_preview_data(smasher, 99, cache).is_empty(), "out-of-range preview index should resolve empty")

	_expect(SkillPreviewResolver.format_number(12.0) == "12", "whole numbers should omit a decimal suffix")
	_expect(SkillPreviewResolver.format_number(1.25) == "1.3", "fractional tooltip numbers should keep the existing one-decimal format")
	var fallback := Color(0.2, 0.3, 0.4, 1.0)
	_expect(SkillPreviewResolver.skill_data_color({}, fallback) == fallback, "missing skill color should retain the character accent fallback")
	_expect(SkillPreviewResolver.skill_data_color({"color": Color.RED}, fallback) == Color.RED, "authored skill color should override the fallback")

	var screen: Control = CharacterSelectScreen.new()
	_expect(screen._get_character_skill_preview_ids(commando) == SkillPreviewResolver.get_character_skill_preview_ids(commando), "screen skill-id facade should match the resolver")
	_expect(screen._get_skill_preview_data(smasher, 0) == SkillPreviewResolver.get_preview_data(smasher, 0, screen.skill_config_instances), "screen preview-data facade should match the resolver")
	_expect(screen._get_skill_config_for_character(commando) == screen.skill_config_instances.get("commando"), "screen config facade should populate its compatibility cache")
	_expect(screen._format_number(1.25) == SkillPreviewResolver.format_number(1.25), "screen numeric format facade should match the resolver")
	_expect(screen._format_skill_meta({"cost": 350.0, "cooldown": 40.0}) == SkillPreviewResolver.format_skill_meta({"cost": 350.0, "cooldown": 40.0}), "screen meta facade should match the resolver under the active locale")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(screen_source.find("CharacterSelectSkillPreviewResolver.get_preview_data") >= 0, "screen preview data should delegate to the resolver")
	_expect(screen_source.find("CharacterSelectSkillPreviewResolver.get_character_skill_preview_ids") >= 0, "screen skill ids should delegate to the resolver")
	_expect(screen_source.find("CharacterSelectSkillPreviewResolver.get_skill_config_for_character") >= 0, "screen config lookup should delegate to the resolver")
	_expect(screen_source.find("CharacterSelectSkillPreviewResolver.format_skill_meta") >= 0, "screen metadata formatting should delegate to the resolver")
	screen.free()

	if failure_count > 0:
		quit(1)
		return
	print("character_select_skill_preview_resolver_smoke: ok")
	quit(0)


func _find_character(characters: Array, runtime_id: String) -> Dictionary:
	for character_value in characters:
		if character_value is Dictionary:
			var character: Dictionary = character_value
			if str(character.get("runtime_id", "")) == runtime_id:
				return character
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
