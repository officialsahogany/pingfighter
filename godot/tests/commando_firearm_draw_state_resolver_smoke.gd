extends SceneTree

const CommandoFirearmDrawStateResolver := preload("res://scripts/characters/commando_firearm_draw_state_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pistol_state()
	_verify_direct_weapon_fire_sheet_state()
	_verify_runtime_delegates_draw_state()

	if _failures.is_empty():
		print("commando_firearm_draw_state_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pistol_state() -> void:
	var pending: Dictionary = CommandoFirearmDrawStateResolver.build_pistol_state(
		2.0,
		60.0,
		3.0,
		18.0,
		12.0,
		24.0,
		0.0,
		18.0
	)
	_expect(bool(pending.get("shot_pending", false)), "pistol state should mark pending shot during fire delay")
	_expect(bool(pending.get("animation_active", false)), "pistol state should mark animation active during fire delay")

	var post_fire: Dictionary = CommandoFirearmDrawStateResolver.build_pistol_state(
		0.0,
		60.0,
		0.0,
		18.0,
		0.0,
		24.0,
		3.0,
		18.0
	)
	_expect(not bool(post_fire.get("shot_pending", true)), "pistol state should clear pending shot after fire delay")
	_expect(bool(post_fire.get("animation_active", false)), "pistol state should keep animation active during post-fire pose")


func _verify_direct_weapon_fire_sheet_state() -> void:
	var active: Dictionary = CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state("ak47", 20.0, 40.0, 8)
	_expect(bool(active.get("active", false)), "weapon-fire sheet should be active when timer and id are present")
	_expect(str(active.get("weapon_id", "")) == "ak47", "weapon-fire sheet should preserve weapon id")
	_expect(int(active.get("frame_count", 0)) == 8, "weapon-fire sheet should preserve frame count")

	var missing_id: Dictionary = CommandoFirearmDrawStateResolver.build_weapon_fire_sheet_state("", 20.0, 40.0, 8)
	_expect(not bool(missing_id.get("active", true)), "weapon-fire sheet should be inactive without weapon id")


func _verify_runtime_delegates_draw_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.pistol_cooldown_frames = 2.0
	runtime.pistol_cooldown_max_frames = 60.0
	runtime.pistol_control_lock_frames = 3.0
	runtime.pistol_control_lock_max_frames = 18.0
	runtime.pistol_fire_delay_frames = 4.0
	runtime.pistol_post_fire_animation_frames = 5.0

	var pistol: Dictionary = runtime._get_pistol_draw_state()
	_expect(is_equal_approx(float(pistol.get("cooldown_frames", 0.0)), 2.0), "runtime pistol draw wrapper should preserve cooldown")
	_expect(is_equal_approx(float(pistol.get("control_lock_frames", 0.0)), 3.0), "runtime pistol draw wrapper should preserve control lock")
	_expect(is_equal_approx(float(pistol.get("fire_delay_frames", 0.0)), 4.0), "runtime pistol draw wrapper should preserve fire delay")
	_expect(is_equal_approx(float(pistol.get("post_fire_animation_frames", 0.0)), 5.0), "runtime pistol draw wrapper should preserve post-fire timer")
	_expect(bool(pistol.get("shot_pending", false)), "runtime pistol draw wrapper should expose pending shot")
	_expect(bool(pistol.get("animation_active", false)), "runtime pistol draw wrapper should expose active animation")

	runtime.weapon_fire_sheet_id = "ak47"
	runtime.weapon_fire_sheet_timer_frames = 20.0
	runtime.weapon_fire_sheet_max_frames = 40.0
	var fire_sheet: Dictionary = runtime._get_weapon_fire_sheet_draw_state()
	_expect(bool(fire_sheet.get("active", false)), "runtime weapon-fire sheet wrapper should expose active state")
	_expect(str(fire_sheet.get("weapon_id", "")) == "ak47", "runtime weapon-fire sheet wrapper should preserve id")
	_expect(int(fire_sheet.get("frame_count", 0)) == runtime.COMMANDO_WEAPON_FIRE_SHEET_FRAME_COUNT, "runtime weapon-fire sheet wrapper should preserve frame count")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
