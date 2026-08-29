extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const BattleSceneDrawer := preload(
	"res://scripts/core/battle_scene_drawer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const ActiveItemCatalog := preload(
	"res://scripts/items/active_item_catalog.gd"
)
const ActiveItemHudVisuals := preload(
	"res://scripts/hud/active_item_hud_visuals.gd"
)
const Stage1PillarUiRenderer := preload(
	"res://scripts/hud/stage1_pillar_ui_renderer.gd"
)
const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_ascent_phase_c"
const CAPTURE_SPECS := [
	{
		"file": "common_shell.png",
		"kind": "common_shell",
		"actions": [],
	},
	{
		"file": "shop.png",
		"kind": "shop",
		"actions": [
			{"label": "일반 액티브 진열 A", "cost_text": "250 금화", "cost_gold": 250, "enabled": true},
			{"label": "일반 액티브 진열 B", "cost_text": "300 금화", "cost_gold": 300, "enabled": true},
			{"label": "일반 액티브 진열 C", "cost_text": "350 금화", "cost_gold": 350, "enabled": true},
			{"label": "프리미엄 액티브 진열", "cost_text": "800 금화", "cost_gold": 800, "enabled": true},
			{"label": "복주머니", "cost_text": "200 금화", "cost_gold": 200, "enabled": true},
			{"label": "기회의 보석", "cost_text": "150 금화", "cost_gold": 150, "enabled": false, "unavailable_reason": "금화 150 필요, 30 부족"},
		],
	},
	{
		"file": "shop_currency_alignment.png",
		"kind": "shop",
		"scenario": "currency_alignment",
		"actions": [
			{"label": "일반 액티브 진열 A", "cost_text": "250 금화", "cost_gold": 250, "enabled": true},
			{"label": "일반 액티브 진열 B", "cost_text": "300 금화", "cost_gold": 300, "enabled": true},
			{"label": "일반 액티브 진열 C", "cost_text": "350 금화", "cost_gold": 350, "enabled": true},
			{"label": "프리미엄 액티브 진열", "cost_text": "800 금화", "cost_gold": 800, "enabled": true},
			{"label": "복주머니", "cost_text": "200 금화", "cost_gold": 200, "enabled": true},
			{"label": "기회의 보석", "cost_text": "150 금화", "cost_gold": 150, "enabled": false, "unavailable_reason": "금화 150 필요, 30 부족"},
		],
	},
	{
		"file": "noncombat_arena_clean.png",
		"kind": "shop",
		"scenario": "noncombat_arena_clean",
		"actions": [
			{"label": "일반 액티브 진열 A", "cost_text": "250 금화", "cost_gold": 250, "enabled": true},
			{"label": "일반 액티브 진열 B", "cost_text": "300 금화", "cost_gold": 300, "enabled": true},
			{"label": "일반 액티브 진열 C", "cost_text": "350 금화", "cost_gold": 350, "enabled": true},
			{"label": "프리미엄 액티브 진열", "cost_text": "800 금화", "cost_gold": 800, "enabled": true},
			{"label": "복주머니", "cost_text": "200 금화", "cost_gold": 200, "enabled": true},
			{"label": "기회의 보석", "cost_text": "150 금화", "cost_gold": 150, "enabled": false, "unavailable_reason": "금화 150 필요, 30 부족"},
		],
	},
	{
		"file": "combat_arena_restored.png",
		"kind": "combat",
		"scenario": "combat_arena_restored",
		"actions": [],
	},
	{
		"file": "training.png",
		"kind": "training",
		"scenario": "baseline",
		"actions": [
			{"label": "체질 수련 선택지 A", "cost_text": "1 무혼", "enabled": true},
			{"label": "체질 수련 선택지 B", "cost_text": "1 무혼", "enabled": true},
			{"label": "체질 수련 선택지 C", "cost_text": "1 무혼", "enabled": true},
			{"label": "체질 수련 선택지 D", "cost_text": "1 무혼", "enabled": true},
		],
	},
	{
		"file": "training_three_purchases.png",
		"kind": "training",
		"scenario": "three_purchases",
		"muhon": 5,
		"actions": [
			{"label": "비천보 수련", "cost_text": "1 무혼", "enabled": true},
			{"label": "유운보 수련", "cost_text": "1 무혼", "enabled": true},
			{"label": "철산공 수련", "cost_text": "1 무혼", "enabled": true},
			{"label": "태허심법 수련", "cost_text": "1 무혼", "enabled": true},
		],
	},
	{
		"file": "training_maximum.png",
		"kind": "training",
		"scenario": "maximum",
		"actions": [
			{"label": "수납술 수련", "cost_text": "1 무혼", "enabled": false, "unavailable_reason": "최대 단계에 도달했습니다."},
			{"label": "유운보 수련", "cost_text": "1 무혼", "enabled": true},
			{"label": "철산공 수련", "cost_text": "1 무혼", "enabled": true},
			{"label": "태허심법 수련", "cost_text": "1 무혼", "enabled": true},
		],
	},
	{
		"file": "training_insufficient_muhon.png",
		"kind": "training",
		"scenario": "insufficient_muhon",
		"muhon": 0,
		"actions": [
			{"label": "비천보 수련", "cost_text": "1 무혼", "enabled": false, "unavailable_reason": "무혼 1 필요, 1 부족"},
			{"label": "유운보 수련", "cost_text": "1 무혼", "enabled": false, "unavailable_reason": "무혼 1 필요, 1 부족"},
			{"label": "철산공 수련", "cost_text": "1 무혼", "enabled": false, "unavailable_reason": "무혼 1 필요, 1 부족"},
			{"label": "태허심법 수련", "cost_text": "1 무혼", "enabled": false, "unavailable_reason": "무혼 1 필요, 1 부족"},
		],
	},
	{
		"file": "fallen_monk.png",
		"kind": "fallen_monk",
		"actions": [
			{"label": "초식 습득 선택지", "cost_text": "3 무혼", "enabled": true},
			{"label": "초식 교환 선택지", "cost_text": "4 무혼", "enabled": true},
			{"label": "초식 제거 선택지", "cost_text": "5 무혼", "enabled": true},
			{"label": "무공 선택지 A", "cost_text": "2 무혼", "enabled": true},
			{"label": "무공 선택지 B", "cost_text": "2 무혼", "enabled": true},
			{"label": "무공 선택지 C", "cost_text": "2 무혼", "enabled": true},
		],
	},
	{
		"file": "guardian_spring.png",
		"kind": "guardian_spring",
		"actions": [
			{"label": "수호령 강화", "cost_text": "2 무혼", "enabled": true},
			{"label": "봉인 수호령 교체", "cost_text": "무료", "enabled": true},
			{"label": "봉인 수호령 흡수", "cost_text": "무료", "enabled": true},
		],
	},
	{
		"file": "rest.png",
		"kind": "rest",
		"actions": [
			{"label": "기회의 보석 1개 회복", "cost_text": "무료", "enabled": true},
		],
	},
]


