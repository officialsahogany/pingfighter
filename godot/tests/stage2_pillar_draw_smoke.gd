extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2PillarSceneDrawer := preload("res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd")


class Stage2DrawProbe:
	extends Node2D

	var background: Object = null
	var draw_count := 0
	var draw_result := false
	var overlay_draw_result := false

	func _draw() -> void:
		draw_count += 1
		draw_result = background.draw(
			self,
			Vector2(1280.0, 800.0),
			Vector2(260.0, 25.0),
			Vector2(760.0, 750.0),
			760.0
		)
		overlay_draw_result = background.draw_pillar_background_overlay(
			self,
			Vector2(1280.0, 800.0),
			Vector2(260.0, 25.0),
			Vector2(760.0, 750.0),
			760.0
		)


var probe: Stage2DrawProbe = null
var frame_count := 0


func _init() -> void:
	var background: Object = Stage2PillarBackground.new()
	var scene_drawer: Object = Stage2PillarSceneDrawer.new()
	_expect(background.has_method("draw_pillar_background_overlay"), "Stage 2 pillar background should expose clipped overlay drawing")
	_expect(scene_drawer.has_method("draw_pillar_background_overlay"), "Stage 2 pillar scene drawer should restore background during split overlay draws")
	var asset_status: Dictionary = background.get_imagegen_asset_status()
	_expect(bool(asset_status.get("base", false)), "Stage 2 pillar base image should load before drawing")
	_expect(bool(asset_status.get("tree", false)), "Stage 2 pillar tree sprites should load before drawing")
	_expect(bool(asset_status.get("game_frame", false)), "Stage 2 pillar game frame should load before drawing")
	_expect(bool(asset_status.get("leaf", false)), "Stage 2 ambient leaf sprites should load before drawing")

	background._spawn_crisis_rock_wall({})
	var boss_serve_y := 25.0 + 40.0 + 16.9 * 1.575
	var ball_collision_radius := 28.6 * 0.5
	for rock in background.get_rocks_snapshot():
		var target: Vector2 = rock.get("target_pos", Vector2.ZERO)
		var radius := float(rock.get("radius", 0.0))
		_expect(
			target.y + radius + ball_collision_radius < boss_serve_y - 4.0,
			"Stage 2 crisis wall rocks should stay behind the boss serve ball"
		)

	probe = Stage2DrawProbe.new()
	probe.background = background
	get_root().add_child(probe)
	probe.queue_redraw()


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 2:
		return false
	_expect(probe.draw_count > 0, "Stage 2 pillar draw probe should receive a draw callback")
	_expect(probe.draw_result, "Stage 2 original pillar background draw should return true")
	_expect(probe.overlay_draw_result, "Stage 2 pillar background overlay draw should return true")
	print("stage2_pillar_draw_smoke: ok")
	quit(0)
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
