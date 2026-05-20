extends SceneTree

const ActiveItemBrickWallActions := preload("res://scripts/items/active_item_brick_wall_actions.gd")
const ActiveItemBrickWallGeometry := preload("res://scripts/items/active_item_brick_wall_geometry.gd")
const ActiveItemBrickWallInstallation := preload("res://scripts/items/active_item_brick_wall_installation.gd")
const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectFeedback := preload("res://scripts/items/active_item_effect_feedback.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 700.0)
	var player_paddle_width := 100.0


class FakeMythicRuntime:
	extends RefCounted

	func get_brick_wall_width(_base_width: float) -> float:
		return 120.0


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, duration: float) -> void:
		shakes.append(Vector2(amount, duration))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_active_item() -> void:
		calls.append("play_active_item")


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_direct_brick_wall_actions()
	_verify_direct_brick_wall_action_rejections()
	_verify_controller_delegates_brick_wall_actions()

	if _failures.is_empty():
		print("active_item_brick_wall_actions_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_brick_wall_actions() -> void:
	seed(606)
	var target: Object = ActiveItemEffectController.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": FakeMythicRuntime.new(),
		"battle_feedback_state": feedback,
		"game_audio": audio,
	})

	_expect(_activate(target, FakeOwner.new(), false, registry), "Brick Wall actions should activate")
	_expect(target.brick_wall_installing, "Brick Wall actions should apply installing state")
	_expect(is_equal_approx(target.brick_wall_install_timer_frames, 30.0), "Brick Wall actions should apply install timer")
	_expect(is_equal_approx(target.brick_wall_install_initial_frames, 30.0), "Brick Wall actions should apply initial install timer")
	_expect(target.pending_brick_wall.get("rect", Rect2()) == Rect2(Vector2(90.0, 723.0), Vector2(120.0, 20.0)), "Brick Wall actions should use mythic-adjusted geometry")
	_expect(target.pending_brick_wall.get("gauge_center", Vector2.ZERO) == Vector2(150.0, 670.0), "Brick Wall actions should store install gauge center")
	_expect(target.brick_particles.size() == 8, "Brick Wall actions should spawn install particles")
	_expect(feedback.shakes == [Vector2(0.025, 0.85)], "Brick Wall actions should dispatch reference shake")
	_expect(audio.calls == ["play_active_item"], "Brick Wall actions should play active-item audio")


func _verify_direct_brick_wall_action_rejections() -> void:
	var installing_target: Object = ActiveItemEffectController.new()
	var installing_audio := FakeAudio.new()
	_expect(not _activate(installing_target, FakeOwner.new(), true, FakeRegistry.new({"game_audio": installing_audio})), "Brick Wall actions should reject while installing")
	_expect(not installing_target.brick_wall_installing, "installing rejection should not mutate target")
	_expect(installing_target.brick_particles.is_empty(), "installing rejection should not spawn particles")
	_expect(installing_audio.calls.is_empty(), "installing rejection should not play audio")

	var missing_owner_target: Object = ActiveItemEffectController.new()
	var missing_owner_audio := FakeAudio.new()
	_expect(not _activate(missing_owner_target, null, false, FakeRegistry.new({"game_audio": missing_owner_audio})), "Brick Wall actions should reject missing owner")
	_expect(not missing_owner_target.brick_wall_installing, "missing-owner rejection should not mutate target")
	_expect(missing_owner_target.brick_particles.is_empty(), "missing-owner rejection should not spawn particles")
	_expect(missing_owner_audio.calls.is_empty(), "missing-owner rejection should not play audio")


func _verify_controller_delegates_brick_wall_actions() -> void:
	seed(607)
	var controller: Object = ActiveItemEffectController.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": FakeMythicRuntime.new(),
		"battle_feedback_state": feedback,
		"game_audio": audio,
	})

	_expect(controller.activate_wall(FakeOwner.new(), registry), "controller should delegate Brick Wall activation")
	_expect(controller.brick_wall_installing, "controller delegated Brick Wall should install")
	_expect(is_equal_approx(controller.brick_wall_install_timer_frames, 30.0), "controller delegated Brick Wall should set timer")
	_expect(controller.pending_brick_wall.get("rect", Rect2()) == Rect2(Vector2(90.0, 723.0), Vector2(120.0, 20.0)), "controller delegated Brick Wall should preserve geometry")
	_expect(controller.pending_brick_wall.get("gauge_center", Vector2.ZERO) == Vector2(150.0, 670.0), "controller delegated Brick Wall should preserve gauge center")
	_expect(controller.brick_particles.size() == 8, "controller delegated Brick Wall should spawn install particles")
	_expect(feedback.shakes == [Vector2(0.025, 0.85)], "controller delegated Brick Wall should preserve feedback")
	_expect(audio.calls == ["play_active_item"], "controller delegated Brick Wall should preserve audio")


func _activate(target: Object, owner: Object, installing: bool, registry: Object) -> bool:
	return ActiveItemBrickWallActions.new().activate(
		target,
		owner,
		registry,
		installing,
		target.brick_particles,
		ActiveItemBrickWallGeometry.new(),
		ActiveItemBrickWallInstallation.new(),
		ActiveItemBrickWallParticles.new(),
		ActiveItemEffectStateApplier.new(),
		ActiveItemEffectFeedback.new()
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