class CaptureFlow:
	extends RefCounted

	var source_flow: Object
	var modal_state: Object = TowerAscentNodeModalState.new()
	var renderer: Object = TowerAscentFlowRenderer.new()
	var capture_kind := "common_shell"
	var card_renderer: Object
	var icon_renderer: Object
	var active_item_hud_visuals: Object
	var retained_background := false
	var active := true
	var phase := "NODE_MODAL"

	func _init(
		new_source_flow: Object,
		kind: String,
		actions: Array,
		new_card_renderer: Object,
		new_icon_renderer: Object,
		new_active_item_hud_visuals: Object,
		muhon_balance: int
	) -> void:
		source_flow = new_source_flow
		capture_kind = kind
		card_renderer = new_card_renderer
		icon_renderer = new_icon_renderer
		active_item_hud_visuals = new_active_item_hud_visuals
		modal_state.open(
			str(source_flow.get_current_node_id()),
			kind,
			{"gold": 120, "muhon": muhon_balance, "chance_gems": 2},
			actions
		)

	func is_active() -> bool:
		return active

	func get_phase_name() -> String:
		return phase

	func get_map_transition_visual_model() -> Dictionary:
		return {}

	func is_map_overlay_closing() -> bool:
		return false

	func get_header_subtitle() -> String:
		return "페이즈 C 노드 실기능 검증 · %s" % capture_kind

	func get_node_modal_view_model(view_size: Vector2 = Vector2(GAME_SIZE)) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return capture_kind

	func get_node_modal_render_context() -> Dictionary:
		return {
			"card_renderer": card_renderer,
			"icon_renderer": icon_renderer,
			"active_item_hud_visuals": active_item_hud_visuals,
		}

	func get_retained_noncombat_node_background_resolution() -> Dictionary:
		return (
			source_flow.get_retained_noncombat_node_background_resolution()
			if retained_background
			else {}
		)

	func has_renderable_retained_noncombat_node_background() -> bool:
		if not retained_background:
			return false
		var resolution := get_retained_noncombat_node_background_resolution()
		return (
			not resolution.is_empty()
			and bool(resolution.get("ready", false))
			and not bool(resolution.get("fallback_to_stage_background", false))
		)

	func get_graph_nodes() -> Array:
		return source_flow.get_graph_nodes()

	func get_graph_edges() -> Array:
		return source_flow.get_graph_edges()

	func get_graph_floors() -> Array:
		return source_flow.get_graph_floors()

	func get_route_target_ids() -> Array:
		return source_flow.get_route_target_ids()

	func get_current_node_id() -> String:
		return source_flow.get_current_node_id()

	func get_selected_target_id() -> String:
		return ""

	func draw(canvas: CanvasItem) -> void:
		renderer.draw(canvas, self)

	func draw_retained_noncombat_node_background(
		canvas: CanvasItem,
		fallback_rect: Rect2 = Rect2()
	) -> void:
		renderer.draw_retained_noncombat_node_background(canvas, self, fallback_rect)

	func draw_fullscreen_surface(
		canvas: CanvasItem,
		fallback_rect: Rect2 = Rect2(),
		_walker_model: Dictionary = {}
	) -> void:
		renderer.draw_fullscreen_surface(canvas, self, fallback_rect)


