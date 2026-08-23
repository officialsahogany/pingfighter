extends SceneTree

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const BattleRewardModalInputRouter := preload("res://scripts/core/battle_reward_modal_input_router.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TowerRewardPickState := preload("res://scripts/tower_ascent/tower_reward_pick_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_ROOT := "res://.godot/codex_captures/battle_scene_victory_modal_zorder"
const MIN_CHANGED_PIXELS := 4000
const PIXEL_DELTA_THRESHOLD := 0.08
const MYTHIC_FIELD_SIZE := Vector2(760.0, 750.0)
const MYTHIC_STRONG_LIT_DELTA_THRESHOLD := 0.45
const MYTHIC_STRONG_LIT_CHANNEL_THRESHOLD := 0.72
const MYTHIC_CLEANUP_DELTA_THRESHOLD := 0.01

var _failures: Array[String] = []
var _output_dir := ""


class CaptureOwner:
	extends RefCounted

	var selected_character_type := "smasher"


class CaptureFlowOwner:
	extends RefCounted

	var balances := {"muhon": 9, "gold": 0, "chance_gems": 3}

	func get_reward_pick_context() -> Dictionary:
		return {
			"node_resolution_id": "victory-modal-zorder-visual-qa",
			"boss_slot_id": "floor_01_dalji",
		}

	func get_run_state_snapshot() -> Dictionary:
		return balances.duplicate(true)


class CaptureRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class CaptureOfferBuilder:
	extends RefCounted

	var offer: Dictionary = {}

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {}
	) -> Dictionary:
		return offer.duplicate(true)


class CaptureVictoryLootState:
	extends RefCounted

	var reward_state: Object = null
	var external_modal_active := false
	var predicate_checks := 0
	var reward_draw_calls := 0

	func is_reward_pick_external_modal_active() -> bool:
		predicate_checks += 1
		return external_modal_active

	func is_reward_pick_active() -> bool:
		return reward_state != null

	func draw_reward_pick(canvas: CanvasItem, view_size: Vector2) -> void:
		reward_draw_calls += 1
		reward_state.draw(canvas, view_size)


class HiddenHudStripRenderer:
	extends RefCounted

	func has_visible_entries(_levels: Dictionary, _projection: Dictionary) -> bool:
		return false


class CaptureCanvas:
	extends Node2D

	var drawer: Object = null
	var registry: Object = null

	func _draw() -> void:
		drawer.draw(self, registry, {"view_size": Vector2(VIEW_SIZE)})


class MythicCaptureOwner:
	extends Node2D

	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var gameplay_frame_counter := 100

	func request_battle_redraw() -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.012, 0.016, 0.028, 1.0), true)
		var field_origin := (Vector2(VIEW_SIZE) - MYTHIC_FIELD_SIZE) * 0.5
		draw_rect(
			Rect2(field_origin, MYTHIC_FIELD_SIZE),
			Color(0.035, 0.045, 0.075, 1.0),
			true
		)


class MythicCaptureAudio:
	extends RefCounted

	func play_legendary_open() -> void:
		pass

	func play_legendary_after() -> void:
		pass

	func play_legendary_ending() -> void:
		pass

	func stop_legendary_after() -> void:
		pass

	func play_item_get() -> void:
		pass


class MythicCaptureActiveItemRuntime:
	extends RefCounted

	func pause_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		pass

	func resume_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("visual QA requires a real window")
	elif RenderingServer.get_rendering_device() == null:
		_fail("visual QA requires a Vulkan rendering device")
	if not _failures.is_empty():
		_finish()
		return

	LanguageSettings.set_test_locale_override("ko")
	_output_dir = ProjectSettings.globalize_path(
		"%s/run_%d_%d" % [OUTPUT_ROOT, Time.get_ticks_usec(), OS.get_process_id()]
	)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if mkdir_error != OK:
		_fail("capture directory creation failed (%d): %s" % [mkdir_error, _output_dir])
		_finish()
		return

	await _capture_case("victory_chosik_slot_swap_above_reward.png", "swap")
	await _capture_case("victory_perk_fusion_above_reward.png", "fusion")
	await _capture_mythic_acquisition_case()
	LanguageSettings.set_test_locale_override("")
	_finish()


