extends RefCounted

const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

const STAGE_ID := 4
const FIELD_HEIGHT := 750.0
const GAUGE_MAX := 500.0
const MEDITATION_CHANCE := 1.0

# Stateful cross-owner runtime flow for Ponk's skill set. Focused state owners
# retain their own clocks and payloads; this coordinator owns only shared gauge/
# presentation-clock scalars, activation policy, exact per-frame ordering,
# audio dispatch, and round/stage/full-reset orchestration.

var frame_clock := 0.0
var boss_special_gauge := 0.0
var boss_special_ready := false

var _test_meditation_chance := -1.0
var _magnetic_field_state: Object
var _magnetic_projectile_state: Object
var _meditation_state: Object
var _illusion_state: Object
var _fx_host_coordinator: Object
var _ball_interaction_coordinator: Object


func _init(
	magnetic_field_state: Object,
	magnetic_projectile_state: Object,
	meditation_state: Object,
	illusion_state: Object,
	fx_host_coordinator: Object,
	ball_interaction_coordinator: Object
) -> void:
	_magnetic_field_state = magnetic_field_state
	_magnetic_projectile_state = magnetic_projectile_state
	_meditation_state = meditation_state
	_illusion_state = illusion_state
	_fx_host_coordinator = fx_host_coordinator
	_ball_interaction_coordinator = ball_interaction_coordinator


func reset() -> void:
	boss_special_gauge = 0.0
	boss_special_ready = false
	_magnetic_field_state.reset()
	_magnetic_projectile_state.reset()
	_fx_host_coordinator.stop_magnetic()
	_meditation_state.reset()
	_fx_host_coordinator.stop_meditation()
	_illusion_state.reset()
	_fx_host_coordinator.stop_illusion()
	_fx_host_coordinator.stop_awaken_aura()
	frame_clock = 0.0


func reset_round(deps: Dictionary = {}) -> void:
	if (
		bool(_magnetic_field_state.get("magnetic_active"))
		or bool(_magnetic_projectile_state.has_audio_runtime())
	):
		_ball_interaction_coordinator.stop_magnetic_audio(deps)
	_magnetic_field_state.reset_round()
	_magnetic_projectile_state.reset_round()
	_fx_host_coordinator.stop_magnetic()
	_meditation_state.reset_round()
	_fx_host_coordinator.stop_meditation()
	if bool(_illusion_state.get("illusion_active")):
		_stop_illusion_audio(deps)
	_illusion_state.reset_round()
	_fx_host_coordinator.stop_illusion()
	_fx_host_coordinator.stop_awaken_aura()


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	if not _is_live_stage_context(context):
		_clear_stage_transients(deps)
		return

	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	frame_clock += clamped_delta
	_magnetic_field_state.sync_center(_ball_interaction_coordinator.get_boss_center(context))
	_illusion_state.set_aura_enraged(_is_enraged(context))
	var activated_illusion_this_tick := false

	if not _ball_interaction_coordinator.is_timing_frozen(context):
		if not _is_boss_skill_cooldown_paused(context):
			_update_skill_cooldowns(clamped_delta)
		_illusion_state.update_awaken_burst(fps_scale)
		activated_illusion_this_tick = _illusion_state.update_awaken_state(
			fps_scale,
			_is_serve_waiting(context),
			_is_boss_skill_cooldown_paused(context)
		)
		if not _is_boss_skill_cooldown_paused(context):
			if _can_auto_activate_magnetic(context):
				_activate_magnetic(context, deps)
			if _illusion_state.can_auto_activate(_is_serve_waiting(context)):
				if BossSkillParryGate.try_parry("ponk_illusion", "환영파문", context, deps):
					_illusion_state.consume_parried()
				else:
					_illusion_state.activate()
				activated_illusion_this_tick = true
		_update_magnetic(fps_scale, context, deps)
		_magnetic_projectile_state.update(
			fps_scale,
			_ball_interaction_coordinator.get_player_center(context),
			float(context.get("height", FIELD_HEIGHT)),
			bool(_magnetic_field_state.get("magnetic_enraged"))
		)
		_update_meditation(fps_scale, context, deps)
		if not activated_illusion_this_tick:
			_illusion_state.update_active(fps_scale)

	_sync_magnetic_audio(deps)
	_sync_illusion_audio(deps)


func handle_score_event(scoring_side: String, score_result: Dictionary) -> void:
	_illusion_state.handle_score_event(scoring_side, int(score_result.get("player_score", 0)))


func register_boss_hit(context: Dictionary = {}, deps: Dictionary = {}) -> void:
	if not _is_live_stage_context(context):
		return
	if (
		bool(_magnetic_field_state.get("magnetic_active"))
		or bool(_meditation_state.get("meditation_active"))
	):
		return
	if float(_meditation_state.get("meditation_cooldown_seconds")) <= 0.0:
		_activate_meditation(context, deps)


func apply_gauge_delta(delta: float) -> void:
	boss_special_gauge = clampf(boss_special_gauge + delta, 0.0, GAUGE_MAX)
	boss_special_ready = false


