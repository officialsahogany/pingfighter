extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const Stage1GaksitalBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_cooldown_state.gd")
const Stage1GaksitalFanThrowRenderer := preload("res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd")
const Stage1GaksitalFanThrowSkillState := preload("res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd")

const FAN_PROJECTILE_PATH := "res://assets/sprites/stage1/gaksital/gaksital_fan_projectile_imagegen_v1.png"
const FAN_SKILLCARD_PATH := "res://assets/sprites/stage1/gaksital/gaksital_fan_throw_skillcard_imagegen_v2.png"
const FAN_SOUND_PATH := "res://assets/sounds/fan.wav"
const WHIPCRACK_SOUND_PATH := "res://assets/sounds/whipcrack.wav"

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration: float, data: Dictionary = {}, source: String = "") -> void:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration": duration,
			"data": data.duplicate(true),
			"source": source,
		})


class FakeMovementState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func start_knockback(velocity: float, frames: float, decay: float, interrupt_dash: bool = true, allow_stack: bool = true) -> void:
		calls.append({
			"velocity": velocity,
			"frames": frames,
			"decay": decay,
			"interrupt_dash": interrupt_dash,
			"allow_stack": allow_stack,
		})


class FakeImpactEffects:
	extends RefCounted

	var explosion_count := 0
	var particle_count := 0

	func create_energy_explosion(_pos: Vector2, _scale: float = 1.0, _alpha: float = 1.0) -> void:
		explosion_count += 1

	func spawn_paddle_hit_particles(_pos: Vector2, _is_player: bool = true, _normal: Vector2 = Vector2.ZERO, _scale: float = 1.0) -> void:
		particle_count += 1


class FakeAudio:
	extends RefCounted

	var whip_count := 0
	var paddle_hit_count := 0
	var fan_volumes: Array[float] = []
	var whipcrack_volumes: Array[float] = []

	func play_whip() -> void:
		whip_count += 1

	func play_paddle_hit() -> void:
		paddle_hit_count += 1

	func play_gaksital_fan(volume: float = 0.35) -> void:
		fan_volumes.append(volume)

	func play_whipcrack(volume: float = 0.6) -> void:
		whipcrack_volumes.append(volume)


class FakeTearGasRuntime:
	extends RefCounted

	var zones: Array = []
	var parry_count := 0
	var parry_labels: Array[String] = []
	var parry_keys: Array[String] = []

	func get_tear_gas_zones() -> Array:
		return zones

	func trigger_magic_anti_potion_parry(label: String, _pos: Vector2, cooldown_key: String) -> void:
		parry_count += 1
		parry_labels.append(label)
		parry_keys.append(cooldown_key)


class FakeFanThrowActivator:
	extends RefCounted

	var activate_count := 0
	var active := false

	func is_active() -> bool:
		return active

	func activate(context: Dictionary, _deps: Dictionary = {}) -> bool:
		if int(context.get("current_stage", 0)) != 1:
			return false
		if str(context.get("stage1_boss_variant", "")) != "gaksi":
			return false
		activate_count += 1
		active = true
		return true


