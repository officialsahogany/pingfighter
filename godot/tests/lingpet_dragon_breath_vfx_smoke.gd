extends SceneTree

# Seals the Dragon Breath modular-VFX remaster: WritheEmber shader presets +
# procedural texture pieces + the real immediate-draw path (canvas.material
# set/restore around textured polygons / rects). A SCRIPT ERROR inside the
# probe's _draw() would be flagged by the smoke runner's error scan, so driving
# a live _draw() across the breath / fire-zone / hit-flash states is what proves
# the new render path does not crash.

const DragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")
const DragonBreathTextureCache := preload("res://scripts/lingpet/lingpet_dragon_breath_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const VIEW_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []
var _skill: Object = null
var _owner: FakeOwner = null
var _registry: FakeRegistry = null
var _probe: BreathVfxProbe = null


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := true
	var ball_pos := Vector2(380.0, 640.0)
	var ball_vel := Vector2(0.0, -260.0)
	var ball_size := 28.6


class FakeStatusEffectState:
	extends RefCounted

	func apply_status(_target: String, _status_id: String, _duration_frames: float, _data: Dictionary = {}, _source: String = "") -> Dictionary:
		return {}

	func clear_status(_target: String, _status_id: String = "", _source: String = "") -> void:
		pass


class FakeAudio:
	extends RefCounted

	func play_dragon_breath_fire(_low_volume: bool = false) -> void:
		pass


class FakeFeedback:
	extends RefCounted

	func max_screen_shake(_duration: float, _strength: float) -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = FakeStatusEffectState.new()
	var game_audio: Object = FakeAudio.new()
	var battle_feedback_state: Object = FakeFeedback.new()

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "game_audio":
			return game_audio
		if key == "battle_feedback_state":
			return battle_feedback_state
		return null


class BreathVfxProbe:
	extends Node2D

	var skill: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if skill != null:
			skill.draw(self, Vector2.ZERO)


func _init() -> void:
	seed(424242)
	get_root().size = VIEW_SIZE
	_verify_presets_and_textures()
	_skill = DragonBreathSkill.new()
	_skill.prewarm()
	_owner = FakeOwner.new()
	_registry = FakeRegistry.new()
	_skill.launch(Vector2(380.0, 690.0), _owner)
	_probe = BreathVfxProbe.new()
	_probe.name = "BreathVfxProbe"
	_probe.skill = _skill
	get_root().add_child(_probe)
	call_deferred("_run")


func _run() -> void:
	# Frame 1: breath jet + initial embers should be live.
	_probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(_skill.is_active(), "breath should be active on the first drawn frame")

	# Advance until a hit flash and at least one fire zone have appeared, redrawing
	# along the way so the probe draws every VFX state.
	var safety := 0
	while safety < 360:
		_skill.update(1.0 / 60.0, _owner, _registry)
		if _skill.get_fire_zone_spawn_count_for_tests() >= 1 and _skill.get_ball_hit_count_for_tests() >= 1:
			break
		if safety % 6 == 0:
			_probe.queue_redraw()
			await process_frame
		safety += 1

	_expect(_skill.get_ball_hit_count_for_tests() >= 1, "an ember should have hit the ball (drives the hit-flash VFX)")
	_expect(_skill.get_fire_zone_spawn_count_for_tests() >= 1, "a lingering fire zone should have spawned for the zone VFX")
	await _verify_breath_zone_host_attached()

	# Force the hit-flash state and draw it explicitly.
	_owner.ball_pos = Vector2(380.0, 360.0)
	_owner.ball_vel = Vector2(0.0, -260.0)
	_skill.update(1.0 / 60.0, _owner, _registry)
	_probe.queue_redraw()
	await process_frame
	await process_frame

	# Let the breath finish so the fade-out / zones-only state also draws.
	for _i in range(40):
		_skill.update(1.0 / 60.0, _owner, _registry)
	_probe.queue_redraw()
	await process_frame
	await process_frame

	_expect(_probe.draw_count >= 3, "probe should have drawn the breath VFX across multiple frames")
	await _verify_empty_draw_hides_zone_host()
	await _verify_reset_hides_zone_host()
	_finish()


func _verify_presets_and_textures() -> void:
	_expect(WritheEmber.has_preset("red_dragon_breath_jet"), "WritheEmber should expose the dragon-breath jet preset")
	_expect(WritheEmber.has_preset("red_dragon_breath_zone"), "WritheEmber should expose the dragon-breath zone preset")
	var jet_mat: ShaderMaterial = WritheEmber.build_material("red_dragon_breath_jet")
	_expect(jet_mat != null and WritheEmber.is_material_using_shader(jet_mat), "jet preset should build a WritheEmber ShaderMaterial")
	var flame: Texture2D = DragonBreathTextureCache.get_flame_tongue_texture()
	var ember: Texture2D = DragonBreathTextureCache.get_ember_texture()
	_expect(flame != null and flame.get_width() == 64 and flame.get_height() == 64, "flame-tongue texture piece should build at 64x64")
	_expect(ember != null and ember.get_width() == 48 and ember.get_height() == 48, "ember texture piece should build at 48x48")


func _verify_breath_zone_host_attached() -> void:
	_probe.queue_redraw()
	await process_frame
	await process_frame
	var breath_host := _probe.get_node_or_null("LingpetDragonBreathFireFxHost0") as Node2D
	_expect(breath_host != null, "dragon breath should attach a dedicated molotov-zone FX host")
	_expect(
		_probe.get_node_or_null("ActiveItemMolotovFxHost0") == null,
		"dragon breath should not reuse the active-item molotov host-name prefix"
	)
	if breath_host != null:
		_expect(breath_host.visible, "dragon breath zone host should be visible while a fire zone is alive")


func _verify_empty_draw_hides_zone_host() -> void:
	var local_skill: Object = DragonBreathSkill.new()
	local_skill.prewarm()
	var local_probe := BreathVfxProbe.new()
	local_probe.name = "BreathEmptyHideProbe"
	local_probe.skill = local_skill
	get_root().add_child(local_probe)
	await process_frame

	local_skill.call("_spawn_fire_zone", Vector2(380.0, 320.0))
	local_probe.queue_redraw()
	await process_frame
	await process_frame

	var host := local_probe.get_node_or_null("LingpetDragonBreathFireFxHost0") as Node2D
	_expect(host != null, "empty-draw probe should attach the dragon-breath zone host")
	if host != null:
		_expect(host.visible, "empty-draw probe host should start visible with a live zone")

	local_skill.update(3.0, _owner, _registry)
	local_probe.queue_redraw()
	await process_frame
	await process_frame
	if host != null and is_instance_valid(host):
		_expect(not host.visible, "empty fire-zone draw should hide the molotov host after zone expiry")

	local_probe.queue_free()


func _verify_reset_hides_zone_host() -> void:
	var breath_host := _probe.get_node_or_null("LingpetDragonBreathFireFxHost0") as Node2D
	_skill.reset()
	await process_frame
	if breath_host != null and is_instance_valid(breath_host):
		_expect(not breath_host.visible, "dragon breath reset should directly hide any reusable molotov host")


func _finish() -> void:
	if _failures.is_empty():
		print("lingpet_dragon_breath_vfx_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
