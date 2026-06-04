extends SceneTree

const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetDebugPicker := preload("res://scripts/core/lingpet_debug_picker.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraws := 0
	var ai_mode := "junior league"
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_active_skill_level := 0
	var ringpet_active_skill_level := 0
	var lingpet_active_skill_max_level := 0
	var ringpet_active_skill_max_level := 0
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_player_speed_bonus_pct := 0.0
	var ringpet_player_speed_bonus_pct := 0.0
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_level := 0
	var ringpet_passive_skill_level := 0
	var lingpet_passive_skill_max_level := 0
	var ringpet_passive_skill_max_level := 0
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

	func queue_redraw() -> void:
		redraws += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeAudio:
	extends RefCounted

	var lingpet_acquire_count := 0
	var lingpet_click_reaction_pet_ids: Array = []

	func play_lingpet_acquire_cutin() -> void:
		lingpet_acquire_count += 1

	func play_lingpet_click_reaction(pet_id: String) -> void:
		lingpet_click_reaction_pet_ids.append(pet_id)


class FakeAcquireRuntime:
	extends RefCounted

	var active := true

	func is_acquire_cutin_active() -> bool:
		return active


class FakeAcquireHost:
	extends RefCounted

	var draw_count := 0

	func draw(_canvas: CanvasItem, _runtime: Object, _view_size: Vector2) -> void:
		draw_count += 1


class FakeResultScreen:
	extends RefCounted

	var active := true
	var draw_count := 0
	var input_count := 0

	func is_active() -> bool:
		return active

	func draw(_canvas: CanvasItem, _owner: Object, _registry: Object, _view_size: Vector2) -> void:
		draw_count += 1

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		input_count += 1
		return true


class FakeOverlayInput:
	extends RefCounted

	var input_count := 0

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _module_getter: Callable, _context: Dictionary) -> bool:
		input_count += 1
		return true


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _stage_landing_intro_started: bool) -> bool:
		return false