class FanThrowRenderFixture:
	extends Node2D

	var renderer: Object = null
	var context: Dictionary = {}

	func _draw() -> void:
		if renderer != null and renderer.has_method("draw"):
			renderer.draw(self, context, Vector2.ZERO, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_verify_visual_assets_and_renderer_contract()
	_verify_audio_assets_and_contract()
	await _verify_renderer_attaches_to_viewport_without_transform_error()
	_verify_fan_throw_launches_single_and_enraged_fans()
	_verify_fan_throw_uses_fps_scale_for_windup_and_motion()
	_verify_fan_throw_stuns_and_knocks_player_on_hit()
	_verify_fan_throw_smoke_blocks_status_and_knockback()
	_verify_fan_throw_runtime_smoke_zone_blocks_status_and_knockback()
	_verify_fan_throw_cleanup_and_variant_gates()
	_verify_cooldown_state_activates_fan_throw_and_exports_hud()
	_verify_gaksital_skill_copy_is_localized()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("stage1_gaksital_fan_throw_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_visual_assets_and_renderer_contract() -> void:
	var projectile_texture := load(FAN_PROJECTILE_PATH) as Texture2D
	var projectile := projectile_texture.get_image() if projectile_texture != null else null
	_expect(projectile != null and not projectile.is_empty(), "Gaksital fan projectile PNG should load for visual QA")
	if projectile != null and not projectile.is_empty():
		_expect(projectile.get_width() == 256 and projectile.get_height() == 256, "fan projectile should stay square 256x256 for center-rotation")
		_expect(_count_visible_samples(projectile, 16) >= 24, "fan projectile should contain visible nonblank pixels")
		_expect(_corner_alpha_max(projectile) <= 0.05, "fan projectile corners should stay transparent after nukki")

	var skillcard_texture := load(FAN_SKILLCARD_PATH) as Texture2D
	var skillcard := skillcard_texture.get_image() if skillcard_texture != null else null
	_expect(skillcard != null and not skillcard.is_empty(), "Gaksital fan throw skillcard PNG should load for visual QA")
	if skillcard != null and not skillcard.is_empty():
		_expect(skillcard.get_width() == 408 and skillcard.get_height() == 120, "fan throw skillcard should keep the 408x120 boss-card crop")
		_expect(_count_visible_samples(skillcard, 12) >= 40, "fan throw skillcard should contain visible nonblank pixels")

	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd")
	_expect(renderer_source.find("draw_set_transform") < 0, "fan throw renderer should not reset the battle canvas transform")
	_expect(renderer_source.find("canvas.draw_polygon(points") >= 0, "fan throw renderer should draw rotated texture quads through UV polygons")
	_expect(renderer_source.find("Vector2(0.0, 0.0)") >= 0 and renderer_source.find("Vector2(1.0, 1.0)") >= 0, "fan throw renderer should keep full-texture UVs for the square projectile")

	var boss_renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_boss_actor_renderer.gd")
	_expect(boss_renderer_source.find("GAKSITAL_STATIC_GRID_COLS := 3") >= 0, "Gaksital 8f sheets should keep the 3x3 grid authority")
	_expect(boss_renderer_source.find("GAKSITAL_WALK_GRID_COLS := 4") >= 0, "Gaksital walk sheets should keep the 4x4 grid authority")
	_expect(boss_renderer_source.find("GAKSITAL_FAN_THROW_GRID_COLS := 4") >= 0, "Gaksital fan_throw sheet should keep the 4x4 grid authority")
	_expect(boss_renderer_source.find("_gaksital_static_selection") >= 0, "Gaksital static sheets should use a dedicated 3x3 selection helper")


func _verify_audio_assets_and_contract() -> void:
	var fan_stream := load(FAN_SOUND_PATH) as AudioStream
	var whipcrack_stream := load(WHIPCRACK_SOUND_PATH) as AudioStream
	_expect(fan_stream != null, "Gaksital fan throw should load original fan.wav")
	_expect(whipcrack_stream != null, "Gaksital fan throw should load original whipcrack.wav")

	var state_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd")
	_expect(state_source.find("play_gaksital_fan") >= 0, "fan throw should call the original fan sound helper")
	_expect(state_source.find("play_whipcrack") >= 0, "fan throw should call the original whipcrack hit helper")
	_expect(state_source.find("play_whip(") < 0, "fan throw should not use Dalji whip audio as a stand-in")
	_expect(state_source.find("play_paddle_hit(") < 0, "fan throw should not use generic paddle-hit audio as a stand-in")
	_expect(state_source.find("TAU") >= 0 and state_source.find("fan_sound_volume") >= 0, "fan throw should play fan.wav on spin-boundary crossings")

	var game_audio_source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(game_audio_source.find("FAN_SOUND_PATH") >= 0, "game_audio should register fan.wav")
	_expect(game_audio_source.find("WHIPCRACK_SOUND_PATH") >= 0, "game_audio should register whipcrack.wav")
	_expect(game_audio_source.find("GAKSITAL_FAN_SOUND_POOL_SIZE := 3") >= 0, "game_audio should keep a three-layer fan sound pool for enraged throws")


func _verify_renderer_attaches_to_viewport_without_transform_error() -> void:
	var projectile_texture := load(FAN_PROJECTILE_PATH) as Texture2D
	_expect(projectile_texture != null, "fan projectile texture should load for viewport render smoke")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 160)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var fixture := FanThrowRenderFixture.new()
	fixture.renderer = Stage1GaksitalFanThrowRenderer.new()
	fixture.context = {
		"current_stage": 1,
		"boss_fan_projectile_texture": projectile_texture,
		"stage1_fan_throw_fans": [{
			"x": 80.0,
			"y": 80.0,
			"draw_size": 64.0,
			"spin": 0.65,
			"alpha": 1.0,
			"tint": Color.WHITE,
		}],
	}
	viewport.add_child(fixture)
	fixture.queue_redraw()
	for _idx in range(4):
		await process_frame

	_expect(fixture.is_inside_tree(), "fan throw renderer fixture should stay attached through viewport redraw")
	viewport.queue_free()


func _verify_fan_throw_launches_single_and_enraged_fans() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	var audio := FakeAudio.new()
	var deps := {"audio": audio}
	_expect(state.activate(context, deps), "Gaksital fan throw should activate in Stage 1 gaksi context")
	_advance_until_launched(state, context, deps)
	var draw_context: Dictionary = state.get_draw_context()
	var fans: Array = _as_array(draw_context.get("stage1_fan_throw_fans", []))
	_expect(fans.size() == 1, "normal Gaksital fan throw should launch one fan")
	_expect(bool(draw_context.get("stage1_fan_throw_active", false)), "fan throw draw context should stay active after launch")
	_expect(audio.whip_count == 0, "fan throw windup and launch should stay silent in Python parity")
	_expect(audio.paddle_hit_count == 0, "fan throw launch should not use paddle-hit audio")
	_expect(audio.fan_volumes.is_empty(), "fan throw should not play fan audio until a spin crosses 2pi")
	_set_all_fan_spins(state, TAU - 0.05)
	state.update_and_collide(1.0, {}, context, deps)
	_expect(audio.fan_volumes.size() == 1, "main fan should play fan.wav once when crossing a 2pi spin boundary")
	if not audio.fan_volumes.is_empty():
		_expect(is_equal_approx(float(audio.fan_volumes[0]), 0.35), "main fan spin audio should use original 0.35 volume")

	var enraged_state: Object = Stage1GaksitalFanThrowSkillState.new()
	var enraged_context: Dictionary = context.duplicate(true)
	enraged_context["enraged_boss_active"] = true
	var enraged_audio := FakeAudio.new()
	var enraged_deps := {"audio": enraged_audio}
	_expect(enraged_state.activate(enraged_context, enraged_deps), "enraged Gaksital fan throw should activate")
	var ball_context_without_enrage: Dictionary = context.duplicate(true)
	ball_context_without_enrage.erase("enraged_boss_active")
	_advance_until_launched(enraged_state, ball_context_without_enrage, enraged_deps)
	var enraged_fans: Array = _as_array(enraged_state.get_draw_context().get("stage1_fan_throw_fans", []))
	_expect(enraged_fans.size() == 3, "enraged Gaksital fan throw should launch three fans even when the later ball context lacks the enraged flag")
	_set_all_fan_spins(enraged_state, TAU - 0.05)
	enraged_state.update_and_collide(1.0, {}, ball_context_without_enrage, enraged_deps)
	_expect(enraged_audio.fan_volumes.size() == 3, "enraged fan throw should play all three fan spin sounds on a shared 2pi crossing")
	if enraged_audio.fan_volumes.size() == 3:
		_expect(is_equal_approx(float(enraged_audio.fan_volumes[0]), 0.35), "enraged main fan should keep original 0.35 spin volume")
		_expect(is_equal_approx(float(enraged_audio.fan_volumes[1]), 0.25), "first extra fan should use original 0.25 spin volume")
		_expect(is_equal_approx(float(enraged_audio.fan_volumes[2]), 0.25), "second extra fan should use original 0.25 spin volume")


func _verify_fan_throw_uses_fps_scale_for_windup_and_motion() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	_expect(state.activate(context, {}), "fan throw should activate before fps_scale smoke")
	for _idx in range(59):
		state.update_and_collide(0.5, {}, context, {})
	_expect(_as_array(state.get_draw_context().get("stage1_fan_throw_fans", [])).is_empty(), "0.5 fps_scale should not finish the 30f windup early")
	state.update_and_collide(0.5, {}, context, {})
	var fans: Array = _as_array(state.get_draw_context().get("stage1_fan_throw_fans", []))
	_expect(fans.size() == 1, "two half-frames should accumulate to the final windup frame")
	if fans.is_empty() or not (fans[0] is Dictionary):
		return
	var before: Dictionary = (fans[0] as Dictionary).duplicate(true)
	state.update_and_collide(0.5, {}, context, {})
	var after_fans: Array = _as_array(state.get_draw_context().get("stage1_fan_throw_fans", []))
	_expect(after_fans.size() == 1, "fan should remain active after a half-frame motion tick")
	if after_fans.is_empty() or not (after_fans[0] is Dictionary):
		return
	var after: Dictionary = after_fans[0]
	_expect(is_equal_approx(float(after.get("elapsed", 0.0)) - float(before.get("elapsed", 0.0)), 0.5), "fan elapsed should advance by fps_scale")
	_expect(is_equal_approx(float(after.get("spin", 0.0)) - float(before.get("spin", 0.0)), 0.15), "fan spin should advance by 0.3 * fps_scale")


func _verify_fan_throw_stuns_and_knocks_player_on_hit() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	var status_state := FakeStatusEffectState.new()
	var movement_state := FakeMovementState.new()
	var impact_effects := FakeImpactEffects.new()
	var audio := FakeAudio.new()
	var deps := {
		"status_effect_state": status_state,
		"movement_state": movement_state,
		"impact_effects": impact_effects,
		"audio": audio,
	}
	_expect(state.activate(context, deps), "fan throw should activate before hit smoke")
	_advance_until_launched(state, context, deps)
	state.rng.seed = _find_seed_for_first_randf_below(0.5)
	var player_size := Vector2(155.0, 50.0)
	context["player_paddle_size"] = player_size
	context["player_pos"] = _first_fan_pos(state) + Vector2(12.0, 0.0) - player_size * 0.5
	var scene := {}
	var result: Dictionary = state.update_and_collide(1.0, scene, context, deps)
	_expect(bool(result.get("stage1_gaksital_fan_throw_hit", false)), "fan throw should report a player hit")
	_expect(bool(result.get("stage1_gaksital_fan_throw_player_stunned", false)), "fan throw should report player stun")
	_expect(status_state.calls.size() == 1, "fan throw should apply exactly one status")
	if not status_state.calls.is_empty():
		var status_call: Dictionary = status_state.calls[0]
		_expect(str(status_call.get("target", "")) == "player", "fan throw status target should be player")
		_expect(str(status_call.get("status_id", "")) == "stun", "fan throw status id should be stun")
		_expect(is_equal_approx(float(status_call.get("duration", 0.0)), 18.0), "fan throw stun duration should match the Phase 3 contract")
		_expect(str(status_call.get("source", "")) == "stage1_fan_throw", "fan throw status source should be stage1_fan_throw")
	_expect(movement_state.calls.size() == 1, "fan throw should apply exactly one knockback")
	if not movement_state.calls.is_empty():
		var knockback_call: Dictionary = movement_state.calls[0]
		_expect(is_equal_approx(float(knockback_call.get("velocity", 0.0)), -12.0), "fan throw knockback should use Python-style random ±12, not player-vs-fan direction")
		_expect(is_equal_approx(float(knockback_call.get("frames", 0.0)), 18.0), "fan throw knockback duration should match the Phase 3 contract")
		_expect(is_equal_approx(float(knockback_call.get("decay", 0.0)), 0.92), "fan throw knockback decay should match the Phase 3 contract")
	_expect(impact_effects.explosion_count == 1, "fan throw hit should spawn impact explosion")
	_expect(impact_effects.particle_count == 1, "fan throw hit should spawn paddle-hit particles")
	_expect(audio.paddle_hit_count == 0, "fan throw hit should not use generic paddle-hit audio")
	_expect(audio.whipcrack_volumes.size() == 1, "fan throw hit should play original whipcrack audio")
	if not audio.whipcrack_volumes.is_empty():
		_expect(is_equal_approx(float(audio.whipcrack_volumes[0]), 0.6), "main fan hit should use original 0.6 whipcrack volume")
	_expect(bool(scene.get("stage1_gaksital_fan_throw_hit", false)), "fan throw hit should be mirrored into the scene dictionary")


func _verify_fan_throw_smoke_blocks_status_and_knockback() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	var status_state := FakeStatusEffectState.new()
	var movement_state := FakeMovementState.new()
	var impact_effects := FakeImpactEffects.new()
	var deps := {
		"status_effect_state": status_state,
		"movement_state": movement_state,
		"impact_effects": impact_effects,
	}
	_expect(state.activate(context, deps), "fan throw should activate before smoke block")
	_advance_until_launched(state, context, deps)
	var player_size := Vector2(155.0, 50.0)
	var player_center: Vector2 = _first_fan_pos(state)
	context["player_paddle_size"] = player_size
	context["player_pos"] = player_center - player_size * 0.5
	context["tear_gas_zones"] = [{
		"position": player_center,
		"radius": 80.0,
		"radius_x": 120.0,
		"opacity": 0.8,
	}]
	var result: Dictionary = state.update_and_collide(1.0, {}, context, deps)
	_expect(bool(result.get("stage1_gaksital_fan_throw_hit", false)), "smoke-blocked fan throw should still report a hit")
	_expect(bool(result.get("stage1_gaksital_fan_throw_smoke_blocked", false)), "tear gas should block fan throw stun and knockback")
	_expect(status_state.calls.is_empty(), "smoke-blocked fan throw should not apply stun")
	_expect(movement_state.calls.is_empty(), "smoke-blocked fan throw should not apply knockback")
	_expect(impact_effects.explosion_count == 0, "smoke-blocked fan throw should not spawn impact explosion")
	_expect(impact_effects.particle_count == 0, "smoke-blocked fan throw should not spawn paddle-hit particles")
	_expect(is_equal_approx(float(state.get_draw_context().get("stage1_fan_throw_hit_effect_timer", -1.0)), 0.0), "smoke-blocked fan throw should not arm the hit-effect timer")


func _verify_fan_throw_runtime_smoke_zone_blocks_status_and_knockback() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	var status_state := FakeStatusEffectState.new()
	var movement_state := FakeMovementState.new()
	var runtime := FakeTearGasRuntime.new()
	var deps := {
		"status_effect_state": status_state,
		"movement_state": movement_state,
		"active_item_runtime": runtime,
	}
	_expect(state.activate(context, deps), "fan throw should activate before runtime smoke block")
	_advance_until_launched(state, context, deps)
	var player_size := Vector2(155.0, 50.0)
	var player_center: Vector2 = _first_fan_pos(state)
	context["player_paddle_size"] = player_size
	context["player_pos"] = player_center - player_size * 0.5
	runtime.zones = [{
		"position": player_center,
		"radius": 90.0,
		"radius_x": 110.0,
		"opacity": 0.9,
	}]
	var result: Dictionary = state.update_and_collide(1.0, {}, context, deps)
	_expect(bool(result.get("stage1_gaksital_fan_throw_smoke_blocked", false)), "active_item_runtime tear gas zones should block fan throw")
	_expect(status_state.calls.is_empty(), "runtime smoke-blocked fan throw should not apply stun")
	_expect(movement_state.calls.is_empty(), "runtime smoke-blocked fan throw should not apply knockback")
	_expect(runtime.parry_count == 1, "runtime smoke-blocked fan throw should notify the magic anti-potion parry hook")
	if runtime.parry_count > 0:
		_expect(str(runtime.parry_labels[0]) == "부채", "fan throw parry hook should use the Korean fan label")
		_expect(str(runtime.parry_keys[0]) == "fan_throw", "fan throw parry hook should use the fan_throw cooldown key")


func _verify_fan_throw_cleanup_and_variant_gates() -> void:
	var state: Object = Stage1GaksitalFanThrowSkillState.new()
	var context: Dictionary = _base_context()
	_expect(state.should_roll_activation(150.0, context), "fan throw should roll activation at the gauge cost")
	_expect(not state.should_roll_activation(149.0, context), "fan throw should not roll activation below the gauge cost")
	_expect(not state.can_activate({"current_stage": 1, "stage1_boss_variant": "dalji"}), "Gaksital fan throw should not activate for Dalji variant")
	_expect(state.activate(context, {}), "fan throw should activate before cleanup smoke")
	var dalji_context: Dictionary = context.duplicate(true)
	dalji_context["stage1_boss_variant"] = "dalji"
	state.update_and_collide(1.0, {}, dalji_context, {})
	_expect(not state.is_active(), "fan throw should reset immediately when the live context switches back to Dalji")

	var timer_state: Object = Stage1GaksitalFanThrowSkillState.new()
	_expect(timer_state.activate(context, {}), "fan throw should activate before timer cleanup smoke")
	_advance_until_launched(timer_state, context)
	for _idx in range(181):
		timer_state.update_and_collide(1.0, {}, context, {})
	_expect(not timer_state.is_active(), "fan throw should clear itself after its 180f timer expires")

	var out_state: Object = Stage1GaksitalFanThrowSkillState.new()
	_expect(out_state.activate(context, {}), "fan throw should activate before out-of-bounds cleanup smoke")
	_advance_until_launched(out_state, context)
	var out_context: Dictionary = context.duplicate(true)
	out_context["width"] = 1.0
	out_context["height"] = 1.0
	out_state.update_and_collide(1.0, {}, out_context, {})
	_expect(not out_state.is_active(), "fan throw should clear itself after all fans leave bounds")

	var round_state: Object = Stage1GaksitalFanThrowSkillState.new()
	_expect(round_state.activate(context, {}), "fan throw should activate before round cleanup smoke")
	round_state.reset_round()
	_expect(not round_state.is_active(), "reset_round should clear windup and active fans")


func _verify_cooldown_state_activates_fan_throw_and_exports_hud() -> void:
	var cooldown_state: Object = Stage1GaksitalBossSkillCooldownState.new()
	var fan_throw := FakeFanThrowActivator.new()
	var context := _base_context()
	context["ball_active"] = true
	var deps := {"stage1_gaksital_fan_throw_skill_state": fan_throw}
	cooldown_state.update(960.0, context, deps)
	_expect(fan_throw.activate_count == 1, "Gaksital cooldown should activate fan throw when charged")
	var hud_context: Dictionary = cooldown_state.get_hud_context()
	_expect(bool(hud_context.get("stage1_gaksital_boss_skill_hud_active", false)), "Gaksital cooldown should export active HUD context")
	_expect(str(hud_context.get("stage1_gaksital_boss_skill_hud_boss_name", "")) == "각시탈", "Gaksital HUD boss name should be Korean")
	var skills: Array = _as_array(hud_context.get("stage1_gaksital_boss_skill_hud_skills", []))
	_expect(skills.size() == 2, "Gaksital HUD should expose fan throw and fan wind")
	var fan_throw_skill: Dictionary = _find_skill(skills, "fan_throw")
	var fan_wind_skill: Dictionary = _find_skill(skills, "fan_wind")
	_expect(not fan_throw_skill.is_empty(), "Gaksital HUD should include fan_throw")
	_expect(not fan_wind_skill.is_empty(), "Gaksital HUD should include fan_wind")
	if not fan_throw_skill.is_empty():
		_expect(str(fan_throw_skill.get("label", "")) == "부채던지기", "Gaksital fan throw HUD label should be Korean")
		_expect(str(fan_throw_skill.get("status", "")) == "casting", "Gaksital fan throw HUD status should become casting after activation")
	if not fan_wind_skill.is_empty():
		_expect(str(fan_wind_skill.get("label", "")) == "부채바람", "Gaksital fan wind HUD label should be Korean")
		_expect(str(fan_wind_skill.get("trigger_type", "")) == "on_boss_hit", "Gaksital fan wind should use the on-hit trigger")
		_expect(str(fan_wind_skill.get("trigger_label", "")) == "타격", "Gaksital fan wind trigger label should be Korean")


func _verify_gaksital_skill_copy_is_localized() -> void:
	var expected := {
		LanguageSettings.LANGUAGE_ENGLISH: {
			"부채던지기": "Fan Throw",
			"부채바람": "Fan Wind",
			"각시탈": "Gaksital",
		},
		LanguageSettings.LANGUAGE_CHINESE: {
			"부채던지기": "投扇",
			"부채바람": "扇风",
			"각시탈": "假面",
		},
		LanguageSettings.LANGUAGE_JAPANESE: {
			"부채던지기": "扇投げ",
			"부채바람": "扇風",
			"각시탈": "カクシタル",
		},
		LanguageSettings.LANGUAGE_SPANISH: {
			"부채던지기": "Lanzamiento de abanico",
			"부채바람": "Viento de abanico",
			"각시탈": "Gaksital",
		},
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
			"부채던지기": "Arremesso de leque",
			"부채바람": "Vento de leque",
			"각시탈": "Gaksital",
		},
		LanguageSettings.LANGUAGE_RUSSIAN: {
			"부채던지기": "Бросок веера",
			"부채바람": "Ветер веера",
			"각시탈": "Какситаль",
		},
	}
	var description := "회전하는 부채를 던집니다. 맞으면 잠시 기절하고 밀려납니다."
	var fan_wind_description := "부채바람 소용돌이로 공을 붙잡았다가 아래로 방출합니다."
	for language in expected.keys():
		LanguageSettings.set_language(str(language))
		var spec: Dictionary = expected[language]
		for source_text in spec.keys():
			var localized: String = LanguageSettings.translate_text(str(source_text))
			_expect(localized == str(spec[source_text]), "%s should localize %s" % [language, source_text])
			_expect(not _has_hangul(localized), "%s localized %s should not leak Korean" % [language, source_text])
		_expect(not _has_hangul(LanguageSettings.translate_text(description)), "%s fan throw description should not leak Korean" % language)
		_expect(not _has_hangul(LanguageSettings.translate_text(fan_wind_description)), "%s fan wind description should not leak Korean" % language)


