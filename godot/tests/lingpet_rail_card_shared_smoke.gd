extends SceneTree

# Verifies the shared LingpetRailCard helper (build_entry / append_entry /
# tooltip_info / is_lingpet_skill) and that ALL FIVE stages' boss skill-card
# rails wire the hatched lingpet card through it (the companion persists across
# every stage, so its card must ride every stage's rail, not just Stage 1).

const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

var _failures: Array[String] = []


class FakeLingpetRuntime:
	extends RefCounted

	var active := true
	var snapshot := {}

	func is_companion_active(_pet_id: String = "") -> bool:
		return active

	func is_maribo_companion_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeRegistry:
	extends RefCounted

	var runtime: Object = null

	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return runtime
		return null


func _init() -> void:
	_verify_is_lingpet_skill()
	_verify_build_entry_states()
	_verify_build_entry_inactive_is_empty()
	_verify_append_entry_forces_active_flag()
	_verify_append_entry_noop_when_inactive()
	_verify_tooltip_info()
	_verify_all_stage_rails_wire_shared_helper()
	_verify_prewarm_registered()

	if _failures.is_empty():
		print("lingpet_rail_card_shared_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_runtime(active: bool, cooldown: float, ready: bool, projectile: bool, puddle: bool, winding_up: bool, flash: float = 0.0) -> FakeLingpetRuntime:
	var runtime := FakeLingpetRuntime.new()
	runtime.active = active
	runtime.snapshot = {
		"companion_skill_id": "maribo_hydro_sphere" if active else "",
		"companion_skill_name": "하이드로 스피어",
		"companion_skill_description": "물의 기운이 담긴 창을 던집니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
		"companion_skill_cooldown": cooldown,
		"companion_skill_cooldown_duration": 40.0,
		"companion_skill_ready": ready,
		"companion_skill_flash_ratio": flash,
		"companion_skill_winding_up": winding_up,
		"hydro_sphere_projectile_active": projectile,
		"hydro_sphere_puddle_active": puddle,
		"headbutt_active": false,
		"headbutt_impact_active": false,
		"headbutt_miss_active": false,
		"headbutt_repeat_wait_active": false,
	}
	return runtime


func _make_registry(runtime: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.runtime = runtime
	return registry


func _verify_is_lingpet_skill() -> void:
	_expect(LingpetRailCard.is_lingpet_skill({"is_lingpet": true}), "is_lingpet_skill should detect the is_lingpet flag")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "maribo_hydro_sphere"}), "is_lingpet_skill should detect the maribo skill id")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "lunabi_headbutt"}), "is_lingpet_skill should detect the Lunabi skill id through the catalog")
	_expect(not LingpetRailCard.is_lingpet_skill({"id": "whip"}), "is_lingpet_skill should reject boss skills")


