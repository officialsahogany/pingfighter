extends RefCounted

const ACQUISITION_CINEMATIC_SCRIPT_PATH := "res://scripts/items/mythic_item_acquisition_cinematic_v2.gd"
const MythicAcquisitionCinematic := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const MythicItemCatalogIconMetadata := preload("res://scripts/items/mythic_item_catalog_icon_metadata.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")


func prewarm(runtime: Object, owner: Object = null, registry: Object = null) -> void:
	prewarm_assets()
	prewarm_item_textures()
	if runtime.acquisition_cinematic != null or not (owner is Node):
		return
	if ensure_host(runtime, owner):
		runtime.acquisition_cinematic.reset(registry)


# Warms the per-item mythic icon sheets into the ProjectResourceLoader path
# cache so trigger()'s _load_item_texture does not pay a cold texture load
# inside the first-pickup store sample. Sheets are 7~39KB each; the whole
# batch is a few ms on a loading/intro frame.
func prewarm_item_textures() -> void:
	for path_value in MythicItemCatalogIconMetadata.MYTHIC_ICON_SHEET_PATHS.values():
		var path: String = str(path_value)
		if path != "":
			ProjectResourceLoader.load_imported_texture(path)
	for path_value in RuntimePerkIconRenderer.PERK_SHEET_PATHS.values():
		var perk_path: String = str(path_value)
		if perk_path != "":
			ProjectResourceLoader.load_imported_texture(perk_path)


func reset(runtime: Object, registry: Object = null) -> void:
	if runtime.acquisition_cinematic != null:
		runtime.acquisition_cinematic.reset(registry)


func is_active(runtime: Object) -> bool:
	return runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.is_active()


func start(
	runtime: Object,
	acquired_item_data: Dictionary,
	pickup_position: Vector2,
	owner: Object,
	registry: Object = null,
	target_player_center_override: Vector2 = Vector2.INF,
	context_constants: Dictionary = {},
	fallback_player_center: Vector2 = Vector2.ZERO
) -> bool:
	if acquired_item_data.is_empty():
		return false
	if not should_use_item_data(acquired_item_data):
		return false
	prewarm_assets()
	if runtime.acquisition_cinematic == null and not ensure_host(runtime, owner):
		return false
	runtime.acquisition_cinematic.trigger(
		acquired_item_data,
		pickup_position,
		resolve_player_center(owner, context_constants, fallback_player_center) if target_player_center_override == Vector2.INF else target_player_center_override,
		registry
	)
	return true


func handle_input(runtime: Object, event: InputEvent, registry: Object = null) -> bool:
	if runtime.acquisition_cinematic == null:
		return false
	return runtime.acquisition_cinematic.handle_input(event, registry)


func get_snapshot(runtime: Object) -> Dictionary:
	if runtime.acquisition_cinematic == null:
		return {}
	return runtime.acquisition_cinematic.get_snapshot()


func update(
	runtime: Object,
	delta: float,
	registry: Object = null,
	owner: Object = null
) -> void:
	if runtime.acquisition_cinematic == null:
		return
	var was_active: bool = runtime.acquisition_cinematic.is_active()
	var previous_snapshot: Dictionary = (
		runtime.acquisition_cinematic.get_snapshot()
		if was_active and runtime.acquisition_cinematic.has_method("get_snapshot")
		else {}
	)
	runtime.acquisition_cinematic.update(delta, registry)
	if was_active and not runtime.acquisition_cinematic.is_active():
		_notify_natural_completion(previous_snapshot, owner, registry)


func _notify_natural_completion(
	previous_snapshot: Dictionary,
	owner: Object,
	registry: Object
) -> void:
	var item_data_value: Variant = previous_snapshot.get("item_data", {})
	var item_data: Dictionary = item_data_value if item_data_value is Dictionary else {}
	var perk_id: String = str(
		item_data.get("perk_id", item_data.get("id", ""))
	).strip_edges()
	if perk_id == "" or registry == null or not registry.has_method("get_instance"):
		return
	var runtime_perk_state: Object = registry.get_instance("runtime_perk_state")
	if (
		runtime_perk_state != null
		and runtime_perk_state.has_method("on_angel_blessing_acquisition_cinematic_finished")
	):
		runtime_perk_state.on_angel_blessing_acquisition_cinematic_finished(
			perk_id,
			owner,
			registry
		)


func get_cinematic_script() -> Variant:
	return MythicAcquisitionCinematic


func prewarm_assets() -> void:
	var cinematic_script: Variant = get_cinematic_script()
	if cinematic_script != null and cinematic_script.has_method("prewarm_assets"):
		cinematic_script.prewarm_assets()
		return
	while not prewarm_static_assets_step():
		pass


func prewarm_static_assets() -> void:
	prewarm_assets()


func prewarm_static_assets_step() -> bool:
	var cinematic_script: Variant = get_cinematic_script()
	if cinematic_script == null:
		return true
	if cinematic_script.has_method("prewarm_assets_step"):
		return bool(cinematic_script.prewarm_assets_step())
	if cinematic_script.has_method("prewarm_assets"):
		cinematic_script.prewarm_assets()
	return true


func ensure_host(runtime: Object, owner: Object) -> bool:
	if runtime.acquisition_cinematic != null:
		return true
	if not (owner is Node):
		return false
	var cinematic_script: Variant = get_cinematic_script()
	if cinematic_script == null:
		return false
	var node: Node2D = cinematic_script.new()
	(owner as Node).add_child(node)
	runtime.acquisition_cinematic = node
	return true


func should_use_item_data(item_data: Dictionary) -> bool:
	var cinematic_script: Variant = get_cinematic_script()
	if cinematic_script == null:
		return false
	return bool(cinematic_script.should_use_item_data(item_data))


func resolve_player_center(
	owner: Object,
	context_constants: Dictionary = {},
	fallback_player_center: Vector2 = Vector2.ZERO
) -> Vector2:
	var cinematic_script: Variant = get_cinematic_script()
	if cinematic_script == null:
		return fallback_player_center
	return cinematic_script.resolve_player_center(owner, context_constants)
