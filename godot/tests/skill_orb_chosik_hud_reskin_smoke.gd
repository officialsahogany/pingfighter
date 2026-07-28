extends SceneTree

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const FRAME_SIZE := Vector2i(256, 256)
const CLUSTER_SIZE := Vector2i(250, 650)
const CLUSTER_CENTER := Vector2(141.0, 559.0)
const ALPHA_THRESHOLD := 16.0 / 255.0

var _failures: Array[String] = []


func _init() -> void:
	var frame_path: String = BattleCoreTexturePaths.SKILL_ORB_FRAME_TEXTURE_PATH
	var smasher_cluster_path: String = BattleCoreTexturePaths.SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH
	var viper_cluster_path: String = BattleCoreTexturePaths.VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH
	_expect(frame_path.ends_with("skill_orb_frame_imagegen_v2.png"), "Chosik sockets must use the accepted Korean-fantasy v2 ring")
	_expect(smasher_cluster_path.ends_with("player_skill_gauge_full_frame_165_33_5_hwangyeok_v2.png"), "Smasher five-slot HUD must use the Korean-fantasy cluster")
	_expect(viper_cluster_path.ends_with("player_skill_gauge_full_frame_155_32_5_hwangyeok_v2.png"), "Viper five-slot HUD must use the Korean-fantasy cluster")

	for path in [frame_path, smasher_cluster_path, viper_cluster_path]:
		_expect(FileAccess.file_exists(path), "Chosik HUD PNG must exist: %s" % path)
		_expect(FileAccess.file_exists(path + ".import"), "Chosik HUD PNG must ship with .import: %s" % path)
		_expect(_import_ctex_exists(path + ".import"), "Chosik HUD import must point to an existing .ctex: %s" % path)

	var frame_image := Image.load_from_file(ProjectSettings.globalize_path(frame_path))
	_expect(frame_image != null and frame_image.get_size() == FRAME_SIZE, "Chosik socket must preserve its 256x256 source contract")
	if frame_image != null:
		var frame_bbox := _alpha_bbox(frame_image)
		_expect(frame_bbox.size.x >= 221 and frame_bbox.size.x <= 225, "Chosik socket outer alpha width must preserve the accepted slim ring")
		_expect(frame_bbox.size.y >= 226 and frame_bbox.size.y <= 230, "Chosik socket outer alpha height must retain the compact plum seal")
		_expect(_transparent_center_run_x(frame_image) >= 171 and _transparent_center_run_x(frame_image) <= 175, "Chosik socket horizontal hole must fit the live 48px icon")
		_expect(_transparent_center_run_y(frame_image) >= 174 and _transparent_center_run_y(frame_image) <= 178, "Chosik socket vertical hole must fit the live 48px icon")
		_expect(frame_image.get_pixel(128, 128).a <= 0.01, "Chosik socket center must stay transparent")
		_expect(_opaque_magenta_count(frame_image) == 0, "Chosik socket must not retain opaque magenta")

	var renderer := SmasherSkillOrbRenderer.new()
	_verify_cluster(renderer, smasher_cluster_path, 165.0, 33.0, "Smasher")
	_verify_cluster(renderer, viper_cluster_path, 155.0, 32.0, "Viper")

	var character_runtime := PlayerCharacterRuntime.new()
	_expect(character_runtime.get_skill_cluster_frame_texture_key("smasher", 5) == "smasher_skill_cluster_frame_texture", "Smasher five-slot cluster routing must stay intact")
	_expect(character_runtime.get_skill_cluster_frame_texture_key("viper", 5) == "viper_skill_cluster_frame_texture", "Viper five-slot cluster routing must stay intact")
	_expect(character_runtime.get_skill_cluster_frame_texture_key("smasher", 6) == "", "Heavenly Cape six-slot HUD must keep the individual-socket fallback")

	var resources := BattleResources.new()
	var expected_specs := {
		frame_path: "skill_orb_frame_texture",
		smasher_cluster_path: "smasher_skill_cluster_frame_texture",
		viper_cluster_path: "viper_skill_cluster_frame_texture",
	}
	for path in expected_specs:
		var spec_count := 0
		for spec_value in resources._get_core_texture_specs():
			if spec_value is Dictionary:
				var spec: Dictionary = spec_value
				if str(spec.get("path", "")) == path and expected_specs[path] in spec.get("keys", []):
					spec_count += 1
		_expect(spec_count == 1, "Chosik HUD texture must join core staged prewarm exactly once: %s" % path)

	var underlay_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_underlay_renderer.gd")
	_expect(underlay_source.find("22.0 / 255.0, 81.0 / 255.0, 70.0 / 255.0") >= 0, "six-slot fallback connectors must use the deep-teal dancheong accent")
	_expect(underlay_source.find("32.0 / 255.0, 193.0 / 255.0, 230.0 / 255.0") < 0, "six-slot fallback connectors must retire the old electric-cyan accent")

	if _failures.is_empty():
		print("skill_orb_chosik_hud_reskin_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cluster(renderer: Object, path: String, base_angle: float, angle_step: float, label: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and image.get_size() == CLUSTER_SIZE, "%s Chosik cluster must preserve the 250x650 source contract" % label)
	if image == null:
		return
	var positions: Array[Vector2] = renderer.get_slot_positions(CLUSTER_CENTER, 55.0, 1.0, {
		"max_slots": 5,
		"skill_orb_radius": 24.0,
		"gauge_gap": 28.0,
		"orb_radius_base": 55.0,
		"slot_base_angle": base_angle,
		"slot_angle_step": angle_step,
	})
	_expect(positions.size() == 5, "%s Chosik cluster must retain exactly five slot anchors" % label)
	for position in positions:
		var rim_pos := Vector2i(roundi(position.x + 24.0), roundi(position.y))
		_expect(image.get_pixelv(rim_pos).a > ALPHA_THRESHOLD, "%s Chosik cluster must retain the ring at every slot anchor" % label)
	_expect(_opaque_gauge_annulus_count(image, CLUSTER_CENTER, 58.0, 95.0) < 7000, "%s Chosik cluster must not bake the retired large gauge ring underneath the live gauge" % label)
	_expect(_opaque_magenta_count(image) == 0, "%s Chosik cluster must not retain opaque magenta" % label)


func _alpha_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _transparent_center_run_x(image: Image) -> int:
	var y := int(image.get_height() * 0.5)
	var left := int(image.get_width() * 0.5)
	var right := left
	while left > 0 and image.get_pixel(left - 1, y).a <= ALPHA_THRESHOLD:
		left -= 1
	while right < image.get_width() - 1 and image.get_pixel(right + 1, y).a <= ALPHA_THRESHOLD:
		right += 1
	return right - left + 1


func _transparent_center_run_y(image: Image) -> int:
	var x := int(image.get_width() * 0.5)
	var top := int(image.get_height() * 0.5)
	var bottom := top
	while top > 0 and image.get_pixel(x, top - 1).a <= ALPHA_THRESHOLD:
		top -= 1
	while bottom < image.get_height() - 1 and image.get_pixel(x, bottom + 1).a <= ALPHA_THRESHOLD:
		bottom += 1
	return bottom - top + 1


func _opaque_gauge_annulus_count(image: Image, center: Vector2, inner_radius: float, outer_radius: float) -> int:
	var count := 0
	var inner_sq := inner_radius * inner_radius
	var outer_sq := outer_radius * outer_radius
	for y in range(max(0, floori(center.y - outer_radius)), min(image.get_height(), ceili(center.y + outer_radius + 1.0))):
		for x in range(max(0, floori(center.x - outer_radius)), min(image.get_width(), ceili(center.x + outer_radius + 1.0))):
			var distance_sq := Vector2(float(x), float(y)).distance_squared_to(center)
			if distance_sq >= inner_sq and distance_sq <= outer_sq and image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				count += 1
	return count


func _opaque_magenta_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > ALPHA_THRESHOLD and color.r > 0.86 and color.b > 0.70 and color.g < 0.35:
				count += 1
	return count


func _import_ctex_exists(import_path: String) -> bool:
	var import_text := FileAccess.get_file_as_string(import_path)
	var path_marker := "path=\""
	var start := import_text.find(path_marker)
	if start < 0:
		return false
	start += path_marker.length()
	var end := import_text.find("\"", start)
	if end < 0:
		return false
	return FileAccess.file_exists(import_text.substr(start, end - start))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
