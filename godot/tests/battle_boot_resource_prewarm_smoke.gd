extends SceneTree

const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
const BattleBootWarmupController := preload("res://scripts/core/battle_boot_warmup_controller.gd")
const BattleBootWarmupPlan := preload("res://scripts/core/battle_boot_warmup_plan.gd")


class FakeOwner:
	var current_stage := 1
	var selected_character_type := "smasher"
	var battle_textures: Dictionary = {}
	var smasher_skill_icon_textures: Dictionary = {}
	var viper_skill_icon_textures: Dictionary = {}
	var commando_skill_icon_textures: Dictionary = {}


class FakePerfLogger:
	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func has_label_containing(fragment: String) -> bool:
		for label in labels:
			if label.find(fragment) >= 0:
				return true
		return false


class FakePrewarmModule:
	var prewarm_count := 0

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeRuntimeNodePrewarmModule:
	var prewarm_count := 0
	var runtime_node_calls := 0
	var last_runtime_owner: Object = null

	func prewarm_assets() -> void:
		prewarm_count += 1

	func prewarm_runtime_nodes(owner: Object = null) -> void:
		runtime_node_calls += 1
		last_runtime_owner = owner


class FakeBallRenderer:
	var step_calls := 0
	var runtime_step_calls := 0
	var last_runtime_owner: Object = null

	func prewarm_assets_step() -> bool:
		step_calls += 1
		return true

	func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
		runtime_step_calls += 1
		last_runtime_owner = owner
		return true


class FakeActiveItemRuntime:
	var prewarm_count := 0
	var step_calls := 0
	var last_visuals: Object
	var complete_after := 3

	func prewarm_assets_step(active_item_hud_visuals: Object = null) -> bool:
		step_calls += 1
		last_visuals = active_item_hud_visuals
		return step_calls >= complete_after

	func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
		prewarm_count += 1
		last_visuals = active_item_hud_visuals


class FakeMythicItemRuntime:
	var prewarm_count := 0
	var acquisition_asset_prewarm_count := 0
	var acquisition_asset_step_calls := 0
	var acquisition_asset_complete_after := 3
	var acquisition_prewarm_count := 0
	var last_acquisition_owner: Object = null

	func prewarm_assets() -> void:
		prewarm_count += 1

	func prewarm_acquisition_cinematic_assets_step() -> bool:
		acquisition_asset_step_calls += 1
		if acquisition_asset_step_calls >= acquisition_asset_complete_after:
			acquisition_asset_prewarm_count += 1
			return true
		return false

	func prewarm_acquisition_cinematic_assets() -> void:
		acquisition_asset_prewarm_count += 1

	func prewarm_acquisition_cinematic(owner: Object = null) -> void:
		acquisition_prewarm_count += 1
		last_acquisition_owner = owner


class FakeStagedPrewarmModule:
	var step_calls := 0
	var monolithic_calls := 0
	var runtime_step_calls := 0
	var last_runtime_owner: Object = null
	var complete_after := 3

	func prewarm_assets_step() -> bool:
		step_calls += 1
		return step_calls >= complete_after

	func prewarm_assets() -> void:
		monolithic_calls += 1

	func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
		runtime_step_calls += 1
		last_runtime_owner = owner
		return true


class FakeStagedResultScreen:
	var step_calls := 0
	var threaded_step_calls := 0
	var prewarm_count := 0
	var shell_prewarm_count := 0
	var complete_after := 4
	var last_owner: Object = null

	func prewarm_scene_shell() -> bool:
		shell_prewarm_count += 1
		return true

	func prewarm_assets_threaded_step(owner: Object = null, _registry: Object = null) -> bool:
		threaded_step_calls += 1
		return prewarm_assets_step(owner, _registry)

	func prewarm_assets_step(owner: Object = null, _registry: Object = null) -> bool:
		step_calls += 1
		last_owner = owner
		if step_calls >= complete_after:
			prewarm_count += 1
			return true
		return false

	func prewarm_assets(owner: Object = null, _registry: Object = null) -> void:
		prewarm_count += 1
		last_owner = owner


class FakeGameAudio:
	var setup_calls := 0
	var setup_complete_after := 6
	var prime_calls := 0
	var last_prime_stage := 0

	func setup_step(_owner: Object = null) -> bool:
		setup_calls += 1
		return setup_calls >= setup_complete_after

	func get_setup_progress() -> float:
		return clampf(float(setup_calls) / float(setup_complete_after), 0.0, 1.0)

	func prime_stage_bgm(stage: int) -> void:
		prime_calls += 1
		last_prime_stage = stage


class FakeBattleResources:
	var step_calls := 0
	var load_all_calls := 0
	var complete_after := 3
	var last_context: Dictionary = {}
	var cache: Dictionary = {
		"loaded_stage": 1,
		"smasher_skill_icon_textures": {"wheel": RefCounted.new()},
		"viper_skill_icon_textures": {},
		"commando_skill_icon_textures": {},
	}

	func prewarm_transition_textures_step(context: Dictionary = {}) -> bool:
		step_calls += 1
		last_context = context.duplicate(true)
		cache["loaded_stage"] = int(context.get("current_stage", 1))
		return step_calls >= complete_after

	func get_resource_cache() -> Dictionary:
		return cache

	func load_all(context: Dictionary = {}) -> Dictionary:
		load_all_calls += 1
		last_context = context.duplicate(true)
		cache["loaded_stage"] = int(context.get("current_stage", 1))
		return cache


class FakePillarSceneModule:
	var prewarm_count := 0
	var last_selected_character_type := ""
	var last_module_getter_valid := false

	func prewarm_assets(module_getter: Callable = Callable(), selected_character_type: String = "smasher") -> void:
		prewarm_count += 1
		last_module_getter_valid = module_getter.is_valid()
		last_selected_character_type = selected_character_type


