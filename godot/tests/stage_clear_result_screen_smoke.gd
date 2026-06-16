extends SceneTree

const MatchScoreboardFlowController := preload("res://scripts/core/match_scoreboard_flow_controller.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")
const StageClearResultRewardPlanBuilder := preload("res://scripts/core/stage_clear_result_reward_plan_builder.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


class FakeOwner:
	extends Node2D

	var current_stage := 1
	var selected_character_type := "smasher"
	var active_item_slots: Array = []
	var passive_item_inventory: Array = []
	var runtime_perk_levels: Dictionary = {}


class FakeScoreState:
	extends RefCounted

	var player_score := 5
	var boss_score := 0

	func get_snapshot() -> Dictionary:
		return {
			"player_score": player_score,
			"boss_score": boss_score,
		}


class FakeRegistry:
	extends RefCounted

	var score_state: Object
	var runtime_perk_state: Object
	var runtime_perk_catalog: Object
	var game_audio: Object
	var mythic_item_runtime: Object

	func _init(
		new_score_state: Object,
		new_runtime_perk_state: Object = null,
		new_runtime_perk_catalog: Object = null,
		new_game_audio: Object = null,
		new_mythic_item_runtime: Object = null
	) -> void:
		score_state = new_score_state
		runtime_perk_state = new_runtime_perk_state
		runtime_perk_catalog = new_runtime_perk_catalog
		game_audio = new_game_audio
		mythic_item_runtime = new_mythic_item_runtime

	func get_instance(key: String) -> Object:
		if key == "match_score_state":
			return score_state
		if key == "runtime_perk_state":
			return runtime_perk_state
		if key == "runtime_perk_catalog":
			return runtime_perk_catalog
		if key == "game_audio":
			return game_audio
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


class FakeRuntimePerkCatalog:
	extends RefCounted

	func get_choices(
		_character_type: String,
		_runtime_skill_levels: Dictionary,
		_exclude_instant: bool = false,
		_target_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return [
			{
				"id": "dash_module_control",
				"name": "모듈제어",
				"description": "테스트 퍽",
			},
		]

	func get_perk_data(perk_id: String) -> Dictionary:
		return {
			"id": perk_id,
			"name": "모듈제어",
			"description": "테스트 퍽",
		}


class FakeRuntimePerkState:
	extends RefCounted

	var pending_skill_choices := 0
	var choice_active := false
	var collect_calls := 0
	var open_calls := 0
	var choose_calls := 0
	var last_defer_choice_open := false
	var last_choice_context: Dictionary = {}
	var last_selected_choice: Dictionary = {}
	var selected_choice_sequence := 0

	func collect_star_points(
		amount: int,
		character_type: String,
		catalog: Object,
		owner: Object = null,
		registry: Object = null,
		defer_choice_open: bool = false
	) -> bool:
		collect_calls += 1
		last_defer_choice_open = defer_choice_open
		pending_skill_choices += max(0, amount)
		if pending_skill_choices > 0 and not choice_active and not defer_choice_open:
			open_next_choice(character_type, catalog, false, owner, registry)
		return choice_active

	func open_next_choice(
		_character_type: String,
		_catalog: Object,
		_exclude_instant: bool = false,
		_owner: Object = null,
		_registry: Object = null,
		_perf_logger: Object = null,
		choice_context: Dictionary = {}
	) -> void:
		open_calls += 1
		last_choice_context = choice_context.duplicate(true)
		if pending_skill_choices > 0:
			choice_active = true

	func is_choice_active() -> bool:
		return choice_active

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": {},
			"current_choices": [
				{
					"id": "dash_module_control",
					"name": "모듈제어",
					"description": "테스트 퍽",
				},
			],
			"selected_index": 0,
			"animation_time": 0.32,
			"particles": [],
			"pending_skill_choices": pending_skill_choices,
			"last_selected_id": str(last_selected_choice.get("id", "")),
			"last_selected_choice": last_selected_choice.duplicate(true),
			"selected_choice_sequence": selected_choice_sequence,
		}

	func build_layout(view_size: Vector2) -> Dictionary:
		var card_size := Vector2(250.0, 126.0)
		var center := view_size * 0.5
		return {
			"title_pos": center + Vector2(0.0, -150.0),
			"cards_start": center - card_size * 0.5,
			"card_size": card_size,
			"card_gap": 16.0,
			"desc_rect": Rect2(center + Vector2(-200.0, 92.0), Vector2(400.0, 88.0)),
			"panel_rect": Rect2(center + Vector2(-200.0, 190.0), Vector2(400.0, 120.0)),
			"hint_pos": center + Vector2(0.0, 340.0),
		}

	func get_card_rects(view_size: Vector2) -> Array:
		var layout: Dictionary = build_layout(view_size)
		return [Rect2(layout.get("cards_start", Vector2.ZERO), layout.get("card_size", Vector2(250.0, 126.0)))]

	func has_pending_unlock_swap() -> bool:
		return false

	func handle_input(event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		if not choice_active:
			return false
		if event is InputEventKey:
			var key_event: InputEventKey = event
			if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
				choose_calls += 1
				last_selected_choice = {
					"id": "dash_module_control",
					"name": "Module Control",
					"description": "Test perk from result box",
					"current_level": 0,
					"next_level": 1,
					"level_delta": 1,
				}
				selected_choice_sequence += 1
				pending_skill_choices = max(0, pending_skill_choices - 1)
				choice_active = false
			return true
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				choose_calls += 1
				last_selected_choice = {
					"id": "dash_module_control",
					"name": "Module Control",
					"description": "Test perk from result box",
					"current_level": 0,
					"next_level": 1,
					"level_delta": 1,
				}
				selected_choice_sequence += 1
				pending_skill_choices = max(0, pending_skill_choices - 1)
				choice_active = false
			return true
		return true


class FakeScoreboard:
	extends RefCounted

	var result := 2

	func update_scoreboard(_delta: float) -> int:
		return result


class CallbackSink:
	extends RefCounted

	var show_calls := 0
	var reset_calls := 0
	var exit_calls := 0
	var show_result := true

	func show_stage_clear_result() -> bool:
		show_calls += 1
		return show_result

	func reset_game() -> void:
		reset_calls += 1

	func exit_to_menu() -> void:
		exit_calls += 1


class FakeGameAudio:
	extends RefCounted

	var result_box_open_calls := 0
	var runtime_perk_choice_open_calls := 0

	func play_result_box_open() -> void:
		result_box_open_calls += 1

	func play_runtime_perk_choice_open() -> void:
		runtime_perk_choice_open_calls += 1


class FakeMythicItemRuntime:
	extends RefCounted

	var acquisition_active := false
	var update_calls := 0
	var input_calls := 0

	func is_acquisition_cinematic_active() -> bool:
		return acquisition_active

	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		update_calls += 1

	func handle_acquisition_cinematic_input(_event: InputEvent, _registry: Object = null) -> bool:
		input_calls += 1
		acquisition_active = false
		return true


class FakeRewardResolver:
	extends RefCounted

	var roll_calls := 0
	var grant_calls := 0
	var granted_rewards: Array = []
	var reward_type := "starpoint"

	func roll_reward(box_kind: String, _owner: Object = null, _registry: Object = null) -> Dictionary:
		roll_calls += 1
		if reward_type == "mythic":
			return {
				"type": "mythic",
				"label": "Heavenly Cape",
				"item_name": "heavenly_cape",
				"item_data": {
					"name": "heavenly_cape",
					"type": "mythic",
					"rarity": "mythic",
					"display_name": "Heavenly Cape",
				},
				"box_kind_seen": box_kind,
			}
		return {
			"type": "starpoint",
			"label": "★ 1",
			"amount": 1,
			"box_kind_seen": box_kind,
		}

	func grant_rewards(rewards: Array, _owner: Object, _registry: Object) -> Dictionary:
		grant_calls += 1
		granted_rewards = rewards.duplicate(true)
		for reward_value in rewards:
			if not (reward_value is Dictionary):
				continue
			var reward: Dictionary = reward_value
			if str(reward.get("type", "")) == "starpoint":
				var runtime_state: Object = _registry.get_instance("runtime_perk_state") if _registry != null and _registry.has_method("get_instance") else null
				var catalog: Object = _registry.get_instance("runtime_perk_catalog") if _registry != null and _registry.has_method("get_instance") else null
				if runtime_state != null and catalog != null and runtime_state.has_method("collect_star_points"):
					runtime_state.collect_star_points(
						int(reward.get("amount", 0)),
						"smasher",
						catalog,
						_owner,
						_registry,
						bool(reward.get("defer_choice_open", false))
					)
			elif str(reward.get("type", "")) == "mythic":
				var mythic_runtime: Object = _registry.get_instance("mythic_item_runtime") if _registry != null and _registry.has_method("get_instance") else null
				if mythic_runtime != null:
					mythic_runtime.set("acquisition_active", true)
		return {
			"attempted": rewards.size(),
			"granted": rewards.size(),
			"starpoint_granted": rewards.size() if reward_type == "starpoint" else 0,
			"mythic_granted": rewards.size() if reward_type == "mythic" else 0,
			"failed": [],
		}


func _init() -> void:
	_verify_module_registration()
	_verify_stage_clear_box_kind_odds()
	_verify_scene_shell_prewarm_is_light()
	_verify_prewarm_assets_are_staged()
	_verify_prewarm_assets_follow_selected_character()
	_verify_screen_defers_unwarmed_scene_spawn()
	_verify_screen_opens_for_player_win()
	_verify_box_open_audio_routes_from_screen()
	_verify_screen_ignores_boss_win()
	_verify_stage_summary_includes_stage_inventory()
	_verify_starpoint_choice_waits_on_result_screen()
	_verify_mythic_box_starts_result_screen_acquisition_cinematic()
	_verify_advance_through_boxes_to_next_stage()
	_verify_exit_to_menu_from_visible_scroll()
	_verify_escape_ignored_while_boxes_remain()
	_verify_scoreboard_flow_waits_for_result_screen()
	_verify_scoreboard_flow_falls_back_to_reset()

	print("stage_clear_result_screen_smoke: ok")
	quit(0)


func _verify_module_registration() -> void:
	var spec: Dictionary = GameplayCoreModuleCatalog.new().get_spec("stage_clear_result_screen")
	_expect(str(spec.get("path", "")) == "res://scripts/core/stage_clear_result_screen.gd", "result screen should be registered in the core module catalog")


func _verify_stage_clear_box_kind_odds() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	_expect(builder.roll_stage_clear_box_kind(0.0) == "guaranteed_mythic", "stage-clear box odds should map the low 3 percent to guaranteed mythic boxes")
	_expect(builder.roll_stage_clear_box_kind(0.029) == "guaranteed_mythic", "guaranteed mythic box range should end before 3 percent")
	_expect(builder.roll_stage_clear_box_kind(0.03) == "advanced", "stage-clear box odds should map rolls from 3 percent to advanced boxes")
	_expect(builder.roll_stage_clear_box_kind(0.229) == "advanced", "advanced box range should add exactly 20 percent")
	_expect(builder.roll_stage_clear_box_kind(0.23) == "normal", "normal boxes should occupy the remaining 77 percent")


func _verify_scene_shell_prewarm_is_light() -> void:
	StageClearResultScene.reset_prewarm_assets_for_test()
	var screen: Object = StageClearResultScreen.new()
	_expect(screen.prewarm_scene_shell(), "result screen shell prewarm should load the packed scene")
	var status: Dictionary = screen.get("_prewarm_assets_status")
	_expect(bool(status.get("result_scene_packed", false)), "result screen shell prewarm should mark the scene packed")
	_expect(not status.has("background_texture"), "result screen shell prewarm should not load the heavy result background")
	_expect(not status.has("dalji_defeat_sheet"), "result screen shell prewarm should not load large result animation sheets")
	_expect(not status.has("stage2_boss_defeat_live2d_sheet"), "result screen shell prewarm should not load Stage 2 result animation sheets")
	_expect(not status.has("stage2_boss_defeat_click_reaction_sheet"), "result screen shell prewarm should not load Stage 2 click reaction animation sheets")
	_expect(not status.has("result_box_sheet_guaranteed_mythic"), "result screen shell prewarm should not load guaranteed mythic result box sheets")


func _verify_prewarm_assets_are_staged() -> void:
	StageClearResultScene.reset_prewarm_assets_for_test()
	var screen: Object = StageClearResultScreen.new()
	var calls := 0
	while not bool(screen.prewarm_assets_step()):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1, "result screen staged prewarm should complete within the declared step budget")
	calls += 1
	_expect(
		calls == StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1,
		"result screen should split packed-scene, texture, audio, and FX prewarm across separate steps"
	)
	var status: Dictionary = screen.get("_prewarm_assets_status")
	_expect(bool(status.get("result_scene_packed", false)), "result screen staged prewarm should load the packed scene")
	_expect(int(status.get("current_stage", 0)) == 1, "result screen staged prewarm should remember the current stage")
	_expect(bool(status.get("background_texture", false)), "result screen staged prewarm should load the result background")
	_expect(bool(status.get("dalji_defeat_sheet", false)), "Stage 1 result prewarm should load the Dalji base sheet")
	_expect(bool(status.get("dalji_click_reaction_sheet", false)), "Stage 1 result prewarm should load the Dalji click sheet")
	_expect(not status.has("stage2_boss_defeat_live2d_sheet"), "Stage 1 result prewarm should skip Stage 2 boss base sheets")
	_expect(not status.has("stage2_boss_defeat_click_reaction_sheet"), "Stage 1 result prewarm should skip Stage 2 boss click sheets")
	_expect(bool(status.get("result_box_sheet_guaranteed_mythic", false)), "result screen staged prewarm should load the guaranteed mythic result box sheet")
	_expect(bool(status.get("result_box_fx", false)), "result screen staged prewarm should prewarm result-box FX")

	var stage2_owner := FakeOwner.new()
	stage2_owner.current_stage = 2
	calls = 0
	while not bool(screen.prewarm_assets_step(stage2_owner)):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1, "Stage 2 result prewarm should complete within the declared step budget")
	status = screen.get("_prewarm_assets_status")
	_expect(int(status.get("current_stage", 0)) == 2, "Stage 2 result prewarm should remember the current stage")
	_expect(bool(status.get("stage2_boss_defeat_live2d_sheet", false)), "Stage 2 result prewarm should load the Stage 2 boss base sheet")
	_expect(bool(status.get("stage2_boss_defeat_click_reaction_sheet", false)), "Stage 2 result prewarm should load the Stage 2 boss click sheet")
	_expect(not status.has("dalji_defeat_sheet"), "Stage 2 result prewarm should skip the Dalji base sheet")
	_expect(not status.has("dalji_click_reaction_sheet"), "Stage 2 result prewarm should skip the Dalji click sheet")
	stage2_owner.free()


