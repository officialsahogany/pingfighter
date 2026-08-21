extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleSceneOwnerReader := preload(
	"res://scripts/core/battle_scene_owner_reader.gd"
)
const MainScene := preload("res://scenes/main.tscn")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentScreenSpaceSurfacePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_noncombat_return_selector"
const CAPTURE_SIZE := Vector2i(2020, 1246)
const INITIAL_ROUTE_OUTPUT := "stage1_initial_route_clean.png"
const TRAINING_MODAL_OUTPUT := "training_node_modal_no_previous_boss.png"
const ROUTE_SELECTOR_OUTPUT := "training_return_route_clean.png"
const COMBAT_RETURN_OUTPUT := "combat_return_restored.png"
const NONTOWER_OUTPUT := "nontower_campaign_unchanged.png"
const TRAINING_MAP_SEED := 5
const INITIAL_PLAYER_POS := Vector2(230.0, 680.0)
const BOSS_SENTINEL_RECT := Rect2(330.0, 90.0, 80.0, 80.0)
const STAGE_OBJECT_SENTINEL_RECT := Rect2(90.0, 250.0, 72.0, 72.0)
const SKILL_RAIL_SENTINEL_RECT := Rect2(112.0, 330.0, 64.0, 64.0)
const MIN_SELECTOR_CHANGED_PIXELS := 120
const MIN_SELECTOR_BRIGHT_PIXELS := 40
const MIN_COMBAT_SENTINEL_PIXELS := 900
const MIN_BORDER_CHANGED_PIXELS := 800
const MIN_PLAYER_CHANGED_PIXELS := 120


class InstrumentedPlayfieldDrawer:
	extends RefCounted

	var production: Object
	var full_draw_calls := 0
	var route_border_draw_calls := 0
	var route_player_draw_calls := 0
	var route_selector_ball_draw_calls := 0
	var draw_route_border := true
	var draw_route_player := true

	func _init(value: Object) -> void:
		production = value

	func reset_counts() -> void:
		full_draw_calls = 0
		route_border_draw_calls = 0
		route_player_draw_calls = 0
		route_selector_ball_draw_calls = 0

	func draw(
		canvas: CanvasItem,
		registry: Object,
		shake_offset: Vector2,
		width: float,
		height: float,
		pillar_width: float
	) -> void:
		full_draw_calls += 1
		if production != null and production.has_method("draw"):
			production.draw(
				canvas,
				registry,
				shake_offset,
				width,
				height,
				pillar_width
			)
		# Exact-color QA sentinels are emitted only when the stale full battle
		# composition (previous boss and stage objects) is allowed through.
		canvas.draw_rect(BOSS_SENTINEL_RECT, Color.MAGENTA, true)
		canvas.draw_rect(STAGE_OBJECT_SENTINEL_RECT, Color.LIME, true)

	func draw_tower_route_playfield_border(
		canvas: CanvasItem,
		width: float,
		height: float
	) -> void:
		route_border_draw_calls += 1
		if (
			draw_route_border
			and production != null
			and production.has_method("draw_tower_route_playfield_border")
		):
			production.draw_tower_route_playfield_border(canvas, width, height)

	func draw_tower_route_player(
		canvas: CanvasItem,
		registry: Object,
		shake_offset: Vector2
	) -> void:
		route_player_draw_calls += 1
		if (
			draw_route_player
			and production != null
			and production.has_method("draw_tower_route_player")
		):
			production.draw_tower_route_player(canvas, registry, shake_offset)

	func draw_tower_route_selector_ball(
		canvas: CanvasItem,
		registry: Object,
		shake_offset: Vector2,
		width: float,
		height: float
	) -> void:
		route_selector_ball_draw_calls += 1
		if (
			production != null
			and production.has_method("draw_tower_route_selector_ball")
		):
			production.draw_tower_route_selector_ball(
				canvas,
				registry,
				shake_offset,
				width,
				height
			)


class BossSkillRailSentinelRenderer:
	extends RefCounted

	var draw_calls := 0

	func reset_counts() -> void:
		draw_calls = 0

	func draw(canvas: CanvasItem, _context: Dictionary) -> void:
		draw_calls += 1
		canvas.draw_rect(SKILL_RAIL_SENTINEL_RECT, Color.CYAN, true)


