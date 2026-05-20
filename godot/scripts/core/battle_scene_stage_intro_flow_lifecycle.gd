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
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if ball_spawn_intro != null and ball_spawn_intro.has_method("begin"):
		if bool(ball_spawn_intro.begin(owner, registry)):
			_queue_redraw(owner)


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
