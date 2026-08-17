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
	await _verify_clear_helpers_hide_visible_slots()

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
	_expect(
		bool(status.get("common_starpoint_soft_halo_shader_ready", false)),
		"soft halo shader resource must be marked ready after prewarm_assets()"
	)
	_expect(
		bool(status.get("common_starpoint_soft_halo_texture_ready", false)),
		"soft halo falloff texture must be created during prewarm_assets()"
	)


func _verify_pipeline_status_keys() -> void:
	var status: Dictionary = CommonStarpointVisualHost.build_pipeline_status()
	for required_key in [
		"common_starpoint_drop_shader_ready",
		"common_starpoint_drop_max_slots",
		"common_starpoint_drop_white_texture_ready",
		"common_starpoint_soft_halo_shader_ready",
		"common_starpoint_soft_halo_texture_ready",
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
	_expect(
		host_source.find("res://shaders/playfield/starpoint_soft_halo.gdshader") >= 0,
		"FX host must load the soft halo shader from res://shaders/playfield/ per repo convention"
	)
	var shader_source := FileAccess.get_file_as_string("res://shaders/playfield/starpoint_drop.gdshader")
	_expect(
		shader_source != "",
		"starpoint_drop.gdshader must be present at res://shaders/playfield/"
	)
	var halo_shader_source := FileAccess.get_file_as_string("res://shaders/playfield/starpoint_soft_halo.gdshader")
	_expect(
		halo_shader_source != "",
		"starpoint_soft_halo.gdshader must be present at res://shaders/playfield/"
	)
	for required_halo_uniform in [
		"halo_texture",
		"elapsed",
		"alpha",
		"glow_intensity",
		"spawn_scale",
		"halo_color",
		"sparkle_intensity",
		"iridescent_rim_intensity",
	]:
		_expect(
			halo_shader_source.find("uniform") >= 0 and halo_shader_source.find(required_halo_uniform) >= 0,
			"starpoint soft halo shader must declare uniform %s" % required_halo_uniform
		)
	for required_uniform in [
		"alpha",
		"glow_intensity",
		"rotation",
		"size_norm",
		"glow_color",
		"fill_color",
		"mid_color",
		"outline_color",
		"core_color",
		"detector_shimmer_intensity",
		"elapsed",
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
	_expect(
		shader_source.find("soul_flame_sdf") >= 0
			and shader_source.find("flame_profile_sdf") >= 0
			and shader_source.find("star_sdf") < 0,
		"compatibility shader must render the muhon soul-flame profile instead of a star SDF"
	)
	_expect(
		shader_source.find("vec2 side_q") >= 0
			and shader_source.find("detector_shimmer_intensity") >= 0,
		"muhon shader must keep a split crown and restrained detector-bonus contour"
	)
	_expect(
		shader_source.find("sparkle_ray_intensity") < 0
			and shader_source.find("star_tip_count") < 0,
		"muhon shader must remove old star-tip and lens-flare controls"
	)


func _verify_instance_slot_pool_and_gating() -> void:
	var host: Node2D = CommonStarpointVisualHost.new()
	get_root().add_child(host)
	await process_frame
	_expect(host._slot_count >= 16, "slot pool should be populated after _ready()")
	_expect(host._halo_slots.size() == host._slot_count, "soft halo slot pool should mirror the star slot pool")
	# sync_drop with zero life must hide the slot (no wasted GPU work).
	host.begin_frame()
	host.sync_drop({"pos": Vector2(40.0, 40.0), "size": 12.0, "life": 0.0})
	# Real drop with full life and the shared crimson muhon palette.
	host.sync_drop({
		"pos": Vector2(120.0, 40.0),
		"size": 12.0,
		"life": 255.0,
		"rotation": 0.42,
		"glow_intensity": 1.0,
		"star_detector_bonus": false,
		"glow_color": CommonStarpointVisualHost.MUHON_GLOW_COLOR,
		"fill_color": CommonStarpointVisualHost.MUHON_FILL_COLOR,
		"mid_color": CommonStarpointVisualHost.MUHON_MID_COLOR,
		"outline_color": CommonStarpointVisualHost.MUHON_OUTLINE_COLOR,
		"core_color": CommonStarpointVisualHost.MUHON_CORE_COLOR,
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
	_expect(
		host._halo_slots[1].visible,
		"positive-life sync_drop should leave the matching soft halo slot visible behind the star"
	)
	# end_frame must hide stale slots from previous frames.
	host.begin_frame()
	host.end_frame()
	for i in range(host._slot_count):
		_expect(
			not host._slots[i].visible,
			"end_frame() must hide all unclaimed slots so stale overlays don't render"
		)
		_expect(
			not host._halo_slots[i].visible,
			"end_frame() must hide all unclaimed soft halo slots so stale auras don't render"
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


func _verify_clear_helpers_hide_visible_slots() -> void:
	var fake_canvas := Node2D.new()
	get_root().add_child(fake_canvas)
	var host: Node2D = CommonStarpointVisualHost.get_or_create_on_canvas(fake_canvas) as Node2D
	await process_frame
	_make_visible_drop(host)
	_expect(_has_visible_drop_slot(host), "test setup should leave a visible starpoint slot")
	CommonStarpointVisualHost.hide_on_canvas(fake_canvas)
	_expect(not _has_visible_drop_slot(host), "hide_on_canvas() must hide stale starpoint slots without creating a new frame")
	_expect(not bool(host.visible), "hide_on_canvas() should hide the host node after clearing slots")
	_make_visible_drop(host)
	_expect(_has_visible_drop_slot(host), "test setup should restore a visible starpoint slot")
	CommonStarpointVisualHost.hide_all_existing_hosts()
	_expect(not _has_visible_drop_slot(host), "hide_all_existing_hosts() must clear modal/stage-transition stale slots")
	fake_canvas.queue_free()


func _make_visible_drop(host: Node2D) -> void:
	host.begin_frame()
	host.sync_drop({
		"pos": Vector2(96.0, 72.0),
		"size": 12.0,
		"life": 255.0,
	})
	host.end_frame()


func _has_visible_drop_slot(host: Node2D) -> bool:
	for slot in host._slots:
		if slot != null and bool(slot.visible):
			return true
	for halo_slot in host._halo_slots:
		if halo_slot != null and bool(halo_slot.visible):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
