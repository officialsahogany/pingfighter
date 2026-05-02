extends RefCounted


func clear_ball_effects(deps: Dictionary, clear_all_effects: bool) -> void:
	var ball_effects = deps.get("ball_effects", null)
	if ball_effects == null:
		return
	if clear_all_effects:
		ball_effects.clear_all()
	else:
		ball_effects.clear_intensity()


func clear_impact_effects(deps: Dictionary) -> void:
	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.clear_all()


func clear_ball_renderer(deps: Dictionary) -> void:
	var ball_renderer = deps.get("ball_renderer", null)
	if ball_renderer != null:
		ball_renderer.clear()


func reset_ball_rally(deps: Dictionary) -> void:
	var ball_intensity = deps.get("ball_intensity", null)
	if ball_intensity != null:
		ball_intensity.reset()
	clear_ball_effects(deps, false)
