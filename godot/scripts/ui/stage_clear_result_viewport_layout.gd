extends RefCounted

const DEFAULT_VIEW_SIZE := Vector2(1920.0, 1080.0)


static func get_layout_scale(view_size: Vector2) -> float:
	return 1.0 if view_size.x <= 0.0 or view_size.y <= 0.0 else min(view_size.x / DEFAULT_VIEW_SIZE.x, view_size.y / DEFAULT_VIEW_SIZE.y)


static func get_view_size(control: Control) -> Vector2:
	if control == null:
		return DEFAULT_VIEW_SIZE
	var viewport: Viewport = control.get_viewport()
	return viewport.get_visible_rect().size if viewport != null else DEFAULT_VIEW_SIZE


static func get_current_view_size(control: Control) -> Vector2:
	if control == null:
		return DEFAULT_VIEW_SIZE
	return control.size if control.size != Vector2.ZERO else get_view_size(control)


static func sync_control_to_viewport(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	var view_size: Vector2 = get_view_size(control)
	if view_size == Vector2.ZERO:
		return Vector2.ZERO
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = Vector2.ZERO
	control.size = view_size
	return view_size
