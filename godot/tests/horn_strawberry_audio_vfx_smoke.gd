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

	func stop_horn_strawberry_eat() -> void:
		calls.append("stop_horn_strawberry_eat")

	func play_horn_strawberry_stem_fire() -> void:
		calls.append("play_horn_strawberry_stem_fire")

	func play_horn_strawberry_stem_hit() -> void:
		calls.append("play_horn_strawberry_stem_hit")

	func play_horn_strawberry_field() -> void:
		calls.append("play_horn_strawberry_field")

	func play_horn_strawberry_field_break() -> void:
		calls.append("play_horn_strawberry_field_break")

	func play_horn_strawberry_field_build_break() -> void:
		calls.append("play_horn_strawberry_field_build_break")

	func play_horn_strawberry_horn_charge() -> void:
		calls.append("play_horn_strawberry_horn_charge")

	func play_horn_strawberry_horn_impact() -> void:
		calls.append("play_horn_strawberry_horn_impact")

	func play_horn_strawberry_bomb_throw() -> void:
		calls.append("play_horn_strawberry_bomb_throw")

	func play_horn_strawberry_bomb_explosion() -> void:
		calls.append("play_horn_strawberry_bomb_explosion")


class RecordingPlayerFactory:
	extends RefCounted

	var created := {}

	func create(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		var player := AudioStreamPlayer.new()
		player.name = name
		player.volume_db = volume_db
		player.stream = AudioStreamWAV.new()
		created[name] = {
			"path": path,
			"volume_db": volume_db,
			"player": player,
		}
		if parent != null:
			parent.add_child(player)
		return player


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
	_verify_game_audio_dedicated_sfx()
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
	_expect(GameAudio.HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH == "res://assets/sounds/arrow.wav", "stem fire should use the legacy arrow wav")
	_expect(GameAudio.HORN_STRAWBERRY_STEM_HIT_SOUND_PATH == "res://assets/sounds/bullethit.wav", "stem hit should use the legacy bullethit wav")
	_expect(GameAudio.HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH == "res://assets/sounds/horncharge.wav", "horn charge should use the legacy horncharge wav")
	_expect(GameAudio.HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH == "res://assets/sounds/bonemake3.wav", "field build should use the legacy bonemake3 wav")
	_expect(GameAudio.HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH == "res://assets/sounds/bonebreak.wav", "field break should use the legacy bonebreak wav")
	_expect(GameAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH == "res://assets/sounds/shurikenhit.wav", "field build break should use the legacy shurikenhit wav")
	_expect(GameAudio.HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH == "res://assets/sounds/bullethit.wav", "bomb trigger should use the legacy bullethit wav")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH, "strawberrychange")
	# Python live volumes: stem hit = bullethit 0.3 (pingfighter play_cached_sound; the
	# module's 0.4 loader is unused), bomb throw = bullethit 0.4.
	_expect(abs(db_to_linear(GameAudio.HORN_STRAWBERRY_STEM_HIT_GAIN_DB) - 0.3) < 0.001, "stem hit gain should match the Python live 0.3 volume")
	_expect(abs(db_to_linear(GameAudio.HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB) - 0.4) < 0.001, "bomb trigger gain should match the Python 0.4 volume")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_EAT_SOUND_PATH, "strawberryeat")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH, "arrow")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_STEM_HIT_SOUND_PATH, "bullethit")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH, "horncharge")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH, "bonemake3")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH, "bonebreak")
	_expect_audio_asset(GameAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH, "shurikenhit")