func _capture_case(file_name: String, modal_kind: String) -> void:
	var owner := CaptureOwner.new()
	var flow := CaptureFlowOwner.new()
	var runtime_state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	var overlay_renderer := RuntimePerkOverlayRenderer.new()
	overlay_renderer.set_training_stat_preview_draw_msec_for_tests(2000)
	overlay_renderer.prewarm_assets()
	var registry := CaptureRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"runtime_perk_icon_renderer": icon_renderer,
		"runtime_perk_overlay_renderer": overlay_renderer,
		"tower_ascent_flow_owner": flow,
	}

	var reward_state := TowerRewardPickState.new()
	var offer_builder := CaptureOfferBuilder.new()
	offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"choices": _build_reward_choices(catalog),
	}
	reward_state.set("_offer_builder", offer_builder)
	if not reward_state.start(owner, registry, Callable()):
		_fail("%s fixture could not start the production reward-pick board" % modal_kind)
		return
	reward_state.selected_index = 2
	reward_state.update(1.0)

	if modal_kind == "swap":
		_configure_swap_modal(runtime_state)
	else:
		_configure_fusion_modal(runtime_state, catalog, owner, registry)
	var modal_active := (
		runtime_state.has_pending_unlock_swap()
		if modal_kind == "swap"
		else runtime_state.is_perk_fusion_modal_active()
	)
	if not modal_active:
		_fail("%s production modal fixture did not become active" % modal_kind)
		reward_state.reset()
		return

	var victory_loot := CaptureVictoryLootState.new()
	victory_loot.reward_state = reward_state
	registry.instances["victory_loot_phase_state"] = victory_loot
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new()
	canvas.drawer = BattleSceneDrawer.new()
	canvas.drawer.hud_strip_renderer = HiddenHudStripRenderer.new()
	canvas.registry = registry
	viewport.add_child(canvas)

	victory_loot.external_modal_active = false
	var buried_image := await _capture_frame(viewport, canvas)
	victory_loot.external_modal_active = true
	var raised_image := await _capture_frame(viewport, canvas)
	var changed_pixels := _count_changed_pixels(buried_image, raised_image)
	if changed_pixels < MIN_CHANGED_PIXELS:
		_fail(
			"%s z-order counterfactual changed only %d pixels (minimum %d)"
			% [modal_kind, changed_pixels, MIN_CHANGED_PIXELS]
		)
	var output_path := _output_dir.path_join(file_name)
	if raised_image == null or raised_image.is_empty() or raised_image.get_size() != VIEW_SIZE:
		_fail("%s raised-modal Vulkan capture was empty or the wrong size" % modal_kind)
	elif raised_image.save_png(output_path) != OK:
		_fail("%s capture save failed: %s" % [modal_kind, output_path])
	else:
		print(
			"[VictoryModalZOrderQA] kind=%s changed_pixels=%d capture=%s"
			% [modal_kind, changed_pixels, output_path]
		)

	reward_state.reset()
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _capture_mythic_acquisition_case() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var owner := MythicCaptureOwner.new()
	viewport.add_child(owner)
	var runtime := MythicItemRuntime.new()
	var registry := CaptureRegistry.new()
	registry.instances = {
		"active_item_runtime": MythicCaptureActiveItemRuntime.new(),
		"battle_scene_item_update_driver": BattleSceneItemUpdateDriver.new(),
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"game_audio": MythicCaptureAudio.new(),
		"mythic_item_runtime": runtime,
		"runtime_perk_state": RuntimePerkState.new(),
	}
	var controller := BattleSceneFrameController.new()
	var baseline_image := await _capture_frame(viewport, owner)
	var item_data: Dictionary = MythicItemCatalog.new().build_item_by_name("heavenly_cape")
	item_data["name"] = "절세무공"
	item_data["reveal_description"] = "신화 획득 시네마틱 진행 검증"
	if not runtime.start_acquisition_cinematic(
		item_data,
		Vector2(220.0, 330.0),
		owner,
		registry
	):
		_fail("mythic acquisition visual fixture could not start the production cinematic")
		await _cleanup_mythic_capture(viewport, runtime, registry)
		return
	var entry_image := await _capture_frame(viewport, owner)
	_save_capture(entry_image, "mythic_acquisition_buildup_entry.png", "mythic_entry")

	_process_mythic_physics(controller, owner, registry, 1.21)
	_process_mythic_physics(controller, owner, registry, 0.41)
	_process_mythic_physics(controller, owner, registry, 0.51)
	_process_mythic_physics(controller, owner, registry, 0.51)
	var reveal_snapshot: Dictionary = runtime.get_acquisition_cinematic_snapshot()
	if (
		str(reveal_snapshot.get("phase", "")) != "reveal"
		or not bool(reveal_snapshot.get("waiting_for_click", false))
	):
		_fail("mythic acquisition production frames did not reach armed REVEAL")
	var reveal_image := await _capture_frame(viewport, owner)
	var center_rect := Rect2i(
		Vector2i(VIEW_SIZE.x / 2 - 180, VIEW_SIZE.y / 2 - 180),
		Vector2i(360, 360)
	)
	var strong_center_pixels := _count_strong_brightened_pixels(
		entry_image,
		reveal_image,
		center_rect
	)
	if strong_center_pixels <= 0:
		_fail("mythic REVEAL center has no strongly brightened pixels above the GRT-047 threshold")
	_save_capture(reveal_image, "mythic_acquisition_reveal_after_fix.png", "mythic_reveal")
	print("[VictoryModalZOrderQA] kind=mythic_reveal strong_center_pixels=%d" % strong_center_pixels)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	BattleRewardModalInputRouter.new().handle_input(
		click,
		owner,
		registry,
		Callable(registry, "get_instance")
	)
	_process_mythic_physics(controller, owner, registry, 1.51)
	_process_mythic_physics(controller, owner, registry, 0.51)
	if runtime.is_acquisition_cinematic_active():
		_fail("mythic acquisition production frames did not reach natural completion")
	var completed_image := await _capture_frame(viewport, owner)
	var residual_pixels := _count_pixels_above_delta(
		baseline_image,
		completed_image,
		MYTHIC_CLEANUP_DELTA_THRESHOLD
	)
	if residual_pixels != 0:
		_fail("completed mythic acquisition left %d residual pixels (expected 0)" % residual_pixels)
	_save_capture(completed_image, "mythic_acquisition_completed_cleanup.png", "mythic_complete")
	print("[VictoryModalZOrderQA] kind=mythic_complete residual_pixels=%d" % residual_pixels)
	await _cleanup_mythic_capture(viewport, runtime, registry)


