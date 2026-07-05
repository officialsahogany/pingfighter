extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowQuery := preload("res://scripts/items/active_item_throw_query.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_controller_delegates_visible_effect_queries()
	_verify_controller_delegates_actor_and_boss_contexts()
	_verify_query_reads_controller_constants()

	if _failures.is_empty():
		print("active_item_throw_query_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_controller_delegates_visible_effect_queries() -> void:
	var controller: Object = ActiveItemThrowController.new()
	_expect(not controller.has_visible_effects(), "fresh throw controller should report no visible effects")
	_expect(not controller.is_throw_windup_active(), "fresh throw controller should report no windup")
	_expect(not controller.has_actor_draw_context(), "fresh throw controller should report no actor draw context")
	_expect(controller.get_actor_draw_context().is_empty(), "fresh throw controller should skip empty actor draw context")

	var grenades: Array[Dictionary] = [{"position": Vector2(100.0, 100.0)}]
	controller.grenades = grenades
	_expect(controller.has_visible_effects(), "nonempty grenade list should report visible effects")
	_expect(controller.has_actor_draw_context(), "visible throw effects should report actor draw context")

	var pending_throws: Array[Dictionary] = [{
		"item_name": "grenade",
		"start_msec": Time.get_ticks_msec() - 100,
		"release_msec": Time.get_ticks_msec() + 500,
	}]
	var empty_grenades: Array[Dictionary] = []
	controller.grenades = empty_grenades
	controller.pending_throws = pending_throws
	_expect(controller.has_visible_effects(), "pending throw windup should report visible effects")
	_expect(controller.is_throw_windup_active(), "pending throw should report active windup")


func _verify_controller_delegates_actor_and_boss_contexts() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "flare",
		"start_msec": Time.get_ticks_msec() - 100,
		"release_msec": Time.get_ticks_msec() + 500,
	}]
	var molotov_fire_zones: Array[Dictionary] = [{"boss_in_fire": true}]
	controller.pending_throws = pending_throws
	controller.grenade_boss_stun_timer_frames = 12.0
	controller.grenade_boss_knockback_timer_frames = 5.0
	controller.grenade_boss_knockback_vel = -7.5
	controller.flare_boss_confused_timer_frames = 18.0
	controller.tear_gas_boss_pause_timer_frames = 3.0
	controller.tear_gas_boss_pause_text_timer_frames = 9.0
	controller.banana_boss_slip_timer_frames = controller.BANANA_SLIP_DURATION_FRAMES * 0.5
	controller.banana_boss_slip_direction = -1.0
	controller.soap_boss_slip_timer_frames = controller.SOAP_DEBUFF_DURATION_FRAMES * 0.25
	controller.spider_mine_slow_timer_frames = controller.SPIDER_MINE_SLOW_DURATION_FRAMES * 0.5
	controller.molotov_fire_zones = molotov_fire_zones

	var actor_context: Dictionary = controller.get_actor_draw_context()
	_expect(bool(actor_context.get("active_item_throw_windup_active", false)), "actor context should preserve throw windup active flag")
	_expect(str(actor_context.get("active_item_throw_windup_name", "")) == "flare", "actor context should preserve throw windup item name")
	_expect(bool(actor_context.get("active_item_boss_stun_active", false)), "actor context should expose boss stun")
	_expect(bool(actor_context.get("active_item_boss_tear_gas_pause_active", false)), "actor context should expose tear gas pause marker")
	_expect(bool(actor_context.get("active_item_boss_skill_cooldown_paused", false)), "actor context should mirror tear gas cooldown pause")
	_expect(is_equal_approx(float(actor_context.get("active_item_boss_banana_slip_ratio", 0.0)), 0.5), "actor context should compute banana slip ratio")
	_expect(is_equal_approx(float(actor_context.get("active_item_boss_soap_ratio", 0.0)), 0.25), "actor context should compute soap slip ratio")
	_expect(is_equal_approx(float(actor_context.get("active_item_boss_spider_slow_ratio", 0.0)), 0.5), "actor context should compute spider slow ratio")

	var boss_context: Dictionary = controller.get_boss_ai_context()
	_expect(bool(boss_context.get("active_item_grenade_stun_active", false)), "boss context should expose grenade stun")
	_expect(bool(boss_context.get("active_item_grenade_knockback_active", false)), "boss context should expose grenade knockback")
	_expect(is_equal_approx(float(boss_context.get("active_item_grenade_knockback_vel", 0.0)), -7.5), "boss context should preserve knockback velocity")
	_expect(bool(boss_context.get("active_item_flare_confusion_active", false)), "boss context should expose flare confusion")
	_expect(not bool(boss_context.get("active_item_molotov_slow_active", true)), "molotov slow should be inactive when no fire timer is running")
	_expect(is_equal_approx(float(boss_context.get("active_item_molotov_slow_factor", 0.0)), controller.MOLOTOV_FIRE_SLOW_FACTOR), "molotov slow factor should expose the configured 화염 감속 factor")
	_expect(bool(boss_context.get("active_item_boss_skill_cooldown_paused", false)), "boss context should expose tear gas cooldown pause")
	_expect(float(boss_context.get("active_item_banana_slip_speed", 0.0)) > controller.BANANA_SLIP_BASE_SPEED, "boss context should compute banana slip speed")


func _verify_query_reads_controller_constants() -> void:
	var query: Object = ActiveItemThrowQuery.new()
	var controller: Object = ActiveItemThrowController.new()
	controller.banana_boss_slip_timer_frames = controller.BANANA_SLIP_DURATION_FRAMES
	_expect(
		is_equal_approx(
			query.get_banana_slip_speed(controller),
			controller.BANANA_SLIP_BASE_SPEED + controller.BANANA_SLIP_DECAY_SPEED
		),
		"throw query should read controller timing constants"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
