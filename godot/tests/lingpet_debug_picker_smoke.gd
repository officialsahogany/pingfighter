extends SceneTree

const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetDebugPicker := preload("res://scripts/core/lingpet_debug_picker.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

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
	var lingpet_companion_appearance_rate := 0.0
	var ringpet_companion_appearance_rate := 0.0
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
	var lingpet_starpoint_tracking_chance_pct := 0.0
	var ringpet_starpoint_tracking_chance_pct := 0.0
	var lingpet_ring_dash_chance_pct := 0.0
	var ringpet_ring_dash_chance_pct := 0.0
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

	func clear_refs() -> void:
		instances.clear()


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
	_verify_skill_rows_never_overlap_apply_button()
	_verify_click_grants_and_activates_lingpet()
	_verify_debug_picker_can_select_koyora_doll_curse()
	_verify_acquire_cutin_overlays_stage_result_paths()
	_verify_debug_grant_accepts_explicit_skill_loadout()
	_verify_full_slots_replace_active_slot_for_debug_grant()
	_verify_defense_rate_slider()
	_verify_flight_pet_appearance_override()
	_verify_move_speed_slider()
	ProjectResourceLoader.clear_caches()
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
	var shortcut_source := FileAccess.get_file_as_string("res://scripts/core/battle_debug_menu_shortcut_router.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	var picker_source := FileAccess.get_file_as_string("res://scripts/core/lingpet_debug_picker.gd")
	_expect(input_source.find("BattleDebugMenuShortcutRouter") >= 0 and shortcut_source.find("LINGPET_DEBUG_KEY") >= 0 and shortcut_source.find("DEBUG_MENU_LINGPET_PICKER") >= 0, "overlay input should delegate F7 to the lingpet debug menu shortcut router")
	_expect(frame_source.find("draw.overlay.lingpet_debug") >= 0, "overlay frame controller should draw the lingpet debug menu")
	_expect(frame_source.find("process.overlay.lingpet_debug_queue_redraw") >= 0, "overlay frame controller should redraw F7 lingpet debug for animated thumbnails")
	_expect(gate_source.find("is_lingpet_debug_picker_open") >= 0 and gate_source.find("physics.modal_gate.lingpet_debug") >= 0, "modal gate should expose lingpet debug as a blocking modal")
	_expect(picker_source.find("_get_thumbnail_frame") >= 0 and picker_source.find("Time.get_ticks_msec") >= 0, "lingpet debug cards should advance companion-sheet thumbnails instead of pinning frame 0")
	_expect(picker_source.find("ProjectResourceLoader.load_texture(path)") >= 0, "lingpet debug picker thumbnails should use the central loader fallback for newly generated PNGs")


func _verify_red_dragon_click_live2d_catalog_wiring() -> void:
	_expect(LingpetCatalog.has_pet("red_dragon"), "Red Dragon should be a debug-activatable lingpet catalog entry")
	_expect(LingpetCatalog.get_display_name("red_dragon") == "파루키라스", "Red Dragon catalog display name should be Farukiras")
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
		LingpetCatalog.get_active_skill_runtime_kind("red_dragon_dragon_wing") == "dragon_wing",
		"Red Dragon Dragon Wing should use the dedicated dragon_wing runtime kind"
	)
	_expect(
		is_equal_approx(float(LingpetCatalog.get_active_skill_entry("red_dragon_dragon_breath").get("cooldown", 0.0)), 40.0),
		"Red Dragon Dragon Breath should use the requested 40-second cooldown"
	)
	_expect(
		is_equal_approx(float(LingpetCatalog.get_active_skill_entry("red_dragon_dragon_wing").get("cooldown", 0.0)), 15.0),
		"Red Dragon Dragon Wing should keep Ignis' 15-second cooldown"
	)
	var red_dragon_active_pool := LingpetCatalog.get_active_skill_pool("red_dragon")
	_expect(_active_pool_has(red_dragon_active_pool, "red_dragon_dragon_breath"), "Red Dragon active pool should keep Dragon Breath selectable")
	_expect(_active_pool_has(red_dragon_active_pool, "red_dragon_dragon_wing"), "Red Dragon active pool should include Dragon Wing as an Ignis port")
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
	_cleanup_debug_fixture(picker)


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
	_expect(_find_pet_index(picker, "orbi") >= 0, "F7 lingpet debug picker should list Serabi")
	_expect(_find_pet_index(picker, "red_dragon") >= 0, "F7 lingpet debug picker should list Red Dragon")
	_expect(_find_pet_index(picker, "koyora") >= 0, "F7 lingpet debug picker should list debug-only Koyora")
	_expect(_find_pet_index(picker, "nekuring") >= 0, "F7 lingpet debug picker should list debug-only Nekuring")
	_expect(_find_pet_index(picker, "monkeyring") >= 0, "F7 lingpet debug picker should list debug-only Monkeyring")
	_expect(_find_pet_index(picker, "rabi") >= 0, "F7 lingpet debug picker should list debug-only Rabi")
	_expect(_find_pet_index(picker, "onimaru") >= 0, "F7 lingpet debug picker should list debug-only Onimaru")
	_expect(_find_pet_index(picker, "rahoset") >= 0, "F7 lingpet debug picker should list debug-only Rahoset")
	_expect(LingpetCatalog.get_debug_pet_ids().has("koyora"), "Koyora should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("koyora"), "Koyora should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("koyora"), "Koyora should now appear in the enabled hatch pet id list")
	_expect(LingpetCatalog.get_debug_pet_ids().has("nekuring"), "Nekuring should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("nekuring"), "Nekuring should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("nekuring"), "Nekuring should now appear in the enabled hatch pet id list")
	_expect(LingpetCatalog.get_debug_pet_ids().has("monkeyring"), "Monkeyring should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("monkeyring"), "Monkeyring should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("monkeyring"), "Monkeyring should now appear in the enabled hatch pet id list")
	_expect(LingpetCatalog.get_debug_pet_ids().has("rabi"), "Rabi should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("rabi"), "Rabi should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("rabi"), "Rabi should now appear in the enabled hatch pet id list")
	_expect(LingpetCatalog.get_debug_pet_ids().has("onimaru"), "Onimaru should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("onimaru"), "Onimaru should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("onimaru"), "Onimaru should now appear in the enabled hatch pet id list after production promotion")
	_expect(LingpetCatalog.get_debug_pet_ids().has("rahoset"), "Rahoset should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("rahoset"), "Rahoset should be accepted by runtime helpers for F7 debug activation")
	_expect(LingpetCatalog.get_pet_ids().has("rahoset"), "Rahoset should now appear in the enabled hatch pet id list after production promotion")
	var hatch_candidates := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(hatch_candidates.has("koyora"), "Koyora should now enter the random hatch pool")
	_expect(hatch_candidates.has("nekuring"), "Nekuring should now enter the random hatch pool")
	_expect(hatch_candidates.has("monkeyring"), "Monkeyring should now enter the random hatch pool")
	_expect(hatch_candidates.has("onimaru"), "Onimaru should now enter the random hatch pool")
	_expect(hatch_candidates.has("rabi"), "Rabi should now enter the random hatch pool")
	_expect(hatch_candidates.has("rahoset"), "Rahoset should now enter the random hatch pool")
	_expect(LingpetCatalog.get_display_name("rahoset") == "라호세트", "Rahoset catalog display name should use the accepted Korean name")
	_expect(LingpetCatalog.get_motion_style("rahoset") == "sortie_flight", "Rahoset should use the airborne sortie-flight movement style")
	_expect(
		LingpetCatalog.get_visual_path("rahoset", "cutin_art") == "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png"
		and LingpetCatalog.get_visual_path("rahoset", "cutin_anim") == "res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png"
		and LingpetCatalog.get_visual_path("rahoset", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png"
		and LingpetCatalog.get_visual_path("rahoset", "click_reaction_anim") == "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png"
		and LingpetCatalog.get_visual_path("rahoset", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png"
		and LingpetCatalog.get_visual_path("rahoset", "companion_walk") == "res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png"
		and LingpetCatalog.get_visual_path("rahoset", "companion_strike") == "res://assets/sprites/lingpet/rahoset_companion_rear_strike_25f.png",
		"Rahoset F7 debug visuals should route acquisition hover and angle-matched click action to distinct AutoSprite-derived sheets"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1_magenta_source.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_companion_rear_hover_25f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_companion_rear_strike_25f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png"),
		"Rahoset source, exact-magenta source, and distinct F7 debug AutoSprite click-transition sheets should ship under the lingpet asset tree"
	)
	_expect(LingpetCatalog.get_display_name("koyora") == "살각시", "Koyora compatibility id should expose the rebranded Korean display name")
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_art") == "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png",
		"Koyora static Live2D source art should use the accepted attached-tail puppet miko artwork"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_anim") == "res://assets/sprites/lingpet/koyora_cutin_anim.png",
		"Koyora F7 acquisition cut-in should use the 4x4 / 16-frame AutoSprite sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/koyora_cutin_dismiss_anim.png"
		and LingpetCatalog.get_visual_path("koyora", "click_reaction_anim") == "res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png",
		"Koyora acquisition dismiss should route to the dedicated capped dismiss sheet while the full click reaction keeps the full-res 98-frame click Live2D (decoupled 2026-06-21)"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/koyora_companion_click_reaction_98f.png",
		"Koyora in-battle companion click reaction should use the downscaled 14x7 / 128px runtime sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "companion_idle") == "res://assets/sprites/lingpet/koyora_companion_idle.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_move_left") == "res://assets/sprites/lingpet/koyora_companion_move_left.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_move_right") == "res://assets/sprites/lingpet/koyora_companion_move_right.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_walk") == "res://assets/sprites/lingpet/koyora_companion_move_right.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_strike") == "res://assets/sprites/lingpet/koyora_companion_strike.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_cast") == "res://assets/sprites/lingpet/koyora_companion_idle.png",
		"Koyora F7 runtime companion visuals should use dedicated rear-view idle/left/right/strike SD sheets"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "companion_puppet_control") == "res://assets/sprites/lingpet/koyora_puppet_control_cast.png",
		"Koyora Puppet Control should expose the dedicated arm-thrust / pull-in companion sheet"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_view_h_ratio", 0.0), 0.56)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_seconds", 0.0), 4.25)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_action_portion", 0.0), 0.86)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_fade_start", 0.0), 0.70)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "click_reaction_draw_size", 0.0), 84.0),
		"Koyora acquisition click-dismiss should use calmer 98-frame Live2D exit timing"
	)
	var koyora_active_pool := LingpetCatalog.get_active_skill_pool("koyora")
	_expect(_active_pool_has(koyora_active_pool, "koyora_doll_curse"), "Koyora debug loadout should expose Doll Curse as a second active skill")
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("koyora_doll_curse") == "doll_curse",
		"Koyora Doll Curse should route through the ported doll_curse runtime"
	)
	_expect(_active_pool_has(koyora_active_pool, "koyora_puppet_control"), "Koyora debug loadout should expose 꼭두각시 조종 (Puppet Control)")
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("koyora_puppet_control") == "puppet_grab",
		"Koyora 꼭두각시 조종 should route through the ported puppet_grab runtime"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3_magenta_source.png"),
		"Koyora source and exact-magenta source artwork should ship under the lingpet asset tree"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/koyora_cutin_anim.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_idle.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_move_left.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_move_right.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_strike.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_click_reaction_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_puppet_control_cast.png"),
		"Koyora acquisition, full click, four-way SD companion, companion click, and Puppet Control textures should exist under the lingpet asset tree"
	)
	var koyora_cutin_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_cutin_anim_manifest.json")
	_expect(
		koyora_cutin_manifest.find("koyora_acquisition_cutin_anim") >= 0
		and koyora_cutin_manifest.find("\"frame_count\": 16") >= 0
		and koyora_cutin_manifest.find("\"cols\": 4") >= 0
		and koyora_cutin_manifest.find("\"rows\": 4") >= 0
		and koyora_cutin_manifest.find("8192") >= 0
		and koyora_cutin_manifest.find("\"whole_sheet_edge_alpha\": 0") >= 0
		and koyora_cutin_manifest.find("\"cells_with_edge_touch\": []") >= 0,
		"Koyora acquisition cut-in manifest should pin the 4x4 / 16-frame / 8192px sheet and clean-edge QA"
	)
	var koyora_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f_manifest.json")
	_expect(
		koyora_click_manifest.find("koyora_click_live2d_pingpong_98f") >= 0
		and koyora_click_manifest.find("\"frame_count\": 98") >= 0
		and koyora_click_manifest.find("\"cols\": 14") >= 0
		and koyora_click_manifest.find("\"rows\": 7") >= 0
		and koyora_click_manifest.find("\"final_whole_sheet_edge_alpha\": 0") >= 0
		and koyora_click_manifest.find("\"edge_touch_frames\": []") >= 0,
		"Koyora full click Live2D manifest should pin the 14x7 / 98-frame pingpong sheet and clean-edge QA"
	)
	var koyora_companion_idle_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_idle_manifest.json")
	var koyora_companion_move_left_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_move_left_manifest.json")
	var koyora_companion_move_right_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_move_right_manifest.json")
	var koyora_companion_strike_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_strike_manifest.json")
	var koyora_companion_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_click_reaction_98f_manifest.json")
	var koyora_puppet_control_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_puppet_control_cast_manifest.json")
	_expect(
		koyora_companion_idle_manifest.find("koyora_companion_idle_rear_25f_v1") >= 0
		and koyora_companion_move_left_manifest.find("koyora_companion_move_left_rear_3q_smooth_25f_v2") >= 0
		and koyora_companion_move_right_manifest.find("koyora_companion_move_right_rear_3q_smooth_25f_v2") >= 0
		and koyora_companion_strike_manifest.find("koyora_companion_strike_rear_only_25f_v1") >= 0
		and koyora_companion_idle_manifest.find("\"frame_count\": 25") >= 0
		and koyora_companion_move_left_manifest.find("\"frame_count\": 25") >= 0
		and koyora_companion_move_right_manifest.find("\"frame_count\": 25") >= 0
		and koyora_companion_strike_manifest.find("\"frame_count\": 25") >= 0
		and koyora_companion_idle_manifest.find("\"edge_alpha_max\": 0") >= 0
		and koyora_companion_move_left_manifest.find("\"edge_alpha_max\": 0") >= 0
		and koyora_companion_move_right_manifest.find("\"edge_alpha_max\": 0") >= 0
		and koyora_companion_strike_manifest.find("\"edge_alpha_max\": 0") >= 0,
		"Koyora SD companion manifests should pin the rear-view 5x5 / 25-frame movement and strike sheets with transparent-edge QA"
	)
	_expect(
		koyora_companion_click_manifest.find("koyora_companion_click_reaction_98f_v1") >= 0
		and koyora_companion_click_manifest.find("\"frame_count\": 98") >= 0
		and koyora_companion_click_manifest.find("\"cols\": 14") >= 0
		and koyora_companion_click_manifest.find("\"rows\": 7") >= 0
		and koyora_companion_click_manifest.find("\"cell_size\": [") >= 0
		and koyora_companion_click_manifest.find("128") >= 0
		and koyora_companion_click_manifest.find("\"edge_touch_frames\": []") >= 0,
		"Koyora companion click manifest should pin the 14x7 / 98-frame / 128px runtime sheet and clean-edge QA"
	)
	_expect(
		koyora_puppet_control_manifest.find("koyora_puppet_control_cast_original_idle_big_two_arm_v3") >= 0
		and koyora_puppet_control_manifest.find("koyora_companion_idle.png") >= 0
		and koyora_puppet_control_manifest.find("\"new_attack_strings_drawn\": false") >= 0
		and koyora_puppet_control_manifest.find("visible_motion_tuning") >= 0
		and koyora_puppet_control_manifest.find("\"frame_count\": 25") >= 0
		and koyora_puppet_control_manifest.find("\"cols\": 5") >= 0
		and koyora_puppet_control_manifest.find("\"rows\": 5") >= 0
		and koyora_puppet_control_manifest.find("\"edge_alpha_max\": 0") >= 0
		and koyora_puppet_control_manifest.find("\"edge_touch_frames\": []") >= 0,
		"Koyora Puppet Control manifest should pin the original-idle-derived 5x5 / 25-frame arm-thrust and pull-in sheet with clean-edge QA"
	)
	_expect(
		LingpetCatalog.get_visual_path("rabi", "cutin_anim") == "res://assets/sprites/lingpet/rabi_cutin_anim_sd_identity_32f_hq_clean.png",
		"Rabi F7 acquisition cut-in should use the cleaned SD-identity 32-frame HQ sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("rabi", "cutin_art") == "res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png",
		"Rabi static Live2D source art should use the cleaned SD-identity redesign with side ear-wing appendages"
	)
	_expect(
		LingpetCatalog.get_visual_path("rabi", "click_reaction_anim") == "res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f.png"
		and LingpetCatalog.get_visual_path("rabi", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/rabi_companion_click_reaction_98f.png",
		"Rabi click-reaction visuals should use dedicated full-size and companion-scale SD-identity sheets"
	)
	_expect(
		LingpetCatalog.get_visual_path("rabi", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f.png",
		"Rabi acquisition click-dismiss cut-in should route to the full-size 98-frame click Live2D sheet"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("rabi", "cutin_dismiss_seconds", 0.0), 3.35)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("rabi", "cutin_dismiss_action_portion", 0.0), 0.92)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("rabi", "cutin_dismiss_fade_start", 0.0), 0.82),
		"Rabi acquisition click-dismiss should slow the 98-frame Live2D sheet to roughly 32fps before fade-out"
	)
	_expect(
		LingpetCatalog.get_visual_path("rabi", "companion_walk") == "res://assets/sprites/lingpet/rabi_companion_walk.png"
		and LingpetCatalog.get_visual_path("rabi", "companion_strike") == "res://assets/sprites/lingpet/rabi_companion_walk.png"
		and LingpetCatalog.get_visual_path("rabi", "companion_cast") == "res://assets/sprites/lingpet/rabi_companion_walk.png",
		"Rabi F7 runtime companion visuals should use the dedicated SD float loop instead of Maribo placeholders"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/rabi_cutin_anim_sd_identity_32f_hq_clean.png"),
		"Rabi cleaned SD-identity 32-frame acquisition cut-in HQ texture should exist under the lingpet asset tree"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rabi_companion_click_reaction_98f.png"),
		"Rabi dedicated click-reaction textures should exist under the lingpet asset tree"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/rabi_companion_walk.png"),
		"Rabi in-game SD companion texture should exist under the lingpet asset tree"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v2_magenta_source.png"),
		"Rabi cleaned SD-identity Live2D source art should ship while preserving the original chroma-key source"
	)
	var rabi_cutin_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_cutin_anim_sd_identity_32f_hq_manifest.json")
	_expect(
		rabi_cutin_manifest.find("rabi_acquisition_cutin_anim_sd_identity_32f_hq") >= 0
		and rabi_cutin_manifest.find("\"frame_count\": 32") >= 0
		and rabi_cutin_manifest.find("\"cols\": 6") >= 0
		and rabi_cutin_manifest.find("\"rows\": 6") >= 0
		and rabi_cutin_manifest.find("\"sheet_size\": [") >= 0
		and rabi_cutin_manifest.find("6144") >= 0
		and rabi_cutin_manifest.find("rabi_live2d_source_sd_identity_v2") >= 0
		and rabi_cutin_manifest.find("cmq2f0zrf003jgpobw2whfb8q") >= 0
		and rabi_cutin_manifest.find("Real-ESRGAN x4") >= 0,
		"Rabi SD-identity 32-frame acquisition cut-in manifest should pin the source art, AutoSprite provenance, grid, frame count, and HQ upscale process"
	)
	var rabi_clean_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_live2d_edge_clean_v3_manifest.json")
	_expect(
		rabi_clean_manifest.find("rabi_live2d_component_clean_v3") >= 0
		and rabi_clean_manifest.find("connected dark component cleanup") >= 0
		and rabi_clean_manifest.find("rabi_cutin_art_sd_identity_v3_clean.png") >= 0
		and rabi_clean_manifest.find("rabi_cutin_anim_sd_identity_32f_hq_clean.png") >= 0
		and rabi_clean_manifest.find("removed_connected_dark_pixels") >= 0,
		"Rabi cleaned Live2D manifest should pin the connected dark-matte cleanup and output assets"
	)
	var rabi_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f_manifest.json")
	_expect(
		rabi_click_manifest.find("rabi_click_live2d_pingpong_98f") >= 0
		and rabi_click_manifest.find("\"frame_count\": 98") >= 0
		and rabi_click_manifest.find("\"cols\": 14") >= 0
		and rabi_click_manifest.find("\"rows\": 7") >= 0
		and rabi_click_manifest.find("1152") >= 0
		and rabi_click_manifest.find("rabi_live2d_source_sd_identity_v2") >= 0
		and rabi_click_manifest.find("cmq2fjhpg001qmilhiurs1b87") >= 0
		and rabi_click_manifest.find("Real-ESRGAN x4") >= 0
		and rabi_click_manifest.find("\"final_whole_sheet_edge_alpha\": 0") >= 0
		and rabi_click_manifest.find("face_nukki_cleanup") >= 0
		and rabi_click_manifest.find("removed_dark_matte_components") >= 0
		and rabi_click_manifest.find("edge_inpainted_pixels") >= 0
		and rabi_click_manifest.find("opaque eye and mouth line art preserved") >= 0
		and rabi_click_manifest.find("face_nukki_cleanup_v4") >= 0
		and rabi_click_manifest.find("removed_side_cavity_pixels_after_dilation") >= 0
		and rabi_click_manifest.find("face-side cavities") >= 0
		and rabi_click_manifest.find("central gold collar line art preserved") >= 0,
		"Rabi 98-frame click Live2D manifest should pin the SD source, AutoSprite provenance, 14x7 grid, HQ upscale, edge cleanup, and v4 face-side matte cleanup"
	)
	var rabi_companion_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_companion_click_reaction_98f_manifest.json")
	_expect(
		rabi_companion_click_manifest.find("rabi_companion_click_reaction_98f") >= 0
		and rabi_companion_click_manifest.find("\"frame_count\": 98") >= 0
		and rabi_companion_click_manifest.find("\"cols\": 14") >= 0
		and rabi_companion_click_manifest.find("\"rows\": 7") >= 0
		and rabi_companion_click_manifest.find("128") >= 0
		and rabi_companion_click_manifest.find("cmq2fjhpg001qmilhiurs1b87") >= 0
		and rabi_companion_click_manifest.find("source_face_nukki_cleanup") >= 0
		and rabi_companion_click_manifest.find("face_nukki_clean_v4") >= 0
		and rabi_companion_click_manifest.find("source_face_nukki_cleanup_v4") >= 0,
		"Rabi companion click-reaction manifest should pin the 98-frame downscaled runtime sheet contract and inherit the v4 face matte cleanup"
	)
	var rabi_companion_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_companion_walk_manifest.json")
	_expect(
		rabi_companion_manifest.find("rabi_companion_earwing_flight_autosprite_composite_v1") >= 0
		and rabi_companion_manifest.find("\"frame_count\": 25") >= 0
		and rabi_companion_manifest.find("\"cols\": 5") >= 0
		and rabi_companion_manifest.find("\"rows\": 5") >= 0
		and rabi_companion_manifest.find("640") >= 0
		and rabi_companion_manifest.find("cmq2wmlre00n1c7cq9ghln0vw") >= 0
		and rabi_companion_manifest.find("cmq36fa15001tvnk0c7c3j0v4") >= 0
		and rabi_companion_manifest.find("wf_348f008d-f2d7-4d3c-b648-c2f2bdce7aad") >= 0
		and rabi_companion_manifest.find("safe_content_size") >= 0
		and rabi_companion_manifest.find("right face edge") >= 0
		and rabi_companion_manifest.find("left face edge") >= 0
		and rabi_companion_manifest.find("ear-like side appendages are the wings") >= 0
		and rabi_companion_manifest.find("flap up/down") >= 0,
		"Rabi in-game SD companion manifest should pin the composite AutoSprite ear-wing flight sheet, 5x5 grid, face-direction contract, and ear-wing flap contract"
	)
	_expect(
		rabi_companion_manifest.find("\"edge_alpha_max\": 0") >= 0
		and rabi_companion_manifest.find("\"visible_magenta_pixels\": 0") >= 0
		and rabi_companion_manifest.find("\"visible_green_pixels\": 0") >= 0
		and rabi_companion_manifest.find("\"edge_touch_frames\": []") >= 0,
		"Rabi companion movement sheet should pin transparent-edge and chroma cleanup QA"
	)
	_expect(
		rabi_companion_manifest.find("wf_45c14cc7-caec-4394-aa7d-cf30c732acb5") >= 0
		and rabi_companion_manifest.find("wf_5ba7c58e-ffd5-4923-aac7-737b4e8dad64") >= 0
		and rabi_companion_manifest.find("wf_92860a58-8090-42f8-8ac2-228e5e6186e1") >= 0,
		"Rabi companion manifest should document rejected AutoSprite attempts that were too front-facing, rotating, or broken"
	)
	var companion_context_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
	var companion_renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	_expect(
		companion_context_source.find("\"pet_id\": _get_pet_id(current_profile)") < 0
		and companion_renderer_source.find("_draw_directional_face_hint") < 0
		and companion_context_source.find("companion_idle") >= 0
		and companion_context_source.find("companion_move_left") >= 0
		and companion_context_source.find("companion_move_right") >= 0
		and companion_renderer_source.find("face_left") >= 0,
		"Companion movement face should come from the sheet itself when available, while the renderer keeps the standard left/right mirror fallback"
	)
	var rabi_source_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v2_manifest.json")
	_expect(
		rabi_source_manifest.find("rabi_live2d_source_sd_identity_v2") >= 0
		and rabi_source_manifest.find("large ear-like side appendages") >= 0
		and rabi_source_manifest.find("\"visible_magenta_pixels\": 0") >= 0
		and rabi_source_manifest.find("\"edge_alpha_max\": 0") >= 0,
		"Rabi SD-identity Live2D source manifest should pin the ear-wing identity locks and alpha cleanup QA"
	)
	var cutin_host_source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(
		cutin_host_source.find("\"rabi\": 6") >= 0
		and cutin_host_source.find("\"rabi\": 32,") >= 0
		and cutin_host_source.find("\"rabi\": 32.0") >= 0,
		"Rabi acquisition cut-in should register 6x6 / 32-frame / 32fps playback overrides"
	)
	_expect(
		cutin_host_source.find("CUTIN_DISMISS_COLS_OVERRIDES") >= 0
		and cutin_host_source.find("\"rabi\": 14") >= 0
		and cutin_host_source.find("\"rabi\": 7") >= 0
		and cutin_host_source.find("\"rabi\": 98") >= 0,
		"Rabi acquisition click-dismiss cut-in should register 14x7 / 98-frame playback overrides"
	)
	_expect(
		cutin_host_source.find("CUTIN_DISMISS_COLS_OVERRIDES") >= 0
		and cutin_host_source.find("\"koyora\": 14") >= 0
		and cutin_host_source.find("\"koyora\": 7") >= 0
		and cutin_host_source.find("\"koyora\": 98") >= 0,
		"Koyora acquisition dismiss should register its current 14x7/98 medium-res dismiss sheet contract"
	)
	_expect(
		cutin_host_source.find("CUTIN_DISMISS_COLS_OVERRIDES") >= 0
		and cutin_host_source.find("\"nekuring\": 14") >= 0
		and cutin_host_source.find("\"nekuring\": 7") >= 0
		and cutin_host_source.find("\"nekuring\": 98") >= 0,
		"Nekuring acquisition dismiss should register its current 14x7/98 medium-res dismiss sheet contract"
	)
	_expect(LingpetCatalog.get_display_name("nekuring") == "네쿠링", "Nekuring catalog display name should use the accepted Korean name")
	_expect(
		LingpetCatalog.get_visual_path("nekuring", "cutin_art") == "res://assets/sprites/lingpet/nekuring_cutin_art.png"
		and LingpetCatalog.get_visual_path("nekuring", "cutin_anim") == "res://assets/sprites/lingpet/nekuring_cutin_anim.png"
		and LingpetCatalog.get_visual_path("nekuring", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/nekuring_cutin_dismiss_anim.png"
		and LingpetCatalog.get_visual_path("nekuring", "click_reaction_anim") == "res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f.png",
		"Nekuring acquisition cut-in should use the accepted static + 4x4 loop, a dedicated capped dismiss sheet, and the full-res 98-frame click sheet (dismiss decoupled 2026-06-21)"
	)
	_expect(
		LingpetCatalog.get_visual_path("nekuring", "companion_idle") == "res://assets/sprites/lingpet/nekuring_companion_idle.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_move_left") == "res://assets/sprites/lingpet/nekuring_companion_move_left.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_move_right") == "res://assets/sprites/lingpet/nekuring_companion_move_right.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_walk") == "res://assets/sprites/lingpet/nekuring_companion_idle.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_strike") == "res://assets/sprites/lingpet/nekuring_companion_strike.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_cast") == "res://assets/sprites/lingpet/nekuring_companion_idle.png"
		and LingpetCatalog.get_visual_path("nekuring", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/nekuring_companion_click_reaction_98f.png",
		"Nekuring debug companion should use the ringpart-matched idle SD sheet, dedicated movement and strike sheets, and downscaled click-reaction sheet"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_cutin_art.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_cutin_art_magenta_source.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_cutin_anim.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_click_reaction_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_idle.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_walk.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_move_left.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_move_right.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_strike.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/nekuring_companion_rear_source.png"),
		"Nekuring source, acquisition, full click, companion click, idle, fallback, movement, and strike SD companion textures should exist under the lingpet asset tree"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "cutin_anim_view_h_ratio", 0.0), 0.56)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "cutin_dismiss_view_h_ratio", 0.0), 0.56)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "cutin_dismiss_seconds", 0.0), 3.75)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "cutin_dismiss_action_portion", 0.0), 0.90)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "cutin_dismiss_fade_start", 0.0), 0.82)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("nekuring", "click_reaction_draw_size", 0.0), 73.6),
		"Nekuring acquisition and companion Live2D should keep the accepted smaller scale while using the original fast click timing"
	)
	var nekuring_active_pool := LingpetCatalog.get_active_skill_pool("nekuring")
	_expect(not _active_pool_has(nekuring_active_pool, "nekuring_ghost_summon"), "Nekuring debug loadout should not expose removed 해골소환")
	_expect(_active_pool_has(nekuring_active_pool, "nekuring_skeleton_archer"), "Nekuring debug loadout should expose 해골궁수")
	_expect(_active_pool_has(nekuring_active_pool, "nekuring_bone_barrier"), "Nekuring debug loadout should expose Bone Barrier")
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("nekuring_ghost_summon") == "",
		"Nekuring 해골소환 should be removed from active skill routing"
	)
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("nekuring_skeleton_archer") == "skeleton_archer",
		"Nekuring 해골궁수 should route through the Skeleton Archer runtime"
	)
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("nekuring_bone_barrier") == "bone_barrier",
		"Nekuring Bone Barrier should route through the Bone Barrier runtime"
	)
	var nekuring_cutin_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_cutin_anim_manifest.json")
	var nekuring_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f_manifest.json")
	var nekuring_companion_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_companion_click_reaction_98f_manifest.json")
	var nekuring_companion_idle_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_companion_idle_manifest.json")
	var nekuring_companion_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_companion_walk_manifest.json")
	var nekuring_companion_move_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_companion_move_pair_manifest.json")
	var nekuring_companion_strike_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_companion_strike_manifest.json")
	var nekuring_art_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/nekuring_cutin_art_manifest.json")
	_expect(
		nekuring_art_manifest.find("nekuring_cutin_art_imagegen_v1") >= 0
		and nekuring_art_manifest.find("manual hard key") >= 0
		and nekuring_art_manifest.find("\"whole_image_edge_alpha\": 0") >= 0,
		"Nekuring source-art manifest should pin the hard-key alpha cleanup and clean-edge QA"
	)
	_expect(
		nekuring_cutin_manifest.find("nekuring_acquisition_cutin_anim_v1") >= 0
		and nekuring_cutin_manifest.find("\"frame_count\": 16") >= 0
		and nekuring_cutin_manifest.find("\"cols\": 4") >= 0
		and nekuring_cutin_manifest.find("\"rows\": 4") >= 0
		and nekuring_cutin_manifest.find("\"realesrgan_upscale\"") >= 0
		and nekuring_cutin_manifest.find("\"final_cell_size\": [") >= 0
		and nekuring_cutin_manifest.find("1024") >= 0
		and nekuring_cutin_manifest.find("\"whole_sheet_edge_alpha\": 0") >= 0
		and nekuring_cutin_manifest.find("\"cells_with_edge_touch\": []") >= 0,
		"Nekuring acquisition cut-in manifest should pin the 4x4 / 16-frame HQ sheet and clean-edge QA"
	)
	_expect(
		nekuring_click_manifest.find("nekuring_click_live2d_pingpong_98f_v1") >= 0
		and nekuring_click_manifest.find("\"frame_count\": 98") >= 0
		and nekuring_click_manifest.find("\"cols\": 14") >= 0
		and nekuring_click_manifest.find("\"rows\": 7") >= 0
		and nekuring_click_manifest.find("\"source_scale_repack\": 0.84") >= 0
		and nekuring_click_manifest.find("\"realesrgan_upscale\"") >= 0
		and nekuring_click_manifest.find("\"final_cell_size\": [") >= 0
		and nekuring_click_manifest.find("1152") >= 0
		and nekuring_click_manifest.find("\"final_whole_sheet_edge_alpha\": 0") >= 0
		and nekuring_click_manifest.find("\"final_cells_with_edge_touch\": []") >= 0,
		"Nekuring full click Live2D manifest should pin the 14x7 / 98-frame HQ pingpong sheet and clean-edge QA"
	)
	_expect(
		nekuring_companion_click_manifest.find("nekuring_companion_click_reaction_98f_v1") >= 0
		and nekuring_companion_click_manifest.find("\"frame_count\": 98") >= 0
		and nekuring_companion_click_manifest.find("\"cols\": 14") >= 0
		and nekuring_companion_click_manifest.find("\"rows\": 7") >= 0
		and nekuring_companion_click_manifest.find("\"cell_size\": [") >= 0
		and nekuring_companion_click_manifest.find("128") >= 0
		and nekuring_companion_click_manifest.find("\"final_cells_with_edge_touch\": []") >= 0,
		"Nekuring companion click manifest should pin the downscaled 14x7 / 98-frame / 128px sheet and clean-edge QA"
	)
	_expect(
		nekuring_companion_manifest.find("nekuring_companion_rear_idle_25f_v1") >= 0
		and nekuring_companion_manifest.find("cmq748y50004ne7iexc9ebie9") >= 0
		and nekuring_companion_manifest.find("cmq74axve004elccrs0m8gxdh") >= 0
		and nekuring_companion_manifest.find("\"frame_count\": 25") >= 0
		and nekuring_companion_manifest.find("\"cols\": 5") >= 0
		and nekuring_companion_manifest.find("\"rows\": 5") >= 0
		and nekuring_companion_manifest.find("256") >= 0
		and nekuring_companion_manifest.find("\"edge_alpha_max\": 0") >= 0
		and nekuring_companion_manifest.find("\"edge_touch_frames\": []") >= 0
		and nekuring_companion_manifest.find("\"visible_background_green_pixels\": 0") >= 0,
		"Nekuring rear-view SD companion manifest should pin the 5x5 / 25-frame AutoSprite sheet and clean-edge QA"
	)
	_expect(
		nekuring_companion_idle_manifest.find("nekuring_companion_idle_ringparts_25f_v1") >= 0
		and nekuring_companion_idle_manifest.find("cmq77h3fv005uocu4groreo2c") >= 0
		and nekuring_companion_idle_manifest.find("wf_4ca8ff92-657c-4a80-aa8a-465a969085a0") >= 0
		and nekuring_companion_idle_manifest.find("cmq77ixc10068ocu4ahtned1b") >= 0
		and nekuring_companion_idle_manifest.find("\"source_frame_index\": 12") >= 0
		and nekuring_companion_idle_manifest.find("\"frame_count\": 25") >= 0
		and nekuring_companion_idle_manifest.find("\"cols\": 5") >= 0
		and nekuring_companion_idle_manifest.find("\"rows\": 5") >= 0
		and nekuring_companion_idle_manifest.find("\"edge_alpha_max\": 0") >= 0
		and nekuring_companion_idle_manifest.find("\"edge_touch_frames\": []") >= 0
		and nekuring_companion_idle_manifest.find("\"visible_green_pixels\": 0") >= 0,
		"Nekuring idle manifest should pin the ringpart-matched idle source and clean-edge QA"
	)
	_expect(
		nekuring_companion_move_manifest.find("nekuring_companion_rear_3q_move_pair_25f_v1") >= 0
		and nekuring_companion_move_manifest.find("cmq75rk81000914hjk6cryb81") >= 0
		and nekuring_companion_move_manifest.find("wf_fd50f148-cc91-46ab-8904-a07da3c56c10") >= 0
		and nekuring_companion_move_manifest.find("\"accepted_kind\": \"iso_walk_northeast\"") >= 0
		and nekuring_companion_move_manifest.find("\"companion_move_left\"") >= 0
		and nekuring_companion_move_manifest.find("\"companion_move_right\"") >= 0
		and nekuring_companion_move_manifest.find("\"frame_count\": 25") >= 0
		and nekuring_companion_move_manifest.find("\"cols\": 5") >= 0
		and nekuring_companion_move_manifest.find("\"rows\": 5") >= 0
		and nekuring_companion_move_manifest.find("\"edge_alpha_max\": 0") >= 0
		and nekuring_companion_move_manifest.find("\"edge_touch_frames\": []") >= 0
		and nekuring_companion_move_manifest.find("\"visible_green_pixels\": 0") >= 0,
		"Nekuring rear-3/4 movement manifest should pin the accepted AutoSprite sheet, mirrored left sheet, and clean-edge QA"
	)
	_expect(
		nekuring_companion_strike_manifest.find("nekuring_companion_strike_rear_staff_25f_v1") >= 0
		and nekuring_companion_strike_manifest.find("cmq77h3fv005uocu4groreo2c") >= 0
		and nekuring_companion_strike_manifest.find("wf_e7de6e2b-f675-4690-bda8-19033f908f29") >= 0
		and nekuring_companion_strike_manifest.find("cmqbeitp2001pv3js5m9m7sd4") >= 0
		and nekuring_companion_strike_manifest.find("\"runtime_active_frames\": [") >= 0
		and nekuring_companion_strike_manifest.find("\"frame_count\": 25") >= 0
		and nekuring_companion_strike_manifest.find("\"cols\": 5") >= 0
		and nekuring_companion_strike_manifest.find("\"rows\": 5") >= 0
		and nekuring_companion_strike_manifest.find("\"edge_alpha_max\": 0") >= 0
		and nekuring_companion_strike_manifest.find("\"edge_touch_frames\": []") >= 0
		and nekuring_companion_strike_manifest.find("\"visible_green_pixels\": 0") >= 0,
		"Nekuring strike manifest should pin the AutoSprite rear staff-strike remap and clean-edge QA"
	)
	_expect(modal_gate.is_lingpet_debug_picker_open(Callable(registry, "get_instance")), "modal gate should see the open lingpet picker")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "open lingpet picker should block battle physics")
	_expect(owner.redraws == 1, "opening lingpet debug should request one redraw")
	_cleanup_debug_fixture(picker, runtime, registry)


