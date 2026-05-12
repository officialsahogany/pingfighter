extends RefCounted

const SkillOrbTooltipOverlay := preload("res://scripts/hud/skill_orb_tooltip_overlay.gd")

var _overlay: Node2D = null


func queue_redraw(owner: Object, registry: Object) -> void:
	var overlay: Node2D = _get_overlay(owner)
	if overlay == null:
		return
	if overlay.has_method("configure"):
		overlay.configure(owner, registry)
	overlay.visible = true
	overlay.queue_redraw()


func hide() -> void:
	if _overlay == null:
		return
	if not is_instance_valid(_overlay):
		_overlay = null
		return
	_overlay.visible = false


func clear() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _get_overlay(owner: Object) -> Node2D:
	if _overlay != null and is_instance_valid(_overlay):
		return _overlay
	var owner_node: Node = owner as Node
	if owner_node == null:
		return null
	var overlay: Node2D = SkillOrbTooltipOverlay.new()
	overlay.name = "SkillOrbTooltipOverlay"
	overlay.top_level = true
	overlay.z_index = 1000
	overlay.visible = false
	owner_node.add_child(overlay)
	_overlay = overlay
	return _overlay
