extends RefCounted

const BattleSystemShortcutInputRouter := preload(
	"res://scripts/core/battle_system_shortcut_input_router.gd"
)
const BattleLingpetInteractionInputRouter := preload(
	"res://scripts/core/battle_lingpet_interaction_input_router.gd"
)
const BattleTerminalScreenInputRouter := preload(
	"res://scripts/core/battle_terminal_screen_input_router.gd"
)
const BattleRewardModalInputRouter := preload(
	"res://scripts/core/battle_reward_modal_input_router.gd"
)
const BattleCombatShortcutInputRouter := preload(
	"res://scripts/core/battle_combat_shortcut_input_router.gd"
)
const BattlePreIntroStageInputRouter := preload(
	"res://scripts/core/battle_pre_intro_stage_input_router.gd"
)
const BattleTowerMapOverlayInputRouter := preload(
	"res://scripts/core/battle_tower_map_overlay_input_router.gd"
)

const FULLSCREEN_TOGGLE_KEY := BattleSystemShortcutInputRouter.FULLSCREEN_TOGGLE_KEY
const BGM_TOGGLE_KEY := BattleSystemShortcutInputRouter.BGM_TOGGLE_KEY
const FORCE_STAGE_CLEAR_KEY := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_KEY
const FORCE_STAGE_CLEAR_PLAYER_SCORE := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_PLAYER_SCORE
const FORCE_STAGE_CLEAR_BOSS_SCORE := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_BOSS_SCORE
const RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC := BattleSystemShortcutInputRouter.RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC
const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0

var _system_shortcut_input_router := BattleSystemShortcutInputRouter.new()
var _lingpet_input_router := BattleLingpetInteractionInputRouter.new()
var _terminal_input_router := BattleTerminalScreenInputRouter.new()
var _reward_modal_input_router := BattleRewardModalInputRouter.new()
var _combat_shortcut_input_router := BattleCombatShortcutInputRouter.new()
var _pre_intro_stage_input_router := BattlePreIntroStageInputRouter.new()
var _tower_map_overlay_input_router := BattleTowerMapOverlayInputRouter.new()


func handle_unhandled_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> void:
	if _system_shortcut_input_router.handle_input(event, owner, module_getter):
		return
	if _handle_online_match_input(event, owner, registry, module_getter):
		return
	if _handle_victory_highlight_input(event, owner, module_getter):
		return
	if _handle_tower_ascent_flow_input(event, owner, registry, module_getter):
		return
	if _is_stage_transition_loading_active(module_getter):
		_queue_redraw(owner)
		_mark_handled(owner)
		return
	if _handle_mobile_touch_input(event, owner, module_getter, bool(context.get("mobile_touch_scene_ready", false))):
		return
	if _pre_intro_stage_input_router.handle_input(
		event,
		owner,
		registry,
		module_getter,
		context
	):
		return
	# 스테이지 7 프리배틀 영상 스킵은 intro/warmup 차단 조기 반환보다 먼저
	# 라우팅해야 실제로 도달한다 — 영상 재생 중엔 랜딩이 아직 시작 전이라
	# _is_intro_or_warmup_blocking이 true이기 때문.
	if _is_intro_or_warmup_blocking(module_getter, context):
		return
	var intro_input: Object = _get_intro_input_controller(module_getter)
	if intro_input != null and intro_input.has_method("handle_input"):
		if bool(intro_input.handle_input(event, owner, registry, module_getter, context)):
			return

	if _lingpet_input_router.handle_priority_cutin_input(event, owner, registry, module_getter):
		return
	if _terminal_input_router.handle_input(event, owner, registry, module_getter):
		return
	if _handle_runtime_perk_choice_input(event, owner, registry, module_getter):
		return
	if _reward_modal_input_router.handle_input(event, owner, registry, module_getter):
		return

	var overlay_input: Object = _get_overlay_input_controller(module_getter)
	if overlay_input != null and overlay_input.has_method("handle_input"):
		if bool(overlay_input.handle_input(event, owner, registry, module_getter, context)):
			return
	if _tower_map_overlay_input_router.handle_open_shortcut(event, owner, registry):
		return
	if _handle_active_item_hud_input(event, owner, registry, module_getter, context):
		return
	if _lingpet_input_router.handle_companion_input(event, owner, registry, module_getter):
		return
	if _combat_shortcut_input_router.handle_input(event, owner, registry, module_getter):
		return


func _handle_online_match_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var session: Object = _get_cached_module(registry, "online_match_session")
	var session_active := (
		session != null
		and session.has_method("is_active")
		and bool(session.is_active())
	)
	var runtime: Object = _get_cached_module(registry, "online_match_runtime")
	var runtime_active := (
		runtime != null
		and runtime.has_method("is_active")
		and bool(runtime.is_active())
	)
	if not session_active and not runtime_active:
		return false
	# Input singleton state is still collected once by OnlineMatchInputCollector
	# during the physics tick. Consuming the event here prevents every legacy
	# item, Lingpet, perk/modal, debug-combat, and pause route from mutating state.
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if (
			key_event.pressed
			and not key_event.echo
			and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE)
		):
			if runtime != null and runtime.has_method("stop"):
				runtime.stop()
			var match_flow: Object = _get_module(module_getter, "battle_scene_match_flow_driver")
			if match_flow != null and match_flow.has_method("exit_to_main_menu"):
				match_flow.exit_to_main_menu(owner)
	_mark_handled(owner)
	return true


