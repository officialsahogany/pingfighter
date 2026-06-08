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
	_verify_acquire_cutin_overlays_stage_result_paths()
	_verify_debug_grant_accepts_explicit_skill_loadout()
	_verify_full_slots_replace_active_slot_for_debug_grant()
	_verify_defense_rate_slider()
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
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	var gate_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	_expect(input_source.find("KEY_F7") >= 0 and input_source.find("DEBUG_MENU_LINGPET_PICKER") >= 0, "overlay input should wire F7 to the lingpet debug menu")
	_expect(frame_source.find("draw.overlay.lingpet_debug") >= 0, "overlay frame controller should draw the lingpet debug menu")
	_expect(gate_source.find("is_lingpet_debug_picker_open") >= 0 and gate_source.find("physics.modal_gate.lingpet_debug") >= 0, "modal gate should expose lingpet debug as a blocking modal")


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
	_expect(_find_pet_index(picker, "koyora") >= 0, "F7 lingpet debug picker should list debug-only Koyora")
	_expect(_find_pet_index(picker, "rabi") >= 0, "F7 lingpet debug picker should list debug-only Rabi")
	_expect(LingpetCatalog.get_debug_pet_ids().has("koyora"), "Koyora should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("koyora"), "Koyora should be accepted by runtime helpers for F7 debug activation")
	_expect(not LingpetCatalog.get_pet_ids().has("koyora"), "Koyora should stay out of the enabled hatch pet id list until final runtime assets ship")
	_expect(LingpetCatalog.get_debug_pet_ids().has("rabi"), "Rabi should be included in the debug-only lingpet picker list")
	_expect(LingpetCatalog.has_pet("rabi"), "Rabi should be accepted by runtime helpers for F7 debug activation")
	_expect(not LingpetCatalog.get_pet_ids().has("rabi"), "Rabi should stay out of the enabled hatch pet id list until final runtime assets ship")
	var hatch_candidates := LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect(not hatch_candidates.has("koyora"), "Koyora should not enter the random hatch pool while it is debug-only")
	_expect(not hatch_candidates.has("rabi"), "Rabi should not enter the random hatch pool while it is debug-only")
	_expect(LingpetCatalog.get_display_name("koyora") == "코요라", "Koyora catalog display name should use the accepted Korean name")
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_art") == "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png",
		"Koyora static Live2D source art should use the accepted attached-tail puppet miko artwork"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_anim") == "res://assets/sprites/lingpet/koyora_cutin_anim.png",
		"Koyora F7 acquisition cut-in should use the 4x4 / 16-frame AutoSprite sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png"
		and LingpetCatalog.get_visual_path("koyora", "click_reaction_anim") == "res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png",
		"Koyora acquisition click-dismiss and full click reaction should route to the 98-frame full-size click Live2D sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/koyora_companion_click_reaction_98f.png",
		"Koyora in-battle companion click reaction should use the downscaled 14x7 / 128px runtime sheet"
	)
	_expect(
		LingpetCatalog.get_visual_path("koyora", "companion_walk") == "res://assets/sprites/lingpet/koyora_companion_walk.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_strike") == "res://assets/sprites/lingpet/koyora_companion_walk.png"
		and LingpetCatalog.get_visual_path("koyora", "companion_cast") == "res://assets/sprites/lingpet/koyora_companion_walk.png",
		"Koyora F7 runtime companion visuals should use the temporary 5x5 source-art hover sheet instead of cropping the fullscreen Live2D sheet"
	)
	_expect(
		is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_seconds", 0.0), 3.35)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_action_portion", 0.0), 0.92)
		and is_equal_approx(LingpetCatalog.get_visual_layout_value("koyora", "cutin_dismiss_fade_start", 0.0), 0.82),
		"Koyora acquisition click-dismiss should use the long 98-frame Live2D exit timing"
	)
	var koyora_active_pool := LingpetCatalog.get_active_skill_pool("koyora")
	_expect(_active_pool_has(koyora_active_pool, "koyora_puppet_string_orbit"), "Koyora debug loadout should expose Puppet String Orbit")
	_expect(
		LingpetCatalog.get_active_skill_runtime_kind("koyora_puppet_string_orbit") == "moon_orbit",
		"Koyora temporary debug active skill should route through the supported moon_orbit runtime"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3_magenta_source.png"),
		"Koyora source and exact-magenta source artwork should ship under the lingpet asset tree"
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/lingpet/koyora_cutin_anim.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_walk.png")
		and FileAccess.file_exists("res://assets/sprites/lingpet/koyora_companion_click_reaction_98f.png"),
		"Koyora acquisition, full click, companion walk, and companion click textures should exist under the lingpet asset tree"
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
	var koyora_companion_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_walk_manifest.json")
	var koyora_companion_click_manifest := FileAccess.get_file_as_string("res://assets/sprites/lingpet/koyora_companion_click_reaction_98f_manifest.json")
	_expect(
		koyora_companion_manifest.find("koyora_companion_static_float_25f_v1") >= 0
		and koyora_companion_manifest.find("\"frame_count\": 25") >= 0
		and koyora_companion_manifest.find("\"cols\": 5") >= 0
		and koyora_companion_manifest.find("\"rows\": 5") >= 0
		and koyora_companion_manifest.find("\"edge_alpha_max\": 0") >= 0,
		"Koyora temporary companion hover manifest should pin the 5x5 / 25-frame sheet and transparent-edge QA"
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
		and companion_renderer_source.find("face_left") >= 0,
		"Rabi companion movement face should now come from the AutoSprite sheet itself, while the renderer keeps the standard left/right mirror path"
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
		"Koyora acquisition click-dismiss cut-in should register 14x7 / 98-frame playback overrides"
	)
	_expect(modal_gate.is_lingpet_debug_picker_open(Callable(registry, "get_instance")), "modal gate should see the open lingpet picker")
	_expect(modal_gate.should_block_battle_physics(Callable(registry, "get_instance")), "open lingpet picker should block battle physics")
	_expect(owner.redraws == 1, "opening lingpet debug should request one redraw")


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
	var rabi_runtime := LingpetEggRuntime.new()
	var rabi_owner := FakeOwner.new()
	_expect(rabi_runtime.debug_grant_and_activate_pet("rabi", rabi_owner, false, "rabi_ghost_summon", "lingpet_resonance_boost"), "debug grant should accept debug-only Rabi")
	_expect(rabi_owner.active_lingpet_id == "rabi", "debug-only Rabi should activate when granted through the F7 debug path")
	_expect(rabi_owner.lingpet_active_skill_id == "rabi_ghost_summon", "debug-only Rabi should persist its ghost summon active skill")
	var koyora_runtime := LingpetEggRuntime.new()
	var koyora_owner := FakeOwner.new()
	_expect(koyora_runtime.debug_grant_and_activate_pet("koyora", koyora_owner, false, "koyora_puppet_string_orbit", "lingpet_resonance_boost"), "debug grant should accept debug-only Koyora")
	_expect(koyora_owner.active_lingpet_id == "koyora", "debug-only Koyora should activate when granted through the F7 debug path")
	_expect(koyora_owner.lingpet_active_skill_id == "koyora_puppet_string_orbit", "debug-only Koyora should persist its puppet-string active skill")


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
