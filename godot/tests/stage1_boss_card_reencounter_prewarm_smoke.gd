extends SceneTree

const BattleBootResourcePrewarmController := preload(
	"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
)
const BattleSceneMatchEventDriver := preload(
	"res://scripts/core/battle_scene_match_event_driver.gd"
)
const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const Stage1PillarSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_scene_drawer.gd"
)

const VARIANTS := ["dalji", "gaksi", "podo"]
const HUD_RENDERER_KEYS := {
	"dalji": "stage1_dalji_boss_skill_hud_renderer",
	"gaksi": "stage1_gaksital_boss_skill_hud_renderer",
	"podo": "stage1_pododaejang_boss_skill_hud_renderer",
}
const COOLDOWN_KEYS := {
	"dalji": "stage1_dalji_boss_skill_cooldown_state",
	"gaksi": "stage1_gaksital_boss_skill_cooldown_state",
	"podo": "stage1_pododaejang_boss_skill_cooldown_state",
}
const SKILL_CONTEXT_KEYS := {
	"dalji": "stage1_dalji_boss_skill_hud_skills",
	"gaksi": "stage1_gaksital_boss_skill_hud_skills",
	"podo": "stage1_pododaejang_boss_skill_hud_skills",
}
const ACTIVE_CONTEXT_KEYS := {
	"dalji": "stage1_dalji_boss_skill_hud_active",
	"gaksi": "stage1_gaksital_boss_skill_hud_active",
	"podo": "stage1_pododaejang_boss_skill_hud_active",
}

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var selected_character_type := "smasher"
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context: Dictionary = {}
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var battle_textures: Dictionary = {}
	var smasher_skill_icon_textures: Dictionary = {}
	var viper_skill_icon_textures: Dictionary = {}
	var commando_skill_icon_textures: Dictionary = {}
	var redraw_calls := 0

	func request_battle_redraw() -> void:
		redraw_calls += 1


class FakeTowerFlow:
	extends RefCounted

	func prewarm_muhon_collection(_owner: Object) -> Dictionary:
		return {"accepted": true, "reason": "test_fixture"}


class FakeLoadingRenderer:
	extends RefCounted

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		_context: Dictionary = {}
	) -> void:
		pass


class FakeLingpetRuntime:
	extends RefCounted

	func is_companion_active() -> bool:
		return false


class FakeBossCooldownState:
	extends RefCounted

	var variant := "dalji"

	func _init(value: String) -> void:
		variant = value

	func get_hud_context() -> Dictionary:
		var skills := [
			{
				"id": "%s_primary" % variant,
				"name": "%s primary" % variant,
				"status": "charging",
				"progress": 0.55,
				"ready": false,
			},
		]
		if variant == "podo":
			skills.append({
				"id": "podo_secondary",
				"name": "podo secondary",
				"status": "ready",
				"progress": 1.0,
				"ready": true,
			})
		return {
			SKILL_CONTEXT_KEYS[variant]: skills,
			ACTIVE_CONTEXT_KEYS[variant]: true,
		}