func _get_cached_module(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _handle_victory_highlight_input(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	var playback: Object = _get_module(module_getter, "victory_highlight_playback_state")
	if (
		playback == null
		or not playback.has_method("is_active")
		or not bool(playback.is_active())
	):
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F9 or key_event.physical_keycode == KEY_F9:
			return false
	if playback.has_method("handle_input") and bool(playback.handle_input(event)):
		_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_tower_ascent_flow_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var flow_owner := _get_cached_module(registry, "tower_ascent_flow_owner")
	if (
		flow_owner == null
		or not flow_owner.has_method("is_active")
		or not bool(flow_owner.is_active())
	):
		return false
	if flow_owner.has_method("handle_input"):
		flow_owner.handle_input(_tower_event_in_playfield_coordinates(event, owner, module_getter))
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _tower_event_in_playfield_coordinates(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> InputEvent:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return event
	var screen_position := (
		(event as InputEventMouseButton).position
		if event is InputEventMouseButton
		else (event as InputEventScreenTouch).position
	)
	var layout := _build_tower_input_layout(owner, module_getter)
	var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var render_scale := maxf(0.001, float(layout.get("render_scale", 1.0)))
	var playfield_position := (screen_position - game_offset) / render_scale
	var localized := event.duplicate(true) as InputEvent
	if localized is InputEventMouseButton:
		(localized as InputEventMouseButton).position = playfield_position
		(localized as InputEventMouseButton).global_position = playfield_position
	elif localized is InputEventScreenTouch:
		(localized as InputEventScreenTouch).position = playfield_position
	return localized


func _build_tower_input_layout(owner: Object, module_getter: Callable) -> Dictionary:
	var view_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	if owner != null and owner.has_method("get_viewport_rect"):
		view_size = owner.get_viewport_rect().size
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout != null and view_layout.has_method("build_game_layout"):
		return view_layout.build_game_layout(view_size, GAME_WIDTH, GAME_HEIGHT)
	var game_size := Vector2(GAME_WIDTH, GAME_HEIGHT)
	return {
		"view_size": view_size,
		"game_offset": (view_size - game_size) * 0.5,
		"game_size": game_size,
		"render_scale": 1.0,
	}


func _handle_mobile_touch_input(event: InputEvent, owner: Object, module_getter: Callable, scene_ready: bool) -> bool:
	var mobile_touch: Object = _get_module(module_getter, "battle_mobile_touch_controller")
	if mobile_touch == null or not mobile_touch.has_method("handle_input"):
		return false
	return bool(mobile_touch.handle_input(event, owner, module_getter, scene_ready))


func _handle_active_item_hud_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	var interaction: Object = _get_module(module_getter, "active_item_hud_interaction")
	if interaction == null or not interaction.has_method("handle_input"):
		return false
	var handled: bool = bool(interaction.handle_input(
		event,
		owner,
		registry,
		module_getter,
		bool(context.get("battle_initialized", false))
	))
	if handled:
		_queue_redraw(owner)
		_mark_handled(owner)
	return handled


func _handle_runtime_perk_choice_input(event: InputEvent, owner: Object, registry: Object, module_getter: Callable) -> bool:
	if not _is_runtime_perk_choice_active(module_getter):
		return false
	var overlay_input: Object = _get_overlay_input_controller(module_getter)
	if overlay_input != null and overlay_input.has_method("handle_input"):
		overlay_input.handle_input(event, owner, registry, module_getter, {})
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_intro_or_warmup_blocking(module_getter: Callable, context: Dictionary) -> bool:
	var readiness: Object = _get_readiness_controller(module_getter)
	if readiness == null or not readiness.has_method("is_intro_or_warmup_blocking"):
		return true
	return bool(readiness.is_intro_or_warmup_blocking(
		module_getter,
		bool(context.get("battle_initialized", false)),
		bool(context.get("stage_landing_intro_started", false))
	))


func _is_stage_transition_loading_active(module_getter: Callable) -> bool:
	var match_event_driver: Object = _get_module(module_getter, "battle_scene_match_event_driver")
	return (
		match_event_driver != null
		and match_event_driver.has_method("is_stage_transition_loading_active")
		and bool(match_event_driver.is_stage_transition_loading_active())
	)


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	return (
		modal_gate != null
		and modal_gate.has_method("is_runtime_perk_choice_active")
		and bool(modal_gate.is_runtime_perk_choice_active(module_getter))
	)


func _get_readiness_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_readiness_controller")


func _get_intro_input_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_intro_input_controller")


func _get_overlay_input_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_overlay_input_controller")


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
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
