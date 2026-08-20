extends SceneTree

const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerNoncombatNodeBackgroundCatalog := preload(
	"res://scripts/tower_ascent/tower_noncombat_node_background_catalog.gd"
)

const BITMAP_NODE_KINDS := ["shop", "training", "fallen_monk", "guardian_spring"]

var _failures: Array[String] = []
var _cold_prewarm_max_usec := 0


func _init() -> void:
	_verify_unique_owner_contract_and_promoted_art()
	_verify_missing_asset_fallback()
	_verify_flow_owner_prewarm_bridge_and_order()
	_verify_snapshot_restore_rewarms_before_surface_use()
	if _failures.is_empty():
		print(
			"tower_noncombat_node_background_contract_smoke: cold_prewarm_max_usec=%d"
			% _cold_prewarm_max_usec
		)
		print("tower_noncombat_node_background_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_unique_owner_contract_and_promoted_art() -> void:
	var catalog := TowerNoncombatNodeBackgroundCatalog.new()
	var declared_paths: Dictionary = {}
	for kind in BITMAP_NODE_KINDS:
		var path := catalog.resolve_declared_path(kind)
		_expect(path.begins_with("res://assets/sprites/tower/noncombat/"), "%s must resolve inside the canonical background root" % kind)
		_expect(not declared_paths.has(path), "%s must not share another node background path" % kind)
		declared_paths[path] = true
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s approved background must be imported" % kind)

		var cold_peek: Dictionary = catalog.get_cached_resolution(kind)
		_expect(not bool(cold_peek.get("cached", true)), "%s draw-side peek must not probe the filesystem" % kind)
		_expect(bool(cold_peek.get("fallback_to_stage_background", false)), "%s cold peek must preserve the current stage background" % kind)

		var first: Dictionary = catalog.prewarm_node_kind(kind)
		var second: Dictionary = catalog.prewarm_node_kind(kind)
		_cold_prewarm_max_usec = maxi(_cold_prewarm_max_usec, int(first.get("cold_prewarm_usec", 0)))
		var texture := first.get("texture", null) as Texture2D
		_expect(bool(first.get("ready", false)), "%s approved background must be ready" % kind)
		_expect(not bool(first.get("fallback_to_stage_background", true)), "%s approved background must not use the stage fallback" % kind)
		_expect(str(first.get("reason", "")) == "texture_ready", "%s must classify the promoted asset" % kind)
		_expect(texture != null, "%s must load a Texture2D" % kind)
		if texture != null:
			_expect(texture.get_width() == 1254 and texture.get_height() == 1254, "%s must retain the approved 1254x1254 geometry" % kind)
		_expect(bool(second.get("cache_hit", false)), "%s repeated prewarm must reuse the cached texture" % kind)
		_expect(int(second.get("cold_prewarm_usec", -1)) == 0, "%s cached prewarm must perform no cold work" % kind)

	var rest_path := catalog.resolve_declared_path("rest")
	_expect(rest_path == TowerNoncombatNodeBackgroundCatalog.REST_CAMP_PROCEDURAL_PATH, "rest must retain R4's procedural camp instead of adding a fifth bitmap")
	_expect(not declared_paths.has(rest_path), "rest must retain a distinct resolved background identity")
	var rest: Dictionary = catalog.prewarm_node_kind("rest")
	_expect(bool(rest.get("ready", false)), "the existing procedural rest camp must be immediately ready")
	_expect(not bool(rest.get("fallback_to_stage_background", true)), "the procedural rest camp must not collapse into the stage fallback")

	var unknown_first: Dictionary = catalog.prewarm_node_kind("../unsafe")
	var unknown_second: Dictionary = catalog.prewarm_node_kind("another-unsafe-kind")
	_expect(bool(unknown_first.get("fallback_to_stage_background", false)), "unknown kinds must fail closed to the stage background")
	_expect(bool(unknown_second.get("cache_hit", false)), "unknown-kind misses must share one bounded negative-cache entry")

	var debug_state: Dictionary = catalog.get_debug_state()
	var attempts: Dictionary = debug_state.get("load_attempt_by_path", {})
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == BITMAP_NODE_KINDS.size(), "GRT-004: each promoted bitmap path must hit the filesystem exactly once")
	_expect(int(debug_state.get("resource_load_count", -1)) == BITMAP_NODE_KINDS.size(), "each promoted bitmap path must load exactly once")
	for path_variant in declared_paths:
		_expect(int(attempts.get(str(path_variant), 0)) == 1, "GRT-004: cached texture must own one load attempt for %s" % str(path_variant))

	var owner_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_noncombat_node_background_catalog.gd"
	)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(owner_source.find("preload(") < 0, "the background owner must never const-preload approval-gated art")
	_expect(owner_source.find("ResourceLoader.exists") >= 0 and owner_source.find("ResourceLoader.load") >= 0, "the background owner must use guarded runtime loading")
	_expect(renderer_source.find("shop_arena_background_imagegen_v1.png") < 0, "renderers must not know background path literals")


