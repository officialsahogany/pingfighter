extends SceneTree

const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemAdversityArmorRuntime := preload("res://scripts/items/mythic_item_adversity_armor_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {}

	func _init() -> void:
		values["player_pos"] = Vector2(302.5, 690.0)
		values["player_paddle_width"] = 155.0
		values["player_paddle_height"] = 50.0

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakeRoundState:
	extends RefCounted

	func begin_serve(_msec: int) -> void:
		pass

	func does_player_serve() -> bool:
		return true


class FakeBallRoundState:
	extends RefCounted

	func build_serve_snapshot(
		_player_is_serving: bool,
		_player_pos: Vector2,
		_boss_pos: Vector2,
		_player_y: float,
		_boss_y: float,
		_player_paddle_width: float,
		_boss_paddle_width: float,
		_boss_hitbox_height: float,
		_ball_size: float,
		_serve_ball_offset: float,
		_ball_physics: Object
	) -> Dictionary:
		return {
			"ball_active": true,
			"ball_pos": Vector2(380.0, 700.0),
			"ball_vel": Vector2(0.0, -10.0),
			"ball_impact_boost": 1.0,
			"ball_boost_decay_rate": 0.975,
			"ball_min_boost": 0.70,
		}


class FakeBallPhysics:
	extends RefCounted

	func compute_serve_launch_impact_boost(velocity: Vector2) -> Dictionary:
		return {
			"boost": velocity.length() / 10.0,
			"decay_rate": 0.91,
			"min_boost": 0.62,
		}


class SnapshotReceiver:
	extends RefCounted

	var snapshot: Dictionary = {}

	func apply(snapshot_value: Dictionary) -> void:
		snapshot = snapshot_value


var _failures: Array[String] = []


func _init() -> void:
	seed(7)
	_verify_runtime_constant_ownership()
	_verify_catalog()
	_verify_runtime_flow()
	_verify_ball_collision_and_serve_bonus()
	_verify_timer_gauge_layout()

	if _failures.is_empty():
		print("adversity_armor_port_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_constant_ownership() -> void:
	var helper: Object = MythicItemAdversityArmorRuntime.new()
	_expect(is_equal_approx(helper.get_barrier_y(), 732.0), "Adversity Armor helper should own barrier y")
	_expect(MythicItemAdversityArmorRuntime.BARRIER_PARTICLE_MAX == 72, "Adversity Armor helper should own barrier particle cap")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_adversity_armor_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "adversity armor helper source should be readable")
	_expect(not runtime_source.contains("ADVERSITY_ARMOR_CONSTANTS"), "runtime facade should not regain ADVERSITY_ARMOR_CONSTANTS")
	_expect(not runtime_source.contains("const ADVERSITY_ARMOR_MAX"), "runtime facade should not regain Adversity Armor cap constants")
	_expect(not runtime_source.contains("const ADVERSITY_ARMOR_FLASH"), "runtime facade should not regain Adversity Armor flash constants")
	_expect(not runtime_source.contains("const ADVERSITY_ARMOR_BARRIER"), "runtime facade should not regain Adversity Armor barrier constants")
	_expect(runtime_source.find("return adversity_armor_runtime.is_equipped(self)") >= 0, "runtime facade should delegate Adversity Armor equipped checks")
	_expect(runtime_source.find("return adversity_armor_runtime.get_trigger_chance_pct(self)") >= 0, "runtime facade should delegate Adversity Armor chance rolls")
	_expect(runtime_source.find("roll_query.get_equipped_roll_value(self, ITEM_ADVERSITY_ARMOR") < 0, "runtime facade should not keep Adversity Armor roll math inline")
	_expect(helper_source.contains("const DEFAULT_SERVE_SPEED_BONUS_PCT"), "Adversity Armor helper should keep serve-speed constants")
	_expect(helper_source.find("func get_trigger_chance_pct(") >= 0, "Adversity Armor helper should own trigger roll math")
	_expect(helper_source.find("func get_invincible_duration_sec(") >= 0, "Adversity Armor helper should own duration roll math")


func _verify_catalog() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("adversity_armor")
	_expect(not item_data.is_empty(), "adversity armor should build from catalog")
	_expect(str(item_data.get("display_name", "")) == "역경의 갑옷", "adversity armor should keep Korean display name")
	_expect(str(item_data.get("slot", "")) == "top", "adversity armor should occupy top slot")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "adversity armor icon should load")
	var roll_options: Array = catalog.get_roll_options("adversity_armor")
	_expect(roll_options.size() == 2, "adversity armor should expose two roll options")
	_expect(_has_roll_option(roll_options, "trigger_chance_pct", 20.0, 30.0), "trigger chance roll should match Python reference")
	_expect(_has_roll_option(roll_options, "invincible_duration_sec", 8.0, 15.0), "duration roll should match Python reference")
	_expect(_field_spawn_has(catalog, "adversity_armor"), "adversity armor should be in the field spawn pool")


