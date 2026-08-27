extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")
const ActiveItemTimerGaugeRenderer := preload("res://scripts/items/active_item_timer_gauge_renderer.gd")
const ActiveItemGyeongsinhwanParticles := preload("res://scripts/items/active_item_gyeongsinhwan_particles.gd")
const ActiveItemGyeongsinhwanParticlePayloadFactory := preload("res://scripts/items/active_item_gyeongsinhwan_particle_payload_factory.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0
	var special_gauge := 100.0
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(3.0, -4.0)


func _init() -> void:
	_verify_icon_contract()
	_verify_feather_vfx_contract()
	_verify_live_vitamin_particle_route()
	if _failures.is_empty():
		print("active_item_gyeongsinhwan_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_icon_contract() -> void:
	_expect(
		ActiveItemCatalog.VITAMIN_PILL_ICON_PATH == "res://assets/sprites/items/vitamin_pill_icon_hq_v1.png",
		"Gyeongsinhwan should use its dedicated generated icon through the vitamin item"
	)
	_expect(
		ActiveItemTimerGaugeRenderer.VITAMIN_PILL_ICON_PATH == ActiveItemCatalog.VITAMIN_PILL_ICON_PATH,
		"Gyeongsinhwan timer gauge should share the catalog icon source"
	)
	_expect(
		ActiveItemCatalog.DASH_BOOST_ICON_PATH == "res://assets/sprites/items/dash_boost_icon_hq_v1.png",
		"Chukjibu should use its generated talisman icon"
	)
	var icon: Texture2D = load(ActiveItemCatalog.VITAMIN_PILL_ICON_PATH) as Texture2D
	_expect(icon != null, "Gyeongsinhwan icon should load")
	if icon != null:
		_expect(icon.get_size() == Vector2(256.0, 256.0), "Gyeongsinhwan HUD icon should use the 256px HQ contract")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd")
	_expect(
		overlay_source.find("\"vitamin_pill\": \"res://assets/sprites/items/vitamin_pill_icon_hq_v1.png\"") >= 0,
		"Gyeongsinhwan TAB breakdown should use the generated icon through the vitamin item"
	)
	_expect(
		overlay_source.find("\"dash_boost\": \"res://assets/sprites/items/dash_boost_icon_hq_v1.png\"") >= 0,
		"Chukjibu TAB breakdown should share its generated icon"
	)


func _verify_feather_vfx_contract() -> void:
	var renderer: Object = ActiveItemEffectRenderer.new()
	renderer.prewarm_assets()
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	var effect_body := _function_body(source, "func _draw_vitamin_pill_effect(")
	var feather_body := _function_body(source, "func _draw_gyeongsinhwan_feather_particle(")
	var dash_effect_body := _function_body(source, "func _draw_dash_boost_effect(")
	_expect(effect_body.find("_draw_gyeongsinhwan_feather_particle") >= 0, "Gyeongsinhwan should draw its runtime wind-feather particles through the vitamin item")
	_expect(effect_body.find("get_gyeongsinhwan_wind_seal_texture") < 0, "Gyeongsinhwan should not restore the circular cloud seal")
	_expect(effect_body.find("ImpactFlareTextureCache.draw_glow") < 0, "Gyeongsinhwan should not restore the persistent center glow")
	_expect(effect_body.find("_draw_rotated_texture") < 0, "Gyeongsinhwan should not rotate a center texture layer")
	_expect(effect_body.find("canvas.draw_arc") < 0, "Gyeongsinhwan should not restore the three-cycle arc fallback")
	_expect(feather_body.find("canvas.draw_line") >= 0, "Gyeongsinhwan feathers should render as wind streaks")
	_expect(dash_effect_body.find("_draw_gyeongsinhwan_feather") < 0, "Chukjibu should not retain Gyeongsindan's feather identity")
	_expect(dash_effect_body.find("_chukjibu_renderer.draw") >= 0, "Chukjibu should delegate its field VFX to the focused renderer")
	_expect(source.find("GYEONGSINHWAN_WIND_SEAL_PATH") < 0, "Gyeongsinhwan renderer should not retain the removed seal asset contract")
	_expect(source.find("func _draw_gyeongsinhwan_wind_fallback") < 0, "Gyeongsinhwan renderer should not retain a circular fallback")
	_verify_original_feather_emission_contract()
	_verify_vitamin_runtime_particle_wiring()


func _verify_original_feather_emission_contract() -> void:
	seed(20260721)
	var center := Vector2(380.0, 700.0)
	for _index in range(48):
		var particle: Dictionary = ActiveItemGyeongsinhwanParticlePayloadFactory.build_idle_particle(center)
		var position: Vector2 = particle.get("position", Vector2.ZERO)
		var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
		_expect(position.x >= center.x - 105.0 and position.x <= center.x + 105.0, "Gyeongsinhwan feather should spawn in the original close horizontal envelope")
		_expect(position.y >= center.y - 26.0 and position.y <= center.y + 12.0, "Gyeongsinhwan feather should spawn around the player's body")
		_expect(velocity.x >= -132.0 and velocity.x <= 132.0, "Gyeongsinhwan feather should keep the original lateral drift range")
		_expect(velocity.y >= -48.0 and velocity.y <= -12.0, "Gyeongsinhwan feather should keep the original upward drift range")
		_expect(float(particle.get("length", 0.0)) >= 9.0 and float(particle.get("length", 0.0)) <= 20.0, "Gyeongsinhwan feather should keep the original length range")
	var particles: Array[Dictionary] = []
	var helper: Object = ActiveItemGyeongsinhwanParticles.new()
	var accumulator: float = helper.advance_idle_particles(particles, 0.0, center, 3.0, 0.0)
	_expect(is_equal_approx(accumulator, 0.0), "Gyeongsinhwan should emit on the original three-frame cadence")
	_expect(particles.size() == 2, "Gyeongsinhwan should emit the original two feathers per cadence")


func _verify_vitamin_runtime_particle_wiring() -> void:
	var controller_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_controller.gd")
	var update_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_update_driver.gd")
	var query_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_query.gd")
	var reset_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_reset.gd")
	_expect(controller_source.find("vitamin_pill_particles") >= 0, "Gyeongsinhwan particles should be owned by the vitamin runtime")
	_expect(update_source.find("_gyeongsinhwan_particles.advance_idle_particles") >= 0, "Gyeongsinhwan particles should advance from the vitamin update path")
	_expect(query_source.find("vitamin_pill_context[\"particles\"]") >= 0, "Gyeongsinhwan particles should reach the vitamin render context")
	_expect(reset_source.find("_clear_array(target, \"vitamin_pill_particles\")") >= 0, "Gyeongsinhwan particles should clear at runtime reset")


func _verify_live_vitamin_particle_route() -> void:
	seed(20260721)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	_expect(controller.activate_vitamin_pill(owner, null), "Gyeongsinhwan should activate through the vitamin runtime")
	for _frame in range(3):
		controller.update(owner, 1.0 / 60.0)
	_expect(controller.get_vitamin_pill_particles().size() == 2, "Gyeongsinhwan should emit two live feathers after three frames")
	var draw_context: Dictionary = controller.get_field_effect_draw_context()
	var vitamin_context: Dictionary = draw_context.get("vitamin_pill_timer_context", {})
	var context_particles: Variant = vitamin_context.get("particles", [])
	_expect(context_particles is Array and context_particles.size() == 2, "Gyeongsinhwan live feathers should reach the vitamin render context")
	controller.set("vitamin_pill_timer_frames", 1.0)
	controller.update(owner, 1.0 / 60.0)
	_expect(not bool(controller.get("vitamin_pill_active")), "Gyeongsinhwan gameplay state should end when its timer expires")
	var fading_particles: Array[Dictionary] = controller.get_vitamin_pill_particles()
	_expect(fading_particles.size() == 2, "Gyeongsinhwan feathers should remain after gameplay state expiry instead of popping away")
	var fading_alpha: float = float(fading_particles[0].get("alpha", 0.0)) if not fading_particles.is_empty() else 0.0
	draw_context = controller.get_field_effect_draw_context()
	vitamin_context = draw_context.get("vitamin_pill_timer_context", {})
	context_particles = vitamin_context.get("particles", [])
	_expect(not vitamin_context.is_empty(), "Gyeongsinhwan fade-out should keep a draw context after gameplay state expiry")
	_expect(not bool(vitamin_context.get("active", true)), "Gyeongsinhwan timer gauge should stay inactive during feather fade-out")
	_expect(context_particles is Array and context_particles.size() == 2, "Gyeongsinhwan fading feathers should remain renderable")
	controller.update(owner, 1.0 / 60.0)
	var faded_particles: Array[Dictionary] = controller.get_vitamin_pill_particles()
	_expect(not faded_particles.is_empty() and float(faded_particles[0].get("alpha", 1.0)) < fading_alpha, "Gyeongsinhwan feathers should fade progressively after expiry")
	for _frame in range(40):
		controller.update(owner, 1.0 / 60.0)
	_expect(controller.get_vitamin_pill_particles().is_empty(), "Gyeongsinhwan feathers should remove themselves after their natural fade-out")
	controller.reset()
	_expect(controller.get_vitamin_pill_particles().is_empty(), "Gyeongsinhwan live feathers should clear on reset")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + signature.length())
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