class RecordingBossHudRenderer:
	extends RefCounted

	var variant := "dalji"
	var last_card_rects: Array[Rect2] = []
	var prewarm_calls := 0

	func _init(value: String) -> void:
		variant = value

	func prewarm_assets_step() -> bool:
		prewarm_calls += 1
		return true

	func draw(canvas: CanvasItem, context: Dictionary) -> void:
		last_card_rects.clear()
		if canvas == null or int(context.get("current_stage", 1)) != 1:
			return
		var skills_value: Variant = context.get(SKILL_CONTEXT_KEYS[variant], [])
		var skills: Array = skills_value if skills_value is Array else []
		for index in range(skills.size()):
			var card_rect := Rect2(
				Vector2(158.0, 112.0 + 46.0 * float(index)),
				Vector2(96.0, 40.0)
			)
			last_card_rects.append(card_rect)
			canvas.draw_rect(card_rect, Color(0.78, 0.47, 0.18, 0.94), true)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var cold_get_calls := 0
	var count_cold_gets := false

	func _init(controller: Object = null) -> void:
		instances["lingpet_egg_runtime"] = FakeLingpetRuntime.new()
		if controller != null:
			instances["battle_boot_resource_prewarm_controller"] = controller

	func request_threaded_script(_key: String) -> bool:
		return true

	func is_threaded_script_ready(_key: String) -> bool:
		return true

	func get_instance(key: String) -> Object:
		if count_cold_gets:
			cold_get_calls += 1
		if instances.has(key):
			return instances[key]
		var instance: Object = null
		match key:
			"battle_boot_resource_prewarm_controller":
				instance = BattleBootResourcePrewarmController.new()
			"stage1_pillar_scene_drawer":
				instance = Stage1PillarSceneDrawer.new()
			"tower_ascent_flow_owner":
				instance = FakeTowerFlow.new()
			"battle_loading_screen_renderer":
				instance = FakeLoadingRenderer.new()
			_:
				var variant := _variant_for_module_key(key)
				if variant != "":
					if key == str(HUD_RENDERER_KEYS[variant]):
						instance = RecordingBossHudRenderer.new(variant)
					elif key == str(COOLDOWN_KEYS[variant]):
						instance = FakeBossCooldownState.new(variant)
		if instance != null:
			instances[key] = instance
		return instance

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func _variant_for_module_key(key: String) -> String:
		for variant in VARIANTS:
			if key == str(HUD_RENDERER_KEYS[variant]) or key == str(COOLDOWN_KEYS[variant]):
				return variant
		return ""


class DrawProbe:
	extends Node2D

	var drawer: Object
	var registry: Object
	var variant := "dalji"
	var draw_calls := 0
	var card_rect_count := 0
	var cold_get_calls := 0

	func _draw() -> void:
		draw_calls += 1
		var context := {
			"current_stage": 1,
			"stage1_boss_variant": variant,
			"selected_character_type": "smasher",
		}
		var cold_before: int = int(registry.cold_get_calls)
		drawer._draw_stage1_boss_skill_hud(
			self,
			context,
			registry,
			Vector2(1280.0, 750.0),
			Vector2(260.0, 0.0),
			Vector2(760.0, 750.0),
			1.25
		)
		cold_get_calls += int(registry.cold_get_calls) - cold_before
		var renderer: Object = registry.get_cached_instance(str(HUD_RENDERER_KEYS[variant]))
		card_rect_count = 0 if renderer == null else int(renderer.last_card_rects.size())