func _advance_until_launched(state: Object, context: Dictionary, deps: Dictionary = {}) -> void:
	for _idx in range(40):
		state.update_and_collide(1.0, {}, context, deps)
		var fans: Array = _as_array(state.get_draw_context().get("stage1_fan_throw_fans", []))
		if not fans.is_empty():
			return
	_expect(false, "fan throw should launch fans after windup")


func _first_fan_pos(state: Object) -> Vector2:
	var fans: Array = _as_array(state.get_draw_context().get("stage1_fan_throw_fans", []))
	if fans.is_empty() or not (fans[0] is Dictionary):
		return Vector2.ZERO
	var fan: Dictionary = fans[0]
	return Vector2(float(fan.get("x", 0.0)), float(fan.get("y", 0.0)))


func _set_all_fan_spins(state: Object, spin: float) -> void:
	for index in range(state.fans.size()):
		if state.fans[index] is Dictionary:
			var fan: Dictionary = state.fans[index]
			fan["spin"] = spin
			state.fans[index] = fan


func _base_context() -> Dictionary:
	return {
		"current_stage": 1,
		"stage1_boss_variant": "gaksi",
		"width": 760.0,
		"height": 750.0,
		"boss_pos": Vector2(330.0, 70.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 650.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _find_skill(skills: Array, skill_id: String) -> Dictionary:
	for value in skills:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value as Dictionary
	return {}


func _find_seed_for_first_randf_below(threshold: float) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 1024):
		probe.seed = candidate
		if probe.randf() < threshold:
			return candidate
	return 1


func _count_visible_samples(image: Image, step: int) -> int:
	var count := 0
	for y in range(0, image.get_height(), max(1, step)):
		for x in range(0, image.get_width(), max(1, step)):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count


func _corner_alpha_max(image: Image) -> float:
	var corners := [
		Vector2i(0, 0),
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]
	var max_alpha := 0.0
	for corner in corners:
		max_alpha = max(max_alpha, image.get_pixelv(corner).a)
	return max_alpha


func _has_hangul(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x1100 and code <= 0x11FF:
			return true
		if code >= 0x3130 and code <= 0x318F:
			return true
		if code >= 0xAC00 and code <= 0xD7AF:
			return true
	return false


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	if bool(_language_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_language_settings_snapshot.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