class BaselineEnergyRendererAdapter:
	extends RefCounted

	var production: Object

	func _init(value: Object) -> void:
		production = value

	func prewarm_assets_step() -> bool:
		return bool(production.prewarm_assets_step())

	func prewarm_runtime_nodes(owner: Object = null) -> void:
		production.prewarm_runtime_nodes(owner)

	func prewarm_runtime_nodes_step(owner: Object = null) -> bool:
		return bool(production.prewarm_runtime_nodes_step(owner))

	func clear() -> void:
		production.clear()

	func hide_node_fx() -> void:
		production.hide_node_fx()

	func draw(
		canvas: CanvasItem,
		pos: Vector2,
		boost_charging_active: bool,
		ball_vel: Vector2 = Vector2.ZERO,
		node_fx_layout: Dictionary = {},
		hit_pulse_event: Dictionary = {},
		skill_fx_mode: String = "",
		enable_node_fx: bool = true,
		fx_lod_scale: float = 1.0,
		_visual_alpha: float = 1.0
	) -> void:
		production.draw(
			canvas,
			pos,
			boost_charging_active,
			ball_vel,
			node_fx_layout,
			hit_pulse_event,
			skill_fx_mode,
			enable_node_fx,
			fx_lod_scale
		)


class BaselineOverdriveRendererAdapter:
	extends RefCounted

	var production: Object

	func _init(value: Object) -> void:
		production = value

	func clear() -> void:
		production.clear()

	func draw(
		canvas: CanvasItem,
		pos: Vector2,
		fx: Dictionary,
		ball_vel: Vector2,
		lod_scale: float,
		_render_alpha: float = 1.0
	) -> void:
		production.draw(canvas, pos, fx, ball_vel, lod_scale)


class BaselineStatusOverlayRendererAdapter:
	extends RefCounted

	var production: Object

	func _init(value: Object) -> void:
		production = value

	func clear() -> void:
		production.clear()

	func draw(
		canvas: CanvasItem,
		pos: Vector2,
		context: Dictionary,
		ball_render_radius: float,
		_render_alpha: float = 1.0
	) -> void:
		production.draw(canvas, pos, context, ball_render_radius)


class DelegatingRegistry:
	extends RefCounted

	var base: Object
	var instrumented_playfield: Object
	var tower_flow: Object
	var boss_skill_rail: Object

	func _init(
		base_registry: Object,
		playfield: Object,
		flow: Object,
		rail: Object
	) -> void:
		base = base_registry
		instrumented_playfield = playfield
		tower_flow = flow
		boss_skill_rail = rail

	func get_instance(key: String) -> Variant:
		if key == "battle_playfield_scene_drawer":
			return instrumented_playfield
		if key == "tower_ascent_flow_owner":
			return tower_flow
		if key == "stage1_dalji_boss_skill_hud_renderer":
			return boss_skill_rail
		return base.get_instance(key) if base != null and base.has_method("get_instance") else null

	func get_cached_instance(key: String) -> Variant:
		if key == "battle_playfield_scene_drawer":
			return instrumented_playfield
		if key == "tower_ascent_flow_owner":
			return tower_flow
		if key == "stage1_dalji_boss_skill_hud_renderer":
			return boss_skill_rail
		return (
			base.get_cached_instance(key)
			if base != null and base.has_method("get_cached_instance")
			else null
		)


