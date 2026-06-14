extends RefCounted

const ActiveItemLifeElixirParticlePayloadFactory := preload("res://scripts/items/active_item_life_elixir_particle_payload_factory.gd")

const LIFE_ELIXIR_PARTICLE_COUNT := 22


func spawn_particles(particles: Array[Dictionary], center: Vector2) -> void:
	for i in range(LIFE_ELIXIR_PARTICLE_COUNT):
		particles.append(ActiveItemLifeElixirParticlePayloadFactory.build_particle(center, i, LIFE_ELIXIR_PARTICLE_COUNT))
