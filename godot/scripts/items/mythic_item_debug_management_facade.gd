extends RefCounted


func prewarm_assets(runtime: Object) -> void:
	if runtime == null or runtime.debug_management_menu == null:
		return
	if runtime.debug_management_menu.has_method("prewarm_assets"):
		runtime.debug_management_menu.prewarm_assets(runtime)


func toggle_menu(runtime: Object, initial_tab: int = 0) -> void:
	if runtime == null or runtime.debug_management_menu == null:
		return
	prewarm_assets(runtime)
	runtime.debug_management_menu.toggle(initial_tab)


func close_menu(runtime: Object) -> void:
	if runtime == null or runtime.debug_management_menu == null:
		return
	runtime.debug_management_menu.close()


func is_menu_open(runtime: Object) -> bool:
	if runtime == null or runtime.debug_management_menu == null:
		return false
	return bool(runtime.debug_management_menu.is_open())


func handle_menu_input(
	runtime: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if runtime == null or runtime.debug_management_menu == null:
		return false
	return bool(runtime.debug_management_menu.handle_input(event, owner, registry, view_size))


func draw_menu(
	runtime: Object,
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> void:
	if runtime == null or runtime.debug_management_menu == null:
		return
	runtime.debug_management_menu.draw(canvas, owner, registry, view_size)
