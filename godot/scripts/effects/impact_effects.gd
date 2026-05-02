extends RefCounted

const ImpactEnergyEffectState := preload("res://scripts/effects/impact_energy_effect_state.gd")
const ImpactPaddleEffectState := preload("res://scripts/effects/impact_paddle_effect_state.gd")
const ImpactWallEffectState := preload("res://scripts/effects/impact_wall_effect_state.gd")

var paddle_state: Object = ImpactPaddleEffectState.new()
var wall_state: Object = ImpactWallEffectState.new()
var energy_state: Object = ImpactEnergyEffectState.new()


func clear_all() -> void:
	paddle_state.clear()
	wall_state.clear()
	energy_state.clear()


func spawn_hit_particles(pos: Vector2, color: Color) -> void:
	paddle_state.spawn_hit_particles(pos, color)


func spawn_paddle_hit_particles(pos: Vector2, is_player: bool) -> void:
	paddle_state.spawn_paddle_hit_particles(pos, is_player)


func create_energy_explosion(pos: Vector2, scale: float, intensity: float) -> void:
	energy_state.create_energy_explosion(pos, scale, intensity)


func spawn_drive_particles(pos: Vector2, count: int = 4) -> void:
	energy_state.spawn_drive_particles(pos, count)


func spawn_wall_impact(pos: Vector2, side: String, impact_speed: float) -> void:
	wall_state.spawn_wall_impact(pos, side, impact_speed)


func update(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	paddle_state.update(delta)
	wall_state.update(delta)
	energy_state.update(fps_scale)


func get_hit_particles() -> Array[Dictionary]:
	return paddle_state.get_hit_particles()


func get_wall_impact_particles() -> Array[Dictionary]:
	return wall_state.get_wall_impact_particles()


func get_wall_impact_flash_timer() -> float:
	return wall_state.get_wall_impact_flash_timer()


func get_wall_impact_position() -> Vector2:
	return wall_state.get_wall_impact_position()


func get_energy_explosion_particles() -> Array[Dictionary]:
	return energy_state.get_energy_explosion_particles()