func _verify_skill_rows_never_overlap_apply_button() -> void:
	# The shared passive pool grows over time, so the skill section height and row
	# pitch are derived at draw time. Lock the invariant that no skill row ever
	# collides with the apply button, both on a roomy view and on a short view that
	# forces the rows to compact. This is the regression that left passive rows
	# rendering on top of the "적용" button once the pool passed three entries.
	var picker := LingpetDebugPicker.new()
	var owner := FakeOwner.new()
	picker.toggle(owner)
	for view_size in [Vector2(1280.0, 720.0), Vector2(760.0, 620.0), Vector2(760.0, 750.0)]:
		var apply_rect: Rect2 = picker.get_apply_button_rect_for_tests(view_size)
		var passive_count := _count_passive_skills(picker)
		_expect(passive_count >= 4, "shared passive pool should have grown past the old 3-row section budget")
		for index in range(passive_count):
			var row_rect: Rect2 = picker.get_passive_skill_rect_for_tests(index, view_size)
			_expect(
				not apply_rect.intersects(row_rect),
				"passive skill row %d should not overlap the apply button at view %s" % [index, view_size]
			)
			_expect(
				row_rect.end.y <= apply_rect.position.y + 0.5,
				"passive skill row %d should sit above the apply button at view %s" % [index, view_size]
			)
		for index in range(_count_active_skills(picker)):
			var active_rect: Rect2 = picker.get_active_skill_rect_for_tests(index, view_size)
			_expect(
				not apply_rect.intersects(active_rect),
				"active skill row %d should not overlap the apply button at view %s" % [index, view_size]
			)
	_cleanup_debug_fixture(picker)


