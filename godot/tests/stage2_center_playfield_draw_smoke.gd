extends SceneTree

const Stage2PlayfieldRenderer := preload("res://scripts/stages/stage2/stage2_playfield_renderer.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")


class Stage2CenterProbe:
	extends Node2D

	var renderer: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		renderer.draw(self, {
			"current_stage": 2,
			"width": 760.0,
			"height": 750.0,
			"ball_pos": Vector2(418.0, 394.0),
			"boss_pos": Vector2(320.0, 48.0),
			"boss_paddle_size": Vector2(110.0, 18.0),
			"boss_hitbox_height": 18.0,
			"boss_vel": 12.0,
			"player_pos": Vector2(296.0, 677.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"stage2_boss_expression": "happy",
			"stage2_boss_rage_tint": 0.25,
			"dash_snapshot": {"active": true},
		}, Vector2.ZERO)


var probe: Stage2CenterProbe = null
var frame_count := 0


func _init() -> void:
	var renderer: Object = Stage2PlayfieldRenderer.new()
	var asset_status: Dictionary = renderer.get_imagegen_asset_status()
	_expect(bool(asset_status.get("center_source", false)), "Stage 2 center source image should load")
	_expect(bool(asset_status.get("center_fallback", false)), "Stage 2 center fallback image should load")
	_expect(bool(asset_status.get("bush_atlas", false)), "Stage 2 bush atlas should load")
	_expect(bool(asset_status.get("vine_atlas", false)), "Stage 2 boss vine atlas should load")

	var layout: Dictionary = renderer.get_layout_snapshot()
	_expect(int(layout.get("bush_count", 0)) == 12, "Stage 2 center playfield should keep the original 12 bush anchors")
	_expect(int(layout.get("vine_count", 0)) == 6, "Stage 2 center playfield should keep the original 6 boss vines")
	_expect(int(layout.get("falling_leaf_count", 0)) == 8, "Stage 2 center playfield should keep the original 8 falling leaves")
	_expect(not Stage2PlayfieldRenderer.ENABLE_STATIC_BUSH_CLUSTER_CACHE, "Stage 2 static bush clusters should avoid runtime image-composite cache generation")
	_expect(Stage2PlayfieldRenderer.MAX_BUSH_TEXTURE_CLUSTERS_PER_BUSH == 3, "Stage 2 bush clusters should restore visible clump density without returning to the uncapped backup budget")
	_expect(Stage2PlayfieldRenderer.PLAYER_BUSH_TEXTURE_CLUSTER_BONUS == 1, "Stage 2 player-side bushes should keep a small foreground density bonus")
	_expect(int(layout.get("bush_draw_cluster_count", 999)) == 42, "Stage 2 bush anchors should restore a bounded 42-cluster texture draw list")
	_expect(Stage2PlayfieldRenderer.BUSH_RENDER_STRIDE_SEVERE_LOD <= 1, "Stage 2 severe LOD should keep all bush anchors visible")
	_expect(int(layout.get("bush_render_stride_severe_lod", 0)) == Stage2PlayfieldRenderer.BUSH_RENDER_STRIDE_SEVERE_LOD, "Stage 2 layout snapshot should expose severe bush stride")
	_expect(Stage2PlayfieldRenderer.BUSH_CLUSTER_RENDER_STRIDE_SEVERE_LOD >= 2, "Stage 2 severe LOD should stride bush texture clusters instead of dropping bush anchors")
	_expect(int(layout.get("bush_cluster_render_stride_severe_lod", 0)) == Stage2PlayfieldRenderer.BUSH_CLUSTER_RENDER_STRIDE_SEVERE_LOD, "Stage 2 layout snapshot should expose severe bush cluster stride")
	_expect(Stage2PlayfieldRenderer.FALLING_LEAF_RENDER_LIMIT <= 8, "Stage 2 falling leaves should keep the restored 8-leaf ambience within a bounded budget")
	_expect(Stage2PlayfieldRenderer.FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD >= 4 and Stage2PlayfieldRenderer.FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD <= 8, "Stage 2 severe LOD should keep falling leaves visible (2026-07-04 original-look restore)")
	_expect(int(layout.get("falling_leaf_render_limit_severe_lod", 999)) == Stage2PlayfieldRenderer.FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD, "Stage 2 layout snapshot should expose severe falling-leaf cap")
	_expect(Stage2PlayfieldRenderer.VINE_RUSTLE_STRIP_COUNT <= 1, "Stage 2 vine rustle should keep the textured slice count capped")
	_expect(Stage2PlayfieldRenderer.VINE_RENDER_STRIDE_SEVERE_LOD <= 1, "Stage 2 severe LOD should keep all boss vines visible (2026-07-04 original-look restore)")
	_expect(int(layout.get("vine_render_stride_severe_lod", 0)) == Stage2PlayfieldRenderer.VINE_RENDER_STRIDE_SEVERE_LOD, "Stage 2 layout snapshot should expose severe vine stride")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_SEGMENTS >= 32, "Stage 2 center stadium ellipse fills should keep the original round silhouette")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_SEGMENTS <= 36, "Stage 2 center stadium ellipse fills should stay within a bounded draw budget")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_OUTLINE_SEGMENTS >= 64, "Stage 2 center stadium outline should keep the original round silhouette")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_OUTLINE_SEGMENTS <= 64, "Stage 2 center stadium outline should stay within a bounded draw budget")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_ARC_SEGMENTS >= 28, "Stage 2 center stadium electric arcs should avoid polygonal stepping")
	_expect(Stage2PlayfieldRenderer.ELLIPSE_ARC_SEGMENTS <= 28, "Stage 2 center stadium electric arcs should stay within a bounded draw budget")
	_expect(renderer._is_severe_lod_active(0.58), "Stage 2 renderer should treat the 60 FPS cap quality scale as severe LOD")
	_expect(renderer._get_lod_count(10, 7, 3, 0.58) == 3, "Stage 2 renderer should use severe LOD counts at 60 FPS cap quality")

	var actor_context_builder: Object = BattleDrawActorContext.new()
	var tracked_ball := Vector2(418.0, 394.0)
	var actor_context: Dictionary = actor_context_builder.build({
		"current_stage": 2,
		"ball_active": true,
		"ball_pos": tracked_ball,
		"ball_vel": Vector2(5.0, -3.0),
	}, {})
	_expect(
		actor_context.get("ball_pos", Vector2.ZERO) == tracked_ball,
		"Stage 2 actor context should forward ball_pos for crocodile eye tracking"
	)
	var pupil_offset: Vector2 = renderer._calculate_pupil_offset(
		Vector2(353.0, 363.0),
		tracked_ball,
		12.0,
		5.0
	)
	_expect(pupil_offset.length() > 0.5, "Stage 2 crocodile pupils should offset toward the tracked ball")

	probe = Stage2CenterProbe.new()
	probe.renderer = renderer
	get_root().add_child(probe)
	probe.queue_redraw()


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 2:
		return false
	_expect(probe.draw_count > 0, "Stage 2 center playfield draw probe should receive a draw callback")
	print("stage2_center_playfield_draw_smoke: ok")
	quit(0)
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
