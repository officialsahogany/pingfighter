extends RefCounted

const StageClearResultViewportLayout := preload("res://scripts/ui/stage_clear_result_viewport_layout.gd")


static func get_current_view_size(scene: Control) -> Vector2:
	return StageClearResultViewportLayout.get_current_view_size(scene)


static func get_layout_scale(view_size: Vector2) -> float:
	return StageClearResultViewportLayout.get_layout_scale(view_size)


static func get_view_size(scene: Control) -> Vector2:
	return StageClearResultViewportLayout.get_view_size(scene)


static func sync_control_to_viewport(scene: Control) -> Vector2:
	return StageClearResultViewportLayout.sync_control_to_viewport(scene)
