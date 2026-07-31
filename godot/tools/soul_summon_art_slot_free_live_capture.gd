extends SceneTree

# Windowed Vulkan proof for the production TAB snapshot/projection path.
# Equips Soul Summoning Art as Chosik with no paid Mugong and fails unless the
# Chosik slot remains visible while the Mugong section renders an empty 0/6.

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

const VIEW_SIZE := Vector2i(1264, 964)
const OUT_PATH := "D:/tmp/bosspong_guardian_transition_qa/soul_summon_mugong_hidden_live.png"


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


class CharacterRuntimeStub:
	extends RefCounted

	func get_base_movement_config(_character_type: String) -> Dictionary:
		return {"paddle_speed": 6.0, "paddle_max_speed": 6.0}


class OverlayCanvas:
	extends Node2D
	var overlay: Object
	var owner_ref: Object
	var registry_ref: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.07, 0.09, 0.14), true)
		overlay.draw(self, owner_ref, registry_ref, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("soul_summon_art_slot_free_live_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir()) != OK:
		push_error("failed to create capture directory")
		quit(1)
		return

	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = {
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
	}
	var catalog := RuntimePerkCatalog.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	var skill_config := SmasherSkillConfig.new()
	skill_config.equipped_skills = [CommonSkillCatalog.SOUL_SUMMON_ART_ID]
	var registry := RegistryStub.new()
	registry.modules = {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"runtime_perk_icon_renderer": icon_renderer,
		"smasher_skill_config": skill_config,
		"character_runtime": CharacterRuntimeStub.new(),
	}
	var owner := PermissiveOwner.new({
		"selected_character_type": "smasher",
		"special_gauge": 120.0,
		"special_gauge_max": 500.0,
		"player_paddle_width": 155.0,
		"active_item_slots": [],
		"show_character_info": true,
	})
	var overlay := CharacterInfoOverlay.new()
	overlay.prewarm_assets(owner, registry, Callable(), true, Vector2(VIEW_SIZE))
	overlay.active = true
	overlay.animation_time = 10.0

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := OverlayCanvas.new()
	canvas.overlay = overlay
	canvas.owner_ref = owner
	canvas.registry_ref = registry
	viewport.add_child(canvas)
	for _frame_index in range(4):
		canvas.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw

	var entries: Array = overlay._perk_display_entries_cache
	if entries.size() != RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT:
		push_error("expected the standard six-cell Mugong grid, got %d" % entries.size())
		quit(1)
		return
	for entry_value in entries:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		if not bool(entry.get("_empty_slot", false)):
			push_error("Soul-only equipped fixture must render six empty Mugong cells")
			quit(1)
			return
		if str(entry.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID or bool(entry.get("_slot_free_cell", false)):
			push_error("equipped Soul Summoning Art leaked into the Mugong section")
			quit(1)
			return
	var skill_ids: Array = overlay._skill_slot_id_cache
	if not skill_ids.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID):
		push_error("Soul Summoning Art disappeared from the equipped Chosik section")
		quit(1)
		return

	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUT_PATH) != OK:
		push_error("failed to save live TAB capture")
		quit(1)
		return
	print("[SoulSummonMugongHiddenCapture] mugong_empty=%d chosik_present=true path=%s" % [entries.size(), OUT_PATH])
	quit(0)
