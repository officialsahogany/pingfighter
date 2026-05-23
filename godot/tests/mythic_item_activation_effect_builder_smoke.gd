extends SceneTree

const MythicItemActivationEffectRuntime := preload("res://scripts/items/mythic_item_activation_effect_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


func _init() -> void:
	var runtime: Object = MythicItemRuntime.new()
	while not runtime.prewarm_initialization_step(false):
		pass
	runtime.activation_effect_runtime.build_particles(runtime)
	runtime.activation_effect_runtime.build_bolts(runtime)

	_expect(runtime.activation_particles.size() == MythicItemActivationEffectRuntime.PARTICLE_COUNT, "Megingjord activation should build the expected particle count")
	_expect(runtime.activation_bolts.size() == MythicItemActivationEffectRuntime.BOLT_COUNT, "Megingjord activation should build the expected bolt count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	_expect(runtime_source.find("_build_activation_particles") < 0, "mythic runtime should not keep activation particle bridge methods inline")
	_expect(runtime_source.find("MEGINGJORD_PARTICLE_COUNT") < 0, "mythic runtime should not keep activation particle constants inline")

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
