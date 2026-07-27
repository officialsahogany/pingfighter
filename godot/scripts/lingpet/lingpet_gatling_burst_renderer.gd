extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const TRANSFORM_SHEET_PATH := "res://assets/sprites/lingpet/volty_gatling_tank_transform.png"
const TRANSFORM_FRAME_COUNT := 25
const TRANSFORM_COLUMNS := 5
const TRANSFORM_CHASSIS_FRAME_INDEX := 11
const TANK_SOURCE_DRAW_SIZE := 118.0
const TANK_DRAW_SIZE := 96.0
const TANK_VISUAL_SCALE := TANK_DRAW_SIZE / TANK_SOURCE_DRAW_SIZE
const CANNON_LENGTH := 42.0 * TANK_VISUAL_SCALE

const BULLET_SPEED := 620.0
const BULLET_LENGTH := 8.0
const BULLET_WIDTH := 3.0
const MUZZLE_FLASH_SECONDS := 0.08
const TRAIL_STEPS := 5
const TRAIL_STEP_SECONDS := 0.012
const CANNON_MOUNT_PROGRESS_START := 0.45

var _textures_prewarmed := false
var _transform_texture: Texture2D = null


func prewarm() -> void:
	if _textures_prewarmed:
		return
	_transform_texture = ProjectResourceLoader.load_texture(TRANSFORM_SHEET_PATH)
	if _transform_texture != null:
		_transform_texture.get_size()
	_textures_prewarmed = true


