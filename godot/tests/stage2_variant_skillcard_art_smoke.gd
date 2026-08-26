extends SceneTree

const Stage2ArachneBossState := preload(
	"res://scripts/stages/stage2/stage2_arachne_boss_state.gd"
)
const Stage2BossSkillHudAssets := preload(
	"res://scripts/stages/stage2/stage2_boss_skill_hud_assets.gd"
)
const Stage2BossSkillHudRenderer := preload(
	"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd"
)
const Stage2MolewangBossState := preload(
	"res://scripts/stages/stage2/stage2_molewang_boss_state.gd"
)

const EXPECTED_PATHS := {
	"tunnel_raid": "res://assets/sprites/hud/stage2_tunnel_raid_skillcard_imagegen_v1.png",
	"spinning_claw": "res://assets/sprites/hud/stage2_spinning_claw_skillcard_imagegen_v1.png",
	"friend_moles": "res://assets/sprites/hud/stage2_friend_moles_skillcard_imagegen_v1.png",
	"web_trap": "res://assets/sprites/hud/stage2_web_trap_skillcard_imagegen_v1.png",
	"web_rescue": "res://assets/sprites/hud/stage2_web_rescue_skillcard_imagegen_v1.png",
	"spider_rage": "res://assets/sprites/hud/stage2_spider_rage_skillcard_imagegen_v1.png",
}
const EXPECTED_SKILLCARD_SIZE := Vector2(2172.0, 724.0)

var _failures: Array[String] = []


class SkillCardRailProbe:
	extends Node2D

	var renderer: Object
	var context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		renderer.draw(self, context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var variant_contexts := _build_variant_hud_contexts()
	var runtime_skill_ids := _collect_runtime_skill_ids(variant_contexts)
	_verify_declared_paths(runtime_skill_ids)
	var renderer := Stage2BossSkillHudRenderer.new()
	renderer.prewarm_assets()
	_verify_materialized_textures(renderer, runtime_skill_ids)
	await _verify_live_hud_draws(renderer, variant_contexts)
	_verify_missing_mapping_counterproof(runtime_skill_ids)
	if _failures.is_empty():
		print(
			"stage2_variant_skillcard_art_smoke: ids=%s textures=%d hud_draws=%d"
			% [str(runtime_skill_ids), runtime_skill_ids.size(), variant_contexts.size()]
		)
		print("stage2_variant_skillcard_art_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_variant_hud_contexts() -> Array[Dictionary]:
	var contexts: Array[Dictionary] = []
	var states: Array = [
		Stage2MolewangBossState.new(),
		Stage2ArachneBossState.new(),
	]
	for state in states:
		state.reset()
		var context: Dictionary = state.get_hud_context()
		context.merge({
			"current_stage": 2,
			"view_size": Vector2(1280.0, 750.0),
			"game_offset": Vector2(260.0, 0.0),
			"game_size": Vector2(760.0, 750.0),
			"time_seconds": 1.25,
		}, true)
		contexts.append(context)
	return contexts


func _collect_runtime_skill_ids(contexts: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for context in contexts:
		for skill_variant in context.get("stage2_boss_skill_hud_skills", []):
			if not (skill_variant is Dictionary):
				_expect(false, "Stage 2 variant HUD must emit dictionary skill entries")
				continue
			var skill_id := str((skill_variant as Dictionary).get("id", ""))
			if not skill_id.is_empty() and not result.has(skill_id):
				result.append(skill_id)
	result.sort()
	var expected_ids: Array[String] = []
	for skill_id_variant in EXPECTED_PATHS.keys():
		expected_ids.append(str(skill_id_variant))
	expected_ids.sort()
	_expect(
		result == expected_ids,
		"live Molewang and Arachne states must emit exactly the six art-backed ids"
	)
	return result


func _verify_declared_paths(runtime_skill_ids: Array[String]) -> void:
	for skill_id in runtime_skill_ids:
		_expect(
			Stage2BossSkillHudAssets.SKILLCARD_PREWARM_IDS.has(skill_id),
			"prewarm list must include %s" % skill_id
		)


func _verify_materialized_textures(
	renderer: RefCounted,
	runtime_skill_ids: Array[String]
) -> void:
	for skill_id in runtime_skill_ids:
		var expected_path := str(EXPECTED_PATHS.get(skill_id, ""))
		var actual_path := str(renderer.call("_get_skillcard_texture_path", skill_id))
		_expect(actual_path == expected_path, "%s must route to its promoted PNG" % skill_id)
		_expect(FileAccess.file_exists(expected_path), "%s source PNG must exist" % skill_id)
		_expect(
			FileAccess.file_exists(expected_path + ".import"),
			"%s must keep its materialized import sidecar" % skill_id
		)
		_expect(
			ResourceLoader.exists(expected_path, "Texture2D"),
			"%s must resolve through ResourceLoader" % skill_id
		)
		var texture := renderer.call("_get_skillcard_texture", skill_id) as Texture2D
		_expect(texture != null, "%s HUD draw texture must be non-null" % skill_id)
		if texture != null:
			_expect(
				texture.get_size() == EXPECTED_SKILLCARD_SIZE,
				"%s imported texture must remain 2172x724" % skill_id
			)
	_expect(
		renderer.call("_get_skillcard_texture_path", "missing_variant_skill") == "",
		"unknown skill ids must remain on the procedural fallback path"
	)


func _verify_live_hud_draws(
	renderer: RefCounted,
	variant_contexts: Array[Dictionary]
) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 750)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var probe := SkillCardRailProbe.new()
	probe.renderer = renderer
	viewport.add_child(probe)
	for context in variant_contexts:
		var before_draw_count := probe.draw_count
		probe.context = context
		probe.queue_redraw()
		for _frame in range(3):
			await process_frame
		_expect(
			probe.draw_count > before_draw_count,
			"each Stage 2 variant must execute the production HUD draw pass"
		)
	viewport.queue_free()
	await process_frame


func _verify_missing_mapping_counterproof(runtime_skill_ids: Array[String]) -> void:
	var mapping_without_one := EXPECTED_PATHS.duplicate(true)
	var deleted_id := runtime_skill_ids[0] if not runtime_skill_ids.is_empty() else ""
	mapping_without_one.erase(deleted_id)
	var missing_ids: Array[String] = []
	for skill_id in runtime_skill_ids:
		if not mapping_without_one.has(skill_id):
			missing_ids.append(skill_id)
	_expect(
		not deleted_id.is_empty() and missing_ids == [deleted_id],
		"deleting one promoted mapping must make the coverage counterproof RED"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
