extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_reward_pick"


class CaptureOwner:
	extends RefCounted

	var selected_character_type := "smasher"


class CaptureRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {
		"common_swiftness": 2,
		"megingjord": 1,
	}
	var current_choice_context: Dictionary = {}
	var _stats_owner: Object = null
	var _stats_registry_ref: WeakRef = null

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var choice_id := str(choice.get("id", ""))
		if not choice_id.is_empty():
			runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return true

	func capture_stats_context(owner: Object, registry: Object) -> bool:
		_stats_owner = owner
		_stats_registry_ref = weakref(registry) if registry != null else null
		return owner != null and registry != null

	func get_stats_context_owner() -> Object:
		return _stats_owner

	func get_stats_context_registry() -> Object:
		return _stats_registry_ref.get_ref() if _stats_registry_ref != null else null

	func get_status_hover_mouse_pos() -> Vector2:
		return Vector2(-1.0, -1.0)

	func get_physique_training_snapshot() -> Dictionary:
		return {"power": 1, "guard": 1}

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"pending_skill_choices": 0,
			"gold_from_perks": 0,
			"current_choices": [],
			"particles": [],
			"physique_training": get_physique_training_snapshot(),
		}


class CaptureFlowOwner:
	extends RefCounted

	var balances := {"muhon": 7, "gold": 0, "chance_gems": 3}

	func get_reward_pick_context() -> Dictionary:
		return {
			"node_resolution_id": "visual-reward-pick",
			"boss_slot_id": "floor_01_dalji",
		}

	func get_run_state_snapshot() -> Dictionary:
		return balances.duplicate(true)

	func finalize_reward_pick(_vision_boss_slot_id: String = "") -> Dictionary:
		return {"accepted": true, "applied": true}

	func apply_reward_pick_purchase(
		_slot_index: int,
		_choice: Dictionary,
		cost: int,
		effect_callback: Callable,
		rollback_callback: Callable = Callable()
	) -> Dictionary:
		if int(balances.get("muhon", 0)) < cost:
			return {"accepted": false, "applied": false, "reason": "insufficient_muhon"}
		if not bool(effect_callback.call()):
			if rollback_callback.is_valid():
				rollback_callback.call()
			return {"accepted": false, "applied": false, "reason": "effect_rejected"}
		balances["muhon"] = int(balances.get("muhon", 0)) - cost
		return {"accepted": true, "applied": true, "balances": balances.duplicate(true)}


class CaptureRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


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


