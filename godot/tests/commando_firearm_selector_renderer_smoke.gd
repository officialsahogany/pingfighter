extends SceneTree

const CommandoFirearmSelectorRenderer := preload("res://scripts/hud/commando_firearm_selector_renderer.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_prewarm_assets()
	_verify_single_fixed_panel_state()

	if _failures.is_empty():
		print("commando_firearm_selector_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_assets() -> void:
	var renderer: Object = CommandoFirearmSelectorRenderer.new()
	_expect(renderer.has_method("prewarm_assets"), "firearm selector should expose boot prewarm")
	renderer.prewarm_assets()
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/ui/commando_firearm_hud_frame_v1.png") is Texture2D, "firearm selector prewarm should cache the HUD frame")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_pistol_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the pistol HUD icon")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_pistol_firearm_fire_recoil_sheet_autosprite_v1_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the pistol recoil sheet")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_ak47_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the AK-47 HUD icon")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_ak47_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the AK-47 recoil sheet")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_bazooka_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the bazooka HUD icon")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_bazooka_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png") is Texture2D, "firearm selector prewarm should cache the bazooka recoil sheet")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_bowling_trap_firearm_icon_imagegen_v1.png") is Texture2D, "firearm selector prewarm should cache the imagegen bowling trap HUD icon")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/hud/commando_bowling_trap_firearm_install_sheet_autosprite_v1.png") is Texture2D, "firearm selector prewarm should cache the bowling-trap HUD install sheet")
	_expect(ProjectResourceLoader.get_cached_texture("res://assets/sprites/effects/commando_bowling_trap_capture_sheet_autosprite_v1.png") is Texture2D, "firearm selector prewarm should cache the bowling-trap HUD capture sheet")