func _process_mythic_physics(
	controller: Object,
	owner: MythicCaptureOwner,
	registry: CaptureRegistry,
	delta: float
) -> void:
	owner.gameplay_frame_counter += 1
	controller.process_physics(
		delta,
		owner,
		registry,
		Callable(registry, "get_instance"),
		{
			"is_battle_initialized": Callable(self, "_return_true"),
			"is_stage_landing_intro_started": Callable(self, "_return_true"),
		}
	)


func _cleanup_mythic_capture(
	viewport: SubViewport,
	runtime: Object,
	registry: CaptureRegistry
) -> void:
	runtime.reset_round(registry)
	runtime.acquisition_cinematic = null
	registry.instances.clear()
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _save_capture(image: Image, file_name: String, kind: String) -> void:
	var output_path := _output_dir.path_join(file_name)
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("%s Vulkan capture was empty or the wrong size" % kind)
	elif image.save_png(output_path) != OK:
		_fail("%s capture failed: %s" % [kind, output_path])
	else:
		print("[VictoryModalZOrderQA] kind=%s capture=%s" % [kind, output_path])


func _return_true() -> bool:
	return true


func _capture_frame(viewport: SubViewport, canvas: CanvasItem) -> Image:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _configure_swap_modal(runtime_state: Object) -> void:
	runtime_state.choice_active = true
	runtime_state.animation_time = 1.0
	runtime_state.pending_unlock_swap = {
		"unlocks_skill": "cleanse",
		"new_name": "정화",
		"candidates": [
			{"skill_id": "drive", "name": "질풍 드라이브"},
			{"skill_id": "power_smashing", "name": "벽력 강타"},
			{"skill_id": "plasma", "name": "한령탄"},
			{"skill_id": "recovery", "name": "운기조식"},
			{"skill_id": "magnum_grip", "name": "천근추"},
		],
	}
	runtime_state.unlock_swap_selected_index = 2