func draw_gatling_burst(
	canvas: CanvasItem,
	shake_offset: Vector2,
	active: bool,
	mounting: bool,
	dismounting: bool,
	tank_center: Vector2,
	aim_angle: float,
	recoil_offset: float,
	muzzle_flash_timer: float,
	mount_progress: float,
	dismount_progress: float,
	transform_frame_index: int,
	bullets: Array[Dictionary],
	hit_particles: Array[Dictionary],
	shell_casings: Array[Dictionary],
	smoke_puffs: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	_draw_smoke(canvas, smoke_puffs, shake_offset)
	_draw_bullets(canvas, bullets, shake_offset)
	_draw_hit_particles(canvas, hit_particles, shake_offset)
	_draw_shell_casings(canvas, shell_casings, shake_offset)
	if active:
		_draw_tank_body(
			canvas,
			tank_center + shake_offset,
			aim_angle,
			recoil_offset,
			muzzle_flash_timer,
			mounting,
			dismounting,
			mount_progress,
			dismount_progress,
			transform_frame_index
		)


func get_visual_tuning_for_tests() -> Dictionary:
	return {
		"tank_draw_size": TANK_DRAW_SIZE,
		"tank_visual_scale": TANK_VISUAL_SCALE,
		"transform_frame_count": TRANSFORM_FRAME_COUNT,
		"transform_chassis_frame_index": TRANSFORM_CHASSIS_FRAME_INDEX,
	}


func _draw_tank_body(
	canvas: CanvasItem,
	tank_center: Vector2,
	aim_angle: float,
	recoil_offset: float,
	muzzle_flash_timer: float,
	mounting: bool,
	dismounting: bool,
	mount_progress: float,
	dismount_progress: float,
	frame_index: int
) -> void:
	var alpha := 1.0
	if mounting:
		alpha = lerpf(0.82, 1.0, mount_progress)
	elif dismounting:
		alpha = lerpf(1.0, 0.78, dismount_progress)
	var texture := _get_transform_texture()
	if texture != null:
		_draw_transform_frame(canvas, texture, frame_index, tank_center, alpha)
	else:
		_draw_fallback_tank(canvas, tank_center, alpha)
	_draw_cannon_overlay(
		canvas,
		tank_center,
		aim_angle,
		recoil_offset,
		muzzle_flash_timer,
		alpha * _get_cannon_alpha(mounting, dismounting, mount_progress, dismount_progress)
	)
	if mounting:
		_draw_mount_bar(canvas, tank_center + Vector2(0.0, -58.0 * TANK_VISUAL_SCALE), mount_progress, TANK_VISUAL_SCALE)


func _draw_transform_frame(canvas: CanvasItem, texture: Texture2D, frame_index: int, center: Vector2, alpha: float) -> void:
	var rows := maxi(1, ceili(float(TRANSFORM_FRAME_COUNT) / float(TRANSFORM_COLUMNS)))
	var frame_w := float(texture.get_width()) / float(TRANSFORM_COLUMNS)
	var frame_h := float(texture.get_height()) / float(rows)
	if frame_w <= 0.0 or frame_h <= 0.0:
		return
	var col := frame_index % TRANSFORM_COLUMNS
	var row := int(floor(float(frame_index) / float(TRANSFORM_COLUMNS)))
	var src := Rect2(Vector2(float(col) * frame_w, float(row) * frame_h), Vector2(frame_w, frame_h))
	var dest := Rect2(center - Vector2(TANK_DRAW_SIZE, TANK_DRAW_SIZE) * 0.5, Vector2(TANK_DRAW_SIZE, TANK_DRAW_SIZE))
	canvas.draw_texture_rect_region(texture, dest, src, Color(1.0, 1.0, 1.0, alpha), false, true)


func _draw_cannon_overlay(
	canvas: CanvasItem,
	tank_center: Vector2,
	aim_angle: float,
	recoil_offset: float,
	muzzle_flash_timer: float,
	alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var direction := Vector2(cos(aim_angle), sin(aim_angle))
	var scale := TANK_VISUAL_SCALE
	var mount := tank_center + Vector2(0.0, -10.0 * scale) - direction * recoil_offset * scale
	var tip := mount + direction * CANNON_LENGTH
	canvas.draw_line(mount + Vector2(1.5, 2.0) * scale, tip + Vector2(1.5, 2.0) * scale, Color(0.02, 0.03, 0.04, 0.58 * alpha), maxf(1.0, 8.0 * scale), true)
	canvas.draw_line(mount, tip, Color(0.15, 0.17, 0.20, 0.92 * alpha), maxf(1.0, 6.0 * scale), true)
	canvas.draw_line(mount, tip, Color(0.62, 0.74, 0.82, 0.72 * alpha), maxf(1.0, 2.0 * scale), true)
	canvas.draw_circle(mount, 7.0 * scale, Color(0.10, 0.14, 0.18, 0.88 * alpha))
	canvas.draw_circle(mount, 3.2 * scale, Color(0.44, 0.96, 1.0, 0.70 * alpha))
	if muzzle_flash_timer > 0.0:
		var ratio := clampf(muzzle_flash_timer / MUZZLE_FLASH_SECONDS, 0.0, 1.0)
		canvas.draw_circle(tip, 12.0 * scale * ratio, Color(1.0, 0.84, 0.28, 0.58 * ratio))
		canvas.draw_line(tip - direction * 3.0 * scale, tip + direction * 18.0 * scale * ratio, Color(1.0, 0.95, 0.68, 0.82 * ratio), maxf(1.0, 4.0 * scale), true)


func _draw_fallback_tank(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	var scale := TANK_VISUAL_SCALE
	var body := Rect2(center + Vector2(-34.0, -12.0) * scale, Vector2(68.0, 36.0) * scale)
	var turret := Rect2(center + Vector2(-20.0, -30.0) * scale, Vector2(40.0, 28.0) * scale)
	canvas.draw_rect(body.grow(3.0 * scale), Color(0.02, 0.03, 0.04, 0.46 * alpha), true)
	canvas.draw_rect(body, Color(0.16, 0.20, 0.24, 0.94 * alpha), true)
	canvas.draw_rect(body.grow(-4.0 * scale), Color(0.31, 0.40, 0.47, 0.80 * alpha), false, maxf(1.0, 2.0 * scale))
	canvas.draw_rect(turret, Color(0.12, 0.17, 0.22, 0.96 * alpha), true)
	canvas.draw_rect(turret.grow(-4.0 * scale), Color(0.42, 0.92, 1.0, 0.34 * alpha), false, maxf(1.0, 1.8 * scale))
	for side in [-1, 1]:
		var tread_center := center + Vector2(float(side) * 26.0, 20.0) * scale
		canvas.draw_rect(Rect2(tread_center + Vector2(-15.0, -7.0) * scale, Vector2(30.0, 14.0) * scale), Color(0.04, 0.05, 0.06, 0.96 * alpha), true)
		for i in range(3):
			canvas.draw_circle(tread_center + Vector2(float(i - 1) * 8.0, 0.0) * scale, 3.0 * scale, Color(0.48, 0.55, 0.60, 0.72 * alpha))


func _draw_mount_bar(canvas: CanvasItem, center: Vector2, progress: float, scale: float) -> void:
	var bg := Rect2(center + Vector2(-36.0, -4.0) * scale, Vector2(72.0, 8.0) * scale)
	var fill := Rect2(bg.position + Vector2(1.5, 1.5) * scale, Vector2((bg.size.x - 3.0 * scale) * clampf(progress, 0.0, 1.0), bg.size.y - 3.0 * scale))
	canvas.draw_rect(bg.grow(2.0 * scale), Color(0.02, 0.04, 0.06, 0.70), true)
	canvas.draw_rect(bg, Color(0.60, 0.92, 1.0, 0.82), false, maxf(1.0, 1.4 * scale))
	canvas.draw_rect(fill, Color(0.44, 0.98, 1.0, 0.88), true)


func _draw_bullets(canvas: CanvasItem, bullets: Array[Dictionary], shake_offset: Vector2) -> void:
	for bullet in bullets:
		var pos: Vector2 = _as_vector2(bullet.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var vel: Vector2 = _as_vector2(bullet.get("vel", Vector2.ZERO), Vector2.ZERO)
		var direction := vel.normalized() if vel.length_squared() > 0.001 else Vector2(cos(float(bullet.get("angle", 0.0))), sin(float(bullet.get("angle", 0.0))))
		var tracer := bool(bullet.get("tracer", false))
		for i in range(TRAIL_STEPS):
			var trail_ratio := 1.0 - float(i) / float(TRAIL_STEPS)
			var trail_pos := pos - direction * BULLET_SPEED * TRAIL_STEP_SECONDS * float(i + 1)
			var width := BULLET_WIDTH * (0.45 + trail_ratio * 0.55)
			var color := Color(1.0, 0.85, 0.28, 0.18 * trail_ratio)
			if tracer:
				color = Color(0.64, 0.96, 1.0, 0.28 * trail_ratio)
			canvas.draw_line(trail_pos, pos, color, width, true)
		var tip := pos + direction * BULLET_LENGTH
		var core_color := Color(1.0, 0.93, 0.52, 0.96)
		if tracer:
			core_color = Color(0.80, 1.0, 1.0, 1.0)
		canvas.draw_line(pos - direction * BULLET_LENGTH, tip, core_color, BULLET_WIDTH, true)


func _draw_hit_particles(canvas: CanvasItem, hit_particles: Array[Dictionary], shake_offset: Vector2) -> void:
	for particle in hit_particles:
		var age := float(particle.get("age", 0.0))
		var life := maxf(0.001, float(particle.get("life", 0.2)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size := float(particle.get("size", 2.0)) * (0.45 + ratio * 0.55)
		var color := Color(1.0, 0.74, 0.24, 0.82 * ratio) if bool(particle.get("ember", false)) else Color(0.82, 0.96, 1.0, 0.78 * ratio)
		canvas.draw_circle(pos, size, color)


func _draw_shell_casings(canvas: CanvasItem, shell_casings: Array[Dictionary], shake_offset: Vector2) -> void:
	for casing in shell_casings:
		var age := float(casing.get("age", 0.0))
		var life := maxf(0.001, float(casing.get("life", 0.5)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(casing.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var rotation := float(casing.get("rotation", 0.0))
		var direction := Vector2(cos(rotation), sin(rotation))
		canvas.draw_line(pos - direction * 2.2, pos + direction * 2.2, Color(0.96, 0.72, 0.30, 0.70 * ratio), 2.0, true)


func _draw_smoke(canvas: CanvasItem, smoke_puffs: Array[Dictionary], shake_offset: Vector2) -> void:
	for smoke in smoke_puffs:
		var age := float(smoke.get("age", 0.0))
		var life := maxf(0.001, float(smoke.get("life", 0.25)))
		var ratio := clampf(1.0 - age / life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(smoke.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		canvas.draw_circle(pos, float(smoke.get("size", 5.0)), Color(0.55, 0.64, 0.70, 0.16 * ratio))


func _get_cannon_alpha(mounting: bool, dismounting: bool, mount_progress: float, dismount_progress: float) -> float:
	if mounting:
		return clampf((mount_progress - CANNON_MOUNT_PROGRESS_START) / maxf(0.001, 1.0 - CANNON_MOUNT_PROGRESS_START), 0.0, 1.0)
	if dismounting:
		return clampf(1.0 - dismount_progress, 0.0, 1.0)
	return 1.0


func _get_transform_texture() -> Texture2D:
	if _transform_texture == null:
		prewarm()
	return _transform_texture


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
