extends SceneTree

const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)
const BattleSceneModalGateController := preload(
	"res://scripts/core/battle_scene_modal_gate_controller.gd"
)
const BattleSceneOverlayInputController := preload(
	"res://scripts/core/battle_scene_overlay_input_controller.gd"
)
const LingpetAcquireCutinOverlayHost := preload(
	"res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd"
)
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetOverflowChoiceOverlayHost := preload(
	"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
)
const ProjectResourceLoader := preload(
	"res://scripts/resources/project_resource_loader.gd"
)

const VIEW_SIZE := Vector2i(1280, 900)
const OUTPUT_DIR := "res://.godot/codex_captures/guardian_spring_stage3_fix"


class RuntimeFixture:
	extends RefCounted
	var overflow_active := false
	var overflow_snapshot: Dictionary = {}
	var acquire_active := false
	var acquire_dismissing := false
	var acquire_pet_id := ""
	var replace_count := 0
	var cancel_count := 0
	var dismiss_count := 0

	func start_compare(snapshot: Dictionary) -> void:
		overflow_snapshot = snapshot.duplicate(true)
		overflow_active = true
		acquire_active = false

	func start_acquire(pet_id: String) -> void:
		acquire_pet_id = pet_id
		acquire_active = true
		acquire_dismissing = false
		overflow_active = false

	func is_overflow_choice_active() -> bool:
		return overflow_active

	func get_overflow_choice_snapshot() -> Dictionary:
		return overflow_snapshot.duplicate(true)

	func commit_overflow_replace(
		_slot_index: int,
		_owner: Object = null,
		_registry: Object = null
	) -> bool:
		replace_count += 1
		overflow_active = false
		return true

	func commit_overflow_absorb(
		_owner: Object = null,
		_registry: Object = null
	) -> bool:
		cancel_count += 1
		overflow_active = false
		return true

	func is_acquire_cutin_active() -> bool:
		return acquire_active

	func is_acquire_cutin_awaiting_dismiss() -> bool:
		return acquire_active and not acquire_dismissing

	func begin_acquire_cutin_dismiss(_registry: Object = null) -> bool:
		if not is_acquire_cutin_awaiting_dismiss():
			return false
		acquire_dismissing = true
		dismiss_count += 1
		return true

	func is_acquire_cutin_dismissing() -> bool:
		return acquire_dismissing

	func get_acquire_cutin_progress() -> float:
		return 1.0

	func get_acquire_cutin_dismiss_progress() -> float:
		return 0.48

	func get_snapshot() -> Dictionary:
		return {
			"state": "companion",
			"pet_id": acquire_pet_id,
			"active_pet_id": acquire_pet_id,
			"cutin_pet_id": acquire_pet_id,
		}


class TowerFlowFixture:
	extends RefCounted
	var input_calls := 0

	func is_active() -> bool:
		return true

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func handle_input(_event: InputEvent) -> void:
		input_calls += 1