func _configure_fusion_modal(
	runtime_state: Object,
	catalog: Object,
	owner: Object,
	registry: Object
) -> void:
	runtime_state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"common_swiftness": 5,
		"dash_lightweight": 5,
	}
	runtime_state.pending_skill_choices = 1
	runtime_state.choice_active = true
	runtime_state.animation_time = 1.0
	runtime_state.current_choice_context = {"source": "tower_reward_pick"}
	runtime_state.current_choices = [{
		"id": "perk_fusion",
		"name": "무공합일",
		"is_perk_fusion": true,
		"eligible_sources": ["item_luck", "common_bulk_up"],
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	runtime_state.selected_index = 0
	runtime_state.choose_selected(owner, registry, Vector2(VIEW_SIZE))


func _build_reward_choices(catalog: Object) -> Array[Dictionary]:
	return [
		_finalize_reward_choice(catalog.get_perk_data("common_swiftness"), "mugong", 2),
		_finalize_reward_choice(catalog.get_perk_data("common_bulk_up"), "mugong", 2),
		_finalize_reward_choice({
			"id": "perk_fusion",
			"name": "무공합일",
			"description": "보유 무공 두 개를 융합",
			"detail": "기존 무공합일 선택 화면으로 이동합니다.",
			"is_perk_fusion": true,
			"icon_color": Color(0.54, 0.28, 0.72),
		}, "fusion", 3),
		_finalize_reward_choice(catalog.get_perk_data("megingjord"), "supreme", 5),
	]


func _finalize_reward_choice(source: Dictionary, kind: String, cost: int) -> Dictionary:
	var choice := source.duplicate(true)
	choice["reward_pick_kind"] = kind
	choice["reward_pick_cost"] = cost
	choice["reward_pick_price_text"] = "무혼 %d" % cost
	return choice


func _count_changed_pixels(before: Image, after: Image) -> int:
	return _count_pixels_above_delta(before, after, PIXEL_DELTA_THRESHOLD)


func _count_pixels_above_delta(before: Image, after: Image, threshold: float) -> int:
	if before == null or after == null or before.is_empty() or after.is_empty():
		return 0
	if before.get_size() != after.get_size():
		return 0
	var changed := 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta >= threshold:
				changed += 1
	return changed


func _count_strong_brightened_pixels(before: Image, after: Image, rect: Rect2i) -> int:
	if before == null or after == null or before.is_empty() or after.is_empty():
		return 0
	if before.get_size() != after.get_size():
		return 0
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, after.get_size()))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var entry := before.get_pixel(x, y)
			var reveal := after.get_pixel(x, y)
			var positive_delta := maxf(
				reveal.r - entry.r,
				maxf(reveal.g - entry.g, reveal.b - entry.b)
			)
			var reveal_peak := maxf(reveal.r, maxf(reveal.g, reveal.b))
			if (
				positive_delta >= MYTHIC_STRONG_LIT_DELTA_THRESHOLD
				and reveal_peak >= MYTHIC_STRONG_LIT_CHANNEL_THRESHOLD
			):
				count += 1
	return count


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("battle_scene_victory_modal_zorder_visual_qa: evidence=%s" % _output_dir)
		print("battle_scene_victory_modal_zorder_visual_qa: captures=5")
		print("battle_scene_victory_modal_zorder_visual_qa: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
