extends SceneTree

const StageDebugPicker := preload("res://scripts/core/stage_debug_picker.gd")
const Stage7AkamuActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd")
const Stage7AkamuPrebattlePresentation := preload("res://scripts/stages/stage7/stage7_akamu_prebattle_presentation.gd")


class FakeSelectionState:
	extends RefCounted

	var stage_id := 1
	var stage1_boss_variant := "dalji"
	var stage1_boss_variant_explicit := false

	func set_stage(stage: int, stage1_variant: String = "dalji", explicit_stage1_variant: bool = false) -> void:
		stage_id = stage
		stage1_boss_variant = stage1_variant if stage_id == 1 else "dalji"
		stage1_boss_variant_explicit = explicit_stage1_variant and stage_id == 1


class FakeOwner:
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var selected_character_type := "soldier"
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := "rain"
	var weather_event_active := true
	var weather_event_context := {"kind": "rain"}
	var selection_state: Object = null
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_node_or_null(path: NodePath) -> Object:
		if str(path) == "/root/GameSelectionState":
			return selection_state
		return null


class FakeAudio:
	var stopped: Array[String] = []
	var played_stage := 0

	func stop_dash_delay() -> void:
		stopped.append("dash_delay")

	func stop_boomerang_loop() -> void:
		stopped.append("boomerang")

	func stop_stage2_quake_loop() -> void:
		stopped.append("stage2_quake")

	func stop_stage3_psychoball_loop() -> void:
		stopped.append("stage3_psychoball")

	func stop_commando_supply_aircraft_loop() -> void:
		stopped.append("commando_aircraft")

	func stop_commando_supply_radio_loop() -> void:
		stopped.append("commando_radio")

	func stop_bgm() -> void:
		stopped.append("bgm")

	func play_stage_bgm(stage_id: int) -> bool:
		played_stage = stage_id
		return true


class FakeStage7PillarSceneModule:
	# 실물 필러 씬 드로어에는 reset()이 없다 — 허구 reset 계약을 만들지
	# 않도록 fake에도 두지 않는다(reset fanout 대상이 아님).
	var prewarm_count := 0
	var module_getter_valid := false
	var prewarm_character_type := ""

	func prewarm_assets(module_getter: Callable, selected_character_type: String = "smasher") -> void:
		prewarm_count += 1
		module_getter_valid = module_getter.is_valid()
		prewarm_character_type = selected_character_type


class FakeResetModule:
	var reset_count := 0
	var prewarm_count := 0

	func reset() -> void:
		reset_count += 1

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeStage1PillarSceneModule:
	var prewarm_count := 0
	var prewarm_character_type := ""
	var prewarm_stage1_boss_variant := ""
	var module_getter_valid := false

	func prewarm_assets(
		module_getter: Callable,
		selected_character_type: String = "smasher",
		stage1_boss_variant: String = "dalji"
	) -> void:
		prewarm_count += 1
		prewarm_character_type = selected_character_type
		prewarm_stage1_boss_variant = stage1_boss_variant
		module_getter_valid = module_getter.is_valid()


class FakeClearModule:
	var clear_count := 0

	func clear_all() -> void:
		clear_count += 1


class FakeMatchFlowDriver:
	var reset_game_count := 0

	func reset_game(_owner: Object, _registry: Object, _reset_drive: Callable, _reset_ball: Callable) -> void:
		reset_game_count += 1


class FakeBallPhysics:
	var configured_stage := 0
	var configured_weather := "unset"

	func configure_context(stage_id: int, _ai_mode: String, _arena_enabled: bool, weather_type: String) -> void:
		configured_stage = stage_id
		configured_weather = weather_type


class FakeUpdateDriver:
	var reset_ball_count := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_ball_count += 1


class FakeCommandoWeaponController:
	var prepared_stage := 0
	var forced := false

	func prepare_stage_start(stage_id: int, force: bool = false) -> Dictionary:
		prepared_stage = stage_id
		forced = force
		return {}


class FakeActiveItemRuntime:
	var prewarm_count := 0
	var last_visuals: Object

	func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
		prewarm_count += 1
		last_visuals = active_item_hud_visuals


