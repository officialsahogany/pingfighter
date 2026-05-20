extends SceneTree

const BattleSceneReadyLifecycle := preload("res://scripts/core/battle_scene_ready_lifecycle.gd")
const BattleSceneStartupController := preload("res://scripts/core/battle_scene_startup_controller.gd")

var _failures: Array[String] = []
var _fake_modules: Dictionary = {}


class FakeLogoIntro:
	extends RefCounted

	var begin_calls := 0
	var should_begin := true

	func begin(_owner: Node) -> bool:
		begin_calls += 1
		return should_begin


class FakeStartupSurface:
	extends RefCounted

	var apply_calls := 0
	var configure_calls := 0
	var consume_calls := 0
	var queue_redraw_calls := 0
	var skip_logo := false

	func _apply_selection_state(_owner: Object) -> void:
		apply_calls += 1

	func _configure_battle_window(_owner: Object, _module_getter: Callable) -> void:
		configure_calls += 1

	func _consume_skip_battle_logo_once(_owner: Object) -> bool:
		consume_calls += 1
		return skip_logo

	func _get_module(module_getter: Callable, key: String) -> Object:
		if not module_getter.is_valid():
			return null
		var value: Variant = module_getter.call(key)
		if typeof(value) == TYPE_OBJECT:
			return value as Object
		return null

	func _queue_redraw(_owner: Object) -> void:
		queue_redraw_calls += 1


class FakeReadyLifecycle:
	extends RefCounted

	var calls := 0

	func ready(_startup: Object, _owner: Node, _registry: Object, _module_getter: Callable, _callbacks: Dictionary) -> void:
		calls += 1


func _init() -> void:
	_verify_ready_lifecycle_starts_logo_intro()
	_verify_ready_lifecycle_respects_logo_skip()
	_verify_startup_controller_delegates_ready_surface()

	if _failures.is_empty():
		print("battle_scene_ready_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ready_lifecycle_starts_logo_intro() -> void:
	var lifecycle: Object = BattleSceneReadyLifecycle.new()
	var startup := FakeStartupSurface.new()
	var logo := FakeLogoIntro.new()
	var owner := Node.new()
	_fake_modules = {"penguin_logo_intro": logo}

	lifecycle.ready(startup, owner, null, Callable(self, "_get_fake_module"), {})

	_expect(startup.apply_calls == 1, "ready lifecycle should apply selection state")
	_expect(startup.configure_calls == 1, "ready lifecycle should configure battle window")
	_expect(startup.consume_calls == 1, "ready lifecycle should check logo skip")
	_expect(logo.begin_calls == 1, "ready lifecycle should begin logo intro when not skipped")
	_expect(startup.queue_redraw_calls == 1, "ready lifecycle should queue redraw after logo begin")
	owner.free()


func _verify_ready_lifecycle_respects_logo_skip() -> void:
	var lifecycle: Object = BattleSceneReadyLifecycle.new()
	var startup := FakeStartupSurface.new()
	var logo := FakeLogoIntro.new()
	var owner := Node.new()
	startup.skip_logo = true
	_fake_modules = {"penguin_logo_intro": logo}

	lifecycle.ready(startup, owner, null, Callable(self, "_get_fake_module"), {})

	_expect(logo.begin_calls == 0, "ready lifecycle should not begin logo intro when skip flag is consumed")
	_expect(startup.queue_redraw_calls == 1, "ready lifecycle should still queue redraw after skip")
	owner.free()


func _verify_startup_controller_delegates_ready_surface() -> void:
	var startup: Object = BattleSceneStartupController.new()
	var fake := FakeReadyLifecycle.new()
	var owner := Node.new()
	startup.ready_lifecycle = fake

	startup.ready(owner, null, Callable(self, "_get_fake_module"), {})

	_expect(fake.calls == 1, "startup controller should delegate ready to ready lifecycle")
	owner.free()


func _get_fake_module(key: String) -> Object:
	var value: Variant = _fake_modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
