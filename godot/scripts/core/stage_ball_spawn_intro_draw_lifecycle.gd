extends RefCounted


# Routes the per-frame layout sync into the FX host. The intro's `_draw_spawn`
# now renders inside the FX host's playfield-clipped bridge layer, so this
# function intentionally does NOT call `canvas.draw_*` — drawing on the battle
# scene canvas would bypass the playfield clip and bleed into the pillar
# columns (game x=0..80 and 680..760).
func draw_intro(intro: Object, canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	if intro == null or canvas == null or owner == null or registry == null or not _is_overlay_active(intro):
		return
	var layout: Dictionary = intro._build_layout(registry, view_size)
	intro._sync_fx_host_layout(layout)


func _is_overlay_active(intro: Object) -> bool:
	if intro.has_method("is_overlay_active"):
		return bool(intro.is_overlay_active())
	return bool(intro.active)
