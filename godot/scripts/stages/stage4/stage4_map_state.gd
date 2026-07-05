extends RefCounted

const STAGE_ID := 4
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BRAZIER_POSITION := Vector2(380.0, 570.0)
const BRAZIER_HITBOX := Rect2(340.0, 550.0, 80.0, 40.0)
const PLAYER_SCORE_DESTRUCTION_TRIGGER := 3

var brazier_lit := false
var destruction_pending_next_round := false
var phase2_bgm_started := false
var enraged_trigger_seen := false
var current_stage := STAGE_ID


func reset() -> void:
	brazier_lit = false
	destruction_pending_next_round = false
	phase2_bgm_started = false
	enraged_trigger_seen = false


func reset_round() -> void:
	brazier_lit = false


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	current_stage = int(context.get("current_stage", STAGE_ID))
	var destruction: Object = _get_destruction_event(deps)
	if destruction != null and destruction.has_method("update"):
		destruction.update(delta, context, deps)
	var event_context: Dictionary = context.duplicate()
	if destruction != null and destruction.has_method("get_snapshot"):
		event_context.merge(destruction.get_snapshot(), true)
	var moon_event: Object = _get_stage4_event(deps, "stage4_moon_event")
	if moon_event != null and moon_event.has_method("update"):
		moon_event.update(delta, event_context, deps)
	var ponk_skill_state: Object = _get_stage4_event(deps, "stage4_ponk_skill_state")
	if ponk_skill_state != null and ponk_skill_state.has_method("update"):
		ponk_skill_state.update(delta, event_context, deps)
	var bird_event: Object = _get_stage4_event(deps, "stage4_bird_event")
	if bird_event != null and bird_event.has_method("update"):
		bird_event.update(delta, context, deps)
	var monk_event: Object = _get_stage4_event(deps, "stage4_brazier_monk_event")
	if monk_event != null and monk_event.has_method("update"):
		monk_event.update(delta, get_draw_context(deps).merged(event_context, false), deps)
	if brazier_lit and monk_event != null and monk_event.has_method("consumed_smoke_monk_cycle") and bool(monk_event.consumed_smoke_monk_cycle()):
		brazier_lit = false
	if current_stage != STAGE_ID:
		return
	if bool(context.get("enraged_boss_active", false)):
		if not enraged_trigger_seen:
			enraged_trigger_seen = true
			start_destruction_animation("enraged", deps)
	else:
		enraged_trigger_seen = false


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if int(deps.get("current_stage", current_stage)) != STAGE_ID:
		return
	if scoring_side != "player":
		return
	var ponk_skill_state: Object = _get_stage4_event(deps, "stage4_ponk_skill_state")
	if ponk_skill_state != null and ponk_skill_state.has_method("handle_score_event"):
		ponk_skill_state.handle_score_event(scoring_side, score_result, deps)
	if _is_destruction_started(deps):
		return
	if int(score_result.get("player_score", 0)) == PLAYER_SCORE_DESTRUCTION_TRIGGER:
		destruction_pending_next_round = true


func handle_scoreboard_serve_prepare(deps: Dictionary = {}) -> bool:
	if int(deps.get("current_stage", current_stage)) != STAGE_ID:
		return false
	if not destruction_pending_next_round:
		return false
	destruction_pending_next_round = false
	return start_destruction_animation("score_next_round", deps)


func start_destruction_animation(reason: String = "", deps: Dictionary = {}) -> bool:
	var destruction: Object = _get_destruction_event(deps)
	if destruction == null or not destruction.has_method("start_destruction_animation"):
		return false
	var started: bool = bool(destruction.start_destruction_animation(reason))
	if started:
		_play_phase2_bgm(deps)
	return started


func is_destruction_animation_active(deps: Dictionary = {}) -> bool:
	var destruction: Object = _get_destruction_event(deps)
	return destruction != null and destruction.has_method("is_destruction_animation_active") and bool(destruction.is_destruction_animation_active())


func is_temple_destroyed(deps: Dictionary = {}) -> bool:
	var destruction: Object = _get_destruction_event(deps)
	return destruction != null and destruction.has_method("is_temple_destroyed") and bool(destruction.is_temple_destroyed())


func check_smoke_touches_brazier(smoke_x: float, smoke_y: float, smoke_radius: float, deps: Dictionary = {}) -> bool:
	if brazier_lit:
		return false
	var smoke_rect := Rect2(
		float(smoke_x) - float(smoke_radius),
		float(smoke_y) - float(smoke_radius),
		float(smoke_radius) * 2.0,
		float(smoke_radius) * 2.0
	)
	if smoke_rect.intersects(BRAZIER_HITBOX):
		brazier_lit = true
		_spawn_smoke_grenade_monks_from_brazier(deps)
		return true
	return false


