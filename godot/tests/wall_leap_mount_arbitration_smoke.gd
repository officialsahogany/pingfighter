extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetMountState := preload("res://scripts/lingpet/lingpet_mount_state.gd")

class MountInput:
	extends RefCounted
	var rmb := true
	func is_rmb_pressed() -> bool: return rmb
	func is_down_pressed() -> bool: return false

var _support := Support.new()
var _failures: Array[String] = []


func _init() -> void:
	_verify_armable_claims_without_mount()
	_verify_denials_preserve_mount("gauge", func(f): f["owner"].values["special_gauge"] = 159.0)
	_verify_denials_preserve_mount("cooldown", func(f): f["skill_state"].trigger_configured_cooldown("wall_leap_raid", Time.get_ticks_msec(), f["skill_config"]))
	_verify_denials_preserve_mount("unequipped", func(f): f["skill_config"].equipped_skills = [])
	_verify_denials_preserve_mount("other_character", func(f): f["owner"].values["selected_character_type"] = "smasher")
	_finish()


func _verify_armable_claims_without_mount() -> void:
	var fixture: Dictionary = _support.make_fixture()
	var egg := LingpetEggRuntime.new()
	var claimed: bool = egg._is_right_click_claimed_by_player_skill(fixture["owner"], fixture["registry"])
	var mount := _new_mount()
	var companion_x: float = float(fixture["owner"].values["player_pos"].x) + 77.5
	var result: Dictionary = mount.advance(fixture["owner"], Vector2(companion_x, 670.0), true, claimed, 1.0 / 60.0, LingpetMountState.is_mount_permitted("onimaru", []))
	_expect(claimed, "armable wall leap must claim RMB")
	_expect(not bool(result.get("toggled", false)) and not mount.is_mounted(), "claimed RMB must not toggle mount")
	_expect(int(fixture["registry"].cold_reads) == 0, "mount arbitration must use cached peek only")


func _verify_denials_preserve_mount(label: String, configure: Callable) -> void:
	var fixture: Dictionary = _support.make_fixture()
	configure.call(fixture)
	var egg := LingpetEggRuntime.new()
	var claimed: bool = egg._is_right_click_claimed_by_player_skill(fixture["owner"], fixture["registry"])
	var mount := _new_mount()
	var companion_x: float = float(fixture["owner"].values["player_pos"].x) + 77.5
	var result: Dictionary = mount.advance(fixture["owner"], Vector2(companion_x, 670.0), true, claimed, 1.0 / 60.0, LingpetMountState.is_mount_permitted("onimaru", []))
	_expect(not claimed, "%s denial must release RMB to mount" % label)
	_expect(bool(result.get("toggled", false)) and mount.is_mounted(), "%s denial must preserve normal mount toggle" % label)
	_expect(int(fixture["registry"].cold_reads) == 0, "%s arbitration must not cold instantiate" % label)


func _new_mount() -> Object:
	var mount := LingpetMountState.new()
	mount.set_pet_id("onimaru")
	mount.set_input_probe(MountInput.new())
	return mount


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_mount_arbitration_smoke: ok")
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)
