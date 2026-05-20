extends SceneTree

# Verifies the common starpoint visual host's prewarm + slot pool + sync_drop
# gating. The host is the GPU shader overlay that replaced four near-identical
# CPU draw loops on the starpoint drop visual across stages 1/2/3/4. A
# regression here typically shows up as either missing drops (slot pool not
# claiming) or a one-frame PSO compile stutter when the first scoring drop
# spawns in-game.

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_idempotence()
	_verify_pipeline_status_keys()
	_verify_shader_resource_path_and_uniforms()
	await _verify_instance_slot_pool_and_gating()
	await _verify_factory_dedupes_pending_host()

	if _failures.is_empty():
		print("common_starpoint_visual_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_idempotence() -> void:
	CommonStarpointVisualHost.prewarm_assets()
	CommonStarpointVisualHost.prewarm_assets()
	CommonStarpointVisualHost.prewarm_assets()
	var status: Dictionary = CommonStarpointVisualHost.build_pipeline_status()
	_expect(
		bool(status.get("common_starpoint_drop_shader_ready", false)),
		"shader resource must be marked ready after prewarm_assets()"
	)
	_expect(
		bool(status.get("common_starpoint_drop_white_texture_ready", false)),
		"shared white texture must be created during prewarm_assets()"
	)


func _verify_pipeline_status_keys() -> void:
	var status: Dictionary = CommonStarpointVisualHost.build_pipeline_status()
	for required_key in [
		"common_starpoint_drop_shader_ready",
		"common_starpoint_drop_max_slots",
		"common_starpoint_drop_white_texture_ready",
	]:
		_expect(
			status.has(required_key),
			"pipeline status must include %s for prewarm verification" % required_key
		)
	_expect(
		int(status.get("common_starpoint_drop_max_slots", 0)) >= 16,
		"slot pool must hold at least 16 simultaneous drops to cover treasure-hunt / mythic burst scenarios"
	)


func _verify_shader_resource_path_and_uniforms() -> void:
	var host_source := FileAccess.get_file_as_string("res://scripts/effects/common_starpoint_visual_host.gd")
	_expect(
		host_source.find("res://shaders/playfield/starpoint_drop.gdshader") >= 0,
		"FX host must load the shader from res://shaders/playfield/ per repo convention"
	)
	var shader_source := FileAccess.get_file_as_string("res://shaders/playfield/starpoint_drop.gdshader")
	_expect(
		shader_source != "",
		"starpoint_drop.gdshader must be present at res://shaders/playfield/"
	)
	for required_uniform in [
		"alpha",
		"glow_intensity",
		"rotation",
		"size_norm",
		"glow_color",
		"fill_color",
		"outline_color",
		"detector_shimmer_intensity",
		"iridescent_shimmer_intensity",
		"sparkle_ray_intensity",
		"elapsed",
		"star_tip_count",
	]:
		_expect(
			shader_source.find("uniform") >= 0 and shader_source.find(required_uniform) >= 0,
			"starpoint_drop shader must declare uniform %s" % required_uniform
		)
	# The full 4-layer glow that Stage 1's CPU constant collapsed to 1 layer
	# must run from the shader so commonization restores the original look.
	_expect(
		shader_source.find("for (int layer = 0; layer < 4;") >= 0,
		"shader must iterate 4 outer glow layers (restores Stage 1 glow quality)"
	)
	# Stage 1's 4-tip sparkle must remain selectable via star_tip_count; the
	# shader must NOT hardcode TAU / 5.0 in the star SDF or that breaks the
	# per-stage shape parity.
	_expect(
		shader_source.find("TAU / float(n)") >= 0
			and shader_source.find("max(3, tips)") >= 0
			and shader_source.find("TAU / 5.0") < 0,
		"star SDF must be parameterized by tip count (no hardcoded TAU / 5.0)"
	)
	# The SDF must measure distance to actual polygon edges (line segments
	# between tip and valley) rather than interpolating the boundary radius
	# in polar coordinates. The polar interpolation form rendered as rounded
	# petal shapes instead of sharp star tips.
	_expect(
		shader_source.find("vec2 tip = vec2(r_outer, 0.0)") >= 0
			and shader_source.find("vec2 valley = vec2(r_inner * cos(half_sector)") >= 0,
		"star SDF must use line-segment distance to (tip, valley) vertices, not polar mix(r_outer, r_inner, t)"
	)
	_expect(
		shader_source.find("mix(r_outer, r_inner, t)") < 0,
		"star SDF must not fall back to polar radius interpolation (produces rounded petal shapes)"
	)


func _verify_instance_slot_pool_and_gating() -> void:
	var host: Node2D = CommonStarpointVisualHost.new()
	get_root().add_child(host)
	await process_frame
	_expect(host._slot_count >= 16, "slot pool should be populated after _ready()")
	# sync_drop with zero life must hide the slot (no wasted GPU work).
	host.begin_frame()
	host.sync_drop({"pos": Vector2(40.0, 40.0), "size": 12.0, "life": 0.0})
	# Real drop with full life and the normal scrap palette.
	host.sync_drop({
		"pos": Vector2(120.0, 40.0),
		"size": 12.0,
		"life": 255.0,
		"rotation": 0.42,
		"glow_intensity": 1.0,
		"star_detector_bonus": false,
		"glow_color": Color(1.0, 0.45, 0.74, 1.0),
		"fill_color": Color(1.0, 0.0, 0.0, 1.0),
		"outline_color": Color(1.0, 1.0, 0.0, 1.0),
	})
	host.end_frame()
	_expect(
		not host._slots[0].visible,
		"zero-life sync_drop should hide the slot to avoid pointless GPU work"
	)
	_expect(
		host._slots[1].visible,
		"positive-life sync_drop should leave the slot visible for shader render"
	)
	# end_frame must hide stale slots from previous frames.
	host.begin_frame()
	host.end_frame()
	for i in range(host._slot_count):
		_expect(
			not host._slots[i].visible,
			"end_frame() must hide all unclaimed slots so stale overlays don't render"
		)
	host.queue_free()


# The factory's pending-host pointer must stop a second call within the same
# frame from instantiating a duplicate host while the first one waits for the
# deferred add_child. Otherwise multiple hosts pile up on the canvas parent.
func _verify_factory_dedupes_pending_host() -> void:
	var fake_canvas := Node2D.new()
	get_root().add_child(fake_canvas)
	# Two back-to-back factory calls in the same frame should return the same
	# pending host (the second must see the static _pending_host pointer).
	var first: Node = CommonStarpointVisualHost.get_or_create_on_canvas(fake_canvas)
	var second: Node = CommonStarpointVisualHost.get_or_create_on_canvas(fake_canvas)
	_expect(
		first == second,
		"factory must dedupe instances within the same frame so call_deferred add_child does not pile up duplicates"
	)
	await process_frame
	# After the deferred add_child lands, get_node_or_null finds the host and
	# the pending pointer should clear.
	var resolved: Node = CommonStarpointVisualHost.get_or_create_on_canvas(fake_canvas)
	_expect(
		resolved == first,
		"factory must return the previously-pended host once it's parented under the canvas"
	)
	_expect(
		fake_canvas.get_child_count() == 1,
		"canvas should hold exactly one starpoint host node after dedupe"
	)
	fake_canvas.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
