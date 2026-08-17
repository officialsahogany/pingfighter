extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")

const TEXTURE_SLOT_COUNT := 6
const FRAME_HOLE_PREWARM_STEP := TEXTURE_SLOT_COUNT

var base_texture: Texture2D = null
var tree_texture: Texture2D = null
var game_frame_texture: Texture2D = null
var leaf_texture: Texture2D = null
var rock_texture: Texture2D = null
var rock_debris_texture: Texture2D = null
var texture_loaded := false
var prewarm_assets_done := false
var prewarm_step_index := 0
var tree_source_regions: Dictionary = {}
var leaf_source_regions: Array = []
var rock_source_regions: Array = []
var rock_debris_source_regions: Array = []
var game_frame_hole := Rect2()
var game_frame_hole_checked := false


func ensure_textures() -> void:
	if texture_loaded:
		return
	for step_index in range(TEXTURE_SLOT_COUNT):
		_load_texture_step(step_index)
	texture_loaded = true


func prewarm_assets_step() -> bool:
	if prewarm_assets_done:
		return true
	if prewarm_step_index < TEXTURE_SLOT_COUNT:
		if not _prewarm_texture_step(prewarm_step_index):
			return false
	elif prewarm_step_index == FRAME_HOLE_PREWARM_STEP:
		get_game_frame_source_hole()
	else:
		_finish_prewarm()
		return true
	prewarm_step_index += 1
	if prewarm_step_index > FRAME_HOLE_PREWARM_STEP:
		_finish_prewarm()
		return true
	return false


func get_game_frame_source_hole() -> Rect2:
	if game_frame_hole_checked:
		return game_frame_hole
	if game_frame_texture == null:
		return Rect2()
	game_frame_hole = Stage2PillarAssets.GAME_FRAME_SOURCE_HOLE
	game_frame_hole_checked = true
	return game_frame_hole


func _finish_prewarm() -> void:
	prewarm_assets_done = true
	prewarm_step_index = 0


func _prewarm_texture_step(step_index: int) -> bool:
	match step_index:
		0:
			if base_texture != null:
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.BASE_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			base_texture = result.get("texture", null) as Texture2D
		1:
			if tree_texture != null:
				_ensure_tree_regions()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.TREE_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			tree_texture = result.get("texture", null) as Texture2D
			_ensure_tree_regions()
		2:
			if game_frame_texture != null:
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.GAME_FRAME_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			game_frame_texture = result.get("texture", null) as Texture2D
		3:
			if leaf_texture != null:
				_ensure_leaf_regions()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.LEAF_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			leaf_texture = result.get("texture", null) as Texture2D
			_ensure_leaf_regions()
		4:
			if rock_texture != null:
				_ensure_rock_regions()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.ROCK_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			rock_texture = result.get("texture", null) as Texture2D
			_ensure_rock_regions()
		5:
			if rock_debris_texture != null:
				_ensure_rock_debris_regions()
				return true
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
			if not bool(result.get("done", true)):
				return false
			rock_debris_texture = result.get("texture", null) as Texture2D
			_ensure_rock_debris_regions()
	if step_index >= TEXTURE_SLOT_COUNT - 1:
		texture_loaded = true
	return true


func _load_texture_step(step_index: int) -> void:
	match step_index:
		0:
			if base_texture == null:
				base_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.BASE_TEXTURE_PATH)
		1:
			if tree_texture == null:
				tree_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.TREE_TEXTURE_PATH)
			_ensure_tree_regions()
		2:
			if game_frame_texture == null:
				game_frame_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.GAME_FRAME_TEXTURE_PATH)
		3:
			if leaf_texture == null:
				leaf_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.LEAF_TEXTURE_PATH)
			_ensure_leaf_regions()
		4:
			if rock_texture == null:
				rock_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_TEXTURE_PATH)
			_ensure_rock_regions()
		5:
			if rock_debris_texture == null:
				rock_debris_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
			_ensure_rock_debris_regions()


func _ensure_tree_regions() -> void:
	if tree_texture != null and tree_source_regions.is_empty():
		tree_source_regions = Stage2PillarAssets.TREE_SOURCE_REGION_DATA.duplicate()


func _ensure_leaf_regions() -> void:
	if leaf_texture != null and leaf_source_regions.is_empty():
		leaf_source_regions = Stage2PillarAssets.LEAF_SOURCE_REGION_DATA.duplicate()


func _ensure_rock_regions() -> void:
	if rock_texture != null and rock_source_regions.is_empty():
		rock_source_regions = Stage2PillarAssets.ROCK_SOURCE_REGION_DATA.duplicate()


func _ensure_rock_debris_regions() -> void:
	if rock_debris_texture != null and rock_debris_source_regions.is_empty():
		rock_debris_source_regions = Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA.duplicate()
