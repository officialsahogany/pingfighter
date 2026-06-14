extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetPuppetGrabPayloadFactory := preload("res://scripts/lingpet/lingpet_puppet_grab_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_heart_payload()
	_verify_sparkle_payload()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_puppet_grab_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_heart_payload() -> void:
	var center := Vector2(380.0, 620.0)
	var heart: Dictionary = LingpetPuppetGrabPayloadFactory.build_heart(center, 0.9)
	var pos: Vector2 = heart.get("pos", Vector2.ZERO)
	_expect(pos.x >= center.x - 22.0 and pos.x <= center.x + 22.0, "heart should keep the original x spread")
	_expect(pos.y >= center.y - 6.0 and pos.y <= center.y + 14.0, "heart should keep the original y spread")
	_expect(float(heart.get("drift", 0.0)) >= -18.0 and float(heart.get("drift", 0.0)) <= 18.0, "heart should keep drift range")
	_expect(is_equal_approx(float(heart.get("life", 0.0)), 0.9), "heart should preserve life")
	_expect(float(heart.get("size", 0.0)) >= 5.0 and float(heart.get("size", 0.0)) <= 9.0, "heart should keep size range")


func _verify_sparkle_payload() -> void:
	var center := Vector2(380.0, 620.0)
	var sparkle: Dictionary = LingpetPuppetGrabPayloadFactory.build_sparkle(center, 0.5)
	var pos: Vector2 = sparkle.get("pos", Vector2.ZERO)
	_expect(pos.x >= center.x - 30.0 and pos.x <= center.x + 30.0, "sparkle should keep the original x spread")
	_expect(pos.y >= center.y - 20.0 and pos.y <= center.y + 20.0, "sparkle should keep the original y spread")
	_expect(is_equal_approx(float(sparkle.get("life", 0.0)), 0.5), "sparkle should preserve life")
	_expect(float(sparkle.get("size", 0.0)) >= 2.0 and float(sparkle.get("size", 0.0)) <= 5.0, "sparkle should keep size range")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")
	_expect(source.find("LingpetPuppetGrabPayloadFactory.build_heart") >= 0, "Puppet Grab should delegate heart payloads")
	_expect(source.find("LingpetPuppetGrabPayloadFactory.build_sparkle") >= 0, "Puppet Grab should delegate sparkle payloads")
	_expect(source.find("_hearts.append({") < 0, "Puppet Grab should not inline heart dictionaries")
	_expect(source.find("_sparkles.append({") < 0, "Puppet Grab should not inline sparkle dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_puppet_grab_payload_factory"), "lingpet module catalog should list the Puppet Grab payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_puppet_grab_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_puppet_grab_payload_factory.gd", "top-level module catalog should resolve the Puppet Grab payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
