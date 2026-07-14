extends RefCounted

const BattleBootWarmupSampleLabels := preload("res://scripts/core/battle_boot_warmup_sample_labels.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const BOOT_WARMUP_TOTAL_STEPS := 21
# Frame-budgeted step batching. The boot loading path used to advance exactly
# one warmup (sub)step per process frame, so an entry loading of ~2,100 step
# invocations was paced by wall-clock frame rate (~30s at 72 FPS for ~11s of
# measured work; most substeps are sub-millisecond). The budgeted loop packs
# synchronous substeps into one frame until the time budget is spent, but must
# yield the frame whenever the current step waits on work only a real frame
# can advance:
# - the shared threaded texture/audio prewarm slot: its bounded-fallback
#   counters assume ~1 poll per frame, so same-frame spin-polling would hit
#   MAX_POLLS early and demote big threaded sheet loads to synchronous
#   main-thread fallbacks (see project_resource_loader.gd), and
# - the BattlePsoPrewarmer node: GPU pipeline warmup advances per rendered
#   frame, not per call.
# BOOT_WARMUP_MAX_STEPS_PER_FRAME bounds any unknown wait-poll step that
# returns "call me again" without making observable progress.
const BOOT_WARMUP_FRAME_BUDGET_USEC := 24000
const BOOT_WARMUP_MAX_STEPS_PER_FRAME := 128
const PSO_PREWARMER_NODE_NAME := "BattlePsoPrewarmer"
const BOOT_WARMUP_SAMPLE_PREFIX := "process.intro.boot_warmup_step."
const BOOT_WARMUP_STATUS_BY_STEP := {
	0: "전투 화면 준비 중",
	1: "인트로 리소스 확인 중",
	2: "핵심 전투 리소스 불러오는 중",
	3: "플레이어 리소스 불러오는 중",
	4: "보스 리소스 불러오는 중",
	5: "스매셔 스킬 아이콘 준비 중",
	6: "바이퍼 스킬 아이콘 준비 중",
	7: "전투 캐시 정리 중",
	8: "오디오 장치 준비 중",
	9: "스테이지 BGM 준비 중",
	10: "전투 리소스 마무리 중",
	11: "시작 모듈 준비 중",
	12: "아이템 런타임 준비 중",
	13: "업데이트 런타임 준비 중",
	14: "공 물리 런타임 준비 중",
	15: "드로우 런타임 준비 중",
	16: "스테이지 인트로 준비 중",
	17: "스테이지 런타임 준비 중",
	18: "결과 화면 리소스 준비 중",
	19: "전투 상태 초기화 중",
	20: "첫 프레임 정리 중",
}

var prewarmed_module_groups: Dictionary = {}
var prewarm_module_group_indices: Dictionary = {}
var boot_warmup_step: int = 0
var boot_warmup_finished: bool = false


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


func is_finished() -> bool:
	return boot_warmup_finished


func get_progress(module_getter: Callable = Callable()) -> float:
	if boot_warmup_finished:
		return 1.0
	var step_progress: float = _get_current_step_progress(module_getter)
	return clampf((float(boot_warmup_step) + step_progress) / float(BOOT_WARMUP_TOTAL_STEPS), 0.0, 0.99)


func get_status_text() -> String:
	if boot_warmup_finished:
		return LanguageSettings.translate_text("전투 준비 완료")
	return LanguageSettings.translate_text(str(BOOT_WARMUP_STATUS_BY_STEP.get(boot_warmup_step, "전투 데이터 준비 중")))


func get_total_steps() -> int:
	return BOOT_WARMUP_TOTAL_STEPS


func get_current_sample_detail_label(owner: Object, module_getter: Callable) -> String:
	var sample_label := _get_boot_warmup_sample_label(owner, module_getter)
	if sample_label.begins_with(BOOT_WARMUP_SAMPLE_PREFIX):
		return sample_label.substr(BOOT_WARMUP_SAMPLE_PREFIX.length())
	return sample_label


func _get_current_step_progress(module_getter: Callable) -> float:
	if not module_getter.is_valid():
		return 0.0
	match boot_warmup_step:
		8:
			var audio: Object = _get_module(module_getter, "game_audio")
			if audio != null and audio.has_method("get_setup_progress"):
				return clampf(float(audio.get_setup_progress()), 0.0, 0.98)
	return 0.0


func prewarm_battle_resources(owner: Object, module_getter: Callable) -> void:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm != null and resource_prewarm.has_method("prewarm_battle_resources"):
		resource_prewarm.prewarm_battle_resources(owner, module_getter)


func run_boot_warmup_step(
	owner: Object,
	module_getter: Callable,
	initialize_battle: Callable,
	request_redraw: Callable = Callable()
) -> void:
	if boot_warmup_finished:
		return
	var logo_intro: Object = _get_module(module_getter, "penguin_logo_intro")
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	var perf_label: String = _get_boot_warmup_sample_label(owner, module_getter)
	var perf_start: int = _perf_begin(perf_logger)
	var should_advance := true
	match boot_warmup_step:
		0:
			pass
		1:
			if logo_intro != null and logo_intro.has_method("prewarm_assets"):
				logo_intro.prewarm_assets()
		2:
			should_advance = _call_resource_prewarm_bool(owner, module_getter, "prewarm_battle_texture_resources_step")
		3:
			_call_resource_prewarm_with_owner(owner, module_getter, "prewarm_battle_player_resources")
		4:
			_call_resource_prewarm_with_owner(owner, module_getter, "prewarm_battle_boss_resources")
		5:
			_call_resource_prewarm_with_owner(owner, module_getter, "prewarm_battle_smasher_skill_icons")
		6:
			_call_resource_prewarm_with_owner(owner, module_getter, "prewarm_battle_viper_skill_icons")
		7:
			_call_resource_prewarm_with_owner(owner, module_getter, "finalize_battle_resource_cache")
		8:
			should_advance = _call_resource_prewarm_bool(owner, module_getter, "prewarm_battle_audio_setup_step")
		9:
			_call_resource_prewarm_with_owner(owner, module_getter, "prime_battle_bgm")
		10:
			should_advance = _call_resource_prewarm_bool(owner, module_getter, "finish_battle_resource_prewarm")
		11:
			should_advance = _prewarm_module_group_step(owner, module_getter, "battle_startup")
		12:
			should_advance = _prewarm_module_group_step(owner, module_getter, "item_runtime")
		13:
			should_advance = _prewarm_module_group_step(owner, module_getter, "update_runtime")
			if should_advance:
				should_advance = _prewarm_update_runtime_step(owner, module_getter)
		14:
			should_advance = _prewarm_module_group_step(owner, module_getter, "ball_runtime")
		15:
			should_advance = _prewarm_module_group_step(owner, module_getter, "draw_runtime")
		16:
			should_advance = _call_resource_prewarm_bool(owner, module_getter, "prewarm_stage_intro_resources_step")
		17:
			should_advance = _call_resource_prewarm_bool(owner, module_getter, "prewarm_stage_runtime_resources_step")
		18:
			should_advance = _call_stage_clear_result_resources_prewarm_bool(owner, module_getter)
		19:
			if initialize_battle.is_valid():
				initialize_battle.call(false)
		20:
			if request_redraw.is_valid():
				request_redraw.call()
		_:
			boot_warmup_finished = true
	_perf_end(perf_logger, perf_label, perf_start)
	if not should_advance:
		return
	boot_warmup_step += 1


func run_boot_warmup_steps_budgeted(
	owner: Object,
	module_getter: Callable,
	initialize_battle: Callable,
	request_redraw: Callable = Callable(),
	budget_usec: int = BOOT_WARMUP_FRAME_BUDGET_USEC
) -> void:
	# A slot orphaned by the menu-idle entry prewarmer (scene changed mid-load)
	# would otherwise hold the in-flight gate true and throttle this whole loop
	# to one step per frame. Resolve a finished foreign load before batching.
	ProjectResourceLoader.try_resolve_finished_threaded_prewarm()
	var deadline_usec: int = Time.get_ticks_usec() + max(0, budget_usec)
	var steps_left: int = BOOT_WARMUP_MAX_STEPS_PER_FRAME
	while not boot_warmup_finished and steps_left > 0:
		run_boot_warmup_step(owner, module_getter, initialize_battle, request_redraw)
		steps_left -= 1
		if Time.get_ticks_usec() >= deadline_usec:
			return
		if _is_waiting_on_frame_gated_work(owner, module_getter):
			return


func _is_waiting_on_frame_gated_work(owner: Object, module_getter: Callable) -> bool:
	if _is_threaded_prewarm_in_flight(module_getter):
		return true
	return _is_pso_prewarmer_node_alive(owner)


func _is_threaded_prewarm_in_flight(module_getter: Callable) -> bool:
	if ProjectResourceLoader.has_threaded_prewarm_in_flight():
		return true
	# Stage 7 프리배틀 영상은 ResourceLoader에 직접 스레드 요청을 건다(공유
	# 슬롯 밖). in-flight를 여기 등재하지 않으면 budgeted 루프가 같은 스텝을
	# 프레임당 128회 폴링해 냉부트에서 poll 예산이 수 프레임 만에 소진된다.
	# 캐시 peek 전용 — 타 스테이지 부트에서 Stage 7 presentation을 생성하지
	# 않는다(핫패스 lazy-init 금지와 같은 취지).
	var stage7_prebattle: Object = _peek_cached_module(module_getter, "stage7_akamu_prebattle_presentation")
	if (
		stage7_prebattle != null
		and stage7_prebattle.has_method("is_video_thread_load_in_flight")
		and bool(stage7_prebattle.is_video_thread_load_in_flight())
	):
		return true
	# battle_resources owns separate transition/result threaded slots that do
	# not go through the shared ProjectResourceLoader slot.
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources != null and resources.has_method("is_threaded_prewarm_in_flight"):
		return bool(resources.is_threaded_prewarm_in_flight())
	return false


func _is_pso_prewarmer_node_alive(owner: Object) -> bool:
	if owner == null or not (owner is Node):
		return false
	var prewarmer: Node = (owner as Node).get_node_or_null(PSO_PREWARMER_NODE_NAME)
	return prewarmer != null and is_instance_valid(prewarmer) and not prewarmer.is_queued_for_deletion()


func run_logo_intro_warmup_step(module_getter: Callable) -> void:
	if boot_warmup_finished:
		return
	if boot_warmup_step > 1:
		return
	var logo_intro: Object = _get_module(module_getter, "penguin_logo_intro")
	match boot_warmup_step:
		0:
			pass
		1:
			if logo_intro != null and logo_intro.has_method("prewarm_assets"):
				logo_intro.prewarm_assets()
	boot_warmup_step += 1


func _prewarm_module_group(owner: Object, module_getter: Callable, group_name: String) -> void:
	if prewarmed_module_groups.has(group_name):
		return
	var module_keys: Array = _get_warmup_module_group_for_owner(owner, module_getter, group_name)
	for module_key in module_keys:
		_get_module(module_getter, str(module_key))
	prewarmed_module_groups[group_name] = true
	prewarm_module_group_indices.erase(group_name)


func _prewarm_module_group_step(owner: Object, module_getter: Callable, group_name: String) -> bool:
	if prewarmed_module_groups.has(group_name):
		return true
	var module_keys: Array = _get_warmup_module_group_for_owner(owner, module_getter, group_name)
	if module_keys.is_empty():
		prewarmed_module_groups[group_name] = true
		prewarm_module_group_indices.erase(group_name)
		return true
	var module_index := int(prewarm_module_group_indices.get(group_name, 0))
	if module_index >= module_keys.size():
		prewarmed_module_groups[group_name] = true
		prewarm_module_group_indices.erase(group_name)
		return true
	var module: Object = _get_module(module_getter, str(module_keys[module_index]))
	if not _prewarm_module_initialization_step(group_name, module):
		prewarm_module_group_indices[group_name] = module_index
		return false
	module_index += 1
	if module_index >= module_keys.size():
		prewarmed_module_groups[group_name] = true
		prewarm_module_group_indices.erase(group_name)
		return true
	prewarm_module_group_indices[group_name] = module_index
	return false


func _prewarm_module_initialization_step(group_name: String, module: Object) -> bool:
	if group_name != "item_runtime":
		return true
	if module == null or not module.has_method("prewarm_initialization_step"):
		return true
	return bool(module.prewarm_initialization_step())


func _get_warmup_module_group(module_getter: Callable, group_name: String) -> Array:
	var warmup_plan: Object = _get_module(module_getter, "battle_boot_warmup_plan")
	if warmup_plan == null or not warmup_plan.has_method("get_module_group"):
		return []
	return warmup_plan.get_module_group(group_name)


func _get_warmup_module_group_for_owner(owner: Object, module_getter: Callable, group_name: String) -> Array:
	return _filter_current_stage_module_group(owner, group_name, _get_warmup_module_group(module_getter, group_name))


func _filter_current_stage_module_group(owner: Object, group_name: String, module_keys: Array) -> Array:
	if group_name != "update_runtime" and group_name != "draw_runtime":
		return module_keys
	var current_stage := _get_current_stage(owner)
	var filtered_keys: Array = []
	for module_key_value in module_keys:
		var module_key := str(module_key_value)
		if _is_stage_scoped_module_key(module_key) and not _is_module_key_for_stage(module_key, current_stage):
			continue
		filtered_keys.append(module_key_value)
	return filtered_keys


func _is_stage_scoped_module_key(module_key: String) -> bool:
	return (
		module_key.begins_with("stage1_")
		or module_key.begins_with("stage2_")
		or module_key.begins_with("stage3_")
		or module_key.begins_with("stage4_")
		or module_key.begins_with("stage5_")
	)


func _is_module_key_for_stage(module_key: String, current_stage: int) -> bool:
	match current_stage:
		1:
			return module_key.begins_with("stage1_")
		2:
			return module_key.begins_with("stage2_")
		3:
			return module_key.begins_with("stage3_")
		4:
			return module_key.begins_with("stage4_")
		5:
			return module_key.begins_with("stage5_")
	return true


func _call_resource_prewarm(module_getter: Callable, method_name: String) -> void:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm != null and resource_prewarm.has_method(method_name):
		resource_prewarm.call(method_name, module_getter)


func _call_resource_prewarm_with_owner(owner: Object, module_getter: Callable, method_name: String) -> void:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm != null and resource_prewarm.has_method(method_name):
		resource_prewarm.call(method_name, owner, module_getter)


func _call_resource_prewarm_bool(owner: Object, module_getter: Callable, method_name: String) -> bool:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm == null or not resource_prewarm.has_method(method_name):
		return true
	return bool(resource_prewarm.call(method_name, owner, module_getter))


func _call_resource_prewarm_bool_no_owner(module_getter: Callable, method_name: String) -> bool:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm == null or not resource_prewarm.has_method(method_name):
		return true
	return bool(resource_prewarm.call(method_name, module_getter))


func _call_stage_clear_result_resources_prewarm_bool(owner: Object, module_getter: Callable) -> bool:
	var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
	if resource_prewarm == null or not resource_prewarm.has_method("prewarm_stage_clear_result_resources_step"):
		return true
	return bool(resource_prewarm.call("prewarm_stage_clear_result_resources_step", module_getter, owner))


func _get_boot_warmup_sample_label(owner: Object, module_getter: Callable) -> String:
	var label := str(BattleBootWarmupSampleLabels.BOOT_WARMUP_SAMPLE_LABEL_BY_STEP.get(
		boot_warmup_step,
		"%02d_unknown" % boot_warmup_step
	))
	match boot_warmup_step:
		2:
			var resources: Object = _get_module(module_getter, "battle_resources")
			var texture_step := _get_int_property(resources, "_transition_texture_prewarm_step_index", -1)
			if texture_step >= 0:
				label += ".sub_%02d" % texture_step
		8:
			var audio: Object = _get_module(module_getter, "game_audio")
			var audio_step := _get_int_property(audio, "_audio_setup_step", -1)
			if audio_step >= 0:
				label += ".sub_%02d" % audio_step
				var stream_prewarm_group := _get_int_property(audio, "_audio_setup_stream_prewarm_group", -1)
				var stream_prewarm_index := _get_int_property(audio, "_audio_setup_stream_prewarm_index", -1)
				if stream_prewarm_group == audio_step and stream_prewarm_index >= 0:
					label += ".stream_%02d" % stream_prewarm_index
			if audio_step == 6:
				var bgm_step := _get_int_property(audio, "_bgm_setup_step", -1)
				if bgm_step >= 0:
					label += ".%s" % BattleBootWarmupSampleLabels.get_bgm_setup_sample_label(bgm_step)
		10:
			if _get_current_stage(owner) == 1:
				var stage1_background: Object = _get_module(module_getter, "stage1_pillar_background")
				var stage1_background_step := _get_int_property(stage1_background, "_prewarm_assets_step_index", -1)
				if stage1_background_step >= 0:
					label += ".stage1_bg_%02d" % stage1_background_step
		11:
			label += _get_module_group_sample_suffix(owner, module_getter, "battle_startup")
		12:
			label += _get_module_group_sample_suffix(owner, module_getter, "item_runtime")
		13:
			var update_prewarm: Object = _get_module(module_getter, "battle_scene_update_prewarm_driver")
			if _get_bool_property(update_prewarm, "battle_update_prewarmed", false):
				label += ".prewarm_update.done"
			elif prewarmed_module_groups.has("update_runtime"):
				var update_step := _get_int_property(update_prewarm, "update_prewarm_step_index", 0)
				label += ".prewarm_update.%02d" % update_step
				var update_detail := _get_update_prewarm_detail_label(update_prewarm, owner)
				if update_detail != "":
					label += "_%s" % _sanitize_sample_token(update_detail)
			else:
				label += _get_module_group_sample_suffix(owner, module_getter, "update_runtime")
		14:
			label += _get_module_group_sample_suffix(owner, module_getter, "ball_runtime")
		15:
			label += _get_module_group_sample_suffix(owner, module_getter, "draw_runtime")
		16:
			var resource_prewarm_intro: Object = _get_resource_prewarm_controller(module_getter)
			var stage_intro_step := _get_int_property(resource_prewarm_intro, "stage_intro_resources_prewarm_step_index", -1)
			if stage_intro_step >= 0:
				label += ".%s" % BattleBootWarmupSampleLabels.get_stage_intro_sample_label(stage_intro_step)
		17:
			var resource_prewarm: Object = _get_resource_prewarm_controller(module_getter)
			var stage_detail_label := _get_stage_runtime_prewarm_detail_label(owner, resource_prewarm)
			if stage_detail_label != "":
				label += ".%s" % stage_detail_label
	return "process.intro.boot_warmup_step.%s" % label


func _get_stage_runtime_prewarm_detail_label(owner: Object, resource_prewarm: Object) -> String:
	if resource_prewarm == null:
		return ""
	if resource_prewarm.has_method("get_stage_runtime_prewarm_debug_label"):
		var debug_label := str(resource_prewarm.get_stage_runtime_prewarm_debug_label(owner))
		if debug_label != "":
			return debug_label
	var stage_step := _get_int_property(resource_prewarm, "stage_runtime_prewarm_step_index", -1)
	if stage_step >= 0:
		return BattleBootWarmupSampleLabels.get_stage_runtime_sample_label(_get_current_stage(owner), stage_step)
	return ""


func _get_module_group_sample_suffix(owner: Object, module_getter: Callable, group_name: String) -> String:
	var module_keys: Array = _get_warmup_module_group_for_owner(owner, module_getter, group_name)
	if module_keys.is_empty():
		return ".empty"
	var module_index := int(prewarm_module_group_indices.get(group_name, 0))
	if module_index >= module_keys.size():
		return ".done"
	return ".%02d_%s" % [module_index, _sanitize_sample_token(str(module_keys[module_index]))]


func _sanitize_sample_token(value: String) -> String:
	return value.replace("/", "_").replace("\\", "_").replace(":", "_").replace(" ", "_")


func _get_current_stage(owner: Object) -> int:
	if owner == null:
		return 1
	var value: Variant = owner.get("current_stage")
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return 1


func _get_int_property(source: Object, property_name: String, fallback: int) -> int:
	if source == null:
		return fallback
	var value: Variant = source.get(property_name)
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func _get_bool_property(source: Object, property_name: String, fallback: bool) -> bool:
	if source == null:
		return fallback
	var value: Variant = source.get(property_name)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback


func _get_string_property(source: Object, property_name: String, fallback: String) -> String:
	if source == null:
		return fallback
	var value: Variant = source.get(property_name)
	if typeof(value) == TYPE_STRING:
		return str(value)
	return fallback


func _get_update_prewarm_detail_label(update_prewarm: Object, owner: Object) -> String:
	if update_prewarm == null:
		return ""
	if update_prewarm.has_method("get_update_prewarm_detail_label"):
		var value: Variant = update_prewarm.get_update_prewarm_detail_label(owner)
		if typeof(value) == TYPE_STRING:
			return str(value)
	return _get_string_property(update_prewarm, "update_prewarm_detail_label", "")


func _prewarm_update_runtime_step(owner: Object, module_getter: Callable) -> bool:
	var prewarm_driver: Object = _get_module(module_getter, "battle_scene_update_prewarm_driver")
	if prewarm_driver == null:
		return true
	var registry := ModuleGetterRegistryAdapter.new(module_getter)
	if prewarm_driver.has_method("prewarm_update_step"):
		return bool(prewarm_driver.prewarm_update_step(owner, registry))
	if prewarm_driver.has_method("prewarm_update"):
		prewarm_driver.prewarm_update(owner, registry)
	return true


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_resource_prewarm_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_boot_resource_prewarm_controller")


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var module: Variant = module_getter.call(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null


func _peek_cached_module(module_getter: Callable, key: String) -> Object:
	# 레지스트리가 비생성 peek(get_cached_instance)를 제공하면 그것만 쓴다 —
	# 미등록 키를 여기서 get_instance로 조회하면 모듈이 '생성'된다.
	if not module_getter.is_valid():
		return null
	var callable_owner: Object = module_getter.get_object()
	if callable_owner != null and is_instance_valid(callable_owner) and callable_owner.has_method("get_cached_instance"):
		var cached: Variant = callable_owner.call("get_cached_instance", key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	return _get_module(module_getter, key)