func _verify_prewarm_assets_follow_selected_character() -> void:
	StageClearResultScene.reset_prewarm_assets_for_test()
	var screen: Object = StageClearResultScreen.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var calls := 0
	while not bool(screen.prewarm_assets_step(owner)):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1, "Commando result prewarm should complete within the declared step budget")
	var status: Dictionary = screen.get("_prewarm_assets_status")
	_expect(str(status.get("selected_character_type", "")) == "soldier", "result screen staged prewarm should remember the selected Commando character")
	_expect(bool(status.get("player_victory_sheet", false)), "Commando result prewarm should load the selected player victory base sheet")
	_expect(bool(status.get("player_victory_click_reaction_sheet", false)), "Commando result prewarm should load the selected player victory click sheet")
	owner.selected_character_type = "viper"
	calls = 0
	while not bool(screen.prewarm_assets_step(owner)):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 1, "unsupported result victory characters should complete fallback prewarm")
	status = screen.get("_prewarm_assets_status")
	_expect(str(status.get("selected_character_type", "")) == "smasher", "unsupported result victory characters should prewarm the Smasher fallback sheet")
	owner.free()


func _verify_screen_defers_unwarmed_scene_spawn() -> void:
	StageClearResultScene.reset_prewarm_assets_for_test()
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	var screen: Object = StageClearResultScreen.new()

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable()),
		"unwarmed stage-clear result screen should still open for a player win"
	)
	_expect(screen.is_active(), "unwarmed result screen should become active immediately")
	_expect(owner.get_child_count() == 0, "unwarmed result screen should defer attaching the heavy scene")
	var status: Dictionary = screen.get_status()
	_expect(bool(status.get("spawn_pending", false)), "unwarmed result screen should expose pending staged spawn")
	_expect(
		screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0)),
		"pending result screen should consume input while assets are staged"
	)
	_expect(owner.get_child_count() == 0, "pending input must not skip staged scene preparation")
	_ensure_result_scene_spawned(screen, owner)
	status = screen.get_status()
	_expect(bool(status.get("scene_ready", false)), "staged result screen should report readiness after spawn")
	_expect(not bool(status.get("spawn_pending", true)), "staged result screen should clear pending spawn after attach")
	owner.free()


