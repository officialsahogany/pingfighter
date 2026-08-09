extends SceneTree

# Windowed Vulkan pixel-QA harness for the one-guardian Replace / Absorb modal.
# Run from godot/ with --rendering-method mobile, never --headless.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetOverflowChoiceOverlayHost := preload(
	"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const OUT_DIR := "D:/tmp/bosspong_guardian_roster_qa"
const VIEW_SIZE := Vector2i(760, 750)


class FakeRuntime:
	extends RefCounted
	var snapshot: Dictionary = {}
	var replace_count := 0
	var absorb_count := 0

	func is_overflow_choice_active() -> bool:
		return true

	func get_overflow_choice_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func commit_overflow_replace(_slot_index: int, _owner: Object, _registry: Object) -> bool:
		replace_count += 1
		return true

	func commit_overflow_absorb(_owner: Object, _registry: Object) -> bool:
		absorb_count += 1
		return true


class ModalCanvas:
	extends Node2D
	var host: Object
	var runtime: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.045, 0.07, 0.105), true)
		draw_circle(Vector2(118.0, 245.0), 142.0, Color(0.08, 0.42, 0.43, 0.38))
		draw_circle(Vector2(655.0, 170.0), 118.0, Color(0.42, 0.17, 0.36, 0.32))
		draw_rect(Rect2(0.0, 620.0, 760.0, 130.0), Color(0.018, 0.035, 0.055), true)
		host.draw(self, runtime, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("lingpet_replace_absorb_choice_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required, got: %s" % RenderingServer.get_current_rendering_method())
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_DIR) != OK:
		push_error("failed to create capture directory: %s" % OUT_DIR)
		quit(1)
		return
	var host := LingpetOverflowChoiceOverlayHost.new()
	host.prewarm_assets()
	var pet_id := "rahoset"
	var art_path := LingpetCatalog.get_visual_path(pet_id, "cutin_art")
	ProjectResourceLoader.load_imported_texture(art_path)
	# Worst case on the left (both second slots unlocked = 4 rows), empty passive on the
	# right so one capture covers the max layout AND the explicit empty-slot row.
	var current_guardian := _build_guardian_snapshot("maribo", false, 2, 2)
	var replacement_guardian := _build_guardian_snapshot(pet_id, true, 1, 0)
	ProjectResourceLoader.load_imported_texture(str(current_guardian.get("art_path", "")))
	var runtime := FakeRuntime.new()
	runtime.snapshot = {
		"active": true,
		"pending_pet_id": pet_id,
		"pending_display_name": LingpetCatalog.get_display_name(pet_id),
		"pending_art_path": art_path,
		"pending_stats": {
			"patrol_speed_default": LingpetCatalog.get_stat(pet_id, "patrol_speed_default", 0.0),
			"patrol_speed_min": LingpetCatalog.get_stat(pet_id, "patrol_speed_min", 0.0),
			"patrol_speed_max": LingpetCatalog.get_stat(pet_id, "patrol_speed_max", 0.0),
			"catch_width": LingpetCatalog.get_stat(pet_id, "catch_width", 0.0),
			"catch_height": LingpetCatalog.get_stat(pet_id, "catch_height", 0.0),
			"defense_rate": LingpetCatalog.get_stat(pet_id, "defense_rate", 0.0),
			"appearance_rate": LingpetCatalog.get_stat(pet_id, "appearance_rate", 0.0),
			"hit_gauge_gain": LingpetCatalog.get_stat(pet_id, "hit_gauge_gain", 0.0),
		},
		"absorb_only": false,
		"replacement_skill_name": str(replacement_guardian.get("active_skill_name", "")),
		"replacement_skill_description": str(replacement_guardian.get("active_skill_description", "")),
		"replacement_skill_cooldown": float(replacement_guardian.get("active_skill_cooldown", 0.0)),
		"replacement_skill_icon_path": str(replacement_guardian.get("active_skill_icon_path", "")),
		"slots": [{
			"slot_index": 0,
			"pet_id": "maribo",
			"display_name": LingpetCatalog.get_display_name("maribo"),
			"active": true,
		}],
		"active_slot_index": 0,
		"current_guardian": current_guardian,
		"replacement_guardian": replacement_guardian,
	}
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ModalCanvas.new()
	canvas.host = host
	canvas.runtime = runtime
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/guardian_replace_absorb_choice.png" % OUT_DIR
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("failed to save capture: %s" % output_path)
		quit(1)
		return
	if not FileAccess.file_exists(output_path) or FileAccess.get_file_as_bytes(output_path).is_empty():
		push_error("capture missing or empty: %s" % output_path)
		quit(1)
		return
	var hover_event := InputEventMouseMotion.new()
	hover_event.position = host.get_new_pet_art_rect_for_tests(Vector2(VIEW_SIZE)).get_center()
	host.handle_input(hover_event, runtime, null, null, Vector2(VIEW_SIZE))
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var tooltip_image: Image = viewport.get_texture().get_image()
	var tooltip_output_path := "%s/guardian_replace_absorb_choice_tooltip.png" % OUT_DIR
	if tooltip_image == null or tooltip_image.is_empty() or tooltip_image.save_png(tooltip_output_path) != OK:
		push_error("failed to save tooltip capture: %s" % tooltip_output_path)
		quit(1)
		return
	var key_one := InputEventKey.new()
	key_one.pressed = true
	key_one.keycode = KEY_1
	host.handle_input(key_one, runtime, null, null, Vector2(VIEW_SIZE))
	if runtime.replace_count != 0:
		push_error("comparison capture committed replacement before confirmation")
		quit(1)
		return
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var compare_image: Image = viewport.get_texture().get_image()
	var compare_output_path := "%s/guardian_replace_compare.png" % OUT_DIR
	if compare_image == null or compare_image.is_empty() or compare_image.save_png(compare_output_path) != OK:
		push_error("failed to save comparison capture: %s" % compare_output_path)
		quit(1)
		return
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	host.handle_input(enter, runtime, null, null, Vector2(VIEW_SIZE))
	if runtime.replace_count != 0:
		push_error("confirmation capture committed replacement before final confirmation")
		quit(1)
		return
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var confirm_image: Image = viewport.get_texture().get_image()
	var confirm_output_path := "%s/guardian_replace_confirm.png" % OUT_DIR
	if confirm_image == null or confirm_image.is_empty() or confirm_image.save_png(confirm_output_path) != OK:
		push_error("failed to save confirmation capture: %s" % confirm_output_path)
		quit(1)
		return
	print("[LingpetRosterCapture] %s" % output_path)
	print("[LingpetRosterCapture] %s" % tooltip_output_path)
	print("[LingpetRosterCapture] %s" % compare_output_path)
	print("[LingpetRosterCapture] %s" % confirm_output_path)
	print("[LingpetRosterCapture] renderer=%s" % RenderingServer.get_current_rendering_method())
	quit(0)