class CaptureRegistry:
	extends RefCounted

	var flow_owner: Object
	var instances: Dictionary = {}

	func _init(new_flow_owner: Object) -> void:
		flow_owner = new_flow_owner

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return instances.get(key, null)


class LiveUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return content_id in [
			"physique_dash_distance",
			"physique_move_speed",
			"physique_paddle_size",
			"physique_max_gauge",
		]


class LiveRuntimePerkCatalog:
	extends RefCounted

	func get_choices(
		_character_type: String,
		runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		var result: Array[Dictionary] = []
		for spec in [
			["live_mugong_alpha", "청류심법"],
			["live_mugong_beta", "철벽심법"],
			["live_mugong_gamma", "비연심법"],
		]:
			var current_level := int(runtime_levels.get(spec[0], 0))
			result.append({
				"id": spec[0],
				"name": spec[1],
				"description": "%s %d단계 효과" % [spec[1], current_level + 1],
				"descriptions": {
					1: "%s 1단계 효과" % spec[1],
					2: "%s 2단계 효과" % spec[1],
					3: "%s 3단계 효과" % spec[1],
					4: "%s 4단계 효과" % spec[1],
					5: "%s 5단계 효과" % spec[1],
				},
				"current_level": current_level,
				"next_level": current_level + 1,
				"max_level": 5,
				"icon_color": Color(0.28, 0.52, 0.74),
			})
		return result


class LiveRuntimePerkState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var training_counts: Dictionary = {}

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass

	func get_physique_training_count(training_id: String) -> int:
		return int(training_counts.get(training_id, 0))

	func get_physique_training_multiplier() -> float:
		return 1.0

	func is_physique_training_saturated(
		_training_id: String,
		_registry: Object = null
	) -> bool:
		return false

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var choice_id := str(choice.get("id", ""))
		if bool(choice.get("is_physique_training", false)):
			training_counts[choice_id] = int(training_counts.get(choice_id, 0)) + 1
		else:
			runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"physique_training": {"counts": training_counts.duplicate(true)},
		}

	func apply_unlock_save_snapshot(
		snapshot: Dictionary,
		_owner: Object = null,
		_registry: Object = null
	) -> Dictionary:
		var levels_value: Variant = snapshot.get("runtime_skill_levels", {})
		if not (levels_value is Dictionary):
			return {"restored": false}
		runtime_skill_levels = (levels_value as Dictionary).duplicate(true)
		var training_value: Variant = snapshot.get("physique_training", {})
		if training_value is Dictionary:
			var counts_value: Variant = (training_value as Dictionary).get("counts", {})
			if counts_value is Dictionary:
				training_counts = (counts_value as Dictionary).duplicate(true)
		return {"restored": true}