func _init() -> void:
	_verify_catalog_and_source_wiring()
	_verify_red_dragon_click_live2d_catalog_wiring()
	_verify_catalog_entries_are_cached_for_draw_helpers()
	_verify_f7_opens_lingpet_debug_picker()
	_verify_click_grants_and_activates_lingpet()
	_verify_acquire_cutin_overlays_stage_result_paths()
	_verify_debug_grant_accepts_explicit_skill_loadout()
	_verify_full_slots_replace_active_slot_for_debug_grant()
	if _failures.is_empty():
		print("lingpet_debug_picker_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_source_wiring() -> void:
	var spec: Dictionary = GameplayCoreModuleCatalog.new().get_spec("lingpet_debug_picker")
	_expect(str(spec.get("path", "")) == "res://scripts/core/lingpet_debug_picker.gd", "lingpet debug picker should be registered in the core module catalog")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_input_controller.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(input_source.find("KEY_F7") >= 0 and input_source.find("DEBUG_MENU_LINGPET_PICKER") >= 0, "overlay input should wire F7 to the lingpet debug menu")
	_expect(frame_source.find("draw.overlay.lingpet_debug") >= 0, "overlay frame controller should draw the lingpet debug menu")
	_expect(gate_source.find("is_lingpet_debug_picker_open") >= 0 and gate_source.find("physics.modal_gate.lingpet_debug") >= 0, "modal gate should expose lingpet debug as a blocking modal")


func _verify_red_dragon_click_live2d_catalog_wiring() -> void:
	_expect(LingpetCatalog.has_pet("red_dragon"), "Red Dragon should be a debug-activatable lingpet catalog entry")
	_expect(
		LingpetCatalog.get_visual_path("red_dragon", "click_reaction_anim") == "res://assets/sprites/lingpet/red_dragon_lingpet_click_live2d_pingpong_98f.png",
		"Red Dragon should wire the dedicated click Live2D reaction sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("red_dragon", "cutin_anim") == "res://assets/sprites/lingpet/red_dragon_cutin_anim.png",
		"Red Dragon acquisition cut-in should not fall back to Maribo's cut-in animation"
	)
	_expect(
		LingpetCatalog.get_visual_path("red_dragon", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/red_dragon_cutin_dismiss_anim.png",
		"Red Dragon acquisition dismiss cut-in should use the dedicated red dragon sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("red_dragon", "companion_walk") == "res://assets/sprites/lingpet/red_dragon_companion_wing_flap.png",
		"Red Dragon should wire the dedicated in-game SD wing-flap sheet"
	)
	var red_dragon_cutin_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/red_dragon_cutin_anim_manifest.json")
	var red_dragon_dismiss_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/red_dragon_cutin_dismiss_anim_manifest.json")
	var red_dragon_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/red_dragon_lingpet_click_live2d_pingpong_98f_manifest.json")
	var red_dragon_wing_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/red_dragon_companion_wing_flap_manifest.json")
	_expect(
		red_dragon_cutin_manifest.find("red_dragon_acquisition_cutin_anim_v3_32f_smooth") >= 0
		and red_dragon_cutin_manifest.find("\"frame_count\": 32") >= 0
		and red_dragon_cutin_manifest.find("\"playback_fps\": 16.0") >= 0,
		"Red Dragon acquisition cut-in should use the smooth 32-frame AutoSprite sheet with a 16fps playback contract"
	)
	_expect(
		red_dragon_click_manifest.find("red_dragon_lingpet_click_live2d_pingpong_98f_v2") >= 0 and red_dragon_click_manifest.find("motion_separation") >= 0,
		"Red Dragon click Live2D should use the separate v2 click-reaction motion"
	)
	_expect(
		red_dragon_cutin_manifest.find("realesr-animevideov3") >= 0
		and red_dragon_dismiss_manifest.find("realesr-animevideov3") >= 0
		and red_dragon_click_manifest.find("realesr-animevideov3") >= 0,
		"Red Dragon acquisition, dismiss, and click Live2D sheets should record the accepted Real-ESRGAN animev3 x2 upscale"
	)
	_expect(
		red_dragon_wing_manifest.find("red_dragon_companion_wing_flap_v3_rear_locked") >= 0 and red_dragon_wing_manifest.find("cmpz3okgv001210fbdhn4pnpv") >= 0,
		"Red Dragon SD companion wing-flap should use the rear-view AutoSprite v3 sheet"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "cutin_anim_view_h_ratio", 0.0), 0.568)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "cutin_dismiss_view_h_ratio", 0.0), 0.568)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "click_reaction_draw_size", 0.0), 64.0),
		"Red Dragon Live2D acquisition and click reaction should apply the requested 20 percent smaller visual layout"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "companion_walk_draw_size", 0.0), 83.2)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "companion_strike_draw_size", 0.0), 83.2)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "companion_cast_draw_size", 0.0), 83.2),
		"Red Dragon in-game SD companion should apply the requested 20 percent smaller visual layout"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("red_dragon", "companion_wing_flap_max_speed_ratio", 0.0), 0.55),
		"Red Dragon in-game SD companion should cap high-speed wing-flap cadence to avoid jittery flight"
	)
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("red_dragon_dragon_breath") == "dragon_breath",
		"Red Dragon Dragon Breath should use the dedicated dragon_breath runtime kind"
	)
	_expect(
		is_equal_approx(float(LingpetCatalog.get_active_skill_entry("red_dragon_dragon_breath").get("cooldown", 0.0)), 40.0),
		"Red Dragon Dragon Breath should use the requested 40-second cooldown"
	)
	_expect(
		LingpetCatalog.get_motion_style("red_dragon") == "sortie_flight",
		"Red Dragon should use the same sortie-flight movement style as Lunabi"
	)
	var hatch_candidates := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(hatch_candidates.has("red_dragon"), "Red Dragon should be available from the Junior Smasher hatch pool")


