extends RefCounted

const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")
const CharacterInfoLingpetPrewarmFilter := preload("res://scripts/hud/character_info_lingpet_prewarm_filter.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")

const STAGE_RUNTIME_PREWARM_COMMON_STEP_COUNT := 11
const STAGE_RUNTIME_PREWARM_COMMON_LABELS := [
	"weather",
	"active_item",
	"mythic_cinematic",
	"perk_overlay",
	"perk_debug_deferred",
	"character_info_prewarm",
	"selected_character",
	"ball_update",
	"result_shell_deferred",
	"lingpet_runtime",
	"lingpet_rail_card",
]
const STAGE2_RUNTIME_PREWARM_LABELS := [
	"stage2_pillar_background",
	"stage2_pillar_scene",
	"stage2_playfield",
	"stage2_skill_hud",
	"stage2_monkey",
]
const STAGE4_RUNTIME_PREWARM_MODULE_KEYS := [
	"stage4_ponk_gauge_hud_renderer",
	"stage4_bird_event",
	"stage4_brazier_monk_event",
	"stage4_moon_event",
	"stage4_ponk_skill_state",
	"stage4_ponk_boss_skill_hud_renderer",
]
const STAGE5_RUNTIME_PREWARM_MODULE_KEYS := [
	"stage5_hongryun_actor_renderer",
	"stage5_hongryun_pillar_scene_drawer",
	"stage5_hongryun_boss_skill_hud_renderer",
]
# Stage 6 비주얼 셸 전체(액터 시트 7장 + 필러 씬 + 보스 스킬 카드 PNG). 이 목록이
# 비어 있던 동안 두 콜드 경로가 첫 전투 draw 프레임으로 떨어졌다:
# actors.lookup_renderer 43.5ms + actors.renderer_draw 51.7ms, 그리고
# stage6.pillar.tetriser_boss_hud 156.6ms(= draw.pillar_overlay.post_hud 157.2ms).
const STAGE6_RUNTIME_PREWARM_MODULE_KEYS := [
	"stage6_tetriser_actor_renderer",
	"stage6_tetriser_pillar_scene_drawer",
	"stage6_tetriser_boss_skill_hud_renderer",
]
const CHARACTER_INFO_OVERLAY_MODULE_KEY := "character_info_overlay"

var battle_resources_prewarmed: bool = false
var battle_core_resources_prewarmed: bool = false
var battle_player_resources_prewarmed: bool = false
var battle_boss_resources_prewarmed: bool = false
var battle_smasher_skill_icons_prewarmed: bool = false
var battle_viper_skill_icons_prewarmed: bool = false
var battle_commando_skill_icons_prewarmed: bool = false
var battle_texture_resources_prewarmed: bool = false
var battle_resource_cache_finalized: bool = false
var battle_audio_setup_finished: bool = false
var battle_bgm_primed: bool = false
var battle_active_item_runtime_prewarmed: bool = false
var battle_mythic_item_runtime_prewarmed: bool = false
var battle_selected_character_runtime_prewarmed: bool = false
var battle_selected_character_runtime_prewarmed_for := ""
var selected_character_runtime_prewarm_step_character := ""
var selected_character_runtime_prewarm_step_index := 0
var battle_pillar_background_prewarmed: bool = false
var battle_stage2_pillar_background_prewarmed: bool = false
var battle_stage2_playfield_resources_prewarmed: bool = false
var battle_stage3_pillar_background_prewarmed: bool = false
var battle_stage3_playfield_resources_prewarmed: bool = false
var battle_stage4_pillar_background_prewarmed: bool = false
var battle_stage4_playfield_resources_prewarmed: bool = false
var battle_stage5_pillar_background_prewarmed: bool = false
var battle_stage6_pillar_background_prewarmed: bool = false
var battle_runtime_perk_overlay_prewarmed: bool = false
var battle_runtime_perk_debug_prewarmed: bool = false
var battle_character_info_prewarmed: bool = false
var battle_character_info_lingpet_prewarmed_for_key := ""
var battle_character_info_lingpet_prewarm_pet_ids: Array[String] = []
var battle_stage_clear_result_shell_prewarmed: bool = false
var battle_stage_clear_result_prewarmed: bool = false
var battle_stage_clear_result_prewarmed_for := ""
var stage_intro_resources_prewarmed: bool = false
var stage_intro_resources_prewarm_step_index: int = 0
var stage_runtime_resources_prewarmed_for_stage: int = 0
var stage_runtime_prewarm_step_stage: int = 0
var stage_runtime_prewarm_step_index: int = 0
var battle_pso_prewarmer_attached: bool = false
var battle_pso_prewarmer_stage_ids: Dictionary = {}


class ModuleGetterRegistryAdapter:
	extends RefCounted

	var module_getter: Callable = Callable()

	func _init(p_module_getter: Callable = Callable()) -> void:
		module_getter = p_module_getter

	func get_instance(key: String) -> Object:
		if not module_getter.is_valid():
			return null
		var value: Variant = module_getter.call(key)
		if value is Object:
			return value
		return null


func prewarm_battle_resources(owner: Object, module_getter: Callable) -> void:
	if battle_resources_prewarmed:
		return
	while not prewarm_battle_texture_resources_step(owner, module_getter):
		pass
	while not prewarm_battle_audio_setup_step(owner, module_getter):
		pass
	prime_battle_bgm(owner, module_getter)
	while not finish_battle_resource_prewarm(owner, module_getter):
		pass


func prewarm_battle_core_resources(owner: Object, module_getter: Callable) -> void:
	if battle_core_resources_prewarmed:
		return
	battle_core_resources_prewarmed = true
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_core_textures"):
		resources.prewarm_core_textures(_build_resource_context(owner))


func prewarm_battle_player_resources(owner: Object, module_getter: Callable) -> void:
	if battle_player_resources_prewarmed:
		return
	battle_player_resources_prewarmed = true
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_player_textures"):
		resources.prewarm_player_textures(_build_resource_context(owner))


func prewarm_battle_boss_resources(owner: Object, module_getter: Callable) -> void:
	if battle_boss_resources_prewarmed:
		return
	battle_boss_resources_prewarmed = true
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_boss_textures"):
		resources.prewarm_boss_textures(_build_resource_context(owner))


func prewarm_battle_smasher_skill_icons(owner: Object, module_getter: Callable) -> void:
	if battle_smasher_skill_icons_prewarmed:
		return
	battle_smasher_skill_icons_prewarmed = true
	if _get_selected_character_type(owner) != "smasher":
		return
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_smasher_skill_icons"):
		resources.prewarm_smasher_skill_icons()


func prewarm_battle_viper_skill_icons(owner: Object, module_getter: Callable) -> void:
	if battle_viper_skill_icons_prewarmed:
		return
	battle_viper_skill_icons_prewarmed = true
	if _get_selected_character_type(owner) != "viper":
		return
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_viper_skill_icons"):
		resources.prewarm_viper_skill_icons()


func prewarm_battle_commando_skill_icons(owner: Object, module_getter: Callable) -> void:
	if battle_commando_skill_icons_prewarmed:
		return
	battle_commando_skill_icons_prewarmed = true
	if _get_selected_character_type(owner) != "soldier":
		return
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("prewarm_commando_skill_icons"):
		resources.prewarm_commando_skill_icons()


func finalize_battle_resource_cache(owner: Object, module_getter: Callable) -> void:
	if battle_resource_cache_finalized:
		return
	if battle_texture_resources_prewarmed:
		battle_resource_cache_finalized = true
		return
	battle_resource_cache_finalized = true
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("load_all"):
		var textures: Variant = resources.load_all(_build_boot_transition_texture_context(owner))
		if textures is Dictionary:
			_sync_owner_battle_texture_cache(owner, textures)
	_mark_battle_texture_resources_prewarmed()