func _count_passive_skills(picker: Object) -> int:
	var count := 0
	for index in range(32):
		if str(picker.get_passive_skill_id_for_tests(index)) == "":
			break
		count += 1
	return count


func _count_active_skills(picker: Object) -> int:
	var count := 0
	for index in range(32):
		if str(picker.get_active_skill_id_for_tests(index)) == "":
			break
		count += 1
	return count


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
	_cleanup_debug_fixture(picker, runtime, registry)


func _verify_debug_picker_can_select_koyora_doll_curse() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"game_audio": FakeAudio.new(),
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var view_size := owner.get_viewport_rect().size
	picker.toggle(owner)
	var koyora_index := _find_pet_index(picker, "koyora")
	_expect(koyora_index >= 0, "F7 picker should list Koyora before selecting Doll Curse")
	if koyora_index < 0:
		_cleanup_debug_fixture(picker, runtime, registry)
		return
	var card_rect := picker.get_card_rect_for_tests(koyora_index, view_size)
	var handled := bool(picker.handle_input(_mouse_click(card_rect.position + card_rect.size * 0.5), owner, registry, view_size))
	_expect(handled, "clicking the Koyora card should be handled")
	_expect(picker.get_selected_pet_id_for_tests() == "koyora", "Koyora card click should switch the F7 skill loadout panel to Koyora")
	_expect(picker.get_active_skill_id_for_tests() == "koyora_puppet_control", "Koyora should still default to Puppet Control before selecting the second active")
	var doll_curse_index := _find_active_skill_index(picker, "koyora_doll_curse")
	_expect(doll_curse_index >= 0, "Koyora Doll Curse should be listed as a selectable F7 active skill row")
	if doll_curse_index < 0:
		_cleanup_debug_fixture(picker, runtime, registry)
		return
	var skill_rect := picker.get_active_skill_rect_for_tests(doll_curse_index, view_size)
	handled = bool(picker.handle_input(_mouse_click(skill_rect.position + skill_rect.size * 0.5), owner, registry, view_size))
	_expect(handled, "clicking Koyora Doll Curse active row should be handled")
	_expect(picker.get_active_skill_id_for_tests() == "koyora_doll_curse", "clicked Koyora Doll Curse row should become the selected F7 loadout skill")
	var apply_rect := picker.get_apply_button_rect_for_tests(view_size)
	handled = bool(picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size))
	_expect(handled, "applying Koyora Doll Curse through F7 should be handled")
	_expect(not picker.is_open(), "applying Koyora Doll Curse should close the F7 picker")
	_expect(owner.active_lingpet_id == "koyora", "F7 apply should activate Koyora after selecting Doll Curse")
	_expect(owner.lingpet_active_skill_id == "koyora_doll_curse", "F7 apply should persist Koyora Doll Curse as the active skill")
	var loadout: Dictionary = owner.lingpet_loadouts.get("koyora", {})
	_expect(str(loadout.get("active_skill_id", "")) == "koyora_doll_curse", "stored Koyora F7 loadout should include Doll Curse")
	_expect(str(loadout.get("passive_skill_id", "")) == "lingpet_resonance_boost", "stored Koyora F7 loadout should retain the default Resonance Boost passive")
	_cleanup_debug_fixture(picker, runtime, registry)


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
	_cleanup_debug_fixture(null, null, registry)


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
	var rabi_runtime := LingpetEggRuntime.new()
	var rabi_owner := FakeOwner.new()
	_expect(rabi_runtime.debug_grant_and_activate_pet("rabi", rabi_owner, false, "rabi_ghost_summon", "lingpet_resonance_boost"), "debug grant should accept debug-only Rabi")
	_expect(rabi_owner.active_lingpet_id == "rabi", "debug-only Rabi should activate when granted through the F7 debug path")
	_expect(rabi_owner.lingpet_active_skill_id == "rabi_ghost_summon", "debug-only Rabi should persist its ghost summon active skill")
	var koyora_runtime := LingpetEggRuntime.new()
	var koyora_owner := FakeOwner.new()
	_expect(koyora_runtime.debug_grant_and_activate_pet("koyora", koyora_owner, false, "koyora_puppet_control", "lingpet_resonance_boost"), "debug grant should accept debug-only Koyora")
	_expect(koyora_owner.active_lingpet_id == "koyora", "debug-only Koyora should activate when granted through the F7 debug path")
	_expect(koyora_owner.lingpet_active_skill_id == "koyora_puppet_control", "debug-only Koyora should persist its 꼭두각시 조종 active skill")
	var koyora_doll_runtime := LingpetEggRuntime.new()
	var koyora_doll_owner := FakeOwner.new()
	_expect(koyora_doll_runtime.debug_grant_and_activate_pet("koyora", koyora_doll_owner, false, "koyora_doll_curse", "lingpet_resonance_boost"), "debug grant should accept Koyora Doll Curse as an explicit active skill")
	_expect(koyora_doll_owner.active_lingpet_id == "koyora", "debug-only Koyora should activate when granted with Doll Curse")
	_expect(koyora_doll_owner.lingpet_active_skill_id == "koyora_doll_curse", "debug-only Koyora should persist Doll Curse as its explicit active skill")
	var koyora_doll_loadout: Dictionary = koyora_doll_owner.lingpet_loadouts.get("koyora", {})
	_expect(str(koyora_doll_loadout.get("active_skill_id", "")) == "koyora_doll_curse", "explicit Koyora Doll Curse debug grant should persist active skill in loadouts")
	var nekuring_runtime := LingpetEggRuntime.new()
	var nekuring_owner := FakeOwner.new()
	_expect(nekuring_runtime.debug_grant_and_activate_pet("nekuring", nekuring_owner, false, "nekuring_ghost_summon", "lingpet_resonance_boost"), "debug grant should keep Nekuring activatable even if removed 해골소환 is requested")
	_expect(nekuring_owner.active_lingpet_id == "nekuring", "debug-only Nekuring should activate when granted through the F7 debug path")
	_expect(nekuring_owner.lingpet_active_skill_id != "nekuring_ghost_summon", "debug-only Nekuring should not persist removed 해골소환 as its active skill")
	var nekuring_archer_runtime := LingpetEggRuntime.new()
	var nekuring_archer_owner := FakeOwner.new()
	_expect(nekuring_archer_runtime.debug_grant_and_activate_pet("nekuring", nekuring_archer_owner, false, "nekuring_skeleton_archer", "lingpet_resonance_boost"), "debug grant should accept Nekuring Skeleton Archer as an explicit active skill")
	_expect(nekuring_archer_owner.lingpet_active_skill_id == "nekuring_skeleton_archer", "debug-only Nekuring should persist Skeleton Archer as its explicit active skill")
	var nekuring_barrier_runtime := LingpetEggRuntime.new()
	var nekuring_barrier_owner := FakeOwner.new()
	_expect(nekuring_barrier_runtime.debug_grant_and_activate_pet("nekuring", nekuring_barrier_owner, false, "nekuring_bone_barrier", "lingpet_resonance_boost"), "debug grant should accept Nekuring Bone Barrier as an explicit active skill")
	_expect(nekuring_barrier_owner.lingpet_active_skill_id == "nekuring_bone_barrier", "debug-only Nekuring should persist Bone Barrier as its explicit active skill")
	for runtime_value in [runtime, rabi_runtime, koyora_runtime, koyora_doll_runtime, nekuring_runtime, nekuring_archer_runtime, nekuring_barrier_runtime]:
		_cleanup_debug_fixture(null, runtime_value, null)


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
	_cleanup_debug_fixture(null, runtime, null)


