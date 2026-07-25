extends RefCounted

const FIELD_CENTER := Vector2(380.0, 375.0)

var backplate_intensity := 0.0
var backplate_alpha := 0.0
var backplate_scale := 0.6
var arc_alpha := 0.0
var arc_extension := 0.0
var icon_backdrop_alpha := 0.0
var icon_backdrop_scale := 1.0
var icon_alpha := 0.0
var icon_scale := 0.0
var icon_float_offset := 0.0
var icon_position := FIELD_CENTER
var white_flash_alpha := 0.0
var vignette_alpha := 0.0
var paddle_glow_intensity := 0.0


func begin() -> void:
	clear()
	vignette_alpha = 1.0


func clear() -> void:
	backplate_intensity = 0.0
	backplate_alpha = 0.0
	backplate_scale = 0.6
	arc_alpha = 0.0
	arc_extension = 0.0
	icon_backdrop_alpha = 0.0
	icon_backdrop_scale = 1.0
	icon_alpha = 0.0
	icon_scale = 0.0
	icon_float_offset = 0.0
	icon_position = FIELD_CENTER
	white_flash_alpha = 0.0
	vignette_alpha = 0.0
	paddle_glow_intensity = 0.0


func project_buildup(phase_timer: float, duration: float, extra_flash: float) -> void:
	var progress := clampf(phase_timer / maxf(duration, 0.0001), 0.0, 1.0)
	var eased := ease(progress, 0.4)
	backplate_alpha = eased
	backplate_intensity = lerpf(0.4, 1.0, eased) + extra_flash * 1.3
	backplate_scale = lerpf(0.55, 1.0, eased) + extra_flash * 0.04
	arc_alpha = 0.0
	arc_extension = 0.0
	icon_backdrop_alpha = 0.0
	icon_alpha = 0.0
	icon_scale = 0.0
	white_flash_alpha = extra_flash


func project_ignite(phase_timer: float, duration: float, extra_flash: float) -> void:
	var progress := clampf(phase_timer / maxf(duration, 0.0001), 0.0, 1.0)
	var eased := ease(progress, 0.3)
	var punch := ease(progress, 0.25)
	backplate_intensity = lerpf(1.9, 1.1, punch)
	backplate_alpha = 1.0
	backplate_scale = lerpf(1.30, 1.12, punch)
	arc_alpha = lerpf(1.0, 0.7, eased)
	arc_extension = eased
	icon_backdrop_alpha = 0.0
	white_flash_alpha = maxf(extra_flash, clampf((1.0 - progress) * 1.5, 0.0, 1.0))


func project_white_fade(phase_timer: float, duration: float) -> void:
	var progress := clampf(phase_timer / maxf(duration, 0.0001), 0.0, 1.0)
	white_flash_alpha = 0.4 * (1.0 - progress)
	backplate_intensity = lerpf(1.1, 0.9, progress)
	backplate_alpha = 1.0
	arc_alpha = lerpf(0.7, 0.35, progress)
	icon_backdrop_alpha = 0.0


func project_reveal(phase_timer: float, elapsed: float) -> void:
	white_flash_alpha = 0.0
	var reveal_in := clampf(phase_timer / 0.45, 0.0, 1.0)
	var reveal_eased := ease(reveal_in, 0.4)
	icon_alpha = reveal_in
	icon_scale = lerpf(0.0, 1.0, reveal_eased)
	icon_backdrop_alpha = 0.68 * reveal_eased
	icon_backdrop_scale = lerpf(0.42, 0.72, reveal_eased)
	icon_float_offset = sin(elapsed * 1.6) * 5.0
	backplate_intensity = 0.42 + 0.04 * sin(elapsed * 1.3)
	backplate_alpha = 0.62
	arc_alpha = 0.35 + 0.05 * sin(elapsed * 0.9)


func project_absorb(phase_timer: float, duration: float, player_center: Vector2) -> void:
	var progress := clampf(phase_timer / maxf(duration, 0.0001), 0.0, 1.0)
	var eased := ease(progress, 0.6)
	backplate_alpha = lerpf(1.0, 0.0, eased)
	backplate_intensity = lerpf(0.95, 1.5, eased)
	backplate_scale = lerpf(1.0, 0.35, eased)
	arc_alpha = lerpf(0.35, 0.0, eased)
	icon_backdrop_alpha = lerpf(0.68, 0.18, eased)
	icon_backdrop_scale = lerpf(0.72, 0.38, eased)
	var spiral_angle := eased * TAU * 1.8
	var radius := (1.0 - eased) * 60.0
	var spiral_position := Vector2(cos(spiral_angle), sin(spiral_angle)) * radius
	icon_position = FIELD_CENTER.lerp(player_center, eased) + spiral_position
	icon_alpha = lerpf(1.0, 0.4, eased)
	icon_scale = lerpf(1.0, 0.25, eased)


func start_impact() -> void:
	paddle_glow_intensity = 1.0


func project_impact(phase_timer: float, duration: float) -> void:
	var progress := clampf(phase_timer / maxf(duration, 0.0001), 0.0, 1.0)
	paddle_glow_intensity = 1.0 - progress
	white_flash_alpha = clampf(1.0 - progress * 2.4, 0.0, 1.0) * 0.6
	icon_alpha = 0.0
	icon_backdrop_alpha = 0.0
	backplate_alpha = 0.0
	arc_alpha = 0.0
