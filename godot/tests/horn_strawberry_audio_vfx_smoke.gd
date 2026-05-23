extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const TransformCinematicRenderer := preload("res://scripts/items/horn_strawberry_transform_cinematic_renderer.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"special_gauge": 500.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 35.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_horn_strawberry_change() -> void:
		calls.append("play_horn_strawberry_change")

	func play_horn_strawberry_eat() -> void:
		calls.append("play_horn_strawberry_eat")

	func play_horn_strawberry_stem_fire() -> void:
		calls.append("play_horn_strawberry_stem_fire")

	func play_horn_strawberry_stem_hit() -> void:
		calls.append("play_horn_strawberry_stem_hit")

	func play_horn_strawberry_field() -> void:
		calls.append("play_horn_strawberry_field")

	func play_horn_strawberry_horn_charge() -> void:
		calls.append("play_horn_strawberry_horn_charge")

	func play_horn_strawberry_horn_impact() -> void:
		calls.append("play_horn_strawberry_horn_impact")

	func play_horn_strawberry_bomb_throw() -> void:
		calls.append("play_horn_strawberry_bomb_throw")

	func play_horn_strawberry_bomb_explosion() -> void:
		calls.append("play_horn_strawberry_bomb_explosion")


class FakeStatusEffectState:
	extends RefCounted

	var applied_statuses: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied_statuses.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		})
		return {"active": true}


class FakeBossAiState:
	extends RefCounted

	func clear_paddle_hit_knockback() -> void:
		pass

	func start_paddle_hit_knockback(
		_velocity: float,
		_frames: float = 36.0,
		_decay_per_frame: float = 0.85,
		_replace_current: bool = true
	) -> void:
		pass


class FakeDashTokenState:
	extends RefCounted

	var dash_tokens := 0
	var dash_tokens_max := 1
	var dash_charge_timer := 120.0


class FakeDashState:
	extends RefCounted

	var token_state: Object = FakeDashTokenState.new()


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(source_instances: Dictionary = {}) -> void:
		instances = source_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


var _failures: Array[String] = []


func _init() -> void:
	_verify_audio_assets()
	_verify_transform_cinematic_phase_context()
	_verify_transform_audio_and_visible_event()
	_verify_skill_audio_edges()

	if _failures.is_empty():
		print("horn_strawberry_audio_vfx_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_audio_assets() -> void:
	_expect(GameAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH == "res://assets/sounds/strawberrychange.wav", "transform sound should use the legacy strawberrychange wav")
	_expect(GameAudio.HORN_STRAWBERRY_EAT_SOUND_PATH == "res://assets/sounds/strawberryeat.wav", "eat sound should use the legacy strawberryeat wav")
	_expect(FileAccess.file_exists(GameAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH), "strawberrychange wav should exist in the Godot asset tree")
	_expect(FileAccess.file_exists(GameAudio.HORN_STRAWBERRY_EAT_SOUND_PATH), "strawberryeat wav should exist in the Godot asset tree")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH) != null, "strawberrychange wav should load as a Godot audio stream")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.HORN_STRAWBERRY_EAT_SOUND_PATH) != null, "strawberryeat wav should load as a Godot audio stream")


func _verify_transform_cinematic_phase_context() -> void:
	var renderer := TransformCinematicRenderer.new()
	var transform_phase: Dictionary = renderer.build_phase_context({
		"state": "transform_event",
		"event_timer_sec": 2.25,
	})
	_expect(bool(renderer.is_visible({"state": "transform_event"})), "transform event should be visible")
	_expect(is_equal_approx(float(transform_phase.get("duration_sec", 0.0)), 4.5), "transform cinematic should use the 4.5 second event")
	_expect(is_equal_approx(float(transform_phase.get("progress", 0.0)), 0.5), "transform cinematic progress should derive from event_timer_sec")

	var detransform_phase: Dictionary = renderer.build_phase_context({
		"state": "detransform_event",
		"event_timer_sec": 1.0,
	})
	_expect(bool(renderer.is_visible({"state": "detransform_event"})), "detransform event should be visible")
	_expect(is_equal_approx(float(detransform_phase.get("duration_sec", 0.0)), 2.0), "detransform cinematic should use the 2 second event")
	_expect(is_equal_approx(float(detransform_phase.get("progress", 0.0)), 0.5), "detransform cinematic progress should derive from event_timer_sec")
	_expect(renderer.build_phase_context({"state": "idle"}).is_empty(), "idle should not build a cinematic phase")


func _verify_transform_audio_and_visible_event() -> void:
	var bundle: Dictionary = _make_transformed_bundle(false)
	var runtime: Object = bundle.get("runtime")
	var owner: Object = bundle.get("owner")
	var registry: Object = bundle.get("registry")
	var audio: FakeAudio = bundle.get("audio") as FakeAudio
	_expect(runtime.try_horn_strawberry_transform(owner, registry), "transform should start for audio smoke")
	_expect(audio.calls == ["play_horn_strawberry_change"], "transform start should play strawberrychange once")
	_expect(runtime.horn_strawberry_mask_runtime.has_visible_effects(runtime), "transform event should expose visible effects")
	runtime.update(owner, registry, 4.5)
	_expect(runtime.is_horn_strawberry_transformed(), "transform should finalize before detransform audio smoke")
	runtime.update(owner, registry, 60.0)
	_expect(audio.calls.count("play_horn_strawberry_change") == 2, "detransform start should replay strawberrychange")