class LiveRegistry:
	extends RefCounted

	var runtime_state: Object = LiveRuntimePerkState.new()
	var catalog: Object = LiveRuntimePerkCatalog.new()
	var unlock_store: Object = LiveUnlockStore.new()
	var card_renderer: Object
	var icon_renderer: Object

	func _init(new_card_renderer: Object, new_icon_renderer: Object) -> void:
		card_renderer = new_card_renderer
		icon_renderer = new_icon_renderer

	func get_instance(key: String) -> Variant:
		match key:
			"runtime_perk_state":
				return runtime_state
			"runtime_perk_catalog":
				return catalog
			"runtime_perk_overlay_renderer":
				return card_renderer
			"runtime_perk_icon_renderer":
				return icon_renderer
			TowerAscentUnlockFilter.STORE_KEY:
				return unlock_store
		return null

	func get_cached_instance(key: String) -> Variant:
		return get_instance(key)


class LiveOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "smasher"
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class ProductionPlayfieldCanvas:
	extends Node2D

	var flow: Object
	var drawer: Object = TowerAscentFlowRenderer.new()
	var ball_active := false
	var ball_visual_type := "pingpong"

	func _init(new_flow: Object) -> void:
		flow = new_flow

	func _draw() -> void:
		# Magenta sentinels emulate battle/HUD pixels beneath the fullscreen
		# surface. Every corner must be overwritten by the opaque node backdrop.
		draw_rect(Rect2(Vector2.ZERO, Vector2(GAME_SIZE)), Color.MAGENTA, true)
		drawer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
		)


class CurrencyAlignmentCanvas:
	extends Node2D

	var pillar_renderer: Object = Stage1PillarUiRenderer.new()

	func _draw() -> void:
		pillar_renderer.draw_gold_hud(
			self,
			Vector2(350.0, 90.0),
			Vector2(760.0, 750.0),
			{
				"height": 750.0,
				"gold_hud_amount": 120,
				"tower_muhon_hud_visible": true,
				"tower_muhon_hud_amount": 8,
			}
		)


class SentinelPlayfieldDrawer:
	extends RefCounted

	var draw_calls := 0

	func draw(
		canvas: CanvasItem,
		_registry: Object,
		_shake_offset: Vector2,
		width: float,
		height: float,
		_pillar_width: float
	) -> void:
		draw_calls += 1
		canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color("251733"), true)
		for stripe in range(6):
			canvas.draw_rect(
				Rect2(0.0, float(stripe) * height / 6.0, width, height / 12.0),
				Color(0.20 + float(stripe) * 0.025, 0.10, 0.24, 1.0),
				true
			)
		var boss_center := Vector2(width * 0.5, height * 0.19)
		canvas.draw_circle(boss_center, 58.0, Color("ff2478"))
		canvas.draw_circle(boss_center, 38.0, Color("4b0924"))
		canvas.draw_string(
			ThemeDB.fallback_font,
			boss_center + Vector2(-92.0, 92.0),
			"COMBAT BOSS RESTORED",
			HORIZONTAL_ALIGNMENT_CENTER,
			184.0,
			18,
			Color.WHITE
		)


class BattleBoundaryCanvas:
	extends Node2D

	var registry: Object
	var drawer: Object = BattleSceneDrawer.new()

	func _init(new_registry: Object) -> void:
		registry = new_registry

	func _draw() -> void:
		drawer.draw(self, registry, {
			"width": 760.0,
			"height": 750.0,
			"pillar_width": 80.0,
			"view_size": Vector2(GAME_SIZE),
			"context_owner": self,
		})


class LiveTrainingCanvas:
	extends Node2D

	var flow: Object
	var drawer: Object = TowerAscentFlowRenderer.new()
	var current_stage := 4
	var selected_character_type := "smasher"

	func request_battle_redraw() -> void:
		queue_redraw()

	func _draw() -> void:
		drawer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
		)


var _card_renderer: Object = RuntimePerkOverlayRenderer.new()
var _icon_renderer: Object = RuntimePerkIconRenderer.new()
var _active_item_hud_visuals: Object = ActiveItemHudVisuals.new()
var _active_item_catalog: Object = ActiveItemCatalog.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_ascent_phase_c_node_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_ascent_phase_c_node_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	PerkConversionFlags.debug_set_enabled(true)
	_card_renderer.prewarm_assets()
	_icon_renderer.prewarm_assets()
	_active_item_hud_visuals.prewarm_catalog_icons()
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("phase-C node capture directory creation failed: %d" % mkdir_error)
		quit(1)
		return
	for index in range(CAPTURE_SPECS.size()):
		if not await _capture_node(CAPTURE_SPECS[index], output_dir, index):
			return
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(false)
	print("tower_ascent_phase_c_node_visual_qa: evidence=%s" % output_dir)
	print("tower_ascent_phase_c_node_visual_qa: captures=%d" % CAPTURE_SPECS.size())
	print("tower_ascent_phase_c_node_visual_qa: live_runs=1")
	print("tower_ascent_phase_c_node_visual_qa: ok")
	quit(0)