func _verify_defense_rate_slider() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var view_size := Vector2(1280.0, 720.0)
	picker.toggle(owner)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), -1.0), "defense override should default to 기본 (off / use pet value)")

	# Right triangle (감도조절): off(-1) -> 0% -> +5% steps.
	var inc_rect: Rect2 = picker.get_defense_inc_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(inc_rect.position + inc_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), 0.0), "first ► step from 기본 should set the override to 0%")
	picker.handle_input(_mouse_click(inc_rect.position + inc_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), 0.05), "second ► step should raise the override to 5%")

	# Mouse wheel up over the slider row: +5%.
	var bar_rect: Rect2 = picker.get_defense_bar_rect_for_tests(view_size)
	picker.handle_input(_mouse_wheel(bar_rect.position + bar_rect.size * 0.5, true), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), 0.10), "mouse wheel up over the slider should step the override up")

	# Clicking the bar sets the value to that position (center -> 50%).
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), 0.5), "clicking the slider bar should set the override to the clicked position")

	# Far-left of the bar -> 0%, then one ◄ step returns to 기본 (off).
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), 0.0), "clicking the far-left of the bar should set 0%")
	var dec_rect: Rect2 = picker.get_defense_dec_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(dec_rect.position + dec_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), -1.0), "◄ stepping below 0% should return to 기본 (off)")

	# Stage 50% and apply -> committed to the runtime AND it drives the live defense rate.
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	var maribo_index := _find_pet_index(picker, "maribo")
	if maribo_index < 0:
		maribo_index = 0
	var card_rect := picker.get_card_rect_for_tests(maribo_index, view_size)
	picker.handle_input(_mouse_click(card_rect.position + card_rect.size * 0.5), owner, registry, view_size)
	var apply_rect := picker.get_apply_button_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(runtime.get_debug_defense_rate_override(), 0.5), "apply should commit the staged defense override to the lingpet runtime")
	runtime.update(0.0, owner, registry)
	_expect(is_equal_approx(float(owner.lingpet_companion_defense_rate), 0.5), "the committed override should drive the live companion defense rate, overriding Maribo's 30%")

	# Clearing the override (기본) restores the pet's catalog defense rate (0.30).
	runtime.set_debug_defense_rate_override(-1.0)
	runtime.update(0.0, owner, registry)
	_expect(is_equal_approx(float(owner.lingpet_companion_defense_rate), 0.30), "clearing the override should restore Maribo's catalog 30% defense rate")
	_cleanup_debug_fixture(picker, runtime, registry)