var _main_node: Node = null
var _capture_viewport: SubViewport = null
var _base_registry: Object = null
var _ball_renderer: Object = null
var _baseline_energy_renderer: Object = null
var _baseline_overdrive_renderer: Object = null
var _baseline_status_overlay_renderer: Object = null
var _failure_message := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower noncombat return selector QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower noncombat return selector QA requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_release_test_input()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	DisplayServer.window_set_title("Tower route screen cleanup QA")
	if not _prepare_selection_state():
		_fail("GameSelectionState was unavailable")
		return

	_main_node = MainScene.instantiate()
	_install_baseline_ball_renderer_adapters(_main_node)
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = CAPTURE_SIZE
	_capture_viewport.transparent_bg = false
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_capture_viewport)
	_capture_viewport.add_child(_main_node)
	for _frame in range(4):
		await process_frame
	_prepare_battle_scene(_main_node)
	_main_node.set_process(false)
	_main_node.set_physics_process(false)
	for _frame in range(2):
		await process_frame

	_base_registry = _main_node.get("gameplay_modules")
	var flow: Object = TowerAscentFlowOwner.new()
	if _base_registry == null or flow == null:
		_fail("live battle scene did not expose the tower flow and gameplay registry")
		return
	var production_playfield: Variant = _base_registry.get_instance(
		"battle_playfield_scene_drawer"
	)
	if not (typeof(production_playfield) == TYPE_OBJECT and is_instance_valid(production_playfield)):
		_fail("production playfield drawer was unavailable")
		return
	# The ordinary boot warmup is skipped by this harness. Materialize the exact
	# modules consumed by the cached-only retained-arena draw path before capture.
	for module_key in [
		"stage1_pillar_ui_renderer",
		"stage1_actor_renderer",
		"stage1_dalji_boss_skill_cooldown_state",
		"tower_ascent_flow_owner",
	]:
		_base_registry.get_instance(module_key)
	var instrumented := InstrumentedPlayfieldDrawer.new(production_playfield)
	var boss_skill_rail := BossSkillRailSentinelRenderer.new()
	var registry := DelegatingRegistry.new(
		_base_registry,
		instrumented,
		flow,
		boss_skill_rail
	)
	_main_node.set("gameplay_modules", registry)

	if not bool(flow.begin_vertical_slice(
		_main_node,
		Callable(),
		{
			"registry": registry,
			"run_id": "tower-route-screen-cleanup-visual-qa",
			"current_stage": 1,
			"map_seed": TRAINING_MAP_SEED,
			"node_modal_kind": "training",
			"run_state": {"chance_gems": 2, "gold": 0, "muhon": 120},
		}
	)):
		_fail("live battle scene could not begin the deterministic Stage 1 training route")
		return
	print("[TowerNoncombatReturnSelectorQA] initial_phase=%s targets=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_route_aim_targets()),
	])
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create route cleanup QA capture directory")
		return

	# The initial post-combat route has no retained room. This is the exact Stage
	# 1 balloon/boss leak leg that used to fall back to the full battle draw.
	instrumented.reset_counts()
	boss_skill_rail.reset_counts()
	var initial_image := await _capture_current_frame(
		output_dir.path_join(INITIAL_ROUTE_OUTPUT)
	)
	if initial_image == null:
		return
	var initial_border_calls := instrumented.route_border_draw_calls
	var initial_player_calls := instrumented.route_player_draw_calls
	var initial_full_calls := instrumented.full_draw_calls
	var playfield_crop := _game_rect_to_capture(
		_main_node,
		Rect2(Vector2.ZERO, Vector2(760.0, 750.0)),
		initial_image
	)
	instrumented.draw_route_border = false
	var border_hidden_image := await _capture_current_frame("")
	instrumented.draw_route_border = true
	instrumented.draw_route_player = false
	var player_hidden_image := await _capture_current_frame("")
	instrumented.draw_route_player = true
	if border_hidden_image == null or player_hidden_image == null:
		return
	var border_changed_pixels := _count_changed_border_pixels(
		initial_image,
		border_hidden_image,
		playfield_crop
	)
	var player_crop := _game_rect_to_capture(
		_main_node,
		Rect2(INITIAL_PLAYER_POS - Vector2(100.0, 92.0), Vector2(200.0, 162.0)),
		initial_image
	)
	var player_changed_pixels := _count_changed_pixels(
		initial_image,
		player_hidden_image,
		player_crop
	)
	var initial_boss_pixels := _count_magenta_pixels(
		initial_image,
		_game_rect_to_capture(_main_node, BOSS_SENTINEL_RECT, initial_image)
	)
	var initial_stage_object_pixels := _count_lime_pixels(
		initial_image,
		_game_rect_to_capture(_main_node, STAGE_OBJECT_SENTINEL_RECT, initial_image)
	)
	var initial_skill_rail_pixels := _count_cyan_pixels(initial_image)
	print("[TowerRouteCleanupQA] initial full=%d border_calls=%d player_calls=%d border_pixels=%d player_pixels=%d boss_pixels=%d stage_object_pixels=%d skill_rail_calls=%d skill_rail_pixels=%d" % [
		initial_full_calls,
		initial_border_calls,
		initial_player_calls,
		border_changed_pixels,
		player_changed_pixels,
		initial_boss_pixels,
		initial_stage_object_pixels,
		boss_skill_rail.draw_calls,
		initial_skill_rail_pixels,
	])
	if initial_full_calls != 0 or initial_boss_pixels != 0 or initial_stage_object_pixels != 0:
		_fail("initial Stage 1 route retained the stale boss/stage-object composition")
		return
	if boss_skill_rail.draw_calls != 0 or initial_skill_rail_pixels != 0:
		_fail("initial Stage 1 route retained the Dalji boss-skill rail")
		return
	if initial_border_calls <= 0 or border_changed_pixels < MIN_BORDER_CHANGED_PIXELS:
		_fail("initial Stage 1 route border pixel delta was below threshold: %d < %d" % [border_changed_pixels, MIN_BORDER_CHANGED_PIXELS])
		return
	if initial_player_calls <= 0 or player_changed_pixels < MIN_PLAYER_CHANGED_PIXELS:
		_fail("initial Stage 1 route player pixel delta was below threshold: %d < %d" % [player_changed_pixels, MIN_PLAYER_CHANGED_PIXELS])
		return

	if not _enter_target_node(flow, "training"):
		_fail("live route did not arrive at the training node: phase=%s kind=%s" % [
			str(flow.get_phase_name()),
			str(flow.get_node_modal_kind()),
		])
		return
	if str(flow.get_phase_name()) != "NODE_MODAL":
		_fail("training arrival did not remain in NODE_MODAL")
		return
	print("[TowerNoncombatReturnSelectorQA] phase=%s retained=%s playfield_flow=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_retained_noncombat_node_background_kind()),
		str(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			str(flow.get_phase_name())
		)),
	])

	instrumented.reset_counts()
	var modal_image := await _capture_current_frame(
		output_dir.path_join(TRAINING_MODAL_OUTPUT)
	)
	if modal_image == null:
		return
	if instrumented.full_draw_calls != 0:
		_fail("training NODE_MODAL called the stale full battle playfield")
		return

	if not _finish_node_work_through_pointer(flow):
		_fail("training end-work pointer route was not consumed")
		return
	if (
		str(flow.get_phase_name()) != "ROUTE_AIM"
		or str(flow.get_retained_noncombat_node_background_kind()) != "training"
	):
		_fail("training return state mismatch: phase=%s retained=%s" % [
			str(flow.get_phase_name()),
			str(flow.get_retained_noncombat_node_background_kind()),
		])
		return
	print("[TowerNoncombatReturnSelectorQA] phase=%s retained=%s playfield_flow=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_retained_noncombat_node_background_kind()),
		str(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			str(flow.get_phase_name())
		)),
	])

	flow.update_selective(
		TowerAscentTuning.TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS,
		_main_node
	)
	var route_serve_runtime: Object = flow.get("_route_serve_runtime")
	if route_serve_runtime == null or not route_serve_runtime.has_method("_serve_live_ball"):
		_fail("production route-serve runtime was unavailable")
		return
	route_serve_runtime.call("_serve_live_ball")
	print("[TowerNoncombatReturnSelectorQA] launch_route=production_route_serve_runtime._serve_live_ball")
	for _step in range(11):
		flow.update_selective(1.0 / 60.0, _main_node)
	var round_state: Object = registry.get_instance("round_flow_state")
	print("[TowerNoncombatReturnSelectorQA] launch_state ball_active=%s waiting=%s selector_launched=%s" % [
		str(BattleSceneOwnerReader.get_value(_main_node, "ball_active", false)),
		str(round_state.is_waiting_for_serve() if round_state != null else "missing"),
		str(flow.is_selector_launched()),
	])
	if not bool(BattleSceneOwnerReader.get_value(_main_node, "ball_active", false)):
		_fail("training return selector did not launch the production ball")
		return
	var ball_pos := BattleSceneOwnerReader.get_vector2(
		_main_node,
		"ball_pos",
		Vector2.ZERO
	)
	if str(flow.get_phase_name()) != "ROUTE_AIM":
		_fail("selector resolved before the requested in-flight pixel frame")
		return
	if not bool(flow.is_selector_launched()):
		_fail("training return selector did not remain in flight for the pixel frame")
		return

	instrumented.reset_counts()
	var route_output := output_dir.path_join(ROUTE_SELECTOR_OUTPUT)
	var route_image := await _capture_current_frame(route_output)
	if route_image == null:
		return
	var route_full_draw_calls := instrumented.full_draw_calls
	var route_selector_calls := instrumented.route_selector_ball_draw_calls
	var sentinel_crop := _game_rect_to_capture(
		_main_node,
		BOSS_SENTINEL_RECT,
		route_image
	)
	var route_sentinel_pixels := _count_magenta_pixels(route_image, sentinel_crop)
	var route_stage_object_pixels := _count_lime_pixels(
		route_image,
		_game_rect_to_capture(_main_node, STAGE_OBJECT_SENTINEL_RECT, route_image)
	)
	var route_skill_rail_pixels := _count_cyan_pixels(route_image)
	_main_node.set("ball_active", false)
	var hidden_image := await _capture_current_frame("")
	_main_node.set("ball_active", true)
	if hidden_image == null:
		return
	var selector_crop := _selector_crop(_main_node, route_image, ball_pos)
	var selector_changed_pixels := _count_changed_pixels(
		route_image,
		hidden_image,
		selector_crop
	)
	var selector_bright_pixels := _count_changed_bright_pixels(
		route_image,
		hidden_image,
		selector_crop
	)
	print("[TowerRouteCleanupQA] selector_pos=%s crop=%s changed_pixels=%d bright_pixels=%d route_draw_calls=%d border_calls=%d player_calls=%d full_draw_calls=%d stale_boss_pixels=%d stage_object_pixels=%d skill_rail_pixels=%d" % [
		ball_pos,
		selector_crop,
		selector_changed_pixels,
		selector_bright_pixels,
		route_selector_calls,
		instrumented.route_border_draw_calls,
		instrumented.route_player_draw_calls,
		route_full_draw_calls,
		route_sentinel_pixels,
		route_stage_object_pixels,
		route_skill_rail_pixels,
	])
	if route_full_draw_calls != 0 or route_sentinel_pixels != 0 or route_stage_object_pixels != 0:
		_fail("training ROUTE_AIM restored the stale battle composition")
		return
	if route_skill_rail_pixels != 0 or boss_skill_rail.draw_calls != 0:
		_fail("training ROUTE_AIM restored the stale boss-skill rail")
		return
	if route_selector_calls <= 0:
		_fail("training ROUTE_AIM did not call the selector-ball draw owner")
		return
	if selector_changed_pixels < MIN_SELECTOR_CHANGED_PIXELS:
		_fail("training return selector pixel delta was below threshold: %d < %d" % [
			selector_changed_pixels,
			MIN_SELECTOR_CHANGED_PIXELS,
		])
		return
	if selector_bright_pixels < MIN_SELECTOR_BRIGHT_PIXELS:
		_fail("training return selector bright pixels were below threshold: %d < %d" % [
			selector_bright_pixels,
			MIN_SELECTOR_BRIGHT_PIXELS,
		])
		return

	var combat_target := _find_combat_target(flow.get_route_aim_targets())
	if combat_target.is_empty():
		_fail("training return route exposed no combat target")
		return
	flow.call("_resolve_route_target", str(combat_target.get("id", "")))
	print("[TowerNoncombatReturnSelectorQA] phase=%s retained=%s playfield_flow=%s" % [
		str(flow.get_phase_name()),
		str(flow.get_retained_noncombat_node_background_kind()),
		str(TowerAscentScreenSpaceSurfacePolicy.uses_playfield_flow_phase(
			str(flow.get_phase_name()),
			flow.get_map_transition_visual_model()
		)),
	])
	flow.update_selective(1.0, _main_node)
	if flow.is_active() or not str(flow.get_retained_noncombat_node_background_kind()).is_empty():
		_fail("combat return did not release the retained noncombat arena")
		return
	instrumented.reset_counts()
	var combat_image := await _capture_current_frame(
		output_dir.path_join(COMBAT_RETURN_OUTPUT)
	)
	if combat_image == null:
		return
	var combat_sentinel_pixels := _count_magenta_pixels(
		combat_image,
		_game_rect_to_capture(_main_node, BOSS_SENTINEL_RECT, combat_image)
	)
	var combat_stage_object_pixels := _count_lime_pixels(
		combat_image,
		_game_rect_to_capture(_main_node, STAGE_OBJECT_SENTINEL_RECT, combat_image)
	)
	var combat_skill_rail_pixels := _count_cyan_pixels(combat_image)
	var combat_full_draw_calls := instrumented.full_draw_calls
	var combat_skill_rail_calls := boss_skill_rail.draw_calls
	if combat_full_draw_calls <= 0:
		_fail("combat return did not restore the full battle playfield")
		return
	if min(combat_sentinel_pixels, combat_stage_object_pixels) < MIN_COMBAT_SENTINEL_PIXELS:
		_fail("combat return boss/stage sentinel pixels were below threshold: %d,%d < %d" % [
			combat_sentinel_pixels,
			combat_stage_object_pixels,
			MIN_COMBAT_SENTINEL_PIXELS,
		])
		return
	if combat_skill_rail_calls <= 0 or combat_skill_rail_pixels <= 0:
		_fail("combat return did not restore the Stage 1 boss-skill rail")
		return

	# Separate reverse leg: with the Tower feature disabled, the ordinary campaign
	# keeps the same full stage composition and boss-skill HUD contract.
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	instrumented.reset_counts()
	boss_skill_rail.reset_counts()
	var nontower_image := await _capture_current_frame(
		output_dir.path_join(NONTOWER_OUTPUT)
	)
	if nontower_image == null:
		return
	var nontower_boss_pixels := _count_magenta_pixels(
		nontower_image,
		_game_rect_to_capture(_main_node, BOSS_SENTINEL_RECT, nontower_image)
	)
	var nontower_stage_object_pixels := _count_lime_pixels(
		nontower_image,
		_game_rect_to_capture(_main_node, STAGE_OBJECT_SENTINEL_RECT, nontower_image)
	)
	var nontower_skill_rail_pixels := _count_cyan_pixels(nontower_image)
	if (
		instrumented.full_draw_calls <= 0
		or min(nontower_boss_pixels, nontower_stage_object_pixels) < MIN_COMBAT_SENTINEL_PIXELS
		or boss_skill_rail.draw_calls <= 0
		or nontower_skill_rail_pixels <= 0
	):
		_fail("non-Tower campaign did not preserve full playfield and boss-skill HUD")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)

	print("[TowerRouteCleanupQA] captures=%s,%s,%s,%s,%s" % [
		output_dir.path_join(INITIAL_ROUTE_OUTPUT),
		output_dir.path_join(TRAINING_MODAL_OUTPUT),
		route_output,
		output_dir.path_join(COMBAT_RETURN_OUTPUT),
		output_dir.path_join(NONTOWER_OUTPUT),
	])
	print("[TowerRouteCleanupQA] combat_full_draw_calls=%d boss_pixels=%d stage_object_pixels=%d skill_rail_pixels=%d nontower_full_draw_calls=%d nontower_skill_rail_pixels=%d" % [
		combat_full_draw_calls,
		combat_sentinel_pixels,
		combat_stage_object_pixels,
		combat_skill_rail_pixels,
		instrumented.full_draw_calls,
		nontower_skill_rail_pixels,
	])
	print("tower_noncombat_return_selector_visual_qa: captures=5")
	print("tower_noncombat_return_selector_visual_qa: ok")
	_cleanup()
	call_deferred("_finish_success")
	return