func _capture_node(spec: Dictionary, output_dir: String, index: int) -> bool:
	if str(spec.get("scenario", "")) == "three_purchases":
		return await _capture_live_training_round(spec, output_dir)
	var source_flow := TowerAscentFlowOwner.new()
	if not source_flow.begin_vertical_slice(null, Callable(), {
		"run_id": "phase-c-visual-%d" % index,
		"current_stage": 4,
		"map_seed": 83521,
	}):
		push_error("phase-C node visual fixture could not begin")
		quit(1)
		return false
	var actions: Array = []
	for action_index in range((spec.get("actions", []) as Array).size()):
		var action := ((spec.get("actions", []) as Array)[action_index] as Dictionary).duplicate(true)
		action["id"] = "visual:%d" % action_index
		if str(spec.get("kind", "")) in ["shop", "training", "fallen_monk"]:
			action["payload"] = {
				"choice": _build_card_choice(spec, action, action_index),
			}
		actions.append(action)
	var capture_flow := CaptureFlow.new(
		source_flow,
		str(spec.get("kind", "common_shell")),
		actions,
		_card_renderer,
		_icon_renderer,
		_active_item_hud_visuals,
		int(spec.get("muhon", 8))
	)
	var scenario := str(spec.get("scenario", ""))
	var capture_kind := str(spec.get("kind", "common_shell"))
	if capture_kind != "combat":
		var background_kind := (
			capture_kind
			if capture_kind in [
				"shop",
				"training",
				"fallen_monk",
				"guardian_spring",
				"rest",
			]
			else "rest"
		)
		var prewarm: Dictionary = source_flow.call(
			"_prewarm_noncombat_node_background",
			background_kind
		)
		if not bool(prewarm.get("ready", false)):
			push_error("node capture could not prewarm background: %s" % background_kind)
			quit(1)
			return false
		source_flow.call("_retain_noncombat_node_background", background_kind)
		capture_flow.retained_background = true
	if scenario == "combat_arena_restored":
		capture_flow.active = false
		capture_flow.phase = "COMBAT"
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas: Node2D
	var currency_overlay: Node2D = null
	var sentinel_drawer: Object = null
	if scenario == "currency_alignment":
		canvas = ProductionPlayfieldCanvas.new(capture_flow)
		currency_overlay = CurrencyAlignmentCanvas.new()
	elif scenario in ["noncombat_arena_clean", "combat_arena_restored"]:
		sentinel_drawer = SentinelPlayfieldDrawer.new()
		var boundary_registry := CaptureRegistry.new(capture_flow)
		boundary_registry.instances["battle_playfield_scene_drawer"] = sentinel_drawer
		canvas = BattleBoundaryCanvas.new(boundary_registry)
	else:
		canvas = ProductionPlayfieldCanvas.new(capture_flow)
	viewport.add_child(canvas)
	if currency_overlay != null:
		viewport.add_child(currency_overlay)
		currency_overlay.queue_redraw()
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(str(spec.get("file", "capture.png")))
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("phase-C node visual QA capture failed: %s" % output_path)
		quit(1)
		return false
	if str(spec.get("kind", "")) in ["shop", "training", "fallen_monk"]:
		var card_rects: Array[Rect2] = capture_flow.modal_state.get_action_rects(
			Vector2(GAME_SIZE)
		)
		var card_count := 4 if str(spec.get("kind", "")) == "training" else 6
		if card_rects.size() != card_count + 1:
			push_error("service-card visual fixture did not expose its cards plus footer")
			quit(1)
			return false
		for card_index in range(card_count):
			if not _rect_has_visual_detail(image, card_rects[card_index] as Rect2):
				push_error("card %d did not produce enough rendered pixel detail" % card_index)
				quit(1)
				return false
	if scenario == "currency_alignment":
		var modal_gold_text := str(capture_flow.get_node_modal_view_model(
			Vector2(GAME_SIZE)
		).get("gold_text", ""))
		if not modal_gold_text.contains("120"):
			push_error("currency alignment capture modal did not show run gold 120")
			quit(1)
			return false
	if scenario == "noncombat_arena_clean" and int(sentinel_drawer.draw_calls) != 0:
		push_error("noncombat boundary capture rendered the stale battle playfield")
		quit(1)
		return false
	if scenario == "combat_arena_restored" and int(sentinel_drawer.draw_calls) <= 0:
		push_error("combat boundary capture did not restore the battle playfield")
		quit(1)
		return false
	for corner in [
		Vector2i(1, 1),
		Vector2i(GAME_SIZE.x - 2, 1),
		Vector2i(1, GAME_SIZE.y - 2),
		Vector2i(GAME_SIZE.x - 2, GAME_SIZE.y - 2),
	]:
		var corner_color := image.get_pixelv(corner)
		if corner_color.a < 0.99 or (
			corner_color.r > 0.92
			and corner_color.b > 0.92
			and corner_color.g < 0.15
		):
			push_error("fullscreen node backdrop did not cover HUD sentinel at %s" % corner)
			quit(1)
			return false
	print("[TowerAscentPhaseCVisualQA] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true


func _capture_live_training_round(spec: Dictionary, output_dir: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := LiveTrainingCanvas.new()
	viewport.add_child(canvas)
	var owner := LiveOwner.new()
	var registry := LiveRegistry.new(_card_renderer, _icon_renderer)
	var flow := TowerAscentFlowOwner.new()
	canvas.flow = flow
	if not flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-card-live-one",
		"current_stage": 4,
		"map_seed": 5,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30, "gold": 120, "chance_gems": 2},
		"registry": registry,
	}):
		push_error("live training round could not begin")
		quit(1)
		return false
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == "training":
			target_index = index
			break
	if target_index < 0:
		push_error("live training round did not expose a training route")
		quit(1)
		return false
	flow.debug_launch_at_target(target_index)
	flow.update_selective(1.5, owner)
	flow.update_selective(1.0, owner)
	if flow.get_phase_name() != "NODE_MODAL" or flow.get_node_modal_kind() != "training":
		push_error("live training round did not enter the production training modal")
		quit(1)
		return false
	var action_id := ""
	for action_value in flow.get_node_modal_view_model(Vector2(GAME_SIZE)).get("actions", []):
		if not (action_value is Dictionary):
			continue
		var action := action_value as Dictionary
		var choice: Dictionary = action.get("payload", {}).get("choice", {})
		if (
			str(action.get("id", "")).begins_with("training_stat:")
			and int(choice.get("training_max_count", 0)) < 0
		):
			action_id = str(action.get("id", ""))
			break
	if action_id.is_empty():
		push_error("live training round did not expose a repeatable training card")
		quit(1)
		return false
	for purchase_index in range(3):
		var result: Dictionary = flow.execute_node_action(
			action_id,
			"training-card-live:%d" % purchase_index
		)
		if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
			push_error("live repeated training purchase %d failed" % (purchase_index + 1))
			quit(1)
			return false
	var live_action := _find_action_by_id(
		flow.get_node_modal_view_model(Vector2(GAME_SIZE)).get("actions", []),
		action_id
	)
	var live_choice: Dictionary = live_action.get("payload", {}).get("choice", {})
	if (
		flow.get_training_history().size() != 3
		or int(flow.get_run_state_snapshot().get("muhon", -1)) != 26
		or str(live_choice.get("level_text", "")) != "Lv.3"
		or not bool(live_action.get("enabled", false))
	):
		push_error("live repeated training state did not retain three purchases")
		quit(1)
		return false
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := output_dir.path_join(str(spec.get("file", "training_three_purchases.png")))
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("live training capture failed: %s" % output_path)
		quit(1)
		return false
	var card_rects: Array = flow.get_node_modal_view_model(Vector2(GAME_SIZE)).get(
		"action_rects",
		[]
	)
	for card_index in range(4):
		if not _rect_has_visual_detail(image, card_rects[card_index] as Rect2):
			push_error("live training card %d lacked rendered detail" % card_index)
			quit(1)
			return false
	print("[TowerAscentPhaseCVisualQA] %s" % output_path)
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return true


