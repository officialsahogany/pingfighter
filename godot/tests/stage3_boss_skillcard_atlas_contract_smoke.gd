extends SceneTree

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage2BossSkillHudAssets := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_assets.gd")
const Stage3BossSkillHudAssets := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_assets.gd")
const Stage3BossSkillHudRenderer := preload("res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")

const EXPECTED_TOP_ROW_RGBA_SHA256 := "983a6fd3271deda9503c4e581b77d95164b141924d8306b999527d3d8efb1ac1"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_declared_atlas_contract()
	var runtime_ids := _collect_runtime_skill_ids()
	_verify_runtime_mapping(runtime_ids)
	_verify_imported_texture_and_source_pixels()
	_verify_renderer_slices(runtime_ids)
	_verify_fallback_counterproof(runtime_ids)
	_verify_stage2_sibling_unchanged()
	if failures.is_empty():
		print("stage3_boss_skillcard_atlas_contract_smoke: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_declared_atlas_contract() -> void:
	_expect(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLS == 4, "Stage 3 skillcard atlas must declare COLS=4")
	_expect(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_ROWS == 3, "Stage 3 skillcard atlas must declare ROWS=3")
	_expect(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_FRAMES == 11, "Stage 3 skillcard atlas must declare FRAMES=11")
	_expect(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLUMNS == Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLS, "legacy COLUMNS alias must remain lockstep with COLS")
	_expect(Stage3BossSkillHudAssets.SKILLCARD_FRAME_SIZE == Vector2i(256, 96), "Stage 3 skillcard cells must remain 256x96")
	_expect(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE == Vector2i(1024, 288), "Stage 3 skillcard atlas must remain 1024x288")
	_expect(
		Stage3BossSkillHudAssets.SKILLCARD_ATLAS_PATH == "res://assets/sprites/stage3/stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png",
		"Stage 3 skillcard runtime must use the Hwangyeokjeon canonical atlas"
	)
	_expect(int(Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.get("tear_shower", -1)) == 0, "tear_shower must keep index 0")
	_expect(int(Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.get("curse_chest", -1)) == 1, "curse_chest must keep index 1")
	_expect(int(Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.get("psycho_ball", -1)) == 2, "psycho_ball must keep index 2")
	_expect(not Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.values().has(3), "preserved canonical cell 3 must stay unassigned")


func _collect_runtime_skill_ids() -> Array[String]:
	var all_ids: Array[String] = []
	var stage3_variants: Array[String] = []
	for variant_value in StageBossVariantCatalog.VARIANTS.keys():
		var variant_id := str(variant_value)
		var entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
		if int(entry.get("stage", -1)) == 3 and bool(entry.get("ported", false)):
			stage3_variants.append(variant_id)
	stage3_variants.sort()
	_expect(stage3_variants.has("yeonmyo"), "Stage 3 runtime catalog must still include Yeonmyo")
	_expect(stage3_variants.has("teddy_bear"), "Stage 3 runtime catalog must still include Teddy Bear")
	_expect(stage3_variants.has("alice"), "Stage 3 runtime catalog must still include Alice")

	for variant_id in stage3_variants:
		var state := Stage3BossVariantSkillState.new()
		var context := _build_state_context(variant_id)
		var _update_result: Dictionary = state.update(0.0, context, {})
		_expect(str(state.active_variant) == variant_id, "Stage 3 wrapper must route the catalog variant %s" % variant_id)
		var hud_context: Dictionary = state.get_hud_context(null, context)
		_expect(bool(hud_context.get("stage3_boss_skill_hud_active", false)), "%s must enable the live Stage 3 skill rail" % variant_id)
		var skills := _as_array(hud_context.get("stage3_boss_skill_hud_skills", []))
		_expect(not skills.is_empty(), "%s must emit live boss skill ids" % variant_id)
		for skill_value in skills:
			if not (skill_value is Dictionary):
				_expect(false, "%s emitted a non-dictionary skill entry" % variant_id)
				continue
			var skill_id := str((skill_value as Dictionary).get("id", ""))
			_expect(not skill_id.is_empty(), "%s emitted an empty skill id" % variant_id)
			if not skill_id.is_empty() and not all_ids.has(skill_id):
				all_ids.append(skill_id)
	return all_ids


func _build_state_context(variant_id: String) -> Dictionary:
	return {
		"current_stage": 3,
		"stage_boss_variant": variant_id,
		"ball_active": false,
		"waiting_for_serve": true,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_size": 28.6,
	}


func _verify_runtime_mapping(runtime_ids: Array[String]) -> void:
	_expect(runtime_ids.size() == 10, "current Stage 3 boss states must emit ten unique art-backed skill ids")
	var violations := _mapping_violations(
		runtime_ids,
		Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX,
		Stage3BossSkillHudAssets.SKILLCARD_ATLAS_FRAMES
	)
	_expect(violations.is_empty(), "every live Stage 3 boss skill id must map inside the declared frame range: %s" % [violations])


func _mapping_violations(runtime_ids: Array[String], mapping: Dictionary, frame_count: int) -> Array[String]:
	var violations: Array[String] = []
	for skill_id in runtime_ids:
		if not mapping.has(skill_id):
			violations.append("missing:%s" % skill_id)
			continue
		var frame_index := int(mapping[skill_id])
		if frame_index < 0 or frame_index >= frame_count:
			violations.append("out_of_range:%s=%d" % [skill_id, frame_index])
	return violations


func _verify_imported_texture_and_source_pixels() -> void:
	var atlas_path: String = Stage3BossSkillHudAssets.SKILLCARD_ATLAS_PATH
	_expect(FileAccess.file_exists(atlas_path), "promoted Stage 3 canonical atlas PNG must exist")
	_expect(FileAccess.file_exists(atlas_path + ".import"), "promoted Stage 3 atlas must keep its .import sidecar")
	_expect(ResourceLoader.exists(atlas_path, "Texture2D"), "promoted Stage 3 atlas must have a materialized Texture2D import")
	var texture := ResourceLoader.load(atlas_path, "Texture2D") as Texture2D
	_expect(texture != null, "promoted Stage 3 atlas must load through ResourceLoader")
	if texture != null:
		_expect(texture is CompressedTexture2D, "promoted Stage 3 atlas must resolve to a .ctex-backed CompressedTexture2D")
		_expect(texture.get_size() == Vector2(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE), "imported Stage 3 atlas must expose 1024x288 pixels")

	var source_image := Image.new()
	var source_load_error := source_image.load_png_from_buffer(FileAccess.get_file_as_bytes(atlas_path))
	_expect(source_load_error == OK and not source_image.is_empty(), "promoted Stage 3 source PNG must decode")
	if source_load_error != OK or source_image.is_empty():
		return
	_expect(source_image.get_size() == Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE, "promoted Stage 3 source PNG must be 1024x288")
	var first_row := source_image.get_region(Rect2i(0, 0, 1024, 96))
	_expect(
		_sha256(first_row.get_data()) == EXPECTED_TOP_ROW_RGBA_SHA256,
		"promoted Stage 3 atlas first row must remain decoded-pixel-identical to canonical cells 0..3"
	)


func _verify_renderer_slices(runtime_ids: Array[String]) -> void:
	var renderer := Stage3BossSkillHudRenderer.new()
	var atlas_size := Vector2(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE)
	for skill_id in runtime_ids:
		if not Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.has(skill_id):
			continue
		var frame_index := int(Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX[skill_id])
		var expected_rect := Rect2(
			Vector2(
				(frame_index % Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLS) * 256,
				floori(float(frame_index) / float(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_COLS)) * 96
			),
			Vector2(256.0, 96.0)
		)
		_expect(
			renderer.get_debug_skillcard_source_rect(atlas_size, skill_id) == expected_rect,
			"%s must use its declared two-dimensional atlas cell" % skill_id
		)
	_expect(renderer.get_debug_skillcard_source_rect(atlas_size, "tear_shower") == Rect2(0.0, 0.0, 256.0, 96.0), "index 0 source pixels must not move")
	_expect(renderer.get_debug_skillcard_source_rect(atlas_size, "curse_chest") == Rect2(256.0, 0.0, 256.0, 96.0), "index 1 source pixels must not move")
	_expect(renderer.get_debug_skillcard_source_rect(atlas_size, "psycho_ball") == Rect2(512.0, 0.0, 256.0, 96.0), "index 2 source pixels must not move")


func _verify_fallback_counterproof(runtime_ids: Array[String]) -> void:
	var renderer := Stage3BossSkillHudRenderer.new()
	var atlas_size := Vector2(Stage3BossSkillHudAssets.SKILLCARD_ATLAS_SIZE)
	_expect(not renderer.get_debug_skillcard_source_rect(atlas_size, "missing_runtime_skill").has_area(), "an unknown skill id must remain on the procedural fallback path")
	_expect(not renderer.get_debug_skillcard_source_rect(Vector2(1024.0, 96.0), "tear_shower").has_area(), "a stale one-row atlas must fail closed to the fallback path")
	if runtime_ids.is_empty():
		return
	var deleted_id := runtime_ids[0]
	var mapping_without_one := Stage3BossSkillHudAssets.SKILLCARD_ID_TO_INDEX.duplicate(true)
	mapping_without_one.erase(deleted_id)
	var red_violations := _mapping_violations(runtime_ids, mapping_without_one, Stage3BossSkillHudAssets.SKILLCARD_ATLAS_FRAMES)
	_expect(red_violations.has("missing:%s" % deleted_id), "deleting any emitted id must make the coverage seal RED")


func _verify_stage2_sibling_unchanged() -> void:
	_expect(
		Stage2BossSkillHudAssets.SKILLCARD_PREWARM_IDS == ["jungle_quake", "speed_defense", "water_cannon"],
		"Stage 3 atlas wiring must not alter the Stage 2 sibling skillcard owner"
	)


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
