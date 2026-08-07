extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _character_runtime: Object = PlayerCharacterRuntime.new()


func build_deps(owner: Object, registry: Object) -> Dictionary:
	if owner == null or registry == null:
		return {}
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var character_type: String = _character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	_perf_end(perf_logger, "physics.deps.character_type", sample_start)
	sample_start = _perf_begin(perf_logger)
	var skill_orb_tooltip_state := _get_skill_orb_tooltip_hover_state(owner, registry)
	_perf_end(perf_logger, "physics.deps.skill_tooltip_hover", sample_start)
	sample_start = _perf_begin(perf_logger)
	_sync_ball_intensity_stakes(registry)
	_perf_end(perf_logger, "physics.deps.ball_intensity_stakes", sample_start)
	sample_start = _perf_begin(perf_logger)
	var current_stage: int = int(_get_owner_value(owner, "current_stage", 1))
	var deps := {
		"current_stage": current_stage,
		# 스테이지 게이트: 비-7 스테이지 프레임에서 stage7 상태를 cold-instantiate
		# 하지 않도록 조건부로만 조회한다(핫패스 lazy-init 트랩).
		"stage7_akamu_state": _get_instance(registry, "stage7_akamu_state") if current_stage == 7 else null,
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"stage3_boss_skill_state": _get_instance(registry, "stage3_boss_skill_state"),
		"power_state": _get_instance(registry, "smasher_power_smash_state") if character_type == PlayerCharacterRuntime.SMASHER else null,
		"round_state": _get_instance(registry, "round_flow_state"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		# 프레임플로우의 _is_runtime_perk_pause_active 재확인(신화 획득이 같은
		# 프레임에 후속 퍽 선택을 여는 엣지)과 전리품 분기의 모달 일시정지가
		# 실제로 작동하려면 이 키가 있어야 한다 — 빠지면 두 체크 모두 조용히
		# 항상 false(공허)다.
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"victory_highlight_playback_state": _get_instance(registry, "victory_highlight_playback_state"),
		"victory_loot_phase_state": _get_instance(registry, "victory_loot_phase_state"),
		"serve_flow_controller": _get_instance(registry, "serve_flow_controller"),
		"game_audio": _get_instance(registry, "game_audio"),
		"serve_context": _build_serve_context(owner),
		"skill_orb_tooltip_active": not skill_orb_tooltip_state.is_empty(),
		"skill_orb_tooltip_key": str(skill_orb_tooltip_state.get("skill_name", "")),
	}
	_perf_end(perf_logger, "physics.deps.instances", sample_start)
	_perf_end(perf_logger, "physics.deps.total", total_start)
	return deps


func _build_serve_context(owner: Object) -> Dictionary:
	return {
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
	}


func _get_skill_orb_tooltip_hover_state(owner: Object, registry: Object) -> Dictionary:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("update_hover_state"):
		return {}
	return hover_state.update_hover_state(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _sync_ball_intensity_stakes(registry: Object) -> void:
	var ball_intensity: Object = _get_instance(registry, "ball_intensity")
	if ball_intensity == null or not ball_intensity.has_method("set_stakes"):
		return
	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state == null:
		ball_intensity.set_stakes(false, false, false)
		return
	ball_intensity.set_stakes(
		_is_deuce_mode(score_state),
		_would_score_finish(score_state, "player"),
		_is_player_in_danger(score_state)
	)


func _is_deuce_mode(score_state: Object) -> bool:
	if score_state.has_method("get_snapshot"):
		var snapshot: Dictionary = score_state.get_snapshot()
		return bool(snapshot.get("deuce_mode", false))
	var value: Variant = score_state.get("deuce_mode")
	return bool(value) if value != null else false


func _would_score_finish(score_state: Object, scoring_side: String) -> bool:
	if score_state.has_method("would_score_finish"):
		return bool(score_state.would_score_finish(scoring_side))
	return false


func _is_player_in_danger(score_state: Object) -> bool:
	if score_state.has_method("is_player_in_danger"):
		return bool(score_state.is_player_in_danger())
	return _would_score_finish(score_state, "boss")


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
