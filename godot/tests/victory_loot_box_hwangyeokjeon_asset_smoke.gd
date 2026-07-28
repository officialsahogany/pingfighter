extends SceneTree

const GRID_COLS := 4
const GRID_ROWS := 4
const FRAME_COUNT := 16
const CELL_SIZE := 256
const TARGET_BASELINE_Y := 233
const MANIFEST_PATH := "res://assets/sprites/result_boxes/victory_loot_box_autosprite_manifest.json"
const SHEETS := [
	{
		"label": "normal",
		"path": "res://assets/sprites/result_boxes/result_box_common_open_16f.png",
	},
	{
		"label": "advanced",
		"path": "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png",
	},
	{
		"label": "guaranteed_mythic",
		"path": "res://assets/sprites/result_boxes/result_box_guaranteed_mythic_open_16f.png",
	},
]

var _failures := 0


func _initialize() -> void:
	var closed_widths: Array[int] = []
	for sheet_value: Variant in SHEETS:
		var sheet: Dictionary = sheet_value as Dictionary
		closed_widths.append(_verify_sheet(str(sheet.get("path", "")), str(sheet.get("label", ""))))
	_verify_closed_size_tier(closed_widths)
	_verify_autosprite_manifest()
	_verify_full_common_frame_policy()
	if _failures == 0:
		print("victory_loot_box_hwangyeokjeon_asset_smoke: ok")
		quit(0)
		return
	push_error("victory loot-box asset smoke failed: %d" % _failures)
	quit(1)


func _verify_sheet(path: String, label: String) -> int:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_expect(not bytes.is_empty(), "%s source PNG should be readable" % label)
	if bytes.is_empty():
		return 0
	var image := Image.new()
	var load_error: Error = image.load_png_from_buffer(bytes)
	_expect(load_error == OK, "%s source PNG should decode" % label)
	if load_error != OK:
		return 0
	_expect(
		image.get_size() == Vector2i(CELL_SIZE * GRID_COLS, CELL_SIZE * GRID_ROWS),
		"%s should keep the 4x4 / 256px-cell contract" % label
	)
	var frame_baselines: Array[int] = []
	var closed_width := 0
	for frame_index in range(FRAME_COUNT):
		var frame_bbox: Rect2i = _alpha_bbox_in_cell(image, frame_index)
		_expect(frame_bbox.size.x > 0 and frame_bbox.size.y > 0, "%s frame %d should not be empty" % [label, frame_index])
		_expect(_cell_edge_alpha_count(image, frame_index) == 0, "%s frame %d should leave every cell edge transparent" % [label, frame_index])
		if frame_bbox.size.x <= 0 or frame_bbox.size.y <= 0:
			continue
		var baseline_y: int = frame_bbox.end.y - 1
		frame_baselines.append(baseline_y)
		_expect(
			baseline_y == TARGET_BASELINE_Y,
			"%s frame %d should keep the chest contact baseline at y=%d (got %d)" % [label, frame_index, TARGET_BASELINE_Y, baseline_y]
		)
		if frame_index == 0:
			closed_width = frame_bbox.size.x
	_expect(frame_baselines.size() == FRAME_COUNT, "%s should expose all 16 frame baselines" % label)
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "%s runtime texture should import" % label)
	if texture != null:
		_expect(texture.get_size() == Vector2(CELL_SIZE * GRID_COLS, CELL_SIZE * GRID_ROWS), "%s imported texture should keep source dimensions" % label)
	return closed_width


func _verify_closed_size_tier(widths: Array[int]) -> void:
	_expect(widths.size() == SHEETS.size(), "all three closed-chest widths should be measured")
	if widths.size() != SHEETS.size():
		return
	var min_width: int = widths.min()
	var max_width: int = widths.max()
	_expect(min_width > 0, "closed-chest widths should be non-zero")
	if min_width <= 0:
		return
	_expect(
		float(max_width) / float(min_width) <= 1.10,
		"three reward tiers should keep closed-body size within the shared 10%% band"
	)


func _verify_autosprite_manifest() -> void:
	var source: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	_expect(not source.is_empty(), "victory loot-box AutoSprite manifest should exist")
	for required_token in [
		"cms4gwdsp006pau1iamoab4xd",
		"cms4gwf6l006rau1i0m4q8f2n",
		"cms4gwgo9006tau1iy07gk21t",
		"fixed_transform_all_frames",
		"\"safe_last_frame\": 15",
	]:
		_expect(source.contains(required_token), "manifest should pin provenance token: %s" % required_token)


func _verify_full_common_frame_policy() -> void:
	var loot_source: String = FileAccess.get_file_as_string("res://scripts/core/victory_loot_phase_state.gd")
	var result_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(loot_source.contains("const BOX_COMMON_SAFE_LAST_FRAME := 15"), "in-game loot should use all 16 valid common frames")
	_expect(result_source.contains("const RESULT_BOX_COMMON_SAFE_LAST_FRAME := 15"), "dormant result-box renderer should move with the same 16-frame common policy")


func _alpha_bbox_in_cell(image: Image, frame_index: int) -> Rect2i:
	var row: int = floori(float(frame_index) / float(GRID_COLS))
	var origin := Vector2i((frame_index % GRID_COLS) * CELL_SIZE, row * CELL_SIZE)
	var min_x := CELL_SIZE
	var min_y := CELL_SIZE
	var max_x := -1
	var max_y := -1
	for y in range(CELL_SIZE):
		for x in range(CELL_SIZE):
			if image.get_pixel(origin.x + x, origin.y + y).a <= 0.0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _cell_edge_alpha_count(image: Image, frame_index: int) -> int:
	var row: int = floori(float(frame_index) / float(GRID_COLS))
	var origin := Vector2i((frame_index % GRID_COLS) * CELL_SIZE, row * CELL_SIZE)
	var count := 0
	for x in range(CELL_SIZE):
		count += int(image.get_pixel(origin.x + x, origin.y).a > 0.0)
		count += int(image.get_pixel(origin.x + x, origin.y + CELL_SIZE - 1).a > 0.0)
	for y in range(1, CELL_SIZE - 1):
		count += int(image.get_pixel(origin.x, origin.y + y).a > 0.0)
		count += int(image.get_pixel(origin.x + CELL_SIZE - 1, origin.y + y).a > 0.0)
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