func prewarm_battle_texture_resources_step(owner: Object, module_getter: Callable) -> bool:
	if battle_texture_resources_prewarmed:
		return true
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources == null:
		_mark_battle_texture_resources_prewarmed()
		return true

	var context := _build_boot_transition_texture_context(owner)
	var textures: Variant = {}
	if resources.has_method("prewarm_transition_textures_step"):
		if not bool(resources.prewarm_transition_textures_step(context)):
			return false
		if resources.has_method("get_resource_cache"):
			textures = resources.get_resource_cache()
		elif resources.has_method("load_all"):
			textures = resources.load_all(context)
	elif resources.has_method("load_all"):
		textures = resources.load_all(context)

	if textures is Dictionary:
		_sync_owner_battle_texture_cache(owner, textures)
	_mark_battle_texture_resources_prewarmed()
	return true


func prewarm_battle_audio_setup_step(owner: Object, module_getter: Callable) -> bool:
	if battle_audio_setup_finished:
		return true
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio == null:
		battle_audio_setup_finished = true
		return true
	if audio.has_method("setup_step"):
		battle_audio_setup_finished = bool(audio.setup_step(owner))
	elif audio.has_method("setup"):
		audio.setup(owner)
		battle_audio_setup_finished = true
	else:
		battle_audio_setup_finished = true
	return battle_audio_setup_finished


func prime_battle_bgm(owner: Object, module_getter: Callable) -> void:
	if battle_bgm_primed:
		return
	battle_bgm_primed = true
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio != null and audio.has_method("prime_stage_bgm"):
		audio.prime_stage_bgm(_get_current_stage(owner))


func finish_battle_resource_prewarm(owner: Object, module_getter: Callable) -> bool:
	if battle_resources_prewarmed:
		return true
	if _get_current_stage(owner) == 1:
		if not prewarm_stage1_pillar_background_step(module_getter):
			return false
	battle_resources_prewarmed = true
	return true


func prewarm_stage1_pillar_background(module_getter: Callable) -> void:
	while not prewarm_stage1_pillar_background_step(module_getter):
		pass


func prewarm_stage1_pillar_background_step(module_getter: Callable) -> bool:
	if battle_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage1_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets_step"):
		if not bool(stage_background.prewarm_assets_step()):
			return false
	elif stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	battle_pillar_background_prewarmed = true
	return true


func prewarm_stage_intro_resources(owner: Object, module_getter: Callable) -> void:
	while not prewarm_stage_intro_resources_step(owner, module_getter):
		pass


func prewarm_stage_intro_resources_step(owner: Object, module_getter: Callable) -> bool:
	if stage_intro_resources_prewarmed:
		return true
	match stage_intro_resources_prewarm_step_index:
		0:
			var current_stage: int = _get_current_stage(owner)
			var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
			if landing_intro != null and landing_intro.has_method("prewarm_assets_step"):
				if not bool(landing_intro.prewarm_assets_step(current_stage)):
					return false
			elif landing_intro != null and landing_intro.has_method("prewarm_assets"):
				landing_intro.prewarm_assets(current_stage)
		1:
			var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
			if ball_spawn_intro != null and ball_spawn_intro.has_method("prewarm_assets_step"):
				if not bool(ball_spawn_intro.prewarm_assets_step()):
					return false
			elif ball_spawn_intro != null and ball_spawn_intro.has_method("prewarm_assets"):
				ball_spawn_intro.prewarm_assets()
		_:
			stage_intro_resources_prewarmed = true
			stage_intro_resources_prewarm_step_index = 0
			return true
	stage_intro_resources_prewarm_step_index += 1
	return false


func prewarm_stage_runtime_resources(owner: Object, module_getter: Callable) -> void:
	while not prewarm_stage_runtime_resources_step(owner, module_getter, false):
		pass
	_attach_battle_pso_prewarmer(owner)


func get_stage_runtime_prewarm_debug_label(owner: Object) -> String:
	var current_stage: int = _get_current_stage(owner)
	var step_index := stage_runtime_prewarm_step_index
	var step_label := _get_stage_runtime_prewarm_step_label(owner, current_stage, step_index)
	var label := "%02d_%s" % [step_index, step_label]
	if step_label == "selected_character":
		var character_type := _get_selected_character_type(owner)
		label += ".%s" % _get_selected_character_runtime_prewarm_debug_label(character_type)
	return label


func prewarm_stage_runtime_resources_step(owner: Object, module_getter: Callable, wait_for_frame_gated_pso: bool = true) -> bool:
	var current_stage: int = _get_current_stage(owner)
	if stage_runtime_resources_prewarmed_for_stage == current_stage:
		return true
	if stage_runtime_prewarm_step_stage != current_stage:
		stage_runtime_prewarm_step_stage = current_stage
		stage_runtime_prewarm_step_index = 0
	var total_steps := (
		STAGE_RUNTIME_PREWARM_COMMON_STEP_COUNT
		+ _get_stage_specific_runtime_prewarm_step_count(owner, current_stage)
		+ (1 if wait_for_frame_gated_pso else 0)
	)
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	_request_threaded_module_script(module_getter, CHARACTER_INFO_OVERLAY_MODULE_KEY)
	var prewarm_step_index := stage_runtime_prewarm_step_index
	var sample_start: int = _perf_begin(perf_logger)
	var step_complete := _run_stage_runtime_prewarm_step(owner, module_getter, current_stage, stage_runtime_prewarm_step_index, perf_logger)
	var step_label := _get_stage_runtime_prewarm_step_label(owner, current_stage, prewarm_step_index)
	_perf_end(
		perf_logger,
		"process.frame.stage_runtime_prewarm.step.%d.%s" % [prewarm_step_index, step_label],
		sample_start
	)
	if not step_complete:
		return false
	stage_runtime_prewarm_step_index += 1
	if stage_runtime_prewarm_step_index >= total_steps:
		stage_runtime_resources_prewarmed_for_stage = current_stage
		stage_runtime_prewarm_step_stage = 0
		stage_runtime_prewarm_step_index = 0
		return true
	return false


func _run_stage_runtime_prewarm_step(
	owner: Object,
	module_getter: Callable,
	current_stage: int,
	step_index: int,
	perf_logger: Object = null
) -> bool:
	match step_index:
		0:
			var weather_renderer: Object = _get_module(module_getter, "weather_event_renderer")
			if weather_renderer != null and weather_renderer.has_method("prewarm_assets_step"):
				return bool(weather_renderer.prewarm_assets_step())
			if weather_renderer != null and weather_renderer.has_method("prewarm_assets"):
				weather_renderer.prewarm_assets()
		1:
			return prewarm_active_item_runtime_resources_step(module_getter)
		2:
			return prewarm_mythic_acquisition_cinematic_resources_step(owner, module_getter)
		3:
			return prewarm_runtime_perk_overlay_resources_step(owner, module_getter)
		4:
			mark_runtime_perk_debug_assets_deferred()
		5:
			return prewarm_character_info_resources_step(
				owner,
				module_getter,
				perf_logger,
				"process.frame.stage_runtime_prewarm.step.%d.character_info_prewarm" % step_index
			)
		6:
			return prewarm_selected_character_runtime_resources_step(owner, module_getter)
		7:
			return prewarm_ball_update_runtime_resources_step(owner, module_getter)
		8:
			mark_stage_clear_result_shell_deferred()
		9:
			var lingpet_runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
			if lingpet_runtime != null and lingpet_runtime.has_method("prewarm_assets"):
				lingpet_runtime.prewarm_assets()
			var overflow_choice_host: Object = _get_module(module_getter, "lingpet_overflow_choice_overlay_host")
			if overflow_choice_host != null and overflow_choice_host.has_method("prewarm_assets"):
				overflow_choice_host.prewarm_assets()
		10:
			# Lingpet rail card art (the hatched companion's skill card rides every
			# stage's boss skill rail, so warm it once here rather than lazy-loading
			# in any stage's HUD draw hot path).
			return bool(LingpetRailCard.prewarm_step())
		_:
			var stage_step := step_index - STAGE_RUNTIME_PREWARM_COMMON_STEP_COUNT
			var stage_step_count := _get_stage_specific_runtime_prewarm_step_count(owner, current_stage)
			if stage_step < stage_step_count:
				return _run_stage_specific_runtime_prewarm_step(owner, module_getter, current_stage, stage_step)
			else:
				return _run_battle_pso_prewarmer_step(owner)
	return true


