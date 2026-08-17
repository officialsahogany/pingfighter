extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

# Texture paths, atlas geometry, and pure atlas-region slicing for the
# Stage 2 pillar background. `stage2_pillar_asset_state.gd` retains the loaded
# Texture2D references, staged-prewarm progress, and frame-hole cache; this
# module remains the immutable asset surface (paths, grid sizes, measured
# source rects) plus the offline-compatible pure slicing helper.

const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage2_cheongringwi_dragon_pool_base_imagegen_v3.png"
const TREE_TEXTURE_PATH := "res://assets/sprites/hud/stage2_cheongringwi_pine_guardians_imagegen_v1.png"
const GAME_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/stage2_cheongringwi_game_frame_imagegen_v1.png"
const LEAF_TEXTURE_PATH := "res://assets/sprites/hud/stage2_cheongringwi_ambient_seal_sprites_imagegen_v1.png"
const ROCK_TEXTURE_PATH := "res://assets/sprites/hud/stage2_crisis_rock_atlas_imagegen_v2.png"
const ROCK_DEBRIS_TEXTURE_PATH := "res://assets/sprites/hud/stage2_crisis_rock_debris_atlas_imagegen_v1.png"

const ROCK_ATLAS_COLUMNS := 4
const ROCK_ATLAS_ROWS := 4

# Fixed Stage 2 imagegen atlases use measured alpha bounds to avoid first-entry pixel scans.
const TREE_SOURCE_REGION_DATA := {
	"left": Rect2(55.0, 63.0, 404.0, 913.0),
	"right": Rect2(1078.0, 34.0, 412.0, 945.0),
}
const LEAF_SOURCE_REGION_DATA := [
	Rect2(176.0, 59.0, 298.0, 395.0),
	Rect2(625.0, 62.0, 266.0, 383.0),
	Rect2(1126.0, 117.0, 143.0, 252.0),
	Rect2(201.0, 529.0, 206.0, 400.0),
	Rect2(656.0, 545.0, 239.0, 370.0),
	Rect2(1115.0, 552.0, 221.0, 368.0),
]
const GAME_FRAME_SOURCE_HOLE := Rect2(155.0, 296.0, 1362.0, 568.0)
const ROCK_SOURCE_REGION_DATA := [
	Rect2(46.0, 60.0, 254.0, 246.0),
	Rect2(359.0, 66.0, 245.0, 234.0),
	Rect2(662.0, 68.0, 245.0, 238.0),
	Rect2(961.0, 65.0, 258.0, 242.0),
	Rect2(50.0, 365.0, 245.0, 234.0),
	Rect2(348.0, 396.0, 257.0, 191.0),
	Rect2(657.0, 367.0, 253.0, 232.0),
	Rect2(975.0, 365.0, 235.0, 234.0),
	Rect2(47.0, 652.0, 253.0, 256.0),
	Rect2(357.0, 673.0, 248.0, 228.0),
	Rect2(661.0, 672.0, 246.0, 233.0),
	Rect2(959.0, 678.0, 256.0, 224.0),
	Rect2(49.0, 982.0, 247.0, 217.0),
	Rect2(349.0, 991.0, 255.0, 202.0),
	Rect2(654.0, 983.0, 249.0, 217.0),
	Rect2(954.0, 985.0, 248.0, 210.0),
]
const ROCK_DEBRIS_SOURCE_REGION_DATA := [
	Rect2(44.0, 63.0, 240.0, 227.0),
	Rect2(368.0, 42.0, 210.0, 252.0),
	Rect2(670.0, 56.0, 225.0, 240.0),
	Rect2(992.0, 68.0, 207.0, 226.0),
	Rect2(44.0, 358.0, 208.0, 231.0),
	Rect2(361.0, 369.0, 223.0, 216.0),
	Rect2(658.0, 364.0, 239.0, 224.0),
	Rect2(985.0, 361.0, 222.0, 223.0),
	Rect2(40.0, 676.0, 223.0, 206.0),
	Rect2(365.0, 677.0, 207.0, 202.0),
	Rect2(672.0, 666.0, 202.0, 213.0),
	Rect2(989.0, 665.0, 212.0, 217.0),
	Rect2(40.0, 959.0, 209.0, 227.0),
	Rect2(375.0, 962.0, 192.0, 218.0),
	Rect2(669.0, 969.0, 204.0, 216.0),
	Rect2(989.0, 968.0, 192.0, 217.0),
]


# Slice a packed sprite atlas into per-cell `Rect2` source regions, trimmed to
# each cell's alpha bounds with a small `padding` margin. Returns one `Rect2`
# per `column * row` slot in row-major order. Cells whose alpha bounds are
# empty fall back to the full cell rect.
static func slice_alpha_atlas_regions(path: String, columns: int, rows: int, padding: int = 2) -> Array:
	if columns <= 0 or rows <= 0:
		return []
	var texture: Texture2D = ProjectResourceLoader.load_texture(path)
	if texture == null:
		return []
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return []
	if image.is_compressed():
		image.decompress()
	@warning_ignore("integer_division")
	var cell_w: int = image.get_width() / columns
	@warning_ignore("integer_division")
	var cell_h: int = image.get_height() / rows
	if cell_w <= 0 or cell_h <= 0:
		return []
	var regions: Array = []
	for row in range(rows):
		for column in range(columns):
			var cell_origin := Vector2i(column * cell_w, row * cell_h)
			var cell_rect := Rect2i(cell_origin, Vector2i(cell_w, cell_h))
			var cell_image: Image = image.get_region(cell_rect)
			var used_rect: Rect2i = cell_image.get_used_rect()
			if used_rect.size.x <= 0 or used_rect.size.y <= 0:
				regions.append(Rect2(cell_rect.position, cell_rect.size))
				continue
			var local_x: int = maxi(0, used_rect.position.x - padding)
			var local_y: int = maxi(0, used_rect.position.y - padding)
			var local_end_x: int = mini(cell_w, used_rect.position.x + used_rect.size.x + padding)
			var local_end_y: int = mini(cell_h, used_rect.position.y + used_rect.size.y + padding)
			regions.append(Rect2(
				float(cell_origin.x + local_x),
				float(cell_origin.y + local_y),
				float(maxi(1, local_end_x - local_x)),
				float(maxi(1, local_end_y - local_y))
			))
	return regions