func _verify_screen_opens_for_player_win() -> void:
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()
	var reward_resolver := FakeRewardResolver.new()
	screen.set("_reward_resolver", reward_resolver)

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable(sink, "reset_game")),
		"stage clear result screen should open for a player match win"
	)
	_expect(screen.is_active(), "result screen should become active")
	_ensure_result_scene_spawned(screen, owner)
	_expect(owner.get_child_count() == 1, "result screen should add a dedicated scene child to the battle scene")
	var result_scene := owner.get_child(0)
	_expect(result_scene is Control, "result screen scene root should be a Control")
	_expect(result_scene.name == "StageClearResultScene", "result screen scene should use the runtime result scene name")
	_expect(result_scene.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "result scene should own linear filtering for cutscene art")
	if result_scene.has_method("get_interaction_status"):
		var scene_status: Dictionary = result_scene.get_interaction_status()
		_expect(bool(scene_status.get("scroll_texture_loaded", false)), "result scene should load the generated cyber scroll texture")

	var plan: Dictionary = screen.get_reward_plan()
	_expect(int(plan.get("reward_count", 0)) == 5, "5:0 reward plan should expose five stage-clear boxes")
	var boxes_value: Variant = plan.get("boxes", [])
	var boxes: Array = boxes_value if boxes_value is Array else []
	_expect(boxes.size() == 5, "5:0 reward plan should include five box entries")
	for box_value in boxes:
		var box: Dictionary = box_value if box_value is Dictionary else {}
		_expect(str(box.get("kind", "")) in ["guaranteed_mythic", "advanced", "normal"], "5:0 reward plan should roll an allowed box kind")

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_ENTER
	key_event.physical_keycode = KEY_ENTER
	_expect(screen.handle_input(key_event, owner, registry, Vector2(1920.0, 1080.0)), "Enter should be consumed by the result screen")
	_expect(screen.is_active(), "Enter while boxes remain should keep the result screen active (advance opens boxes)")
	_expect(sink.reset_calls == 0, "Enter during the box phase must not invoke the next-stage callback yet")
	owner.free()