func _get_stage_specific_runtime_prewarm_step_count(_owner: Object, current_stage: int) -> int:
	match current_stage:
		1:
			return 6
		2:
			return STAGE2_RUNTIME_PREWARM_LABELS.size()
		3:
			return 3
		4:
			return 3 + STAGE4_RUNTIME_PREWARM_MODULE_KEYS.size()
		5:
			return 1 + STAGE5_RUNTIME_PREWARM_MODULE_KEYS.size()
		6:
			return 1 + STAGE6_RUNTIME_PREWARM_MODULE_KEYS.size()
		7:
			# 프리배틀 영상 스텝(0번, 최우선 — 스레드 VideoStream+숨은 호스트가
			# 다른 렌더 프리웜과 병행 진행되도록 가장 먼저 시작) + 렌더 4스텝.
			return 5
	return 0


func _get_stage_runtime_prewarm_step_label(owner: Object, current_stage: int, step_index: int) -> String:
	if step_index >= 0 and step_index < STAGE_RUNTIME_PREWARM_COMMON_LABELS.size():
		return str(STAGE_RUNTIME_PREWARM_COMMON_LABELS[step_index])
	var stage_step := step_index - STAGE_RUNTIME_PREWARM_COMMON_STEP_COUNT
	var stage_step_count := _get_stage_specific_runtime_prewarm_step_count(owner, current_stage)
	if stage_step >= stage_step_count:
		return "pso_prewarmer"
	match current_stage:
		1:
			return _get_stage1_runtime_prewarm_step_label(stage_step)
		2:
			if stage_step >= 0 and stage_step < STAGE2_RUNTIME_PREWARM_LABELS.size():
				return str(STAGE2_RUNTIME_PREWARM_LABELS[stage_step])
		3:
			return _get_stage3_runtime_prewarm_step_label(stage_step)
		4:
			return _get_stage4_runtime_prewarm_step_label(stage_step)
		5:
			return _get_stage5_runtime_prewarm_step_label(stage_step)
		6:
			return _get_stage6_runtime_prewarm_step_label(stage_step)
		7:
			return _get_stage7_runtime_prewarm_step_label(stage_step)
	return "stage%d_step%d" % [current_stage, stage_step]


func _get_stage1_runtime_prewarm_step_label(stage_step: int) -> String:
	match stage_step:
		0:
			return "stage1_pillar_background"
		1:
			return "stage1_pillar_scene"
		2:
			return "stage1_balloon"
		3:
			return "stage1_skill_hud"
		4:
			return "stage1_commando"
		5:
			return "stage1_actor_renderer"
	return "stage1_step%d" % stage_step


func _get_stage3_runtime_prewarm_step_label(stage_step: int) -> String:
	match stage_step:
		0:
			return "stage3_pillar_background"
		1:
			return "stage3_playfield"
		2:
			return "stage3_skill_hud"
	return "stage3_step%d" % stage_step


func _get_stage4_runtime_prewarm_step_label(stage_step: int) -> String:
	match stage_step:
		0:
			return "stage4_pillar_background"
		1:
			return "stage4_playfield"
		2:
			return "stage4_actor_runtime"
	var module_index := stage_step - 3
	if module_index >= 0 and module_index < STAGE4_RUNTIME_PREWARM_MODULE_KEYS.size():
		return str(STAGE4_RUNTIME_PREWARM_MODULE_KEYS[module_index])
	return "stage4_step%d" % stage_step


func _get_stage5_runtime_prewarm_step_label(stage_step: int) -> String:
	if stage_step == 0:
		return "stage5_pillar_background"
	var module_index := stage_step - 1
	if module_index >= 0 and module_index < STAGE5_RUNTIME_PREWARM_MODULE_KEYS.size():
		return str(STAGE5_RUNTIME_PREWARM_MODULE_KEYS[module_index])
	return "stage5_step%d" % stage_step


func _get_stage6_runtime_prewarm_step_label(stage_step: int) -> String:
	if stage_step == 0:
		return "stage6_pillar_background"
	var module_index := stage_step - 1
	if module_index >= 0 and module_index < STAGE6_RUNTIME_PREWARM_MODULE_KEYS.size():
		return str(STAGE6_RUNTIME_PREWARM_MODULE_KEYS[module_index])
	return "stage6_step%d" % stage_step


func _run_stage_specific_runtime_prewarm_step(
	owner: Object,
	module_getter: Callable,
	current_stage: int,
	stage_step: int
) -> bool:
	match current_stage:
		1:
			return _run_stage1_runtime_prewarm_step(owner, module_getter, stage_step)
		2:
			return _run_stage2_runtime_prewarm_step(owner, module_getter, stage_step)
		3:
			return _run_stage3_runtime_prewarm_step(module_getter, stage_step)
		4:
			return _run_stage4_runtime_prewarm_step(owner, module_getter, stage_step)
		5:
			return _run_stage5_runtime_prewarm_step(owner, module_getter, stage_step)
		6:
			return _run_stage6_runtime_prewarm_step(owner, module_getter, stage_step)
		7:
			return _run_stage7_runtime_prewarm_step(owner, module_getter, stage_step)
	return true


func _run_stage1_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			return prewarm_stage1_pillar_background_step(module_getter)
		1:
			var pillar_scene_drawer: Object = _get_module(module_getter, "stage1_pillar_scene_drawer")
			if pillar_scene_drawer != null and pillar_scene_drawer.has_method("prewarm_assets_step"):
				return bool(pillar_scene_drawer.prewarm_assets_step(
					module_getter,
					_get_selected_character_type(owner),
					_get_stage1_boss_variant(owner)
				))
			if pillar_scene_drawer != null and pillar_scene_drawer.has_method("prewarm_assets"):
				pillar_scene_drawer.prewarm_assets(
					module_getter,
					_get_selected_character_type(owner),
					_get_stage1_boss_variant(owner)
				)
		2:
			var balloon_event: Object = _get_module(module_getter, "stage1_balloon_event")
			if balloon_event != null and balloon_event.has_method("prewarm_assets_step"):
				return bool(balloon_event.prewarm_assets_step())
			if balloon_event != null and balloon_event.has_method("prewarm_assets"):
				balloon_event.prewarm_assets()
		3:
			var skill_hud_key := _get_stage1_boss_skill_hud_key(_get_stage1_boss_variant(owner))
			if skill_hud_key == "":
				return true
			var skill_hud: Object = _get_module(module_getter, skill_hud_key)
			if skill_hud != null and skill_hud.has_method("prewarm_assets_step"):
				return bool(skill_hud.prewarm_assets_step())
			if skill_hud != null and skill_hud.has_method("prewarm_assets"):
				skill_hud.prewarm_assets()
		4:
			if _get_selected_character_type(owner) != "soldier":
				return true
			var firearm_selector: Object = _get_module(module_getter, "commando_firearm_selector_renderer")
			if firearm_selector != null and firearm_selector.has_method("prewarm_assets_step"):
				if not bool(firearm_selector.prewarm_assets_step()):
					return false
			elif firearm_selector != null and firearm_selector.has_method("prewarm_assets"):
				firearm_selector.prewarm_assets()
		5:
			var actor_renderer: Object = _get_module(module_getter, "stage1_actor_renderer")
			if actor_renderer != null and actor_renderer.has_method("prewarm_assets_step"):
				if not bool(actor_renderer.prewarm_assets_step()):
					return false
			elif actor_renderer != null and actor_renderer.has_method("prewarm_assets"):
				actor_renderer.prewarm_assets()
	return true


