extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const EXPECTED_SIZE := Vector2i(256, 256)
const TRAINING_ICON_FILES := {
	"physique_dash_recharge": "physique_dash_recharge_training_icon.png",
	"physique_dash_recovery": "physique_dash_recovery_training_icon.png",
	"physique_dash_distance": "physique_dash_distance_training_icon.png",
	"physique_move_speed": "physique_move_speed_training_icon.png",
	"physique_posture": "physique_posture_training_icon.png",
	"physique_paddle_size": "physique_paddle_size_training_icon.png",
	"physique_max_gauge": "physique_max_gauge_training_icon.png",
	"physique_hit_gauge": "physique_hit_gauge_training_icon.png",
	"physique_active_item_cooldown": "physique_active_item_cooldown_training_icon.png",
	"physique_chosik_cooldown": "physique_chosik_cooldown_training_icon.png",
	"physique_storage": "physique_storage_training_icon.png",
}
const MIGRATED_MUGONG_IDS := {
	"physique_dash_recharge": "dash_lightweight",
	"physique_dash_recovery": "dash_module_control",
	"physique_dash_distance": "dash_jump",
	"physique_move_speed": "common_swiftness",
	"physique_posture": "bulletproof_hat",
	"physique_paddle_size": "common_bulk_up",
	"physique_max_gauge": "fuel_pouch",
	"physique_hit_gauge": "bluetooth_ring",
	"physique_active_item_cooldown": "item_cooldown_mastery",
	"physique_chosik_cooldown": "common_training",
	"physique_storage": "common_expansion",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_training_icon_set()
	if _failures.is_empty():
		print("physique_training_icon_art_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_training_icon_set() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	var covered_ids := renderer.covered_ids()
	for id_value in TRAINING_ICON_FILES:
		var training_id := str(id_value)
		var expected_path := "res://assets/sprites/perks/physique_training/%s" % str(TRAINING_ICON_FILES[training_id])
		var actual_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(training_id, ""))
		var migrated_mugong_id := str(MIGRATED_MUGONG_IDS[training_id])
		var migrated_mugong_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(migrated_mugong_id, ""))

		_expect(actual_path == expected_path, "%s should use its dedicated Physique Training icon" % training_id)
		_expect(actual_path != migrated_mugong_path, "%s should not reuse the migrated Mugong icon" % training_id)
		_expect(covered_ids.has(training_id), "%s should stay covered by the runtime icon renderer" % training_id)
		_expect(ResourceLoader.exists(expected_path, "Texture2D"), "%s icon should import as Texture2D" % training_id)

		var source: Dictionary = renderer._get_icon_source(training_id)
		var texture: Texture2D = source.get("texture", null)
		_expect(texture != null, "%s icon should load through the production source query" % training_id)
		if texture != null:
			_expect(texture.get_width() == EXPECTED_SIZE.x and texture.get_height() == EXPECTED_SIZE.y, "%s icon should stay 256x256" % training_id)
		_expect(source.get("region", Rect2()).size == Vector2.ZERO, "%s should remain a static icon" % training_id)
		_verify_alpha_and_chroma(expected_path, training_id)

	renderer.prewarm_assets()
	for id_value in TRAINING_ICON_FILES:
		var training_id := str(id_value)
		var expected_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS[training_id])
		_expect(renderer.has_icon(training_id), "%s should remain drawable after prewarm" % training_id)
		_expect(renderer._texture_cache.has(expected_path), "%s should be cached by prewarm" % training_id)


func _verify_alpha_and_chroma(path: String, label: String) -> void:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		load_error = image.load(path)
	_expect(load_error == OK, "%s source PNG should load for visual QA" % label)
	if load_error != OK:
		return
	_expect(image.get_width() == EXPECTED_SIZE.x and image.get_height() == EXPECTED_SIZE.y, "%s source PNG should keep expected dimensions" % label)

	var visible_count := 0
	var edge_alpha_count := 0
	var visible_magenta_count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.03:
				visible_count += 1
			if (x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1) and pixel.a > 0.03:
				edge_alpha_count += 1
			if pixel.a > 0.10 and pixel.r > 0.67 and pixel.b > 0.55 and pixel.g < 0.36:
				visible_magenta_count += 1
	_expect(visible_count > 30000, "%s should contain a substantial visible medallion" % label)
	_expect(edge_alpha_count == 0, "%s should preserve a transparent outer edge" % label)
	_expect(visible_magenta_count == 0, "%s should not retain visible chroma-key spill" % label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
