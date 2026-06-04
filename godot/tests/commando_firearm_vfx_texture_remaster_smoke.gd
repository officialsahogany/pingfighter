extends SceneTree

const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_texture_piece_remaster_plan()
	_verify_weapon_visual_identity_report()

	if _failures.is_empty():
		print("commando_firearm_vfx_texture_remaster_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_texture_piece_remaster_plan() -> void:
	var renderer := Stage1CommandoFirearmRenderer.new()
	var plan: Dictionary = renderer.build_texture_remaster_plan({
		"commando_firearm_muzzle_flashes": [
			{"pos": Vector2(10.0, 20.0), "radius": 12.0},
		],
		"commando_firearm_impact_flashes": [
			{"pos": Vector2(12.0, 18.0), "kind": "net", "radius": 24.0},
			{"pos": Vector2(44.0, 26.0), "kind": "support_marker", "radius": 32.0},
			{"pos": Vector2(60.0, 36.0), "kind": "bullet", "radius": 16.0},
			{"pos": Vector2(82.0, 42.0), "kind": "grenade_explosion", "weapon_id": "fire_support", "radius": 190.0},
		],
		"commando_firearm_lingering_effects": [
			{"pos": Vector2(20.0, 30.0), "kind": "net_field", "width": 280.0, "height": 140.0},
			{"pos": Vector2(30.0, 40.0), "kind": "fire_zone", "width": 150.0, "height": 60.0},
			{"pos": Vector2(40.0, 50.0), "kind": "trap_clamp", "width": 92.0, "height": 42.0},
			{"pos": Vector2(50.0, 60.0), "kind": "blast_field", "width": 168.0, "height": 110.0},
		],
		"commando_firearm_pistol_feedbacks": [
			{"kind": "headshot", "text": "헤드샷!"},
			{"kind": "legshot", "text": "레그샷!"},
		],
	})

	_expect(bool(plan.get("texture_piece_pipeline", false)), "Stage1 Commando firearm renderer should expose a texture-piece VFX pipeline")
	_expect(bool(plan.get("pistol_feedback_text_pipeline", false)), "Stage1 Commando firearm renderer should expose pistol feedback text rendering")
	_expect(bool(plan.get("shader_host_pipeline", false)), "Stage1 Commando firearm renderer should expose the shader FX host pipeline")
	_expect(bool(plan.get("gpu_particle_pipeline", false)), "Stage1 Commando firearm renderer should expose the GPU particle FX host pipeline")
	_expect(int(plan.get("fx_host_shader_layers", 0)) == 1, "Commando firearm FX host should report one shader layer")
	_expect(int(plan.get("fx_host_gpu_particle_layers", 0)) == 2, "Commando firearm FX host should report muzzle and impact particle layers")
	_expect(bool(plan.get("fx_host_texture_pieces_ready", false)), "Commando firearm FX host should prewarm shared texture pieces")
	_expect(bool(plan.get("glow_texture_ready", false)), "glow texture piece should prewarm")
	_expect(bool(plan.get("burst_texture_ready", false)), "burst texture piece should prewarm")
	_expect(bool(plan.get("sparkle_texture_ready", false)), "sparkle texture piece should prewarm")
	_expect(bool(plan.get("ring_texture_ready", false)), "ring texture piece should prewarm")
	_expect(bool(plan.get("bowling_trap_installed_texture_ready", false)), "bowling trap installed imagegen texture should prewarm")
	_expect(bool(plan.get("bowling_trap_capture_sheet_ready", false)), "bowling trap capture AutoSprite sheet should prewarm")
	_expect(bool(plan.get("bowling_trap_launch_sheet_ready", false)), "bowling trap launch AutoSprite sheet should prewarm")
	_expect(bool(plan.get("support_aircraft_texture_ready", false)), "fire-support stealth aircraft imagegen texture should prewarm")
	_expect(plan.get("support_aircraft_draw_size", Vector2.ZERO) == Vector2(90.0, 80.4), "fire-support stealth aircraft should render at the 40% smaller tuned size")
	_expect(bool(plan.get("support_bomb_texture_ready", false)), "fire-support bomb projectile imagegen texture should prewarm")
	_expect(bool(plan.get("grenade_explosion_texture_pieces_ready", false)), "shared grenade explosion texture pieces should prewarm for fire-support airstrikes")
	_expect(int(plan.get("support_airstrike_explosion_texture_layers", 0)) == 12, "fire-support airstrike explosion should expose its high-quality texture layers")
	_expect(int(plan.get("bowling_trap_sheet_frame_count", 0)) == 16, "bowling trap AutoSprite sheets should expose sixteen runtime frames")
	_expect(int(plan.get("muzzle_texture_layers", 0)) == 2, "one muzzle flash should produce two texture layers")
	_expect(int(plan.get("impact_texture_layers", 0)) == 21, "impact flashes should count net/support/bullet texture layers plus the fire-support airstrike burst")
	_expect(int(plan.get("lingering_texture_layers", 0)) == 8, "lingering fields should count net/fire/trap/blast texture layers")
	_expect(int(plan.get("pistol_feedback_entries", 0)) == 2, "headshot/legshot feedback entries should be counted for renderer QA")
	var families: Array = plan.get("families", [])
	for family in ["muzzle_glow", "impact_burst", "impact_ring", "lingering_field_glow", "projectile_silhouette", "bowling_trap_claw", "drone_rotor", "support_aircraft", "support_bomb_projectile", "support_airstrike_explosion"]:
		_expect(families.has(family), "texture remaster plan should include %s" % family)


func _verify_weapon_visual_identity_report() -> void:
	var renderer := Stage1CommandoFirearmRenderer.new()
	var report: Dictionary = renderer.build_visual_identity_report({
		"commando_firearm_projectiles": [
			{"weapon_id": "pistol", "kind": "bullet"},
			{"weapon_id": "commando_pistol", "kind": "bullet"},
			{"weapon_id": "ak47", "kind": "bullet"},
			{"weapon_id": "bazooka", "kind": "rocket"},
			{"weapon_id": "net_gun", "kind": "net"},
			{"weapon_id": "fire_support", "kind": "support"},
			{"weapon_id": "suicide_drone", "kind": "drone", "size": Vector2(48.0, 48.0), "rotor_angle": 90.0},
		],
		"commando_firearm_shell_casings": [
			{"weapon_id": "ak47"},
		],
		"commando_firearm_pistol_feedbacks": [
			{"kind": "headshot", "text": "헤드샷!"},
		],
		"commando_firearm_impact_flashes": [
			{"weapon_id": "fire_support", "kind": "grenade_explosion", "pos": Vector2(82.0, 42.0), "radius": 190.0},
		],
		"commando_firearm_support_calls": [
			{"origin": Vector2(20.0, 30.0), "target": Vector2(60.0, 70.0), "aircraft_active": true},
		],
		"commando_firearm_bowling_traps": [
			{"state": "capturing", "pos": Vector2(120.0, 130.0)},
		],
		"commando_firearm_lingering_effects": [
			{"kind": "trap_clamp", "pos": Vector2(120.0, 130.0)},
			{"kind": "fire_zone", "pos": Vector2(180.0, 210.0)},
		],
	})
	_expect(bool(report.get("all_required_families_present", false)), "Stage1 visual identity report should cover every Commando firearm family")
	_expect(int(report.get("family_count", 0)) == 8, "Stage1 visual identity report should distinguish eight Commando firearm families")
	var families: Array = report.get("weapon_families", [])
	for family in ["pistol", "commando_pistol", "ak47", "bazooka", "net_gun", "fire_support", "bowling_trap", "suicide_drone"]:
		_expect(families.has(family), "Stage1 visual identity report should include %s" % family)
	var layers: Array = report.get("layers", [])
	for layer in [
		"pistol:base_bullet",
		"commando_pistol:aimed_bullet",
		"ak47:rapid_bullet",
		"bazooka:accelerating_rocket_smoke",
		"net_gun:harpoon_rope",
		"fire_support:aircraft_silhouette",
		"fire_support:airstrike_grenade_explosion",
		"bowling_trap:ground_clamp_capturing",
		"suicide_drone:manual_drone_rotor",
	]:
		_expect(layers.has(layer), "Stage1 visual identity report should expose %s" % layer)
	_expect(not renderer.should_draw_projectile_trail({"weapon_id": "pistol", "kind": "bullet"}), "base pistol bullets should render without the stick-like speed trail")
	_expect(not renderer.should_draw_projectile_trail({"weapon_id": "commando_pistol", "kind": "bullet"}), "Commando pistol bullets should match the original clean circle without a speed trail")
	_expect(not renderer.should_draw_projectile_trail({"weapon_id": "ak47", "kind": "bullet"}), "AK-47 bullets should match the original clean circle without a speed trail")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
