extends SceneTree

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const Stage1PillarStatusOrbContextBuilder := preload("res://scripts/hud/stage1_pillar_status_orb_context_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	var frame_path := BattleCoreTexturePaths.GAUGE_ORB_FRAME_TEXTURE_PATH
	_expect(frame_path.ends_with("gauge_orb_frame_imagegen_v3.png"), "ki orb must use the count-neutral Korean-fantasy v3 frame")
	_expect(frame_path != BattleCoreTexturePaths.DASH_TOKEN_FRAME_TEXTURE_PATH, "ki and dash frames must keep separate hole geometry despite sharing ornament language")
	_expect(FileAccess.file_exists(frame_path), "ki-orb frame PNG must exist")
	_expect(FileAccess.file_exists(frame_path + ".import"), "ki-orb frame PNG must ship with its import sidecar")

	var image := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	_expect(image != null and image.get_size() == Vector2i(240, 240), "ki-orb frame must preserve the 240x240 runtime contract")
	if image != null:
		var alpha_bbox := _alpha_bbox(image, 16.0 / 255.0)
		_expect(alpha_bbox.size.x >= 197 and alpha_bbox.size.x <= 199, "ki-orb frame outer alpha width must match the v1 socket")
		_expect(alpha_bbox.size.y >= 197 and alpha_bbox.size.y <= 199, "ki-orb frame outer alpha height must match the v1 socket")
		var hole_width := _transparent_center_run_x(image, 16.0 / 255.0)
		var hole_height := _transparent_center_run_y(image, 16.0 / 255.0)
		_expect(hole_width >= 127 and hole_width <= 131, "ki-orb frame horizontal hole must preserve the v1 orb fit")
		_expect(hole_height >= 129 and hole_height <= 133, "ki-orb frame vertical hole must preserve the v1 orb fit")
		_expect(image.get_pixel(120, 120).a <= 0.01, "ki-orb frame center must stay transparent")
		_expect(image.get_pixel(0, 0).a <= 0.01, "ki-orb frame corners must stay transparent")
		_expect(_opaque_magenta_count(image) == 0, "ki-orb frame must not retain opaque magenta chroma pixels")
		_expect(_luminous_blue_pixel_count(image) == 0, "ki-orb frame must not restore fixed blue jewel nodes")

	var ornament_path := BattleCoreTexturePaths.GAUGE_ORB_KI_JADE_ORNAMENT_TEXTURE_PATH
	_expect(ornament_path.ends_with("gauge_orb_ki_jade_ornament_imagegen_v1.png"), "ki orb must use the accepted single jade ornament")
	_expect(FileAccess.file_exists(ornament_path), "ki-orb jade ornament PNG must exist")
	_expect(FileAccess.file_exists(ornament_path + ".import"), "ki-orb jade ornament must ship with its import sidecar")
	var ornament_image := Image.load_from_file(ProjectSettings.globalize_path(ornament_path))
	_expect(ornament_image != null and ornament_image.get_size() == Vector2i(128, 128), "ki-orb jade ornament must preserve its 128x128 socket")
	if ornament_image != null:
		var ornament_bbox := _alpha_bbox(ornament_image, 16.0 / 255.0)
		_expect(ornament_bbox.size == Vector2i(68, 108), "ki-orb jade ornament alpha bbox must preserve the bell-paired silhouette")
		_expect(_opaque_magenta_count(ornament_image) == 0, "ki-orb jade ornament must not retain opaque magenta chroma pixels")
		_expect(_luminous_blue_pixel_count(ornament_image) >= 1000, "ki-orb jade ornament must retain one readable blue energy core")

	var texture_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var frame_texture := ImageTexture.create_from_image(texture_image)
	var ornament_texture := ImageTexture.create_from_image(texture_image)
	var builder := Stage1PillarStatusOrbContextBuilder.new()
	var gauge_context: Dictionary = builder.build_gauge_orb_context({
		"gauge_frame_texture": frame_texture,
		"gauge_orb_ki_jade_ornament_texture": ornament_texture,
	}, null)
	_expect(gauge_context.get("frame_texture", null) == frame_texture, "ki-orb context must receive the prewarmed v3 frame texture")
	_expect(gauge_context.get("ornament_texture", null) == ornament_texture, "ki-orb context must receive the prewarmed jade ornament texture")
	var renderer := PillarGaugeOrbRenderer.new()
	var ornament_draw_spec := renderer.build_ki_jade_ornament_draw_spec(Vector2(100.0, 100.0), 55.0, gauge_context)
	var ornament_rect: Rect2 = ornament_draw_spec.get("rect", Rect2())
	_expect(ornament_draw_spec.get("texture", null) == ornament_texture, "ki-orb ornament draw spec must retain texture identity")
	_expect(ornament_rect.size.is_equal_approx(Vector2(28.0, 28.0)), "ki-orb ornament must match the dash bell's 28px base draw size")
	_expect(is_equal_approx(ornament_rect.get_center().x, 100.0), "ki-orb ornament must stay centered at 12 o'clock")
	_expect(is_equal_approx(ornament_rect.get_center().y, 35.0), "ki-orb ornament must overlap the top rim without entering the liquid core")

	var resources := BattleResources.new()
	var frame_spec_count := 0
	var ornament_spec_count := 0
	for spec_value in resources._get_core_texture_specs():
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		if str(spec.get("path", "")) == frame_path and "gauge_orb_frame_texture" in spec.get("keys", []):
			frame_spec_count += 1
		if str(spec.get("path", "")) == ornament_path and "gauge_orb_ki_jade_ornament_texture" in spec.get("keys", []):
			ornament_spec_count += 1
	_expect(frame_spec_count == 1, "ki-orb v3 frame must join core staged prewarm exactly once")
	_expect(ornament_spec_count == 1, "ki-orb jade ornament must join core staged prewarm exactly once")

	var gauge_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_gauge_orb_renderer.gd")
	var glass_index := gauge_source.find("pillar_drawer.draw_pillar_orb_glass(canvas")
	var frame_index := gauge_source.find("pillar_drawer.draw_rotating_orb_frame_texture")
	var ornament_index := gauge_source.find("_draw_ki_jade_ornament_overlay(canvas", frame_index)
	_expect(glass_index >= 0 and frame_index > glass_index, "ki-orb frame must remain the final foreground collar above the glass")
	_expect(ornament_index > frame_index, "ki-orb jade ornament must stay fixed above the rotating frame draw")
	_expect(gauge_source.count("\t_draw_ki_jade_ornament_overlay(canvas") == 1, "ki-orb must draw exactly one decorative jade ornament")

	if _failures.is_empty():
		print("gauge_orb_hwangyeok_frame_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _alpha_bbox(image: Image, threshold: float) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= threshold:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _transparent_center_run_x(image: Image, threshold: float) -> int:
	var y := int(image.get_height() * 0.5)
	var left := int(image.get_width() * 0.5)
	var right := left
	while left > 0 and image.get_pixel(left - 1, y).a <= threshold:
		left -= 1
	while right < image.get_width() - 1 and image.get_pixel(right + 1, y).a <= threshold:
		right += 1
	return right - left + 1


func _transparent_center_run_y(image: Image, threshold: float) -> int:
	var x := int(image.get_width() * 0.5)
	var top := int(image.get_height() * 0.5)
	var bottom := top
	while top > 0 and image.get_pixel(x, top - 1).a <= threshold:
		top -= 1
	while bottom < image.get_height() - 1 and image.get_pixel(x, bottom + 1).a <= threshold:
		bottom += 1
	return bottom - top + 1


func _opaque_magenta_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > 16.0 / 255.0 and color.r > 0.86 and color.b > 0.70 and color.g < 0.32:
				count += 1
	return count


func _luminous_blue_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > 0.50 and color.b > 0.59 and color.g > 0.27 and color.r < 0.25 and color.b > color.g * 1.15:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