func _verify_box_open_audio_routes_from_screen() -> void:
	var score_state := FakeScoreState.new()
	score_state.boss_score = 4
	var audio := FakeGameAudio.new()
	var registry := FakeRegistry.new(score_state, null, null, audio)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var screen: Object = StageClearResultScreen.new()

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable()),
		"result screen should open for box-open audio routing smoke"
	)
	_ensure_result_scene_spawned(screen, owner)
	var result_scene := owner.get_child(0)
	_expect(result_scene.has_method("get_interaction_status"), "result scene should expose interaction status")
	var scene_status: Dictionary = result_scene.get_interaction_status()
	_expect(bool(scene_status.get("box_open_audio_ready", false)), "result screen should pass game audio into the result scene")
	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	_expect(audio.result_box_open_calls == 1, "opening a result box should play the routed box-open SFX")
	owner.free()


func _verify_screen_ignores_boss_win() -> void:
	var score_state := FakeScoreState.new()
	score_state.player_score = 2
	score_state.boss_score = 5
	var screen: Object = StageClearResultScreen.new()
	var owner := FakeOwner.new()
	_expect(
		not screen.show_from_scoreboard(owner, FakeRegistry.new(score_state), Callable()),
		"stage clear result screen should not open for a boss match win"
	)
	_expect(not screen.is_active(), "boss win should leave result screen inactive")
	owner.free()


