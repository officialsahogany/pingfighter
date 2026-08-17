extends RefCounted

const GYEONGSINHWAN_PARTICLE_COLORS := [
	Color(0.16, 0.72, 0.64, 1.0),
	Color(0.42, 1.0, 0.86, 1.0),
	Color(0.86, 1.0, 0.92, 1.0),
	Color(1.0, 0.84, 0.32, 1.0),
]


static func build_idle_particle(player_center: Vector2) -> Dictionary:
	# 최초 dash_boost 오귀속 당시 사용자가 선호한 경신단 깃털 생성 계약.
	return {
		"position": Vector2(player_center.x + randf_range(-105.0, 105.0), player_center.y + randf_range(-26.0, 12.0)),
		"velocity": Vector2(randf_range(-2.2, 2.2), randf_range(-0.8, -0.2)) * 60.0,
		"radius": float(randi_range(2, 4)),
		"length": randf_range(9.0, 20.0),
		"alpha": 200.0 / 255.0,
		"shrink_per_frame": 0.05,
		"color": GYEONGSINHWAN_PARTICLE_COLORS[randi() % GYEONGSINHWAN_PARTICLE_COLORS.size()],
	}
