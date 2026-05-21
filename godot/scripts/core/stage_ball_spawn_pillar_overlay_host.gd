extends Node2D

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")

var drawer: Object = BattleSceneDrawer.new()
var registry: Object = null
var context_owner: Object = null
var active := false


func begin(next_registry: Object, next_context_owner: Object = null) -> void:
	registry = next_registry
	context_owner = next_context_owner
	active = true
	visible = true
	z_as_relative = false
	z_index = 950
	queue_redraw()


func sync_active(next_active: bool) -> void:
	if active == next_active and visible == next_active:
		return
	active = next_active
	visible = next_active
	queue_redraw()


func tear_down(free_self: bool = false) -> void:
	active = false
	visible = false
	registry = null
	context_owner = null
	if free_self:
		queue_free()


func _draw() -> void:
	if not active or registry == null:
		return
	drawer.draw_pillar_overlay(self, registry, {
		"context_owner": context_owner,
		"skip_background": true,
	})