func _verify_flight_pet_appearance_override() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var view_size := Vector2(1280.0, 720.0)
	picker.toggle(owner)

	# Patrol pet selected -> the header slider is the defense-rate forcing control.
	var maribo_index := _find_pet_index(picker, "maribo")
	var lunabi_index := _find_pet_index(picker, "lunabi")
	_expect(maribo_index >= 0 and lunabi_index >= 0, "maribo and lunabi should both be present in the F7 picker for the override-routing case")
	if maribo_index < 0 or lunabi_index < 0:
		_cleanup_debug_fixture(picker, runtime, registry)
		return
	var maribo_rect := picker.get_card_rect_for_tests(maribo_index, view_size)
	picker.handle_input(_mouse_click(maribo_rect.position + maribo_rect.size * 0.5), owner, registry, view_size)
	_expect(picker.get_stat_override_label_for_tests() == "방어율 강제", "patrol pet should label the override slider 방어율 강제")

	# Flight pet selected -> the same slider becomes the appearance-rate (출현율) control.
	var lunabi_rect := picker.get_card_rect_for_tests(lunabi_index, view_size)
	picker.handle_input(_mouse_click(lunabi_rect.position + lunabi_rect.size * 0.5), owner, registry, view_size)
	_expect(picker.get_stat_override_label_for_tests() == "출현율 강제", "flight pet should label the override slider 출현율 강제")

	# Stage 50% and apply -> committed to the appearance channel; defense stays clear
	# (it would be a silent no-op for a flight pet).
	var bar_rect: Rect2 = picker.get_defense_bar_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	var apply_rect := picker.get_apply_button_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(runtime.get_debug_appearance_rate_override(), 0.5), "applying a flight pet should commit the staged override to the appearance-rate channel")
	_expect(is_equal_approx(runtime.get_debug_defense_rate_override(), -1.0), "applying a flight pet should leave the defense-rate channel cleared")
	runtime.update(0.0, owner, registry)
	_expect(is_equal_approx(float(owner.lingpet_companion_appearance_rate), 0.5), "the committed appearance override should drive the live companion appearance rate")
	_expect(is_equal_approx(float(owner.lingpet_companion_defense_rate), 0.0), "a flight pet should still report 0 defense rate with a staged slider value")

	# Re-applying a patrol pet routes the staged value back to defense and clears
	# the appearance channel (no cross-pet-type leak).
	picker.toggle(owner)
	maribo_rect = picker.get_card_rect_for_tests(maribo_index, view_size)
	picker.handle_input(_mouse_click(maribo_rect.position + maribo_rect.size * 0.5), owner, registry, view_size)
	apply_rect = picker.get_apply_button_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(runtime.get_debug_defense_rate_override(), 0.5), "re-applying a patrol pet should route the staged override back to the defense channel")
	_expect(is_equal_approx(runtime.get_debug_appearance_rate_override(), -1.0), "re-applying a patrol pet should clear the appearance-rate channel")
	_cleanup_debug_fixture(picker, runtime, registry)


