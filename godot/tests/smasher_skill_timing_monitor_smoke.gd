extends SceneTree

const BattleDrawBannerContext := preload("res://scripts/core/battle_draw_banner_context.gd")
const SmasherSkillTimingMonitorRenderer := preload("res://scripts/characters/smasher_skill_timing_monitor_renderer.gd")

var _failures: Array[String] = []


class FakeSkillConfig:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"skill_costs": {
				"drive": 150.0,
				"power_smashing": 300.0,
			},
		}


class FakeSkillState:
	extends RefCounted

	var cooldowns: Dictionary = {}

	func _init(initial_cooldowns: Dictionary = {}) -> void:
		cooldowns = initial_cooldowns.duplicate(true)

	func get_configured_cooldown_remaining(skill_name: String, _current_msec: int, _skill_config: Object) -> float:
		return float(cooldowns.get(skill_name, 0.0))


class FakeDriveInputState:
	extends RefCounted

	var blocked := false

	func _init(is_blocked: bool = false) -> void:
		blocked = is_blocked

	func is_frame_cooldown_blocked() -> bool:
		return blocked


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false


func _init() -> void:
	_verify_banner_context_exposes_ready_state()
	_verify_drive_monitor_requires_ready_drive()
	_verify_power_monitor_requires_ready_power()
	_verify_frame_cooldown_hides_monitor()

	if _failures.is_empty():
		print("smasher_skill_timing_monitor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_banner_context_exposes_ready_state() -> void:
	var builder: Object = BattleDrawBannerContext.new()
	var context: Dictionary = _base_context(200.0, Vector2(377.5, 650.0))
	var banner_context: Dictionary = builder.build(
		context,
		{
			"skill_config": FakeSkillConfig.new(),
			"skill_state": FakeSkillState.new({"drive": 0.4}),
			"drive_input_state": FakeDriveInputState.new(true),
			"round_state": FakeRoundState.new(),
		}
	)

	_expect(str(banner_context.get("selected_character_type", "")) == "smasher", "banner context should carry selected character")
	_expect(is_equal_approx(float(banner_context.get("drive_gauge_cost", 0.0)), 150.0), "banner context should expose Drive gauge cost")
	_expect(is_equal_approx(float(banner_context.get("drive_cooldown_remaining", 0.0)), 0.4), "banner context should expose Drive cooldown ratio")
	_expect(bool(banner_context.get("drive_frame_cooldown_blocked", false)), "banner context should expose frame cooldown lockout")
	_expect(not bool(banner_context.get("waiting_for_serve", true)), "fake round state should mark play as active")


func _verify_drive_monitor_requires_ready_drive() -> void:
	var renderer: Object = SmasherSkillTimingMonitorRenderer.new()
	var low_gauge: Dictionary = renderer._build_monitor_state(_base_context(149.0, Vector2(377.5, 650.0)))
	_expect(not bool(low_gauge.get("active", false)), "Drive monitor should hide below Drive gauge cost")

	var on_cooldown_context: Dictionary = _base_context(200.0, Vector2(377.5, 650.0))
	on_cooldown_context["drive_cooldown_remaining"] = 0.5
	var on_cooldown: Dictionary = renderer._build_monitor_state(on_cooldown_context)
	_expect(not bool(on_cooldown.get("active", false)), "Drive monitor should hide while Drive cooldown remains")

	var ready: Dictionary = renderer._build_monitor_state(_base_context(200.0, Vector2(377.5, 650.0)))
	_expect(bool(ready.get("active", false)), "Drive monitor should show when Drive is ready and the ball is in range")
	_expect(str(ready.get("text", "")) == "Drive!", "ready Drive monitor should use Drive text")


func _verify_power_monitor_requires_ready_power() -> void:
	var renderer: Object = SmasherSkillTimingMonitorRenderer.new()
	var ready_power_context: Dictionary = _base_context(320.0, Vector2(377.5, 690.0))
	var ready_power: Dictionary = renderer._build_monitor_state(ready_power_context)
	_expect(bool(ready_power.get("active", false)), "Power monitor should show when Power Smashing is ready and in input range")
	_expect(str(ready_power.get("text", "")) == "SMASHING", "ready Power monitor should use SMASHING text")

	var power_cooling_context: Dictionary = _base_context(320.0, Vector2(377.5, 650.0))
	power_cooling_context["power_smash_cooldown_remaining"] = 0.5
	var power_cooling: Dictionary = renderer._build_monitor_state(power_cooling_context)
	_expect(bool(power_cooling.get("active", false)), "Power cooldown should still allow the Drive monitor when Drive is ready")
	_expect(str(power_cooling.get("text", "")) == "Drive!", "Power cooldown fallback should show Drive text")


func _verify_frame_cooldown_hides_monitor() -> void:
	var renderer: Object = SmasherSkillTimingMonitorRenderer.new()
	var context: Dictionary = _base_context(320.0, Vector2(377.5, 690.0))
	context["drive_frame_cooldown_blocked"] = true
	var state: Dictionary = renderer._build_monitor_state(context)
	_expect(not bool(state.get("active", false)), "shared frame cooldown lockout should hide the timing monitor")

	context["drive_frame_cooldown_blocked"] = false
	context["selected_character_type"] = "viper"
	state = renderer._build_monitor_state(context)
	_expect(not bool(state.get("active", false)), "Smasher timing monitor should hide for non-Smasher characters")


func _base_context(gauge: float, ball_pos: Vector2) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"waiting_for_serve": false,
		"ball_active": true,
		"ball_pos": ball_pos,
		"ball_vel": Vector2(0.0, 10.0),
		"ball_render_radius": 26.6175,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"special_gauge": gauge,
		"drive_gauge_cost": 150.0,
		"power_smash_gauge_cost": 300.0,
		"drive_cooldown_remaining": 0.0,
		"power_smash_cooldown_remaining": 0.0,
		"drive_frame_cooldown_blocked": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
