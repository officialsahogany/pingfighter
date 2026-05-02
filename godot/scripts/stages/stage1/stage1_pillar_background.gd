extends RefCounted

const Stage1PillarAmbientState := preload("res://scripts/stages/stage1/stage1_pillar_ambient_state.gd")
const Stage1PillarLayerRenderer := preload("res://scripts/stages/stage1/stage1_pillar_layer_renderer.gd")

const HANJI_TEXTURE_PATH := "res://assets/sprites/hud/stage1_layered_cyber_hanji_base_imagegen_v1.png"
const TREE_SPRITE_TEXTURE_PATH := "res://assets/sprites/hud/stage1_layered_tree_sprites_imagegen_v1.png"
const CLOUD_SPRITE_TEXTURE_PATH := "res://assets/sprites/hud/stage1_layered_cloud_sprites_imagegen_v1.png"
const BUTTERFLY_SHEET_TEXTURE_PATH := "res://assets/sprites/hud/stage1_butterfly_sheet_v1.png"

var hanji_texture: Texture2D
var tree_sprite_texture: Texture2D
var cloud_sprite_texture: Texture2D
var butterfly_sheet_texture: Texture2D

var ambient_state: Object = Stage1PillarAmbientState.new()
var layer_renderer: Object = Stage1PillarLayerRenderer.new()


func _init() -> void:
	_load_textures()
	ambient_state.init_state()


func _load_textures() -> void:
	hanji_texture = _load_texture_resource(HANJI_TEXTURE_PATH)
	tree_sprite_texture = _load_texture_resource(TREE_SPRITE_TEXTURE_PATH)
	cloud_sprite_texture = _load_texture_resource(CLOUD_SPRITE_TEXTURE_PATH)
	butterfly_sheet_texture = _load_texture_resource(BUTTERFLY_SHEET_TEXTURE_PATH)


func _load_texture_resource(path: String) -> Texture2D:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture is Texture2D:
			return texture
	return null


func update(delta: float) -> void:
	ambient_state.update(delta)


func trigger_tree_shake(side: String, impact_y: float, impact_speed: float, field_height: float) -> void:
	ambient_state.trigger_tree_shake(side, impact_y, impact_speed, field_height, layer_renderer)


func draw(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2, field_width: float) -> bool:
	ambient_state.update_layout(view_size, game_offset, game_size)
	if hanji_texture == null:
		return false

	var source_size: Vector2 = hanji_texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return false

	var game_rect := Rect2(game_offset, game_size)
	var cover_scale: float = max(view_size.x / source_size.x, view_size.y / source_size.y)
	var target_size: Vector2 = source_size * cover_scale
	var target_pos: Vector2 = (view_size - target_size) * 0.5
	canvas.draw_texture_rect(hanji_texture, Rect2(target_pos, target_size), false)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 246.0 / 255.0, 220.0 / 255.0, 16.0 / 255.0))

	var scale_factor: float = game_size.x / max(1.0, field_width)
	layer_renderer.draw_hanji_subtle_borders(canvas, view_size, game_rect, scale_factor)
	layer_renderer.draw_cloud_motion_layers(canvas, cloud_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_time())
	layer_renderer.draw_tree_motion_layers(canvas, tree_sprite_texture, view_size, game_offset, game_size, scale_factor, ambient_state.get_tree_shakes())
	layer_renderer.draw_tree_drop_petals(canvas, ambient_state.get_tree_drop_petals())
	layer_renderer.draw_floating_petals(canvas, ambient_state.get_floating_petals())
	layer_renderer.draw_butterflies(canvas, butterfly_sheet_texture, ambient_state.get_butterflies(), view_size, game_offset, game_size, scale_factor, ambient_state.get_time())
	layer_renderer.draw_game_border_shine(canvas, game_rect, scale_factor, ambient_state.get_time())
	return true
