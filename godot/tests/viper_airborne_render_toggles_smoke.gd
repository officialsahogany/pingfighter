extends SceneTree

const ViperAirborneRenderToggles := preload("res://scripts/core/viper_airborne_render_toggles.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_default_off()
	_verify_hover_embers_force_disable()
	_verify_hold_bar_force_disable()
	_verify_hover_sheet_draw_force_disable()
	_verify_flag_path_constants()

	if _failures.is_empty():
		print("viper_airborne_render_toggles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_off() -> void:
	ViperAirborneRenderToggles.reset_cache_for_test()
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "0")
	_expect(not ViperAirborneRenderToggles.is_hover_embers_disabled(), "hover embers toggle should force off when env var is '0'")
	_expect(not ViperAirborneRenderToggles.is_hold_bar_disabled(), "hold bar toggle should force off when env var is '0'")
	_expect(not ViperAirborneRenderToggles.is_hover_sheet_draw_disabled(), "hover sheet draw toggle should force off when env var is '0'")


func _verify_hover_embers_force_disable() -> void:
	ViperAirborneRenderToggles.reset_cache_for_test()
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "1")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "0")
	_expect(ViperAirborneRenderToggles.is_hover_embers_disabled(), "hover embers toggle should switch on when its env var is '1'")
	_expect(not ViperAirborneRenderToggles.is_hold_bar_disabled(), "hover embers toggle should not affect hold bar toggle state")
	_expect(not ViperAirborneRenderToggles.is_hover_sheet_draw_disabled(), "hover embers toggle should not affect hover sheet draw toggle state")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "0")
	ViperAirborneRenderToggles.reset_cache_for_test()


func _verify_hold_bar_force_disable() -> void:
	ViperAirborneRenderToggles.reset_cache_for_test()
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "1")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "0")
	_expect(ViperAirborneRenderToggles.is_hold_bar_disabled(), "hold bar toggle should switch on when its env var is '1'")
	_expect(not ViperAirborneRenderToggles.is_hover_embers_disabled(), "hold bar toggle should not affect hover embers toggle state")
	_expect(not ViperAirborneRenderToggles.is_hover_sheet_draw_disabled(), "hold bar toggle should not affect hover sheet draw toggle state")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "0")
	ViperAirborneRenderToggles.reset_cache_for_test()


func _verify_hover_sheet_draw_force_disable() -> void:
	ViperAirborneRenderToggles.reset_cache_for_test()
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "1")
	_expect(ViperAirborneRenderToggles.is_hover_sheet_draw_disabled(), "hover sheet draw toggle should switch on when its env var is '1'")
	_expect(not ViperAirborneRenderToggles.is_hover_embers_disabled(), "hover sheet draw toggle should not affect hover embers toggle state")
	_expect(not ViperAirborneRenderToggles.is_hold_bar_disabled(), "hover sheet draw toggle should not affect hold bar toggle state")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "0")
	ViperAirborneRenderToggles.reset_cache_for_test()


func _verify_flag_path_constants() -> void:
	_expect(ViperAirborneRenderToggles.HOVER_EMBERS_FLAG == "res://viper_disable_hover_embers.flag", "hover embers flag path should stay stable so external tooling can drop the flag")
	_expect(ViperAirborneRenderToggles.HOLD_BAR_FLAG == "res://viper_disable_jetpack_hold_bar.flag", "hold bar flag path should stay stable so external tooling can drop the flag")
	_expect(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_FLAG == "res://viper_disable_hover_sheet_draw.flag", "hover sheet draw flag path should stay stable so external tooling can drop the flag")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
