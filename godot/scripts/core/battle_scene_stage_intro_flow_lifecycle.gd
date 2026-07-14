extends RefCounted


func begin_stage_landing_intro(
	flow: Object,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	cached_module_getter: Callable
) -> void:
	if flow == null:
		return
	if bool(flow.get("_stage_landing_intro_started")) or not bool(flow.get("_battle_initialized")):
		return
	var logo_intro: Object = _get_module(cached_module_getter, "penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("is_audio_playing") and bool(logo_intro.is_audio_playing()):
		_queue_redraw(owner)
		return
	# 스테이지 7 프리배틀 영상 게이트: 랜딩 BGM 시작 전에 아카무 인트로
	# 시네마틱을 먼저 재생한다. begin_video가 true면(영상 무장 성공) 랜딩을
	# 시작하지 않고 반환 — 인트로 프레임 컨트롤러가 영상을 구동하고, 완료 후
	# 같은 엔트리의 begin_video는 false를 반환해 정상 랜딩으로 진행된다.
	var stage7_akamu_prebattle_presentation: Object = _get_module(module_getter, "stage7_akamu_prebattle_presentation")
	if (
		stage7_akamu_prebattle_presentation != null
		and stage7_akamu_prebattle_presentation.has_method("begin_video")
		and bool(stage7_akamu_prebattle_presentation.begin_video(owner, registry))
	):
		_queue_redraw(owner)
		return
	start_battle_bgm(flow, owner, module_getter)
	flow.set("_stage_landing_intro_started", true)
	var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
	if landing_intro != null and landing_intro.has_method("begin"):
		if bool(landing_intro.begin(owner, registry)):
			_queue_redraw(owner)
			return
	if flow.has_method("begin_ball_spawn_intro"):
		flow.begin_ball_spawn_intro(owner, registry, module_getter)


func begin_ball_spawn_intro(flow: Object, owner: Object, registry: Object, module_getter: Callable) -> void:
	if flow == null:
		return
	if bool(flow.get("_ball_spawn_intro_started")) or not bool(flow.get("_battle_initialized")):
		return
	flow.set("_ball_spawn_intro_started", true)
	_stage_acquisition_cinematic(owner, registry, module_getter)
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if ball_spawn_intro != null and ball_spawn_intro.has_method("begin"):
		if bool(ball_spawn_intro.begin(owner, registry)):
			_queue_redraw(owner)


# Policy (b), 2026-06-11: the mythic/legendary acquisition cinematic host
# (~11 nodes, 3 GPUParticles2D) and the mythic icon sheets are staged at
# ball-spawn-intro start — entry and stage transition both pass here, with
# the owner available and outside rally frames — so the first mid-battle
# pickup no longer pays the ~52ms ensure_host cold start. The boot
# stage-runtime prewarm stays asset-only per its smoke contract
# (battle_boot_resource_prewarm_smoke). Idempotent: the runtime prewarm
# no-ops once the host exists and the loader cache holds the sheet paths.
func _stage_acquisition_cinematic(owner: Object, registry: Object, module_getter: Callable) -> void:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("prewarm_acquisition_cinematic"):
		mythic_item_runtime.prewarm_acquisition_cinematic(owner, registry)


func start_battle_bgm(flow: Object, owner: Object, module_getter: Callable) -> void:
	if flow == null or bool(flow.get("_battle_bgm_started")):
		return
	flow.set("_battle_bgm_started", true)
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio != null and audio.has_method("play_stage_bgm"):
		audio.play_stage_bgm(int(owner.get("current_stage")))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