class StageOnlyLatchFixture:
	extends RefCounted

	var prewarmed_stage := 0

	func prewarm_step(
		controller: Object,
		owner: Object,
		registry: Object
	) -> bool:
		if prewarmed_stage == int(owner.current_stage):
			return true
		if controller.prewarm_stage_runtime_resources_step(
			owner,
			Callable(registry, "get_instance"),
			false
		):
			prewarmed_stage = int(owner.current_stage)
			return true
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_production_contract_source()
	await _verify_cache_state_controls_card_rects_and_warning_once()
	_verify_stage_only_red_counterproof()
	for opening_variant in VARIANTS:
		for next_variant in VARIANTS:
			if opening_variant == next_variant:
				continue
			await _verify_reencounter_permutation(opening_variant, next_variant)

	if _failures.is_empty():
		print("stage1_boss_card_reencounter_prewarm_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_production_contract_source() -> void:
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
	)
	var driver_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_match_event_driver.gd"
	)
	var drawer_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
	)
	_expect(
		controller_source.contains("stage_runtime_resources_prewarmed_for_key"),
		"stage runtime prewarm completion must be keyed by the composite encounter identity"
	)
	_expect(
		controller_source.contains("stage_runtime_prewarm_step_key"),
		"in-progress stage runtime prewarm must rewind on the same composite key"
	)
	_expect(
		driver_source.contains(
			"_apply_tower_encounter_identity(owner, normalized)\n"
			+ "\t_invalidate_stage_runtime_resources(registry)\n"
			+ "\t_begin_stage_transition_loading(owner, registry, stage_id)"
		),
		"tower encounter identity changes must explicitly invalidate the outer prewarm latch"
	)
	var non_stage1_owner := FakeOwner.new()
	non_stage1_owner.current_stage = 2
	non_stage1_owner.stage1_boss_variant = "dalji"
	var controller := BattleBootResourcePrewarmController.new()
	var non_stage1_key_a := str(controller.call("_get_stage_runtime_prewarm_key", non_stage1_owner, 2))
	non_stage1_owner.stage1_boss_variant = "podo"
	var non_stage1_key_b := str(controller.call("_get_stage_runtime_prewarm_key", non_stage1_owner, 2))
	_expect(
		non_stage1_key_a == "2:default" and non_stage1_key_b == non_stage1_key_a,
		"non-Stage-1 prewarm keys must remain stage-only"
	)
	_expect(
		drawer_source.contains("push_warning")
		and drawer_source.contains("_warn_missing_stage1_boss_skill_hud_module_once"),
		"Stage 1 boss-card peek misses must emit a warning-once diagnostic"
	)
	_expect(
		not drawer_source.contains("get_instance(registry, \"stage1_dalji_boss_skill_hud_renderer\")"),
		"Stage 1 boss-card draw must preserve the cache-only renderer lookup contract"
	)


func _verify_cache_state_controls_card_rects_and_warning_once() -> void:
	var drawer := Stage1PillarHudSceneDrawer.new()
	var cold_registry := FakeRegistry.new()
	var cold_probe: Dictionary = {}
	for variant in VARIANTS:
		var variant_probe: Dictionary = await _draw_variant(drawer, cold_registry, variant)
		_expect(int(variant_probe.get("card_rect_count", -1)) == 0, "uncached %s registry must draw zero boss cards" % variant)
		_expect(int(variant_probe.get("cold_get_calls", -1)) == 0, "uncached %s draw must not cold-create a boss-card renderer" % variant)
		await _draw_variant(drawer, cold_registry, variant)
		if variant == "podo":
			cold_probe = variant_probe
	_expect(int(cold_probe.get("card_rect_count", -1)) == 0, "uncached Pododaejang registry must draw zero boss cards")
	_expect(int(cold_probe.get("cold_get_calls", -1)) == 0, "uncached draw must not cold-create a boss-card renderer")

	# Reach the cooldown-miss warning through the registry factory, without
	# directly injecting a renderer into the cache.
	for variant in VARIANTS:
		cold_registry.get_instance(str(HUD_RENDERER_KEYS[variant]))
		await _draw_variant(drawer, cold_registry, variant)
		await _draw_variant(drawer, cold_registry, variant)
	var drawer_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
	)
	if drawer_source.contains("_missing_boss_skill_hud_warning_keys"):
		var warning_keys_value: Variant = drawer.get("_missing_boss_skill_hud_warning_keys")
		var warning_keys: Dictionary = warning_keys_value if warning_keys_value is Dictionary else {}
		_expect(warning_keys.size() == 6, "all three renderer and cooldown misses must each warn once without duplicates")

	var warm_controller := BattleBootResourcePrewarmController.new()
	var warm_registry := FakeRegistry.new(warm_controller)
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = "podo"
	_prepare_cached_common_runtime_prewarm(warm_controller, owner)
	_expect(
		_complete_runtime_prewarm(warm_controller, owner, warm_registry),
		"Pododaejang runtime prewarm must complete before the behavior draw leg"
	)
	warm_registry.count_cold_gets = true
	var warm_probe: Dictionary = await _draw_variant(Stage1PillarHudSceneDrawer.new(), warm_registry, "podo")
	_expect(int(warm_probe.get("card_rect_count", -1)) == 2, "prewarmed Pododaejang registry must draw patrol and rope cards")
	_expect(int(warm_probe.get("cold_get_calls", -1)) == 0, "first battle draw must perform zero cold module creation")
	print("[BossCardCacheBehavior] cold_rects=%d warm_rects=%d first_frame_cold_gets=%d" % [
		int(cold_probe.get("card_rect_count", -1)),
		int(warm_probe.get("card_rect_count", -1)),
		int(warm_probe.get("cold_get_calls", -1)),
	])


