extends SceneTree

# Windowed Vulkan evidence harness for the stowed-guardian TAB contract.
# Run from godot/ without --headless:
#   Godot..._console.exe --path . --rendering-method mobile \
#     -s res://tools/character_info_lingpet_stowed_capture.gd

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const VIEW_SIZE := Vector2i(1264, 964)
const OUT_ROOT := "C:/Users/woduq/bosspong_backups/qa_evidence"


class PermissiveOwner:
	extends RefCounted

	var fields: Dictionary = {}

	func _init(initial: Dictionary) -> void:
		fields = initial.duplicate(true)

	func _get(property: StringName) -> Variant:
		return fields.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		fields[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class RegistryStub:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		return modules.get(key, null)


class OverlayCanvas:
	extends Node2D

	var overlay: Object
	var owner_ref: Object
	var registry_ref: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.07, 0.09, 0.14))
		overlay.draw(self, owner_ref, registry_ref, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("character_info_lingpet_stowed_capture requires a windowed display server")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("character_info_lingpet_stowed_capture requires the Vulkan mobile renderer")
		quit(1)
		return
	LanguageSettings.set_test_locale_override("ko")
	var owner := PermissiveOwner.new({
		"ai_mode": "junior league",
		"selected_character_type": "smasher",
		"special_gauge": 120.0,
		"special_gauge_max": 500.0,
		"player_paddle_width": 155.0,
		"active_item_slots": [],
		"show_character_info": true,
		"lingpet_owned_pet_ids": ["maribo"],
		"owned_lingpet_ids": ["maribo"],
		"owned_ringpet_ids": ["maribo"],
		"lingpet_slots": ["maribo", "", ""],
		"ringpet_slots": ["maribo", "", ""],
		"lingpet_slot_pet_ids": ["maribo", "", ""],
		"ringpet_slot_pet_ids": ["maribo", "", ""],
		"lingpet_active_slot_index": 0,
		"ringpet_active_slot_index": 0,
	})
	var runtime: Object = LingpetEggRuntime.new()
	var registry := RegistryStub.new()
	registry.modules = {
		"lingpet_egg_runtime": runtime,
		"runtime_perk_state": RuntimePerkState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_icon_renderer": RuntimePerkIconRenderer.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
	}
	if not runtime.debug_grant_and_activate_pet(
		"maribo",
		owner,
		false,
		"maribo_hydro_sphere",
		"lingpet_resonance_boost",
		registry,
		3,
		4,
		"",
		"lingpet_afterglow_leak",
		0,
		5
	):
		push_error("failed to activate the capture guardian")
		quit(1)
		return
	runtime.add_affinity_points("hatch", {}, registry)
	runtime.update(6.1, owner, registry)
	runtime.set_duration_pool_for_tests(30.0, 60.0)
	if not runtime.try_toggle_guardian_stow(owner, registry) or not runtime.is_guardian_stowed():
		push_error("failed to enter the real stowed runtime path")
		quit(1)
		return
	var panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(panel_snapshot, runtime.get_snapshot())
	if (
		str(panel_snapshot.get("subtitle", "")) != "수납 중"
		or int(panel_snapshot.get("companion_skill_level", 0)) != 3
		or int(panel_snapshot.get("companion_passive_skill_level", 0)) != 4
		or float(panel_snapshot.get("companion_defense_rate", 0.0)) <= 0.0
		or float(panel_snapshot.get("affinity_next_requirement", 0.0)) <= 0.0
	):
		push_error("capture fixture did not preserve the stowed TAB display contract")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var overlay: Object = CharacterInfoOverlay.new()
	overlay.prewarm_assets(owner, registry, Callable(), true, Vector2(VIEW_SIZE), ["maribo"])
	var prewarm_guard := 0
	while not overlay.prewarm_lingpet_panel_assets_step(["maribo"]) and prewarm_guard < 400:
		prewarm_guard += 1
	overlay.set("active", true)
	overlay.set("animation_time", 10.0)
	var canvas := OverlayCanvas.new()
	canvas.overlay = overlay
	canvas.owner_ref = owner
	canvas.registry_ref = registry
	viewport.add_child(canvas)
	for _frame in range(8):
		canvas.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var out_dir := "%s/lingpet_guardian_round2_%d_%d" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id()]
	var mkdir_error := DirAccess.make_dir_recursive_absolute(out_dir)
	var output_path := "%s/stowed_tab.png" % out_dir
	if mkdir_error != OK or image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("failed to save the stowed TAB evidence image")
		quit(1)
		return
	print("character_info_lingpet_stowed_capture: ok")
	print("character_info_lingpet_stowed_capture: evidence=", output_path)
	LanguageSettings.set_test_locale_override("")
	runtime.reset_for_tests()
	registry.modules.clear()
	canvas.overlay = null
	canvas.owner_ref = null
	canvas.registry_ref = null
	viewport.queue_free()
	await process_frame
	quit(0)
