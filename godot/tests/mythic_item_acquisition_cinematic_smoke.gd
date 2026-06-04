extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")

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
	_verify_cinematic_host_prewarm_reused()
	_verify_cinematic_phase_lifecycle()
	_verify_cinematic_updates_while_gameplay_frame_is_frozen()
	_verify_cinematic_reset_round_cleanup()

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
	var prewarmed_host: Object = runtime.acquisition_cinematic
	var prewarmed_node: Node = prewarmed_host as Node
	_expect(prewarmed_host is Node2D, "acquisition cinematic prewarm should create the hidden Node2D host")
	_expect(prewarmed_node != null and owner.is_ancestor_of(prewarmed_node), "prewarmed acquisition cinematic host should attach to the owner")
	_expect(not runtime.is_acquisition_cinematic_active(), "prewarmed acquisition cinematic should stay inactive")

	_expect(runtime.start_acquisition_cinematic(item_data, Vector2(220.0, 330.0), owner, registry), "prewarmed runtime should still start the acquisition cinematic")
	_expect(runtime.acquisition_cinematic == prewarmed_host, "field pickup should reuse the prewarmed acquisition cinematic host")
	owner.queue_free()


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
	owner.queue_free()


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
	owner.queue_free()


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
	owner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