func _verify_build_entry_states() -> void:
	# Charging: cooldown remaining, not ready, not casting -> progress < 1.
	var charging := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 20.0, false, false, false, false)))
	_expect(not charging.is_empty(), "build_entry should produce an entry for an active companion")
	_expect(str(charging.get("id", "")) == "maribo_hydro_sphere", "rail entry id should be maribo_hydro_sphere")
	_expect(bool(charging.get("is_lingpet", false)), "rail entry should carry is_lingpet")
	_expect(charging.get("accent_color", Color.BLACK) == LingpetRailCard.ACCENT, "rail entry accent should be the cyan ally accent")
	_expect(str(charging.get("card_texture_path", "")).ends_with("maribo_hydro_sphere_skillcard_imagegen_v2.png"), "rail entry should carry the catalog-backed skill-card texture path")
	_expect(not str(charging.get("description", "")).is_empty(), "rail entry should carry the companion skill description for tooltip paths")
	_expect(str(charging.get("status", "")) == "charging", "remaining cooldown should read as charging")
	_expect(absf(float(charging.get("progress", -1.0)) - 0.5) <= 0.01, "progress should be 1 - cooldown/duration (20/40 -> 0.5)")

	# Ready: cooldown 0, ready, not casting.
	var ready := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 0.0, true, false, false, false)))
	_expect(str(ready.get("status", "")) == "ready", "zero cooldown + ready should read as ready")
	_expect(absf(float(ready.get("progress", -1.0)) - 1.0) <= 0.01, "ready entry progress should be full")

	# Casting: winding up overrides to casting even before the projectile launches.
	var windup := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 0.0, true, false, false, true)))
	_expect(str(windup.get("status", "")) == "casting", "wind-up should read as casting on the rail card")
	var projectile := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 30.0, false, true, false, false)))
	_expect(str(projectile.get("status", "")) == "casting", "an in-flight hydro projectile should read as casting")

	var lunabi_runtime := FakeLingpetRuntime.new()
	lunabi_runtime.active = true
	lunabi_runtime.snapshot = {
		"companion_skill_id": "lunabi_headbutt",
		"companion_skill_name": "박치기",
		"companion_skill_description": "루나비가 상대 패들을 향해 돌진합니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
		"companion_skill_cooldown": 12.0,
		"companion_skill_cooldown_duration": 30.0,
		"companion_skill_ready": false,
		"companion_skill_flash_ratio": 0.0,
		"companion_skill_winding_up": false,
		"headbutt_active": true,
		"headbutt_impact_active": false,
		"headbutt_miss_active": false,
		"headbutt_repeat_wait_active": false,
	}
	var lunabi_entry := LingpetRailCard.build_entry(_make_registry(lunabi_runtime))
	_expect(str(lunabi_entry.get("id", "")) == "lunabi_headbutt", "rail entry should support Lunabi Headbutt")
	_expect(str(lunabi_entry.get("status", "")) == "casting", "an active Lunabi Headbutt dash should read as casting")
	_expect(absf(float(lunabi_entry.get("cooldown_total", 0.0)) - 30.0) <= 0.01, "Lunabi rail entry should carry its 30s cooldown")
	_expect(str(lunabi_entry.get("card_texture_path", "")).ends_with("lunabi_headbutt_skillcard_imagegen_v1.png"), "Lunabi rail entry should carry the imagegen skill-card texture path")
	lunabi_runtime.snapshot["headbutt_active"] = false
	lunabi_runtime.snapshot["headbutt_repeat_wait_active"] = true
	var lunabi_repeat_wait_entry := LingpetRailCard.build_entry(_make_registry(lunabi_runtime))
	_expect(str(lunabi_repeat_wait_entry.get("status", "")) == "casting", "Lunabi Headbutt repeat wait should stay in casting state on the rail card")


func _verify_build_entry_inactive_is_empty() -> void:
	_expect(LingpetRailCard.build_entry(_make_registry(_make_runtime(false, 0.0, false, false, false, false))).is_empty(), "build_entry should be empty when the companion is not active (pre-hatch mystery)")
	_expect(LingpetRailCard.build_entry(_make_registry(null)).is_empty(), "build_entry should be empty when no lingpet runtime is registered")
	_expect(LingpetRailCard.build_entry(null).is_empty(), "build_entry should be empty for a null registry")


func _verify_append_entry_forces_active_flag() -> void:
	var registry := _make_registry(_make_runtime(true, 0.0, true, false, false, false))
	var context := {"stage9_boss_skill_hud_skills": [{"id": "boss_a"}], "stage9_boss_skill_hud_active": false}
	LingpetRailCard.append_entry(context, registry, "stage9_boss_skill_hud_skills", "stage9_boss_skill_hud_active")
	var skills: Array = context.get("stage9_boss_skill_hud_skills", [])
	_expect(skills.size() == 2, "append_entry should append the lingpet entry to the rail array")
	_expect(str((skills[1] as Dictionary).get("id", "")) == "maribo_hydro_sphere", "appended entry should be the lingpet card")
	_expect(bool(context.get("stage9_boss_skill_hud_active", false)), "append_entry MUST force the rail active flag true (renderers early-return on a false flag)")
	# Must not mutate the caller's original array reference in place.
	_expect(skills.size() == 2, "append_entry should write a fresh duplicated array")


func _verify_append_entry_noop_when_inactive() -> void:
	var registry := _make_registry(_make_runtime(false, 0.0, false, false, false, false))
	var context := {"stage9_boss_skill_hud_skills": [{"id": "boss_a"}], "stage9_boss_skill_hud_active": false}
	LingpetRailCard.append_entry(context, registry, "stage9_boss_skill_hud_skills", "stage9_boss_skill_hud_active")
	_expect((context.get("stage9_boss_skill_hud_skills", []) as Array).size() == 1, "append_entry should be a no-op when the companion is not active")
	_expect(not bool(context.get("stage9_boss_skill_hud_active", true)), "append_entry should NOT force the active flag when there is no lingpet entry")


