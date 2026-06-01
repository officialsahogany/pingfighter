extends SceneTree

const Stage5HongryunPillarBackground := preload("res://scripts/stages/stage5/stage5_hongryun_pillar_background.gd")
const Stage5HongryunPlayfieldRenderer := preload("res://scripts/stages/stage5/stage5_hongryun_playfield_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_playfield_center_border_contract()
	_verify_background_severe_lod_contract()

	if _failures.is_empty():
		print("stage5_center_border_background_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_playfield_center_border_contract() -> void:
	var renderer := Stage5HongryunPlayfieldRenderer.new()
	renderer.prewarm_assets()
	var status: Dictionary = renderer.get_imagegen_asset_status()
	_expect(bool(status.get("stage5_center_border_texture", false)), "Stage 5 playfield should load the imagegen center border")
	_expect(bool(status.get("stage5_center_border_draw_enabled", false)), "Stage 5 playfield should draw the imagegen center border")
	_expect(
		str(status.get("stage5_center_border_path", "")).ends_with("stage5_hongryun_center_border_imagegen_v1.png"),
		"Stage 5 playfield should use the accepted Hongryun center border PNG"
	)
	_expect(
		float(status.get("stage5_center_border_fallback_stroke", 99.0)) <= 2.0,
		"Stage 5 fallback center border should stay thin when the PNG is missing"
	)
	_expect(
		float(status.get("stage5_center_border_collision_edge_band_px", 99.0)) <= 13.0,
		"Stage 5 center border should stay inside the ball collision edge band"
	)
	_expect(
		bool(status.get("stage5_center_border_inner_guides_removed", false)),
		"Stage 5 center border should not draw misleading inner guide lines"
	)
	_verify_center_border_alpha()


func _verify_center_border_alpha() -> void:
	var path := "res://assets/sprites/hud/stage5_hongryun_center_border_imagegen_v1.png"
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null, "Stage 5 center border PNG should load for alpha audit")
	if image == null:
		return
	_expect(image.get_size() == Vector2i(760, 750), "Stage 5 center border PNG should match the 760x750 playfield")
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var inner_clear_margin_px := 28
	var inner_alpha_pixels := 0
	for y in range(inner_clear_margin_px, image.get_height() - inner_clear_margin_px):
		for x in range(inner_clear_margin_px, image.get_width() - inner_clear_margin_px):
			if image.get_pixel(x, y).a > 0.01:
				inner_alpha_pixels += 1
	_expect(inner_alpha_pixels == 0, "Stage 5 center border PNG should leave the inner playfield clear")

	var edge_alpha_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var edge_distance: int = mini(mini(x, image.get_width() - 1 - x), mini(y, image.get_height() - 1 - y))
			if edge_distance <= int(Stage5HongryunPlayfieldRenderer.CENTER_BORDER_COLLISION_EDGE_BAND_PX) and image.get_pixel(x, y).a > 0.01:
				edge_alpha_pixels += 1
	_expect(edge_alpha_pixels > 1000, "Stage 5 center border PNG should contain visible alpha near the collision edge")


func _verify_background_severe_lod_contract() -> void:
	var background := Stage5HongryunPillarBackground.new()
	_expect(
		Stage5HongryunPillarBackground.SPIRAL_BURST_ARM_COUNT_SEVERE_LOD <= 2,
		"Stage 5 background severe LOD should reduce spiral burst arms"
	)
	_expect(
		Stage5HongryunPillarBackground.SPIRAL_BURST_PRIMARY_SEGMENTS_SEVERE_LOD <= 14,
		"Stage 5 background severe LOD should reduce spiral burst arc segments"
	)
	_expect(
		Stage5HongryunPillarBackground.FIRE_IMPACT_OUTER_SEGMENTS_SEVERE_LOD <= 20,
		"Stage 5 background severe LOD should reduce fire impact arc segments"
	)
	_expect(
		Stage5HongryunPillarBackground.VIGNETTE_STEPS_SEVERE_LOD <= 3,
		"Stage 5 background severe LOD should reduce vignette passes"
	)
	_expect(
		background._get_lod_count(4, 3, 2, Stage5HongryunPillarBackground.SEVERE_LOD_ACTIVE_THRESHOLD) == 2,
		"Stage 5 background LOD helper should select severe counts at the severe threshold"
	)
	_expect(
		background._get_lod_count(4, 3, 2, Stage5HongryunPillarBackground.LOD_ACTIVE_THRESHOLD) == 3,
		"Stage 5 background LOD helper should select medium LOD counts at the normal LOD threshold"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
