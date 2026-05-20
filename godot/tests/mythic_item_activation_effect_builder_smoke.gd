extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime: Object = MythicItemRuntime.new()
	runtime._build_activation_particles()
	runtime._build_activation_bolts()

	_expect(runtime.activation_particles.size() == 58, "Megingjord activation should build the expected particle count")
	_expect(runtime.activation_bolts.size() == 24, "Megingjord activation should build the expected bolt count")

	var particle: Dictionary = runtime.activation_particles[0]
	_expect(particle.get("velocity", null) is Vector2, "activation particle should keep velocity")
	_expect(particle.get("color", null) is Color, "activation particle should keep color")
	_expect(float(particle.get("life", 0.0)) > 0.0, "activation particle should keep positive life")

	var bolt: Dictionary = runtime.activation_bolts[0]
	_expect(float(bolt.get("life", 0.0)) > 0.0, "activation bolt should keep positive life")
	_expect(bolt.get("points", null) is PackedVector2Array, "activation bolt should keep point data")
	_expect((bolt.get("points", PackedVector2Array()) as PackedVector2Array).size() >= 2, "activation bolt should have a drawable polyline")

	print("mythic_item_activation_effect_builder_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
