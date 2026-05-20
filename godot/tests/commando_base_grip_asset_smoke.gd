extends SceneTree

## Smoke test for Commando B2 base-grip assets.
##
## These sheets are generated with Gemini MCP, then deterministically fitted
## into the runtime 4x2 / 160x160 cell contract. They are not wired into
## gameplay yet; this test locks down the asset contract so later anchor-table
## work can rely on stable dimensions.

const IDLE_BACK_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_idle_back_gemini_v1.png"
const WALK_RIGHT_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_right_gemini_v1.png"
const WALK_LEFT_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_left_gemini_v1.png"

const ASSETS := [
	{
		"label": "idle_back",
		"path": IDLE_BACK_PATH,
		"min_w": 80,
		"max_w": 88,
	},
	{
		"label": "walk_right",
		"path": WALK_RIGHT_PATH,
		"min_w": 50,
		"max_w": 64,
	},
	{
		"label": "walk_left",
		"path": WALK_LEFT_PATH,
		"min_w": 50,
		"max_w": 64,
	},
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_texture_loads()
	_verify_image_contract()

	if _failures.is_empty():
		print("commando_base_grip_asset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_texture_loads() -> void:
	for asset in ASSETS:
		var label: String = asset["label"]
		var path: String = asset["path"]
		var texture: Texture2D = load(path)
		_expect(texture is Texture2D, "B2 %s texture must load as Texture2D" % label)
		if texture is Texture2D:
			_expect(texture.get_width() == 640, "B2 %s texture width must be 640" % label)
			_expect(texture.get_height() == 320, "B2 %s texture height must be 320" % label)


func _verify_image_contract() -> void:
	for asset in ASSETS:
		var label: String = asset["label"]
		var path: String = asset["path"]
		var image := Image.new()
		var error: Error = image.load(ProjectSettings.globalize_path(path))
		_expect(error == OK, "B2 %s Image.load must succeed" % label)
		if error != OK:
			continue
		_expect(image.get_width() == 640, "B2 %s image width must be 640" % label)
		_expect(image.get_height() == 320, "B2 %s image height must be 320" % label)
		_verify_transparent_corners(image, label)
		_verify_frame_alpha_bounds(image, asset)


func _verify_transparent_corners(image: Image, label: String) -> void:
	var corners := [
		Vector2i(0, 0),
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]
	for corner in corners:
		var color: Color = image.get_pixelv(corner)
		_expect(color.a <= 0.01, "B2 %s sheet corner %s must be transparent, alpha=%s" % [label, str(corner), str(color.a)])


func _verify_frame_alpha_bounds(image: Image, asset: Dictionary) -> void:
	const CELL := 160
	var label: String = asset["label"]
	var min_w: int = int(asset["min_w"])
	var max_w: int = int(asset["max_w"])
	for frame_index in range(8):
		var col: int = frame_index % 4
		@warning_ignore("integer_division")
		var row: int = frame_index / 4
		var min_x := CELL
		var min_y := CELL
		var max_x := -1
		var max_y := -1
		for y in range(CELL):
			for x in range(CELL):
				var alpha: float = image.get_pixel(col * CELL + x, row * CELL + y).a
				if alpha > 0.05:
					min_x = min(min_x, x)
					min_y = min(min_y, y)
					max_x = max(max_x, x)
					max_y = max(max_y, y)
		_expect(max_x >= 0 and max_y >= 0, "B2 %s frame %d must contain visible pixels" % [label, frame_index])
		if max_x < 0 or max_y < 0:
			continue
		var visible_w: int = max_x - min_x + 1
		var visible_h: int = max_y - min_y + 1
		_expect(visible_h >= 96 and visible_h <= 106, "B2 %s frame %d visible height must stay near 100px, got %d" % [label, frame_index, visible_h])
		_expect(visible_w >= min_w and visible_w <= max_w, "B2 %s frame %d visible width must stay in %d..%d, got %d" % [label, frame_index, min_w, max_w, visible_w])
		_expect(max_y >= 149 and max_y <= 153, "B2 %s frame %d feet/bottom y must stay near 152, got %d" % [label, frame_index, max_y])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