func _verify_stage_summary_includes_stage_inventory() -> void:
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	owner.current_stage = 2
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner.active_item_slots = [
		{
			"name": "banana",
			"display_name": "Banana",
			"type": "active",
			"icon_path": "res://assets/sprites/items/banana.png",
		},
	]
	owner.passive_item_inventory = [
		{
			"name": "speedboots",
			"display_name": "Speed Boots",
			"type": "passive",
			"rarity": "passive",
			"icon_path": "res://assets/sprites/items/speedboots.png",
			"_inventory_id": 1,
		},
	]
	owner.runtime_perk_levels = {
		"dash_lightweight": 1,
	}
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()
	screen.prepare_stage_start(owner, registry, 2)

	owner.passive_item_inventory.append({
		"name": "megingjord",
		"display_name": "Megingjord",
		"type": "mythic",
		"rarity": "mythic",
		"icon_path": "res://assets/sprites/items/megingjord.png",
		"_inventory_id": 2,
	})
	owner.runtime_perk_levels["dash_module_control"] = 2

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable(sink, "reset_game")),
		"stage clear result screen should open for stage-summary inventory smoke"
	)
	_ensure_result_scene_spawned(screen, owner)
	var result_scene := owner.get_child(0)
	var scene_status: Dictionary = result_scene.get_interaction_status()
	_expect(int(scene_status.get("stage_active_item_count", 0)) == 1, "result scroll should include remaining active items")
	_expect(int(scene_status.get("stage_passive_item_count", 0)) == 1, "result scroll should include passive items acquired during this stage")
	_expect(int(scene_status.get("stage_perk_count", 0)) == 1, "result scroll should include perks acquired during this stage")
	_expect(int(scene_status.get("item_reward_count", 0)) == 2, "item summary should combine stage passive items and remaining active items")
	_expect(int(scene_status.get("perk_reward_count", 0)) == 1, "perk summary should include stage perk gains before box rewards")
	owner.free()


