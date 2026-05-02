extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const Stage1PlayfieldRenderer := preload("res://scripts/stages/stage1/stage1_playfield_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1BossActorRenderer := preload("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")

var playfield_renderer: Object = Stage1PlayfieldRenderer.new()
var player_renderer: Object = Stage1PlayerActorRenderer.new()
var boss_renderer: Object = Stage1BossActorRenderer.new()


func draw(canvas: CanvasItem, context: Dictionary) -> void:
	if canvas == null:
		return

	var shake_offset: Vector2 = _as_vector2(context.get("shake_offset", Vector2.ZERO), Vector2.ZERO)
	playfield_renderer.draw(canvas, context, shake_offset)
	playfield_renderer.draw_dash_trail(canvas, context, shake_offset)
	player_renderer.draw(canvas, context, shake_offset)
	boss_renderer.draw(canvas, context, shake_offset)


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)