class FakeActiveItemHudVisuals:
	var prewarm_count := 0

	func prewarm_catalog_icons() -> void:
		prewarm_count += 1


class FakeRegistry:
	var requested_keys: Array[String] = []
	var audio := FakeAudio.new()
	var match_flow := FakeMatchFlowDriver.new()
	var stage_intro := FakeResetModule.new()
	var stage1_bg := FakeResetModule.new()
	var stage1_pillar_scene := FakeStage1PillarSceneModule.new()
	var stage1_balloon := FakeResetModule.new()
	var stage1_skill_hud := FakeResetModule.new()
	var stage1_gaksital_skill_hud := FakeResetModule.new()
	var stage2_bg := FakeResetModule.new()
	var stage7_bg := FakeResetModule.new()
	var stage7_actor := FakeResetModule.new()
	var stage7_pillar_scene := FakeStage7PillarSceneModule.new()
	var stage7_skill_hud := FakeResetModule.new()
	var stage7_state := FakeResetModule.new()
	var prebattle_presentation: RefCounted = null
	var impact_effects := FakeClearModule.new()
	var ball_effects := FakeClearModule.new()
	var ball_physics := FakeBallPhysics.new()
	var update_driver := FakeUpdateDriver.new()
	var commando_weapon := FakeCommandoWeaponController.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var active_item_hud_visuals := FakeActiveItemHudVisuals.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"game_audio":
				return audio
			"battle_scene_match_flow_driver":
				return match_flow
			"stage_ball_spawn_intro":
				return stage_intro
			"stage1_pillar_background":
				return stage1_bg
			"stage1_pillar_scene_drawer":
				return stage1_pillar_scene
			"stage1_balloon_event":
				return stage1_balloon
			"stage1_dalji_boss_skill_hud_renderer":
				return stage1_skill_hud
			"stage1_gaksital_boss_skill_hud_renderer":
				return stage1_gaksital_skill_hud
			"stage2_pillar_background":
				return stage2_bg
			"stage7_akamu_pillar_background":
				return stage7_bg
			"stage7_akamu_actor_renderer":
				return stage7_actor
			"stage7_akamu_pillar_scene_drawer":
				return stage7_pillar_scene
			"stage7_akamu_boss_skill_hud_renderer":
				return stage7_skill_hud
			"stage7_akamu_state":
				return stage7_state
			"stage7_akamu_prebattle_presentation":
				return prebattle_presentation
			"impact_effects":
				return impact_effects
			"ball_effects":
				return ball_effects
			"ball_physics":
				return ball_physics
			"battle_scene_update_driver":
				return update_driver
			"commando_weapon_controller":
				return commando_weapon
			"active_item_runtime":
				return active_item_runtime
			"active_item_hud_visuals":
				return active_item_hud_visuals
		return null


