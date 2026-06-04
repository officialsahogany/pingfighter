extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")

const BAZOOKA_ICON_PATH := "res://assets/sprites/skills/commando_bazooka_skill_orb.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_bazooka_icon_normalizes_for_orb_hud()
	_verify_commando_resource_map_uses_normalized_bazooka_icon()
	_verify_commando_unlock_alias_uses_normalized_bazooka_icon()

	if _failures.is_empty():
		print("commando_skill_orb_texture_normalizer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bazooka_icon_normalizes_for_orb_hud() -> void:
	var source: Texture2D = ProjectResourceLoader.load_texture(
		BAZOOKA_ICON_PATH,
		"Missing Commando bazooka orb icon at %s",
		"Failed to load Commando bazooka orb icon at %s"
	)
	_expect(source != null, "Commando bazooka source icon should load")
	_expect(source.get_width() == 256 and source.get_height() == 256, "Commando bazooka source icon should remain the authored 256px PNG")

	var source_rect: Rect2i = _get_used_rect(source)
	_expect(source_rect.size.x < 238 and source_rect.size.y < 238, "Commando bazooka source icon should document the pre-fix undersized alpha fill")

	var normalized: Texture2D = SkillOrbTextureNormalizer.normalize("bazooka", source)
	_expect(normalized != null, "normalized Commando bazooka icon should be available")
	_expect(normalized.get_width() == 256, "normalized Commando bazooka icon should be 256px wide")
	_expect(normalized.get_height() == 256, "normalized Commando bazooka icon should be 256px tall")
	_assert_hud_fit(normalized, "normalized Commando bazooka icon")

	var passthrough: Texture2D = SkillOrbTextureNormalizer.normalize("commando_pistol", source)
	_expect(passthrough == source, "unlisted Commando skill ids should keep the original texture")


func _verify_commando_resource_map_uses_normalized_bazooka_icon() -> void:
	SkillOrbTextureNormalizer.clear_cache()
	var resources := BattleResources.new()
	var icon_map: Dictionary = resources._load_skill_icon_map({"bazooka": BAZOOKA_ICON_PATH})
	var normalized: Texture2D = icon_map.get("bazooka", null)
	_expect(normalized != null, "Commando skill icon map should expose the normalized bazooka texture")
	_assert_hud_fit(normalized, "Commando skill icon map bazooka texture")


func _verify_commando_unlock_alias_uses_normalized_bazooka_icon() -> void:
	SkillOrbTextureNormalizer.clear_cache()
	var renderer := RuntimePerkIconRenderer.new()
	var source: Dictionary = renderer._get_icon_source("soldier_unlock_bazooka")
	var texture: Texture2D = source.get("texture", null)
	_expect(texture != null, "Commando bazooka unlock alias should resolve through the runtime perk icon renderer")
	_assert_hud_fit(texture, "Commando bazooka unlock alias texture")


func _assert_hud_fit(texture: Texture2D, label: String) -> void:
	var image: Image = texture.get_image()
	_expect(image != null and not image.is_empty(), "%s should expose pixels" % label)
	var used_rect: Rect2i = image.get_used_rect()
	_expect(used_rect.position.x >= 4 and used_rect.position.y >= 4, "%s should keep transparent inset before the orb edge" % label)
	_expect(used_rect.end.x <= 252 and used_rect.end.y <= 252, "%s should not touch the orb edge" % label)
	_expect(used_rect.size.x >= 238 and used_rect.size.x <= 246, "%s should fill the skill orb horizontally like neighboring icons" % label)
	_expect(used_rect.size.y >= 238 and used_rect.size.y <= 246, "%s should fill the skill orb vertically like neighboring icons" % label)
	_expect(image.get_pixel(0, 0).a == 0.0, "%s top-left corner should stay transparent" % label)
	_expect(image.get_pixel(255, 0).a == 0.0, "%s top-right corner should stay transparent" % label)
	_expect(image.get_pixel(0, 255).a == 0.0, "%s bottom-left corner should stay transparent" % label)
	_expect(image.get_pixel(255, 255).a == 0.0, "%s bottom-right corner should stay transparent" % label)


func _get_used_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2i()
	return image.get_used_rect()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
