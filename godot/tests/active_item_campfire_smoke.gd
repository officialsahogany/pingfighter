extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemCampfireRuntime := preload("res://scripts/items/active_item_campfire_runtime.gd")
const ActiveItemCampfireRenderer := preload("res://scripts/items/active_item_campfire_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const DaljiVisionChosikState := preload("res://scripts/characters/dalji_vision_chosik_state.gd")
const CheongringwiVisionChosikState := preload("res://scripts/characters/cheongringwi_vision_chosik_state.gd")
const YeonmyoVisionChosikState := preload("res://scripts/characters/yeonmyo_vision_chosik_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BallMotionEventProcessor := preload("res://scripts/ball/ball_motion_event_processor.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")

const BALL_SIZE := 28.6
const FRAME_DELTA := 1.0 / 60.0
const EXPECTED_ICON_PATH := "res://assets/sprites/items/campfire_icon_hq_v1.png"
const EXPECTED_LOCALIZED_NAMES := {
	"ko": "모닥불",
	"en": "Campfire",
	"zh": "营火",
	"ja": "焚き火",
	"es": "Hoguera",
	"pt-BR": "Fogueira",
	"ru": "Костёр",
}

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 100.0
	var special_gauge_max := 500.0


class FakeCooldownState:
	extends RefCounted
	var advanced_msec := 0

	func advance_cooldowns_by_msec(bonus_msec: int, _time_now: int = -1) -> int:
		advanced_msec += bonus_msec
		return 1


class FakeDashState:
	extends RefCounted
	var active := false

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {"active": active}


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class ControllerBackedItemRuntime:
	extends RefCounted
	var controller: Object = null

	func _init(controller_value: Object) -> void:
		controller = controller_value

	func get_ball_collision_context() -> Dictionary:
		return controller.get_campfire_collision_context()

	func notify_campfire_hit(campfire_index: int, impact_pos: Vector2) -> Dictionary:
		return controller.notify_campfire_hit(campfire_index, impact_pos)


class FakeAudio:
	extends RefCounted
	var explosion_count := 0

	func play_molotov_explosion() -> void:
		explosion_count += 1


class FakeFeedback:
	extends RefCounted
	var shake_count := 0

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_count += 1


func _init() -> void:
	var original_language: String = LanguageSettings.get_language()
	_verify_catalog_and_visual_assets()
	_verify_router_and_placement()
	_verify_range_indicator_stays_hidden()
	_verify_dash_sweep_destroys_campfire()
	_verify_integer_vigor_and_dynamic_recovery()
	_verify_skill_cooldown_clock_acceleration()
	_verify_full_stepper_collision_priority()
	_verify_one_hit_reflection_and_destruction()
	_verify_rising_ball_is_ignored()
	_verify_reset_clears_state()
	LanguageSettings.set_language(original_language)

	if _failures.is_empty():
		print("active_item_campfire_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_visual_assets() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("campfire")
	_expect(not item_data.is_empty(), "catalog should build campfire item data")
	_expect(str(item_data.get("type", "")) == "active", "campfire should be an active item")
	_expect(str(item_data.get("effect", "")) == "campfire", "campfire effect id should match")
	_expect(str(item_data.get("display_name", "")) == "모닥불", "campfire should display as 모닥불 in Korean")
	var description: String = str(item_data.get("description", ""))
	for token in ["80px", "80%", "초당 30", "한 번", "반사", "대쉬"]:
		_expect(description.contains(str(token)), "campfire Korean description should disclose %s" % token)
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("campfire"), "campfire should be in FIELD_SPAWN_ORDER")
	_expect(ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("campfire"), "campfire should be in the F2 debug spawn menu")
	_expect(str(item_data.get("icon_path", "")) == EXPECTED_ICON_PATH, "campfire should use its generated icon")
	_expect(FileAccess.file_exists(EXPECTED_ICON_PATH), "campfire generated icon PNG should exist")

	var icon := load(EXPECTED_ICON_PATH) as Texture2D
	_expect(icon != null, "campfire generated icon should load")
	if icon != null:
		_expect(icon.get_size() == Vector2(256.0, 256.0), "campfire HUD icon should use the 256px HQ contract")
	var renderer: Object = ActiveItemCampfireRenderer.new()
	renderer.prewarm_assets()
	var deploy_texture: Texture2D = renderer.get_campfire_texture()
	_expect(deploy_texture != null, "campfire deploy texture should prewarm")
	if deploy_texture != null:
		_expect(deploy_texture.get_size() == Vector2(128.0, 128.0), "campfire deploy texture should be 128x128")
	var grounded_rect: Rect2 = ActiveItemCampfireRenderer.compute_campfire_draw_rect(
		Rect2(Vector2(300.0, ActiveItemCampfireRuntime.CAMPFIRE_BOTTOM_Y - ActiveItemCampfireRuntime.CAMPFIRE_SIZE.y), ActiveItemCampfireRuntime.CAMPFIRE_SIZE)
	)
	var visible_bottom: float = (
		grounded_rect.end.y
		- grounded_rect.size.y * ActiveItemCampfireRenderer.CAMPFIRE_TEXTURE_BOTTOM_INSET_RATIO
	)
	_expect(absf(visible_bottom - ActiveItemCampfireRuntime.FIELD_HEIGHT) < 0.01, "campfire's visible log pixels should touch the playfield floor")

	for locale in EXPECTED_LOCALIZED_NAMES.keys():
		LanguageSettings.set_language(str(locale))
		var localized_item: Dictionary = catalog.build_item_by_name("campfire")
		_expect(
			str(localized_item.get("display_name", "")) == str(EXPECTED_LOCALIZED_NAMES[locale]),
			"campfire should localize in %s" % locale
		)
		if str(locale) == "en":
			_expect(
				str(localized_item.get("description", "")).contains("dashing through"),
				"campfire English description should disclose dash destruction"
			)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_router_and_placement() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("campfire")
	var consumed: bool = ActiveItemEffectRouter.new().apply_item_effect(item_data, owner, null, controller, null)
	_expect(consumed, "router should dispatch campfire activation")
	_expect(controller.campfires.size() == 1, "router activation should place one campfire")
	var rect: Rect2 = controller.campfires[0].get("rect", Rect2())
	_expect(absf(rect.get_center().x - (owner.player_pos.x + owner.player_paddle_width * 0.5)) < 0.01, "campfire should be centered on the player")
	_expect(absf(rect.end.y - ActiveItemCampfireRuntime.FIELD_HEIGHT) < 0.01, "campfire bottom should sit exactly on the 750px playfield floor")
	_expect(rect.position.y < owner.player_pos.y - 5.0, "campfire collision top should stay above the player paddle hitbox")
	_expect(not controller.campfire_particles.is_empty(), "placement should emit install embers")
	_expect(controller.has_field_effects(), "placed campfire should keep field effect drawing active")
	_expect(not controller.get_field_effect_draw_context().get("campfire_context", {}).is_empty(), "field draw context should expose campfire state")


func _verify_range_indicator_stays_hidden() -> void:
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_campfire_renderer.gd")
	_expect(renderer_source.find("aura_radius") < 0, "campfire renderer should not consume the 80px radius for presentation")
	_expect(renderer_source.find("draw_arc(") < 0, "campfire renderer should not draw a circular range outline")
	_expect(renderer_source.find("ground halo around the campfire") >= 0, "campfire renderer should document the hidden range-indicator contract")


func _verify_dash_sweep_destroys_campfire() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(40.0, 700.0)
	var registry := FakeRegistry.new()
	var dash_state := FakeDashState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	registry.instances["smasher_dash_state"] = dash_state
	registry.instances["game_audio"] = audio
	registry.instances["battle_feedback_state"] = feedback
	controller.activate_campfire(owner, registry)
	feedback.shake_count = 0
	controller.campfires[0]["rect"] = Rect2(Vector2(354.0, 692.0), ActiveItemCampfireRuntime.CAMPFIRE_SIZE)

	owner.player_pos = Vector2(560.0, 700.0)
	controller.update_campfires(owner, registry, FRAME_DELTA)
	_expect(controller.campfires.size() == 1, "ordinary movement through a campfire should not destroy it")

	owner.player_pos = Vector2(40.0, 700.0)
	controller.update_campfires(owner, registry, FRAME_DELTA)
	dash_state.active = true
	owner.player_pos = Vector2(560.0, 700.0)
	var particles_before: int = controller.campfire_particles.size()
	controller.update_campfires(owner, registry, FRAME_DELTA)
	_expect(controller.campfires.is_empty(), "a dash sweep should destroy a campfire even when both endpoints miss it")
	_expect(controller.campfire_particles.size() > particles_before, "dash destruction should emit an ember burst")
	_expect(audio.explosion_count == 1, "dash destruction should play one fire burst cue")
	_expect(feedback.shake_count == 1, "dash destruction should trigger one screen response")
	_expect(not controller.campfire_player_in_range, "dash destruction should remove the recovery aura immediately")
	_expect(controller.get_dash_cooldown_multiplier() == 1.0, "dash destruction should remove the glide recovery bonus immediately")

	var campfire_rect := Rect2(Vector2(354.0, 692.0), ActiveItemCampfireRuntime.CAMPFIRE_SIZE)
	var left_player_rect := Rect2(Vector2(40.0, 700.0), Vector2(owner.player_paddle_width, owner.player_paddle_height))
	var right_player_rect := Rect2(Vector2(560.0, 700.0), Vector2(owner.player_paddle_width, owner.player_paddle_height))
	_expect(
		ActiveItemCampfireRuntime.dash_sweep_intersects_campfire(left_player_rect, right_player_rect, campfire_rect),
		"continuous dash geometry should detect a crossed campfire between non-overlapping endpoints"
	)

	var final_frame_controller: Object = ActiveItemEffectController.new()
	var final_frame_owner := FakeOwner.new()
	final_frame_owner.player_pos = Vector2(40.0, 700.0)
	var final_frame_registry := FakeRegistry.new()
	var final_frame_dash_state := FakeDashState.new()
	final_frame_dash_state.active = true
	final_frame_registry.instances["smasher_dash_state"] = final_frame_dash_state
	final_frame_controller.activate_campfire(final_frame_owner, final_frame_registry)
	final_frame_controller.campfires[0]["rect"] = campfire_rect
	final_frame_dash_state.active = false
	final_frame_owner.player_pos = Vector2(560.0, 700.0)
	final_frame_controller.update_campfires(final_frame_owner, final_frame_registry, FRAME_DELTA)
	_expect(
		final_frame_controller.campfires.is_empty(),
		"the final dash movement segment should destroy the campfire after dash state turns inactive"
	)


func _verify_integer_vigor_and_dynamic_recovery() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var cooldown_states: Dictionary = {}
	for state_key in ActiveItemCampfireRuntime.SKILL_COOLDOWN_STATE_KEYS:
		var cooldown_state := FakeCooldownState.new()
		cooldown_states[str(state_key)] = cooldown_state
		registry.instances[str(state_key)] = cooldown_state
	controller.activate_campfire(owner, null)

	var previous_gauge: float = owner.special_gauge
	for _frame in range(60):
		controller.update_campfires(owner, registry, FRAME_DELTA)
		var frame_gain: float = owner.special_gauge - previous_gauge
		_expect(frame_gain == 0.0 or frame_gain == 1.0, "vigor recovery should advance only in whole 1-point steps")
		_expect(owner.special_gauge == floor(owner.special_gauge), "vigor should remain integral")
		previous_gauge = owner.special_gauge
	_expect(owner.special_gauge == 130.0, "one second in the aura should restore exactly 30 vigor")
	for state_key in ActiveItemCampfireRuntime.SKILL_COOLDOWN_STATE_KEYS:
		_expect(
			int(cooldown_states[str(state_key)].advanced_msec) == 800,
			"one second in the aura should add exactly 800ms of Chosik cooldown progress to %s" % state_key
		)
	_expect(absf(controller.get_dash_cooldown_multiplier() - (1.0 / 1.8)) < 0.0001, "aura should make glide recovery 80% faster")
	var base_recharge_frames: float = SmasherDashState.compute_dash_recharge_frames(null, null)
	var aura_recharge_frames: float = SmasherDashState.compute_dash_recharge_frames(null, null, null, null, controller)
	_expect(
		absf(aura_recharge_frames - base_recharge_frames / 1.8) < 0.0001,
		"production SmasherDashState path should reduce glide recharge frames by the 1.8x recovery rate"
	)

	owner.player_pos = Vector2(20.0, 700.0)
	var gauge_before_outside: float = owner.special_gauge
	var cooldown_before_outside: int = int(cooldown_states["smasher_skill_state"].advanced_msec)
	controller.update_campfires(owner, registry, 1.0)
	_expect(owner.special_gauge == gauge_before_outside, "outside 80px should not restore vigor")
	_expect(int(cooldown_states["smasher_skill_state"].advanced_msec) == cooldown_before_outside, "outside 80px should not accelerate Chosik cooldowns")
	_expect(controller.get_dash_cooldown_multiplier() == 1.0, "outside 80px should not accelerate glide recovery")


func _verify_skill_cooldown_clock_acceleration() -> void:
	var state: Object = SmasherSkillState.new()
	state.trigger_cooldown("test_chosik", 1000, 10.0)
	_expect(absf(state.get_cooldown_remaining("test_chosik", 2000, 10.0) - 0.9) < 0.0001, "cooldown precondition should be 90% remaining")
	_expect(state.advance_cooldowns_by_msec(800, 2000) == 1, "campfire helper should advance a live Chosik cooldown")
	_expect(absf(state.get_cooldown_remaining("test_chosik", 2000, 10.0) - 0.82) < 0.0001, "80% bonus should turn 1 real second into 1.8 seconds of cooldown progress")

	var early_state: Object = SmasherSkillState.new()
	early_state.trigger_cooldown("early", 100, 10.0)
	early_state.advance_cooldowns_by_msec(200, 100)
	_expect(early_state.advance_cooldowns_by_msec(100, 100) == 1, "negative shifted timestamps must keep accepting aura progress")
	_expect(absf(early_state.get_cooldown_remaining("early", 100, 10.0) - 0.97) < 0.0001, "negative timestamp compatibility flag should preserve correct remaining ratio")

	state.pause_cooldowns(2000)
	_expect(state.advance_cooldowns_by_msec(800, 2200) == 0, "paused Chosik cooldowns should not recover through the aura")

	var dalji_vision := DaljiVisionChosikState.new()
	dalji_vision.cooldown_duration = 32.0
	dalji_vision.cooldown_remaining = 20.0
	_expect(dalji_vision.advance_cooldowns_by_msec(800, 2200) == 1, "Campfire should advance Dalji Vision cooldown")
	_expect(absf(dalji_vision.cooldown_remaining - 19.2) < 0.0001, "Dalji Vision should gain exactly 800ms of Campfire cooldown progress")

	var cheongringwi_vision := CheongringwiVisionChosikState.new()
	cheongringwi_vision.cooldown_duration = 40.0
	cheongringwi_vision.cooldown_remaining = 30.0
	_expect(cheongringwi_vision.advance_cooldowns_by_msec(800, 2200) == 1, "Campfire should advance Cheongringwi Vision cooldown")
	_expect(absf(cheongringwi_vision.cooldown_remaining - 29.2) < 0.0001, "Cheongringwi Vision should gain exactly 800ms of Campfire cooldown progress")

	var yeonmyo_vision := YeonmyoVisionChosikState.new()
	yeonmyo_vision.cooldown_duration = 35.0
	yeonmyo_vision.cooldown_remaining = 25.0
	_expect(yeonmyo_vision.advance_cooldowns_by_msec(800, 2200) == 1, "Campfire should advance Yeonmyo Vision cooldown")
	_expect(absf(yeonmyo_vision.cooldown_remaining - 24.2) < 0.0001, "Yeonmyo Vision should gain exactly 800ms of Campfire cooldown progress")


func _verify_full_stepper_collision_priority() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.activate_campfire(owner, null)
	var rect: Rect2 = controller.campfires[0].get("rect", Rect2())
	var context: Dictionary = _build_step_context(owner, controller)
	var event: String = _run_stepper_descent(Vector2(rect.get_center().x, 635.0), Vector2(0.0, 8.0), context)
	_expect(event == "campfire", "full stepper path should select campfire before the x-overlapping player paddle (got %s)" % event)


func _verify_one_hit_reflection_and_destruction() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.activate_campfire(owner, null)
	var rect: Rect2 = controller.campfires[0].get("rect", Rect2())
	var runtime := ControllerBackedItemRuntime.new(controller)
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var scene := {
		"ball_pos": Vector2(rect.get_center().x, rect.position.y - BALL_SIZE * 0.5 - 2.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_impact_boost": 1.0,
	}
	BallMotionEventProcessor.new().step_motion(
		scene,
		1.0,
		_build_step_context(owner, controller),
		{
			"motion_stepper": BallMotionStepper.new(),
			"active_item_runtime": runtime,
			"audio": audio,
			"feedback": feedback,
		},
		{}
	)
	var reflected_velocity: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	_expect(reflected_velocity.y < 0.0, "the destruction contact should reflect the ball upward")
	_expect(absf(reflected_velocity.x - 3.4) < 0.001, "campfire reflection should retain 85% of lateral velocity")
	_expect(controller.campfires.is_empty(), "the first ball hit should destroy the campfire")
	_expect(not controller.campfire_particles.is_empty(), "destruction should emit ember particles")
	_expect(audio.explosion_count == 1, "destruction should play one fire burst cue")
	_expect(feedback.shake_count == 1, "destruction should trigger one screen response")
	var second_hit: Dictionary = controller.notify_campfire_hit(0, rect.get_center())
	_expect(not bool(second_hit.get("destroyed", true)), "a destroyed campfire must not accept a second hit")


func _verify_rising_ball_is_ignored() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.activate_campfire(FakeOwner.new(), null)
	var rect: Rect2 = controller.campfires[0].get("rect", Rect2())
	var event: Dictionary = BallMotionCollisionDetector.new().check_campfire(
		rect.get_center(), Vector2(0.0, -8.0), BALL_SIZE, controller.get_campfire_collision_context()
	)
	_expect(event.is_empty(), "a rising reflected ball should not immediately collide with the same campfire")


func _verify_reset_clears_state() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.activate_campfire(owner, null)
	_expect(controller.needs_campfire_update(), "active campfire should arm its focused update path")
	controller.update_campfires(owner, null, FRAME_DELTA)
	controller.reset()
	_expect(controller.campfires.is_empty(), "reset should clear placed campfires")
	_expect(controller.campfire_particles.is_empty(), "reset should clear campfire particles")
	_expect(not controller.campfire_player_in_range, "reset should clear the aura flag")
	_expect(controller.get_dash_cooldown_multiplier() == 1.0, "reset should remove the glide recovery bonus")
	_expect(not controller.needs_campfire_update(), "empty campfire state should not add per-frame update work")


func _build_step_context(owner: FakeOwner, controller: Object) -> Dictionary:
	var context: Dictionary = {
		"ball_size": BALL_SIZE,
		"width": 760.0,
		"height": 750.0,
		"max_step_distance": 12.0,
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, owner.player_paddle_height),
		"boss_pos": Vector2(302.5, 25.0),
		"boss_paddle_size": Vector2(155.0, 40.0),
		"hitbox_padding": 5.0,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	context.merge(controller.get_campfire_collision_context(), true)
	return context


func _run_stepper_descent(start_pos: Vector2, ball_vel: Vector2, context: Dictionary) -> String:
	var stepper: Object = BallMotionStepper.new()
	var ball_pos: Vector2 = start_pos
	for _frame in range(120):
		var step_result: Dictionary = stepper.step(ball_pos, ball_vel * FRAME_DELTA * 60.0, ball_vel, context)
		ball_pos = step_result.get("ball_pos", ball_pos)
		var event: String = str(step_result.get("event", "none"))
		if event != "none":
			return event
	return "none"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