class RewardCanvas:
	extends Node2D

	var reward_state: Object

	func _init(new_reward_state: Object) -> void:
		reward_state = new_reward_state

	func _draw() -> void:
		reward_state.draw(self, Vector2(GAME_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_reward_pick_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_reward_pick_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	LanguageSettings.set_test_locale_override("ko")
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("reward-pick capture directory creation failed: %d" % mkdir_error)
		quit(1)
		return
	if not await _capture_offer("four_card_reward_pick.png", _build_general_choices(), 0, output_dir, true):
		return
	if not await _capture_offer("vision_reward_pick.png", _build_vision_choices(), 0, output_dir):
		return
	LanguageSettings.set_test_locale_override("")
	print("tower_reward_pick_visual_qa: evidence=%s" % output_dir)
	print("tower_reward_pick_visual_qa: captures=3")
	print("tower_reward_pick_visual_qa: ok")
	quit(0)


func _capture_offer(
	file_name: String,
	choices: Array[Dictionary],
	selected_index: int,
	output_dir: String,
	capture_empty_after_purchase: bool = false
) -> bool:
	var flow := CaptureFlowOwner.new()
	var renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	var registry := CaptureRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": CaptureRuntimeState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_overlay_renderer": renderer,
		"runtime_perk_icon_renderer": icon_renderer,
	}
	var offer_builder := CaptureOfferBuilder.new()
	offer_builder.offer = {
		"accepted": true,
		"boss_slot_id": "floor_01_dalji",
		"vision_unlock_id": str(choices[0].get("id", "")) if str(choices[0].get("reward_pick_kind", "")) == "vision" else "",
		"choices": choices,
	}
	var reward_state := TowerRewardPickState.new()
	reward_state.set("_offer_builder", offer_builder)
	if not reward_state.start(CaptureOwner.new(), registry, Callable()):
		push_error("reward-pick visual fixture could not start")
		quit(1)
		return false
	reward_state.selected_index = selected_index
	reward_state.update(1.0)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := RewardCanvas.new(reward_state)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(file_name)
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE or image.save_png(output_path) != OK:
		push_error("reward-pick visual QA capture failed: %s" % output_path)
		quit(1)
		return false
	print("[TowerRewardPickVisualQA] %s" % output_path)
	if capture_empty_after_purchase:
		var original_rects: Array = reward_state.get_card_rects()
		reward_state.call("_purchase", 0)
		reward_state.update(1.0)
		var empty_model: Dictionary = reward_state.build_view_model()
		var empty_choices: Array = empty_model.get("choices", [])
		if (
			empty_choices.size() != 4
			or not bool((empty_choices[0] as Dictionary).get("reward_pick_empty", false))
			or bool((empty_choices[1] as Dictionary).get("reward_pick_empty", false))
			or (empty_model.get("card_rects", []) as Array) != original_rects
		):
			push_error("post-purchase visual fixture did not preserve one stable empty slot")
			quit(1)
			return false
		canvas.queue_redraw()
		for _frame_index in range(8):
			await process_frame
		var empty_image: Image = viewport.get_texture().get_image()
		var empty_output_path := output_dir.path_join("post_purchase_empty_slot.png")
		if (
			empty_image == null
			or empty_image.is_empty()
			or empty_image.get_size() != GAME_SIZE
			or empty_image.save_png(empty_output_path) != OK
		):
			push_error("post-purchase empty-slot capture failed: %s" % empty_output_path)
			quit(1)
			return false
		print("[TowerRewardPickVisualQA] %s" % empty_output_path)
	reward_state.reset()
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true


func _build_general_choices() -> Array[Dictionary]:
	var catalog := RuntimePerkCatalog.new()
	return [
		_finalize_choice({
			"id": "physique_power_training",
			"name": "완력 수련",
			"description": "공격력 +4%",
			"detail": "반복 수련으로 기본 공격력을 강화합니다.",
			"is_physique_training": true,
			"icon_color": Color(0.72, 0.34, 0.20),
		}, "training", 1),
		_finalize_choice(catalog.get_perk_data("common_swiftness"), "mugong", 2),
		_finalize_choice({
			"id": "perk_fusion",
			"name": "무공합일",
			"description": "보유 무공 두 개를 융합",
			"detail": "기존 무공합일 선택 화면으로 이동합니다.",
			"is_perk_fusion": true,
			"icon_color": Color(0.54, 0.28, 0.72),
		}, "fusion", 3),
		_finalize_choice(catalog.get_perk_data("megingjord"), "supreme", 5),
	]


func _build_vision_choices() -> Array[Dictionary]:
	var catalog := RuntimePerkCatalog.new()
	var vision := TowerAscentBossRewardCatalog.build_vision_choice("floor_01_dalji")
	vision["vision_swap_required"] = true
	vision["detail"] = "%s  %s" % [
		str(vision.get("detail", vision.get("description", ""))),
		TowerRewardPickLocalization.text("vision_swap"),
	]
	return [
		_finalize_choice(vision, "vision", 3),
		_finalize_choice({
			"id": "physique_guard_training",
			"name": "호신 수련",
			"description": "받는 피해 -3%",
			"detail": "반복 수련으로 방어 능력을 강화합니다.",
			"is_physique_training": true,
			"icon_color": Color(0.32, 0.52, 0.66),
		}, "training", 1),
		_finalize_choice(catalog.get_perk_data("common_swiftness"), "mugong", 2),
		_finalize_choice(catalog.get_perk_data("megingjord"), "supreme", 5),
	]


func _finalize_choice(source: Dictionary, kind: String, cost: int) -> Dictionary:
	var choice := source.duplicate(true)
	choice["reward_pick_kind"] = kind
	choice["reward_pick_cost"] = cost
	choice["reward_pick_price_text"] = TowerRewardPickLocalization.text(
		"price",
		{"amount": cost}
	)
	return choice
