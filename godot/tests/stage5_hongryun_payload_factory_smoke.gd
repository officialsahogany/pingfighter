extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage5HongryunPayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var projectile: Dictionary = Stage5HongryunPayloadFactory.build_fireball_projectile(
		Vector2(420.0, 180.0),
		Vector2(3.0, 14.0),
		12.8
	)
	_expect(projectile.get("pos", Vector2.ZERO) == Vector2(420.0, 180.0), "fireball projectile should preserve position")
	_expect(projectile.get("vel", Vector2.ZERO) == Vector2(3.0, 14.0), "fireball projectile should preserve velocity")
	_expect(is_equal_approx(float(projectile.get("radius", 0.0)), 12.8), "fireball projectile should preserve radius")
	_expect(is_equal_approx(float(projectile.get("age", -1.0)), 0.0), "fireball projectile should start with zero age")

	var impact: Dictionary = Stage5HongryunPayloadFactory.build_fireball_impact_event(
		Vector2(220.0, 700.0),
		"floor",
		0.85
	)
	_expect(impact.get("pos", Vector2.ZERO) == Vector2(220.0, 700.0), "fireball impact should preserve position")
	_expect(str(impact.get("reason", "")) == "floor", "fireball impact should preserve reason")
	_expect(is_equal_approx(float(impact.get("scale", 0.0)), 0.85), "fireball impact should preserve scale")

	var source := FileAccess.get_file_as_string("res://scripts/stages/stage5/stage5_hongryun_state.gd")
	_expect(source.find("Stage5HongryunPayloadFactory.build_fireball_projectile") >= 0, "Hongryun state should delegate fireball projectile payloads")
	_expect(source.find("Stage5HongryunPayloadFactory.build_fireball_impact_event") >= 0, "Hongryun state should delegate fireball impact payloads")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage5_hongryun_payload_factory"), "stage module catalog should list the Stage 5 Hongryun payload factory")

	if _failures.is_empty():
		print("stage5_hongryun_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
