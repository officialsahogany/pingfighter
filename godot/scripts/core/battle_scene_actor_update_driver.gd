extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneActorUpdateResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")
const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const VisionInputExclusivePolicy := preload("res://scripts/characters/vision_input_exclusive_policy.gd")
const VisionModifierInputProxy := preload("res://scripts/characters/vision_modifier_input_proxy.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()
var _fallback_result_applier: Object = BattleSceneActorUpdateResultApplier.new()
var _fallback_config_builder: Object = BattleScenePlayerControlConfigBuilder.new()
var _vision_modifier_input_proxy: Object = VisionModifierInputProxy.new()
var _vision_input_frame_key := -1
var _vision_input_owner_id := 0
var _vision_input_frame: Dictionary = {}
var _vision_proxy_enabled := true
var _vision_status_movement_transform_enabled := true


func update_player_control(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var controller: Object = _get_instance(registry, character_runtime.get_player_controller_key(character_type))
	_perf_end(perf_logger, "physics.player_control.lookup", sample_start)
	if controller == null or context_builder == null:
		_perf_end(perf_logger, "physics.player_control.total", total_start)
		return
	var fps_scale: float = max(0.0, delta * 60.0)
	sample_start = _perf_begin(perf_logger)
	var player_control_deps: Dictionary = context_builder.build_player_control_deps(registry, character_type)
	player_control_deps["owner"] = owner
	player_control_deps["registry"] = registry
	_perf_end(perf_logger, "physics.player_control.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	var config: Dictionary = _get_config_builder(registry).build_config(owner, registry, character_type, context_builder)
	_perf_end(perf_logger, "physics.player_control.build_config", sample_start)
	var locked_player_pos := _get_owner_vector2(owner, "player_pos", Vector2.ZERO)
	var vision_entries: Array[Dictionary] = [
		{
			"state": player_control_deps.get("dalji_vision_chosik_state", null),
			"skill_id": CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID,
		},
		{
			"state": player_control_deps.get("gaksital_vision_chosik_state", null),
			"skill_id": CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID,
		},
		{
			"state": player_control_deps.get("cheongringwi_vision_chosik_state", null),
			"skill_id": CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
		},
		{
			"state": player_control_deps.get("yeonmyo_vision_chosik_state", null),
			"skill_id": CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID,
		},
	]
	var vision_special_gauge_override := -1.0
	var vision_movement_locked := false
	var vision_activated := false
	var input_reader: Object = player_control_deps.get("input_reader", null)
	var status_input_reader: Object = player_control_deps.get("status_input_reader", null)
	var skill_config: Object = player_control_deps.get("skill_config", null)
	var vision_input_frame := prepare_vision_input_frame(
		owner,
		registry,
		input_reader,
		skill_config,
		status_input_reader
	)
	var input_snapshot: Dictionary = _get_dictionary(vision_input_frame, "raw_snapshot")
	var modifier_pressed := bool(vision_input_frame.get("modifier_pressed", false))
	var vision_input_exclusive := bool(vision_input_frame.get("exclusive_active", false))
	for entry: Dictionary in vision_entries:
		var vision_state: Object = entry.get("state", null)
		if vision_state == null or not vision_state.has_method("update"):
			continue
		var vision_result: Dictionary = vision_state.update(
			delta,
			input_snapshot,
			modifier_pressed,
			locked_player_pos,
			config,
			player_control_deps
		)
		if vision_result.has("special_gauge"):
			vision_special_gauge_override = float(vision_result.get("special_gauge", config.get("special_gauge", 0.0)))
			config["special_gauge"] = vision_special_gauge_override
		if bool(vision_result.get("activated", false)):
			vision_activated = true
		if vision_state.has_method("is_movement_locked") and bool(vision_state.is_movement_locked()):
			vision_movement_locked = true
	if bool(vision_input_frame.get("combat_input_filtered", false)):
		var shared_vision_input_reader: Object = vision_input_frame.get("input_reader", input_reader)
		player_control_deps["input_reader"] = shared_vision_input_reader
		# The dash lane normally bypasses character-skill locks through a sibling
		# reader. While Vision owns or drains combat input, both controller reads
		# must use the canonical frame snapshot instead of polling raw again.
		player_control_deps["dash_input_reader"] = shared_vision_input_reader
	if vision_input_exclusive:
		player_control_deps["vision_exclusive_raw_snapshot"] = input_snapshot
	config["vision_input_exclusive"] = vision_input_exclusive
	if bool(vision_input_frame.get("horizontal_input_blocked", false)):
		config["horizontal_input_locked"] = true
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = controller.update(
		delta,
		int(_get_owner_value(owner, "gameplay_frame_counter", 0)),
		_get_owner_vector2(owner, "player_pos", Vector2.ZERO),
		float(_get_owner_value(owner, "player_speed", 0.0)),
		config,
		player_control_deps
	)
	_perf_end(perf_logger, "physics.player_control.controller", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_player_weather_motion(result, owner, registry, fps_scale, character_type)
	if vision_activated:
		result["activated"] = true
	if vision_special_gauge_override >= 0.0:
		result["special_gauge"] = vision_special_gauge_override
	if vision_movement_locked:
		result["player_pos"] = locked_player_pos
		result["player_speed"] = 0.0
	_get_result_applier(registry).apply_player_result(owner, registry, result)
	_perf_end(perf_logger, "physics.player_control.apply", sample_start)
	_perf_end(perf_logger, "physics.player_control.total", total_start)


func prepare_vision_input_frame(
	owner: Object,
	registry: Object,
	input_reader: Object = null,
	skill_config: Object = null,
	status_input_reader: Object = null
) -> Dictionary:
	if owner == null or registry == null:
		return {
			"raw_snapshot": {},
			"input_reader": input_reader,
			"modifier_pressed": false,
			"exclusive_active": false,
		}
	var frame_key := int(Engine.get_physics_frames())
	var owner_id := owner.get_instance_id()
	_vision_modifier_input_proxy.begin_snapshot_frame(frame_key, owner_id)
	if (
		frame_key == _vision_input_frame_key
		and owner_id == _vision_input_owner_id
		and not _vision_input_frame.is_empty()
	):
		_refresh_cached_status_movement_transform(
			status_input_reader if status_input_reader != null else input_reader,
			skill_config if skill_config != null else _vision_input_frame.get("skill_config", null)
		)
		return _vision_input_frame.duplicate()
	var canonical_input_reader: Object = _get_character_input_reader(owner, registry)
	if canonical_input_reader == null:
		canonical_input_reader = input_reader
	if skill_config == null:
		skill_config = _get_character_skill_config(owner, registry)

	# GRT-019: every gameplay input consumer for this physics frame shares this
	# one canonical reader sample and this one stateful proxy. Mythic runtimes
	# pass the raw reader before player control passes its status proxy, while
	# ball/paddle consumers pass raw afterward. Caller identity cannot split the
	# frame cache or poll the canonical reader a second time.
	var input_snapshot: Dictionary = {}
	if canonical_input_reader != null and canonical_input_reader.has_method("get_snapshot"):
		var snapshot_value: Variant = canonical_input_reader.get_snapshot()
		if snapshot_value is Dictionary:
			input_snapshot = (snapshot_value as Dictionary).duplicate(true)
	var modifier_pressed := Input.is_action_pressed("vision_modifier")
	var vision_input_exclusive := VisionInputExclusivePolicy.is_active(modifier_pressed, skill_config)
	var blocked_hold_channels := VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
	var movement_snapshot := _apply_status_movement_transform(
		input_snapshot,
		status_input_reader if status_input_reader != null else input_reader
	)
	_vision_modifier_input_proxy.configure_snapshot(
		canonical_input_reader,
		movement_snapshot,
		vision_input_exclusive,
		blocked_hold_channels,
		input_snapshot
	)
	_vision_input_frame_key = frame_key
	_vision_input_owner_id = owner_id
	_vision_input_frame = {
		"raw_snapshot": input_snapshot,
		"source_reader": canonical_input_reader,
		"skill_config": skill_config,
		"blocked_hold_channels": blocked_hold_channels.duplicate(),
		"input_reader": _vision_modifier_input_proxy if _vision_proxy_enabled else canonical_input_reader,
		"modifier_pressed": modifier_pressed,
		"exclusive_active": vision_input_exclusive,
		"horizontal_input_blocked": (
			vision_input_exclusive
			and VisionInputExclusivePolicy.blocks_horizontal_movement(skill_config)
		),
		"combat_input_filtered": _vision_modifier_input_proxy.should_filter_current_snapshot(),
		"status_movement_transform_applied": _can_transform_status_snapshot(
			status_input_reader if status_input_reader != null else input_reader
		),
	}
	return _vision_input_frame.duplicate()


func set_vision_proxy_enabled_for_test(enabled: bool) -> void:
	_vision_proxy_enabled = enabled
	_vision_input_frame.clear()
	_vision_modifier_input_proxy.invalidate_snapshot_frame_for_test()


func set_vision_status_movement_transform_enabled_for_test(enabled: bool) -> void:
	_vision_status_movement_transform_enabled = enabled
	_vision_input_frame.clear()
	_vision_modifier_input_proxy.invalidate_snapshot_frame_for_test()


func set_vision_same_frame_rebuild_idempotence_enabled_for_test(enabled: bool) -> void:
	_vision_modifier_input_proxy.set_same_frame_rebuild_idempotence_enabled_for_test(enabled)
	_vision_input_frame.clear()


func reset_vision_input_frame_cache_for_test() -> void:
	_vision_input_frame.clear()
	_vision_modifier_input_proxy.invalidate_snapshot_frame_for_test()


func reset_vision_input_state() -> void:
	_vision_modifier_input_proxy.reset()
	_vision_input_frame_key = -1
	_vision_input_owner_id = 0
	_vision_input_frame.clear()


func _refresh_cached_status_movement_transform(
	status_input_reader: Object,
	skill_config: Object
) -> void:
	if bool(_vision_input_frame.get("status_movement_transform_applied", false)):
		return
	if not _can_transform_status_snapshot(status_input_reader):
		return
	var raw_snapshot: Dictionary = _get_dictionary(_vision_input_frame, "raw_snapshot")
	var movement_snapshot := _apply_status_movement_transform(
		raw_snapshot,
		status_input_reader
	)
	var exclusive_active := bool(_vision_input_frame.get("exclusive_active", false))
	var blocked_hold_channels: Dictionary = _vision_input_frame.get(
		"blocked_hold_channels",
		VisionInputExclusivePolicy.get_blocked_hold_channels(skill_config)
	)
	_vision_modifier_input_proxy.configure_snapshot(
		_vision_input_frame.get("source_reader", null),
		movement_snapshot,
		exclusive_active,
		blocked_hold_channels,
		raw_snapshot
	)
	_vision_input_frame["combat_input_filtered"] = (
		_vision_modifier_input_proxy.should_filter_current_snapshot()
	)
	_vision_input_frame["status_movement_transform_applied"] = true


func _apply_status_movement_transform(
	raw_snapshot: Dictionary,
	status_input_reader: Object
) -> Dictionary:
	if not _can_transform_status_snapshot(status_input_reader):
		return raw_snapshot.duplicate(true)
	var transformed_value: Variant = status_input_reader.transform_snapshot(raw_snapshot)
	if transformed_value is Dictionary:
		# configure_snapshot() takes its own immutable copy at the proxy boundary.
		return transformed_value as Dictionary
	return raw_snapshot.duplicate(true)


func _can_transform_status_snapshot(status_input_reader: Object) -> bool:
	return (
		_vision_status_movement_transform_enabled
		and status_input_reader != null
		and status_input_reader.has_method("transform_snapshot")
	)


func get_vision_aware_input_reader(
	owner: Object,
	registry: Object,
	input_reader: Object = null,
	skill_config: Object = null
) -> Object:
	return prepare_vision_input_frame(owner, registry, input_reader, skill_config).get(
		"input_reader",
		input_reader
	)


func update_boss_ai(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if ai_state == null:
		_perf_end(perf_logger, "physics.boss_ai.total", total_start)
		return
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	var sample_start: int = _perf_begin(perf_logger)
	var context: Dictionary = context_builder.build_boss_ai_context(owner, registry) if context_builder != null else {}
	_perf_end(perf_logger, "physics.boss_ai.build_context", sample_start)
	var fps_scale: float = max(0.0, delta * 60.0)
	owner.set("boss_pos_prev", _get_owner_vector2(owner, "boss_pos", Vector2.ZERO))
	owner.set("boss_interp_last_physics_usec", Time.get_ticks_usec())
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = ai_state.update(
		delta,
		_get_owner_vector2(owner, "boss_pos", Vector2.ZERO),
		float(_get_owner_value(owner, "boss_vel", 0.0)),
		context
	)
	_perf_end(perf_logger, "physics.boss_ai.controller", sample_start)
	sample_start = _perf_begin(perf_logger)
	_apply_boss_weather_motion(result, owner, registry, fps_scale)
	_get_result_applier(registry).apply_boss_result(owner, result)
	_perf_end(perf_logger, "physics.boss_ai.apply", sample_start)
	_perf_end(perf_logger, "physics.boss_ai.total", total_start)

func _apply_player_weather_motion(
	result: Dictionary,
	owner: Object,
	registry: Object,
	fps_scale: float,
	character_type: String
) -> void:
	if not _should_query_player_weather_motion(owner, character_type):
		return
	var weather: Object = _get_instance(registry, "weather_event_state")
	if weather != null and weather.has_method("apply_player_motion_effects_to_result"):
		weather.apply_player_motion_effects_to_result(result, owner, registry, fps_scale)
	elif weather != null and weather.has_method("apply_player_wind_to_result"):
		weather.apply_player_wind_to_result(result, owner, fps_scale)


func _apply_boss_weather_motion(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	if not _should_query_boss_weather_motion(owner):
		return
	var weather: Object = _get_instance(registry, "weather_event_state")
	if weather != null and weather.has_method("apply_boss_motion_effects_to_result"):
		weather.apply_boss_motion_effects_to_result(result, owner, registry, fps_scale)
	elif weather != null and weather.has_method("apply_boss_wind_to_result"):
		weather.apply_boss_wind_to_result(result, owner, fps_scale)


func _should_query_player_weather_motion(owner: Object, character_type: String) -> bool:
	if bool(_get_owner_value(owner, "weather_event_active", true)):
		return true
	return character_runtime.normalize(character_type) == "smasher"


func _should_query_boss_weather_motion(owner: Object) -> bool:
	return bool(_get_owner_value(owner, "weather_event_active", true))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_character_input_reader(owner: Object, registry: Object) -> Object:
	var character_type: String = character_runtime.normalize(
		_get_owner_value(owner, "selected_character_type", "smasher")
	)
	return _get_instance(registry, character_runtime.get_input_reader_key(character_type))


func _get_character_skill_config(owner: Object, registry: Object) -> Object:
	var character_type: String = character_runtime.normalize(
		_get_owner_value(owner, "selected_character_type", "smasher")
	)
	return _get_instance(registry, character_runtime.get_skill_config_key(character_type))


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value.duplicate(true) if value is Dictionary else {}


func _get_result_applier(registry: Object) -> Object:
	var applier: Object = _get_instance(registry, "battle_scene_actor_update_result_applier")
	if applier != null and applier.has_method("apply_player_result") and applier.has_method("apply_boss_result"):
		return applier
	return _fallback_result_applier


func _get_config_builder(registry: Object) -> Object:
	var builder: Object = _get_instance(registry, "battle_scene_player_control_config_builder")
	if builder != null and builder.has_method("build_config"):
		return builder
	return _fallback_config_builder


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
