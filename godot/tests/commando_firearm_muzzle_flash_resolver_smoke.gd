extends SceneTree

const CommandoFirearmMuzzleFlashResolver := preload("res://scripts/characters/commando_firearm_muzzle_flash_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_muzzle_flash_resolver()
	_verify_runtime_uses_muzzle_flash_resolver()
	_verify_removed_runtime_muzzle_flash_bridge()

	if _failures.is_empty():
		print("commando_firearm_muzzle_flash_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_muzzle_flash_resolver() -> void:
	var profile := {
		"kind": "rocket",
		"radius": 7.0,
		"muzzle_flash_frames": 5.0,
		"secondary": Color(0.25, 0.5, 0.75),
	}
	var flash: Dictionary = CommandoFirearmMuzzleFlashResolver.build_flash(
		Vector2(12.0, 34.0),
		Vector2.UP,
		profile,
		"bazooka"
	)
	_expect(str(flash.get("weapon_id", "")) == "bazooka", "muzzle flash should preserve weapon id")
	_expect(str(flash.get("kind", "")) == "rocket", "muzzle flash should preserve profile kind")
	_expect(_get_vector2(flash.get("pos", Vector2.ZERO)) == Vector2(12.0, 34.0), "muzzle flash should preserve origin")
	_expect(_get_vector2(flash.get("direction", Vector2.ZERO)) == Vector2.UP, "muzzle flash should preserve direction")
	_expect(is_equal_approx(float(flash.get("radius", 0.0)), 15.4), "muzzle flash radius should scale from profile radius")
	_expect(is_equal_approx(float(flash.get("timer_frames", 0.0)), 5.0), "muzzle flash timer should use profile timer")
	_expect(is_equal_approx(float(flash.get("max_timer_frames", 0.0)), 5.0), "muzzle flash max timer should mirror timer")
	_expect(_get_color(flash.get("color", Color.WHITE)) == Color(0.25, 0.5, 0.75), "muzzle flash should use profile secondary color")

	var fallback: Dictionary = CommandoFirearmMuzzleFlashResolver.build_flash(
		Vector2.ZERO,
		Vector2.RIGHT,
		{"radius": 2.0, "muzzle_flash_frames": 0.2},
		"pistol"
	)
	_expect(str(fallback.get("kind", "")) == "bullet", "muzzle flash should default to bullet kind")
	_expect(is_equal_approx(float(fallback.get("radius", 0.0)), 10.0), "muzzle flash radius should clamp to the minimum")
	_expect(is_equal_approx(float(fallback.get("timer_frames", 0.0)), 1.0), "muzzle flash timer should clamp to one frame")
	_expect(_get_color(fallback.get("color", Color.WHITE)) == Color(1.0, 0.7, 0.2), "muzzle flash should use fallback color")


func _verify_runtime_uses_muzzle_flash_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var profile := {
		"kind": "rocket",
		"radius": 7.0,
		"muzzle_flash_frames": 5.0,
		"secondary": Color(0.25, 0.5, 0.75),
	}
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _build_muzzle_flash("), "runtime should not keep muzzle-flash build bridge")

	runtime._spawn_firearm_effect(
		"bazooka",
		{
			"player_pos": Vector2(12.0, 34.0),
			"boss_pos": Vector2(12.0, 0.0),
			"paddle_width": 1.0,
			"paddle_height": 1.0,
		},
		{},
		profile
	)
	_expect(runtime.muzzle_flashes.size() == 1, "runtime spawn should append one muzzle flash")
	var spawned: Dictionary = CommandoFirearmValueUtils.get_dict(runtime.muzzle_flashes[0])
	_expect(str(spawned.get("weapon_id", "")) == "bazooka", "runtime spawn should preserve weapon id")
	_expect(is_equal_approx(float(spawned.get("timer_frames", 0.0)), 5.0), "runtime spawn should use resolver timer")


func _verify_removed_runtime_muzzle_flash_bridge() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(source.find("func _spawn_muzzle_flash(") < 0, "runtime should not keep muzzle-flash append bridge")


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
