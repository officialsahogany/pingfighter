extends SceneTree

# Verifies the dash token boost FX host's prewarm + slot pool + intensity gating
# behaviour. The host is the GPU shader overlay that replaced three CPU draw
# paths on the dash orb (rainbow refund ring, sector boost, half-ready blink).
# A regression here usually shows up as either invisible boost overlays or as a
# first-frame PSO compile hitch when a player earns their first boost charge.

const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_idempotence()
	_verify_pipeline_status_keys()
	_verify_shader_resource_path()
	await _verify_instance_slot_pool_and_gating()

	if _failures.is_empty():
		print("dash_token_boost_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_idempotence() -> void:
	# prewarm_assets() must be safe to call repeatedly across stage transitions,
	# warmup retries, and from both the resource prewarm controller AND the PSO
	# prewarmer without re-loading shader resources or rebuilding textures.
	DashTokenBoostFxHost.prewarm_assets()
	DashTokenBoostFxHost.prewarm_assets()
	DashTokenBoostFxHost.prewarm_assets()
	var status: Dictionary = DashTokenBoostFxHost.build_pipeline_status()
	_expect(
		bool(status.get("dash_token_boost_ring_shader_ready", false)),
		"shader resource must be marked ready after prewarm_assets()"
	)
	_expect(
		bool(status.get("dash_token_boost_ring_white_texture_ready", false)),
		"shared white texture must be created during prewarm_assets()"
	)


func _verify_pipeline_status_keys() -> void:
	var status: Dictionary = DashTokenBoostFxHost.build_pipeline_status()
	for required_key in [
		"dash_token_boost_ring_shader_ready",
		"dash_token_boost_ring_max_slots",
		"dash_token_boost_ring_white_texture_ready",
	]:
		_expect(
			status.has(required_key),
			"pipeline status must include %s for prewarm verification" % required_key
		)
	_expect(
		int(status.get("dash_token_boost_ring_max_slots", 0)) >= 2,
		"slot pool must hold at least 2 slots (player + boss dash)"
	)


func _verify_shader_resource_path() -> void:
	# Pinning the shader path catches accidental renames or relocations into
	# `godot/assets/shaders/` that would break the repo convention.
	var source := FileAccess.get_file_as_string("res://scripts/hud/dash_token_boost_fx_host.gd")
	_expect(
		source.find("res://shaders/hud/dash_token_boost_ring.gdshader") >= 0,
		"FX host must load the shader from res://shaders/hud/ per repo convention"
	)
	var shader_source := FileAccess.get_file_as_string("res://shaders/hud/dash_token_boost_ring.gdshader")
	_expect(
		shader_source != "",
		"dash_token_boost_ring.gdshader must be present at res://shaders/hud/"
	)
	# Every uniform that the FX host writes must exist in the shader, otherwise
	# set_shader_parameter() silently no-ops and the boost overlay renders blank.
	for required_uniform in [
		"sector_intensity",
		"sector_progress",
		"sector_start_angle",
		"sector_end_angle",
		"rainbow_intensity",
		"rainbow_rotation",
		"half_ready_intensity",
		"plasma_ball_intensity",
		"plasma_core_color",
		"plasma_tendril_color",
		"plasma_tendril_count",
		"orb_radius_norm",
		"outer_extent_norm",
		"elapsed",
	]:
		_expect(
			shader_source.find("uniform") >= 0 and shader_source.find(required_uniform) >= 0,
			"dash_token_boost_ring shader must declare uniform %s" % required_uniform
		)
	# Plasma ball replaces the old CPU recovery lock effect; the fragment must
	# include both the central core falloff and the tendril for loop so the
	# look stays "electric ball" rather than "sparse sticks".
	_expect(
		shader_source.find("plasma_ball_intensity > 0.001") >= 0,
		"dash_token_boost_ring shader must gate the plasma ball block on plasma_ball_intensity"
	)
	_expect(
		shader_source.find("plasma_tendril_count") >= 0
			and shader_source.find("for (int i = 0; i < 8;") >= 0,
		"plasma ball block must iterate over plasma_tendril_count tendrils"
	)


func _verify_instance_slot_pool_and_gating() -> void:
	var host: Node2D = DashTokenBoostFxHost.new()
	get_root().add_child(host)
	await process_frame
	# Slot pool should be ready after _ready()
	_expect(host._slot_count >= 2, "slot pool should be populated after _ready()")
	# sync_slot with all intensities at 0 must hide that slot (no zero-cost waste)
	host.begin_frame()
	host.sync_slot(Vector2(40.0, 40.0), 38.0, 1.0, {
		"sector_intensity": 0.0,
		"rainbow_intensity": 0.0,
		"half_ready_intensity": 0.0,
	})
	# Real boost state - rainbow refund only
	host.sync_slot(Vector2(120.0, 40.0), 38.0, 1.0, {
		"elapsed": 1.0,
		"rainbow_intensity": 1.0,
	})
	host.end_frame()
	# Slot 0 was claimed but with zero intensity, so it must be hidden
	_expect(
		not host._slots[0].visible,
		"zero-intensity sync_slot should hide the slot to avoid pointless GPU work"
	)
	_expect(
		host._slots[1].visible,
		"non-zero intensity sync_slot should leave the slot visible for shader render"
	)
	# Slots beyond _frame_slot_index from previous frame must hide on end_frame
	host.begin_frame()
	host.end_frame()
	for i in range(host._slot_count):
		_expect(
			not host._slots[i].visible,
			"end_frame() must hide all unclaimed slots so stale overlays don't render"
		)
	host.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