class Registry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class ModuleTable:
	extends RefCounted
	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class CaptureCanvas:
	extends Node2D
	var runtime: Object = null
	var overflow_host: Object = null
	var acquire_host: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("081424"), true)
		draw_circle(Vector2(170.0, 250.0), 210.0, Color(0.08, 0.48, 0.45, 0.24))
		draw_circle(Vector2(1110.0, 180.0), 180.0, Color(0.52, 0.17, 0.38, 0.22))
		draw_rect(Rect2(0.0, 735.0, 1280.0, 165.0), Color("06101c"), true)
		if runtime.is_acquire_cutin_active():
			acquire_host.draw(self, runtime, Vector2(VIEW_SIZE))
		elif runtime.is_overflow_choice_active():
			overflow_host.draw(self, runtime, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_guardian_spring_stage3_fix_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_guardian_spring_stage3_fix_visual_qa requires Vulkan")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("S3-fix capture directory creation failed")
		quit(1)
		return
	var window := get_root()
	window.mode = Window.MODE_WINDOWED
	window.size = VIEW_SIZE
	window.content_scale_size = VIEW_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var runtime := RuntimeFixture.new()
	var tower_flow := TowerFlowFixture.new()
	var overflow_host := LingpetOverflowChoiceOverlayHost.new()
	var acquire_host := LingpetAcquireCutinOverlayHost.new()
	var registry := Registry.new()
	var modal_gate := BattleSceneModalGateController.new()
	var overlay_input := BattleSceneOverlayInputController.new()
	var input_controller := BattleSceneInputController.new()
	var modules := ModuleTable.new()
	registry.instances = {
		"lingpet_overflow_choice_overlay_host": overflow_host,
		"tower_ascent_flow_owner": tower_flow,
	}
	modules.modules = {
		"battle_scene_modal_gate_controller": modal_gate,
		"battle_scene_overlay_input_controller": overlay_input,
		"lingpet_egg_runtime": runtime,
	}
	var module_getter := Callable(modules, "get_module")
	var canvas := CaptureCanvas.new()
	canvas.runtime = runtime
	canvas.overflow_host = overflow_host
	canvas.acquire_host = acquire_host
	window.add_child(canvas)
	overflow_host.prewarm_assets()

	var confirm_snapshot := _build_compare_snapshot("maribo", "lumion")
	_prewarm_compare_snapshot(confirm_snapshot)
	runtime.start_compare(confirm_snapshot)
	_dispatch_key(input_controller, KEY_ENTER, canvas, registry, module_getter)
	if overflow_host.get_phase_for_tests() != LingpetOverflowChoiceOverlayHost.PHASE_CONFIRM:
		push_error("actual input route did not open comparison confirmation")
		quit(1)
		return
	var confirm_path := output_dir.path_join("compare_confirm.png")
	if not await _capture(window, canvas, confirm_path):
		quit(1)
		return
	_dispatch_key(input_controller, KEY_ENTER, canvas, registry, module_getter)
	if runtime.replace_count != 1 or tower_flow.input_calls != 0:
		push_error("actual input route did not commit confirmation ahead of Tower flow")
		quit(1)
		return

	var cancel_snapshot := _build_compare_snapshot("lumion", "rabi")
	_prewarm_compare_snapshot(cancel_snapshot)
	runtime.start_compare(cancel_snapshot)
	var cancel_path := output_dir.path_join("compare_cancel.png")
	if not await _capture(window, canvas, cancel_path):
		quit(1)
		return
	_dispatch_key(input_controller, KEY_ESCAPE, canvas, registry, module_getter)
	if runtime.cancel_count != 1 or runtime.is_overflow_choice_active() or tower_flow.input_calls != 0:
		push_error("actual input route did not cancel comparison ahead of Tower flow")
		quit(1)
		return

	var cutin_pet_id := "baekrin"
	# This isolated QA worktree intentionally has no editor-materialized import
	# for the new Baekrin art while the user's main editor is open. Decode the
	# source once in this offline capture setup and inject it into the production
	# host; the draw path itself still performs no raw load.
	var cutin_art := _load_qa_source_texture(
		LingpetCatalog.get_visual_path(cutin_pet_id, "cutin_art")
	)
	if cutin_art == null:
		push_error("first-pick QA source art failed to load")
		quit(1)
		return
	acquire_host.set("_asset_pet_id", cutin_pet_id)
	acquire_host.set("_title_text", LingpetCatalog.get_display_name(cutin_pet_id))
	acquire_host.set("_cutin_art", cutin_art)
	acquire_host.set("_pet_texture_prewarm_finished_for", cutin_pet_id)
	runtime.start_acquire(cutin_pet_id)
	_dispatch_key(input_controller, KEY_ENTER, canvas, registry, module_getter)
	if runtime.dismiss_count != 1 or not runtime.is_acquire_cutin_dismissing() or tower_flow.input_calls != 0:
		push_error("actual input route did not start first-pick cut-in dismissal")
		quit(1)
		return
	var first_pick_path := output_dir.path_join("first_pick_cutin_dismiss.png")
	if not await _capture(window, canvas, first_pick_path):
		quit(1)
		return

	print("[GuardianSpringS3FixVisualQA] confirm=%s" % confirm_path)
	print("[GuardianSpringS3FixVisualQA] cancel=%s" % cancel_path)
	print("[GuardianSpringS3FixVisualQA] first_pick=%s" % first_pick_path)
	print("tower_guardian_spring_stage3_fix_visual_qa: confirm=1 cancel=1 first_pick_dismiss=1")
	print("tower_guardian_spring_stage3_fix_visual_qa: ok")
	canvas.runtime = null
	canvas.overflow_host = null
	canvas.acquire_host = null
	canvas.queue_free()
	await process_frame
	await process_frame
	registry.instances.clear()
	modules.modules.clear()
	cutin_art = null
	call_deferred("_finish_success")


func _finish_success() -> void:
	await process_frame
	await process_frame
	quit(0)


func _capture(window: Window, canvas: CanvasItem, output_path: String) -> bool:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := window.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("S3-fix capture failed: %s" % output_path)
		return false
	return true


func _load_qa_source_texture(resource_path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _dispatch_key(
	controller: Object,
	keycode: int,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	controller.handle_unhandled_input(event, owner, registry, module_getter, {})


func _build_compare_snapshot(current_pet_id: String, replacement_pet_id: String) -> Dictionary:
	var current := _build_guardian_snapshot(current_pet_id, false)
	var replacement := _build_guardian_snapshot(replacement_pet_id, true)
	return {
		"active": true,
		"compare_only": true,
		"absorb_only": false,
		"pending_pet_id": replacement_pet_id,
		"pending_display_name": str(replacement.get("display_name", "")),
		"pending_art_path": str(replacement.get("art_path", "")),
		"slots": [{
			"slot_index": 0,
			"pet_id": current_pet_id,
			"display_name": str(current.get("display_name", "")),
			"active": true,
		}],
		"active_slot_index": 0,
		"current_guardian": current,
		"replacement_guardian": replacement,
	}


func _build_guardian_snapshot(pet_id: String, pending_roll: bool) -> Dictionary:
	var active_pool := LingpetCatalog.get_active_skill_pool(pet_id)
	var passive_pool := LingpetCatalog.get_passive_skill_pool(pet_id)
	var active_skill: Dictionary = (
		LingpetCatalog.get_active_skill(pet_id, str(active_pool[0].get("id", "")), 3)
		if not active_pool.is_empty()
		else {}
	)
	var passive_skill: Dictionary = (
		LingpetCatalog.get_passive_skill(pet_id, str(passive_pool[0].get("id", "")), 2)
		if not passive_pool.is_empty()
		else {}
	)
	var active_entry := _build_skill_entry(active_skill, 3)
	var passive_entry := _build_skill_entry(passive_skill, 2)
	return {
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
		"active_skills": [active_entry] if not active_entry.is_empty() else [],
		"passive_skills": [passive_entry] if not passive_entry.is_empty() else [],
		"active_skill_name": str(active_entry.get("name", "")),
		"active_skill_description": str(active_entry.get("description", "")),
		"active_skill_cooldown": float(active_entry.get("cooldown", 0.0)),
		"active_skill_icon_path": str(active_entry.get("icon_path", "")),
		"active_skill_level": int(active_entry.get("level", 0)),
		"passive_skill_name": str(passive_entry.get("name", "")),
		"passive_skill_description": str(passive_entry.get("description", "")),
		"passive_skill_icon_path": str(passive_entry.get("icon_path", "")),
		"passive_skill_level": int(passive_entry.get("level", 0)),
		"pending_roll": pending_roll,
	}


func _build_skill_entry(skill: Dictionary, level: int) -> Dictionary:
	if skill.is_empty():
		return {}
	return {
		"name": str(skill.get("name", "")),
		"description": str(skill.get("description", "")),
		"cooldown": float(skill.get("cooldown", 0.0)),
		"icon_path": str(skill.get("icon_texture_path", "")),
		"level": level,
	}


func _prewarm_compare_snapshot(snapshot: Dictionary) -> void:
	for key in ["current_guardian", "replacement_guardian"]:
		var guardian: Dictionary = snapshot.get(key, {}) as Dictionary
		ProjectResourceLoader.load_imported_texture(str(guardian.get("art_path", "")))
		for skill_key in ["active_skills", "passive_skills"]:
			for skill_value in guardian.get(skill_key, []) as Array:
				if skill_value is Dictionary:
					ProjectResourceLoader.load_imported_texture(
						str((skill_value as Dictionary).get("icon_path", ""))
					)