func _verify_starpoint_choice_waits_on_result_screen() -> void:
	var score_state := FakeScoreState.new()
	score_state.boss_score = 4
	var runtime_state := FakeRuntimePerkState.new()
	var runtime_catalog := FakeRuntimePerkCatalog.new()
	var audio := FakeGameAudio.new()
	var registry := FakeRegistry.new(score_state, runtime_state, runtime_catalog, audio)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()
	var reward_resolver := FakeRewardResolver.new()
	screen.set("_reward_resolver", reward_resolver)

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable(sink, "reset_game")),
		"result screen should open for deferred starpoint choice smoke"
	)
	_ensure_result_scene_spawned(screen, owner)
	var result_scene := owner.get_child(0)
	_expect(result_scene != null and result_scene.visible, "result scene should start visible")

	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	for _i in range(14):
		screen.update(0.05)

	_expect(reward_resolver.grant_calls == 1, "starpoint reward should still grant when the box opens")
	_expect(runtime_state.collect_calls == 1, "starpoint grant should reach runtime perk state")
	_expect(runtime_state.last_defer_choice_open, "result-screen starpoint grant should defer opening the perk choice")
	_expect(not runtime_state.choice_active, "perk choice should not open during the star rise")
	_expect(audio.runtime_perk_choice_open_calls == 0, "perk-choice open SFX should wait for the deferred modal")
	_expect(result_scene.visible, "result scene should remain visible while the starpoint choice is delayed")
	var scene_status: Dictionary = result_scene.get_interaction_status()
	_expect(bool(scene_status.get("starpoint_choice_gate_active", false)), "result scene should gate box/scroll input while waiting to open the choice")
	var screen_status: Dictionary = screen.get_status()
	var pending_delay: float = float(screen_status.get("pending_starpoint_choice_delay", -1.0))
	_expect(
		StageClearResultScreen.STARPOINT_CHOICE_REWARD_DELAY < 1.0,
		"result-screen starpoint choices should open quickly after the reward reveal"
	)
	_expect(pending_delay > 0.0, "deferred starpoint choice should expose remaining delay")

	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	_expect(sink.reset_calls == 0, "Enter during delayed starpoint choice must not advance stages")

	screen.update(max(0.0, pending_delay - 0.05))
	_expect(not runtime_state.choice_active, "perk choice should wait until the faster starpoint reveal delay finishes")

	screen.update(0.10)
	_expect(runtime_state.choice_active, "perk choice should open after the delayed starpoint animation")
	_expect(runtime_state.open_calls == 1, "deferred starpoint should open one perk-choice modal")
	_expect(str(runtime_state.last_choice_context.get("source", "")) == "result_box_starpoint_choice", "result-screen starpoint choices should carry their box source context")
	_expect(bool(runtime_state.last_choice_context.get("defer_instant_dimension_gate_until_spawn_intro_end", false)), "result-screen starpoint choices should defer instant dimension gate until the next spawn intro ends")
	_expect(bool(runtime_state.last_choice_context.get("defer_instant_full_gauge_until_spawn_intro_end", false)), "result-screen starpoint choices should defer instant full gauge until the next spawn intro ends")
	_expect(audio.runtime_perk_choice_open_calls == 1, "deferred result-screen perk choice should play its open SFX once")
	_expect(result_scene.visible, "result scene should remain visible behind the perk choice")
	scene_status = result_scene.get_interaction_status()
	_expect(bool(scene_status.get("runtime_perk_choice_active", false)), "result scene should expose the active perk choice overlay state")
	_expect(not bool(scene_status.get("starpoint_choice_gate_active", true)), "starpoint gate should clear once the perk choice opens")

	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	_expect(runtime_state.choose_calls == 1, "result-scene perk overlay input should choose the selected perk")
	_expect(not runtime_state.choice_active, "choosing a result-scene perk should close the perk overlay")
	_expect(sink.reset_calls == 0, "choosing a perk must not also advance to the next stage")
	scene_status = result_scene.get_interaction_status()
	_expect(int(scene_status.get("starpoint_total", -1)) == 0, "resolved box starpoints should no longer appear as perk choice tickets")
	_expect(int(scene_status.get("perk_reward_count", 0)) == 1, "resolved box starpoints should appear as the selected perk")
	var perk_source_counts: Dictionary = scene_status.get("perk_reward_source_counts", {}) if scene_status.get("perk_reward_source_counts", {}) is Dictionary else {}
	_expect(int(perk_source_counts.get("box", 0)) == 1, "selected result-screen perks should keep the box reward source")
	var perk_info: Dictionary = scene_status.get("perk_info", {}) if scene_status.get("perk_info", {}) is Dictionary else {}
	_expect(str(perk_info.get("kind", "")) == "perk", "result perk info should describe the selected perk after a box starpoint choice")
	owner.free()