func _verify_single_fixed_panel_state() -> void:
	var renderer: Object = CommandoFirearmSelectorRenderer.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var controller: Object = CommandoWeaponController.new()
	_expect(bool(skill_config.unlock_and_equip_skill("net_gun")), "net gun should equip")
	_expect(bool(skill_config.unlock_and_equip_skill("bazooka")), "bazooka should equip")
	_expect(bool(skill_config.unlock_and_equip_skill("ak47")), "ak47 should equip")
	controller.sync_equipped_permanent(skill_config)
	_expect(bool(controller.add_rental_weapon("fire_support", 1, 1)), "rental fire support should be grantable")
	_expect(bool(controller.set_current_weapon("bazooka")), "bazooka should be selectable")

	var center := Vector2(90.0, 260.0)
	var context := {"commando_weapon_controller": controller}
	var first: Dictionary = renderer.build_panel_state(center, 1.0, context)
	_expect(int(first.get("panel_count", 0)) == 1, "firearm selector should expose exactly one panel")
	_expect(int(first.get("weapon_count", 0)) == controller.get_weapons().size(), "single panel should report total weapon count without creating extra panels")
	_expect(str(first.get("current_weapon_id", "")) == "bazooka", "panel should show only the current weapon")
	var first_rect: Rect2 = _get_rect(first.get("rect", Rect2()))
	_expect(_same_vector(first_rect.size, Vector2(68.0, 112.0)), "default panel size should use the original-style compact vertical weapon slot")
	var first_meter_rect: Rect2 = _get_rect(first.get("meter_rect", Rect2()))
	_expect(
		first_meter_rect.position.y >= first_rect.position.y + 89.0
		and first_meter_rect.end.y <= first_rect.position.y + 106.0,
		"ammo icons should anchor inside the imagegen HUD frame bottom tray instead of floating above it"
	)
	var frame_path: String = str(first.get("hud_frame_path", ""))
	_expect(frame_path == "res://assets/ui/commando_firearm_hud_frame_v1.png", "firearm selector should expose the imagegen HUD frame path")
	_verify_hud_frame_asset(frame_path)
	_verify_firearm_png_assets(first)
	_expect(not bool(first.get("bazooka_fire_recoil_active", true)), "idle bazooka panel should use the static imagegen bazooka icon")
	var firing_bazooka_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_weapon_fire_sheet_state": {
			"active": true,
			"weapon_id": "bazooka",
			"timer_frames": 60.0,
			"timer_max_frames": 60.0,
			"frame_count": 8,
		},
	})
	_expect(bool(firing_bazooka_panel.get("bazooka_fire_recoil_active", false)), "firing bazooka panel should activate the AutoSprite HUD recoil sheet")
	_expect(int(firing_bazooka_panel.get("bazooka_fire_recoil_frame", -1)) == 0, "fresh bazooka HUD fire frame should start at the first sheet frame")
	_expect(int(firing_bazooka_panel.get("bazooka_fire_recoil_frame_count", 0)) == 16, "bazooka HUD fire sheet should expose 16 frames")
	_expect(float(firing_bazooka_panel.get("bazooka_fire_recoil_draw_scale", 0.0)) > 1.25, "bazooka HUD fire sheet should compensate AutoSprite padding so it does not shrink below the static icon")
	var mid_bazooka_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_weapon_fire_sheet_state": {
			"active": true,
			"weapon_id": "bazooka",
			"timer_frames": 30.0,
			"timer_max_frames": 60.0,
			"frame_count": 8,
		},
	})
	_expect(int(mid_bazooka_panel.get("bazooka_fire_recoil_frame", -1)) == 8, "mid bazooka HUD fire frame should advance through the 16-frame sheet")
	var bazooka_ammo: Dictionary = _get_dict(first.get("ammo_icon_state", {}))
	_expect(not bazooka_ammo.is_empty(), "limited-ammo firearm panel should expose icon ammo state instead of relying on 3/4 text")
	_expect(int(bazooka_ammo.get("display_slots", 0)) == 4 and int(bazooka_ammo.get("filled_slots", 0)) == 4, "bazooka ammo icons should expose one filled icon per rocket")
	_expect(not bool(bazooka_ammo.get("compressed", true)), "small ammo pools should draw exact ammo icons")
	_expect(bool(controller.consume_current_weapon_ammo()), "bazooka ammo should be consumable for icon smoke")
	var spent_bazooka_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	var spent_bazooka_ammo: Dictionary = _get_dict(spent_bazooka_panel.get("ammo_icon_state", {}))
	_expect(int(spent_bazooka_ammo.get("filled_slots", -1)) == 3, "spent bazooka ammo should remove one filled icon instead of only changing text")

	_expect(bool(controller.set_current_weapon("fire_support")), "rental fire support should be selectable")
	var second: Dictionary = renderer.build_panel_state(center, 1.0, context)
	var second_rect: Rect2 = _get_rect(second.get("rect", Rect2()))
	_expect(int(second.get("panel_count", 0)) == 1, "rental selection should still use one fixed panel")
	_expect(second_rect == first_rect, "switching current weapon should not resize or move the selector panel")
	_expect(str(second.get("current_weapon_id", "")) == "fire_support", "panel should follow current weapon after switching")

	var tiny_scale: Dictionary = renderer.build_panel_state(center, 0.1, context)
	var tiny_rect: Rect2 = _get_rect(tiny_scale.get("rect", Rect2()))
	_expect(_same_vector(tiny_rect.size, Vector2(37.4, 61.6)), "selector should keep a stable minimum compact-slot size at tiny scales")

	_expect(bool(skill_config.swap_equipped_permanent("net_gun", "commando_pistol")), "Commando pistol should equip for ammo icon smoke")
	controller.sync_equipped_permanent(skill_config)
	_expect(bool(controller.set_current_weapon("commando_pistol")), "Commando pistol should be selectable for ammo icon smoke")
	var pistol_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	var pistol_ammo: Dictionary = _get_dict(pistol_panel.get("ammo_icon_state", {}))
	_expect(str(pistol_panel.get("title", "")) == "베레타", "Commando pistol selector should use the Beretta display name")
	_expect(int(pistol_ammo.get("display_slots", 0)) == 4, "Commando pistol should expose four bullet icon slots")
	_expect(int(pistol_ammo.get("filled_slots", 0)) == 4, "full Commando pistol should draw four filled bullet icons")
	_expect(int(pistol_ammo.get("magazines_max", 0)) == 2 and int(pistol_ammo.get("magazines_current", 0)) == 2, "Beretta should expose two spare magazine icons for 12 total shots")
	_expect(bool(controller.consume_current_weapon_ammo()), "Commando pistol ammo should be consumable for icon smoke")
	var spent_pistol_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	var spent_pistol_ammo: Dictionary = _get_dict(spent_pistol_panel.get("ammo_icon_state", {}))
	_expect(int(spent_pistol_ammo.get("filled_slots", -1)) == 3, "spent Commando pistol ammo should remove one filled bullet icon")

	_expect(bool(controller.set_current_weapon("ak47")), "AK-47 should be selectable for compressed ammo icon smoke")
	var ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	var ak47_ammo: Dictionary = _get_dict(ak47_panel.get("ammo_icon_state", {}))
	_expect(bool(ak47_ammo.get("compressed", false)), "AK-47 should use a compressed bullet-belt icon row instead of sixty text bullets")
	_expect(int(ak47_ammo.get("display_slots", 0)) == 15, "AK-47 compressed ammo icon row should match the original 15-round visual belt")
	_expect(not bool(ak47_panel.get("ak47_fire_recoil_active", true)), "idle AK-47 panel should use the static imagegen AK-47 icon")
	_expect(bool(controller.trigger_hud_highlight("ak47", 90.0)), "firearm HUD highlight should be triggerable for the selected weapon")
	var highlighted_ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	_expect(bool(highlighted_ak47_panel.get("hud_highlight_active", false)), "highlighted AK-47 panel should expose the HUD flash flag")
	_expect(float(highlighted_ak47_panel.get("hud_highlight_ratio", 0.0)) > 0.95, "fresh HUD highlight should start at full intensity")
	controller.update_timers(90.0)
	var expired_ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, context)
	_expect(not bool(expired_ak47_panel.get("hud_highlight_active", true)), "expired HUD highlight should disappear from panel state")
	var firing_ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_weapon_fire_sheet_state": {
			"active": true,
			"weapon_id": "ak47",
			"timer_frames": 40.0,
			"timer_max_frames": 40.0,
			"frame_count": 8,
		},
	})
	_expect(bool(firing_ak47_panel.get("ak47_fire_recoil_active", false)), "firing AK-47 panel should activate the AutoSprite HUD recoil sheet")
	_expect(int(firing_ak47_panel.get("ak47_fire_recoil_frame", -1)) == 0, "fresh AK-47 HUD fire frame should start at the first sheet frame")
	_expect(int(firing_ak47_panel.get("ak47_fire_recoil_frame_count", 0)) == 16, "AK-47 HUD fire sheet should expose 16 frames")
	_expect(float(firing_ak47_panel.get("ak47_fire_recoil_draw_scale", 0.0)) > 1.10, "AK-47 HUD fire sheet should compensate AutoSprite padding so it does not shrink below the static icon")
	_expect(is_equal_approx(float(firing_ak47_panel.get("ak47_fire_recoil_rotation_degrees", 999.0)), 0.0), "fresh AK-47 HUD fire sheet should begin from the neutral aim angle")
	var runtime_start_ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_weapon_fire_sheet_state": {
			"active": true,
			"weapon_id": "ak47",
			"timer_frames": 25.0,
			"timer_max_frames": 40.0,
			"frame_count": 8,
		},
	})
	_expect(int(runtime_start_ak47_panel.get("ak47_fire_recoil_frame", -1)) == 6, "runtime AK-47 shot pulse should enter the HUD recoil sheet on the muzzle-kick frames")
	_expect(float(runtime_start_ak47_panel.get("ak47_fire_recoil_rotation_degrees", 0.0)) <= -6.0, "runtime AK-47 shot pulse should lift the muzzle angle for visible recoil")
	var mid_ak47_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_weapon_fire_sheet_state": {
			"active": true,
			"weapon_id": "ak47",
			"timer_frames": 20.0,
			"timer_max_frames": 40.0,
			"frame_count": 8,
		},
	})
	_expect(int(mid_ak47_panel.get("ak47_fire_recoil_frame", -1)) == 8, "mid AK-47 HUD fire frame should advance through the 16-frame sheet")
	_expect(float(mid_ak47_panel.get("ak47_fire_recoil_rotation_degrees", 0.0)) < -1.0, "mid AK-47 HUD fire frame should still show a smaller recoil angle before settling")

	_expect(bool(controller.set_current_weapon("pistol")), "base pistol should be selectable")
	var base_pistol_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_slingshot_state": {
			"charging": true,
			"charge_level": 2,
			"charge_ratio": 0.55,
			"charge_tick_ratio": 0.45,
		},
	})
	_expect(str(base_pistol_panel.get("title", "")) == "권총", "base selector should show the Korean pistol name")
	_expect(str(base_pistol_panel.get("status", "")) == "탄약 4/4", "base selector should show the four-round pistol magazine")
	var base_ammo: Dictionary = _get_dict(base_pistol_panel.get("ammo_icon_state", {}))
	_expect(int(base_ammo.get("filled_slots", -1)) == 4 and int(base_ammo.get("display_slots", -1)) == 4, "base pistol should expose four bullet icons")
	var base_icon_rect: Rect2 = _get_rect(base_pistol_panel.get("icon_rect", Rect2()))
	var base_meter_rect: Rect2 = _get_rect(base_pistol_panel.get("meter_rect", Rect2()))
	_expect(
		base_meter_rect.position.y >= base_icon_rect.end.y + 14.0,
		"base pistol bullet icons should sit in the HUD ammo tray, not directly on top of the weapon slot"
	)
	_expect(str(base_pistol_panel.get("current_weapon_id", "")) == "pistol", "base pistol should keep the save-compatible pistol id")
	_expect(not bool(base_pistol_panel.get("pistol_fire_recoil_active", true)), "idle base pistol panel should use the static imagegen pistol icon")
	_verify_firearm_png_assets(base_pistol_panel)

	var firing_pistol_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_pistol_state": {
			"fire_delay_frames": 0.0,
			"fire_delay_max_frames": 24.0,
			"post_fire_animation_frames": 18.0,
			"post_fire_animation_max_frames": 18.0,
		},
	})
	_expect(bool(firing_pistol_panel.get("pistol_fire_recoil_active", false)), "firing base pistol panel should activate the AutoSprite recoil sheet")
	_expect(int(firing_pistol_panel.get("pistol_fire_recoil_frame", -1)) == 4, "first post-shot UI recoil frame should be the muzzle-flash frame")
	_expect(int(firing_pistol_panel.get("pistol_fire_recoil_frame_count", 0)) == 16, "pistol UI recoil sheet should expose 16 frames")

	var mid_recoil_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_pistol_state": {
			"fire_delay_frames": 0.0,
			"fire_delay_max_frames": 24.0,
			"post_fire_animation_frames": 9.0,
			"post_fire_animation_max_frames": 18.0,
		},
	})
	_expect(int(mid_recoil_panel.get("pistol_fire_recoil_frame", -1)) == 10, "mid post-shot UI recoil frame should advance through the 16-frame recovery")

	_expect(bool(controller.add_rental_weapon("bowling_trap", 3, 3)), "rental bowling trap should be grantable for HUD motion smoke")
	_expect(bool(controller.set_current_weapon("bowling_trap")), "bowling trap should be selectable for HUD motion smoke")
	var installing_bowling_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_bowling_trap_state": {
			"installing": true,
			"install_progress": 0.5,
			"install_pose_frames": 24.0,
			"control_lock_frames": 24.0,
		},
		"commando_firearm_bowling_traps": [
			{"state": "installing", "install_progress": 0.5, "timer_frames": 24.0, "max_timer_frames": 48.0},
		],
	})
	_expect(bool(installing_bowling_panel.get("bowling_trap_ui_animation_active", false)), "installing bowling trap should mark the firearm HUD icon animated")
	_expect(bool(installing_bowling_panel.get("bowling_trap_ui_install_animation_active", false)), "installing bowling trap should use the AutoSprite install sheet in the firearm HUD")
	_expect(not bool(installing_bowling_panel.get("bowling_trap_ui_capture_animation_active", true)), "installing bowling trap HUD motion should not claim the capture sheet")
	_expect(int(installing_bowling_panel.get("bowling_trap_ui_install_animation_frame", -1)) == 8, "mid install HUD frame should advance through the 16-frame install sheet")
	_expect(int(installing_bowling_panel.get("bowling_trap_ui_install_animation_frame_count", 0)) == 16, "bowling-trap HUD install sheet should expose sixteen frames")
	var waiting_bowling_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_bowling_trap_state": {
			"installing": false,
			"install_pose_frames": 0.0,
			"control_lock_frames": 0.0,
		},
		"commando_firearm_bowling_traps": [
			{"state": "waiting", "timer_frames": 0.0, "max_timer_frames": 48.0},
		],
	})
	_expect(bool(waiting_bowling_panel.get("bowling_trap_ui_animation_active", false)), "installed bowling trap should keep the firearm HUD icon moving while waiting")
	_expect(not bool(waiting_bowling_panel.get("bowling_trap_ui_capture_animation_active", true)), "waiting bowling trap HUD motion should not claim the capture sheet")
	var capturing_bowling_panel: Dictionary = renderer.build_panel_state(center, 1.0, {
		"commando_weapon_controller": controller,
		"commando_firearm_bowling_trap_state": {
			"installing": false,
			"install_pose_frames": 0.0,
			"control_lock_frames": 0.0,
		},
		"commando_firearm_bowling_traps": [
			{"state": "capturing", "capture_progress": 0.5, "timer_frames": 45.0, "max_timer_frames": 90.0},
		],
	})
	_expect(bool(capturing_bowling_panel.get("bowling_trap_ui_animation_active", false)), "capturing bowling trap should mark the firearm HUD icon animated")
	_expect(bool(capturing_bowling_panel.get("bowling_trap_ui_capture_animation_active", false)), "capturing bowling trap should use the AutoSprite capture sheet in the firearm HUD")
	_expect(int(capturing_bowling_panel.get("bowling_trap_ui_animation_frame", -1)) == 8, "mid capture HUD frame should advance through the 16-frame capture sheet")
	_expect(int(capturing_bowling_panel.get("bowling_trap_ui_animation_frame_count", 0)) == 16, "bowling-trap HUD capture sheet should expose sixteen frames")


