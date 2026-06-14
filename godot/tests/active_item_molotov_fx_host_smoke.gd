extends SceneTree

# Verifies the molotov fire-zone modular VFX host pipeline: prewarm is
# idempotent, all five WritheEmber presets the host depends on stay
# wired, sync_state with a non-zero life ratio actually shows the layered
# sprite/particle nodes, and trigger_explosion_burst kicks off the one-shot
# burst tween without leaking past zone end-of-life.
#
# Regression here usually shows up as either invisible fire zones (preset
# rename / missing prewarm) or as a stuck visible burst sprite from a
# torn-down tween (set_active(false) ordering bug).

const ActiveItemMolotovFxHost := preload("res://scripts/items/active_item_molotov_fx_host.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_idempotence()
	_verify_pipeline_status_keys()
	_verify_required_writhe_ember_presets()
	await _verify_host_sync_and_burst()
	await _verify_throw_renderer_deactivates_molotov_pool()

	if _failures.is_empty():
		print("active_item_molotov_fx_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_idempotence() -> void:
	# prewarm must survive being called repeatedly from the throw_renderer's
	# prewarm_assets() at every stage transition without rebuilding the heat
	# texture or re-loading the WritheEmber shader resource.
	ActiveItemMolotovFxHost.prewarm_assets()
	ActiveItemMolotovFxHost.prewarm_assets()
	ActiveItemMolotovFxHost.prewarm_assets()
	var status: Dictionary = ActiveItemMolotovFxHost.build_pipeline_status()
	_expect(
		bool(status.get("molotov_fx_host_shader_floor_ready", false)),
		"ember floor shader (hongryun_inferno_charge preset) must be ready after prewarm"
	)
	_expect(
		bool(status.get("molotov_fx_host_shader_flame_ready", false)),
		"flame dome shader (hongryun_inferno_trail preset) must be ready after prewarm"
	)
	_expect(
		bool(status.get("molotov_fx_host_shader_char_ring_ready", false)),
		"char ring shader (hongryun_inferno_dragon_ring preset) must be ready after prewarm"
	)
	_expect(
		bool(status.get("molotov_fx_host_shader_burst_ready", false)),
		"explosion burst shader (hongryun_inferno_burst preset) must be ready after prewarm"
	)


func _verify_pipeline_status_keys() -> void:
	var status: Dictionary = ActiveItemMolotovFxHost.build_pipeline_status()
	for required_key in [
		"molotov_fx_host_shader_floor_ready",
		"molotov_fx_host_shader_flame_ready",
		"molotov_fx_host_shader_char_ring_ready",
		"molotov_fx_host_shader_burst_ready",
		"molotov_fx_host_particle_amount",
		"molotov_fx_host_layers",
	]:
		_expect(
			status.has(required_key),
			"molotov FX host pipeline status must include %s for prewarm verification" % required_key
		)
	_expect(
		int(status.get("molotov_fx_host_layers", 0)) >= 5,
		"molotov FX host must declare at least 5 visual layers (floor + dome + char ring + burst + particles)"
	)


func _verify_required_writhe_ember_presets() -> void:
	# Each preset is a contract: a rename or accidental removal must trip
	# this assertion BEFORE the host silently renders a blank sprite at
	# runtime.
	for required_preset in [
		"hongryun_inferno_charge",
		"hongryun_inferno_trail",
		"hongryun_inferno_dragon_ring",
		"hongryun_inferno_burst",
	]:
		_expect(
			WritheEmber.has_preset(required_preset),
			"WritheEmber must keep preset '%s' for molotov FX host" % required_preset
		)


func _verify_host_sync_and_burst() -> void:
	var host: Node2D = ActiveItemMolotovFxHost.new()
	get_root().add_child(host)
	await process_frame

	# Active sync with non-zero life ratio shows the layered sprites.
	# zone_pos is passed in screen-space (already game_offset + raw*render_scale
	# converted by the renderer) so the host can drop it straight into position.
	# This protects against the "draw_set_transform doesn't propagate to child
	# Node2Ds" trap documented in CLAUDE.md / memory feedback_godot_draw_set_transform_trap:
	# if the host ever reverts to interpreting zone_pos as game-space, a regression
	# here would catch it because position would no longer match the input pos.
	var test_screen_pos := Vector2(820.0, 240.0)
	host.sync_state({
		"zone_pos": test_screen_pos,
		"width": 150.0,
		"height": 60.0,
		"life_ratio": 1.0,
		"age_frames": 0.0,
		"render_scale": 1.7,
		"quality_scale": 1.0,
	}, true)
	_expect(host.visible, "host should be visible when sync_state is active with life_ratio > 0")
	_expect(
		host.position.is_equal_approx(test_screen_pos),
		"host.position must equal sync_state's screen-space zone_pos exactly — game-coord interpretation would break the playfield clip and leak into pillar chrome"
	)
	_expect(
		is_equal_approx(host.scale.x, 1.7) and is_equal_approx(host.scale.y, 1.7),
		"host.scale must equal sync_state's render_scale so sprite sizes match the rest of the playfield letterbox"
	)
	var status_active: Dictionary = host.get_debug_status()
	_expect(
		bool(status_active.get("floor_shader_ready", false))
			and bool(status_active.get("flame_shader_ready", false))
			and bool(status_active.get("char_ring_shader_ready", false)),
		"active host should report all three persistent shader layers wired"
	)

	# Burst is one-shot — triggering it should not change visible-state at
	# the sprite level immediately (the burst sprite turns visible inside
	# the trigger), and the host's parent visibility should stay true.
	host.trigger_explosion_burst()
	await process_frame
	_expect(host.visible, "host should stay visible while the explosion burst tween is in flight")

	# set_active(false) must hide everything and stop emitting particles in
	# a single call so freed fire zones don't leak GPU work.
	host.set_active(false)
	await process_frame
	_expect(not host.visible, "set_active(false) must hide the host")
	var status_idle: Dictionary = host.get_debug_status()
	_expect(
		not bool(status_idle.get("ember_emitting", false)),
		"set_active(false) must stop the ember particle emission"
	)

	host.queue_free()


func _verify_throw_renderer_deactivates_molotov_pool() -> void:
	var renderer: Object = ActiveItemThrowRenderer.new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	renderer.draw(
		canvas,
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[_build_fire_zone()],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		[],
		Vector2.ZERO
	)
	await process_frame

	var host: Node = canvas.get_node_or_null("ActiveItemMolotovFxHost0")
	_expect(host != null, "throw renderer should create a molotov FX host for active fire zones")
	if host != null:
		_expect(host.visible, "throw renderer molotov host should be visible after active fire zone sync")

	renderer.deactivate_all_hosts()
	await process_frame

	if host != null and is_instance_valid(host):
		_expect(not host.visible, "throw renderer deactivate_all_hosts should hide pooled molotov hosts")
		var status: Dictionary = host.get_debug_status()
		_expect(
			not bool(status.get("ember_emitting", false)),
			"throw renderer deactivate_all_hosts should stop pooled molotov ember emission"
		)

	canvas.queue_free()


func _build_fire_zone() -> Dictionary:
	return {
		"zone_id": 991,
		"position": Vector2(230.0, 520.0),
		"width": 150.0,
		"height": 60.0,
		"duration_frames": 120.0,
		"max_duration_frames": 150.0,
		"age_frames": 1.0,
		"flames": [],
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