func _verify_move_speed_slider() -> void:
	var picker := LingpetDebugPicker.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"lingpet_debug_picker": picker,
		"lingpet_egg_runtime": runtime,
	})
	var view_size := Vector2(1280.0, 720.0)
	picker.toggle(owner)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), -1.0), "move-speed override should default to 기본 (off)")

	# Stepping: off(-1) -> MIN 0.5x -> +0.25 steps, independent of the defense row.
	var inc_rect: Rect2 = picker.get_move_speed_inc_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(inc_rect.position + inc_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), 0.5), "first ► step should set the move-speed override to 0.5x")
	var bar_rect: Rect2 = picker.get_move_speed_bar_rect_for_tests(view_size)
	picker.handle_input(_mouse_wheel(bar_rect.position + bar_rect.size * 0.5, true), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), 0.75), "wheel up over the move-speed row should step to 0.75x")
	_expect(is_equal_approx(picker.get_defense_override_for_tests(), -1.0), "the move-speed row must not touch the defense slider")

	# Bar center -> 1.25x (MIN 0.5 + 0.5 * range 1.5, snapped to the 0.25 grid).
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), 1.25), "clicking the bar center should set ~1.25x")

	# ◄ below MIN returns to 기본 (off).
	var dec_rect: Rect2 = picker.get_move_speed_dec_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), 0.5), "far-left bar click should set MIN 0.5x")
	picker.handle_input(_mouse_click(dec_rect.position + dec_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(picker.get_move_speed_override_for_tests(), -1.0), "◄ below MIN should return to 기본 (off)")

	# PATROL pet apply commits the staged multiplier.
	picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
	var maribo_index := _find_pet_index(picker, "maribo")
	if maribo_index < 0:
		maribo_index = 0
	var maribo_rect := picker.get_card_rect_for_tests(maribo_index, view_size)
	picker.handle_input(_mouse_click(maribo_rect.position + maribo_rect.size * 0.5), owner, registry, view_size)
	var apply_rect := picker.get_apply_button_rect_for_tests(view_size)
	picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size)
	_expect(is_equal_approx(runtime.get_debug_move_speed_override(), 1.25), "patrol pet apply should commit the staged move-speed multiplier")

	# FLIGHT pet apply ALSO commits move-speed (no motion-style gate, unlike defense/appearance).
	var lunabi_index := _find_pet_index(picker, "lunabi")
	if lunabi_index >= 0:
		picker.toggle(owner)
		bar_rect = picker.get_move_speed_bar_rect_for_tests(view_size)
		picker.handle_input(_mouse_click(Vector2(bar_rect.position.x + bar_rect.size.x * 0.5, bar_rect.position.y + bar_rect.size.y * 0.5)), owner, registry, view_size)
		var lunabi_rect := picker.get_card_rect_for_tests(lunabi_index, view_size)
		picker.handle_input(_mouse_click(lunabi_rect.position + lunabi_rect.size * 0.5), owner, registry, view_size)
		apply_rect = picker.get_apply_button_rect_for_tests(view_size)
		picker.handle_input(_mouse_click(apply_rect.position + apply_rect.size * 0.5), owner, registry, view_size)
		_expect(is_equal_approx(runtime.get_debug_move_speed_override(), 1.25), "flight pet apply should ALSO commit move-speed (no motion-style gate)")

	# Live effect: the override scales the published patrol speed by the multiplier,
	# and clearing it restores the base speed (no gate -> works for the active pet).
	runtime.set_debug_move_speed_override(-1.0)
	runtime.update(0.0, owner, registry)
	var base_speed := float(owner.lingpet_companion_patrol_speed_default)
	runtime.set_debug_move_speed_override(1.5)
	runtime.update(0.0, owner, registry)
	var scaled_speed := float(owner.lingpet_companion_patrol_speed_default)
	_expect(base_speed > 0.0, "base patrol speed should be published before scaling")
	_expect(is_equal_approx(scaled_speed, base_speed * 1.5), "move-speed override should scale the live patrol speed by the multiplier")
	_cleanup_debug_fixture(picker, runtime, registry)


func _find_pet_index(picker: Object, pet_id: String) -> int:
	for index in range(32):
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


func _active_pool_has(pool: Array[Dictionary], skill_id: String) -> bool:
	for skill in pool:
		if str(skill.get("id", "")) == skill_id:
			return true
	return false


func _cleanup_debug_fixture(picker: Object = null, runtime: Object = null, registry: Object = null) -> void:
	if picker != null and picker.has_method("clear_for_tests"):
		picker.clear_for_tests()
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
	if registry != null and registry.has_method("clear_refs"):
		registry.clear_refs()
	ProjectResourceLoader.clear_caches()


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


func _mouse_wheel(position: Vector2, up: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.position = position
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
