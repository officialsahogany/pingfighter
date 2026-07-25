extends SceneTree

# Seals the golden mythic-perk ornament (runtime_perk_overlay_renderer):
#   - mythic rarity must reach BOTH draw branches (choice card + owned-perk tray),
#     while ordinary perks must NOT be gilded (grep-negative-evidence guard).
#   - _perimeter_point (new sparkle-orbit math) hits every corner and wraps.
#   - a LIVE draw of the mythic card + ornament (large + compact rects) runs on a
#     real CanvasItem; the smoke runner fails on any Godot ERROR line, so a
#     degenerate draw_colored_polygon ("Invalid polygon data") on the crown gem or
#     a bad draw call would break this seal.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []
var _renderer: RefCounted = null
var _draw_ran := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_renderer = RuntimePerkOverlayRenderer.new()
	var catalog := RuntimePerkCatalog.new()

	# --- Data seal: mythic rarity reaches the choice-card branch. ---
	var mythic_id := "ragnarok_hammer"
	var mythic_data: Dictionary = catalog.get_perk_data(mythic_id)
	_expect(
		str(mythic_data.get("rarity", "")).to_lower() == "mythic",
		"catalog.get_perk_data(%s) must report rarity 'mythic' so the choice-card ornament fires" % mythic_id
	)

	# --- Data seal: rarity reaches the owned-perk tray branch; commons stay plain. ---
	var acquired: Array = _renderer._build_acquired_perks({mythic_id: 1, "common_swiftness": 3}, catalog, null)
	var mythic_marked := false
	var common_marked := false
	for entry_value in acquired:
		var entry: Dictionary = entry_value
		var is_myth: bool = str(entry.get("rarity", "")).to_lower() == "mythic"
		match str(entry.get("id", "")):
			mythic_id:
				mythic_marked = is_myth
			"common_swiftness":
				common_marked = is_myth
	_expect(mythic_marked, "owned mythic perk must carry rarity 'mythic' so the tray ornament fires")
	_expect(not common_marked, "a common perk must NOT be tagged mythic (no false gold ornament)")

	# --- Geometry seal: perimeter walk (sparkle orbit path). ---
	_verify_perimeter_point()

	# --- Live draw seal. ---
	await _run_live_draw()

	if _failures.is_empty():
		print("mythic_perk_ornament_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_perimeter_point() -> void:
	var r := Rect2(Vector2(10.0, 20.0), Vector2(100.0, 60.0))
	var perim: float = 2.0 * (100.0 + 60.0)
	_expect(_renderer._perimeter_point(r, 0.0).is_equal_approx(Vector2(10.0, 20.0)), "perimeter dist 0 should be the top-left corner")
	_expect(_renderer._perimeter_point(r, 50.0).is_equal_approx(Vector2(60.0, 20.0)), "perimeter along the top edge should track x")
	_expect(_renderer._perimeter_point(r, 100.0).is_equal_approx(Vector2(110.0, 20.0)), "perimeter dist == width should be the top-right corner")
	_expect(_renderer._perimeter_point(r, 160.0).is_equal_approx(Vector2(110.0, 80.0)), "perimeter dist width+height should be the bottom-right corner")
	_expect(_renderer._perimeter_point(r, perim).is_equal_approx(Vector2(10.0, 20.0)), "a full perimeter walk should wrap back to the origin")
	_expect(_renderer._perimeter_point(r, -perim).is_equal_approx(Vector2(10.0, 20.0)), "negative distances should wrap via fposmod")


func _run_live_draw() -> void:
	var node := Node2D.new()
	node.draw.connect(_on_node_draw.bind(node))
	root.add_child(node)
	# Redraw across several frames so the ornament renders at varying pulse/twinkle
	# phases (different sparkles cross the alpha gate, gem/frame sizes vary).
	for _i in range(4):
		node.queue_redraw()
		await process_frame
	_expect(_draw_ran, "the live mythic draw pass should have executed at least once")
	node.queue_free()


func _on_node_draw(node: CanvasItem) -> void:
	_draw_ran = true
	var choice := {
		"id": "ragnarok_hammer",
		"name": "라그나로크",
		"rarity": "mythic",
		"icon_color": Color(0.6, 0.4, 1.0),
		"current_level": 0,
		"next_level": 1,
		"max_level": 1,
		"character_restriction": "",
	}
	# Large choice cards (>= crown ref) in both selected + unselected intensity.
	_renderer._draw_card(node, choice, Rect2(Vector2(60.0, 60.0), Vector2(250.0, 126.0)), true, 1.0, null)
	_renderer._draw_card(node, choice, Rect2(Vector2(360.0, 60.0), Vector2(250.0, 126.0)), false, 1.0, null)
	# Compact owned-tray cell (below the crown threshold -> no crown gem): glow behind
	# the (implicit) cell + frame in front, mirroring the real draw order.
	var tray_rect := Rect2(Vector2(60.0, 260.0), Vector2(54.0, 54.0))
	_renderer._draw_mythic_ornament_glow(node, tray_rect, 1.0, 0.72)
	_renderer._draw_mythic_ornament_frame(node, tray_rect, 1.0, 0.72)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
