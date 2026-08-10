extends SceneTree

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaWorldGeometry := preload("res://scripts/plaza/plaza_world_geometry.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")


class ExitSink:
	extends RefCounted

	var call_count := 0
	var scene: Control = null
	var host_status_at_callback: Dictionary = {}

	func finish() -> void:
		call_count += 1
		if scene != null and is_instance_valid(scene):
			host_status_at_callback = scene.call("get_map_world_host_status_for_test")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_production_owner_prewarm_route()
	await _verify_live_handler_route()
	if _failures.is_empty():
		print("plaza_hwangyeok_building_r1_production_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_production_owner_prewarm_route() -> void:
	ProjectResourceLoader.clear_caches()
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	var handler := StageClearResultPlazaSceneHandler.new()
	var prewarm_owner := Node2D.new()
	prewarm_owner.name = "HwangyeokPrewarmOwner"
	root.add_child(prewarm_owner)
	_expect(
		not handler.ensure_assets_ready(1, prewarm_owner),
		"Texture2D cache completion alone must not report production plaza spawn readiness"
	)
	var status := PlazaScene.get_prewarm_asset_status()
	var building_status_value: Variant = status.get("hwangyeok_building_status", {})
	var building_status: Dictionary = building_status_value as Dictionary if building_status_value is Dictionary else {}
	_expect(bool(status.get("complete", false)), "composed plaza prewarm status should require both base and building assets")
	_expect(bool(building_status.get("complete", false)), "top-owner prewarm should complete the retained building set")
	_expect(int(building_status.get("expected_path_count", 0)) == 21, "top-owner prewarm should delegate all 7 x 3 retained layers")
	_expect(int(building_status.get("path_count", 0)) == 21, "top-owner prewarm should discover exactly 21 retained layer paths")
	for path in PlazaAssetLoader.get_hwangyeok_building_prewarm_texture_paths():
		_expect(bool(building_status.get(path, false)), "top-owner prewarm should load %s" % path)
		_expect(ProjectResourceLoader.get_cached_texture(path) != null, "production prewarm should populate the shared texture cache for %s" % path)
	_expect(
		not handler.spawn_scene(prewarm_owner, {"current_stage": 1}, Callable()),
		"production handler must reject a cache-only plaza spawn before the retained GPU draw"
	)
	handler.prewarm_assets_step(1, prewarm_owner)
	await process_frame
	var gpu_prewarmer := prewarm_owner.get_node_or_null(BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME)
	_expect(gpu_prewarmer != null, "production prewarm owner should attach the Hwangyeok-only BattlePsoPrewarmer")
	if gpu_prewarmer != null:
		gpu_prewarmer.call("_process", 0.0)
		var instance_status: Dictionary = gpu_prewarmer.call("get_hwangyeok_instance_status")
		_expect(bool(instance_status.get("retained_draw_issued", false)), "headless state leg should issue the real retained 7x3 draw setup")
		_expect(int(instance_status.get("drawn_layer_count", 0)) == 21, "headless state leg should bind all 21 retained layers before simulating render flush")
		_expect(instance_status.get("render_target_size", Vector2.ZERO) == Vector2(512.0, 512.0), "GPU prewarm should own a bounded 512px SubViewport independent of the offscreen parent transform")
		_expect(int(instance_status.get("in_bounds_layer_count", 0)) == 21, "all 21 retained layers must lie inside the GPU prewarm render target")
		# Headless wrappers do not emit a reliable RenderingServer.frame_post_draw.
		# The real Vulkan QA awaits the signal; this state smoke advances only the
		# already-issued node's completion callback to test the owner gate.
		var existing_flushes := int(instance_status.get("post_draw_flush_count", 0))
		for _flush_idx in range(existing_flushes, BattlePsoPrewarmer.POST_WARMUP_FLUSH_FRAMES):
			gpu_prewarmer.call("_on_hwangyeok_frame_post_draw")
	await process_frame
	var gpu_status := BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status()
	_expect(bool(gpu_status.get("complete", false)), "actual BattlePsoPrewarmer retained draw should complete the GPU readiness seal")
	_expect(int(gpu_status.get("drawn_layer_count", 0)) == 21, "GPU prewarm should render all 7 x 3 retained building layers")
	_expect(int(gpu_status.get("post_draw_flush_count", 0)) >= 2, "GPU prewarm should cross at least two frame_post_draw flushes")
	_expect(int(gpu_status.get("in_bounds_layer_count", 0)) == 21, "GPU seal should preserve proof that every layer was inside the SubViewport")
	_expect(int(gpu_status.get("sealed_texture_count", 0)) == 21, "GPU seal should bind all 21 cached Texture2D instance identities")
	_expect(bool(gpu_status.get("texture_identity_match", false)), "GPU seal should match the currently cached Texture2D instances")

	# Counterproof: a process-global bool is insufficient because cache reset or
	# reload can replace the Texture2D RIDs after the old offscreen draw. The
	# seal must invalidate immediately, then require the replacement identities
	# to pass through another real retained draw setup.
	ProjectResourceLoader.clear_caches()
	_expect(not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete(), "clearing the sealed Texture2D cache must invalidate prior GPU readiness")
	var drift_status := BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status()
	_expect(str(drift_status.get("last_rejection_reason", "")) == "sealed_texture_identity_drift", "identity drift should expose an actionable spawn rejection reason")
	PlazaScene.reset_prewarm_assets_for_test()
	handler.reset()
	_expect(not handler.ensure_assets_ready(1, prewarm_owner), "replacement Texture2D identities must remain gated before their retained draw")
	await process_frame
	gpu_prewarmer = prewarm_owner.get_node_or_null(BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME)
	_expect(gpu_prewarmer != null, "identity replacement should attach a fresh Hwangyeok GPU prewarmer")
	if gpu_prewarmer != null:
		gpu_prewarmer.call("_process", 0.0)
		var replacement_status: Dictionary = gpu_prewarmer.call("get_hwangyeok_instance_status")
		for _flush_idx in range(
			int(replacement_status.get("post_draw_flush_count", 0)),
			BattlePsoPrewarmer.POST_WARMUP_FLUSH_FRAMES
		):
			gpu_prewarmer.call("_on_hwangyeok_frame_post_draw")
	await process_frame
	_expect(BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete(), "replacement Texture2D identities should become ready only after the second retained draw seal")
	_expect(handler.ensure_assets_ready(1, prewarm_owner), "completed production handler prewarm should remain idempotent")
	prewarm_owner.queue_free()
	await process_frame


func _verify_live_handler_route() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var owner := Control.new()
	owner.name = "ProductionOwner"
	viewport.add_child(owner)

	var sink := ExitSink.new()
	var handler := StageClearResultPlazaSceneHandler.new()
	var spawned := handler.spawn_scene(
		owner,
		{
			"current_stage": 1,
			"map_seed": 918273,
			"full_layout_for_test": true,
		},
		Callable(sink, "finish")
	)
	_expect(spawned, "production stage-clear plaza handler should spawn the live plaza scene")
	var scene := owner.get_node_or_null("PlazaScene") as Control
	_expect(scene != null, "production handler should attach PlazaScene to its real owner")
	if scene == null:
		viewport.free()
		return
	var expected_scene_rect := PlazaWorldGeometry.fit_game_rect(Vector2(1280.0, 720.0), Vector2(760.0, 750.0))
	_expect(scene.position.is_equal_approx(expected_scene_rect.position), "live plaza root should use the fitted local offset, not the raw viewport origin")
	_expect(scene.size.is_equal_approx(expected_scene_rect.size), "live plaza root should use its fitted render_size contract")
	_expect(not scene.size.is_equal_approx(Vector2(1280.0, 720.0)), "wide viewport fixture must distinguish root-local render_size from viewport size")

	scene.call("set_map_world_ticks_msec_for_test", 1000)
	handler.update(1.0 / 60.0)
	var host := scene.get_node_or_null("PlazaMapWorldHost") as Control
	_expect(host != null, "live PlazaScene should own the retained PlazaMapWorldHost")
	_expect(scene.z_index == 1200, "production handler should retain the plaza root z=1200 contract")
	if host != null:
		_expect(host.get_parent() == scene, "retained world host should be a direct child of the live plaza root")
		_expect(host.z_as_relative, "retained world host z=-1 must remain relative")
		_expect(host.z_index == -1, "retained world host should stay one plane below root actors/UI")
		_expect(not host.is_processing(), "retained world host should stay sync-driven with process disabled")
		_expect(host.position.is_equal_approx(Vector2.ZERO), "retained world host should remain plaza-root local")
		_expect(host.size.is_equal_approx(scene.size), "retained world host should receive plaza_scene.size as render_size")
		_expect(not host.size.is_equal_approx(Vector2(viewport.size)), "retained world host must not consume the engine viewport size")

	var scene_status: Dictionary = scene.call("get_status")
	var expected_world_size := Vector2(2400.0, 1500.0)
	var expected_exit_zone := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
	_expect(PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE == expected_world_size, "loader should own the exact promoted 2400 x 1500 map-world contract")
	_expect(scene_status.get("world_size", Vector2.ZERO) == expected_world_size, "live plaza should publish the exact promoted 2400 x 1500 map-world contract")
	var specs: Array[Dictionary] = scene.call("get_building_specs_for_test")
	_expect(specs.size() == 7, "full-layout production scene should build all seven retained buildings")
	var exit_zone: Rect2 = scene_status.get("exit_zone", Rect2())
	_expect(exit_zone == expected_exit_zone, "R1 MAP_SIZE promotion should place the live exit at the exact 2400-world edge contract")
	PlazaAssetLoader.invalidate_hwangyeok_building_specs_cache()
	var rebuilt_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 918273, true, false)
	_expect(rebuilt_specs.size() == specs.size(), "fixed-width rebuild should preserve the saved-seed building count")
	for spec_index in range(mini(specs.size(), rebuilt_specs.size())):
		_expect(str(rebuilt_specs[spec_index].get("type", "")) == str(specs[spec_index].get("type", "")), "fixed 2400 rebuild should preserve saved-seed building order")
		var rebuilt_pivot: Vector2 = rebuilt_specs[spec_index].get("pivot_pos", Vector2.ZERO)
		var live_pivot: Vector2 = specs[spec_index].get("pivot_pos", Vector2.ZERO)
		_expect(rebuilt_pivot.is_equal_approx(live_pivot), "fixed 2400 rebuild should reproduce saved-seed building positions")
	for spec in specs:
		_expect(str(spec.get("asset_set_id", "")) == PlazaAssetLoader.HWANGYEOK_BUILDING_ASSET_SET_ID, "%s should use the active Hwangyeok asset set" % str(spec.get("type", "building")))
		_expect(
			scene.call("_get_minimap_building_color", str(spec.get("type", ""))) == spec.get("window_glow_color", Color.TRANSPARENT),
			"%s interior accent should consume the same manifest color as retained windows and the minimap" % str(spec.get("type", "building"))
		)
		var source_size: Vector2 = spec.get("source_size", Vector2.ZERO)
		var display_scale := float(spec.get("display_scale", 0.0))
		var visual_rect: Rect2 = spec.get("visual_rect", Rect2())
		_expect(visual_rect.size.is_equal_approx(source_size * display_scale), "%s should preserve source-space geometry while drawing its 512px runtime texture" % str(spec.get("type", "building")))
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		_expect(interaction_rect.position.x >= 0.0 and interaction_rect.end.x < exit_zone.position.x, "%s interaction should remain reachable before the 2400-world exit" % str(spec.get("type", "building")))
		var manifest := PlazaAssetLoader.load_manifest(str(spec.get("manifest_path", "")))
		var layers_value: Variant = manifest.get("layers", {})
		var layers: Dictionary = layers_value as Dictionary if layers_value is Dictionary else {}
		for binding in [["base", "base_texture"], ["sign_emissive", "sign_texture"], ["window_glow_mask", "window_texture"]]:
			var layer_value: Variant = layers.get(str(binding[0]), {})
			var layer: Dictionary = layer_value as Dictionary if layer_value is Dictionary else {}
			var path := str(layer.get("res_path", ""))
			var cached := ProjectResourceLoader.get_cached_texture(path)
			var bound_value: Variant = spec.get(str(binding[1]), null)
			_expect(cached != null and bound_value is Texture2D and (bound_value as Texture2D).get_instance_id() == cached.get_instance_id(), "%s %s should reuse the production-prewarmed texture object" % [str(spec.get("type", "building")), str(binding[0])])

	var ground_y := float(scene_status.get("ground_y", 0.0))
	scene.call("set_player_pos_for_test", Vector2(exit_zone.get_center().x, ground_y))
	var exit_reach_status: Dictionary = scene.call("get_status")
	var exit_reach_player_pos: Vector2 = exit_reach_status.get("player_pos", Vector2.ZERO)
	_expect(exit_zone.has_point(exit_reach_player_pos), "promoted 2400-world exit should remain reachable on the live player ground line")
	_expect(is_equal_approx(float(exit_reach_status.get("camera_x", -1.0)), 1640.0), "promoted 2400-world exit should drive the live one-axis camera to its exact right clamp")
	scene.call("set_player_pos_for_test", Vector2(120.0, ground_y))

	var first_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
	_expect(bool(first_host_status.get("attached", false)), "live owner status should report the actual host attachment")
	_expect(bool(first_host_status.get("active", false)), "valid live street sync should activate the retained world")
	_expect(bool(first_host_status.get("visible", false)), "valid live street sync should show the retained world")
	_expect(int(first_host_status.get("last_synced_ticks_msec", -1)) == 1000, "live owner should forward its sampled frame tick")
	var first_layers: Array[Dictionary] = scene.call("get_map_world_layer_statuses_for_test")
	var first_active := _first_active_layer(first_layers)
	_expect(not first_active.is_empty(), "live owner sync should activate at least one on-screen retained building")

	# Retained nodes do not inherit PlazaScene's immediate-mode quiet early
	# return. Drive a genuinely degenerate viewport through the handler owner,
	# then restore the wide viewport and require the same route to reactivate it.
	var live_scene_size := scene.size
	scene.size = Vector2.ONE
	scene.queue_redraw()
	scene.call("_draw")
	var degenerate_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
	_expect(not bool(degenerate_host_status.get("active", true)), "1x1 production viewport should fail-close the retained world")
	_expect(not bool(degenerate_host_status.get("visible", true)), "degenerate production projection must not leave retained ghosts")
	scene.size = live_scene_size
	scene.call("set_map_world_ticks_msec_for_test", 1012)
	handler.update(1.0 / 60.0)
	var restored_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
	_expect(bool(restored_host_status.get("active", false)), "restoring the wide production viewport should reactivate retained buildings through handler.update")
	_expect(bool(restored_host_status.get("visible", false)), "restored production projection should show the retained world again")

	scene.call("set_map_world_ticks_msec_for_test", 1022)
	handler.update(1.0 / 60.0)
	var second_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
	var second_layers: Array[Dictionary] = scene.call("get_map_world_layer_statuses_for_test")
	var second_active := _first_active_layer(second_layers)
	_expect(int(second_host_status.get("successful_sync_count", 0)) == int(restored_host_status.get("successful_sync_count", 0)) + 1, "each valid production handler update should perform one retained-world sync")
	_expect(int(second_host_status.get("previous_synced_ticks_msec", -1)) == 1012, "retained host should retain the restored production-owner tick")
	_expect(int(second_host_status.get("last_synced_ticks_msec", -1)) == 1022, "retained host should receive the next production-owner tick")
	_expect(bool(second_host_status.get("ticks_advanced_on_last_sync", false)), "different rendered-frame samples should diagnose an advancing tick")
	var live_camera_x := float((scene.call("get_status") as Dictionary).get("camera_x", 0.0))
	var live_render_scale := scene.size.x / 760.0
	for layer_index in range(second_layers.size()):
		var layer_status: Dictionary = second_layers[layer_index]
		if bool(layer_status.get("active", false)):
			_expect(int(layer_status.get("last_synced_ticks_msec", -1)) == 1022, "every visible retained child should consume the owner's current frame tick")
			var expected_render_rect := PlazaWorldGeometry.world_rect_to_local(
				specs[layer_index].get("visual_rect", Rect2()),
				live_camera_x,
				live_render_scale
			)
			_expect((layer_status.get("base_render_rect", Rect2()) as Rect2).is_equal_approx(expected_render_rect), "512px retained base should project back to its source-authored world visual rect")
	if not first_active.is_empty() and not second_active.is_empty():
		var first_alpha := (first_active.get("window_modulate", Color.TRANSPARENT) as Color).a
		var second_alpha := (second_active.get("window_modulate", Color.TRANSPARENT) as Color).a
		_expect(not is_equal_approx(first_alpha, second_alpha), "production ticks should propagate into actual retained glow modulation")

	scene.call("set_map_world_glow_strength_for_test", 0.0)
	scene.call("set_map_world_ticks_msec_for_test", 1044)
	handler.update(1.0 / 60.0)
	var glow_off := _first_active_layer(scene.call("get_map_world_layer_statuses_for_test"))
	_expect(not glow_off.is_empty() and is_zero_approx((glow_off.get("sign_modulate", Color.TRANSPARENT) as Color).a), "owner-path glow fixture should drive retained sign alpha to zero")
	_expect(not glow_off.is_empty() and is_zero_approx((glow_off.get("window_modulate", Color.TRANSPARENT) as Color).a), "owner-path glow fixture should drive retained window alpha to zero")
	scene.call("set_map_world_glow_strength_for_test", 1.0)
	scene.call("set_map_world_ticks_msec_for_test", 1066)
	handler.update(1.0 / 60.0)
	var glow_on := _first_active_layer(scene.call("get_map_world_layer_statuses_for_test"))
	_expect(not glow_on.is_empty() and (glow_on.get("sign_modulate", Color.TRANSPARENT) as Color).a > 0.0, "owner-path glow fixture should re-enable the retained ADD sign layer")
	_expect(not glow_on.is_empty() and (glow_on.get("window_modulate", Color.TRANSPARENT) as Color).a > 0.0, "owner-path glow fixture should re-enable the retained ADD window layer")
	if not glow_on.is_empty():
		_expect(int(glow_on.get("base_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX, "live retained base should own a MIX material")
		_expect(int(glow_on.get("sign_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "live retained sign should own an ADD material")
		_expect(int(glow_on.get("window_bound_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "live retained window should own an ADD material")
		_expect(glow_on.get("base_texture_size", Vector2.ZERO) == Vector2(512.0, 512.0), "active base should bind the 512px runtime texture")
		_expect(glow_on.get("sign_texture_size", Vector2.ZERO) == Vector2(512.0, 512.0), "active sign should bind the 512px runtime mask")
		_expect(glow_on.get("window_texture_size", Vector2.ZERO) == Vector2(512.0, 512.0), "active window should bind the 512px runtime mask")

	# Positioning is a fixture hook; discovery still goes through the real
	# PlazaWorldGeometry interaction path for every production spec.
	for spec in specs:
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		scene.call("set_player_pos_for_test", interaction_rect.get_center())
		var reachable_status: Dictionary = scene.call("get_status")
		_expect(str(reachable_status.get("interactable_building_type", "")) == str(spec.get("type", "")), "%s should be reachable through the live player interaction contract" % str(spec.get("type", "building")))

	var bank := _find_spec(specs, "bank")
	_expect(not bank.is_empty(), "full-layout live scene should expose the bank for lifecycle testing")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		scene.call("set_player_pos_for_test", interaction_rect.get_center())
		handler.update(1.0 / 60.0)
		var enter := InputEventKey.new()
		enter.pressed = true
		enter.keycode = KEY_ENTER
		handler.handle_input(enter)
		handler.update(10.0)
		_expect(bool((scene.call("get_status") as Dictionary).get("interior_view_active", false)), "handler KEY_ENTER and owner update should enter the real bank interior route")
		var interior_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
		_expect(not bool(interior_host_status.get("active", true)), "opening an interior should fail-close the retained world immediately")
		_expect(not bool(interior_host_status.get("visible", true)), "opening an interior should not leave retained building ghosts")
		scene.call("close_menu_for_test", true)
		scene.call("set_map_world_ticks_msec_for_test", 1088)
		handler.update(1.0 / 60.0)
		_expect(bool((scene.call("get_map_world_host_status_for_test") as Dictionary).get("active", false)), "returning to the street should reactivate the retained world through owner update")

	# The result handler must hide retained children synchronously before its
	# queued deletion flushes; otherwise queue_free would conceal a ghost route.
	var first_scene := scene
	handler.free_scene()
	_expect(not bool((first_scene.call("get_map_world_host_status_for_test") as Dictionary).get("active", true)), "handler free_scene should synchronously fail-close the retained world")
	await process_frame

	var exit_sink := ExitSink.new()
	var exit_spawned := handler.spawn_scene(
		owner,
		{
			"current_stage": 1,
			"map_seed": 918273,
			"full_layout_for_test": true,
		},
		Callable(exit_sink, "finish")
	)
	_expect(exit_spawned, "production handler should respawn a clean scene for the exit lifecycle leg")
	scene = owner.get_node_or_null("PlazaScene") as Control
	if scene == null:
		viewport.free()
		return
	exit_sink.scene = scene

	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	handler.handle_input(escape)
	handler.update(10.0)
	_expect(exit_sink.call_count == 1, "real plaza exit transition should invoke its completion callback once")
	_expect(not bool(exit_sink.host_status_at_callback.get("active", true)), "exit callback should observe the retained world already inactive")
	_expect(not bool(exit_sink.host_status_at_callback.get("visible", true)), "exit callback should never observe retained building ghosts")
	var exited_host_status: Dictionary = scene.call("get_map_world_host_status_for_test")
	_expect(not bool(exited_host_status.get("active", true)), "finished plaza exit should keep the retained world fail-closed")
	_expect(not bool(exited_host_status.get("visible", true)), "finished plaza exit should not be reactivated later in the completing update")

	handler.free_scene()
	viewport.free()


func _first_active_layer(statuses: Array[Dictionary]) -> Dictionary:
	for status in statuses:
		if bool(status.get("active", false)):
			return status
	return {}


func _find_spec(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