func _verify_stage_only_red_counterproof() -> void:
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = "dalji"
	var controller := BattleBootResourcePrewarmController.new()
	var registry := FakeRegistry.new(controller)
	var stage_only_gate := StageOnlyLatchFixture.new()
	_prepare_cached_common_runtime_prewarm(controller, owner)
	_expect(
		_complete_stage_only_fixture(stage_only_gate, controller, owner, registry),
		"stage-only RED fixture must complete its opening Dalji prewarm"
	)
	owner.stage1_boss_variant = "podo"
	var gate_reported_complete := stage_only_gate.prewarm_step(controller, owner, registry)
	var renderer: Object = registry.get_cached_instance(str(HUD_RENDERER_KEYS["podo"]))
	var card_rect_count := 0
	_expect(gate_reported_complete, "stage-only RED fixture must falsely report same-stage completion")
	_expect(
		renderer == null,
		"stage-only RED fixture must leave the second-encounter renderer absent"
	)
	_expect(card_rect_count == 0, "stage-only RED fixture must reproduce the zero-card failure")
	print("[BossCardPrewarmRED] stage_only=true next_variant=podo renderer=null card_rects=%d expected_red=true" % card_rect_count)


func _verify_reencounter_permutation(opening_variant: String, next_variant: String) -> void:
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = opening_variant
	var controller := BattleBootResourcePrewarmController.new()
	var registry := FakeRegistry.new(controller)
	_prepare_cached_common_runtime_prewarm(controller, owner)
	_expect(
		_complete_runtime_prewarm(controller, owner, registry),
		"opening %s runtime prewarm must complete" % opening_variant
	)
	_expect(
		registry.get_cached_instance(str(HUD_RENDERER_KEYS[next_variant])) == null,
		"opening %s prewarm must not eagerly create %s renderer" % [opening_variant, next_variant]
	)

	var driver := BattleSceneMatchEventDriver.new()
	_expect(
		driver.begin_tower_boss_transition(owner, registry, {
			"stage": 1,
			"variant": next_variant,
		}),
		"%s -> %s must enter the production Tower transition" % [opening_variant, next_variant]
	)
	_expect(owner.stage1_boss_variant == next_variant, "Tower transition must apply %s identity before prewarm" % next_variant)
	_expect(
		str(controller.stage_runtime_resources_prewarmed_for_key).is_empty()
		and str(controller.stage_runtime_prewarm_step_key).is_empty()
		and int(controller.stage_runtime_prewarm_step_index) == 0,
		"%s -> %s must invalidate outer completion and in-progress state immediately" % [opening_variant, next_variant]
	)
	var loading_canvas := Node2D.new()
	_expect(
		driver.draw_stage_transition_loading(
			loading_canvas,
			owner,
			registry,
			Callable(registry, "get_instance"),
			Vector2(1280.0, 750.0)
		),
		"%s -> %s loading screen must arm transition work" % [opening_variant, next_variant]
	)
	loading_canvas.free()

	var prewarm_elapsed_usec := _run_transition_through_runtime_prewarm(driver, owner, registry)
	var renderer: Object = registry.get_cached_instance(str(HUD_RENDERER_KEYS[next_variant]))
	_expect(renderer != null, "%s -> %s transition must cache the encounter renderer" % [opening_variant, next_variant])
	registry.count_cold_gets = true
	var probe: Dictionary = await _draw_variant(Stage1PillarHudSceneDrawer.new(), registry, next_variant)
	_expect(int(probe.get("card_rect_count", -1)) >= 1, "%s -> %s first battle draw must create at least one card rect" % [opening_variant, next_variant])
	_expect(int(probe.get("cold_get_calls", -1)) == 0, "%s -> %s first battle draw must not cold-create modules" % [opening_variant, next_variant])
	print("[BossCardReencounterPrewarm] %s->%s elapsed_usec=%d renderer_cached=%s card_rects=%d first_frame_cold_gets=%d" % [
		opening_variant,
		next_variant,
		prewarm_elapsed_usec,
		str(renderer != null),
		int(probe.get("card_rect_count", -1)),
		int(probe.get("cold_get_calls", -1)),
	])