func _verify_mythic_box_starts_result_screen_acquisition_cinematic() -> void:
	var score_state := FakeScoreState.new()
	score_state.boss_score = 4
	var mythic_runtime := FakeMythicItemRuntime.new()
	var registry := FakeRegistry.new(score_state, null, null, null, mythic_runtime)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var screen: Object = StageClearResultScreen.new()
	var reward_resolver := FakeRewardResolver.new()
	reward_resolver.reward_type = "mythic"
	screen.set("_reward_resolver", reward_resolver)

	_expect(
		screen.show_from_scoreboard(owner, registry, Callable()),
		"result screen should open for result-screen mythic cinematic smoke"
	)
	_ensure_result_scene_spawned(screen, owner)
	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	for _i in range(14):
		screen.update(0.05)

	_expect(reward_resolver.grant_calls == 1, "mythic reward should grant immediately when the result box opens")
	_expect(not reward_resolver.granted_rewards.is_empty(), "mythic immediate grant should pass the reward payload")
	var granted_reward: Dictionary = reward_resolver.granted_rewards[0] if reward_resolver.granted_rewards[0] is Dictionary else {}
	_expect(bool(granted_reward.get("show_acquisition_cinematic", false)), "result mythic grant should request the field acquisition cinematic")
	_expect(granted_reward.get("pickup_position", null) is Vector2, "result mythic grant should pass the opened box position to the cinematic")
	_expect(granted_reward.get("target_player_center", null) is Vector2, "result mythic grant should pass the result Live2D target to the cinematic")
	if granted_reward.get("pickup_position", null) is Vector2 and granted_reward.get("target_player_center", null) is Vector2:
		var pickup_position: Vector2 = granted_reward.get("pickup_position")
		var target_player_center: Vector2 = granted_reward.get("target_player_center")
		_expect(target_player_center.x > pickup_position.x, "result mythic absorb target should sit on the right-side Live2D panel")
	_expect(mythic_runtime.acquisition_active, "result mythic grant should activate the acquisition cinematic")

	screen.update(0.05)
	_expect(mythic_runtime.update_calls > 0, "result screen should update an active mythic acquisition cinematic")
	var result_scene := owner.get_child(0)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	_expect(result_scene.has_method("handle_result_input"), "result scene should expose GUI input handling")
	_expect(result_scene.handle_result_input(click_event), "result-scene GUI input should be consumed during mythic acquisition")
	_expect(mythic_runtime.input_calls == 1, "result-scene GUI mouse input should route to the mythic acquisition cinematic")
	_expect(not mythic_runtime.acquisition_active, "mythic acquisition click should start the absorb/finish path instead of opening result UI")
	mythic_runtime.acquisition_active = true
	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	_expect(mythic_runtime.input_calls == 2, "result screen should route controller input to the mythic acquisition cinematic first")
	owner.free()


func _verify_advance_through_boxes_to_next_stage() -> void:
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()
	var reward_resolver := FakeRewardResolver.new()
	screen.set("_reward_resolver", reward_resolver)

	_expect(
		screen.show_from_scoreboard(
			owner, registry,
			Callable(sink, "reset_game"),
			Callable(sink, "exit_to_menu")
		),
		"result screen should open for player win in advance scenario"
	)
	_ensure_result_scene_spawned(screen, owner)

	var box_count: int = int(screen.get_reward_plan().get("reward_count", 0))
	_expect(box_count > 0, "5:0 plan must expose at least one box for advance smoke")
	for _i in range(box_count):
		screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	for _i in range(80):
		screen.update(0.05)
	_expect(screen.is_active(), "result screen should still be active until next-stage Enter")
	_expect(reward_resolver.grant_calls == box_count, "starpoint box rewards should grant immediately as boxes open")

	screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	_expect(not screen.is_active(), "Enter on visible scroll should close the result screen")
	_expect(sink.reset_calls == 1, "Enter on visible scroll must invoke the next-stage callback exactly once")
	_expect(sink.exit_calls == 0, "Enter on visible scroll must not invoke the exit callback")
	_expect(reward_resolver.roll_calls == box_count, "result screen should roll one reward per opened box")
	_expect(reward_resolver.grant_calls == box_count, "next-stage confirmation should not re-grant immediately handled starpoints")
	var status: Dictionary = screen.get_status()
	var grant_summary: Dictionary = status.get("last_grant_summary", {}) if status.get("last_grant_summary", {}) is Dictionary else {}
	_expect(bool(status.get("rewards_granted", false)), "next-stage confirmation should mark rewards granted")
	_expect(int(grant_summary.get("attempted", 0)) == box_count, "grant summary should include all opened box rewards")
	owner.free()


