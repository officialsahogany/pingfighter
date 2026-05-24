extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_shell_casing_state()
	_verify_runtime_delegates_shell_casing_state()

	if _failures.is_empty():
		print("commando_firearm_shell_casing_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_shell_casing_state() -> void:
	var ak47_shell: Dictionary = CommandoFirearmShellCasingState.build_ak47_shell(
		Vector2(100.0, 200.0),
		Vector2.UP,
		{"player_pos": Vector2(90.0, 600.0), "paddle_height": 40.0},
		7,
		750.0,
		180.0
	)
	_expect(str(ak47_shell.get("weapon_id", "")) == "ak47", "AK-47 shell should preserve weapon id")
	_expect(ak47_shell.get("pos", Vector2.ZERO) == Vector2(111.0, 194.0), "AK-47 shell should preserve side eject offset")
	_expect(is_equal_approx(float(ak47_shell.get("floor_y", 0.0)), 645.0), "AK-47 shell should preserve floor clamp")
	_expect(is_equal_approx(float(ak47_shell.get("lifetime_frames", 0.0)), 180.0), "AK-47 shell should preserve configured lifetime")

	var zero_direction_shell: Dictionary = CommandoFirearmShellCasingState.build_pistol_shell(
		Vector2(100.0, 200.0),
		Vector2.ZERO,
		{},
		0,
		"commando_pistol",
		750.0,
		150.0
	)
	_expect(zero_direction_shell.get("pos", Vector2.ZERO) == Vector2(100.0, 197.0), "zero direction shell should preserve legacy no-side-offset spawn")
	_expect(int(zero_direction_shell.get("id", 0)) == 1, "shell seed should clamp to one")

	var bouncing_shell := {
		"pos": Vector2(100.0, 644.0),
		"velocity": Vector2(2.0, 4.0),
		"rotation": 5.0,
		"rotation_speed": 10.0,
		"bounce_count": 0,
		"floor_y": 645.0,
		"lifetime_frames": 10.0,
	}
	var bounced: Dictionary = CommandoFirearmShellCasingState.advance_shell(bouncing_shell, 1.0, 760.0, 750.0, 0.45, 0.42, 2)
	_expect(bool(bounced.get("active", false)), "bounced shell should stay active")
	var bounced_shell: Dictionary = bounced.get("shell", {})
	_expect(int(bounced_shell.get("bounce_count", 0)) == 1, "shell should increment bounce count on floor impact")
	_expect((bounced_shell.get("velocity", Vector2.ZERO) as Vector2).y < 0.0, "floor bounce should invert vertical velocity")

	_expect(
		not bool(CommandoFirearmShellCasingState.advance_shell({"lifetime_frames": 0.5}, 1.0, 760.0, 750.0, 0.45, 0.42, 2).get("active", true)),
		"expired shell should deactivate"
	)
	_expect(
		not bool(CommandoFirearmShellCasingState.advance_shell({
			"pos": Vector2(900.0, 100.0),
			"velocity": Vector2.ZERO,
			"lifetime_frames": 5.0,
		}, 1.0, 760.0, 750.0, 0.0, 0.42, 2).get("active", true)),
		"out-of-bounds shell should deactivate"
	)
	var shell_list: Array = [
		bouncing_shell,
		{"lifetime_frames": 0.5},
	]
	var advanced_shells: Array = CommandoFirearmShellCasingState.advance_shells(
		shell_list,
		1.0,
		760.0,
		750.0,
		0.45,
		0.42,
		2
	)
	_expect(advanced_shells.size() == 1, "shell list helper should keep active shells only")
	_expect(int((advanced_shells[0] as Dictionary).get("bounce_count", 0)) == 1, "shell list helper should preserve advanced shell state")
	_expect(CommandoFirearmShellCasingState.advance_shells(shell_list, 0.0, 760.0, 750.0, 0.45, 0.42, 2).size() == 2, "zero-step shell list helper should preserve shells")


func _verify_runtime_delegates_shell_casing_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.shot_serial = 6
	runtime._spawn_firearm_effect(
		"ak47",
		{"player_pos": Vector2(90.0, 600.0), "paddle_height": 40.0, "boss_pos": Vector2(330.0, 60.0)},
		{},
		{"kind": "bullet", "speed": 16.0, "angle_offset": 0.0}
	)
	var context: Dictionary = runtime.get_actor_draw_context()
	var shells: Array = context.get("commando_firearm_shell_casings", [])
	_expect(shells.size() == 1, "runtime fire path should create AK-47 shell casing")
	if shells.size() == 1:
		var shell: Dictionary = shells[0]
		_expect(str(shell.get("weapon_id", "")) == "ak47", "runtime shell casing should preserve weapon id")
		_expect(int(shell.get("id", 0)) == 7, "runtime shell casing should use projectile shot id")
		_expect(is_equal_approx(float(shell.get("floor_y", 0.0)), 645.0), "runtime shell casing should preserve floor clamp")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _spawn_ak47_shell_casing("), "runtime should not keep AK-47 shell spawn bridge")
	_expect(not runtime_source.contains("func _spawn_pistol_shell_casing("), "runtime should not keep pistol shell spawn bridge")
	_expect(not runtime_source.contains("func _update_shell_casings("), "runtime should not keep shell-casing update bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