class FakeStagedPillarSceneModule:
	var step_calls := 0
	var monolithic_calls := 0
	var complete_after := 3
	var last_selected_character_type := ""
	var last_module_getter_valid := false

	func prewarm_assets_step(module_getter: Callable = Callable(), selected_character_type: String = "smasher") -> bool:
		step_calls += 1
		last_module_getter_valid = module_getter.is_valid()
		last_selected_character_type = selected_character_type
		return step_calls >= complete_after

	func prewarm_assets(module_getter: Callable = Callable(), selected_character_type: String = "smasher") -> void:
		monolithic_calls += 1
		last_module_getter_valid = module_getter.is_valid()
		last_selected_character_type = selected_character_type


class FakePerkDebugPicker:
	var prewarm_count := 0
	var last_catalog: Object
	var last_owner: Object
	var last_icon_renderer: Object

	func prewarm_assets(catalog: Object = null, owner: Object = null, icon_renderer: Object = null) -> void:
		prewarm_count += 1
		last_catalog = catalog
		last_owner = owner
		last_icon_renderer = icon_renderer
		if icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
			icon_renderer.prewarm_assets()


class FakeCharacterInfo:
	var prewarm_count := 0
	var last_owner: Object
	var last_registry: Object
	var last_module_getter_valid := false
	var last_include_shared_icon_assets := true

	func prewarm_assets(
		owner: Object = null,
		registry: Object = null,
		module_getter: Callable = Callable(),
		include_shared_icon_assets: bool = true
	) -> void:
		prewarm_count += 1
		last_owner = owner
		last_registry = registry
		last_module_getter_valid = module_getter.is_valid()
		last_include_shared_icon_assets = include_shared_icon_assets


class FakeRegistry:
	var warmup_plan := BattleBootWarmupPlan.new()
	var resource_prewarm := BattleBootResourcePrewarmController.new()
	var battle_perf_logger := FakePerfLogger.new()
	var battle_resources := FakeBattleResources.new()
	var ball_renderer := FakeBallRenderer.new()
	var game_audio := FakeGameAudio.new()
	var weather := FakePrewarmModule.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var mythic_item_runtime := FakeMythicItemRuntime.new()
	var active_item_hud_visuals := RefCounted.new()
	var perk_icon_renderer := FakePrewarmModule.new()
	var perk_overlay_renderer := FakePrewarmModule.new()
	var perk_debug_picker := FakePerkDebugPicker.new()
	var perk_catalog := RefCounted.new()
	var character_info := FakeCharacterInfo.new()
	var result_screen := FakeStagedResultScreen.new()
	var monkey_blessing_delivery_state := FakeStagedPrewarmModule.new()
	var commando_reload_delivery_state := FakeStagedPrewarmModule.new()
	var stage1_bg := FakePrewarmModule.new()
	var stage1_pillar_scene := FakePillarSceneModule.new()
	var stage1_balloon_event := FakeStagedPrewarmModule.new()
	var stage1_skill_hud := FakeStagedPrewarmModule.new()
	var stage1_actor_renderer := FakePrewarmModule.new()
	var commando_firearm_selector := FakeStagedPrewarmModule.new()
	var skill_cutin_overlay_host := FakeRuntimeNodePrewarmModule.new()
	var smasher_plasma_state := FakeStagedPrewarmModule.new()
	var smasher_recovery_state := FakeStagedPrewarmModule.new()
	var smasher_warp_gate_state := FakePrewarmModule.new()
	var smasher_wheel_state := FakePrewarmModule.new()
	var smasher_shield_kiting_state := FakePrewarmModule.new()
	var viper_input_reader := FakePrewarmModule.new()
	var viper_skill_runtime := FakeStagedPrewarmModule.new()
	var viper_skill_state := FakePrewarmModule.new()
	var viper_skill_config := FakePrewarmModule.new()
	var viper_jetpack_state := FakePrewarmModule.new()
	var stage2_bg := FakeStagedPrewarmModule.new()
	var stage2_pillar_scene := FakeStagedPillarSceneModule.new()
	var stage2_actor_renderer := FakeStagedPrewarmModule.new()
	var stage2_skill_hud := FakeStagedPrewarmModule.new()
	var stage2_monkey_event := FakeStagedPrewarmModule.new()
	var stage3_bg := FakePrewarmModule.new()
	var stage3_actor_renderer := FakeStagedPrewarmModule.new()
	var stage3_skill_hud := FakePrewarmModule.new()
	var stage4_bg := FakeStagedPrewarmModule.new()
	var stage4_actor_renderer := FakeStagedPrewarmModule.new()
	var stage4_gauge_hud := FakePrewarmModule.new()
	var stage4_bird_event := FakePrewarmModule.new()
	var stage4_brazier_monk_event := FakePrewarmModule.new()
	var stage4_moon_event := FakePrewarmModule.new()
	var stage4_ponk_skill_state := FakeStagedPrewarmModule.new()
	var stage4_boss_skill_hud := FakePrewarmModule.new()
	var stage5_bg := FakeStagedPrewarmModule.new()
	var stage5_actor_renderer := FakeStagedPrewarmModule.new()
	var stage5_pillar_scene := FakeStagedPillarSceneModule.new()
	var stage5_skill_hud := FakeStagedPrewarmModule.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_boot_resource_prewarm_controller":
				return resource_prewarm
			"battle_boot_warmup_plan":
				return warmup_plan
			"battle_perf_logger":
				return battle_perf_logger
			"battle_resources":
				return battle_resources
			"ball_renderer":
				return ball_renderer
			"game_audio":
				return game_audio
			"weather_event_renderer":
				return weather
			"active_item_runtime":
				return active_item_runtime
			"mythic_item_runtime":
				return mythic_item_runtime
			"active_item_hud_visuals":
				return active_item_hud_visuals
			"runtime_perk_icon_renderer":
				return perk_icon_renderer
			"runtime_perk_overlay_renderer":
				return perk_overlay_renderer
			"runtime_perk_debug_picker":
				return perk_debug_picker
			"runtime_perk_catalog":
				return perk_catalog
			"character_info_overlay":
				return character_info
			"stage_clear_result_screen":
				return result_screen
			"monkey_blessing_delivery_state":
				return monkey_blessing_delivery_state
			"commando_reload_delivery_state":
				return commando_reload_delivery_state
			"stage1_pillar_background":
				return stage1_bg
			"stage1_pillar_scene_drawer":
				return stage1_pillar_scene
			"stage1_balloon_event":
				return stage1_balloon_event
			"stage1_dalji_boss_skill_hud_renderer":
				return stage1_skill_hud
			"stage1_actor_renderer":
				return stage1_actor_renderer
			"commando_firearm_selector_renderer":
				return commando_firearm_selector
			"skill_cutin_overlay_host":
				return skill_cutin_overlay_host
			"smasher_plasma_state":
				return smasher_plasma_state
			"smasher_recovery_state":
				return smasher_recovery_state
			"stage2_pillar_background":
				return stage2_bg
			"stage2_pillar_scene_drawer":
				return stage2_pillar_scene
			"stage2_actor_renderer":
				return stage2_actor_renderer
			"stage2_boss_skill_hud_renderer":
				return stage2_skill_hud
			"stage2_monkey_banana_event":
				return stage2_monkey_event
			"stage3_pillar_background":
				return stage3_bg
			"stage3_actor_renderer":
				return stage3_actor_renderer
			"stage3_boss_skill_hud_renderer":
				return stage3_skill_hud
			"stage4_pillar_background":
				return stage4_bg
			"stage4_actor_renderer":
				return stage4_actor_renderer
			"stage4_ponk_gauge_hud_renderer":
				return stage4_gauge_hud
			"stage4_bird_event":
				return stage4_bird_event
			"stage4_brazier_monk_event":
				return stage4_brazier_monk_event
			"stage4_moon_event":
				return stage4_moon_event
			"stage4_ponk_skill_state":
				return stage4_ponk_skill_state
			"stage4_ponk_boss_skill_hud_renderer":
				return stage4_boss_skill_hud
			"stage5_hongryun_pillar_background":
				return stage5_bg
			"stage5_hongryun_actor_renderer":
				return stage5_actor_renderer
			"stage5_hongryun_pillar_scene_drawer":
				return stage5_pillar_scene
			"stage5_hongryun_boss_skill_hud_renderer":
				return stage5_skill_hud
			"smasher_warp_gate_state":
				return smasher_warp_gate_state
			"smasher_wheel_state":
				return smasher_wheel_state
			"smasher_shield_kiting_state":
				return smasher_shield_kiting_state
			"viper_input_reader":
				return viper_input_reader
			"viper_skill_runtime":
				return viper_skill_runtime
			"viper_skill_state":
				return viper_skill_state
			"viper_skill_config":
				return viper_skill_config
			"viper_jetpack_state":
				return viper_jetpack_state
		return null