func _finish_node_work_through_pointer(flow: Object) -> bool:
	var view_model: Dictionary = flow.get_node_modal_view_model(
		Vector2(CAPTURE_SIZE)
	)
	var rects: Array = view_model.get("action_rects", [])
	if rects.is_empty() or not (rects[rects.size() - 1] is Rect2):
		return false
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = (rects[rects.size() - 1] as Rect2).get_center()
	return bool(flow.handle_input(event))


func _find_combat_target(targets: Array) -> Dictionary:
	for target_value in targets:
		if not (target_value is Dictionary):
			continue
		var target := target_value as Dictionary
		if str(target.get("kind", "")) in ["boss", "combat", "enraged"]:
			return target
	return {}


func _enter_target_node(flow: Object, expected_kind: String) -> bool:
	var target: Dictionary = {}
	for target_value in flow.get_route_aim_targets():
		if target_value is Dictionary and str(target_value.get("kind", "")) == expected_kind:
			target = target_value
			break
	if target.is_empty():
		return false
	flow.call("_resolve_route_target", str(target.get("id", "")))
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return false
	flow.update_selective(1.0, _main_node)
	return (
		str(flow.get_phase_name()) == "NODE_MODAL"
		and str(flow.get_node_modal_kind()) == expected_kind
	)


