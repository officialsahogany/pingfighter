extends RefCounted

# Last-known live boss geometry for Stage 7 Akamu Rigo.
#
# Update, gameplay-freeze, collision, Awakening, and Superspeed consumers all
# share this snapshot so missing or transitional contexts keep one fallback
# contract. The snapshot is data-only and performs no scene mutation.

const DEFAULT_BOSS_POS := Vector2(330.0, 25.0)
const DEFAULT_BOSS_SIZE := Vector2(100.0, 40.0)
const MIN_VISUAL_SCALE := 0.2
const MAX_VISUAL_SCALE := 1.0

var boss_pos := DEFAULT_BOSS_POS
var boss_size := DEFAULT_BOSS_SIZE
var visual_scale := MAX_VISUAL_SCALE


func reset() -> void:
	boss_pos = DEFAULT_BOSS_POS
	boss_size = DEFAULT_BOSS_SIZE
	visual_scale = MAX_VISUAL_SCALE


func sync(context: Dictionary) -> void:
	boss_pos = resolve_position(context)
	boss_size = resolve_size(context)
	visual_scale = clampf(
		float(context.get("boss_paddle_shrink_scale", visual_scale)),
		MIN_VISUAL_SCALE,
		MAX_VISUAL_SCALE
	)


func set_snapshot(next_boss_pos: Vector2, next_boss_size: Vector2) -> void:
	boss_pos = next_boss_pos
	boss_size = next_boss_size


func resolve_position(context: Dictionary) -> Vector2:
	return _as_vector2(context.get("boss_pos", boss_pos), boss_pos)


func resolve_size(context: Dictionary) -> Vector2:
	var legacy_size := Vector2(
		float(context.get("boss_paddle_width", boss_size.x)),
		float(context.get("boss_hitbox_height", boss_size.y))
	)
	return _as_vector2(context.get("boss_paddle_size", legacy_size), boss_size)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
