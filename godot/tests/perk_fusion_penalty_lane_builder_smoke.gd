extends SceneTree

const PerkFusionPenaltyLaneBuilder := preload(
	"res://scripts/characters/perk_fusion_penalty_lane_builder.gd"
)
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")


class RuntimeStateStub:
	extends RefCounted

	var converted_levels := {
		"sensor": 5,
		"star_detector": 5,
		"shrapnel_armor": 5,
		"soul_burst": 5,
		"sage_ring": 3,
	}
	var central_bonuses := {
		"item_luck": 0.60,
		"kick_enhance": 99.0,
	}

	func get_converted_perk_effect_level(perk_id: String) -> int:
		return int(converted_levels.get(perk_id, 0))

	func get_runtime_skill_bonus(perk_id: String) -> float:
		return float(central_bonuses.get(perk_id, 0.0))


var _failures: Array[String] = []
var _builder := PerkFusionPenaltyLaneBuilder.new()
var _catalog := RuntimePerkCatalog.new()
var _runtime_state := RuntimeStateStub.new()


func _init() -> void:
	_test_converted_and_central_lanes()
	_test_classification_exclusions()
	_test_lane_contract()

	if _failures.is_empty():
		print("perk_fusion_penalty_lane_builder_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_converted_and_central_lanes() -> void:
	var lanes: Array[Dictionary] = _builder.build(
		["sensor", "star_detector", "item_luck"],
		_runtime_state,
		_catalog
	)
	var sensor_tokens: Dictionary = _find_lane(lanes, "sensor", "auto_dash_token_count")
	var sensor_cooldown: Dictionary = _find_lane(lanes, "sensor", "auto_dash_cooldown_sec")
	var star_bonus: Dictionary = _find_lane(lanes, "star_detector", "star_bonus_pct")
	var item_luck: Dictionary = _find_lane(lanes, "item_luck", "runtime_skill_bonus")

	_expect(not sensor_tokens.is_empty(), "sensor should expose its token-count lane")
	_expect(str(sensor_tokens.get("polarity", "")) == "forward", "sensor token count should be forward")
	_expect(str(sensor_tokens.get("value_kind", "")) == "int", "sensor token count should be quantized as int")
	_expect(int(sensor_tokens.get("value", 0)) == 2, "sensor Lv5 should snapshot two auto-dash tokens")
	_expect(int(sensor_tokens.get("remaining_option_count", 0)) == 2, "both sensor lanes should remain eligible")

	_expect(not sensor_cooldown.is_empty(), "sensor should expose its cooldown lane")
	_expect(str(sensor_cooldown.get("polarity", "")) == "reverse", "sensor cooldown should be reverse")
	_expect(str(sensor_cooldown.get("value_kind", "")) == "float", "sensor cooldown should remain a float lane")
	_expect_close(float(sensor_cooldown.get("value", 0.0)), 15.0, "sensor Lv5 cooldown snapshot")

	_expect(not star_bonus.is_empty(), "star detector should expose its converted value lane")
	_expect(str(star_bonus.get("polarity", "")) == "forward", "star bonus should be forward")
	_expect_close(float(star_bonus.get("value", 0.0)), 25.0, "star detector Lv5 snapshot")

	_expect(not item_luck.is_empty(), "common item_luck should use the central bonus lane")
	_expect(str(item_luck.get("polarity", "")) == "forward", "central bonus should be forward")
	_expect(str(item_luck.get("value_kind", "")) == "float", "central bonus should be a float lane")
	_expect_close(float(item_luck.get("value", 0.0)), 0.60, "item_luck should snapshot the central helper value")


func _test_classification_exclusions() -> void:
	var lanes: Array[Dictionary] = _builder.build(
		["kick_enhance", "sage_ring", "gravitybelt", "smartphone"],
		_runtime_state,
		_catalog
	)
	_expect(lanes.is_empty(), "character-local, exempt, and boolean sources must expose no penalty lanes")


func _test_lane_contract() -> void:
	var lanes: Array[Dictionary] = _builder.build(
		[
			"sensor",
			"star_detector",
			"item_luck",
			"shrapnel_armor",
			"soul_burst",
		],
		_runtime_state,
		_catalog
	)
	for lane: Dictionary in lanes:
		var polarity: String = str(lane.get("polarity", ""))
		var value_kind: String = str(lane.get("value_kind", ""))
		_expect(polarity == "forward" or polarity == "reverse", "every emitted lane needs known polarity")
		_expect(value_kind == "float" or value_kind == "int", "every emitted lane needs known value kind")
		_expect(not bool(lane.get("is_boolean", true)), "boolean lanes must be excluded before emission")
		_expect(float(lane.get("value", 0.0)) > 0.0, "every emitted lane needs a positive snapshot value")
		_expect(int(lane.get("remaining_option_count", 0)) >= 1, "every emitted lane needs a source option count")
	_expect(
		str(_find_lane(lanes, "shrapnel_armor", "gauge_cost").get("polarity", "")) == "reverse",
		"generic gauge_cost must use reverse polarity"
	)
	_expect(
		str(_find_lane(lanes, "shrapnel_armor", "shard_count").get("value_kind", "")) == "int",
		"shard_count must use integer quantization"
	)
	_expect(
		str(_find_lane(lanes, "shrapnel_armor", "knockback_level").get("value_kind", "")) == "int",
		"knockback_level must use integer quantization"
	)
	_expect(
		str(_find_lane(lanes, "soul_burst", "soul_burst_gauge_cost").get("polarity", "")) == "reverse",
		"soul burst gauge cost must use reverse polarity"
	)


func _find_lane(lanes: Array[Dictionary], perk_id: String, key: String) -> Dictionary:
	for lane: Dictionary in lanes:
		if str(lane.get("perk_id", "")) == perk_id and str(lane.get("key", "")) == key:
			return lane
	return {}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s, expected=%s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
