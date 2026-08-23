extends RefCounted

const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const TowerAscentFlowRenderer := preload("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
const TowerAscentMapDragState := preload(
	"res://scripts/tower_ascent/tower_ascent_map_drag_state.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentFloorRevealState := preload(
	"res://scripts/tower_ascent/tower_ascent_floor_reveal_state.gd"
)
const TowerAscentMapGenerator := preload("res://scripts/tower_ascent/tower_ascent_map_generator.gd")
const TowerAscentBossRegistry := preload("res://scripts/tower_ascent/tower_ascent_boss_registry.gd")
const TowerAscentRouteCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_candidate_policy.gd"
)
const TowerAscentRouteServeRuntime := preload(
	"res://scripts/tower_ascent/tower_ascent_route_serve_runtime.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentRoutePickupState := preload(
	"res://scripts/tower_ascent/tower_ascent_route_pickup_state.gd"
)
const TowerAscentRunState := preload("res://scripts/tower_ascent/tower_ascent_run_state.gd")
const TowerAscentTuning := preload("res://scripts/tower_ascent/tower_ascent_tuning.gd")
const TowerAscentNodeResolutionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_resolution_transaction.gd"
)
const TowerAscentDefeatResolver := preload(
	"res://scripts/tower_ascent/tower_ascent_defeat_resolver.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentModalLifecycle := preload(
	"res://scripts/tower_ascent/tower_ascent_modal_lifecycle.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentShopInventory := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_inventory.gd"
)
const TowerAscentTrainingOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
)
const TowerAscentFallenMonkNode := preload(
	"res://scripts/tower_ascent/tower_ascent_fallen_monk_node.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentRestNode := preload(
	"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)
const TowerAscentEndingState := preload(
	"res://scripts/tower_ascent/tower_ascent_ending_state.gd"
)
const TowerAscentSettlementState := preload(
	"res://scripts/tower_ascent/tower_ascent_settlement_state.gd"
)
const TowerAscentGauntletState := preload(
	"res://scripts/tower_ascent/tower_ascent_gauntlet_state.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTransitionFadeState := preload(
	"res://scripts/tower_ascent/tower_ascent_transition_fade_state.gd"
)
const TowerNoncombatNodeBackgroundCatalog := preload(
	"res://scripts/tower_ascent/tower_noncombat_node_background_catalog.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const SNAPSHOT_SCHEMA_VERSION := TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION
const MAP_GENERATOR_VERSION := TowerAscentMapGenerator.GENERATOR_VERSION
const MAP_GRAPH_STORAGE_FULL := "full_graph"
const PHASE_COMBAT := 0
const PHASE_NODE_MODAL := 1
const PHASE_ROUTE_AIM := 2
const PHASE_MAP_TRANSITION := 3
const PHASE_FAKE_ENDING_TEASER := 4
const PHASE_ENDING_CHOICE := 5
const PHASE_RUN_SETTLEMENT := 6
const PHASE_GAUNTLET_TRANSITION := 7
const SELECTOR_RADIUS := 11.0
const SELECTOR_SPEED := 520.0
const SELECTOR_ORIGIN := Vector2(380.0, 665.0)
const SELECTOR_TARGET_Y := 165.0
const SELECTOR_LEFT_WALL := 52.0
const SELECTOR_RIGHT_WALL := 708.0
const SELECTOR_RESET_Y := 92.0

var _active := false
var _map_seed := 0
var _prepared := false
var _prepared_resolution_id := ""
var _phase := PHASE_COMBAT
var _graph_phases: Array[Dictionary] = []
var _active_graph_phase_index := 0
var _graph_nodes: Array[Dictionary] = []
var _graph_edges: Array[Dictionary] = []
var _graph_node_by_id: Dictionary = {}
var _graph_all_phase_node_by_id: Dictionary = {}
var _graph_outgoing_target_ids_by_id: Dictionary = {}
var _graph_index_build_count := 0
var _current_node_id := ""
var _completed_nodes: Array[Dictionary] = []
var _resolution_ids: Dictionary = {}
var _reward_pick_history: Array[Dictionary] = []
var _pending_rewards: Array[Dictionary] = []
var _run_state: Object = TowerAscentRunState.new()
var _resolution_transaction: Object = TowerAscentNodeResolutionTransaction.new()
var _node_action_transaction: Object = TowerAscentNodeActionTransaction.new()
var _defeat_resolver: Object = TowerAscentDefeatResolver.new()
var _generated_shop_inventory: Array[Dictionary] = []
var _purchase_history: Array[Dictionary] = []
var _generated_training_offers: Array[Dictionary] = []
var _training_history: Array[Dictionary] = []
var _claimed_decoration_ids: Array[String] = []
var _build_state := {
	"mugong": [],
	"chosik": [],
	"active_items": [],
	"mythic": {},
}
var _guardian_state := {
	"soul_summoning_owned": false,
	"active_guardian": {},
	"sealed_guardians": [],
}
var _gameplay_rng_state := {"seed": 140913, "state": 140913}
var _training_timing_roll_count := 0
var _route_history: Array[Dictionary] = []
var _route_source_node_id := ""
var _route_target_ids: Array[String] = []
var _available_route_target_ids: Array[String] = []
var _route_aim_targets_cache: Array[Dictionary] = []
var _route_wind_roll_count := 0
var _route_pickup_state: Object = TowerAscentRoutePickupState.new()
var _selected_target_id := ""
var _selector_position := SELECTOR_ORIGIN
var _selector_velocity := Vector2.ZERO
var _selector_launched := false
var _aim_target_x := 220.0
var _map_transition_progress := 0.0
# 피드백2 5항: 구름 상시 드리프트 앰비언트 클록. 표현 전용이며 게임플레이
# 상태·RNG에 절대 쓰지 않는다.
var _map_ambient_drift_sec := 0.0
var _map_render_revision := 0
var _finish_callback := Callable()
var _renderer: Object = TowerAscentFlowRenderer.new()
var _map_drag_state: Object = TowerAscentMapDragState.new()
var _floor_reveal_state: Object = TowerAscentFloorRevealState.new()
var _map_generator: Object = TowerAscentMapGenerator.new()
var _route_candidate_policy: Object = TowerAscentRouteCandidatePolicy.new()
var _route_serve_runtime: Object = TowerAscentRouteServeRuntime.new()
var _shop_inventory_builder: Object = TowerAscentShopInventory.new()
var _training_offer_builder: Object = TowerAscentTrainingOfferBuilder.new()
var _fallen_monk_node: Object = TowerAscentFallenMonkNode.new()
var _guardian_spring_node: Object = TowerAscentGuardianSpringNode.new()
var _rest_node: Object = TowerAscentRestNode.new()
var _record_store: Object = TowerAscentRecordStore.new()
var _ending_state: Object = TowerAscentEndingState.new()
var _settlement_state: Object = TowerAscentSettlementState.new()
var _gauntlet_state: Object = TowerAscentGauntletState.new()
var _node_modal_state: Object = TowerAscentNodeModalState.new()
var _modal_lifecycle: Object = TowerAscentModalLifecycle.new()
var _node_modal_kind := "guardian_spring"
var _retained_noncombat_background_kind := ""
var _map_overlay_active := false
var _map_overlay_closing := false
var _map_overlay_lifecycle_owned := false
var _map_overlay_owner: Object = null
var _map_overlay_registry: Object = null
var _active_owner: Object = null
var _active_registry: Object = null
var _pending_runtime_perk_rollback_snapshot: Dictionary = {}
var _codex_discoveries: Array[Dictionary] = []
var _gauntlet_transition_callback := Callable()
var _run_defeat_count := 0
var _defeat_event_ids: Array[String] = []
var _header_subtitle := ""
var _transition_fade_state: Object = TowerAscentTransitionFadeState.new()
var _noncombat_node_background_catalog: Object = TowerNoncombatNodeBackgroundCatalog.new()
var _map_scroll_asset_catalog: Object = TowerMapScrollAssetCatalog.new()

func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null

func _make_resolution_id(node_id: String, resolution_kind: String) -> String:
	return "%s:%s:%s" % [_run_state.get_run_id(), node_id, resolution_kind]

func _reset_selector() -> void:
	_selector_position = SELECTOR_ORIGIN
	_selector_velocity = Vector2.ZERO
	_selector_launched = false
	_aim_target_x = 220.0

func _reset_runtime_state() -> void:
	_route_serve_runtime.cancel()
	_route_pickup_state.reset()
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_active_owner = null
	_active_registry = null
	_active = false
	_prepared = false
	_prepared_resolution_id = ""
	_phase = PHASE_COMBAT
	_run_state.reset()
	_header_subtitle = ""
	_graph_phases.clear()
	_active_graph_phase_index = 0
	_graph_nodes.clear()
	_graph_edges.clear()
	_graph_node_by_id.clear()
	_graph_all_phase_node_by_id.clear()
	_graph_outgoing_target_ids_by_id.clear()
	_graph_index_build_count = 0
	_map_render_revision += 1
	_current_node_id = ""
	_completed_nodes.clear()
	_resolution_ids.clear()
	_reward_pick_history.clear()
	_resolution_transaction.reset()
	_pending_rewards.clear()
	_generated_shop_inventory.clear()
	_purchase_history.clear()
	_generated_training_offers.clear()
	_training_history.clear()
	_fallen_monk_node.reset()
	_guardian_spring_node.reset()
	_rest_node.reset()
	_ending_state.reset()
	_settlement_state.reset()
	_gauntlet_state.reset()
	_pending_runtime_perk_rollback_snapshot.clear()
	_codex_discoveries.clear()
	_gauntlet_transition_callback = Callable()
	_run_defeat_count = 0
	_defeat_event_ids.clear()
	_claimed_decoration_ids.clear()
	_build_state = {
		"mugong": [],
		"chosik": [],
		"active_items": [],
		"mythic": {},
	}
	_guardian_state = {
		"soul_summoning_owned": false,
		"soul_summoning_node_id": "",
		"active_guardian": {},
		"sealed_guardians": [],
		"history": [],
		"runtime_snapshot": {},
	}
	_gameplay_rng_state = {"seed": 140913, "state": 140913}
	_training_timing_roll_count = 0
	_route_history.clear()
	_route_source_node_id = ""
	_route_target_ids.clear()
	_available_route_target_ids.clear()
	_route_aim_targets_cache.clear()
	_route_wind_roll_count = 0
	_node_modal_kind = "guardian_spring"
	_retained_noncombat_background_kind = ""
	_map_overlay_active = false
	_map_overlay_closing = false
	_map_overlay_lifecycle_owned = false
	_map_overlay_owner = null
	_map_overlay_registry = null
	_map_drag_state.reset_surface()
	_floor_reveal_state.cancel()
	_selected_target_id = ""
	_map_transition_progress = 0.0
	_transition_fade_state.reset()
	_noncombat_node_background_catalog.clear_cache()
	_map_scroll_asset_catalog.clear_cache()
	_finish_callback = Callable()
	_reset_selector()


func _prewarm_noncombat_node_background(node_kind: String) -> Dictionary:
	return _noncombat_node_background_catalog.prewarm_node_kind(node_kind)


func get_noncombat_node_background_resolution(node_kind: String) -> Dictionary:
	return _noncombat_node_background_catalog.get_cached_resolution(node_kind)


func get_noncombat_node_background_debug_state() -> Dictionary:
	return _noncombat_node_background_catalog.get_debug_state()


func _prewarm_map_scroll_assets() -> Dictionary:
	return _map_scroll_asset_catalog.prewarm_all()


func get_map_scroll_asset_resolution(asset_key: String) -> Dictionary:
	return _map_scroll_asset_catalog.get_cached_resolution(asset_key)


func get_map_scroll_asset_debug_state() -> Dictionary:
	return _map_scroll_asset_catalog.get_debug_state()


func _retain_noncombat_node_background(node_kind: String) -> void:
	_retained_noncombat_background_kind = _normalize_retained_noncombat_background_kind(
		node_kind
	)


func _clear_retained_noncombat_node_background() -> void:
	_retained_noncombat_background_kind = ""


func get_retained_noncombat_node_background_kind() -> String:
	return _retained_noncombat_background_kind if _active else ""


func get_retained_noncombat_node_background_resolution() -> Dictionary:
	var kind := get_retained_noncombat_node_background_kind()
	if kind.is_empty():
		return {}
	return _noncombat_node_background_catalog.get_cached_resolution(kind)


func has_renderable_retained_noncombat_node_background() -> bool:
	var resolution := get_retained_noncombat_node_background_resolution()
	if (
		resolution.is_empty()
		or not bool(resolution.get("ready", false))
		or bool(resolution.get("fallback_to_stage_background", false))
	):
		return false
	var source := str(resolution.get("source", ""))
	if source == "procedural":
		return true
	return source == "bitmap" and resolution.get("texture", null) is Texture2D


func _dictionary_copy(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result

func _get_owner_int(owner: Object, property_name: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else int(value)

func _is_confirm_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _request_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")

func _sync_owner_chance_gems(owner: Object) -> void:
	if owner == null:
		return
	owner.set("chance_gems_count", _run_state.get_chance_gems())
	owner.set("chance_gems_max", TowerAscentRunState.MAX_CHANCE_GEMS)

func _derive_map_seed(run_id: String, current_stage: int) -> int:
	return absi(hash("%s:%d:%s" % [run_id, current_stage, MAP_GENERATOR_VERSION]))

func _normalize_node_modal_kind(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["shop", "training", "fallen_monk", "guardian_spring", "rest", "common_shell"]:
		return normalized
	return "common_shell"


func _normalize_retained_noncombat_background_kind(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return (
		normalized
		if normalized in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
		else ""
	)


func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