func _verify_game_audio_dedicated_sfx() -> void:
	var host := Node.new()
	var factory := RecordingPlayerFactory.new()
	var audio: Object = GameAudio.new()
	audio.player_factory = factory
	audio.owner_node = host
	audio._setup_item_command_sfx()

	_expect_created_sfx(factory, "HornStrawberryChangeSfx", GameAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH, GameAudio.HORN_STRAWBERRY_CHANGE_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryEatSfx", GameAudio.HORN_STRAWBERRY_EAT_SOUND_PATH, GameAudio.HORN_STRAWBERRY_EAT_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryStemFireSfx", GameAudio.HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH, GameAudio.HORN_STRAWBERRY_STEM_FIRE_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryStemHitSfx", GameAudio.HORN_STRAWBERRY_STEM_HIT_SOUND_PATH, GameAudio.HORN_STRAWBERRY_STEM_HIT_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryHornChargeSfx", GameAudio.HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH, GameAudio.HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryFieldBuildSfx", GameAudio.HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH, GameAudio.HORN_STRAWBERRY_FIELD_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryFieldBreakSfx", GameAudio.HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH, GameAudio.HORN_STRAWBERRY_FIELD_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryFieldBuildBreakSfx", GameAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH, GameAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB)
	_expect_created_sfx(factory, "HornStrawberryBombTriggerSfx", GameAudio.HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH, GameAudio.HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB)

	var source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd").replace("\r\n", "\n")
	_expect(_function_body(source, "func play_horn_strawberry_change() -> void:").find("randf_range") < 0, "transform cue should not pitch-randomize the legacy sample")
	_expect(_function_body(source, "func play_horn_strawberry_eat() -> void:").find("randf_range") < 0, "eat cue should not pitch-randomize the legacy sample")
	_expect(_function_body(source, "func play_horn_strawberry_stem_fire() -> void:").find("horn_strawberry_stem_fire_sfx") >= 0, "stem fire should play the dedicated arrow cue")
	_expect(_function_body(source, "func play_horn_strawberry_stem_hit() -> void:").find("horn_strawberry_stem_hit_sfx") >= 0, "stem hit should play the dedicated bullethit cue")
	_expect(_function_body(source, "func play_horn_strawberry_field() -> void:").find("horn_strawberry_field_build_sfx") >= 0, "field build should play the dedicated bonemake3 cue")
	_expect(_function_body(source, "func play_horn_strawberry_field() -> void:").find("shield_kiting_launch_sfx") < 0, "field build should not reuse Shield Kiting launch audio")
	_expect(_function_body(source, "func play_horn_strawberry_field_break() -> void:").find("horn_strawberry_field_break_sfx") >= 0, "field break should play the dedicated bonebreak cue")
	_expect(_function_body(source, "func play_horn_strawberry_field_build_break() -> void:").find("horn_strawberry_field_build_break_sfx") >= 0, "field build-break should play the dedicated shurikenhit cue")
	_expect(_function_body(source, "func play_horn_strawberry_horn_charge() -> void:").find("horn_strawberry_horn_charge_sfx") >= 0, "horn charge should play the dedicated horncharge cue")
	_expect(_function_body(source, "func play_horn_strawberry_horn_charge() -> void:").find("power_smash_launch_sfx") < 0, "horn charge should not reuse Power Smash launch audio")
	_expect(_function_body(source, "func play_horn_strawberry_bomb_throw() -> void:").find("horn_strawberry_bomb_trigger_sfx") >= 0, "bomb throw should play the dedicated trigger cue")
	_expect(_function_body(source, "func play_horn_strawberry_bomb_throw() -> void:").find("throw_sfx") < 0, "bomb throw should not reuse generic throw audio")
	host.free()


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
	_expect(audio.calls.has("stop_horn_strawberry_eat"), "eat finish should stop strawberryeat")
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
	input_reader.snapshot = {}
	runtime.update(owner, registry, 0.5)
	var field_context: Dictionary = runtime.get_horn_strawberry_field_context()
	var barriers: Array = field_context.get("barriers", [])
	if not barriers.is_empty() and barriers[0] is Dictionary:
		var barrier: Dictionary = barriers[0]
		_expect(
			runtime.notify_horn_strawberry_field_hit(int(barrier.get("id", 0)), _get_vector2(barrier, "position"), {"registry": registry, "audio": audio}),
			"field hit should notify the active barrier"
		)
		_expect(audio.calls.has("play_horn_strawberry_field_break"), "field hit should play bonebreak")
	else:
		_expect(false, "field build should expose a barrier for break audio smoke")

	audio.calls.clear()
	# Python parity: a barrier destroyed while still BUILDING plays shurikenhit, not bonebreak.
	audio.calls.clear()
	runtime.horn_strawberry_field_state.reset()
	owner.values["special_gauge"] = 200.0
	input_reader.snapshot = {"down_pressed": true}
	runtime.update(owner, registry, 1.0)
	input_reader.snapshot = {}
	var building_context: Dictionary = runtime.get_horn_strawberry_field_context()
	var building_barriers: Array = building_context.get("barriers", [])
	if not building_barriers.is_empty() and building_barriers[0] is Dictionary:
		var building_barrier: Dictionary = building_barriers[0]
		_expect(not bool(building_barrier.get("built", true)), "field should still be building right after cast (Python 3.0s build)")
		_expect(
			runtime.notify_horn_strawberry_field_hit(int(building_barrier.get("id", 0)), Vector2.ZERO, {"registry": registry, "audio": audio}, false),
			"build-phase field hit should notify the building barrier"
		)
		_expect(audio.calls.has("play_horn_strawberry_field_build_break"), "build-phase destruction should play shurikenhit")
		_expect(not audio.calls.has("play_horn_strawberry_field_break"), "build-phase destruction should not play bonebreak")
	else:
		_expect(false, "field should expose a building barrier for build-break audio smoke")

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
	_expect(not audio.calls.has("play_horn_strawberry_horn_impact"), "horn charge should not add a separate impact cue")

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
	_expect(audio.calls.has("play_horn_strawberry_bomb_throw"), "bomb activation should play the legacy bullethit trigger")
	var bomb_context: Dictionary = runtime.get_horn_strawberry_bomb_context()
	var bombs: Array = bomb_context.get("bombs", [])
	if not bombs.is_empty() and bombs[0] is Dictionary:
		var first_bomb: Dictionary = bombs[0]
		var bomb_pos: Vector2 = _get_vector2(first_bomb, "position")
		owner.values["boss_pos"] = bomb_pos - Vector2(50.0, 20.0)
		input_reader.snapshot = {}
		runtime.update(owner, registry, 0.0)
		_expect(not audio.calls.has("play_horn_strawberry_bomb_explosion"), "bomb collision should not add a separate explosion cue")
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


func _expect_audio_asset(path: String, label: String) -> void:
	_expect(FileAccess.file_exists(path), "%s wav should exist in the Godot asset tree" % label)
	_expect(ProjectResourceLoader.load_audio_stream(path) != null, "%s wav should load as a Godot audio stream" % label)


func _expect_created_sfx(factory: RecordingPlayerFactory, name: String, path: String, volume_db: float) -> void:
	var created: Dictionary = _as_dict(factory.created.get(name, {}))
	_expect(str(created.get("path", "")) == path, "%s should use %s" % [name, path])
	_expect(abs(float(created.get("volume_db", 0.0)) - volume_db) <= 0.001, "%s should use the expected gain" % name)
	_expect(created.get("player", null) is AudioStreamPlayer, "%s should expose an AudioStreamPlayer" % name)


func _function_body(source: String, marker: String) -> String:
	var start := source.find(marker)
	_expect(start >= 0, "%s should exist in GameAudio" % marker)
	if start < 0:
		return ""
	var end := source.find("\n\nfunc ", start + marker.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
