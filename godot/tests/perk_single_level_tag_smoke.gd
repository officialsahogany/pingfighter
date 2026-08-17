extends SceneTree

# Seals the single-level perk tag wording (2026-07-09 decision): perks with
# max_level == 1 never level up, so instead of a growth rank they show:
#   - "비급" for active-skill manuals (character_restriction present),
#   - "신화" for mythic-rarity perks,
#   - "고유" for every other one-off perk (무중력화 / 윤회 / 오토파일럿 등).
# Multi-level Korean perks use 1성~N성 and 극성. Covered on both render paths: the character-info
# formatter and the perk-choice renderer's _level_text.

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	call_deferred("_run")


func _run() -> void:
	_test_formatter_tag()
	_test_choice_renderer_tag()
	LanguageSettings.set_test_locale_override("")
	print("perk_single_level_tag_smoke: ok")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_formatter_tag() -> void:
	# Character-info grid / status panel path.
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "rarity": "mythic", "level": 1}) == "절세무공", "mythic single perk must tag 절세무공")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "level": 1}) == "고유", "non-mythic single perk must tag 고유")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "character_restriction": "smasher", "level": 1}) == "비급", "skill manual must tag 비급")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 5, "level": 3}) == "3성", "multi-level perk should use the Korean star rank")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 5, "level": 5}) == "극성", "authored max level should display as 극성")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 5, "level": 7}) == "극성 +2", "effective overflow should remain visible above 극성")
	# Colors differ per tag so the tags read distinctly.
	var mythic_color: Color = CharacterInfoOverlayFormatter.perk_level_color({"max_level": 1, "rarity": "mythic"}, Color.WHITE)
	var single_color: Color = CharacterInfoOverlayFormatter.perk_level_color({"max_level": 1}, Color.WHITE)
	_expect(mythic_color != single_color, "신화 and 고유 tags should use distinct colors")
	var dark_hanji_gold := Color(0.50, 0.33, 0.13)
	var growth_rank_color: Color = CharacterInfoOverlayFormatter.perk_level_color({"max_level": 5, "level": 1}, dark_hanji_gold)
	_expect(growth_rank_color.get_luminance() >= 0.70, "1성~극성 text should stay readable on the dark Mugong rank plaque")
	_expect(growth_rank_color.r > growth_rank_color.g and growth_rank_color.g > growth_rank_color.b, "multi-level rank text should retain a warm-gold hierarchy")


func _test_choice_renderer_tag() -> void:
	# Perk-choice card / per-card accent path.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(renderer._level_text({"max_level": 1, "rarity": "mythic", "next_level": 1}) == "절세무공", "choice: mythic single perk must tag 절세무공")
	_expect(renderer._level_text({"max_level": 1, "next_level": 1}) == "고유", "choice: non-mythic single perk must tag 고유")
	_expect(renderer._level_text({"max_level": 1, "character_restriction": "smasher", "next_level": 1}) == "비급", "choice: skill manual must tag 비급")
	_expect(renderer._level_text({"max_level": 5, "next_level": 3}) == "3성", "choice: multi-level perk should use the Korean star rank")
	_expect(renderer._level_text({"max_level": 5, "next_level": 5}) == "극성", "choice: max-level perk should use 극성")
	_expect(renderer._long_level_text({"max_level": 5, "current_level": 4, "next_level": 5}).contains("4성 → 극성"), "choice transition should reveal entry into 극성")
	_expect(renderer._level_text({"is_gold_conversion": true}) == "골드", "choice: gold conversion keeps 골드")
	_expect(renderer._level_text({"is_instant": true}) == "즉시", "choice: instant perk keeps 즉시")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_single_level_tag_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
