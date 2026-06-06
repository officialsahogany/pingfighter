extends RefCounted


static func handle_runtime_perk_input(
	event: InputEvent,
	runtime_perk_state: Object,
	runtime_perk_owner: Object,
	runtime_perk_registry: Object,
	view_size: Vector2
) -> bool:
	if runtime_perk_state == null or not runtime_perk_state.has_method("handle_input"):
		return true
	runtime_perk_state.handle_input(event, runtime_perk_owner, runtime_perk_registry, view_size)
	return true


static func handle_mythic_acquisition_input(
	event: InputEvent,
	mythic_item_runtime: Object,
	runtime_perk_registry: Object
) -> bool:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		mythic_item_runtime.handle_acquisition_cinematic_input(event, runtime_perk_registry)
	return true


static func is_mythic_acquisition_cinematic_active(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		and bool(mythic_item_runtime.is_acquisition_cinematic_active())
	)


static func is_treasure_hunt_effect_active(treasure_hunt_runtime: Object) -> bool:
	return (
		treasure_hunt_runtime != null
		and treasure_hunt_runtime.has_method("is_effect_active")
		and bool(treasure_hunt_runtime.is_effect_active())
	)


static func is_runtime_perk_choice_active(runtime_perk_state: Object) -> bool:
	return (
		runtime_perk_state != null
		and runtime_perk_state.has_method("is_choice_active")
		and bool(runtime_perk_state.is_choice_active())
	)


static func is_interaction_blocked(
	starpoint_choice_gate_active: bool,
	runtime_perk_state: Object,
	treasure_hunt_runtime: Object
) -> bool:
	return (
		starpoint_choice_gate_active
		or is_runtime_perk_choice_active(runtime_perk_state)
		or is_treasure_hunt_effect_active(treasure_hunt_runtime)
	)


static func should_draw_overlay(
	runtime_perk_overlay_renderer: Object,
	runtime_perk_state: Object,
	mythic_item_runtime: Object,
	treasure_hunt_runtime: Object
) -> bool:
	if is_runtime_perk_choice_active(runtime_perk_state) or is_treasure_hunt_effect_active(treasure_hunt_runtime):
		return true
	if runtime_perk_overlay_renderer != null and runtime_perk_overlay_renderer.has_method("has_visible_effects"):
		return bool(runtime_perk_overlay_renderer.has_visible_effects(
			runtime_perk_state,
			mythic_item_runtime,
			treasure_hunt_runtime
		))
	return false


static func draw_overlay(
	canvas: CanvasItem,
	runtime_perk_overlay_renderer: Object,
	runtime_perk_state: Object,
	fallback_perk_catalog: Object,
	runtime_perk_catalog: Object,
	fallback_perk_icon_renderer: Object,
	runtime_perk_icon_renderer: Object,
	view_size: Vector2,
	mythic_item_runtime: Object,
	treasure_hunt_runtime: Object
) -> bool:
	if not should_draw_overlay(
		runtime_perk_overlay_renderer,
		runtime_perk_state,
		mythic_item_runtime,
		treasure_hunt_runtime
	):
		return false
	if runtime_perk_overlay_renderer == null or not runtime_perk_overlay_renderer.has_method("draw"):
		return false
	var catalog: Object = runtime_perk_catalog if runtime_perk_catalog != null else fallback_perk_catalog
	var icon_renderer: Object = runtime_perk_icon_renderer if runtime_perk_icon_renderer != null else fallback_perk_icon_renderer
	runtime_perk_overlay_renderer.draw(
		canvas,
		runtime_perk_state,
		catalog,
		view_size,
		icon_renderer,
		mythic_item_runtime,
		treasure_hunt_runtime
	)
	return true