func _verify_missing_asset_fallback() -> void:
	var missing_catalog := TowerNoncombatNodeBackgroundCatalog.new(
		func(_path: String) -> bool: return false,
		func(_path: String) -> Resource: return null
	)
	var first: Dictionary = missing_catalog.prewarm_node_kind("shop")
	var second: Dictionary = missing_catalog.prewarm_node_kind("shop")
	_expect(bool(first.get("fallback_to_stage_background", false)), "a missing approved bitmap must preserve the current stage background")
	_expect(str(first.get("reason", "")) == "missing_asset", "a failed existence probe must retain the missing_asset reason")
	_expect(first.get("texture", null) == null, "a missing bitmap must not fabricate a texture")
	_expect(bool(second.get("cache_hit", false)), "a missing bitmap must retain the GRT-004 negative cache")
	var debug_state: Dictionary = missing_catalog.get_debug_state()
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == 1, "a cached missing bitmap must execute one existence probe")
	_expect(int(debug_state.get("resource_load_count", -1)) == 0, "a missing bitmap must not call the resource loader")


func _verify_flow_owner_prewarm_bridge_and_order() -> void:
	var flow := TowerAscentFlowOwner.new()
	var cold: Dictionary = flow.get_noncombat_node_background_resolution("shop")
	_expect(not bool(cold.get("cached", true)), "the production flow must begin without a draw-time filesystem probe")
	var warmed: Dictionary = flow.call("_prewarm_noncombat_node_background", "shop")
	_expect(bool(warmed.get("ready", false)), "the production flow bridge must expose promoted art")
	_expect(not bool(warmed.get("fallback_to_stage_background", true)), "the production flow bridge must not fall back when promoted art is ready")
	var cached: Dictionary = flow.get_noncombat_node_background_resolution("shop")
	_expect(bool(cached.get("cached", false)), "the production flow bridge must expose the warmed cache")

	var map_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"
	)
	var resolve_body := _function_body(map_source, "func _resolve_route_target(")
	var prewarm_index := resolve_body.find("_prewarm_noncombat_node_background(target_kind)")
	var transition_index := resolve_body.find("_phase = PHASE_MAP_TRANSITION")
	_expect(prewarm_index >= 0, "the route-selection production owner must prewarm the chosen noncombat kind")
	_expect(transition_index > prewarm_index, "GRT-003: prewarm must finish before MAP_TRANSITION begins")


func _verify_snapshot_restore_rewarms_before_surface_use() -> void:
	var snapshot_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_snapshot_progress.gd"
	)
	var restore_body := _function_body(snapshot_source, "func restore_snapshot(")
	_expect(
		restore_body.find("_prewarm_noncombat_node_background(selected_kind)") >= 0,
		"a MAP_TRANSITION snapshot restore must rebuild the selected-node cache"
	)
	_expect(
		restore_body.find("_prewarm_noncombat_node_background(current_kind)") >= 0,
		"a NODE_MODAL snapshot restore must rebuild the current-node cache"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_func < 0 else source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
