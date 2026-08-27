extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")
const MobileTouchControls := preload("res://scripts/core/mobile_touch_controls.gd")
const PlayerRainWetnessLifecycle := preload("res://scripts/effects/player_rain_wetness_lifecycle.gd")


func exit_tree(owner: Node, registry: Object, cached_module_getter: Callable, callbacks: Dictionary) -> void:
	# Final scene retirement is the one boundary where the canvas-owned wetness
	# host cannot be reused. Free it before module/cache teardown drops the
	# renderer reference; otherwise the detached child can survive until the
	# outgoing battle canvas itself is finally destroyed.
	PlayerRainWetnessLifecycle.tear_down_from_canvas(owner, true)
	if registry != null and registry.has_method("get_cached_instance"):
		var online_runtime: Variant = registry.get_cached_instance("online_match_runtime")
		if typeof(online_runtime) == TYPE_OBJECT and online_runtime != null and online_runtime.has_method("stop"):
			online_runtime.stop()
	var logo_intro: Object = _get_module(cached_module_getter, "penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("cleanup"):
		logo_intro.cleanup()
	var han_miryang_prologue: Object = _get_module(
		cached_module_getter, "stage1_han_miryang_prologue_presentation"
	)
	if han_miryang_prologue != null and han_miryang_prologue.has_method("tear_down"):
		han_miryang_prologue.tear_down()
	var tower_start_card: Object = _get_module(
		cached_module_getter, "tower_start_card_state"
	)
	if tower_start_card != null:
		if tower_start_card.has_method("capture_stats_context"):
			tower_start_card.capture_stats_context(null, null)
		if tower_start_card.has_method("tear_down"):
			tower_start_card.tear_down()
	# 프리배틀 영상 호스트는 detached Control이라 씬 퇴장 때 명시적으로
	# 해제해야 한다(tear_down = 호스트 free + 스트림 참조 해제).
	var stage7_akamu_prebattle_presentation: Object = _get_module(
		cached_module_getter, "stage7_akamu_prebattle_presentation"
	)
	if stage7_akamu_prebattle_presentation != null and stage7_akamu_prebattle_presentation.has_method("tear_down"):
		stage7_akamu_prebattle_presentation.tear_down()
	var audio: Object = _get_module(cached_module_getter, "game_audio")
	if audio != null and audio.has_method("stop_bgm"):
		audio.stop_bgm()
	# 모바일 터치 컨트롤은 수동 Input.action_press와 정적 accept 채널을
	# 유지한다 — 손가락을 누른 채 전투를 떠나면 눌림이 다음 씬으로
	# 누출되므로 registry를 지우기 전에 해제한다. 모듈이 이미 없어도
	# 정적 채널·수동 액션은 강제로 내린다(getter-null fallback).
	var mobile_touch_controls: Object = _get_module(cached_module_getter, "mobile_touch_controls")
	if mobile_touch_controls != null and mobile_touch_controls.has_method("release_all"):
		mobile_touch_controls.release_all()
	MobileTouchControls.force_release_static()
	# Clear battle resources but KEEP the character-select warm set. Every
	# post-battle exit (F10 booth reset, true-defeat settlement, stage-clear
	# exit) skips the boot loading screen, so wiping these here forces a cold
	# main-thread reload (multi-second freeze) or on-demand streaming
	# ("애니메이션 준비 중" badges) on the very next screen. The set was already
	# resident for the whole battle, so retaining it is not a VRAM regression.
	var retained: Dictionary = CharacterSelectPrewarm.new().collect_retained_cache_paths()
	ProjectResourceLoader.clear_caches_except(
		retained.get("textures", []),
		retained.get("audio", [])
	)
	SkillOrbTextureNormalizer.clear_cache()
	if registry != null and registry.has_method("clear_all"):
		registry.clear_all()
	_call(callbacks, "clear_module_cache")


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
