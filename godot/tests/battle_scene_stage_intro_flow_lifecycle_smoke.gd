extends SceneTree

const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")
const BattleSceneStageIntroFlowLifecycle := preload("res://scripts/core/battle_scene_stage_intro_flow_lifecycle.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}
var _cached_modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var redraw_calls := 0

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeLogoIntro:
	extends RefCounted

	var audio_playing := false

	func is_audio_playing() -> bool:
		return audio_playing


class FakeAudio:
	extends RefCounted

	var play_calls := 0
	var played_stage := 0

	func play_stage_bgm(stage: int) -> void:
		play_calls += 1
		played_stage = stage


class FakeIntro:
	extends RefCounted

	var begin_calls := 0
	var should_begin := true

	func begin(_owner: Object, _registry: Object) -> bool:
		begin_calls += 1
		return should_begin


class FakeMythicItemRuntime:
	extends RefCounted

	var prewarm_calls := 0
	var last_owner: Object = null
	var last_registry: Object = null

	func prewarm_acquisition_cinematic(owner: Object = null, registry: Object = null) -> void:
		prewarm_calls += 1
		last_owner = owner
		last_registry = registry


class FakeStageIntroFlowLifecycle:
	extends RefCounted

	var landing_calls := 0
	var ball_calls := 0
	var bgm_calls := 0

	func begin_stage_landing_intro(
		_flow: Object,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_cached_module_getter: Callable
	) -> void:
		landing_calls += 1

	func begin_ball_spawn_intro(_flow: Object, _owner: Object, _registry: Object, _module_getter: Callable) -> void:
		ball_calls += 1

	func start_battle_bgm(_flow: Object, _owner: Object, _module_getter: Callable) -> void:
		bgm_calls += 1


func _init() -> void:
	_verify_stage_intro_waits_for_logo_audio()
	_verify_stage_intro_starts_landing_intro()
	_verify_stage_intro_falls_back_to_ball_spawn()
	_verify_ball_spawn_intro_stages_acquisition_cinematic()
	_verify_flow_controller_delegates_stage_intro_surface()

	if _failures.is_empty():
		print("battle_scene_stage_intro_flow_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_intro_waits_for_logo_audio() -> void:
	var lifecycle: Object = BattleSceneStageIntroFlowLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	var owner := FakeOwner.new()
	var logo := FakeLogoIntro.new()
	var audio := FakeAudio.new()
	var landing := FakeIntro.new()
	logo.audio_playing = true
	flow.set("_battle_initialized", true)
	_modules = {"game_audio": audio, "stage_landing_intro": landing}
	_cached_modules = {"penguin_logo_intro": logo}

	lifecycle.begin_stage_landing_intro(
		flow,
		owner,
		null,
		Callable(self, "_get_module"),
		Callable(self, "_get_cached_module")
	)

	_expect(
		not bool(flow.get("_stage_landing_intro_started")),
		"stage intro should wait while logo audio is still playing"
	)
	_expect(owner.redraw_calls == 1, "logo-audio wait should request redraw")
	_expect(audio.play_calls == 0 and landing.begin_calls == 0, "logo-audio wait should not start BGM or landing intro")


func _verify_stage_intro_starts_landing_intro() -> void:
	var lifecycle: Object = BattleSceneStageIntroFlowLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	var owner := FakeOwner.new()
	var logo := FakeLogoIntro.new()
	var audio := FakeAudio.new()
	var landing := FakeIntro.new()
	flow.set("_battle_initialized", true)
	_modules = {"game_audio": audio, "stage_landing_intro": landing}
	_cached_modules = {"penguin_logo_intro": logo}

	lifecycle.begin_stage_landing_intro(
		flow,
		owner,
		null,
		Callable(self, "_get_module"),
		Callable(self, "_get_cached_module")
	)

	_expect(bool(flow.get("_stage_landing_intro_started")), "stage intro should mark landing intro started")
	_expect(bool(flow.get("_battle_bgm_started")), "stage intro should latch BGM start")
	_expect(audio.play_calls == 1 and audio.played_stage == 4, "stage intro should start stage BGM with owner stage")
	_expect(landing.begin_calls == 1, "stage intro should begin landing intro")
	_expect(
		not bool(flow.get("_ball_spawn_intro_started")),
		"successful landing intro should not immediately start ball-spawn intro"
	)
	_expect(owner.redraw_calls == 1, "successful landing intro should request redraw")


func _verify_stage_intro_falls_back_to_ball_spawn() -> void:
	var lifecycle: Object = BattleSceneStageIntroFlowLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	var owner := FakeOwner.new()
	var logo := FakeLogoIntro.new()
	var audio := FakeAudio.new()
	var landing := FakeIntro.new()
	var ball_spawn := FakeIntro.new()
	landing.should_begin = false
	flow.set("_battle_initialized", true)
	_modules = {
		"game_audio": audio,
		"stage_landing_intro": landing,
		"stage_ball_spawn_intro": ball_spawn,
	}
	_cached_modules = {"penguin_logo_intro": logo}

	lifecycle.begin_stage_landing_intro(
		flow,
		owner,
		null,
		Callable(self, "_get_module"),
		Callable(self, "_get_cached_module")
	)

	_expect(bool(flow.get("_stage_landing_intro_started")), "fallback path should still mark landing intro attempted")
	_expect(bool(flow.get("_ball_spawn_intro_started")), "fallback path should start ball-spawn intro")
	_expect(
		landing.begin_calls == 1 and ball_spawn.begin_calls == 1,
		"fallback path should try landing then ball-spawn intro"
	)
	_expect(owner.redraw_calls == 1, "ball-spawn fallback should request redraw when it begins")


# Policy (b), 2026-06-11: the acquisition cinematic host is staged at
# ball-spawn-intro start (entry + stage transition both pass here, outside
# rally frames) so the first mid-battle mythic/legendary pickup does not pay
# the ~52ms ensure_host cold start. The boot stage-runtime prewarm stays
# asset-only — battle_boot_resource_prewarm_smoke pins that contract.
func _verify_ball_spawn_intro_stages_acquisition_cinematic() -> void:
	var lifecycle: Object = BattleSceneStageIntroFlowLifecycle.new()
	var flow: Object = BattleSceneFlowController.new()
	var owner := FakeOwner.new()
	var ball_spawn := FakeIntro.new()
	var mythic := FakeMythicItemRuntime.new()
	flow.set("_battle_initialized", true)
	_modules = {
		"stage_ball_spawn_intro": ball_spawn,
		"mythic_item_runtime": mythic,
	}
	_cached_modules = {}

	lifecycle.begin_ball_spawn_intro(flow, owner, null, Callable(self, "_get_module"))
	_expect(
		mythic.prewarm_calls == 1,
		"ball-spawn intro start should stage the acquisition cinematic host once"
	)
	_expect(
		mythic.last_owner == owner,
		"cinematic host staging must receive the battle owner for ensure_host"
	)

	lifecycle.begin_ball_spawn_intro(flow, owner, null, Callable(self, "_get_module"))
	_expect(
		mythic.prewarm_calls == 1,
		"repeat begin while the intro flag is set should not restage the host"
	)


func _verify_flow_controller_delegates_stage_intro_surface() -> void:
	var flow: Object = BattleSceneFlowController.new()
	var fake := FakeStageIntroFlowLifecycle.new()
	var owner := FakeOwner.new()
	flow.stage_intro_flow_lifecycle = fake

	flow.begin_stage_landing_intro(owner, null, Callable(self, "_get_module"), Callable(self, "_get_cached_module"))
	flow.begin_ball_spawn_intro(owner, null, Callable(self, "_get_module"))
	flow._start_battle_bgm(owner, Callable(self, "_get_module"))

	_expect(fake.landing_calls == 1, "flow controller should delegate stage-landing intro surface")
	_expect(fake.ball_calls == 1, "flow controller should delegate ball-spawn intro surface")
	_expect(fake.bgm_calls == 1, "flow controller should delegate BGM helper surface")


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _get_cached_module(key: String) -> Object:
	var value: Variant = _cached_modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