var _failures: Array[String] = []
var _registry := FakeRegistry.new()
var _boot_initialize_calls := 0
var _boot_redraw_calls := 0


func _init() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()

	controller.prewarm_stage_runtime_resources(owner, Callable(self, "_get_module"))
	controller.prewarm_stage_runtime_resources(owner, Callable(self, "_get_module"))

	_expect(_registry.active_item_runtime.step_calls == 3, "stage runtime prewarm should stage active item assets before the first visible draw")
	_expect(_registry.active_item_runtime.prewarm_count == 0, "stage runtime prewarm should avoid monolithic active item loading when staged")
	_expect(_registry.active_item_runtime.last_visuals == _registry.active_item_hud_visuals, "active item prewarm should receive HUD visuals")
	_expect(_registry.mythic_item_runtime.prewarm_count == 0, "stage runtime prewarm should defer mythic debug assets until needed")
	_expect(_registry.mythic_item_runtime.acquisition_asset_step_calls == 3, "stage runtime prewarm should stage mythic field-pickup cinematic static assets")
	_expect(_registry.mythic_item_runtime.acquisition_asset_prewarm_count == 1, "stage runtime prewarm should warm mythic field-pickup cinematic static assets once")
	_expect(_registry.mythic_item_runtime.acquisition_prewarm_count == 0, "stage runtime prewarm should not build the mythic field-pickup Node2D host before the first battle frame")
	_expect(_registry.mythic_item_runtime.last_acquisition_owner == null, "asset-only mythic field-pickup prewarm should not require the battle owner")
	_expect(_registry.perk_icon_renderer.prewarm_count == 1, "stage runtime prewarm should warm runtime perk choice icons before the first card draw")
	_expect(_registry.perk_overlay_renderer.prewarm_count == 1, "stage runtime prewarm should warm runtime perk overlay text caches before the first overlay draw")
	_expect(_registry.perk_debug_picker.prewarm_count == 0, "stage runtime prewarm should defer perk debug picker assets until opened")
	_expect(_registry.character_info.prewarm_count == 0, "stage runtime prewarm should defer character info assets until opened")
	_expect(_registry.result_screen.shell_prewarm_count == 0, "stage runtime prewarm should leave the stage-clear result shell for the dedicated result warmup")
	_expect(_registry.result_screen.prewarm_count == 0, "stage runtime prewarm should leave full stage-clear result assets for the dedicated result warmup")
	_expect(_registry.result_screen.step_calls == 0, "stage runtime prewarm should not touch the heavy result staged path before its dedicated warmup")
	_expect(_registry.monkey_blessing_delivery_state.step_calls == 3, "stage runtime prewarm should stage Monkey Blessing delivery assets before the first visible draw")
	_expect(_registry.monkey_blessing_delivery_state.monolithic_calls == 0, "Monkey Blessing delivery prewarm should avoid monolithic loading when staged")
	_expect(_registry.commando_reload_delivery_state.step_calls == 3, "stage runtime prewarm should stage Commando reload delivery assets before the first visible draw")
	_expect(_registry.commando_reload_delivery_state.monolithic_calls == 0, "Commando reload delivery prewarm should avoid monolithic loading when staged")
	_expect(_registry.ball_renderer.step_calls == 1, "stage runtime prewarm should warm ball renderer assets before the first visible draw")
	_expect(_registry.ball_renderer.runtime_step_calls == 1, "stage runtime prewarm should pre-create ball renderer runtime FX nodes")
	_expect(_registry.ball_renderer.last_runtime_owner == owner, "ball renderer runtime node prewarm should receive the battle owner")
	_expect(_registry.skill_cutin_overlay_host.prewarm_count == 1, "stage runtime prewarm should warm Smasher cut-in assets once")
	_expect(_registry.skill_cutin_overlay_host.runtime_node_calls == 1, "stage runtime prewarm should pre-create the Smasher cut-in FX host")
	_expect(_registry.skill_cutin_overlay_host.last_runtime_owner == owner, "Smasher cut-in FX host prewarm should receive the battle owner")
	_expect(
		_registry.battle_perf_logger.has_label_containing("selected_character.04_skill_cutin_overlay_host.assets"),
		"selected character prewarm should report per-module cut-in asset timing"
	)
	_expect(
		_registry.battle_perf_logger.has_label_containing("selected_character.04_skill_cutin_overlay_host.runtime_nodes"),
		"selected character prewarm should report per-module cut-in runtime node timing"
	)
	_expect(_registry.smasher_warp_gate_state.prewarm_count == 1, "stage runtime prewarm should warm Smasher warp gate assets once")
	_expect(_registry.smasher_wheel_state.prewarm_count == 1, "stage runtime prewarm should warm Smasher wheel assets once")
	_expect(_registry.smasher_plasma_state.step_calls == 3, "stage runtime prewarm should stage Smasher plasma textures")
	_expect(_registry.smasher_plasma_state.monolithic_calls == 0, "Smasher plasma prewarm should avoid the monolithic asset path when staged")
	_expect(_registry.smasher_recovery_state.step_calls == 3, "stage runtime prewarm should stage Smasher recovery textures")
	_expect(_registry.smasher_recovery_state.monolithic_calls == 0, "Smasher recovery prewarm should avoid the monolithic asset path when staged")
	_expect(_registry.smasher_shield_kiting_state.prewarm_count == 1, "stage runtime prewarm should warm Smasher shield assets once")

	_verify_full_stage_clear_result_prewarm_remains_staged()
	_verify_stage1_staged_visual_prewarm()
	_verify_stage1_soldier_commando_prewarm()
	_verify_stage2_staged_playfield_prewarm()
	_verify_stage3_staged_playfield_prewarm()
	_verify_stage4_staged_playfield_and_skill_prewarm()
	_verify_stage5_visual_shell_prewarm()
	_verify_battle_texture_prewarm_is_staged()
	_verify_viper_runtime_node_prewarm()
	_verify_boot_warmup_uses_staged_runtime_prewarm()
	_verify_boot_warmup_result_step_uses_result_prewarm_signature()
	_verify_full_boot_warmup_finishes_without_stalling()

	if _failures.is_empty():
		print("battle_boot_resource_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _get_module(key: String) -> Object:
	return _registry.get_instance(key)


func _mark_boot_initialized(_play_stage_bgm: bool = true) -> void:
	_boot_initialize_calls += 1


func _mark_boot_redraw_requested() -> void:
	_boot_redraw_calls += 1


func _verify_full_stage_clear_result_prewarm_remains_staged() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	_expect(
		not controller.prewarm_stage_clear_result_resources_step(Callable(self, "_get_module"), owner),
		"full result prewarm should hold until the staged result screen reports completion"
	)
	_expect(_registry.result_screen.step_calls == 1, "full result prewarm should advance one staged result chunk")
	_expect(
		not controller.prewarm_stage_clear_result_resources_step(Callable(self, "_get_module"), owner),
		"full result prewarm should keep staging result assets"
	)
	_expect(
		not controller.prewarm_stage_clear_result_resources_step(Callable(self, "_get_module"), owner),
		"full result prewarm should still hold before the final chunk"
	)
	_expect(
		controller.prewarm_stage_clear_result_resources_step(Callable(self, "_get_module"), owner),
		"full result prewarm should complete when the staged result path finishes"
	)
	_expect(_registry.result_screen.prewarm_count == 1, "full result prewarm should finish the heavy result asset path once")
	_expect(_registry.result_screen.step_calls == 4, "full result prewarm should use every staged result chunk")
	_expect(_registry.result_screen.threaded_step_calls == 4, "full result background prewarm should use the threaded staged path")
	_expect(_registry.result_screen.last_owner == owner, "full result prewarm should pass the selected-character owner")
	_expect(_registry.result_screen.shell_prewarm_count == 0, "full result prewarm should not be replaced by shell prewarm")
	_expect(not controller.has_stage_clear_result_resource_prewarm_work(owner), "completed result prewarm should stop idle work for the selected result character")
	var stage2_owner := FakeOwner.new()
	stage2_owner.current_stage = 2
	stage2_owner.selected_character_type = "soldier"
	_expect(controller.has_stage_clear_result_resource_prewarm_work(stage2_owner), "Stage 1 result prewarm should not mark Stage 2 result sheets ready")
	var smasher_owner := FakeOwner.new()
	_expect(controller.has_stage_clear_result_resource_prewarm_work(smasher_owner), "Commando result prewarm should not mark Smasher result sheets ready")


func _verify_stage1_staged_visual_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 1
	var guard := 0
	while _registry.stage1_pillar_scene.prewarm_count == 0 and guard < 80:
		_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 prewarm should not finish before visual chunks")
		guard += 1
	_expect(guard < 80, "stage 1 prewarm should reach the pillar scene chunk")
	_expect(_registry.stage1_bg.prewarm_count == 1, "stage 1 runtime prewarm should warm pillar background")
	_expect(_registry.stage1_pillar_scene.prewarm_count == 1, "stage 1 runtime prewarm should warm pillar scene")
	_expect(_registry.stage1_balloon_event.step_calls == 0, "stage 1 balloon event should wait for its own staged chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 balloon prewarm should hold on first chunk")
	_expect(_registry.stage1_balloon_event.step_calls == 1, "stage 1 balloon prewarm should advance one texture chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 balloon prewarm should hold on second chunk")
	_expect(_registry.stage1_balloon_event.step_calls == 2, "stage 1 balloon prewarm should continue staging")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 balloon prewarm should finish its chunk before skill HUD")
	_expect(_registry.stage1_balloon_event.step_calls == 3, "stage 1 balloon prewarm should finish through the step API")
	_expect(_registry.stage1_balloon_event.monolithic_calls == 0, "stage 1 balloon prewarm should not use the monolithic asset path when staged")
	_expect(_registry.stage1_skill_hud.step_calls == 0, "stage 1 skill HUD should wait until balloon prewarm completes")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 skill HUD prewarm should hold on first chunk")
	_expect(_registry.stage1_skill_hud.step_calls == 1, "stage 1 skill HUD should advance one card chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 skill HUD prewarm should continue staging")
	_expect(_registry.stage1_skill_hud.step_calls == 2, "stage 1 skill HUD should not skip card chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 skill HUD prewarm should finish its chunk before firearm/PSO")
	_expect(_registry.stage1_skill_hud.step_calls == 3, "stage 1 skill HUD should finish through the step API")
	_expect(_registry.stage1_skill_hud.monolithic_calls == 0, "stage 1 skill HUD should not use the monolithic asset path when staged")
	_expect(_registry.stage1_actor_renderer.prewarm_count == 0, "stage 1 actor renderer should wait until boss skill HUD assets are ready")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "non-Commando Stage 1 prewarm should advance through the empty firearm chunk")
	_expect(_registry.commando_firearm_selector.step_calls == 0, "Smasher Stage 1 prewarm should not wake Commando firearm selector assets")
	_expect(_registry.stage1_actor_renderer.prewarm_count == 0, "stage 1 actor renderer should wait for the dedicated actor chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 actor renderer prewarm should run before the PSO chunk")
	_expect(_registry.stage1_actor_renderer.prewarm_count == 1, "stage 1 actor renderer should warm playfield/player caches before the first visible draw")
	_expect(controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 1 prewarm should finish after the PSO prewarmer chunk")


func _verify_stage1_soldier_commando_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 1
	owner.selected_character_type = "soldier"
	controller.prewarm_stage_runtime_resources(owner, Callable(self, "_get_module"))
	_expect(_registry.commando_firearm_selector.step_calls == 3, "soldier Stage 1 prewarm should stage the Commando selector")
	_expect(_registry.commando_firearm_selector.monolithic_calls == 0, "soldier Stage 1 prewarm should avoid monolithic Commando selector prewarm")
	_expect(_registry.stage1_actor_renderer.prewarm_count == 1, "soldier Stage 1 prewarm should warm the Commando actor renderer assets")


func _verify_stage2_staged_playfield_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 2
	var guard := 0
	while _registry.stage2_bg.step_calls < _registry.stage2_bg.complete_after and guard < 80:
		_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 prewarm should not finish before pillar background chunks")
		guard += 1
	_expect(guard < 80, "stage 2 prewarm should reach the pillar background chunk")
	_expect(_registry.stage2_bg.step_calls == 3, "stage 2 runtime prewarm should stage pillar background chunks before playfield")
	_expect(_registry.stage2_bg.monolithic_calls == 0, "stage 2 pillar background should not use the monolithic asset path when staged")
	_expect(_registry.stage2_actor_renderer.step_calls == 0, "stage 2 playfield should wait for its own staged chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 pillar scene prewarm should hold on first chunk")
	_expect(_registry.stage2_pillar_scene.step_calls == 1, "stage 2 pillar scene should advance one shared-HUD chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 pillar scene prewarm should keep staging")
	_expect(_registry.stage2_pillar_scene.step_calls == 2, "stage 2 pillar scene should not skip shared-HUD chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "completed stage 2 pillar scene should move to playfield on the following frame")
	_expect(_registry.stage2_pillar_scene.step_calls == 3, "stage 2 pillar scene should complete through the step API")
	_expect(_registry.stage2_pillar_scene.monolithic_calls == 0, "stage 2 pillar scene should not use the monolithic path when staged")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "incomplete stage 2 playfield prewarm should hold the same chunk")
	_expect(_registry.stage2_actor_renderer.step_calls == 1, "stage 2 playfield prewarm should advance by one actor chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "second incomplete stage 2 playfield prewarm should still hold")
	_expect(_registry.stage2_actor_renderer.step_calls == 2, "stage 2 playfield prewarm should not skip actor chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "completed stage 2 playfield should move to the next chunk on the following frame")
	_expect(_registry.stage2_actor_renderer.step_calls == 3, "stage 2 playfield prewarm should complete through the step API")
	_expect(_registry.stage2_actor_renderer.monolithic_calls == 0, "stage 2 playfield should not use the monolithic actor path when staged")
	_expect(_registry.stage2_skill_hud.step_calls == 0, "stage 2 skill HUD should wait until playfield prewarm is complete")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 skill HUD prewarm should hold on first chunk")
	_expect(_registry.stage2_skill_hud.step_calls == 1, "stage 2 skill HUD should advance one card chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 skill HUD prewarm should keep staging")
	_expect(_registry.stage2_skill_hud.step_calls == 2, "stage 2 skill HUD should not skip card chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "completed stage 2 skill HUD should move to the monkey chunk on the following frame")
	_expect(_registry.stage2_skill_hud.step_calls == 3, "stage 2 skill HUD should complete through the step API")
	_expect(_registry.stage2_skill_hud.monolithic_calls == 0, "stage 2 skill HUD should not use the monolithic path when staged")
	_expect(_registry.stage2_monkey_event.step_calls == 0, "stage 2 monkey event should wait until skill HUD prewarm is complete")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 monkey prewarm should hold on first chunk")
	_expect(_registry.stage2_monkey_event.step_calls == 1, "stage 2 monkey event should advance one asset chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 monkey prewarm should keep staging")
	_expect(_registry.stage2_monkey_event.step_calls == 2, "stage 2 monkey event should not skip asset chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "completed stage 2 monkey event should move to the PSO chunk on the following frame")
	_expect(_registry.stage2_monkey_event.step_calls == 3, "stage 2 monkey event should complete through the step API")
	_expect(_registry.stage2_monkey_event.monolithic_calls == 0, "stage 2 monkey event should not use the monolithic path when staged")
	_expect(controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 2 prewarm should finish after the PSO prewarmer chunk")


func _verify_stage3_staged_playfield_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 3
	var guard := 0
	while _registry.stage3_bg.prewarm_count == 0 and guard < 80:
		_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 3 prewarm should not finish before playfield work")
		guard += 1
	_expect(guard < 80, "stage 3 prewarm should reach the pillar background chunk")
	_expect(_registry.stage3_bg.prewarm_count == 1, "stage 3 runtime prewarm should warm pillar background before playfield")
	_expect(_registry.stage3_actor_renderer.step_calls == 0, "stage 3 playfield should wait for its own staged chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "incomplete stage 3 playfield prewarm should hold the same chunk")
	_expect(_registry.stage3_actor_renderer.step_calls == 1, "stage 3 playfield prewarm should advance by one actor chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "second incomplete stage 3 playfield prewarm should still hold")
	_expect(_registry.stage3_actor_renderer.step_calls == 2, "stage 3 playfield prewarm should not skip actor chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "completed stage 3 playfield should move to the next chunk on the following frame")
	_expect(_registry.stage3_actor_renderer.step_calls == 3, "stage 3 playfield prewarm should complete through the step API")
	_expect(_registry.stage3_skill_hud.prewarm_count == 0, "stage 3 skill HUD should wait until playfield prewarm is complete")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 3 skill HUD chunk should run after playfield completion")
	_expect(_registry.stage3_skill_hud.prewarm_count == 1, "stage 3 skill HUD should prewarm once")
	_expect(controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 3 prewarm should finish after the PSO prewarmer chunk")


func _verify_stage4_staged_playfield_and_skill_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 4
	var guard := 0
	while _registry.stage4_bg.step_calls == 0 and guard < 80:
		_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 prewarm should not finish before playfield work")
		guard += 1
	_expect(guard < 80, "stage 4 prewarm should reach the pillar background chunk")
	_expect(_registry.stage4_bg.step_calls == 1, "stage 4 runtime prewarm should advance one pillar background chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 pillar background prewarm should keep staging")
	_expect(_registry.stage4_bg.step_calls == 2, "stage 4 pillar background should continue staging")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 pillar background should complete before playfield")
	_expect(_registry.stage4_bg.step_calls == 3, "stage 4 pillar background should complete through the step API")
	_expect(_registry.stage4_bg.monolithic_calls == 0, "stage 4 pillar background should avoid monolithic prewarm when staged")
	_expect(_registry.stage4_actor_renderer.step_calls == 0, "stage 4 actor renderer should wait for its staged playfield chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 actor renderer prewarm should hold on the first chunk")
	_expect(_registry.stage4_actor_renderer.step_calls == 1, "stage 4 actor renderer should advance one chunk")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 actor renderer prewarm should hold on the second chunk")
	_expect(_registry.stage4_actor_renderer.step_calls == 2, "stage 4 actor renderer should not skip chunks")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 actor renderer prewarm should finish before the module chunks")
	_expect(_registry.stage4_actor_renderer.step_calls == 3, "stage 4 actor renderer should complete through the step API")
	_expect(_registry.stage4_actor_renderer.monolithic_calls == 0, "stage 4 actor renderer should avoid the monolithic prewarm path when staged")
	_expect(_registry.stage4_actor_renderer.runtime_step_calls == 0, "stage 4 actor runtime host prewarm should wait until actor assets are ready")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 actor runtime host prewarm should run before module chunks")
	_expect(_registry.stage4_actor_renderer.runtime_step_calls == 1, "stage 4 actor renderer should prewarm runtime FX hosts once")
	_expect(_registry.stage4_actor_renderer.last_runtime_owner == owner, "stage 4 actor runtime prewarm should receive the battle owner")
	_expect(_registry.stage4_ponk_skill_state.step_calls == 0, "stage 4 Ponk skill assets should wait until runtime FX host prewarm finishes")

	guard = 0
	while _registry.stage4_ponk_skill_state.step_calls == 0 and guard < 80:
		_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 module prewarm should not finish before Ponk skill assets")
		guard += 1
	_expect(guard < 80, "stage 4 prewarm should reach the Ponk skill chunk")
	_expect(_registry.stage4_gauge_hud.prewarm_count == 1, "stage 4 gauge HUD should prewarm before Ponk skill state")
	_expect(_registry.stage4_bird_event.prewarm_count == 1, "stage 4 bird event should prewarm before Ponk skill state")
	_expect(_registry.stage4_brazier_monk_event.prewarm_count == 1, "stage 4 monk event should prewarm before Ponk skill state")
	_expect(_registry.stage4_moon_event.prewarm_count == 1, "stage 4 moon event should prewarm before Ponk skill state")
	_expect(_registry.stage4_ponk_skill_state.step_calls == 1, "stage 4 Ponk skill prewarm should advance one chunk")
	_expect(_registry.stage4_ponk_skill_state.monolithic_calls == 0, "stage 4 Ponk skill prewarm should avoid the monolithic path when staged")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 Ponk skill prewarm should keep staging")
	_expect(_registry.stage4_ponk_skill_state.step_calls == 2, "stage 4 Ponk skill should continue staging")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 Ponk skill prewarm should complete before boss skill HUD")
	_expect(_registry.stage4_ponk_skill_state.step_calls == 3, "stage 4 Ponk skill should complete through the step API")
	_expect(_registry.stage4_boss_skill_hud.prewarm_count == 0, "stage 4 boss skill HUD should wait until Ponk skill prewarm completes")
	_expect(not controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 boss skill HUD chunk should run after Ponk skill completion")
	_expect(_registry.stage4_boss_skill_hud.prewarm_count == 1, "stage 4 boss skill HUD should prewarm once")
	_expect(controller.prewarm_stage_runtime_resources_step(owner, Callable(self, "_get_module")), "stage 4 prewarm should finish after the PSO prewarmer chunk")


func _verify_stage5_visual_shell_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	owner.selected_character_type = "soldier"
	controller.prewarm_stage_runtime_resources(owner, Callable(self, "_get_module"))
	_expect(_registry.stage5_bg.step_calls == 3, "stage 5 runtime prewarm should stage Hongryun background")
	_expect(_registry.stage5_bg.monolithic_calls == 0, "stage 5 background prewarm should avoid monolithic loading when staged")
	_expect(_registry.stage5_actor_renderer.step_calls == 3, "stage 5 runtime prewarm should stage Hongryun actor renderer")
	_expect(_registry.stage5_actor_renderer.monolithic_calls == 0, "stage 5 actor prewarm should avoid monolithic loading when staged")
	_expect(_registry.stage5_pillar_scene.step_calls == 3, "stage 5 runtime prewarm should stage Hongryun pillar scene")
	_expect(_registry.stage5_pillar_scene.monolithic_calls == 0, "stage 5 pillar scene prewarm should avoid monolithic loading when staged")
	_expect(_registry.stage5_pillar_scene.last_module_getter_valid, "stage 5 pillar scene prewarm should receive module getter")
	_expect(_registry.stage5_pillar_scene.last_selected_character_type == "soldier", "stage 5 pillar scene prewarm should receive selected character")
	_expect(_registry.stage5_skill_hud.step_calls == 3, "stage 5 runtime prewarm should stage Hongryun skill HUD")
	_expect(_registry.stage5_skill_hud.monolithic_calls == 0, "stage 5 skill HUD prewarm should avoid monolithic loading when staged")


func _verify_battle_texture_prewarm_is_staged() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 1
	owner.selected_character_type = "smasher"

	_expect(
		not controller.prewarm_battle_texture_resources_step(owner, Callable(self, "_get_module")),
		"battle texture prewarm should hold the boot step until the transition texture chunk completes"
	)
	_expect(_registry.battle_resources.step_calls == 1, "battle texture prewarm should advance one resource chunk")
	_expect(not controller.battle_texture_resources_prewarmed, "battle texture prewarm should not mark complete mid-stream")
	_expect(owner.battle_textures.is_empty(), "owner battle texture cache should wait until resource prewarm completes")

	_expect(
		not controller.prewarm_battle_texture_resources_step(owner, Callable(self, "_get_module")),
		"battle texture prewarm should continue staging on the next frame"
	)
	_expect(
		controller.prewarm_battle_texture_resources_step(owner, Callable(self, "_get_module")),
		"battle texture prewarm should finish when the transition texture API reports complete"
	)
	_expect(controller.battle_texture_resources_prewarmed, "battle texture resources should be marked complete after staged load")
	_expect(controller.battle_resource_cache_finalized, "staged texture prewarm should satisfy the final cache step")
	_expect(controller.battle_core_resources_prewarmed, "staged texture prewarm should satisfy the old core flag")
	_expect(controller.battle_player_resources_prewarmed, "staged texture prewarm should satisfy the old player flag")
	_expect(controller.battle_boss_resources_prewarmed, "staged texture prewarm should satisfy the old boss flag")
	_expect(_registry.battle_resources.load_all_calls == 0, "staged texture prewarm should use the cached transition path without load_all")
	_expect(
		not bool(_registry.battle_resources.last_context.get("include_result_sheets", true)),
		"first battle texture prewarm should defer result sheets to the dedicated result prewarm path"
	)
	_expect(int(owner.battle_textures.get("loaded_stage", 0)) == 1, "owner should receive the battle texture cache")
	_expect(owner.smasher_skill_icon_textures.has("wheel"), "owner should receive the selected character skill icon cache")

	_expect(
		controller.prewarm_battle_texture_resources_step(owner, Callable(self, "_get_module")),
		"completed battle texture prewarm should stay complete"
	)
	_expect(_registry.battle_resources.step_calls == 3, "completed battle texture prewarm should not re-run texture chunks")


func _verify_viper_runtime_node_prewarm() -> void:
	_registry = FakeRegistry.new()
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "viper"
	controller.prewarm_selected_character_runtime_resources(owner, Callable(self, "_get_module"))
	_expect(_registry.viper_skill_runtime.step_calls == 3, "Viper skill runtime assets should finish before runtime node prewarm")
	_expect(_registry.viper_skill_runtime.monolithic_calls == 0, "Viper skill runtime prewarm should stay staged")
	_expect(_registry.viper_skill_runtime.runtime_step_calls == 1, "Viper skill runtime should prewarm FX host nodes once")
	_expect(_registry.viper_skill_runtime.last_runtime_owner == owner, "Viper FX host node prewarm should receive the battle owner")
	_expect(_registry.skill_cutin_overlay_host.prewarm_count == 1, "Viper runtime prewarm should warm the shared skill cut-in assets once")
	_expect(_registry.skill_cutin_overlay_host.runtime_node_calls == 1, "Viper runtime prewarm should run shared skill cut-in runtime node prewarm once")
	_expect(_registry.skill_cutin_overlay_host.last_runtime_owner == owner, "Viper skill cut-in runtime node prewarm should receive the battle owner")


func _verify_boot_warmup_uses_staged_runtime_prewarm() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_warmup_controller.gd")
	var resource_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var landing_source := FileAccess.get_file_as_string("res://scripts/core/stage_landing_intro.gd")
	var label_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_warmup_sample_labels.gd")
	_expect(
		source.find("\"prewarm_battle_texture_resources_step\"") >= 0,
		"boot warmup should advance battle texture resource prewarm one chunk per frame"
	)
	_expect(
		resource_source.find("landing_intro.prewarm_assets_step(current_stage)") >= 0,
		"boot resource prewarm should stage landing intro background loading"
	)
	_expect(
		source.find("\"prewarm_stage_runtime_resources_step\"") >= 0,
		"boot warmup should advance stage runtime resource prewarm one chunk per frame"
	)
	_expect(
		resource_source.find("LingpetRailCard.prewarm_step()") >= 0,
		"boot resource prewarm should stage lingpet rail-card loading"
	)
	_expect(
		resource_source.find("\"lingpet_runtime\"") >= 0 and resource_source.find("lingpet_runtime.prewarm_assets()") >= 0,
		"boot resource prewarm should warm lingpet runtime passive VFX assets before the first passive hit"
	)
	_expect(
		label_source.find("\"09_lingpet_runtime\"") >= 0 and label_source.find("\"10_lingpet_rail_card\"") >= 0,
		"boot warmup sample labels should name lingpet runtime and rail-card prewarm steps"
	)
	_expect(
		resource_source.find("prewarm_runtime_nodes_step(owner)") >= 0,
		"boot resource prewarm should create ball runtime FX nodes before the first visible battle draw"
	)
	_expect(
		resource_source.find("return _run_battle_pso_prewarmer_step(owner)") >= 0,
		"boot resource prewarm should wait for the PSO prewarmer draw passes before the first visible battle draw"
	)
	_expect(
		resource_source.find("prewarm_stage_runtime_resources_step(owner, module_getter, false)") >= 0,
		"monolithic stage runtime prewarm should skip frame-gated PSO waits"
	)
	_expect(
		resource_source.find("while not prewarm_stage_runtime_resources_step(owner, module_getter):") < 0,
		"monolithic stage runtime prewarm should not busy-loop a frame-gated PSO step"
	)
	_expect(
		landing_source.find("prewarm_texture_threaded_step") >= 0,
		"stage landing intro prewarm should use the threaded texture path"
	)
	_expect(
		source.find("\"prewarm_stage_clear_result_resources_step\"") >= 0,
		"boot warmup should stage full stage-clear result assets before the first battle frame"
	)
	_expect(
		source.find("\"prewarm_stage_clear_result_shell_resources_step\"") < 0,
		"boot warmup should not stop at the lightweight stage-clear result shell"
	)
	_expect(
		source.find("\"prewarm_stage_runtime_resources\")") < 0,
		"boot warmup should not run the monolithic stage runtime prewarm loop in one process frame"
	)
	_expect(
		source.find("\"prewarm_stage_clear_result_resources\")") < 0,
		"boot warmup should not run the monolithic stage-clear result prewarm loop in one process frame"
	)


func _verify_boot_warmup_result_step_uses_result_prewarm_signature() -> void:
	_registry = FakeRegistry.new()
	var warmup := BattleBootWarmupController.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	warmup.set("boot_warmup_step", 18)
	for _i in range(4):
		warmup.run_boot_warmup_step(owner, Callable(self, "_get_module"), Callable(), Callable())
	_expect(int(warmup.get("boot_warmup_step")) == 19, "boot result warmup should finish without swapping result prewarm arguments")
	_expect(_registry.result_screen.threaded_step_calls == 4, "boot result warmup should advance the threaded result asset path")
	_expect(_registry.result_screen.last_owner == owner, "boot result warmup should pass the owner as the result prewarm owner argument")


func _verify_full_boot_warmup_finishes_without_stalling() -> void:
	_registry = FakeRegistry.new()
	_boot_initialize_calls = 0
	_boot_redraw_calls = 0
	var warmup := BattleBootWarmupController.new()
	var owner := FakeOwner.new()
	owner.current_stage = 1
	owner.selected_character_type = "smasher"
	var frame_count := 0
	var same_step_frames := 0
	var last_step := int(warmup.get("boot_warmup_step"))
	var previous_progress := -0.001
	const MAX_BOOT_WARMUP_FRAMES := 220
	const MAX_SAME_BOOT_STEP_FRAMES := 80

	while not bool(warmup.is_finished()) and frame_count < MAX_BOOT_WARMUP_FRAMES:
		warmup.run_boot_warmup_step(
			owner,
			Callable(self, "_get_module"),
			Callable(self, "_mark_boot_initialized"),
			Callable(self, "_mark_boot_redraw_requested")
		)
		var current_step := int(warmup.get("boot_warmup_step"))
		if current_step == last_step:
			same_step_frames += 1
		else:
			last_step = current_step
			same_step_frames = 0
		var progress := float(warmup.get_progress(Callable(self, "_get_module")))
		_expect(
			progress + 0.001 >= previous_progress,
			"boot warmup progress should be monotonic while staged work is running"
		)
		_expect(
			same_step_frames <= MAX_SAME_BOOT_STEP_FRAMES,
			"boot warmup step %d should not hold the loading screen indefinitely" % current_step
		)
		previous_progress = maxf(previous_progress, progress)
		frame_count += 1

	_expect(bool(warmup.is_finished()), "full boot warmup should finish before the no-stall frame guard")
	_expect(frame_count < MAX_BOOT_WARMUP_FRAMES, "full boot warmup should stay inside the boot loading frame budget")
	_expect(_registry.game_audio.setup_calls == _registry.game_audio.setup_complete_after, "full boot warmup should finish staged audio setup exactly once")
	_expect(_registry.game_audio.prime_calls == 1, "full boot warmup should prime BGM once after audio setup")
	_expect(_registry.game_audio.last_prime_stage == 1, "full boot warmup should prime the selected stage BGM")
	_expect(_boot_initialize_calls == 1, "full boot warmup should initialize battle exactly once")
	_expect(_boot_redraw_calls == 1, "full boot warmup should request the first redraw exactly once")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