func _verify_skill_audio_edges() -> void:
	var bundle: Dictionary = _make_transformed_bundle(true)
	var runtime: Object = bundle.get("runtime")
	var owner: FakeOwner = bundle.get("owner") as FakeOwner
	var input_reader: FakeInputReader = bundle.get("input_reader") as FakeInputReader
	var registry: Object = bundle.get("registry")
	var audio: FakeAudio = bundle.get("audio") as FakeAudio

	audio.calls.clear()
	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"action_pressed": true,
		"action_just_pressed": true,
	}
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(audio.calls.has("play_horn_strawberry_eat"), "eat input should play strawberryeat")
	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.8)
	_expect(audio.calls.has("play_horn_strawberry_stem_fire"), "eat finish should play stem fire audio")
	var eat_context: Dictionary = runtime.get_horn_strawberry_eat_context()
	owner.values["boss_pos"] = _get_first_projectile_boss_pos(eat_context)
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(audio.calls.has("play_horn_strawberry_stem_hit"), "stem collision should play hit audio")

	audio.calls.clear()
	runtime.horn_strawberry_eat_state.reset()
	owner.values["special_gauge"] = 200.0
	input_reader.snapshot = {"down_pressed": true}
	runtime.update(owner, registry, 0.5)
	runtime.update(owner, registry, 0.5)
	_expect(audio.calls == ["play_horn_strawberry_field"], "field build should play one field audio cue")

	audio.calls.clear()
	runtime.horn_strawberry_field_state.reset()
	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"up_pressed": true,
		"up_just_pressed": true,
	}
	runtime.update(owner, registry, 1.0 / 60.0)
	_expect(audio.calls.has("play_horn_strawberry_horn_charge"), "horn charge should play launch audio")
	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.43)
	_expect(audio.calls.has("play_horn_strawberry_horn_impact"), "horn charge impact should play impact audio")

	bundle = _make_transformed_bundle(true)
	runtime = bundle.get("runtime")
	owner = bundle.get("owner") as FakeOwner
	input_reader = bundle.get("input_reader") as FakeInputReader
	registry = bundle.get("registry")
	audio = bundle.get("audio") as FakeAudio
	audio.calls.clear()
	owner.values["special_gauge"] = 500.0
	input_reader.snapshot = {
		"left_pressed": true,
		"right_pressed": true,
	}
	runtime.update(owner, registry, 0.5)
	_expect(audio.calls.has("play_horn_strawberry_bomb_throw"), "bomb hold should play throw audio")
	var bomb_context: Dictionary = runtime.get_horn_strawberry_bomb_context()
	var bombs: Array = bomb_context.get("bombs", [])
	if not bombs.is_empty() and bombs[0] is Dictionary:
		var first_bomb: Dictionary = bombs[0]
		var bomb_pos: Vector2 = _get_vector2(first_bomb, "position")
		owner.values["boss_pos"] = bomb_pos - Vector2(50.0, 20.0)
		input_reader.snapshot = {}
		runtime.update(owner, registry, 0.0)
		_expect(audio.calls.has("play_horn_strawberry_bomb_explosion"), "bomb collision should play explosion audio")
	else:
		_expect(false, "bomb throw should expose a bomb for explosion audio smoke")


func _make_transformed_bundle(finish_transform: bool) -> Dictionary:
	var owner := FakeOwner.new()
	var runtime: Object = MythicItemRuntime.new()
	var input_reader := FakeInputReader.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"smasher_input_reader": input_reader,
		"game_audio": audio,
		"status_effect_state": FakeStatusEffectState.new(),
		"boss_ai_state": FakeBossAiState.new(),
		"smasher_dash_state": FakeDashState.new(),
	})
	_expect(runtime.equip_item("horn_strawberry_mask", owner, registry, {"transform_duration": 60.0}, false), "horn strawberry should equip for audio smoke")
	if finish_transform:
		_expect(runtime.try_horn_strawberry_transform(owner, registry), "horn strawberry should begin transform for skill audio smoke")
		runtime.update(owner, registry, 4.5)
		_expect(runtime.is_horn_strawberry_transformed(), "horn strawberry should finish transform for skill audio smoke")
	return {
		"owner": owner,
		"runtime": runtime,
		"input_reader": input_reader,
		"audio": audio,
		"registry": registry,
	}


func _get_first_projectile_boss_pos(eat_context: Dictionary) -> Vector2:
	var projectiles: Array = eat_context.get("projectiles", [])
	if projectiles.is_empty() or not (projectiles[0] is Dictionary):
		return Vector2(330.0, 35.0)
	var projectile_pos: Vector2 = _get_vector2(projectiles[0], "position")
	return projectile_pos - Vector2(50.0, 20.0)


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
