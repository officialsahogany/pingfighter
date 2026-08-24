extends SceneTree

const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)

const VIEW_SIZE := Vector2i(1280, 900)
const OUTPUT_PATH := "res://.godot/codex_captures/guardian_spring_stage2/prayer_count_2_stats.png"


class QaOwner:
	extends RefCounted
	var selected_character_type := "smasher"
	var special_gauge_max := 530.0
	var player_paddle_width := 155.0
	var runtime_paddle_scale := 1.0
	var active_item_slots: Array = []


class QaRegistry:
	extends RefCounted
	var runtime_state: Object

	func _init(value: Object) -> void:
		runtime_state = value

	func get_instance(key: String) -> Object:
		return runtime_state if key == "runtime_perk_state" else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class CaptureCanvas:
	extends Node2D
	var renderer: Object
	var qa_registry: Object
	var qa_owner: Object

	func _init(renderer_value: Object, registry_value: Object, owner_value: Object) -> void:
		renderer = renderer_value
		qa_registry = registry_value
		qa_owner = owner_value

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("101723"))
		draw_rect(Rect2(120.0, 70.0, 1040.0, 760.0), Color("e9dfc7"))
		renderer.draw_tower_training_stats_panel(
			self,
			Rect2(180.0, 105.0, 920.0, 680.0),
			Vector2(-1.0, -1.0),
			Vector2(VIEW_SIZE)
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_guardian_spring_stage2_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_guardian_spring_stage2_visual_qa requires Vulkan")
		quit(1)
		return
	var runtime_state := RuntimePerkState.new()
	runtime_state.set_tower_spring_prayer_count(2)
	var owner := QaOwner.new()
	var registry := QaRegistry.new(runtime_state)
	var renderer := RuntimePerkOverlayRenderer.new()
	renderer.prewarm_traditional_choice_assets()
	var prepared: Dictionary = renderer.prepare_tower_training_stats_panel(owner, registry)
	if not bool(prepared.get("prepared", false)):
		push_error("S2 prayer stats panel did not prepare")
		quit(1)
		return
	var stats: Dictionary = renderer.get_tower_training_stats_snapshot_for_tests()
	var labels: Array = stats.get("labels", [])
	var values: Array = stats.get("values", [])
	var speed_index := labels.find("이동 속도")
	var gauge_index := labels.find("최대 기력")
	if speed_index < 0 or gauge_index < 0:
		push_error("S2 prayer stats panel is missing production rows")
		quit(1)
		return
	if str(values[speed_index]) == "800.00" or str(values[gauge_index]) != "530pt":
		push_error("S2 prayer stats panel did not render divergent +6% values: %s" % [values])
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK:
		push_error("S2 prayer capture directory creation failed")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(renderer, registry, owner)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("S2 prayer stats capture failed")
		quit(1)
		return
	print("[GuardianSpringS2VisualQA] %s" % output_path)
	print("tower_guardian_spring_stage2_visual_qa: prayer_count=2 speed=%s max_gauge=%s" % [values[speed_index], values[gauge_index]])
	print("tower_guardian_spring_stage2_visual_qa: ok")
	quit(0)
