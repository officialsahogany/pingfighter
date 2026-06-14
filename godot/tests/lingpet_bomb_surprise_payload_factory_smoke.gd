extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetBombSurprisePayloadFactory := preload("res://scripts/lingpet/lingpet_bomb_surprise_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_status_payloads()
	_verify_base_particle_payload()
	_verify_explosion_particle_payloads()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_bomb_surprise_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_status_payloads() -> void:
	var boss_data: Dictionary = LingpetBombSurprisePayloadFactory.build_boss_stun_status_data("volty_bomb_surprise", -52.0, 18.0, 0.85)
	_expect(bool(boss_data.get("cleansable", false)), "boss stun data should stay cleansable")
	_expect(str(boss_data.get("visual", "")) == "volty_bomb_surprise", "boss stun data should keep the Bomb Surprise visual key")
	_expect(is_equal_approx(float(boss_data.get("knockback_vel", 0.0)), -52.0), "boss stun data should preserve knockback velocity")
	_expect(bool(boss_data.get("knockback_active", false)), "boss stun data should mark knockback active")
	_expect(is_equal_approx(float(boss_data.get("knockback_frames", 0.0)), 18.0), "boss stun data should preserve knockback frames")
	_expect(is_equal_approx(float(boss_data.get("knockback_decay_per_frame", 0.0)), 0.85), "boss stun data should preserve knockback decay")

	var player_data: Dictionary = LingpetBombSurprisePayloadFactory.build_player_stun_status_data("volty_bomb_surprise", true)
	_expect(bool(player_data.get("cleansable", false)), "player stun data should stay cleansable")
	_expect(str(player_data.get("visual", "")) == "volty_bomb_surprise", "player stun data should keep the Bomb Surprise visual key")
	_expect(bool(player_data.get("weak_stun", false)), "player stun data should preserve the weak self-stun marker")


func _verify_base_particle_payload() -> void:
	var particle: Dictionary = LingpetBombSurprisePayloadFactory.build_particle(Vector2(10.0, 20.0), Vector2(-4.0, 7.0), -0.5, 0.1, 1)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(10.0, 20.0), "base particle should preserve position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(-4.0, 7.0), "base particle should preserve velocity")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 0.01), "base particle should clamp life")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), 0.01), "base particle should clamp max life")
	_expect(is_equal_approx(float(particle.get("size", 0.0)), 0.5), "base particle should clamp size")
	_expect(int(particle.get("kind", -1)) == 1, "base particle should preserve kind")


func _verify_explosion_particle_payloads() -> void:
	var origin := Vector2(320.0, 360.0)
	var strong_particle: Dictionary = LingpetBombSurprisePayloadFactory.build_explosion_particle(origin, false)
	_expect(_is_particle_inside_ranges(strong_particle, origin, 0.24, 0.62, 3.0, 11.0), "strong explosion particle should keep the original range")
	var weak_particle: Dictionary = LingpetBombSurprisePayloadFactory.build_explosion_particle(origin, true)
	_expect(_is_particle_inside_ranges(weak_particle, origin, 0.16, 0.40, 2.0, 7.0), "weak self-explosion particle should keep the original range")


func _is_particle_inside_ranges(particle: Dictionary, origin: Vector2, life_min: float, life_max: float, size_min: float, size_max: float) -> bool:
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	if pos.x < origin.x - 8.0 or pos.x > origin.x + 8.0:
		return false
	if pos.y < origin.y - 8.0 or pos.y > origin.y + 8.0:
		return false
	if not (particle.get("vel", Vector2.ZERO) is Vector2):
		return false
	var life := float(particle.get("life", 0.0))
	if life < life_min or life > life_max:
		return false
	if not is_equal_approx(float(particle.get("max_life", 0.0)), life):
		return false
	var size := float(particle.get("size", 0.0))
	if size < size_min or size > size_max:
		return false
	var kind := int(particle.get("kind", -1))
	return kind == 0 or kind == 1


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bomb_surprise_skill.gd")
	_expect(source.find("LingpetBombSurprisePayloadFactory.build_boss_stun_status_data") >= 0, "Bomb Surprise should delegate boss stun status data")
	_expect(source.find("LingpetBombSurprisePayloadFactory.build_player_stun_status_data") >= 0, "Bomb Surprise should delegate player stun status data")
	_expect(source.find("LingpetBombSurprisePayloadFactory.build_explosion_particle") >= 0, "Bomb Surprise should delegate explosion particle payloads")
	_expect(source.find("_particles.append({") < 0, "Bomb Surprise should not inline particle dictionaries")
	_expect(source.find("\"weak_stun\": self_explosion") < 0, "Bomb Surprise should not inline player stun status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_bomb_surprise_payload_factory"), "lingpet module catalog should list the Bomb Surprise payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_bomb_surprise_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_bomb_surprise_payload_factory.gd", "top-level module catalog should resolve the Bomb Surprise payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
