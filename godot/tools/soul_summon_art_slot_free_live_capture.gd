extends SceneTree

# Windowed Vulkan proof for the production TAB snapshot/projection path.
# Renders a fully occupied six-cell Mugong budget plus Soul Summoning Art and
# fails unless the manual is the seventh, slot-free, right-leading cell.

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")

const VIEW_SIZE := Vector2i(1264, 964)
const OUT_PATH := "D:/tmp/bosspong_guardian_transition_qa/soul_summon_slot_free_live.png"


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
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"dash_acceleration": 1,
		"item_luck": 1,
		"common_swiftness": 1,
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
	var paid_count := 0
	var soul_index := -1
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] if entries[index] is Dictionary else {}
		if bool(entry.get("_empty_slot", false)):
			push_error("full-budget fixture unexpectedly contains an empty paid slot")
			quit(1)
			return
		if bool(entry.get("_slot_free_cell", false)):
			if str(entry.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID:
				soul_index = index
		else:
			paid_count += 1
	if paid_count != RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT:
		push_error("expected six paid cells, got %d" % paid_count)
		quit(1)
		return
	if entries.size() != RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT + 1 or soul_index != entries.size() - 1:
		push_error("Soul Summoning Art must be the seventh appended slot-free cell")
		quit(1)
		return

	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(OUT_PATH) != OK:
		push_error("failed to save live TAB capture")
		quit(1)
		return
	print("[SoulSummonSlotFreeCapture] paid=%d total=%d soul_index=%d path=%s" % [paid_count, entries.size(), soul_index, OUT_PATH])
	quit(0)
