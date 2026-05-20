extends SceneTree

const Stage1PillarTreeRenderer := preload("res://scripts/stages/stage1/stage1_pillar_tree_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TREE_TEXTURE_PATH := "res://assets/sprites/hud/stage1_layered_tree_sidewallroot_imagegen_v3.png"

const VIEW_SIZE := Vector2i(1280, 800)

var _failures: Array[String] = []
var _probe: TreeWallrootProbe = null
var _frame_count := 0


class TreeWallrootProbe:
	extends Node2D

	var renderer: Object = Stage1PillarTreeRenderer.new()
	var tree_texture: Texture2D = ProjectResourceLoader.load_texture(TREE_TEXTURE_PATH)
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.045, 0.040, 0.035, 1.0), true)
		if tree_texture == null:
			return
		renderer.draw(
			self,
			tree_texture,
			Vector2(VIEW_SIZE),
			Vector2(260.0, 0.0),
			Vector2(760.0, 750.0),
			1.0,
			{}
		)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_probe = TreeWallrootProbe.new()
	_probe.name = "TreeWallrootProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_expect(_probe != null and _probe.draw_count > 0, "Stage 1 tree wallroot probe should receive a draw callback")
	_expect(_probe != null and _probe.tree_texture != null, "Stage 1 wallroot tree texture should load")
	if _probe != null and _probe.tree_texture != null:
		_expect(_probe.tree_texture.get_width() == 1645, "Stage 1 wallroot tree texture width should match generated sheet")
		_expect(_probe.tree_texture.get_height() == 956, "Stage 1 wallroot tree texture height should match generated sheet")
	if _failures.is_empty():
		print("stage1_pillar_tree_wallroot_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
