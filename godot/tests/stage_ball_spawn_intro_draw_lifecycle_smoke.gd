extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroDrawLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_draw_lifecycle.gd")
const StageBallSpawnPillarOverlayHost := preload("res://scripts/core/stage_ball_spawn_pillar_overlay_host.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted


class FakeOwner:
	extends RefCounted


class FakeIntro:
	extends RefCounted

	var active := true
	var overlay_active := true
	var layout_calls := 0
	var sync_calls := 0
	var draw_calls := 0
	var last_view_size := Vector2.ZERO
	var last_layout: Dictionary = {}

	func _build_layout(_registry: Object, view_size: Vector2) -> Dictionary:
		layout_calls += 1
		last_view_size = view_size
		return {
			"game_offset": Vector2(12.0, 34.0),
			"render_scale": 1.5,
		}

	func _sync_fx_host_layout(layout: Dictionary) -> void:
		sync_calls += 1
		last_layout = layout

	func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
		return value if value is Vector2 else fallback

	func _draw_spawn(_canvas: CanvasItem) -> void:
		draw_calls += 1

	func is_overlay_active() -> bool:
		return active or overlay_active


class FakeDrawLifecycle:
	extends RefCounted

	var calls := 0
	var last_view_size := Vector2.ZERO

	func draw_intro(_intro: Object, _canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
		calls += 1
		last_view_size = view_size


class FakePillarOverlayHost:
	extends Node2D

	var active := true


class FakePillarOverlayDrawer:
	extends RefCounted

	var draw_calls := 0
	var last_config: Dictionary = {}

	func draw_pillar_overlay(_canvas: CanvasItem, _registry: Object, config: Dictionary = {}) -> void:
		draw_calls += 1
		last_config = config


class DrawHarness:
	extends Node2D

	var lifecycle: Object = null
	var intro: Object = null
	var draw_owner: Object = null
	var registry: Object = null
	var view_size := Vector2.ZERO
	var draw_completed := false

	func _draw() -> void:
		lifecycle.draw_intro(intro, self, draw_owner, registry, view_size)
		draw_completed = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_draw_lifecycle_runs_intro_draw_frame()
	_verify_draw_lifecycle_keeps_inactive_guard()
	_verify_intro_delegates_public_draw_surface()
	_verify_intro_pillar_restore_stops_after_handoff()
	_verify_intro_detached_pillar_restore_runs_until_handoff()
	_verify_detached_pillar_host_skips_background_restore()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_draw_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draw_lifecycle_runs_intro_draw_frame() -> void:
	var lifecycle: Object = StageBallSpawnIntroDrawLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var canvas := DrawHarness.new()
	canvas.lifecycle = lifecycle
	canvas.intro = intro
	canvas.draw_owner = owner
	canvas.registry = registry
	canvas.view_size = Vector2(1280.0, 720.0)
	get_root().add_child(canvas)
	canvas.queue_redraw()

	await process_frame

	_expect(canvas.draw_completed, "draw harness should run a real CanvasItem draw callback")
	_expect(intro.layout_calls == 1, "draw lifecycle should build layout once")
	_expect(intro.last_view_size == Vector2(1280.0, 720.0), "draw lifecycle should pass view size to layout")
	_expect(intro.sync_calls == 1, "draw lifecycle should sync FX host layout")
	_expect(is_equal_approx(float(intro.last_layout.get("render_scale", 0.0)), 1.5), "draw lifecycle should sync returned layout")
	# `_draw_spawn` MUST NOT be invoked on the battle scene canvas: doing so
	# bypasses the FX host's playfield clip and the spawn animation bleeds into
	# the pillar columns. The FX host's intro draw bridge owns rendering now.
	_expect(intro.draw_calls == 0, "draw lifecycle must NOT draw the spawn intro on the battle scene canvas")
	canvas.free()


func _verify_draw_lifecycle_keeps_inactive_guard() -> void:
	var lifecycle: Object = StageBallSpawnIntroDrawLifecycle.new()
	var intro := FakeIntro.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	intro.active = false
	intro.overlay_active = false

	lifecycle.draw_intro(intro, null, owner, registry, Vector2(800.0, 600.0))

	_expect(intro.layout_calls == 0, "inactive draw lifecycle should not build layout")
	_expect(intro.sync_calls == 0, "inactive draw lifecycle should not sync FX layout")
	_expect(intro.draw_calls == 0, "inactive draw lifecycle should not draw on canvas")


func _verify_intro_delegates_public_draw_surface() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var lifecycle := FakeDrawLifecycle.new()
	intro.draw_lifecycle = lifecycle

	intro.draw(null, null, null, Vector2(640.0, 360.0))

	_expect(lifecycle.calls == 1, "intro draw should delegate to draw lifecycle helper")
	_expect(lifecycle.last_view_size == Vector2(640.0, 360.0), "intro draw should pass view size through")


func _verify_intro_pillar_restore_stops_after_handoff() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	intro.active = true
	intro.overlay_active = true
	intro.serve_handoff_done = false
	_expect(intro.should_restore_pillar_overlay(), "active intro should request pillar restore")
	var host := FakePillarOverlayHost.new()
	get_root().add_child(host)
	intro.pillar_overlay_host = host
	_expect(not intro.should_restore_pillar_overlay(), "active intro should not request a second pillar restore while the detached host is active")
	intro.pillar_overlay_host = null
	host.free()
	intro.serve_handoff_done = true
	intro.active = false
	intro.overlay_active = true
	_expect(not intro.should_restore_pillar_overlay(), "post-handoff residual overlay should skip pillar restore")
	intro.overlay_active = false
	_expect(not intro.should_restore_pillar_overlay(), "inactive intro should not request pillar restore")


func _verify_intro_detached_pillar_restore_runs_until_handoff() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	intro.active = true
	intro.overlay_active = true
	intro.serve_handoff_done = false
	intro.elapsed_sec = 3.90
	_expect(intro._should_use_pillar_overlay_host(), "detached FX pillar restore should remain active until gameplay handoff")
	intro.elapsed_sec = 4.01
	_expect(not intro._should_use_pillar_overlay_host(), "detached FX pillar restore should stop after blocking intro time")
	intro.elapsed_sec = 3.90
	intro.active = false
	intro.overlay_active = true
	intro.serve_handoff_done = true
	_expect(not intro._should_use_pillar_overlay_host(), "detached FX pillar restore should not run during residual post-handoff overlay")


func _verify_detached_pillar_host_skips_background_restore() -> void:
	var host: Object = StageBallSpawnPillarOverlayHost.new()
	var drawer := FakePillarOverlayDrawer.new()
	var context_owner := Node2D.new()
	host.drawer = drawer
	host.begin(FakeRegistry.new(), context_owner)
	host._draw()

	_expect(drawer.draw_calls == 1, "detached pillar host should draw its overlay once when active")
	_expect(bool(drawer.last_config.get("skip_background", false)), "detached pillar host should skip the expensive background restore")
	_expect(drawer.last_config.get("context_owner", null) == context_owner, "detached pillar host should keep the real battle scene context owner")
	host.free()
	context_owner.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
