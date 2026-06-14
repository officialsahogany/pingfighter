extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetAffinityFeedbackPayloadFactory := preload("res://scripts/lingpet/lingpet_affinity_feedback_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	_verify_point_popup_payload()
	_verify_draw_popup_payload()
	_verify_state_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_affinity_feedback_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_point_popup_payload() -> void:
	var popup: Dictionary = LingpetAffinityFeedbackPayloadFactory.build_point_popup(-3.0)
	_expect(is_equal_approx(float(popup.get("amount", -1.0)), 0.0), "point popup should clamp negative amount")
	_expect(is_equal_approx(float(popup.get("age", -1.0)), 0.0), "point popup should start with zero age")


func _verify_draw_popup_payload() -> void:
	var draw_popup: Dictionary = LingpetAffinityFeedbackPayloadFactory.build_draw_popup({"amount": 4.0, "age": 0.45}, 0.9)
	_expect(is_equal_approx(float(draw_popup.get("amount", 0.0)), 4.0), "draw popup should preserve amount")
	_expect(is_equal_approx(float(draw_popup.get("ratio", 0.0)), 0.5), "draw popup should convert age to ratio")
	var clamped: Dictionary = LingpetAffinityFeedbackPayloadFactory.build_draw_popup({"amount": 4.0, "age": 9.0}, 0.9)
	_expect(is_equal_approx(float(clamped.get("ratio", 0.0)), 1.0), "draw popup ratio should clamp high")


func _verify_state_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_feedback_state.gd")
	_expect(source.find("LingpetAffinityFeedbackPayloadFactory.build_point_popup") >= 0, "affinity feedback should delegate stored popup payloads")
	_expect(source.find("LingpetAffinityFeedbackPayloadFactory.build_draw_popup") >= 0, "affinity feedback should delegate draw popup payloads")
	_expect(source.find("point_popups.append({") < 0, "affinity feedback should not inline point popup dictionaries")
	_expect(source.find("popups.append({") < 0, "affinity feedback should not inline draw popup dictionaries")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_affinity_feedback_payload_factory"), "lingpet module catalog should list the affinity feedback payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_affinity_feedback_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_affinity_feedback_payload_factory.gd", "top-level module catalog should resolve the affinity feedback payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
