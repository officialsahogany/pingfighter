extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")


func _init() -> void:
	var source: Texture2D = ProjectResourceLoader.load_texture(
		"res://assets/sprites/skills/smasher_wheel_skill_orb.png",
		"Missing smasher wheel orb icon at %s",
		"Failed to load smasher wheel orb icon at %s"
	)
	_expect(source != null, "smasher wheel source icon should load")
	_expect(source.get_width() > 256 and source.get_height() > 256, "source icon should remain the large authored PNG")

	var normalized: Texture2D = SkillOrbTextureNormalizer.normalize("smasher_wheel", source)
	_expect(normalized != null, "normalized smasher wheel icon should be available")
	_expect(normalized.get_width() == 256, "normalized smasher wheel icon should be 256px wide")
	_expect(normalized.get_height() == 256, "normalized smasher wheel icon should be 256px tall")

	var image: Image = normalized.get_image()
	_expect(image != null and not image.is_empty(), "normalized smasher wheel image should expose pixels")
	_expect(image.get_pixel(128, 128).a > 0.10, "normalized smasher wheel center should stay visible")
	var used_rect: Rect2i = image.get_used_rect()
	_expect(used_rect.position.x >= 5 and used_rect.position.y >= 5, "normalized smasher wheel should keep transparent inset before the orb edge")
	_expect(used_rect.end.x <= 251 and used_rect.end.y <= 251, "normalized smasher wheel should not touch the orb edge")
	_expect(used_rect.size.x >= 240 and used_rect.size.x <= 246, "normalized smasher wheel should fill the orb like adjacent 256px skill icons")
	_expect(used_rect.size.y >= 240 and used_rect.size.y <= 246, "normalized smasher wheel should keep a balanced vertical fit")
	_expect(image.get_pixel(0, 0).a == 0.0, "normalized smasher wheel top-left corner should stay transparent")
	_expect(image.get_pixel(255, 0).a == 0.0, "normalized smasher wheel top-right corner should stay transparent")
	_expect(image.get_pixel(0, 255).a == 0.0, "normalized smasher wheel bottom-left corner should stay transparent")
	_expect(image.get_pixel(255, 255).a == 0.0, "normalized smasher wheel bottom-right corner should stay transparent")

	var passthrough: Texture2D = SkillOrbTextureNormalizer.normalize("drive", source)
	_expect(passthrough == source, "unlisted skill ids should keep the original texture")

	print("smasher_wheel_icon_normalizer_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
