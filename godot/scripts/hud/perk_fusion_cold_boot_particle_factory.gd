extends RefCounted

# 콜드부트 스파크 파티클 팩토리(CB4c-2) — mythic acquisition presentation
# factory의 GPUParticles2D 패턴 포크(§5 계약: mythic shard 패턴 재사용).
# 전 노드는 emitting=false·additive 블렌드·one_shot으로 생성되고, 발화는
# 호스트의 전이 이벤트 소비(+presentation 카운트 게이트)가 소유한다.
# 픽셀 QA 결정론: use_fixed_seed — 방출 방향/수명 롤이 캡처마다 같다.

const VENT_SEED := 41207
const SHOWER_SEED := 90311

# 앵커 오프셋(뷰포트 중심 기준) 단일 소스 — 호스트의 sync별 재정렬이
# 같은 상수를 읽는다(리사이즈 시 스파크-섀시 분리 방지 계약).
const VENT_LEFT_OFFSET := Vector2(-96.0, 44.0)
const VENT_RIGHT_OFFSET := Vector2(96.0, 44.0)
const SHOWER_OFFSET := Vector2(0.0, -150.0)


static func build(parent: Node2D, spark_texture: Texture2D, center: Vector2) -> Dictionary:
	if parent == null or spark_texture == null:
		return {}
	var vent_left := _build_vent_fan(spark_texture, center + VENT_LEFT_OFFSET, Vector3(-0.82, 0.57, 0.0))
	var vent_right := _build_vent_fan(spark_texture, center + VENT_RIGHT_OFFSET, Vector3(0.82, 0.57, 0.0))
	var gold_shower := _build_gold_shower(spark_texture, center + SHOWER_OFFSET)
	parent.add_child(vent_left)
	parent.add_child(vent_right)
	parent.add_child(gold_shower)
	return {
		"vent_left": vent_left,
		"vent_right": vent_right,
		"gold_shower": gold_shower,
	}


# 부작용 벤트/EJECT: 측면 보조 해치에서 바깥-아래로 뿜는 방향성 스파크 팬
# (B3 진입 + 페널티 물량>0에서 1회). 초반 백열→앰버→적 감쇠 램프.
static func _build_vent_fan(texture: Texture2D, fan_position: Vector2, direction: Vector3) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 64
	particles.lifetime = 0.85
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35
	particles.use_fixed_seed = true
	particles.seed = VENT_SEED
	particles.texture = texture
	particles.position = fan_position
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process_material.direction = direction
	process_material.spread = 24.0
	process_material.gravity = Vector3(0.0, 320.0, 0.0)
	process_material.initial_velocity_min = 240.0
	process_material.initial_velocity_max = 460.0
	process_material.damping_min = 40.0
	process_material.damping_max = 110.0
	process_material.scale_min = 0.030
	process_material.scale_max = 0.062
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -300.0
	process_material.angular_velocity_max = 300.0
	process_material.color_ramp = _build_gradient_texture([
		[0.0, Color(1.0, 0.98, 0.90, 1.0)],
		[0.30, Color(1.0, 0.72, 0.34, 1.0)],
		[0.70, Color(1.0, 0.45, 0.35, 0.75)],
		[1.0, Color(0.60, 0.20, 0.18, 0.0)],
	])
	_apply_particle_materials(particles, process_material)
	return particles


# 부산물 각성: 섀시 상부 밴드에서 낙하하는 골드 스파크 샤워(B4 진입 +
# 전개 모듈>0에서 1회, 낮은 explosiveness로 스태거 낙하).
static func _build_gold_shower(texture: Texture2D, shower_position: Vector2) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 120
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.randomness = 0.4
	particles.use_fixed_seed = true
	particles.seed = SHOWER_SEED
	particles.texture = texture
	particles.position = shower_position
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(140.0, 6.0, 1.0)
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 10.0
	process_material.gravity = Vector3(0.0, 460.0, 0.0)
	process_material.initial_velocity_min = 60.0
	process_material.initial_velocity_max = 160.0
	process_material.scale_min = 0.026
	process_material.scale_max = 0.052
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -160.0
	process_material.angular_velocity_max = 160.0
	process_material.color_ramp = _build_gradient_texture([
		[0.0, Color(1.0, 0.95, 0.60, 0.0)],
		[0.15, Color(1.0, 0.92, 0.55, 1.0)],
		[0.70, Color(1.0, 0.72, 0.25, 0.8)],
		[1.0, Color(0.80, 0.50, 0.20, 0.0)],
	])
	_apply_particle_materials(particles, process_material)
	return particles


static func _build_gradient_texture(points: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	for point_value: Variant in points:
		var point: Array = point_value if point_value is Array else []
		if point.size() >= 2:
			gradient.add_point(float(point[0]), point[1] as Color)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _apply_particle_materials(particles: GPUParticles2D, process_material: ParticleProcessMaterial) -> void:
	particles.process_material = process_material
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = canvas_material
	particles.emitting = false
