extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemTimedPaddleEffects := preload("res://scripts/items/active_item_timed_paddle_effects.gd")
const ActiveItemEffectReset := preload("res://scripts/items/active_item_effect_reset.gd")
const RETIRED_ACTIVE_ITEM_TOKEN_RULES := [
	{"token": "hologram_disk", "case_sensitive": false},
	{"token": "HOLOGRAM_DISK", "case_sensitive": true},
	{"token": "ActiveItemHologramDiskRuntime", "case_sensitive": true},
	{"token": "hologram_decoy", "case_sensitive": false},
	{"token": "hologram_deception", "case_sensitive": false},
]
const RETIRED_ACTIVE_ITEM_PATHS := [
	"res://scripts/items/active_item_hologram_disk_runtime.gd",
	"res://scripts/items/active_item_hologram_disk_runtime.gd.uid",
	"res://assets/sprites/items/hologram_disk.png",
	"res://assets/sprites/items/hologram_disk.png.import",
	"res://tests/active_item_hologram_disk_smoke.gd.uid",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_hologram_disk_active_item_is_fully_removed()
	_verify_dynamic_reset_call_arity_contract()
	_verify_reset_helper_direct_application()
	_verify_controller_reset_delegates_clear_state()

	if _failures.is_empty():
		print("active_item_effect_controller_reset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hologram_disk_active_item_is_fully_removed() -> void:
	var runtime_files: Array[String] = []
	_collect_resource_files("res://scripts", ["gd"], runtime_files)
	_verify_files_exclude_retired_tokens(runtime_files, "production runtime")

	var scene_resource_files: Array[String] = []
	_collect_resource_files("res://", ["tscn", "tres"], scene_resource_files)
	_verify_files_exclude_retired_tokens(scene_resource_files, "scene/resource")

	for retired_path: String in RETIRED_ACTIVE_ITEM_PATHS:
		_expect(not FileAccess.file_exists(retired_path), "retired hologram active-item path must stay deleted: %s" % retired_path)


func _verify_files_exclude_retired_tokens(paths: Array[String], scope: String) -> void:
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		for rule: Dictionary in RETIRED_ACTIVE_ITEM_TOKEN_RULES:
			var token: String = str(rule.get("token", ""))
			var offset: int = source.find(token) if bool(rule.get("case_sensitive", false)) else source.findn(token)
			_expect(offset < 0, "%s must not reference retired active-item token %s: %s" % [scope, token, path])


func _collect_resource_files(path: String, extensions: Array[String], output: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_expect(directory != null, "removal seal must be able to scan %s" % path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var entry_path: String = path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_resource_files(entry_path, extensions, output)
			elif extensions.has(entry_name.get_extension().to_lower()):
				output.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _verify_dynamic_reset_call_arity_contract() -> void:
	var helper: Object = ActiveItemEffectReset.new()
	var helper_argument_count := Callable(helper, "apply").get_argument_count()
	var caller_argument_count := _count_controller_reset_apply_arguments()
	_expect(helper_argument_count == 10, "reset helper must expose the ten dependencies owned by the controller")
	_expect(
		caller_argument_count == helper_argument_count,
		"GRT-048: dynamic reset caller argument count must match the helper signature"
	)


func _verify_reset_helper_direct_application() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var helper: Object = ActiveItemTimedPaddleEffects.new()
	var reset_helper: Object = ActiveItemEffectReset.new()
	var default_center: Vector2 = helper.get_default_player_center()

	_dirty_every_effect_bucket(controller)
	reset_helper.call(
		"apply",
		controller,
		controller._state_applier,
		controller._aipill_runtime,
		controller._timed_paddle_effects,
		controller._stopwatch_runtime,
		controller._magnet_field_runtime,
		controller._holy_barrier_runtime,
		controller._dash_boost_runtime,
		controller._brick_wall_installation,
		controller._commando_supply_actions
	)

	_expect_reset_clean(controller, default_center)


func _verify_controller_reset_delegates_clear_state() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var helper: Object = ActiveItemTimedPaddleEffects.new()
	var default_center: Vector2 = helper.get_default_player_center()

	_dirty_every_effect_bucket(controller)
	controller.reset()

	_expect_reset_clean(controller, default_center)


func _expect_reset_clean(controller: Object, default_center: Vector2) -> void:
	_expect(controller.regeneration_potion_particles.is_empty(), "reset should clear regeneration potion particles")
	_expect(controller.regeneration_potion_rings.is_empty(), "reset should clear regeneration potion rings")
	_expect(controller.pickup_particles.is_empty(), "reset should clear pickup particles")
	_expect(controller.pickup_effect.is_empty(), "reset should clear pickup effect")

	_expect(not controller.aipill_active, "reset should clear AI Pill active state")
	_expect(is_equal_approx(controller.aipill_phase, 0.0), "reset should clear AI Pill phase")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 0.0), "reset should clear AI Pill flash")

	_expect(not controller.long_boost_active, "reset should clear long boost active state")
	_expect(is_equal_approx(controller.long_boost_timer_frames, 0.0), "reset should clear long boost timer")
	_expect(is_equal_approx(controller.long_boost_initial_timer_frames, 0.0), "reset should clear long boost initial timer")
	_expect(is_equal_approx(controller.long_boost_scale, 1.0), "reset should clear long boost scale")

	_expect(not controller.milk_bottle_active, "reset should clear milk bottle active state")
	_expect(is_equal_approx(controller.milk_bottle_scale, 1.0), "reset should clear milk bottle scale")

	_expect(not controller.vitamin_pill_active, "reset should clear vitamin pill active state")
	_expect(is_equal_approx(controller.vitamin_pill_timer_frames, 0.0), "reset should clear vitamin pill timer")
	_expect(is_equal_approx(controller.vitamin_pill_initial_timer_frames, 0.0), "reset should clear vitamin pill initial timer")
	_expect(is_equal_approx(controller.vitamin_pill_phase, 0.0), "reset should clear vitamin pill phase")
	_expect(is_equal_approx(controller.vitamin_pill_flash_timer_frames, 0.0), "reset should clear vitamin pill flash")
	_expect(controller.vitamin_pill_player_center == default_center, "reset should restore vitamin pill default center")

	_expect(not controller.strange_vial_active, "reset should clear strange vial active state")
	_expect(is_equal_approx(controller.strange_vial_timer_frames, 0.0), "reset should clear strange vial timer")
	_expect(str(controller.strange_vial_effect_type) == "", "reset should clear strange vial effect type")
	_expect(is_equal_approx(controller.strange_vial_scale, 1.0), "reset should clear strange vial scale")
	_expect(is_equal_approx(controller.strange_vial_speed_multiplier, 1.0), "reset should clear strange vial speed")
	_expect(controller.strange_vial_player_center == default_center, "reset should restore strange vial default center")

	_expect(not controller.stopwatch_active, "reset should clear stopwatch active state")
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 0.0), "reset should clear stopwatch timer")
	_expect(is_equal_approx(controller.stopwatch_initial_timer_frames, 0.0), "reset should clear stopwatch initial timer")
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 0.0), "reset should clear stopwatch recovery timer")
	_expect(controller.stopwatch_original_ball_vel == Vector2.ZERO, "reset should clear stopwatch original velocity")
	_expect(is_equal_approx(controller.stopwatch_flash_timer_frames, 0.0), "reset should clear stopwatch flash")
	_expect(is_equal_approx(controller.stopwatch_clock_angle, 0.0), "reset should clear stopwatch clock angle")

	_expect(not controller.magnet_field_active, "reset should clear magnet field active state")
	_expect(is_equal_approx(controller.magnet_field_timer_frames, 0.0), "reset should clear magnet field timer")
	_expect(is_equal_approx(controller.magnet_field_initial_timer_frames, 0.0), "reset should clear magnet field initial timer")
	_expect(is_equal_approx(controller.magnet_field_phase, 0.0), "reset should clear magnet field phase")
	_expect(controller.magnet_field_player_center == default_center, "reset should restore magnet field default center")
	_expect(is_equal_approx(controller.magnet_field_particle_accumulator_frames, 0.0), "reset should clear magnet field accumulator")
	_expect(controller.magnet_field_particles.is_empty(), "reset should clear magnet field particles")

	_expect(not controller.holy_barrier_active, "reset should clear holy barrier active state")
	_expect(is_equal_approx(controller.holy_barrier_timer_frames, 0.0), "reset should clear holy barrier timer")
	_expect(is_equal_approx(controller.holy_barrier_initial_timer_frames, 0.0), "reset should clear holy barrier initial timer")
	_expect(is_equal_approx(controller.holy_barrier_glow_phase, 0.0), "reset should clear holy barrier glow")
	_expect(is_equal_approx(controller.holy_barrier_particle_accumulator_frames, 0.0), "reset should clear holy barrier accumulator")
	_expect(controller.holy_barrier_particles.is_empty(), "reset should clear holy barrier particles")

	_expect(not controller.brick_wall_installing, "reset should clear brick installation state")
	_expect(is_equal_approx(controller.brick_wall_install_timer_frames, 0.0), "reset should clear brick installation timer")
	_expect(is_equal_approx(controller.brick_wall_install_initial_frames, 0.0), "reset should clear brick installation initial timer")
	_expect(controller.pending_brick_wall.is_empty(), "reset should clear pending brick wall")
	_expect(controller.brick_walls.is_empty(), "reset should clear placed brick walls")
	_expect(controller.brick_particles.is_empty(), "reset should clear brick particles")