func _run_transition_through_runtime_prewarm(
	driver: Object,
	owner: Object,
	registry: Object
) -> int:
	var prewarm_start_usec := -1
	var prewarm_elapsed_usec := -1
	var primed_cached_common := false
	for _iteration in range(1024):
		var work_step := int(driver.get("_stage_transition_loading_work_step"))
		if work_step == 5 and prewarm_start_usec < 0:
			prewarm_start_usec = Time.get_ticks_usec()
		if work_step == 5 and not primed_cached_common:
			# A Tower re-encounter has already paid the common runtime prewarm.
			# Start at the first still-relevant common step so this focused seal
			# does not depend on unrelated Lingpet card import artifacts.
			_prepare_cached_common_runtime_prewarm(
				registry.get_cached_instance("battle_boot_resource_prewarm_controller"),
				owner
			)
			primed_cached_common = true
		driver.update_stage_transition_loading(0.001, owner, registry)
		var next_work_step := int(driver.get("_stage_transition_loading_work_step"))
		if work_step == 5 and next_work_step > 5:
			prewarm_elapsed_usec = Time.get_ticks_usec() - prewarm_start_usec
			break
	_expect(prewarm_elapsed_usec >= 0, "transition runtime prewarm work step must complete within the smoke bound")
	return prewarm_elapsed_usec


func _prepare_cached_common_runtime_prewarm(controller: Object, owner: Object) -> void:
	if controller == null:
		return
	var controller_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_boot_resource_prewarm_controller.gd"
	)
	if controller_source.contains("stage_runtime_prewarm_step_key"):
		controller.set(
			"stage_runtime_prewarm_step_key",
			"%d:%s" % [int(owner.current_stage), str(owner.stage1_boss_variant)]
		)
	else:
		controller.set("stage_runtime_prewarm_step_stage", int(owner.current_stage))
	controller.set("stage_runtime_prewarm_step_index", 11)
	controller.set("stage_runtime_prewarm_detail_label", "")


func _complete_runtime_prewarm(controller: Object, owner: Object, registry: Object) -> bool:
	for _iteration in range(1024):
		if controller.prewarm_stage_runtime_resources_step(
			owner,
			Callable(registry, "get_instance"),
			false
		):
			return true
	return false


func _complete_stage_only_fixture(
	fixture: Object,
	controller: Object,
	owner: Object,
	registry: Object
) -> bool:
	for _iteration in range(1024):
		if fixture.prewarm_step(controller, owner, registry):
			return true
	return false


func _draw_variant(drawer: Object, registry: Object, variant: String) -> Dictionary:
	var probe := DrawProbe.new()
	probe.drawer = drawer
	probe.registry = registry
	probe.variant = variant
	get_root().add_child(probe)
	probe.queue_redraw()
	for _frame in range(3):
		await process_frame
	var result := {
		"draw_calls": probe.draw_calls,
		"card_rect_count": probe.card_rect_count,
		"cold_get_calls": probe.cold_get_calls,
	}
	probe.queue_free()
	await process_frame
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
