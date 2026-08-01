extends Node2D

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

var _progress := 1.0


func sync_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	visible = _progress < 1.0
	if visible:
		queue_redraw()


func set_active(active: bool) -> void:
	visible = active and _progress < 1.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var expansion := 1.0 - pow(1.0 - _progress, 3.0)
	var fade := pow(1.0 - _progress, 0.72)
	ImpactFlareTextureCache.draw_glow(self, Vector2.ZERO, lerpf(64.0, 196.0, expansion), Color(1.0, 0.035, 0.012), 0.94 * fade)
	ImpactFlareTextureCache.draw_glow(self, Vector2.ZERO, lerpf(34.0, 118.0, expansion), Color(1.0, 0.34, 0.045), fade)
	ImpactFlareTextureCache.draw_sparkle(self, Vector2.ZERO, lerpf(24.0, 52.0, expansion), Color(1.0, 0.97, 0.80), fade)