func _capture_current_frame(output_path: String) -> Image:
	_main_node.queue_redraw()
	for _frame in range(8):
		await process_frame
		_main_node.queue_redraw()
	var image := _capture_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("selector QA viewport capture was empty")
		return null
	if image.get_size() != CAPTURE_SIZE:
		_fail("selector QA capture size mismatch: %s" % image.get_size())
		return null
	if not output_path.is_empty() and image.save_png(output_path) != OK:
		_fail("could not save selector QA capture: %s" % output_path)
		return null
	return image


func _selector_crop(main_node: Node, image: Image, _ball_pos: Vector2) -> Rect2i:
	# The paired frame differs only by `ball_active`, so the full playfield is a
	# stricter selector-pixel mask than guessing at the interpolation sample.
	# This counts the production ball body and its owned trail wherever that
	# frame actually rendered them, while excluding unchanged route/background
	# pixels.
	return _game_rect_to_capture(
		main_node,
		Rect2(Vector2.ZERO, Vector2(760.0, 750.0)),
		image
	)


func _game_rect_to_capture(
	main_node: Node,
	game_rect: Rect2,
	image: Image
) -> Rect2i:
	var layout_module: Object = _get_module(main_node, "battle_view_layout")
	if layout_module == null or not layout_module.has_method("build_game_layout"):
		return Rect2i()
	var layout: Dictionary = layout_module.build_game_layout(
		Vector2(CAPTURE_SIZE),
		BattleSceneConfig.WIDTH,
		BattleSceneConfig.HEIGHT
	)
	var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var render_scale := maxf(0.001, float(layout.get("render_scale", 1.0)))
	var rect_in_canvas := Rect2(
		game_offset + game_rect.position * render_scale,
		game_rect.size * render_scale
	)
	var canvas_to_capture: Transform2D = (
		_main_node.get_viewport().get_final_transform()
		* main_node.get_canvas_transform()
	)
	var rect_in_capture := canvas_to_capture * rect_in_canvas
	return Rect2i(rect_in_capture.intersection(
		Rect2(Vector2.ZERO, Vector2(image.get_size()))
	))