func is_brazier_lit() -> bool:
	return brazier_lit


func get_brazier_position() -> Vector2:
	return BRAZIER_POSITION


func trigger_smoke_grenade_monk_return(deps: Dictionary = {}) -> int:
	var monk_event: Object = _get_stage4_event(deps, "stage4_brazier_monk_event")
	if monk_event != null and monk_event.has_method("trigger_smoke_grenade_monk_return"):
		return int(monk_event.trigger_smoke_grenade_monk_return())
	return 0


func get_draw_context(deps: Dictionary = {}) -> Dictionary:
	var result := {
		"stage4_brazier_lit": brazier_lit,
		"stage4_destruction_pending_next_round": destruction_pending_next_round,
		"stage4_phase2_bgm_started": phase2_bgm_started,
	}
	var destruction: Object = _get_destruction_event(deps)
	if destruction != null and destruction.has_method("get_snapshot"):
		result.merge(destruction.get_snapshot(), true)
	var moon_event: Object = _get_stage4_event(deps, "stage4_moon_event")
	if moon_event != null and moon_event.has_method("get_actor_draw_context"):
		result.merge(moon_event.get_actor_draw_context(), true)
	var ponk_skill_state: Object = _get_stage4_event(deps, "stage4_ponk_skill_state")
	if ponk_skill_state != null and ponk_skill_state.has_method("get_actor_draw_context"):
		result.merge(ponk_skill_state.get_actor_draw_context(), true)
	var bird_event: Object = _get_stage4_event(deps, "stage4_bird_event")
	if bird_event != null and bird_event.has_method("get_actor_draw_context"):
		result.merge(bird_event.get_actor_draw_context(), true)
	var monk_event: Object = _get_stage4_event(deps, "stage4_brazier_monk_event")
	if monk_event != null and monk_event.has_method("get_actor_draw_context"):
		result.merge(monk_event.get_actor_draw_context(), true)
	return result


func get_actor_draw_context(deps: Dictionary = {}) -> Dictionary:
	return get_draw_context(deps)


func get_hud_context(deps: Dictionary = {}) -> Dictionary:
	var destruction_active := is_destruction_animation_active(deps)
	var ponk_skill_state: Object = _get_stage4_event(deps, "stage4_ponk_skill_state")
	var hud_context: Dictionary = (
		ponk_skill_state.get_hud_context()
		if ponk_skill_state != null and ponk_skill_state.has_method("get_hud_context")
		else {
			"stage4_ponk_gauge_visible": true,
			"stage4_ponk_gauge_value": 0.0,
			"stage4_ponk_gauge_max": 500.0,
			"stage4_ponk_gauge_ready": false,
			"stage4_ponk_gauge_active": false,
		}
	)
	hud_context["stage4_ponk_gauge_active"] = bool(hud_context.get("stage4_ponk_gauge_active", false)) or destruction_active
	return hud_context


func _is_destruction_started(deps: Dictionary) -> bool:
	var destruction: Object = _get_destruction_event(deps)
	if destruction == null or not destruction.has_method("get_snapshot"):
		return false
	var snapshot: Dictionary = destruction.get_snapshot()
	return bool(snapshot.get("stage4_destruction_active", false)) or bool(snapshot.get("stage4_temple_destroyed", false))


func _get_destruction_event(deps: Dictionary) -> Object:
	var value: Variant = deps.get("stage4_temple_destruction_event", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return null


func _get_stage4_event(deps: Dictionary, key: String) -> Object:
	var value: Variant = deps.get(key, null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return null


func _spawn_smoke_grenade_monks_from_brazier(deps: Dictionary) -> void:
	var monk_event: Object = _get_stage4_event(deps, "stage4_brazier_monk_event")
	if monk_event != null and monk_event.has_method("spawn_smoke_grenade_monks_from_brazier"):
		monk_event.spawn_smoke_grenade_monks_from_brazier()


func _play_phase2_bgm(deps: Dictionary) -> void:
	if phase2_bgm_started:
		return
	phase2_bgm_started = true
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_bgm"):
		audio.play_bgm("stage4_phase2")
	elif audio != null and audio.has_method("play_stage4_phase2_bgm"):
		audio.play_stage4_phase2_bgm()