func _verify_exit_to_menu_from_visible_scroll() -> void:
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()
	var reward_resolver := FakeRewardResolver.new()
	screen.set("_reward_resolver", reward_resolver)

	screen.show_from_scoreboard(
		owner, registry,
		Callable(sink, "reset_game"),
		Callable(sink, "exit_to_menu")
	)
	_ensure_result_scene_spawned(screen, owner)

	var box_count: int = int(screen.get_reward_plan().get("reward_count", 0))
	for _i in range(box_count):
		screen.handle_input(_make_key_event(KEY_ENTER), owner, registry, Vector2(1920.0, 1080.0))
	for _i in range(80):
		screen.update(0.05)

	screen.handle_input(_make_key_event(KEY_ESCAPE), owner, registry, Vector2(1920.0, 1080.0))
	_expect(not screen.is_active(), "ESC on visible scroll should close the result screen")
	_expect(sink.exit_calls == 1, "ESC on visible scroll must invoke the exit-to-menu callback exactly once")
	_expect(sink.reset_calls == 0, "ESC on visible scroll must not invoke the next-stage callback")
	_expect(reward_resolver.grant_calls == box_count, "exit confirmation should not re-grant immediately handled starpoints")
	owner.free()


func _verify_escape_ignored_while_boxes_remain() -> void:
	var score_state := FakeScoreState.new()
	var registry := FakeRegistry.new(score_state)
	var owner := FakeOwner.new()
	owner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sink := CallbackSink.new()
	var screen: Object = StageClearResultScreen.new()

	screen.show_from_scoreboard(
		owner, registry,
		Callable(sink, "reset_game"),
		Callable(sink, "exit_to_menu")
	)
	_ensure_result_scene_spawned(screen, owner)

	screen.handle_input(_make_key_event(KEY_ESCAPE), owner, registry, Vector2(1920.0, 1080.0))
	_expect(screen.is_active(), "ESC during box phase must not close the result screen")
	_expect(sink.reset_calls == 0, "ESC during box phase must not invoke the next-stage callback")
	_expect(sink.exit_calls == 0, "ESC during box phase must not invoke the exit callback")
	owner.free()


func _make_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _ensure_result_scene_spawned(screen: Object, owner: Node) -> void:
	var max_steps: int = StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT + 4
	for _i in range(max_steps):
		if owner.get_child_count() > 0:
			return
		screen.update(0.016)
	_expect(owner.get_child_count() > 0, "result screen should attach the staged scene after prewarm steps")


func _verify_scoreboard_flow_waits_for_result_screen() -> void:
	var sink := CallbackSink.new()
	MatchScoreboardFlowController.new().update_scoreboard(
		0.0,
		{"scoreboard_state": FakeScoreboard.new()},
		{
			"show_stage_clear_result": Callable(sink, "show_stage_clear_result"),
			"reset_game": Callable(sink, "reset_game"),
		},
		{"update_reset_game": 2}
	)
	_expect(sink.show_calls == 1, "scoreboard reset result should ask the result screen to open")
	_expect(sink.reset_calls == 0, "scoreboard flow should not reset while the result screen is open")


func _verify_scoreboard_flow_falls_back_to_reset() -> void:
	var sink := CallbackSink.new()
	sink.show_result = false
	MatchScoreboardFlowController.new().update_scoreboard(
		0.0,
		{"scoreboard_state": FakeScoreboard.new()},
		{
			"show_stage_clear_result": Callable(sink, "show_stage_clear_result"),
			"reset_game": Callable(sink, "reset_game"),
		},
		{"update_reset_game": 2}
	)
	_expect(sink.show_calls == 1, "scoreboard flow should try the result screen before fallback reset")
	_expect(sink.reset_calls == 1, "scoreboard flow should reset when no result screen opens")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