func _count_changed_pixels(first: Image, second: Image, crop: Rect2i) -> int:
	if first.get_size() != second.get_size():
		return 0
	var count := 0
	for y in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if (
				absf(a.r - b.r)
				+ absf(a.g - b.g)
				+ absf(a.b - b.b)
				+ absf(a.a - b.a)
			) >= 0.12:
				count += 1
	return count


func _count_changed_border_pixels(first: Image, second: Image, crop: Rect2i) -> int:
	if first.get_size() != second.get_size():
		return 0
	var border_band := 24
	var count := 0
	for y in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			if (
				x - crop.position.x >= border_band
				and crop.end.x - 1 - x >= border_band
				and y - crop.position.y >= border_band
				and crop.end.y - 1 - y >= border_band
			):
				continue
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) >= 0.12:
				count += 1
	return count


func _count_changed_bright_pixels(
	first: Image,
	second: Image,
	crop: Rect2i
) -> int:
	var count := 0
	for y in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			var pixel := first.get_pixel(x, y)
			var hidden_pixel := second.get_pixel(x, y)
			if (
				absf(pixel.r - hidden_pixel.r)
				+ absf(pixel.g - hidden_pixel.g)
				+ absf(pixel.b - hidden_pixel.b)
				+ absf(pixel.a - hidden_pixel.a)
			) >= 0.12 and pixel.r >= 0.82 and pixel.g >= 0.82 and pixel.b >= 0.82:
				count += 1
	return count


