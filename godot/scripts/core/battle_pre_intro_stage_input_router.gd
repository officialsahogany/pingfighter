extends RefCounted

const FORCE_STAGE_CLEAR_KEY := KEY_F9
const FORCE_STAGE_CLEAR_PLAYER_SCORE := 5
const FORCE_STAGE_CLEAR_BOSS_SCORE := 0


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	if _handle_force_stage_clear_shortcut(event, owner, registry, module_getter, context):
		return true
	return _handle_stage7_prebattle_input(event, owner, registry, module_getter)


func _handle_force_stage_clear_shortcut(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	if not _is_key_pressed(event, FORCE_STAGE_CLEAR_KEY):
		return false
	if not bool(context.get("battle_initialized", false)):
		return false
	if not bool(context.get("stage_landing_intro_started", false)):
		return false

	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if (
		result_screen != null
		and result_screen.has_method("is_active")
		and bool(result_screen.is_active())
	):
		_mark_handled(owner)
		return true

	_reset_victory_loot_phase(owner, registry, module_getter)
	_force_player_stage_clear_score(registry, module_getter)
	_start_debug_scoreboard_snapshot(registry, module_getter)
	if result_screen != null and result_screen.has_method("show_from_scoreboard"):
		var reset_callback: Callable = context.get("reset_game_after_stage_clear", Callable())
		var exit_callback: Callable = context.get("exit_to_menu_after_stage_clear", Callable())
		result_screen.show_from_scoreboard(
			owner,
			registry,
			reset_callback,
			exit_callback
		)

	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_stage7_prebattle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var presentation: Object = _get_module(
		module_getter,
		"stage7_akamu_prebattle_presentation"
	)
	if presentation == null:
		presentation = _get_instance(
			registry,
			"stage7_akamu_prebattle_presentation"
		)
	if (
		presentation == null
		or not presentation.has_method("is_active")
		or not bool(presentation.is_active())
	):
		return false
	# The video owns the whole prebattle beat. Local input may ignore an event,
	# but the event must never leak into battle controls while the video is live.
	if (
		presentation.has_method("handle_input")
		and bool(presentation.handle_input(event, owner, registry))
	):
		_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _reset_victory_loot_phase(
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	# F9는 결과화면을 직접 열므로, 진행 중이던 승리 전리품 페이즈를 정리하지
	# 않으면 결과화면 물리 게이트 뒤에 활성 상태로 얼어붙었다가 다음 스테이지
	# 프레임 플로우를 하이재킹한다.
	var loot_state: Object = _get_module(module_getter, "victory_loot_phase_state")
	if loot_state == null:
		loot_state = _get_instance(registry, "victory_loot_phase_state")
	if loot_state != null and loot_state.has_method("reset"):
		loot_state.reset(owner)
	var game_audio: Object = _get_instance(registry, "game_audio")
	if game_audio != null and game_audio.has_method("stop_stage2_quake_loop"):
		game_audio.stop_stage2_quake_loop()


func _force_player_stage_clear_score(
	registry: Object,
	module_getter: Callable
) -> void:
	var score_state: Object = _get_module(module_getter, "match_score_state")
	if score_state == null:
		score_state = _get_instance(registry, "match_score_state")
	if score_state == null:
		return
	if score_state.has_method("force_score"):
		score_state.force_score(
			FORCE_STAGE_CLEAR_PLAYER_SCORE,
			FORCE_STAGE_CLEAR_BOSS_SCORE
		)
		return
	score_state.set("player_score", FORCE_STAGE_CLEAR_PLAYER_SCORE)
	score_state.set("boss_score", FORCE_STAGE_CLEAR_BOSS_SCORE)
	score_state.set("deuce_mode", false)


func _start_debug_scoreboard_snapshot(
	registry: Object,
	module_getter: Callable
) -> void:
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	if scoreboard_state == null:
		scoreboard_state = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("start"):
		scoreboard_state.start(
			FORCE_STAGE_CLEAR_PLAYER_SCORE,
			FORCE_STAGE_CLEAR_BOSS_SCORE,
			true,
			"player"
		)


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