func _verify_catalog_entries_are_cached_for_draw_helpers() -> void:
	var picker := LingpetDebugPicker.new()
	var view_size := Vector2(1280.0, 720.0)
	_expect(picker.get_entries_build_count_for_tests() == 0, "lingpet picker cache should start cold")
	_expect(str(picker.get_pet_id_for_tests(0)) != "", "lingpet picker should build a non-empty catalog cache")
	var first_build_count := int(picker.get_entries_build_count_for_tests())
	picker.get_pet_id_for_tests(1)
	picker.get_card_rect_for_tests(0, view_size)
	picker.get_apply_button_rect_for_tests(view_size)
	_expect(first_build_count == 1, "lingpet picker should build the catalog cache once")
	_expect(picker.get_entries_build_count_for_tests() == first_build_count, "lingpet picker draw helpers should reuse the catalog cache")


func _verify_f7_opens_lingpet_debug_picker() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var modal_gate := BattleSceneModalGateController.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": modal_gate,
		"game_audio": audio,
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var input := BattleSceneOverlayInputController.new()
	var handled := bool(input.handle_input(_key_event(KEY_F7), owner, registry, Callable(registry, "get_instance"), {}))
	_expect(handled, "F7 should be handled by overlay input")
	_expect(picker.is_open(), "F7 should open the lingpet debug picker")
	_expect(_find_pet_index(picker, "milkring") >= 0, "F7 lingpet debug picker should list Milkring")
	_expect(_find_pet_index(picker, "volty") >= 0, "F7 lingpet debug picker should list Volty")
	_expect(_find_pet_index(picker, "orbi") >= 0, "F7 lingpet debug picker should list Orbi")
	_expect(_find_pet_index(picker, "red_dragon") >= 0, "F7 lingpet debug picker should list Red Dragon")
	_expect(modal_gate.is_lingpet_debug_picker_open(Callable(registry, "get_instance")), "modal gate should see the open lingpet picker")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "open lingpet picker should block battle physics")
	_expect(owner.redraws == 1, "opening lingpet debug should request one redraw")