func _count_magenta_pixels(image: Image, crop: Rect2i) -> int:
	var count := 0
	for y in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.r >= 0.98 and pixel.g <= 0.02 and pixel.b >= 0.98:
				count += 1
	return count


func _count_lime_pixels(image: Image, crop: Rect2i) -> int:
	var count := 0
	for y in range(crop.position.y, crop.end.y):
		for x in range(crop.position.x, crop.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.r <= 0.02 and pixel.g >= 0.98 and pixel.b <= 0.02:
				count += 1
	return count


func _count_cyan_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.r <= 0.02 and pixel.g >= 0.98 and pixel.b >= 0.98:
				count += 1
	return count


func _prepare_selection_state() -> bool:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null or not selection_state.has_method("set_stage"):
		return false
	if selection_state.has_method("set_character"):
		selection_state.set_character({
			"id": "smasher",
			"runtime_id": "smasher",
			"name": "스매셔",
		})
	selection_state.set_stage(1)
	if selection_state.has_method("set_league_mode"):
		selection_state.set_league_mode("champion")
	if selection_state.has_method("request_skip_battle_logo_once"):
		selection_state.request_skip_battle_logo_once()
	return true


func _prepare_battle_scene(main_node: Node) -> void:
	if main_node.has_method("_initialize_battle"):
		main_node.call("_initialize_battle", false)
	if main_node.has_method("configure_player_character"):
		main_node.call("configure_player_character", "smasher")
	var warmup: Object = _get_module(main_node, "battle_boot_warmup_controller")
	if warmup != null:
		warmup.set("boot_warmup_finished", true)
		warmup.set("boot_warmup_step", 999)
	var logo_intro: Object = _get_module(main_node, "penguin_logo_intro")
	if logo_intro != null:
		logo_intro.set("active", false)
	var battle_flow: Object = _get_module(main_node, "battle_scene_flow_controller")
	if battle_flow != null:
		battle_flow.set("_battle_initialized", true)
		battle_flow.set("_stage_landing_intro_started", true)
		battle_flow.set("_ball_spawn_intro_started", true)
	var landing_intro: Object = _get_module(main_node, "stage_landing_intro")
	if landing_intro != null:
		landing_intro.set("active", false)
	var ball_spawn_intro: Object = _get_module(main_node, "stage_ball_spawn_intro")
	if ball_spawn_intro != null:
		if ball_spawn_intro.has_method("reset"):
			ball_spawn_intro.reset()
		ball_spawn_intro.set("active", false)
		ball_spawn_intro.set("overlay_active", false)
	main_node.set("player_pos", INITIAL_PLAYER_POS)
	main_node.set("player_speed", 0.0)
	main_node.set("ball_pos", Vector2(307.5, 650.0))
	main_node.set("ball_vel", Vector2.ZERO)
	main_node.set("ball_active", false)
	main_node.set("boss_pos", Vector2(325.0, 25.0))
	main_node.queue_redraw()


func _install_baseline_ball_renderer_adapters(main_node: Node) -> void:
	var registry: Variant = main_node.get("gameplay_modules")
	if not (typeof(registry) == TYPE_OBJECT and is_instance_valid(registry)):
		return
	_ball_renderer = registry.get_instance("ball_renderer")
	if _ball_renderer == null:
		return
	_baseline_energy_renderer = _ball_renderer.get("energy_renderer")
	_baseline_overdrive_renderer = _ball_renderer.get("overdrive_trail_renderer")
	_baseline_status_overlay_renderer = _ball_renderer.get("status_overlay_renderer")
	_ball_renderer.set(
		"energy_renderer",
		BaselineEnergyRendererAdapter.new(_baseline_energy_renderer)
	)
	_ball_renderer.set(
		"overdrive_trail_renderer",
		BaselineOverdriveRendererAdapter.new(_baseline_overdrive_renderer)
	)
	_ball_renderer.set(
		"status_overlay_renderer",
		BaselineStatusOverlayRendererAdapter.new(_baseline_status_overlay_renderer)
	)


func _get_module(main_node: Node, key: String) -> Object:
	if main_node == null or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _release_test_input() -> void:
	for action_name in ["ui_left", "ui_right", "ui_accept"]:
		Input.action_release(action_name)
	_set_left_mouse_pressed(false)


func _set_left_mouse_pressed(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = Vector2(760.0, 500.0)
	Input.parse_input_event(event)


func _cleanup() -> void:
	_release_test_input()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	var viewport_to_free: SubViewport = _capture_viewport
	if _capture_viewport != null and is_instance_valid(_capture_viewport):
		_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _main_node != null and is_instance_valid(_main_node):
		if _base_registry != null:
			_main_node.set("gameplay_modules", _base_registry)
	_main_node = null
	if viewport_to_free != null and is_instance_valid(viewport_to_free):
		viewport_to_free.queue_free()
	_capture_viewport = null
	_ball_renderer = null
	_base_registry = null
	_baseline_energy_renderer = null
	_baseline_overdrive_renderer = null
	_baseline_status_overlay_renderer = null


func _finish_success() -> void:
	# Let Vulkan retire the freed SubViewport and its cached draw resources after
	# `_run` locals (flow, registry wrappers, captured Images) leave scope.
	for _frame in range(4):
		await process_frame
	quit(0)


func _fail(message: String) -> void:
	if not _failure_message.is_empty():
		return
	_failure_message = message
	_cleanup()
	call_deferred("_finish_failure")


func _finish_failure() -> void:
	for _frame in range(4):
		await process_frame
	push_error(_failure_message)
	quit(1)
