extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemCatalogIconMetadata := preload("res://scripts/items/mythic_item_catalog_icon_metadata.gd")
const MythicAcquisitionCinematic := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var gameplay_frame_counter := 100


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_legendary_open() -> void:
		calls.append("play_legendary_open")

	func play_legendary_after() -> void:
		calls.append("play_legendary_after")

	func play_legendary_ending() -> void:
		calls.append("play_legendary_ending")

	func stop_legendary_after() -> void:
		calls.append("stop_legendary_after")

	func play_item_get() -> void:
		calls.append("play_item_get")


class FakeRegistry:
	extends RefCounted

	var audio: Object
	var mythic_runtime: Object = null

	func _init(audio_source: Object) -> void:
		audio = audio_source

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "mythic_item_runtime":
			return mythic_runtime
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_blocking_prewarm_uses_safe_asset_path()
	_verify_teardown_keeps_host_reusable()
	_verify_cinematic_host_prewarm_reused()
	_verify_cinematic_phase_lifecycle()
	_verify_cinematic_updates_while_gameplay_frame_is_frozen()
	_verify_cinematic_reset_round_cleanup()
	await _drain_frames(8)
	_clear_runtime_caches_for_test()
	await _drain_frames(30)

	if _failures.is_empty():
		print("mythic_item_acquisition_cinematic_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cinematic_host_prewarm_reused() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	root.add_child(owner)

	runtime.prewarm_acquisition_cinematic(owner, registry)
	for sheet_path_value in MythicItemCatalogIconMetadata.MYTHIC_ICON_SHEET_PATHS.values():
		_expect(
			ProjectResourceLoader.get_cached_texture(str(sheet_path_value)) != null,
			"cinematic prewarm should warm the mythic icon sheet into the loader cache (%s)" % str(sheet_path_value)
		)
	var prewarmed_host: Object = runtime.acquisition_cinematic
	var prewarmed_node: Node = prewarmed_host as Node
	_expect(prewarmed_host is Node2D, "acquisition cinematic prewarm should create the hidden Node2D host")
	_expect(prewarmed_node != null and owner.is_ancestor_of(prewarmed_node), "prewarmed acquisition cinematic host should attach to the owner")
	_expect(not runtime.is_acquisition_cinematic_active(), "prewarmed acquisition cinematic should stay inactive")

	_expect(runtime.start_acquisition_cinematic(item_data, Vector2(220.0, 330.0), owner, registry), "prewarmed runtime should still start the acquisition cinematic")
	_expect(runtime.acquisition_cinematic == prewarmed_host, "field pickup should reuse the prewarmed acquisition cinematic host")
	_cleanup_runtime_owner(runtime, registry, owner)


func _verify_cinematic_phase_lifecycle() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	item_data["rolls"] = {"cooldown_reduction": 12.0}
	item_data = catalog.sync_roll_fields(item_data, false)
	root.add_child(owner)

	_expect(runtime.start_acquisition_cinematic(item_data, Vector2(220.0, 330.0), owner, registry), "runtime should start mythic acquisition cinematic")
	_expect(runtime.should_pause_game(), "active acquisition cinematic should pause gameplay")
	_expect(audio.calls.has("play_legendary_open"), "cinematic should play the original open cue")
	_expect(runtime.acquisition_cinematic is Node2D, "v2 acquisition cinematic should be a Node2D host")
	_expect(owner.is_ancestor_of(runtime.acquisition_cinematic), "v2 acquisition cinematic should attach to the owner node")

	runtime.acquisition_cinematic.update(1.21, registry)
	var ignite_snapshot: Dictionary = runtime.get_acquisition_cinematic_snapshot()
	_expect(str(ignite_snapshot.get("phase", "")) == "ignite", "build phase should advance into the ignite phase")
	_expect(audio.calls.has("play_legendary_after"), "ignite follow-up should play the original after cue")
	_expect(float(ignite_snapshot.get("shake_trauma", 0.0)) > 0.0, "ignite should kick screen-shake trauma for the original-style impact punch")

	runtime.acquisition_cinematic.update(0.41, registry)
	runtime.acquisition_cinematic.update(0.51, registry)
	runtime.acquisition_cinematic.update(0.51, registry)
	var reveal_snapshot: Dictionary = runtime.get_acquisition_cinematic_snapshot()
	_expect(bool(reveal_snapshot.get("waiting_for_click", false)), "reveal phase should wait for click/confirm input")
	runtime.acquisition_cinematic.update(0.75, registry)
	_expect(not audio.calls.has("stop_legendary_after"), "after cue should keep playing while the reveal waits for player input")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_expect(runtime.handle_acquisition_cinematic_input(click, registry), "click input should be consumed while the cinematic is active")
	var clicked_snapshot: Dictionary = runtime.get_acquisition_cinematic_snapshot()
	_expect(bool(clicked_snapshot.get("absorb_started", false)), "click should start the acquisition absorb animation")
	_expect(audio.calls.has("play_legendary_ending"), "click absorb should play the original ending cue")

	runtime.acquisition_cinematic.update(1.55, registry)
	runtime.acquisition_cinematic.update(0.51, registry)
	_expect(not runtime.is_acquisition_cinematic_active(), "acquisition cinematic should finish after the absorb and paddle-glow phases")
	_expect(audio.calls.has("stop_legendary_after"), "after cue should be stopped during the click acquisition phase")
	_cleanup_runtime_owner(runtime, registry, owner)


func _verify_cinematic_updates_while_gameplay_frame_is_frozen() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	registry.mythic_runtime = runtime
	var item_driver: Object = BattleSceneItemUpdateDriver.new()
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	root.add_child(owner)

	_expect(runtime.start_acquisition_cinematic(item_data, Vector2(220.0, 330.0), owner, registry), "frozen-frame test should start mythic acquisition cinematic")
	item_driver.update_mythic_items(owner, registry, 0.25)
	var first_elapsed: float = float(runtime.get_acquisition_cinematic_snapshot().get("elapsed", 0.0))
	item_driver.update_mythic_items(owner, registry, 0.25)
	var next_elapsed: float = float(runtime.get_acquisition_cinematic_snapshot().get("elapsed", 0.0))
	_expect(next_elapsed > first_elapsed + 0.20, "pause cinematic should keep updating even when gameplay_frame_counter is frozen")
	_cleanup_runtime_owner(runtime, registry, owner)


func _verify_cinematic_reset_round_cleanup() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	root.add_child(owner)

	_expect(runtime.start_acquisition_cinematic(item_data, Vector2(220.0, 330.0), owner, registry), "round-reset test should start mythic acquisition cinematic")
	runtime.acquisition_cinematic.update(1.21, registry)
	runtime.reset_round(registry)
	_expect(not runtime.is_acquisition_cinematic_active(), "reset_round() should hide and deactivate the acquisition cinematic host")
	_expect(audio.calls.has("stop_legendary_after"), "reset_round() should stop the acquisition after cue")
	_cleanup_runtime_owner(runtime, registry, owner)


func _cleanup_runtime_owner(runtime: Object, registry: Object, owner: Node) -> void:
	if runtime != null and runtime.has_method("reset_round"):
		runtime.reset_round(registry)
		runtime.acquisition_cinematic = null
	if owner != null:
		owner.queue_free()


func _clear_runtime_caches_for_test() -> void:
	MythicAcquisitionCinematic.reset_for_test()
	ProjectResourceLoader.clear_caches()


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _verify_blocking_prewarm_uses_safe_asset_path() -> void:
	var cinematic_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var cinematic_body := _function_body(cinematic_source, "static func prewarm_assets() -> void:")
	_expect(
		cinematic_body.find("while not prewarm_assets_step()") < 0,
		"cinematic blocking prewarm should not busy-loop the staged threaded prewarm step"
	)
	_expect(
		cinematic_body.find("ProjectResourceLoader.load_texture") >= 0
			and cinematic_body.find("_get_or_build_soft_white_flash_texture()") >= 0,
		"cinematic blocking prewarm should use the direct safe texture/procedural path"
	)

	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_runtime.gd")
	var helper_body := _function_body(helper_source, "func prewarm_assets() -> void:")
	var helper_direct_index := helper_body.find("cinematic_script.prewarm_assets()")
	var helper_fallback_index := helper_body.find("while not prewarm_static_assets_step()")
	_expect(
		helper_direct_index >= 0 and (helper_fallback_index < 0 or helper_direct_index < helper_fallback_index),
		"cinematic runtime blocking prewarm should prefer the safe direct prewarm before any staged fallback"
	)

	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var runtime_body := _function_body(runtime_source, "func prewarm_acquisition_cinematic_assets() -> void:")
	var runtime_direct_index := runtime_body.find("acquisition_cinematic_runtime.prewarm_static_assets()")
	var runtime_fallback_index := runtime_body.find("while not prewarm_acquisition_cinematic_assets_step()")
	_expect(
		runtime_direct_index >= 0 and (runtime_fallback_index < 0 or runtime_direct_index < runtime_fallback_index),
		"mythic runtime blocking acquisition prewarm should route through the helper's safe direct prewarm"
	)


func _verify_teardown_keeps_host_reusable() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var host := MythicAcquisitionCinematic.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	var item_data: Dictionary = catalog.build_item_by_name("heavenly_cape")
	root.add_child(owner)
	owner.add_child(host)

	host.trigger(item_data, Vector2(220.0, 330.0), Vector2(380.0, 710.0), registry)
	host.tear_down(false)
	_expect(not host.is_queued_for_deletion(), "tear_down(false) should keep the cinematic host available for reuse")
	host.trigger(item_data, Vector2(230.0, 340.0), Vector2(380.0, 710.0), registry)
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("active", false)), "cinematic host should restart after tear_down(false)")
	_expect(str(snapshot.get("item_name", "")) == "heavenly_cape", "reused cinematic host should preserve the new item payload")
	host.tear_down(true)
	owner.queue_free()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var end := source.length()
	for next_signature in ["\nfunc ", "\nstatic func "]:
		var candidate := source.find(next_signature, start + signature.length())
		if candidate >= 0:
			end = min(end, candidate)
	return source.substr(start, end - start)
