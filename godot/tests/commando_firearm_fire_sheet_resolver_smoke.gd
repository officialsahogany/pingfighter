extends SceneTree

const CommandoFirearmFireSheetResolver := preload("res://scripts/characters/commando_firearm_fire_sheet_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_fire_sheet_resolver()
	_verify_runtime_uses_fire_sheet_resolver_boundary()
	_verify_removed_runtime_fire_sheet_bridges()

	if _failures.is_empty():
		print("commando_firearm_fire_sheet_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_fire_sheet_resolver() -> void:
	for weapon_id in ["ak47", "bazooka", "net_gun", "bowling_trap", "suicide_drone"]:
		_expect(
			CommandoFirearmFireSheetResolver.normalize_weapon_fire_sheet_id(weapon_id) == weapon_id,
			"%s should resolve to a weapon-fire sheet id" % weapon_id
		)
	for weapon_id in ["pistol", "commando_pistol", "fire_support", "experimental_firearm"]:
		_expect(
			CommandoFirearmFireSheetResolver.normalize_weapon_fire_sheet_id(weapon_id) == "",
			"%s should not resolve to a weapon-fire sheet id" % weapon_id
		)

	_expect(
		is_equal_approx(CommandoFirearmFireSheetResolver.get_duration_frames("bazooka", 40.0, 60.0), 60.0),
		"bazooka should use the long weapon-fire sheet duration"
	)
	_expect(
		is_equal_approx(CommandoFirearmFireSheetResolver.get_duration_frames("bowling_trap", 40.0, 60.0), 60.0),
		"bowling trap should use the long weapon-fire sheet duration"
	)
	_expect(
		is_equal_approx(CommandoFirearmFireSheetResolver.get_duration_frames("ak47", 40.0, 60.0), 40.0),
		"ak47 should use the default weapon-fire sheet duration"
	)

	_expect(CommandoFirearmFireSheetResolver.get_start_frame("ak47", 8) == 3, "ak47 should start on authored frame 3")
	_expect(CommandoFirearmFireSheetResolver.get_start_frame("bazooka", 8) == 3, "bazooka should start on authored frame 3")
	_expect(CommandoFirearmFireSheetResolver.get_start_frame("net_gun", 8) == 3, "net gun should start on authored frame 3")
	_expect(CommandoFirearmFireSheetResolver.get_start_frame("bowling_trap", 8) == 0, "bowling trap should start on frame 0")
	_expect(CommandoFirearmFireSheetResolver.get_start_frame("ak47", 2) == 1, "start frames should clamp to the available frame count")


func _verify_runtime_uses_fire_sheet_resolver_boundary() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime._start_weapon_fire_sheet_animation("pistol")
	_expect(runtime.weapon_fire_sheet_id == "", "pistol should not start the shared weapon-fire sheet")

	runtime._start_weapon_fire_sheet_animation("bazooka")
	_expect(runtime.weapon_fire_sheet_id == "bazooka", "bazooka should start the shared weapon-fire sheet")
	_expect(is_equal_approx(runtime.weapon_fire_sheet_max_frames, 60.0), "bazooka fire sheet should keep the long duration")
	_expect(is_equal_approx(runtime.weapon_fire_sheet_timer_frames, 37.5), "bazooka fire sheet should start at frame 3")

	runtime._start_weapon_fire_sheet_animation("ak47")
	var ak47_start_timer: float = runtime.weapon_fire_sheet_timer_frames
	_expect(runtime.weapon_fire_sheet_id == "ak47", "AK-47 should start the shared weapon-fire sheet")
	_expect(is_equal_approx(ak47_start_timer, 25.0), "AK-47 fire sheet should start at authored muzzle-flash frame 3")
	runtime.weapon_fire_sheet_timer_frames = 6.0
	runtime._start_weapon_fire_sheet_animation("ak47")
	_expect(is_equal_approx(runtime.weapon_fire_sheet_timer_frames, ak47_start_timer), "AK-47 fire sheet should restart on every bullet for per-shot recoil")


func _verify_removed_runtime_fire_sheet_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_normalize_weapon_fire_sheet_id",
		"_get_weapon_fire_sheet_duration_frames",
		"_get_weapon_fire_sheet_start_frame",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep fire-sheet bridge %s" % bridge_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
