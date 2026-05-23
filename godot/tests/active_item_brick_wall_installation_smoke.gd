extends SceneTree

const ActiveItemBrickWallInstallation := preload("res://scripts/items/active_item_brick_wall_installation.gd")
const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 700.0)
	var player_paddle_width := 100.0


class FakeInstallTarget:
	extends RefCounted

	var brick_wall_installing := false
	var brick_wall_install_timer_frames := 0.0
	var brick_wall_install_initial_frames := 0.0
	var pending_brick_wall: Dictionary = {}


func _init() -> void:
	_verify_direct_installation_state()
	_verify_direct_installation_update_application()
	_verify_controller_delegates_installation_state()

	if _failures.is_empty():
		print("active_item_brick_wall_installation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_installation_state() -> void:
	var installation: Object = ActiveItemBrickWallInstallation.new()
	var wall_rect := Rect2(Vector2(100.0, 723.0), Vector2(80.0, 20.0))
	var gauge_center := Vector2(140.0, 670.0)

	var state: Dictionary = installation.start_installation(wall_rect, gauge_center)
	_expect(bool(state.get("installing", false)), "brick installation should start installing")
	_expect(is_equal_approx(float(state.get("timer_frames", 0.0)), 30.0), "brick installation should use reference install timer")
	var pending_wall: Dictionary = state.get("pending_wall", {})
	_expect(pending_wall.get("rect", Rect2()) == wall_rect, "brick installation should keep pending wall rect")
	_expect(pending_wall.get("gauge_center", Vector2.ZERO) == gauge_center, "brick installation should keep pending gauge center")
	_expect(int(pending_wall.get("visual_variant", -1)) >= 0 and int(pending_wall.get("visual_variant", -1)) < 8, "brick installation should assign a visual variant")

	state = installation.update_installation(true, 30.0, 30.0, pending_wall, 0.25)
	_expect(bool(state.get("installing", false)), "brick installation should continue before timer ends")
	_expect(is_equal_approx(float(state.get("timer_frames", 0.0)), 15.0), "brick installation should tick by fps scale")
	_expect(_get_dictionary(state, "completed_wall").is_empty(), "brick installation should not complete early")

	state = installation.update_installation(true, 1.0, 30.0, pending_wall, 1.0 / 60.0)
	_expect(not bool(state.get("installing", true)), "brick installation should stop when timer ends")
	_expect(_get_dictionary(state, "pending_wall").is_empty(), "brick installation should clear pending wall after completion")
	var completed_wall: Dictionary = _get_dictionary(state, "completed_wall")
	_expect(completed_wall.get("rect", Rect2()) == wall_rect, "brick installation should expose completed wall rect")
	_expect(completed_wall.get("visual_variant", -1) == pending_wall.get("visual_variant", -2), "completed brick wall should preserve its visual variant")
	_expect(not completed_wall.has("gauge_center"), "completed brick wall should drop install-only gauge center")

	var idle_state: Dictionary = installation.update_installation(false, 8.0, 30.0, pending_wall, 1.0 / 60.0)
	_expect(not bool(idle_state.get("installing", true)), "idle brick installation should stay inactive")
	_expect(is_equal_approx(float(idle_state.get("timer_frames", -1.0)), 0.0), "idle brick installation should reset timer")
	_expect(is_equal_approx(float(idle_state.get("initial_frames", -1.0)), 0.0), "idle brick installation should reset initial timer")


func _verify_direct_installation_update_application() -> void:
	seed(45)
	var installation: Object = ActiveItemBrickWallInstallation.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var particles_helper: Object = ActiveItemBrickWallParticles.new()
	var target := FakeInstallTarget.new()
	var wall_rect := Rect2(Vector2(180.0, 723.0), Vector2(80.0, 20.0))
	var pending_wall: Dictionary = {
		"rect": wall_rect,
		"hit_count": 0,
		"crack_level": 0,
		"gauge_center": Vector2(220.0, 670.0),
		"visual_variant": 5,
	}
	var brick_walls: Array[Dictionary] = []
	var particles: Array[Dictionary] = []

	target.brick_wall_installing = true
	target.brick_wall_install_timer_frames = 1.0
	target.brick_wall_install_initial_frames = 30.0
	target.pending_brick_wall = pending_wall
	installation.apply_update(
		target,
		target.brick_wall_installing,
		target.brick_wall_install_timer_frames,
		target.brick_wall_install_initial_frames,
		target.pending_brick_wall,
		brick_walls,
		particles,
		1.0 / 60.0,
		state_applier,
		particles_helper
	)

	_expect(not target.brick_wall_installing, "brick installation helper should apply inactive state after completion")
	_expect(target.pending_brick_wall.is_empty(), "brick installation helper should apply pending-wall cleanup")
	_expect(brick_walls.size() == 1, "brick installation helper should append completed wall")
	_expect(brick_walls[0].get("rect", Rect2()) == wall_rect, "brick installation helper should keep completed wall rect")
	_expect(int(brick_walls[0].get("visual_variant", -1)) == 5, "brick installation helper should preserve completed visual variant")
	_expect(not brick_walls[0].has("gauge_center"), "brick installation helper should drop install-only gauge center")
	_expect(particles.size() == 10, "brick installation helper should spawn install-complete particles")


func _verify_controller_delegates_installation_state() -> void:
	seed(44)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.activate_wall(owner, null), "controller should activate delegated wall installation")
	_expect(controller.brick_wall_installing, "controller should apply delegated installation active state")
	_expect(is_equal_approx(controller.brick_wall_install_timer_frames, 30.0), "controller should apply delegated install timer")
	_expect(controller.pending_brick_wall.get("gauge_center", Vector2.ZERO) == Vector2(150.0, 670.0), "controller should keep install gauge center while pending")
	var pending_variant: int = int(controller.pending_brick_wall.get("visual_variant", -1))
	_expect(pending_variant >= 0 and pending_variant < 8, "controller should assign a pending brick visual variant")
	_expect(controller.brick_particles.size() == 8, "controller should still spawn install particles")

	controller.brick_wall_install_timer_frames = 1.0
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.brick_wall_installing, "controller should clear installation after delegated completion")
	_expect(controller.pending_brick_wall.is_empty(), "controller should clear pending wall after delegated completion")
	_expect(controller.brick_walls.size() == 1, "controller should append completed brick wall")
	_expect(int(controller.brick_walls[0].get("visual_variant", -1)) == pending_variant, "controller completed wall should preserve visual variant")
	_expect(not controller.brick_walls[0].has("gauge_center"), "controller completed wall should not keep install gauge center")
	_expect(controller.brick_particles.size() == 18, "controller should still spawn install-complete particles")


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
