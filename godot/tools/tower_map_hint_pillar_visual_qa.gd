extends SceneTree

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentMapHintRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_hint_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_PATH := (
	"res://.godot/codex_captures/tower_map_iconography/"
	+ "s4_map_hint_left_pillar_2020x1246.png"
)


class FakePillarDrawPass:
	extends RefCounted

	func draw(
		canvas: CanvasItem,
		_registry: Object,
		view_size: Vector2,
		layout: Dictionary
	) -> void:
		var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
		var game_size: Vector2 = layout.get("game_size", Vector2.ZERO)
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color("111722"), true)
		canvas.draw_rect(
			Rect2(Vector2.ZERO, Vector2(game_offset.x, view_size.y)),
			Color("17202d"),
			true
		)
		canvas.draw_rect(
			Rect2(
				Vector2(game_offset.x - 18.0, game_offset.y),
				Vector2(14.0, game_size.y)
			),
			Color("6d4c32"),
			true
		)


class FakePlayfieldDrawer:
	extends RefCounted

	func draw(
		canvas: CanvasItem,
		_registry: Object,
		_shake_offset: Vector2,
		width: float,
		height: float,
		_pillar_width: float
	) -> void:
		canvas.draw_rect(
			Rect2(Vector2.ZERO, Vector2(width, height)),
			Color("294b63"),
			true
		)
		for row: int in range(1, 6):
			var y := float(row) * height / 6.0
			canvas.draw_line(Vector2(0.0, y), Vector2(width, y), Color("335b72"), 1.0)
		canvas.draw_circle(Vector2(width * 0.5, height * 0.55), 50.0, Color("e6c867"))


class FakeFlowOwner:
	extends RefCounted

	func is_active() -> bool:
		return false

	func get_phase_name() -> String:
		return ""


class CaptureRegistry:
	extends RefCounted

	var flow_owner: Object = FakeFlowOwner.new()
	var pillar_draw_pass: Object = FakePillarDrawPass.new()
	var playfield_drawer: Object = FakePlayfieldDrawer.new()
	var view_layout: Object = BattleViewLayout.new()

	func get_instance(key: String) -> Variant:
		match key:
			"tower_ascent_flow_owner":
				return flow_owner
			"battle_scene_pillar_draw_pass":
				return pillar_draw_pass
			"battle_playfield_scene_drawer":
				return playfield_drawer
			"battle_view_layout":
				return view_layout
		return null

	func get_cached_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return get_instance(key)


class ProductionScreenCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattleSceneDrawer.new()

	func _init(new_registry: Object) -> void:
		registry = new_registry

	func _draw() -> void:
		drawer.draw(self, registry, {"context_owner": self})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_map_hint_pillar_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_map_hint_pillar_visual_qa requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if mkdir_error != OK:
		_fail("capture directory creation failed: %d" % mkdir_error)
		return

	var registry := CaptureRegistry.new()
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := ProductionScreenCanvas.new(registry)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index: int in range(6):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("2020 by 1246 viewport capture failed")
		return

	var layout: Dictionary = registry.view_layout.build_game_layout(
		Vector2(VIEW_SIZE),
		760.0,
		750.0
	)
	var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var game_size: Vector2 = layout.get("game_size", Vector2.ZERO)
	var hint_rect := TowerAscentMapHintRenderer.new().get_hint_rect(
		Vector2(VIEW_SIZE),
		game_offset,
		game_size
	)
	var playfield_rect := Rect2(game_offset, game_size)
	if hint_rect.size.x <= 0.0 or hint_rect.intersects(playfield_rect):
		_fail("production hint geometry intersects the playfield: %s" % hint_rect)
		return
	if _count_changed_pixels(image, hint_rect, Color("17202d")) < 120:
		_fail("pillar hint did not materialize enough visible pixels")
		return
	if image.save_png(output_path) != OK:
		_fail("capture save failed: %s" % output_path)
		return

	print("tower_map_hint_pillar_visual_qa: size=%s" % VIEW_SIZE)
	print("tower_map_hint_pillar_visual_qa: hint_rect=%s playfield_rect=%s" % [
		hint_rect,
		playfield_rect,
	])
	print("tower_map_hint_pillar_visual_qa: capture=%s" % output_path)
	print("tower_map_hint_pillar_visual_qa: ok")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	registry = null
	await process_frame
	quit(0)


func _count_changed_pixels(image: Image, rect: Rect2, background: Color) -> int:
	var bounds := Rect2i(
		Vector2i(maxi(0, int(floor(rect.position.x))), maxi(0, int(floor(rect.position.y)))),
		Vector2i(
			mini(image.get_width(), int(ceil(rect.end.x))) - maxi(0, int(floor(rect.position.x))),
			mini(image.get_height(), int(ceil(rect.end.y))) - maxi(0, int(floor(rect.position.y)))
		)
	)
	var changed := 0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var pixel := image.get_pixel(x, y)
			var color_delta := (
				absf(pixel.r - background.r)
				+ absf(pixel.g - background.g)
				+ absf(pixel.b - background.b)
			)
			if color_delta > 0.08:
				changed += 1
	return changed


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
