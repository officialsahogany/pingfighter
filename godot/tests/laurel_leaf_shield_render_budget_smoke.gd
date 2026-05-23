extends SceneTree

const LaurelLeafShieldState := preload("res://scripts/characters/laurel_leaf_shield_state.gd")


func _init() -> void:
	_verify_laurel_lod_thresholds()
	_verify_laurel_draw_path_uses_shared_render_lod()
	print("laurel_leaf_shield_render_budget_smoke: ok")
	quit(0)


func _verify_laurel_lod_thresholds() -> void:
	var state := LaurelLeafShieldState.new()
	_expect(state._is_lod_active(0.58), "Sacred Laurel should enter Laurel shield draw LOD at the 72 FPS render scale")
	_expect(state._is_severe_lod_active(0.58), "Sacred Laurel should use the severe Laurel shield draw path at the 72 FPS render scale")
	_expect(state._get_particle_render_stride(0.58) == LaurelLeafShieldState.SEVERE_LOD_PARTICLE_STRIDE, "severe Laurel draw should stride hit particles")
	_expect(LaurelLeafShieldState.LOD_GLOW_SEGMENTS <= 10, "Laurel LOD glow should keep a tight segment budget")


func _verify_laurel_draw_path_uses_shared_render_lod() -> void:
	var effects_source: String = _read_source("res://scripts/core/battle_playfield_effects_drawer.gd")
	var scene_source: String = _read_source("res://scripts/core/battle_playfield_scene_drawer.gd")
	var state_source: String = _read_source("res://scripts/characters/laurel_leaf_shield_state.gd")
	_expect(
		effects_source.find("BattleRenderQuality.effect_scale(draw_context)") >= 0,
		"Laurel shield drawer should use the shared render-quality LOD scale"
	)
	_expect(
		scene_source.find("draw_laurel_leaf_shield(canvas, registry, shake_offset, draw_context)") >= 0,
		"playfield scene should pass draw context into Laurel shield rendering"
	)
	_expect(
		state_source.find("func _draw_leaf_lod") >= 0 and state_source.find("if lod_active:") >= 0,
		"Laurel shield state should have a low-cost LOD leaf draw path"
	)
	_expect(
		state_source.find("draw_colored_polygon(body_points") >= 0,
		"Laurel shield LOD should preserve a leaf silhouette instead of drawing boxy wide lines"
	)
	_expect(
		state_source.find("draw_line(stem, tip, base_color") < 0,
		"Laurel shield LOD should not use a thick stem-to-tip body line"
	)


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % path)
		quit(1)
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
