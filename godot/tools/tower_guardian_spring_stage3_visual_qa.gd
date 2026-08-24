extends SceneTree

const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerGuardianSpringOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_offer_builder.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_PATH := "res://.godot/codex_captures/guardian_spring_stage3/floor_5_elite_cards.png"


class QaRunState:
	extends RefCounted

	func export_economy() -> Dictionary:
		return {"muhon": 20, "gold": 2000, "chance_gems": 3}

	func get_prayer_count() -> int:
		return 2

	func is_guardian_prayer_locked() -> bool:
		return true


class QaLingpetRuntime:
	extends RefCounted
	var active_pet_id: String

	func _init(pet_id: String) -> void:
		active_pet_id = pet_id

	func build_save_snapshot() -> Dictionary:
		return {
			"state": "companion",
			"pet_id": active_pet_id,
			"owned_pet_ids": [active_pet_id],
			"guardian_run_state": {"pets": {active_pet_id: {}}},
		}

	func build_guardian_enhance_live_candidates(_owner: Object = null) -> Array:
		return [{"type": "mobility"}]


class QaRegistry:
	extends RefCounted
	var runtime: Object

	func _init(runtime_value: Object) -> void:
		runtime = runtime_value

	func get_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class QaOwner:
	extends RefCounted

	func set_tower_ascent_guardian_projection(
		_sealed_guardians: Array,
		_soul_summoning_owned: bool
	) -> void:
		pass


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object

	func _init(state_value: Object, card_value: Object, icon_value: Object) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "guardian_spring"

	func get_node_modal_render_context() -> Dictionary:
		return {"card_renderer": card_renderer, "icon_renderer": icon_renderer}


class CaptureCanvas:
	extends Node2D
	var flow: Object
	var renderer := TowerAscentFlowRenderer.new()

	func _init(flow_value: Object) -> void:
		flow = flow_value

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_guardian_spring_stage3_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_guardian_spring_stage3_visual_qa requires Vulkan")
		quit(1)
		return
	var active_pet_id := "maribo"
	var offers: Array[Dictionary] = TowerGuardianSpringOfferBuilder.new().build_browse_offers(
		53005,
		"spring-05",
		1,
		5,
		[active_pet_id]
	)
	for offer in offers:
		offer["node_id"] = "spring-05"
		offer["browse_sequence"] = 1
	var spring := TowerAscentGuardianSpringNode.new()
	spring.restore_state({
		"soul_summoning_owned": true,
		"first_pick_completed": true,
		"active_guardian": {"pet_id": active_pet_id, "display_name": "마리보"},
		"browse_sequence": 1,
		"browse_offers": offers,
	})
	var actions := spring.build_actions(
		"spring-05",
		53005,
		QaRunState.new(),
		QaOwner.new(),
		QaRegistry.new(QaLingpetRuntime.new(active_pet_id))
	)
	if actions.size() != 3:
		push_error("S3 visual fixture must expose exactly three elite cards")
		quit(1)
		return
	for action in actions:
		if not str(action.get("cost_text", "")).contains("280"):
			push_error("S3 floor-five elite card is missing its 280 Gold price")
			quit(1)
			return
	var card_renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	card_renderer.prewarm_traditional_choice_assets()
	_prewarm_guardian_portraits(icon_renderer)
	var modal := TowerAscentNodeModalState.new()
	modal.open("spring-s3-visual", "guardian_spring", {"muhon": 20, "gold": 2000}, actions)
	modal.set_clock_msec_for_tests(1000)
	var action_rects := modal.get_action_rects(Vector2(VIEW_SIZE))
	if action_rects.size() < 3:
		push_error("S3 visual fixture did not allocate three production card rectangles")
		quit(1)
		return
	modal.update_hover_at_position(
		(action_rects[1] as Rect2).get_center(),
		Vector2(VIEW_SIZE)
	)
	modal.set_clock_msec_for_tests(1160)
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK:
		push_error("S3 capture directory creation failed")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var flow := CaptureFlow.new(modal, card_renderer, icon_renderer)
	var canvas := CaptureCanvas.new(flow)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("S3 elite-card capture failed")
		quit(1)
		return
	print("[GuardianSpringS3VisualQA] %s" % output_path)
	print("tower_guardian_spring_stage3_visual_qa: cards=3 floor=5 price=280")
	print("tower_guardian_spring_stage3_visual_qa: ok")
	quit(0)


func _prewarm_guardian_portraits(icon_renderer: Object) -> void:
	var jobs_value: Variant = icon_renderer.call("_build_prewarm_asset_jobs")
	if not (jobs_value is Array):
		return
	for job_value in jobs_value as Array:
		if (
			job_value is Dictionary
			and str((job_value as Dictionary).get("type", "")) == "guardian_portrait"
		):
			icon_renderer.call("_run_prewarm_asset_job", job_value)