func _find_action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("id", "")) == action_id:
			return action_value as Dictionary
	return {}


func _build_card_choice(spec: Dictionary, action: Dictionary, index: int) -> Dictionary:
	var node_kind := str(spec.get("kind", "training"))
	if node_kind == "shop":
		return _build_shop_card_choice(action, index)
	var scenario := str(spec.get("scenario", "baseline"))
	var stat_card := node_kind == "training"
	var current_level := 0
	var maximum_level := -1 if stat_card else 5
	if scenario == "three_purchases" and index == 0:
		current_level = 3
	if scenario == "maximum" and index == 0:
		current_level = 3
		maximum_level = 3
	var level_text := (
		"Lv.%d" % current_level
		if maximum_level < 0
		else "%d / %d" % [current_level, maximum_level]
	)
	if node_kind == "fallen_monk":
		level_text = "비급" if index < 3 else "0 / 5"
	var choice_ids := (
		[
			"physique_dash_distance",
			"physique_move_speed",
			"physique_paddle_size",
			"physique_max_gauge",
			"physique_hit_gauge",
			"physique_active_item_cooldown",
		]
		if node_kind == "training"
		else [
			"fallen_monk_chosik_a",
			"fallen_monk_chosik_b",
			"fallen_monk_chosik_c",
			"common_swiftness",
			"common_bulk_up",
			"common_training",
		]
	)
	return {
		"id": choice_ids[index],
		"name": str(action.get("label", "선택지")),
		"description": (
			"같은 카드를 반복 수련해도 현재 단계가 즉시 갱신되고 다음 효과를 확인할 수 있습니다."
			if scenario == "three_purchases" and index == 0
			else "카드 설명과 효과 수치를 확인하고 원하는 수련을 선택합니다."
		),
		"detail": "보상 카드와 같은 문법을 사용하는 승천탑 선택 카드입니다.",
		"level_text": level_text,
		"current_level": current_level,
		"next_level": current_level + 1,
		"max_level": maximum_level,
		"is_physique_training": stat_card,
		"icon_color": Color(0.66, 0.43, 0.18) if stat_card else Color(0.28, 0.52, 0.74),
	}


