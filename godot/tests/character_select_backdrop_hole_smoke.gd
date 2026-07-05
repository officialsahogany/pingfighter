extends SceneTree

const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const CharacterSelectPreviewVfxHost := preload("res://scripts/ui/character_select_preview_vfx_host.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class StubPreviewHost:
	extends Control

	var backdrop_active := true

	func is_backdrop_host_active() -> bool:
		return backdrop_active


func _init() -> void:
	var screen: Control = CharacterSelectScreen.new()
	screen.size = Vector2(1920.0, 1080.0)

	# Negative-z backdrop trap seal (Slice H fullscreen shape): while the
	# adopted fullscreen host is live the screen must report backdrop-active
	# and skip its opaque background fill entirely; without a live host the
	# opaque fallback must return.
	_expect(not bool(screen.call("_backdrop_fullscreen_active")), "no preview node -> opaque fallback background must stay on")

	var stub := StubPreviewHost.new()
	screen.set("preview", stub)
	_expect(bool(screen.call("_backdrop_fullscreen_active")), "active backdrop host -> screen must skip the opaque background")

	stub.backdrop_active = false
	_expect(not bool(screen.call("_backdrop_fullscreen_active")), "inactive backdrop host -> opaque fallback background must return")

	# Editorial diagonal-cut chrome geometry: cached per rect, closed outline,
	# and provably triangulable fill.
	var rect := Rect2(Vector2(100.0, 100.0), Vector2(400.0, 300.0))
	var first: Dictionary = screen.call("_diag_panel_geometry", rect, 16.0)
	var second: Dictionary = screen.call("_diag_panel_geometry", rect, 16.0)
	_expect(is_same(first, second), "diag panel geometry must be served from the per-rect cache")
	var fill_points: PackedVector2Array = first.get("fill", PackedVector2Array())
	var outline_points: PackedVector2Array = first.get("outline", PackedVector2Array())
	_expect(fill_points.size() == 6, "diag panel fill must be the 6-point hexagon")
	_expect(outline_points.size() == 7 and outline_points[0] == outline_points[6], "diag panel outline must close the loop")
	_expect(Geometry2D.triangulate_polygon(fill_points).size() > 0, "diag panel fill polygon must stay triangulable")

	screen.size = Vector2(1280.0, 720.0)
	var resized: Dictionary = screen.call("_diag_panel_geometry", rect, 16.0)
	_expect(not is_same(first, resized), "view-size change must reset the diag geometry cache")

	# Watermark shear precondition seal: the identity-restore after the
	# oblique watermark is only safe while this canvas sets NO other
	# transform — exactly one set/restore pair may exist in the screen.
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(
		screen_source.count("draw_set_transform_matrix(") == 2,
		"character_select_screen must contain exactly the watermark shear set/restore pair"
	)
	_expect(
		screen_source.count("draw_set_transform(") == 0,
		"character_select_screen must not add positional draw_set_transform calls"
	)

	# Slice D/I asset-and-wiring-same-slice seal: every backplate path must
	# point at a real on-disk file (a reserved-but-absent path in a draw path
	# re-stats the filesystem every frame — plan §3-4).
	_expect(
		FileAccess.file_exists(CharacterSelectPreviewVfxHost.DEEP_BACKPLATE_PATH),
		"DEEP_BACKPLATE_PATH must point at an existing texture file"
	)
	for backplate_character_id in CharacterSelectPreviewVfxHost.BACKPLATE_PATHS:
		var backplate_path := str(CharacterSelectPreviewVfxHost.BACKPLATE_PATHS[backplate_character_id])
		_expect(
			FileAccess.file_exists(backplate_path),
			"Slice I backplate for %s must exist on disk" % str(backplate_character_id)
		)
		# Import sidecar seal (Codex Slice I review P1): file_exists alone
		# passes on a raw PNG, but without <file>.png.import the texture is
		# excluded from threaded prewarm and from exports — it silently falls
		# back to a synchronous raw decode.
		_expect(
			ProjectResourceLoader.texture_resource_exists(backplate_path),
			"Slice I backplate for %s must have a Godot import sidecar" % str(backplate_character_id)
		)
	_expect(
		CharacterSelectPreviewVfxHost.get_backplate_texture_path("unknown_id") == CharacterSelectPreviewVfxHost.DEEP_BACKPLATE_PATH,
		"unknown character ids must fall back to the Mika city backplate"
	)
	# (rail holo-stage stills retired 2026-07-04 — 상승 랩 에너지로 교체;
	# PNGs remain on disk as unwired rollback references.)

	screen.free()
	stub.free()

	if _failures.is_empty():
		print("character_select_backdrop_hole_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
