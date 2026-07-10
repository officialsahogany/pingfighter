extends RefCounted

var _skill_orb_tooltip_pause_active := false
var _skill_orb_tooltip_pause_key := ""


func update(delta: float, deps: Dictionary, callbacks: Dictionary) -> void:
	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state != null and scoreboard_state.is_active():
		if _skill_orb_tooltip_pause_active:
			_call(callbacks, "resume_skill_cooldowns")
		_call(callbacks, "hide_skill_orb_tooltip_overlay")
		_clear_skill_orb_tooltip_pause()
		_call_delta(callbacks, "update_effects", delta)
		return

	if bool(deps.get("skill_orb_tooltip_active", false)):
		var tooltip_key := str(deps.get("skill_orb_tooltip_key", ""))
		if not _skill_orb_tooltip_pause_active:
			_call(callbacks, "pause_skill_cooldowns")
		_call(callbacks, "queue_skill_orb_tooltip_overlay_redraw")
		_skill_orb_tooltip_pause_active = true
		_skill_orb_tooltip_pause_key = tooltip_key
		return
	if _skill_orb_tooltip_pause_active:
		_call(callbacks, "resume_skill_cooldowns")
		_call(callbacks, "hide_skill_orb_tooltip_overlay")
	_clear_skill_orb_tooltip_pause()

	var stage3_boss_skill_state = deps.get("stage3_boss_skill_state", null)
	if (
		int(deps.get("current_stage", 1)) == 3
		and stage3_boss_skill_state != null
		and stage3_boss_skill_state.has_method("is_kuromi_awakening_active")
		and bool(stage3_boss_skill_state.is_kuromi_awakening_active())
	):
		_call_delta(callbacks, "update_effects", delta)
		_call(callbacks, "queue_redraw")
		return

	if _is_stage3_psychoball_hitstop_active(deps):
		_call_delta(callbacks, "update_effects", delta)
		_call(callbacks, "queue_redraw")
		return

	var power_state = deps.get("power_state", null)
	if power_state != null and power_state.is_freeze_active():
		_call_delta(callbacks, "update_ball", delta)
		_call_delta(callbacks, "update_effects", delta)
		_call(callbacks, "queue_redraw")
		return

	_call_delta(callbacks, "update_weather", delta)
	_call_delta(callbacks, "update_mythic_items", delta)
	# Mythic acquisition may close and synchronously open the deferred next
	# perk choice or Angel modal inside update_mythic_items(). Recheck the live
	# runtime state before allowing even one gameplay tick through that edge.
	if _is_mythic_pause_active(deps) or _is_runtime_perk_pause_active(deps):
		_call_delta(callbacks, "update_effects", delta)
		_call(callbacks, "queue_redraw")
		return

	_call_delta(callbacks, "update_player_control", delta)
	_call_delta(callbacks, "update_runtime_perk_resume", delta)
	_call_delta(callbacks, "update_active_items", delta)
	_call_delta(callbacks, "update_boss_ai", delta)

	var round_state = deps.get("round_state", null)
	if round_state != null and round_state.is_waiting_for_serve():
		var serve_flow_controller = deps.get("serve_flow_controller", null)
		if serve_flow_controller != null:
			serve_flow_controller.update(
				delta,
				_get_dictionary(deps, "serve_context"),
				{"round_state": round_state},
				callbacks
			)
		elif round_state.update_waiting(delta):
			_call(callbacks, "serve_ball")
	else:
		if not _is_stage3_kuromi_ball_hidden(deps):
			_call_delta(callbacks, "update_ball", delta)

	_call_delta(callbacks, "update_lingpet", delta)
	_call_delta(callbacks, "update_effects", delta)
	_call(callbacks, "queue_redraw")


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _call_delta(callbacks: Dictionary, key: String, delta: float) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call(delta)


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _is_mythic_pause_active(deps: Dictionary) -> bool:
	var mythic_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_runtime == null:
		return false
	if mythic_runtime.has_method("should_pause_game") and bool(mythic_runtime.should_pause_game()):
		return true
	if mythic_runtime.has_method("is_baal_boots_cinematic_active") and bool(mythic_runtime.is_baal_boots_cinematic_active()):
		return true
	return false


func _is_runtime_perk_pause_active(deps: Dictionary) -> bool:
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state == null:
		return false
	if runtime_perk_state.has_method("is_choice_active") and bool(runtime_perk_state.is_choice_active()):
		return true
	return (
		runtime_perk_state.has_method("is_angel_blessing_modal_active")
		and bool(runtime_perk_state.is_angel_blessing_modal_active())
	)


func _is_stage3_kuromi_ball_hidden(deps: Dictionary) -> bool:
	if int(deps.get("current_stage", 1)) != 3:
		return false
	var stage3_boss_skill_state = deps.get("stage3_boss_skill_state", null)
	return (
		stage3_boss_skill_state != null
		and stage3_boss_skill_state.has_method("is_kuromi_ball_hidden")
		and bool(stage3_boss_skill_state.is_kuromi_ball_hidden())
	)


func _is_stage3_psychoball_hitstop_active(deps: Dictionary) -> bool:
	if int(deps.get("current_stage", 1)) != 3:
		return false
	var stage3_boss_skill_state = deps.get("stage3_boss_skill_state", null)
	return (
		stage3_boss_skill_state != null
		and stage3_boss_skill_state.has_method("is_psychoball_hitstop_active")
		and bool(stage3_boss_skill_state.is_psychoball_hitstop_active())
	)


func _clear_skill_orb_tooltip_pause() -> void:
	_skill_orb_tooltip_pause_active = false
	_skill_orb_tooltip_pause_key = ""
