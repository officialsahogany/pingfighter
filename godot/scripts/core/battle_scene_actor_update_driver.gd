extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneActorUpdateResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")
const BattleScenePlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()
var _fallback_result_applier: Object = BattleSceneActorUpdateResultApplier.new()
var _fallback_config_builder: Object = BattleScenePlayerControlConfigBuilder.new()


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
	_get_result_applier(registry).apply_player_result(owner, registry, result)
	_perf_end(perf_logger, "physics.player_control.apply", sample_start)
	_perf_end(perf_logger, "physics.player_control.total", total_start)


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