func _init() -> void:
	var picker := StageDebugPicker.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	picker.toggle(owner)
	picker.selected_index = picker._find_stage_index(2)

	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER

	_expect(picker.handle_input(event, owner, registry, Vector2(1280.0, 720.0)), "Enter should apply selected stage")
	_expect(not picker.is_open(), "stage debug picker should close after applying a stage")
	_expect(owner.current_stage == 2, "owner current_stage should update")
	_expect(owner.weather_type == "", "stage debug reset should clear owner weather")
	_expect(not owner.weather_event_active, "stage debug reset should clear weather event flag")
	_expect(registry.match_flow.reset_game_count == 1, "stage debug reset should use full match reset")
	_expect(registry.audio.stopped.has("dash_delay"), "stage debug reset should stop shared gameplay loops")
	_expect(registry.audio.stopped.has("commando_radio"), "stage debug reset should stop Commando supply hold radio loop")
	_expect(registry.audio.stopped.has("stage2_quake"), "stage debug reset should stop stage quake loop")
	_expect(registry.audio.stopped.has("bgm"), "stage debug reset should stop old BGM")
	_expect(registry.audio.played_stage == 2, "stage debug reset should restart selected stage BGM")
	_expect(registry.stage_intro.reset_count == 1, "stage debug reset should tear down ball-spawn intro FX")
	_expect(registry.stage2_bg.reset_count == 1, "stage debug reset should reset stage modules")
	_expect(registry.stage2_bg.prewarm_count == 1, "stage debug reset should prewarm the selected Stage 2 background")
	_expect(registry.active_item_runtime.prewarm_count == 1, "stage debug reset should prewarm active item runtime assets")
	_expect(registry.active_item_runtime.last_visuals == registry.active_item_hud_visuals, "active item prewarm should receive HUD visuals")
	_expect(registry.impact_effects.clear_count == 1, "stage debug reset should clear impact effects")
	_expect(registry.ball_effects.clear_count == 1, "stage debug reset should clear ball effects")
	_expect(registry.commando_weapon.prepared_stage == 2 and registry.commando_weapon.forced, "stage debug reset should prepare commando weapons for the new stage")
	_expect(registry.ball_physics.configured_stage == 2, "stage debug reset should reconfigure ball physics")
	_expect(registry.ball_physics.configured_weather == "", "ball physics should receive cleared weather")
	_expect(registry.update_driver.reset_ball_count == 1, "stage debug reset should reset the ball once")
	_expect(owner.redraw_count == 1, "stage debug reset should queue one redraw")

	var stage1_owner := FakeOwner.new()
	stage1_owner.selected_character_type = " Commando "
	var stage1_registry := FakeRegistry.new()
	picker.toggle(stage1_owner)
	picker.selected_index = picker._find_stage_variant_index(1, "dalji")
	_expect(picker.handle_input(event, stage1_owner, stage1_registry, Vector2(1280.0, 720.0)), "Enter should apply Stage 1")
	_expect(stage1_owner.stage1_boss_variant == "dalji", "Stage 1 Dalji debug route should keep the default boss variant")
	_expect(stage1_registry.stage1_bg.prewarm_count == 1, "stage debug reset should prewarm the selected Stage 1 background")
	_expect(stage1_registry.stage1_pillar_scene.prewarm_count == 1, "stage debug reset should prewarm the selected Stage 1 pillar scene")
	_expect(stage1_registry.stage1_pillar_scene.module_getter_valid, "Stage 1 pillar scene prewarm should receive a module getter")
	_expect(stage1_registry.stage1_pillar_scene.prewarm_character_type == "soldier", "Stage 1 pillar scene prewarm should receive the selected character type")
	_expect(stage1_registry.stage1_pillar_scene.prewarm_stage1_boss_variant == "dalji", "Stage 1 Dalji prewarm should receive the selected boss variant")
	_expect(stage1_registry.stage1_balloon.prewarm_count == 1, "stage debug reset should prewarm Stage 1 balloon runtime assets")
	_expect(stage1_registry.stage1_skill_hud.prewarm_count == 1, "stage debug reset should prewarm Stage 1 skill HUD assets")
	_expect(stage1_registry.active_item_runtime.prewarm_count == 1, "Stage 1 debug reset should prewarm active item runtime assets")

	var gaksi_owner := FakeOwner.new()
	gaksi_owner.selection_state = FakeSelectionState.new()
	var gaksi_registry := FakeRegistry.new()
	picker.toggle(gaksi_owner)
	picker.selected_index = picker._find_stage_variant_index(1, "gaksi")
	_expect(picker.handle_input(event, gaksi_owner, gaksi_registry, Vector2(1280.0, 720.0)), "Enter should apply Stage 1 Gaksital")
	_expect(gaksi_owner.current_stage == 1, "Gaksital debug route should remain Stage 1")
	_expect(gaksi_owner.stage1_boss_variant == "gaksi", "Gaksital debug route should set the Stage 1 boss variant")
	_expect(gaksi_owner.selection_state.stage_id == 1, "Gaksital debug route should sync selected Stage 1")
	_expect(gaksi_owner.selection_state.stage1_boss_variant == "gaksi", "Gaksital debug route should sync selected boss variant")
	_expect(gaksi_owner.selection_state.stage1_boss_variant_explicit, "Gaksital debug route should mark the selected boss variant explicit")
	_expect(gaksi_registry.stage1_bg.prewarm_count == 1, "Gaksital debug route should still prewarm shared Stage 1 background")
	_expect(gaksi_registry.stage1_pillar_scene.prewarm_stage1_boss_variant == "gaksi", "Gaksital debug route should prewarm the selected boss variant")
	_expect(gaksi_registry.stage1_gaksital_skill_hud.prewarm_count == 1, "Gaksital debug route should prewarm the Gaksital boss skill HUD")

	var podo_owner := FakeOwner.new()
	podo_owner.selection_state = FakeSelectionState.new()
	var podo_registry := FakeRegistry.new()
	picker.toggle(podo_owner)
	picker.selected_index = picker._find_stage_variant_index(1, "pododaejang")
	_expect(picker.handle_input(event, podo_owner, podo_registry, Vector2(1280.0, 720.0)), "Enter should apply Stage 1 Pododaejang")
	_expect(podo_owner.current_stage == 1, "Pododaejang debug route should remain Stage 1")
	_expect(podo_owner.stage1_boss_variant == "podo", "Pododaejang debug route should set the Stage 1 boss variant")
	_expect(podo_owner.selection_state.stage_id == 1, "Pododaejang debug route should sync selected Stage 1")
	_expect(podo_owner.selection_state.stage1_boss_variant == "podo", "Pododaejang debug route should sync selected boss variant")
	_expect(podo_owner.selection_state.stage1_boss_variant_explicit, "Pododaejang debug route should mark the selected boss variant explicit")
	_expect(podo_registry.stage1_bg.prewarm_count == 1, "Pododaejang debug route should still prewarm shared Stage 1 background")
	_expect(podo_registry.stage1_balloon.prewarm_count == 1, "Pododaejang debug route should prewarm shared Stage 1 balloon assets")
	_expect(podo_registry.stage1_pillar_scene.prewarm_stage1_boss_variant == "podo", "Pododaejang debug route should prewarm the selected boss variant")
	_expect(podo_registry.stage1_skill_hud.prewarm_count == 0, "Pododaejang Slice 1 should not prewarm Dalji boss skill HUD assets")
	_expect(podo_registry.stage1_gaksital_skill_hud.prewarm_count == 0, "Pododaejang Slice 1 should not prewarm Gaksital boss skill HUD assets")
	_expect(not podo_registry.requested_keys.has("stage1_pododaejang_boss_skill_hud_renderer"), "Pododaejang Slice 1 should not request missing Pododaejang HUD modules yet")
	var stage7_owner := FakeOwner.new()
	stage7_owner.selected_character_type = "viper"
	var stage7_registry := FakeRegistry.new()
	picker.toggle(stage7_owner)
	picker.selected_index = picker._find_stage_index(7)
	_expect(picker.handle_input(event, stage7_owner, stage7_registry, Vector2(1280.0, 720.0)), "Enter should apply Stage 7 Akamu")
	_expect(stage7_owner.current_stage == 7, "Stage 7 Akamu debug route should route to stage 7")
	_expect(stage7_registry.audio.played_stage == 7, "Stage 7 debug reset should restart Stage 7 BGM (picker route has no prebattle video lifecycle)")
	_expect(stage7_registry.match_flow.reset_game_count == 1, "Stage 7 debug reset should use full match reset")
	_expect(stage7_registry.stage7_bg.prewarm_count == 1, "Stage 7 debug reset should prewarm the Akamu pillar background")
	_expect(stage7_registry.stage7_actor.prewarm_count == 1, "Stage 7 debug reset should prewarm the Akamu actor renderer")
	_expect(stage7_registry.stage7_pillar_scene.prewarm_count == 1, "Stage 7 debug reset should prewarm the Akamu pillar scene drawer")
	_expect(stage7_registry.stage7_pillar_scene.module_getter_valid, "Stage 7 pillar scene prewarm should receive a module getter")
	_expect(stage7_registry.stage7_pillar_scene.prewarm_character_type == "viper", "Stage 7 pillar scene prewarm should receive the selected character type")
	_expect(stage7_registry.stage7_skill_hud.prewarm_count == 1, "Stage 7 debug reset should prewarm the Akamu boss skill HUD")
	_expect(stage7_registry.active_item_runtime.prewarm_count == 1, "Stage 7 debug reset should prewarm active item runtime assets")
	_expect(stage7_registry.stage7_bg.reset_count == 1, "picker fanout should reset the Akamu pillar background exactly once")
	_expect(stage7_registry.stage7_actor.reset_count == 1, "picker fanout should reset the Akamu actor renderer (live parent) exactly once")
	_expect(stage7_registry.stage7_state.reset_count == 1, "picker fanout should reset the Akamu boss state exactly once")
	_expect(stage7_registry.stage7_skill_hud.reset_count == 1, "picker fanout should reset the Akamu boss skill HUD exactly once")
	# 보스/플레이필드 렌더러는 액터 렌더러의 자식(reset 위임)이라 registry 키
	# 조회는 standalone 사본만 만든다 — 피커가 요청조차 하지 않아야 한다.
	_expect(not stage7_registry.requested_keys.has("stage7_akamu_boss_actor_renderer"), "picker fanout must not instantiate a standalone Akamu boss actor renderer copy")
	_expect(not stage7_registry.requested_keys.has("stage7_akamu_playfield_renderer"), "picker fanout must not instantiate a standalone Akamu playfield renderer copy")
	# 실 액터 렌더러(live parent)의 reset()이 자식 보스/플레이필드 렌더러로
	# 위임하는 실계약 봉인 — fanout 4키가 실제 정리 범위를 커버함을 증명.
	var real_stage7_actor: RefCounted = Stage7AkamuActorRenderer.new()
	var delegated_boss := FakeResetModule.new()
	var delegated_playfield := FakeResetModule.new()
	real_stage7_actor.set("boss_renderer", delegated_boss)
	real_stage7_actor.set("playfield_renderer", delegated_playfield)
	real_stage7_actor.reset()
	_expect(delegated_boss.reset_count == 1, "real Stage 7 actor renderer reset should delegate to its boss renderer child")
	_expect(delegated_playfield.reset_count == 1, "real Stage 7 actor renderer reset should delegate to its playfield renderer child")

	# no-driver fallback: match-flow driver가 없으면 정상 경로의 프리배틀
	# 정리가 빠진다 — 피커 fallback이 프리배틀 presentation을 직접 reset해
	# 활성 인트로가 unarm(호스트 숨김·정지 포함)되는지 실물로 봉인한다.
	var fallback_owner := FakeOwner.new()
	var fallback_registry := FakeRegistry.new()
	fallback_registry.match_flow = null
	var real_prebattle: RefCounted = Stage7AkamuPrebattlePresentation.new()
	real_prebattle.reset_for_stage_entry(7)
	_expect(real_prebattle.blocks_battle_physics(), "fallback probe should start with an armed Stage 7 prebattle entry")
	fallback_registry.prebattle_presentation = real_prebattle
	picker.toggle(fallback_owner)
	picker.selected_index = picker._find_stage_index(7)
	_expect(picker.handle_input(event, fallback_owner, fallback_registry, Vector2(1280.0, 720.0)), "Enter should apply Stage 7 on the no-driver fallback path")
	_expect(not real_prebattle.blocks_battle_physics(), "no-driver fallback must disarm the Stage 7 prebattle intro (no leftover video host behind restarted BGM)")
	_expect(fallback_registry.audio.played_stage == 7, "no-driver fallback should still restart Stage 7 BGM after the prebattle cleanup")

	var panel_rect: Rect2 = picker._get_panel_rect(Vector2(1280.0, 720.0))
	var last_card_rect: Rect2 = picker._get_card_rect(picker._find_stage_index(12), panel_rect)
	_expect(last_card_rect.end.y <= panel_rect.end.y - 20.0, "stage debug picker panel should expand for the fourth row after adding Stage 1-C")

	print("stage_debug_picker_runtime_reset_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
