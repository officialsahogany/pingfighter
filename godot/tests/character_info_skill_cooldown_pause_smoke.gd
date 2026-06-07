extends SceneTree

const BattleSceneSkillTooltipDriver := preload("res://scripts/core/battle_scene_skill_tooltip_driver.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

var _failures: Array[String] = []
var _active_registry: Object = null


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var active_item_slots: Array = [{"name": "long_boost", "cooldown_msec": 10000, "last_use_msec": 1000}]

	func queue_redraw() -> void:
		pass

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeActiveItemRuntime:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0

	func pause_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		pause_calls += 1

	func resume_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		resume_calls += 1


class FakeRegistry:
	extends RefCounted

	var modal_gate: Object = BattleSceneModalGateController.new()
	var character_info: Object = CharacterInfoOverlay.new()
	var skill_tooltip_driver: Object = BattleSceneSkillTooltipDriver.new()
	var skill_state: Object = SmasherSkillState.new()
	var active_item_runtime: Object = FakeActiveItemRuntime.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_scene_modal_gate_controller":
				return modal_gate
			"character_info_overlay":
				return character_info
			"battle_scene_skill_tooltip_driver":
				return skill_tooltip_driver
			"smasher_skill_state":
				return skill_state
			"active_item_runtime":
				return active_item_runtime
		return null


func _init() -> void:
	_verify_character_info_pauses_wall_clock_skill_cooldowns()
	_verify_tab_input_opens_character_info_with_cooldown_pause()

	if _failures.is_empty():
		print("character_info_skill_cooldown_pause_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_info_pauses_wall_clock_skill_cooldowns() -> void:
	var overlay := CharacterInfoOverlay.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var skill_state: Object = registry.skill_state
	var cooldown_seconds := 10.0
	var start_msec: int = Time.get_ticks_msec()
	skill_state.trigger_cooldown("drive", start_msec, cooldown_seconds)

	_expect(
		is_equal_approx(float(skill_state.get_cooldown_remaining("drive", start_msec + 15000, cooldown_seconds)), 0.0),
		"unpaused wall-clock cooldown should expire in the far future"
	)

	overlay.open(owner, registry)
	var pause_started_msec: int = int(skill_state.get("cooldown_pause_started_msec"))
	_expect(pause_started_msec >= start_msec, "character info should pause the selected character skill state")
	_expect(
		float(skill_state.get_cooldown_remaining("drive", pause_started_msec + 15000, cooldown_seconds)) > 0.9,
		"paused character info cooldown should stay pinned even if wall-clock time advances"
	)
	_expect(registry.active_item_runtime.pause_calls == 1, "character info should pause active item cooldowns too")

	overlay.close()
	_expect(
		int(skill_state.get("cooldown_pause_started_msec")) == -1,
		"closing character info should resume paused skill cooldowns"
	)
	_expect(registry.active_item_runtime.resume_calls == 1, "closing character info should resume active item cooldowns too")


func _verify_tab_input_opens_character_info_with_cooldown_pause() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	_active_registry = registry
	var start_msec: int = Time.get_ticks_msec()
	registry.skill_state.trigger_cooldown("drive", start_msec, 10.0)

	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = KEY_TAB
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = KEY_TAB
	_expect(
		bool(input.handle_input(event, owner, registry, Callable(self, "_get_module"), {})),
		"TAB input should be handled by the overlay input controller"
	)
	_expect(bool(registry.character_info.is_active()), "TAB input should open character info")
	_expect(
		int(registry.skill_state.get("cooldown_pause_started_msec")) >= start_msec,
		"TAB input should pass owner and registry so character info pauses skill cooldowns"
	)
	_expect(registry.active_item_runtime.pause_calls == 1, "TAB input should pause active item cooldowns through character info")

	registry.character_info.close()
	_expect(registry.active_item_runtime.resume_calls == 1, "closing TAB character info should resume active item cooldowns")
	_active_registry = null


func _get_module(key: String) -> Object:
	if _active_registry == null:
		return null
	return _active_registry.get_instance(key)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
