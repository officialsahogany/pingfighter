extends SceneTree

# expect-zero-object-leaks
const BattleCombatShortcutInputRouter := preload(
	"res://scripts/core/battle_combat_shortcut_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeTooltipDriver:
	extends RefCounted

	var accept := true
	var cycle_count := 0

	func cycle_gamepad_tooltip(_owner: Object, _registry: Object) -> bool:
		cycle_count += 1
		return accept


class FakeCommandoInputReader:
	extends RefCounted

	var accept := true
	var switch_count := 0

	func handle_weapon_switch_event(
		_event: InputEvent,
		_owner: Object,
		_registry: Object
	) -> bool:
		switch_count += 1
		return accept


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_gamepad_tooltip_has_first_priority()
	_verify_arrow_space_shift_aliases()
	_verify_tooltip_refusal_falls_through_to_commando()
	_verify_commando_switch_success_and_refusal()
	_verify_source_ownership_and_order()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_combat_shortcut_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_gamepad_tooltip_has_first_priority() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var tooltip: FakeTooltipDriver = fixture["tooltip"]
	var commando: FakeCommandoInputReader = fixture["commando"]
	var owner := FakeOwner.new()
	_expect(
		BattleCombatShortcutInputRouter.new().handle_input(
			_joy_button(JOY_BUTTON_BACK), owner, null, Callable(holder, "get_module")
		),
		"gamepad Back must cycle the skill tooltip"
	)
	_expect(tooltip.cycle_count == 1, "tooltip driver must receive the Back event once")
	_expect(commando.switch_count == 0, "accepted tooltip input must stop Commando switching")
	_expect(owner.redraw_count == 1, "accepted tooltip cycle must redraw once")
	_clear_fixture(fixture)


func _verify_arrow_space_shift_aliases() -> void:
	for grip_style in ["space_arrows", "arrows-space", "ARROWS SPACE"]:
		var fixture := _build_fixture()
		var holder: ModuleHolder = fixture["holder"]
		var tooltip: FakeTooltipDriver = fixture["tooltip"]
		var owner := FakeOwner.new()
		owner.set_meta("tutorial_grip_style", grip_style)
		_expect(
			BattleCombatShortcutInputRouter.new().handle_input(
				_key_event(KEY_SHIFT), owner, null, Callable(holder, "get_module")
			),
			"Shift must cycle tooltips for normalized arrow-space grip '%s'" % grip_style
		)
		_expect(tooltip.cycle_count == 1, "normalized arrow-space grip must reach tooltip driver")
		_clear_fixture(fixture)


func _verify_tooltip_refusal_falls_through_to_commando() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var tooltip: FakeTooltipDriver = fixture["tooltip"]
	var commando: FakeCommandoInputReader = fixture["commando"]
	var owner := FakeOwner.new()
	tooltip.accept = false
	_expect(
		BattleCombatShortcutInputRouter.new().handle_input(
			_joy_button(JOY_BUTTON_BACK), owner, null, Callable(holder, "get_module")
		),
		"rejected tooltip cycle must fall through to Commando input"
	)
	_expect(tooltip.cycle_count == 1, "tooltip driver must receive the rejected event")
	_expect(commando.switch_count == 1, "Commando input must receive tooltip fallthrough")
	_expect(owner.redraw_count == 1, "accepted fallthrough must redraw only once")
	_clear_fixture(fixture)


func _verify_commando_switch_success_and_refusal() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var tooltip: FakeTooltipDriver = fixture["tooltip"]
	var commando: FakeCommandoInputReader = fixture["commando"]
	var owner := FakeOwner.new()
	var router := BattleCombatShortcutInputRouter.new()
	_expect(
		router.handle_input(
			_joy_button(JOY_BUTTON_LEFT_STICK), owner, null, Callable(holder, "get_module")
		),
		"accepted Commando weapon switch must consume input"
	)
	_expect(tooltip.cycle_count == 0 and commando.switch_count == 1, "L3 must route only to Commando switching")
	commando.accept = false
	_expect(
		not router.handle_input(
			_joy_button(JOY_BUTTON_LEFT_STICK), owner, null, Callable(holder, "get_module")
		),
		"rejected Commando switch must fall through"
	)
	_expect(owner.redraw_count == 1, "rejected Commando switch must not redraw")
	_clear_fixture(fixture)


func _verify_source_ownership_and_order() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_combat_shortcut_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	_expect(router_source.find("is_skill_tooltip_cycle_event") < router_source.find("handle_weapon_switch_event"), "skill tooltip routing must precede Commando switching")
	_expect(router_source.contains("cycle_gamepad_tooltip(owner, registry)"), "combat shortcut router must own tooltip-driver fanout")
	_expect(router_source.contains("tutorial_grip_style"), "combat shortcut router must own tutorial grip lookup")
	_expect(router_source.contains("junior_mika_grip_style"), "combat shortcut router must preserve junior Mika grip fallback")
	_expect(input_source.contains("BattleCombatShortcutInputRouter.new()"), "scene input controller must compose combat shortcut router")
	_expect(input_source.contains("_combat_shortcut_input_router.handle_input("), "scene input controller must delegate combat shortcuts once")
	_expect(input_source.find("_lingpet_input_router.handle_companion_input(") < input_source.find("_combat_shortcut_input_router.handle_input("), "companion input must stay above combat shortcuts")
	_expect(not input_source.contains("func _handle_skill_orb_tooltip_cycle"), "scene input controller must not retain tooltip cycle policy")
	_expect(not input_source.contains("func _handle_commando_weapon_switch"), "scene input controller must not retain Commando switch policy")
	_expect(not input_source.contains("func _normalize_grip_style"), "scene input controller must not retain grip normalization")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var tooltip := FakeTooltipDriver.new()
	var commando := FakeCommandoInputReader.new()
	holder.modules = {
		"battle_scene_skill_tooltip_driver": tooltip,
		"commando_input_reader": commando,
	}
	return {
		"holder": holder,
		"tooltip": tooltip,
		"commando": commando,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button_index
	return event


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