func _verify_click_grants_and_activates_lingpet() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var modal_gate := BattleSceneModalGateController.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": modal_gate,
		"game_audio": audio,
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	picker.toggle(owner)
	var target_index := _find_pet_index(picker, "maribo")
	if target_index < 0:
		target_index = 0
	var target_pet_id := picker.get_pet_id_for_tests(target_index)
	var selected_before_hover := picker.get_selected_pet_id_for_tests()
	var hover_index := _find_pet_index(picker, "milkring")
	if hover_index >= 0 and hover_index != target_index:
		var hover_rect := picker.get_card_rect_for_tests(hover_index, owner.get_viewport_rect().size)
		var hover_handled := bool(picker.handle_input(_mouse_motion(hover_rect.position + hover_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
		_expect(hover_handled, "hovering a lingpet card should be handled by the F7 picker")
		_expect(picker.get_selected_pet_id_for_tests() == selected_before_hover, "hovering a lingpet card should not change the selected F7 lingpet")
	var card_rect := picker.get_card_rect_for_tests(target_index, owner.get_viewport_rect().size)
	var handled := bool(picker.handle_input(_mouse_click(card_rect.position + card_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
	_expect(handled, "clicking a lingpet card should be handled")
	_expect(picker.is_open(), "clicking a lingpet card should keep the picker open for skill loadout selection")
	_expect(owner.active_lingpet_id == "", "card selection alone should not activate the lingpet before the apply command")
	_expect(target_pet_id != "", "target pet id should be available")
	var bubble_trap_index := _find_active_skill_index(picker, "maribo_bubble_trap")
	_expect(bubble_trap_index >= 0, "Maribo bubble trap should be listed as a selectable active skill")
	if bubble_trap_index >= 0:
		var skill_rect := picker.get_active_skill_rect_for_tests(bubble_trap_index, owner.get_viewport_rect().size)
		handled = bool(picker.handle_input(_mouse_click(skill_rect.position + skill_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
		_expect(handled, "clicking an active skill row should be handled")
		_expect(picker.get_active_skill_id_for_tests() == "maribo_bubble_trap", "clicked active skill row should become the selected F7 loadout skill")
	var active_level_plus_rect := picker.get_active_skill_level_plus_rect_for_tests(owner.get_viewport_rect().size)
	for _i in range(2):
		handled = bool(picker.handle_input(_mouse_click(active_level_plus_rect.position + active_level_plus_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
		_expect(handled, "clicking the active skill level plus button should be handled")
	_expect(picker.get_active_skill_level_for_tests() == 3, "F7 active skill level plus button should raise the selected active skill to Lv.3")
	var passive_level_plus_rect := picker.get_passive_skill_level_plus_rect_for_tests(owner.get_viewport_rect().size)
	handled = bool(picker.handle_input(_mouse_click(passive_level_plus_rect.position + passive_level_plus_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
	_expect(handled, "clicking the passive skill level plus button should be handled")
	_expect(picker.get_passive_skill_level_for_tests() == 2, "F7 passive skill level plus button should raise the selected passive skill to Lv.2")
	var apply_rect := picker.get_apply_button_rect_for_tests(owner.get_viewport_rect().size)
	handled = bool(picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, owner.get_viewport_rect().size))
	_expect(handled, "clicking the lingpet apply button should be handled")
	_expect(not picker.is_open(), "apply should close the picker")
	_expect(owner.active_lingpet_id == target_pet_id, "applied lingpet should become the active battle companion")
	_expect(owner.lingpet_state == "companion", "clicked lingpet should immediately enter companion state")
	_expect(owner.lingpet_active_skill_id == "maribo_bubble_trap", "F7 apply should persist the selected active skill loadout")
	_expect(int(owner.lingpet_active_skill_level) == 3, "F7 apply should persist the selected active skill level")
	_expect(owner.lingpet_passive_skill_id == "lingpet_resonance_boost", "F7 apply should persist the default Resonance Boost passive loadout")
	_expect(int(owner.lingpet_passive_skill_level) == 2, "F7 apply should persist the selected passive skill level")
	_expect(owner.lingpet_loadouts.has(target_pet_id), "F7 apply should store a lingpet loadout for the selected pet")
	if owner.lingpet_loadouts.has(target_pet_id):
		var loadout: Dictionary = owner.lingpet_loadouts.get(target_pet_id, {})
		_expect(str(loadout.get("active_skill_id", "")) == "maribo_bubble_trap", "stored F7 loadout should include the selected active skill")
		_expect(int(loadout.get("active_skill_level", 0)) == 3, "stored F7 loadout should include the selected active skill level")
		_expect(str(loadout.get("passive_skill_id", "")) == "lingpet_resonance_boost", "stored F7 loadout should include the default Resonance Boost passive")
		_expect(int(loadout.get("passive_skill_level", 0)) == 2, "stored F7 loadout should include the selected passive skill level")
	_expect(owner.lingpet_owned_pet_ids.has(target_pet_id), "clicked lingpet should be added to owned pet ids")
	_expect(owner.lingpet_slots.has(target_pet_id), "clicked lingpet should be assigned to a battle slot")
	_expect(runtime.is_companion_active(target_pet_id), "runtime should report the clicked lingpet as active")
	_expect(runtime.is_acquire_cutin_active(), "F7 card selection should show the lingpet Live2D acquisition cut-in first")
	_expect(audio.lingpet_acquire_count == 1, "F7-triggered acquisition cut-in should play its cinematic sound once")
	_expect(is_equal_approx(float(runtime.get_acquire_cutin_progress()), 0.0), "F7-triggered acquisition cut-in should start from the first reveal frame")
	_expect(modal_gate.is_lingpet_acquire_cutin_active(Callable(registry, "get_instance")), "modal gate should expose the F7-triggered acquisition cut-in")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "F7-triggered acquisition cut-in should pause battle physics")
	runtime.advance_acquire_cutin(2.0)
	_expect(runtime.is_acquire_cutin_awaiting_dismiss(), "F7-triggered acquisition cut-in should hold until the player clicks")
	var input := BattleSceneOverlayInputController.new()
	handled = bool(input.handle_input(_mouse_click(Vector2(120.0, 120.0)), owner, registry, Callable(registry, "get_instance"), {}))
	_expect(handled, "clicking the held acquisition cut-in should be handled by overlay input")
	_expect(runtime.is_acquire_cutin_dismissing(), "clicking the held acquisition cut-in should start the Live2D exit action")
	_expect(audio.lingpet_click_reaction_pet_ids == [target_pet_id], "clicking the acquisition Live2D exit action should request the selected pet voice once")
	_expect(owner.redraws >= 1, "F7 selection and apply should request redraws")


func _verify_acquire_cutin_overlays_stage_result_paths() -> void:
	var runtime := FakeAcquireRuntime.new()
	var acquire_host := FakeAcquireHost.new()
	var result_screen := FakeResultScreen.new()
	var overlay_input := FakeOverlayInput.new()
	var readiness := FakeReadiness.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_readiness_controller": readiness,
		"battle_scene_overlay_input_controller": overlay_input,
		"lingpet_egg_runtime": runtime,
		"lingpet_acquire_cutin_overlay_host": acquire_host,
		"stage_clear_result_screen": result_screen,
	})
	var canvas := Node2D.new()
	BattleSceneFrameController.new().draw(canvas, owner, registry, Callable(registry, "get_instance"), {})
	_expect(result_screen.draw_count == 1, "active stage-clear result screen should still draw as the base layer")
	_expect(acquire_host.draw_count == 1, "active lingpet acquisition cut-in should draw above the stage-clear result screen")
	canvas.free()

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(Vector2(12.0, 12.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": true,
		}
	)
	_expect(overlay_input.input_count == 1, "lingpet acquisition cut-in should receive input before the stage-clear result screen")
	_expect(result_screen.input_count == 0, "stage-clear result input should not consume clicks while the lingpet acquisition cut-in is active")


func _verify_debug_grant_accepts_explicit_skill_loadout() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_bubble_trap", "maribo_resonance_boost"), "debug grant should accept explicit active/passive skill ids")
	_expect(owner.active_lingpet_id == "maribo", "explicit loadout debug grant should activate the selected pet")
	_expect(owner.lingpet_active_skill_id == "maribo_bubble_trap", "explicit debug grant should sync the chosen active skill to owner state")
	_expect(owner.lingpet_passive_skill_id == "lingpet_resonance_boost", "explicit debug grant should normalize the legacy passive id to Resonance Boost")
	var loadout: Dictionary = owner.lingpet_loadouts.get("maribo", {})
	_expect(str(loadout.get("active_skill_id", "")) == "maribo_bubble_trap", "explicit debug grant should persist active skill in loadouts")
	_expect(str(loadout.get("passive_skill_id", "")) == "lingpet_resonance_boost", "explicit debug grant should persist normalized Resonance Boost in loadouts")


func _verify_full_slots_replace_active_slot_for_debug_grant() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.lingpet_slots = ["maribo", "maribo", "maribo"]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 1
	owner.ringpet_active_slot_index = 1
	_expect(runtime.debug_grant_and_activate_pet("lunabi", owner), "debug grant should accept an implemented lingpet id")
	_expect(owner.active_lingpet_id == "lunabi", "debug grant should activate the selected lingpet even when slots were full")
	_expect(owner.lingpet_slots[owner.lingpet_active_slot_index] == "lunabi", "debug grant should replace the active full slot with the selected lingpet")
	_expect(not runtime.is_acquire_cutin_active(), "direct debug grant should keep cut-in optional unless F7 requests it")


func _find_pet_index(picker: Object, pet_id: String) -> int:
	for index in range(9):
		var current := str(picker.get_pet_id_for_tests(index))
		if current == pet_id:
			return index
		if current == "":
			return -1
	return -1


func _find_active_skill_index(picker: Object, skill_id: String) -> int:
	for index in range(8):
		var current := str(picker.get_active_skill_id_for_tests(index))
		if current == skill_id:
			return index
		if current == "":
			return -1
	return -1


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