# active_slots / passive_slots drive the per-slot arrays the production snapshot now
# publishes, so a capture can actually exercise the layouts the flat single-skill
# fixture could never reach: the 2-active + 2-passive MAX row count (Guardian
# Enhancement can unlock both second slots) and the empty-slot "없음" row.
func _build_guardian_snapshot(
	pet_id: String,
	pending_roll: bool,
	active_slots: int = 1,
	passive_slots: int = 1
) -> Dictionary:
	var active_entries: Array[Dictionary] = []
	for skill in LingpetCatalog.get_active_skill_pool(pet_id):
		if active_entries.size() >= active_slots:
			break
		var level := 3 + active_entries.size() * 2
		active_entries.append(_build_slot_entry(
			LingpetCatalog.get_active_skill(pet_id, str(skill.get("id", "")), level),
			level
		))
	var passive_entries: Array[Dictionary] = []
	for passive in LingpetCatalog.get_passive_skill_pool(pet_id):
		if passive_entries.size() >= passive_slots:
			break
		var level := 2 + passive_entries.size() * 2
		passive_entries.append(_build_slot_entry(
			LingpetCatalog.get_passive_skill(pet_id, str(passive.get("id", "")), level),
			level
		))
	var active_skill: Dictionary = active_entries[0] if not active_entries.is_empty() else {}
	var passive_skill: Dictionary = passive_entries[0] if not passive_entries.is_empty() else {}
	return {
		"active_skills": active_entries,
		"passive_skills": passive_entries,
		"pet_id": pet_id,
		"display_name": LingpetCatalog.get_display_name(pet_id),
		"art_path": LingpetCatalog.get_visual_path(pet_id, "cutin_art"),
		"stats": {
			"patrol_speed_default": LingpetCatalog.get_stat(pet_id, "patrol_speed_default", 0.0),
			"patrol_speed_min": LingpetCatalog.get_stat(pet_id, "patrol_speed_min", 0.0),
			"patrol_speed_max": LingpetCatalog.get_stat(pet_id, "patrol_speed_max", 0.0),
			"catch_width": LingpetCatalog.get_stat(pet_id, "catch_width", 0.0),
			"catch_height": LingpetCatalog.get_stat(pet_id, "catch_height", 0.0),
			"defense_rate": LingpetCatalog.get_stat(pet_id, "defense_rate", 0.0),
			"appearance_rate": LingpetCatalog.get_stat(pet_id, "appearance_rate", 0.0),
			"hit_gauge_gain": LingpetCatalog.get_stat(pet_id, "hit_gauge_gain", 0.0),
		},
		"active_skill_name": str(active_skill.get("name", "")),
		"active_skill_description": str(active_skill.get("description", "")),
		"active_skill_cooldown": float(active_skill.get("cooldown", 0.0)),
		"active_skill_icon_path": str(active_skill.get("icon_path", "")),
		"active_skill_level": int(active_skill.get("level", 0)),
		"passive_skill_name": str(passive_skill.get("name", "")),
		"passive_skill_description": str(passive_skill.get("description", "")),
		"passive_skill_icon_path": str(passive_skill.get("icon_path", "")),
		"passive_skill_level": int(passive_skill.get("level", 0)),
		"pending_roll": pending_roll,
	}


func _build_slot_entry(skill: Dictionary, level: int) -> Dictionary:
	return {
		"name": str(skill.get("name", "")),
		"description": str(skill.get("description", "")),
		"cooldown": float(skill.get("cooldown", 0.0)),
		"icon_path": str(skill.get("icon_texture_path", "")),
		"level": level,
	}
