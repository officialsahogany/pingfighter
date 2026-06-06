extends RefCounted

const BattleSceneBossHealthFlow := preload("res://scripts/core/battle_scene_boss_health_flow.gd")

var _fallback_boss_health_flow: Object = BattleSceneBossHealthFlow.new()


func initialize(owner: Node, context: Dictionary, registry) -> Dictionary:
	var perf_logger: Object = _get_perf_logger(registry)
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var player_y: float = float(context.get("player_y", 700.0))
	var boss_y: float = float(context.get("boss_y", 25.0))
	var player_paddle_width: float = float(context.get("player_paddle_width", 155.0))
	var player_paddle_height: float = float(context.get("player_paddle_height", 50.0))
	var runtime_paddle_base_width: float = float(context.get("runtime_paddle_base_width", player_paddle_width))
	var runtime_paddle_base_height: float = float(context.get("runtime_paddle_base_height", player_paddle_height))
	var player_paddle_visual_scale_override: float = -1.0
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	var selected_character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	var current_stage: int = int(context.get("current_stage", 1))
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var boss_start_pos := Vector2(width * 0.5 - boss_paddle_width * 0.5, boss_y)

	var sample_start: int = _perf_begin(perf_logger)
	var audio = registry.get_instance("game_audio")
	if audio != null:
		audio.setup(owner)
		if bool(context.get("play_stage_bgm_on_initialize", true)) and audio.has_method("play_stage_bgm"):
			audio.play_stage_bgm(current_stage)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.audio", sample_start)

	sample_start = _perf_begin(perf_logger)
	var battle_textures: Dictionary = {}
	var resources = registry.get_instance("battle_resources")
	if resources != null:
		var resource_context := {
			"selected_character_type": selected_character_type,
			"current_stage": current_stage,
			"include_result_sheets": false,
			"include_all_characters": false,
			"include_all_stages": false,
		}
		if resources.has_method("get_resource_cache"):
			var cached_textures: Variant = resources.get_resource_cache()
			if cached_textures is Dictionary and not (cached_textures as Dictionary).is_empty():
				battle_textures = cached_textures
		if resources.has_method("load_all") and battle_textures.is_empty():
			battle_textures = resources.load_all(resource_context)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.resources", sample_start)

	sample_start = _perf_begin(perf_logger)
	var skill_icons: Dictionary = {}
	var skill_icon_value: Variant = battle_textures.get("smasher_skill_icon_textures", {})
	if skill_icon_value is Dictionary:
		skill_icons = skill_icon_value
	var viper_skill_icons: Dictionary = {}
	var viper_skill_icon_value: Variant = battle_textures.get("viper_skill_icon_textures", {})
	if viper_skill_icon_value is Dictionary:
		viper_skill_icons = viper_skill_icon_value
	var commando_skill_icons: Dictionary = {}
	var commando_skill_icon_value: Variant = battle_textures.get("commando_skill_icon_textures", {})
	if commando_skill_icon_value is Dictionary:
		commando_skill_icons = commando_skill_icon_value
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.skill_icons", sample_start)

	sample_start = _perf_begin(perf_logger)
	var active_item_slots: Array = []
	var active_item_runtime = registry.get_instance("active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("build_starting_slots"):
		active_item_slots = active_item_runtime.build_starting_slots()
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.active_item_slots", sample_start)

	sample_start = _perf_begin(perf_logger)
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var mythic_item_runtime = registry.get_instance("mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("build_starting_equipment_slots"):
		equipment_slots = mythic_item_runtime.build_starting_equipment_slots()
	if mythic_item_runtime != null and mythic_item_runtime.has_method("build_starting_inventory"):
		passive_item_inventory = mythic_item_runtime.build_starting_inventory()
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.passive_inventory", sample_start)

	sample_start = _perf_begin(perf_logger)
	var ball_physics = registry.get_instance("ball_physics")
	if ball_physics != null:
		ball_physics.configure_context(
			current_stage,
			str(context.get("ai_mode", "champion")),
			bool(context.get("arena_mode_enabled", false)),
			str(context.get("weather_type", ""))
		)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.ball_physics", sample_start)

	sample_start = _perf_begin(perf_logger)
	var starting_dash_tokens: int = max(1, int(context.get("starting_dash_tokens", 1)))
	_initialize_dash_tokens(registry, starting_dash_tokens)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.dash_tokens", sample_start)

	sample_start = _perf_begin(perf_logger)
	var optimus_snapshot: Dictionary = {}
	if selected_character_type == "optimus":
		var optimus_energy_state: Object = registry.get_instance("optimus_energy_state")
		if optimus_energy_state != null and optimus_energy_state.has_method("reset"):
			optimus_energy_state.reset()
		if optimus_energy_state != null and optimus_energy_state.has_method("build_scale_snapshot"):
			optimus_snapshot = optimus_energy_state.build_scale_snapshot(500.0)
		player_paddle_width = max(1.0, float(optimus_snapshot.get("player_paddle_width", 296.0)))
		player_paddle_height = max(1.0, float(optimus_snapshot.get("player_paddle_height", 147.0)))
		runtime_paddle_base_width = max(1.0, float(optimus_snapshot.get("runtime_paddle_base_width", player_paddle_width)))
		runtime_paddle_base_height = max(1.0, float(optimus_snapshot.get("runtime_paddle_base_height", player_paddle_height)))
		player_y = height - player_paddle_height
		special_gauge = 500.0
		special_gauge_max = 500.0
	var league_player_paddle_scale: float = max(0.1, float(context.get("league_player_paddle_scale", 1.0)))
	if not is_equal_approx(league_player_paddle_scale, 1.0):
		player_paddle_visual_scale_override = max(0.1, player_paddle_width / 155.0)
		player_paddle_width *= league_player_paddle_scale
		player_paddle_height *= league_player_paddle_scale
		runtime_paddle_base_width *= league_player_paddle_scale
		runtime_paddle_base_height *= league_player_paddle_scale
		player_y = height - player_paddle_height
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.character_state", sample_start)

	sample_start = _perf_begin(perf_logger)
	var boss_health_snapshot: Dictionary = _build_boss_health_snapshot(registry, current_stage)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.boss_health", sample_start)

	sample_start = _perf_begin(perf_logger)
	var snapshot := {
		"player_pos": Vector2(width * 0.5 - player_paddle_width * 0.5, player_y),
		"player_paddle_width": player_paddle_width,
		"player_paddle_height": player_paddle_height,
		"player_paddle_scale": max(0.1, player_paddle_width / 155.0),
		"player_paddle_visual_scale_override": player_paddle_visual_scale_override,
		"runtime_paddle_base_width": runtime_paddle_base_width,
		"runtime_paddle_base_height": runtime_paddle_base_height,
		"runtime_paddle_scale": 1.0,
		"starting_dash_tokens": starting_dash_tokens,
		"boss_pos": boss_start_pos,
		"boss_pos_prev": boss_start_pos,
		"boss_paddle_width": boss_paddle_width,
		"boss_hitbox_height": boss_hitbox_height,
		"selected_character_type": selected_character_type,
		"battle_textures": battle_textures,
		"smasher_skill_icon_textures": skill_icons,
		"viper_skill_icon_textures": viper_skill_icons,
		"commando_skill_icon_textures": commando_skill_icons,
		"active_item_slots": active_item_slots,
		"special_gauge": special_gauge,
		"special_gauge_max": special_gauge_max,
		"blacksmith_umbrella_open": false,
		"blacksmith_umbrella_anim_timer": 0.0,
		"blacksmith_umbrella_retracting": false,
		"blacksmith_umbrella_anim_direction": 1,
		"blacksmith_umbrella_open_ratio": 0.0,
		"blacksmith_thor_shield_open_ratio": 0.0,
		"blacksmith_umbrella_raise_amount": 0.0,
		"blacksmith_umbrella_shield_open_amount": 0.0,
		"blacksmith_umbrella_visual_state": "closed",
		"blacksmith_umbrella_folded": true,
		"blacksmith_umbrella_deployed": false,
		"blacksmith_umbrella_swing_active": false,
		"blacksmith_umbrella_swing_direction": 0,
		"blacksmith_umbrella_swing_timer": 0.0,
		"blacksmith_umbrella_gauge": 5,
		"blacksmith_umbrella_gauge_max": 5,
		"blacksmith_umbrella_gauge_gain": 60.0,
		"blacksmith_umbrella_damage_flash_timer": 0.0,
		"blacksmith_umbrella_hit_pulse_timer": 0.0,
		"equipment_slots": equipment_slots,
		"passive_item_inventory": passive_item_inventory,
		"passive_item_slots": equipment_slots.duplicate(true),
		"equipped_passive_items": equipment_slots.duplicate(true),
	}
	if not optimus_snapshot.is_empty():
		optimus_snapshot["optimus_energy_initialized"] = true
		optimus_snapshot["special_gauge"] = special_gauge
		optimus_snapshot["special_gauge_max"] = special_gauge_max
		snapshot.merge(optimus_snapshot, true)
	snapshot.merge(boss_health_snapshot, true)
	_perf_end(perf_logger, "process.intro.initialize_battle.bootstrap.snapshot", sample_start)
	return snapshot


func _initialize_dash_tokens(registry: Object, starting_dash_tokens: int) -> void:
	var token_count: int = max(1, starting_dash_tokens)
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("reset_full"):
		dash_state.reset_full(token_count)
	var orb_hud_state: Object = _get_instance(registry, "orb_hud_state")
	if orb_hud_state == null or not orb_hud_state.has_method("reset_dash_tokens"):
		return
	var current_tokens: int = token_count
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot_value: Variant = dash_state.get_snapshot()
		if snapshot_value is Dictionary:
			var dash_snapshot: Dictionary = snapshot_value
			current_tokens = int(dash_snapshot.get("tokens", token_count))
	orb_hud_state.reset_dash_tokens(current_tokens)


func _build_boss_health_snapshot(registry: Object, current_stage: int) -> Dictionary:
	var flow: Object = _get_boss_health_flow(registry)
	if flow != null and flow.has_method("build_stage_health_snapshot"):
		return flow.build_stage_health_snapshot(current_stage)
	return _fallback_boss_health_flow.build_stage_health_snapshot(current_stage)


func _get_boss_health_flow(registry: Object) -> Object:
	if registry != null and registry.has_method("get_instance"):
		var flow: Object = registry.get_instance("battle_scene_boss_health_flow")
		if flow != null and flow.has_method("build_stage_health_snapshot"):
			return flow
	return _fallback_boss_health_flow


func _get_perf_logger(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("battle_perf_logger")


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger == null or not perf_logger.has_method("begin_sample"):
		return 0
	return int(perf_logger.begin_sample())


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger == null or not perf_logger.has_method("finish_sample"):
		return
	perf_logger.finish_sample(label, start_usec)
