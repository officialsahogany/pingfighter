extends SceneTree

const StageBallSpawnIntroFxHost := preload("res://scripts/core/stage_ball_spawn_intro_fx_host.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

var _failures: Array[String] = []


class FakeIntroRenderer:
	extends RefCounted

	var draw_calls := 0

	func _draw_spawn(_canvas: CanvasItem) -> void:
		draw_calls += 1

	func _current_phase() -> int:
		return 1


func _init() -> void:
	_verify_pipeline_status()
	_verify_host_layers_and_stage_tint()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_fx_host_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pipeline_status() -> void:
	var status: Dictionary = StageBallSpawnIntroFxHost.build_pipeline_status()
	_expect(WritheEmber.has_preset("ball_spawn_vortex"), "WritheEmber should expose the ball spawn vortex preset")
	_expect(WritheEmber.has_preset("ball_spawn_orbit_rings"), "WritheEmber should expose the ball spawn orbit rings preset")
	_expect(bool(status.get("ball_spawn_intro_shader_host_pipeline", false)), "ball spawn FX host should expose the shader pipeline")
	_expect(bool(status.get("ball_spawn_intro_texture_pieces_ready", false)), "ball spawn FX host should load vortex, orbit rings, and ray burst textures")
	_expect(bool(status.get("ball_spawn_intro_vortex_png_slot", false)), "ball spawn FX host should load the vortex PNG")
	_expect(bool(status.get("ball_spawn_intro_orbit_rings_png_slot", false)), "ball spawn FX host should load the orbit rings PNG")
	_expect(bool(status.get("ball_spawn_intro_ray_burst_png_slot", false)), "ball spawn FX host should load the ray burst PNG")


func _verify_host_layers_and_stage_tint() -> void:
	var host := StageBallSpawnIntroFxHost.new()
	get_root().add_child(host)
	var intro_renderer := FakeIntroRenderer.new()
	host.set_intro_renderer(intro_renderer)
	host.begin_fx(
		Vector2(380.0, 375.0),
		Vector2(380.0, 672.0),
		26.6175,
		2.0,
		0.75,
		1.25,
		true
	)
	host.set_intro_renderer(intro_renderer)
	var pre_layout_status: Dictionary = host.get_debug_status()
	_expect(not host.visible, "ball spawn FX host should stay hidden until viewport layout is synced")
	_expect(not bool(pre_layout_status.get("active", true)), "unsynced FX host should not report active")
	_expect(not bool(pre_layout_status.get("layout_synced", true)), "unsynced FX host should expose missing layout")
	host.apply_stage_tint(5)
	host.sync_layout({
		"game_offset": Vector2(12.0, 18.0),
		"render_scale": 1.25,
	})
	host.sync_state({
		"visible": true,
		"phase_progress": 0.25,
		"pos": Vector2(380.0, 375.0),
		"scale": 0.82,
		"alpha": 0.55,
	}, 1, 0.35)
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "ball spawn FX host should become active after begin_fx")
	_expect(bool(status.get("layout_synced", false)), "ball spawn FX host should require synced viewport layout before drawing")
	_expect(bool(status.get("vortex_writhe_shader", false)), "phase 1 vortex should use the shared WritheEmber shader")
	_expect(bool(status.get("orbit_rings_writhe_shader", false)), "phase 1 orbit rings should use the shared WritheEmber shader")
	_expect(bool(status.get("orbit_rings_visible", false)), "phase 1 orbit rings should be visible during condensation")
	_expect(bool(status.get("playfield_clip_active", false)), "ball spawn FX host should clip texture and particle layers to the playfield columns (game x=80..680)")
	_expect(bool(status.get("procedural_accents_clipped_to_playfield", false)), "ball spawn FX host should draw procedural accent rays inside the clipped playfield")
	_expect(bool(status.get("intro_renderer_clipped_to_playfield", false)), "ball spawn intro `_draw_spawn` must render inside the clipped playfield bridge, not on the battle scene canvas")
	_expect(bool(status.get("particles_local_to_clip", false)), "ball spawn FX particles should simulate in the clipped playfield space")
	_expect(bool(status.get("phase1_inflow_radius_safe", false)), "phase 1 inflow particles should spawn inside the playfield bounds")
	_expect(status.get("stage_tint", Color.WHITE) == Color(0.55, 0.85, 1.0, 1.0), "stage tint should use Stage 5 cyan")

	host.sync_state({
		"visible": true,
		"phase_progress": 0.05,
		"pos": Vector2(380.0, 420.0),
		"scale": 1.0,
		"alpha": 1.0,
	}, 3, 2.82)
	status = host.get_debug_status()
	_expect(bool(status.get("orbit_rings_phaseout_triggered", false)), "phase 3 should have started the orbit rings fadeout")
	_expect(bool(status.get("ray_burst_triggered", false)), "phase 3 should trigger the ray burst once")
	_expect(bool(status.get("ray_burst_visible", false)), "ray burst texture should be visible immediately after trigger")

	host.tear_down(true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