func _dirty_every_effect_bucket(controller: Object) -> void:
	controller.regeneration_potion_particles.append({"alpha": 1.0})
	controller.regeneration_potion_rings.append({"radius": 4.0})
	controller.holy_barrier_particles.append({"alpha": 1.0})
	controller.pickup_particles.append({"alpha": 1.0})
	controller.pickup_effect = {"name": "test_item"}

	controller.aipill_active = true
	controller.aipill_phase = 2.0
	controller.aipill_flash_timer_frames = 3.0

	controller.long_boost_active = true
	controller.long_boost_timer_frames = 123.0
	controller.long_boost_initial_timer_frames = 480.0
	controller.long_boost_scale = 1.4

	controller.milk_bottle_active = true
	controller.milk_bottle_scale = 1.2

	controller.vitamin_pill_active = true
	controller.vitamin_pill_timer_frames = 234.0
	controller.vitamin_pill_initial_timer_frames = 600.0
	controller.vitamin_pill_phase = 5.0
	controller.vitamin_pill_flash_timer_frames = 7.0
	controller.vitamin_pill_player_center = Vector2(111.0, 222.0)

	controller.strange_vial_active = true
	controller.strange_vial_timer_frames = 345.0
	controller.strange_vial_initial_timer_frames = 600.0
	controller.strange_vial_effect_type = "enlarge"
	controller.strange_vial_scale = 2.2
	controller.strange_vial_target_scale = 2.2
	controller.strange_vial_speed_multiplier = 0.5
	controller.strange_vial_target_speed_multiplier = 0.5
	controller.strange_vial_phase = 6.0
	controller.strange_vial_flash_timer_frames = 8.0
	controller.strange_vial_player_center = Vector2(222.0, 333.0)

	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 120.0
	controller.stopwatch_initial_timer_frames = 180.0
	controller.stopwatch_recovery_timer_frames = 30.0
	controller.stopwatch_original_ball_vel = Vector2(10.0, -12.0)
	controller.stopwatch_flash_timer_frames = 4.0
	controller.stopwatch_clock_angle = 9.0

	controller.magnet_field_active = true
	controller.magnet_field_timer_frames = 300.0
	controller.magnet_field_initial_timer_frames = 420.0
	controller.magnet_field_phase = 1.5
	controller.magnet_field_player_center = Vector2(333.0, 444.0)
	controller.magnet_field_particle_accumulator_frames = 2.5
	controller.magnet_field_particles.append({"alpha": 1.0})

	controller.holy_barrier_active = true
	controller.holy_barrier_timer_frames = 240.0
	controller.holy_barrier_initial_timer_frames = 360.0
	controller.holy_barrier_glow_phase = 2.5
	controller.holy_barrier_particle_accumulator_frames = 4.5

	controller.brick_walls.append({"rect": Rect2(Vector2(1.0, 2.0), Vector2(3.0, 4.0))})
	controller.pending_brick_wall = {"rect": Rect2(Vector2(5.0, 6.0), Vector2(7.0, 8.0))}
	controller.brick_wall_installing = true
	controller.brick_wall_install_timer_frames = 10.0
	controller.brick_wall_install_initial_frames = 30.0
	controller.brick_particles.append({"alpha": 1.0})


func _count_controller_reset_apply_arguments() -> int:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_controller.gd")
	var marker := "\t_effect_reset.apply("
	var call_start := source.find(marker)
	_expect(call_start >= 0, "controller reset must call the effect-reset helper")
	if call_start < 0:
		return -1
	var depth := 1
	var comma_count := 0
	var has_argument := false
	var cursor := call_start + marker.length()
	while cursor < source.length():
		var character := source.substr(cursor, 1)
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return comma_count + 1 if has_argument else 0
		elif character == "," and depth == 1:
			comma_count += 1
		elif depth == 1 and not character.strip_edges().is_empty():
			has_argument = true
		cursor += 1
	_expect(false, "controller reset helper call must close its argument list")
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