func _verify_tooltip_info() -> void:
	var info := LingpetRailCard.tooltip_info()
	_expect(str(info.get("name", "")) == "하이드로 스피어", "tooltip should name the Hydro Sphere skill")
	_expect(absf(float(info.get("cooldown_seconds", 0.0)) - 40.0) <= 0.01, "tooltip should expose cooldown_seconds 40 (stage1/4 + shared spec)")
	_expect(not str(info.get("cooldown", "")).is_empty(), "tooltip should expose a cooldown string (stage5 own tooltip reads it)")
	_expect(not str(info.get("description", "")).is_empty(), "tooltip should expose a description")
	var future_skill_info := LingpetRailCard.tooltip_info({
		"id": "test_bubble_guard",
		"is_lingpet": true,
		"label": "Bubble Guard",
		"trigger_label": "Auto",
		"cooldown_total": 18.0,
		"description": "Future lingpet tooltip copy",
	})
	_expect(str(future_skill_info.get("name", "")) == "Bubble Guard", "tooltip should use the live lingpet card label, not the Maribo fallback")
	_expect(str(future_skill_info.get("trigger", "")) == "Auto", "tooltip should use the live lingpet trigger label")
	_expect(absf(float(future_skill_info.get("cooldown_seconds", 0.0)) - 18.0) <= 0.01, "tooltip should use the live lingpet skill cooldown")
	_expect(str(future_skill_info.get("description", "")) == "Future lingpet tooltip copy", "tooltip should use the live lingpet skill description")
	var lunabi_info := LingpetRailCard.tooltip_info({
		"id": "lunabi_headbutt",
		"is_lingpet": true,
		"label": "박치기",
		"trigger_label": "자동",
		"cooldown_total": 30.0,
		"description": "루나비가 돌진합니다.",
	})
	_expect(str(lunabi_info.get("name", "")) == "박치기", "tooltip should use the live Lunabi Headbutt label")
	_expect(absf(float(lunabi_info.get("cooldown_seconds", 0.0)) - 30.0) <= 0.01, "tooltip should expose Lunabi Headbutt's 30s cooldown")


func _verify_all_stage_rails_wire_shared_helper() -> void:
	# Each stage's boss-skill HUD composition must append via the shared helper with
	# its own rail keys, and each renderer must delegate the lingpet card to the helper.
	var stages := [
		{
			"drawer": "res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
			"skills_key": "stage1_dalji_boss_skill_hud_skills",
			"active_key": "stage1_dalji_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
			"skills_key": "stage2_boss_skill_hud_skills",
			"active_key": "stage2_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
			"skills_key": "stage3_boss_skill_hud_skills",
			"active_key": "stage3_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage4/stage4_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
			"skills_key": "stage4_ponk_boss_skill_hud_skills",
			"active_key": "stage4_ponk_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
			"skills_key": "stage5_boss_skill_hud_skills",
			"active_key": "stage5_boss_skill_hud_active",
		},
	]
	var router_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage_runtime_router.gd")
	_expect(router_source.find("\"pillar_scene_drawer\": \"stage5_hongryun_pillar_scene_drawer\"") >= 0, "Stage 5 live router should use the Hongryun pillar drawer covered by this test")
	for stage in stages:
		var drawer_source: String = FileAccess.get_file_as_string(str(stage["drawer"]))
		_expect(drawer_source.find("lingpet_rail_card.gd") >= 0, "%s should preload the shared lingpet rail card helper" % str(stage["drawer"]))
		_expect(drawer_source.find("append_entry(") >= 0, "%s should append the lingpet card via the shared helper" % str(stage["drawer"]))
		_expect(drawer_source.find("\"%s\"" % str(stage["skills_key"])) >= 0, "%s should pass its boss rail skills key %s" % [str(stage["drawer"]), str(stage["skills_key"])])
		_expect(drawer_source.find("\"%s\"" % str(stage["active_key"])) >= 0, "%s should pass its boss rail active-flag key %s" % [str(stage["drawer"]), str(stage["active_key"])])
		var renderer_source: String = FileAccess.get_file_as_string(str(stage["renderer"]))
		_expect(renderer_source.find("LingpetRailCard") >= 0, "%s should reference the shared LingpetRailCard helper" % str(stage["renderer"]))
		_expect(renderer_source.find("is_lingpet_skill") >= 0, "%s should delegate the lingpet entry via is_lingpet_skill" % str(stage["renderer"]))


func _verify_prewarm_registered() -> void:
	var controller_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	_expect(controller_source.find("LingpetRailCard.prewarm()") >= 0, "boot prewarm controller should warm the lingpet rail card texture once (no hot-path lazy load on any stage)")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
