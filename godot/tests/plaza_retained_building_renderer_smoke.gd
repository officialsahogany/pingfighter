extends SceneTree

const PlazaBuildingRenderer := preload("res://scripts/plaza/plaza_building_renderer.gd")
const PlazaMapWorldHost := preload("res://scripts/plaza/plaza_map_world_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_delegation_contract()
	_verify_retained_building_lifecycle()
	_verify_world_host_fail_closed_lifecycle()
	if _failures.is_empty():
		print("plaza_retained_building_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_prewarm_delegation_contract() -> void:
	var manifest_paths: Array[String] = []
	_expect(
		not PlazaBuildingRenderer.prewarm_assets_step(manifest_paths, false, "empty_counterproof"),
		"an invalid empty manifest set must not silently report already warm"
	)
	var source_file := FileAccess.open("res://scripts/plaza/plaza_building_renderer.gd", FileAccess.READ)
	_expect(source_file != null, "renderer source should be readable for delegation ownership check")
	if source_file != null:
		var source := source_file.get_as_text()
		_expect(
			source.find("PlazaAssetLoader.prewarm_building_assets_step(") >= 0,
			"renderer should directly delegate prewarm work to PlazaAssetLoader"
		)
		_expect(
			source.find("has_method(\"prewarm_building_assets_step\")") < 0,
			"renderer must not turn missing dynamic delegation into a false warm result"
		)


func _verify_retained_building_lifecycle() -> void:
	var visual := PlazaBuildingRenderer.create_retained_visual()
	root.add_child(visual)
	var initial_status: Dictionary = visual.call("get_layer_status")
	_expect(not bool(initial_status.get("active", true)), "retained building should start inactive")
	_expect(not bool(initial_status.get("process_enabled", true)), "retained building should be sync-only")

	var texture := _make_texture()
	var spec := {
		"type": "bank",
		"visual_rect": Rect2(10.0, 20.0, 80.0, 100.0),
		"pivot_pos": Vector2(50.0, 100.0),
		"base_texture": texture,
		"sign_texture": texture,
		"window_texture": texture,
		"sign_glow_color": Color(1.0, 0.6, 0.2, 1.0),
		"window_glow_color": Color(0.2, 1.0, 0.8, 1.0),
	}
	_expect(bool(visual.call("sync_state", spec, 0.0, 200.0, 100.0, 1.0, 1000)), "valid retained building sync should activate")
	var active_status: Dictionary = visual.call("get_layer_status")
	_expect(bool(active_status.get("active", false)), "valid retained building should be active")
	_expect(bool(active_status.get("base_visible", false)), "base layer should be visible")
	_expect(bool(active_status.get("sign_visible", false)), "sign layer should be visible")
	_expect(bool(active_status.get("window_visible", false)), "window layer should be visible")
	_expect(bool(active_status.get("all_layer_z_zero", false)), "retained layers must not climb above the relative z=-1 host")
	_expect(
		int(active_status.get("base_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX,
		"base layer should own a MIX material"
	)
	_expect(
		int(active_status.get("sign_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD,
		"sign layer should own an ADD material"
	)
	_expect(
		int(active_status.get("window_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD,
		"window layer should own an ADD material"
	)
	_expect(
		int(active_status.get("base_bound_material_id", 0)) == int(active_status.get("base_material_id", -1))
		and int(active_status.get("base_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX,
		"base Sprite2D should bind the renderer-owned MIX material"
	)
	_expect(
		int(active_status.get("sign_bound_material_id", 0)) == int(active_status.get("sign_material_id", -1))
		and int(active_status.get("sign_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD,
		"sign Sprite2D should bind the renderer-owned ADD material"
	)
	_expect(
		int(active_status.get("window_bound_material_id", 0)) == int(active_status.get("window_material_id", -1))
		and int(active_status.get("window_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD,
		"window Sprite2D should bind the renderer-owned ADD material"
	)
	_expect(active_status.get("base_texture_size", Vector2.ZERO) == Vector2(4.0, 4.0), "retained base should report its bound runtime texture size")
	_expect(active_status.get("base_position", Vector2.ZERO) == Vector2(10.0, 20.0), "retained base should map to the projected rect origin")
	_expect(active_status.get("base_scale", Vector2.ZERO) == Vector2(20.0, 25.0), "retained base should scale from texture pixels to the projected rect")
	_expect(active_status.get("base_render_rect", Rect2()) == Rect2(10.0, 20.0, 80.0, 100.0), "retained base render rect should equal the requested visual rect")
	_expect(active_status.get("sign_render_rect", Rect2()) == active_status.get("base_render_rect", Rect2()), "sign mask should remain registered to the base rect")
	_expect(active_status.get("window_render_rect", Rect2()) == active_status.get("base_render_rect", Rect2()), "window mask should remain registered to the base rect")
	var material_ids := {
		int(active_status.get("base_material_id", 0)): true,
		int(active_status.get("sign_material_id", 0)): true,
		int(active_status.get("window_material_id", 0)): true,
	}
	_expect(material_ids.size() == 3 and not material_ids.has(0), "each retained layer should own a distinct material")

	_expect(not bool(visual.call("sync_state", spec, 0.0, 1.0, 100.0, 1.0, 1000)), "degenerate viewport should reject sync")
	_expect(not bool((visual.call("get_layer_status") as Dictionary).get("active", true)), "rejected sync should fail closed")
	visual.call("sync_state", spec, 0.0, 200.0, 100.0, 1.0, 1000)
	visual.call("clear_transient_canvas_items")
	_expect(not bool((visual.call("get_layer_status") as Dictionary).get("active", true)), "clear_transient_canvas_items should hide retained layers")
	visual.free()


func _verify_world_host_fail_closed_lifecycle() -> void:
	var host := PlazaMapWorldHost.new()
	root.add_child(host)
	var initial_status := host.get_debug_status()
	_expect(not bool(initial_status.get("active", true)), "map host should start inactive")
	_expect(not bool(initial_status.get("process_enabled", true)), "map host should be sync-only")
	_expect(int(initial_status.get("z_index", 0)) == -1, "map host should use the relative z=-1 slot")
	_expect(bool(initial_status.get("z_as_relative", false)), "map host z=-1 must remain relative to the plaza root")

	var texture := _make_texture()
	var valid_state := {
		"render_size": Vector2(200.0, 160.0),
		"game_size": Vector2(200.0, 160.0),
		"render_scale": 1.0,
		"render_background": false,
		"draw_opaque_fill": true,
		"ticks_msec": 1000,
		"building_baseline_y": 100.0,
		"building_specs": [{
			"type": "bank",
			"visual_rect": Rect2(10.0, 20.0, 80.0, 100.0),
			"pivot_pos": Vector2(50.0, 100.0),
			"base_texture": texture,
			"sign_texture": texture,
			"window_texture": texture,
		}],
	}
	var legacy_key_state := valid_state.duplicate(true)
	legacy_key_state["viewport_size"] = legacy_key_state["render_size"]
	_expect(not host.sync_state(legacy_key_state), "legacy viewport_size should reject even when render_size is also present")
	_expect(
		str(host.get_debug_status().get("last_sync_rejection_reason", "")) == "legacy_viewport_size_key",
		"legacy size-key rejection should be visible in debug state"
	)
	_expect(int(host.get_debug_status().get("successful_sync_count", -1)) == 0, "rejected legacy key should not count as a successful sync")
	_expect(host.sync_state(valid_state), "valid map-host sync should activate")
	var active_status := host.get_debug_status()
	_expect(bool(active_status.get("active", false)), "valid map host should be active")
	_expect(not bool(active_status.get("process_enabled", true)), "active map host should remain owner-sync driven")
	_expect(int(active_status.get("visible_building_count", 0)) == 1, "valid map host should expose one retained building")
	_expect(bool(active_status.get("all_building_z_zero", false)), "building visuals must remain on the host's relative z=-1 plane")
	_expect(int(active_status.get("successful_sync_count", 0)) == 1, "first valid state should count exactly one successful sync")
	_expect(int(active_status.get("last_synced_ticks_msec", -1)) == 1000, "first sync should record its explicit frame ticks")
	_expect(int(active_status.get("previous_synced_ticks_msec", 0)) == -1, "first sync should expose that no previous frame sample exists")
	_expect(not bool(active_status.get("ticks_advanced_on_last_sync", true)), "first tick sample should not claim an unobserved advance")
	_expect(not bool(active_status.get("frozen_ticks_detected", true)), "first sync should not report frozen ticks")
	var first_layer_statuses := host.get_building_layer_statuses()
	var first_sign_modulate: Color = first_layer_statuses[0].get("sign_modulate", Color.TRANSPARENT)
	var first_window_modulate: Color = first_layer_statuses[0].get("window_modulate", Color.TRANSPARENT)

	_expect(host.sync_state(valid_state), "a repeated tick fixture should still render for diagnosis")
	var frozen_tick_status := host.get_debug_status()
	_expect(bool(frozen_tick_status.get("frozen_ticks_detected", false)), "reusing one ticks_msec value should be detected as frozen")
	_expect(bool(frozen_tick_status.get("non_advancing_ticks_detected", false)), "repeated ticks should be reported as non-advancing without rejecting the sync")
	_expect(not bool(frozen_tick_status.get("ticks_advanced_on_last_sync", true)), "frozen tick sync should report no advance")
	_expect(int(frozen_tick_status.get("consecutive_non_advancing_tick_syncs", 0)) == 1, "one repeated tick should produce one non-advancing sync")
	_expect(int(frozen_tick_status.get("successful_sync_count", 0)) == 2, "frozen-tick diagnostic sync should still count as a completed render sync")
	var frozen_layer_statuses := host.get_building_layer_statuses()
	var frozen_sign_modulate: Color = frozen_layer_statuses[0].get("sign_modulate", Color.TRANSPARENT)
	var frozen_window_modulate: Color = frozen_layer_statuses[0].get("window_modulate", Color.TRANSPARENT)
	_expect(is_equal_approx(frozen_sign_modulate.a, first_sign_modulate.a), "same tick should preserve retained sign flicker alpha")
	_expect(is_equal_approx(frozen_window_modulate.a, first_window_modulate.a), "same tick should preserve retained window flicker alpha")

	var advanced_state := valid_state.duplicate(true)
	advanced_state["ticks_msec"] = 1022
	_expect(host.sync_state(advanced_state), "advanced render-frame ticks should restore a healthy sync")
	var advanced_tick_status := host.get_debug_status()
	_expect(bool(advanced_tick_status.get("ticks_advanced_on_last_sync", false)), "new render-frame ticks should be reported as advancing")
	_expect(not bool(advanced_tick_status.get("frozen_ticks_detected", true)), "new render-frame ticks should clear the frozen flag")
	_expect(int(advanced_tick_status.get("consecutive_non_advancing_tick_syncs", -1)) == 0, "new frame ticks should reset the stale-sync counter")
	_expect(int(advanced_tick_status.get("successful_sync_count", 0)) == 3, "different frame ticks should produce a third successful owner sync")
	var advanced_layer_statuses := host.get_building_layer_statuses()
	var advanced_sign_modulate: Color = advanced_layer_statuses[0].get("sign_modulate", Color.TRANSPARENT)
	var advanced_window_modulate: Color = advanced_layer_statuses[0].get("window_modulate", Color.TRANSPARENT)
	_expect(not is_equal_approx(advanced_sign_modulate.a, first_sign_modulate.a), "tick 1000 -> 1022 should update retained sign flicker alpha")
	_expect(not is_equal_approx(advanced_window_modulate.a, first_window_modulate.a), "tick 1000 -> 1022 should update retained window flicker alpha")

	var working_state := valid_state.duplicate(true)
	working_state["ticks_msec"] = 1034
	_expect(host.sync_state(working_state), "fresh render-frame state should reactivate fill and buildings")
	var degenerate_state := working_state.duplicate(true)
	degenerate_state["render_size"] = Vector2(1.0, 160.0)
	_expect(not host.sync_state(degenerate_state), "degenerate map-host size should reject sync")
	var degenerate_status := host.get_debug_status()
	_expect(not bool(degenerate_status.get("active", true)), "degenerate map-host sync should hide the host")
	_expect(int(degenerate_status.get("visible_building_count", -1)) == 0, "degenerate map-host sync should hide retained buildings")
	_expect(str(degenerate_status.get("last_sync_rejection_reason", "")) == "degenerate_render_size", "degenerate render_size rejection should be diagnosable")

	var missing_ticks_state := working_state.duplicate(true)
	missing_ticks_state.erase("ticks_msec")
	_expect(not host.sync_state(missing_ticks_state), "missing owner frame ticks should reject sync")
	_expect(str(host.get_debug_status().get("last_sync_rejection_reason", "")) == "missing_ticks_msec", "missing tick rejection should be diagnosable")
	var non_integer_ticks_state := working_state.duplicate(true)
	non_integer_ticks_state["ticks_msec"] = 1051.0
	_expect(not host.sync_state(non_integer_ticks_state), "non-integer owner frame ticks should reject sync")
	_expect(str(host.get_debug_status().get("last_sync_rejection_reason", "")) == "invalid_ticks_msec_type", "tick type rejection should be diagnosable")
	_expect(int(host.get_debug_status().get("successful_sync_count", 0)) == 4, "rejected syncs should not change the successful-sync count")

	working_state["ticks_msec"] = 1068
	host.sync_state(working_state)
	_expect(not host.sync_state(working_state, false), "inactive plaza/transition sync should reject activation")
	_expect(not bool(host.get_debug_status().get("active", true)), "plaza exit/interior gate should hide the retained host")
	working_state["ticks_msec"] = 1085
	host.sync_state(working_state)
	host.clear_transient_canvas_items()
	var cleared_status := host.get_debug_status()
	_expect(not bool(cleared_status.get("active", true)), "transient clear should hide the retained host")
	_expect(int(cleared_status.get("last_synced_ticks_msec", 0)) == -1, "transient clear should reset render-frame tick diagnostics")
	_expect(int(cleared_status.get("successful_sync_count", -1)) == 0, "transient clear should reset successful-sync diagnostics")
	host.free()


func _make_texture() -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
