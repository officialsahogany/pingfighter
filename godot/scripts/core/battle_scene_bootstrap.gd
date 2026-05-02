extends RefCounted


func initialize(owner: Node, context: Dictionary, registry) -> Dictionary:
	var width: float = float(context.get("width", 760.0))
	var player_y: float = float(context.get("player_y", 700.0))
	var boss_y: float = float(context.get("boss_y", 25.0))
	var player_paddle_width: float = float(context.get("player_paddle_width", 155.0))
	var boss_paddle_width: float = float(context.get("boss_paddle_width", 100.0))

	var audio = registry.get_instance("game_audio")
	if audio != null:
		audio.setup(owner)
		if audio.has_method("play_stage_bgm"):
			audio.play_stage_bgm(int(context.get("current_stage", 1)))

	var battle_textures: Dictionary = {}
	var resources = registry.get_instance("battle_resources")
	if resources != null:
		battle_textures = resources.load_all()

	var skill_icons: Dictionary = {}
	var skill_icon_value: Variant = battle_textures.get("smasher_skill_icon_textures", {})
	if skill_icon_value is Dictionary:
		skill_icons = skill_icon_value

	var active_item_slots: Array = []
	var active_item_runtime = registry.get_instance("active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("build_starting_slots"):
		active_item_slots = active_item_runtime.build_starting_slots()

	var ball_physics = registry.get_instance("ball_physics")
	if ball_physics != null:
		ball_physics.configure_context(
			int(context.get("current_stage", 1)),
			str(context.get("ai_mode", "champion")),
			bool(context.get("arena_mode_enabled", false)),
			str(context.get("weather_type", ""))
		)

	return {
		"player_pos": Vector2(width * 0.5 - player_paddle_width * 0.5, player_y),
		"boss_pos": Vector2(width * 0.5 - boss_paddle_width * 0.5, boss_y),
		"battle_textures": battle_textures,
		"smasher_skill_icon_textures": skill_icons,
		"active_item_slots": active_item_slots,
	}