func _run_stage2_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			return prewarm_stage2_pillar_background_step(module_getter)
		1:
			var pillar_scene_drawer: Object = _get_module(module_getter, "stage2_pillar_scene_drawer")
			return _prewarm_pillar_scene_assets_step(pillar_scene_drawer, module_getter, _get_selected_character_type(owner))
		2:
			return prewarm_stage2_playfield_resources_step(module_getter)
		3:
			var skill_hud: Object = _get_module(module_getter, "stage2_boss_skill_hud_renderer")
			return _prewarm_module_assets_step(skill_hud)
		4:
			var monkey_event: Object = _get_module(module_getter, "stage2_monkey_banana_event")
			return _prewarm_module_assets_step(monkey_event)
	return true


func _run_stage3_runtime_prewarm_step(module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			return prewarm_stage3_pillar_background_step(module_getter)
		1:
			return prewarm_stage3_playfield_resources_step(module_getter)
		2:
			var skill_hud: Object = _get_module(module_getter, "stage3_boss_skill_hud_renderer")
			if skill_hud != null and skill_hud.has_method("prewarm_assets"):
				skill_hud.prewarm_assets()
	return true


func _run_stage4_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	if stage_step == 0:
		return prewarm_stage4_pillar_background_step(module_getter)
	if stage_step == 1:
		return prewarm_stage4_playfield_resources_step(module_getter)
	if stage_step == 2:
		return prewarm_stage4_actor_runtime_nodes_step(owner, module_getter)
	var module_index := stage_step - 3
	if module_index < 0 or module_index >= STAGE4_RUNTIME_PREWARM_MODULE_KEYS.size():
		return true
	var module: Object = _get_module(module_getter, STAGE4_RUNTIME_PREWARM_MODULE_KEYS[module_index])
	return _prewarm_module_assets_step(module)


func _run_stage5_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			return prewarm_stage5_pillar_background_step(module_getter)
		_:
			var module_index := stage_step - 1
			if module_index < 0 or module_index >= STAGE5_RUNTIME_PREWARM_MODULE_KEYS.size():
				return true
			var module_key := str(STAGE5_RUNTIME_PREWARM_MODULE_KEYS[module_index])
			var module: Object = _get_module(module_getter, STAGE5_RUNTIME_PREWARM_MODULE_KEYS[module_index])
			if module_key == "stage5_hongryun_pillar_scene_drawer":
				return _prewarm_pillar_scene_assets_step(module, module_getter, _get_selected_character_type(owner))
			return _prewarm_module_assets_step(module)


func _run_stage6_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			return prewarm_stage6_pillar_background_step(module_getter)
		_:
			var module_index := stage_step - 1
			if module_index < 0 or module_index >= STAGE6_RUNTIME_PREWARM_MODULE_KEYS.size():
				return true
			var module_key := str(STAGE6_RUNTIME_PREWARM_MODULE_KEYS[module_index])
			var module: Object = _get_module(module_getter, STAGE6_RUNTIME_PREWARM_MODULE_KEYS[module_index])
			if module_key == "stage6_tetriser_pillar_scene_drawer":
				return _prewarm_pillar_scene_assets_step(module, module_getter, _get_selected_character_type(owner))
			return _prewarm_module_assets_step(module)


const STAGE7_RUNTIME_PREWARM_STEP_LABELS := [
	"stage7_akamu_prebattle_video",
	"stage7_akamu_pillar_background",
	"stage7_akamu_actor_renderer",
	"stage7_akamu_pillar_scene",
	"stage7_akamu_skill_hud",
]


func _get_stage7_runtime_prewarm_step_label(stage_step: int) -> String:
	if stage_step >= 0 and stage_step < STAGE7_RUNTIME_PREWARM_STEP_LABELS.size():
		return str(STAGE7_RUNTIME_PREWARM_STEP_LABELS[stage_step])
	return "stage7_step%d" % stage_step


func _run_stage7_runtime_prewarm_step(owner: Object, module_getter: Callable, stage_step: int) -> bool:
	match stage_step:
		0:
			# 프리배틀 영상: 스레드 VideoStream 로드 + 숨은 호스트 생성.
			# 로드 실패는 presentation 내부에서 이번 엔트리 한정 degradation으로
			# 래치되므로(재시도 스톰 없음) 스텝 자체는 완료로 취급된다.
			var prebattle: Object = _get_module(module_getter, "stage7_akamu_prebattle_presentation")
			if prebattle == null or not prebattle.has_method("prewarm_stage_entry_step"):
				return true
			return bool(prebattle.prewarm_stage_entry_step(owner))
		1:
			return _prewarm_module_assets_step(_get_module(module_getter, "stage7_akamu_pillar_background"))
		2:
			return _prewarm_module_assets_step(_get_module(module_getter, "stage7_akamu_actor_renderer"))
		3:
			return _prewarm_pillar_scene_assets_step(
				_get_module(module_getter, "stage7_akamu_pillar_scene_drawer"),
				module_getter,
				_get_selected_character_type(owner)
			)
		4:
			return _prewarm_module_assets_step(_get_module(module_getter, "stage7_akamu_boss_skill_hud_renderer"))
	return true


# Attach a hidden offscreen Node2D once per stage so Vulkan / GPU
# compiles the textured-quad PSOs that the air-strike, hover sheet, and
# pillar HUD paths use before the first real-gameplay frame touches them.
# The prewarmer self-destructs after its staged draw passes, so attaching
# once per stage gives stage-specific pillar atlases a chance to issue their
# first texture draws during loading instead of the first visible battle frame.
func _attach_battle_pso_prewarmer(owner: Object) -> void:
	var stage_id: int = max(1, _get_current_stage(owner))
	if bool(battle_pso_prewarmer_stage_ids.get(stage_id, false)):
		return
	if owner == null or not (owner is Node) or not (owner as Node).is_inside_tree():
		return
	battle_pso_prewarmer_attached = true
	battle_pso_prewarmer_stage_ids[stage_id] = true
	var prewarmer := BattlePsoPrewarmer.new()
	prewarmer.name = "BattlePsoPrewarmer"
	(owner as Node).add_child(prewarmer)


func _run_battle_pso_prewarmer_step(owner: Object) -> bool:
	var stage_id: int = max(1, _get_current_stage(owner))
	if owner == null or not (owner is Node) or not (owner as Node).is_inside_tree():
		return true
	var owner_node := owner as Node
	var existing := owner_node.get_node_or_null("BattlePsoPrewarmer")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		return false
	if bool(battle_pso_prewarmer_stage_ids.get(stage_id, false)):
		return true
	_attach_battle_pso_prewarmer(owner)
	existing = owner_node.get_node_or_null("BattlePsoPrewarmer")
	return existing == null or not is_instance_valid(existing) or existing.is_queued_for_deletion()


func prewarm_stage2_runtime_resources(module_getter: Callable) -> void:
	prewarm_stage2_pillar_background(module_getter)
	var pillar_scene_drawer: Object = _get_module(module_getter, "stage2_pillar_scene_drawer")
	while not _prewarm_pillar_scene_assets_step(pillar_scene_drawer, module_getter, "smasher"):
		pass
	prewarm_stage2_playfield_resources(module_getter)
	var skill_hud: Object = _get_module(module_getter, "stage2_boss_skill_hud_renderer")
	while not _prewarm_module_assets_step(skill_hud):
		pass
	var monkey_event: Object = _get_module(module_getter, "stage2_monkey_banana_event")
	while not _prewarm_module_assets_step(monkey_event):
		pass


func prewarm_stage2_pillar_background(module_getter: Callable) -> void:
	while not prewarm_stage2_pillar_background_step(module_getter):
		pass


func prewarm_stage2_pillar_background_step(module_getter: Callable) -> bool:
	if battle_stage2_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage2_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets_step"):
		if not bool(stage_background.prewarm_assets_step()):
			return false
	elif stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	battle_stage2_pillar_background_prewarmed = true
	return true


func prewarm_stage2_playfield_resources(module_getter: Callable) -> void:
	while not prewarm_stage2_playfield_resources_step(module_getter):
		pass


func prewarm_stage2_playfield_resources_step(module_getter: Callable) -> bool:
	if battle_stage2_playfield_resources_prewarmed:
		return true
	var actor_renderer: Object = _get_module(module_getter, "stage2_actor_renderer")
	if actor_renderer != null:
		if actor_renderer.has_method("prewarm_assets_step"):
			if not bool(actor_renderer.prewarm_assets_step()):
				return false
		elif actor_renderer.has_method("prewarm_assets"):
			actor_renderer.prewarm_assets()
	battle_stage2_playfield_resources_prewarmed = true
	return true


func prewarm_stage3_runtime_resources(module_getter: Callable) -> void:
	prewarm_stage3_pillar_background(module_getter)
	prewarm_stage3_playfield_resources(module_getter)
	var skill_hud: Object = _get_module(module_getter, "stage3_boss_skill_hud_renderer")
	if skill_hud != null and skill_hud.has_method("prewarm_assets"):
		skill_hud.prewarm_assets()


func prewarm_stage3_pillar_background(module_getter: Callable) -> void:
	while not prewarm_stage3_pillar_background_step(module_getter):
		pass


func prewarm_stage3_pillar_background_step(module_getter: Callable) -> bool:
	if battle_stage3_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage3_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets_step"):
		if not bool(stage_background.prewarm_assets_step()):
			return false
	elif stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	battle_stage3_pillar_background_prewarmed = true
	return true


func prewarm_stage3_playfield_resources(module_getter: Callable) -> void:
	while not prewarm_stage3_playfield_resources_step(module_getter):
		pass


func prewarm_stage3_playfield_resources_step(module_getter: Callable) -> bool:
	if battle_stage3_playfield_resources_prewarmed:
		return true
	var actor_renderer: Object = _get_module(module_getter, "stage3_actor_renderer")
	if actor_renderer != null:
		if actor_renderer.has_method("prewarm_assets_step"):
			if not bool(actor_renderer.prewarm_assets_step()):
				return false
		elif actor_renderer.has_method("prewarm_assets"):
			actor_renderer.prewarm_assets()
	battle_stage3_playfield_resources_prewarmed = true
	return true


func prewarm_stage4_runtime_resources(module_getter: Callable) -> void:
	prewarm_stage4_pillar_background(module_getter)
	prewarm_stage4_playfield_resources(module_getter)
	for key in [
		"stage4_ponk_gauge_hud_renderer",
		"stage4_bird_event",
		"stage4_brazier_monk_event",
		"stage4_moon_event",
		"stage4_ponk_skill_state",
		"stage4_ponk_boss_skill_hud_renderer",
	]:
		var module: Object = _get_module(module_getter, key)
		while not _prewarm_module_assets_step(module):
			pass


func prewarm_stage4_pillar_background(module_getter: Callable) -> void:
	while not prewarm_stage4_pillar_background_step(module_getter):
		pass


func prewarm_stage4_pillar_background_step(module_getter: Callable) -> bool:
	if battle_stage4_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage4_pillar_background")
	if stage_background != null and stage_background.has_method("prewarm_assets_step"):
		if not bool(stage_background.prewarm_assets_step()):
			return false
	elif stage_background != null and stage_background.has_method("prewarm_assets"):
		stage_background.prewarm_assets()
	battle_stage4_pillar_background_prewarmed = true
	return true


func prewarm_stage5_pillar_background(module_getter: Callable) -> void:
	while not prewarm_stage5_pillar_background_step(module_getter):
		pass


func prewarm_stage5_pillar_background_step(module_getter: Callable) -> bool:
	if battle_stage5_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage5_hongryun_pillar_background")
	if not _prewarm_module_assets_step(stage_background):
		return false
	battle_stage5_pillar_background_prewarmed = true
	return true


func prewarm_stage6_pillar_background_step(module_getter: Callable) -> bool:
	if battle_stage6_pillar_background_prewarmed:
		return true
	var stage_background: Object = _get_module(module_getter, "stage6_tetriser_pillar_background")
	if not _prewarm_module_assets_step(stage_background):
		return false
	battle_stage6_pillar_background_prewarmed = true
	return true


func _prewarm_pillar_scene_assets_step(
	module: Object,
	module_getter: Callable,
	selected_character_type: String
) -> bool:
	if module == null:
		return true
	if module.has_method("prewarm_assets_step"):
		return bool(module.prewarm_assets_step(module_getter, selected_character_type))
	if module.has_method("prewarm_assets"):
		module.prewarm_assets(module_getter, selected_character_type)
	return true


func prewarm_stage4_playfield_resources(module_getter: Callable) -> void:
	while not prewarm_stage4_playfield_resources_step(module_getter):
		pass


func prewarm_stage4_playfield_resources_step(module_getter: Callable) -> bool:
	if battle_stage4_playfield_resources_prewarmed:
		return true
	var actor_renderer: Object = _get_module(module_getter, "stage4_actor_renderer")
	if not _prewarm_module_assets_step(actor_renderer):
		return false
	battle_stage4_playfield_resources_prewarmed = true
	return true


func prewarm_stage4_actor_runtime_nodes_step(owner: Object, module_getter: Callable) -> bool:
	var actor_renderer: Object = _get_module(module_getter, "stage4_actor_renderer")
	if actor_renderer == null:
		return true
	if actor_renderer.has_method("prewarm_runtime_nodes_step"):
		return bool(actor_renderer.prewarm_runtime_nodes_step(owner))
	if actor_renderer.has_method("prewarm_runtime_nodes"):
		actor_renderer.prewarm_runtime_nodes(owner)
	return true


func _prewarm_module_assets_step(module: Object) -> bool:
	if module == null:
		return true
	if module.has_method("prewarm_assets_step"):
		return bool(module.prewarm_assets_step())
	if module.has_method("prewarm_assets"):
		module.prewarm_assets()
	return true


func prewarm_active_item_runtime_resources(module_getter: Callable) -> void:
	while not prewarm_active_item_runtime_resources_step(module_getter):
		pass


func prewarm_active_item_runtime_resources_step(module_getter: Callable) -> bool:
	if battle_active_item_runtime_prewarmed:
		return true
	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	var active_item_hud_visuals: Object = _get_module(module_getter, "active_item_hud_visuals")
	if active_item_runtime != null and active_item_runtime.has_method("prewarm_assets_step"):
		if not bool(active_item_runtime.prewarm_assets_step(active_item_hud_visuals)):
			return false
	elif active_item_runtime != null and active_item_runtime.has_method("prewarm_assets"):
		active_item_runtime.prewarm_assets(active_item_hud_visuals)
	elif active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons_step"):
		if not bool(active_item_hud_visuals.prewarm_catalog_icons_step()):
			return false
	elif active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons"):
		active_item_hud_visuals.prewarm_catalog_icons()
	battle_active_item_runtime_prewarmed = true
	return true


func prewarm_mythic_item_runtime_resources(module_getter: Callable) -> void:
	if battle_mythic_item_runtime_prewarmed:
		return
	battle_mythic_item_runtime_prewarmed = true
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_assets"):
		mythic_item_runtime.prewarm_assets()


func prewarm_mythic_acquisition_cinematic_resources(owner: Object, module_getter: Callable) -> void:
	while not prewarm_mythic_acquisition_cinematic_resources_step(owner, module_getter):
		pass


func prewarm_mythic_acquisition_cinematic_resources_step(owner: Object, module_getter: Callable) -> bool:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_acquisition_cinematic_assets_step"):
		if not bool(mythic_item_runtime.prewarm_acquisition_cinematic_assets_step()):
			return false
	elif mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_acquisition_cinematic_assets"):
		mythic_item_runtime.prewarm_acquisition_cinematic_assets()
	elif mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_acquisition_cinematic"):
		mythic_item_runtime.prewarm_acquisition_cinematic(owner)
	mark_mythic_item_runtime_assets_deferred()
	return true


func mark_mythic_item_runtime_assets_deferred() -> void:
	battle_mythic_item_runtime_prewarmed = true


func prewarm_selected_character_runtime_resources(owner: Object, module_getter: Callable) -> void:
	while not prewarm_selected_character_runtime_resources_step(owner, module_getter):
		pass


func prewarm_selected_character_runtime_resources_step(owner: Object, module_getter: Callable) -> bool:
	var character_type := _get_selected_character_type(owner)
	if battle_selected_character_runtime_prewarmed and battle_selected_character_runtime_prewarmed_for == character_type:
		return true
	if selected_character_runtime_prewarm_step_character != character_type:
		selected_character_runtime_prewarm_step_character = character_type
		selected_character_runtime_prewarm_step_index = 0
	var module_keys: Array[String] = _get_selected_character_runtime_module_keys(character_type)
	if module_keys.is_empty():
		_mark_selected_character_runtime_prewarmed(character_type)
		return true
	if selected_character_runtime_prewarm_step_index >= module_keys.size():
		_mark_selected_character_runtime_prewarmed(character_type)
		return true
	var module_key := module_keys[selected_character_runtime_prewarm_step_index]
	var module_index := selected_character_runtime_prewarm_step_index
	var module_label := "%02d_%s" % [module_index, module_key]
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var lookup_start: int = _perf_begin(perf_logger)
	var module: Object = _get_module(module_getter, module_key)
	_perf_end(
		perf_logger,
		"process.frame.stage_runtime_prewarm.selected_character.%s.lookup" % module_label,
		lookup_start
	)
	var assets_start: int = _perf_begin(perf_logger)
	var assets_complete := _prewarm_selected_character_module_assets_step(module, character_type)
	_perf_end(
		perf_logger,
		"process.frame.stage_runtime_prewarm.selected_character.%s.assets" % module_label,
		assets_start
	)
	if not assets_complete:
		_perf_end(
			perf_logger,
			"process.frame.stage_runtime_prewarm.selected_character.%s.total" % module_label,
			total_start
		)
		return false
	var runtime_start: int = _perf_begin(perf_logger)
	var runtime_nodes_complete := _prewarm_selected_character_runtime_nodes_step(owner, module)
	_perf_end(
		perf_logger,
		"process.frame.stage_runtime_prewarm.selected_character.%s.runtime_nodes" % module_label,
		runtime_start
	)
	if not runtime_nodes_complete:
		_perf_end(
			perf_logger,
			"process.frame.stage_runtime_prewarm.selected_character.%s.total" % module_label,
			total_start
		)
		return false
	_perf_end(
		perf_logger,
		"process.frame.stage_runtime_prewarm.selected_character.%s.total" % module_label,
		total_start
	)
	selected_character_runtime_prewarm_step_index += 1
	if selected_character_runtime_prewarm_step_index >= module_keys.size():
		_mark_selected_character_runtime_prewarmed(character_type)
		return true
	return false


func _prewarm_selected_character_module_assets_step(module: Object, character_type: String) -> bool:
	if module == null:
		return true
	if module.has_method("prewarm_assets_for_character_step"):
		return bool(module.prewarm_assets_for_character_step(character_type))
	if module.has_method("prewarm_assets_for_character"):
		module.prewarm_assets_for_character(character_type)
		return true
	return _prewarm_module_assets_step(module)


func _prewarm_selected_character_runtime_nodes_step(owner: Object, module: Object) -> bool:
	if module == null:
		return true
	if module.has_method("prewarm_runtime_nodes_step"):
		return bool(module.prewarm_runtime_nodes_step(owner))
	if module.has_method("prewarm_runtime_nodes"):
		module.prewarm_runtime_nodes(owner)
	return true


func _get_selected_character_runtime_prewarm_debug_label(character_type: String) -> String:
	var debug_character := character_type
	if selected_character_runtime_prewarm_step_character != "":
		debug_character = selected_character_runtime_prewarm_step_character
	var module_keys: Array[String] = _get_selected_character_runtime_module_keys(debug_character)
	var module_index := selected_character_runtime_prewarm_step_index
	if module_index < 0:
		return "%s.unknown" % debug_character
	if module_index >= module_keys.size():
		return "%s.done" % debug_character
	return "%s.%02d_%s" % [debug_character, module_index, module_keys[module_index]]


func _mark_selected_character_runtime_prewarmed(character_type: String) -> void:
	battle_selected_character_runtime_prewarmed = true
	battle_selected_character_runtime_prewarmed_for = character_type
	selected_character_runtime_prewarm_step_character = ""
	selected_character_runtime_prewarm_step_index = 0


func _get_selected_character_runtime_module_keys(character_type: String) -> Array[String]:
	var keys: Array[String] = [
		"monkey_blessing_delivery_state",
		"commando_reload_delivery_state",
	]
	match character_type:
		"smasher":
			keys.append_array([
				"smasher_input_reader",
				"smasher_power_smash_state",
				"skill_cutin_overlay_host",
				"lingpet_acquire_cutin_overlay_host",
				"smasher_drive_input_state",
				"smasher_combo_state",
				"smasher_skill_state",
				"smasher_skill_config",
				"smasher_plasma_state",
				"smasher_drive_bounce_state",
				"smasher_drive_counter_state",
				"smasher_drive_activation_controller",
				"smasher_power_smash_activation_controller",
				"smasher_power_smash_motion_controller",
				"smasher_magnum_grip_state",
				"smasher_recovery_state",
				"smasher_cleanse_state",
				"smasher_warp_gate_state",
				"smasher_wheel_state",
				"smasher_overdrive_state",
				"smasher_dash_spirit_state",
				"smasher_shield_kiting_state",
				"smasher_dash_state",
			])
		"soldier":
			keys.append_array([
				"commando_input_reader",
				"commando_skill_state",
				"commando_skill_config",
				"commando_firearm_runtime",
				"commando_supply_drop_state",
				"commando_weapon_controller",
				"commando_emergency_supply_state",
			])
		"viper":
			keys.append_array([
				"viper_input_reader",
				"viper_skill_runtime",
				"skill_cutin_overlay_host",
				"viper_skill_state",
				"viper_skill_config",
				"viper_jetpack_state",
			])
		"blacksmith":
			keys.append_array([
				"blacksmith_input_reader",
				"blacksmith_player_controller",
				"blacksmith_thor_shield_state",
				"blacksmith_skill_state",
				"blacksmith_skill_config",
				"smasher_dash_state",
			])
	return keys


func prewarm_ball_update_runtime_resources_step(owner: Object, module_getter: Callable) -> bool:
	var ball_renderer: Object = _get_module(module_getter, "ball_renderer")
	if ball_renderer != null and ball_renderer.has_method("prewarm_assets_step"):
		if not bool(ball_renderer.prewarm_assets_step()):
			return false
	elif ball_renderer != null and ball_renderer.has_method("prewarm_assets"):
		ball_renderer.prewarm_assets()
	if ball_renderer != null and ball_renderer.has_method("prewarm_runtime_nodes_step"):
		if not bool(ball_renderer.prewarm_runtime_nodes_step(owner)):
			return false
	elif ball_renderer != null and ball_renderer.has_method("prewarm_runtime_nodes"):
		ball_renderer.prewarm_runtime_nodes(owner)
	var prewarm_driver: Object = _get_module(module_getter, "battle_scene_update_prewarm_driver")
	if prewarm_driver == null:
		return true
	var registry := ModuleGetterRegistryAdapter.new(module_getter)
	if prewarm_driver.has_method("prewarm_ball_update_step"):
		return bool(prewarm_driver.prewarm_ball_update_step(owner, registry))
	if prewarm_driver.has_method("prewarm_ball_update"):
		prewarm_driver.prewarm_ball_update(owner, registry)
	return true


func _prewarm_selected_character_runtime_resources_legacy(owner: Object, module_getter: Callable) -> void:
	if battle_selected_character_runtime_prewarmed:
		return
	battle_selected_character_runtime_prewarmed = true
	var module_keys: Array[String] = []
	match _get_selected_character_type(owner):
		"smasher":
			module_keys = [
				"smasher_warp_gate_state",
				"smasher_wheel_state",
				"smasher_overdrive_state",
				"smasher_shield_kiting_state",
			]
		"soldier":
			module_keys = [
				"commando_supply_drop_state",
			]
		"viper":
			module_keys = [
				"viper_skill_runtime",
			]
	for key in module_keys:
		var module: Object = _get_module(module_getter, key)
		if module != null and module.has_method("prewarm_assets"):
			module.prewarm_assets()


func prewarm_runtime_perk_overlay_resources_step(owner: Object, module_getter: Callable) -> bool:
	if battle_runtime_perk_overlay_prewarmed:
		return true
	var icon_renderer: Object = _get_module(module_getter, "runtime_perk_icon_renderer")
	if icon_renderer != null and icon_renderer.has_method("prewarm_assets_step"):
		if not bool(icon_renderer.prewarm_assets_step()):
			return false
	elif icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()
	var overlay_renderer: Object = _get_module(module_getter, "runtime_perk_overlay_renderer")
	if overlay_renderer != null and overlay_renderer.has_method("prewarm_assets"):
		overlay_renderer.prewarm_assets()
	# 융합 재료쌍 합성 텍스처 프리웜(부트 로딩 프레임 — draw 밖): 세이브
	# 복원으로 이미 융합을 보유한 매치가 첫 표시 프레임에서 합성 히치를
	# 겪지 않게 한다.
	if icon_renderer != null and icon_renderer.has_method("prewarm_fusion_pair_icons_for_state"):
		icon_renderer.prewarm_fusion_pair_icons_for_state(_get_module(module_getter, "runtime_perk_state"))
	# 신비의 주사위 패들 오라 분리형 스크린 호스트: 상태는 바인딩된 호스트만
	# 반환하고 드로어는 조회 전용이라, 여기(부트 로딩 프레임 — draw 밖)서
	# 씬에 부착·바인딩하지 않으면 실게임에서 오라가 렌더되지 않는다.
	# 호스트는 배틀 씬의 자식으로 붙어 씬 해제와 함께 정리된다.
	_ensure_mystic_dice_paddle_fx_host(owner, _get_module(module_getter, "runtime_perk_state"))
	var treasure_hunt_runtime: Object = _get_module(module_getter, "treasure_hunt_runtime")
	if treasure_hunt_runtime != null and treasure_hunt_runtime.has_method("prewarm_assets"):
		treasure_hunt_runtime.prewarm_assets()
	var overlay_frame_controller: Object = _get_module(module_getter, "battle_scene_overlay_frame_controller")
	if (
		overlay_frame_controller != null
		and overlay_frame_controller.has_method("prewarm_angel_blessing_runtime_nodes")
		and not bool(overlay_frame_controller.prewarm_angel_blessing_runtime_nodes(owner))
	):
		return false
	battle_runtime_perk_overlay_prewarmed = true
	return true


# 주사위 패들 오라 호스트 보증: 유효 호스트가 이미 트리 안에 바인딩돼
# 있으면 no-op(중복 부착 금지), 아니면 생성→씬 부착→상태 바인딩. 씬 교체로
# 호스트가 해제된 뒤의 재부트에서는 새 호스트를 다시 붙인다.
func _ensure_mystic_dice_paddle_fx_host(owner: Object, runtime_perk_state: Object) -> void:
	if runtime_perk_state == null or not runtime_perk_state.has_method("bind_mystic_dice_paddle_fx_host"):
		return
	if not (owner is Node):
		return
	if runtime_perk_state.has_method("get_mystic_dice_paddle_fx_host"):
		var bound_host: Node = runtime_perk_state.get_mystic_dice_paddle_fx_host()
		if bound_host != null and is_instance_valid(bound_host) and bound_host.is_inside_tree():
			return
	var host: Node = load("res://scripts/characters/mystic_dice_paddle_fx_host.gd").new()
	(owner as Node).add_child(host)
	runtime_perk_state.bind_mystic_dice_paddle_fx_host(host)


func prewarm_runtime_perk_debug_resources(owner: Object, module_getter: Callable) -> void:
	if battle_runtime_perk_debug_prewarmed:
		return
	battle_runtime_perk_debug_prewarmed = true
	var icon_renderer: Object = _get_module(module_getter, "runtime_perk_icon_renderer")
	var perk_debug_picker: Object = _get_module(module_getter, "runtime_perk_debug_picker")
	var catalog: Object = _get_module(module_getter, "runtime_perk_catalog")
	if perk_debug_picker != null and perk_debug_picker.has_method("prewarm_assets"):
		perk_debug_picker.prewarm_assets(catalog, owner, icon_renderer)
	elif icon_renderer != null and icon_renderer.has_method("prewarm_assets"):
		icon_renderer.prewarm_assets()


func mark_runtime_perk_debug_assets_deferred() -> void:
	battle_runtime_perk_debug_prewarmed = true


func prewarm_character_info_resources(owner: Object, module_getter: Callable) -> void:
	while not prewarm_character_info_resources_step(owner, module_getter):
		pass


func prewarm_character_info_resources_step(
	owner: Object,
	module_getter: Callable,
	perf_logger: Object = null,
	perf_label_prefix: String = "process.frame.character_info_prewarm"
) -> bool:
	var sample_start: int = _perf_begin(perf_logger)
	var script_sample_start: int = _perf_begin(perf_logger)
	_request_threaded_module_script(module_getter, CHARACTER_INFO_OVERLAY_MODULE_KEY)
	if not _is_threaded_module_script_ready(module_getter, CHARACTER_INFO_OVERLAY_MODULE_KEY):
		_perf_end(perf_logger, "%s.resolve_module.script_load" % perf_label_prefix, script_sample_start)
		_perf_end(perf_logger, "%s.resolve_module_wait" % perf_label_prefix, sample_start)
		return false
	_perf_end(perf_logger, "%s.resolve_module.script_load" % perf_label_prefix, script_sample_start)
	var instantiate_sample_start: int = _perf_begin(perf_logger)
	var character_info: Object = _get_module(module_getter, CHARACTER_INFO_OVERLAY_MODULE_KEY)
	_perf_end(perf_logger, "%s.resolve_module.instantiate" % perf_label_prefix, instantiate_sample_start)
	_perf_end(perf_logger, "%s.resolve_module" % perf_label_prefix, sample_start)
	sample_start = _perf_begin(perf_logger)
	var registry_adapter := ModuleGetterRegistryAdapter.new(module_getter)
	var lingpet_prewarm_pet_ids := CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids(owner, registry_adapter, module_getter)
	var lingpet_prewarm_key := _build_lingpet_prewarm_key(lingpet_prewarm_pet_ids)
	battle_character_info_lingpet_prewarm_pet_ids = lingpet_prewarm_pet_ids
	_perf_end(perf_logger, "%s.lingpet_slot_scan.%d" % [perf_label_prefix, lingpet_prewarm_pet_ids.size()], sample_start)
	if battle_character_info_prewarmed:
		if battle_character_info_lingpet_prewarmed_for_key == lingpet_prewarm_key:
			return true
		if lingpet_prewarm_pet_ids.is_empty():
			battle_character_info_lingpet_prewarmed_for_key = lingpet_prewarm_key
			return true
		if character_info != null and character_info.has_method("prewarm_lingpet_panel_assets_step"):
			sample_start = _perf_begin(perf_logger)
			var panel_done := bool(character_info.prewarm_lingpet_panel_assets_step(
				lingpet_prewarm_pet_ids,
				perf_logger,
				"%s.lingpet_panel" % perf_label_prefix
			))
			_perf_end(perf_logger, "%s.lingpet_panel_step" % perf_label_prefix, sample_start)
			if not panel_done:
				return false
		battle_character_info_lingpet_prewarmed_for_key = lingpet_prewarm_key
		return true
	if character_info != null and character_info.has_method("prewarm_assets_step"):
		sample_start = _perf_begin(perf_logger)
		var overlay_done := bool(character_info.prewarm_assets_step(
			owner,
			registry_adapter,
			module_getter,
			true,
			Vector2.ZERO,
			lingpet_prewarm_pet_ids,
			perf_logger,
			"%s.overlay" % perf_label_prefix
		))
		_perf_end(perf_logger, "%s.overlay_step" % perf_label_prefix, sample_start)
		if not overlay_done:
			return false
	elif character_info != null and character_info.has_method("prewarm_assets"):
		sample_start = _perf_begin(perf_logger)
		character_info.prewarm_assets(owner, registry_adapter, module_getter, true, Vector2.ZERO, lingpet_prewarm_pet_ids)
		_perf_end(perf_logger, "%s.overlay_full" % perf_label_prefix, sample_start)
	battle_character_info_prewarmed = true
	battle_character_info_lingpet_prewarmed_for_key = lingpet_prewarm_key
	return true


func _build_lingpet_prewarm_key(pet_ids: Array[String]) -> String:
	return ",".join(pet_ids)


func prewarm_stage_clear_result_resources(module_getter: Callable, owner: Object = null) -> void:
	while not prewarm_stage_clear_result_resources_step(module_getter, owner):
		pass


func prewarm_stage_clear_result_shell_resources(module_getter: Callable) -> void:
	if battle_stage_clear_result_shell_prewarmed:
		return
	battle_stage_clear_result_shell_prewarmed = true
	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("prewarm_scene_shell"):
		result_screen.prewarm_scene_shell()


func prewarm_stage_clear_result_shell_resources_step(module_getter: Callable) -> bool:
	prewarm_stage_clear_result_shell_resources(module_getter)
	return true


func mark_stage_clear_result_shell_deferred() -> void:
	battle_stage_clear_result_shell_prewarmed = true


func has_stage_clear_result_resource_prewarm_work(owner: Object = null) -> bool:
	return (
		not battle_stage_clear_result_prewarmed
		or battle_stage_clear_result_prewarmed_for != _get_stage_clear_result_prewarm_key(owner)
	)


func prewarm_stage_clear_result_resources_step(module_getter: Callable, owner: Object = null) -> bool:
	var result_prewarm_key := _get_stage_clear_result_prewarm_key(owner)
	if battle_stage_clear_result_prewarmed and battle_stage_clear_result_prewarmed_for == result_prewarm_key:
		return true
	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("prewarm_assets_threaded_step"):
		if not bool(result_screen.prewarm_assets_threaded_step(owner)):
			return false
	elif result_screen != null and result_screen.has_method("prewarm_assets_step"):
		if not bool(result_screen.prewarm_assets_step(owner)):
			return false
	elif result_screen != null and result_screen.has_method("prewarm_assets"):
		result_screen.prewarm_assets(owner)
	battle_stage_clear_result_prewarmed = true
	battle_stage_clear_result_prewarmed_for = result_prewarm_key
	return true


func _sync_owner_battle_texture_cache(owner: Object, textures: Dictionary) -> void:
	if owner == null:
		return
	owner.set("battle_textures", textures)
	owner.set("smasher_skill_icon_textures", _get_dictionary(textures.get("smasher_skill_icon_textures", {})))
	owner.set("viper_skill_icon_textures", _get_dictionary(textures.get("viper_skill_icon_textures", {})))
	owner.set("commando_skill_icon_textures", _get_dictionary(textures.get("commando_skill_icon_textures", {})))


func _mark_battle_texture_resources_prewarmed() -> void:
	battle_core_resources_prewarmed = true
	battle_player_resources_prewarmed = true
	battle_boss_resources_prewarmed = true
	battle_smasher_skill_icons_prewarmed = true
	battle_viper_skill_icons_prewarmed = true
	battle_commando_skill_icons_prewarmed = true
	battle_texture_resources_prewarmed = true
	battle_resource_cache_finalized = true


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var module: Variant = module_getter.call(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null


func _request_threaded_module_script(module_getter: Callable, key: String) -> void:
	if not module_getter.is_valid():
		return
	var callable_owner: Object = module_getter.get_object()
	if callable_owner == null or not is_instance_valid(callable_owner):
		return
	if callable_owner.has_method("request_threaded_script"):
		callable_owner.call("request_threaded_script", key)


func _is_threaded_module_script_ready(module_getter: Callable, key: String) -> bool:
	if not module_getter.is_valid():
		return true
	var callable_owner: Object = module_getter.get_object()
	if callable_owner == null or not is_instance_valid(callable_owner):
		return true
	if callable_owner.has_method("is_threaded_script_ready"):
		return bool(callable_owner.call("is_threaded_script_ready", key))
	return true


func _get_current_stage(owner: Object) -> int:
	if owner == null:
		return 1
	return int(owner.get("current_stage"))


func _get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: String = str(owner.get("selected_character_type")).strip_edges().to_lower()
	if value == "soldier" or value == "commando":
		return "soldier"
	if value == "blacksmith" or value == "baltor" or value == "kohaku":
		return "blacksmith"
	if value == "optimus" or value == "io":
		return "optimus"
	if value == "viper":
		return "viper"
	return "smasher"


func _get_stage1_boss_variant(owner: Object) -> String:
	if owner == null:
		return "dalji"
	var variant: String = str(owner.get("stage1_boss_variant")).strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"


func _get_stage1_boss_skill_hud_key(stage1_boss_variant: String) -> String:
	match _get_normalized_stage1_boss_variant(stage1_boss_variant):
		"gaksi":
			return "stage1_gaksital_boss_skill_hud_renderer"
		"dalji":
			return "stage1_dalji_boss_skill_hud_renderer"
	return ""


func _get_normalized_stage1_boss_variant(value: String) -> String:
	var variant: String = value.strip_edges().to_lower()
	if variant in ["gaksi", "gaksital", "talkwangdae", "talchum"]:
		return "gaksi"
	if variant in ["podo", "pododaejang", "podo_daejang"]:
		return "podo"
	return "dalji"


func _get_result_victory_character_type(owner: Object) -> String:
	if _get_selected_character_type(owner) == "soldier":
		return "soldier"
	return "smasher"


func _get_stage_clear_result_prewarm_key(owner: Object) -> String:
	return "%s:%d" % [_get_result_victory_character_type(owner), _get_current_stage(owner)]


func _build_resource_context(owner: Object) -> Dictionary:
	return {
		"selected_character_type": _get_selected_character_type(owner),
		"current_stage": _get_current_stage(owner),
		"stage1_boss_variant": _get_stage1_boss_variant(owner),
		"include_result_sheets": true,
		"include_all_characters": false,
		"include_all_stages": false,
	}


func _build_boot_transition_texture_context(owner: Object) -> Dictionary:
	var context := _build_resource_context(owner)
	context["include_result_sheets"] = false
	return context
