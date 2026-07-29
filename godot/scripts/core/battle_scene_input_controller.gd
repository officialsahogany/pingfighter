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

const FULLSCREEN_TOGGLE_KEY := BattleSystemShortcutInputRouter.FULLSCREEN_TOGGLE_KEY
const BGM_TOGGLE_KEY := BattleSystemShortcutInputRouter.BGM_TOGGLE_KEY
const FORCE_STAGE_CLEAR_KEY := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_KEY
const FORCE_STAGE_CLEAR_PLAYER_SCORE := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_PLAYER_SCORE
const FORCE_STAGE_CLEAR_BOSS_SCORE := BattlePreIntroStageInputRouter.FORCE_STAGE_CLEAR_BOSS_SCORE
const LINGPET_CYCLE_KEY := BattleLingpetInteractionInputRouter.LINGPET_CYCLE_KEY
const RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC := BattleSystemShortcutInputRouter.RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC

var _system_shortcut_input_router := BattleSystemShortcutInputRouter.new()
var _lingpet_input_router := BattleLingpetInteractionInputRouter.new()
var _terminal_input_router := BattleTerminalScreenInputRouter.new()
var _reward_modal_input_router := BattleRewardModalInputRouter.new()
var _combat_shortcut_input_router := BattleCombatShortcutInputRouter.new()
var _pre_intro_stage_input_router := BattlePreIntroStageInputRouter.new()


func handle_unhandled_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> void:
	if _system_shortcut_input_router.handle_input(event, owner, module_getter):
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
	if _handle_active_item_hud_input(event, owner, registry, module_getter, context):
		return
	if _lingpet_input_router.handle_companion_input(event, owner, registry, module_getter):
		return
	if _combat_shortcut_input_router.handle_input(event, owner, registry, module_getter):
		return


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
