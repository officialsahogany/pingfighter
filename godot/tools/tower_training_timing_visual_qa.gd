extends SceneTree

const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerTrainingTimingJudgmentPolicy := preload(
	"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
)
const TowerTrainingTimingState := preload(
	"res://scripts/tower_ascent/tower_training_timing_state.gd"
)
const BattleResources := preload(
	"res://scripts/resources/battle_resources.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_training_timing"
const TARGET_ACTION_ID := "training_stat:physique_move_speed"
const ALLOWED_TRAINING_IDS: Array[String] = [
	"physique_move_speed",
	"physique_storage",
	"physique_dash_distance",
	"physique_paddle_size",
	"physique_max_gauge",
	"physique_hit_gauge",
]
const TIER_SPECS: Array[Dictionary] = [
	{
		"kind": "critical",
		"multiplier": 1.5,
		"frames": [
			["gauge_running", -1],
			["stop_hitstop", 0],
			["hitstop_199ms", 199],
			["red_aura", 200],
			["strong_strike", 320],
			["contact", 620],
			["dummy_and_message", 900],
			["returned", 1800],
		],
	},
	{
		"kind": "great",
		"multiplier": 1.3,
		"frames": [
			["gauge_running", -1],
			["stop_blue_aura", 0],
			["windup", 180],
			["contact", 360],
			["contact_hitstop", 404],
			["dummy_and_message", 650],
			["recovery", 900],
			["returned", 1500],
		],
	},
	{
		"kind": "base",
		"multiplier": 1.0,
		"frames": [
			["gauge_running", -1],
			["stop_no_aura", 0],
			["windup", 180],
			["contact", 360],
			["contact_hitstop", 404],
			["dummy_and_message", 650],
			["recovery", 900],
			["returned", 1500],
		],
	},
]


class CaptureOwner:
	extends Node2D
	var current_stage := 4
	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class CaptureUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return ALLOWED_TRAINING_IDS.has(content_id)


class CaptureMythicItemRuntime:
	extends RefCounted
	var runtime_state: Object = null

	func _init(runtime_state_value: Object) -> void:
		runtime_state = runtime_state_value

	func refresh_runtime_perk_scaling(owner: Object, _registry: Object) -> void:
		var bonus := 0.0
		if runtime_state != null:
			bonus = float(runtime_state.get_physique_training_bonus("max_gauge_flat"))
		owner.set("special_gauge_max", 500.0 + bonus)

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		if runtime_state == null:
			return base_charge
		return base_charge * (
			1.0
			+ float(runtime_state.get_physique_training_bonus("hit_gauge_bonus_pct"))
			/ 100.0
		)

	func get_player_paddle_scale() -> float:
		return 1.0


class CaptureBattleResources:
	extends RefCounted
	var cache: Dictionary = {}

	func get_resource_cache() -> Dictionary:
		return cache


class CaptureRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class CaptureCanvas:
	extends Node2D
	var flow: Object = null
	var renderer := TowerAscentFlowRenderer.new()

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


var _failed := false
var _capture_count := 0
var _stats_same_frame_count := 0
var _dummy_bitmap_comparison_ok := false
var _gauge_bitmap_comparison_ok := false
var _critical_zone_readable := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("capture directory creation failed")
		return

	var original_conversion_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var owner := CaptureOwner.new()
	viewport.add_child(owner)
	var runtime_state := RuntimePerkState.new()
	var card_renderer := RuntimePerkOverlayRenderer.new()
	var registry := CaptureRegistry.new()
	var battle_resources := CaptureBattleResources.new()
	battle_resources.cache = _load_training_texture_cache()
	if battle_resources.cache.size() != 2:
		_fail("production Smasher idle/attack textures did not load")
		_finish_flags(original_conversion_flag)
		return
	registry.instances = {
		"runtime_perk_state": runtime_state,
		"tower_ascent_unlock_store": CaptureUnlockStore.new(),
		"runtime_perk_overlay_renderer": card_renderer,
		"mythic_item_runtime": CaptureMythicItemRuntime.new(runtime_state),
		"battle_resources": battle_resources,
	}
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active", true)
	flow.set("_phase", 1)
	flow.set("_node_modal_kind", "training")
	flow.set("_current_node_id", "training-timing-visual")
	flow.set("_map_seed", 417)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", registry)
	var run_state: Object = flow.get("_run_state")
	if not bool(run_state.begin("training-timing-visual-run", {"muhon": 30})):
		_fail("training visual run state did not begin")
		_finish_flags(original_conversion_flag)
		return
	flow.call("_open_node_modal")

	var canvas := CaptureCanvas.new()
	canvas.flow = flow
	viewport.add_child(canvas)
	var after_idle := await _capture_frame(
		viewport,
		canvas,
		output_dir.path_join("training_card_after_overlap_fix.png")
	)
	if after_idle == null:
		_fail("after-overlap card capture failed")
	else:
		_verify_card_text_budget(flow, card_renderer)
		_save_before_after_card_board(flow, after_idle, output_dir)
		await _capture_dummy_bitmap_and_fallback(
			viewport,
			canvas,
			flow,
			after_idle,
			output_dir
		)

	for tier_spec in TIER_SPECS:
		if _failed:
			break
		await _capture_tier_sequence(
			viewport,
			canvas,
			flow,
			card_renderer,
			output_dir,
			tier_spec
		)

	_finish_flags(original_conversion_flag)
	if _failed:
		quit(1)
		return
	print("tower_training_timing_visual_qa: evidence=%s" % output_dir)
	print("tower_training_timing_visual_qa: captures=%d" % _capture_count)
	print("tower_training_timing_visual_qa: tiers=3")
	print("tower_training_timing_visual_qa: strips=3")
	print("tower_training_timing_visual_qa: stats_same_frame=%d" % _stats_same_frame_count)
	print("tower_training_timing_visual_qa: card_comparison=ok")
	print("tower_training_timing_visual_qa: dummy_bitmap_and_fallback=%s" % (
		"ok" if _dummy_bitmap_comparison_ok else "failed"
	))
	print("tower_training_timing_visual_qa: gauge_bitmap_and_fallback=%s" % (
		"ok" if _gauge_bitmap_comparison_ok else "failed"
	))
	print("tower_training_timing_visual_qa: critical_zone_readable=%s" % (
		"ok" if _critical_zone_readable else "failed"
	))
	print("tower_training_timing_visual_qa: ok")
	quit(0)


func _capture_dummy_bitmap_and_fallback(
	viewport: SubViewport,
	canvas: CanvasItem,
	flow: Object,
	bitmap_image: Image,
	output_dir: String
) -> void:
	var renderer: Object = canvas.get("renderer")
	if renderer == null:
		_fail("training renderer was unavailable for dummy bitmap proof")
		return
	var bitmap_state: Dictionary = renderer.get_training_dummy_asset_debug_state()
	if (
		not bool(bitmap_state.get("loaded", false))
		or str(bitmap_state.get("render_mode", "")) != "bitmap"
		or Vector2i(bitmap_state.get("texture_size", Vector2i.ZERO)) != Vector2i(256, 256)
	):
		_fail("approved 256x256 dummy bitmap was not prewarmed for Vulkan capture")
		return
	renderer.debug_set_training_dummy_texture(null)
	var fallback_image := await _capture_frame(
		viewport,
		canvas,
		output_dir.path_join("training_dummy_procedural_fallback.png")
	)
	if fallback_image == null:
		_fail("procedural dummy fallback capture failed")
		return
	if str(renderer.get_training_dummy_asset_debug_state().get("render_mode", "")) != "procedural_fallback":
		_fail("forced missing texture did not select procedural fallback mode")
		return
	if bitmap_image.get_data() == fallback_image.get_data():
		_fail("bitmap and procedural fallback captures must differ visibly")
		return
	if not _save_dummy_bitmap_comparison(
		flow,
		bitmap_image,
		fallback_image,
		output_dir
	):
		_fail("dummy bitmap/fallback comparison board save failed")
		return
	renderer.prewarm_training_dummy_asset()
	if not bool(renderer.get_training_dummy_asset_debug_state().get("loaded", false)):
		_fail("dummy bitmap prewarm did not recover after forced fallback")
		return
	_dummy_bitmap_comparison_ok = true


func _save_dummy_bitmap_comparison(
	flow: Object,
	bitmap_image: Image,
	fallback_image: Image,
	output_dir: String
) -> bool:
	var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var stage_rect: Rect2 = model.get("training_stage_rect", Rect2())
	var crop_rect := Rect2i(stage_rect.grow(10.0)).intersection(
		Rect2i(Vector2i.ZERO, bitmap_image.get_size())
	)
	if not crop_rect.has_area():
		return false
	var bitmap_crop := bitmap_image.get_region(crop_rect)
	var fallback_crop := fallback_image.get_region(crop_rect)
	bitmap_crop.convert(Image.FORMAT_RGBA8)
	fallback_crop.convert(Image.FORMAT_RGBA8)
	if bitmap_crop.save_png(output_dir.path_join("training_dummy_bitmap_idle.png")) != OK:
		return false
	if fallback_crop.save_png(output_dir.path_join("training_dummy_fallback_idle.png")) != OK:
		return false
	var gap := 12
	var board := Image.create(
		bitmap_crop.get_width() + gap + fallback_crop.get_width(),
		maxi(bitmap_crop.get_height(), fallback_crop.get_height()),
		false,
		Image.FORMAT_RGBA8
	)
	board.fill(Color(0.035, 0.025, 0.018, 1.0))
	board.blit_rect(
		bitmap_crop,
		Rect2i(Vector2i.ZERO, bitmap_crop.get_size()),
		Vector2i.ZERO
	)
	board.blit_rect(
		fallback_crop,
		Rect2i(Vector2i.ZERO, fallback_crop.get_size()),
		Vector2i(bitmap_crop.get_width() + gap, 0)
	)
	return board.save_png(
		output_dir.path_join("training_dummy_bitmap_vs_procedural_fallback.png")
	) == OK


func _capture_tier_sequence(
	viewport: SubViewport,
	canvas: CanvasItem,
	flow: Object,
	card_renderer: Object,
	output_dir: String,
	tier_spec: Dictionary
) -> void:
	var kind := str(tier_spec.get("kind", "base"))
	var clock_base := 10000 + TIER_SPECS.find(tier_spec) * 3000
	flow.set_training_stage_clock_msec_for_tests(clock_base)
	var card_rect := _action_rect(flow, TARGET_ACTION_ID)
	if not card_rect.has_area():
		_fail("%s target card rect missing" % kind)
		return
	var top_corner := card_rect.position + Vector2(2.0, 2.0)
	flow.handle_input(_mouse_button(true, top_corner))
	flow.handle_input(_mouse_button(false, top_corner))
	var timing_debug: Dictionary = flow.get_training_timing_debug_state()
	if not bool(timing_debug.get("running", false)):
		_fail("%s timing gauge did not open" % kind)
		return
	var stop_position := _stop_position_for_tier(timing_debug, kind)
	var stop_elapsed := int(roundf(
		stop_position * float(TowerTrainingTimingState.FULL_CYCLE_MSEC) * 0.5
	))
	var stop_clock := int(timing_debug.get("started_msec", clock_base)) + stop_elapsed
	flow.set_training_stage_clock_msec_for_tests(stop_clock)
	flow.update_selective(0.016, null)
	var frames: Array[Image] = []
	var running_image := await _capture_frame(
		viewport,
		canvas,
		output_dir.path_join("training_timing_%s_00_gauge_running.png" % kind)
	)
	if running_image == null:
		_fail("%s running gauge capture failed" % kind)
		return
	if kind == "critical":
		_verify_training_timing_critical_zone_readable(flow, running_image, output_dir)
		if _failed:
			return
		await _capture_timing_gauge_bitmap_and_fallback(
			viewport,
			canvas,
			flow,
			running_image,
			output_dir
		)
		if _failed:
			return
	frames.append(running_image)

	var before_values: Array = card_renderer.get_tower_training_stats_snapshot_for_tests().get(
		"values",
		[]
	)
	flow.handle_input(_mouse_button(true, Vector2(8.0, 8.0)))
	flow.handle_input(_mouse_button(false, Vector2(8.0, 8.0)))
	var after_values: Array = card_renderer.get_tower_training_stats_snapshot_for_tests().get(
		"values",
		[]
	)
	if var_to_bytes(after_values) == var_to_bytes(before_values):
		_fail("%s judgment did not refresh canonical stats in the stop frame" % kind)
		return
	_stats_same_frame_count += 1
	var history: Array = flow.get_training_history()
	var record: Dictionary = history.back() if not history.is_empty() else {}
	if (
		str(record.get("timing_judgment_kind", "")) != kind
		or not is_equal_approx(
			float(record.get("effect_multiplier", 0.0)),
			float(tier_spec.get("multiplier", 0.0))
		)
	):
		_fail("%s authoritative result did not match its captured tier" % kind)
		return
	var strike_debug: Dictionary = flow.get_training_stage_presentation_debug_state()
	var strike_start := int(strike_debug.get("started_msec", stop_clock))
	var frame_specs: Array = tier_spec.get("frames", [])
	for frame_index in range(1, frame_specs.size()):
		var frame_spec: Array = frame_specs[frame_index]
		var frame_name := str(frame_spec[0])
		var elapsed_msec := int(frame_spec[1])
		flow.set_training_stage_clock_msec_for_tests(strike_start + elapsed_msec)
		flow.update_selective(0.016, null)
		var image := await _capture_frame(
			viewport,
			canvas,
			output_dir.path_join("training_timing_%s_%02d_%s.png" % [
				kind,
				frame_index,
				frame_name,
			])
		)
		if image == null:
			_fail("%s %s capture failed" % [kind, frame_name])
			return
		frames.append(image)
	if not _save_frame_strip(
		frames,
		output_dir.path_join("training_timing_%s_sequence_strip.png" % kind)
	):
		_fail("%s sequence strip save failed" % kind)


func _capture_timing_gauge_bitmap_and_fallback(
	viewport: SubViewport,
	canvas: CanvasItem,
	flow: Object,
	bitmap_image: Image,
	output_dir: String
) -> void:
	var renderer: Object = canvas.get("renderer")
	if renderer == null:
		_fail("training renderer was unavailable for timing-gauge bitmap proof")
		return
	var bitmap_state: Dictionary = renderer.get_training_timing_gauge_asset_debug_state()
	if (
		not bool(bitmap_state.get("loaded", false))
		or str(bitmap_state.get("render_mode", "")) != "bitmap"
		or Vector2i(bitmap_state.get("frame_size", Vector2i.ZERO)) != Vector2i(1593, 156)
		or Vector2i(bitmap_state.get("tick_size", Vector2i.ZERO)) != Vector2i(123, 517)
		or Vector2i(bitmap_state.get("pointer_size", Vector2i.ZERO)) != Vector2i(218, 918)
	):
		_fail("approved timing-gauge bitmap set was not prewarmed for Vulkan capture")
		return
	renderer.debug_set_training_timing_gauge_textures(null, null, null)
	var fallback_image := await _capture_frame(
		viewport,
		canvas,
		output_dir.path_join("training_timing_gauge_procedural_fallback.png")
	)
	if fallback_image == null:
		_fail("procedural timing-gauge fallback capture failed")
		return
	if (
		str(renderer.get_training_timing_gauge_asset_debug_state().get("render_mode", ""))
		!= "procedural_fallback"
	):
		_fail("forced missing timing-gauge textures did not select procedural fallback")
		return
	if bitmap_image.get_data() == fallback_image.get_data():
		_fail("bitmap and procedural timing-gauge captures must differ visibly")
		return
	if not _save_timing_gauge_bitmap_comparison(
		flow,
		bitmap_image,
		fallback_image,
		output_dir
	):
		_fail("timing-gauge bitmap/fallback comparison board save failed")
		return
	renderer.prewarm_training_timing_gauge_assets()
	if not bool(renderer.get_training_timing_gauge_asset_debug_state().get("loaded", false)):
		_fail("timing-gauge bitmap prewarm did not recover after forced fallback")
		return
	_gauge_bitmap_comparison_ok = true


func _save_timing_gauge_bitmap_comparison(
	flow: Object,
	bitmap_image: Image,
	fallback_image: Image,
	output_dir: String
) -> bool:
	var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var content_scale := maxf(0.001, float(model.get("content_scale", 1.0)))
	var stage_rect: Rect2 = model.get("training_stage_rect", Rect2())
	var gauge_rect := Rect2(
		stage_rect.position + Vector2(24.0, 11.0) * content_scale,
		Vector2(stage_rect.size.x - 48.0 * content_scale, 29.0 * content_scale)
	)
	var crop_rect := Rect2i(gauge_rect.grow(14.0 * content_scale)).intersection(
		Rect2i(Vector2i.ZERO, bitmap_image.get_size())
	)
	if not crop_rect.has_area():
		return false
	var bitmap_crop := bitmap_image.get_region(crop_rect)
	var fallback_crop := fallback_image.get_region(crop_rect)
	bitmap_crop.convert(Image.FORMAT_RGBA8)
	fallback_crop.convert(Image.FORMAT_RGBA8)
	if bitmap_crop.save_png(output_dir.path_join("training_timing_gauge_bitmap.png")) != OK:
		return false
	if fallback_crop.save_png(output_dir.path_join("training_timing_gauge_fallback.png")) != OK:
		return false
	var gap := 12
	var board := Image.create(
		bitmap_crop.get_width() + gap + fallback_crop.get_width(),
		maxi(bitmap_crop.get_height(), fallback_crop.get_height()),
		false,
		Image.FORMAT_RGBA8
	)
	board.fill(Color(0.035, 0.025, 0.018, 1.0))
	board.blit_rect(
		bitmap_crop,
		Rect2i(Vector2i.ZERO, bitmap_crop.get_size()),
		Vector2i.ZERO
	)
	board.blit_rect(
		fallback_crop,
		Rect2i(Vector2i.ZERO, fallback_crop.get_size()),
		Vector2i(bitmap_crop.get_width() + gap, 0)
	)
	return board.save_png(
		output_dir.path_join("training_timing_gauge_bitmap_vs_fallback.png")
	) == OK


func _verify_training_timing_critical_zone_readable(
	flow: Object,
	image: Image,
	output_dir: String
) -> void:
	var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var content_scale := maxf(0.001, float(model.get("content_scale", 1.0)))
	var stage_rect: Rect2 = model.get("training_stage_rect", Rect2())
	var gauge_rect := Rect2(
		stage_rect.position + Vector2(24.0, 11.0) * content_scale,
		Vector2(stage_rect.size.x - 48.0 * content_scale, 29.0 * content_scale)
	)
	var track_rect := gauge_rect.grow(-5.0 * content_scale)
	var timing_debug: Dictionary = flow.get_training_timing_debug_state()
	var target := clampf(float(timing_debug.get("target_position", 0.5)), 0.0, 1.0)
	var cell_width := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(
		float(timing_debug.get("luck_percent", 2.0))
	)
	var critical_rect := Rect2(
		Vector2(
			track_rect.position.x + track_rect.size.x * (target - cell_width * 0.5),
			track_rect.position.y
		),
		Vector2(track_rect.size.x * cell_width, track_rect.size.y)
	)
	var sample_rect := Rect2i(critical_rect).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	if not sample_rect.has_area():
		_fail("critical-zone sample rect was outside the Vulkan capture")
		return
	var red_pixel_count := 0
	for y in range(sample_rect.position.y, sample_rect.end.y):
		for x in range(sample_rect.position.x, sample_rect.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.r >= 0.34 and pixel.r > pixel.g * 1.35 and pixel.r > pixel.b * 1.35:
				red_pixel_count += 1
	if red_pixel_count < 6:
		_fail("2 percent critical zone was hidden by the bitmap frame")
		return
	var proof_rect := sample_rect.grow(10).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	var proof := image.get_region(proof_rect)
	proof.resize(proof.get_width() * 8, proof.get_height() * 8, Image.INTERPOLATE_NEAREST)
	if proof.save_png(output_dir.path_join("training_timing_critical_zone_8x.png")) != OK:
		_fail("critical-zone readability proof save failed")
		return
	_critical_zone_readable = true


func _stop_position_for_tier(timing_debug: Dictionary, kind: String) -> float:
	var target := float(timing_debug.get("target_position", 0.5))
	var cell_width := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(
		float(timing_debug.get("luck_percent", 20.0))
	)
	if kind == "critical":
		return target
	if kind == "great":
		return target + cell_width if target + cell_width <= 1.0 else target - cell_width
	return 0.0 if target >= 0.5 else 1.0


func _verify_card_text_budget(flow: Object, card_renderer: Object) -> void:
	var action := _action(flow, TARGET_ACTION_ID)
	var rect := _action_rect(flow, TARGET_ACTION_ID)
	var production_layout: Dictionary = card_renderer.build_tower_node_card_text_layout(
		action,
		rect
	)
	if (
		int(production_layout.get("appended_description_row_count", -1)) != 1
		or int(production_layout.get("appended_bonus_badge_row_count", -1)) != 1
	):
		_fail("production card did not retain one effect row plus one footer row")
		return
	var long_action := action.duplicate(true)
	var choice: Dictionary = long_action.get("payload", {}).get("choice", {})
	choice["description"] = "수련 효과와 실제 적용값을 확인하는 가장 긴 설명 문구를 세 행 예산으로 정확하게 검증합니다 반복 문장"
	var long_layout: Dictionary = card_renderer.build_tower_node_card_text_layout(
		long_action,
		rect
	)
	if (
		int(long_layout.get("appended_description_row_count", -1)) != 2
		or int(long_layout.get("appended_bonus_badge_row_count", -1)) != 1
		or int(long_layout.get("appended_text_row_count", -1)) != 3
	):
		_fail("GRT-021 live card did not preserve the complete 2+1 row budget: description=%d badge=%d total=%d" % [
			int(long_layout.get("appended_description_row_count", -1)),
			int(long_layout.get("appended_bonus_badge_row_count", -1)),
			int(long_layout.get("appended_text_row_count", -1)),
		])


func _save_before_after_card_board(
	flow: Object,
	after_image: Image,
	output_dir: String
) -> void:
	var before_path := _before_card_path_from_args()
	if before_path.is_empty() or not FileAccess.file_exists(before_path):
		_fail("before-card Vulkan capture path was not supplied")
		return
	var before_image := Image.load_from_file(before_path)
	if before_image == null or before_image.is_empty():
		_fail("before-card Vulkan capture could not be loaded")
		return
	var card_rect := _action_rect(flow, TARGET_ACTION_ID).grow(10.0)
	var crop_rect := Rect2i(card_rect).intersection(
		Rect2i(Vector2i.ZERO, after_image.get_size())
	)
	var before_crop := before_image.get_region(crop_rect)
	var after_crop := after_image.get_region(crop_rect)
	before_crop.convert(Image.FORMAT_RGBA8)
	after_crop.convert(Image.FORMAT_RGBA8)
	before_crop.save_png(output_dir.path_join("training_card_overlap_before.png"))
	after_crop.save_png(output_dir.path_join("training_card_overlap_after.png"))
	var gap := 12
	var board := Image.create(
		before_crop.get_width() + gap + after_crop.get_width(),
		maxi(before_crop.get_height(), after_crop.get_height()),
		false,
		Image.FORMAT_RGBA8
	)
	board.fill(Color(0.035, 0.025, 0.018, 1.0))
	board.blit_rect(
		before_crop,
		Rect2i(Vector2i.ZERO, before_crop.get_size()),
		Vector2i.ZERO
	)
	board.blit_rect(
		after_crop,
		Rect2i(Vector2i.ZERO, after_crop.get_size()),
		Vector2i(before_crop.get_width() + gap, 0)
	)
	if board.save_png(
		output_dir.path_join("training_card_overlap_before_after.png")
	) != OK:
		_fail("before/after card comparison save failed")


func _before_card_path_from_args() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--before-card="):
			return argument.trim_prefix("--before-card=").strip_edges()
	return ""


func _capture_frame(
	viewport: SubViewport,
	canvas: CanvasItem,
	path: String
) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		return null
	_capture_count += 1
	return image


func _save_frame_strip(frames: Array[Image], path: String) -> bool:
	if frames.size() != 8:
		return false
	var cell_size := Vector2i(VIEW_SIZE.x / 4, VIEW_SIZE.y / 4)
	var strip := Image.create(
		cell_size.x * 4,
		cell_size.y * 2,
		false,
		Image.FORMAT_RGBA8
	)
	strip.fill(Color(0.025, 0.02, 0.016, 1.0))
	for index in range(frames.size()):
		var thumbnail := frames[index].duplicate()
		thumbnail.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		thumbnail.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			thumbnail,
			Rect2i(Vector2i.ZERO, thumbnail.get_size()),
			Vector2i(index % 4, index / 4) * cell_size
		)
	return strip.save_png(path) == OK


func _load_training_texture_cache() -> Dictionary:
	var idle := _load_source_texture(BattleResources.SMASHER_IDLE_SHEET_PATH)
	var attack := _load_source_texture(BattleResources.SMASHER_ATTACK_RIGHT_SHEET_PATH)
	if idle == null or attack == null:
		return {}
	return {
		"player_idle_back_sheet": idle,
		"player_attack_right_sheet": attack,
	}


func _load_source_texture(resource_path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _action_rect(flow: Object, action_id: String) -> Rect2:
	var model: Dictionary = flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var actions: Array = model.get("actions", [])
	var rects: Array = model.get("action_rects", [])
	for index in range(actions.size()):
		if str((actions[index] as Dictionary).get("id", "")) == action_id:
			return rects[index] as Rect2
	return Rect2()


func _action(flow: Object, action_id: String) -> Dictionary:
	for action_value in flow.get_node_modal_view_model(Vector2(VIEW_SIZE)).get(
		"actions",
		[]
	):
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")) == action_id
		):
			return action_value as Dictionary
	return {}


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	return event


func _finish_flags(original_conversion_flag: bool) -> void:
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)


func _fail(message: String) -> void:
	_failed = true
	push_error("tower_training_timing_visual_qa: %s" % message)