func _build_shop_card_choice(action: Dictionary, index: int) -> Dictionary:
	if index < 4:
		var item_name: String = str([
			"grenade",
			"flare",
			"stopwatch",
			"pandora_box",
		][index])
		var item_data: Dictionary = _active_item_catalog.build_item_by_name(item_name)
		var rarity := str(item_data.get("rarity", "common"))
		return {
			"id": item_name,
			"name": str(action.get("label", item_data.get("display_name", item_name))),
			"description": str(item_data.get("description", "액티브 아이템입니다.")),
			"rarity": rarity,
			"is_unique": index == 3,
			"tree": "item",
			"icon_color": item_data.get("color", Color(0.78, 0.78, 0.78)),
			"card_content_kind": "active_item",
			"level_text": "귀물 액티브" if index == 3 else "일반 액티브",
			"item_data": item_data,
		}
	if index == 4:
		return {
			"id": "active_item_capsule",
			"name": str(action.get("label", "복주머니")),
			"description": "봉인된 액티브 아이템 하나를 획득합니다.",
			"rarity": "common",
			"tree": "item",
			"icon_color": Color(0.72, 0.47, 0.24),
			"card_content_kind": "capsule",
			"level_text": "액티브 물자",
			"item_data": {},
		}
	return {
		"id": "chance_gem",
		"name": str(action.get("label", "기회의 보석")),
		"description": "패배 후 도전을 이어갈 때 쓰는 보석을 1개 얻습니다.",
		"rarity": "common",
		"tree": "item",
		"icon_color": Color(0.33, 0.72, 1.0),
		"card_content_kind": "chance_gem",
		"level_text": "탑 물자",
		"item_data": {},
	}


func _rect_has_visual_detail(image: Image, rect: Rect2) -> bool:
	var colors := {}
	for y_step in range(5):
		for x_step in range(5):
			var point := Vector2i(
				clampi(int(round(lerpf(rect.position.x + 3.0, rect.end.x - 3.0, float(x_step) / 4.0))), 0, image.get_width() - 1),
				clampi(int(round(lerpf(rect.position.y + 3.0, rect.end.y - 3.0, float(y_step) / 4.0))), 0, image.get_height() - 1)
			)
			colors[image.get_pixelv(point).to_html()] = true
	return colors.size() >= 6
