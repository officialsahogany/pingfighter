extends SceneTree

const GuardianEnhanceHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)

const PANEL_SOURCE_SIZE := Vector2(1485.0, 1059.0)
const MEASURED_ENSO_CENTER_PX := Vector2(743.0, 499.0)
const MEASURED_ENSO_RADIUS_PX := 254.0
const FULL_PANEL_HEIGHT := 442.0

var _failures: Array[String] = []


func _init() -> void:
	_verify_measured_enso_anchor()
	_verify_authored_draw_size_spread()
	_verify_panel_relative_upper_cap_without_lower_clamp()

	if _failures.is_empty():
		print("guardian_enhance_cutin_layout_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_measured_enso_anchor() -> void:
	_expect_vector2(
		GuardianEnhanceHost.ENSO_CENTER_NORMALIZED,
		MEASURED_ENSO_CENTER_PX / PANEL_SOURCE_SIZE,
		"Enso center must stay on the independently measured PNG anchor"
	)
	_expect_close(
		GuardianEnhanceHost.ENSO_STROKE_RADIUS_HEIGHT_RATIO,
		MEASURED_ENSO_RADIUS_PX / PANEL_SOURCE_SIZE.y,
		"Enso stroke radius must stay on the independently measured PNG radius"
	)


func _verify_authored_draw_size_spread() -> void:
	var host := GuardianEnhanceHost.new()
	_expect_contract_height(host, "rabi", 64.0 * 1.18)
	_expect_contract_height(host, "red_dragon", 64.0 * 1.18)
	_expect_contract_height(host, "nekuring", 73.6 * 1.18)
	# Maribo has no click-specific override. The canonical resolver must reach the
	# authored 104 px walk size instead of the old host-local 96 px fallback.
	_expect_contract_height(host, "maribo", 104.0 * 1.18)


func _verify_panel_relative_upper_cap_without_lower_clamp() -> void:
	var rabi_height := 64.0 * 1.18
	_expect_close(
		GuardianEnhanceHost.resolve_panel_companion_draw_height(
			rabi_height,
			FULL_PANEL_HEIGHT
		),
		rabi_height,
		"small authored reactions must not be raised to the retired 90 px floor"
	)
	_expect_close(
		GuardianEnhanceHost.resolve_panel_companion_draw_height(
			200.0,
			FULL_PANEL_HEIGHT
		),
		FULL_PANEL_HEIGHT * 0.30,
		"oversized reactions must use only the panel-relative upper cap"
	)


func _expect_contract_height(host: Object, pet_id: String, expected: float) -> void:
	var contract: Dictionary = host.get_animation_contract(pet_id)
	_expect_close(
		float(contract.get("draw_size", -1.0)),
		expected,
		"%s must preserve its canonical click-reaction size" % pet_id
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if not is_equal_approx(actual, expected) and absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.4f, got %.4f)" % [message, expected, actual])


func _expect_vector2(
	actual: Vector2,
	expected: Vector2,
	message: String,
	tolerance: float = 0.0001
) -> void:
	if actual.distance_to(expected) > tolerance:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
