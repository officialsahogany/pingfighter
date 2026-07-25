extends SceneTree

# Seals the single-level perk tag wording (2026-07-09 decision): perks with
# max_level == 1 never level up, so instead of a meaningless "Lv.1" they show:
#   - "해금" for active-skill unlocks (character_restriction present),
#   - "신화" for mythic-rarity perks,
#   - "고유" for every other one-off perk (무중력화 / 윤회 / 오토파일럿 등).
# Multi-level perks keep "Lv.N". Covered on both render paths: the character-info
# formatter and the perk-choice renderer's _level_text.

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_formatter_tag()
	_test_choice_renderer_tag()
	print("perk_single_level_tag_smoke: ok")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_formatter_tag() -> void:
	# Character-info grid / status panel path.
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "rarity": "mythic", "level": 1}) == "신화", "mythic single perk must tag 신화")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "level": 1}) == "고유", "non-mythic single perk must tag 고유")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "character_restriction": "smasher", "level": 1}) == "해금", "unlock perk must still tag 해금")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 5, "level": 3}) == "Lv.3", "multi-level perk keeps Lv.N")
	# Colors differ per tag so the tags read distinctly.
	var mythic_color: Color = CharacterInfoOverlayFormatter.perk_level_color({"max_level": 1, "rarity": "mythic"}, Color.WHITE)
	var single_color: Color = CharacterInfoOverlayFormatter.perk_level_color({"max_level": 1}, Color.WHITE)
	_expect(mythic_color != single_color, "신화 and 고유 tags should use distinct colors")


func _test_choice_renderer_tag() -> void:
	# Perk-choice card / per-card accent path.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(renderer._level_text({"max_level": 1, "rarity": "mythic", "next_level": 1}) == "신화", "choice: mythic single perk must tag 신화")
	_expect(renderer._level_text({"max_level": 1, "next_level": 1}) == "고유", "choice: non-mythic single perk must tag 고유")
	_expect(renderer._level_text({"max_level": 1, "character_restriction": "smasher", "next_level": 1}) == "해금", "choice: unlock perk must still tag 해금")
	_expect(renderer._level_text({"max_level": 5, "next_level": 3}) == "Lv.3", "choice: multi-level perk keeps Lv.N")
	_expect(renderer._level_text({"is_gold_conversion": true}) == "골드", "choice: gold conversion keeps 골드")
	_expect(renderer._level_text({"is_instant": true}) == "즉시", "choice: instant perk keeps 즉시")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_single_level_tag_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