func _get_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _color_energy(color: Color) -> float:
	return color.r + color.g + color.b + color.a * 0.25


func _same_vector(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)


func _verify_hud_frame_asset(path: String) -> void:
	_expect(FileAccess.file_exists(path), "imagegen firearm HUD frame PNG should exist")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "imagegen firearm HUD frame PNG should load as an image")
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == Vector2i(272, 448), "imagegen firearm HUD frame should keep the 68:112 compact slot aspect at 4x")
	var size: Vector2i = image.get_size()
	var corner_alpha := [
		image.get_pixel(0, 0).a,
		image.get_pixel(size.x - 1, 0).a,
		image.get_pixel(0, size.y - 1).a,
		image.get_pixel(size.x - 1, size.y - 1).a,
	]
	for alpha in corner_alpha:
		_expect(alpha <= 0.01, "imagegen firearm HUD frame corners should stay transparent")


func _verify_firearm_png_assets(panel_state: Dictionary) -> void:
	var icon_path: String = str(panel_state.get("pistol_icon_path", ""))
	_expect(icon_path == "res://assets/sprites/hud/commando_pistol_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN pistol HUD icon path")
	_verify_alpha_png_asset(icon_path, Vector2i(1024, 1024), "Real-ESRGAN pistol HUD icon")
	var sheet_path: String = str(panel_state.get("pistol_fire_recoil_sheet_path", ""))
	_expect(sheet_path == "res://assets/sprites/hud/commando_pistol_firearm_fire_recoil_sheet_autosprite_v1_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN AutoSprite pistol recoil sheet path")
	_verify_alpha_png_asset(sheet_path, Vector2i(4096, 4096), "Real-ESRGAN AutoSprite pistol recoil sheet")
	var ak47_icon_path: String = str(panel_state.get("ak47_icon_path", ""))
	_expect(ak47_icon_path == "res://assets/sprites/hud/commando_ak47_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN AK-47 HUD icon path")
	_verify_alpha_png_asset(ak47_icon_path, Vector2i(1024, 1024), "Real-ESRGAN AK-47 HUD icon")
	var ak47_sheet_path: String = str(panel_state.get("ak47_fire_recoil_sheet_path", ""))
	_expect(ak47_sheet_path == "res://assets/sprites/hud/commando_ak47_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN AutoSprite AK-47 recoil sheet path")
	_verify_alpha_png_asset(ak47_sheet_path, Vector2i(4096, 4096), "Real-ESRGAN AutoSprite AK-47 recoil sheet")
	var bazooka_icon_path: String = str(panel_state.get("bazooka_icon_path", ""))
	_expect(bazooka_icon_path == "res://assets/sprites/hud/commando_bazooka_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN bazooka HUD icon path")
	_verify_alpha_png_asset(bazooka_icon_path, Vector2i(1024, 1024), "Real-ESRGAN bazooka HUD icon")
	var bazooka_sheet_path: String = str(panel_state.get("bazooka_fire_recoil_sheet_path", ""))
	_expect(bazooka_sheet_path == "res://assets/sprites/hud/commando_bazooka_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png", "firearm selector should expose the Real-ESRGAN AutoSprite bazooka recoil sheet path")
	_verify_alpha_png_asset(bazooka_sheet_path, Vector2i(4096, 4096), "Real-ESRGAN AutoSprite bazooka recoil sheet")
	var bowling_trap_icon_path: String = str(panel_state.get("bowling_trap_icon_path", ""))
	_expect(bowling_trap_icon_path == "res://assets/sprites/hud/commando_bowling_trap_firearm_icon_imagegen_v1.png", "firearm selector should expose the imagegen bowling trap HUD icon path")
	_verify_alpha_png_asset(bowling_trap_icon_path, Vector2i(1024, 1024), "imagegen bowling trap HUD icon")
	var bowling_trap_install_path: String = str(panel_state.get("bowling_trap_install_sheet_path", ""))
	_expect(bowling_trap_install_path == "res://assets/sprites/hud/commando_bowling_trap_firearm_install_sheet_autosprite_v1.png", "firearm selector should expose the AutoSprite bowling trap install sheet path")
	_verify_alpha_png_asset(bowling_trap_install_path, Vector2i(2048, 2048), "AutoSprite bowling trap HUD install sheet")
	var bowling_trap_capture_path: String = str(panel_state.get("bowling_trap_capture_sheet_path", ""))
	_expect(bowling_trap_capture_path == "res://assets/sprites/effects/commando_bowling_trap_capture_sheet_autosprite_v1.png", "firearm selector should expose the AutoSprite bowling trap capture sheet path")
	_verify_alpha_png_asset(bowling_trap_capture_path, Vector2i(2048, 2048), "AutoSprite bowling trap HUD capture sheet")


func _verify_alpha_png_asset(path: String, expected_size: Vector2i, label: String) -> void:
	_expect(FileAccess.file_exists(path), "%s PNG should exist" % label)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s PNG should load as an image" % label)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should keep expected size %s" % [label, str(expected_size)])
	var size: Vector2i = image.get_size()
	var corner_alpha := [
		image.get_pixel(0, 0).a,
		image.get_pixel(size.x - 1, 0).a,
		image.get_pixel(0, size.y - 1).a,
		image.get_pixel(size.x - 1, size.y - 1).a,
	]
	for alpha in corner_alpha:
		_expect(alpha <= 0.01, "%s corners should stay transparent" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