func _verify_runtime_flow() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	_expect(runtime.equip_item("adversity_armor", owner, registry, {
		"trigger_chance_pct": 100.0,
		"invincible_duration_sec": 8.0,
	}, false), "adversity armor should equip")
	_expect(runtime.is_adversity_armor_equipped(), "runtime should report equipped adversity armor")
	_expect(bool(owner.values.get("adversity_armor_equipped", false)), "owner sync should expose equipped state")

	_expect(runtime.try_queue_adversity_armor_after_loss({"owner": owner, "registry": registry}), "100% roll should queue the next-round shield")
	_expect(runtime.adversity_armor_pending_invincible, "loss proc should mark pending invincibility")
	_expect(runtime.adversity_armor_serve_speed_boost_pending, "loss proc should arm serve speed boost")
	runtime.reset_round(registry)
	_expect(runtime.adversity_armor_pending_invincible, "round reset should preserve pending next-round shield")
	_expect(not runtime.is_adversity_armor_invincible(), "round reset should clear current invincibility before activation")
	runtime.on_round_start(owner, registry)
	_expect(not runtime.adversity_armor_pending_invincible, "round start should consume pending shield")
	_expect(runtime.is_adversity_armor_invincible(), "round start should activate invincibility")
	_expect(is_equal_approx(runtime.adversity_armor_invincible_timer_frames, 480.0), "8s duration should become 480 frames")
	_expect(runtime.get_ball_collision_context().get("adversity_armor_invincible", false), "active armor should expose ball collision context")
	runtime.notify_adversity_armor_barrier_hit(Vector2(380.0, 732.0), Vector2(0.0, 12.0), {"owner": owner, "registry": registry})
	_expect(not runtime.adversity_armor_barrier_particles.is_empty(), "barrier hit should spawn visual particles")


func _verify_ball_collision_and_serve_bonus() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	runtime.equip_item("adversity_armor", owner, registry, {
		"trigger_chance_pct": 100.0,
		"invincible_duration_sec": 8.0,
	}, false)
	runtime.try_queue_adversity_armor_after_loss({"owner": owner, "registry": registry})
	runtime.on_round_start(owner, registry)

	var stepper: Object = BallMotionStepper.new()
	var step_result: Dictionary = stepper.step(
		Vector2(380.0, 730.0),
		Vector2(0.0, 8.0),
		Vector2(0.0, 8.0),
		{
			"ball_size": 28.6,
			"width": 760.0,
			"height": 750.0,
			"adversity_armor_invincible": true,
			"adversity_armor_barrier_y": 732.0,
		}
	)
	_expect(str(step_result.get("event", "")) == "adversity_armor", "active armor should intercept bottom score motion")

	var receiver := SnapshotReceiver.new()
	var round_controller: Object = BallRoundController.new()
	round_controller.serve_ball({
		"current_msec": 100,
		"player_pos": Vector2(302.5, 690.0),
		"boss_pos": Vector2(330.0, 25.0),
		"player_y": 690.0,
		"boss_y": 25.0,
		"player_paddle_width": 155.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_size": 28.6,
		"ball_render_radius": 14.3,
	}, {
		"round_state": FakeRoundState.new(),
		"ball_round_state": FakeBallRoundState.new(),
		"ball_physics": FakeBallPhysics.new(),
		"mythic_item_runtime": runtime,
	}, {
		"apply_ball_snapshot": Callable(receiver, "apply"),
	})
	_expect(is_equal_approx(_get_vector2(receiver.snapshot.get("ball_vel", Vector2.ZERO)).length(), 12.0), "next player serve should consume the 20% speed boost")
	_expect(not runtime.adversity_armor_serve_speed_boost_pending, "serve boost should be one-shot")
	_expect(is_equal_approx(float(receiver.snapshot.get("ball_impact_boost", 0.0)), 1.2), "serve launch boost should be recomputed from boosted velocity")


func _verify_timer_gauge_layout() -> void:
	var field_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_field_effect_renderer.gd")
	var armor_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_armor_field_renderer.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(field_source != "", "mythic field renderer source should be readable")
	_expect(armor_source != "", "mythic armor field renderer source should be readable")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(drawer_source != "", "playfield drawer source should be readable")
	_expect(
		armor_source.find("Vector2(285.0, barrier_y - 28.0)") < 0,
		"adversity armor timer gauge should not be anchored at the playfield center"
	)
	_expect(
		armor_source.find("timer_stack.claim(timer_stack_key, true)") >= 0,
		"adversity armor timer gauge should use the shared horizontal timer stack"
	)
	_expect(
		armor_source.find("_get_adversity_armor_timer_bar_position") >= 0,
		"adversity armor timer gauge should use the right-bottom timer-bar position helper"
	)
	_expect(
		field_source.find("_armor_field_renderer.draw_adversity_armor_effect") >= 0
		and field_source.find("timer_stack,") >= 0
		and armor_source.find("_draw_adversity_armor_timer_gauge(") >= 0,
		"mythic field renderer should pass the timer stack into the adversity armor timer gauge"
	)
	_expect(
		drawer_source.find("_mythic_draw_field_effects_uses_timer_stack") >= 0,
		"playfield drawer should route the shared timer stack into mythic field effects"
	)


func _has_roll_option(options: Array, key: String, expected_min: float, expected_max: float) -> bool:
	for option_value in options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("key", "")) != key:
			continue
		return (
			is_equal_approx(float(option.get("min", 0.0)), expected_min)
			and is_equal_approx(float(option.get("max", 0.0)), expected_max)
		)
	return false


func _field_spawn_has(catalog: Object, item_name: String) -> bool:
	for item_value in catalog.get_field_spawn_items():
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return true
	return false


func _get_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