func force_activate_magnetic(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	boss_special_ready = false
	boss_special_gauge = 0.0
	_activate_magnetic(context, deps)
	return bool(_magnetic_field_state.get("magnetic_active"))


func force_activate_meditation(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	_activate_meditation(context, deps)
	return bool(_meditation_state.get("meditation_active"))


func set_meditation_chance_for_tests(value: float) -> void:
	_test_meditation_chance = value


func get_meditation_chance() -> float:
	if _test_meditation_chance >= 0.0:
		return clampf(_test_meditation_chance, 0.0, 1.0)
	return MEDITATION_CHANCE


func _clear_stage_transients(deps: Dictionary) -> void:
	if bool(_magnetic_field_state.get("magnetic_active")):
		_ball_interaction_coordinator.stop_magnetic_audio(deps)
	_magnetic_field_state.clear_stage_transients()
	_magnetic_projectile_state.clear_stage_transients()
	_fx_host_coordinator.stop_magnetic()
	_meditation_state.clear_stage_transients()
	_fx_host_coordinator.stop_meditation()
	if bool(_illusion_state.get("illusion_active")):
		_stop_illusion_audio(deps)
	_illusion_state.clear_stage_transients()
	_fx_host_coordinator.stop_illusion()
	_fx_host_coordinator.stop_awaken_aura()


func _update_skill_cooldowns(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	_magnetic_field_state.update_cooldown(step)
	_meditation_state.update_cooldown(step)
	_illusion_state.update_cooldown(step)


func _can_auto_activate_magnetic(context: Dictionary) -> bool:
	return _magnetic_field_state.can_auto_activate(
		bool(_meditation_state.get("meditation_active")),
		_is_serve_waiting(context)
	)


func _activate_magnetic(context: Dictionary, deps: Dictionary) -> void:
	if BossSkillParryGate.try_parry("ponk_magnetic_field", "자기역장", context, deps):
		_magnetic_field_state.consume_parried()
		boss_special_ready = false
		boss_special_gauge = 0.0
		return
	_magnetic_field_state.activate(
		_is_enraged(context),
		_ball_interaction_coordinator.get_boss_center(context),
		maxf(
			_ball_interaction_coordinator.get_base_ball_speed(context, deps),
			float(context.get("player_last_shot_speed", 0.0))
		)
	)
	boss_special_ready = false
	boss_special_gauge = 0.0
	_play_magnetic_audio(deps)


func _update_magnetic(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if not _magnetic_field_state.update(fps_scale):
		return
	_magnetic_projectile_state.spawn(
		_ball_interaction_coordinator.get_boss_center(context),
		float(_magnetic_field_state.get("magnetic_radius"))
	)
	_ball_interaction_coordinator.stop_magnetic_audio(deps)


func _activate_meditation(context: Dictionary, deps: Dictionary) -> void:
	_meditation_state.activate(
		_ball_interaction_coordinator.get_boss_center(context),
		_magnetic_field_state.get("magnetic_center")
	)
	_play_meditation_audio(deps)


func _update_meditation(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if not _meditation_state.update(
		fps_scale,
		_ball_interaction_coordinator.get_boss_center(context)
	):
		return
	_meditation_state.finish(_ball_interaction_coordinator.get_base_ball_speed(context, deps))
	_play_meditation_after_audio(deps)


func _is_live_stage_context(context: Dictionary) -> bool:
	return int(context.get("current_stage", STAGE_ID)) == STAGE_ID and not _is_inwang_context(context)


func _is_enraged(context: Dictionary) -> bool:
	return bool(context.get("enraged_boss_active", context.get("boss_enraged", false)))


func _is_serve_waiting(context: Dictionary) -> bool:
	return (
		bool(context.get("serve_wait_active", false))
		or bool(context.get("scoreboard_active", false))
		or bool(context.get("round_serve_prepare_active", false))
		or not bool(context.get("ball_active", true))
	)


func _is_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _is_inwang_context(context: Dictionary) -> bool:
	if bool(context.get("stage4_is_inwang", false)):
		return true
	for key in ["current_boss_name", "boss_name", "stage4_boss_name", "stage4_current_boss"]:
		var value := str(context.get(key, "")).strip_edges().to_lower()
		if value == "인왕" or value == "inwang":
			return true
	return false


func _play_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_magnetic_loop"):
		audio.play_stage4_magnetic_loop()


func _sync_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_stage4_magnetic_loop"):
		audio.sync_stage4_magnetic_loop(bool(_magnetic_field_state.get("magnetic_active")))


# 몽환포영 루프 동기(마그네틱 미러). update 말미에서 illusion_active로 게이트 —
# 물결이 뜨는 창(illusion_active)에만 최면 앰비언스 루프가 돈다. 별도 release
# 페이즈 없음(illusion_active가 곧 가시창).
func _sync_illusion_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_stage4_illusion_loop"):
		audio.sync_stage4_illusion_loop(bool(_illusion_state.get("illusion_active")))


func _stop_illusion_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_stage4_illusion_loop"):
		audio.stop_stage4_illusion_loop()


func _play_meditation_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_meditation"):
		audio.play_stage4_meditation()


func _play_meditation_after_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_meditation_after"):
		audio.play_stage4_meditation_after()
